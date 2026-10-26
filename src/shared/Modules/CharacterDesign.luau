--!strict
-- CharacterDesign.luau: rancangan visual karakter pemain "Teknisi IT".
--
-- Modul murni: tanpa game:GetService, tanpa `script`, supaya bisa dites Lune
-- (disiplin yang sama dengan Enemies.luau). Yang ada di sini cuma ANGKA dan
-- WARNA; yang membangun Part-nya adalah CharacterService di sisi server.
--
-- Kenapa karakternya dibangun dari Part, bukan dari aksesori katalog Roblox:
-- aksesori katalog dirujuk lewat asset id, dan asset id yang salah ketik atau
-- sudah di-takedown tidak gagal saat boot, dia gagal diam-diam dan
-- karakternya muncul tanpa aksesori itu, tanpa pesan apa pun. Part yang
-- dibangun sendiri tidak punya ketergantungan ke luar place: kalau file ini
-- ikut, karakternya ikut. Itu juga yang membuat seluruh rancangan ini bisa
-- dibaca dan diubah di satu file, bukan lewat belasan nomor yang tidak ada
-- artinya kalau dibaca orang lain.
--
-- UKURAN DAN POSISI DITULIS SEBAGAI PECAHAN, BUKAN STUD. `sizeScale` dan
-- `offsetScale` dikalikan dengan ukuran Part induknya saat dibangun. Alasannya
-- praktis: ukuran bagian tubuh R15 tidak tetap, dia ikut berubah kalau
-- Humanoid punya skala badan berbeda (HeadScale, BodyWidthScale, dan
-- seterusnya). Angka stud yang dipatok akan pas di satu avatar dan melayang di
-- avatar lain. Pecahan ikut menyesuaikan sendiri.
--
-- `shape` dan `material` disimpan sebagai STRING, bukan Enum. Bukan karena
-- Enum tidak jalan, tapi supaya modul ini tetap bisa di-require dari test Lune
-- tanpa menyeret definisi Enum Roblox. CharacterService yang menerjemahkannya
-- sekali, di satu tempat, dan satu nama shape yang salah ketik langsung
-- ketahuan di situ.

local CharacterDesign = {}

-- --------------------------------------------------------------------------
-- Palet
-- --------------------------------------------------------------------------
--
-- Warnanya dipilih untuk SATU tujuan: pemain harus bisa dibedakan dari musuh
-- dalam sekejap, bahkan saat layar ramai pada wave akhir. Musuh di game ini
-- memakai warna panas (merah, jingga, ungu) sesuai peta cerita di Tugas 5.
-- Karena itu tim IT memakai sisi dingin: badan gelap netral, aksen sian.
-- Kontras ini bukan selera; dia yang membuat pemain tidak menembaki rekannya
-- sendiri dan tidak panik mencari dirinya di tengah kerumunan.

local PALETTE = {
	uniform = Color3.fromRGB(38, 45, 58), -- biru keabuan gelap, badan seragam
	uniformDark = Color3.fromRGB(24, 29, 38), -- rompi, ransel, sepatu
	trim = Color3.fromRGB(60, 72, 90), -- garis pembatas antar bagian
	accent = Color3.fromRGB(0, 212, 255), -- sian neon: visor, lampu, inti ransel
	accentWarm = Color3.fromRGB(255, 176, 46), -- kuning: sabuk alat, pelindung lutut
	skin = Color3.fromRGB(234, 196, 160),
	badge = Color3.fromRGB(226, 232, 240),

	-- DUA WARNA ANGGOTA BADAN, dan kenapa keduanya harus ada.
	--
	-- Rekaman playtest pertama memperlihatkan masalah yang tidak terpikirkan
	-- saat merancang di atas kertas: seluruh bagian bawah badan terbaca
	-- sebagai SATU gumpalan gelap. Paha, betis, rompi, dan sabuk semuanya
	-- memakai dua warna yang hanya berbeda tipis, dan di bawah pencahayaan
	-- arena yang memang gelap, mata tidak punya tepi untuk dipegang.
	--
	-- Akibatnya bukan cuma jelek. Kalau kaki kiri dan kaki kanan tidak bisa
	-- dibedakan, langkah kaki TIDAK TERLIHAT sama sekali walaupun sendinya
	-- benar-benar berayun. Jadi masalah animasi yang dilaporkan ("kakinya
	-- tidak berjalan seperti manusia") sebagian adalah masalah warna.
	--
	-- `limbLight` sengaja jauh lebih terang daripada rompi, dan `limbDark`
	-- dipakai di bawah lutut dan siku. Batas terang-gelap di sendi itulah yang
	-- memberi tahu mata di mana kaki menekuk.
	limbLight = Color3.fromRGB(96, 112, 136),
	limbDark = Color3.fromRGB(52, 62, 78),
}

CharacterDesign.PALETTE = PALETTE

-- --------------------------------------------------------------------------
-- Warna badan
-- --------------------------------------------------------------------------
--
-- Kepala sengaja dibiarkan berwarna kulit, bukan ikut gelap. Wajah adalah satu
-- -satunya bagian yang dipakai pemain untuk mengenali arah hadap karakter dari
-- jauh; kalau kepala ikut gelap seperti rompi, siluetnya jadi satu blok dan
-- arah hadapnya hilang.

CharacterDesign.BODY_COLORS = {
	Head = PALETTE.skin,

	-- Torso tetap gelap: dia latar tempat rompi, lampu dada, dan tanda
	-- pengenal menempel, dan ketiganya butuh permukaan gelap untuk terbaca.
	UpperTorso = PALETTE.uniform,
	LowerTorso = PALETTE.uniform,

	-- Lengan dan kaki jauh lebih terang daripada torso. Ini yang memisahkan
	-- anggota badan dari badan, sehingga ayunannya terlihat.
	LeftUpperArm = PALETTE.limbLight,
	LeftLowerArm = PALETTE.limbDark,
	LeftHand = PALETTE.skin,
	RightUpperArm = PALETTE.limbLight,
	RightLowerArm = PALETTE.limbDark,
	RightHand = PALETTE.skin,

	LeftUpperLeg = PALETTE.limbLight,
	LeftLowerLeg = PALETTE.limbDark,
	LeftFoot = PALETTE.uniformDark,
	RightUpperLeg = PALETTE.limbLight,
	RightLowerLeg = PALETTE.limbDark,
	RightFoot = PALETTE.uniformDark,
} :: { [string]: Color3 }

-- --------------------------------------------------------------------------
-- Aksesori
-- --------------------------------------------------------------------------

export type Accessory = {
	id: string,
	attachTo: string, -- nama Part R15 yang jadi induk
	shape: string, -- "Block" | "Cylinder" | "Ball"
	sizeScale: Vector3, -- pecahan dari ukuran Part induk
	offsetScale: Vector3, -- pecahan dari ukuran Part induk, di ruang lokal induk
	rotation: Vector3?, -- derajat, opsional
	color: Color3,
	material: string,
	transparency: number?,
}

-- Catatan arah sumbu, supaya angka di bawah bisa dibaca tanpa menebak:
-- pada Part tubuh R15, +X ke kanan karakter, +Y ke atas, dan -Z ke DEPAN
-- (arah hadap). Jadi offset Z negatif berarti maju, positif berarti mundur.

local ACCESSORIES: { Accessory } = {
	-- ---------------------------------------------------------------- kepala
	{
		id = "Visor",
		attachTo = "Head",
		shape = "Block",
		sizeScale = Vector3.new(1.04, 0.26, 1.06),
		offsetScale = Vector3.new(0, 0.08, -0.03),
		color = PALETTE.accent,
		material = "Neon",
		-- Setengah tembus pandang, bukan solid: visor solid menutupi mata dan
		-- wajahnya jadi hilang sama sekali. Sudah dibahas di atas kenapa wajah
		-- perlu tetap terbaca.
		transparency = 0.45,
	},
	{
		id = "VisorFrame",
		attachTo = "Head",
		shape = "Block",
		sizeScale = Vector3.new(1.08, 0.33, 1.02),
		offsetScale = Vector3.new(0, 0.08, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "HeadsetBand",
		attachTo = "Head",
		shape = "Block",
		sizeScale = Vector3.new(1.14, 0.12, 0.5),
		offsetScale = Vector3.new(0, 0.44, 0.02),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "EarcupLeft",
		attachTo = "Head",
		shape = "Cylinder",
		-- Cylinder di Roblox bersumbu X: panjangnya mengikuti Size.X dan
		-- penampang lingkarannya mengikuti Y dan Z. Jadi angka X kecil = cakram
		-- tipis yang menempel di sisi kepala, bukan tabung panjang.
		sizeScale = Vector3.new(0.16, 0.52, 0.52),
		offsetScale = Vector3.new(-0.58, 0.12, 0.02),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "EarcupRight",
		attachTo = "Head",
		shape = "Cylinder",
		sizeScale = Vector3.new(0.16, 0.52, 0.52),
		offsetScale = Vector3.new(0.58, 0.12, 0.02),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "EarcupLightRight",
		attachTo = "Head",
		shape = "Cylinder",
		sizeScale = Vector3.new(0.2, 0.24, 0.24),
		offsetScale = Vector3.new(0.63, 0.12, 0.02),
		color = PALETTE.accent,
		material = "Neon",
	},
	{
		id = "MicBoom",
		attachTo = "Head",
		shape = "Block",
		sizeScale = Vector3.new(0.07, 0.07, 0.62),
		offsetScale = Vector3.new(0.5, -0.04, -0.32),
		rotation = Vector3.new(14, 0, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},

	-- ----------------------------------------------------------------- badan
	{
		id = "Vest",
		attachTo = "UpperTorso",
		shape = "Block",
		-- Sedikit lebih besar dari torsonya supaya terbaca sebagai rompi yang
		-- DIPAKAI, bukan sebagai warna torso yang berbeda.
		--
		-- Dikecilkan dari versi pertama (1.08 x 0.94 x 1.16). Rompi yang
		-- terlalu tebal membuat badan jadi balok lebar, dan lengan yang
		-- berayun di sisinya tertelan bayangannya sendiri.
		sizeScale = Vector3.new(1.03, 0.9, 1.08),
		offsetScale = Vector3.new(0, -0.02, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "VestTrim",
		attachTo = "UpperTorso",
		shape = "Block",
		sizeScale = Vector3.new(1.1, 0.1, 1.18),
		offsetScale = Vector3.new(0, 0.3, 0),
		color = PALETTE.trim,
		material = "SmoothPlastic",
	},
	{
		id = "ChestLight",
		attachTo = "UpperTorso",
		shape = "Block",
		sizeScale = Vector3.new(0.16, 0.16, 0.1),
		offsetScale = Vector3.new(0.27, 0.12, -0.59),
		color = PALETTE.accent,
		material = "Neon",
	},
	{
		id = "IdBadge",
		attachTo = "UpperTorso",
		shape = "Block",
		sizeScale = Vector3.new(0.2, 0.28, 0.08),
		offsetScale = Vector3.new(-0.28, 0.06, -0.59),
		color = PALETTE.badge,
		material = "SmoothPlastic",
	},
	{
		id = "Backpack",
		attachTo = "UpperTorso",
		shape = "Block",
		sizeScale = Vector3.new(0.72, 0.8, 0.4),
		offsetScale = Vector3.new(0, 0.0, 0.66),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "BackpackCore",
		attachTo = "UpperTorso",
		shape = "Ball",
		sizeScale = Vector3.new(0.3, 0.3, 0.3),
		offsetScale = Vector3.new(0, 0.0, 0.84),
		color = PALETTE.accent,
		material = "Neon",
	},
	{
		id = "ShoulderLamp",
		attachTo = "RightUpperArm",
		shape = "Block",
		sizeScale = Vector3.new(0.62, 0.22, 0.66),
		offsetScale = Vector3.new(0, 0.4, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "ShoulderLampLens",
		attachTo = "RightUpperArm",
		shape = "Block",
		sizeScale = Vector3.new(0.4, 0.1, 0.4),
		offsetScale = Vector3.new(0, 0.5, -0.1),
		color = PALETTE.accent,
		material = "Neon",
	},

	-- ----------------------------------------------------------------- sabuk
	{
		id = "ToolBelt",
		attachTo = "LowerTorso",
		shape = "Block",
		sizeScale = Vector3.new(1.12, 0.4, 1.2),
		offsetScale = Vector3.new(0, -0.1, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "BeltBuckle",
		attachTo = "LowerTorso",
		shape = "Block",
		sizeScale = Vector3.new(0.26, 0.26, 0.1),
		offsetScale = Vector3.new(0, -0.1, -0.6),
		color = PALETTE.accentWarm,
		material = "SmoothPlastic",
	},
	{
		id = "BeltPouch",
		attachTo = "LowerTorso",
		shape = "Block",
		sizeScale = Vector3.new(0.3, 0.46, 0.32),
		offsetScale = Vector3.new(0.56, -0.16, 0.1),
		color = PALETTE.accentWarm,
		material = "SmoothPlastic",
	},

	-- ------------------------------------------------------------ anggota badan
	{
		id = "GloveLeft",
		attachTo = "LeftHand",
		shape = "Block",
		sizeScale = Vector3.new(1.14, 1.1, 1.14),
		offsetScale = Vector3.new(0, 0, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "GloveRight",
		attachTo = "RightHand",
		shape = "Block",
		sizeScale = Vector3.new(1.14, 1.1, 1.14),
		offsetScale = Vector3.new(0, 0, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	-- PELINDUNG LUTUT: TUTUP DEPAN, BUKAN PITA MELINGKAR.
	--
	-- Versi pertama selebar 1.1 kali lebar betis dan berwarna oranye terang.
	-- Dipasang di dua kaki yang berdiri berdampingan, keduanya nyaris
	-- bersentuhan dan terbaca sebagai SATU pita mendatar yang menyambung,
	-- persis seperti rok. Pita mendatar adalah bentuk yang paling buruk untuk
	-- ini: dia justru menyembunyikan garis pemisah antara kaki kiri dan kanan,
	-- yaitu satu-satunya garis yang membuat langkah terlihat.
	--
	-- Sekarang lebarnya 0.62 dan hanya menempel di sisi depan lutut, jadi ada
	-- celah gelap di antara kedua kaki sepanjang waktu.
	{
		id = "KneePadLeft",
		attachTo = "LeftLowerLeg",
		shape = "Block",
		sizeScale = Vector3.new(0.62, 0.34, 0.5),
		offsetScale = Vector3.new(0, 0.26, -0.4),
		color = PALETTE.accentWarm,
		material = "SmoothPlastic",
	},
	{
		id = "KneePadRight",
		attachTo = "RightLowerLeg",
		shape = "Block",
		sizeScale = Vector3.new(0.62, 0.34, 0.5),
		offsetScale = Vector3.new(0, 0.26, -0.4),
		color = PALETTE.accentWarm,
		material = "SmoothPlastic",
	},

	-- GARIS BETIS. Satu garis sian tipis di sisi LUAR tiap betis.
	--
	-- Ini penanda gerak, bukan hiasan. Saat kaki berayun, garis inilah yang
	-- bergerak melintasi layar dan memberi tahu mata bahwa ada dua kaki yang
	-- bergantian, bukan satu massa gelap yang bergeser. Dipasang di sisi luar
	-- supaya selalu terlihat dari samping, yaitu sudut pandang yang paling
	-- sering dipakai saat berlari menyusuri lane.
	{
		id = "ShinStripeLeft",
		attachTo = "LeftLowerLeg",
		shape = "Block",
		sizeScale = Vector3.new(0.16, 0.66, 0.42),
		offsetScale = Vector3.new(-0.46, -0.05, 0),
		color = PALETTE.accent,
		material = "Neon",
		transparency = 0.15,
	},
	{
		id = "ShinStripeRight",
		attachTo = "RightLowerLeg",
		shape = "Block",
		sizeScale = Vector3.new(0.16, 0.66, 0.42),
		offsetScale = Vector3.new(0.46, -0.05, 0),
		color = PALETTE.accent,
		material = "Neon",
		transparency = 0.15,
	},

	-- Pita paha gelap tepat di bawah sabuk. Memotong siluet di pangkal paha,
	-- sehingga kaki terbaca mulai dari situ dan tidak menyatu dengan sabuk.
	{
		id = "ThighBandLeft",
		attachTo = "LeftUpperLeg",
		shape = "Block",
		sizeScale = Vector3.new(1.06, 0.2, 1.08),
		offsetScale = Vector3.new(0, 0.36, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "ThighBandRight",
		attachTo = "RightUpperLeg",
		shape = "Block",
		sizeScale = Vector3.new(1.06, 0.2, 1.08),
		offsetScale = Vector3.new(0, 0.36, 0),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},

	{
		id = "BootLeft",
		attachTo = "LeftFoot",
		shape = "Block",
		sizeScale = Vector3.new(1.12, 0.8, 1.1),
		offsetScale = Vector3.new(0, 0.06, -0.02),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},
	{
		id = "BootRight",
		attachTo = "RightFoot",
		shape = "Block",
		sizeScale = Vector3.new(1.12, 0.8, 1.1),
		offsetScale = Vector3.new(0, 0.06, -0.02),
		color = PALETTE.uniformDark,
		material = "SmoothPlastic",
	},

	-- Sol sepatu berwarna terang. Saat kaki terangkat, sol inilah yang
	-- menghadap kamera, dan warnanya yang membuat langkah terlihat bahkan dari
	-- belakang: dua kilatan terang bergantian di bawah badan.
	{
		id = "SoleLeft",
		attachTo = "LeftFoot",
		shape = "Block",
		sizeScale = Vector3.new(1.14, 0.3, 1.12),
		offsetScale = Vector3.new(0, -0.42, -0.02),
		color = PALETTE.trim,
		material = "SmoothPlastic",
	},
	{
		id = "SoleRight",
		attachTo = "RightFoot",
		shape = "Block",
		sizeScale = Vector3.new(1.14, 0.3, 1.12),
		offsetScale = Vector3.new(0, -0.42, -0.02),
		color = PALETTE.trim,
		material = "SmoothPlastic",
	},
}

CharacterDesign.ACCESSORIES = ACCESSORIES

-- Nama folder tempat seluruh aksesori ditaruh di dalam karakter. Dipakai dua
-- arah: CharacterService memasangnya ke sini, dan dia juga yang dihapus lebih
-- dulu kalau desainnya dipasang ulang. Tanpa satu folder bersama, aksesori
-- lama bercampur dengan yang baru dan karakternya menumpuk dua rompi.
CharacterDesign.CONTAINER_NAME = "CodeVerseKit"

-- Bagian tubuh R15 yang WAJIB ada sebelum desain dipasang. Dipakai
-- CharacterService untuk menunggu rig selesai dirakit: memasang aksesori ke
-- rig yang baru setengah jadi menghasilkan Part yang menempel di tempat salah,
-- dan itu tidak terlihat sebagai error, cuma terlihat jelek.
CharacterDesign.REQUIRED_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftHand",
	"RightHand",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot",
	"RightUpperArm",
}

-- Dipakai test: tiap aksesori harus menunjuk bagian tubuh yang memang ada di
-- daftar warna badan, dan id-nya tidak boleh kembar. Dua kesalahan ini yang
-- paling mungkin terjadi saat menambah aksesori baru dengan menyalin blok di
-- atas, dan dua-duanya tidak menimbulkan error saat runtime, aksesori yang
-- induknya salah ketik cuma tidak muncul.
function CharacterDesign.validate(): (boolean, string?)
	local seen: { [string]: boolean } = {}
	for _, acc in ACCESSORIES do
		if seen[acc.id] then
			return false, string.format("id aksesori kembar: %s", acc.id)
		end
		seen[acc.id] = true

		if not CharacterDesign.BODY_COLORS[acc.attachTo] then
			return false,
				string.format(
					"aksesori %s menempel ke bagian tak dikenal: %s",
					acc.id,
					acc.attachTo
				)
		end

		if acc.shape ~= "Block" and acc.shape ~= "Cylinder" and acc.shape ~= "Ball" then
			return false,
				string.format("aksesori %s memakai shape tak dikenal: %s", acc.id, acc.shape)
		end
	end
	return true, nil
end

return CharacterDesign
