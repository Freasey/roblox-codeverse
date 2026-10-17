--!strict
-- ResultController.luau — layar hasil match, lalu hilang sendiri saat kembali
-- ke lobby.
--
-- Isinya murni dari payload `Remotes.MatchResult` (bagian 3.6). Controller ini
-- tidak menghitung reward: angka yang ditampilkan harus angka yang
-- benar-benar disimpan server, kalau tidak pemain melihat "+120 koin" lalu
-- menemukan 100 di lobby dan menganggap progresnya hilang.
--
-- Layar ini TIDAK punya tombol tutup. Server mengembalikan state ke Lobby
-- setelah MatchService.ENDED_SECONDS, dan layar mengikuti state itu — bukan
-- timer sendiri, supaya tidak ada versi kebenaran kedua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchStore = require(script.Parent.MatchStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local ResultController = {}

local localPlayer = Players.LocalPlayer

export type MatchResultPayload = {
	won: boolean,
	waveReached: number,
	coins: number,
	xp: number,
	materials: { [string]: number },
	unlocked: { string },
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local started = false

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseResult", 40)

	local frame =
		UiKit.panel(screen, "Panel", UDim2.new(0.5, -200, 0.5, -130), UDim2.fromOffset(400, 260))
	frame.BackgroundTransparency = 0.05
	frame.Visible = false

	local title =
		UiKit.label(frame, "Title", UDim2.fromOffset(20, 18), UDim2.fromOffset(360, 28), "")
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24

	local body =
		UiKit.label(frame, "Body", UDim2.fromOffset(20, 56), UDim2.fromOffset(360, 186), "")
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextSize = 15
	body.TextColor3 = UiKit.COLOR_TEXT

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	titleLabel = title
	bodyLabel = body
end

local function isValid(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local payload = value :: { [string]: unknown }
	return type(payload.won) == "boolean"
		and type(payload.waveReached) == "number"
		and type(payload.coins) == "number"
		and type(payload.xp) == "number"
		and type(payload.materials) == "table"
		and type(payload.unlocked) == "table"
end

local function show(payload: MatchResultPayload)
	build()
	local frame = panel
	local title = titleLabel
	local body = bodyLabel
	if frame == nil or title == nil or body == nil then
		return
	end

	title.Text = if payload.won then "Core Server aman!" else "Core Server jebol"
	title.TextColor3 = if payload.won then UiKit.COLOR_GOOD else UiKit.COLOR_BAD

	local lines: { string } = {}
	table.insert(lines, string.format("Wave tercapai: %d", payload.waveReached))
	table.insert(lines, string.format("Koin: +%d", payload.coins))
	table.insert(lines, string.format("XP: +%d", payload.xp))

	local materials: { string } = {}
	for id, amount in payload.materials do
		table.insert(materials, string.format("%s x%d", id, amount))
	end
	table.sort(materials)
	if #materials > 0 then
		table.insert(lines, "Material: " .. table.concat(materials, ", "))
	end

	if #payload.unlocked > 0 then
		table.insert(lines, "Terbuka: " .. table.concat(payload.unlocked, ", "))
	end

	table.insert(lines, "")
	table.insert(lines, "Kembali ke lobby sebentar lagi...")

	body.Text = table.concat(lines, "\n")
	frame.Visible = true
end

local function hide()
	local frame = panel
	if frame ~= nil then
		frame.Visible = false
	end
end

function ResultController.start()
	if started then
		return
	end
	started = true

	build()

	Remotes.Events.MatchResult.OnClientEvent:Connect(function(raw: unknown)
		if not isValid(raw) then
			return
		end
		show(raw :: MatchResultPayload)
	end)

	-- Layar ditutup oleh perpindahan state, bukan oleh timer sendiri.
	MatchStore.onMatchState:Connect(function(payload)
		if payload.state ~= "Ended" then
			hide()
		end
	end)
end

return ResultController
