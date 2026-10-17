--!strict
-- BossService.luau — dispatcher perilaku boss.
--
-- Service ini tidak tahu apa pun tentang membelah atau mengunci toko. Dia
-- membaca `mechanic.kind` dari Bosses.luau dan mendelegasikan ke modul di
-- Bosses/. Pembedaannya dari `kind`, BUKAN dari id boss (`if bossId ==
-- "boss_splitter"`), supaya menambah boss baru yang memakai mekanik yang sama
-- tidak perlu menyentuh file ini — itu sebabnya Types.BossMechanic ditulis
-- sebagai tagged union.
--
-- HP boss disiarkan ke client lewat `BossState`, satu remote yang TIDAK ada di
-- tabel bagian 3.6. Alasannya: M4 minta "HP bar boss di HUD", dan payload
-- `MatchState` yang sudah dipatok tabel itu tidak punya tempat untuk HP boss.
-- Ini penambahan, bukan penggantian nama.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Bosses = require(Shared.Modules.Bosses)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Modules.Signal)

local EnemyService = require(script.Parent.EnemyService)
local MatchService = require(script.Parent.MatchService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Locker = require(script.Parent.Bosses.Locker)
local Splitter = require(script.Parent.Bosses.Splitter)

local BossService = {}

-- (bossId). Ditembakkan setelah drop material dibagikan.
BossService.onBossDefeated = Signal.new() :: Signal.Signal<string>

local BROADCAST_INTERVAL = 0.2

local activeBossId: string? = nil
local activeEnemyId: number? = nil
local splitterState = Splitter.newState()
local lockerState = Locker.newState()
local lastBroadcastAt = 0
local lastSentHp = -1

-- Material yang didapat peserta pada match ini, per UserId. Dipakai dua hal:
-- memberi material ke peserta yang sedang disconnect saat boss mati (dibayar
-- saat dia rejoin), dan mengisi payload `MatchResult` di M5.
local matchMaterials: { [number]: { [string]: number } } = {}
local pendingGrants: { [number]: { [string]: number } } = {}

local started = false
local loop: thread? = nil

local function broadcastBossState(alive: boolean)
	local bossId = activeBossId
	if bossId == nil then
		Remotes.Events.BossState:FireAllClients({
			bossId = "",
			hp = 0,
			maxHp = 0,
			alive = false,
		})
		return
	end

	local enemyId = activeEnemyId
	local enemy = if enemyId ~= nil then EnemyService.get(enemyId) else nil

	Remotes.Events.BossState:FireAllClients({
		bossId = bossId,
		hp = if enemy ~= nil then enemy.hp else 0,
		maxHp = if enemy ~= nil then enemy.maxHp else 0,
		alive = alive and enemy ~= nil and not enemy.dead,
	})
end

-- Material dicatat ke pembukuan match untuk SEMUA peserta (M4: "drop material
-- ke semua player yang ikut match"), lalu dibayarkan sekarang ke yang sedang
-- terhubung dan ditandai tertunda untuk yang sedang disconnect. Peserta yang
-- disconnect boleh rejoin dan melanjutkan (bagian 3.3), jadi dropnya tidak
-- boleh hilang hanya karena dia sedang tidak di server saat boss mati.
local function grantMaterial(materialId: string, amount: number)
	local userIds = MatchService.getParticipants()
	if #userIds == 0 then
		return
	end

	for _, userId in userIds do
		local ledger = matchMaterials[userId]
		if ledger == nil then
			ledger = {}
			matchMaterials[userId] = ledger
		end
		ledger[materialId] = (ledger[materialId] or 0) + amount

		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			-- update() yang mengirim DataChanged, jadi tidak perlu manual.
			PlayerDataService.update(player, function(data)
				data.materials[materialId] = (data.materials[materialId] or 0) + amount
			end)
		else
			local tertunda = pendingGrants[userId]
			if tertunda == nil then
				tertunda = {}
				pendingGrants[userId] = tertunda
			end
			tertunda[materialId] = (tertunda[materialId] or 0) + amount
		end
	end

	print(string.format("[BossService] drop %s x%d ke %d peserta", materialId, amount, #userIds))
end

local function flushPending(player: Player)
	local tertunda = pendingGrants[player.UserId]
	if tertunda == nil then
		return
	end
	pendingGrants[player.UserId] = nil

	PlayerDataService.update(player, function(data)
		for materialId, amount in tertunda do
			data.materials[materialId] = (data.materials[materialId] or 0) + amount
		end
	end)
	print(string.format("[BossService] material tertunda dibayarkan ke %s", player.Name))
end

local function clearActive()
	activeBossId = nil
	activeEnemyId = nil
	splitterState = Splitter.newState()
	lockerState = Locker.newState()
	lastSentHp = -1
end

-- --------------------------------------------------------------------------
-- API
-- --------------------------------------------------------------------------

function BossService.isBossAlive(): boolean
	local enemyId = activeEnemyId
	if enemyId == nil then
		return false
	end
	local enemy = EnemyService.get(enemyId)
	return enemy ~= nil and not enemy.dead
end

function BossService.getActiveBossId(): string?
	return activeBossId
end

-- Material yang didapat tiap peserta pada match ini. Dipakai RewardService di
-- M5 untuk mengisi payload `MatchResult`.
function BossService.getMatchMaterials(): { [number]: { [string]: number } }
	local copy: { [number]: { [string]: number } } = {}
	for userId, ledger in matchMaterials do
		copy[userId] = table.clone(ledger)
	end
	return copy
end

-- Dipanggil WaveService lewat pengait yang disuntik di init.server.luau.
function BossService.spawnForWave(bossId: string)
	local def = Bosses[bossId]
	if def == nil then
		warn(string.format("[BossService] boss '%s' tidak ada di Bosses.luau", bossId))
		return
	end

	-- Mekanik boss sebelumnya dibersihkan dulu. Dalam alur normal tidak ada
	-- yang tersisa (wave boss tidak bisa bersih sebelum boss-nya mati), tapi
	-- loop pemanggil minion Locker adalah thread yang hidup sendiri — kalau
	-- sampai ada yang tersisa, dia akan terus mengantre musuh di wave berikutnya
	-- dan tidak ada apa pun yang menunjuk ke penyebabnya.
	Locker.cleanup(lockerState)
	clearActive()
	activeBossId = bossId

	-- Boss masuk lewat antrian supaya jalurnya sama dengan musuh lain
	-- (penskalaan HP, lane, HP bar), tapi `primeSpawnTimer` di WaveService
	-- memastikan dia muncul di frame berikutnya, bukan setelah 30 musuh biasa.
	EnemyService.queueBoss(bossId, 1)

	-- Entitasnya baru ada setelah EnemyService men-spawn-nya dari antrian,
	-- jadi id-nya dicari di loop di bawah, bukan di sini.
	print(
		string.format(
			"[BossService] %s (%s) diantre untuk wave %d",
			def.name,
			def.analogy,
			def.wave
		)
	)
end

local function findSpawnedBoss()
	local bossId = activeBossId
	if bossId == nil or activeEnemyId ~= nil then
		return
	end
	for id, enemy in EnemyService.getAll() do
		if enemy.isBoss and enemy.defId == bossId then
			activeEnemyId = id

			local def = Bosses[bossId]
			if def ~= nil then
				-- Mekanik yang punya reaksi saat spawn dijalankan di sini,
				-- bukan di spawnForWave: saat itu entitasnya belum ada dan
				-- Locker butuh id-nya untuk memeriksa apakah boss masih hidup.
				if def.mechanic.kind == "locker" then
					Locker.onSpawned(lockerState, def.mechanic, enemy)
				end
			end

			broadcastBossState(true)
			return
		end
	end
end

local function onBossDefeated()
	local bossId = activeBossId
	if bossId == nil then
		return
	end
	local def = Bosses[bossId]

	if def ~= nil then
		if def.mechanic.kind == "splitter" then
			Splitter.onDefeated(splitterState, def.mechanic)
		elseif def.mechanic.kind == "locker" then
			Locker.onDefeated(lockerState, def.mechanic)
		end

		grantMaterial(def.dropMaterial, 1)

		-- Kartu info malware ditampilkan SETELAH boss mati (CONCEPT.md).
		-- Payload-nya cuma bossId: teks kartunya ada di Bosses.luau dan
		-- identik di client, jadi mengirim seluruh teksnya lewat remote cuma
		-- menambah trafik.
		for _, userId in MatchService.getParticipants() do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				Remotes.Events.ShowInfoCard:FireClient(player, bossId)
			end
		end
	end

	broadcastBossState(false)
	clearActive()
	BossService.onBossDefeated:Fire(bossId)
end

local function step()
	findSpawnedBoss()

	local enemyId = activeEnemyId
	if enemyId == nil then
		return
	end

	local enemy = EnemyService.get(enemyId)
	if enemy == nil or enemy.dead then
		onBossDefeated()
		return
	end

	local bossId = activeBossId
	local def = if bossId ~= nil then Bosses[bossId] else nil
	if def ~= nil and def.mechanic.kind == "splitter" then
		Splitter.onHealthChanged(splitterState, def.mechanic, enemy)
	end

	-- HP disiarkan paling sering BROADCAST_INTERVAL dan cuma kalau angkanya
	-- berubah. Tanpa dua syarat itu, bar HP boss mengirim 60 paket per detik
	-- ke semua client sepanjang wave 5 dan 10.
	local now = os.clock()
	if enemy.hp ~= lastSentHp and now - lastBroadcastAt >= BROADCAST_INTERVAL then
		lastSentHp = enemy.hp
		lastBroadcastAt = now
		broadcastBossState(true)
	end
end

function BossService.start()
	if started then
		return
	end
	started = true

	-- Boss yang mati karena serangan terakhir: sinyal onDied datang lebih dulu
	-- daripada loop di bawah menyadarinya, dan mendelegasikan ke jalur yang
	-- sama membuat drop material tidak tertunda sampai frame berikutnya.
	EnemyService.onDied:Connect(function(enemy)
		if enemy.isBoss and activeEnemyId == enemy.id then
			onBossDefeated()
		end
	end)

	-- Match berhenti lewat jalur yang bukan kematian boss: Core hancur, atau
	-- semua peserta keluar. Kunci toko Locker HARUS dilepas di sini juga,
	-- kalau tidak toko tetap terkunci sampai match berikutnya dan tidak ada
	-- pemain yang bisa membukanya.
	MatchService.onStateChanged:Connect(function(next: MatchService.State)
		if next == "WaveActive" then
			return
		end
		if activeBossId ~= nil or next == "Lobby" then
			Locker.cleanup(lockerState)
			broadcastBossState(false)
			clearActive()
		end
		if next == "Lobby" then
			matchMaterials = {}
		end
	end)

	Players.PlayerAdded:Connect(flushPending)
	for _, player in Players:GetPlayers() do
		flushPending(player)
	end

	loop = task.spawn(function()
		while true do
			RunService.Heartbeat:Wait()
			step()
		end
	end)

	-- Validasi data sekali saat boot, supaya boss yang mekaniknya tidak dikenal
	-- ketahuan sekarang, bukan di tengah wave 10 sebagai boss yang berjalan ke
	-- Core tanpa melakukan apa pun.
	local known = 0
	for bossId, def in Bosses do
		if def.baseHp <= 0 then
			warn(string.format("[BossService] boss '%s' baseHp-nya %d", bossId, def.baseHp))
		end
		if def.mechanic.kind == "splitter" or def.mechanic.kind == "locker" then
			known += 1
		else
			warn(
				string.format(
					"[BossService] boss '%s' memakai mekanik yang tidak ada modulnya di Bosses/",
					bossId
				)
			)
		end
	end
	print(string.format("[BossService] siap, %d boss dengan mekanik yang dikenal", known))
end

function BossService.stop()
	local thread = loop
	if thread ~= nil then
		task.cancel(thread)
		loop = nil
	end
	Locker.cleanup(lockerState)
	clearActive()
	started = false
end

return BossService
