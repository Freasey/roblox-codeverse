--!strict
-- StanceController.luau: tombol gerak dan bar stamina (Soal 4).
--
-- Yang dikirim ke server cuma NIAT, dan cuma SAAT BERUBAH. Bukan tiap frame:
-- niat pemain berubah beberapa kali per detik di keadaan paling ramai
-- sekalipun, sementara mengirimnya tiap frame berarti 60 panggilan remote per
-- detik untuk mengatakan hal yang sama berulang-ulang, dan itu akan menabrak
-- rate limit server sendiri.
--
-- Satu pengiriman ulang berkala tetap ada (`REFRESH_INTERVAL`), sebagai jaring
-- pengaman kalau satu paket niat hilang. Tanpa itu, satu paket "walk" yang
-- hilang akan meninggalkan pemain berlari sampai dia menekan tombol lain.
--
-- Bar stamina di layar DIBACA DARI ATRIBUT KARAKTER yang ditulis server, bukan
-- dihitung ulang di sini. Menghitungnya sendiri akan menghasilkan dua angka
-- yang pelan-pelan berbeda, dan yang terlihat pemain adalah bar penuh saat
-- sprint-nya sudah ditolak server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MoveRules = require(ReplicatedStorage.Shared.Modules.MoveRules)
local UiKit = require(script.Parent.UiKit)

local StanceController = {}

local localPlayer = Players.LocalPlayer
local started = false

local REFRESH_INTERVAL = 0.5

local sprintHeld = false
local crouchOn = false
local lastSent = ""
local lastSentAt = 0

local staminaBar: UiKit.Bar? = nil
local hintLabel: TextLabel? = nil

local function send(intent: string, force: boolean)
	local now = os.clock()
	if not force and intent == lastSent and now - lastSentAt < REFRESH_INTERVAL then
		return
	end
	lastSent = intent
	lastSentAt = now
	Remotes.Events.MoveIntent:FireServer(intent)
end

-- Jongkok menang atas sprint kalau dua-duanya aktif.
--
-- Harus ada yang menang, dan jongkok dipilih karena dia yang DISENGAJA: sprint
-- menyala hanya selama tombolnya ditahan, sementara jongkok adalah saklar yang
-- sudah ditekan pemain dan dia berhak menganggapnya masih menyala. Kalau
-- sprint yang menang, menahan Shift akan diam-diam membatalkan jongkok tanpa
-- mematikan saklarnya, dan pemain melepas Shift lalu mendapati dirinya jongkok
-- lagi entah kenapa.
local function currentIntent(): string
	if crouchOn then
		return "crouch"
	end
	if sprintHeld then
		return "sprint"
	end
	return "walk"
end

local function buildUi()
	local gui = UiKit.screenGui("StanceHud", 4)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel =
		UiKit.panel(gui, "Stance", UDim2.new(0.5, -130, 1, -86), UDim2.fromOffset(260, 46))
	panel.BackgroundTransparency = 0.35

	local bar = UiKit.bar(panel, "Stamina", UDim2.fromOffset(10, 8), UDim2.fromOffset(240, 14))
	staminaBar = bar

	local hint = UiKit.label(panel, "Hint", UDim2.fromOffset(10, 24), UDim2.fromOffset(240, 18), "")
	hint.TextSize = 12
	hint.TextColor3 = UiKit.COLOR_MUTED
	hintLabel = hint
end

-- Tombol layar sentuh. Dibuat hanya kalau perangkatnya memang menyentuh dan
-- tidak punya keyboard: menampilkan tombol di PC akan menutupi arena tanpa
-- guna, dan pemain PC sudah punya Shift, C, dan Q.
local function buildTouchButtons()
	if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
		return
	end

	local gui = UiKit.screenGui("StanceTouch", 5)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local sprint =
		UiKit.button(gui, "Sprint", UDim2.new(1, -190, 1, -190), UDim2.fromOffset(84, 44), "LARI")
	sprint.MouseButton1Down:Connect(function()
		sprintHeld = true
		send(currentIntent(), true)
	end)
	sprint.MouseButton1Up:Connect(function()
		sprintHeld = false
		send(currentIntent(), true)
	end)

	local crouch = UiKit.button(
		gui,
		"Crouch",
		UDim2.new(1, -190, 1, -138),
		UDim2.fromOffset(84, 44),
		"JONGKOK"
	)
	crouch.MouseButton1Click:Connect(function()
		crouchOn = not crouchOn
		send(currentIntent(), true)
	end)

	local dash =
		UiKit.button(gui, "Dash", UDim2.new(1, -190, 1, -86), UDim2.fromOffset(84, 44), "DASH")
	dash.MouseButton1Click:Connect(function()
		Remotes.Events.MoveIntent:FireServer("dash")
	end)
end

function StanceController.start()
	if started then
		return
	end
	started = true

	buildUi()
	buildTouchButtons()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprintHeld = true
			send(currentIntent(), true)
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			crouchOn = not crouchOn
			send(currentIntent(), true)
		elseif input.KeyCode == Enum.KeyCode.Q then
			Remotes.Events.MoveIntent:FireServer("dash")
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprintHeld = false
			send(currentIntent(), true)
		end
	end)

	-- Jongkok dimatikan saat karakter baru lahir, menyesuaikan reset yang sudah
	-- dilakukan MovementService di sisi server. Kalau cuma server yang mereset,
	-- saklar di client tetap menyala dan pemain yang respawn akan mengira
	-- jongkoknya macet.
	localPlayer.CharacterAdded:Connect(function()
		crouchOn = false
		sprintHeld = false
		send("walk", true)
	end)

	RunService.RenderStepped:Connect(function()
		send(currentIntent(), false)

		local bar = staminaBar
		if bar == nil then
			return
		end

		local character = localPlayer.Character
		local stamina = if character ~= nil then character:GetAttribute("Stamina") else nil
		local value = if type(stamina) == "number" then stamina else MoveRules.MAX_STAMINA

		UiKit.setBar(bar, value, MoveRules.MAX_STAMINA, string.format("STAMINA  %d", value))

		local hint = hintLabel
		if hint ~= nil then
			local stance = if character ~= nil then character:GetAttribute("Stance") else nil
			local label = if stance == "sprint"
				then "LARI"
				elseif stance == "crouch" then "JONGKOK"
				else "JALAN"
			hint.Text =
				string.format("%s     Shift lari     C jongkok     Q dash     Space lompat", label)
		end
	end)
end

return StanceController
