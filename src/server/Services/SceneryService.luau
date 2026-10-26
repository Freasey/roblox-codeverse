--!strict
-- SceneryService.luau: latar belakang dan pencahayaan arena.
--
-- Ini jawaban Soal 2. Di game 2D, background adalah lapisan gambar yang
-- digambar di belakang pemain, biasanya berlapis supaya ada parallax. Di ruang
-- 3D lapisan itu tidak digambar, dia DIBANGUN pada jarak yang berbeda-beda,
-- dan efek parallax-nya muncul sendiri dari perspektif saat pemain bergerak.
--
-- Empat lapisan, dari yang terdekat ke yang terjauh:
--   1. dinding arena dengan jendela kaca di bagian atas (ArenaBuilder)
--   2. plafon ruang server beserta rangka dan panel lampunya
--   3. deretan menara server di luar gedung, terlihat lewat kaca
--   4. kabut dan atmosphere yang menelan lapisan 3 secara bertahap
--
-- KENAPA PLAFON, BUKAN LANGIT
--
-- Roblox menyediakan skybox, tapi skybox yang pantas butuh enam tekstur yang
-- harus di-upload sebagai asset, dan asset terikat akun yang meng-upload,
-- masalah yang sama dengan klip animasi di Poses.luau. Lagi pula ceritanya
-- memang terjadi DI DALAM gedung: tim IT mempertahankan satu lantai ruang
-- server. Plafon lebih benar daripada langit, dan plafon bisa dibangun dari
-- Part tanpa satu pun asset dari luar.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ArenaLayout = require(Shared.Modules.ArenaLayout)
local Config = require(Shared.Config)

local SceneryService = {}

local built = false

local ACCENT = Color3.fromRGB(0, 212, 255)
local STRUCTURE = Color3.fromRGB(22, 26, 33)

local CEILING_HEIGHT = 38
local FOLDER_NAME = "Scenery"

-- Benih tetap untuk seluruh keacakan di file ini.
--
-- Bukan detail kecil: tanpa benih tetap, tinggi menara latar berubah tiap kali
-- server dijalankan, dan dua screenshot yang diambil di hari berbeda untuk
-- laporan yang sama akan memperlihatkan gedung yang berbeda. Dengan benih
-- tetap, latar belakangnya SELALU sama persis, jadi "acak" di sini artinya
-- "bervariasi", bukan "tidak bisa diulang".
local SEED = 20261026

-- Pembangkit acak ditulis sendiri, TIDAK memakai `Random.new`.
--
-- Alasannya bukan ketidakpercayaan pada Random bawaan, melainkan supaya
-- hasilnya bisa dihitung ulang DI LUAR Roblox. Geometri latar dipanggang ke
-- dalam file place lewat harness yang menjalankan file ini dengan Instance
-- tiruan (tools/bake.luau), dan harness itu tidak punya PRNG Roblox. Dengan
-- rumus yang ditulis di sini, menara yang terlihat di Studio sebelum Play
-- benar-benar sama dengan yang akan dibangun kalau suatu saat dibangun ulang
-- saat runtime, bukan sekadar mirip.
--
-- LCG 32-bit biasa. Tidak perlu bagus; yang dibutuhkan cuma ulangan yang sama.
local rngState = SEED

local function nextRandom(): number
	rngState = (rngState * 1103515245 + 12345) % 2147483648
	return rngState / 2147483648
end

local function randomBetween(low: number, high: number): number
	return low + (high - low) * nextRandom()
end

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
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- --------------------------------------------------------------------------
-- Pencahayaan
-- --------------------------------------------------------------------------

local function applyLighting()
	-- Malam hari: ruang server tidak punya jendela ke luar yang besar, dan
	-- cahaya matahari siang akan membuat seluruh aksen neon, yang jadi bahasa
	-- warna game ini, tenggelam tidak terlihat.
	Lighting.ClockTime = 1.5
	Lighting.GeographicLatitude = 0
	Lighting.Brightness = 1.4
	Lighting.ExposureCompensation = 0.2

	-- Ambient dibiarkan kebiruan dan gelap, bukan hitam. Hitam pekat membuat
	-- bagian yang tidak kena lampu jadi siluet tanpa bentuk sama sekali, dan
	-- musuh yang masuk ke bayangan itu praktis hilang.
	Lighting.Ambient = Color3.fromRGB(28, 34, 46)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 42, 58)

	-- Kabut inilah yang mengubah deretan menara dari "benda jelas di kejauhan"
	-- jadi "latar yang memudar". Dia juga yang menyembunyikan tepi dunia.
	Lighting.FogColor = Color3.fromRGB(14, 18, 26)
	Lighting.FogStart = 120
	Lighting.FogEnd = 460

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere == nil then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(150, 170, 200)
	atmosphere.Decay = Color3.fromRGB(70, 90, 120)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.6

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom == nil then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	-- Threshold tinggi: hanya permukaan Neon yang mekar, bukan seluruh lantai
	-- logam yang terang. Bloom yang ambangnya rendah membuat teks HUD ikut
	-- berpendar dan jadi sulit dibaca.
	bloom.Intensity = 0.7
	bloom.Size = 20
	bloom.Threshold = 1.1

	-- SunRays dimatikan, bukan disetel. Sumber cahaya utama di sini lampu
	-- plafon, dan berkas matahari yang menembus dari arah mana pun di ruangan
	-- tertutup terbaca sebagai kesalahan render.
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays ~= nil then
		rays.Enabled = false
	end

	-- Depth of field dimatikan dengan alasan gameplay, bukan selera: game ini
	-- menuntut pemain membaca musuh di kejauhan, dan latar yang diburamkan
	-- justru membuat musuh yang baru masuk lewat gerbang sulit dikenali.
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof ~= nil then
		dof.Enabled = false
	end

	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction == nil then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Parent = Lighting
	end
	correction.Brightness = 0.02
	correction.Contrast = 0.12
	correction.Saturation = 0.06
	correction.TintColor = Color3.fromRGB(236, 243, 255)
end

-- --------------------------------------------------------------------------
-- Lapisan 2: plafon
-- --------------------------------------------------------------------------

local function buildCeiling(parent: Instance)
	local ceiling = Instance.new("Folder")
	ceiling.Name = "Ceiling"
	ceiling.Parent = parent

	local span = 34
	local reach = 2 -- -2..2 petak = 170 x 170 stud, melebihi arena di semua sisi

	for gx = -reach, reach do
		for gz = -reach, reach do
			part(
				"Panel",
				Vector3.new(span - 0.4, 2, span - 0.4),
				CFrame.new(gx * span, CEILING_HEIGHT, gz * span),
				STRUCTURE,
				Enum.Material.Metal,
				ceiling
			)

			-- Panel lampu di tengah tiap petak plafon. Inilah sumber cahaya
			-- yang menjelaskan kenapa lantai terang, tanpa benda yang
			-- terlihat memancarkannya, pencahayaan terasa datang dari
			-- ketiadaan.
			local lamp = part(
				"Lamp",
				Vector3.new(span - 14, 0.4, 5),
				CFrame.new(gx * span, CEILING_HEIGHT - 1.2, gz * span),
				Color3.fromRGB(205, 232, 255),
				Enum.Material.Neon,
				ceiling
			)
			lamp.Transparency = 0.1

			-- Cuma petak berselang yang benar-benar memancarkan cahaya nyata.
			-- 25 PointLight sekaligus mahal dan hasilnya nyaris sama dengan 9.
			if (gx + gz) % 2 == 0 then
				local light = Instance.new("PointLight")
				light.Brightness = 1.5
				light.Range = 48
				light.Color = Color3.fromRGB(190, 215, 255)
				light.Parent = lamp
			end
		end
	end

	-- Rangka baja melintang. Memberi plafon arah dan skala; bidang rata tanpa
	-- rangka terbaca sebagai langit-langit tak berjarak.
	local full = span * (reach * 2 + 1)
	for i = -reach, reach do
		part(
			"Truss",
			Vector3.new(full, 1.6, 1.6),
			CFrame.new(0, CEILING_HEIGHT - 2.4, i * span + span / 2),
			Color3.fromRGB(30, 35, 44),
			Enum.Material.Metal,
			ceiling
		)
		part(
			"Truss",
			Vector3.new(1.6, 1.6, full),
			CFrame.new(i * span + span / 2, CEILING_HEIGHT - 2.4, 0),
			Color3.fromRGB(30, 35, 44),
			Enum.Material.Metal,
			ceiling
		)
	end
end

-- --------------------------------------------------------------------------
-- Lapisan 3: menara server di kejauhan
-- --------------------------------------------------------------------------

local function buildSkyline(parent: Instance)
	local skyline = Instance.new("Folder")
	skyline.Name = "Skyline"
	skyline.Parent = parent

	rngState = SEED

	-- Tiga cincin pada jarak berbeda. Jarak yang berbeda itulah yang
	-- menghasilkan parallax: saat pemain berlari menyusuri arena, cincin
	-- terdekat bergeser jelas, cincin terjauh nyaris diam, persis perilaku
	-- lapisan background berlapis di game 2D.
	for _, ring in
		{
			{ radius = 130, count = 18, scale = 1 },
			{ radius = 185, count = 22, scale = 1.5 },
			{ radius = 260, count = 24, scale = 2.2 },
		}
	do
		for i = 1, ring.count do
			-- Sudutnya dibuat tidak rata persis supaya deretannya tidak
			-- terbaca sebagai pagar melingkar.
			local angle = (i / ring.count) * math.pi * 2 + randomBetween(-0.05, 0.05)
			local radius = ring.radius + randomBetween(-14, 14)
			local height = randomBetween(28, 86) * ring.scale
			local width = randomBetween(14, 30) * ring.scale

			local x, z = math.cos(angle) * radius, math.sin(angle) * radius
			local cf = CFrame.new(x, height / 2, z) * CFrame.Angles(0, -angle, 0)

			part(
				"Tower",
				Vector3.new(width, height, width * 0.7),
				cf,
				Color3.fromRGB(18, 22, 30),
				Enum.Material.Metal,
				skyline
			)

			-- Pita lampu mendatar di tiap menara: ini yang membuat siluet
			-- gelap terbaca sebagai gedung berisi dan bukan sebagai balok.
			local bands = math.max(2, math.floor(height / 14))
			for band = 1, bands do
				local y = (band / (bands + 1)) * height
				local strip = part(
					"Band",
					Vector3.new(width + 0.3, 0.7 * ring.scale, width * 0.7 + 0.3),
					CFrame.new(x, y, z) * CFrame.Angles(0, -angle, 0),
					if nextRandom() < 0.75 then ACCENT else Color3.fromRGB(255, 150, 60),
					Enum.Material.Neon,
					skyline
				)
				-- Makin jauh makin pudar, membantu kabut memisahkan cincin.
				strip.Transparency = math.clamp(0.25 + (radius - 120) / 420, 0.25, 0.8)
			end
		end
	end
end

-- --------------------------------------------------------------------------

function SceneryService.build(): boolean
	if built then
		return true
	end

	-- Pencahayaan SELALU diterapkan, bahkan kalau geometrinya sudah dipanggang.
	-- Murah (beberapa properti), dan dia yang menjamin place yang pernah
	-- disentuh tangan di Studio tetap kembali ke tampilan yang dirancang.
	applyLighting()

	-- Geometri latar yang sudah dipanggang ke file place tidak dibangun ulang.
	-- Alasan lengkapnya ada di ArenaBuilder.build().
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old ~= nil and #old:GetChildren() > 0 then
		built = true
		print(
			string.format("[%s] latar sudah ada di place, pembangunan dilewati", Config.GAME_NAME)
		)
		return true
	end
	if old ~= nil then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local ok, err = pcall(function()
		buildCeiling(folder)
		buildSkyline(folder)
	end)
	if not ok then
		folder:Destroy()
		warn(string.format("[%s] latar gagal dibangun: %s", Config.GAME_NAME, tostring(err)))
		return false
	end

	folder.Parent = Workspace
	built = true

	print(
		string.format(
			"[%s] latar dibangun: plafon setinggi %d, %d objek latar",
			Config.GAME_NAME,
			CEILING_HEIGHT,
			#folder:GetDescendants()
		)
	)
	return true
end

-- Dipakai ArenaBuilder lewat init.server.luau: tinggi plafon menentukan batas
-- atas yang masuk akal untuk apa pun yang dibangun di arena, supaya tidak ada
-- menara atau gerbang yang menembus langit-langit.
function SceneryService.ceilingHeight(): number
	return CEILING_HEIGHT
end

-- Sanity check sederhana yang dipanggil saat boot: dinding arena tidak boleh
-- lebih tinggi dari plafon.
function SceneryService.validate(): (boolean, string?)
	if ArenaLayout.WALL_HEIGHT >= CEILING_HEIGHT - 4 then
		return false,
			string.format(
				"dinding arena (%d) terlalu tinggi untuk plafon (%d)",
				ArenaLayout.WALL_HEIGHT,
				CEILING_HEIGHT
			)
	end
	return true, nil
end

return SceneryService
