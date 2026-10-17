--!strict
-- MatchService.luau — state machine match (docs/DEVELOPMENT_PLAN.md bagian 3.3).
--
--   Lobby -> Countdown (10 dtk) -> WaveActive <-> Intermission (20 dtk) -> Ended -> Lobby
--                                      |
--                                      +-> Ended (core HP 0)
--
-- Service ini memegang state, nomor wave, kesulitan yang dikunci, dan
-- `participants`. Service lain TIDAK BOLEH mengubah state langsung; mereka
-- memanggil fungsi di sini (`onWaveCleared`, `requestReady`, ...) atau
-- mendengarkan `onStateChanged`. Itu bukan sekadar gaya: kalau WaveService dan
-- BossService sama-sama boleh men-set state, dua transisi bisa terjadi pada
-- frame yang sama dan tidak ada satu tempat pun untuk membaca urutannya.
--
-- Arah require-nya satu arah ke bawah: MatchService me-require CoreService dan
-- EnemyService, dan tidak pernah sebaliknya. Yang butuh memberi tahu
-- MatchService memanggil fungsinya; yang butuh diberi tahu mendengarkan
-- sinyalnya. Tidak ada lingkaran require.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Difficulties = require(Shared.Modules.Difficulties)
local MatchRules = require(Shared.Modules.MatchRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Modules.Signal)
local Types = require(Shared.Modules.Types)
local Waves = require(Shared.Modules.Waves)
local Weapons = require(Shared.Modules.Weapons)

local CoreService = require(script.Parent.CoreService)
local EnemyService = require(script.Parent.EnemyService)
local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MatchService = {}

export type State = "Lobby" | "Countdown" | "WaveActive" | "Intermission" | "Ended"

MatchService.COUNTDOWN_SECONDS = 10
MatchService.INTERMISSION_SECONDS = 20
MatchService.ENDED_SECONDS = 10

-- (state baru, state lama). Dipakai WaveService, ShopService, EnemyService.
MatchService.onStateChanged = Signal.new() :: Signal.Signal<State, State>
-- Wave berikutnya siap dijalankan: (nomor wave).
MatchService.onWaveStarted = Signal.new() :: Signal.Signal<number>
-- Match selesai: (menang, wave yang dicapai, id kesulitan, daftar UserId peserta).
MatchService.onMatchEnded = Signal.new() :: Signal.Signal<boolean, number, string, { number }>

local state: State = "Lobby"
local wave = 0
local timer = 0

-- `participants` memakai UserId, BUKAN objek Player: objek Player hilang saat
-- pemain disconnect, jadi set yang berisi objek tidak bisa lagi dipakai untuk
-- mengenali pemain yang rejoin (bagian 3.3).
local participants: { [number]: boolean } = {}
local participantCount = 0

local difficultyId = "normal"
local ready: { [number]: boolean? } = {}
local selectedDifficulty: { [number]: string } = {}

local started = false
local ticker: thread? = nil

-- 2 panggilan per detik untuk remote selain Attack (bagian 3.6).
local limiter = RateLimit.newRegistry({ SetReady = 2, SelectLoadout = 2 }, 2)

local function getDifficulty(): Types.DifficultyDef
	return Difficulties[difficultyId] or Difficulties.normal
end

local function broadcast()
	Remotes.Events.MatchState:FireAllClients({
		state = state,
		wave = wave,
		timer = math.max(0, timer),
		coreHp = CoreService.getHp(),
		coreMaxHp = CoreService.getMaxHp(),
	})
end

local function participantList(): { number }
	local list: { number } = {}
	for userId in participants do
		table.insert(list, userId)
	end
	table.sort(list)
	return list
end

local function clearParticipants()
	participants = {}
	participantCount = 0
end

-- Pemain yang sedang terhubung DAN termasuk peserta match. Beda dari
-- participantCount, yang tetap menghitung peserta yang sedang disconnect.
local function connectedParticipants(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if participants[player.UserId] then
			count += 1
		end
	end
	return count
end

local function setState(next: State)
	if state == next then
		return
	end
	local previous: State = state
	state = next
	MatchService.onStateChanged:Fire(next, previous)
	broadcast()
end

local function spawnPoint(): Vector3?
	local arena = MapService.getArena()
	if arena ~= nil and arena.playerSpawn ~= nil then
		return arena.playerSpawn.Position + Vector3.new(0, 5, 0)
	end
	return nil
end

local function lobbyPoint(): Vector3?
	local lobby = MapService.getLobby()
	if lobby ~= nil and lobby.spawn ~= nil then
		return lobby.spawn.Position + Vector3.new(0, 5, 0)
	end
	return nil
end

-- Tempatkan karakter sesuai apakah pemainnya peserta match atau bukan
-- (bagian 3.3). Pemain yang bukan peserta ditahan di lobby: dia tidak
-- dipindahkan ke arena dan `Attack`-nya ditolak gerbang di bawah.
function MatchService.placeCharacter(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	if character:FindFirstChild("HumanoidRootPart") == nil then
		if character:WaitForChild("HumanoidRootPart", 5) == nil then
			return
		end
	end

	local inMatch = state ~= "Lobby" and participants[player.UserId] == true
	local target = if inMatch then spawnPoint() else lobbyPoint() or spawnPoint()
	if target ~= nil then
		character:PivotTo(CFrame.new(target))
	end
end

-- Syarat masuk Countdown (bagian 3.3): SEMUA pemain di server menekan Ready,
-- minimal satu pemain.
local function everyoneReady(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not ready[player.UserId] then
			return false
		end
	end
	return true
end

local function lockDifficulty()
	-- Kesulitan dikunci saat Countdown. Pilihan beberapa pemain bisa berbeda;
	-- MatchRules.easiestDifficulty mengambil yang paling mudah, dan alasannya
	-- ada di modul itu.
	local ids: { string } = {}
	for _, player in Players:GetPlayers() do
		local chosen = selectedDifficulty[player.UserId]
		if chosen ~= nil then
			table.insert(ids, chosen)
		end
	end
	difficultyId = MatchRules.easiestDifficulty(ids, Difficulties) or "normal"
end

local function beginMatch()
	clearParticipants()
	for _, player in Players:GetPlayers() do
		participants[player.UserId] = true
		participantCount += 1
	end

	CoreService.reset()
	EnemyService.clearAll()
	wave = 0

	for _, player in Players:GetPlayers() do
		MatchService.placeCharacter(player)
	end
end

local function startNextWave()
	wave += 1
	EnemyService.setContext(wave, getDifficulty(), math.max(1, participantCount))
	setState("WaveActive")
	MatchService.onWaveStarted:Fire(wave)
end

local function endMatch(won: boolean)
	local reached = math.max(1, wave)
	local list = participantList()

	EnemyService.setRunning(false)
	EnemyService.clearAll()

	timer = MatchService.ENDED_SECONDS
	setState("Ended")
	MatchService.onMatchEnded:Fire(won, reached, difficultyId, list)

	print(
		string.format(
			"[MatchService] match selesai: %s di wave %d (%s), %d peserta",
			if won then "menang" else "kalah",
			reached,
			difficultyId,
			#list
		)
	)
end

local function returnToLobby()
	wave = 0
	timer = 0
	-- participants baru dikosongkan di sini, bukan saat Ended: RewardService
	-- dan layar hasil masih membutuhkannya selama state Ended (bagian 3.3).
	clearParticipants()
	table.clear(ready)
	EnemyService.setRunning(false)
	EnemyService.clearAll()
	setState("Lobby")
end

-- Semua peserta keluar di tengah match. Rencana development menyerahkan ini ke
-- implementasi dan menyebut konsekuensinya: tanpa pembatalan, server nyangkut
-- di WaveActive tanpa pemain, musuh terus berjalan, dan Core akhirnya hancur
-- tanpa ada yang menontonnya — lalu match "selesai kalah" untuk peserta yang
-- sudah tidak ada. Jadi match dibatalkan dan state kembali ke Lobby.
--
-- Pembatalan BUKAN kekalahan: `onMatchEnded` tidak ditembakkan, jadi tidak ada
-- reward yang dihitung di sini. Reward peserta yang keluar sudah dibayar satu
-- per satu saat dia keluar (lihat RewardService dan bagian 3.3).
local function abandonMatch()
	warn("[MatchService] semua peserta keluar, match dibatalkan dan kembali ke Lobby")
	returnToLobby()
end

local function tick(delta: number)
	if state == "Countdown" then
		-- Syarat masuknya terus diperiksa, bukan cuma sekali: kalau ada pemain
		-- yang membatalkan Ready atau pemain baru join (yang otomatis belum
		-- Ready), hitung mundur dibatalkan. Kalau tidak, match bisa dimulai
		-- dengan pemain yang tidak pernah menyatakan siap.
		if not everyoneReady() then
			timer = 0
			setState("Lobby")
			return
		end
		timer -= delta
		if timer <= 0 then
			timer = 0
			beginMatch()
			startNextWave()
		end
	elseif state == "Intermission" then
		if participantCount > 0 and connectedParticipants() == 0 then
			abandonMatch()
			return
		end
		timer -= delta
		if timer <= 0 then
			timer = 0
			startNextWave()
		end
	elseif state == "WaveActive" then
		if participantCount > 0 and connectedParticipants() == 0 then
			abandonMatch()
			return
		end
	elseif state == "Ended" then
		timer -= delta
		if timer <= 0 then
			timer = 0
			returnToLobby()
		end
	end
end

-- --------------------------------------------------------------------------
-- API untuk service lain
-- --------------------------------------------------------------------------

function MatchService.getState(): State
	return state
end

function MatchService.getWave(): number
	return wave
end

function MatchService.getTimer(): number
	return math.max(0, timer)
end

function MatchService.getDifficultyId(): string
	return difficultyId
end

function MatchService.getDifficulty(): Types.DifficultyDef
	return getDifficulty()
end

function MatchService.getParticipants(): { number }
	return participantList()
end

function MatchService.getParticipantCount(): number
	return participantCount
end

function MatchService.isParticipant(player: Player): boolean
	return participants[player.UserId] == true
end

-- Gerbang untuk CombatService (bagian 3.6: `Attack` hanya saat state
-- `WaveActive` dan pemain ada di `participants`).
function MatchService.canAttack(player: Player): boolean
	return state == "WaveActive"
		and participants[player.UserId] == true
		and not CoreService.isDestroyed()
end

-- Dipanggil WaveService saat semua musuh wave ini habis. Satu-satunya cara
-- service lain memindahkan state.
function MatchService.onWaveCleared()
	if state ~= "WaveActive" then
		return
	end

	if wave >= Waves.LAST_WAVE then
		endMatch(true)
		return
	end

	EnemyService.setRunning(false)
	timer = MatchService.INTERMISSION_SECONDS
	setState("Intermission")
end

-- --------------------------------------------------------------------------
-- Remote
-- --------------------------------------------------------------------------

local function onSetReady(player: Player, value: unknown)
	if not RateLimit.check(limiter, player.UserId, "SetReady", os.clock()) then
		return
	end
	if type(value) ~= "boolean" then
		return
	end
	-- Ready cuma bermakna di Lobby dan Countdown (bagian 3.6: hanya state
	-- `Lobby`; Countdown diizinkan khusus untuk MEMBATALKAN).
	if state ~= "Lobby" and state ~= "Countdown" then
		return
	end

	ready[player.UserId] = value or nil

	if state == "Lobby" and everyoneReady() then
		lockDifficulty()
		timer = MatchService.COUNTDOWN_SECONDS
		setState("Countdown")
	end
end

local function onSelectLoadout(player: Player, weaponId: unknown, difficulty: unknown)
	if not RateLimit.check(limiter, player.UserId, "SelectLoadout", os.clock()) then
		return
	end
	if type(weaponId) ~= "string" or type(difficulty) ~= "string" then
		return
	end
	-- Loadout dikunci begitu match mulai: mengganti senjata di tengah wave
	-- berarti damage berubah di tengah pertarungan tanpa biaya apa pun.
	if state ~= "Lobby" then
		Remotes.Events.ActionResult:FireClient(player, {
			action = "SelectLoadout",
			ok = false,
			reason = "Cuma bisa ganti loadout di lobby.",
		})
		return
	end

	local weapon = Weapons[weaponId]
	local difficultyDef = Difficulties[difficulty]
	if weapon == nil or difficultyDef == nil then
		return
	end

	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end

	-- Validasi bagian 3.6: senjata dimiliki, tingkat terbuka. Dicek di server
	-- dari data server, bukan dari apa pun yang dikirim client.
	if data.weapons[weaponId] == nil then
		Remotes.Events.ActionResult:FireClient(player, {
			action = "SelectLoadout",
			ok = false,
			reason = "Senjata itu belum kamu miliki.",
		})
		return
	end
	if data.unlockedDifficulties[difficulty] ~= true then
		Remotes.Events.ActionResult:FireClient(player, {
			action = "SelectLoadout",
			ok = false,
			reason = "Tingkat kesulitan itu belum terbuka.",
		})
		return
	end

	selectedDifficulty[player.UserId] = difficulty
	-- update() yang mengirim DataChanged, jadi tidak perlu manual.
	PlayerDataService.update(player, function(d)
		d.equippedWeapon = weaponId
	end)
	Remotes.Events.ActionResult:FireClient(player, {
		action = "SelectLoadout",
		ok = true,
		reason = nil,
	})
end

function MatchService.start()
	if started then
		return
	end
	started = true

	Remotes.Events.SetReady.OnServerEvent:Connect(onSetReady)
	Remotes.Events.SelectLoadout.OnServerEvent:Connect(onSelectLoadout)

	-- Kalah: Core hancur. Satu-satunya jalan ke Ended selain menang di wave
	-- terakhir.
	CoreService.onDestroyed:Connect(function()
		if state == "WaveActive" or state == "Intermission" then
			endMatch(false)
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			MatchService.placeCharacter(player)
		end)
		if player.Character ~= nil then
			MatchService.placeCharacter(player)
		end

		-- Aturan join/rejoin bagian 3.3. MatchState dikirim ke pemain ini juga
		-- kalau dia ditahan di lobby, supaya HUD-nya bisa menampilkan "match
		-- sedang berjalan, tunggu" daripada layar kosong.
		if state ~= "Lobby" and participants[player.UserId] then
			print(string.format("[MatchService] %s rejoin ke match berjalan", player.Name))
		end
		broadcast()
	end

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		ready[player.UserId] = nil
		selectedDifficulty[player.UserId] = nil
		RateLimit.forget(limiter, player.UserId)
		-- `participants` sengaja TIDAK dihapus: peserta yang disconnect boleh
		-- rejoin dan melanjutkan (bagian 3.3), jadi UserId-nya harus tetap ada
		-- sampai match selesai.
	end)

	-- Satu loop, bukan satu task per state. State machine yang tiap
	-- transisinya memulai task.delay sendiri akan punya beberapa timer hidup
	-- bersamaan setelah satu transisi dibatalkan, dan yang lama tetap menyala.
	ticker = task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local now = os.clock()
			local delta = now - last
			last = now
			tick(delta)
			broadcast()
		end
	end)

	broadcast()
	print(
		string.format(
			"[MatchService] siap, %d wave, countdown %ds, intermission %ds",
			Config.LAST_WAVE,
			MatchService.COUNTDOWN_SECONDS,
			MatchService.INTERMISSION_SECONDS
		)
	)
end

function MatchService.stop()
	local thread = ticker
	if thread ~= nil then
		task.cancel(thread)
		ticker = nil
	end
	started = false
end

return MatchService
