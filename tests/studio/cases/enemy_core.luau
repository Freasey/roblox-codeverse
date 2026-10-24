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
-- Empat bagian. Dua yang pertama dipisah dengan alasan waktu: lane punya 7
-- waypoint dan panjangnya puluhan stud, jadi menunggu satu musuh berjalan dari
-- awal lane sampai ke Core bisa memakan waktu lama di Studio yang cuma ~8 Hz.
-- Bagian 1 membuktikan GERAK dari awal lane (jaraknya menyusut monoton).
-- Bagian 2 membuktikan SAMPAI dan DAMAGE dengan men-spawn musuh di waypoint
-- terakhir lewat EnemyService.spawnAt — jalur yang sama yang dipakai mekanik
-- boss Splitter, jadi bukan jalur khusus test.
--
-- Bagian 3 mengulang bagian 2 untuk keempat tipe musuh sisanya, dan bagian 4
-- membaca HP musuh pada beberapa nilai wave. Keduanya murni angka server, jadi
-- keduanya mengambil alih kerja tangan yang paling mahal di daftar manual:
-- membuktikan damage `tank` dan dua boss ke Core menuntut playtest sampai wave
-- 4, 5, dan 10 sambil sengaja membiarkan musuh lewat.

local SAMPLE_COUNT = 4
local SAMPLE_INTERVAL = 0.6

T.main(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage.Shared
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local Balance = require(Shared.Modules.Balance)
	local Bosses = require(Shared.Modules.Bosses)
	local Difficulties = require(Shared.Modules.Difficulties)
	local Enemies = require(Shared.Modules.Enemies)

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

	-- ------------------------------------------------------------------
	-- Bagian 3: damage ke Core untuk keempat tipe musuh SISANYA (CORE-02)
	-- ------------------------------------------------------------------
	-- Bagian 2 baru membuktikan `basic`. CORE-02 menyebut lima angka, dan empat
	-- sisanya justru yang paling mahal dikerjakan tangan: `tank` baru ikut
	-- komposisi wave di wave 4, Splitter di wave 5, dan Locker di wave 10.
	--
	-- Patokannya DIBACA dari modul definisi, bukan ditulis sebagai angka di
	-- sini. Yang diuji adalah bahwa angka di definisi sampai ke HP Core tanpa
	-- berubah di tengah jalan, bukan bahwa angkanya 15: kalau balancing
	-- menggesernya, assertion ini tetap benar dan yang perlu diperbarui cuma
	-- docs/TEST_CASES.md.
	--
	-- Total damage keempat tipe plus satu ulangan di `hard` adalah 99 dari 1000
	-- HP Core, jadi tidak ada kedatangan yang terjadi pada Core yang sudah
	-- hancur (damage setelah hancur ditolak CoreService, dan itu akan membuat
	-- selisih HP-nya nol).
	EnemyService.setRunning(true)

	-- Satu kedatangan, diukur dari HP Core sebelum musuhnya ada. Urutannya
	-- penting: musuh yang di-spawn tepat di waypoint terakhir sampai di
	-- Heartbeat berikutnya dan tidak menunggu siapa pun, jadi membaca HP "sebelum"
	-- setelah spawn bisa membaca HP yang sudah berkurang.
	--
	-- Mengembalikan (selisih HP Core, coreDamage yang dibawa entitas). Keduanya
	-- nil kalau musuhnya tidak pernah di-spawn.
	local function ukurKedatangan(spawn: () -> any): (number?, number?)
		local before = CoreService.getHp()
		local item = spawn()
		if item == nil then
			return nil, nil
		end
		local turun = T.waitUntil(function()
			return CoreService.getHp() < before
		end, 20)
		if not turun then
			return nil, item.coreDamage
		end
		return before - CoreService.getHp(), item.coreDamage
	end

	-- Boss tidak bisa lewat `spawnAt`: fungsi itu memaksa `isBoss = false`
	-- (dia dibuat untuk pecahan Splitter), jadi id boss akan dicari di `Enemies`
	-- dan tidak ketemu — yang keluar cuma warn dan nil. Jalur boss yang
	-- sebenarnya adalah ANTRIAN: `BossService.spawnForWave` sendiri tidak
	-- melakukan apa-apa selain `EnemyService.queueBoss(bossId, 1)` lalu menunggu
	-- entitasnya muncul. Yang tidak dijalankan di sini hanya pembukuan
	-- BossService (drop material, mekanik Locker), dan tidak satu pun dari itu
	-- menyentuh `coreDamage`.
	local function spawnBossDiWaypointTerakhir(bossId: string): any
		EnemyService.queueBoss(bossId, 1)
		EnemyService.primeSpawnTimer()

		-- Ditunggu ENTITAS BOSS-nya, bukan `activeCount() >= 1`: hitungan aktif
		-- juga naik karena musuh lain, dan boss yang tidak pernah muncul akan
		-- lolos dari penantian itu lalu gagal dengan pesan yang menunjuk ke
		-- tempat yang salah.
		local boss: any = nil
		T.waitUntil(function()
			for _, item in EnemyService.getAll() do
				if item.isBoss and item.defId == bossId then
					boss = item
					return true
				end
			end
			return false
		end, 15)
		if boss == nil then
			return nil
		end

		-- Dipindahkan ke waypoint terakhir dengan menulis dua field yang sama
		-- dengan yang ditulis `EnemyService.spawnAt` pada musuh yang baru
		-- dibuatnya: posisi, dan index waypoint yang dituju. Sisanya dituntaskan
		-- `step()` yang asli, lewat `arriveAtCore` — jadi yang dipotong cuma
		-- perjalanannya, bukan jalur damage-nya. Tanpa ini boss harus menempuh
		-- lane 144 stud pada 6–7 stud/detik, 20+ detik per boss, untuk
		-- membuktikan gerak yang sudah dibuktikan `gerak.*` di bagian 1.
		boss.position = lastWaypoint
		boss.waypointIndex = #lane.waypoints
		boss.primary.CFrame = CFrame.new(lastWaypoint)
		return boss
	end

	local PER_TIPE = {
		{ defId = "fast", isBoss = false },
		{ defId = "tank", isBoss = false },
		{ defId = "boss_splitter", isBoss = true },
		{ defId = "boss_locker", isBoss = true },
	}

	for _, kasus in PER_TIPE do
		local def = if kasus.isBoss then Bosses[kasus.defId] else Enemies[kasus.defId]
		local group = "damageTipe." .. kasus.defId
		T.ok(group .. ".definisiAda", def ~= nil, kasus.defId)
		if def ~= nil then
			local turun, dibawa = ukurKedatangan(function()
				if kasus.isBoss then
					return spawnBossDiWaypointTerakhir(kasus.defId)
				end
				return EnemyService.spawnAt(kasus.defId, 1, lastWaypoint, #lane.waypoints)
			end)

			-- Dua assertion, bukan satu, supaya kegagalannya bisa dibedakan:
			-- entitas yang membawa angka yang salah (bug di `spawnFromEntry`)
			-- dan HP Core yang turun sebesar angka lain (bug di `arriveAtCore`
			-- atau di `CoreService.damage`) adalah dua kerusakan yang berbeda.
			T.eq(group .. ".entitasBawaCoreDamageDefinisi", dibawa, def.coreDamage)
			T.eq(group .. ".hpCoreTurunPersisCoreDamage", turun, def.coreDamage)

			-- Sisi "musuh itu hilang, tidak menumpuk di Core" untuk tipe ini.
			T.ok(
				group .. ".musuhDibersihkanSetelahSampai",
				T.waitUntil(function()
					return EnemyService.activeCount() == 0
				end, 10),
				EnemyService.activeCount()
			)
		end
	end

	-- CORE-02 menyebut kelima angkanya sebagai nilai dasar "normal / 1 player",
	-- yang menyisakan pertanyaan apakah `coreDamage` ikut dikali pengali
	-- difficulty seperti HP. Di kode TIDAK: `spawnFromEntry` mengambil
	-- `coreDamage = def.coreDamage` apa adanya, sementara HP-nya lewat
	-- `Balance.enemyHp`. Dipatok di sini — dengan pengali terbesar yang ada
	-- (`hard` 1.8x dan 4 player) supaya pengali apa pun yang ditambahkan nanti
	-- pasti terlihat — supaya kalau pengali itu benar-benar ditambahkan, yang
	-- merah adalah assertion ini dan bukan angka di docs yang diam-diam salah.
	EnemyService.setContext(1, Difficulties.hard, 4)
	local turunHard, dibawaHard = ukurKedatangan(function()
		return EnemyService.spawnAt("tank", 1, lastWaypoint, #lane.waypoints)
	end)
	T.eq("damageTipe.hard4Player.entitasBawaAngkaDasar", dibawaHard, Enemies.tank.coreDamage)
	T.eq("damageTipe.hard4Player.hpCoreTurunAngkaDasar", turunHard, Enemies.tank.coreDamage)
	T.ok("damageTipe.coreBelumHancur", not CoreService.isDestroyed(), CoreService.getHp())

	-- ------------------------------------------------------------------
	-- Bagian 4: HP musuh naik per wave (WAVE-07)
	-- ------------------------------------------------------------------
	-- WAVE-07 menuntut `basic` punya HP 100 di wave 1 dan 160 di wave 5. Yang
	-- dihitung tangan di sana adalah JUMLAH SERANGAN sampai musuh mati (4 vs 7),
	-- dan itu memang butuh karakter; HP-nya sendiri bisa dibaca langsung dari
	-- entitas yang di-spawn, dan itulah angka yang sesungguhnya diuji.
	--
	-- Patokannya TIDAK dihitung dengan `Balance.enemyHp`: fungsi itu yang
	-- dipakai `spawnFromEntry`, jadi membandingkan keduanya cuma membuktikan
	-- 1 == 1. Yang dirangkai ulang di sini adalah rumusnya dari dua angka yang
	-- berdiri sendiri — `baseHp` musuh dan `Balance.HP_PER_WAVE` — lalu
	-- dibulatkan seperti `spawnFromEntry` membulatkannya (floor(hp + 0.5): HP
	-- musuh bilangan bulat, dan tanpa pembulatan itu wave 2 jatuh di
	-- 114.99999999999999).
	--
	-- Musuh di-spawn dengan `running` sudah MATI dan di waypoint PERTAMA: yang
	-- diukur HP saat lahir, dan musuh yang berjalan akan sampai di Core lalu
	-- dihapus sebelum sempat dibaca.
	EnemyService.setRunning(false)
	EnemyService.clearAll()

	local WAVES = { 1, 2, 5, 10 }
	local firstWaypoint = lane.waypoints[1]
	local hpPerWave: { [number]: number } = {}
	for _, wave in WAVES do
		EnemyService.setContext(wave, Difficulties.normal, 1)
		local lahir = EnemyService.spawnAt("basic", 1, firstWaypoint, 1)
		local group = string.format("skalaHp.wave%d", wave)
		T.ok(group .. ".spawn", lahir ~= nil)
		if lahir ~= nil then
			hpPerWave[wave] = lahir.hp
			local harap =
				math.floor(Enemies.basic.baseHp * (1 + Balance.HP_PER_WAVE * (wave - 1)) + 0.5)
			T.eq(group .. ".hp", lahir.hp, harap)
			-- maxHp dipakai bar HP dan `Splitter.onHealthChanged` sebagai
			-- pembagi: kalau dia tidak ikut naik, bar musuh wave 5 mulai dari
			-- 160% dan ambang mekanik boss bergeser.
			T.eq(group .. ".maxHpSamaDenganHpSaatLahir", lahir.maxHp, lahir.hp)
		end
		EnemyService.clearAll()
	end

	local jejakHp: { string } = {}
	for _, wave in WAVES do
		table.insert(jejakHp, string.format("w%d=%s", wave, tostring(hpPerWave[wave])))
	end
	local jejakHpTeks = table.concat(jejakHp, " ")

	-- Bentuk yang diminta WAVE-07 apa adanya: HP wave 5 tepat 1.6x HP wave 1.
	-- Diperiksa sebagai PERBANDINGAN, bukan sebagai dua angka lagi, supaya
	-- `baseHp` yang digeser cuma membuat assertion `.hp` di atas merah dan tidak
	-- ikut menenggelamkan yang ini.
	--
	-- Toleransinya 0.005, dan angka itu datang dari pembulatan HP: HP wave 1
	-- adalah 100, jadi pembulatan ke bilangan bulat bisa menggeser perbandingan
	-- paling banyak 0.5/100.
	if hpPerWave[1] ~= nil and hpPerWave[5] ~= nil and hpPerWave[1] > 0 then
		T.near(
			"skalaHp.wave5BerbandingWave1",
			hpPerWave[5] / hpPerWave[1],
			1 + Balance.HP_PER_WAVE * 4,
			0.005
		)
	else
		T.fail("skalaHp.wave5BerbandingWave1", jejakHpTeks)
	end

	-- Naik terus, bukan cuma berbeda di dua titik yang diuji: HP yang turun di
	-- wave yang lebih tinggi berarti tanda rumusnya terbalik, dan dua wave yang
	-- diuji bisa saja kebetulan tetap benar.
	local naik = true
	for position = 2, #WAVES do
		local sebelum = hpPerWave[WAVES[position - 1]]
		local sesudah = hpPerWave[WAVES[position]]
		if sebelum == nil or sesudah == nil or sesudah <= sebelum then
			naik = false
			break
		end
	end
	T.ok("skalaHp.naikTerusAntarWave", naik, jejakHpTeks)

	-- Kembalikan state supaya case ini tidak meninggalkan jejak kalau nanti
	-- dijalankan berbarengan dengan yang lain di satu sesi Studio. Konteks ikut
	-- dikembalikan ke wave 1 / normal / 1 player: bagian 3 dan 4 mengubahnya,
	-- dan nilai itu tersimpan di EnemyService sampai ada yang menyetelnya lagi.
	EnemyService.setRunning(false)
	EnemyService.clearAll()
	EnemyService.setContext(1, Difficulties.normal, 1)
	CoreService.reset()
end)
