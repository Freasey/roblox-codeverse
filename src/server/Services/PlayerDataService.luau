--!strict
-- PlayerDataService.luau — wrapper DataStore dengan session lock.
--
-- Kenapa session lock: satu player bisa join dua server sekaligus (bug Roblox
-- atau exploit rejoin cepat). Tanpa lock, dua server nulis data yang sama dan
-- salah satu progress-nya hilang. Lock nyimpen JobId pemilik; server lain
-- nunggu sampai lock lepas atau kedaluwarsa.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataSchema = require(Shared.Modules.DataSchema)
local Signal = require(Shared.Modules.Signal)

type PlayerData = Config.PlayerData

local LOCK_EXPIRY = 1800 -- 30 menit; lock lebih tua dari ini dianggap mati
-- Tiga putaran saja. Satu putaran retry() yang gagal total sudah makan ~22
-- detik (lihat cap backoff di retry), jadi batas lama (6) berarti pemain
-- menatap layar kosong menit-menitan sebelum di-kick. Lebih baik kick cepat
-- dengan pesan jelas. Lihat docs/DEVELOPMENT_PLAN.md bagian 3.2 poin 2.
local LOCK_RETRY_LIMIT = 3
local LOCK_RETRY_DELAY = 4
local MAX_BACKOFF = 8
local WAIT_TIMEOUT = 90 -- detik; batas atas waitFor, sedikit di atas worst case load

local PlayerDataService = {}

-- Ditembakkan sekali per player begitu datanya siap dipakai. Ini yang dipakai
-- kode lain untuk tahu kapan boleh membaca data, menggantikan `task.wait(1)`
-- yang dulu ada di init.server.luau (bagian 3.2 poin 3 dan 4).
PlayerDataService.onLoaded = Signal.new() :: Signal.Signal<Player, PlayerData>

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local cache: { [number]: PlayerData } = {}
local loaded: { [number]: boolean } = {}
local shuttingDown = false

local function keyFor(userId: number): string
	return string.format("Player_%d", userId)
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local lastErr: any
	for attempt = 1, Config.SAVE_RETRY_COUNT do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < Config.SAVE_RETRY_COUNT then
			-- Backoff eksponensial yang di-cap: 2, 4, 8, 8, ... Tanpa cap,
			-- lima percobaan saja sudah 62 detik.
			task.wait(math.min(2 ^ attempt, MAX_BACKOFF))
		end
	end
	warn(string.format("[PlayerDataService] %s gagal setelah retry: %s", label, tostring(lastErr)))
	return false, nil
end

function PlayerDataService.load(player: Player): PlayerData?
	local userId = player.UserId
	local key = keyFor(userId)

	for attempt = 1, LOCK_RETRY_LIMIT do
		local ok, result = retry("UpdateAsync(load)", function()
			return store:UpdateAsync(key, function(old: any): any?
				local data =
					DataSchema.reconcile(old and old.data or {}, Config.DEFAULT_DATA :: any)
				local lock = old and old.lock

				-- Ada lock milik server lain yang masih hidup -> tolak.
				if lock and lock.jobId ~= game.JobId and os.time() - lock.at < LOCK_EXPIRY then
					return nil -- batalkan tulisan
				end

				data.lastLogin = os.time()

				return {
					data = data,
					lock = { jobId = game.JobId, at = os.time() },
				}
			end)
		end)

		if ok and result ~= nil then
			local entry = result :: any
			cache[userId] = entry.data
			loaded[userId] = true
			PlayerDataService.onLoaded:Fire(player, entry.data)
			return entry.data
		end

		if attempt < LOCK_RETRY_LIMIT then
			warn(
				string.format(
					"[PlayerDataService] %s ke-lock di server lain, retry %d/%d",
					player.Name,
					attempt,
					LOCK_RETRY_LIMIT
				)
			)
			task.wait(LOCK_RETRY_DELAY)
		end
	end

	warn(
		string.format("[PlayerDataService] gagal load %s, kick biar data gak ketimpa", player.Name)
	)
	player:Kick("Gagal memuat data kamu. Coba join ulang sekitar 30 detik lagi.")
	return nil
end

function PlayerDataService.get(player: Player): PlayerData?
	return cache[player.UserId]
end

-- Tunggu sampai data player siap. Mengembalikan nil kalau player keburu keluar
-- atau load gagal sampai timeout. Pakai ini, jangan task.wait() menebak-nebak.
function PlayerDataService.waitFor(player: Player, timeout: number?): PlayerData?
	local userId = player.UserId
	if loaded[userId] then
		return cache[userId]
	end

	local thread = coroutine.running()
	local settled = false
	local connection: Signal.Connection

	local function finish(data: PlayerData?)
		if settled then
			return
		end
		settled = true
		connection:Disconnect()
		task.spawn(thread, data)
	end

	connection = PlayerDataService.onLoaded:Connect(function(who: Player, data: PlayerData)
		if who == player then
			finish(data)
		end
	end)

	task.delay(timeout or WAIT_TIMEOUT, function()
		finish(nil)
	end)

	return (coroutine.yield() :: any) :: PlayerData?
end

-- Satu-satunya cara yang benar untuk mengubah data: lewat mutator.
-- Jangan pernah assign langsung ke tabel hasil get() tanpa lewat sini.
-- Broadcast DataChanged dilakukan di sini supaya tidak ada service lain yang
-- bisa lupa mengirimnya (bagian 3.2 poin 4).
function PlayerDataService.update(player: Player, mutator: (PlayerData) -> ()): boolean
	local data = cache[player.UserId]
	if not data then
		return false
	end
	mutator(data)
	Remotes.Events.DataChanged:FireClient(player, data)
	return true
end

function PlayerDataService.save(player: Player, releaseLock: boolean?): boolean
	local userId = player.UserId
	local data = cache[userId]
	if not data or not loaded[userId] then
		return false
	end

	local ok = retry("UpdateAsync(save)", function()
		return store:UpdateAsync(keyFor(userId), function(old: any): any?
			-- Jangan nulis kalau lock sudah pindah ke server lain.
			local lock = old and old.lock
			if lock and lock.jobId ~= game.JobId then
				return nil
			end
			return {
				data = data,
				lock = if releaseLock then nil else { jobId = game.JobId, at = os.time() },
			}
		end)
	end)

	if releaseLock and ok then
		cache[userId] = nil
		loaded[userId] = nil
	end
	return ok
end

function PlayerDataService.start()
	-- DataStore mati di Studio kecuali "Enable Studio Access to API Services" dicentang.
	if RunService:IsStudio() then
		local ok = pcall(function()
			store:GetAsync("__probe")
		end)
		if not ok then
			warn(
				"[PlayerDataService] DataStore tidak aktif. Centang Game Settings -> Security -> "
					.. "Enable Studio Access to API Services, lalu restart playtest."
			)
		end
	end

	-- Satu-satunya titik PlayerAdded yang memuat data. Yang butuh tahu kapan
	-- data siap mendengarkan onLoaded, bukan menyambung PlayerAdded lagi.
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerDataService.load, player)
	end
	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.save(player, true)
	end)

	-- Autosave berkala: kalau server crash, kerugian maksimal satu interval.
	task.spawn(function()
		while not shuttingDown do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(PlayerDataService.save, player, false)
			end
		end
	end)

	-- Roblox kasih ~30 detik sebelum server dimatikan. Ini jaring terakhir.
	game:BindToClose(function()
		shuttingDown = true
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				PlayerDataService.save(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
