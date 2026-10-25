-- CombatEffects.spec.luau — efek alur upgrade yang punya umur.
--
-- Semuanya soal WAKTU dan PEMILIHAN, dan dua-duanya tidak bisa dilihat dari
-- playtest: slow yang hilang 0.3 detik lebih cepat dari yang dijanjikan, atau
-- splash yang men-damage target utamanya dua kali, akan terbaca sebagai "alur
-- itu terasa lebih kuat/lemah dari yang tertulis" -- keluhan balancing untuk
-- bug aritmetika. Jadi angkanya dipatok di sini.

local CombatEffects = require("../src/shared/Modules/CombatEffects")
local HitTest = require("../src/shared/Modules/HitTest")

local cases = {}

local function vec(x, z)
	return HitTest.vec(x, 0, z)
end

local function target(id, x, z)
	return { id = id, position = vec(x, z) }
end

-- Umur efek ---------------------------------------------------------------

table.insert(cases, {
	name = "efek aktif sebelum habis dan tidak aktif sesudahnya",
	run = function()
		local timed = { mult = 0.5, expiresAt = 10 }
		assert(CombatEffects.active(9.99, timed), "9.99 harus masih aktif")
		-- Tepat di batasnya sudah TIDAK aktif: `now < expiresAt`, bukan `<=`.
		-- Dengan `<=`, efek berdurasi nol (dari data alur yang rusak) akan
		-- aktif selama satu frame alih-alih tidak pernah.
		assert(not CombatEffects.active(10, timed), "tepat di batas harus habis")
		assert(not CombatEffects.active(11, timed), "sesudah batas harus habis")
		assert(not CombatEffects.active(0, nil), "nil harus tidak aktif")
	end,
})

table.insert(cases, {
	name = "durasi yang tidak wajar menghasilkan efek yang langsung habis",
	run = function()
		-- Bukan efek permanen: satu angka rusak di data alur yang menghasilkan
		-- musuh melambat selamanya jauh lebih sulit didiagnosis daripada efek
		-- yang tidak pernah terlihat.
		for _, bad in { 0, -1, 0 / 0, math.huge } do
			local expires = CombatEffects.expiresAt(100, bad)
			assert(expires == 100, "durasi " .. tostring(bad) .. " -> " .. tostring(expires))
			assert(
				not CombatEffects.active(100, { mult = 0.5, expiresAt = expires }),
				"harus langsung habis"
			)
		end
		assert(CombatEffects.expiresAt(100, nil) == 100, "nil harus langsung habis")
	end,
})

table.insert(cases, {
	name = "pengali efek yang habis jadi netral, bukan nilai terakhirnya",
	run = function()
		local timed = { mult = 0.5, expiresAt = 10 }
		assert(CombatEffects.multOf(5, timed) == 0.5, "masih aktif harus 0.5")
		assert(
			CombatEffects.multOf(20, timed) == CombatEffects.NEUTRAL_MULT,
			"sudah habis harus netral"
		)
		assert(CombatEffects.multOf(5, nil) == CombatEffects.NEUTRAL_MULT, "nil harus netral")
	end,
})

-- Penggabungan: yang terkuat menang --------------------------------------

table.insert(cases, {
	name = "slow yang lebih kuat menggantikan yang lebih lemah",
	run = function()
		local weak = { mult = 0.8, expiresAt = 10 }
		local merged = CombatEffects.merge(5, weak, 0.5, 2, true)
		assert(merged ~= nil and merged.mult == 0.5, "harus ambil 0.5")
		-- Umur yang lebih panjang dipertahankan: 10 dari yang lama, bukan 7
		-- dari yang baru.
		assert(merged ~= nil and merged.expiresAt == 10, "umur " .. tostring(merged.expiresAt))
	end,
})

table.insert(cases, {
	name = "slow yang lebih lemah TIDAK membatalkan yang kuat",
	run = function()
		-- Inilah yang dicegah: Ayunan Cepat memukul tiap 0.25 detik, jadi
		-- dengan "yang terbaru menang" satu pukulan lemah di antara dua
		-- pukulan kuat membuat musuh kadang melambat kadang tidak tanpa pola.
		local strong = { mult = 0.5, expiresAt = 10 }
		local merged = CombatEffects.merge(5, strong, 0.9, 5, true)
		assert(merged ~= nil and merged.mult == 0.5, "harus tetap 0.5")
		assert(merged ~= nil and merged.expiresAt == 10, "umurnya juga tidak boleh berubah")
	end,
})

table.insert(cases, {
	name = "efek yang sudah habis digantikan apa pun kekuatannya",
	run = function()
		local expired = { mult = 0.4, expiresAt = 10 }
		local merged = CombatEffects.merge(50, expired, 0.95, 2, true)
		assert(merged ~= nil and merged.mult == 0.95, "yang habis harus diganti")
		assert(merged ~= nil and merged.expiresAt == 52, "umur " .. tostring(merged.expiresAt))
	end,
})

table.insert(cases, {
	name = "tanda memakai arah sebaliknya: pengali lebih BESAR yang lebih kuat",
	run = function()
		local weak = { mult = 1.25, expiresAt = 10 }
		local merged = CombatEffects.merge(5, weak, 1.4, 4, false)
		assert(merged ~= nil and merged.mult == 1.4, "harus ambil 1.4")

		local strong = { mult = 1.4, expiresAt = 10 }
		local kept = CombatEffects.merge(5, strong, 1.25, 4, false)
		assert(kept ~= nil and kept.mult == 1.4, "yang lemah tidak boleh menurunkan tanda")
	end,
})

table.insert(cases, {
	name = "tanpa efek baru, yang lama dipertahankan apa adanya",
	run = function()
		local current = { mult = 0.5, expiresAt = 10 }
		assert(CombatEffects.merge(5, current, nil, 2, true) == current, "nil mult harus no-op")
		assert(CombatEffects.merge(5, current, 0, 2, true) == current, "nol harus no-op")
		assert(CombatEffects.merge(5, current, 0 / 0, 2, true) == current, "NaN harus no-op")
		assert(CombatEffects.merge(5, nil, nil, 2, true) == nil, "nil + nil tetap nil")
	end,
})

-- Zona --------------------------------------------------------------------

local function zone(x, z, radius, slowMult, dps, expiresAt)
	return {
		position = vec(x, z),
		radius = radius,
		slowMult = slowMult,
		dps = dps,
		expiresAt = expiresAt,
	}
end

table.insert(cases, {
	name = "zona memperlambat di dalam radiusnya dan tidak di luar",
	run = function()
		local zones = { zone(0, 0, 8, 0.6, 0, 10) }
		assert(CombatEffects.zoneSlowAt(5, vec(0, 0), zones) == 0.6, "di pusat harus 0.6")
		assert(CombatEffects.zoneSlowAt(5, vec(8, 0), zones) == 0.6, "tepat di tepi masih kena")
		assert(
			CombatEffects.zoneSlowAt(5, vec(8.1, 0), zones) == CombatEffects.NEUTRAL_MULT,
			"di luar harus netral"
		)
	end,
})

table.insert(cases, {
	name = "zona yang habis tidak memperlambat apa pun",
	run = function()
		local zones = { zone(0, 0, 8, 0.6, 0, 10) }
		assert(
			CombatEffects.zoneSlowAt(20, vec(0, 0), zones) == CombatEffects.NEUTRAL_MULT,
			"zona habis harus netral"
		)
	end,
})

table.insert(cases, {
	name = "zona bertumpuk memakai yang TERKUAT, bukan hasil kalinya",
	run = function()
		-- Tiga zona 0.45 yang dikalikan jadi 0.091: musuh yang praktis
		-- berhenti dari tiga tembakan biasa, dan itu bukan yang dijanjikan satu
		-- pun tingkat alur.
		local zones = {
			zone(0, 0, 8, 0.45, 0, 10),
			zone(1, 0, 8, 0.45, 0, 10),
			zone(-1, 0, 8, 0.6, 0, 10),
		}
		assert(CombatEffects.zoneSlowAt(5, vec(0, 0), zones) == 0.45, "harus 0.45")
	end,
})

table.insert(cases, {
	name = "damage zona dijumlahkan dan sebanding dengan deltaTime",
	run = function()
		-- Damage sengaja DIJUMLAHKAN, bukan diambil yang terkuat: dua jebakan
		-- yang bertumpuk memang dua jebakan, dan penjumlahan damage tidak
		-- menghasilkan keadaan ekstrem seperti musuh yang berhenti total.
		local zones = { zone(0, 0, 8, 1, 6, 10), zone(1, 0, 8, 1, 6, 10) }
		local tick = CombatEffects.zoneDamageAt(5, vec(0, 0), zones, 0.5)
		assert(math.abs(tick - 6) < 1e-9, "dua zona 6 dps x 0.5 detik = 6, dapat " .. tick)

		local setengah = CombatEffects.zoneDamageAt(5, vec(0, 0), zones, 0.25)
		assert(math.abs(setengah - 3) < 1e-9, "setengahnya harus 3, dapat " .. setengah)
	end,
})

table.insert(cases, {
	name = "zona tanpa dps tidak memberi damage",
	run = function()
		local zones = { zone(0, 0, 8, 0.6, 0, 10) }
		assert(CombatEffects.zoneDamageAt(5, vec(0, 0), zones, 1) == 0, "dps 0 harus 0 damage")
	end,
})

table.insert(cases, {
	name = "deltaTime yang tidak wajar tidak menghasilkan damage NaN",
	run = function()
		local zones = { zone(0, 0, 8, 1, 6, 10) }
		for _, bad in { 0, -1, 0 / 0, math.huge } do
			local tick = CombatEffects.zoneDamageAt(5, vec(0, 0), zones, bad)
			assert(tick == 0, "deltaTime " .. tostring(bad) .. " -> " .. tostring(tick))
		end
	end,
})

table.insert(cases, {
	name = "pruneZones membuang yang habis dan mengembalikan daftar baru",
	run = function()
		local zones = { zone(0, 0, 8, 0.6, 0, 10), zone(5, 5, 8, 0.6, 0, 30) }
		local alive = CombatEffects.pruneZones(20, zones)
		assert(#alive == 1, "harus sisa satu, dapat " .. #alive)
		assert(alive[1].expiresAt == 30, "yang bertahan harus yang umurnya 30")
		-- Daftar BARU: pemanggilnya mengiterasi daftar lama di dalam loop frame,
		-- dan menghapus elemen dari tabel yang sedang diiterasi melewatkan
		-- elemen tanpa error apa pun.
		assert(#zones == 2, "daftar asli tidak boleh diubah")
		assert(alive ~= zones, "harus tabel yang berbeda")
	end,
})

-- Pemilihan target --------------------------------------------------------

table.insert(cases, {
	name = "withinRadius mengecualikan target yang sudah kena",
	run = function()
		-- Inti fungsinya. Target utama berdiri DI titik kena dan sudah menerima
		-- damage penuh; tanpa pengecualian dia kena sekali lagi dikali
		-- splashMult, dan selisihnya terlihat seperti damage senjata yang lebih
		-- besar daripada yang tertulis di panel.
		local targets = { target(1, 0, 0), target(2, 3, 0), target(3, 20, 0) }
		local hit = CombatEffects.withinRadius(vec(0, 0), targets, 8, { [1] = true })
		assert(#hit == 1, "harus satu korban splash, dapat " .. #hit)
		assert(hit[1] == 2, "yang kena harus id 2, dapat " .. hit[1])
	end,
})

table.insert(cases, {
	name = "withinRadius tanpa exclude mengembalikan semua di radius",
	run = function()
		local targets = { target(1, 0, 0), target(2, 3, 0), target(3, 20, 0) }
		local hit = CombatEffects.withinRadius(vec(0, 0), targets, 8)
		assert(#hit == 2, "harus dua, dapat " .. #hit)
	end,
})

table.insert(cases, {
	name = "radius yang tidak wajar tidak mengenai siapa pun",
	run = function()
		-- math.huge di sini akan berarti "seluruh arena kena splash", yaitu
		-- satu tembakan yang menghabisi wave.
		local targets = { target(1, 0, 0), target(2, 300, 0) }
		for _, bad in { 0, -1, 0 / 0, math.huge } do
			local hit = CombatEffects.withinRadius(vec(0, 0), targets, bad)
			assert(#hit == 0, "radius " .. tostring(bad) .. " -> " .. #hit .. " kena")
		end
	end,
})

table.insert(cases, {
	name = "nearest mengembalikan sejumlah yang diminta, terdekat lebih dulu",
	run = function()
		local targets = { target(1, 0, 0), target(2, 10, 0), target(3, 3, 0), target(4, 5, 0) }
		local picked = CombatEffects.nearest(vec(0, 0), targets, 2, { [1] = true })
		assert(#picked == 2, "harus dua, dapat " .. #picked)
		assert(picked[1] == 3, "terdekat harus id 3, dapat " .. picked[1])
		assert(picked[2] == 4, "lalu id 4, dapat " .. picked[2])
	end,
})

table.insert(cases, {
	name = "nearest deterministik untuk jarak yang sama persis",
	run = function()
		-- Urutan iterasi tabel Luau tidak dijamin, jadi tanpa pemecah seri
		-- penularan tanda bisa mengenai musuh yang berbeda tiap tembakan di
		-- keadaan yang identik -- dan itu tidak bisa dites ulang.
		local targets = { target(9, 5, 0), target(2, -5, 0), target(7, 0, 5) }
		local picked = CombatEffects.nearest(vec(0, 0), targets, 2)
		assert(picked[1] == 2, "id terkecil dulu, dapat " .. picked[1])
		assert(picked[2] == 7, "lalu id 7, dapat " .. picked[2])
	end,
})

table.insert(cases, {
	name = "nearest tidak error kalau yang diminta lebih banyak dari yang ada",
	run = function()
		local targets = { target(1, 1, 0) }
		local picked = CombatEffects.nearest(vec(0, 0), targets, 5)
		assert(#picked == 1, "harus satu, dapat " .. #picked)

		for _, bad in { 0, -1, 0 / 0 } do
			assert(
				#CombatEffects.nearest(vec(0, 0), targets, bad) == 0,
				"count " .. tostring(bad) .. " harus kosong"
			)
		end
	end,
})

return cases
