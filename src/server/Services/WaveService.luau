--!strict
-- WaveService.luau — menerjemahkan satu baris `Waves.luau` jadi antrian spawn.
--
-- Pembagiannya sendiri (berapa musuh tiap tipe, urutannya, lane-nya) ada di
-- modul murni MatchRules.luau supaya bisa dites Lune di CI. Yang tinggal di
-- sini cuma yang memang butuh runtime Roblox: mendengarkan MatchService,
-- memanggil EnemyService, dan memutuskan kapan wave dianggap bersih.
--
-- Service ini TIDAK mengubah state match. Dia melapor lewat
-- `MatchService.onWaveCleared()` dan MatchService yang memutuskan apakah itu
-- berarti Intermission atau kemenangan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local MatchRules = require(Shared.Modules.MatchRules)
local Waves = require(Shared.Modules.Waves)

local EnemyService = require(script.Parent.EnemyService)
local MatchService = require(script.Parent.MatchService)

local WaveService = {}

-- Boss (wave 5 dan 10) adalah M4. Sampai BossService ada, `bossId` di
-- `Waves.luau` sengaja diabaikan dan wave itu dijalankan sebagai wave biasa.
-- Pengait di bawah disuntik dari init.server.luau, bukan di-require, supaya M4
-- tidak perlu mengubah arah require dan supaya M2 bisa jalan sendiri.
export type BossHooks = {
	spawnForWave: (bossId: string) -> (),
	isBossAlive: () -> boolean,
}

local bossHooks: BossHooks? = nil

local started = false
local activeWave = 0

function WaveService.setBossHooks(hooks: BossHooks?)
	bossHooks = hooks
end

local function startWave(index: number)
	local def = Waves.get(index)
	if def == nil then
		warn(string.format("[WaveService] wave %d tidak ada di Waves.luau", index))
		return
	end

	activeWave = index

	local playerCount = math.max(1, MatchService.getParticipantCount())
	local total = Balance.enemyCount(index, playerCount)
	local laneCount = math.max(1, EnemyService.laneCount())

	EnemyService.primeSpawnTimer()
	EnemyService.setRunning(true)

	-- Boss di-spawn SEBELUM musuh biasa diantre. Alasannya mekaniknya: Splitter
	-- membelah jadi musuh kecil saat HP-nya turun, dan itu cuma bermakna kalau
	-- boss-nya sudah ada di arena sejak awal wave, bukan muncul setelah 30
	-- musuh biasa habis.
	local bossId = def.bossId
	local hooks = bossHooks
	if bossId ~= nil and hooks ~= nil then
		hooks.spawnForWave(bossId)
	end

	local order = MatchRules.spawnOrder(def.entries, total, laneCount)
	for _, item in order do
		EnemyService.queue(item.enemyId, item.laneIndex)
	end

	print(
		string.format(
			"[WaveService] wave %d: %d musuh biasa di %d lane, %d player%s",
			index,
			#order,
			laneCount,
			playerCount,
			if bossId ~= nil and hooks ~= nil
				then string.format(", boss %s", bossId)
				elseif bossId ~= nil then ", boss diabaikan (BossService belum ada)"
				else ""
		)
	)
end

-- Wave bersih kalau TIDAK ada musuh aktif, TIDAK ada antrian, DAN boss-nya
-- sudah mati. Tiga syarat, bukan satu: boss di-spawn lewat jalur terpisah dan
-- musuh yang dipanggil mekanik boss (Locker memanggil minion terus-menerus)
-- bisa masuk ke daftar aktif setelah antrian wave sudah habis.
local function isWaveClear(): boolean
	if not EnemyService.isClear() then
		return false
	end
	local hooks = bossHooks
	if hooks ~= nil and hooks.isBossAlive() then
		return false
	end
	return true
end

-- Idempoten dengan sengaja: dipanggil dari beberapa sumber (musuh terakhir
-- mati, boss mati, dan pemeriksaan berkala), dan `activeWave = 0` di bawah
-- yang memastikan `onWaveCleared` cuma dikirim sekali per wave.
function WaveService.checkClear()
	if MatchService.getState() ~= "WaveActive" then
		return
	end
	if activeWave == 0 then
		return
	end
	if not isWaveClear() then
		return
	end
	activeWave = 0
	MatchService.onWaveCleared()
end

function WaveService.start()
	if started then
		return
	end
	started = true

	MatchService.onWaveStarted:Connect(startWave)
	EnemyService.onAllClear:Connect(WaveService.checkClear)

	-- Jaring pengaman. `onAllClear` adalah jalur utamanya, tapi satu sinyal
	-- yang terlewat di sini berarti match nyangkut di WaveActive selamanya —
	-- kegagalan yang tidak bisa dipulihkan pemain tanpa restart server. Polling
	-- dua kali per detik harganya nol dibanding risiko itu, dan checkClear
	-- idempoten jadi pemanggilan ekstra tidak berefek.
	task.spawn(function()
		while true do
			task.wait(0.5)
			WaveService.checkClear()
		end
	end)

	MatchService.onStateChanged:Connect(function(next: MatchService.State)
		if next == "Lobby" or next == "Ended" then
			activeWave = 0
		end
	end)
end

function WaveService.getActiveWave(): number
	return activeWave
end

return WaveService
