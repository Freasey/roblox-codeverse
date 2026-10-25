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

local cache: { [number]: PlayerData } = {}
local loaded: { [number]: boolean } = {}
local shuttingDown = false

-- DataStore-nya diambil lazy, JANGAN di module scope.
--
-- `GetDataStore` melempar error di place lokal yang belum pernah di-publish
-- ("You must publish this place to the web to access DataStore"). Kalau
-- dipanggil di module scope, error itu terjadi saat modul di-require — jadi
-- `require(script.Services.PlayerDataService)` di init.server.luau ikut gagal
-- dan SELURUH script server mati sebelum satu baris pun jalan. Playtest di file
-- .rbxl lokal jadi mustahil, dan gejalanya menyesatkan: yang terlihat cuma
-- "Requested module experienced an error while loading".
local store: DataStore? = nil
local storeChecked = false

local function getStore(): DataStore?
	if storeChecked then
		return store
	end
	storeChecked = true

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result :: DataStore
	else
		warn(string.format("[PlayerDataService] DataStore tidak tersedia: %s", tostring(result)))
	end
	return store
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
		if attempt < Config.SAVE_RETRY_COUNT then
			-- Backoff eksponensial yang di-cap: 2, 4, 8, 8, ... Tanpa cap,
			-- lima percobaan saja sudah 62 detik.
			task.wait(math.min(2 ^ attempt, MAX_BACKOFF))
		end
	end
	warn(string.format("[PlayerDataService] %s gagal setelah retry: %s", label, tostring(lastErr)))
	return false, nil
end

-- Tidak ada DataStore sama sekali (place lokal belum di-publish, atau API
-- Services belum dicentang). Di Studio: lanjut dengan data default di memori
-- supaya gameplay tetap bisa di-playtest, tapi tandai `loaded = false` sehingga
-- save() berhenti di gerbang pertamanya dan tidak pernah menulis apa pun.
-- Di server live: JANGAN — pemain yang jalan dengan data kosong akan menimpa
-- progresnya sendiri pada autosave berikutnya.
local function loadWithoutDataStore(player: Player): PlayerData?
	if not RunService:IsStudio() then
		warn(
			string.format(
				"[PlayerDataService] tidak ada DataStore di server live, kick %s",
				player.Name
			)
		)
		player:Kick("Layanan data sedang bermasalah. Coba join ulang beberapa saat lagi.")
		return nil
	end

	local data = DataSchema.migrate({}, Config.DEFAULT_DATA :: any)
	cache[player.UserId] = data
	loaded[player.UserId] = false
	PlayerDataService.onLoaded:Fire(player, data)
	warn(
		string.format(
			"[PlayerDataService] %s jalan dengan data default di memori. Progres TIDAK "
				.. "tersimpan. Publish place-nya sekali, lalu centang Game Settings -> "
				.. "Security -> Enable Studio Access to API Services.",
			player.Name
		)
	)
	return data
end

function PlayerDataService.load(player: Player): PlayerData?
	local userId = player.UserId
	local key = keyFor(userId)

	local dataStore = getStore()
	if not dataStore then
		return loadWithoutDataStore(player)
	end

	for attempt = 1, LOCK_RETRY_LIMIT do
		local ok, result = retry("UpdateAsync(load)", function()
			return dataStore:UpdateAsync(key, function(old: any): any?
				local data = DataSchema.migrate(old and old.data or {}, Config.DEFAULT_DATA :: any)
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

	local dataStore = getStore()
	if not dataStore then
		return false
	end

	local ok = retry("UpdateAsync(save)", function()
		return dataStore:UpdateAsync(keyFor(userId), function(old: any): any?
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
	-- DataStore mati di Studio kecuali place-nya sudah pernah di-publish DAN
	-- "Enable Studio Access to API Services" dicentang. Diperiksa sekali di sini
	-- supaya peringatannya muncul saat boot, bukan baru saat player pertama join.
	if RunService:IsStudio() then
		local dataStore = getStore()
		local ok = false
		if dataStore then
			ok = pcall(function()
				dataStore:GetAsync("__probe")
			end)
		end
		if not ok then
			warn(
				"[PlayerDataService] DataStore tidak aktif. Publish place-nya sekali, lalu "
					.. "centang Game Settings -> Security -> Enable Studio Access to API "
					.. "Services, lalu restart playtest. Sementara ini progres tidak tersimpan."
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
