--!strict
-- LeaderboardService.luau — papan wave tertinggi per tingkat kesulitan (M6).
--
-- Bentuknya: satu OrderedDataStore per tingkat, key = UserId, value = wave
-- tertinggi yang pernah dicapai pemain itu di tingkat tersebut. Aturan apa
-- yang boleh menggantikan apa ada di `LeaderboardRules`, bukan di sini; file
-- ini cuma yang menyentuh DataStore dan remote.
--
-- Dua keputusan di file ini yang menentukan sisanya:
--
-- 1. `OnServerInvoke` TIDAK PERNAH yield. Dia menjawab dari papan yang sudah
--    ada di memori dan paling banyak MENJADWALKAN pembacaan ulang. Kalau dia
--    memanggil `GetSortedAsync` sendiri, client yang membuka lobby ikut
--    menunggu panggilan web -- dan saat DataStore sedang throttle, menunggunya
--    bisa puluhan detik. Papan yang terlambat satu menit masih papan; lobby
--    yang membeku bukan lobby. Ini juga yang membuat LB-00 terpenuhi:
--    `InvokeServer` mengembalikan data tanpa menggantung.
--
-- 2. Rekor baru dijahit ke papan memori, bukan memicu pembacaan ulang.
--    `GetSortedAsync` punya kuota sendiri, dan satu match empat pemain akan
--    memanggilnya empat kali beruntun untuk hasil yang sudah diketahui. Itu
--    yang membuat papan ikut terupdate tanpa restart server (LB-04).
--
-- Tanpa DataStore (place lokal yang belum pernah di-publish, atau API Services
-- belum dicentang) seluruh service ini diam: papannya kosong, remote-nya tetap
-- menjawab tabel kosong, dan tidak ada satu pun error yang naik ke client.
-- Pola yang sama dengan PlayerDataService, dan alasannya sama.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Difficulties = require(Shared.Modules.Difficulties)
local LeaderboardRules = require(Shared.Modules.LeaderboardRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Modules.Types)

local MatchService = require(script.Parent.MatchService)

local LeaderboardService = {}

type Entry = Types.LeaderboardEntry

-- Pembacaan ulang berkala. Perlu walaupun rekor lokal sudah dijahit sendiri:
-- server lain menulis ke store yang sama, dan tanpa ini papan di server ini
-- tidak akan pernah melihat rekor pemain yang sedang main di tempat lain.
local REFRESH_INTERVAL = 60
-- Jarak minimum antar pembacaan satu tingkat, berapa pun banyaknya permintaan
-- client. Rate limit remote menjaga satu pemain; angka ini yang menjaga kuota
-- OrderedDataStore saat empat pemain membuka papan bersamaan (SEC-08).
local MIN_FETCH_INTERVAL = 15

local stores: { [string]: OrderedDataStore } = {}
local storeChecked: { [string]: boolean } = {}
local boards: { [string]: { Entry } } = {}
local fetchedAt: { [string]: number } = {}
local fetching: { [string]: boolean } = {}
local names: { [number]: string } = {}

local started = false
local refresher: thread? = nil

local limiter = RateLimit.newRegistry({ GetLeaderboard = 2 }, 2)

-- Lazy, JANGAN di module scope. `GetOrderedDataStore` melempar error di place
-- yang belum pernah di-publish, dan error di module scope menjatuhkan seluruh
-- script server yang me-require file ini -- dengan pesan "Requested module
-- experienced an error while loading" yang tidak menyebut DataStore sama
-- sekali. Larangan ini ditulis di docs/STATUS.md bagian 8.
local function getStore(difficultyId: string): OrderedDataStore?
	if storeChecked[difficultyId] then
		return stores[difficultyId]
	end
	storeChecked[difficultyId] = true

	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(LeaderboardRules.storeNameFor(difficultyId))
	end)
	if ok then
		stores[difficultyId] = result :: OrderedDataStore
	else
		warn(
			string.format(
				"[LeaderboardService] papan %s tidak tersedia: %s",
				difficultyId,
				tostring(result)
			)
		)
	end
	return stores[difficultyId]
end

-- Nama untuk sebuah UserId. Pemain yang sedang ada di server ini dibaca
-- langsung dari objeknya; sisanya lewat panggilan web yang di-cache.
--
-- Yang gagal TIDAK ikut di-cache, dan itu disengaja: nama cadangan
-- "Pemain 12345" yang tersimpan akan bertahan selama server hidup, dan papan
-- yang sekali gagal lookup akan menampilkan angka itu selamanya walaupun
-- panggilan berikutnya pasti berhasil.
local function nameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		names[userId] = player.Name
		return player.Name
	end

	local cached = names[userId]
	if cached ~= nil then
		return cached
	end

	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(result) == "string" then
		names[userId] = result
		return result
	end
	return string.format("Pemain %d", userId)
end

-- Baca sepuluh teratas dari store. Yield; jangan dipanggil dari
-- `OnServerInvoke`.
local function fetch(difficultyId: string)
	if fetching[difficultyId] then
		return
	end
	local store = getStore(difficultyId)
	if store == nil then
		return
	end

	fetching[difficultyId] = true
	fetchedAt[difficultyId] = os.clock()

	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, LeaderboardRules.MAX_ENTRIES)
		return pages:GetCurrentPage()
	end)

	if not ok then
		fetching[difficultyId] = false
		warn(
			string.format(
				"[LeaderboardService] gagal membaca papan %s: %s",
				difficultyId,
				tostring(result)
			)
		)
		return
	end

	local entries: { Entry } = {}
	for _, row in result :: { { key: string, value: number } } do
		local userId = tonumber(row.key)
		-- `value` dari DataStore diperlakukan seperti data dari luar: store ini
		-- pernah ditulis versi kode yang berbeda, dan satu baris rusak tidak
		-- boleh menjatuhkan seluruh papan.
		if userId ~= nil and type(row.value) == "number" and row.value >= 1 then
			table.insert(entries, {
				userId = userId,
				name = nameFor(userId),
				wave = math.floor(row.value),
			})
		end
	end

	boards[difficultyId] = LeaderboardRules.rank(entries)
	fetching[difficultyId] = false
end

-- Pembacaan ulang yang diminta dari jalur yang tidak boleh yield. Dia
-- menjadwalkan, bukan menunggu, dan menolak kalau yang terakhir masih baru.
local function requestFetch(difficultyId: string)
	if fetching[difficultyId] then
		return
	end
	local last = fetchedAt[difficultyId]
	if last ~= nil and os.clock() - last < MIN_FETCH_INTERVAL then
		return
	end
	task.spawn(fetch, difficultyId)
end

-- Catat satu hasil match. Yield.
local function record(userId: number, wave: number, difficultyId: string)
	local id = LeaderboardRules.normalizeDifficulty(difficultyId, Difficulties)
	if id == nil then
		return
	end
	if not LeaderboardRules.isRecord(nil, wave) then
		return
	end

	local store = getStore(id)
	if store == nil then
		return
	end

	-- Nilai lama ditangkap dari DALAM transform, bukan lewat `GetAsync`
	-- terpisah. Dua panggilan berarti dua titik waktu, dan di antaranya server
	-- lain bisa menulis rekor yang lebih tinggi -- yang lalu ditimpa rekor
	-- lebih rendah dari sini. `UpdateAsync` membaca dan menulis dalam satu
	-- transaksi, jadi di situlah satu-satunya tempat yang benar untuk membaca
	-- nilai lamanya.
	local previous: number? = nil

	-- Tipenya `any`, dan itu terpaksa: `globalTypes.d.luau` mendeklarasikan
	-- transform `UpdateAsync` harus mengembalikan `number`, padahal engine
	-- memperlakukan `nil` sebagai "batalkan tulisannya" -- justru perilaku yang
	-- dipakai di sini. Alternatifnya mengembalikan nilai lama, dan itu berarti
	-- satu tulisan DataStore untuk setiap match yang TIDAK memecahkan rekor:
	-- kuota tulis habis untuk menyimpan angka yang sudah ada di sana.
	local transform: any = function(old: any): number?
		previous = if type(old) == "number" then old else nil
		if not LeaderboardRules.isRecord(previous, wave) then
			-- Inilah LB-03 di tingkat penyimpanan: match yang berakhir lebih
			-- rendah tidak menyentuh rekor.
			return nil
		end
		return math.floor(wave)
	end

	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), transform)
	end)

	if not ok then
		warn(
			string.format(
				"[LeaderboardService] gagal menulis catatan %d di %s: %s",
				userId,
				id,
				tostring(err)
			)
		)
		return
	end

	-- Papan memori dijahit dengan nilai yang BENAR-BENAR tersimpan, bukan
	-- dengan `wave` begitu saja: pemain yang rekornya 9 lalu selesai di wave 4
	-- tetap harus tampil sebagai 9, termasuk kalau dia belum ada di papan ini.
	local stored = if LeaderboardRules.isRecord(previous, wave) then math.floor(wave) else previous
	if stored == nil then
		return
	end

	boards[id] = LeaderboardRules.merge(boards[id] or {}, userId, nameFor(userId), stored)

	if previous == nil or stored > previous then
		print(
			string.format(
				"[LeaderboardService] %s: rekor baru wave %d di %s",
				nameFor(userId),
				stored,
				id
			)
		)
	end
end

-- --------------------------------------------------------------------------
-- API untuk service lain
-- --------------------------------------------------------------------------

-- Papan yang sedang dipegang server, tanpa menyentuh DataStore.
function LeaderboardService.getBoard(difficultyId: string): { Entry }
	return boards[difficultyId] or {}
end

function LeaderboardService.start()
	if started then
		return
	end
	started = true

	-- Satu catatan per peserta yang MASIH TERHUBUNG. Peserta yang sudah keluar
	-- sengaja dilewati: dia sudah dicatat saat keluar, dengan wave yang dia
	-- capai saat itu, dan mencatatnya lagi di sini akan memberinya wave yang
	-- dicapai orang lain setelah dia pergi. Aturan yang sama dipakai
	-- RewardService untuk membayar reward, dan dua pembukuan yang memakai
	-- aturan berbeda untuk match yang sama akan saling bertentangan di layar.
	MatchService.onMatchEnded:Connect(
		function(_won: boolean, waveReached: number, difficultyId: string, userIds: { number })
			task.spawn(function()
				for _, userId in userIds do
					if Players:GetPlayerByUserId(userId) ~= nil then
						record(userId, waveReached, difficultyId)
					end
				end
			end)
		end
	)

	-- Keluar di tengah match: dicatat sesuai wave saat dia keluar. Wave dan
	-- tingkatnya DIBACA di sini, bukan di dalam thread yang di-spawn: thread
	-- itu mulai jalan setelah handler ini selesai, dan saat itu match bisa
	-- saja sudah dibatalkan (peserta terakhir keluar) sehingga wave-nya sudah
	-- kembali 0.
	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player.UserId)
		-- Namanya sengaja TIDAK dibuang dari cache. Dia masih benar setelah
		-- pemainnya keluar, dan justru di sinilah dia paling dibutuhkan:
		-- `record` di bawah jalan sesudah pemainnya pergi, jadi membuangnya
		-- berarti satu panggilan web untuk mencari nama yang baru saja ada di
		-- tangan.

		local state = MatchService.getState()
		if state == "Lobby" or not MatchService.isParticipant(player) then
			return
		end
		local wave = MatchService.getWave()
		local difficultyId = MatchService.getDifficultyId()
		task.spawn(record, player.UserId, wave, difficultyId)
	end)

	-- Kena throttle dibalas `nil`, tingkat yang tidak dikenal juga. Dua-duanya
	-- bukan error: ini RemoteFunction, dan `error()` di dalam OnServerInvoke
	-- muncul di client sebagai error yang tidak bisa dia tangani dengan rapi
	-- (SEC-08). Client memperlakukan nil sebagai "papan belum ada".
	Remotes.Functions.GetLeaderboard.OnServerInvoke = function(player: Player, difficulty: unknown)
		if not RateLimit.check(limiter, player.UserId, "GetLeaderboard", os.clock()) then
			return nil
		end
		local id = LeaderboardRules.normalizeDifficulty(difficulty, Difficulties)
		if id == nil then
			return nil
		end
		requestFetch(id)
		return LeaderboardService.getBoard(id)
	end

	-- Pembacaan pertama dan pembacaan berkala. Semua tingkat dibaca, bukan
	-- cuma yang diminta: papan yang kosong saat pemain pertama membukanya
	-- terlihat seperti papan yang rusak.
	refresher = task.spawn(function()
		while true do
			for id in Difficulties do
				fetch(id)
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)

	print(
		string.format(
			"[LeaderboardService] siap, %d baris per tingkat",
			LeaderboardRules.MAX_ENTRIES
		)
	)
end

function LeaderboardService.stop()
	local thread = refresher
	if thread ~= nil then
		task.cancel(thread)
		refresher = nil
	end
	started = false
end

return LeaderboardService
