-- Smoke.spec.luau — verifikasi pola require (docs/DEVELOPMENT_PLAN.md 1.5).
--
-- Kalau test ini merah, seluruh asumsi "satu baris require jalan di Roblox dan
-- di Lune" gugur dan modul harus diubah ke pola terima-data-lewat-argumen.

local Config = require("../src/shared/Config")
local Waves = require("../src/shared/Modules/Waves")
local Enemies = require("../src/shared/Modules/Enemies")

local cases = {}

table.insert(cases, {
	name = "modul murni bisa di-require dari luar Roblox",
	run = function()
		assert(type(Enemies.basic) == "table", "Enemies.basic tidak ada")
	end,
})

table.insert(cases, {
	name = "require relatif ke sibling jalan (Waves -> Enemies, Bosses)",
	run = function()
		-- validate() membaca Enemies dan Bosses lewat require("./Nama").
		-- Kalau require relatif tidak jalan, modul ini gagal dimuat di atas.
		local ok, err = Waves.validate()
		assert(ok, tostring(err))
	end,
})

table.insert(cases, {
	name = "require relatif ke subfolder jalan (Config -> Modules/Types)",
	run = function()
		assert(Config.DEFAULT_DATA.equippedWeapon == "weapon_starter", "DEFAULT_DATA tidak termuat")
	end,
})

return cases
