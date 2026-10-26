--!strict
-- WeaponService.luau: senjata yang terlihat di tangan pemain.
--
-- Dibangun di SERVER, dengan alasan yang sama seperti CharacterService:
-- senjata yang dibuat client hanya ada di layar client itu sendiri, dan
-- seluruh gunanya, melihat senjata apa yang dipegang rekan setim, justru
-- hilang.
--
-- Senjata yang dipasang diambil dari `ProgressionRules.equippedWeapon`, pintu
-- yang sama persis yang dipakai CombatService untuk menentukan damage. Itu
-- syarat, bukan kerapian: kalau keduanya membaca data dengan caranya sendiri,
-- suatu hari pemain akan memegang Patch Wrench di layar sambil menembak
-- sejauh 60 stud, dan tidak ada yang bisa menebak mana dari keduanya yang
-- benar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local WeaponVisuals = require(Shared.Modules.WeaponVisuals)
local Weapons = require(Shared.Modules.Weapons)

local PlayerDataService = require(script.Parent.PlayerDataService)

local WeaponService = {}

local started = false

local CONTAINER_NAME = "Weapon"
local HAND_NAME = "RightHand"

-- Senjata yang terpasang sekarang, per pemain. Dipakai untuk tahu kapan model
-- perlu dibangun ulang: membangun ulang tiap pemeriksaan berarti senjata
-- berkedip hilang-muncul dua kali per detik.
local equipped: { [number]: string } = {}

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function handOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local hand = character:FindFirstChild(HAND_NAME)
	if hand ~= nil and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function buildPiece(hand: BasePart, piece: WeaponVisuals.Piece, parent: Model)
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Shape = SHAPES[piece.shape] or Enum.PartType.Block
	part.Size = piece.size
	part.Color = piece.color
	part.Transparency = piece.transparency or 0

	local material = (Enum.Material :: any)[piece.material]
	part.Material = if typeof(material) == "EnumItem" then material else Enum.Material.Metal

	-- Sama seperti aksesori karakter: tidak bermassa, tidak menabrak, tidak
	-- tertangkap raycast. Yang terakhir paling penting di sini, laras
	-- senapan menjulur 4 stud di depan pemain, dan kalau dia bisa kena
	-- raycast, bidikan rekan setim yang menembak melewati bahu pemain lain
	-- akan berhenti di senjatanya.
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Anchored = false

	local offset = CFrame.new(piece.offset)
	local rotation = piece.rotation
	if rotation ~= nil then
		offset = offset
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	end

	-- Posisikan dulu, baru dilas. WeldConstraint mengunci jarak yang berlaku
	-- saat dia dibuat.
	part.CFrame = hand.CFrame * offset
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
end

local function clearWeapon(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local existing = character:FindFirstChild(CONTAINER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function buildWeapon(player: Player, weaponId: string): boolean
	local hand = handOf(player)
	if hand == nil then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end

	local visual = WeaponVisuals.get(weaponId)
	if visual == nil then
		-- Senjata tanpa bentuk tidak menggagalkan apa pun; pemain cuma
		-- bertangan kosong. Warn-nya menyebut id-nya supaya ketahuan saat
		-- senjata baru ditambahkan ke Weapons.luau tapi lupa ke WeaponVisuals.
		warn(string.format("[%s] senjata '%s' belum punya bentuk", Config.GAME_NAME, weaponId))
		return false
	end

	clearWeapon(player)

	local model = Instance.new("Model")
	model.Name = CONTAINER_NAME

	for _, piece in visual.pieces do
		buildPiece(hand, piece, model)
	end

	model.Parent = character

	-- Dua atribut ini yang dibaca client: `Weapon` untuk tahu senjata apa,
	-- `WeaponKind` untuk tahu animasi serangan mana yang harus diputar.
	-- Client bisa saja menyimpulkan kind dari id lewat WeaponVisuals sendiri,
	-- tapi menuliskannya di sini berarti satu tempat yang memutuskan, dan
	-- id senjata yang suatu hari tidak ada di WeaponVisuals tidak membuat
	-- animasinya diam-diam salah.
	character:SetAttribute("Weapon", weaponId)
	character:SetAttribute("WeaponKind", visual.kind)
	return true
end

-- Senjata yang SEHARUSNYA dipegang pemain menurut data tersimpannya.
local function intendedWeapon(player: Player): string?
	local data = PlayerDataService.get(player)
	if data == nil then
		return nil
	end
	local def = ProgressionRules.equippedWeapon(data, Weapons, Config.DEV_ALL_WEAPONS)
	return def.id
end

local function refresh(player: Player, force: boolean)
	local weaponId = intendedWeapon(player)
	if weaponId == nil then
		return
	end
	if not force and equipped[player.UserId] == weaponId then
		return
	end
	if buildWeapon(player, weaponId) then
		equipped[player.UserId] = weaponId
	end
end

function WeaponService.start()
	if started then
		return
	end
	started = true

	local known: { string } = {}
	for id in Weapons do
		table.insert(known, id)
	end
	local ok, err = WeaponVisuals.validate(known)
	if not ok then
		warn(string.format("[%s] bentuk senjata tidak lengkap: %s", Config.GAME_NAME, tostring(err)))
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			-- Tangan kanan ditunggu, tidak dibaca sekali. Alasannya persis sama
			-- dengan yang ditulis panjang di CharacterAnimatorController: rig
			-- R15 dirakit bertahap, dan membaca sekali pada CharacterAdded
			-- hampir selalu terlalu cepat.
			if character:FindFirstChild(HAND_NAME) == nil then
				if character:WaitForChild(HAND_NAME, 10) == nil then
					return
				end
			end
			equipped[player.UserId] = nil
			refresh(player, true)
		end)

		local current = player.Character
		if current ~= nil then
			task.spawn(refresh, player, true)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		equipped[player.UserId] = nil
	end)

	-- Pemeriksaan berkala dua kali per detik.
	--
	-- Diperiksa berkala, BUKAN disambung ke sinyal, karena sinyal itu tidak
	-- ada: `PlayerDataService` cuma menyiarkan `onLoaded`, dan penggantian
	-- senjata ditulis `MatchService` langsung ke data lewat `update`. Menambah
	-- sinyal baru berarti menyentuh dua service yang sudah bekerja hanya untuk
	-- mengganti model di tangan, sementara memeriksa satu field untuk empat
	-- pemain, dua kali per detik, harganya praktis nol.
	--
	-- Konsekuensinya jujur: senjata di tangan bisa tertinggal sampai setengah
	-- detik setelah pemain menggantinya di lobby. Tidak ada yang mengambil
	-- keputusan dari model itu, jadi keterlambatan segitu tidak berakibat apa
	-- pun selain terlihat.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			refresh(player, false)
		end
	end)
end

return WeaponService
