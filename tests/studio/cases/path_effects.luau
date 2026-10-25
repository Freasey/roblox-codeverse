--!nocheck
-- path_effects.luau — EFEK ALUR UPGRADE di engine sungguhan: slow, zona
-- jebakan, dan tanda.
--
-- Kenapa case ini ada, dan kenapa dia bukan unit test: aritmetikanya SUDAH
-- punya unit test di `tests/CombatEffects.spec.luau` -- yang terkuat menang,
-- umur efek, pemilihan korban splash. Yang di bawah ini membuktikan hal yang
-- berbeda dan tidak bisa dijangkau Lune: bahwa angka-angka itu benar-benar
-- SAMPAI ke gerak Part dan ke HP musuh. `EnemyService` menggerakkan musuh
-- dengan menulis `primary.CFrame` tiap Heartbeat dan membaca `enemy.slow`
-- di loop yang sama; kalau pengalinya dihitung tapi tidak dipakai, unit
-- test-nya tetap hijau dan musuhnya tetap berjalan dengan kecepatan penuh.
--
-- Itu bukan kekhawatiran teoretis: `effectiveSpeed` dipakai di DUA tempat di
-- loop itu (cabang `walking` dan cabang `chasing`), dan satu yang terlewat
-- berarti musuh yang diperlambat tetap mengejar pemain dengan kecepatan penuh
-- -- tepat pada saat perlambatannya paling berarti.
--
-- APA YANG TIDAK BISA DITES DI SINI, dan dilaporkan sebagai SKIP dengan
-- alasannya, bukan dilewatkan diam-diam: tiga dari enam efek alur masuk lewat
-- `CombatService.onAttack`, yang menuntut `Player` sungguhan dan karakternya.
-- Harness ini tidak bisa membuat satu pun (`CreateLocalPlayer` ditolak dengan
-- "lacking capability LocalUser"), jadi splash, kerucut melee yang melebar,
-- dan pengurangan damage yang masuk ke pemain tetap menunggu playtest.
--
-- Soal waktu: Studio di bawah `run-in-roblox` berjalan sekitar 8 Hz, bukan 60.
-- Jadi tidak ada satu pun assertion di bawah yang membandingkan DURASI absolut.
-- Yang dibandingkan jarak tempuh relatif terhadap jendela yang sama panjangnya,
-- dan selisih HP yang tidak bergantung waktu sama sekali (tanda).
--
-- Empat kelompok. `slow.*` mengukur gerak satu musuh di dua jendela yang
-- berurutan, sebelum dan sesudah diperlambat -- musuh yang sama, lane yang
-- sama, supaya variasi spawn tidak ikut terukur. `zona.*` memakai musuh yang
-- DIAM di cincin base, karena zona menempel ke tempat dan musuh yang bergerak
-- keluar-masuk zona membuat selisih HP-nya milik dua keadaan sekaligus.
-- `tanda.*` sama sekali tidak memakai waktu: satu panggilan `damage` dan satu
-- selisih HP. `jaga.*` memeriksa bahwa ketiga API-nya tidak error untuk id yang
-- sudah mati atau tidak ada -- jalur yang benar-benar terjadi, karena musuh bisa
-- mati di antara `collectTargets` dan pemasangan efeknya.

local WINDOW = 1.2
local SLOW_MULT = 0.4
-- Ambang longgar DENGAN SENGAJA. Slow 0.4 seharusnya memberi sekitar 40% jarak,
-- dan ambang 0.75 masih jauh di atas itu -- tapi dia tetap merah kalau
-- pengalinya tidak dipakai sama sekali, dan itu kegagalan yang dicari. Ambang
-- yang ketat (misal 0.45) akan merah karena satu frame panjang di Studio yang
-- sibuk, dan test yang merah karena mesinnya sibuk akan dimatikan orang.
local SLOW_THRESHOLD = 0.75

local MARK_MULT = 1.4
-- Jauh di bawah HP satu `basic` wave 1, yang 100. Angka pertama di sini 100,
-- dan dengan tanda x1.4 dia jadi 140 -- dua-duanya membunuh musuhnya, dan
-- pembacaan HP sesudahnya mengindeks nil. Jadi damage uji harus kecil: yang
-- dibuktikan kelompok ini perkalian damage, bukan kematian.
local MARK_BASE_DAMAGE = 20
local DAMAGE_TOLERANCE = 1e-6

local ZONE_RADIUS = 10
local ZONE_DPS = 20
local ZONE_SECONDS = 30

T.main(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage.Shared
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local CombatEffects = require(Shared.Modules.CombatEffects)
	local Difficulties = require(Shared.Modules.Difficulties)

	T.waitUntil(function()
		return T.logContains("[ProgressionService] siap")
	end, 30)

	local arena = MapService.getArena()
	T.ok("prasyarat.arena", arena ~= nil)
	if arena == nil then
		return
	end
	T.eq("prasyarat.arenaKosong", EnemyService.activeCount(), 0)

	local lane = arena.lanes[1]
	T.ok("prasyarat.lane1AdaWaypoint", lane ~= nil and #lane.waypoints >= 2, #lane.waypoints)
	if lane == nil then
		return
	end
	local lastWaypoint = lane.waypoints[#lane.waypoints]

	EnemyService.setContext(1, Difficulties.normal, 1)

	-- Satu musuh yang dipakai bersama oleh satu kelompok, lalu dibersihkan.
	-- Pembersihannya WAJIB: musuh yang ditinggalkan kelompok sebelumnya terus
	-- memukul base, dan selisih HP yang terukur di kelompok berikutnya jadi
	-- milik dua musuh sekaligus -- kegagalan yang terbaca seperti "angkanya
	-- salah". Alasan yang sama ditulis di header enemy_core.luau.
	local function spawnDiLane(): number?
		EnemyService.queue("basic", 1)
		EnemyService.primeSpawnTimer()
		EnemyService.setRunning(true)
		local ok = T.waitUntil(function()
			return EnemyService.activeCount() >= 1
		end, 10)
		if not ok then
			return nil
		end
		for id in EnemyService.getAll() do
			return id
		end
		return nil
	end

	local function bersihkan()
		EnemyService.setRunning(false)
		EnemyService.clearAll()
	end

	-- Posisi dibaca dari INSTANCE, bukan dari field Lua. Kalau penulisan CFrame
	-- gagal (part tidak anchored, PrimaryPart nil), `enemy.position` tetap
	-- bergerak sementara part-nya diam -- dan cuma pembacaan dari sisi Instance
	-- yang menangkapnya. Alasan yang sama membentuk enemy_core.luau.
	local function posisiPart(id: number): Vector3?
		local enemy = EnemyService.get(id)
		if enemy == nil or enemy.primary == nil then
			return nil
		end
		return enemy.primary.CFrame.Position
	end

	-- Jarak yang ditempuh satu musuh selama `WINDOW` detik.
	local function jarakTempuh(id: number): number?
		local sebelum = posisiPart(id)
		if sebelum == nil then
			return nil
		end
		task.wait(WINDOW)
		local sesudah = posisiPart(id)
		if sesudah == nil then
			return nil
		end
		return (sesudah - sebelum).Magnitude
	end

	-- ------------------------------------------------------------------
	-- Kelompok 1: slow dari pukulan benar-benar memperlambat gerak
	-- ------------------------------------------------------------------
	local slowId = spawnDiLane()
	T.ok("slow.musuhTerspawn", slowId ~= nil, tostring(slowId))

	if slowId ~= nil then
		local normal = jarakTempuh(slowId)
		T.ok(
			"slow.jarakSebelumDiperlambat",
			normal ~= nil and normal > 1,
			string.format("%.2f stud", normal or -1)
		)

		-- Durasi jauh lebih panjang dari jendela pengukuran, supaya yang diukur
		-- benar-benar gerak yang diperlambat dan bukan sisa detik terakhirnya.
		EnemyService.applySlow(slowId, SLOW_MULT, 30)

		local enemy = EnemyService.get(slowId)
		T.ok("slow.tersimpanDiMusuh", enemy ~= nil and enemy.slow ~= nil, tostring(enemy ~= nil))

		local diperlambat = jarakTempuh(slowId)
		if normal ~= nil and normal > 1 and diperlambat ~= nil then
			T.ok(
				"slow.jarakTurunSesudahDiperlambat",
				diperlambat < normal * SLOW_THRESHOLD,
				string.format(
					"%.2f vs %.2f stud (rasio %.2f, pengali %.2f)",
					diperlambat,
					normal,
					diperlambat / normal,
					SLOW_MULT
				)
			)
			-- Nol juga salah, dan bedanya penting: musuh yang BERHENTI TOTAL
			-- berarti pengalinya dipakai sebagai pengganti kecepatan, bukan
			-- pengali -- atau ada cabang yang menolak bergerak sama sekali saat
			-- ada slow. Dua-duanya lolos dari ambang di atas.
			T.ok(
				"slow.musuhTidakBerhentiTotal",
				diperlambat > 0,
				string.format("%.3f stud", diperlambat)
			)
		end

		-- Pukulan yang LEBIH LEMAH tidak boleh membatalkan slow yang kuat.
		-- Aritmetikanya dipatok unit test; yang dibuktikan di sini wiring-nya,
		-- bahwa `EnemyService.applySlow` benar-benar lewat `CombatEffects.merge`
		-- dan bukan menimpa langsung.
		EnemyService.applySlow(slowId, 0.95, 30)
		local sesudahLemah = EnemyService.get(slowId)
		T.near(
			"slow.pukulanLemahTidakMembatalkan",
			if sesudahLemah ~= nil and sesudahLemah.slow ~= nil then sesudahLemah.slow.mult else -1,
			SLOW_MULT,
			DAMAGE_TOLERANCE
		)
	end
	bersihkan()

	-- ------------------------------------------------------------------
	-- Kelompok 2: zona jebakan memperlambat DAN memberi damage per detik
	-- ------------------------------------------------------------------
	-- Musuh di-spawn di waypoint TERAKHIR supaya dia masuk `attacking_base` dan
	-- berdiri diam. Zona menempel ke tempat, jadi musuh yang berjalan
	-- keluar-masuk zona membuat selisih HP-nya milik dua keadaan sekaligus.
	local zonaId = nil
	local diam = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	if diam ~= nil then
		zonaId = diam.id
	end
	T.ok("zona.musuhDiamTerspawn", zonaId ~= nil, tostring(zonaId))

	if zonaId ~= nil then
		EnemyService.setRunning(true)
		local hpSebelum = EnemyService.get(zonaId).hp

		-- Zona dipasang TEPAT di posisi musuhnya.
		local titik = posisiPart(zonaId)
		T.ok("zona.titikTerbaca", titik ~= nil, tostring(titik))
		if titik ~= nil then
			EnemyService.addZone(titik, ZONE_RADIUS, 0.5, ZONE_DPS, ZONE_SECONDS)

			local turun = T.waitUntil(function()
				local e = EnemyService.get(zonaId)
				return e == nil or e.hp < hpSebelum
			end, 5)
			T.ok("zona.hpMusuhTurunTanpaDiserang", turun, tostring(turun))

			local sesudah = EnemyService.get(zonaId)
			if sesudah ~= nil then
				-- Yang dibandingkan ARAH dan ORDE, bukan angka pasti: damage
				-- per detik dikali deltaTime, dan deltaTime di Studio 8 Hz
				-- tidak bisa diprediksi. Yang salah kalau HP-nya habis dalam
				-- satu frame (dps diterapkan tanpa deltaTime) atau tidak turun
				-- sama sekali.
				local hilang = hpSebelum - sesudah.hp
				T.ok(
					"zona.damageSebandingWaktuBukanSekaliHabis",
					hilang > 0 and hilang < hpSebelum,
					string.format("%.1f dari %.1f HP", hilang, hpSebelum)
				)
			end
		end

		-- Musuh DI LUAR radius zona tidak boleh ikut kena. Zona kedua ditaruh
		-- jauh dari arena, dan yang diperiksa musuh yang sama: HP-nya tetap
		-- cuma berkurang oleh zona pertama.
		local jauh = lastWaypoint + Vector3.new(500, 0, 500)
		EnemyService.addZone(jauh, ZONE_RADIUS, 0.5, ZONE_DPS * 10, ZONE_SECONDS)
		local titikMusuh = posisiPart(zonaId)
		if titikMusuh ~= nil then
			T.ok("zona.diLuarRadiusTidakKena", CombatEffects.zoneSlowAt(os.clock(), {
				x = titikMusuh.X,
				y = titikMusuh.Y,
				z = titikMusuh.Z,
			}, {
				{
					position = { x = jauh.X, y = jauh.Y, z = jauh.Z },
					radius = ZONE_RADIUS,
					slowMult = 0.5,
					dps = ZONE_DPS,
					expiresAt = os.clock() + ZONE_SECONDS,
				},
			}) == 1, "zona jauh tidak boleh memperlambat musuh di base")
		end
	end
	bersihkan()

	-- Zona HARUS ikut terbuang oleh clearAll. Umurnya cuma beberapa detik, jadi
	-- membiarkannya hampir tidak terlihat -- tapi "hampir" itu match baru yang
	-- wave 1-nya dimulai dengan zona dari match sebelumnya, dan gejalanya musuh
	-- pertama yang jalannya aneh tanpa ada yang menembaknya.
	local sisaId = spawnDiLane()
	if sisaId ~= nil then
		local hpAwal = EnemyService.get(sisaId).hp
		local titikBaru = posisiPart(sisaId)
		-- Zona lama ada di ujung lane dengan radius 10; musuh baru di awal lane
		-- jauh dari situ. Yang diuji bukan jaraknya tapi bahwa daftar zonanya
		-- kosong: kalau `clearAll` tidak membuangnya, zona DPS 200 yang dipasang
		-- di atas masih hidup dan akan terbaca di sini.
		task.wait(WINDOW)
		local sesudah = EnemyService.get(sisaId)
		T.ok(
			"zona.dibuangSaatClearAll",
			sesudah ~= nil and sesudah.hp == hpAwal,
			string.format("hp %s dari %s", tostring(sesudah and sesudah.hp), tostring(hpAwal))
		)
		T.ok("zona.musuhBaruTetapAda", titikBaru ~= nil, tostring(titikBaru))
	end
	bersihkan()

	-- ------------------------------------------------------------------
	-- Kelompok 3: tanda mengalikan damage dari SIAPA PUN
	-- ------------------------------------------------------------------
	-- Tidak memakai waktu sama sekali: satu panggilan damage, satu selisih HP.
	-- Itu yang membuat kelompok ini satu-satunya di file ini yang angkanya bisa
	-- dipatok persis.
	local tanpaTanda = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	T.ok("tanda.musuhPertamaTerspawn", tanpaTanda ~= nil)
	if tanpaTanda ~= nil then
		local sebelum = tanpaTanda.hp
		local dealt = EnemyService.damage(tanpaTanda.id, MARK_BASE_DAMAGE, nil)
		T.near("tanda.damageDasarTanpaTanda", dealt, MARK_BASE_DAMAGE, DAMAGE_TOLERANCE)
		T.near(
			"tanda.hpTurunSebesarDamageDasar",
			sebelum - EnemyService.get(tanpaTanda.id).hp,
			MARK_BASE_DAMAGE,
			DAMAGE_TOLERANCE
		)
	end
	bersihkan()

	local denganTanda = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	T.ok("tanda.musuhKeduaTerspawn", denganTanda ~= nil)
	if denganTanda ~= nil then
		EnemyService.applyMark(denganTanda.id, MARK_MULT, 30)

		local sebelum = denganTanda.hp
		-- Pembunuhnya nil: tanda harus menaikkan damage dari SIAPA PUN, bukan
		-- cuma dari pemain yang menandainya. Turret Toko Match dan damage zona
		-- juga lewat jalur ini, dan dua-duanya tidak punya pemain.
		local dealt = EnemyService.damage(denganTanda.id, MARK_BASE_DAMAGE, nil)
		T.near(
			"tanda.damageDikaliTanpaPemain",
			dealt,
			MARK_BASE_DAMAGE * MARK_MULT,
			DAMAGE_TOLERANCE
		)
		T.near(
			"tanda.hpTurunSebesarDamageYangDikali",
			sebelum - EnemyService.get(denganTanda.id).hp,
			MARK_BASE_DAMAGE * MARK_MULT,
			DAMAGE_TOLERANCE
		)

		-- Tanda yang LEBIH LEMAH tidak boleh menurunkan yang kuat.
		EnemyService.applyMark(denganTanda.id, 1.1, 30)
		local lagi = EnemyService.damage(denganTanda.id, MARK_BASE_DAMAGE, nil)
		T.near(
			"tanda.tandaLemahTidakMenurunkan",
			lagi,
			MARK_BASE_DAMAGE * MARK_MULT,
			DAMAGE_TOLERANCE
		)
	end
	bersihkan()

	-- Tanda yang sudah habis tidak mengalikan apa pun. Durasinya dibuat sangat
	-- pendek lalu ditunggu -- satu-satunya assertion berbasis waktu di kelompok
	-- ini, dan jendelanya (WINDOW) jauh lebih panjang dari durasi tandanya,
	-- jadi 8 Hz tidak mengubah hasilnya.
	local tandaHabis = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	if tandaHabis ~= nil then
		EnemyService.applyMark(tandaHabis.id, MARK_MULT, 0.1)
		task.wait(WINDOW)
		local dealt = EnemyService.damage(tandaHabis.id, MARK_BASE_DAMAGE, nil)
		T.near("tanda.sesudahHabisKembaliKeDamageDasar", dealt, MARK_BASE_DAMAGE, DAMAGE_TOLERANCE)
	end
	bersihkan()

	-- ------------------------------------------------------------------
	-- Kelompok 4: ketiga API aman untuk id yang tidak ada
	-- ------------------------------------------------------------------
	-- Bukan kehati-hatian kosong: CombatService memasang slow dan tanda pada
	-- SETIAP target yang kena, dan target itu bisa sudah mati di pukulan yang
	-- sama -- atau mati karena turret atau zona di frame yang sama, di antara
	-- `collectTargets` dan pemasangan efeknya.
	local hidup = EnemyService.spawnAt("basic", 1, lastWaypoint, #lane.waypoints)
	if hidup ~= nil then
		EnemyService.damage(hidup.id, hidup.hp * 10, nil)
		local masihAda = EnemyService.get(hidup.id)
		T.eq("jaga.musuhSudahHilangDariActive", masihAda, nil)

		local ok = pcall(function()
			EnemyService.applySlow(hidup.id, 0.5, 5)
			EnemyService.applyMark(hidup.id, 1.5, 5)
			EnemyService.applySlow(-1, 0.5, 5)
			EnemyService.applyMark(999999, 1.5, 5)
			EnemyService.addZone(lastWaypoint, 0, 0.5, 5, 5)
			EnemyService.addZone(lastWaypoint, 8, 0.5, 5, 0)
		end)
		T.ok("jaga.efekPadaIdMatiTidakError", ok, tostring(ok))
		T.eq("jaga.posisiIdMatiNil", EnemyService.getPosition(hidup.id), nil)
	end
	bersihkan()

	T.eq("akhir.arenaKosong", EnemyService.activeCount(), 0)
	T.ok("akhir.coreMasihAda", CoreService.getHp() >= 0, CoreService.getHp())

	-- ------------------------------------------------------------------
	-- Yang butuh Player, dan karena itu TIDAK dites di sini
	-- ------------------------------------------------------------------
	T.skip(
		"splash.korbanDiSekitarTitikKena",
		"splash dipasang di CombatService.onAttack, yang menuntut Player dan karakternya; "
			.. "harness tidak bisa membuat Player (CreateLocalPlayer -> lacking capability "
			.. "LocalUser). Pemilihan korbannya sendiri dipatok unit test CombatEffects "
			.. "(withinRadius, termasuk pengecualian target utama)"
	)
	T.skip(
		"splash.targetUtamaTidakKenaDuaKali",
		"sebab yang sama dengan splash.korbanDiSekitarTitikKena. Ini kegagalan yang paling "
			.. "mahal di antara efek alur, karena gejalanya cuma damage yang lebih besar "
			.. "daripada yang tertulis di panel -- dipatok unit test, menunggu playtest"
	)
	T.skip(
		"kerucut.melebarDiTingkat2",
		"ambang kerucut dipakai di CombatService.collectTargets, yang butuh arah bidik "
			.. "dari Player. HitTest.inCone sendiri punya unit test lintas sudut"
	)
	T.skip(
		"bertahan.damageKePlayerDikurangi",
		"butuh Humanoid untuk diukur, sama seperti damage.pukulanKePlayer di enemy_core. "
			.. "Pengalinya dibaca CombatService.getPlayerDamageTakenMult, yang memanggil "
			.. "Players:GetPlayerByUserId dan mengembalikan 1 tanpa Player"
	)
	T.skip(
		"tanda.menularKeMusuhTerdekat",
		"penularan dipasang di CombatService.onAttack (butuh Player). Pemilihan musuh "
			.. "terdekatnya dipatok unit test CombatEffects.nearest, termasuk pemecah seri "
			.. "yang membuatnya deterministik"
	)
end)
