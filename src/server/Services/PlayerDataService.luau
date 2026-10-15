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

local Config = require(ReplicatedStorage.Shared.Config)

type PlayerData = Config.PlayerData

local LOCK_EXPIRY = 1800 -- 30 menit; lock lebih tua dari ini dianggap mati
local LOCK_RETRY_LIMIT = 6
local LOCK_RETRY_DELAY = 5

local PlayerDataService = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local cache: { [number]: PlayerData } = {}
local loaded: { [number]: boolean } = {}
local shuttingDown = false

-- Isi field yang belum ada dengan default, tanpa menimpa yang sudah ada.
-- Ini yang bikin nambah field baru di Config aman buat player lama.
local function reconcile(data: { [string]: any }): PlayerData
	for key, default in Config.DEFAULT_DATA :: { [string]: any } do
		if data[key] == nil then
			data[key] = default
		end
	end
	return data :: any
end

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
		task.wait(2 ^ attempt) -- backoff eksponensial: 2, 4, 8, ...
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
				local data = reconcile(old and old.data or {})
				local lock = old and old.lock

				-- Ada lock milik server lain yang masih hidup -> tolak.
				if lock and lock.jobId ~= game.JobId and os.time() - lock.at < LOCK_EXPIRY then
					return nil -- batalkan tulisan
				end

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
	player:Kick("Gagal memuat data kamu. Coba join ulang dalam beberapa saat.")
	return nil
end

function PlayerDataService.get(player: Player): PlayerData?
	return cache[player.UserId]
end

-- Satu-satunya cara yang benar untuk mengubah data: lewat mutator.
-- Jangan pernah assign langsung ke tabel hasil get() tanpa lewat sini,
-- supaya ada satu titik buat validasi & broadcast nanti.
function PlayerDataService.update(player: Player, mutator: (PlayerData) -> ()): boolean
	local data = cache[player.UserId]
	if not data then
		return false
	end
	mutator(data)
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
