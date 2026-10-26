--!strict
-- GuideController.luau: panduan dalam game: cara bermain, musuh, dan rencana.
--
-- Dibuka dengan F1 atau tombol "?" di pojok, dan muncul sendiri SEKALI pada
-- kunjungan pertama seorang pemain.
--
-- Kenapa panduan ada di dalam game, bukan di dokumen terpisah: pemain yang
-- bingung sedang berada di dalam game, bukan di depan dokumen. Dan karena
-- kontrol di sini bukan kontrol bawaan Roblox, Shift, C, dan Q tidak akan
-- pernah ditebak sendiri oleh siapa pun, game ini WAJIB mengajarkannya, atau
-- tiga perempat sistem geraknya tidak akan pernah dipakai.
--
-- "Sekali" disimpan di atribut pemain di sisi client saja, bukan di DataStore.
-- Panduan yang muncul lagi setelah ganti perangkat bukan kerugian; satu field
-- tambahan di data tersimpan yang harus ikut dirawat selamanya, iya.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)

local GuideController = {}

local localPlayer = Players.LocalPlayer
local started = false
local shownOnce = false

type Section = {
	title: string,
	lines: { string },
}

type Tab = {
	id: string,
	label: string,
	sections: { Section },
}

-- --------------------------------------------------------------------------
-- Isi panduan
-- --------------------------------------------------------------------------
--
-- Ditulis sebagai data, bukan sebagai rentetan Instance, supaya menambah satu
-- baris panduan tidak berarti menyentuh kode tata letak sama sekali.

local TABS: { Tab } = {
	{
		id = "main",
		label = "CARA BERMAIN",
		sections = {
			{
				title = "Tujuan",
				lines = {
					"Kamu bagian dari tim IT. Satu Core Server di tengah arena",
					"menyimpan seluruh data perusahaan, dan gelombang malware",
					"datang untuk menghancurkannya.",
					"",
					"Kalau HP Core habis, tim kalah.",
					"Kalau tim bertahan sampai wave terakhir, tim menang.",
					"HP Core dipakai bersama. Tidak ada yang bisa menang sendiri.",
				},
			},
			{
				title = "Kontrol",
				lines = {
					"W A S D      jalan",
					"Shift        lari, cepat tapi menguras stamina",
					"C            jongkok, paling lambat tapi memulihkan stamina",
					"Q            dash, lesatan pendek untuk keluar kepungan",
					"Spasi        lompat",
					"Klik kiri    serang ke arah kursor",
					"F1           buka atau tutup panduan ini",
				},
			},
			{
				title = "Stamina",
				lines = {
					"Lari dan dash memakai stamina; bar-nya ada di bawah layar.",
					"Stamina habis memaksamu kembali berjalan sampai pulih.",
					"Jongkok memulihkannya hampir dua kali lebih cepat daripada",
					"berjalan, itu gunanya mundur ke balik rak server sebentar.",
				},
			},
			{
				title = "Membaca arena",
				lines = {
					"Musuh selalu masuk lewat tiga gerbang bercahaya.",
					"Lantai bergaris jingga menandai jalur yang akan mereka lewati,",
					"jadi kamu bisa memilih posisi sebelum wave dimulai.",
					"",
					"Tiga platform tinggi berdiri di antara jalur. Dari atas sana",
					"dua lane terlihat sekaligus, dengan harga kamu butuh waktu",
					"untuk turun kembali.",
				},
			},
			{
				title = "Di antara wave",
				lines = {
					"Setiap wave selesai, ada jeda singkat. Buka Toko Match untuk",
					"menaikkan level senjata, memasang turret, atau memasang",
					"penghalang yang menahan musuh di semua lane.",
					"",
					"Koin match hangus saat match berakhir. Koin permanen dan",
					"material boss ikut tersimpan.",
				},
			},
		},
	},
	{
		id = "enemies",
		label = "MUSUH",
		sections = {
			{
				title = "Mengenali dari bentuknya",
				lines = {
					"Tiap musuh dibentuk supaya bisa dibedakan dari siluetnya saja,",
					"bukan dari warnanya, pada wave akhir layar terlalu ramai",
					"untuk membaca warna.",
				},
			},
			{
				title = "Pop-up Swarmling  (Adware)",
				lines = {
					"Gugus kotak kecil yang mengambang. Lemah, datang berombongan,",
					"menuju langsung ke Core.",
					"Pelajarannya: ancaman yang menyebar kalau dibiarkan.",
				},
			},
			{
				title = "Worm Runner  (Worm)",
				lines = {
					"Badan panjang dan rendah, bergerak paling cepat.",
					"Satu-satunya yang MENGEJAR PEMAIN, bukan Core.",
					"Pelajarannya: pentingnya menambal sistem sebelum menyebar.",
				},
			},
			{
				title = "Rootkit Hulk  (Rootkit)",
				lines = {
					"Balok besar berpelat, paling lambat di game, dan paling",
					"mematikan. Dua pukulan cukup membunuhmu.",
					"Karena lambat, dia bisa dihindari. Tapi jangan dibiarkan lolos.",
				},
			},
			{
				title = "Boss tiap wave kelipatan 5",
				lines = {
					"Trojan      : menyamar, lalu membelah diri saat HP turun",
					"Ransomware  : mengunci salah satu senjatamu sesaat",
					"",
					"Setiap boss kalah memunculkan kartu info: apa malware itu",
					"sebenarnya, dan bagaimana mencegahnya di dunia nyata.",
				},
			},
		},
	},
	{
		id = "roadmap",
		label = "COMING SOON",
		sections = {
			{
				title = "Kenapa halaman ini ada",
				lines = {
					"Game bertahan-gelombang punya satu kelemahan bawaan: setelah",
					"pemain hafal pola wave-nya, match kesepuluh sama persis dengan",
					"match pertama. Daftar di bawah adalah rencana yang semuanya",
					"menyerang kelemahan itu dari sudut berbeda.",
					"",
					"Belum ada satu pun yang jalan. Halaman ini rencana, bukan fitur.",
				},
			},
			{
				title = "1, Mode Endless",
				lines = {
					"Setelah wave terakhir, wave terus berlanjut tanpa batas dengan",
					"penskalaan yang makin tajam. Papan peringkat mingguan direset",
					"tiap Senin, jadi selalu ada alasan kembali.",
				},
			},
			{
				title = "2, Direktif Harian",
				lines = {
					"Satu aturan tambahan yang berganti tiap hari dan sama untuk",
					"semua pemain hari itu. Contoh: 'Worm bergerak 30% lebih cepat,',",
					"'koin match +50%'. Pola wave-nya tetap, cara menghadapinya tidak.",
				},
			},
			{
				title = "3, Tiga peran tim",
				lines = {
					"Analyst    : menandai musuh, timnya ikut melihat tandanya",
					"Engineer   : turret lebih murah dan lebih kuat",
					"Responder  : satu-satunya yang bisa memperbaiki HP Core",
					"",
					"Tim empat orang jadi punya susunan, bukan empat salinan.",
				},
			},
			{
				title = "4, Musim keluarga malware",
				lines = {
					"Keluarga malware baru tiap musim, lengkap dengan musuh, boss,",
					"dan kartu infonya sendiri: Phishing, Botnet, Keylogger,",
					"Cryptojacking. Sisi edukasinya ikut tumbuh, bukan berhenti",
					"di lima jenis.",
				},
			},
			{
				title = "5, Mutator pilihan tim",
				lines = {
					"Sebelum match, tim boleh memilih satu kesulitan tambahan untuk",
					"hadiah lebih besar, misalnya 'tanpa Toko Match' atau 'Core",
					"mulai dari 60% HP'. Risiko jadi keputusan, bukan nasib.",
				},
			},
			{
				title = "6, Arsip malware di lobby",
				lines = {
					"Kartu info yang sudah pernah didapat bisa dibaca ulang di lobby,",
					"beserta kuis singkatnya. Yang dipelajari pemain tidak lagi",
					"hilang begitu match selesai.",
				},
			},
			{
				title = "7, Arena kedua",
				lines = {
					"Tata letak arena ini dihasilkan satu modul (ArenaLayout), jadi",
					"arena kedua berarti satu set angka baru, lima lane, koridor",
					"sempit, Core tidak di tengah, bukan membangun ulang dari nol.",
				},
			},
		},
	},
}

-- --------------------------------------------------------------------------
-- Tampilan
-- --------------------------------------------------------------------------

local gui: ScreenGui? = nil
local body: ScrollingFrame? = nil
local tabButtons: { [string]: TextButton } = {}
local activeTab = "main"

local function renderTab(id: string)
	local frame = body
	if frame == nil then
		return
	end

	activeTab = id
	for tabId, button in tabButtons do
		UiKit.setButtonEnabled(button, tabId ~= id)
	end

	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local tab: Tab? = nil
	for _, candidate in TABS do
		if candidate.id == id then
			tab = candidate
		end
	end
	if tab == nil then
		return
	end

	local y = 0
	local order = 0
	for _, section in tab.sections do
		order += 1
		local heading = UiKit.label(
			frame,
			string.format("H%d", order),
			UDim2.fromOffset(4, y),
			UDim2.new(1, -12, 0, 24),
			section.title
		)
		heading.Font = Enum.Font.GothamBold
		heading.TextSize = 15
		heading.TextColor3 = UiKit.COLOR_ACCENT
		y += 26

		for _, line in section.lines do
			local label = UiKit.label(
				frame,
				string.format("L%d", order),
				UDim2.fromOffset(12, y),
				UDim2.new(1, -24, 0, 17),
				line
			)
			label.TextSize = 13
			-- Font monospace untuk daftar kontrol supaya kolomnya lurus. Dipilih
			-- dari ISI barisnya, bukan dari nama bagiannya: begitu ada bagian
			-- lain yang juga berbentuk tabel, dia ikut rapi tanpa diurus.
			if string.find(line, "   ") ~= nil then
				label.Font = Enum.Font.Code
			end
			label.TextColor3 = UiKit.COLOR_TEXT
			y += 17
			order += 1
		end
		y += 14
	end

	-- Tinggi kanvas dihitung dari isi, bukan dipatok. Angka yang dipatok akan
	-- memotong bagian bawah tiap kali ada baris yang ditambahkan, dan tidak
	-- ada yang akan ingat memperbaruinya.
	frame.CanvasSize = UDim2.fromOffset(0, y + 20)
end

local function setVisible(value: boolean)
	local screen = gui
	if screen ~= nil then
		screen.Enabled = value
	end
end

local function build()
	local screen = UiKit.screenGui("Guide", 20)
	screen.Enabled = false
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Parent = screen

	local panel =
		UiKit.panel(screen, "Panel", UDim2.new(0.5, -310, 0.5, -230), UDim2.fromOffset(620, 460))
	panel.BackgroundTransparency = 0.02

	local title = UiKit.label(
		panel,
		"Title",
		UDim2.fromOffset(18, 12),
		UDim2.fromOffset(400, 26),
		"CODEVERSE, IT vs MALWARE"
	)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18

	local close =
		UiKit.button(panel, "Close", UDim2.new(1, -46, 0, 12), UDim2.fromOffset(34, 26), "X")
	close.MouseButton1Click:Connect(function()
		setVisible(false)
	end)

	local x = 18
	for _, tab in TABS do
		local button = UiKit.button(
			panel,
			tab.id,
			UDim2.fromOffset(x, 46),
			UDim2.fromOffset(150, 28),
			tab.label
		)
		button.MouseButton1Click:Connect(function()
			renderTab(tab.id)
		end)
		tabButtons[tab.id] = button
		x += 158
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.fromOffset(14, 86)
	scroll.Size = UDim2.fromOffset(592, 358)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = panel
	body = scroll

	renderTab("main")
end

local function buildToggle()
	local screen = UiKit.screenGui("GuideToggle", 6)
	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	local button =
		UiKit.button(screen, "Open", UDim2.new(1, -58, 0, 12), UDim2.fromOffset(44, 30), "?")
	button.MouseButton1Click:Connect(function()
		local current = gui
		setVisible(current == nil or not current.Enabled)
	end)
end

function GuideController.start()
	if started then
		return
	end
	started = true

	build()
	buildToggle()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F1 then
			local current = gui
			setVisible(current == nil or not current.Enabled)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			setVisible(false)
		end
	end)

	-- Muncul sendiri sekali, dan DITUNDA tiga detik. Tanpa penundaan dia
	-- terbuka bersamaan dengan layar loading Roblox dan pemain menutupnya
	-- sebelum sempat membaca apa pun.
	if not shownOnce then
		shownOnce = true
		task.delay(3, function()
			if gui ~= nil and activeTab == "main" then
				setVisible(true)
			end
		end)
	end
end

return GuideController
