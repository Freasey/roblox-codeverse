--!strict
-- init.server.luau — entry point server.
-- Rojo bikin file `init.server.luau` jadi Script di node induknya,
-- jadi ini otomatis jalan sebagai ServerScriptService.Server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Waves = require(Shared.Modules.Waves)
local PlayerDataService = require(script.Services.PlayerDataService)

print(string.format("[%s] server booting (place %d)", Config.GAME_NAME, game.PlaceId))

-- Smoke test pola require (docs/DEVELOPMENT_PLAN.md bagian 1.5): Waves me-require
-- Enemies dan Bosses secara relatif. Kalau baris ini tercetak di playtest,
-- `require("./Nama")` memang jalan di engine Roblox, bukan cuma di Lune.
-- Sekalian memvalidasi isinya, supaya id musuh salah ketik ketahuan saat boot.
local wavesOk, wavesErr = Waves.validate()
if wavesOk then
	print(
		string.format(
			"[%s] relative require OK — %d wave tervalidasi",
			Config.GAME_NAME,
			Waves.LAST_WAVE
		)
	)
else
	warn(string.format("[%s] data wave tidak valid: %s", Config.GAME_NAME, tostring(wavesErr)))
end

-- Kirim data ke client begitu siap. Disambung SEBELUM start() supaya player
-- yang sudah ada di server saat start() dipanggil juga kebagian.
-- Cuma PlayerDataService yang menyambung Players.PlayerAdded; dulu init ini
-- ikut menyambung dan balapan dengan load() yang yield (bagian 3.2 poin 3).
PlayerDataService.onLoaded:Connect(function(player, data)
	Remotes.Events.DataLoaded:FireClient(player, data)
end)

PlayerDataService.start()

-- Client minta snapshot datanya sendiri. Perhatikan: tidak ada parameter dari
-- client di sini — server menentukan data siapa yang dikembalikan, bukan client.
Remotes.Functions.GetProfile.OnServerInvoke = function(player: Player)
	return PlayerDataService.waitFor(player)
end

-- Contoh aksi dari client. SELALU validasi di server: argumen dari client
-- bisa apa saja (angka negatif, tabel, nil, string 1MB).
Remotes.Events.RequestAction.OnServerEvent:Connect(function(player: Player, action: unknown)
	if type(action) ~= "string" then
		return
	end

	if action == "claimDailyBonus" then
		local data = PlayerDataService.get(player)
		if not data then
			return
		end
		-- Server yang nentuin jumlahnya, bukan client.
		if os.time() - data.lastLogin > 86400 then
			-- update() yang mengirim DataChanged, jadi tidak perlu manual.
			PlayerDataService.update(player, function(d)
				d.coins += 100
			end)
		end
	end
end)
