--[[
	build_lobby.luau — generator area lobby CodeVerse.

	CARA PAKAI: buka Roblox Studio, buka command bar (View > Command Bar),
	tempel SELURUH isi file ini, tekan Enter. Script ini membangun
	`Workspace.Lobby` secara terprogram lalu memilihnya, supaya kamu bisa
	langsung klik kanan > Save to File > `assets/Lobby.rbxmx`.
	Langkah lengkapnya ada di `docs/TEST_CASES.md` bagian 2.

	Ini BUKAN modul dan BUKAN script yang di-sync Rojo — folder `scripts/`
	tidak di-mount di `default.project.json`. File ini alat sekali pakai,
	pasangan dari `scripts/build_arena.luau`.

	Hierarki yang dihasilkan mengikuti tabel di `docs/DEVELOPMENT_PLAN.md`
	bagian 3.4:

		Lobby/
			SpawnLocation        Part spawn default, dibaca MapService
			ReadyPad             Part penanda siap, dibaca MapService
			Graybox/             lantai, dinding, dan papan nama

	DUA NAMA DI ATAS WAJIB PERSIS. `MapService.getLobby()` mencari
	`Workspace.Lobby.SpawnLocation` dan `Workspace.Lobby.ReadyPad` dengan
	FindFirstChild, jadi salah satu huruf saja membuat lobby terbaca tidak
	lengkap dan MapService mengeluarkan satu warn soal itu.

	Kenapa lobby dibuat terpisah dari arena dan bukan sekalian di
	build_arena.luau: v1 memakai satu place (bagian 1.1), jadi lobby dan arena
	ada di Workspace yang sama tapi disimpan sebagai dua file. Dua file berarti
	kamu bisa mengubah salah satunya tanpa menimpa yang lain, dan prosedur
	export di bagian 1.4 berlaku per file.

	Script ini idempoten: kalau `Workspace.Lobby` sudah ada, dia dihapus dulu.
	Jadi aman dijalankan berkali-kali sambil menyetel angka di bawah.
]]

-- ---------------------------------------------------------------------------
-- Konstanta: semua angka yang mungkin mau kamu setel ada di blok ini.
-- ---------------------------------------------------------------------------

local LOBBY_NAME = "Lobby"

-- Titik acuan lobby. Seluruh geometry dibangun relatif ke sini, jadi
-- memindahkan satu angka ini memindahkan seluruh lobby.
--
-- Z = 400 menaruh lobby jauh di belakang arena. Arena yang dihasilkan
-- build_arena.luau berpusat di (0, 0, 0) dengan lantai 240x240, jadi tepinya
-- ada di Z = 120. Jarak 400 stud berarti pemain di lobby tidak bisa melihat
-- (atau menyerang) musuh di arena, dan sebaliknya — dan karena keduanya ada di
-- satu place, itu harus diatur dengan jarak, bukan dengan kode.
local LOBBY_POSITION = Vector3.new(0, 0, 400)

local FLOOR_SIZE = Vector3.new(90, 4, 90)
local WALL_HEIGHT = 18
local WALL_THICKNESS = 4

-- SpawnLocation default. Di sinilah pemain muncul saat join dan saat dia
-- ditahan di lobby karena bukan peserta match yang sedang berjalan
-- (bagian 3.3).
local SPAWN_OFFSET = Vector3.new(0, 0, 24)
local SPAWN_SIZE = Vector3.new(14, 1, 14)

-- ReadyPad. Penanda posisi, bukan tombol: tombol Ready yang sesungguhnya ada
-- di UI (`LobbyController`), karena tombol UI bisa dipakai di mobile dan tidak
-- bergantung pada pemain berhasil menginjak satu Part.
local READY_PAD_OFFSET = Vector3.new(0, 0, -20)
local READY_PAD_SIZE = Vector3.new(16, 1, 16)

-- Papan nama. Graybox, cuma supaya lobby tidak terlihat seperti kotak kosong.
local SIGN_OFFSET = Vector3.new(0, 0, -40)
local SIGN_SIZE = Vector3.new(30, 12, 1)

local FLOOR_COLOR = Color3.fromRGB(58, 64, 76)
local WALL_COLOR = Color3.fromRGB(44, 48, 58)
local SPAWN_COLOR = Color3.fromRGB(120, 200, 255)
local READY_PAD_COLOR = Color3.fromRGB(110, 220, 150)
local SIGN_COLOR = Color3.fromRGB(32, 35, 44)

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

local existing = workspace:FindFirstChild(LOBBY_NAME)
if existing then
	existing:Destroy()
	print("[build_lobby] Workspace." .. LOBBY_NAME .. " yang lama dihapus")
end

local lobby = Instance.new("Model")
lobby.Name = LOBBY_NAME

-- Lantai & dinding -----------------------------------------------------------

local graybox = Instance.new("Folder")
graybox.Name = "Graybox"
graybox.Parent = lobby

local groundY = LOBBY_POSITION.Y
local floorCenter = Vector3.new(LOBBY_POSITION.X, groundY - FLOOR_SIZE.Y / 2, LOBBY_POSITION.Z)
local floor = makePart("Floor", FLOOR_SIZE, CFrame.new(floorCenter), FLOOR_COLOR, graybox)

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
	local center = Vector3.new(LOBBY_POSITION.X, wallCenterY, LOBBY_POSITION.Z) + wall.offset
	makePart(wall.name, wall.size, CFrame.new(center), WALL_COLOR, graybox)
end

-- SpawnLocation --------------------------------------------------------------

-- Nama instance-nya HARUS "SpawnLocation" (bagian 3.4), dan class-nya memang
-- SpawnLocation supaya Roblox memakainya sebagai titik respawn tanpa kode
-- tambahan.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "SpawnLocation"
spawnPad.Size = SPAWN_SIZE
spawnPad.CFrame = CFrame.new(LOBBY_POSITION + SPAWN_OFFSET + Vector3.new(0, SPAWN_SIZE.Y / 2, 0))
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Duration = 0 -- tanpa forcefield
spawnPad.Color = SPAWN_COLOR
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.BottomSurface = Enum.SurfaceType.Smooth
spawnPad.Parent = lobby

-- ReadyPad -------------------------------------------------------------------

local readyPad = makePart(
	"ReadyPad",
	READY_PAD_SIZE,
	CFrame.new(LOBBY_POSITION + READY_PAD_OFFSET + Vector3.new(0, READY_PAD_SIZE.Y / 2, 0)),
	READY_PAD_COLOR,
	lobby
)
readyPad.Material = Enum.Material.Neon

local readyLabel = Instance.new("BillboardGui")
readyLabel.Name = "Label"
readyLabel.Size = UDim2.fromOffset(200, 40)
readyLabel.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
readyLabel.MaxDistance = 120
readyLabel.Parent = readyPad

local readyText = Instance.new("TextLabel")
readyText.Size = UDim2.fromScale(1, 1)
readyText.BackgroundTransparency = 1
readyText.Font = Enum.Font.GothamBold
readyText.TextSize = 18
readyText.TextColor3 = Color3.fromRGB(235, 238, 245)
readyText.TextStrokeTransparency = 0.5
readyText.Text = "READY"
readyText.Parent = readyLabel

-- Papan nama -----------------------------------------------------------------

local sign = makePart(
	"Sign",
	SIGN_SIZE,
	CFrame.new(LOBBY_POSITION + SIGN_OFFSET + Vector3.new(0, SIGN_SIZE.Y / 2, 0)),
	SIGN_COLOR,
	graybox
)

local signGui = Instance.new("SurfaceGui")
signGui.Name = "Face"
signGui.Face = Enum.NormalId.Front
signGui.CanvasSize = Vector2.new(600, 240)
signGui.Parent = sign

local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(1, 1)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.GothamBold
signText.TextScaled = true
signText.TextColor3 = Color3.fromRGB(90, 170, 240)
signText.Text = "CODEVERSE\nJaga Core Server"
signText.Parent = signGui

lobby.PrimaryPart = floor
lobby.Parent = workspace

-- Pilih hasilnya supaya langsung bisa klik kanan > Save to File.
local selected, selectError = pcall(function()
	game:GetService("Selection"):Set({ lobby })
end)
if not selected then
	warn("[build_lobby] gagal memilih Lobby otomatis: " .. tostring(selectError))
end

print(
	string.format(
		"[build_lobby] %s dibangun di (%d, %d, %d). Lantai %dx%d stud, "
			.. "SpawnLocation dan ReadyPad sudah bernama sesuai bagian 3.4.",
		LOBBY_NAME,
		LOBBY_POSITION.X,
		LOBBY_POSITION.Y,
		LOBBY_POSITION.Z,
		FLOOR_SIZE.X,
		FLOOR_SIZE.Z
	)
)
print(
	"[build_lobby] Berikutnya: klik kanan Workspace."
		.. LOBBY_NAME
		.. " > Save to File > simpan sebagai assets/Lobby.rbxmx"
)
