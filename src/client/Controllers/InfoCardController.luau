--!strict
-- InfoCardController.luau — kartu info malware setelah boss kalah.
--
-- Ini bagian edukasi CONCEPT.md, dan satu-satunya UI di game ini yang menahan
-- perhatian pemain dengan sengaja. Teksnya dibaca dari `Bosses.luau` di client:
-- payload `ShowInfoCard` cuma berisi `bossId` (bagian 3.6), dan teks kartunya
-- data statis yang identik di dua sisi — mengirim seluruh paragrafnya lewat
-- remote cuma menambah trafik tanpa menambah informasi.
--
-- Kartunya punya tombol tutup DAN hilang sendiri setelah beberapa detik. Dua
-- cara, karena kartu ini muncul tepat setelah boss mati — saat itu bisa masih
-- ada musuh pecahan yang berjalan ke Core, dan pemain yang ingin terus
-- bertarung tidak boleh dipaksa membaca dulu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Modules.Bosses)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local InfoCardController = {}

local localPlayer = Players.LocalPlayer

local AUTO_HIDE_SECONDS = 18

local gui: ScreenGui? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local preventionLabel: TextLabel? = nil
local hideToken = 0
local started = false

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseInfoCard", 50)

	local frame =
		UiKit.panel(screen, "Panel", UDim2.new(0.5, -230, 0.5, -170), UDim2.fromOffset(460, 340))
	frame.BackgroundTransparency = 0.03
	frame.Visible = false

	local badge = UiKit.label(
		frame,
		"Badge",
		UDim2.fromOffset(20, 14),
		UDim2.fromOffset(420, 16),
		"KARTU INFO MALWARE"
	)
	badge.TextSize = 12
	badge.TextColor3 = UiKit.COLOR_ACCENT
	badge.Font = Enum.Font.GothamBold

	local title =
		UiKit.label(frame, "Title", UDim2.fromOffset(20, 32), UDim2.fromOffset(420, 28), "")
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22

	local body =
		UiKit.label(frame, "Body", UDim2.fromOffset(20, 66), UDim2.fromOffset(420, 112), "")
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextSize = 14

	local prevention =
		UiKit.label(frame, "Prevention", UDim2.fromOffset(20, 184), UDim2.fromOffset(420, 108), "")
	prevention.TextWrapped = true
	prevention.TextYAlignment = Enum.TextYAlignment.Top
	prevention.TextSize = 14
	prevention.TextColor3 = UiKit.COLOR_GOOD

	local close =
		UiKit.button(frame, "Close", UDim2.fromOffset(20, 298), UDim2.fromOffset(420, 28), "Tutup")
	close.Activated:Connect(function()
		hideToken += 1
		frame.Visible = false
	end)

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	titleLabel = title
	bodyLabel = body
	preventionLabel = prevention
end

local function show(bossId: string)
	build()

	local def = Bosses[bossId]
	if def == nil then
		-- bossId yang tidak dikenal: diam saja. Server yang mengirimnya, jadi
		-- ini cuma pelindung kalau id berubah di satu sisi saja.
		return
	end

	local frame = panel
	local title = titleLabel
	local body = bodyLabel
	local prevention = preventionLabel
	if frame == nil or title == nil or body == nil or prevention == nil then
		return
	end

	local card = def.infoCard
	title.Text = card.title
	body.Text = card.body

	local lines = { "Cara mencegahnya:" }
	for _, item in card.prevention do
		table.insert(lines, "• " .. item)
	end
	prevention.Text = table.concat(lines, "\n")

	frame.Visible = true

	-- Token supaya kartu kedua yang muncul sebelum yang pertama hilang tidak
	-- ikut ditutup oleh timer kartu pertama.
	hideToken += 1
	local token = hideToken
	task.delay(AUTO_HIDE_SECONDS, function()
		if token == hideToken and frame.Visible then
			frame.Visible = false
		end
	end)
end

function InfoCardController.start()
	if started then
		return
	end
	started = true

	build()

	Remotes.Events.ShowInfoCard.OnClientEvent:Connect(function(bossId: unknown)
		if type(bossId) ~= "string" then
			return
		end
		show(bossId :: string)
	end)
end

return InfoCardController
