-- HitTest.spec.luau — toleransi uji kena (docs/DEVELOPMENT_PLAN.md bagian 3.7).
--
-- Yang dites di sini bukan nilai toleransinya (itu akan disetel setelah
-- playtest), tapi sifat yang harus tetap benar: musuh di depan dan dalam
-- jangkauan kena, musuh di belakang tidak, dan toleransi yang lebih besar tidak
-- pernah mengubah "kena" jadi "tidak kena". Sifat terakhir itu yang menjaga
-- mitigasi lag tetap bermakna — kalau menaikkan toleransi bisa membuat serangan
-- hilang, seluruh pendekatan di 3.7 tidak berlaku.

local Balance = require("../src/shared/Modules/Balance")
local HitTest = require("../src/shared/Modules/HitTest")
local Weapons = require("../src/shared/Modules/Weapons")

local cases = {}

local origin = HitTest.vec(0, 0, 0)
local forward = HitTest.vec(0, 0, -1)

table.insert(cases, {
	name = "musuh tepat di depan dan dalam jangkauan: kena",
	run = function()
		assert(HitTest.inCone(origin, forward, HitTest.vec(0, 0, -8), 12, 0.2), "harus kena")
	end,
})

table.insert(cases, {
	name = "musuh di luar jangkauan: tidak kena",
	run = function()
		assert(
			not HitTest.inCone(origin, forward, HitTest.vec(0, 0, -30), 12, 0.2),
			"di luar jangkauan harus tidak kena"
		)
	end,
})

table.insert(cases, {
	name = "musuh di belakang: tidak kena",
	run = function()
		assert(
			not HitTest.inCone(origin, forward, HitTest.vec(0, 0, 8), 12, 0.2),
			"di belakang harus tidak kena"
		)
	end,
})

table.insert(cases, {
	name = "musuh yang menempel selalu kena, apa pun arah bidiknya",
	run = function()
		-- Kalau musuh menempel di pemain, arah tidak bermakna lagi: vektor
		-- pemain->musuh mendekati nol dan sudutnya jadi acak. Harus kena,
		-- bukan dinormalisasi jadi NaN lalu ditolak.
		assert(
			HitTest.inCone(origin, forward, HitTest.vec(0, 0, 0), 12, 0.9),
			"musuh yang menempel harus kena"
		)
	end,
})

table.insert(cases, {
	name = "ketinggian tidak membuat musuh di luar jangkauan",
	run = function()
		-- Pusat model musuh bisa 3 stud di atas atau di bawah pusat karakter.
		-- Jangkauan diukur datar supaya itu tidak mengurangi jangkauan efektif.
		assert(
			HitTest.inCone(origin, forward, HitTest.vec(0, 6, -11), 12, 0.2),
			"selisih ketinggian tidak boleh membatalkan kena"
		)
	end,
})

table.insert(cases, {
	name = "jangkauan yang lebih besar tidak pernah membatalkan kena",
	run = function()
		-- Sifat monoton. Ini yang membuat MELEE_RADIUS_BONUS aman dinaikkan
		-- kalau playtest dengan ping tinggi masih terasa tidak kena.
		local target = HitTest.vec(3, 0, -7)
		local baseRange = 10
		local hitAtBase = HitTest.inCone(origin, forward, target, baseRange, 0.2)
		for bonus = 0, 10 do
			local hit = HitTest.inCone(origin, forward, target, baseRange + bonus, 0.2)
			if hitAtBase then
				assert(hit, string.format("bonus %d membatalkan kena", bonus))
			end
		end
	end,
})

table.insert(cases, {
	name = "kerucut yang lebih lebar tidak pernah membatalkan kena",
	run = function()
		local target = HitTest.vec(5, 0, -5)
		local hitAtTight = HitTest.inCone(origin, forward, target, 12, 0.8)
		if hitAtTight then
			for _, minCos in { 0.8, 0.5, 0.2, 0.0, -0.5 } do
				assert(
					HitTest.inCone(origin, forward, target, 12, minCos),
					string.format("minCos %.1f membatalkan kena", minCos)
				)
			end
		end
	end,
})

table.insert(cases, {
	name = "silinder bidik: musuh di garis bidik kena",
	run = function()
		assert(
			HitTest.inAimCylinder(origin, forward, HitTest.vec(0, 0, -40), 60, 5),
			"musuh tepat di garis bidik harus kena"
		)
	end,
})

table.insert(cases, {
	name = "silinder bidik: musuh sedikit melenceng tetap kena",
	run = function()
		-- Inti mitigasi 3.7: garis setebal nol akan bilang tidak kena di sini,
		-- padahal selisih 3 stud itu persis besarnya ketinggalan posisi musuh
		-- `fast` pada ping ~200 ms.
		assert(
			HitTest.inAimCylinder(origin, forward, HitTest.vec(3, 0, -40), 60, 5),
			"melenceng 3 stud masih harus kena"
		)
	end,
})

table.insert(cases, {
	name = "silinder bidik: musuh terlalu melenceng tidak kena",
	run = function()
		assert(
			not HitTest.inAimCylinder(origin, forward, HitTest.vec(12, 0, -40), 60, 5),
			"melenceng 12 stud tidak boleh kena"
		)
	end,
})

table.insert(cases, {
	name = "silinder bidik: musuh di belakang pemain tidak kena",
	run = function()
		-- Proyeksi di-clamp ke [0, range], jadi musuh di belakang diukur dari
		-- pemain, bukan dari garis tak hingga yang memanjang ke dua arah.
		assert(
			not HitTest.inAimCylinder(origin, forward, HitTest.vec(0, 0, 40), 60, 5),
			"di belakang tidak boleh kena"
		)
	end,
})

table.insert(cases, {
	name = "silinder bidik: musuh lebih jauh dari range tidak kena",
	run = function()
		assert(
			not HitTest.inAimCylinder(origin, forward, HitTest.vec(0, 0, -90), 60, 5),
			"di luar range tidak boleh kena"
		)
	end,
})

table.insert(cases, {
	name = "jarak sepanjang garis bidik dipakai untuk mengurutkan target",
	run = function()
		local _, nearAlong =
			HitTest.distanceToAimSegment(origin, forward, HitTest.vec(0, 0, -10), 60)
		local _, farAlong =
			HitTest.distanceToAimSegment(origin, forward, HitTest.vec(0, 0, -30), 60)
		assert(
			nearAlong < farAlong,
			"musuh yang lebih dulu dilewati harus punya `along` lebih kecil"
		)
	end,
})

table.insert(cases, {
	name = "arah bidik nol tidak menghasilkan NaN",
	run = function()
		local lateral =
			HitTest.distanceToAimSegment(origin, HitTest.vec(0, 0, 0), HitTest.vec(0, 0, -5), 60)
		assert(lateral == lateral, "hasilnya NaN")
		assert(lateral == math.huge, "arah nol harus jadi 'tidak kena', bukan kena")
	end,
})

table.insert(cases, {
	name = "normalize menolak vektor nol, bukan mengembalikan NaN",
	run = function()
		assert(HitTest.normalize(HitTest.vec(0, 0, 0)) == nil, "vektor nol harus nil")
		local unit = HitTest.normalize(HitTest.vec(0, 0, -4))
		assert(unit ~= nil, "vektor normal harus bisa dinormalisasi")
		assert(math.abs(HitTest.length(unit) - 1) < 1e-6, "panjangnya harus 1")
	end,
})

table.insert(cases, {
	name = "konstanta toleransi di Balance masuk akal untuk senjata yang ada",
	run = function()
		assert(Balance.MELEE_RADIUS_BONUS > 0, "toleransi melee harus positif (bagian 3.7)")
		assert(Balance.RANGED_RADIUS > 0, "radius silinder harus positif (bagian 3.7)")
		assert(
			Balance.MELEE_MIN_COS < 1,
			"minCos 1 berarti harus tepat lurus — itu raycast ketat yang dilarang 3.7"
		)
		-- Senjata melee harus punya jangkauan efektif yang lebih besar dari
		-- model musuh terbesar (tank 6 stud), kalau tidak pemain harus berdiri
		-- di dalam musuh untuk bisa menyerangnya.
		local reach = Weapons.weapon_starter.range + Balance.MELEE_RADIUS_BONUS
		assert(reach > 6, "jangkauan melee efektif terlalu pendek")
	end,
})

table.insert(cases, {
	name = "ketiga senjata v1 cocok dengan dua jalur uji kena di CombatService",
	run = function()
		-- CombatService cuma punya dua cabang: `kind == "melee"` pakai kerucut,
		-- sisanya pakai silinder bidik. Senjata dengan `kind` di luar dua nilai
		-- itu akan diam-diam masuk cabang ranged, dan `projectiles` nol akan
		-- membuat serangan tidak pernah mengenai apa pun — dua-duanya tanpa
		-- error.
		local melee, ranged = 0, 0
		for id, def in Weapons do
			assert(
				def.kind == "melee" or def.kind == "ranged",
				string.format("senjata '%s' kind-nya '%s'", id, def.kind)
			)
			assert(def.projectiles >= 1, string.format("senjata '%s' projectiles < 1", id))
			assert(def.range > 0, string.format("senjata '%s' range-nya %d", id, def.range))
			assert(
				def.cooldown > 0,
				string.format("senjata '%s' cooldown-nya %f", id, def.cooldown)
			)
			if def.kind == "melee" then
				melee += 1
			else
				ranged += 1
			end
		end
		assert(melee >= 1, "harus ada minimal satu senjata jarak dekat")
		assert(ranged >= 1, "harus ada minimal satu senjata jarak jauh (M5)")
	end,
})

table.insert(cases, {
	name = "senjata jarak jauh jangkauannya jauh di atas jarak dekat",
	run = function()
		-- Kalau tidak, silinder bidik dan kerucut menutup area yang sama dan
		-- tidak ada alasan memakai senjata jarak jauh.
		local meleeReach = Weapons.weapon_starter.range + Balance.MELEE_RADIUS_BONUS
		assert(
			Weapons.weapon_ranged.range > meleeReach * 2,
			string.format(
				"range ranged %d tidak jauh di atas jangkauan melee efektif %d",
				Weapons.weapon_ranged.range,
				meleeReach
			)
		)
	end,
})

table.insert(cases, {
	name = "senjata multi-proyektil bisa mengenai lebih dari satu musuh",
	run = function()
		-- weapon_boss_a punya projectiles = 3, dan CombatService memakai angka
		-- itu sebagai batas jumlah target. Kalau angkanya 1, senjata hasil
		-- craft tidak berbeda dari senjata beli selain damage.
		assert(
			Weapons.weapon_boss_a.projectiles > 1,
			"weapon_boss_a harus bisa mengenai lebih dari satu musuh"
		)
	end,
})

return cases
