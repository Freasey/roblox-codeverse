-- DataSchema.spec.luau — regression test untuk bug deep copy di reconcile
-- (docs/DEVELOPMENT_PLAN.md bagian 3.2 poin 1).
--
-- Sebelum diperbaiki, `data[key] = default` cuma menyalin referensi, jadi
-- semua player baru berbagi satu tabel `weapons` milik modul Config. Player A
-- upgrade senjata, player B dan C ikut ter-upgrade — dan ikut tersimpan ke
-- DataStore masing-masing, jadi rusaknya permanen.

local Config = require("../src/shared/Config")
local DataSchema = require("../src/shared/Modules/DataSchema")

local function freshData()
	return DataSchema.reconcile({}, Config.DEFAULT_DATA :: any)
end

local cases = {}

table.insert(cases, {
	name = "reconcile mengisi field yang belum ada",
	run = function()
		local data = DataSchema.reconcile({ coins = 500 }, Config.DEFAULT_DATA :: any)
		assert(data.level == 1, "level tidak terisi default")
		assert(data.equippedWeapon == "weapon_starter", "equippedWeapon tidak terisi default")
	end,
})

table.insert(cases, {
	name = "reconcile tidak menimpa nilai yang sudah ada",
	run = function()
		local data = DataSchema.reconcile({ coins = 500 }, Config.DEFAULT_DATA :: any)
		assert(data.coins == 500, "coins ketimpa default")
	end,
})

table.insert(cases, {
	name = "reconcile turun ke tabel bersarang",
	run = function()
		-- Save lama: stats sudah ada tapi belum punya field `wins`.
		local old = { stats = { highestWave = 7, matchesPlayed = 3 } }
		local data = DataSchema.reconcile(old, Config.DEFAULT_DATA :: any)
		assert(data.stats.wins == 0, "field baru di dalam stats tidak terisi")
		assert(data.stats.highestWave == 7, "field lama di dalam stats ketimpa")
	end,
})

table.insert(cases, {
	name = "dua hasil reconcile tidak berbagi tabel yang sama",
	run = function()
		local a = freshData()
		local b = freshData()

		assert(a.weapons ~= b.weapons, "dua player berbagi tabel weapons yang sama")
		assert(a.stats ~= b.stats, "dua player berbagi tabel stats yang sama")
		assert(a.materials ~= b.materials, "dua player berbagi tabel materials yang sama")
		assert(a.clears ~= b.clears, "dua player berbagi tabel clears yang sama")
		assert(
			a.unlockedDifficulties ~= b.unlockedDifficulties,
			"dua player berbagi tabel unlockedDifficulties yang sama"
		)
		assert(
			a.weapons.weapon_starter ~= b.weapons.weapon_starter,
			"salinannya cuma satu tingkat: tabel bersarang masih dibagi"
		)
	end,
})

table.insert(cases, {
	name = "mengubah data satu player tidak mengubah player lain atau DEFAULT_DATA",
	run = function()
		local a = freshData()
		local b = freshData()

		a.weapons.weapon_starter.level = 9
		a.materials.material_a = 4
		a.stats.wins = 3

		assert(b.weapons.weapon_starter.level == 1, "upgrade player A bocor ke player B")
		assert(b.materials.material_a == nil, "material player A bocor ke player B")
		assert(b.stats.wins == 0, "stats player A bocor ke player B")

		local defaults = Config.DEFAULT_DATA :: any
		assert(defaults.weapons.weapon_starter.level == 1, "DEFAULT_DATA ikut termutasi")
		assert(defaults.stats.wins == 0, "DEFAULT_DATA.stats ikut termutasi")
		assert(next(defaults.materials) == nil, "DEFAULT_DATA.materials ikut termutasi")
	end,
})

table.insert(cases, {
	name = "hasil reconcile tidak memakai tabel milik Config",
	run = function()
		local data = freshData()
		local defaults = Config.DEFAULT_DATA :: any
		assert(data.weapons ~= defaults.weapons, "weapons menunjuk langsung ke tabel Config")
		assert(data.stats ~= defaults.stats, "stats menunjuk langsung ke tabel Config")
	end,
})

return cases
