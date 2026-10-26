--!strict
-- ArenaBuilder.luau: membangun arena dan lobby dari ArenaLayout.
--
-- Hasil bangunannya memenuhi kontrak yang dibaca MapService persis: Model
-- `Arena` berisi `CoreServer` (dengan PrimaryPart), folder `Lanes` berisi
-- `Lane1..n` yang masing-masing berisi Part bernama "1".."7", dan Part
-- `PlayerSpawn`. Plus Model `Lobby` berisi `ReadyPad` dan `SpawnLocation`.
--
-- BANGUN DULU, TUKAR BELAKANGAN
--
-- Arena lama TIDAK dihapus di awal. Yang baru dirakit lebih dulu di luar
-- Workspace (Parent = nil), diperiksa, baru ditukar. Alasannya: kalau builder
-- ini error di tengah jalan, satu nama Enum salah ketik, satu pembagian nol
--, urutan "hapus dulu baru bangun" meninggalkan place TANPA lantai sama
-- sekali, dan pemain jatuh selamanya tanpa petunjuk apa pun tentang
-- penyebabnya. Dengan urutan ini, kegagalan apa pun meninggalkan arena lama
-- tetap utuh dan satu warn yang menyebut apa yang salah.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ArenaLayout = require(Shared.Modules.ArenaLayout)
local Config = require(Shared.Config)

local ArenaBuilder = {}

local built = false

-- --------------------------------------------------------------------------
-- Palet bangunan
-- --------------------------------------------------------------------------
--
-- Warna lantai sengaja gelap dan berdekatan satu sama lain. Arena adalah LATAR;
-- yang harus menarik mata adalah musuh (warna panas) dan pemain (sian). Lantai
-- yang berwarna kuat akan bersaing dengan keduanya dan membuat wave akhir,
-- saat ada 40 musuh di layar, jadi tidak terbaca.

type TileStyle = { color: Color3, material: Enum.Material, height: number }

local TILE_STYLES: { [string]: TileStyle } = {
	dais = {
		color = Color3.fromRGB(46, 54, 68),
		material = Enum.Material.Metal,
		height = ArenaLayout.DAIS_HEIGHT,
	},
	lane = {
		color = Color3.fromRGB(58, 48, 34),
		material = Enum.Material.Pebble,
		height = 1,
	},
	edge = {
		color = Color3.fromRGB(20, 23, 29),
		material = Enum.Material.Slate,
		height = 1,
	},
	plateA = {
		color = Color3.fromRGB(34, 38, 47),
		material = Enum.Material.Metal,
		height = 1,
	},
	plateB = {
		color = Color3.fromRGB(29, 33, 41),
		material = Enum.Material.Metal,
		height = 1,
	},
}

local ACCENT = Color3.fromRGB(0, 212, 255)
local ACCENT_WARM = Color3.fromRGB(255, 160, 50)
local STRUCTURE = Color3.fromRGB(26, 30, 38)

-- Pembuat Part yang dipakai seluruh file. Semua bangunan Anchored: tidak ada
-- satu pun bagian arena yang boleh jatuh, terdorong pemain, atau ikut simulasi
-- fisika. Satu Part arena yang lupa di-anchor akan tergeser pelan-pelan
-- sepanjang match oleh tabrakan, dan lantai yang bergeser meninggalkan celah
-- yang membuat pemain jatuh keluar peta.
local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Part hias yang tidak boleh ikut tabrakan maupun raycast. Dipakai untuk garis
-- neon dan penanda: tanpa ini, strip neon setebal 0.3 stud di dinding bisa
-- menghentikan bidikan pemain, dan penyebabnya praktis mustahil ditebak.
local function decor(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = part(name, size, cf, color, material, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- --------------------------------------------------------------------------
-- Lantai
-- --------------------------------------------------------------------------

local function buildFloor(parent: Instance)
	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = parent

	local size = ArenaLayout.TILE
	for gx = -ArenaLayout.GRID, ArenaLayout.GRID do
		for gz = -ArenaLayout.GRID, ArenaLayout.GRID do
			local kind = ArenaLayout.tileKind(gx, gz)
			local style = TILE_STYLES[kind] or TILE_STYLES.plateA

			-- Permukaan atas SELALU di y = tinggi tile, dan Part diletakkan
			-- setengah tingginya di bawah itu. Itu yang membuat tile dais yang
			-- lebih tebal tetap rata dengan tile biasa di sisi bawahnya, bukan
			-- mengambang.
			local top = if kind == "dais" then ArenaLayout.DAIS_HEIGHT else 0
			local cf = CFrame.new(gx * size, top - style.height / 2, gz * size)

			-- Celah 0.08 stud antar tile. Ini yang membuat lantai terbaca
			-- sebagai UBIN dan bukan sebagai satu bidang besar berwarna
			-- belang: garis bayangan tipis di tiap sambungan.
			local tile = part(
				string.format("T%d_%d", gx, gz),
				Vector3.new(size - 0.08, style.height, size - 0.08),
				cf,
				style.color,
				style.material,
				tiles
			)
			tile.CastShadow = false

			if kind == "lane" then
				-- Garis peringatan di tengah ubin lane, searah jalur.
				decor(
					"Stripe",
					Vector3.new(size - 3, 0.06, size - 3),
					cf * CFrame.new(0, style.height / 2 + 0.03, 0),
					ACCENT_WARM,
					Enum.Material.Neon,
					tiles
				).Transparency =
					0.55
			end
		end
	end
end

-- --------------------------------------------------------------------------
-- Dinding
-- --------------------------------------------------------------------------

local function buildWalls(parent: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = parent

	local size = ArenaLayout.TILE
	local extent = ArenaLayout.WALL_EXTENT
	local height = ArenaLayout.WALL_HEIGHT

	for i = -ArenaLayout.GRID, ArenaLayout.GRID do
		local along = i * size
		for _, spec in
			{
				{ cf = CFrame.new(along, height / 2, -extent), flip = false },
				{ cf = CFrame.new(along, height / 2, extent), flip = false },
				{ cf = CFrame.new(-extent, height / 2, along), flip = true },
				{ cf = CFrame.new(extent, height / 2, along), flip = true },
			}
		do
			local dims = if spec.flip
				then Vector3.new(2, height, size)
				else Vector3.new(size, height, 2)
			local panel = part("Panel", dims, spec.cf, STRUCTURE, Enum.Material.Metal, walls)

			-- Bagian atas dinding dibuat kaca. Inilah lapisan yang memisahkan
			-- arena dari latar belakangnya: lewat kaca ini terlihat deretan
			-- menara server di kejauhan (SceneryService), jadi ruangan terbaca
			-- sebagai SATU LANTAI di dalam gedung besar, bukan sebagai kotak
			-- tertutup. Dinding masif setinggi penuh menghilangkan kedalaman
			-- itu sepenuhnya.
			if math.abs(i) % 2 == 1 then
				panel.Size = if spec.flip
					then Vector3.new(2, height * 0.55, size)
					else Vector3.new(size, height * 0.55, 2)
				panel.CFrame = spec.cf * CFrame.new(0, -height * 0.225, 0)

				local glass = if spec.flip
					then Vector3.new(1, height * 0.45, size - 0.6)
					else Vector3.new(size - 0.6, height * 0.45, 1)
				local pane = part(
					"Glass",
					glass,
					spec.cf * CFrame.new(0, height * 0.275, 0),
					Color3.fromRGB(120, 170, 200),
					Enum.Material.Glass,
					walls
				)
				pane.Transparency = 0.82
				pane.CastShadow = false
			end
		end
	end

	-- Garis neon membujur sepanjang tiap sisi, DUA Part per sisi alih-alih dua
	-- per panel. Bukan sekadar hemat: strip yang dipotong-potong per panel
	-- meninggalkan celah gelap di tiap sambungan, dan garis putus-putus tidak
	-- memberi acuan horizon yang jadi alasan strip ini ada.
	local span = ArenaLayout.GRID * size * 2 + size
	for _, y in { height * 0.2, height * 0.49 } do
		for _, spec in
			{
				{ at = CFrame.new(0, y, -extent + 1.3), flip = false },
				{ at = CFrame.new(0, y, extent - 1.3), flip = false },
				{ at = CFrame.new(-extent + 1.3, y, 0), flip = true },
				{ at = CFrame.new(extent - 1.3, y, 0), flip = true },
			}
		do
			decor(
				"WallLight",
				if spec.flip then Vector3.new(0.3, 0.4, span) else Vector3.new(span, 0.4, 0.3),
				spec.at,
				ACCENT,
				Enum.Material.Neon,
				walls
			)
		end
	end
end

-- --------------------------------------------------------------------------
-- Core Server
-- --------------------------------------------------------------------------

local function buildCore(parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CoreServer"
	model.Parent = parent

	local baseY = ArenaLayout.DAIS_HEIGHT

	part(
		"Base",
		Vector3.new(16, 2, 16),
		CFrame.new(0, baseY + 1, 0),
		Color3.fromRGB(38, 44, 56),
		Enum.Material.DiamondPlate,
		model
	)

	-- Empat pilar penyangga, satu di tiap sudut base.
	for _, offset in
		{
			Vector3.new(6, 0, 6),
			Vector3.new(-6, 0, 6),
			Vector3.new(6, 0, -6),
			Vector3.new(-6, 0, -6),
		}
	do
		part(
			"Pillar",
			Vector3.new(1.6, 7, 1.6),
			CFrame.new(Vector3.new(0, baseY + 5.5, 0) + offset),
			STRUCTURE,
			Enum.Material.Metal,
			model
		)
	end

	-- Core itu sendiri. Ini PrimaryPart-nya, dan WARNANYA DIKENDALIKAN
	-- CoreService: `bindVisual` menyimpan warna ini sebagai warna "sehat" lalu
	-- melerpnya ke merah seiring HP turun. Jadi jangan menaruh Texture atau
	-- Decal di Part ini, yang terlihat pemain harus warnanya, bukan gambar
	-- yang menutupinya.
	local core = part(
		"Core",
		Vector3.new(7, 9, 7),
		CFrame.new(0, baseY + 9.5, 0),
		Color3.fromRGB(70, 200, 255),
		Enum.Material.Neon,
		model
	)
	model.PrimaryPart = core

	-- Cangkang luar setengah tembus: membuat Core terlihat seperti benda
	-- berlapis, dan menahan silau neon murni yang kalau dibiarkan polos akan
	-- jadi titik paling terang di layar sepanjang match.
	local shell = decor(
		"Shell",
		Vector3.new(9.5, 11.5, 9.5),
		CFrame.new(0, baseY + 9.5, 0),
		Color3.fromRGB(120, 180, 220),
		Enum.Material.Glass,
		model
	)
	shell.Transparency = 0.72

	local light = Instance.new("PointLight")
	light.Brightness = 2.4
	light.Range = 42
	light.Color = ACCENT
	light.Parent = core

	return model, core
end

-- --------------------------------------------------------------------------
-- Lane: penanda waypoint dan gerbang masuk
-- --------------------------------------------------------------------------

local function buildLanes(parent: Instance)
	local lanes = Instance.new("Folder")
	lanes.Name = "Lanes"
	lanes.Parent = parent

	local gates = Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = parent

	for laneIndex = 1, ArenaLayout.laneCount() do
		local folder = Instance.new("Folder")
		folder.Name = string.format("Lane%d", laneIndex)
		folder.Parent = lanes

		local points = ArenaLayout.laneWaypoints(laneIndex)
		for i, point in points do
			-- Penanda waypoint TIDAK TERLIHAT dan tidak ikut tabrakan. Dia cuma
			-- koordinat yang kebetulan berbentuk Part, karena MapService
			-- membaca `.Position` dari Part. Namanya WAJIB "1".."n" tanpa
			-- bolong, itu kontrak Lanes.luau, bukan selera penamaan.
			local marker = part(
				tostring(i),
				Vector3.new(2, 2, 2),
				CFrame.new(point.x, 2, point.z),
				ACCENT,
				Enum.Material.Neon,
				folder
			)
			marker.Transparency = 1
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
			marker.CastShadow = false
		end

		-- Gerbang di waypoint pertama: dari sinilah musuh muncul, jadi tempat
		-- itu harus punya penanda yang terbaca dari seberang arena.
		local entry = points[1]
		local inward = CFrame.lookAt(Vector3.new(entry.x, 0, entry.z), Vector3.new(0, 0, 0))
		for _, side in { -5, 5 } do
			part(
				"GatePost",
				Vector3.new(1.6, 14, 1.6),
				inward * CFrame.new(side, 7, 0),
				STRUCTURE,
				Enum.Material.Metal,
				gates
			)
		end
		part(
			"GateBeam",
			Vector3.new(11.6, 1.6, 1.6),
			inward * CFrame.new(0, 14, 0),
			STRUCTURE,
			Enum.Material.Metal,
			gates
		)
		decor(
			"GateLight",
			Vector3.new(10, 0.5, 0.6),
			inward * CFrame.new(0, 12.9, 0),
			ACCENT_WARM,
			Enum.Material.Neon,
			gates
		)
	end
end

-- --------------------------------------------------------------------------
-- Properti: rak server dan platform
-- --------------------------------------------------------------------------

local function buildRacks(parent: Instance)
	local props = Instance.new("Folder")
	props.Name = "Racks"
	props.Parent = parent

	for index, spot in ArenaLayout.rackSpots() do
		local cf = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(-spot.angle), 0)

		part(
			string.format("Rack%d", index),
			Vector3.new(6, 9, 3),
			cf * CFrame.new(0, 4.5, 0),
			STRUCTURE,
			Enum.Material.DiamondPlate,
			props
		)

		-- Tiga baris lampu indikator di muka rak. Warnanya berselang-seling
		-- supaya deretan rak tidak terbaca sebagai satu benda panjang.
		for row = 1, 3 do
			local lit = (index + row) % 3 ~= 0
			local strip = decor(
				"Indicator",
				Vector3.new(4.4, 0.3, 0.2),
				cf * CFrame.new(0, 1.8 + row * 2.1, -1.6),
				if lit then ACCENT else ACCENT_WARM,
				Enum.Material.Neon,
				props
			)
			strip.Transparency = if lit then 0.1 else 0.45
		end
	end
end

local function buildPlatforms(parent: Instance)
	local props = Instance.new("Folder")
	props.Name = "Platforms"
	props.Parent = parent

	local height = ArenaLayout.PLATFORM_HEIGHT

	for index, spot in ArenaLayout.platformSpots() do
		local facing = CFrame.lookAt(Vector3.new(spot.x, 0, spot.z), Vector3.new(0, 0, 0))

		part(
			string.format("Deck%d", index),
			Vector3.new(20, 1.2, 14),
			facing * CFrame.new(0, height, 0),
			Color3.fromRGB(40, 46, 57),
			Enum.Material.DiamondPlate,
			props
		)

		-- Pagar rendah di tiga sisi; sisi yang menghadap pusat dibiarkan
		-- terbuka supaya pemain bisa melompat turun ke arah pertempuran tanpa
		-- memutar lewat tangga.
		for _, rail in
			{
				{ size = Vector3.new(20, 2.4, 0.6), at = CFrame.new(0, height + 1.8, 7) },
				{ size = Vector3.new(0.6, 2.4, 14), at = CFrame.new(10, height + 1.8, 0) },
				{ size = Vector3.new(0.6, 2.4, 14), at = CFrame.new(-10, height + 1.8, 0) },
			}
		do
			part("Rail", rail.size, facing * rail.at, STRUCTURE, Enum.Material.Metal, props)
		end

		decor(
			"DeckLight",
			Vector3.new(18, 0.25, 0.4),
			facing * CFrame.new(0, height + 0.7, -6.6),
			ACCENT,
			Enum.Material.Neon,
			props
		)

		-- Tangga dari balok bertingkat, BUKAN bidang miring. Balok tidak punya
		-- ambiguitas arah: bidang miring yang tandanya terbalik menghasilkan
		-- tanjakan yang menukik ke bawah, dan itu cuma ketahuan saat playtest.
		-- Empat anak tangga setinggi 1.5 stud masih bisa dinaiki Humanoid
		-- tanpa melompat.
		local steps = 4
		for stepIndex = 1, steps do
			local y = height - (stepIndex - 1) * (height / steps)
			part(
				"Step",
				Vector3.new(9, y, 3),
				facing * CFrame.new(0, y / 2, 7 + stepIndex * 3),
				Color3.fromRGB(34, 39, 49),
				Enum.Material.Metal,
				props
			)
		end
	end
end

-- --------------------------------------------------------------------------
-- Lobby
-- --------------------------------------------------------------------------
--
-- Lobby sebelumnya TIDAK ADA di place ini, dan itu terlihat sebagai warn
-- "Workspace.Lobby tidak ada" tiap kali server boot. Yang hilang bukan cuma
-- hiasan: `MatchService.placeCharacter` memindahkan pemain ke lobby setiap
-- kali dia bukan peserta match atau match sudah selesai, dan tanpa Lobby
-- fungsinya jatuh ke titik spawn arena, jadi pemain yang menonton berdiri di
-- tengah pertempuran yang tidak bisa dia ikuti.

local LOBBY_CENTER = Vector3.new(0, 0, 420)

local function buildLobby(): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	part(
		"Floor",
		Vector3.new(80, 2, 80),
		CFrame.new(LOBBY_CENTER + Vector3.new(0, -1, 0)),
		Color3.fromRGB(34, 38, 47),
		Enum.Material.Metal,
		lobby
	)

	for _, spec in
		{
			{ size = Vector3.new(80, 18, 2), at = Vector3.new(0, 9, -40) },
			{ size = Vector3.new(80, 18, 2), at = Vector3.new(0, 9, 40) },
			{ size = Vector3.new(2, 18, 80), at = Vector3.new(-40, 9, 0) },
			{ size = Vector3.new(2, 18, 80), at = Vector3.new(40, 9, 0) },
		}
	do
		part(
			"Wall",
			spec.size,
			CFrame.new(LOBBY_CENTER + spec.at),
			STRUCTURE,
			Enum.Material.Metal,
			lobby
		)
	end

	-- ReadyPad: lingkaran menyala di tengah. Dia penanda tempat, bukan tombol
	--, tombol Ready yang sebenarnya ada di UI LobbyController. Dibuat sebagai
	-- Part karena MapService memang mencarinya, dan karena tempat berkumpul
	-- yang terlihat membuat pemain saling menunggu di titik yang sama.
	local pad = part(
		"ReadyPad",
		Vector3.new(18, 0.4, 18),
		CFrame.new(LOBBY_CENTER + Vector3.new(0, 0.2, 0)),
		ACCENT,
		Enum.Material.Neon,
		lobby
	)
	pad.Shape = Enum.PartType.Cylinder
	-- Cylinder bersumbu X, jadi harus direbahkan untuk jadi piringan datar.
	pad.CFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 0.2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	pad.Size = Vector3.new(0.4, 18, 18)
	pad.Transparency = 0.35
	pad.CanCollide = false

	local padLight = Instance.new("PointLight")
	padLight.Brightness = 2
	padLight.Range = 30
	padLight.Color = ACCENT
	padLight.Parent = pad

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 0.5, 14))
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(40, 46, 57)
	spawn.Material = Enum.Material.Metal
	spawn.Transparency = 0.2
	-- Tanpa ini pemain yang mati di arena akan "respawn" di titik yang diatur
	-- Roblox sendiri, bukan di lobby.
	spawn.Neutral = true
	spawn.Parent = lobby

	return lobby
end

-- --------------------------------------------------------------------------
-- Perakitan
-- --------------------------------------------------------------------------

local function assembleArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	buildFloor(arena)
	buildWalls(arena)
	buildLanes(arena)
	buildRacks(arena)
	buildPlatforms(arena)
	local _core, corePart = buildCore(arena)

	local spawnPoint = ArenaLayout.playerSpawn()
	local marker = part(
		"PlayerSpawn",
		Vector3.new(6, 1, 6),
		CFrame.new(spawnPoint.x, ArenaLayout.DAIS_HEIGHT + 0.5, spawnPoint.z),
		ACCENT,
		Enum.Material.Neon,
		arena
	)
	marker.Transparency = 0.7
	marker.CanCollide = false
	marker.CanQuery = false

	arena.PrimaryPart = corePart
	return arena
end

-- Memeriksa hasil rakitan terhadap kontrak MapService SEBELUM yang lama
-- dihapus. Tanpa langkah ini, kesalahan penamaan di builder ini baru ketahuan
-- sebagai "Workspace.Arena.CoreServer tidak ada" dari MapService, setelah
-- arena lama terlanjur hilang.
local function verify(arena: Model): (boolean, string?)
	local core = arena:FindFirstChild("CoreServer")
	if core == nil or not core:IsA("Model") or core.PrimaryPart == nil then
		return false, "CoreServer atau PrimaryPart-nya tidak terbentuk"
	end

	local lanes = arena:FindFirstChild("Lanes")
	if lanes == nil then
		return false, "folder Lanes tidak terbentuk"
	end

	local laneCount = 0
	for _, folder in lanes:GetChildren() do
		laneCount += 1
		local markers = 0
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				markers += 1
			end
		end
		if markers ~= ArenaLayout.LANE_WAYPOINTS then
			return false,
				string.format(
					"%s punya %d waypoint, harus %d",
					folder.Name,
					markers,
					ArenaLayout.LANE_WAYPOINTS
				)
		end
	end
	if laneCount ~= ArenaLayout.laneCount() then
		return false,
			string.format("terbentuk %d lane, harus %d", laneCount, ArenaLayout.laneCount())
	end

	if arena:FindFirstChild("PlayerSpawn") == nil then
		return false, "PlayerSpawn tidak terbentuk"
	end

	return true, nil
end

function ArenaBuilder.build(): boolean
	if built then
		return true
	end

	-- Arena yang SUDAH dipanggang ke dalam file place tidak dibangun ulang.
	--
	-- `tools/bake.py` menjalankan builder ini di luar Roblox lalu menulis
	-- hasilnya langsung ke .rbxl, supaya arena sudah terlihat di Studio
	-- sebelum Play ditekan, untuk screenshot, dan supaya siapa pun yang
	-- membuka file ini tidak melihat peta kosong.
	--
	-- Penandanya folder `Tiles`, bukan keberadaan `Arena` saja: place lama
	-- juga punya Model bernama Arena (graybox dengan folder `Graybox`), dan
	-- memakai nama Arena sebagai penanda akan membuat arena graybox itu
	-- dibiarkan hidup selamanya.
	local existing = Workspace:FindFirstChild("Arena")
	if existing ~= nil and existing:FindFirstChild("Tiles") ~= nil then
		built = true
		print(
			string.format("[%s] arena sudah ada di place, pembangunan dilewati", Config.GAME_NAME)
		)
		return true
	end

	local layoutOk, layoutErr = ArenaLayout.validate()
	if not layoutOk then
		warn(
			string.format(
				"[%s] tata letak arena tidak valid: %s",
				Config.GAME_NAME,
				tostring(layoutErr)
			)
		)
		return false
	end

	local ok, result = pcall(assembleArena)
	if not ok then
		warn(string.format("[%s] arena gagal dirakit: %s", Config.GAME_NAME, tostring(result)))
		return false
	end
	local arena = result :: Model

	local verified, reason = verify(arena)
	if not verified then
		arena:Destroy()
		warn(
			string.format(
				"[%s] arena hasil rakitan ditolak: %s",
				Config.GAME_NAME,
				tostring(reason)
			)
		)
		return false
	end

	local lobbyOk, lobbyResult = pcall(buildLobby)
	if not lobbyOk then
		arena:Destroy()
		warn(string.format("[%s] lobby gagal dirakit: %s", Config.GAME_NAME, tostring(lobbyResult)))
		return false
	end
	local lobby = lobbyResult :: Model

	-- Baru sekarang yang lama dibongkar. Baseplate dan SpawnLocation bawaan
	-- ikut dibuang: keduanya peninggalan template place kosong, dan Baseplate
	-- yang tertinggal akan membentang di bawah arena sebagai lantai kedua yang
	-- menangkap pemain yang seharusnya jatuh.
	for _, name in { "Arena", "Lobby", "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old ~= nil then
			old:Destroy()
		end
	end

	arena.Parent = Workspace
	lobby.Parent = Workspace
	built = true

	local tiles = arena:FindFirstChild("Tiles")
	print(
		string.format(
			"[%s] arena dibangun: %d tile, %d lane, %d rak, %d platform",
			Config.GAME_NAME,
			if tiles ~= nil then #tiles:GetChildren() else 0,
			ArenaLayout.laneCount(),
			#ArenaLayout.rackSpots(),
			#ArenaLayout.platformSpots()
		)
	)
	return true
end

return ArenaBuilder
