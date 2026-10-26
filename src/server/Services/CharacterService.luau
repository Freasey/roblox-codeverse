--!strict
-- CharacterService.luau: memasang rancangan karakter "Teknisi IT" ke tiap
-- pemain yang spawn.
--
-- Dijalankan di SERVER, bukan di client, dan itu bukan pilihan gaya. Part yang
-- dibuat client cuma ada di layar client itu sendiri: pemain akan melihat
-- dirinya memakai rompi, dan tiga rekan setimnya telanjang. Dibuat di server,
-- Part-nya ikut replikasi dan semua orang melihat hal yang sama, termasuk
-- saat screenshot diambil untuk laporan.
--
-- Rancangannya sendiri tidak ada di sini; dia ada di
-- `Shared.Modules.CharacterDesign`. Yang ada di file ini cuma cara
-- memasangnya: menunggu rig siap, menerjemahkan string jadi Enum, dan mengelas
-- Part ke bagian tubuh.
--
-- CATATAN SOAL `LoadCharacterAppearance`
--
-- Supaya seragam ini benar-benar terlihat, `StarterPlayer.LoadCharacterAppearance`
-- disetel `false` di place-nya. Tanpa itu, Roblox memuat avatar milik akun tiap
-- pemain lebih dulu, lengkap dengan topi, rambut, dan baju mereka sendiri,
-- dan rompi yang dipasang di sini cuma jadi lapisan di atas kekacauan yang
-- berbeda-beda tiap orang. Soal 1 meminta KARAKTER YANG DIRANCANG, jadi yang
-- dirancang itulah yang harus muncul, bukan avatar pemain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterDesign = require(Shared.Modules.CharacterDesign)
local Config = require(Shared.Config)

local CharacterService = {}

local started = false

-- Satu warn saja kalau rig-nya ternyata bukan R15, bukan satu per spawn.
-- Pemain respawn berkali-kali dalam satu match; peringatan yang sama tercetak
-- dua puluh kali membuat Output tidak bisa dibaca lagi untuk hal lain.
local warnedAboutRig = false

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
	Ball = Enum.PartType.Ball,
}

-- Ukuran Part terkecil yang masih diterima engine. Ukuran hasil perkalian
-- pecahan bisa jatuh di bawah ini pada avatar yang diperkecil, dan Part dengan
-- salah satu sisi nol tidak error, dia cuma hilang dari layar.
local MIN_PART_SIZE = 0.05

local function resolveMaterial(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	if typeof(material) == "EnumItem" then
		return material
	end
	-- Nama material salah ketik tidak boleh menggagalkan seluruh karakter;
	-- yang hilang cukup tampilannya, dan warn-nya menyebut nama yang salah.
	warn(string.format("[%s] material tidak dikenal: %s", Config.GAME_NAME, name))
	return Enum.Material.SmoothPlastic
end

-- Menunggu seluruh bagian tubuh yang dipakai rancangan benar-benar ada.
--
-- Rig R15 dirakit bertahap: `CharacterAdded` menyala saat Model-nya masuk
-- Workspace, dan sebagian Part menyusul beberapa frame kemudian. Memasang
-- aksesori saat itu menghasilkan Part yang menempel di tempat yang salah, dan
-- itu tidak muncul sebagai error, cuma terlihat jelek dan sulit dilacak.
--
-- Batas waktunya ada supaya karakter yang gagal dirakit (pemain keluar tepat
-- saat spawn) tidak meninggalkan thread yang menunggu selamanya.
local function waitForRig(character: Model, timeout: number): boolean
	local deadline = os.clock() + timeout
	for _, partName in CharacterDesign.REQUIRED_PARTS do
		local remaining = deadline - os.clock()
		if remaining <= 0 then
			return false
		end
		if character:FindFirstChild(partName) == nil then
			local found = character:WaitForChild(partName, remaining)
			if found == nil then
				return false
			end
		end
	end
	return true
end

-- Warna badan disetel per Part, dan `BodyColors` bawaan DIHAPUS lebih dulu.
--
-- Alasannya bukan kerapian: `BodyColors` cuma punya enam kelompok warna
-- (kepala, torso, dua lengan, dua kaki), sedangkan rancangan ini memberi warna
-- berbeda untuk bagian-bagian di dalam satu kelompok yang sama, lengan atas
-- memakai warna seragam sementara telapak tangan memakai warna kulit. Selama
-- `BodyColors` masih ada, dia akan menimpa warna per-Part itu setiap kali
-- propertinya tersentuh, dan telapak tangan kembali ikut warna lengan.
local function applyBodyColors(character: Model)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors ~= nil then
		bodyColors:Destroy()
	end

	for partName, color in CharacterDesign.BODY_COLORS do
		local part = character:FindFirstChild(partName)
		if part ~= nil and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

-- Pakaian dan aksesori bawaan akun dibersihkan kalau masih sempat termuat.
-- `LoadCharacterAppearance = false` seharusnya sudah mencegahnya, tapi setelan
-- itu ada di properti place, bukan di file ini, dan setelan place adalah
-- hal yang paling mudah ikut hilang saat seseorang membuat place baru lalu
-- menyalin isinya. Pembersihan ini yang membuat kehilangan itu tidak membuat
-- rancangan karakternya ikut hilang.
local function stripDefaultAppearance(character: Model)
	for _, child in character:GetChildren() do
		if
			child:IsA("Accessory")
			or child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
		then
			child:Destroy()
		end
	end
end

-- Memastikan hanya ADA SATU script `Animate` di karakter, yaitu milik kita.
--
-- StarterCharacterScripts/Animate seharusnya sudah menggusur yang bawaan, tapi
-- "seharusnya" tidak cukup untuk sesuatu yang gagalnya tidak terlihat sebagai
-- error: kalau dua-duanya ikut, Animator bawaan dan animator kita menulis ke
-- Motor6D yang sama tiap frame, dan karakternya berkedip antara dua animasi.
--
-- Pembedanya bukan nama, dua-duanya bernama `Animate`, melainkan ISI:
-- script bawaan Roblox membawa puluhan objek Animation sebagai anak (idle,
-- walk, run, jump, dan seterusnya), sementara milik kita kosong melompong.
-- Jadi yang punya anak, itulah yang bawaan.
local function removeDefaultAnimate(character: Model)
	for _, child in character:GetChildren() do
		if child.Name == "Animate" and #child:GetChildren() > 0 then
			child:Destroy()
		end
	end
end

local function buildAccessory(character: Model, spec: CharacterDesign.Accessory, parent: Folder)
	local host = character:FindFirstChild(spec.attachTo)
	if host == nil or not host:IsA("BasePart") then
		return
	end

	local hostSize = host.Size

	local part = Instance.new("Part")
	part.Name = spec.id
	part.Shape = SHAPES[spec.shape] or Enum.PartType.Block
	part.Size = Vector3.new(
		math.max(hostSize.X * spec.sizeScale.X, MIN_PART_SIZE),
		math.max(hostSize.Y * spec.sizeScale.Y, MIN_PART_SIZE),
		math.max(hostSize.Z * spec.sizeScale.Z, MIN_PART_SIZE)
	)
	part.Color = spec.color
	part.Material = resolveMaterial(spec.material)
	part.Transparency = spec.transparency or 0

	-- Empat properti ini yang membuat aksesori benar-benar hiasan:
	--   Massless  : tidak menambah massa, jadi tinggi lompat dan kecepatan
	--               karakter tidak berubah hanya karena dia memakai ransel.
	--   CanCollide,  tidak menabrak dinding atau musuh.
	--   CanQuery  : tidak tertangkap raycast. Ini yang penting untuk bidikan:
	--               `InputController` memang sudah mengecualikan karakter
	--               sendiri, tapi raycast pemain LAIN tidak, dan tanpa ini
	--               ransel rekan setim bisa menghentikan bidikan di tengah.
	--   CanTouch  : tidak memicu event sentuhan apa pun.
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = false
	part.CastShadow = false

	local offset = CFrame.new(
		hostSize.X * spec.offsetScale.X,
		hostSize.Y * spec.offsetScale.Y,
		hostSize.Z * spec.offsetScale.Z
	)
	local rotation = spec.rotation
	if rotation ~= nil then
		offset = offset
			* CFrame.Angles(
				math.rad(rotation.X),
				math.rad(rotation.Y),
				math.rad(rotation.Z)
			)
	end

	-- Urutannya wajib: posisikan dulu, baru dilas. WeldConstraint mengunci
	-- jarak yang BERLAKU SAAT DIA DIBUAT, jadi mengelas lebih dulu akan
	-- mengunci Part di titik asalnya (0,0,0 dunia) dan menyeret karakternya.
	part.CFrame = host.CFrame * offset

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part

	part.Parent = parent
end

-- Memasang seluruh rancangan ke satu karakter. Dipisah dari penyambungan event
-- supaya bisa dipanggil ulang dari Command Bar saat menyetel angka di
-- CharacterDesign, tanpa perlu respawn.
function CharacterService.applyTo(character: Model): boolean
	if not waitForRig(character, 5) then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return false
	end

	stripDefaultAppearance(character)
	removeDefaultAnimate(character)
	applyBodyColors(character)

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		if not warnedAboutRig then
			warnedAboutRig = true
			warn(
				string.format(
					"[%s] rig pemain bukan R15, aksesori karakter dilewati. "
						.. "Setel Game Settings -> Avatar -> Avatar Type ke R15.",
					Config.GAME_NAME
				)
			)
		end
		return false
	end

	-- Wadah lama dihapus lebih dulu. Tanpa ini, memanggil applyTo() dua kali
	-- pada karakter yang sama menumpuk dua set aksesori di tempat yang sama,
	-- dan yang terlihat cuma permukaannya jadi berkedip (z-fighting).
	local existing = character:FindFirstChild(CharacterDesign.CONTAINER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local container = Instance.new("Folder")
	container.Name = CharacterDesign.CONTAINER_NAME

	for _, spec in CharacterDesign.ACCESSORIES do
		buildAccessory(character, spec, container)
	end

	container.Parent = character
	return true
end

function CharacterService.start()
	if started then
		return
	end
	started = true

	local ok, err = CharacterDesign.validate()
	if not ok then
		warn(string.format("[%s] rancangan karakter tidak valid: %s", Config.GAME_NAME, tostring(err)))
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			CharacterService.applyTo(character)
		end)
		-- Pemain yang karakternya sudah terlanjur spawn sebelum baris ini
		-- jalan (server reload saat ada orang di dalam) tetap kebagian.
		local current = player.Character
		if current ~= nil then
			task.spawn(CharacterService.applyTo, current)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return CharacterService
