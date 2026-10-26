--!nocheck
-- core_wave.luau — CORE DAN LANE: bagian M1 yang menyangkut HP Core, warna
-- Core, dan pembagian lane, sejauh yang bisa dijangkau tanpa Player.
--
-- Kenapa case ini terpisah dari enemy_core.luau. enemy_core membuktikan satu
-- musuh BERGERAK dan DAMAGE-nya sampai; yang di sini membuktikan hal-hal yang
-- butuh men-setel HP Core ke nilai tertentu atau men-spawn beberapa musuh
-- sekaligus, dan dua-duanya meninggalkan jejak (Core hancur, 8 musuh di arena)
-- yang tidak boleh mengganggu assertion enemy_core.
--
-- BATAS YANG MEMBENTUK SELURUH FILE INI: harness tidak punya Player dan tidak
-- bisa membuatnya (`CreateLocalPlayer` ditolak, *lacking capability LocalUser*
-- — lihat tests/studio/README.md). `MatchService.beginMatch()` mengisi
-- `participants` dari `Players:GetPlayers()`, jadi state TIDAK PERNAH bisa
-- keluar dari `Lobby` di sini. Semua yang bergantung pada transisi state
-- di-skip dengan alasannya, bukan dipalsukan: `setState` itu lokal di
-- MatchService dan memanggilnya dari luar justru akan menguji harness, bukan
-- game.
--
-- Lima kelompok:
--   waypoint.*  WAVE-11 + BOOT-06 — satu musuh melewati waypoint 1..7 BERURUTAN
--               lalu MENEMPEL di base (docs/ARENA_REDESIGN.md bagian 4)
--   warna.*     CORE-06 — Part Core bergeser ke merah seiring HP turun
--   lobby.*     CORE-04 — di luar WaveActive HP Core tidak berkurang
--   habis.*     CORE-03 — Core habis: HP tepat 0, tidak negatif, tidak lanjut
--   lane.*      WAVE-12 — lane dibagikan round-robin, bukan acak

-- Toleransi "lewat dekat waypoint", dalam stud. Dipilih dari dua angka yang
-- diketahui, bukan dikira-kira:
--
--   * Granularitas sampling. Studio di dalam `run-in-roblox` berjalan ~8 Hz,
--     jadi satu frame musuh `basic` (8 stud/detik) menempuh ~1 stud. Musuh
--     juga di-SNAP persis ke waypoint oleh EnemyService.step (`enemy.position =
--     target` saat jaraknya di bawah Balance.WAYPOINT_REACH = 1.5), lalu sisa
--     budget frame itu membawanya maju paling banyak ~1 stud lagi. Jadi sampel
--     terdekat ke sebuah waypoint normalnya < 1.5 stud, dan satu frame yang
--     tersendat 4x lebih panjang pun masih di bawah 4 stud.
--   * Jarak antar waypoint. scripts/build_arena.luau memakai WAYPOINT_SPACING
--     = 20 stud. Dengan toleransi 5, sampel yang "dekat waypoint i" mustahil
--     juga dekat waypoint i±1 (jaraknya minimal 15 stud), jadi urutan
--     kedekatan di bawah tidak bisa tertukar.
--
-- 5 stud duduk di tengah dua angka itu: 3x lebih longgar dari perilaku yang
-- diamati, tapi 4x lebih ketat dari jarak yang bisa membuatnya ambigu.
local WAYPOINT_TOLERANCE = 5

-- Lama maksimum mengikuti satu musuh dari awal lane sampai base. Lane-nya 144
-- stud (CORE_CLEARANCE 24 + 6 x 20) dan `basic` 8 stud/detik, jadi ~15 detik
-- murni jalan; 45 detik memberi ruang untuk frame yang tersendat tanpa
-- menyentuh deadline 150 detik milik case ini.
--
-- Angka ini sekarang SEMATA-MATA pagar, bukan lama jalan yang sesungguhnya.
-- Dulu loop pengikutnya berhenti saat `enemy.dead` — musuh yang sampai di Core
-- dihapus, jadi itu memang penanda "sampai". Setelah rancangan bagian 4, musuh
-- yang sampai TETAP HIDUP, jadi `enemy.dead` tidak pernah true dan loop-nya
-- berjalan sampai habis 45 detik tiap run (wall time case ini naik 35,8 jadi
-- 75,1 detik). Penandanya sekarang transisi state ke `attacking_base`.
local FOLLOW_TIMEOUT = 45
local FOLLOW_INTERVAL = 0.05

T.main(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage.Shared
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local MatchService = require(Services.MatchService)
	local Difficulties = require(Shared.Modules.Difficulties)
	local Lanes = require(Shared.Modules.Lanes)

	T.waitUntil(function()
		return T.logContains("[ProgressionService] siap")
	end, 30)

	local arena = MapService.getArena()
	T.ok("prasyarat.arena", arena ~= nil)
	if arena == nil then
		return
	end
	T.eq("prasyarat.state", MatchService.getState(), "Lobby")
	T.eq("prasyarat.coreHpPenuh", CoreService.getHp(), CoreService.getMaxHp())
	T.eq("prasyarat.arenaKosong", EnemyService.activeCount(), 0)
	T.eq("prasyarat.tigaLane", EnemyService.laneCount(), 3)

	-- Konteks biasanya di-set MatchService saat wave mulai. Di-set langsung di
	-- sini karena match tidak bisa dimulai tanpa Player; sama seperti di
	-- enemy_core.luau.
	EnemyService.setContext(1, Difficulties.normal, 1)

	-- ------------------------------------------------------------------
	-- waypoint.* — WAVE-11 dan BOOT-06: urutan waypoint 1 sampai 7
	-- ------------------------------------------------------------------
	-- Yang dibuktikan di sini lebih kuat dari `gerak.jarakKeCoreMenyusutMonoton`
	-- di enemy_core.luau. Jarak ke Core yang menyusut monoton TIDAK membuktikan
	-- urutan waypoint: lane arena ini satu garis lurus, jadi jalur yang
	-- memotong atau melompati waypoint tetap menghasilkan jarak yang menyusut
	-- monoton dan assertion itu tetap hijau. Yang diperiksa di bawah adalah
	-- kedekatan ke TIAP waypoint dan URUTAN waktu kedekatan itu terjadi.
	--
	-- Posisi waypoint diambil dari Instance-nya langsung, dibaca per NAMA
	-- ("1".."7"), bukan dari `arena.lanes[1].waypoints`. Itu bukan sekadar gaya:
	-- urutan di cache MapService justru salah satu hal yang sedang diuji, jadi
	-- memakainya sebagai patokan akan membuat assertion ini benar dengan
	-- sendirinya.
	local laneFolder = arena.root:FindFirstChild("Lanes")
	laneFolder = if laneFolder ~= nil then laneFolder:FindFirstChild("Lane1") else nil
	T.ok("waypoint.folderLane1", laneFolder ~= nil)
	if laneFolder == nil then
		return
	end

	local expected: { Vector3 } = {}
	local index = 1
	while true do
		local part = laneFolder:FindFirstChild(tostring(index))
		if part == nil or not part:IsA("BasePart") then
			break
		end
		table.insert(expected, part.Position)
		index += 1
	end
	T.eq("waypoint.tujuhWaypointBernamaAngka", #expected, 7)
	if #expected < 2 then
		return
	end

	-- Cache MapService harus berisi waypoint yang sama, dalam urutan yang sama
	-- dengan nama yang di-sort numerik. Ini sisi BOOT-06 yang memeriksa
	-- PEMBACAAN map, sementara assertion gerak di bawah memeriksa PEMAKAIANNYA.
	local lane = arena.lanes[1]
	if lane == nil then
		T.fail("waypoint.laneDiCache", "arena.lanes[1] nil padahal laneCount 2")
		return
	end
	local cacheCocok = #lane.waypoints == #expected
	if cacheCocok then
		for position, point in expected do
			if (lane.waypoints[position] - point).Magnitude > 0.01 then
				cacheCocok = false
				break
			end
		end
	end
	T.ok(
		"waypoint.cacheMapServiceUrutNama",
		cacheCocok,
		string.format("%d waypoint di cache, %d di Instance", #lane.waypoints, #expected)
	)

	-- Sort ANGKA, bukan sort string. Di bawah 10 waypoint keduanya memberi hasil
	-- yang sama, jadi bug ini tidak bisa dibuktikan dari arena yang sekarang
	-- (7 waypoint) — lihat tests/studio/README.md. Yang bisa diuji di sini
	-- adalah fungsi yang memutuskannya, dengan nama yang memaksa keduanya
	-- berbeda: sort string menaruh "10" sebelum "2".
	local ordered = Lanes.orderWaypointNames({ "3", "10", "1", "2", "4", "5", "6", "7", "8", "9" })
	T.ok(
		"waypoint.urutanDariSortAngkaBukanString",
		ordered ~= nil and ordered[2] == "2" and ordered[10] == "10",
		if ordered ~= nil then table.concat(ordered, ",") else "nil"
	)

	EnemyService.queue("basic", 1)
	EnemyService.primeSpawnTimer()
	EnemyService.setRunning(true)

	local muncul = T.waitUntil(function()
		return EnemyService.activeCount() >= 1
	end, 15)
	T.ok("waypoint.musuhSpawn", muncul, EnemyService.activeCount())
	if not muncul then
		EnemyService.setRunning(false)
		EnemyService.clearAll()
		return
	end

	local enemyId: number? = nil
	for id in EnemyService.getAll() do
		enemyId = id
		break
	end
	local enemy = if enemyId ~= nil then EnemyService.get(enemyId) else nil
	T.ok("waypoint.musuhBisaDiambil", enemy ~= nil, enemyId)
	if enemy == nil then
		EnemyService.setRunning(false)
		EnemyService.clearAll()
		return
	end

	-- Jarak terdekat ke tiap waypoint, dan NOMOR SAMPEL saat itu terjadi.
	-- Nomor sampel itu yang membawa urutan: kalau musuh melewati waypoint 5
	-- sebelum waypoint 4, nomor sampelnya tidak naik.
	local nearest: { number } = {}
	local nearestAt: { number } = {}
	local samples = 0
	local menempel = false
	local deadline = os.clock() + FOLLOW_TIMEOUT
	while os.clock() < deadline do
		samples += 1
		-- Dibaca dari Instance, bukan dari `enemy.position`: field Lua cuma
		-- mencatat niat service, dan kalau penulisan CFrame-nya tidak sampai ke
		-- engine, hanya pemeriksaan dari sisi Instance yang menangkapnya.
		local here = enemy.primary.CFrame.Position
		for position, point in expected do
			local distance = (here - point).Magnitude
			if nearest[position] == nil or distance < nearest[position] then
				nearest[position] = distance
				nearestAt[position] = samples
			end
		end
		-- Dua penanda berhenti, dan yang pertama yang biasa dipakai. `dead`
		-- dipertahankan karena musuh ini TETAP bisa mati — misal kalau nanti ada
		-- turret di arena — dan loop yang cuma menunggu `attacking_base` akan
		-- menggantung sampai 45 detik untuk musuh yang mati di tengah lane.
		if enemy.state == "attacking_base" then
			menempel = true
			break
		end
		if enemy.dead then
			break
		end
		task.wait(FOLLOW_INTERVAL)
	end

	T.ok("waypoint.cukupSampel", samples >= 20, samples)
	-- Dulu assertion ini `enemy.dead`: musuh yang sampai di Core men-damage lalu
	-- dihapus, jadi "hilang" memang berarti "sampai". Sekarang yang menandai
	-- kedatangan transisi state-nya, dan "hilang" justru yang TIDAK boleh terjadi
	-- — dua baris di bawah ini mengunci sisi itu.
	T.ok(
		"waypoint.musuhSampaiDiBase",
		menempel and enemy.state == "attacking_base",
		string.format(
			"%d sampel, state %s, waypointIndex %d",
			samples,
			tostring(enemy.state),
			enemy.waypointIndex
		)
	)
	T.eq("waypoint.musuhTetapHidupSetelahSampai", enemy.dead, false)
	T.eq("waypoint.musuhMasihDihitungAktif", EnemyService.activeCount(), 1)
	T.ok("waypoint.ringSlotTerisi", enemy.ringSlot ~= nil, tostring(enemy.ringSlot))
	-- Perjalanan penuh lewat lane berakhir dengan Core yang benar-benar kena.
	-- enemy_core.luau yang memeriksa BESAR pukulannya; yang di sini cuma
	-- memastikan jalur panjangnya bermuara ke sana, bukan ke musuh yang berhenti
	-- di ujung lane tanpa pernah memukul.
	T.ok(
		"waypoint.coreKenaSetelahMusuhMenempel",
		T.waitUntil(function()
			return CoreService.getHp() < CoreService.getMaxHp()
		end, 10),
		string.format("%d / %d", CoreService.getHp(), CoreService.getMaxHp())
	)

	local trace: { string } = {}
	for position = 1, #expected do
		local distance = nearest[position]
		table.insert(
			trace,
			string.format("%d:%.1f@%d", position, distance or -1, nearestAt[position] or -1)
		)
		T.ok(
			string.format("waypoint.lewatDekatWaypoint%d", position),
			distance ~= nil and distance <= WAYPOINT_TOLERANCE,
			string.format("terdekat %.2f stud (toleransi %d)", distance or -1, WAYPOINT_TOLERANCE)
		)
	end

	local naik = true
	for position = 2, #expected do
		local before = nearestAt[position - 1]
		local after = nearestAt[position]
		if before == nil or after == nil or after <= before then
			naik = false
			break
		end
	end
	T.ok("waypoint.urutan1Sampai7", naik, table.concat(trace, " "))

	EnemyService.setRunning(false)
	EnemyService.clearAll()
	CoreService.reset()
	T.eq("waypoint.resetSetelahSampai", CoreService.getHp(), CoreService.getMaxHp())

	-- ------------------------------------------------------------------
	-- warna.* — CORE-06: warna Part Core bergeser ke merah seiring HP turun
	-- ------------------------------------------------------------------
	-- Yang diuji ARAHNYA, bukan nilai RGB-nya. Palet Core (`criticalColor` di
	-- CoreService dan CORE_COLOR di build_arena.luau) adalah presentasi dan
	-- boleh berubah di M7; assertion yang mengunci angka RGB akan gagal saat
	-- itu tanpa ada satu pun yang rusak.
	--
	-- "Ke arah merah" diukur sebagai R dikurangi rata-rata G dan B. Besaran itu
	-- naik untuk warna target merah apa pun, jadi tidak perlu tahu warna
	-- targetnya — berbeda dari memeriksa "R naik", yang kebetulan benar untuk
	-- palet sekarang (biru ke merah) tapi tidak dijamin untuk palet lain.
	local coreServer = arena.root:FindFirstChild("CoreServer")
	local corePart = if coreServer ~= nil then coreServer:FindFirstChild("Core") else nil
	T.ok("warna.partCoreAda", corePart ~= nil and corePart:IsA("BasePart"))
	if corePart == nil or not corePart:IsA("BasePart") then
		return
	end
	-- Part yang diwarnai CoreService harus part yang sama dengan yang dilihat
	-- pemain di arena: `bindVisual` di init.server.luau dipanggil dengan
	-- `arena.corePart`, dan itu PrimaryPart milik CoreServer.
	T.ok("warna.partCoreAdalahYangDiBind", corePart == arena.corePart, corePart:GetFullName())

	local function redness(color: Color3): number
		return color.R - (color.G + color.B) / 2
	end

	local maxHp = CoreService.getMaxHp()
	local penuh = corePart.Color
	CoreService.damage(maxHp * 0.5)
	T.near("warna.hpSetengah", CoreService.getHp() / maxHp, 0.5, 0.01)
	local setengah = corePart.Color
	CoreService.damage(CoreService.getHp() - maxHp * 0.1)
	T.near("warna.hpSepuluhPersen", CoreService.getHp() / maxHp, 0.1, 0.01)
	local sepuluh = corePart.Color

	local urut = { penuh, setengah, sepuluh }
	local label = { "100%", "50%", "10%" }
	local jejak: { string } = {}
	for position, color in urut do
		table.insert(
			jejak,
			string.format(
				"%s=(%.2f,%.2f,%.2f) merah %.3f",
				label[position],
				color.R,
				color.G,
				color.B,
				redness(color)
			)
		)
	end
	local jejakTeks = table.concat(jejak, " -> ")

	T.ok("warna.lebihMerahDi50Persen", redness(setengah) > redness(penuh), jejakTeks)
	T.ok("warna.lebihMerahDi10Persen", redness(sepuluh) > redness(setengah), jejakTeks)

	-- Tiap kanal harus bergerak satu arah saja. Ini yang menangkap lerp yang
	-- zig-zag (misal kalau nanti ada warna perantara kuning yang dipasang
	-- salah): arahnya tidak dikunci, cuma dilarang berbalik di tengah.
	local kanalMonoton = true
	for _, channel in { "R", "G", "B" } do
		local a = (penuh :: any)[channel]
		local b = (setengah :: any)[channel]
		local c = (sepuluh :: any)[channel]
		if not ((b >= a and c >= b) or (b <= a and c <= b)) then
			kanalMonoton = false
			break
		end
	end
	T.ok("warna.tiapKanalMonoton", kanalMonoton, jejakTeks)

	-- Warna tidak boleh ikut berubah tanpa HP berubah, dan reset harus
	-- memulihkannya: kalau `baseColor` di CoreService ikut tergeser tiap kali
	-- `refreshVisual` jalan, warna Core akan merayap ke merah dan tidak pernah
	-- kembali walaupun match baru dimulai.
	CoreService.reset()
	T.ok(
		"warna.resetMemulihkanWarnaAsli",
		(Vector3.new(corePart.Color.R, corePart.Color.G, corePart.Color.B) - Vector3.new(
			penuh.R,
			penuh.G,
			penuh.B
		)).Magnitude < 0.01,
		string.format("(%.2f,%.2f,%.2f)", corePart.Color.R, corePart.Color.G, corePart.Color.B)
	)
	T.skip(
		"warna.terlihatPemainTanpaHud",
		"butuh mata manusia di depan arena: harness tidak punya client, kamera, "
			.. "maupun Player (CreateLocalPlayer ditolak)"
	)

	-- ------------------------------------------------------------------
	-- lobby.* — CORE-04: di luar WaveActive HP Core tidak berkurang
	-- ------------------------------------------------------------------
	-- boot.luau sudah memeriksa `not EnemyService.isRunning()` di Lobby. Yang
	-- ditambahkan di sini dua hal yang tidak dicakupnya: (1) bahwa BENDERA itu
	-- memang mengikuti state — wiring `onStateChanged` -> `setRunning` di
	-- init.server.luau — dan (2) sisi HP Core-nya, dengan musuh yang benar-benar
	-- ada di arena dan berdiri tepat di waypoint terakhir.
	--
	-- Catatan penting soal (1): yang ditembakkan di sini SINYALNYA, bukan
	-- state-nya. `MatchService.getState()` tetap "Lobby" sepanjang case ini dan
	-- memang tidak bisa diubah tanpa Player. Jadi yang diuji adalah
	-- penyambungannya, bukan state machine-nya.
	MatchService.onStateChanged:Fire("Intermission", "WaveActive")
	T.ok(
		"lobby.wiringSetRunningMatiDiIntermission",
		T.waitUntil(function()
			return not EnemyService.isRunning()
		end, 5),
		"setRunning(next == 'WaveActive') di init.server.luau"
	)
	MatchService.onStateChanged:Fire("WaveActive", "Countdown")
	T.ok(
		"lobby.wiringSetRunningHidupDiWaveActive",
		T.waitUntil(function()
			return EnemyService.isRunning()
		end, 5),
		"setRunning(next == 'WaveActive') di init.server.luau"
	)
	MatchService.onStateChanged:Fire("Lobby", "Ended")
	T.ok(
		"lobby.wiringSetRunningMatiDiLobby",
		T.waitUntil(function()
			return not EnemyService.isRunning()
		end, 5),
		"setRunning(next == 'WaveActive') di init.server.luau"
	)

	-- Musuh di-spawn lewat `spawnAt` karena antrian cuma diproses di dalam
	-- `step()`, dan `step()` langsung keluar saat `running` false — jadi musuh
	-- dari antrian tidak akan pernah muncul. Yang mau diuji justru musuh yang
	-- SUDAH ada di arena: itu keadaan sesungguhnya saat wave berakhir dan state
	-- pindah ke Intermission sebelum arena dibersihkan.
	local lastWaypoint = expected[#expected]
	local diam = EnemyService.spawnAt("basic", 1, lastWaypoint, #expected)
	T.ok("lobby.musuhAdaDiArena", diam ~= nil)
	if diam == nil then
		EnemyService.clearAll()
		return
	end

	EnemyService.queue("basic", 2)
	local hpSebelum = CoreService.getHp()
	local posisiSebelum = diam.primary.CFrame.Position
	local aktifSebelum = EnemyService.activeCount()
	task.wait(3)

	T.eq("lobby.coreHpTidakBerubah", CoreService.getHp(), hpSebelum)
	T.eq("lobby.coreTidakHancur", CoreService.isDestroyed(), false)
	T.near(
		"lobby.musuhTidakBergerakSatuStudPun",
		(diam.primary.CFrame.Position - posisiSebelum).Magnitude,
		0,
		0.001
	)
	T.ok("lobby.musuhMasihHidup", not diam.dead)
	T.eq("lobby.antrianTidakSpawn", EnemyService.activeCount(), aktifSebelum)
	T.ok("lobby.antrianMasihTertahan", EnemyService.queuedCount() >= 1, EnemyService.queuedCount())

	EnemyService.clearAll()

	-- ------------------------------------------------------------------
	-- habis.* — CORE-03: Core habis, HP tepat 0 dan tidak pernah negatif
	-- ------------------------------------------------------------------
	local destroyedCount = 0
	local hpSaatSinyal = -1
	local sinyal = CoreService.onDestroyed:Connect(function()
		destroyedCount += 1
		hpSaatSinyal = CoreService.getHp()
	end)

	-- Damage jauh lebih besar dari HP yang tersisa, bukan pas-pasan: justru
	-- itu yang menguji `math.max(0, hp - amount)`. Angka berhingga, karena
	-- `math.huge` ditolak `isValidAmount` dan tidak akan mengurangi apa pun
	-- (celahnya sudah ditutup; lihat komentar panjang di CoreService).
	local hpSebelumHabis = CoreService.getHp()
	local hilang = CoreService.damage(hpSebelumHabis * 3)
	T.eq("habis.hpTepatNol", CoreService.getHp(), 0)
	T.ok("habis.hpTidakNegatif", CoreService.getHp() >= 0, CoreService.getHp())
	T.eq("habis.damageDilaporkanSebesarHpYangAda", hilang, hpSebelumHabis)
	T.eq("habis.isDestroyed", CoreService.isDestroyed(), true)
	T.ok("habis.sinyalOnDestroyedSekali", T.waitUntil(function()
		return destroyedCount >= 1
	end, 5) and destroyedCount == 1, destroyedCount)
	T.eq("habis.hpSudahNolSaatSinyalMenyala", hpSaatSinyal, 0)
	-- Jembatan log lewat ReplicatedStorage (lihat host.luau), jadi barisnya
	-- tidak langsung ada begitu print-nya jalan — ditunggu, bukan dibaca sekali.
	T.ok(
		"habis.logCoreHancur",
		T.waitUntil(function()
			return T.logContains("Core Server hancur")
		end, 10),
		T.logFind("Core Server hancur")
	)

	-- Damage dan heal setelah hancur tidak boleh berefek: HP harus tetap 0,
	-- tidak turun lagi dan tidak naik lagi.
	T.eq("habis.damageLanjutanDitolak", CoreService.damage(50), 0)
	T.eq("habis.healSetelahHancurDitolak", CoreService.heal(500), 0)
	T.eq("habis.hpMasihNol", CoreService.getHp(), 0)

	-- "Tidak terus menyerang Core" dari sisi yang bisa dijangkau: musuh yang
	-- benar-benar SAMPAI di Core setelah Core hancur tidak membuat HP turun di
	-- bawah nol. Musuhnya dijalankan lewat jalur normal (`step` ->
	-- `enterAttackingBase` -> `CoreService.damage`), bukan dengan memanggil
	-- damage langsung.
	--
	-- Sekarang jalur itu memukul BERULANG, bukan sekali: musuhnya menempel di
	-- cincin dan mencoba lagi tiap `attackInterval` sampai dibunuh. Jadi yang
	-- diuji di bawah bukan satu panggilan damage yang ditolak, tapi DERETAN
	-- panggilan yang semuanya ditolak.
	local reached = 0
	local sampai = EnemyService.onReachedCore:Connect(function()
		reached += 1
	end)
	local penyerang = EnemyService.spawnAt("basic", 1, lastWaypoint, #expected)
	EnemyService.setRunning(true)
	local habisDiserang = T.waitUntil(function()
		return reached >= 1
	end, 20)
	-- Pukulan yang DITOLAK tetap menjadwalkan pukulan berikutnya: `step` menulis
	-- `enemy.nextStrikeAt` di luar hasil `CoreService.damage`. Jadi deretan
	-- percobaan itu bisa DITUNGGU, bukan di-`task.wait` buta selama beberapa
	-- interval dan diharapkan cukup — tiga jadwal yang berbeda berarti tiga
	-- percobaan memukul, dan HP yang dibaca sesudahnya sudah melewati ketiganya.
	local jadwal: { number } = {}
	local tigaPercobaan = T.waitUntil(function()
		if penyerang == nil then
			return true
		end
		local at = penyerang.nextStrikeAt
		if jadwal[#jadwal] ~= at then
			table.insert(jadwal, at)
		end
		return #jadwal >= 3
	end, 20)
	EnemyService.setRunning(false)
	sampai:Disconnect()

	T.ok("habis.musuhTetapSampaiDiCore", habisDiserang, reached)
	T.ok(
		"habis.musuhTerusMencobaMemukul",
		tigaPercobaan and #jadwal >= 3,
		string.format("%d jadwal pukulan berbeda terlihat", #jadwal)
	)
	T.eq("habis.hpTetapNolSetelahDiserangLagi", CoreService.getHp(), 0)
	T.ok("habis.hpTetapTidakNegatif", CoreService.getHp() >= 0, CoreService.getHp())
	-- Musuhnya sendiri tidak ikut hilang karena pukulannya ditolak: Core yang
	-- hancur bukan jalan keluar dari `attacking_base`.
	T.eq("habis.musuhTetapHidupDiBase", if penyerang ~= nil then penyerang.dead else nil, false)
	T.eq(
		"habis.stateTetapAttackingBase",
		if penyerang ~= nil then penyerang.state else nil,
		"attacking_base"
	)
	-- Keputusan rancangan bagian 5 dari sisi yang paling mudah dilupakan: arena
	-- yang berisi musuh hidup TIDAK bersih, walaupun Core sudah hancur dan tidak
	-- ada lagi yang bisa dirusak. Dipatok di sini supaya `isClear()` tidak
	-- diam-diam dibuat "true kalau Core hancur" demi wave yang bisa selesai.
	T.eq("habis.isClearFalseWalaupunCoreHancur", EnemyService.isClear(), false)

	-- Yang TIDAK bisa diuji di sini, dan kenapa. Dua-duanya ada di
	-- `MatchService.endMatch`, yang cuma dipanggil dari handler
	-- `CoreService.onDestroyed` saat state `WaveActive` atau `Intermission`.
	-- State di harness ini selamanya `Lobby` (`beginMatch` mengisi
	-- `participants` dari `Players:GetPlayers()`), jadi `endMatch` tidak pernah
	-- jalan — dan memanggilnya dari luar tidak mungkin: dia fungsi lokal.
	T.eq("habis.stateTetapLobbyTanpaPlayer", MatchService.getState(), "Lobby")
	T.skip(
		"habis.stateBerubahKeEnded",
		"MatchService.endMatch cuma jalan dari state WaveActive/Intermission, dan state "
			.. "tidak bisa keluar dari Lobby tanpa Player (participants diisi dari "
			.. "Players:GetPlayers(); CreateLocalPlayer ditolak)"
	)
	T.skip(
		"habis.musuhDibersihkanSaatMatchBerakhir",
		"clearAll() yang membersihkan arena ada di MatchService.endMatch, yang tidak pernah "
			.. "jalan tanpa Player. Yang bisa diuji di sini cuma HP Core-nya: lihat "
			.. "habis.hpTetapNolSetelahDiserangLagi"
	)

	sinyal:Disconnect()
	EnemyService.clearAll()
	CoreService.reset()
	T.eq("habis.resetMengembalikanHp", CoreService.getHp(), CoreService.getMaxHp())
	T.eq("habis.resetMembatalkanHancur", CoreService.isDestroyed(), false)

	-- ------------------------------------------------------------------
	-- lane.* — WAVE-12: lane dibagikan round-robin, bukan acak
	-- ------------------------------------------------------------------
	-- Dijalankan lewat jalur aslinya, bukan dengan memanggil
	-- `MatchRules.spawnOrder` lalu meng-queue sendiri: yang menembakkan
	-- `onWaveStarted` biasanya `MatchService.startNextWave`, dan satu-satunya
	-- yang tidak bisa dijalankan di sini adalah transisi state yang
	-- mendahuluinya. Jadi sinyalnya yang ditembakkan, dan `WaveService.startWave`
	-- yang asli memutuskan jumlah musuh, tipenya, dan lane-nya.
	--
	-- Kenapa 8 musuh cukup: kalau lane diundi acak dengan 3 lane, peluang
	-- hasilnya persis berurutan 1,2,3,1,2,3,1,2 cuma 1/3^7, sekitar 1/2187.
	-- Delapan musuh karena itu memisahkan round-robin dari acak secara
	-- meyakinkan.
	EnemyService.setContext(1, Difficulties.normal, 1)
	MatchService.onWaveStarted:Fire(1)

	local semuaSpawn = T.waitUntil(function()
		return EnemyService.activeCount() >= 8
	end, 40)
	T.ok("lane.waveMengisiArena", semuaSpawn, EnemyService.activeCount())
	T.ok(
		"lane.logWaveService",
		T.waitUntil(function()
			return T.logContains("[WaveService] wave 1: 8 musuh biasa di 3 lane")
		end, 10),
		T.logFind("[WaveService] wave 1:")
	)
	EnemyService.setRunning(false)

	-- Urutan spawn = urutan id: `nextId` naik satu per musuh dan tidak pernah
	-- dipakai ulang, jadi id yang di-sort adalah urutan kemunculan di arena.
	local ids: { number } = {}
	for id in EnemyService.getAll() do
		table.insert(ids, id)
	end
	table.sort(ids)

	local laneUrut: { number } = {}
	local perLane: { [number]: number } = { [1] = 0, [2] = 0, [3] = 0 }
	for _, id in ids do
		local item = EnemyService.get(id)
		if item ~= nil then
			table.insert(laneUrut, item.laneIndex)
			perLane[item.laneIndex] = (perLane[item.laneIndex] or 0) + 1
		end
	end
	local laneTeks = table.concat(laneUrut, ",")

	T.ok("lane.delapanMusuhTerbaca", #laneUrut >= 8, laneTeks)

	local bergantian = #laneUrut >= 8
	for position, laneIndex in laneUrut do
		if laneIndex ~= (position - 1) % 3 + 1 then
			bergantian = false
			break
		end
	end
	T.ok("lane.bergantianSatuSatu", bergantian, laneTeks)
	-- Delapan musuh dibagi tiga lane tidak rata, dan memang begitu: round-robin
	-- berhenti di tengah putaran ketiga.
	T.eq("lane.jumlahDiLane1", perLane[1], 3)
	T.eq("lane.jumlahDiLane2", perLane[2], 3)
	T.eq("lane.jumlahDiLane3", perLane[3], 2)

	-- Musuh harus benar-benar BERJALAN di lane yang disebutnya, bukan cuma
	-- menyimpan angkanya. `spawnFromEntry` jatuh ke `math.random` untuk
	-- `laneIndex` di luar jangkauan, jadi `laneIndex` yang bergantian rapi
	-- dengan posisi yang salah adalah kegagalan yang terlihat sukses.
	--
	-- Tidak dibandingkan dengan waypoint 1: musuh pertama sudah berjalan ~6
	-- detik saat musuh kedelapan muncul (SPAWN_INTERVAL 0.9 detik), jadi
	-- posisinya sudah jauh dari titik spawn. Yang dibandingkan jarak ke JALUR
	-- lane-nya.
	--
	-- Jalurnya diukur sebagai RANTAI SEGMEN, bukan satu garis dari waypoint
	-- pertama ke terakhir. Versi garis lurus benar selama `build_arena.luau`
	-- yang menaruh waypoint, karena dia menaruh semuanya pada satu heading --
	-- tapi `ArenaLayout` membelokkan lane, jadi garis lurus dari ujung ke ujung
	-- memotong tikungannya dan musuh yang berjalan tepat di jalurnya terbaca
	-- puluhan stud melenceng. Rantai segmen benar untuk kedua bentuk.
	local function distanceToLane(point: Vector3, laneIndex: number): number
		local points = arena.lanes[laneIndex].waypoints
		local best = math.huge
		for index = 1, #points - 1 do
			local a = points[index]
			local span = points[index + 1] - a
			local lengthSq = span:Dot(span)
			local along = if lengthSq > 0
				then math.clamp((point - a):Dot(span) / lengthSq, 0, 1)
				else 0
			best = math.min(best, (point - (a + span * along)).Magnitude)
		end
		return best
	end

	-- Dibandingkan dengan lane TERDEKAT di antara semua lane lain, bukan
	-- dengan satu lane sebelah. Dengan tiga lane, lane tengah punya tetangga di
	-- dua sisi, dan memeriksa satu sisi saja meloloskan musuh yang nyasar ke
	-- sisi yang tidak diperiksa.
	local diLaneSendiri = #laneUrut >= 8
	local jejakLane: { string } = {}
	for _, id in ids do
		local item = EnemyService.get(id)
		if item ~= nil then
			local mine = distanceToLane(item.primary.CFrame.Position, item.laneIndex)
			local theirs = math.huge
			for other = 1, #arena.lanes do
				if other ~= item.laneIndex then
					theirs = math.min(theirs, distanceToLane(item.primary.CFrame.Position, other))
				end
			end
			table.insert(jejakLane, string.format("%.1f/%.1f", mine, theirs))
			if mine > WAYPOINT_TOLERANCE or theirs <= WAYPOINT_TOLERANCE * 2 then
				diLaneSendiri = false
			end
		end
	end
	T.ok(
		"lane.musuhBerjalanDiLaneNyaSendiri",
		diLaneSendiri,
		"jarak ke lane sendiri/lane sebelah: " .. table.concat(jejakLane, " ")
	)

	-- Kembalikan state supaya case ini tidak meninggalkan jejak kalau nanti
	-- dijalankan berbarengan dengan case lain di satu sesi Studio.
	EnemyService.setRunning(false)
	EnemyService.clearAll()
	CoreService.reset()
end)
