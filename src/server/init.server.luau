--!strict
-- init.server.luau — entry point server.
-- Rojo bikin file `init.server.luau` jadi Script di node induknya,
-- jadi ini otomatis jalan sebagai ServerScriptService.Server.
--
-- File ini CUMA wiring: dia me-require service, menyambungkan sinyal antar
-- service, lalu memanggil start(). Tidak ada logika gameplay di sini.
--
-- Urutan wiring-nya penting dan sengaja satu arah: service yang lebih rendah
-- (CoreService, EnemyService) tidak pernah me-require yang lebih tinggi.
-- Ketergantungan yang arahnya berlawanan disuntik dari file ini lewat
-- `setGate` dan kawan-kawan, supaya tidak ada lingkaran require — Luau tidak
-- bisa menyelesaikan lingkaran require dan errornya ("requested module is
-- currently being loaded") muncul saat runtime, bukan saat type check.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Waves = require(Shared.Modules.Waves)

local Services = script.Services
local BossService = require(Services.BossService)
local CombatService = require(Services.CombatService)
local CoreService = require(Services.CoreService)
local EnemyService = require(Services.EnemyService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local PlayerDataService = require(Services.PlayerDataService)
local ShopService = require(Services.ShopService)
local WaveService = require(Services.WaveService)

print(string.format("[%s] server booting (place %d)", Config.GAME_NAME, game.PlaceId))

-- Smoke test pola require (docs/DEVELOPMENT_PLAN.md bagian 1.5): Waves me-require
-- Enemies dan Bosses secara relatif. Kalau baris ini tercetak di playtest,
-- `require("./Nama")` memang jalan di engine Roblox, bukan cuma di Lune.
-- Sekalian memvalidasi isinya, supaya id musuh salah ketik ketahuan saat boot.
local wavesOk, wavesErr = Waves.validate()
if wavesOk then
	print(
		string.format(
			"[%s] relative require OK — %d wave tervalidasi",
			Config.GAME_NAME,
			Waves.LAST_WAVE
		)
	)
else
	warn(string.format("[%s] data wave tidak valid: %s", Config.GAME_NAME, tostring(wavesErr)))
end

-- Kirim data ke client begitu siap. Disambung SEBELUM start() supaya player
-- yang sudah ada di server saat start() dipanggil juga kebagian.
-- Cuma PlayerDataService yang menyambung Players.PlayerAdded; dulu init ini
-- ikut menyambung dan balapan dengan load() yang yield (bagian 3.2 poin 3).
PlayerDataService.onLoaded:Connect(function(player, data)
	Remotes.Events.DataLoaded:FireClient(player, data)
end)

PlayerDataService.start()

-- Client minta snapshot datanya sendiri. Perhatikan: tidak ada parameter dari
-- client di sini — server menentukan data siapa yang dikembalikan, bukan client.
Remotes.Functions.GetProfile.OnServerInvoke = function(player: Player)
	return PlayerDataService.waitFor(player)
end

-- Contoh aksi dari client. SELALU validasi di server: argumen dari client
-- bisa apa saja (angka negatif, tabel, nil, string 1MB).
Remotes.Events.RequestAction.OnServerEvent:Connect(function(player: Player, action: unknown)
	if type(action) ~= "string" then
		return
	end

	if action == "claimDailyBonus" then
		local data = PlayerDataService.get(player)
		if not data then
			return
		end
		-- Server yang nentuin jumlahnya, bukan client.
		if os.time() - data.lastLogin > 86400 then
			-- update() yang mengirim DataChanged, jadi tidak perlu manual.
			PlayerDataService.update(player, function(d)
				d.coins += 100
			end)
		end
	end
end)

-- --------------------------------------------------------------------------
-- Gameplay
-- --------------------------------------------------------------------------

-- Pembacaan map dilakukan sekali di sini. Kalau map belum ada, MapService
-- sudah mengeluarkan SATU warn yang menyebut apa yang dicari dan apa yang
-- harus dilakukan user, dan seluruh gameplay di bawah tidak dijalankan.
-- Tidak ada warn kedua, dan tidak ada loop yang terus mencoba.
EnemyService.start()
EnemyService.setRunning(false)

local arena = MapService.getArena()
if arena == nil then
	-- Supaya HUD pemain tidak kosong tanpa penjelasan. MatchService tidak
	-- dijalankan: tanpa arena, menekan Ready akan memulai match yang musuhnya
	-- tidak akan pernah bisa muncul.
	Remotes.Events.MatchState:FireAllClients({
		state = "Lobby",
		wave = 0,
		timer = 0,
		coreHp = CoreService.getHp(),
		coreMaxHp = CoreService.getMaxHp(),
	})
	return
end

CoreService.bindVisual(arena.corePart)

-- Lobby dibaca di sini juga supaya warn-nya (kalau ada) keluar sekali saat
-- boot, bukan nanti di tengah match saat pemain pertama kembali ke lobby.
MapService.getLobby()

-- Gerbang `Attack`: state WaveActive dan pemain ada di participants
-- (bagian 3.6). Disuntik, bukan di-require, supaya CombatService tidak
-- bergantung ke MatchService dan tidak ada lingkaran require.
CombatService.setGate(MatchService.canAttack)
-- Pengali damage dan cooldown dari Toko Match (M3). Disuntik dengan alasan
-- yang sama dengan gerbangnya: CombatService tidak boleh bergantung ke
-- ShopService, dan ShopService sudah bergantung ke MatchService.
CombatService.setModifiers(ShopService.getModifiers)
CombatService.start()

-- Musuh berhenti bergerak di luar WaveActive, dan dibersihkan saat kembali ke
-- lobby. MatchService sendiri sudah memanggil clearAll() di transisinya; ini
-- yang mengurus gerak.
MatchService.onStateChanged:Connect(function(next: MatchService.State)
	EnemyService.setRunning(next == "WaveActive")
	if next == "Lobby" then
		CombatService.resetCooldowns()
	end
end)

MatchService.start()

-- Pengait boss disuntik ke WaveService, bukan di-require olehnya: WaveService
-- sudah di-require BossService secara tidak langsung lewat MatchService, dan
-- arah require yang satu arah itu yang menjaga tidak ada lingkaran.
WaveService.setBossHooks({
	spawnForWave = BossService.spawnForWave,
	isBossAlive = BossService.isBossAlive,
})
WaveService.start()
ShopService.start()
BossService.start()

-- Boss mati bisa berarti wave sudah bersih (kalau musuh biasanya sudah habis
-- lebih dulu). Diperiksa lewat jalur yang sama dengan musuh terakhir mati.
BossService.onBossDefeated:Connect(function()
	WaveService.checkClear()
end)

CoreService.onDestroyed:Connect(function()
	print(string.format("[%s] Core Server hancur", Config.GAME_NAME))
end)

-- Layar hasil. Reward permanen (koin, XP, material, first clear) dihitung
-- RewardService di M5; sampai itu ada, payload-nya dikirim dengan angka reward
-- NOL, bukan angka tebakan. Nol di sini jujur: di M2 memang belum ada reward
-- yang disimpan, dan menampilkan angka yang tidak pernah masuk ke data pemain
-- jauh lebih buruk daripada menampilkan nol.
MatchService.onMatchEnded:Connect(
	function(won: boolean, waveReached: number, _difficultyId: string, userIds: { number })
		local payload = {
			won = won,
			waveReached = waveReached,
			coins = 0,
			xp = 0,
			materials = {},
			unlocked = {},
		}
		for _, userId in userIds do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				Remotes.Events.MatchResult:FireClient(player, payload)
			end
		end
	end
)
