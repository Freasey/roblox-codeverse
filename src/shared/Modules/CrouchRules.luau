--!strict
-- CrouchRules.luau — angka jongkok, dan satu-satunya tempat angkanya ditulis.
--
-- Jongkok disentuh dua sisi jaringan: client menerapkannya seketika supaya
-- tombolnya tidak terasa lambat, server menerapkannya supaya pemain lain ikut
-- melihatnya. Dua sisi yang memakai angka berbeda berarti pemain melihat
-- dirinya melambat ke satu angka dan pemain lain melihatnya melambat ke angka
-- lain -- selisih yang tidak akan dilaporkan siapa pun karena masing-masing
-- layar terlihat wajar sendiri. Jadi angkanya di sini, dibaca keduanya.
--
-- Modul murni: tidak ada datatype Roblox di sini (Vector3 tidak ada di Lune),
-- jadi offset kamera dikembalikan sebagai angka Y saja dan yang memanggilnya
-- yang menyusun Vector3-nya.

local CrouchRules = {}

-- Setengah kecepatan. Pengali, bukan angka mutlak, supaya dia tetap benar
-- kalau nanti ada senjata atau efek yang mengubah kecepatan dasar pemain:
-- yang jongkok selalu setengah dari kecepatan berdirinya SAAT ITU.
CrouchRules.SPEED_MULT = 0.5

-- Badan turun 1.2 stud dari HipHeight berdirinya. R15 berdiri di sekitar 2,
-- jadi 1.2 membuatnya jelas lebih rendah tanpa tenggelam ke lantai.
CrouchRules.HIP_DROP = 1.2

-- Batas bawah, supaya penurunan tidak pernah menaruh pinggul di bawah lantai
-- pada karakter yang HipHeight berdirinya sudah kecil (avatar pendek, R6).
CrouchRules.MIN_HIP_HEIGHT = 0.2

-- Kamera ikut turun sebanyak badan turun. Kalau tidak, pemain jongkok tapi
-- sudut pandangnya tetap setinggi berdiri, dan jongkoknya cuma terasa sebagai
-- karakter yang mengecil di layar.
CrouchRules.CAMERA_DROP = 1.2

-- Dipakai kalau kecepatan atau HipHeight berdiri tidak diketahui: harness yang
-- tidak punya karakter, atau Humanoid yang propertinya sempat nol saat karakter
-- baru dirakit. Sama dengan default Roblox.
CrouchRules.DEFAULT_SPEED = 16
CrouchRules.DEFAULT_HIP_HEIGHT = 2

-- Kecepatan jalan yang berlaku. `standingSpeed` adalah kecepatan berdiri yang
-- dicatat sebelum jongkok, bukan kecepatan sekarang -- membaca kecepatan
-- sekarang berarti jongkok kedua menghitung setengah dari yang sudah separuh.
function CrouchRules.speedFor(standingSpeed: number, crouching: boolean): number
	local base = standingSpeed
	-- NaN lolos dari `<= 0` (NaN tidak lebih kecil dari apa pun), jadi
	-- diperiksa dengan membandingkan dia ke dirinya sendiri.
	if base ~= base or base <= 0 or base == math.huge then
		base = CrouchRules.DEFAULT_SPEED
	end
	if not crouching then
		return base
	end
	return base * CrouchRules.SPEED_MULT
end

-- HipHeight yang berlaku. Dijaga tidak pernah turun di bawah MIN_HIP_HEIGHT.
function CrouchRules.hipHeightFor(standingHipHeight: number, crouching: boolean): number
	local base = standingHipHeight
	if base ~= base or base <= 0 or base == math.huge then
		base = CrouchRules.DEFAULT_HIP_HEIGHT
	end
	if not crouching then
		return base
	end
	return math.max(base - CrouchRules.HIP_DROP, CrouchRules.MIN_HIP_HEIGHT)
end

-- Penurunan kamera, dalam stud, sebagai angka Y. Nol saat berdiri.
function CrouchRules.cameraDropFor(crouching: boolean): number
	if not crouching then
		return 0
	end
	return -CrouchRules.CAMERA_DROP
end

return CrouchRules
