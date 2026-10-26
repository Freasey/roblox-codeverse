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
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)
local Waves = require(Shared.Modules.Waves)

local Services = script.Services
local ArenaBuilder = require(Services.ArenaBuilder)
local BossService = require(Services.BossService)
local CharacterService = require(Services.CharacterService)
local CombatService = require(Services.CombatService)
local MovementService = require(Services.MovementService)
local SceneryService = require(Services.SceneryService)
local WeaponService = require(Services.WeaponService)
local CoreService = require(Services.CoreService)
local EnemyService = require(Services.EnemyService)
local LeaderboardService = require(Services.LeaderboardService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local PlayerDataService = require(Services.PlayerDataService)
local ProgressionService = require(Services.ProgressionService)
local RewardService = require(Services.RewardService)
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

-- RewardService disambung SEBELUM PlayerDataService.start(). Urutannya
-- penting dan bukan gaya: keduanya mendengarkan Players.PlayerRemoving, dan
-- PlayerDataService menyimpan lalu MENGHAPUS cache data pemain di situ. Kalau
-- handler-nya jalan lebih dulu, RewardService tidak punya data lagi untuk
-- dibayar dan pemain yang keluar di tengah match kehilangan rewardnya —
-- tepat kasus yang diwajibkan bagian 3.3. Handler Roblox dijalankan dalam
-- urutan penyambungan, jadi inilah yang menjaminnya.
RewardService.start()

PlayerDataService.start()

-- Pemulihan avatar akun pemain. Dijalankan DI SINI, di atas gerbang arena,
-- dan itu disengaja: `StarterPlayer.LoadCharacterAppearance` harus sudah
-- `true` SEBELUM pemain pertama spawn, dan di Studio pemain spawn beberapa
-- saat setelah server mulai, bukan setelah map selesai dibangun. Kalau baris
-- ini dipasang di bawah gerbang, place yang gagal membangun arena akan
-- memunculkan pemain pertama tanpa baju dan rambutnya sendiri.
CharacterService.start()

-- Senjata yang terlihat di tangan. Dijalankan SETELAH PlayerDataService.start()
-- di atas, dan itu syarat: senjata yang dipasang dibaca dari data tersimpan
-- pemain, jadi tanpa data yang sudah dimuat setiap pemain akan selalu memegang
-- senjata awal sampai pemeriksaan berkala berikutnya.
WeaponService.start()

-- Rate limit dua remote yang wiring-nya ada di file ini, bukan di service
-- (bagian 3.6 mewajibkannya untuk SEMUA remote C -> S). Batasnya 2/detik
-- seperti remote non-`Attack` lainnya: dua-duanya dipicu interaksi UI, bukan
-- tombol tembak, jadi burst dua panggilan per detik sudah lebih longgar
-- daripada yang bisa dilakukan pemain sungguhan.
local limiter = RateLimit.newRegistry({
	GetProfile = 2,
	RequestAction = 2,
}, 2)

Players.PlayerRemoving:Connect(function(player)
	RateLimit.forget(limiter, player.UserId)
end)

-- Client minta snapshot datanya sendiri. Perhatikan: tidak ada parameter dari
-- client di sini — server menentukan data siapa yang dikembalikan, bukan client.
--
-- Kena throttle dibalas `nil`, bukan error dan bukan data basi: ini
-- RemoteFunction, jadi client menunggu nilai balik, dan `error()` di dalam
-- OnServerInvoke muncul sebagai error di client yang tidak bisa dia tangani
-- dengan rapi. `nil` aman karena `ProfileStore` di client sudah memperlakukan
-- balasan nil sebagai "data belum ada" dan tetap menunggu `DataLoaded` —
-- jalur yang sama dengan pemain yang datanya memang belum selesai dimuat.
Remotes.Functions.GetProfile.OnServerInvoke = function(player: Player)
	if not RateLimit.check(limiter, player.UserId, "GetProfile", os.clock()) then
		return nil
	end
	return PlayerDataService.waitFor(player)
end

-- Contoh aksi dari client. SELALU validasi di server: argumen dari client
-- bisa apa saja (angka negatif, tabel, nil, string 1MB).
Remotes.Events.RequestAction.OnServerEvent:Connect(function(player: Player, action: unknown)
	if not RateLimit.check(limiter, player.UserId, "RequestAction", os.clock()) then
		return
	end
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

-- Papan wave tertinggi (M6). Dijalankan DI SINI, sebelum gerbang arena di
-- bawah, dan itu bukan soal urutan yang rapi: start() inilah yang memasang
-- `OnServerInvoke` untuk `GetLeaderboard`, dan remote yang terdaftar tanpa
-- handler membuat client yang memanggilnya menggantung selamanya. Kalau
-- dipindah ke bawah, place tanpa arena akan membekukan lobby tiap kali papan
-- dibuka -- persis keadaan saat seseorang baru clone repo ini dan belum punya
-- assets/Arena.rbxmx.
LeaderboardService.start()

-- --------------------------------------------------------------------------
-- Dunia
-- --------------------------------------------------------------------------
--
-- Arena, lobby, dan latar dibangun DARI KODE di sini, dan urutannya mengikat:
-- keduanya harus selesai SEBELUM `MapService.getArena()` di bawah, karena
-- MapService membaca Workspace sekali lalu meng-cache hasilnya untuk seumur
-- server. Dibalik urutannya, MapService akan membaca arena lama, atau tidak
-- menemukan apa pun, dan seluruh gameplay di bawah tidak dijalankan.
--
-- Kalau salah satunya gagal, keduanya sudah mengeluarkan warn sendiri yang
-- menyebut penyebabnya, dan arena lama di place tetap utuh.
local sceneryOk, sceneryErr = SceneryService.validate()
if not sceneryOk then
	warn(string.format("[%s] latar tidak valid: %s", Config.GAME_NAME, tostring(sceneryErr)))
end
SceneryService.build()
ArenaBuilder.build()

-- Aturan gerak (Soal 4). Tidak bergantung pada arena, tapi ditaruh setelahnya
-- supaya pemain pertama yang masuk sudah punya lantai untuk dipijak sebelum
-- kecepatan jalannya disetel.
MovementService.start()

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
-- Level dan alur senjata yang berlaku di match ini. Upgrade senjata sekarang
-- dibeli dengan cash di dalam match dan dimulai ulang tiap match, jadi yang
-- memegang angkanya ShopService -- bukan data permanen pemain.
CombatService.setMatchWeaponSource(ShopService.getMatchWeapon)
-- Pengurangan damage yang masuk ke pemain (alur senjata "Bertahan", langkah 7
-- rancangan ulang arena). Arahnya sama dengan dua di atas tapi terbalik
-- pemiliknya: yang MEMBACA angkanya EnemyService, dan yang TAHU angkanya
-- CombatService -- karena dia yang memegang resolusi senjata per pemain. Jadi
-- EnemyService yang disuntik, bukan CombatService.
EnemyService.setPlayerDamageTakenMult(CombatService.getPlayerDamageTakenMult)
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
ProgressionService.start()

-- Boss mati bisa berarti wave sudah bersih (kalau musuh biasanya sudah habis
-- lebih dulu). Diperiksa lewat jalur yang sama dengan musuh terakhir mati.
BossService.onBossDefeated:Connect(function()
	WaveService.checkClear()
end)

CoreService.onDestroyed:Connect(function()
	print(string.format("[%s] Core Server hancur", Config.GAME_NAME))
end)
