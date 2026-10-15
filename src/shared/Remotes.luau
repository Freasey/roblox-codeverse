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
local EVENT_NAMES = {
	"DataLoaded", -- Server -> Client: data player siap dipakai
	"DataChanged", -- Server -> Client: ada field yang berubah
	"RequestAction", -- Client -> Server: player melakukan aksi
}

local FUNCTION_NAMES = {
	"GetProfile", -- Client -> Server (yields): snapshot data sekarang
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
