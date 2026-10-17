--!strict
-- ShopItems.luau — isi Toko Match. Dibeli pakai koin match, habis tiap match
-- selesai (CONCEPT.md: dua lapis progres).
--
-- Lima item yang diminta M3: upgrade damage tim, upgrade attack speed, repair
-- core, penghalang, dan turret kecil.
--
-- Semua efek di sini berlaku untuk SELURUH TIM, bukan untuk pembelinya saja.
-- Alasannya dua. Pertama, M3 memang menyebut "upgrade damage tim". Kedua, koin
-- match adalah satu kolam milik tim (bagian 3.7: koin musuh yang mati masuk ke
-- tim), jadi efek per-pembeli akan membuat pemain pertama yang menekan tombol
-- memakai uang bersama untuk keuntungan pribadi.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Types = require("./Types")

export type ShopItemDef = Types.ShopItemDef

local ShopItems: { [string]: ShopItemDef } = {
	shop_damage_up = {
		id = "shop_damage_up",
		name = "Exploit Patch",
		description = "Damage senjata SEMUA pemain +10% sampai match selesai.",
		cost = 200,
		maxPurchases = 5,
	},
	shop_fire_rate = {
		id = "shop_fire_rate",
		name = "Overclock",
		description = "Cooldown senjata SEMUA pemain -8% sampai match selesai.",
		cost = 200,
		maxPurchases = 5,
	},
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
		description = "Tahan musuh di semua lane selama beberapa detik di wave berikutnya.",
		cost = 100,
		maxPurchases = 5,
	},
	shop_turret = {
		id = "shop_turret",
		name = "Scanner Turret",
		description = "Turret yang menembak musuh terdekat sampai match selesai.",
		cost = 250,
		maxPurchases = 2,
	},
}

-- Urutan tampil di UI. Dipisah dari tabel definisi karena urutan iterasi tabel
-- Luau tidak dijamin, jadi tanpa daftar ini susunan tombol toko bisa berbeda
-- tiap kali client dibuka.
local ORDER = {
	"shop_damage_up",
	"shop_fire_rate",
	"shop_core_repair",
	"shop_barrier",
	"shop_turret",
}

local Module = {}

Module.byId = ShopItems
Module.order = ORDER

function Module.get(id: string): ShopItemDef?
	return ShopItems[id]
end

-- Cek bahwa `order` dan `byId` isinya sama. Dipanggil unit test dan sekali saat
-- server boot: item yang ditambahkan ke satu tabel tapi lupa di tabel lain
-- akan hilang dari UI (atau muncul sebagai tombol yang pasti ditolak server),
-- dan dua-duanya tidak menghasilkan error apa pun.
function Module.validate(): (boolean, string?)
	local seen: { [string]: boolean } = {}
	for _, id in ORDER do
		if ShopItems[id] == nil then
			return false, string.format("order memuat '%s' yang tidak ada di byId", id)
		end
		if seen[id] then
			return false, string.format("order memuat '%s' dua kali", id)
		end
		seen[id] = true
	end
	for id, def in ShopItems do
		if not seen[id] then
			return false, string.format("item '%s' tidak ada di order, jadi tidak akan tampil", id)
		end
		if def.id ~= id then
			return false, string.format("item di key '%s' punya id '%s'", id, def.id)
		end
		if def.cost <= 0 then
			return false, string.format("item '%s' harganya %d", id, def.cost)
		end
		if def.maxPurchases < 0 then
			return false, string.format("item '%s' maxPurchases negatif", id)
		end
	end
	return true, nil
end

return Module
