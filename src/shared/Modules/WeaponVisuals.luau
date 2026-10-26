--!strict
-- WeaponVisuals.luau: bentuk senjata yang dipegang pemain.
--
-- Modul murni, pola yang sama dengan CharacterDesign dan EnemyVisuals: angka
-- dan warna saja, `shape`/`material` sebagai string, dirakit jadi Part oleh
-- WeaponService di server.
--
-- KENAPA SENJATA PERLU TERLIHAT SAMA SEKALI
--
-- Uji kena di game ini sepenuhnya geometris: kerucut untuk jarak dekat,
-- silinder di sekitar garis bidik untuk jarak jauh (HitTest.luau). Tidak ada
-- satu pun bagian kode yang membaca Part senjata. Jadi senjata yang terlihat
-- memang TIDAK berpengaruh apa pun pada gameplay, dan itu justru alasannya
-- dibuat belakangan.
--
-- Tapi ketiadaannya punya harga yang nyata: pemain tidak punya cara mengetahui
-- senjata apa yang sedang dipegangnya, dan tidak punya cara mengetahui senjata
-- apa yang dipegang rekan setimnya. Pada game yang seluruh progresnya adalah
-- tiga senjata dengan sembilan alur upgrade, itu kehilangan yang besar.
--
-- Semua ukuran dalam stud, offset relatif terhadap TELAPAK TANGAN KANAN.
-- Sumbu tangan mengikuti sumbu badan: +X kanan, +Y atas, -Z depan.

local WeaponVisuals = {}

export type Piece = {
	name: string,
	shape: string, -- "Block" | "Ball" | "Cylinder"
	size: Vector3,
	offset: Vector3,
	rotation: Vector3?,
	color: Color3,
	material: string,
	transparency: number?,
}

export type Weapon = {
	id: string,
	name: string,
	kind: string, -- "melee" | "ranged" -- menentukan animasi serangannya
	-- Titik moncong, relatif terhadap telapak tangan. Dipakai client untuk
	-- menempatkan kilatan tembakan; senjata jarak dekat memakainya sebagai
	-- ujung alat.
	muzzle: Vector3,
	pieces: { Piece },
}

local STEEL = Color3.fromRGB(58, 64, 76)
local DARK = Color3.fromRGB(26, 30, 38)
local ACCENT = Color3.fromRGB(0, 212, 255)
local WARM = Color3.fromRGB(255, 160, 50)

local WEAPONS: { [string]: Weapon } = {
	-- Patch Wrench, kunci pas besar. Senjata jarak dekat, dan bentuknya
	-- memang alat tukang, bukan pedang: tim ini teknisi IT, dan senjatanya
	-- harus terbaca sebagai perkakas yang diambil dari sabuk alat.
	weapon_starter = {
		id = "weapon_starter",
		name = "Patch Wrench",
		kind = "melee",
		muzzle = Vector3.new(0, 0, -3.1),
		pieces = {
			{
				name = "Grip",
				shape = "Block",
				size = Vector3.new(0.42, 0.42, 1.8),
				offset = Vector3.new(0, 0, -0.5),
				color = DARK,
				material = "SmoothPlastic",
			},
			{
				name = "Shaft",
				shape = "Block",
				size = Vector3.new(0.34, 0.34, 1.6),
				offset = Vector3.new(0, 0, -1.9),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "HeadLeft",
				shape = "Block",
				size = Vector3.new(0.34, 1.1, 0.5),
				offset = Vector3.new(-0.38, 0, -2.8),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "HeadRight",
				shape = "Block",
				size = Vector3.new(0.34, 1.1, 0.5),
				offset = Vector3.new(0.38, 0, -2.8),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "HeadBack",
				shape = "Block",
				size = Vector3.new(1.1, 1.1, 0.4),
				offset = Vector3.new(0, 0, -2.45),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "Charge",
				shape = "Block",
				size = Vector3.new(0.2, 0.2, 1.2),
				offset = Vector3.new(0, 0.25, -1.9),
				color = ACCENT,
				material = "Neon",
				transparency = 0.2,
			},
		},
	},

	-- Packet Rifle, senapan panjang. Jangkauan 60 stud, paling sering dipakai,
	-- jadi siluetnya dibuat paling panjang: pemain di seberang arena harus bisa
	-- menebak jangkauan rekannya dari bentuk senjatanya saja.
	weapon_ranged = {
		id = "weapon_ranged",
		name = "Packet Rifle",
		kind = "ranged",
		muzzle = Vector3.new(0, 0.1, -4.2),
		pieces = {
			{
				name = "Grip",
				shape = "Block",
				size = Vector3.new(0.38, 0.9, 0.5),
				offset = Vector3.new(0, -0.3, 0),
				rotation = Vector3.new(14, 0, 0),
				color = DARK,
				material = "SmoothPlastic",
			},
			{
				name = "Receiver",
				shape = "Block",
				size = Vector3.new(0.5, 0.75, 2.4),
				offset = Vector3.new(0, 0.26, -1.1),
				color = DARK,
				material = "Metal",
			},
			{
				name = "Barrel",
				shape = "Cylinder",
				size = Vector3.new(2.6, 0.3, 0.3),
				offset = Vector3.new(0, 0.3, -3),
				rotation = Vector3.new(0, 90, 0),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "Scope",
				shape = "Block",
				size = Vector3.new(0.26, 0.3, 1),
				offset = Vector3.new(0, 0.72, -1.2),
				color = DARK,
				material = "Metal",
			},
			{
				name = "ScopeLens",
				shape = "Block",
				size = Vector3.new(0.18, 0.2, 0.12),
				offset = Vector3.new(0, 0.72, -1.72),
				color = ACCENT,
				material = "Neon",
			},
			{
				name = "Magazine",
				shape = "Block",
				size = Vector3.new(0.34, 0.8, 0.55),
				offset = Vector3.new(0, -0.28, -1),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "Rail",
				shape = "Block",
				size = Vector3.new(0.14, 0.14, 2),
				offset = Vector3.new(0.28, 0.3, -1.4),
				color = ACCENT,
				material = "Neon",
				transparency = 0.25,
			},
		},
	},

	-- Fork Bomb, pelontar. Senjata hasil crafting dari material boss, jadi
	-- bentuknya sengaja paling tidak rapi di antara ketiganya: tabung gemuk,
	-- bukan garis lurus. Pemain harus bisa melihat dari jauh bahwa seseorang di
	-- timnya sudah sampai ke senjata boss.
	weapon_boss_a = {
		id = "weapon_boss_a",
		name = "Fork Bomb",
		kind = "ranged",
		muzzle = Vector3.new(0, 0.15, -3.4),
		pieces = {
			{
				name = "Grip",
				shape = "Block",
				size = Vector3.new(0.4, 0.95, 0.5),
				offset = Vector3.new(0, -0.32, 0.1),
				rotation = Vector3.new(12, 0, 0),
				color = DARK,
				material = "SmoothPlastic",
			},
			{
				name = "Drum",
				shape = "Cylinder",
				size = Vector3.new(1.1, 1.3, 1.3),
				offset = Vector3.new(0, 0.3, -1),
				rotation = Vector3.new(0, 90, 0),
				color = STEEL,
				material = "Metal",
			},
			{
				name = "Tube",
				shape = "Cylinder",
				size = Vector3.new(2.3, 0.72, 0.72),
				offset = Vector3.new(0, 0.32, -2.5),
				rotation = Vector3.new(0, 90, 0),
				color = DARK,
				material = "Metal",
			},
			{
				name = "Charge1",
				shape = "Ball",
				size = Vector3.new(0.45, 0.45, 0.45),
				offset = Vector3.new(0.45, 0.72, -1),
				color = WARM,
				material = "Neon",
			},
			{
				name = "Charge2",
				shape = "Ball",
				size = Vector3.new(0.45, 0.45, 0.45),
				offset = Vector3.new(-0.45, 0.72, -1),
				color = WARM,
				material = "Neon",
			},
			{
				name = "MuzzleRing",
				shape = "Cylinder",
				size = Vector3.new(0.25, 0.95, 0.95),
				offset = Vector3.new(0, 0.32, -3.4),
				rotation = Vector3.new(0, 90, 0),
				color = WARM,
				material = "Neon",
				transparency = 0.25,
			},
		},
	},
}

function WeaponVisuals.get(weaponId: string): Weapon?
	return WEAPONS[weaponId]
end

function WeaponVisuals.kindOf(weaponId: string): string
	local weapon = WEAPONS[weaponId]
	-- Jatuh ke "melee" untuk id tak dikenal, bukan error: nilainya cuma
	-- menentukan animasi mana yang diputar, dan animasi yang keliru jauh lebih
	-- ringan akibatnya daripada controller yang berhenti jalan.
	return if weapon ~= nil then weapon.kind else "melee"
end

function WeaponVisuals.validate(knownIds: { string }): (boolean, string?)
	for _, id in knownIds do
		if WEAPONS[id] == nil then
			return false, string.format("senjata '%s' tidak punya bentuk", id)
		end
	end

	for id, weapon in WEAPONS do
		if weapon.kind ~= "melee" and weapon.kind ~= "ranged" then
			return false, string.format("%s memakai kind tak dikenal: %s", id, weapon.kind)
		end
		if #weapon.pieces == 0 then
			return false, string.format("%s tidak punya satu pun potongan", id)
		end

		local seen: { [string]: boolean } = {}
		for _, piece in weapon.pieces do
			if seen[piece.name] then
				return false, string.format("%s punya dua potongan bernama %s", id, piece.name)
			end
			seen[piece.name] = true
			if piece.shape ~= "Block" and piece.shape ~= "Ball" and piece.shape ~= "Cylinder" then
				return false, string.format("%s/%s shape tak dikenal: %s", id, piece.name, piece.shape)
			end
		end

		-- Moncong harus ada DI DEPAN tangan (Z negatif). Moncong yang
		-- tandanya terbalik menaruh kilatan tembakan di belakang punggung
		-- pemain, dan itu tidak terbaca sebagai bug, cuma terlihat aneh.
		if weapon.muzzle.Z >= 0 then
			return false, string.format("%s punya moncong di belakang tangan", id)
		end
	end

	return true, nil
end

return WeaponVisuals
