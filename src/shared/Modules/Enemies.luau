--!strict
-- Enemies.luau — definisi musuh v1 (CONCEPT.md: basic, fast, tank).
--
-- Modul murni: tanpa game:GetService, tanpa `script`, supaya bisa dites Lune.
-- Angka di sini adalah nilai dasar pada wave 1, difficulty normal, 1 player.
-- Penskalaannya ada di Balance.luau, bukan di sini.

local Types = require("./Types")

export type EnemyDef = Types.EnemyDef

local Enemies: { [string]: EnemyDef } = {
	basic = {
		id = "basic",
		name = "Pop-up Swarmling",
		analogy = "Adware",
		baseHp = 100,
		speed = 8,
		coreDamage = 5,
		matchCoins = 5,
	},
	fast = {
		id = "fast",
		name = "Worm Runner",
		analogy = "Worm",
		baseHp = 60,
		speed = 16,
		coreDamage = 4,
		matchCoins = 7,
	},
	tank = {
		id = "tank",
		name = "Rootkit Hulk",
		analogy = "Rootkit",
		baseHp = 400,
		speed = 5,
		coreDamage = 15,
		matchCoins = 15,
	},
}

return Enemies
