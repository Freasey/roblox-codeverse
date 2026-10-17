--!strict
-- Waves.luau — komposisi tiap wave untuk v1 (10 wave, boss di wave 5 dan 10).
--
-- `share` adalah bobot, bukan jumlah: Balance.enemyCount menentukan total musuh
-- biasa di satu wave, lalu jumlah itu dibagi menurut share. Jadi menambah
-- player mengubah jumlahnya tanpa perlu mengubah tabel ini.
--
-- Modul murni: tanpa game:GetService, tanpa `script`. Require-nya relatif
-- (docs/DEVELOPMENT_PLAN.md bagian 1.5) supaya jalan di Roblox dan di Lune.

local Types = require("./Types")
local Enemies = require("./Enemies")
local Bosses = require("./Bosses")

export type WaveDef = Types.WaveDef

local Waves: { WaveDef } = {
	{ index = 1, entries = { { enemyId = "basic", share = 1 } } },
	{ index = 2, entries = { { enemyId = "basic", share = 3 }, { enemyId = "fast", share = 1 } } },
	{ index = 3, entries = { { enemyId = "basic", share = 2 }, { enemyId = "fast", share = 1 } } },
	{
		index = 4,
		entries = {
			{ enemyId = "basic", share = 2 },
			{ enemyId = "fast", share = 2 },
			{ enemyId = "tank", share = 1 },
		},
	},
	{
		index = 5,
		entries = { { enemyId = "basic", share = 1 } },
		bossId = "boss_splitter",
	},
	{
		index = 6,
		entries = {
			{ enemyId = "basic", share = 2 },
			{ enemyId = "fast", share = 2 },
			{ enemyId = "tank", share = 1 },
		},
	},
	{
		index = 7,
		entries = {
			{ enemyId = "basic", share = 1 },
			{ enemyId = "fast", share = 2 },
			{ enemyId = "tank", share = 1 },
		},
	},
	{
		index = 8,
		entries = {
			{ enemyId = "basic", share = 1 },
			{ enemyId = "fast", share = 2 },
			{ enemyId = "tank", share = 2 },
		},
	},
	{
		index = 9,
		entries = {
			{ enemyId = "basic", share = 1 },
			{ enemyId = "fast", share = 3 },
			{ enemyId = "tank", share = 2 },
		},
	},
	{
		index = 10,
		entries = { { enemyId = "fast", share = 1 }, { enemyId = "tank", share = 1 } },
		bossId = "boss_locker",
	},
}

local Module = {}

Module.list = Waves
Module.LAST_WAVE = #Waves

function Module.get(index: number): WaveDef?
	return Waves[index]
end

-- Cek bahwa tiap wave cuma memakai id musuh dan boss yang benar-benar ada.
-- Dipanggil unit test, dan juga sekali saat server boot supaya salah ketik id
-- ketahuan di playtest, bukan di tengah wave.
function Module.validate(): (boolean, string?)
	for position, wave in Waves do
		if wave.index ~= position then
			return false, string.format("wave di posisi %d punya index %d", position, wave.index)
		end
		if #wave.entries == 0 and wave.bossId == nil then
			return false, string.format("wave %d kosong", wave.index)
		end
		for _, entry in wave.entries do
			if Enemies[entry.enemyId] == nil then
				return false,
					string.format(
						"wave %d memakai musuh tak dikenal '%s'",
						wave.index,
						entry.enemyId
					)
			end
			if entry.share <= 0 then
				return false,
					string.format("wave %d: share %s harus > 0", wave.index, entry.enemyId)
			end
		end
		local bossId = wave.bossId
		if bossId ~= nil then
			local boss = Bosses[bossId]
			if boss == nil then
				return false,
					string.format("wave %d memakai boss tak dikenal '%s'", wave.index, bossId)
			end
			if boss.wave ~= wave.index then
				return false,
					string.format(
						"boss '%s' terdaftar di wave %d tapi Bosses bilang wave %d",
						bossId,
						wave.index,
						boss.wave
					)
			end
		end
	end
	return true, nil
end

return Module
