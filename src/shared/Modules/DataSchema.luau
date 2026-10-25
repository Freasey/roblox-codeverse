--!strict
-- DataSchema.luau — operasi atas tabel data player: salin dalam,
-- reconcile, dan migrasi skema.
--
-- Kenapa modul sendiri dan bukan di dalam PlayerDataService: service itu
-- memanggil game:GetService, jadi tidak bisa di-require Lune. Bug deep copy
-- yang diperbaiki di sini (docs/DEVELOPMENT_PLAN.md bagian 3.2) justru yang
-- paling perlu punya regression test, jadi logikanya ditaruh di modul murni.

local Types = require("./Types")

local DataSchema = {}

export type PlayerData = Types.PlayerData

-- Salin rekursif. `data[key] = default` biasa cuma menyalin referensi, jadi
-- semua player akan berbagi satu tabel milik modul Config — lihat 3.2 poin 1.
function DataSchema.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: { [any]: any } do
		copy[key] = DataSchema.deepCopy(item)
	end
	return copy :: any
end

-- Isi field yang belum ada di `data` dengan nilai dari `defaults`, tanpa
-- menimpa yang sudah ada. Turun ke tabel bersarang supaya field baru di dalam
-- `stats` ikut terisi untuk player yang `stats`-nya sudah ada.
--
-- `data` diubah di tempat dan juga dikembalikan.
function DataSchema.reconcile(
	data: { [string]: any },
	defaults: { [string]: any }
): { [string]: any }
	for key, default in defaults do
		local current = data[key]
		if current == nil then
			data[key] = DataSchema.deepCopy(default)
		elseif type(default) == "table" and type(current) == "table" then
			DataSchema.reconcile(current, default)
		end
	end
	return data
end

-- Alur upgrade untuk senjata yang belum pernah memilih. String, bukan nil --
-- alasan lengkapnya di `Types.WeaponSave`.
DataSchema.NO_PATH = "none"

-- Isi `path` untuk setiap senjata yang belum punya.
--
-- `reconcile` sendiri TIDAK cukup, dan itu mudah dilewatkan: dia mengisi field
-- yang hilang dari `Config.DEFAULT_DATA`, dan satu-satunya senjata di sana
-- `weapon_starter`. Jadi pemain yang pernah membeli Packet Rifle atau
-- meng-craft Fork Bomb sebelum alur upgrade ada punya `{ level = n }` tanpa
-- `path`, dan `reconcile` tidak punya default untuk kunci yang tidak dia kenal.
--
-- Akibatnya kalau dilewatkan bukan error, dan itu yang membuatnya berbahaya:
-- `save.path` nil berarti `Balance.weaponStats` tidak menemukan alur apa pun,
-- jadi senjata level 10 milik pemain lama berjalan seperti level 10 tanpa alur
-- -- lebih lemah daripada yang dia bayar, tanpa satu pesan pun.
function DataSchema.fillWeaponPaths(data: { [string]: any }): { [string]: any }
	local weapons = data.weapons
	if type(weapons) ~= "table" then
		return data
	end
	for _, save in weapons :: { [string]: any } do
		if type(save) == "table" and save.path == nil then
			save.path = DataSchema.NO_PATH
		end
	end
	return data
end

-- Satu pintu yang dipakai PlayerDataService: reconcile lalu migrasi.
--
-- Dipisah dari `reconcile` supaya `reconcile` tetap jadi fungsi umum yang tidak
-- tahu apa pun soal senjata, dan disatukan di sini supaya dua tempat yang
-- memuat data player tidak bisa menjalankan satu langkah tanpa yang lain.
-- Migrasi skema berikutnya menempel di sini juga.
function DataSchema.migrate(data: { [string]: any }, defaults: { [string]: any }): { [string]: any }
	return DataSchema.fillWeaponPaths(DataSchema.reconcile(data, defaults))
end

return DataSchema
