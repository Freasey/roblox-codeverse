--[[
	build_arena.luau — generator arena graybox CodeVerse.

	CARA PAKAI: buka Roblox Studio, buka command bar (View > Command Bar),
	tempel SELURUH isi file ini, tekan Enter. Script ini membangun
	`Workspace.Arena` secara terprogram lalu memilihnya, supaya kamu bisa
	langsung klik kanan > Save to File > `assets/Arena.rbxmx`.
	Langkah lengkapnya ada di `docs/ARENA.md`.

	Ini BUKAN modul dan BUKAN script yang di-sync Rojo — folder `scripts/`
	tidak di-mount di `default.project.json`. File ini alat sekali pakai.

	Hierarki yang dihasilkan mengikuti tabel di `docs/DEVELOPMENT_PLAN.md`
	bagian 3.4:

		Arena/
			CoreServer           Model, PrimaryPart di-set, target musuh
			Lanes/
				Lane1/1, /2, ... Part waypoint berurutan, terakhir dekat Core
				Lane2/1, /2, ...
			PlayerSpawn          SpawnLocation saat match
			Graybox/             lantai + dinding + strip penanda lane

	Nama Part waypoint HARUS string angka berurutan ("1", "2", ...) dari titik
	spawn musuh menuju Core: kode M1 men-sort waypoint secara numerik dari nama
	ini, karena urutan `GetChildren()` tidak dijamin.

	Script ini idempoten: kalau `Workspace.Arena` sudah ada, dia dihapus dulu.
	Jadi aman dijalankan berkali-kali sambil menyetel angka di bawah.
]]

-- Setel true kalau mau melihat waypoint saat debugging. Untuk arena yang
-- disimpan ke `assets/Arena.rbxmx` biarkan false — waypoint itu penanda,
-- bukan geometry.
local DEBUG_VISIBLE_WAYPOINTS = false

-- ---------------------------------------------------------------------------
-- Konstanta: semua angka yang mungkin mau kamu setel ada di blok ini.
-- ---------------------------------------------------------------------------

local ARENA_NAME = "Arena"

-- Core Server. Y-nya dianggap permukaan lantai, dan lantai + dinding dibangun
-- relatif ke titik ini, jadi seluruh arena ikut kalau kamu memindahkannya.
local CORE_POSITION = Vector3.new(0, 0, 0)
local CORE_BASE_SIZE = Vector3.new(24, 2, 24) -- alas, biar Core kelihatan duduk
local CORE_SIZE = Vector3.new(14, 18, 14) -- ini yang jadi PrimaryPart

-- Lantai & dinding. Lantai 240x240 cukup lega untuk 4 pemain bergerak.
local FLOOR_SIZE = Vector3.new(240, 4, 240)
local WALL_HEIGHT = 20
local WALL_THICKNESS = 4

-- Lane. Waypoint ditaruh pada satu garis lurus dari arah datang musuh menuju
-- Core: waypoint bernomor terakhir berada CORE_CLEARANCE stud dari pusat Core,
-- dan tiap waypoint sebelumnya mundur WAYPOINT_SPACING stud.
--
-- Jarak waypoint pertama ke Core = CORE_CLEARANCE
--   + (WAYPOINTS_PER_LANE - 1) * WAYPOINT_SPACING = 144 stud.
-- Lane-nya diagonal, jadi itu ~102 stud di tiap sumbu — masih di dalam
-- setengah-lantai 120 stud. Kalau kamu menambah waypoint atau jaraknya,
-- besarkan juga FLOOR_SIZE; kalau tidak, waypoint pertama jatuh di luar dinding.
--
-- CORE_CLEARANCE juga tidak boleh lebih kecil dari diagonal alas Core
-- (CORE_BASE_SIZE.X / 2 * sqrt(2) ~ 17 stud), kalau tidak waypoint terakhir
-- menembus alas dan musuh harus memanjat pedestal.
local WAYPOINTS_PER_LANE = 7
local WAYPOINT_SPACING = 20
local CORE_CLEARANCE = 24
local WAYPOINT_HEIGHT = 2 -- tinggi titik tengah waypoint di atas lantai
local WAYPOINT_SIZE = Vector3.new(4, 4, 4)
local LANE_WIDTH = 16 -- lebar strip penanda lane yang digambar di lantai

-- Arah datang tiap lane, relatif Core. Tidak perlu dinormalisasi. Dua lane di
-- bawah datang dari dua sudut berbeda (barat-laut dan timur-laut) dan berakhir
-- di dekat Core dari arah masing-masing.
local LANES = {
	{ name = "Lane1", direction = Vector3.new(-1, 0, -1), color = Color3.fromRGB(205, 140, 60) },
	{ name = "Lane2", direction = Vector3.new(1, 0, -1), color = Color3.fromRGB(90, 190, 140) },
}

-- SpawnLocation saat match. Ditaruh di sisi berlawanan dari kedua lane, jadi
-- pemain muncul di belakang Core dan tidak nongol di tengah jalur musuh.
local PLAYER_SPAWN_OFFSET = Vector3.new(0, 0, 44)
local PLAYER_SPAWN_SIZE = Vector3.new(14, 1, 14)

local FLOOR_COLOR = Color3.fromRGB(72, 78, 88)
local WALL_COLOR = Color3.fromRGB(52, 57, 66)
local CORE_BASE_COLOR = Color3.fromRGB(60, 65, 75)
local CORE_COLOR = Color3.fromRGB(85, 160, 230)
local WAYPOINT_COLOR = Color3.fromRGB(255, 240, 90)
local PLAYER_SPAWN_COLOR = Color3.fromRGB(120, 200, 255)

-- ---------------------------------------------------------------------------
-- Pembangunan
-- ---------------------------------------------------------------------------

local function makePart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Penanda: Part yang cuma dibaca kode, tidak boleh kelihatan atau menghalangi.
local function makeMarker(name, size, cframe, color, parent)
	local marker = makePart(name, size, cframe, color, parent)
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	return marker
end

local existing = workspace:FindFirstChild(ARENA_NAME)
if existing then
	existing:Destroy()
	print("[build_arena] Workspace." .. ARENA_NAME .. " yang lama dihapus")
end

local arena = Instance.new("Model")
arena.Name = ARENA_NAME

-- Lantai & dinding -----------------------------------------------------------

local graybox = Instance.new("Folder")
graybox.Name = "Graybox"
graybox.Parent = arena

local groundY = CORE_POSITION.Y
local floorCenter = Vector3.new(CORE_POSITION.X, groundY - FLOOR_SIZE.Y / 2, CORE_POSITION.Z)
makePart("Floor", FLOOR_SIZE, CFrame.new(floorCenter), FLOOR_COLOR, graybox)

local wallCenterY = groundY + WALL_HEIGHT / 2
local wallOffsetX = FLOOR_SIZE.X / 2 + WALL_THICKNESS / 2
local wallOffsetZ = FLOOR_SIZE.Z / 2 + WALL_THICKNESS / 2
local wallSpanX = Vector3.new(FLOOR_SIZE.X + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS)
local wallSpanZ = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, FLOOR_SIZE.Z + WALL_THICKNESS * 2)

local walls = {
	{ name = "WallNorth", size = wallSpanX, offset = Vector3.new(0, 0, -wallOffsetZ) },
	{ name = "WallSouth", size = wallSpanX, offset = Vector3.new(0, 0, wallOffsetZ) },
	{ name = "WallWest", size = wallSpanZ, offset = Vector3.new(-wallOffsetX, 0, 0) },
	{ name = "WallEast", size = wallSpanZ, offset = Vector3.new(wallOffsetX, 0, 0) },
}

for _, wall in walls do
	local center = Vector3.new(CORE_POSITION.X, wallCenterY, CORE_POSITION.Z) + wall.offset
	makePart(wall.name, wall.size, CFrame.new(center), WALL_COLOR, graybox)
end

-- Core Server ----------------------------------------------------------------

local coreServer = Instance.new("Model")
coreServer.Name = "CoreServer"
coreServer.Parent = arena

local baseCenter = CORE_POSITION + Vector3.new(0, CORE_BASE_SIZE.Y / 2, 0)
makePart("Base", CORE_BASE_SIZE, CFrame.new(baseCenter), CORE_BASE_COLOR, coreServer)

local coreCenter = CORE_POSITION + Vector3.new(0, CORE_BASE_SIZE.Y + CORE_SIZE.Y / 2, 0)
local corePart = makePart("Core", CORE_SIZE, CFrame.new(coreCenter), CORE_COLOR, coreServer)
corePart.Material = Enum.Material.Neon

-- Wajib: kode M1 memakai PrimaryPart sebagai target musuh.
coreServer.PrimaryPart = corePart

-- Lane & waypoint ------------------------------------------------------------

local lanes = Instance.new("Folder")
lanes.Name = "Lanes"
lanes.Parent = arena

local farthestDistance = CORE_CLEARANCE + (WAYPOINTS_PER_LANE - 1) * WAYPOINT_SPACING

for _, lane in LANES do
	local laneFolder = Instance.new("Folder")
	laneFolder.Name = lane.name
	laneFolder.Parent = lanes

	local heading = lane.direction.Unit

	for index = 1, WAYPOINTS_PER_LANE do
		-- index 1 = terjauh (titik spawn musuh), index terakhir = dekat Core.
		local distance = CORE_CLEARANCE + (WAYPOINTS_PER_LANE - index) * WAYPOINT_SPACING
		local position = CORE_POSITION + heading * distance + Vector3.new(0, WAYPOINT_HEIGHT, 0)

		local waypoint = makeMarker(
			tostring(index),
			WAYPOINT_SIZE,
			CFrame.new(position),
			WAYPOINT_COLOR,
			laneFolder
		)
		if DEBUG_VISIBLE_WAYPOINTS then
			waypoint.Material = Enum.Material.Neon
			waypoint.Transparency = 0.35
		else
			waypoint.Transparency = 1
		end
	end

	-- Strip tipis di lantai supaya jalur musuh kelihatan waktu playtest. Bukan
	-- penanda yang dibaca kode, cuma geometry graybox.
	local stripLength = farthestDistance + WAYPOINT_SPACING / 2
	local stripY = groundY + 0.1
	local stripCenter = CORE_POSITION + heading * (stripLength / 2) + Vector3.new(0, stripY, 0)
	local stripTarget = Vector3.new(CORE_POSITION.X, stripY, CORE_POSITION.Z)
	makeMarker(
		lane.name .. "Floor",
		Vector3.new(LANE_WIDTH, 0.2, stripLength),
		CFrame.lookAt(stripCenter, stripTarget),
		lane.color,
		graybox
	)
end

-- PlayerSpawn ----------------------------------------------------------------

local playerSpawn = Instance.new("SpawnLocation")
playerSpawn.Name = "PlayerSpawn"
playerSpawn.Size = PLAYER_SPAWN_SIZE
playerSpawn.CFrame =
	CFrame.new(CORE_POSITION + PLAYER_SPAWN_OFFSET + Vector3.new(0, PLAYER_SPAWN_SIZE.Y / 2, 0))
playerSpawn.Anchored = true
playerSpawn.Neutral = true
playerSpawn.Duration = 0 -- tanpa forcefield
playerSpawn.Color = PLAYER_SPAWN_COLOR
playerSpawn.Material = Enum.Material.SmoothPlastic
playerSpawn.TopSurface = Enum.SurfaceType.Smooth
playerSpawn.BottomSurface = Enum.SurfaceType.Smooth
playerSpawn.Parent = arena

arena.PrimaryPart = corePart
arena.Parent = workspace

-- Pilih hasilnya supaya langsung bisa klik kanan > Save to File.
local selected, selectError = pcall(function()
	game:GetService("Selection"):Set({ arena })
end)
if not selected then
	warn("[build_arena] gagal memilih Arena otomatis: " .. tostring(selectError))
end

print(
	string.format(
		"[build_arena] %s dibangun: %d lane x %d waypoint. Waypoint pertama %d stud dari Core, "
			.. "yang terakhir %d stud. DEBUG_VISIBLE_WAYPOINTS = %s",
		ARENA_NAME,
		#LANES,
		WAYPOINTS_PER_LANE,
		farthestDistance,
		CORE_CLEARANCE,
		tostring(DEBUG_VISIBLE_WAYPOINTS)
	)
)
print(
	"[build_arena] Berikutnya: klik kanan Workspace."
		.. ARENA_NAME
		.. " > Save to File > simpan sebagai assets/Arena.rbxmx"
)
