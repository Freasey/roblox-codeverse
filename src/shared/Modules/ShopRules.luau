--!strict
-- ShopRules.luau — aturan boleh-tidaknya membeli, dan efek kumulatif
-- pembelian.
--
-- Kenapa dipisah dari ShopService: pemeriksaannya adalah daftar syarat yang
-- harus ditolak server (bagian 3.6: state `Intermission`, toko tidak terkunci,
-- koin match cukup — plus batas pembelian per item), dan kriteria penerimaan M3
-- adalah "tidak bisa beli di luar jeda atau dengan koin kurang, dicoba lewat
-- remote manual". Daftar syarat seperti itu paling murah diperiksa dengan unit
-- test, bukan dengan mengetik lima panggilan remote di command bar Studio
-- setiap kali ada yang diubah.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Types = require("./Types")

local ShopRules = {}

export type Context = {
	-- Nama state match sekarang. String, bukan tipe State milik MatchService:
	-- modul ini harus tetap bisa di-require Lune, dan MatchService tidak bisa.
	state: string,
	-- Toko dikunci mekanik boss Locker (M4), terpisah dari "toko tutup karena
	-- bukan Intermission".
	locked: boolean,
	coins: number,
	purchases: { [string]: number },
	-- Pengali harga per pembelian item yang sama (Balance.SHOP_PRICE_GROWTH).
	-- Diminta lewat context, bukan dibaca dari Balance di dalam modul ini,
	-- supaya test bisa menguji kurva harga tanpa menyetel konstanta global --
	-- pola yang sama dengan `damageStep` di `modifiers` di bawah.
	priceGrowth: number,
}

ShopRules.OPEN_STATE = "Intermission"

-- Harga satu item sesudah `used` pembelian sebelumnya: `cost * growth^used`,
-- dibulatkan ke bawah.
--
-- Ini yang menggantikan `maxPurchases` sebagai pembatas untuk item tak
-- terbatas. Dengan growth 1.25 dan harga dasar 200, sepuluh tumpuk memakan
-- 6.647 koin alih-alih 2.000 -- jadi kelebihan koin terkoreksi lewat harga,
-- bukan lewat tembok yang membuat sisa koin tidak ada gunanya.
--
-- `growth` di bawah 1 akan membuat barang makin MURAH tiap dibeli, dan nol atau
-- NaN membuatnya gratis. Dua-duanya diperlakukan sebagai harga tetap: pengali
-- yang rusak tidak boleh menghasilkan toko yang bisa diborong tanpa biaya.
function ShopRules.priceFor(
	def: Types.ShopItemDef,
	purchases: { [string]: number },
	growth: number
): number
	local used = purchases[def.id] or 0
	if type(growth) ~= "number" or growth ~= growth or growth < 1 or growth == math.huge then
		return def.cost
	end
	if used <= 0 then
		return def.cost
	end
	return math.floor(def.cost * growth ^ used)
end

-- Mengembalikan (boleh, alasan kalau tidak boleh). Alasannya dikirim ke client
-- lewat `ActionResult` supaya pemain tahu kenapa tombolnya tidak bekerja —
-- tanpa itu penolakan server terlihat sama seperti tombol yang rusak.
--
-- Urutan pemeriksaannya penting untuk pesan yang masuk akal: kunci boss dulu,
-- lalu state, lalu keberadaan item, lalu jatah, baru koin.
--
-- Kunci boss sebelum state, bukan sesudahnya: Locker (boss wave 10) cuma
-- mengunci toko selama dia hidup, dan selama dia hidup state-nya selalu
-- `WaveActive` — wave tidak bisa dinyatakan bersih sebelum boss mati, jadi
-- tidak pernah ada Intermission sambil toko terkunci. Kalau state diperiksa
-- lebih dulu, cabang `locked` di bawahnya tidak pernah tercapai dan pemain
-- yang kena mekanik boss justru dibilang "tunggu jeda" — padahal jeda itu
-- baru datang setelah boss-nya mati.
--
-- Di bawah kunci, state tetap sebelum koin: kalau tokonya memang tutup,
-- "koin kurang" menyesatkan dan membuat pemain mengumpulkan koin untuk
-- masalah yang bukan masalahnya.
function ShopRules.canBuy(def: Types.ShopItemDef?, context: Context): (boolean, string?)
	if context.locked then
		return false, "Toko dikunci. Kalahkan boss-nya dulu."
	end
	if context.state ~= ShopRules.OPEN_STATE then
		return false, "Toko cuma buka saat jeda antar wave."
	end
	if def == nil then
		return false, "Item itu tidak ada."
	end

	local used = context.purchases[def.id] or 0
	if def.maxPurchases > 0 and used >= def.maxPurchases then
		return false, string.format("Jatah %s sudah habis (%d).", def.name, def.maxPurchases)
	end

	-- Harga yang dipakai harga SEKARANG, bukan `def.cost`. Item tak terbatas
	-- dibatasi oleh harga yang naik, jadi membandingkan koin dengan harga dasar
	-- akan meloloskan pembelian yang tidak bisa dibayar -- dan ShopService
	-- memotong koin sebesar harga sekarang, jadi saldonya bisa jadi negatif.
	local price = ShopRules.priceFor(def, context.purchases, context.priceGrowth)
	if context.coins < price then
		return false,
			string.format("Koin tim kurang: butuh %d, ada %d.", price, math.floor(context.coins))
	end

	return true, nil
end

-- Sisa jatah pembelian satu item. `maxPurchases == 0` berarti tak terbatas
-- (lihat Types.ShopItemDef), dan itu dilaporkan sebagai math.huge supaya
-- pemanggil tidak perlu mengulang pengecekan nol-berarti-tak-terbatas.
function ShopRules.remaining(def: Types.ShopItemDef, purchases: { [string]: number }): number
	if def.maxPurchases <= 0 then
		return math.huge
	end
	return math.max(0, def.maxPurchases - (purchases[def.id] or 0))
end

export type Modifiers = {
	damageMult: number,
	cooldownMult: number,
}

-- Efek kumulatif dari seluruh pembelian tim pada match ini.
--
-- Penambahan, bukan perkalian: 5 x damage +10% jadi 1.5x, bukan 1.61x. Dipilih
-- yang linear supaya harganya bisa tetap sementara efeknya tidak meledak, dan
-- supaya pemain bisa menghitung sendiri apa yang dia dapat.
--
-- `cooldownMult` punya lantai: lima kali -8% secara linear jadi 0.6, dan kalau
-- stepnya nanti dinaikkan tanpa lantai, angkanya bisa menyentuh nol dan
-- cooldown senjata hilang sama sekali.
function ShopRules.modifiers(
	purchases: { [string]: number },
	damageStep: number,
	cooldownStep: number,
	cooldownFloor: number
): Modifiers
	local damageCount = purchases.shop_damage_up or 0
	local fireRateCount = purchases.shop_fire_rate or 0

	return {
		damageMult = 1 + damageStep * damageCount,
		cooldownMult = math.max(cooldownFloor, 1 - cooldownStep * fireRateCount),
	}
end

return ShopRules
