--!strict
-- EnemyVisuals.luau: bentuk tiap jenis musuh.
--
-- Modul murni: tanpa game:GetService, tanpa Instance. `shape` dan `material`
-- disimpan sebagai string dengan alasan yang sama seperti di
-- WeaponVisuals.luau, supaya bisa di-require test Lune tanpa Enum Roblox.
--
-- SILUET DULU, WARNA BELAKANGAN
--
-- Sebelumnya tiap musuh adalah satu kubus; yang membedakan basic, fast, dan
-- tank cuma ukuran dan warna. Itu cukup untuk menguji gameplay, tapi gagal
-- pada satu hal yang menentukan di wave akhir: saat ada 40 musuh di layar dan
-- sebagian tertutup rak server, pemain harus bisa menilai ANCAMAN MANA YANG
-- HARUS DITEMBAK DULU dalam sepersekian detik. Warna hilang di bawah bloom dan
-- di balik efek; bentuk tidak.
--
-- Karena itu ketiganya dibedakan pada proporsi, bukan pada corak:
--   basic, gugus kubus kecil mengambang, lebar dan pecah
--   fast  : badan panjang rendah, jelas punya arah hadap
--   tank  : balok besar berpelat tebal, kaki pendek
-- Ketiganya masih bisa dibedakan sebagai bayangan hitam tanpa warna sama
-- sekali, dan itulah ujian yang dipakai saat merancangnya.

local EnemyVisuals = {}

export type Piece = {
	name: string,
	shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	size: Vector3,
	offset: Vector3,
	rotation: Vector3?, -- derajat
	color: Color3,
	material: string,
	transparency: number?,
	-- Kalau diisi, potongan ini dipasang dengan Motor6D (bukan las mati) dan
	-- diputar oleh EnemyFxController di client sebesar sekian putaran per
	-- detik. Dipakai hemat: tiap potongan berputar adalah satu sendi yang harus
	-- dihitung tiap frame untuk tiap musuh di layar.
	spin: number?,
}

export type Visual = {
	bodySize: Vector3,
	bodyShape: string,
	bodyColor: Color3,
	bodyMaterial: string,
	bodyTransparency: number?,
	pieces: { Piece },
}

-- Palet musuh. Semuanya sisi panas: merah, jingga, ungu, hijau asam.
--
-- Dulu pilihan ini berpasangan dengan palet pemain yang memakai sisi dingin,
-- sehingga pemain dan musuh tidak pernah tertukar. Pasangannya sudah tidak
-- ada: sejak 2026-10-26 pemain memakai avatar akunnya sendiri, dan warnanya
-- bisa apa saja, termasuk merah menyala.
--
-- Jadi yang menanggung pembedaan sekarang tinggal BENTUK, dan itu memang
-- sengaja dipikul duluan oleh siluet di bawah, bukan oleh warna. Kalau di
-- playtest ternyata masih ada yang tertukar, yang perlu ditambah adalah
-- penanda di sisi pemain (outline atau nameplate), bukan warna musuh
-- digelapkan, menggelapkan musuh justru menghapus pembeda antarmusuh.
local ADWARE = Color3.fromRGB(240, 160, 50)
local WORM = Color3.fromRGB(140, 230, 110)
local ROOTKIT = Color3.fromRGB(165, 120, 225)
local TROJAN = Color3.fromRGB(240, 95, 125)
local RANSOM = Color3.fromRGB(245, 70, 60)
local SHELL = Color3.fromRGB(28, 30, 38)

local VISUALS: { [string]: Visual } = {
	-- ----------------------------------------------------------------- basic
	-- Adware: jendela pop-up yang terus bermunculan. Bentuknya sengaja pecah
	-- menjadi beberapa kotak kecil, satu benda utuh akan terbaca sebagai
	-- musuh "padat" yang perlu ditembak lama, padahal basic justru yang paling
	-- cepat mati dan datang paling banyak.
	basic = {
		bodySize = Vector3.new(2.6, 2.6, 2.6),
		bodyShape = "Block",
		bodyColor = ADWARE,
		bodyMaterial = "SmoothPlastic",
		pieces = {
			{
				name = "Popup1",
				shape = "Block",
				size = Vector3.new(1.7, 1.2, 0.3),
				offset = Vector3.new(1.5, 1.1, -0.6),
				rotation = Vector3.new(0, 18, 12),
				color = Color3.fromRGB(255, 225, 180),
				material = "Neon",
				transparency = 0.25,
			},
			{
				name = "Popup2",
				shape = "Block",
				size = Vector3.new(1.4, 1, 0.3),
				offset = Vector3.new(-1.6, 0.4, 0.5),
				rotation = Vector3.new(0, -24, -10),
				color = Color3.fromRGB(255, 205, 140),
				material = "Neon",
				transparency = 0.3,
			},
			{
				name = "Popup3",
				shape = "Block",
				size = Vector3.new(1.2, 0.9, 0.3),
				offset = Vector3.new(0.3, 2, 0.8),
				rotation = Vector3.new(0, 8, 20),
				color = Color3.fromRGB(255, 240, 210),
				material = "Neon",
				transparency = 0.35,
			},
			{
				name = "Frame",
				shape = "Block",
				size = Vector3.new(3, 0.3, 3),
				offset = Vector3.new(0, -1.5, 0),
				color = SHELL,
				material = "SmoothPlastic",
			},
		},
	},

	-- ------------------------------------------------------------------ fast
	-- Worm: badan beruas yang panjang dan rendah. Arah hadapnya harus terbaca
	-- karena fast adalah satu-satunya musuh yang MENGEJAR PEMAIN, bukan Core,
	-- pemain perlu tahu sedang dikejar atau dilewati.
	fast = {
		bodySize = Vector3.new(1.6, 1.4, 3.4),
		bodyShape = "Block",
		bodyColor = WORM,
		bodyMaterial = "SmoothPlastic",
		pieces = {
			{
				name = "Segment1",
				shape = "Block",
				size = Vector3.new(1.3, 1.1, 1.6),
				offset = Vector3.new(0, -0.1, 2.3),
				color = Color3.fromRGB(110, 200, 90),
				material = "SmoothPlastic",
			},
			{
				name = "Segment2",
				shape = "Block",
				size = Vector3.new(1, 0.9, 1.3),
				offset = Vector3.new(0, -0.2, 3.6),
				color = Color3.fromRGB(85, 170, 75),
				material = "SmoothPlastic",
			},
			{
				name = "Eye",
				shape = "Ball",
				size = Vector3.new(0.9, 0.9, 0.9),
				offset = Vector3.new(0, 0.3, -1.7),
				color = Color3.fromRGB(230, 255, 180),
				material = "Neon",
			},
			{
				name = "Fin",
				shape = "Block",
				size = Vector3.new(0.2, 1.4, 1.6),
				offset = Vector3.new(0, 1, 0.6),
				rotation = Vector3.new(12, 0, 0),
				color = Color3.fromRGB(190, 255, 150),
				material = "Neon",
				transparency = 0.35,
			},
		},
	},

	-- ------------------------------------------------------------------ tank
	-- Rootkit: paling lambat (5 stud/detik) dan paling mematikan dari dekat.
	-- Bentuknya dibuat berat dan menapak, tidak mengambang seperti yang lain
	--, supaya "lambat tapi tidak boleh lolos" terbaca dari diamnya.
	tank = {
		bodySize = Vector3.new(5, 4.4, 5),
		bodyShape = "Block",
		bodyColor = ROOTKIT,
		bodyMaterial = "Metal",
		pieces = {
			{
				name = "PlateTop",
				shape = "Block",
				size = Vector3.new(5.6, 0.8, 5.6),
				offset = Vector3.new(0, 2.4, 0),
				color = SHELL,
				material = "DiamondPlate",
			},
			{
				name = "PlateFront",
				shape = "Block",
				size = Vector3.new(5.4, 3, 0.7),
				offset = Vector3.new(0, 0.2, -2.6),
				color = SHELL,
				material = "DiamondPlate",
			},
			{
				name = "CoreGlow",
				shape = "Block",
				size = Vector3.new(1.6, 1.6, 0.4),
				offset = Vector3.new(0, 0.4, -3),
				color = ROOTKIT,
				material = "Neon",
			},
			{
				name = "LegL",
				shape = "Block",
				size = Vector3.new(1, 2, 1),
				offset = Vector3.new(-1.8, -2.8, 0),
				color = SHELL,
				material = "Metal",
			},
			{
				name = "LegR",
				shape = "Block",
				size = Vector3.new(1, 2, 1),
				offset = Vector3.new(1.8, -2.8, 0),
				color = SHELL,
				material = "Metal",
			},
		},
	},

	-- --------------------------------------------------------- boss_splitter
	-- Trojan: tampak seperti benda biasa sebelum menyerang, lalu membelah.
	-- Cincin yang berputar adalah satu-satunya bagian bergerak, dan itu
	-- disengaja, gerakan menarik mata, dan boss memang harus jadi hal yang
	-- paling dilihat di arena saat dia muncul.
	boss_splitter = {
		bodySize = Vector3.new(7, 7, 7),
		bodyShape = "Block",
		bodyColor = TROJAN,
		bodyMaterial = "Neon",
		bodyTransparency = 0.15,
		pieces = {
			{
				name = "Cage",
				shape = "Block",
				size = Vector3.new(8.4, 8.4, 8.4),
				offset = Vector3.new(0, 0, 0),
				rotation = Vector3.new(0, 45, 0),
				color = SHELL,
				material = "DiamondPlate",
				transparency = 0.45,
			},
			{
				name = "Ring",
				shape = "Cylinder",
				size = Vector3.new(0.7, 12, 12),
				offset = Vector3.new(0, 0, 0),
				rotation = Vector3.new(0, 0, 90),
				color = TROJAN,
				material = "Neon",
				transparency = 0.3,
				spin = 0.3,
			},
			{
				name = "RingInner",
				shape = "Cylinder",
				size = Vector3.new(0.5, 9.5, 9.5),
				offset = Vector3.new(0, 0, 0),
				rotation = Vector3.new(90, 0, 0),
				color = Color3.fromRGB(255, 180, 200),
				material = "Neon",
				transparency = 0.45,
				spin = -0.5,
			},
		},
	},

	-- ----------------------------------------------------------- boss_locker
	-- Ransomware: bentuk gembok. Boss penutup, dan satu-satunya musuh yang
	-- bentuknya langsung memberi tahu apa yang dilakukannya, mengunci.
	boss_locker = {
		bodySize = Vector3.new(8, 7, 6),
		bodyShape = "Block",
		bodyColor = RANSOM,
		bodyMaterial = "Metal",
		pieces = {
			{
				name = "Shackle",
				shape = "Cylinder",
				size = Vector3.new(1.4, 7, 7),
				offset = Vector3.new(0, 5.4, 0),
				rotation = Vector3.new(0, 0, 90),
				color = Color3.fromRGB(190, 60, 55),
				material = "Metal",
			},
			{
				name = "Keyhole",
				shape = "Ball",
				size = Vector3.new(2.4, 2.4, 2.4),
				offset = Vector3.new(0, 0.6, -3),
				color = Color3.fromRGB(255, 210, 120),
				material = "Neon",
			},
			{
				name = "KeySlot",
				shape = "Block",
				size = Vector3.new(1.1, 2.6, 0.6),
				offset = Vector3.new(0, -0.9, -3.1),
				color = Color3.fromRGB(255, 210, 120),
				material = "Neon",
			},
			{
				name = "Halo",
				shape = "Cylinder",
				size = Vector3.new(0.6, 13, 13),
				offset = Vector3.new(0, -3.6, 0),
				rotation = Vector3.new(0, 0, 90),
				color = RANSOM,
				material = "Neon",
				transparency = 0.5,
				spin = 0.22,
			},
		},
	},
}

local FALLBACK: Visual = {
	bodySize = Vector3.new(3, 3, 3),
	bodyShape = "Block",
	bodyColor = Color3.fromRGB(200, 200, 200),
	bodyMaterial = "SmoothPlastic",
	pieces = {},
}

-- Selalu mengembalikan sesuatu yang bisa digambar. Musuh tanpa bentuk tidak
-- boleh berarti musuh tak terlihat: musuh tak terlihat yang tetap memukul Core
-- adalah bug yang paling membingungkan dari sisi pemain.
function EnemyVisuals.get(defId: string): Visual
	return VISUALS[defId] or FALLBACK
end

function EnemyVisuals.has(defId: string): boolean
	return VISUALS[defId] ~= nil
end

function EnemyVisuals.validate(knownIds: { string }): (boolean, string?)
	for _, id in knownIds do
		if VISUALS[id] == nil then
			return false, string.format("musuh '%s' tidak punya bentuk", id)
		end
	end

	for id, visual in VISUALS do
		local seen: { [string]: boolean } = {}
		for _, piece in visual.pieces do
			if seen[piece.name] then
				return false, string.format("%s punya dua potongan bernama %s", id, piece.name)
			end
			seen[piece.name] = true

			if piece.shape ~= "Block" and piece.shape ~= "Ball" and piece.shape ~= "Cylinder" then
				return false,
					string.format(
						"%s/%s memakai shape tak dikenal: %s",
						id,
						piece.name,
						piece.shape
					)
			end
		end
	end

	return true, nil
end

return EnemyVisuals
