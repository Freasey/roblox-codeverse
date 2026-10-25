--!strict
-- Config.luau — konstanta yang dipakai server & client.
-- Aman dibaca client, jadi JANGAN taruh rahasia apapun di sini.

local Types = require("./Modules/Types")

local Config = {}

Config.GAME_NAME = "CodeVerse"

-- DataStore
Config.DATASTORE_NAME = "PlayerData_v1" -- naikkan versi kalau skema berubah breaking
Config.AUTOSAVE_INTERVAL = 120 -- detik
Config.SAVE_RETRY_COUNT = 5

-- Match
Config.MAX_PLAYERS = 4
Config.LAST_WAVE = 10

-- Flag dev: semua senjata dianggap dimiliki, level 1 untuk yang belum dibeli.
--
-- Gunanya mencoba tiga senjata (dan nanti sembilan alur upgrade) tanpa lebih
-- dulu mengumpulkan 1.500 koin dan lima material drop boss. Harus `false` di
-- repo; ini knob yang disetel sementara di mesin sendiri, bukan setelan game.
--
-- Hidup di MEMORI saja, dan itu syarat, bukan selera. Jalan pintas yang
-- menggoda adalah menulis ketiga senjata ke `data.weapons` lewat
-- `PlayerDataService.update`, tapi itu masuk DataStore -- dan sesudahnya tidak
-- ada satu pun cara membedakan senjata hasil flag dev dari senjata yang
-- benar-benar dibeli pemain. Akun yang dipakai mencoba jadi akun yang
-- progresnya rusak permanen, dan rusaknya tidak kelihatan sampai flag-nya
-- dimatikan.
--
-- Dibaca lewat satu pintu: `ProgressionRules.ownedWeapons`. Flag ini TIDAK
-- di-require modul murni mana pun; nilainya dikirim sebagai argumen, sama
-- seperti `priceGrowth` di `ShopRules`, supaya test bisa menguji kedua
-- keadaannya tanpa menyentuh konstanta global.
Config.DEV_ALL_WEAPONS = false

-- Skema data default untuk player baru.
-- Tambah field baru di sini; data lama otomatis diisi default (lihat reconcile
-- di Modules/DataSchema.luau). Tidak perlu naik DATASTORE_NAME selama yang
-- ditambah cuma field baru.
--
-- Tipenya dianotasi manual, BUKAN `typeof(Config.DEFAULT_DATA)`: inferensi
-- bikin `weapons` cuma punya key `weapon_starter` dan `materials` jadi tabel
-- kosong tanpa tipe, dua-duanya error di mode strict. Lihat bagian 3.1.
Config.DEFAULT_DATA = {
	schemaVersion = 1,
	coins = 0, -- koin permanen
	level = 1,
	xp = 0,
	playtimeSeconds = 0,
	lastLogin = 0,

	equippedWeapon = "weapon_starter",
	weapons = { -- [weaponId] = { level = number, path = string }
		-- `path = "none"` eksplisit, bukan dibiarkan kosong: nil tidak bertahan
		-- di JSON DataStore. Lihat `Types.WeaponSave`.
		weapon_starter = { level = 1, path = "none" },
	},
	materials = {}, -- [materialId] = jumlah
	unlockedDifficulties = { normal = true },
	clears = {}, -- [difficultyId] = true
	stats = {
		highestWave = 0,
		matchesPlayed = 0,
		wins = 0,
	},
} :: Types.PlayerData

-- Alias supaya kode lama yang memakai `Config.PlayerData` tetap jalan.
export type PlayerData = Types.PlayerData

return Config
