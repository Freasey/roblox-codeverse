--!strict
-- InputController.luau — klik/tap jadi `Remotes.Attack(direction)`.
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

	-- Tahan tombol = serang terus. Tanpa ini pemain harus mengklik 4 kali per
	-- detik untuk memakai senjata jarak jauh secara penuh.
	RunService.RenderStepped:Connect(function()
		if holding then
			trySend()
		end
	end)
end

return InputController
