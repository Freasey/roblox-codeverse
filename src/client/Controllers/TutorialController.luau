--!strict
-- TutorialController.luau — panduan singkat untuk pemain baru.
--
-- M5 mengizinkan tutorial berupa "wave latihan dengan teks panduan". Yang
-- dipilih di sini adalah teks panduan saja, TANPA wave latihan, dan itu
-- keputusan yang diambil sadar — alasannya ada di docs/TEST_CASES.md bagian
-- 20.5. Ringkasnya: wave latihan butuh state baru di MatchService, dan
-- bagian 3.3 eksplisit bahwa service lain tidak boleh menambah atau mengubah
-- state. Menambah state keenam demi tutorial menyentuh bagian paling rapuh
-- dari seluruh sistem untuk keuntungan yang bisa didapat dengan teks.
--
-- Seluruh tutorial ada di CLIENT dan tidak butuh satu remote baru pun. Semua
-- yang perlu diketahui sudah ada di client: `MatchState` memberi state dan
-- wave, dan data pemain memberi `stats.matchesPlayed`. Tutorial adalah
-- presentasi, jadi tidak ada alasan server ikut mengurusnya.

local Players = game:GetService("Players")

local MatchStore = require(script.Parent.MatchStore)
local ProfileStore = require(script.Parent.ProfileStore)
local UiKit = require(script.Parent.UiKit)

local TutorialController = {}

local localPlayer = Players.LocalPlayer

-- Pemain dianggap baru selama belum pernah menyelesaikan satu match pun.
local NEW_PLAYER_MATCH_LIMIT = 1

type Step = {
	id: string,
	text: string,
}

-- Satu langkah per momen yang benar-benar baru bagi pemain. Sengaja pendek:
-- panduan yang panjang dibaca sambil musuh berjalan ke Core tidak dibaca
-- sama sekali.
local STEPS: { [string]: Step } = {
	lobby = {
		id = "lobby",
		text = "Selamat datang di CodeVerse. Kamu tim IT yang menjaga Core Server. "
			.. "Upgrade senjata di panel kiri — cuma bisa di sini — lalu tekan Ready.",
	},
	loadout = {
		id = "loadout",
		text = "20 detik memilih senjata. Setelah fase ini loadout terkunci sampai "
			.. "match selesai, jadi pilih sekarang.",
	},
	countdown = {
		id = "countdown",
		text = "Match dimulai. Berdirilah di antara jalur musuh dan Core Server.",
	},
	wave1 = {
		id = "wave1",
		text = "Klik (atau tap) ke arah malware untuk menyerang. Tahan tombolnya "
			.. "untuk menyerang terus. Jangan biarkan mereka menyentuh Core.",
	},
	wave2 = {
		id = "wave2",
		text = "Musuh hijau (Worm Runner) jauh lebih cepat. Utamakan mereka.",
	},
	intermission = {
		id = "intermission",
		text = "Jeda 20 detik. Toko Match buka di kanan — cash-nya milik tim, "
			.. "dan habis saat match selesai. Pakai, jangan ditabung.",
	},
	boss = {
		id = "boss",
		text = "Boss muncul tiap 5 wave. Setelah dikalahkan kamu dapat kartu info "
			.. "malware dan material untuk craft senjata.",
	},
	ended = {
		id = "ended",
		text = "Koin dan XP dari match ini tersimpan permanen. Pakai di lobby untuk "
			.. "upgrade senjata.",
	},
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local textLabel: TextLabel? = nil
local shown: { [string]: boolean } = {}
local hideToken = 0
local started = false

local function build()
	if gui ~= nil then
		return
	end

	local screen = UiKit.screenGui("CodeVerseTutorial", 25)

	local frame =
		UiKit.panel(screen, "Panel", UDim2.new(0.5, -230, 1, -92), UDim2.fromOffset(460, 62))
	frame.Visible = false

	local badge =
		UiKit.label(frame, "Badge", UDim2.fromOffset(14, 6), UDim2.fromOffset(432, 14), "PANDUAN")
	badge.TextSize = 11
	badge.TextColor3 = UiKit.COLOR_ACCENT
	badge.Font = Enum.Font.GothamBold

	local text = UiKit.label(frame, "Text", UDim2.fromOffset(14, 20), UDim2.fromOffset(432, 36), "")
	text.TextSize = 13
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top

	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	gui = screen
	panel = frame
	textLabel = text
end

local function isNewPlayer(): boolean
	local data = ProfileStore.get()
	if data == nil then
		-- Data belum datang: diam saja. Menampilkan tutorial ke pemain lama
		-- lebih mengganggu daripada menampilkannya sedikit terlambat ke pemain
		-- baru.
		return false
	end
	return data.stats.matchesPlayed < NEW_PLAYER_MATCH_LIMIT
end

-- Tiap langkah muncul SEKALI per sesi. Tanpa itu, langkah `intermission` akan
-- muncul sembilan kali dalam satu match.
local function show(step: Step)
	if shown[step.id] then
		return
	end
	if not isNewPlayer() then
		return
	end

	build()
	local frame = panel
	local text = textLabel
	if frame == nil or text == nil then
		return
	end

	shown[step.id] = true
	text.Text = step.text
	frame.Visible = true

	hideToken += 1
	local token = hideToken
	task.delay(12, function()
		if token == hideToken then
			frame.Visible = false
		end
	end)
end

function TutorialController.start()
	if started then
		return
	end
	started = true

	build()

	MatchStore.onMatchState:Connect(function(payload)
		if payload.state == "Lobby" then
			show(STEPS.lobby)
		elseif payload.state == "Loadout" then
			show(STEPS.loadout)
		elseif payload.state == "Countdown" then
			show(STEPS.countdown)
		elseif payload.state == "Intermission" then
			show(STEPS.intermission)
		elseif payload.state == "Ended" then
			show(STEPS.ended)
		elseif payload.state == "WaveActive" then
			if payload.wave == 1 then
				show(STEPS.wave1)
			elseif payload.wave == 2 then
				show(STEPS.wave2)
			end
		end
	end)

	MatchStore.onBossState:Connect(function(boss)
		if boss.alive then
			show(STEPS.boss)
		end
	end)

	-- Data pemain bisa datang setelah MatchState pertama. Kalau pemain memang
	-- baru, langkah lobby ditampilkan begitu datanya ada.
	ProfileStore.onChanged:Connect(function()
		if MatchStore.getStateName() == "Lobby" then
			show(STEPS.lobby)
		end
	end)
end

return TutorialController
