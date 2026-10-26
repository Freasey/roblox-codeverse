--!strict
-- InputController.luau — input pemain: klik untuk menyerang, C untuk jongkok.
--
-- SERANG
--
-- Yang dikirim ke server cuma ARAH BIDIK, satu Vector3. Bukan "aku kena musuh
-- id 7", bukan "damage 40", bukan posisi musuh. Server yang memutuskan
-- semuanya (bagian 1.2); kalau client boleh menyebut target, pemain yang
-- memodifikasi client-nya bisa menyerang musuh dari seberang arena.
--
-- Client tetap men-throttle pengirimannya. Bukan untuk keamanan — server punya
-- cooldown sendiri dan tidak mempercayai timer client — tapi supaya pemain yang
-- menahan tombol tidak menabrak rate limit 20 panggilan per detik dan
-- serangannya mulai dibuang.
--
-- JONGKOK
--
-- Tombolnya C atau Ctrl kiri, dan dia TOGGLE, bukan tahan. Menahan tombol
-- sudah dipakai menyerang: jongkok yang harus ditahan berarti pemain menahan
-- Ctrl dan klik kiri bersamaan selama satu wave, dan itu bukan permintaannya.
--
-- Ditulis di DUA tempat, dan sengaja: di sini supaya tombolnya langsung
-- terasa tanpa menunggu satu perjalanan jaringan, dan di CrouchService supaya
-- pemain lain ikut melihatnya — properti yang ditulis script client cuma
-- berlaku di layar client itu. Dua tulisan itu tidak bisa berbeda karena
-- angkanya dibaca dari `CrouchRules` yang sama.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CrouchRules = require(ReplicatedStorage.Shared.Modules.CrouchRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InputController = {}

local localPlayer = Players.LocalPlayer

-- 8 kali per detik: di atas senjata tercepat (cooldown 0.25 detik = 4/detik)
-- supaya tidak ada serangan yang hilang, dan jauh di bawah rate limit server.
local SEND_INTERVAL = 1 / 8
local AIM_FALLBACK_DISTANCE = 200

local holding = false
local lastSentAt = 0
local started = false

local CROUCH_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.C] = true,
	[Enum.KeyCode.LeftControl] = true,
}

local crouching = false
-- Kecepatan dan HipHeight BERDIRI, dicatat saat karakter muncul. Dibaca dari
-- Humanoid saat jongkok, yang terbaca adalah angka yang sudah separuh kalau
-- pemain sudah jongkok. Lihat CrouchRules.
local standingSpeed = CrouchRules.DEFAULT_SPEED
local standingHipHeight = CrouchRules.DEFAULT_HIP_HEIGHT

local function characterRoot(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Titik yang sedang dibidik di dunia. Raycast dari kamera lewat titik layar,
-- mengabaikan karakter sendiri supaya bidikan tidak mentok di punggung sendiri.
local function aimPoint(root: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return root.Position + root.CFrame.LookVector * AIM_FALLBACK_DISTANCE
	end

	local screenPoint = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = localPlayer.Character
	params.FilterDescendantsInstances = if character ~= nil then { character } else {}

	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_FALLBACK_DISTANCE, params)
	if result ~= nil then
		return result.Position
	end
	return ray.Origin + ray.Direction * AIM_FALLBACK_DISTANCE
end

local function trySend()
	local now = os.clock()
	if now - lastSentAt < SEND_INTERVAL then
		return
	end

	local root = characterRoot()
	if root == nil then
		return
	end

	local direction = aimPoint(root) - root.Position
	if direction.Magnitude < 1e-3 then
		return
	end

	lastSentAt = now
	Remotes.Events.Attack:FireServer(direction.Unit)
end

local function aliveHumanoid(): Humanoid?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function setCrouch(want: boolean)
	if want == crouching then
		return
	end
	local humanoid = aliveHumanoid()
	if humanoid == nil then
		return
	end

	crouching = want
	humanoid.WalkSpeed = CrouchRules.speedFor(standingSpeed, want)
	humanoid.HipHeight = CrouchRules.hipHeightFor(standingHipHeight, want)
	humanoid.CameraOffset = Vector3.new(0, CrouchRules.cameraDropFor(want), 0)

	-- Server yang membuat jongkok ini terlihat pemain lain. Dikirim sesudah
	-- tulisan lokal, bukan sebelum: kalau remote-nya gagal, yang menekan
	-- tombol setidaknya melihat karakternya sendiri bergerak.
	Remotes.Events.SetCrouch:FireServer(want)
end

local function watchCharacter(character: Model)
	-- Karakter baru selalu berdiri. Tanda jongkoknya dibuang di sini, kalau
	-- tidak tekanan tombol pertama sesudah respawn cuma akan mengirim
	-- "berdiri" dan terlihat seperti tombol yang rusak.
	crouching = false

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	standingSpeed = humanoid.WalkSpeed
	standingHipHeight = humanoid.HipHeight
end

function InputController.start()
	if started then
		return
	end
	started = true

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- `processed` true berarti input itu sudah dipakai UI (pemain mengklik
		-- tombol toko). Menyerang juga saat itu terjadi akan membuat setiap
		-- klik tombol ikut menembak.
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = true
			trySend()
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if CROUCH_KEYS[input.KeyCode] then
			setCrouch(not crouching)
			return
		end

		-- Lompat sambil jongkok: berdiri dulu. Roblox tetap melakukan lompatnya
		-- sendiri di frame yang sama, jadi hasilnya berdiri lalu lompat --
		-- bukan tombol yang diam, yang akan dibaca pemain sebagai input hilang.
		if input.KeyCode == Enum.KeyCode.Space and crouching then
			setCrouch(false)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
		end
	end)

	localPlayer.CharacterAdded:Connect(watchCharacter)
	if localPlayer.Character ~= nil then
		watchCharacter(localPlayer.Character)
	end

	-- Tahan tombol = serang terus. Tanpa ini pemain harus mengklik 4 kali per
	-- detik untuk memakai senjata jarak jauh secara penuh.
	RunService.RenderStepped:Connect(function()
		if holding then
			trySend()
		end
	end)
end

return InputController
