--!strict
-- ProgressionService.luau — upgrade, beli, dan craft senjata (lobby).
--
-- Semua syaratnya ada di ProgressionRules.luau (modul murni, ada unit
-- test-nya). Yang tinggal di sini cuma menerima remote, membaca data dari
-- server, dan menerapkan perubahannya lewat PlayerDataService.update.
--
-- Tiga aturan yang berlaku untuk ketiga aksi:
--   * Hanya saat state `Lobby` (bagian 3.6). Upgrade di tengah wave berarti
--     damage berubah di tengah pertarungan; beli senjata di tengah match
--     berarti pemain bisa mengganti loadout setelah melihat musuh apa yang
--     datang.
--   * Harga dan syaratnya dibaca dari modul shared di server, bukan dari apa
--     pun yang dikirim client. Client cuma mengirim id.
--   * Setiap penolakan dibalas `ActionResult` dengan alasannya. Tanpa jalur
--     balasan, penolakan server terlihat sama seperti tombol yang rusak.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local DataSchema = require(Shared.Modules.DataSchema)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Modules.Weapons)

local MatchService = require(script.Parent.MatchService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

local limiter = RateLimit.newRegistry({
	UpgradeWeapon = 2,
	BuyWeapon = 2,
	CraftWeapon = 2,
}, 2)

local started = false

local function respond(player: Player, action: string, ok: boolean, reason: string?)
	Remotes.Events.ActionResult:FireClient(player, {
		action = action,
		ok = ok,
		reason = reason,
	})
end

-- Pemeriksaan yang sama untuk ketiga aksi: rate limit, tipe argumen, dan data
-- player yang sudah siap. Mengembalikan nil kalau salah satu gagal.
local function prepare(player: Player, action: string, rawId: unknown): (string?, any)
	if not RateLimit.check(limiter, player.UserId, action, os.clock()) then
		return nil, nil
	end
	if type(rawId) ~= "string" then
		return nil, nil
	end

	local data = PlayerDataService.get(player)
	if data == nil then
		respond(player, action, false, "Data kamu belum siap. Coba sebentar lagi.")
		return nil, nil
	end

	return rawId :: string, data
end

local function onUpgrade(player: Player, rawId: unknown, rawPathId: unknown)
	local weaponId, data = prepare(player, "UpgradeWeapon", rawId)
	if weaponId == nil or data == nil then
		return
	end

	-- `pathId` opsional, jadi argumen yang bukan string dibuang jadi nil alih-
	-- alih membatalkan seluruh aksi: client lama yang cuma mengirim `weaponId`
	-- harus tetap bisa meng-upgrade senjata di level yang tidak butuh pilihan
	-- alur. Yang menolak kalau pilihannya memang wajib adalah `canUpgrade`,
	-- dengan pesan yang menyebutkan apa yang kurang.
	local pathId: string? = if type(rawPathId) == "string" then rawPathId else nil

	local def = Weapons[weaponId]
	local save = if def ~= nil then data.weapons[weaponId] else nil
	-- Harga dihitung dari level yang tersimpan di server. Kalau senjatanya
	-- belum dimiliki, level 1 dipakai cuma supaya harganya punya nilai; aksinya
	-- tetap ditolak canUpgrade karena `weapons[id]` nil.
	local price = Balance.upgradePrice(if save ~= nil then save.level else 1)

	local ok, reason = ProgressionRules.canUpgrade(def, {
		state = MatchService.getState(),
		data = data,
	}, price, pathId)

	if not ok or def == nil or save == nil then
		respond(player, "UpgradeWeapon", false, reason)
		return
	end

	-- Dihitung SEBELUM `update`, dari save yang belum naik level: begitu
	-- `entry.level` bertambah, `pathChoiceRequired` sudah tidak berlaku lagi
	-- untuk level yang sama, dan menghitungnya di dalam callback berarti
	-- jawabannya bergantung pada urutan dua baris di dalam satu fungsi.
	local appliedPath = ProgressionRules.pathToApply(def, save, pathId)

	PlayerDataService.update(player, function(d)
		local entry = d.weapons[def.id]
		if entry == nil then
			return
		end
		d.coins -= price
		entry.level += 1
		if appliedPath ~= nil then
			entry.path = appliedPath
		end
	end)

	respond(player, "UpgradeWeapon", true, nil)

	-- Pilihan alur dicetak terpisah, dan sengaja disebut PERMANEN di log:
	-- ini satu-satunya baris di Output yang menandai keputusan yang tidak bisa
	-- dibatalkan, dan kalau ada pemain yang melaporkan alurnya salah, baris ini
	-- yang menjawab apakah servernya menerima pilihan yang berbeda dari yang
	-- dia tekan.
	if appliedPath ~= nil then
		local path = ProgressionRules.findPath(def, appliedPath)
		print(
			string.format(
				"[ProgressionService] %s mengunci alur %s untuk %s -- permanen",
				player.Name,
				if path ~= nil then path.name else appliedPath,
				def.id
			)
		)
	end

	print(
		string.format(
			"[ProgressionService] %s upgrade %s ke level %d (%d koin)",
			player.Name,
			def.id,
			data.weapons[def.id].level,
			price
		)
	)
end

local function onBuy(player: Player, rawId: unknown)
	local weaponId, data = prepare(player, "BuyWeapon", rawId)
	if weaponId == nil or data == nil then
		return
	end

	local def = Weapons[weaponId]
	local ok, reason = ProgressionRules.canBuy(def, {
		state = MatchService.getState(),
		data = data,
	})

	if not ok or def == nil then
		respond(player, "BuyWeapon", false, reason)
		return
	end

	local cost = def.acquire.coinCost or 0
	PlayerDataService.update(player, function(d)
		d.coins -= cost
		-- Senjata baru selalu mulai dari level 1. Tabel baru dibuat di sini,
		-- bukan disalin dari mana pun, supaya tidak ada dua pemain yang
		-- berbagi satu tabel level (bug deep copy bagian 3.2).
		d.weapons[def.id] = { level = 1, path = DataSchema.NO_PATH }
	end)

	respond(player, "BuyWeapon", true, nil)
	print(string.format("[ProgressionService] %s beli %s (%d koin)", player.Name, def.id, cost))
end

local function onCraft(player: Player, rawId: unknown)
	local weaponId, data = prepare(player, "CraftWeapon", rawId)
	if weaponId == nil or data == nil then
		return
	end

	local def = Weapons[weaponId]
	local ok, reason = ProgressionRules.canCraft(def, {
		state = MatchService.getState(),
		data = data,
	})

	if not ok or def == nil then
		respond(player, "CraftWeapon", false, reason)
		return
	end

	local needed: { [string]: number } = def.acquire.materials or {}
	PlayerDataService.update(player, function(d)
		for materialId, amount in needed do
			d.materials[materialId] = math.max(0, (d.materials[materialId] or 0) - amount)
		end
		d.weapons[def.id] = { level = 1, path = DataSchema.NO_PATH }
	end)

	respond(player, "CraftWeapon", true, nil)
	print(string.format("[ProgressionService] %s craft %s", player.Name, def.id))
end

function ProgressionService.start()
	if started then
		return
	end
	started = true

	Remotes.Events.UpgradeWeapon.OnServerEvent:Connect(onUpgrade)
	Remotes.Events.BuyWeapon.OnServerEvent:Connect(onBuy)
	Remotes.Events.CraftWeapon.OnServerEvent:Connect(onCraft)

	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player.UserId)
	end)

	print("[ProgressionService] siap")
end

return ProgressionService
