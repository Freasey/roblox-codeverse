--!nocheck
-- enemy_core.luau — GERAK DAN SERANGAN: musuh yang benar-benar di-spawn sebagai
-- Model di Workspace bergerak mendekat ke Core mengikuti waypoint lane, lalu
-- BERHENTI di cincin sekitar base dan memukulnya berulang sampai dibunuh.
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
-- APA YANG BERUBAH, karena separuh file ini dibentuk olehnya
-- (docs/ARENA_REDESIGN.md bagian 4 dan 5). DULU musuh yang mencapai ujung lane
-- men-damage Core SEKALI lalu dihapus dari arena. SEKARANG dia masuk state
-- `attacking_base`, mengambil satu slot di cincin sekitar base, TETAP HIDUP, dan
-- memukul tiap `attackInterval` detik sampai pemain membunuhnya. Field
-- `coreDamage` sudah tidak ada; penggantinya `attackDamage` + `attackInterval` +
-- `targeting`, dan damage ke base adalah `attackDamage *
-- Balance.BASE_DAMAGE_MULT` (0.2) — bukan `attackDamage` apa adanya.
--
-- Satu konsekuensi dari itu membentuk SELURUH bentuk file ini: `isClear()` tidak
-- lagi tercapai dengan sendirinya, jadi tiap kelompok harus mengosongkan arena
-- sendiri sebelum mengukur. Musuh yang ditinggalkan kelompok sebelumnya akan
-- terus memukul base, dan selisih HP Core yang terukur sesudahnya jadi milik dua
-- musuh sekaligus — kegagalan yang terbaca seperti "angka damage-nya salah".
--
-- Yang SENGAJA tidak diuji di sini: tabel keputusan AI (transisi state, pemilihan
-- target, jadwal pukulan, offset slot cincin) ada di modul murni
-- Shared.Modules.EnemyAI dan punya unit test Lune sendiri di
-- tests/EnemyAI.spec.luau, yang jalan di CI tanpa membuka Studio. Yang di bawah
-- membuktikan WIRING-nya di engine — bahwa keputusan itu sampai ke CFrame
-- Instance dan ke HP Core — bukan aritmetikanya.
--
-- Lima bagian. Dua yang pertama dipisah dengan alasan waktu: lane punya 7
-- waypoint dan panjangnya puluhan stud, jadi menunggu satu musuh berjalan dari
-- awal lane sampai ke Core bisa memakan waktu lama di Studio yang cuma ~8 Hz.
-- Bagian 1 membuktikan GERAK dari awal lane (jaraknya menyusut monoton).
-- Bagian 2 membuktikan SAMPAI, MENEMPEL, dan MEMUKUL BERULANG dengan men-spawn
-- musuh di waypoint terakhir lewat EnemyService.spawnAt — jalur yang sama yang
-- dipakai mekanik boss Splitter, jadi bukan jalur khusus test.
--
-- Bagian 3 membuktikan slot cincin: beberapa musuh yang sampai bersamaan tidak
-- berdiri di titik yang sama. Bagian 4 mengulang bagian 2 untuk kelima tipe
-- musuh, dan bagian 5 membaca HP musuh pada beberapa nilai wave. Keduanya murni
-- angka server, jadi keduanya mengambil alih kerja tangan yang paling mahal di
-- daftar manual: membuktikan damage `tank` dan dua boss ke Core menuntut
-- playtest sampai wave 4, 5, dan 10 sambil sengaja membiarkan musuh lewat.

local SAMPLE_COUNT = 4
local SAMPLE_INTERVAL = 0.6

-- Toleransi untuk angka damage. Bukan `T.eq` karena yang dibandingkan hasil
-- PERKALIAN sekarang: `attackDamage * 0.2`, dan 0.2 tidak punya wujud biner yang
-- tepat. Kelima angka yang dipakai di repo ini kebetulan tetap bulat setelah
-- pembulatan double (25*0.2 = 5 persis), tapi menggantungkan assertion pada
-- kebetulan itu berarti angka balancing berikutnya bisa membuatnya merah tanpa
-- ada yang rusak. 0.001 jauh lebih kecil dari selisih antar kelima angka yang
-- diuji (3, 5, 12, 16, 24), jadi tidak ada yang bisa lolos karena toleransi ini.
local DAMAGE_TOLERANCE = 0.001

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

	-- Damage SATU PUKULAN ke base, dirangkai ulang dari dua angka yang berdiri
	-- sendiri: `attackDamage` di modul definisi dan `BASE_DAMAGE_MULT` di
	-- Balance. TIDAK lewat `EnemyAI.baseDamage`, yang justru fungsi yang sedang
	-- diuji — membandingkan hasilnya dengan dirinya sendiri cuma membuktikan
	-- 1 == 1.
	local function perPukulan(attackDamage: number): number
		return attackDamage * Balance.BASE_DAMAGE_MULT
	end

	-- Selisih HP Core yang nil berarti Core tidak pernah kena sama sekali, dan
	-- itu kegagalan yang berbeda dari angka yang salah. `T.near` akan error pada
	-- nil, jadi dua kasus itu dipisah di sini sekali, bukan di tiap pemanggil.
	local function cocokDamage(name: string, actual: number?, expected: number)
		if actual == nil then
			T.fail(name, string.format("HP Core tidak pernah turun; harap %.3f", expected))
		else
			T.near(name, actual, expected, DAMAGE_TOLERANCE)
		end
	end

	local function jarakHorizontalKeCore(point: Vector3): number
		local flat = Vector3.new(point.X - arena.corePosition.X, 0, point.Z - arena.corePosition.Z)
		return flat.Magnitude
	end

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

	-- Musuh yang baru lahir harus BERJALAN, bukan langsung menempel: state awal
	-- yang salah akan membuat seluruh wave berdiri di base sejak frame pertama.
	T.eq("gerak.stateAwalWalking", enemy.state, "walking")

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
	-- Bagian 2: musuh SAMPAI, MENEMPEL di base, dan MEMUKUL BERULANG
	-- ------------------------------------------------------------------
	-- Kelompok ini kebalikan persis dari yang dulu ada di sini. Yang dulu
	-- dibuktikan: Core kena SEKALI sebesar `coreDamage`, lalu musuhnya hilang dan
	-- HP Core tidak turun lagi. Yang dibuktikan sekarang: Core kena sebesar
	-- `attackDamage * BASE_DAMAGE_MULT`, musuhnya TETAP ADA, dan HP Core terus
	-- turun tiap `attackInterval`.
	--
	-- Baris terpentingnya `.musuhTetapHidupSetelahSampai`: kalau suatu saat ada
	-- yang mengembalikan `removeEnemy` ke jalur kedatangan — misal sambil
	-- "memperbaiki" wave yang tidak pernah selesai — assertion itu yang merah
	-- lebih dulu, bukan playtest tiga minggu kemudian.
	local lastWaypoint = lane.waypoints[#lane.waypoints]

	-- Listener dipasang SEBELUM musuhnya ada. `onReachedCore` menyala tepat sekali
	-- per musuh, pada transisi masuk `attacking_base`, dan itu terjadi di
	-- Heartbeat pertama setelah spawn — listener yang dipasang sesudahnya bisa
	-- ketinggalan.
	local reachedCount = 0
	local hpSaatSinyal: number? = nil
	local connection = EnemyService.onReachedCore:Connect(function()
		reachedCount += 1
		if hpSaatSinyal == nil then
			hpSaatSinyal = CoreService.getHp()
		end
	end)

	local hpBefore = CoreService.getHp()
	local arrived = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	T.ok("damage.spawnDiWaypointTerakhir", arrived ~= nil)
	if arrived == nil then
		connection:Disconnect()
		EnemyService.setRunning(false)
		return
	end

	-- Entitas harus membawa angka dari modul definisi tanpa berubah. Dipisah dari
	-- pengukuran HP Core supaya "entitas membawa angka yang salah" (bug di
	-- `spawnFromEntry`) bisa dibedakan dari "HP Core turun sebesar angka lain"
	-- (bug di `step`/`EnemyAI.baseDamage`/`CoreService.damage`).
	T.eq("damage.entitasBawaAttackDamage", arrived.attackDamage, Enemies.basic.attackDamage)
	T.eq("damage.entitasBawaAttackInterval", arrived.attackInterval, Enemies.basic.attackInterval)
	T.ok("damage.attackDamagePositif", arrived.attackDamage > 0, arrived.attackDamage)

	-- Selisihnya dibaca DI DALAM predikat, bukan setelah `waitUntil` kembali:
	-- yang mau diukur satu pukulan, dan pukulan berikutnya jatuh
	-- `attackInterval` kemudian.
	local hpPukulan1: number? = nil
	local kenaSekali = T.waitUntil(function()
		local hp = CoreService.getHp()
		if hp < hpBefore then
			hpPukulan1 = hp
			return true
		end
		return false
	end, 25)

	T.ok(
		"damage.hpCoreBerkurang",
		kenaSekali,
		string.format("%s -> %s", tostring(hpBefore), tostring(CoreService.getHp()))
	)
	T.eq("damage.sinyalOnReachedCore", reachedCount >= 1, true)
	-- Urutan di dalam satu frame, dan ini KONTRAK yang berubah: dulu sinyal
	-- menyala SESUDAH HP Core turun, sekarang SEBELUM. `enterAttackingBase`
	-- menembakkan sinyal sebagai baris terakhirnya, dan pukulan pertama jatuh
	-- beberapa baris sesudahnya di frame yang sama. Yang membaca HP Core di
	-- handler sinyal itu karena itu melihat HP yang BELUM berkurang.
	T.eq("damage.sinyalMenyalaSebelumHpTurun", hpSaatSinyal, hpBefore)
	cocokDamage(
		"damage.besarPukulanPertama",
		if hpPukulan1 ~= nil then hpBefore - hpPukulan1 else nil,
		perPukulan(Enemies.basic.attackDamage)
	)

	-- Inti perubahannya: musuh yang sampai TIDAK hilang.
	T.eq("damage.musuhTetapHidupSetelahSampai", arrived.dead, false)
	T.eq("damage.musuhMasihDihitungAktif", EnemyService.activeCount(), 1)
	T.ok(
		"damage.modelMasihDiWorkspace",
		arrived.model:IsDescendantOf(workspace),
		arrived.model:GetFullName()
	)
	T.eq("damage.stateAttackingBase", arrived.state, "attacking_base")
	T.ok("damage.ringSlotTerisi", arrived.ringSlot ~= nil, tostring(arrived.ringSlot))

	-- Dan pukulannya BERULANG. Yang lama memastikan HP Core TIDAK turun lagi
	-- setelah 1,5 detik; sekarang kebalikannya yang benar.
	--
	-- Jendelanya `attackInterval * 4 + 5` detik, dan jumlah pukulannya TIDAK
	-- dibandingkan dengan jam dinding: harness ini jalan ~8 Hz, jadi tiap pukulan
	-- bisa tergeser sampai satu frame penuh dan "tiga pukulan dalam 3,6 detik"
	-- adalah assertion yang gagal sesekali tanpa ada yang rusak. Yang dikunci
	-- cuma bahwa pukulan berikutnya memang jatuh, dan besarnya sama.
	local jendela = arrived.attackInterval * 4 + 5
	local hpPukulan2: number? = nil
	local kenaLagi = T.waitUntil(function()
		local hp = CoreService.getHp()
		if hpPukulan1 ~= nil and hp < hpPukulan1 then
			hpPukulan2 = hp
			return true
		end
		return false
	end, jendela)
	T.ok(
		"damage.pukulanBerulang",
		kenaLagi,
		string.format("%s -> %s", tostring(hpPukulan1), tostring(CoreService.getHp()))
	)
	cocokDamage(
		"damage.besarPukulanKedua",
		if hpPukulan1 ~= nil and hpPukulan2 ~= nil then hpPukulan1 - hpPukulan2 else nil,
		perPukulan(Enemies.basic.attackDamage)
	)

	-- Terus, bukan dua kali lalu berhenti: `nextStrikeAt` yang jadi NaN akan
	-- lolos dari dua assertion di atas dan membuat musuh berhenti memukul
	-- selamanya pada pukulan ketiga.
	local total = perPukulan(Enemies.basic.attackDamage) * 3
	T.ok(
		"damage.pukulanKetigaDanSeterusnya",
		T.waitUntil(function()
			return hpBefore - CoreService.getHp() >= total - DAMAGE_TOLERANCE
		end, jendela),
		string.format("turun %s dari %s", tostring(hpBefore - CoreService.getHp()), tostring(total))
	)

	-- Tiga pukulan atau lebih sudah jatuh, dan sinyalnya tetap sekali. Ini yang
	-- menangkap `enterAttackingBase` yang dipanggil ulang tiap frame: HP Core
	-- akan turun dengan laju yang sama persis, jadi tidak satu pun assertion
	-- damage di atas yang berubah.
	T.eq("damage.sinyalOnReachedCoreSekaliSaja", reachedCount, 1)
	connection:Disconnect()

	-- Keputusan rancangan bagian 5, dikunci supaya tidak ada yang
	-- "memperbaikinya" nanti tanpa sadar: wave tidak bisa selesai selama ada
	-- musuh hidup di base. Antrian diperiksa terpisah supaya kegagalannya tidak
	-- bisa dibaca sebagai "isClear false karena masih ada yang mengantri".
	T.eq("damage.antrianKosong", EnemyService.queuedCount(), 0)
	T.eq("damage.isClearFalseSelamaMusuhDiBase", EnemyService.isClear(), false)
	T.ok("damage.coreBelumHancur", not CoreService.isDestroyed(), CoreService.getHp())

	T.skip(
		"damage.pukulanKePlayer",
		"damage ke player lewat humanoid:TakeDamage(attackDamage * PLAYER_DAMAGE_MULT), dan "
			.. "harness ini tidak punya Player maupun Humanoid (CreateLocalPlayer ditolak: "
			.. "lacking capability LocalUser). Pengalinya sendiri dipatok unit test "
			.. "EnemyAI.playerDamage di tests/EnemyAI.spec.luau"
	)

	-- ------------------------------------------------------------------
	-- Bagian 3: slot cincin — musuh di base tidak bertumpuk di satu titik
	-- ------------------------------------------------------------------
	-- Seluruh mekanisme slot cincin ada untuk mencegah satu hal: musuh tidak
	-- punya collision (CanCollide = false) dan tidak punya pathfinding, jadi dua
	-- puluh musuh yang berhenti di titik yang sama bertumpuk jadi satu gumpalan
	-- yang tidak bisa dibidik satu-satu. Tanpa assertion ini, regresinya tidak
	-- akan terlihat sampai ada yang memperhatikan gumpalan itu di playtest.
	--
	-- `clearAll()` juga yang mengembalikan `ringSlotNext` ke 0, jadi ketiga musuh
	-- di bawah mendapat slot 0, 1, 2 — bukan tiga nomor acak yang ditinggalkan
	-- bagian 2.
	EnemyService.clearAll()
	CoreService.reset()

	local cincinReached = 0
	local cincinConn = EnemyService.onReachedCore:Connect(function()
		cincinReached += 1
	end)

	local trio: { any } = {}
	for _ = 1, 3 do
		local item = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
		if item ~= nil then
			table.insert(trio, item)
		end
	end
	T.eq("cincin.tigaMusuhSpawn", #trio, 3)
	if #trio < 3 then
		cincinConn:Disconnect()
		EnemyService.setRunning(false)
		EnemyService.clearAll()
		CoreService.reset()
		return
	end

	local semuaMenempel = T.waitUntil(function()
		for _, item in trio do
			if item.state ~= "attacking_base" then
				return false
			end
		end
		return true
	end, 20)
	T.ok("cincin.ketiganyaMenempelDiBase", semuaMenempel, #trio)

	-- Nomor slot dulu: slot yang kembar adalah penyebab, posisi yang kembar cuma
	-- akibatnya, dan memisahkan keduanya membuat laporan kegagalannya menunjuk ke
	-- `ringSlotNext` dan bukan ke `ringSlotOffset`.
	local slotBerbeda = true
	local slotTerpakai: { [number]: boolean } = {}
	local jejakSlot: { string } = {}
	for _, item in trio do
		table.insert(jejakSlot, tostring(item.ringSlot))
		if item.ringSlot == nil or slotTerpakai[item.ringSlot] then
			slotBerbeda = false
		else
			slotTerpakai[item.ringSlot] = true
		end
	end
	T.ok("cincin.nomorSlotBerbeda", slotBerbeda, table.concat(jejakSlot, ","))

	-- Jarak minimum antar slot pada cincin 12 slot radius 10 adalah tali busur
	-- 2 * 10 * sin(pi/12) = 5,2 stud. Yang dituntut di sini 3 stud: cukup untuk
	-- membuktikan musuhnya tidak di titik yang sama, tapi tidak mengunci jumlah
	-- slot maupun radiusnya — keduanya angka balancing di Balance.luau dan boleh
	-- digeser tanpa membuat assertion ini merah.
	local MIN_PISAH = 3
	local pisah = true
	local jejakPisah: { string } = {}
	for i = 1, #trio do
		for j = i + 1, #trio do
			local jarak = (trio[i].primary.CFrame.Position - trio[j].primary.CFrame.Position).Magnitude
			table.insert(jejakPisah, string.format("%d-%d:%.1f", i, j, jarak))
			if jarak < MIN_PISAH then
				pisah = false
			end
		end
	end
	T.ok(
		"cincin.posisiTidakBertumpuk",
		pisah,
		string.format("jarak antar musuh %s (minimum %d)", table.concat(jejakPisah, " "), MIN_PISAH)
	)

	-- Dan mereka berdiri di CINCIN, bukan sekadar berbeda: jarak horizontalnya ke
	-- Core sebesar BASE_RING_RADIUS. Ini sisi yang membuktikan konstanta Balance
	-- benar-benar dipakai; tiga musuh yang tersebar acak di arena juga lolos dari
	-- assertion "tidak bertumpuk" di atas.
	local diCincin = true
	local jejakRadius: { string } = {}
	for _, item in trio do
		local radius = jarakHorizontalKeCore(item.primary.CFrame.Position)
		table.insert(jejakRadius, string.format("%.1f", radius))
		if math.abs(radius - Balance.BASE_RING_RADIUS) > 0.5 then
			diCincin = false
		end
	end
	T.ok(
		"cincin.jarakKeCoreSebesarRadiusCincin",
		diCincin,
		string.format(
			"radius %s, harap %d",
			table.concat(jejakRadius, " "),
			Balance.BASE_RING_RADIUS
		)
	)

	T.eq("cincin.sinyalSekaliPerMusuh", cincinReached, 3)
	cincinConn:Disconnect()

	-- Satu-satunya yang mengakhiri musuh di base adalah dibunuh, dan di situlah
	-- `isClear()` akhirnya true. Dipatok dua arah, bukan satu: `isClear()` yang
	-- selalu false (misal karena `activeCount` yang bocor) juga lolos dari
	-- assertion "false selama ada musuh".
	T.eq("cincin.isClearFalseSelamaAdaMusuh", EnemyService.isClear(), false)
	for _, item in trio do
		EnemyService.damage(item.id, item.maxHp, nil)
	end
	T.ok(
		"cincin.isClearTrueSetelahDibunuh",
		T.waitUntil(function()
			return EnemyService.isClear()
		end, 10),
		string.format("%d aktif, %d antri", EnemyService.activeCount(), EnemyService.queuedCount())
	)

	-- ------------------------------------------------------------------
	-- Bagian 4: besar pukulan ke base untuk KELIMA tipe musuh (CORE-02)
	-- ------------------------------------------------------------------
	-- CORE-02 menyebut lima angka, dan empat di antaranya yang paling mahal
	-- dikerjakan tangan: `tank` baru ikut komposisi wave di wave 4, Splitter di
	-- wave 5, dan Locker di wave 10. `basic` ikut diulang di sini walaupun bagian
	-- 2 sudah membuktikannya dengan detail, supaya kelima angka CORE-02 dipatok di
	-- satu tempat dengan bentuk yang sama.
	--
	-- Patokannya DIBACA dari modul definisi dan dikali BASE_DAMAGE_MULT, bukan
	-- ditulis sebagai angka di sini. Yang diuji adalah bahwa angka di definisi
	-- sampai ke HP Core lewat satu pengali dan tidak berubah di tengah jalan,
	-- bukan bahwa angkanya 3: kalau balancing menggesernya, assertion ini tetap
	-- benar dan yang perlu diperbarui cuma docs/TEST_CASES.md.
	--
	-- Core di-reset dulu, dan tiap kasus mengosongkan arena sendiri: dengan musuh
	-- yang tidak hilang lagi, satu musuh yang ditinggalkan kasus sebelumnya akan
	-- ikut memukul dan selisih HP yang terukur jadi jumlah dua pukulan.
	EnemyService.setRunning(true)
	CoreService.reset()

	-- Satu PUKULAN PERTAMA, diukur dari HP Core sebelum musuhnya ada. Urutannya
	-- penting: musuh yang di-spawn tepat di waypoint terakhir sampai di Heartbeat
	-- berikutnya dan tidak menunggu siapa pun, jadi membaca HP "sebelum" setelah
	-- spawn bisa membaca HP yang sudah berkurang.
	--
	-- Mengembalikan (selisih HP Core satu pukulan, entitasnya). Keduanya nil kalau
	-- musuhnya tidak pernah di-spawn.
	local function ukurPukulanPertama(spawn: () -> any): (number?, any)
		EnemyService.clearAll()
		local before = CoreService.getHp()
		local item = spawn()
		if item == nil then
			return nil, nil
		end
		local turun: number? = nil
		T.waitUntil(function()
			local hp = CoreService.getHp()
			if hp < before then
				turun = before - hp
				return true
			end
			return false
		end, 20)
		return turun, item
	end

	-- Boss tidak bisa lewat `spawnAt`: fungsi itu memaksa `isBoss = false`
	-- (dia dibuat untuk pecahan Splitter), jadi id boss akan dicari di `Enemies`
	-- dan tidak ketemu — yang keluar cuma warn dan nil. Jalur boss yang
	-- sebenarnya adalah ANTRIAN: `BossService.spawnForWave` sendiri tidak
	-- melakukan apa-apa selain `EnemyService.queueBoss(bossId, 1)` lalu menunggu
	-- entitasnya muncul. Yang tidak dijalankan di sini hanya pembukuan
	-- BossService (drop material, mekanik Locker), dan tidak satu pun dari itu
	-- menyentuh `attackDamage`.
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
		-- `step()` yang asli, lewat `enterAttackingBase` — jadi yang dipotong cuma
		-- perjalanannya, bukan jalur damage-nya. Tanpa ini boss harus menempuh
		-- lane 144 stud pada 6–7 stud/detik, 20+ detik per boss, untuk
		-- membuktikan gerak yang sudah dibuktikan `gerak.*` di bagian 1.
		boss.position = lastWaypoint
		boss.waypointIndex = #lane.waypoints
		boss.primary.CFrame = CFrame.new(lastWaypoint)
		return boss
	end

	local PER_TIPE = {
		{ defId = "basic", isBoss = false },
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
			local turun, entitas = ukurPukulanPertama(function()
				if kasus.isBoss then
					return spawnBossDiWaypointTerakhir(kasus.defId)
				end
				return EnemyService.spawnAt(kasus.defId, 1, lastWaypoint, #lane.waypoints)
			end)

			T.eq(
				group .. ".entitasBawaAttackDamageDefinisi",
				if entitas ~= nil then entitas.attackDamage else nil,
				def.attackDamage
			)
			cocokDamage(
				group .. ".hpCoreTurunSebesarSatuPukulan",
				turun,
				perPukulan(def.attackDamage)
			)

			-- Sisi "musuh itu TETAP ADA, bukan hilang setelah memukul" untuk tipe
			-- ini. Dulu kelompok ini memastikan yang sebaliknya.
			T.eq(
				group .. ".musuhTetapHidupSetelahSampai",
				if entitas ~= nil then entitas.dead else nil,
				false
			)
			T.eq(
				group .. ".stateAttackingBase",
				if entitas ~= nil then entitas.state else nil,
				"attacking_base"
			)
		end
	end

	-- CORE-02 menyebut kelima angkanya sebagai nilai dasar "normal / 1 player",
	-- yang menyisakan pertanyaan apakah damage serangan ikut dikali pengali
	-- difficulty seperti HP. Di kode TIDAK: `spawnFromEntry` mengambil
	-- `attackDamage = def.attackDamage` apa adanya, sementara HP-nya lewat
	-- `Balance.enemyHp`. Dipatok di sini — dengan pengali terbesar yang ada
	-- (`hard` 1.8x dan 4 player) supaya pengali apa pun yang ditambahkan nanti
	-- pasti terlihat — supaya kalau pengali itu benar-benar ditambahkan, yang
	-- merah adalah assertion ini dan bukan angka di docs yang diam-diam salah.
	EnemyService.setContext(1, Difficulties.hard, 4)
	local turunHard, entitasHard = ukurPukulanPertama(function()
		return EnemyService.spawnAt("tank", 1, lastWaypoint, #lane.waypoints)
	end)
	T.eq(
		"damageTipe.hard4Player.entitasBawaAngkaDasar",
		if entitasHard ~= nil then entitasHard.attackDamage else nil,
		Enemies.tank.attackDamage
	)
	cocokDamage(
		"damageTipe.hard4Player.hpCoreTurunAngkaDasar",
		turunHard,
		perPukulan(Enemies.tank.attackDamage)
	)
	-- Pembandingnya: HP-nya memang ikut pengali, jadi "tidak ada pengali yang
	-- sampai ke entitas ini" bukan penjelasan yang mungkin untuk assertion di
	-- atas.
	T.ok(
		"damageTipe.hard4Player.hpIkutPengali",
		entitasHard ~= nil and entitasHard.maxHp > Enemies.tank.baseHp,
		if entitasHard ~= nil then entitasHard.maxHp else "nil"
	)
	T.ok("damageTipe.coreBelumHancur", not CoreService.isDestroyed(), CoreService.getHp())

	-- ------------------------------------------------------------------
	-- Bagian 5: HP musuh naik per wave (WAVE-07)
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
	-- diukur HP saat lahir, dan musuh yang berjalan akan sampai di base lalu
	-- mulai memukul Core sebelum angkanya sempat dibaca.
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
	-- dikembalikan ke wave 1 / normal / 1 player: bagian 4 dan 5 mengubahnya,
	-- dan nilai itu tersimpan di EnemyService sampai ada yang menyetelnya lagi.
	EnemyService.setRunning(false)
	EnemyService.clearAll()
	EnemyService.setContext(1, Difficulties.normal, 1)
	CoreService.reset()
end)
