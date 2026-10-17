-- Waves.spec.luau — isi tabel wave harus konsisten dengan Enemies dan Bosses.
-- Salah ketik id musuh tidak bisa ketahuan dari type checker (tabelnya
-- bertipe { [string]: EnemyDef }), jadi harus dicek di sini.

local Config = require("../src/shared/Config")
local Waves = require("../src/shared/Modules/Waves")
local Enemies = require("../src/shared/Modules/Enemies")
local Bosses = require("../src/shared/Modules/Bosses")

local cases = {}

table.insert(cases, {
	name = "jumlah wave sesuai lingkup v1",
	run = function()
		assert(
			Waves.LAST_WAVE == Config.LAST_WAVE,
			string.format("ada %d wave, Config bilang %d", Waves.LAST_WAVE, Config.LAST_WAVE)
		)
	end,
})

table.insert(cases, {
	name = "setiap wave hanya memakai id musuh yang ada di Enemies",
	run = function()
		for _, wave in Waves.list do
			for _, entry in wave.entries do
				assert(
					Enemies[entry.enemyId] ~= nil,
					string.format("wave %d memakai musuh tak dikenal", wave.index)
				)
			end
		end
	end,
})

table.insert(cases, {
	name = "setiap bossId yang dipakai ada di Bosses dan wave-nya cocok",
	run = function()
		for _, wave in Waves.list do
			local bossId = wave.bossId
			if bossId then
				local boss = Bosses[bossId]
				assert(boss ~= nil, string.format("wave %d memakai boss tak dikenal", wave.index))
				assert(boss.wave == wave.index, string.format("boss di wave %d salah", wave.index))
			end
		end
	end,
})

table.insert(cases, {
	name = "setiap boss yang didefinisikan benar-benar dipakai sebuah wave",
	run = function()
		for id, boss in Bosses do
			local wave = Waves.get(boss.wave)
			assert(wave ~= nil, string.format("boss %s menunjuk wave yang tidak ada", id))
			assert(
				wave.bossId == id,
				string.format("wave %d tidak memanggil boss %s", boss.wave, id)
			)
		end
	end,
})

table.insert(cases, {
	name = "boss muncul tiap 5 wave",
	run = function()
		for _, wave in Waves.list do
			local shouldHaveBoss = wave.index % 5 == 0
			assert(
				(wave.bossId ~= nil) == shouldHaveBoss,
				string.format("wave %d: boss tidak sesuai aturan tiap-5-wave", wave.index)
			)
		end
	end,
})

table.insert(cases, {
	name = "validate() menerima data yang sekarang",
	run = function()
		local ok, err = Waves.validate()
		assert(ok, tostring(err))
	end,
})

return cases
