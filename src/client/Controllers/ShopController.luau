--!strict
-- ShopController.luau — UI Toko Match, yang sekarang menjual UPGRADE SENJATA.
--
-- Panel ini muncul saat jeda antar wave dan saat toko dikunci boss Locker.
-- Yang ditawarkan satu hal saja: menaikkan satu level senjata yang sedang
-- dipakai pemain, dibayar cash. Lima item tim yang dulu ada di sini sudah
-- dimatikan (`Config.MATCH_SHOP_ITEMS_ENABLED`).
--
-- Satu baris, bukan daftar, dan itu mengikuti bentuk fiturnya: fase `Loadout`
-- sudah mengunci senjata yang dipakai sampai match selesai, jadi tidak pernah
-- ada lebih dari satu senjata yang bisa di-upgrade di sini.
--
-- Di level percabangan panel ini berubah bentuk: tombol tunggalnya diganti
-- tiga kartu alur berjajar, masing-masing dengan tombol konfirmasinya sendiri.
-- Berjajar dan bukan satu per satu karena itu syarat rancangan
-- (ARENA_REDESIGN.md bagian 3) -- pilihan yang diambil tanpa melihat dua alur
-- lain bukan keputusan. Bedanya dengan versi lobby dulu: pilihannya cuma
-- mengikat sampai match ini selesai, bukan selamanya.
--
-- Semuanya murni presentasi. Server memeriksa ulang semuanya di ShopService
-- lewat `MatchUpgradeRules` yang SAMA dengan yang dibaca file ini, jadi tombol
-- yang hidup di sini adalah tombol yang akan diterima di sana. Kalau cache
-- client ketinggalan, yang terjadi paling buruk tombol terlihat aktif lalu
-- ditolak dengan alasan yang jelas lewat `ActionResult` -- yang juga
-- ditampilkan di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local MatchUpgradeRules = require(Shared.Modules.MatchUpgradeRules)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Modules.Types)
local Weapons = require(Shared.Modules.Weapons)

local MatchStore = require(script.Parent.MatchStore)
local UiKit = require(script.Parent.UiKit)

local ShopController = {}

local localPlayer = Players.LocalPlayer

local PANEL_WIDTH = 330
local PAD = 14
local INNER = PANEL_WIDTH - PAD * 2
-- Tinggi satu kartu alur: judul, tema, tiga baris tingkat, tombol.
local CARD_HEIGHT = 128
local CARD_GAP = 8
local HEADER_HEIGHT = 108

type Card = {
	root: Frame,
	title: TextLabel,
	body: TextLabel,
	confirm: TextButton,
	pathId: string?,
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil
local upgradeButton: TextButton? = nil
local cards: { Card } = {}
local started = false

-- Balasan `ActionResult` terakhir, ditahan di baris status selama beberapa
-- detik. Perlu ditahan dengan penanda waktu, bukan cuma ditulis sekali:
-- `MatchState` dikirim server tiap 0.2 detik dan tiap paketnya memanggil
-- render(), jadi tanpa ini pesannya ketimpa "N cash" sebelum pemain selesai
-- membacanya.
local NOTICE_SECONDS = 4
local noticeText: string? = nil
local noticeOk = false
local noticeUntil = 0

-- Senjata dan save yang berlaku sekarang. Nil kalau server belum mengirim
-- apa pun -- sebelum match pertama, misalnya.
local function currentWeapon(): (Types.WeaponDef?, Types.WeaponSave)
	local state = MatchStore.getUpgradeState()
	if state == nil then
		return nil, MatchUpgradeRules.freshSave()
	end
	return Weapons[state.weaponId], { level = state.level, path = state.path }
end

local function send(pathId: string?)
	local state = MatchStore.getUpgradeState()
	if state == nil then
		return
	end
	Remotes.Events.UpgradeWeapon:FireServer(state.weaponId, pathId)
end

local function describeStats(def: Types.WeaponDef, save: Types.WeaponSave): string
	local stats = Balance.weaponStats(def, save)
	return string.format(
		"damage %d · jeda %.2fs · jangkauan %d",
		math.floor(stats.damage + 0.5),
		stats.cooldown,
		math.floor(stats.range + 0.5)
	)
end

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseShop", 30)
	-- Tinggi awal saja; `resize` yang menentukan tinggi sebenarnya tiap render,
	-- karena panel ini berganti bentuk antara satu tombol dan tiga kartu.
	local height = HEADER_HEIGHT + PAD
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
		UDim2.fromOffset(PAD, 10),
		UDim2.fromOffset(INNER, 20),
		"Upgrade Senjata"
	)
	title.Font = Enum.Font.GothamBold

	local status =
		UiKit.label(frame, "Status", UDim2.fromOffset(PAD, 32), UDim2.fromOffset(INNER, 16), "")
	status.TextSize = 12
	status.TextColor3 = UiKit.COLOR_WARN

	local detail =
		UiKit.label(frame, "Detail", UDim2.fromOffset(PAD, 50), UDim2.fromOffset(INNER, 32), "")
	detail.TextSize = 12
	detail.TextWrapped = true
	detail.TextColor3 = UiKit.COLOR_MUTED

	local button = UiKit.button(
		frame,
		"Upgrade",
		UDim2.fromOffset(PAD, 86),
		UDim2.fromOffset(INNER, 28),
		"Upgrade"
	)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		send(nil)
	end)

	-- Kartu alur dibuat sebanyak alur TERBANYAK yang dimiliki senjata mana
	-- pun, lalu disembunyikan yang tidak terpakai. Dibuat sekali di sini dan
	-- bukan tiap render: membuat Instance tiap frame membuat panel berkedip
	-- dan menumpuk sampah.
	local maxPaths = 0
	for _, def in Weapons do
		maxPaths = math.max(maxPaths, #def.paths)
	end

	for index = 1, maxPaths do
		local card = UiKit.panel(
			frame,
			string.format("Path%d", index),
			UDim2.fromOffset(PAD, HEADER_HEIGHT + (index - 1) * (CARD_HEIGHT + CARD_GAP)),
			UDim2.fromOffset(INNER, CARD_HEIGHT)
		)
		card.BackgroundColor3 = Color3.fromRGB(26, 29, 36)
		card.Visible = false

		local cardTitle = UiKit.label(
			card,
			"Title",
			UDim2.fromOffset(10, 6),
			UDim2.fromOffset(INNER - 20, 16),
			""
		)
		cardTitle.Font = Enum.Font.GothamBold
		cardTitle.TextSize = 14

		local body = UiKit.label(
			card,
			"Body",
			UDim2.fromOffset(10, 24),
			UDim2.fromOffset(INNER - 20, 70),
			""
		)
		body.TextSize = 11
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextColor3 = UiKit.COLOR_MUTED

		local confirm = UiKit.button(
			card,
			"Confirm",
			UDim2.fromOffset(10, CARD_HEIGHT - 32),
			UDim2.fromOffset(INNER - 20, 24),
			"Pilih alur ini"
		)
		confirm.TextSize = 12

		local entry: Card = {
			root = card,
			title = cardTitle,
			body = body,
			confirm = confirm,
			pathId = nil,
		}
		confirm.Activated:Connect(function()
			if not confirm.Active then
				return
			end
			-- Alur dibaca saat KLIK dari state kartunya, bukan ditangkap saat
			-- kartu dibuat: kartu yang sama dipakai ulang untuk senjata yang
			-- berbeda, jadi id yang ditangkap sekali akan mengunci alur
			-- senjata yang sudah lama tidak ditampilkan.
			send(entry.pathId)
		end)

		cards[index] = entry
	end

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	statusLabel = status
	titleLabel = title
	detailLabel = detail
	upgradeButton = button
end

-- Tinggi panel mengikuti apa yang sedang ditampilkan: satu tombol, atau tiga
-- kartu alur. Dihitung dari isinya dan bukan dipatok, dengan alasan yang sama
-- seperti panel lobby -- angka tinggi yang ditebak akan menindih isinya begitu
-- jumlah kartunya berubah.
local function resize(visibleCards: number)
	local frame = panel
	if frame == nil then
		return
	end
	local height = HEADER_HEIGHT + PAD
	if visibleCards > 0 then
		height = HEADER_HEIGHT + visibleCards * (CARD_HEIGHT + CARD_GAP) + PAD
	end
	frame.Size = UDim2.fromOffset(PANEL_WIDTH, height)
	frame.Position = UDim2.new(1, -(PANEL_WIDTH + 16), 0.5, -height // 2)
end

local function render()
	local frame = panel
	local status = statusLabel
	local title = titleLabel
	local detail = detailLabel
	local button = upgradeButton
	if frame == nil or status == nil or title == nil or detail == nil or button == nil then
		return
	end

	local stateName = MatchStore.getStateName()
	local shop = MatchStore.getShopState()
	frame.Visible = stateName == MatchUpgradeRules.OPEN_STATE or shop.locked

	local cash = MatchStore.getCoins()
	local def, save = currentWeapon()

	if def == nil then
		title.Text = "Upgrade Senjata"
		detail.Text = "Senjata belum siap."
		UiKit.setButtonEnabled(button, false)
		button.Visible = true
		for _, card in cards do
			card.root.Visible = false
		end
		resize(0)
		status.Text = string.format("%d cash", cash)
		status.TextColor3 = UiKit.COLOR_WARN
		return
	end

	local weapon = def :: Types.WeaponDef
	title.Text = string.format("%s · level %d/%d", weapon.name, save.level, weapon.maxLevel)

	-- Baris status: balasan terakhir kalau masih baru, lalu kunci boss, lalu
	-- saldo. Urutannya sama dengan versi sebelumnya karena alasannya sama:
	-- penolakan yang ketimpa saldo sebelum sempat dibaca sama saja dengan
	-- tidak ada penolakan.
	local notice = noticeText
	if notice ~= nil and os.clock() < noticeUntil then
		status.Text = notice
		status.TextColor3 = if noticeOk then UiKit.COLOR_GOOD else UiKit.COLOR_BAD
	elseif shop.locked then
		status.Text = "Dikunci — kalahkan boss-nya dulu"
		status.TextColor3 = UiKit.COLOR_BAD
	else
		status.Text = string.format("%d cash", cash)
		status.TextColor3 = UiKit.COLOR_WARN
	end

	local needsPath = ProgressionRules.pathChoiceRequired(save)
	local price = MatchUpgradeRules.priceFor(weapon, save)
	local ok = MatchUpgradeRules.canUpgrade(weapon, save, {
		state = stateName,
		cash = cash,
		locked = shop.locked,
	}, if needsPath then nil else save.path)

	if save.level >= weapon.maxLevel then
		detail.Text = string.format("%s · sudah maksimum", describeStats(weapon, save))
	else
		local next = { level = save.level + 1, path = save.path }
		detail.Text = string.format(
			"%s\nsesudah upgrade: %s",
			describeStats(weapon, save),
			describeStats(weapon, next)
		)
	end

	if not needsPath then
		button.Visible = true
		button.Text = if save.level >= weapon.maxLevel
			then "Level maksimum"
			else string.format("Upgrade — %d cash", price)
		UiKit.setButtonEnabled(button, ok)
		for _, card in cards do
			card.root.Visible = false
		end
		resize(0)
		return
	end

	-- Titik percabangan: tombol tunggal diganti kartu alur.
	button.Visible = false
	detail.Text = string.format(
		"Level %d mengunci satu alur sampai match ini selesai. Baca ketiganya dulu — %d cash.",
		Balance.PATH_BRANCH_LEVEL,
		price
	)

	local shown = 0
	for index, card in cards do
		local path = weapon.paths[index]
		if path == nil then
			card.root.Visible = false
			continue
		end
		shown += 1
		card.pathId = path.id
		card.root.Visible = true
		card.title.Text = path.name

		local lines = { path.theme }
		for _, tier in path.tiers do
			table.insert(lines, string.format("L%d  %s", tier.level, tier.summary))
		end
		card.body.Text = table.concat(lines, "\n")

		card.confirm.Text = string.format("Pilih %s", path.name)
		-- Tiap kartu ditanya SENDIRI ke aturan yang sama dengan server, dengan
		-- alur kartunya. Satu jawaban untuk ketiganya akan salah begitu ada
		-- alur yang punya syarat sendiri nanti.
		local cardOk = MatchUpgradeRules.canUpgrade(weapon, save, {
			state = stateName,
			cash = cash,
			locked = shop.locked,
		}, path.id)
		UiKit.setButtonEnabled(card.confirm, cardOk)
	end

	resize(shown)
end

function ShopController.start()
	if started then
		return
	end
	started = true

	build()
	render()

	MatchStore.onMatchState:Connect(render)
	MatchStore.onShopState:Connect(render)
	MatchStore.onUpgradeState:Connect(render)
	MatchStore.onCoins:Connect(render)

	Remotes.Events.ActionResult.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if payload.action ~= "UpgradeWeapon" and payload.action ~= "BuyShopItem" then
			return
		end
		noticeOk = payload.ok == true
		noticeText = if type(payload.reason) == "string"
			then payload.reason :: string
			else if noticeOk then "Upgrade terpasang." else "Ditolak."
		noticeUntil = os.clock() + NOTICE_SECONDS
		render()
	end)
end

return ShopController
