--!strict
-- PrototypeDriver.luau — driver sementara untuk M1.
--
-- M1 di docs/DEVELOPMENT_PLAN.md bagian 4 minta "wave statis 1 sampai 3 TANPA
-- state machine lengkap". File ini adalah wave statis itu: dia menyalakan
-- EnemyService, mengantre musuh wave 1 sampai 3, dan menyiarkan `MatchState`
-- supaya HUD punya sesuatu untuk ditampilkan.
--
-- Driver ini DIHAPUS di M2 begitu MatchService ada. Dipisah ke file sendiri,
-- bukan ditulis di init.server.luau, supaya penghapusannya nanti satu langkah
-- dan tidak ada sisa logika prototipe yang nyangkut di bootstrap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Difficulties = require(Shared.Modules.Difficulties)
local Remotes = require(Shared.Remotes)
local Waves = require(Shared.Modules.Waves)

local CoreService = require(script.Parent.CoreService)
local EnemyService = require(script.Parent.EnemyService)
local MapService = require(script.Parent.MapService)

local PrototypeDriver = {}

local PROTOTYPE_LAST_WAVE = 3
local INTERMISSION = 8

local state = "Lobby"
local wave = 0
local timer = 0
local running = false

local function broadcast()
	Remotes.Events.MatchState:FireAllClients({
		state = state,
		wave = wave,
		timer = timer,
		coreHp = CoreService.getHp(),
		coreMaxHp = CoreService.getMaxHp(),
	})
end

-- Komposisi wave prototipe: jumlah total dari Balance.enemyCount dibagi menurut
-- `share` tiap entry. Pembagian yang benar (sisa bagi ikut dibagikan) baru
-- masuk di M2 bersama WaveService; di sini cukup pembagian kasar.
local function queueWave(index: number)
	local def = Waves.get(index)
	if def == nil then
		return
	end

	local playerCount = math.max(1, #Players:GetPlayers())
	EnemyService.setContext(index, Difficulties.normal, playerCount)
	EnemyService.primeSpawnTimer()

	local total = Balance.enemyCount(index, playerCount)
	local shareSum = 0
	for _, entry in def.entries do
		shareSum += entry.share
	end
	if shareSum <= 0 then
		return
	end

	local laneCount = math.max(1, EnemyService.laneCount())
	local spawned = 0
	for _, entry in def.entries do
		local count = math.floor(total * entry.share / shareSum)
		for _ = 1, count do
			spawned += 1
			EnemyService.queue(entry.enemyId, (spawned - 1) % laneCount + 1)
		end
	end
end

function PrototypeDriver.start()
	if running then
		return
	end

	-- Satu titik pemeriksaan map. MapService sudah mengeluarkan satu warn yang
	-- menjelaskan apa yang dicari dan apa yang harus dilakukan user, jadi di
	-- sini cukup berhenti tanpa menambah warn kedua.
	if MapService.getArena() == nil then
		broadcast()
		return
	end

	running = true
	EnemyService.start()
	CoreService.reset()

	task.spawn(function()
		-- Jeda singkat supaya pemain pertama sempat memuat karakternya sebelum
		-- musuh mulai jalan.
		state = "Countdown"
		timer = 5
		while timer > 0 do
			broadcast()
			task.wait(1)
			timer -= 1
		end

		for index = 1, PROTOTYPE_LAST_WAVE do
			if CoreService.isDestroyed() then
				break
			end

			wave = index
			state = "WaveActive"
			timer = 0
			EnemyService.setRunning(true)
			queueWave(index)
			broadcast()

			-- Tunggu sampai wave bersih atau Core hancur. Polling 0.25 detik,
			-- bukan menunggu sinyal onAllClear, karena driver ini sengaja
			-- sederhana; M2 memakai sinyalnya.
			while not EnemyService.isClear() and not CoreService.isDestroyed() do
				task.wait(0.25)
				broadcast()
			end

			if CoreService.isDestroyed() then
				break
			end

			if index < PROTOTYPE_LAST_WAVE then
				state = "Intermission"
				EnemyService.setRunning(false)
				timer = INTERMISSION
				while timer > 0 do
					broadcast()
					task.wait(1)
					timer -= 1
				end
			end
		end

		EnemyService.setRunning(false)
		EnemyService.clearAll()
		state = "Ended"
		timer = 0
		broadcast()

		print(
			string.format(
				"[PrototypeDriver] prototipe selesai di wave %d, core %s",
				wave,
				if CoreService.isDestroyed() then "hancur" else "selamat"
			)
		)
	end)
end

-- Gerbang untuk CombatService: serangan hanya diterima saat wave berjalan.
function PrototypeDriver.canAttack(_player: Player): boolean
	return running and state == "WaveActive" and not CoreService.isDestroyed()
end

return PrototypeDriver
