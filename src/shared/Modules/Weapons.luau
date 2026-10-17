--!strict
-- Weapons.luau — definisi senjata v1 (CONCEPT.md: 3 senjata, level 1 sampai 10).
--
-- Modul murni: tanpa game:GetService, tanpa `script`. Stat per level dan harga
-- upgrade dihitung Balance.luau dari angka dasar di sini.

local Types = require("./Types")

export type WeaponDef = Types.WeaponDef

local MAX_LEVEL = 10

local Weapons: { [string]: WeaponDef } = {
	weapon_starter = {
		id = "weapon_starter",
		name = "Patch Wrench",
		kind = "melee",
		baseDamage = 25,
		cooldown = 0.5,
		range = 12,
		projectiles = 1,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "default",
		},
	},
	weapon_ranged = {
		id = "weapon_ranged",
		name = "Packet Rifle",
		kind = "ranged",
		baseDamage = 14,
		cooldown = 0.25,
		range = 60,
		projectiles = 1,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "buy",
			coinCost = 1500,
		},
	},
	weapon_boss_a = {
		id = "weapon_boss_a",
		name = "Fork Bomb",
		kind = "ranged",
		baseDamage = 30,
		cooldown = 0.6,
		range = 45,
		projectiles = 3,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "craft",
			materials = { material_a = 5 },
		},
	},
}

return Weapons
