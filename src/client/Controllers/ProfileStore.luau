--!strict
-- ProfileStore.luau — cache data player di client.
--
-- Menggantikan cache lokal yang dulu ada langsung di init.client.luau.
-- Alasannya sama dengan MatchStore: lobby, toko, dan HUD semuanya butuh tahu
-- koin permanen, level senjata, dan kesulitan yang terbuka, dan tiga langganan
-- `DataChanged` yang terpisah akan berbeda-beda cara memvalidasinya.
--
-- Ini CUMA cache tampilan. Server tidak pernah mempercayai nilai dari sini;
-- setiap aksi tetap divalidasi ulang di server (bagian 1.2). Kalau cache ini
-- ketinggalan, yang terjadi paling buruk adalah tombol yang terlihat aktif lalu
-- aksinya ditolak server — bukan progres yang salah.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

local ProfileStore = {}

export type PlayerData = Config.PlayerData

ProfileStore.onChanged = Signal.new() :: Signal.Signal<PlayerData>

local profile: PlayerData? = nil
local started = false

-- Payload tetap dicek bentuknya. Server yang mengirimnya, jadi ini bukan soal
-- keamanan — ini supaya skema yang berubah di masa depan menghasilkan UI yang
-- diam, bukan error di tengah render.
local function isPlayerData(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local data = value :: { [string]: unknown }
	return type(data.coins) == "number"
		and type(data.level) == "number"
		and type(data.equippedWeapon) == "string"
		and type(data.weapons) == "table"
		and type(data.materials) == "table"
		and type(data.unlockedDifficulties) == "table"
end

local function accept(raw: unknown)
	if not isPlayerData(raw) then
		return
	end
	profile = raw :: PlayerData
	ProfileStore.onChanged:Fire(profile :: PlayerData)
end

function ProfileStore.start()
	if started then
		return
	end
	started = true

	Remotes.Events.DataLoaded.OnClientEvent:Connect(accept)
	Remotes.Events.DataChanged.OnClientEvent:Connect(accept)

	-- Kalau client join sebelum server sempat FireClient, tarik manual.
	task.spawn(function()
		if profile ~= nil then
			return
		end
		local ok, result = pcall(function()
			return Remotes.Functions.GetProfile:InvokeServer()
		end)
		if ok and profile == nil then
			accept(result)
		end
	end)
end

function ProfileStore.get(): PlayerData?
	return profile
end

function ProfileStore.getCoins(): number
	local data = profile
	return if data ~= nil then data.coins else 0
end

function ProfileStore.getWeaponLevel(weaponId: string): number?
	local data = profile
	if data == nil then
		return nil
	end
	local save = data.weapons[weaponId]
	return if save ~= nil then save.level else nil
end

function ProfileStore.owns(weaponId: string): boolean
	local data = profile
	return data ~= nil and data.weapons[weaponId] ~= nil
end

function ProfileStore.getMaterial(materialId: string): number
	local data = profile
	if data == nil then
		return 0
	end
	return data.materials[materialId] or 0
end

function ProfileStore.hasDifficulty(difficultyId: string): boolean
	local data = profile
	return data ~= nil and data.unlockedDifficulties[difficultyId] == true
end

return ProfileStore
