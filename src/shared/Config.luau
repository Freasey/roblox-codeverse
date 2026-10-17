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
	weapons = { -- [weaponId] = { level = number }
		weapon_starter = { level = 1 },
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
