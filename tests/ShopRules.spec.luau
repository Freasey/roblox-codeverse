-- ShopRules.spec.luau — syarat pembelian Toko Match (bagian 3.6) dan efek
-- kumulatifnya.
--
-- Kriteria penerimaan M3 adalah "tidak bisa beli di luar jeda atau dengan koin
-- kurang, dicoba lewat remote manual". Daftar syarat seperti itu jauh lebih
-- murah diperiksa di sini daripada mengetik lima panggilan remote di command
-- bar Studio setiap kali ada yang diubah — dan yang di Studio tetap dilakukan,
-- lihat docs/TEST_CASES.md kelompok SHOP.

local Balance = require("../src/shared/Modules/Balance")
local ShopItems = require("../src/shared/Modules/ShopItems")
local ShopRules = require("../src/shared/Modules/ShopRules")

local cases = {}

local item = ShopItems.get("shop_core_repair")

local function context(overrides)
	local base = {
		state = "Intermission",
		locked = false,
		coins = 10000,
		purchases = {},
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

table.insert(cases, {
	name = "data ShopItems valid: order dan byId isinya sama",
	run = function()
		-- Item yang ditambahkan ke satu tabel tapi lupa di tabel lain akan
		-- hilang dari UI atau muncul sebagai tombol yang pasti ditolak server,
		-- dan dua-duanya tidak menghasilkan error apa pun.
		local ok, problem = ShopItems.validate()
		assert(ok, tostring(problem))
	end,
})

table.insert(cases, {
	name = "lima item yang diminta M3 ada semua",
	run = function()
		for _, id in
			{
				"shop_damage_up",
				"shop_fire_rate",
				"shop_core_repair",
				"shop_barrier",
				"shop_turret",
			}
		do
			assert(ShopItems.get(id) ~= nil, string.format("item '%s' tidak ada", id))
		end
	end,
})

table.insert(cases, {
	name = "boleh beli saat Intermission dengan koin cukup",
	run = function()
		local ok, reason = ShopRules.canBuy(item, context())
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "ditolak di luar Intermission",
	run = function()
		for _, state in { "Lobby", "Countdown", "WaveActive", "Ended" } do
			local ok, reason = ShopRules.canBuy(item, context({ state = state }))
			assert(not ok, string.format("state %s seharusnya ditolak", state))
			assert(reason ~= nil, "harus ada alasan")
		end
	end,
})

table.insert(cases, {
	name = "ditolak saat toko dikunci boss",
	run = function()
		local ok, reason = ShopRules.canBuy(item, context({ locked = true }))
		assert(not ok, "toko terkunci seharusnya menolak")
		assert(reason ~= nil and string.find(reason, "ikunci") ~= nil, "alasan harus soal kunci")
	end,
})

table.insert(cases, {
	name = "ditolak kalau koin kurang, walau cuma kurang satu",
	run = function()
		local ok = ShopRules.canBuy(item, context({ coins = item.cost - 1 }))
		assert(not ok, "koin kurang seharusnya ditolak")
		local okExact = ShopRules.canBuy(item, context({ coins = item.cost }))
		assert(okExact, "koin tepat sejumlah harga harus cukup")
	end,
})

table.insert(cases, {
	name = "koin nol dan negatif ditolak",
	run = function()
		assert(not ShopRules.canBuy(item, context({ coins = 0 })), "koin 0 harus ditolak")
		assert(not ShopRules.canBuy(item, context({ coins = -500 })), "koin negatif harus ditolak")
	end,
})

table.insert(cases, {
	name = "ditolak kalau item tidak ada",
	run = function()
		-- Client bisa mengirim itemId apa saja.
		local ok, reason = ShopRules.canBuy(nil, context())
		assert(not ok, "item nil seharusnya ditolak")
		assert(reason ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "ditolak kalau jatah pembelian habis",
	run = function()
		local used = { [item.id] = item.maxPurchases }
		local ok, reason = ShopRules.canBuy(item, context({ purchases = used }))
		assert(not ok, "jatah habis seharusnya ditolak")
		assert(reason ~= nil, "harus ada alasan")

		local almost = { [item.id] = item.maxPurchases - 1 }
		assert(
			ShopRules.canBuy(item, context({ purchases = almost })),
			"satu jatah terakhir harus masih boleh"
		)
	end,
})

table.insert(cases, {
	name = "jatah satu item tidak memengaruhi item lain",
	run = function()
		local other = ShopItems.get("shop_turret")
		local used = { shop_core_repair = 99 }
		assert(
			ShopRules.canBuy(other, context({ purchases = used })),
			"jatah item lain tidak boleh ikut habis"
		)
	end,
})

table.insert(cases, {
	name = "state diperiksa sebelum koin, supaya alasannya tidak menyesatkan",
	run = function()
		-- Kalau tokonya memang tutup, "koin kurang" adalah pesan yang salah
		-- dan akan membuat pemain mengumpulkan koin untuk masalah yang bukan
		-- masalahnya.
		local _, reason = ShopRules.canBuy(item, context({ state = "WaveActive", coins = 0 }))
		assert(
			reason ~= nil and string.find(reason, "jeda") ~= nil,
			string.format("alasan harus soal state, dapat '%s'", tostring(reason))
		)
	end,
})

table.insert(cases, {
	name = "kunci boss diperiksa sebelum state, kalau tidak pesannya tidak pernah terpakai",
	run = function()
		-- Locker cuma mengunci toko selama dia hidup, dan selama dia hidup
		-- state-nya selalu WaveActive: wave tidak bisa dinyatakan bersih
		-- sebelum boss mati, jadi tidak pernah ada Intermission sambil toko
		-- terkunci. Kalau state diperiksa lebih dulu, pesan "Toko dikunci"
		-- tidak akan pernah dilihat pemain dan dia dibilang "tunggu jeda" —
		-- padahal jeda itu baru datang setelah boss-nya mati.
		local ok, reason = ShopRules.canBuy(item, context({ state = "WaveActive", locked = true }))
		assert(not ok, "toko terkunci saat WaveActive seharusnya ditolak")
		assert(
			reason ~= nil and string.find(reason, "ikunci") ~= nil,
			string.format("alasan harus soal kunci boss, dapat '%s'", tostring(reason))
		)
	end,
})

table.insert(cases, {
	name = "kunci boss tetap menang atas koin kurang",
	run = function()
		-- Urutan di atas kunci tidak boleh membuat kunci kalah dari koin:
		-- pemain yang kebetulan koinnya kurang saat Locker hidup tetap harus
		-- diberi tahu sebab yang sebenarnya.
		local _, reason =
			ShopRules.canBuy(item, context({ state = "WaveActive", locked = true, coins = 0 }))
		assert(
			reason ~= nil and string.find(reason, "ikunci") ~= nil,
			string.format("alasan harus soal kunci boss, dapat '%s'", tostring(reason))
		)
	end,
})

table.insert(cases, {
	name = "sisa jatah dihitung benar, dan 0 berarti tak terbatas",
	run = function()
		assert(ShopRules.remaining(item, {}) == item.maxPurchases, "sisa awal harus maxPurchases")
		assert(
			ShopRules.remaining(item, { [item.id] = 1 }) == item.maxPurchases - 1,
			"sisa harus berkurang"
		)
		assert(ShopRules.remaining(item, { [item.id] = 999 }) == 0, "sisa tidak boleh negatif")

		local unlimited = { id = "x", name = "X", description = "", cost = 1, maxPurchases = 0 }
		assert(
			ShopRules.remaining(unlimited, { x = 50 }) == math.huge,
			"maxPurchases 0 berarti tak terbatas"
		)
	end,
})

table.insert(cases, {
	name = "tanpa pembelian, pengali tim netral",
	run = function()
		local mods = ShopRules.modifiers(
			{},
			Balance.SHOP_DAMAGE_STEP,
			Balance.SHOP_FIRE_RATE_STEP,
			Balance.SHOP_COOLDOWN_FLOOR
		)
		assert(mods.damageMult == 1, "damageMult awal harus 1")
		assert(mods.cooldownMult == 1, "cooldownMult awal harus 1")
	end,
})

table.insert(cases, {
	name = "pengali damage bertambah linear, bukan berlipat",
	run = function()
		-- Linear dengan sengaja: 5 x +10% jadi 1.5x, bukan 1.61x. Harga bisa
		-- tetap sementara efeknya tidak meledak.
		local five = ShopRules.modifiers(
			{ shop_damage_up = 5 },
			0.1,
			Balance.SHOP_FIRE_RATE_STEP,
			Balance.SHOP_COOLDOWN_FLOOR
		)
		assert(
			math.abs(five.damageMult - 1.5) < 1e-9,
			string.format("dapat %.4f, harus 1.5", five.damageMult)
		)
	end,
})

table.insert(cases, {
	name = "pengali cooldown turun dan naik monoton terhadap jumlah pembelian",
	run = function()
		local previous = math.huge
		for count = 0, 5 do
			local mods = ShopRules.modifiers(
				{ shop_fire_rate = count },
				Balance.SHOP_DAMAGE_STEP,
				Balance.SHOP_FIRE_RATE_STEP,
				Balance.SHOP_COOLDOWN_FLOOR
			)
			assert(mods.cooldownMult <= previous, "cooldownMult harus turun, bukan naik")
			previous = mods.cooldownMult
		end
	end,
})

table.insert(cases, {
	name = "cooldown punya lantai dan tidak pernah nol atau negatif",
	run = function()
		-- Tanpa lantai, step yang dinaikkan nanti bisa membuat cooldown hilang
		-- sama sekali dan senjata menembak setiap frame.
		local mods = ShopRules.modifiers({ shop_fire_rate = 100 }, 0.1, 0.08, 0.4)
		assert(mods.cooldownMult == 0.4, string.format("dapat %.4f, harus 0.4", mods.cooldownMult))
		assert(mods.cooldownMult > 0, "cooldownMult tidak boleh nol")
	end,
})

table.insert(cases, {
	name = "pembelian item lain tidak mengubah pengali tim",
	run = function()
		local mods = ShopRules.modifiers(
			{ shop_core_repair = 3, shop_turret = 2, shop_barrier = 5 },
			Balance.SHOP_DAMAGE_STEP,
			Balance.SHOP_FIRE_RATE_STEP,
			Balance.SHOP_COOLDOWN_FLOOR
		)
		assert(mods.damageMult == 1 and mods.cooldownMult == 1, "pengali harus tetap netral")
	end,
})

table.insert(cases, {
	name = "efek maksimum satu match masih dalam batas yang masuk akal",
	run = function()
		-- Pemeriksaan atas balancing, bukan atas kode: kalau tim bisa membeli
		-- seluruh jatah dan damage-nya jadi 3x sambil cooldown jadi 0.4,
		-- wave 10 akan terasa kosong dan angkanya perlu disetel ulang.
		local full: { [string]: number } = {}
		for id, def in ShopItems.byId do
			full[id] = def.maxPurchases
		end
		local mods = ShopRules.modifiers(
			full,
			Balance.SHOP_DAMAGE_STEP,
			Balance.SHOP_FIRE_RATE_STEP,
			Balance.SHOP_COOLDOWN_FLOOR
		)
		assert(
			mods.damageMult <= 2,
			string.format("damage maksimum %.2fx, terlalu besar", mods.damageMult)
		)
		assert(
			mods.cooldownMult >= 0.4,
			string.format("cooldown maksimum %.2fx, terlalu kecil", mods.cooldownMult)
		)
	end,
})

return cases
