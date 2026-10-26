--!strict
-- HudController.luau — HP Core, nomor wave, state match, timer, koin tim.
--
-- Semua yang ditampilkan datang dari MatchStore, yang isinya payload
-- `Remotes.MatchState` dan `Remotes.MatchCoins` (bagian 3.6). Controller ini
-- tidak menghitung apa pun: kalau HUD menghitung sendiri (misal menghitung
-- timer turun dengan jamnya sendiri), angkanya akan melenceng dari server
-- begitu ada satu paket yang hilang, dan pemain melihat hitung mundur yang
-- tidak cocok dengan apa yang sebenarnya terjadi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Modules.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchStore = require(script.Parent.MatchStore)
local UiKit = require(script.Parent.UiKit)

local HudController = {}

local localPlayer = Players.LocalPlayer

local STATE_TEXT: { [string]: string } = {
	Lobby = "Di lobby",
	Loadout = "Pilih senjata",
	Countdown = "Match mulai dalam",
	WaveActive = "Bertahan!",
	Intermission = "Jeda — toko buka",
	Ended = "Match selesai",
}

local gui: ScreenGui? = nil
local waveLabel: TextLabel? = nil
local stateLabel: TextLabel? = nil
local coinsLabel: TextLabel? = nil
local coreBar: UiKit.Bar? = nil
local bossPanel: Frame? = nil
local bossBar: UiKit.Bar? = nil
local started = false

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseHud", 10)

	local panel = UiKit.panel(screen, "Top", UDim2.new(0.5, -170, 0, 12), UDim2.fromOffset(340, 76))

	local wave = UiKit.label(panel, "Wave", UDim2.fromOffset(14, 6), UDim2.fromOffset(190, 20), "")
	wave.Font = Enum.Font.GothamBold

	local state =
		UiKit.label(panel, "State", UDim2.fromOffset(14, 28), UDim2.fromOffset(312, 18), "")
	state.TextColor3 = UiKit.COLOR_MUTED
	state.TextSize = 14

	local coins =
		UiKit.label(panel, "Coins", UDim2.fromOffset(204, 6), UDim2.fromOffset(122, 20), "")
	coins.TextXAlignment = Enum.TextXAlignment.Right
	coins.TextColor3 = UiKit.COLOR_WARN

	local core = UiKit.bar(panel, "CoreHp", UDim2.fromOffset(14, 50), UDim2.fromOffset(312, 16))

	-- Panel boss dipasang sekarang tapi disembunyikan sampai BossState bilang
	-- ada boss hidup (M4).
	local boss = UiKit.panel(screen, "Boss", UDim2.new(0.5, -200, 0, 96), UDim2.fromOffset(400, 44))
	boss.Visible = false
	local bossName =
		UiKit.label(boss, "Name", UDim2.fromOffset(12, 4), UDim2.fromOffset(376, 16), "")
	bossName.TextSize = 14
	bossName.TextColor3 = UiKit.COLOR_BAD
	bossName.Font = Enum.Font.GothamBold
	local bossHp = UiKit.bar(boss, "Hp", UDim2.fromOffset(12, 22), UDim2.fromOffset(376, 14))

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	waveLabel = wave
	stateLabel = state
	coinsLabel = coins
	coreBar = core
	bossPanel = boss
	bossBar = bossHp
end

local function renderMatch()
	local payload = MatchStore.get()
	local wave = waveLabel
	local state = stateLabel
	local bar = coreBar
	if payload == nil or wave == nil or state == nil or bar == nil then
		return
	end

	wave.Text = string.format("Wave %d / %d", payload.wave, Config.LAST_WAVE)

	local description = STATE_TEXT[payload.state] or payload.state
	if payload.timer > 0 then
		state.Text = string.format("%s · %ds", description, math.ceil(payload.timer))
	else
		state.Text = description
	end

	-- Sandera upgrade oleh boss Locker ditempel ke baris ini, bukan dibikin
	-- label sendiri, dan BUKAN di panel toko: panel toko cuma muncul saat
	-- `Intermission`, sementara Locker cuma hidup saat `WaveActive` — jadi
	-- pemain tidak akan pernah melihatnya di sana. Baris state ini satu-satunya
	-- teks HUD yang selalu terlihat sepanjang match.
	--
	-- Tanpa pemberitahuan apa pun, damage tim yang tiba-tiba kembali ke nilai
	-- dasar terasa seperti bug, bukan seperti mekanik boss.
	if MatchStore.getShopState().suspended then
		state.Text = state.Text .. " · upgrade tim disandera"
	end

	UiKit.setBar(
		bar,
		payload.coreHp,
		payload.coreMaxHp,
		string.format(
			"Core %d / %d",
			math.floor(payload.coreHp + 0.5),
			math.floor(payload.coreMaxHp + 0.5)
		)
	)
end

local function renderCoins()
	local coins = coinsLabel
	if coins == nil then
		return
	end
	-- Tanpa kata "tim": saldo ini milik pemain yang melihatnya sendiri, dan
	-- "cash tim" menjanjikan satu kolam bersama yang sudah tidak ada.
	coins.Text = string.format("%d cash", MatchStore.getCoins())
end

local function renderBoss()
	local panel = bossPanel
	local bar = bossBar
	if panel == nil or bar == nil then
		return
	end

	local boss = MatchStore.getBossState()
	if boss == nil or not boss.alive then
		panel.Visible = false
		return
	end

	-- Nama dan analoginya dibaca dari Bosses.luau di client, bukan dikirim
	-- server: teksnya data statis yang identik di dua sisi, jadi mengirimnya
	-- tiap update HP cuma menambah trafik tanpa menambah informasi.
	local nameLabel = panel:FindFirstChild("Name")
	if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
		local def = Bosses[boss.bossId]
		nameLabel.Text = if def ~= nil
			then string.format("%s — %s", def.name, def.analogy)
			else boss.bossId
	end

	panel.Visible = true
	local percent = math.ceil((if boss.maxHp > 0 then boss.hp / boss.maxHp else 0) * 100)
	UiKit.setBar(bar, boss.hp, boss.maxHp, string.format("%d%%", percent))
end

function HudController.start()
	if started then
		return
	end
	started = true

	build()
	renderCoins()

	MatchStore.onMatchState:Connect(renderMatch)
	MatchStore.onCoins:Connect(renderCoins)
	MatchStore.onBossState:Connect(renderBoss)
	-- `MatchState` berdetak tiap timer berubah, tapi sandera bisa dipasang dan
	-- dilepas di tengah wave tanpa `MatchState` ikut berubah. Tanpa baris ini,
	-- teksnya baru menyusul di detik berikutnya.
	MatchStore.onShopState:Connect(renderMatch)
end

return HudController
