--!strict
-- LobbyController.luau — UI lobby: pilih senjata, pilih kesulitan, Ready,
-- panel upgrade dan craft, dan panel pemilihan alur upgrade.
--
-- Soal panel pemilihan alur: upgrade ke level `Balance.PATH_BRANCH_LEVEL`
-- mengunci satu dari tiga alur SELAMANYA, jadi tombol Upgrade di baris senjata
-- tidak mengirim apa pun di level itu — dia membuka panel yang menampilkan
-- ketiga alur sekaligus beserta ketiga tingkatnya, lalu tiap alur punya tombol
-- konfirmasinya sendiri. Ketiganya ditampilkan berjajar dan bukan satu per satu
-- karena itu syarat rancangan (ARENA_REDESIGN.md bagian 3, "Satu syarat UI yang
-- bukan opsional"): pilihan permanen yang diambil tanpa melihat dua alur lain
-- bukan keputusan, dan pemain yang merasa terjebak di level 10 berhenti main.
--
-- Kapan panel itu muncul diputuskan `ProgressionRules.pathChoiceRequired`, bukan
-- oleh perbandingan level yang ditulis di file ini. Fungsi itu juga yang dipakai
-- server untuk MENOLAK upgrade tanpa pilihan alur, jadi panel yang muncul dan
-- penolakan yang menagihnya tidak bisa bergeser ke level yang berbeda.
--
-- Semua tombol di sini cuma mengirim NIAT (`SetReady`, `SelectLoadout`,
-- `UpgradeWeapon`, `BuyWeapon`, `CraftWeapon`) dengan id saja. Harga, syarat,
-- dan hasilnya diputuskan server (bagian 1.2). Yang ditampilkan di sini dibaca
-- dari modul shared yang sama dengan server (`Weapons`, `Difficulties`,
-- `Balance`, `ProgressionRules`) plus cache data pemain di `ProfileStore`.
--
-- Kalau cache itu ketinggalan, yang terjadi paling buruk adalah tombol
-- terlihat aktif lalu aksinya ditolak server dengan alasan yang jelas lewat
-- `ActionResult` — bukan progres yang salah.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Config = require(Shared.Config)
local Difficulties = require(Shared.Modules.Difficulties)
local MatchRules = require(Shared.Modules.MatchRules)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Modules.Weapons)

local MatchStore = require(script.Parent.MatchStore)
local ProfileStore = require(script.Parent.ProfileStore)
local UiKit = require(script.Parent.UiKit)

local LobbyController = {}

local localPlayer = Players.LocalPlayer

local PANEL_WIDTH = 340
local ROW_HEIGHT = 66

-- Tinggi panel DIHITUNG dari isinya, bukan ditebak. Versi sebelumnya memakai
-- `150 + jumlahSenjata * ROW_HEIGHT` untuk tingginya lalu menaruh baris
-- petunjuk di `height - 56`, dan dua angka itu tidak pernah dihubungkan satu
-- sama lain. Dengan tiga senjata hasilnya bertabrakan: baris senjata terakhir
-- berakhir di y=310 sementara petunjuknya mulai di y=292, jadi teks petunjuk
-- menindih tombol Pakai dan Craft milik senjata ketiga.
--
-- Sekarang tiap bagian menyumbang tingginya sendiri dan posisinya diturunkan
-- dari bagian di atasnya, jadi menambah senjata keempat menggeser semuanya
-- alih-alih menumpuknya.
local ROWS_TOP = 120
local HINT_HEIGHT = 26
local READY_HEIGHT = 24
local SECTION_GAP = 6
local PANEL_PAD = 12

-- Urutan tampil dipatok di sini, bukan dari iterasi tabel: urutan iterasi
-- tabel Luau tidak dijamin, jadi tanpa daftar ini susunan tombol bisa berbeda
-- tiap kali client dibuka.
local WEAPON_ORDER = { "weapon_starter", "weapon_ranged", "weapon_boss_a" }
local DIFFICULTY_ORDER = { "normal", "hard" }

type WeaponRow = {
	root: Frame,
	title: TextLabel,
	detail: TextLabel,
	action: TextButton,
	equip: TextButton,
}

-- Satu kartu alur di panel pemilihan. Kartunya dibuat sekali di `build()` dan
-- dipakai ulang untuk senjata mana pun, jadi `pathId` BUKAN konstanta kartu: dia
-- diisi `renderPathPanel` tiap kali panel dibuka. Tombol konfirmasi membaca
-- field ini saat diklik, bukan menangkap id saat kartunya dibuat.
type PathCard = {
	root: Frame,
	name: TextLabel,
	theme: TextLabel,
	tiers: { TextLabel },
	confirm: TextButton,
	pathId: string?,
}

-- Aksi yang balasannya milik panel ini. `ActionResult` dipakai bersama panel
-- toko (ShopService mengirim `BuyShopItem` lewat remote yang sama), jadi tanpa
-- daftar ini panel lobby ikut menampilkan penolakan pembelian toko — di state
-- yang panelnya sendiri sudah disembunyikan.
local OWN_ACTIONS: { [string]: true } = {
	SelectLoadout = true,
	UpgradeWeapon = true,
	BuyWeapon = true,
	CraftWeapon = true,
}

-- Balasan `ActionResult` terakhir, ditahan di baris petunjuk selama beberapa
-- detik. Perlu penanda waktu, bukan sekadar ditulis sekali: `MatchState`
-- dikirim server tiap 0.2 detik dan tiap paketnya memanggil render(), yang
-- menulis ulang baris petunjuk — tanpa penahan ini pesannya hilang sebelum
-- pemain selesai membacanya.
local NOTICE_SECONDS = 4
local noticeText: string? = nil
local noticeOk = false
local noticeUntil = 0

local gui: ScreenGui? = nil
local panel: Frame? = nil
local readyButton: TextButton? = nil
local hintLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local weaponRows: { [string]: WeaponRow } = {}
local difficultyButtons: { [string]: TextButton } = {}

local isReady = false
local selectedDifficulty = "normal"
local started = false

-- Jumlah kartu dan jumlah baris tingkat yang harus DIBUAT, diambil dari seluruh
-- definisi senjata yang ditampilkan panel ini.
--
-- Dihitung, bukan dipatok "3 dan 3", walau ketiga senjata di `Weapons.luau`
-- sekarang memang 3 alur dengan 3 tingkat. Kartunya dibuat sekali lalu dipakai
-- ulang, jadi angka yang dipatok akan DIAM-DIAM memotong alur keempat atau
-- tingkat keempat yang ditambahkan nanti -- dan alur yang tidak pernah terlihat
-- adalah alur yang tidak pernah dipilih, tanpa satu pun error yang menunjukkan
-- kenapa. Senjata dengan alur lebih SEDIKIT diurus `renderPathPanel`, yang
-- menyembunyikan kartu sisanya.
local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseLobby", 20)

	-- `ROW_HEIGHT` sudah memuat jarak 8px antar baris, jadi dasar baris terakhir
	-- adalah tempat petunjuk boleh mulai.
	local hintTop = ROWS_TOP + #WEAPON_ORDER * ROW_HEIGHT
	local readyTop = hintTop + HINT_HEIGHT + SECTION_GAP
	local height = readyTop + READY_HEIGHT + PANEL_PAD
	local frame = UiKit.panel(
		screen,
		"Panel",
		UDim2.new(0, 16, 0.5, -height // 2),
		UDim2.fromOffset(PANEL_WIDTH, height)
	)

	local title =
		UiKit.label(frame, "Title", UDim2.fromOffset(14, 10), UDim2.fromOffset(312, 20), "Lobby")
	title.Font = Enum.Font.GothamBold

	local status =
		UiKit.label(frame, "Status", UDim2.fromOffset(14, 30), UDim2.fromOffset(312, 18), "")
	status.TextSize = 13
	status.TextColor3 = UiKit.COLOR_WARN

	-- Kesulitan -------------------------------------------------------------
	local difficultyTitle = UiKit.label(
		frame,
		"DifficultyTitle",
		UDim2.fromOffset(14, 52),
		UDim2.fromOffset(312, 16),
		"Tingkat kesulitan"
	)
	difficultyTitle.TextSize = 12
	difficultyTitle.TextColor3 = UiKit.COLOR_MUTED

	local buttonWidth = (312 - 8) // #DIFFICULTY_ORDER
	for index, difficultyId in DIFFICULTY_ORDER do
		local def = Difficulties[difficultyId]
		if def == nil then
			continue
		end
		local button = UiKit.button(
			frame,
			difficultyId,
			UDim2.fromOffset(14 + (index - 1) * (buttonWidth + 8), 70),
			UDim2.fromOffset(buttonWidth, 26),
			def.name
		)
		button.Activated:Connect(function()
			if not button.Active then
				return
			end
			selectedDifficulty = difficultyId
			-- Senjata dan kesulitan dikirim bersama karena tabel bagian 3.6
			-- memaku `SelectLoadout` menerima dua argumen sekaligus.
			local data = ProfileStore.get()
			local weaponId = if data ~= nil then data.equippedWeapon else "weapon_starter"
			Remotes.Events.SelectLoadout:FireServer(weaponId, difficultyId)
		end)
		difficultyButtons[difficultyId] = button
	end

	-- Senjata ---------------------------------------------------------------
	local weaponTitle = UiKit.label(
		frame,
		"WeaponTitle",
		UDim2.fromOffset(14, 102),
		UDim2.fromOffset(312, 16),
		"Senjata"
	)
	weaponTitle.TextSize = 12
	weaponTitle.TextColor3 = UiKit.COLOR_MUTED

	for index, weaponId in WEAPON_ORDER do
		local def = Weapons[weaponId]
		if def == nil then
			continue
		end

		local row = UiKit.panel(
			frame,
			weaponId,
			UDim2.fromOffset(14, ROWS_TOP + (index - 1) * ROW_HEIGHT),
			UDim2.fromOffset(312, ROW_HEIGHT - 8)
		)
		row.BackgroundColor3 = Color3.fromRGB(26, 29, 36)

		local rowTitle =
			UiKit.label(row, "Title", UDim2.fromOffset(10, 4), UDim2.fromOffset(292, 16), def.name)
		rowTitle.Font = Enum.Font.GothamBold
		rowTitle.TextSize = 13

		local detail =
			UiKit.label(row, "Detail", UDim2.fromOffset(10, 20), UDim2.fromOffset(292, 14), "")
		detail.TextSize = 11
		detail.TextColor3 = UiKit.COLOR_MUTED

		local equip =
			UiKit.button(row, "Equip", UDim2.fromOffset(10, 36), UDim2.fromOffset(140, 20), "Pakai")
		equip.TextSize = 12
		equip.Activated:Connect(function()
			if not equip.Active then
				return
			end
			Remotes.Events.SelectLoadout:FireServer(weaponId, selectedDifficulty)
		end)

		local action =
			UiKit.button(row, "Action", UDim2.fromOffset(158, 36), UDim2.fromOffset(144, 20), "")
		action.TextSize = 12
		action.Activated:Connect(function()
			if not action.Active then
				return
			end
			-- Satu tombol, tiga aksi: remote mana yang dikirim ditentukan
			-- status senjata dan `acquire.method`-nya, bukan oleh teks tombol.
			-- Senjata yang sudah dimiliki tidak punya aksi apa pun di lobby.
			-- Upgrade pindah ke dalam match dan dibayar cash, jadi tombol ini
			-- cuma untuk MENDAPATKAN senjata yang belum dimiliki.
			if ProfileStore.owns(weaponId) then
				return
			elseif def.acquire.method == "buy" then
				Remotes.Events.BuyWeapon:FireServer(weaponId)
			elseif def.acquire.method == "craft" then
				Remotes.Events.CraftWeapon:FireServer(weaponId)
			end
		end)

		weaponRows[weaponId] = {
			root = row,
			title = rowTitle,
			detail = detail,
			action = action,
			equip = equip,
		}
	end

	-- Ready -----------------------------------------------------------------
	local hint = UiKit.label(
		frame,
		"Hint",
		UDim2.fromOffset(14, hintTop),
		UDim2.fromOffset(312, HINT_HEIGHT),
		""
	)
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextColor3 = UiKit.COLOR_MUTED

	local button = UiKit.button(
		frame,
		"Ready",
		UDim2.fromOffset(14, readyTop),
		UDim2.fromOffset(312, READY_HEIGHT),
		"Ready"
	)
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
	statusLabel = status
end

local function describeWeapon(weaponId: string): string
	local def = Weapons[weaponId]
	if def == nil then
		return ""
	end

	local level = ProfileStore.getWeaponLevel(weaponId)
	if level == nil then
		-- Belum dimiliki: yang relevan adalah cara mendapatkannya.
		if def.acquire.method == "buy" then
			return string.format("Belum dimiliki — %d koin", def.acquire.coinCost or 0)
		end
		if def.acquire.method == "craft" then
			local parts: { string } = {}
			local needed: { [string]: number } = def.acquire.materials or {}
			for materialId, amount in needed do
				table.insert(
					parts,
					string.format(
						"%s %d/%d",
						materialId,
						ProfileStore.getMaterial(materialId),
						amount
					)
				)
			end
			table.sort(parts)
			return "Belum dimiliki — craft: " .. table.concat(parts, ", ")
		end
		return "Belum dimiliki"
	end

	-- Stat DASAR, level 1 tanpa alur, dan itu memang yang benar di lobby:
	-- upgrade senjata hidup di dalam match dan dimulai ulang tiap match, jadi
	-- tidak ada level permanen yang bisa ditampilkan di sini. Menulis level
	-- dari `data.weapons` akan selalu berbunyi "Level 1/10" selamanya --
	-- angka yang tidak pernah bergerak, yang terbaca sebagai progres yang
	-- rusak.
	local stats = Balance.weaponStats(def, { level = 1, path = "none" })
	local pathText = string.format(" · %d alur", #def.paths)

	return string.format(
		"damage %d · %s%s",
		math.floor(stats.damage + 0.5),
		if def.kind == "melee" then "jarak dekat" else "jarak jauh",
		pathText
	)
end

local function render()
	local frame = panel
	local button = readyButton
	local hint = hintLabel
	local status = statusLabel
	if frame == nil or button == nil or hint == nil or status == nil then
		return
	end

	local stateName = MatchStore.getStateName()
	-- Daftar state-nya dari MatchRules, daftar yang sama yang dipakai server
	-- untuk menolak `SelectLoadout`. Tombol Equip yang hidup di state yang
	-- ditolak server, atau mati di fase `Loadout` yang justru dibuat untuk
	-- menekannya, dua-duanya terlihat seperti tombol rusak.
	local canSelect = MatchRules.canSelectLoadout(stateName)
	-- Disimpan sebagai boolean, bukan dibandingkan ulang di bawah: gerbang
	-- `return` berikutnya membandingkan `stateName` dengan satu literal, dan
	-- itu membuat Luau menyempitkan tipenya jadi `"Countdown"` untuk SELURUH
	-- sisa fungsi -- lalu perbandingan dengan "Loadout" di baris petunjuk
	-- ditolak type checker sebagai perbandingan yang tidak mungkin.
	local inCountdown = stateName == "Countdown"
	-- Panel tetap terlihat sepanjang Loadout dan Countdown. Loadout adalah
	-- satu-satunya fase yang gunanya memilih di panel ini, jadi panel yang
	-- hilang di situ membuat fasenya tidak ada artinya.
	frame.Visible = canSelect or inCountdown

	if not canSelect and not inCountdown then
		-- Match sudah jalan: Ready dari match sebelumnya tidak boleh terbawa,
		-- kalau tidak pemain yang kembali ke lobby langsung dianggap siap
		-- tanpa menekan apa pun.
		isReady = false
		return
	end

	local data = ProfileStore.get()
	if data == nil then
		status.Text = "Memuat data..."
		UiKit.setButtonEnabled(button, false)
		return
	end

	status.Text = string.format("Level %d · %d koin", data.level, data.coins)

	-- Kesulitan: yang belum terbuka dimatikan, yang dipilih ditandai.
	for difficultyId, difficultyButton in difficultyButtons do
		local unlocked = ProfileStore.hasDifficulty(difficultyId)
		UiKit.setButtonEnabled(difficultyButton, unlocked and canSelect)
		local def = Difficulties[difficultyId]
		local name = if def ~= nil then def.name else difficultyId
		if not unlocked then
			difficultyButton.Text = name .. " (terkunci)"
		else
			difficultyButton.Text = name
		end

		-- Yang TIDAK terpilih diredupkan; yang terpilih dibiarkan warna aksen
		-- penuh. Penandanya warna, bukan karakter, karena versi sebelumnya
		-- menempelkan "▸" di depan nama dan glyph itu tidak ada di font
		-- Gotham milik Roblox: yang muncul di layar kotak kosong, dan kotak
		-- kosong terbaca sebagai teks rusak, bukan sebagai penanda pilihan.
		-- Titik tengah dan em dash di panel ini tampil benar, jadi batas
		-- fontnya ada di antara Latin-1 dan bentuk geometri -- bukan sesuatu
		-- yang bisa ditebak aman untuk karakter penanda berikutnya.
		if unlocked and canSelect and difficultyId ~= selectedDifficulty then
			difficultyButton.BackgroundColor3 = Color3.fromRGB(58, 86, 112)
		end
	end

	-- Senjata.
	--
	-- Dua daftar kepemilikan, dan bedanya penting. `equippable` lewat
	-- `ProgressionRules.ownedWeapons`, pintu yang sama yang dipakai server untuk
	-- menerima `SelectLoadout` -- jadi tombol Equip hidup tepat kalau server
	-- akan menerimanya, termasuk saat `Config.DEV_ALL_WEAPONS` hidup. Baris
	-- beli/craft/upgrade di bawah tetap memakai `ProfileStore.owns`, yang
	-- membaca `data.weapons` sungguhan: kalau dia ikut flag dev, senjata yang
	-- belum dibeli akan menampilkan tombol "Upgrade" yang pasti ditolak server
	-- alih-alih tombol "Beli" yang benar.
	local equippable = ProgressionRules.ownedWeapons(data, Weapons, Config.DEV_ALL_WEAPONS)

	for weaponId, row in weaponRows do
		local def = Weapons[weaponId]
		if def == nil then
			continue
		end

		row.detail.Text = describeWeapon(weaponId)

		local owned = ProfileStore.owns(weaponId)
		local equipped = data.equippedWeapon == weaponId
		row.title.Text = if equipped then def.name .. " (dipakai)" else def.name
		row.title.TextColor3 = if equipped then UiKit.COLOR_ACCENT else UiKit.COLOR_TEXT
		UiKit.setButtonEnabled(
			row.equip,
			equippable[weaponId] ~= nil and not equipped and canSelect
		)

		-- Upgrade, beli, dan craft tetap LOBBY SAJA, jadi tombolnya mati
		-- sepanjang fase Loadout. Itu disengaja: ketiganya mengubah data
		-- permanen, dan `ProgressionRules.ALLOWED_STATE` menolaknya di server
		-- dengan alasan yang sama. Memilih alur upgrade permanen (nanti) di
		-- bawah timer 20 detik adalah keputusan besar yang diambil terburu-buru.
		-- Baris petunjuk di bawah yang memberitahu pemain kenapa.
		local context: ProgressionRules.Context = { state = stateName, data = data }
		if owned then
			local level = ProfileStore.getWeaponLevel(weaponId) or 1
			local save = ProfileStore.getWeaponSave(weaponId)
			local price = Balance.upgradePrice(level)
			-- Level maks diperiksa PALING DULU. `pathChoiceRequired` juga benar
			-- untuk save level 10 yang `path`-nya masih "none" -- data dari
			-- sebelum fitur ini ada -- dan senjata yang tidak bisa naik level
			-- lagi tidak boleh menawarkan panel pemilihan yang tombol
			-- konfirmasinya pasti ditolak `canUpgrade`.
			if level >= def.maxLevel then
				row.action.Text = "Level maks"
				UiKit.setButtonEnabled(row.action, false)
			elseif save ~= nil and ProgressionRules.pathChoiceRequired(save) then
				-- Tombol ini MEMBUKA panel, jadi syaratnya bukan syarat upgrade:
				-- `canUpgrade` di titik percabangan menolak selama `pathId`
				-- belum ada, dan menolak lagi kalau koinnya kurang. Dua-duanya
				-- akan mematikan tombol yang satu-satunya gunanya MEMBACA ketiga
				-- alur, dan pemain yang koinnya belum cukup justru dia yang
				-- paling perlu melihat dia menabung untuk apa.
				--
				-- Dibandingkan dengan `ProgressionRules.ALLOWED_STATE`, bukan
				-- dengan literal "Lobby": literalnya akan menyempitkan tipe
				-- `stateName` untuk sisa fungsi ini, persis jebakan yang sudah
				-- dicatat di atas pada `inCountdown`.
				row.action.Text = "Pilih alur"
				UiKit.setButtonEnabled(row.action, stateName == ProgressionRules.ALLOWED_STATE)
			else
				row.action.Text = string.format("Upgrade %d", price)
				UiKit.setButtonEnabled(
					row.action,
					(ProgressionRules.canUpgrade(def, context, price))
				)
			end
		elseif def.acquire.method == "buy" then
			row.action.Text = string.format("Beli %d", def.acquire.coinCost or 0)
			UiKit.setButtonEnabled(row.action, (ProgressionRules.canBuy(def, context)))
		elseif def.acquire.method == "craft" then
			row.action.Text = "Craft"
			UiKit.setButtonEnabled(row.action, (ProgressionRules.canCraft(def, context)))
		else
			row.action.Text = "—"
			UiKit.setButtonEnabled(row.action, false)
		end
	end

	-- Ready.
	button.Text = if isReady then "Batal siap" else "Ready"
	UiKit.setButtonEnabled(button, true)

	if noticeText ~= nil and os.clock() >= noticeUntil then
		noticeText = nil
	end

	local notice = noticeText
	if notice ~= nil then
		hint.Text = notice
		hint.TextColor3 = if noticeOk then UiKit.COLOR_GOOD else UiKit.COLOR_BAD
	else
		hint.TextColor3 = UiKit.COLOR_MUTED
		if stateName == "Loadout" then
			hint.Text = "Pilih senjata sekarang — terkunci setelah ini. "
				.. "Upgrade-nya nanti di dalam match, tiap jeda wave."
		elseif inCountdown then
			hint.Text = "Semua pemain siap. Tekan lagi untuk membatalkan."
		elseif isReady then
			hint.Text = "Kamu siap. Menunggu pemain lain."
		else
			hint.Text = "Match baru jalan kalau semua pemain di server siap."
		end
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
	ProfileStore.onChanged:Connect(function(data)
		-- Kesulitan yang dipilih diikutkan ke data server supaya pilihan
		-- pemain tidak hilang saat dia rejoin.
		if not ProfileStore.hasDifficulty(selectedDifficulty) then
			selectedDifficulty = "normal"
		end
		local _ = data
		render()
	end)

	-- Penolakan dari server ditampilkan di baris petunjuk. Tanpa ini, aksi yang
	-- ditolak terlihat sama seperti tombol yang rusak.
	Remotes.Events.ActionResult.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if type(payload.action) ~= "string" or type(payload.ok) ~= "boolean" then
			return
		end
		if not OWN_ACTIONS[payload.action :: string] then
			return
		end

		noticeOk = payload.ok :: boolean
		if noticeOk then
			noticeText = "Berhasil."
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
		-- kalau paket itu berhenti datang.
		task.delay(NOTICE_SECONDS, render)
	end)
end

return LobbyController
