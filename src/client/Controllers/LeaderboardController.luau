--!strict
-- LeaderboardController.luau — papan wave tertinggi di lobby (M6, LB-01..LB-05).
--
-- Panelnya hidup di file sendiri, bukan di LobbyController, karena dia tidak
-- berbagi apa pun dengan panel lobby: tidak ada tombol yang mengirim niat,
-- tidak ada data pemain yang dibaca, dan satu-satunya sumbernya satu
-- RemoteFunction. Menempelkannya ke LobbyController cuma akan menambah 150
-- baris ke file yang sudah mengurus senjata, kesulitan, upgrade, dan alur.
--
-- Papan ini MEMBACA saja. Tidak ada satu pun keputusan gameplay yang diambil
-- dari isinya, jadi client yang dimodifikasi paling jauh bisa membohongi
-- layarnya sendiri.
--
-- Soal `InvokeServer`: dia dipanggil di dalam `task.spawn` dan dibungkus
-- pcall. RemoteFunction menunggu balasan server, jadi memanggilnya dari jalur
-- UI biasa berarti satu klik tab bisa membekukan seluruh client kalau server
-- sedang sibuk. Server sendiri sudah dirancang untuk menjawab tanpa yield
-- (lihat LeaderboardService), tapi client tidak boleh bergantung pada janji
-- itu -- dia tetangga yang tidak dia kendalikan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Difficulties = require(Shared.Modules.Difficulties)
local LeaderboardRules = require(Shared.Modules.LeaderboardRules)
local MatchRules = require(Shared.Modules.MatchRules)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Modules.Types)

local MatchStore = require(script.Parent.MatchStore)
local UiKit = require(script.Parent.UiKit)

local LeaderboardController = {}

type Entry = Types.LeaderboardEntry

local PANEL_WIDTH = 300
local ROW_HEIGHT = 22
local HEADER_HEIGHT = 92

-- Urutan tab dipatok di sini, bukan dari iterasi `Difficulties`: urutan
-- iterasi tabel Luau tidak dijamin, jadi tanpa daftar ini posisi tab bisa
-- bertukar tiap kali client dibuka.
local DIFFICULTY_ORDER = { "normal", "hard" }

-- Papan diminta ulang berkala supaya rekor pemain lain di server yang sama
-- ikut terlihat tanpa menekan apa pun. 20 detik, jauh di bawah rate limit
-- remote-nya (2 per detik) dan jauh di atas biaya satu pembacaan di server,
-- yang dijawab dari memori.
local REFRESH_SECONDS = 20

local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local rows: { TextLabel } = {}
local tabs: { [string]: TextButton } = {}

local selected = "normal"
local boards: { [string]: { Entry } } = {}
local inFlight: { [string]: boolean } = {}
local started = false

local function setRows(entries: { Entry })
	for index, row in rows do
		local entry = entries[index]
		if entry == nil then
			row.Text = ""
			row.Visible = false
			continue
		end
		row.Visible = true
		-- Nama dan angka di satu label polos, bukan dua label atau RichText:
		-- RichText memperlakukan nama pemain sebagai markup, dan nama yang
		-- kebetulan mengandung tanda kurung sudut akan hilang sebagian.
		row.Text = string.format("%d.  %s  --  wave %d", index, entry.name, entry.wave)
		row.TextColor3 = if entry.userId == localPlayer.UserId
			then UiKit.COLOR_ACCENT
			else UiKit.COLOR_TEXT
	end
end

local function render()
	local frame = panel
	local status = statusLabel
	if frame == nil or status == nil then
		return
	end

	-- Papan tampil di `Lobby` dan `Loadout` saja. Dua state itu persis yang
	-- dipakai panel lobby (`MatchRules.canSelectLoadout`), dan dipakai di sini
	-- juga supaya papan tidak pernah menutupi panel toko -- yang menempati
	-- sisi layar yang sama saat Intermission.
	frame.Visible = MatchRules.canSelectLoadout(MatchStore.getStateName())

	for id, button in tabs do
		UiKit.setButtonEnabled(button, id ~= selected)
	end

	local entries = boards[selected]
	if entries == nil then
		status.Text = "Memuat papan..."
		setRows({})
		return
	end
	if #entries == 0 then
		status.Text = "Belum ada catatan di tingkat ini."
		setRows({})
		return
	end

	local def = Difficulties[selected]
	status.Text = string.format("Wave tertinggi · %s", if def ~= nil then def.name else selected)
	setRows(entries)
end

-- Satu permintaan per tingkat, bukan satu permintaan untuk seluruh panel.
-- Menghalangi duplikat untuk tingkat yang SAMA memang perlu: menekan tombol
-- tab berulang kali tidak boleh menumpuk panggilan remote. Tapi menghalangi
-- tingkat yang BERBEDA akan membuat pemain yang berpindah tab selagi
-- permintaan pertama di jalan melihat "Memuat papan..." sampai refresh berkala
-- berikutnya, 20 detik kemudian.
--
-- Balasan yang datang tidak berurutan tidak jadi masalah karena tiap balasan
-- ditulis ke kuncinya sendiri di `boards`, dan `render` selalu membaca kunci
-- tab yang sedang menyala.
local function request(difficultyId: string)
	if inFlight[difficultyId] then
		return
	end
	inFlight[difficultyId] = true
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.Functions.GetLeaderboard:InvokeServer(difficultyId)
		end)
		inFlight[difficultyId] = nil

		if not ok then
			-- Tidak ada papan baru, tapi juga tidak ada yang rusak. Yang lama
			-- dibiarkan di layar; menghapusnya karena satu panggilan gagal
			-- membuat papan berkedip kosong tiap kali server sibuk.
			warn(string.format("[LeaderboardController] gagal meminta papan: %s", tostring(result)))
			return
		end
		if type(result) ~= "table" then
			-- `nil` berarti server menolak dengan rapi (kena rate limit, atau
			-- tingkat yang tidak dikenal). Bukan error, dan juga BUKAN papan
			-- kosong: menulis `{}` ke sini akan membuat penolakan terbaca
			-- sebagai "belum ada catatan di tingkat ini", padahal yang terjadi
			-- cuma satu permintaan yang ditolak. Dibiarkan apa adanya, jadi
			-- papan lama tetap tampil dan yang belum pernah dimuat tetap
			-- berbunyi "Memuat papan..." sampai permintaan berikutnya.
			render()
			return
		end

		local entries: { Entry } = {}
		for _, raw in result :: { any } do
			if
				type(raw) == "table"
				and type(raw.userId) == "number"
				and type(raw.name) == "string"
				and type(raw.wave) == "number"
			then
				table.insert(entries, {
					userId = raw.userId,
					name = raw.name,
					wave = math.floor(raw.wave),
				})
			end
		end
		-- Diurutkan ulang di client dengan fungsi yang sama dengan server.
		-- Bukan karena server tidak dipercaya mengurutkan, tapi karena baris
		-- yang tidak lolos validasi di atas bisa meninggalkan lubang, dan
		-- `rank` yang sama menutup lubang itu dengan aturan yang sama.
		boards[difficultyId] = LeaderboardRules.rank(entries)
		render()
	end)
end

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseLeaderboard", 20)
	local height = HEADER_HEIGHT + LeaderboardRules.MAX_ENTRIES * ROW_HEIGHT + 12
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
		UDim2.fromOffset(14, 10),
		UDim2.fromOffset(PANEL_WIDTH - 28, 20),
		"Papan Wave Tertinggi"
	)
	title.Font = Enum.Font.GothamBold

	local status = UiKit.label(
		frame,
		"Status",
		UDim2.fromOffset(14, 32),
		UDim2.fromOffset(PANEL_WIDTH - 28, 16),
		""
	)
	status.TextSize = 12
	status.TextColor3 = UiKit.COLOR_MUTED

	local buttonWidth = (PANEL_WIDTH - 28 - 8) // #DIFFICULTY_ORDER
	for index, difficultyId in DIFFICULTY_ORDER do
		local def = Difficulties[difficultyId]
		if def == nil then
			continue
		end
		local button = UiKit.button(
			frame,
			difficultyId,
			UDim2.fromOffset(14 + (index - 1) * (buttonWidth + 8), 54),
			UDim2.fromOffset(buttonWidth, 26),
			def.name
		)
		button.Activated:Connect(function()
			if selected == difficultyId then
				return
			end
			selected = difficultyId
			render()
			request(difficultyId)
		end)
		tabs[difficultyId] = button
	end

	for index = 1, LeaderboardRules.MAX_ENTRIES do
		local row = UiKit.label(
			frame,
			string.format("Row%d", index),
			UDim2.fromOffset(14, HEADER_HEIGHT + (index - 1) * ROW_HEIGHT),
			UDim2.fromOffset(PANEL_WIDTH - 28, ROW_HEIGHT),
			""
		)
		row.TextSize = 13
		row.Visible = false
		rows[index] = row
	end

	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
	panel = frame
	statusLabel = status
end

function LeaderboardController.start()
	if started then
		return
	end
	started = true

	build()
	render()
	request(selected)

	-- Yang dipantau PERGANTIAN state, bukan tiap siaran. `MatchService`
	-- menyiarkan `MatchState` tiap 0,2 detik apa pun yang terjadi, jadi
	-- menyambung langsung berarti papan digambar ulang lima kali per detik --
	-- dan, jauh lebih buruk, `request` di bawah menembak remote lima kali per
	-- detik juga. Rate limitnya 2 per detik, jadi tiga dari lima panggilan itu
	-- akan ditolak server dan dibalas nil, terus-menerus, selama pemain berdiri
	-- di lobby.
	--
	-- Kembali ke lobby adalah satu-satunya saat papan bisa berubah karena
	-- perbuatan pemain di server ini: match baru saja selesai dan catatannya
	-- baru saja ditulis. Diminta ulang di situ, bukan saat `Ended`, karena
	-- server menulis catatannya SELAMA `Ended`.
	local lastState = MatchStore.getStateName()
	MatchStore.onMatchState:Connect(function(payload)
		if payload.state == lastState then
			return
		end
		lastState = payload.state
		render()
		if payload.state == "Lobby" then
			request(selected)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			local frame = panel
			-- Papan yang tidak terlihat tidak diminta ulang. Selama satu match
			-- penuh itu menghemat belasan panggilan remote yang hasilnya tidak
			-- akan dilihat siapa pun.
			if frame ~= nil and frame.Visible then
				request(selected)
			end
		end
	end)
end

return LeaderboardController
