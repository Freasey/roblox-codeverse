--!strict
-- Difficulties.luau — tingkat kesulitan v1 (CONCEPT.md: normal, hard).
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Types = require("./Types")

export type DifficultyDef = Types.DifficultyDef

local Difficulties: { [string]: DifficultyDef } = {
	normal = {
		id = "normal",
		name = "Normal",
		hpMult = 1.0,
		rewardMult = 1.0,
		unlockedByDefault = true,
	},
	hard = {
		id = "hard",
		name = "Hard",
		hpMult = 1.8,
		rewardMult = 1.6,
		unlockedByDefault = false,
		unlockedBy = "normal",
	},
}

return Difficulties
