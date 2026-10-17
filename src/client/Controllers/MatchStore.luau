--!strict
-- MatchStore.luau — satu langganan `MatchState` untuk semua controller.
--
-- Kenapa ada: HUD, toko, lobby, layar hasil, dan tutorial semuanya perlu tahu
-- state match sekarang. Kalau masing-masing menyambung `OnClientEvent` dan
-- memvalidasi payload sendiri, validasinya akan berbeda-beda setelah beberapa
-- bulan dan satu di antaranya akan error saat payload berubah. Satu store, satu
-- validasi, satu sinyal.
--
-- Store ini CUMA cache tampilan. Server tetap sumber kebenarannya; tidak ada
-- keputusan gameplay yang diambil dari nilai di sini.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

local MatchStore = {}

export type MatchState = {
	state: string,
	wave: number,
	timer: number,
	coreHp: number,
	coreMaxHp: number,
}

export type ShopState = {
	open: boolean,
	locked: boolean,
	purchases: { [string]: number },
}

export type BossState = {
	bossId: string,
	hp: number,
	maxHp: number,
	alive: boolean,
}

MatchStore.onMatchState = Signal.new() :: Signal.Signal<MatchState>
MatchStore.onCoins = Signal.new() :: Signal.Signal<number>
MatchStore.onShopState = Signal.new() :: Signal.Signal<ShopState>
MatchStore.onBossState = Signal.new() :: Signal.Signal<BossState>

local matchState: MatchState? = nil
local coins = 0
local shopState: ShopState = { open = false, locked = false, purchases = {} }
local bossState: BossState? = nil
local started = false

local function isNumber(value: unknown): boolean
	return type(value) == "number" and value == value
end

function MatchStore.start()
	if started then
		return
	end
	started = true

	Remotes.Events.MatchState.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if
			type(payload.state) ~= "string"
			or not isNumber(payload.wave)
			or not isNumber(payload.timer)
			or not isNumber(payload.coreHp)
			or not isNumber(payload.coreMaxHp)
		then
			return
		end
		matchState = raw :: MatchState
		MatchStore.onMatchState:Fire(raw :: MatchState)
	end)

	Remotes.Events.MatchCoins.OnClientEvent:Connect(function(raw: unknown)
		if not isNumber(raw) then
			return
		end
		coins = raw :: number
		MatchStore.onCoins:Fire(coins)
	end)

	Remotes.Events.ShopState.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if
			type(payload.open) ~= "boolean"
			or type(payload.locked) ~= "boolean"
			or type(payload.purchases) ~= "table"
		then
			return
		end
		shopState = raw :: ShopState
		MatchStore.onShopState:Fire(shopState)
	end)

	Remotes.Events.BossState.OnClientEvent:Connect(function(raw: unknown)
		if type(raw) ~= "table" then
			return
		end
		local payload = raw :: { [string]: unknown }
		if
			type(payload.bossId) ~= "string"
			or not isNumber(payload.hp)
			or not isNumber(payload.maxHp)
			or type(payload.alive) ~= "boolean"
		then
			return
		end
		bossState = raw :: BossState
		MatchStore.onBossState:Fire(bossState :: BossState)
	end)
end

function MatchStore.get(): MatchState?
	return matchState
end

function MatchStore.getStateName(): string
	local current = matchState
	return if current ~= nil then current.state else "Lobby"
end

function MatchStore.getCoins(): number
	return coins
end

function MatchStore.getShopState(): ShopState
	return shopState
end

function MatchStore.getBossState(): BossState?
	return bossState
end

return MatchStore
