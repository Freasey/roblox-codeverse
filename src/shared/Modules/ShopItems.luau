--!strict
-- ShopItems.luau — isi Toko Match. Dibeli pakai koin match, habis tiap match
-- selesai (CONCEPT.md: dua lapis progres).
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Types = require("./Types")

export type ShopItemDef = Types.ShopItemDef

local ShopItems: { [string]: ShopItemDef } = {
	shop_core_repair = {
		id = "shop_core_repair",
		name = "Hotfix",
		description = "Pulihkan 15% HP maksimum Core Server.",
		cost = 150,
		maxPurchases = 3,
	},
	shop_barrier = {
		id = "shop_barrier",
		name = "Firewall Block",
		description = "Pasang penghalang yang menahan musuh beberapa detik.",
		cost = 100,
		maxPurchases = 5,
	},
	shop_turret = {
		id = "shop_turret",
		name = "Scanner Turret",
		description = "Turret kecil yang menembak musuh terdekat sampai match selesai.",
		cost = 250,
		maxPurchases = 2,
	},
	shop_damage_up = {
		id = "shop_damage_up",
		name = "Exploit Patch",
		description = "Damage senjatamu +10% sampai match selesai.",
		cost = 200,
		maxPurchases = 5,
	},
	shop_fire_rate = {
		id = "shop_fire_rate",
		name = "Overclock",
		description = "Cooldown senjatamu -8% sampai match selesai.",
		cost = 200,
		maxPurchases = 5,
	},
}

return ShopItems
