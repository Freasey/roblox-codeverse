--!strict
-- ArenaLayout.luau: tata letak arena: ukuran kisi, jalur lane, dan jenis tile.
--
-- Modul murni: tanpa game:GetService, tanpa Instance. Yang ada di sini cuma
-- GEOMETRI dalam bentuk angka. ArenaBuilder yang mengubahnya jadi Part.
--
-- Pemisahan ini yang membuat arena bisa diuji tanpa membuka Studio sama
-- sekali. Pertanyaan seperti "apakah ada lane yang menembus dais Core?" atau
-- "apakah rak server pernah berdiri di tengah jalur musuh?" dijawab test,
-- bukan dilihat satu per satu dengan mata setelah map-nya jadi.
--
-- KENAPA ARENA DIBANGUN SCRIPT, BUKAN DIGAMBAR DI STUDIO
--
-- Arena ini 289 tile lantai, 68 panel dinding, dan puluhan properti. Digambar
-- tangan, mengubah satu keputusan, misalnya "lane-nya terlalu sempit",
-- berarti memindahkan ratusan Part satu per satu. Di sini lebarnya satu
-- konstanta: `LANE_HALF_WIDTH`. Dan karena hasilnya ikut di dalam file .rbxl
-- sebagai kode, orang lain yang membuka place ini mendapat arena yang sama
-- persis tanpa perlu menerima file map terpisah.

local ArenaLayout = {}

export type Vec2 = { x: number, z: number }

-- --------------------------------------------------------------------------
-- Ukuran
-- --------------------------------------------------------------------------

-- Satu tile = 8 stud. Ini angka "tileset" game ini: SEMUA lantai kelipatan
-- angka ini, jadi tidak pernah ada celah atau tumpang tindih antar tile.
-- Dipilih 8 karena karakter Roblox selebar ~4 stud, dua karakter muat
-- berdampingan dalam satu tile, dan tile terbaca sebagai ubin lantai ruang
-- server, bukan sebagai kotak catur raksasa.
ArenaLayout.TILE = 8

-- Kisi membentang dari -GRID ke +GRID, jadi 17 x 17 = 289 tile = 136 x 136
-- stud. Ukurannya ditentukan dari jangkauan turret Toko Match (70 stud di
-- Balance.luau): turret di tengah harus bisa menjangkau sekitar separuh arena,
-- supaya penempatannya jadi keputusan, bukan formalitas.
ArenaLayout.GRID = 8

-- Dais Core: lingkaran tempat Core Server berdiri. Jari-jarinya harus lebih
-- besar dari `Balance.BASE_RING_RADIUS_OUTER` (14), karena di cincin itulah
-- musuh berdiri saat menyerang Core. Kalau dais lebih kecil, musuh berdiri
-- melayang di luar tepinya.
ArenaLayout.DAIS_RADIUS = 20
ArenaLayout.DAIS_HEIGHT = 1.5

-- Tinggi dinding dan jarak dinding dari pusat.
ArenaLayout.WALL_HEIGHT = 22
-- Tile terluar berpusat di GRID * TILE = 64, dan lebarnya setengah tile lagi
-- ke luar, jadi tepi lantai ada di 68. Dinding berdiri tepat di situ; angka
-- yang lebih kecil akan membuat dinding memotong barisan tile terluar.
ArenaLayout.WALL_EXTENT = 68 -- = GRID * TILE + TILE / 2

-- --------------------------------------------------------------------------
-- Lane
-- --------------------------------------------------------------------------
--
-- Tiga lane, bukan dua. Dengan dua lane, tim empat orang membagi diri dua-dua
-- dan tidak pernah ada keputusan sulit. Dengan tiga, selalu ada satu lane yang
-- kurang dijaga, dan itulah yang membuat Toko Match (penghalang, turret) punya
-- arti. Tidak ada kode lain yang mematok jumlah lane: EnemyService dan
-- ShopService dua-duanya membaca `laneCount()`, jadi angka ini aman diubah.
ArenaLayout.LANE_ANGLES = { 90, 210, 330 }
ArenaLayout.LANE_WAYPOINTS = 7
ArenaLayout.LANE_OUTER_RADIUS = 62
ArenaLayout.LANE_INNER_RADIUS = 21
ArenaLayout.LANE_HALF_WIDTH = 7

-- Besar lengkungan lane, dalam derajat. Nol berarti lane lurus menembus dari
-- tepi ke pusat, dan lane lurus berarti pemain cukup berdiri di satu titik
-- dan menembak ke satu arah sepanjang match. Lengkungan membuat musuh muncul
-- dari balik rak server, jadi posisi berdiri pemain jadi pilihan.
local LANE_CURVE = 26

-- Waypoint ke-i (1..LANE_WAYPOINTS) untuk sebuah lane, dalam koordinat dunia.
--
-- Jari-jarinya menyusut linear dari tepi ke cincin Core, sementara sudutnya
-- menyimpang mengikuti setengah gelombang sinus: nol di ujung luar, puncak di
-- tengah, nol lagi di ujung dalam. Jadi lane-nya melengkung tapi tetap SAMPAI
-- di tempat yang benar, lengkungan yang tidak kembali ke nol akan membuat
-- musuh tiba di sisi dais yang salah.
function ArenaLayout.laneWaypoint(laneIndex: number, i: number): Vec2
	local baseAngle = ArenaLayout.LANE_ANGLES[laneIndex]
	if baseAngle == nil then
		baseAngle = 0
	end

	local count = ArenaLayout.LANE_WAYPOINTS
	local t = if count > 1 then (i - 1) / (count - 1) else 0

	local radius = ArenaLayout.LANE_OUTER_RADIUS
		+ (ArenaLayout.LANE_INNER_RADIUS - ArenaLayout.LANE_OUTER_RADIUS) * t

	-- Arah lengkungan berganti-ganti antar lane supaya ketiganya tidak terlihat
	-- seperti satu bentuk yang diputar tiga kali.
	local direction = if laneIndex % 2 == 0 then -1 else 1
	local angle = baseAngle + math.sin(t * math.pi) * LANE_CURVE * direction

	local rad = math.rad(angle)
	return { x = math.cos(rad) * radius, z = math.sin(rad) * radius }
end

function ArenaLayout.laneWaypoints(laneIndex: number): { Vec2 }
	local out: { Vec2 } = {}
	for i = 1, ArenaLayout.LANE_WAYPOINTS do
		table.insert(out, ArenaLayout.laneWaypoint(laneIndex, i))
	end
	return out
end

function ArenaLayout.laneCount(): number
	return #ArenaLayout.LANE_ANGLES
end

-- --------------------------------------------------------------------------
-- Jarak ke jalur lane
-- --------------------------------------------------------------------------

local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	if lengthSq < 1e-9 then
		local ox, oz = px - ax, pz - az
		return math.sqrt(ox * ox + oz * oz)
	end
	-- Dijepit ke [0,1] supaya titik di luar ujung segmen diukur ke UJUNGNYA,
	-- bukan ke perpanjangan garis khayal di belakangnya.
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSq, 0, 1)
	local cx, cz = ax + dx * t, az + dz * t
	local ox, oz = px - cx, pz - cz
	return math.sqrt(ox * ox + oz * oz)
end

-- Jarak datar titik mana pun ke jalur lane terdekat. Dipakai untuk dua hal:
-- memilih jenis tile lantai, dan menolak posisi properti yang akan menghalangi
-- musuh.
function ArenaLayout.distanceToLanes(x: number, z: number): number
	local best = math.huge
	for laneIndex = 1, ArenaLayout.laneCount() do
		local points = ArenaLayout.laneWaypoints(laneIndex)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local d = distanceToSegment(x, z, a.x, a.z, b.x, b.z)
			if d < best then
				best = d
			end
		end
	end
	return best
end

-- --------------------------------------------------------------------------
-- Jenis tile
-- --------------------------------------------------------------------------
--
-- Inilah "tileset"-nya: lima jenis ubin berukuran sama yang diulang menutupi
-- seluruh lantai. Yang menentukan jenis tiap petak bukan tangan, tapi fungsi
-- di bawah, dan karena fungsinya murni, hasilnya persis sama setiap kali
-- arena dibangun.

function ArenaLayout.tileKind(gx: number, gz: number): string
	local tile = ArenaLayout.TILE
	local x, z = gx * tile, gz * tile
	local radius = math.sqrt(x * x + z * z)

	if radius <= ArenaLayout.DAIS_RADIUS then
		return "dais"
	end

	-- Lantai bertanda di sepanjang jalur musuh. Ini bukan hiasan: pemain baru
	-- harus bisa melihat dari mana musuh akan datang SEBELUM wave pertama
	-- mulai, tanpa ada yang menjelaskannya.
	if ArenaLayout.distanceToLanes(x, z) <= ArenaLayout.LANE_HALF_WIDTH then
		return "lane"
	end

	-- Tepi arena: ubin gelap, supaya mata membaca batas ruangan.
	if math.abs(gx) >= ArenaLayout.GRID or math.abs(gz) >= ArenaLayout.GRID then
		return "edge"
	end

	-- Sisanya pola papan catur halus. Bedanya dibuat tipis (dua abu-abu yang
	-- berdekatan), supaya lantai punya tekstur tanpa menarik perhatian dari
	-- musuh yang justru harus terlihat.
	if (gx + gz) % 2 == 0 then
		return "plateA"
	end
	return "plateB"
end

-- --------------------------------------------------------------------------
-- Properti
-- --------------------------------------------------------------------------

export type Spot = { x: number, z: number, angle: number }

-- Rak server berdiri melingkar di sektor yang TIDAK dilewati lane. Dihitung,
-- bukan didaftar satu per satu, supaya saat sudut lane diubah rak ikut
-- menyingkir sendiri, daftar manual akan tertinggal dan rak akan berdiri di
-- tengah jalur musuh tanpa ada yang menyadarinya sampai playtest.
function ArenaLayout.rackSpots(): { Spot }
	local out: { Spot } = {}
	for _, radius in { 30, 42, 54 } do
		local step = 18
		for angle = 0, 359, step do
			local rad = math.rad(angle)
			local x, z = math.cos(rad) * radius, math.sin(rad) * radius
			-- Jarak aman: setengah lebar lane ditambah kedalaman rak.
			if ArenaLayout.distanceToLanes(x, z) > ArenaLayout.LANE_HALF_WIDTH + 5 then
				-- Rak menghadap pusat arena.
				table.insert(out, { x = x, z = z, angle = angle + 90 })
			end
		end
	end
	return out
end

-- Platform tinggi di antara lane. Ada supaya gerak vertikal punya guna: dari
-- atas sini pemain melihat dua lane sekaligus, dengan harga tidak bisa cepat
-- turun. Tanpa tempat yang pantas dinaiki, tombol lompat cuma hiasan.
ArenaLayout.PLATFORM_HEIGHT = 6
ArenaLayout.PLATFORM_RADIUS = 38

function ArenaLayout.platformSpots(): { Spot }
	local out: { Spot } = {}
	for _, angle in { 30, 150, 270 } do
		local rad = math.rad(angle)
		table.insert(out, {
			x = math.cos(rad) * ArenaLayout.PLATFORM_RADIUS,
			z = math.sin(rad) * ArenaLayout.PLATFORM_RADIUS,
			angle = angle,
		})
	end
	return out
end

-- Titik pemain diturunkan saat match mulai: di atas dais, di belakang Core
-- relatif terhadap lane pertama.
function ArenaLayout.playerSpawn(): Vec2
	return { x = 0, z = -12 }
end

-- --------------------------------------------------------------------------
-- Pemeriksaan
-- --------------------------------------------------------------------------
--
-- Dijalankan ArenaBuilder sebelum satu Part pun dibuat. Yang dijaga adalah
-- empat hal yang kalau salah TIDAK menimbulkan error, arenanya tetap
-- terbangun, cuma tidak bisa dimainkan:
function ArenaLayout.validate(): (boolean, string?)
	if ArenaLayout.DAIS_RADIUS <= 14 then
		return false, "DAIS_RADIUS harus lebih besar dari Balance.BASE_RING_RADIUS_OUTER (14)"
	end

	for laneIndex = 1, ArenaLayout.laneCount() do
		local points = ArenaLayout.laneWaypoints(laneIndex)
		if #points < 2 then
			return false, string.format("lane %d punya kurang dari 2 waypoint", laneIndex)
		end

		-- Waypoint terakhir harus mendarat di tepi dais, bukan di tengahnya:
		-- musuh yang waypoint terakhirnya ada di dalam dais akan berjalan
		-- menembus Core sebelum berhenti menyerang.
		local last = points[#points]
		local lastRadius = math.sqrt(last.x * last.x + last.z * last.z)
		if lastRadius > ArenaLayout.DAIS_RADIUS + 4 or lastRadius < 10 then
			return false,
				string.format(
					"lane %d berakhir di jari-jari %.1f, harus di antara 10 dan %d",
					laneIndex,
					lastRadius,
					ArenaLayout.DAIS_RADIUS + 4
				)
		end

		-- Waypoint pertama harus di dalam dinding, kalau tidak musuh spawn di
		-- balik tembok dan tidak pernah sampai.
		local first = points[1]
		if math.abs(first.x) >= ArenaLayout.WALL_EXTENT or math.abs(first.z) >= ArenaLayout.WALL_EXTENT then
			return false, string.format("lane %d mulai di luar dinding arena", laneIndex)
		end
	end

	-- Tidak boleh ada rak yang berdiri di jalur musuh.
	for index, spot in ArenaLayout.rackSpots() do
		if ArenaLayout.distanceToLanes(spot.x, spot.z) <= ArenaLayout.LANE_HALF_WIDTH then
			return false, string.format("rak ke-%d berdiri di dalam lane", index)
		end
	end

	-- Platform tidak boleh menggantung di atas lane: musuh yang lewat di
	-- bawahnya jadi tidak bisa ditembak dari mana pun.
	for index, spot in ArenaLayout.platformSpots() do
		if ArenaLayout.distanceToLanes(spot.x, spot.z) <= ArenaLayout.LANE_HALF_WIDTH + 8 then
			return false, string.format("platform ke-%d menggantung di atas lane", index)
		end
	end

	return true, nil
end

return ArenaLayout
