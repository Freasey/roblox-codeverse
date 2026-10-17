-- RateLimit.spec.luau — token bucket per player per remote (bagian 3.6).
--
-- `now` dioper manual di semua test: itu sebabnya modulnya murni. Kalau
-- RateLimit memanggil os.clock() sendiri, test ini harus benar-benar menunggu
-- satu detik untuk memeriksa pengisian token.

local RateLimit = require("../src/shared/Modules/RateLimit")

local cases = {}

table.insert(cases, {
	name = "panggilan pertama selalu lolos",
	run = function()
		local bucket = RateLimit.new(5)
		assert(RateLimit.allow(bucket, 0), "panggilan pertama harus lolos")
	end,
})

table.insert(cases, {
	name = "burst sebesar kapasitas lolos, yang ke-(n+1) ditolak",
	run = function()
		local bucket = RateLimit.new(5)
		for index = 1, 5 do
			assert(RateLimit.allow(bucket, 0), string.format("panggilan %d harus lolos", index))
		end
		assert(not RateLimit.allow(bucket, 0), "panggilan ke-6 pada waktu yang sama harus ditolak")
	end,
})

table.insert(cases, {
	name = "token terisi lagi seiring waktu",
	run = function()
		local bucket = RateLimit.new(10)
		for _ = 1, 10 do
			RateLimit.allow(bucket, 0)
		end
		assert(not RateLimit.allow(bucket, 0), "bucket harus habis")
		-- 0.1 detik pada 10/detik = tepat satu token.
		assert(RateLimit.allow(bucket, 0.1), "setelah 0.1 detik harus ada satu token")
		assert(not RateLimit.allow(bucket, 0.1), "tapi cuma satu")
	end,
})

table.insert(cases, {
	name = "token tidak menumpuk melebihi kapasitas",
	run = function()
		local bucket = RateLimit.new(4)
		-- Diam sepuluh detik: tanpa cap, bucket akan punya 40 token dan satu
		-- burst bisa mengirim 40 panggilan sekaligus.
		local allowed = 0
		for _ = 1, 20 do
			if RateLimit.allow(bucket, 10) then
				allowed += 1
			end
		end
		assert(allowed == 4, string.format("harus 4 yang lolos, dapat %d", allowed))
	end,
})

table.insert(cases, {
	name = "rata-rata jangka panjang tidak melebihi batas",
	run = function()
		local rate = 20
		local bucket = RateLimit.new(rate)
		local allowed = 0
		-- Simulasi 2 detik, dicek 200 kali (100 Hz). Batas teoretisnya adalah
		-- kapasitas awal + rate * durasi = 20 + 40 = 60.
		for tick = 1, 200 do
			if RateLimit.allow(bucket, tick * 0.01) then
				allowed += 1
			end
		end
		assert(
			allowed <= rate + rate * 2,
			string.format("%d panggilan lolos, terlalu banyak", allowed)
		)
		assert(allowed >= rate * 2, string.format("cuma %d lolos, terlalu ketat", allowed))
	end,
})

table.insert(cases, {
	name = "waktu yang mundur tidak mengunci bucket selamanya",
	run = function()
		local bucket = RateLimit.new(2)
		RateLimit.allow(bucket, 100)
		RateLimit.allow(bucket, 100)
		assert(not RateLimit.allow(bucket, 100), "bucket harus habis")
		-- Jam mundur (tidak seharusnya terjadi, tapi kalau iya, bucket tidak
		-- boleh menolak selamanya karena updatedAt-nya di masa depan).
		RateLimit.allow(bucket, 0)
		assert(RateLimit.allow(bucket, 2), "setelah jam normal lagi, token harus terisi")
	end,
})

table.insert(cases, {
	name = "registry memisahkan bucket per player",
	run = function()
		local registry = RateLimit.newRegistry({ Attack = 2 }, 2)
		assert(RateLimit.check(registry, 1, "Attack", 0), "player 1 panggilan 1")
		assert(RateLimit.check(registry, 1, "Attack", 0), "player 1 panggilan 2")
		assert(not RateLimit.check(registry, 1, "Attack", 0), "player 1 harus kehabisan")
		-- Spam satu pemain tidak boleh ikut memblokir pemain lain.
		assert(RateLimit.check(registry, 2, "Attack", 0), "player 2 tidak boleh ikut terblokir")
	end,
})

table.insert(cases, {
	name = "registry memisahkan bucket per remote",
	run = function()
		local registry = RateLimit.newRegistry({ Attack = 20, BuyShopItem = 2 }, 2)
		assert(RateLimit.check(registry, 1, "BuyShopItem", 0))
		assert(RateLimit.check(registry, 1, "BuyShopItem", 0))
		assert(not RateLimit.check(registry, 1, "BuyShopItem", 0), "BuyShopItem harus habis")
		-- Attack punya batas sendiri yang jauh lebih longgar.
		assert(RateLimit.check(registry, 1, "Attack", 0), "Attack tidak boleh ikut terblokir")
	end,
})

table.insert(cases, {
	name = "remote tanpa batas eksplisit memakai defaultLimit",
	run = function()
		local registry = RateLimit.newRegistry({}, 1)
		assert(RateLimit.check(registry, 1, "Apapun", 0))
		assert(not RateLimit.check(registry, 1, "Apapun", 0), "default 1/detik harus berlaku")
	end,
})

table.insert(cases, {
	name = "forget membuang bucket player yang keluar",
	run = function()
		local registry = RateLimit.newRegistry({ Attack = 1 }, 1)
		RateLimit.check(registry, 7, "Attack", 0)
		assert(not RateLimit.check(registry, 7, "Attack", 0))
		RateLimit.forget(registry, 7)
		assert(registry.buckets[7] == nil, "bucket harus dibuang")
	end,
})

return cases
