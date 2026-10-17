--!nocheck
-- enemy_core.luau — GERAK DAN DAMAGE: musuh yang benar-benar di-spawn sebagai
-- Model di Workspace bergerak mendekat ke Core mengikuti waypoint lane, dan HP
-- Core berkurang tepat sebesar coreDamage musuh saat musuh sampai.
--
-- Kenapa ini berbeda sifatnya dari BOOT: yang diuji di sini perilaku yang
-- berjalan sepanjang waktu, dan datanya diambil dari Instance sungguhan.
-- EnemyService menggerakkan musuh dengan menulis `primary.CFrame` tiap
-- Heartbeat (musuh bukan Humanoid dan tidak pakai PathfindingService). Jadi
-- yang diperiksa bukan field `enemy.position` di tabel Lua — itu cuma mencatat
-- niat service — tapi `primary.CFrame.Position` yang dibaca balik dari engine.
-- Kalau penulisan CFrame-nya gagal (part tidak anchored, model dihancurkan,
-- PrimaryPart nil), field Lua tetap bergerak sementara part-nya diam, dan
-- hanya pemeriksaan dari sisi Instance yang menangkapnya.
--
-- Dua bagian, dengan alasan waktu. Lane punya 7 waypoint dan panjangnya puluhan
-- stud, jadi menunggu satu musuh berjalan dari awal lane sampai ke Core bisa
-- memakan waktu lama di Studio yang cuma ~8 Hz. Bagian 1 membuktikan GERAK dari
-- awal lane (jaraknya menyusut monoton). Bagian 2 membuktikan SAMPAI dan DAMAGE
-- dengan men-spawn musuh di waypoint terakhir lewat EnemyService.spawnAt —
-- jalur yang sama yang dipakai mekanik boss Splitter, jadi bukan jalur khusus
-- test.

local SAMPLE_COUNT = 4
local SAMPLE_INTERVAL = 0.6

T.main(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage.Shared
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local Difficulties = require(Shared.Modules.Difficulties)

	T.waitUntil(function()
		return T.logContains("[ProgressionService] siap")
	end, 30)

	local arena = MapService.getArena()
	T.ok("prasyarat.arena", arena ~= nil)
	if arena == nil then
		return
	end
	T.eq("prasyarat.coreHpPenuh", CoreService.getHp(), CoreService.getMaxHp())
	T.eq("prasyarat.arenaKosong", EnemyService.activeCount(), 0)

	local lane = arena.lanes[1]
	T.ok("prasyarat.lane1AdaWaypoint", lane ~= nil and #lane.waypoints >= 2, #lane.waypoints)

	-- Konteks biasanya di-set WaveService saat wave mulai. Di sini di-set
	-- langsung: test ini tidak butuh MatchService, dan MatchService tidak bisa
	-- memulai match tanpa Player (harness ini tidak punya Player — lihat
	-- remote_reject.luau).
	EnemyService.setContext(1, Difficulties.normal, 1)

	-- ------------------------------------------------------------------
	-- Bagian 1: musuh di-spawn dari antrian dan BERGERAK mendekat ke Core
	-- ------------------------------------------------------------------
	EnemyService.queue("basic", 1)
	EnemyService.primeSpawnTimer()
	EnemyService.setRunning(true)

	local spawned = T.waitUntil(function()
		return EnemyService.activeCount() >= 1
	end, 15)
	T.ok("gerak.musuhSpawn", spawned, EnemyService.activeCount())
	if not spawned then
		EnemyService.setRunning(false)
		return
	end

	local enemyId: number? = nil
	for id in EnemyService.getAll() do
		enemyId = id
		break
	end
	local enemy = if enemyId ~= nil then EnemyService.get(enemyId) else nil
	T.ok("gerak.musuhBisaDiambil", enemy ~= nil, enemyId)
	if enemy == nil then
		EnemyService.setRunning(false)
		return
	end

	T.eq("gerak.defId", enemy.defId, "basic")
	T.ok("gerak.hpPositif", enemy.hp > 0, enemy.hp)

	-- Model sungguhan di Workspace, bukan cuma tabel Lua.
	T.ok("gerak.modelDiWorkspace", enemy.model:IsDescendantOf(workspace), enemy.model:GetFullName())
	T.ok("gerak.primaryPart", enemy.primary:IsA("BasePart"))
	T.ok(
		"gerak.primaryAnchored",
		enemy.primary.Anchored,
		"musuh digerakkan lewat CFrame, bukan fisika"
	)

	-- Jarak diukur dari CFrame part-nya, bukan dari enemy.position.
	local function distanceToCore(): number
		return (enemy.primary.CFrame.Position - arena.corePosition).Magnitude
	end

	local samples = { distanceToCore() }
	for _ = 1, SAMPLE_COUNT do
		task.wait(SAMPLE_INTERVAL)
		if enemy.dead then
			break
		end
		table.insert(samples, distanceToCore())
	end

	T.ok("gerak.cukupSampel", #samples >= 3, #samples)
	local monotone = true
	for index = 2, #samples do
		if samples[index] >= samples[index - 1] then
			monotone = false
			break
		end
	end
	local trace = {}
	for _, value in samples do
		table.insert(trace, string.format("%.1f", value))
	end
	T.ok("gerak.jarakKeCoreMenyusutMonoton", monotone, table.concat(trace, " -> "))
	T.ok(
		"gerak.majuNyata",
		#samples >= 2 and (samples[1] - samples[#samples]) > 1,
		string.format("maju %.1f stud", samples[1] - samples[#samples])
	)

	-- Posisi tabel Lua dan posisi Instance harus sejalan: kalau berbeda jauh,
	-- berarti penulisan CFrame-nya tidak sampai ke engine.
	T.near(
		"gerak.cframeIkutPositionLua",
		(enemy.primary.CFrame.Position - enemy.position).Magnitude,
		0,
		0.5
	)

	-- Core belum boleh kena: musuh masih di tengah lane.
	T.eq("gerak.coreBelumKena", CoreService.getHp(), CoreService.getMaxHp())

	EnemyService.clearAll()
	T.ok(
		"gerak.clearAllMembersihkan",
		T.waitUntil(function()
			return EnemyService.activeCount() == 0
		end, 10),
		EnemyService.activeCount()
	)

	-- ------------------------------------------------------------------
	-- Bagian 2: musuh SAMPAI ke Core dan HP Core berkurang sebesar coreDamage
	-- ------------------------------------------------------------------
	local lastWaypoint = lane.waypoints[#lane.waypoints]
	local arrived = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	T.ok("damage.spawnDiWaypointTerakhir", arrived ~= nil)
	if arrived == nil then
		EnemyService.setRunning(false)
		return
	end

	local coreDamage = arrived.coreDamage
	local hpBefore = CoreService.getHp()
	T.ok("damage.coreDamagePositif", coreDamage > 0, coreDamage)

	local reachedFired = false
	local connection = EnemyService.onReachedCore:Connect(function()
		reachedFired = true
	end)

	local hpDropped = T.waitUntil(function()
		return CoreService.getHp() < hpBefore
	end, 25)
	connection:Disconnect()

	T.ok(
		"damage.hpCoreBerkurang",
		hpDropped,
		string.format("%d -> %d", hpBefore, CoreService.getHp())
	)
	T.eq("damage.sinyalOnReachedCore", reachedFired, true)
	T.eq("damage.besarDamagePersis", hpBefore - CoreService.getHp(), coreDamage)
	T.ok("damage.coreBelumHancur", not CoreService.isDestroyed(), CoreService.getHp())

	-- Musuh yang sampai harus hilang, bukan menumpuk dan men-damage terus.
	T.ok(
		"damage.musuhDibersihkanSetelahSampai",
		T.waitUntil(function()
			return EnemyService.activeCount() == 0
		end, 10),
		EnemyService.activeCount()
	)
	local settled = CoreService.getHp()
	task.wait(1.5)
	T.eq("damage.tidakDamageBerulang", CoreService.getHp(), settled)

	-- Kembalikan state supaya case ini tidak meninggalkan jejak kalau nanti
	-- dijalankan berbarengan dengan yang lain di satu sesi Studio.
	EnemyService.setRunning(false)
	EnemyService.clearAll()
	CoreService.reset()
end)
