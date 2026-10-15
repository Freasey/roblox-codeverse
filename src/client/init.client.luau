--!strict
-- init.client.luau — entry point client.
-- Jalan di device tiap player. Apapun di sini bisa dibaca & dimodifikasi
-- pemain yang niat ngecheat, jadi taruh presentasi/input saja di sisi ini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

-- Cache lokal, murni buat tampilan. Server tetap sumber kebenarannya.
local profile: Config.PlayerData? = nil

local function render()
	if not profile then
		return
	end
	print(
		string.format(
			"[%s] %s — level %d, %d coins",
			Config.GAME_NAME,
			localPlayer.Name,
			profile.level,
			profile.coins
		)
	)
end

Remotes.Events.DataLoaded.OnClientEvent:Connect(function(data)
	profile = data
	render()
end)

Remotes.Events.DataChanged.OnClientEvent:Connect(function(data)
	profile = data
	render()
end)

-- Kalau client join sebelum server sempat FireClient, tarik manual.
task.spawn(function()
	if profile == nil then
		local ok, result = pcall(function()
			return Remotes.Functions.GetProfile:InvokeServer()
		end)
		if ok and result then
			profile = result
			render()
		end
	end
end)
