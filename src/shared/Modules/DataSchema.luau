--!strict
-- DataSchema.luau — operasi atas tabel data player: salin dalam dan reconcile.
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

return DataSchema
