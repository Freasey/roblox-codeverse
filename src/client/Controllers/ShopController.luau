--!strict
-- ShopController.luau — UI Toko Match.
--
-- Panel ini muncul saat jeda antar wave DAN saat toko dikunci boss Locker,
-- dan tombolnya dinonaktifkan kalau koin tim kurang atau jatah item habis.
-- Semuanya murni presentasi: server tetap memeriksa ulang semuanya di
-- ShopService (bagian 1.2), dan kalau cache client ketinggalan, yang terjadi
-- paling buruk adalah tombol terlihat aktif lalu pembeliannya ditolak dengan
-- alasan yang jelas lewat `ActionResult` — yang juga ditampilkan di sini.
--
-- Harga dan sisa jatah dibaca dari modul shared yang sama dengan server
-- (`ShopItems`, `ShopRules`), bukan dikirim per update: angkanya data statis
-- yang identik di dua sisi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Modules.Balance)
local MatchStore = require(script.Parent.MatchStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopItems = require(ReplicatedStorage.Shared.Modules.ShopItems)
local ShopRules = require(ReplicatedStorage.Shared.Modules.ShopRules)
local UiKit = require(script.Parent.UiKit)

local ShopController = {}

local localPlayer = Players.LocalPlayer

local ROW_HEIGHT = 58
local PANEL_WIDTH = 330

type Row = {
	button: TextButton,
	title: TextLabel,
	detail: TextLabel,
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local rows: { [string]: Row } = {}
local started = false

-- Balasan `ActionResult` terakhir, ditahan di baris status selama beberapa
-- detik. Perlu ditahan dengan penanda waktu, bukan cuma ditulis sekali:
-- `MatchState` dikirim server tiap 0.2 detik dan tiap paketnya memanggil
-- render(), jadi tanpa ini pesannya ketimpa "N cash tim" sebelum pemain
-- selesai membacanya.
local NOTICE_SECONDS = 4
local noticeText: string? = nil
local noticeOk = false
local noticeUntil = 0

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseShop", 30)

	local height = 54 + #ShopItems.order * ROW_HEIGHT
	local frame = UiKit.panel(
		screen,
		"Panel",
		UDim2.new(1, -(PANEL_WIDTH + 16), 0.5, -height // 2),
		UDim2.fromOffset(PANEL_WIDTH, height)
	)
	frame.Visible = false

	local title = UiKit.label(
		frame,
		"Title",
		UDim2.fromOffset(14, 8),
		UDim2.fromOffset(302, 20),
		"Toko Match"
	)
	title.Font = Enum.Font.GothamBold

	local status =
		UiKit.label(frame, "Status", UDim2.fromOffset(14, 28), UDim2.fromOffset(302, 18), "")
	status.TextSize = 13
	status.TextColor3 = UiKit.COLOR_MUTED

	-- Urutan dari ShopItems.order, bukan dari iterasi tabel: urutan iterasi
	-- tabel Luau tidak dijamin, jadi tanpa daftar itu susunan tombol bisa
	-- berbeda tiap kali client dibuka.
	for index, itemId in ShopItems.order do
		local def = ShopItems.get(itemId)
		if def == nil then
			continue
		end

		local top = 52 + (index - 1) * ROW_HEIGHT

		local button = UiKit.button(
			frame,
			itemId,
			UDim2.fromOffset(14, top),
			UDim2.fromOffset(302, ROW_HEIGHT - 8),
			""
		)
		button.Text = ""

		local rowTitle = UiKit.label(
			button,
			"Title",
			UDim2.fromOffset(10, 4),
			UDim2.fromOffset(282, 18),
			def.name
		)
		rowTitle.Font = Enum.Font.GothamBold
		rowTitle.TextSize = 14
		rowTitle.TextColor3 = Color3.fromRGB(16, 18, 24)

		local detail =
			UiKit.label(button, "Detail", UDim2.fromOffset(10, 22), UDim2.fromOffset(282, 26), "")
		detail.TextSize = 12
		detail.TextWrapped = true
		detail.TextColor3 = Color3.fromRGB(40, 44, 54)

		button.Activated:Connect(function()
			if not button.Active then
				return
			end
			Remotes.Events.BuyShopItem:FireServer(itemId)
		end)

		rows[itemId] = { button = button, title = rowTitle, detail = detail }
	end

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	statusLabel = status
end

local function render()
	local frame = panel
	local status = statusLabel
	if frame == nil or status == nil then
		return
	end

	local shop = MatchStore.getShopState()
	local coins = MatchStore.getCoins()
	local stateName = MatchStore.getStateName()

	-- Panel tetap terlihat saat toko terkunci boss, dengan alasannya. Kalau
	-- disembunyikan, pemain tidak tahu bedanya "belum waktunya" dan "dikunci
	-- Locker" — padahal yang kedua adalah mekanik yang harus dia sadari.
	--
	-- `shop.locked` perlu disebut terpisah dari state: Locker cuma hidup saat
	-- `WaveActive` dan wave tidak bisa dinyatakan bersih selama dia hidup,
	-- jadi tidak akan pernah ada Intermission sambil toko terkunci. Tanpa
	-- cabang ini kuncinya tidak terlihat di UI sama sekali.
	frame.Visible = stateName == ShopRules.OPEN_STATE or shop.locked

	if noticeText ~= nil and os.clock() >= noticeUntil then
		noticeText = nil
	end

	local notice = noticeText
	if notice ~= nil then
		status.Text = notice
		status.TextColor3 = if noticeOk then UiKit.COLOR_GOOD else UiKit.COLOR_BAD
	elseif shop.locked then
		status.Text = "Dikunci — kalahkan boss-nya dulu"
		status.TextColor3 = UiKit.COLOR_BAD
	else
		status.Text = string.format("%d cash tim", coins)
		status.TextColor3 = UiKit.COLOR_WARN
	end

	for itemId, row in rows do
		local def = ShopItems.get(itemId)
		if def == nil then
			continue
		end

		local remaining = ShopRules.remaining(def, shop.purchases)
		local remainingText = if remaining == math.huge
			then ""
			else string.format(" · sisa %d", remaining)
		-- Harga SEKARANG, bukan `def.cost`. Untuk item tak terbatas harganya
		-- naik tiap pembelian, dan tombol yang menampilkan harga dasar akan
		-- memotong cash lebih banyak daripada yang tertulis -- pemain akan
		-- menganggapnya bug, dan dia benar.
		local price = ShopRules.priceFor(def, shop.purchases, Balance.SHOP_PRICE_GROWTH)
		row.detail.Text = string.format("%d cash%s — %s", price, remainingText, def.description)

		local canBuy = ShopRules.canBuy(def, {
			state = stateName,
			locked = shop.locked,
			coins = coins,
			purchases = shop.purchases,
			priceGrowth = Balance.SHOP_PRICE_GROWTH,
		})
		UiKit.setButtonEnabled(row.button, canBuy)
		row.title.TextColor3 = if canBuy
			then Color3.fromRGB(16, 18, 24)
			else Color3.fromRGB(140, 145, 155)
		row.detail.TextColor3 = if canBuy
			then Color3.fromRGB(40, 44, 54)
			else Color3.fromRGB(120, 125, 135)
	end
end

function ShopController.start()
	if started then
		return
	end
	started = true

	build()
	render()

	MatchStore.onShopState:Connect(render)
	MatchStore.onMatchState:Connect(render)
	MatchStore.onCoins:Connect(render)

	-- Penolakan pembelian ditampilkan di baris status panel toko. Tanpa ini
	-- tidak ada yang menampilkannya di mana pun: satu-satunya pendengar
	-- `ActionResult` yang lain adalah LobbyController, dan panel lobby
	-- disembunyikan di luar state Lobby/Loadout/Countdown — persis saat toko
	-- buka.
	-- Tombol yang ditolak server jadi terlihat sama seperti tombol yang rusak.
	--
	-- Disaring lewat `payload.action`: aksi lobby (SelectLoadout, upgrade,
	-- beli, craft senjata) bukan urusan panel ini dan sudah ada tempatnya
	-- sendiri.
	Remotes.Events.ActionResult.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if payload.action ~= "BuyShopItem" or type(payload.ok) ~= "boolean" then
			return
		end

		noticeOk = payload.ok :: boolean
		if noticeOk then
			noticeText = "Pembelian berhasil."
		else
			noticeText = if type(payload.reason) == "string"
				then payload.reason :: string
				else "Ditolak server."
		end
		noticeUntil = os.clock() + NOTICE_SECONDS
		render()

		-- Dikembalikan ke teks biasa setelah beberapa detik supaya pesan
		-- penolakan lama tidak menempel selamanya. render() yang dipicu
		-- `MatchState` biasanya sudah melakukannya lebih dulu; ini jaringnya
		-- kalau paket itu berhenti datang (match selesai).
		task.delay(NOTICE_SECONDS, render)
	end)
end

return ShopController
