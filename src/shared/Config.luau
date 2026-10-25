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
--
-- MAX_PLAYERS adalah angka yang DIASUMSIKAN rancangan (jumlah musuh per wave
-- dan hadiah koin dihitung per pemain, dan keduanya diuji sampai 4), tapi dia
-- TIDAK menegakkan apa pun: batas pemain sungguhan ada di Game Settings ->
-- Players -> Max Players di place-nya, dan itu setelan place yang tidak
-- dikelola Rojo maupun file ini. Jangan tambahkan kode yang mencoba menyetelnya
-- saat runtime -- yang perlu dilakukan sekali adalah menyetelnya di Studio
-- setelah publish pertama (docs/STATUS.md bagian 5.1).
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
		--
		-- KETIGA SENJATA TERBUKA SEJAK AWAL, SEMENTARA (permintaan Daffa,
		-- 2026-10-25). Upgrade TETAP bayar koin; yang dimatikan cuma pintu
		-- masuknya, bukan ekonominya.
		--
		-- Dilakukan di sini, bukan lewat `Config.DEV_ALL_WEAPONS`, dan bedanya
		-- bukan gaya: flag itu memberi senjata di MEMORI saja, jadi senjatanya
		-- bisa dipakai tapi `canUpgrade` -- yang membaca `data.weapons`
		-- langsung -- tetap menolaknya. Hasilnya senjata gratis yang tidak bisa
		-- di-upgrade sama sekali, yaitu separuh dari yang diminta. Lewat
		-- DEFAULT_DATA, `DataSchema.reconcile` menuliskannya ke data pemain,
		-- jadi senjatanya benar-benar dimiliki: bisa dipakai, bisa di-upgrade,
		-- dan ikut tersimpan.
		--
		-- Konsekuensi yang harus disadari sebelum ini dibalikkan: begitu data
		-- pernah tersimpan, ketiga senjata itu sudah ada di DataStore dan tidak
		-- ada cara membedakannya dari senjata yang dibeli. Menghapus dua baris
		-- di bawah TIDAK mengambilnya kembali; yang mengambilnya cuma menaikkan
		-- `Config.DATASTORE_NAME`. Hari ini biayanya nol karena place-nya belum
		-- pernah di-publish dan tidak ada yang tersimpan sama sekali.
		--
		-- `acquire` di `Weapons.luau` sengaja TIDAK disentuh: harga 1.500 dan
		-- resep craft-nya masih benar dan menunggu dinyalakan lagi. Yang
		-- terjadi sekarang cuma `canBuy`/`canCraft` tidak pernah tercapai
		-- karena senjatanya sudah dimiliki lebih dulu.
		weapon_starter = { level = 1, path = "none" },
		weapon_ranged = { level = 1, path = "none" },
		weapon_boss_a = { level = 1, path = "none" },
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
