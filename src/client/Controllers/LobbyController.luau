--!strict
-- LobbyController.luau — UI lobby.
--
-- M2 cuma butuh satu hal dari file ini: tombol Ready. Tanpa itu tidak ada cara
-- memulai match, dan kriteria M2 ("satu match penuh bisa dimainkan dari lobby
-- sampai hasil") tidak bisa diverifikasi sama sekali. Panel pilih senjata,
-- pilih kesulitan, upgrade, dan craft masuk di M5 — semuanya menempel di panel
-- yang sama.
--
-- Tombol Ready cuma mengirim `SetReady(boolean)`. Dia TIDAK memutuskan apakah
-- match mulai; server yang memeriksa syaratnya (semua pemain siap, minimal
-- satu) dan client cuma melihat hasilnya lewat `MatchState`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchStore = require(script.Parent.MatchStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local LobbyController = {}

local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local panel: Frame? = nil
local readyButton: TextButton? = nil
local hintLabel: TextLabel? = nil
local isReady = false
local started = false

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseLobby", 20)

	local frame =
		UiKit.panel(screen, "Panel", UDim2.new(0.5, -150, 1, -108), UDim2.fromOffset(300, 92))

	local hint = UiKit.label(frame, "Hint", UDim2.fromOffset(14, 8), UDim2.fromOffset(272, 32), "")
	hint.TextSize = 13
	hint.TextWrapped = true
	hint.TextColor3 = UiKit.COLOR_MUTED

	local button =
		UiKit.button(frame, "Ready", UDim2.fromOffset(14, 46), UDim2.fromOffset(272, 32), "Ready")

	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		isReady = not isReady
		Remotes.Events.SetReady:FireServer(isReady)
	end)

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	readyButton = button
	hintLabel = hint
end

local function render()
	local frame = panel
	local button = readyButton
	local hint = hintLabel
	if frame == nil or button == nil or hint == nil then
		return
	end

	local stateName = MatchStore.getStateName()
	local inLobby = stateName == "Lobby" or stateName == "Countdown"
	frame.Visible = inLobby

	if not inLobby then
		-- Match sudah jalan: Ready dari match sebelumnya tidak boleh ikut
		-- terbawa, kalau tidak pemain yang kembali ke lobby langsung dianggap
		-- siap tanpa menekan apa pun.
		isReady = false
		return
	end

	button.Text = if isReady then "Batal siap" else "Ready"
	UiKit.setButtonEnabled(button, true)

	if stateName == "Countdown" then
		hint.Text = "Semua pemain siap. Match dimulai — tekan lagi untuk membatalkan."
	elseif isReady then
		hint.Text = "Kamu siap. Menunggu pemain lain."
	else
		hint.Text = "Tekan Ready untuk mulai. Match baru jalan kalau semua pemain siap."
	end
end

function LobbyController.start()
	if started then
		return
	end
	started = true

	build()
	render()

	MatchStore.onMatchState:Connect(render)
end

return LobbyController
