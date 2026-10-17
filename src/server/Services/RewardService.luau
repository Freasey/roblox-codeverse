--!strict
-- RewardService.luau — menghitung dan menyimpan reward akhir match.
--
-- Dua jalur pembayaran, dan keduanya perlu:
--
--   1. Match selesai (menang atau kalah) → semua peserta yang masih terhubung
--      dibayar sesuai wave yang dicapai.
--   2. Pemain keluar di tengah match → dibayar SAAT ITU, sesuai wave saat dia
--      keluar (bagian 3.3 mewajibkan ini).
--
-- Satu peserta tidak boleh dibayar dua kali untuk match yang sama. Itu yang
-- `paid` di bawah jaga: pemain yang keluar di wave 7 lalu rejoin sebelum match
-- selesai sudah dibayar, dan tidak ikut dibayar lagi di akhir. Tanpa itu,
-- keluar-lalu-rejoin jadi cara menggandakan reward.
--
-- Semua rumusnya dari Balance.luau. Tidak ada satu angka balancing pun di
-- file ini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Difficulties = require(Shared.Modules.Difficulties)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local Remotes = require(Shared.Remotes)

local BossService = require(script.Parent.BossService)
local MatchService = require(script.Parent.MatchService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local RewardService = {}

-- UserId yang sudah dibayar untuk match yang sedang berjalan.
local paid: { [number]: boolean } = {}
local started = false

local function difficultyFor(id: string)
	return Difficulties[id] or Difficulties.normal
end

-- Hitung dan simpan reward satu pemain. `won` false untuk pemain yang keluar
-- di tengah match: dia tidak menyelesaikan match, jadi tidak dapat bonus
-- menang, tapi tetap dapat reward sesuai wave yang dicapai (bagian 3.3).
local function payPlayer(player: Player, waveReached: number, won: boolean, difficultyId: string)
	if paid[player.UserId] then
		return
	end

	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end

	paid[player.UserId] = true

	local difficulty = difficultyFor(difficultyId)
	local coins = Balance.rewardCoins(waveReached, won, difficulty)
	local xp = Balance.rewardXp(waveReached, won)

	-- Material dari boss sudah dibayarkan BossService saat boss mati, jadi di
	-- sini tidak ditambahkan lagi — cuma dibaca untuk ditampilkan di layar
	-- hasil. Kalau ditambahkan di sini juga, satu boss memberi dua kali.
	local materials = BossService.getMatchMaterials()[player.UserId] or {}

	local unlocked: { string } = {}
	local levelsGained = 0

	-- update() yang mengirim DataChanged ke client, jadi tidak perlu manual.
	PlayerDataService.update(player, function(d)
		d.coins += coins

		local newLevel, newXp, gained = Balance.applyXp(d.level, d.xp, xp)
		d.level = newLevel
		d.xp = newXp
		levelsGained = gained

		d.stats.matchesPlayed += 1
		if won then
			d.stats.wins += 1
			-- `clears` dicatat SEBELUM memeriksa kesulitan yang terbuka, kalau
			-- tidak first clear normal baru membuka hard setelah match
			-- berikutnya (bagian 3.1: first clear membuka hard).
			d.clears[difficultyId] = true
		end
		if waveReached > d.stats.highestWave then
			d.stats.highestWave = waveReached
		end

		unlocked = ProgressionRules.newlyUnlockedDifficulties(d, Difficulties)
		for _, id in unlocked do
			d.unlockedDifficulties[id] = true
		end
	end)

	Remotes.Events.MatchResult:FireClient(player, {
		won = won,
		waveReached = waveReached,
		coins = coins,
		xp = xp,
		materials = materials,
		unlocked = unlocked,
	})

	print(
		string.format(
			"[RewardService] %s: wave %d %s, +%d koin, +%d xp%s%s",
			player.Name,
			waveReached,
			if won then "menang" else "tidak selesai/kalah",
			coins,
			xp,
			if levelsGained > 0 then string.format(", naik %d level", levelsGained) else "",
			if #unlocked > 0
				then string.format(", membuka %s", table.concat(unlocked, ", "))
				else ""
		)
	)
end

function RewardService.start()
	if started then
		return
	end
	started = true

	MatchService.onMatchEnded:Connect(
		function(won: boolean, waveReached: number, difficultyId: string, userIds: { number })
			for _, userId in userIds do
				local player = Players:GetPlayerByUserId(userId)
				if player ~= nil then
					payPlayer(player, waveReached, won, difficultyId)
				end
			end
		end
	)

	-- Pembukuan "sudah dibayar" direset saat match BARU dimulai, bukan saat
	-- match selesai: pemain yang keluar di tengah match sudah dibayar, dan
	-- kalau pembukuannya dihapus saat Ended, dia bisa ikut dibayar lagi di
	-- akhir match yang sama kalau sempat rejoin.
	MatchService.onStateChanged:Connect(function(next: MatchService.State)
		if next == "Countdown" then
			table.clear(paid)
		end
	end)

	-- Pemain keluar di tengah match: dibayar sekarang, sesuai wave saat dia
	-- keluar (bagian 3.3). PlayerDataService.save pada PlayerRemoving yang
	-- menyimpannya ke DataStore, dan handler-nya sudah terpasang di service
	-- itu — yang penting di sini data sudah berubah SEBELUM save jalan.
	Players.PlayerRemoving:Connect(function(player)
		local state = MatchService.getState()
		if state == "Lobby" then
			return
		end
		if not MatchService.isParticipant(player) then
			return
		end
		payPlayer(
			player,
			math.max(1, MatchService.getWave()),
			false,
			MatchService.getDifficultyId()
		)
	end)

	print("[RewardService] siap")
end

return RewardService
