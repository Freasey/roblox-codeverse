--!strict
-- init.server.luau — entry point server.
-- Rojo bikin file `init.server.luau` jadi Script di node induknya,
-- jadi ini otomatis jalan sebagai ServerScriptService.Server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Services.PlayerDataService)

print(string.format("[%s] server booting (place %d)", Config.GAME_NAME, game.PlaceId))

PlayerDataService.start()

-- Kirim data ke client begitu siap.
Players.PlayerAdded:Connect(function(player)
	local data = PlayerDataService.get(player)
	if not data then
		-- load() masih jalan atau gagal; tunggu sebentar lalu coba lagi.
		task.wait(1)
		data = PlayerDataService.get(player)
	end
	if data then
		PlayerDataService.update(player, function(d)
			d.lastLogin = os.time()
		end)
		Remotes.Events.DataLoaded:FireClient(player, data)
	end
end)

-- Client minta snapshot datanya sendiri. Perhatikan: tidak ada parameter dari
-- client di sini — server menentukan data siapa yang dikembalikan, bukan client.
Remotes.Functions.GetProfile.OnServerInvoke = function(player: Player)
	return PlayerDataService.get(player)
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
			PlayerDataService.update(player, function(d)
				d.coins += 100
			end)
			Remotes.Events.DataChanged:FireClient(player, PlayerDataService.get(player))
		end
	end
end)
