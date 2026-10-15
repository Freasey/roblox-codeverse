--!strict
-- Config.luau — konstanta yang dipakai server & client.
-- Aman dibaca client, jadi JANGAN taruh rahasia apapun di sini.

local Config = {}

Config.GAME_NAME = "CodeVerse"

-- DataStore
Config.DATASTORE_NAME = "PlayerData_v1" -- naikkan versi kalau skema berubah breaking
Config.AUTOSAVE_INTERVAL = 120 -- detik
Config.SAVE_RETRY_COUNT = 5

-- Skema data default untuk player baru.
-- Tambah field baru di sini; data lama otomatis diisi default (lihat reconcile).
Config.DEFAULT_DATA = {
	schemaVersion = 1,
	coins = 0,
	level = 1,
	xp = 0,
	playtimeSeconds = 0,
	lastLogin = 0,
}

export type PlayerData = typeof(Config.DEFAULT_DATA)

return Config
