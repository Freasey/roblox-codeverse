--!strict
-- Remotes.luau — satu-satunya tempat deklarasi RemoteEvent / RemoteFunction.
-- Server bikin instance-nya, client nunggu sampai ada.
--
-- Pakai:
--   local Remotes = require(ReplicatedStorage.Shared.Remotes)
--   Remotes.Events.DataLoaded:FireClient(player, data)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- Daftarkan remote baru di dua tabel ini.
--
-- Nama dan payload remote gameplay mengikuti tabel docs/DEVELOPMENT_PLAN.md
-- bagian 3.6 persis. Jangan diubah namanya tanpa mengubah tabel itu juga.
local EVENT_NAMES = {
	-- Data player (M0)
	"DataLoaded", -- S -> C: data player siap dipakai
	"DataChanged", -- S -> C: ada field yang berubah
	"RequestAction", -- C -> S: player melakukan aksi

	-- Match (bagian 3.6)
	"MatchState", -- S -> C: { state, wave, timer, coreHp, coreMaxHp }
	"MatchCoins", -- S -> C: number (cash tim; nama remote tetap Coins, lihat ShopService)
	"MatchResult", -- S -> C: { won, waveReached, coins, xp, materials, unlocked }
	-- S -> C, PER PEMAIN: { weaponId, level, path } yang berlaku di match ini.
	-- Terpisah dari `ShopState` karena isinya milik satu pemain sementara
	-- `ShopState` disiarkan ke semua -- satu payload untuk dua sifat yang
	-- berbeda berarti salah satunya pasti salah alamat.
	"MatchUpgradeState",
	"SetReady", -- C -> S: boolean
	"SelectLoadout", -- C -> S: weaponId, difficultyId

	-- Combat (bagian 3.7)
	"Attack", -- C -> S: Vector3 arah bidik
	"EnemyHit", -- S -> C: { id, damage, position } — untuk efek saja

	-- Toko Match
	"BuyShopItem", -- C -> S: itemId
	"ShopState", -- S -> C: { open, locked, purchases } — lihat catatan di bawah

	-- Boss
	"BossState", -- S -> C: { bossId, hp, maxHp, alive } — lihat catatan di bawah
	"ShowInfoCard", -- S -> C: bossId

	-- Progres permanen (lobby)
	-- `pathId` cuma dipakai saat naik KE level 4, titik percabangan alur
	-- upgrade; di level lain dia diabaikan. Opsional di remote, wajib di level
	-- 4 -- dan yang menegakkannya `ProgressionRules.canUpgrade`, bukan di sini.
	"UpgradeWeapon", -- C -> S: weaponId, pathId?
	"BuyWeapon", -- C -> S: weaponId
	"CraftWeapon", -- C -> S: weaponId
	"ActionResult", -- S -> C: { action, ok, reason } — lihat catatan di bawah
}

-- Tiga remote di atas (`ShopState`, `BossState`, `ActionResult`) TIDAK ada di
-- tabel bagian 3.6. Ditambahkan karena milestone-nya memintanya tapi tabelnya
-- tidak menyediakan jalurnya:
--   * `BossState` — M4 minta "HP bar boss di HUD", dan payload `MatchState`
--     yang sudah dipatok tidak punya tempat untuk HP boss.
--   * `ShopState` — M3 minta toko hanya aktif saat Intermission dan punya
--     batas pembelian per item; client butuh tahu sisa jatahnya untuk
--     menonaktifkan tombol, dan itu bukan sesuatu yang boleh ditebak client.
--   * `ActionResult` — semua remote C -> S harus bisa ditolak server (koin
--     kurang, state salah). Tanpa jalur balasan, penolakan jadi tidak terlihat
--     dan pemain mengira tombolnya rusak.
-- Semuanya penambahan, bukan penggantian nama, jadi tidak ada yang bergeser
-- dari tabel 3.6.
--
-- `GetLeaderboard` baru didaftarkan di M6, BERSAMA `LeaderboardService` yang
-- memasang `OnServerInvoke`-nya. Urutan itu syarat, bukan kerapian:
-- RemoteFunction yang ada tapi tidak punya handler membuat client yang
-- memanggilnya menggantung selamanya -- tanpa error, tanpa timeout, dan tanpa
-- petunjuk apa pun di layar. Jadi jangan pernah menambah nama ke tabel di
-- bawah lebih dulu supaya client bisa mulai ditulis. Lihat LB-00.
local FUNCTION_NAMES = {
	"GetProfile", -- C -> S (yields): snapshot data sekarang
	"GetLeaderboard", -- C -> S: difficultyId -> { { userId, name, wave } } atau nil
}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Instance
end

local function resolve(folder: Instance, name: string, className: string): Instance
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name, 30) :: Instance
end

local folder = getFolder()

local Events: { [string]: RemoteEvent } = {}
for _, name in EVENT_NAMES do
	Events[name] = resolve(folder, name, "RemoteEvent") :: RemoteEvent
end

local Functions: { [string]: RemoteFunction } = {}
for _, name in FUNCTION_NAMES do
	Functions[name] = resolve(folder, name, "RemoteFunction") :: RemoteFunction
end

return {
	Events = Events,
	Functions = Functions,
}
