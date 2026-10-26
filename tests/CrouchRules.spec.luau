-- CrouchRules.spec.luau — angka jongkok.
--
-- Jongkok tidak punya aturan gameplay: dia cuma memperlambat jalan dan
-- menurunkan badan. Yang dipatok di sini karena itu bukan keputusan, tapi dua
-- hal yang kalau salah tidak akan terlihat sebagai bug. Pertama, jongkok yang
-- dihitung dari kecepatan SEKARANG alih-alih kecepatan berdiri: jongkok kedua
-- jadi seperempat, ketiga seperdelapan, dan pemain cuma merasa karakternya
-- makin lama makin berat. Kedua, nilai berdiri yang rusak (nol dari Humanoid
-- yang belum selesai dirakit, NaN dari pengali di tempat lain) yang diteruskan
-- apa adanya: WalkSpeed nol berarti pemain tidak bisa bergerak sama sekali
-- sampai dia mati.

local CrouchRules = require("../src/shared/Modules/CrouchRules")

local cases = {}

table.insert(cases, {
	name = "jongkok setengah kecepatan berdiri, berdiri kembali ke angka semula",
	run = function()
		assert(CrouchRules.speedFor(16, true) == 8, "16 jongkok harus jadi 8")
		assert(CrouchRules.speedFor(16, false) == 16, "berdiri harus kembali ke 16")
		assert(CrouchRules.speedFor(24, true) == 12, "pengali, bukan angka mutlak")
	end,
})

table.insert(cases, {
	name = "kecepatan dihitung dari angka berdiri, jadi jongkok berulang tidak menumpuk",
	run = function()
		-- Ini yang dijaga: pemanggil mengoper kecepatan BERDIRI tiap kali, jadi
		-- memanggilnya tiga kali berturut-turut tetap menghasilkan setengah.
		local standing = 16
		local once = CrouchRules.speedFor(standing, true)
		local twice = CrouchRules.speedFor(standing, true)
		assert(once == twice, "jongkok kedua tidak boleh lebih lambat dari yang pertama")
		-- Dan ini bahayanya, dipatok supaya terlihat: mengoper hasil jongkok
		-- kembali ke fungsinya memang menghasilkan seperempat. Fungsi ini tidak
		-- bisa mencegahnya; yang mencegahnya pemanggil yang menyimpan kecepatan
		-- berdiri terpisah.
		assert(CrouchRules.speedFor(once, true) == 4, "seperempat, dan itu yang dihindari")
	end,
})

table.insert(cases, {
	name = "kecepatan berdiri yang rusak jatuh ke default, bukan diteruskan",
	run = function()
		assert(CrouchRules.speedFor(0, true) == 8, "nol harus jatuh ke default 16, lalu separuh")
		assert(CrouchRules.speedFor(0, false) == 16, "nol saat berdiri juga jatuh ke default")
		assert(CrouchRules.speedFor(-5, true) == 8, "negatif harus jatuh ke default")
		assert(CrouchRules.speedFor(0 / 0, true) == 8, "NaN harus jatuh ke default")
		assert(CrouchRules.speedFor(math.huge, true) == 8, "inf harus jatuh ke default")
	end,
})

table.insert(cases, {
	name = "HipHeight turun 1.2 saat jongkok dan kembali utuh saat berdiri",
	run = function()
		local standing = 2
		local crouched = CrouchRules.hipHeightFor(standing, true)
		assert(math.abs(crouched - 0.8) < 1e-9, "2 - 1.2 = 0.8")
		assert(CrouchRules.hipHeightFor(standing, false) == standing, "berdiri harus utuh")
	end,
})

table.insert(cases, {
	name = "HipHeight tidak pernah turun di bawah batas bawah",
	run = function()
		-- Avatar yang HipHeight berdirinya sudah kecil: 1 - 1.2 negatif, dan
		-- pinggul di bawah lantai berarti karakter tenggelam.
		local crouched = CrouchRules.hipHeightFor(1, true)
		assert(crouched == CrouchRules.MIN_HIP_HEIGHT, "harus dijepit ke batas bawah")
		assert(crouched > 0, "HipHeight tidak boleh nol atau negatif")
	end,
})

table.insert(cases, {
	name = "HipHeight berdiri yang rusak jatuh ke default",
	run = function()
		assert(CrouchRules.hipHeightFor(0, false) == 2, "nol harus jatuh ke default 2")
		assert(CrouchRules.hipHeightFor(0 / 0, false) == 2, "NaN harus jatuh ke default")
		assert(CrouchRules.hipHeightFor(math.huge, true) == 0.8, "inf jatuh ke default dulu")
	end,
})

table.insert(cases, {
	name = "kamera turun saat jongkok dan nol saat berdiri",
	run = function()
		assert(CrouchRules.cameraDropFor(false) == 0, "berdiri tidak menggeser kamera")
		assert(CrouchRules.cameraDropFor(true) < 0, "jongkok menurunkan kamera, bukan menaikkan")
		assert(
			CrouchRules.cameraDropFor(true) == -CrouchRules.CAMERA_DROP,
			"besarnya harus sama dengan konstantanya"
		)
	end,
})

table.insert(cases, {
	name = "kamera turun sebanyak badan turun",
	run = function()
		-- Bukan kerapian: kamera yang turun lebih sedikit daripada badan membuat
		-- pemain melihat punggung karakternya sendiri saat jongkok.
		assert(
			CrouchRules.CAMERA_DROP == CrouchRules.HIP_DROP,
			"penurunan kamera dan badan harus satu angka"
		)
	end,
})

return cases
