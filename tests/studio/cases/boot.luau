--!nocheck
-- boot.luau — BOOT: seluruh rantai service di init.server.luau jalan di engine
-- Roblox yang sungguhan, tanpa error, dan MapService berhasil membaca
-- assets/Arena.rbxmx.
--
-- Ini satu-satunya test di sini yang menguji WIRING-nya, bukan cuma
-- service-nya satu per satu: yang diperiksa adalah jejak log dari
-- init.server.luau apa adanya, plus state awal yang dia hasilkan. Nilainya
-- besar karena inilah kelas bug yang lolos dari lint, type check, dan unit test
-- Lune sekaligus — urutan require yang melingkar, API web yang dipanggil di
-- module scope, atau nama Instance yang salah di Arena.rbxmx semuanya cuma
-- muncul saat engine sungguhan menjalankannya.
--
-- Soal warn: place ini belum pernah di-publish dan assets/Lobby.rbxmx belum
-- ada, jadi DUA warn memang diharapkan muncul. Daripada melonggarkan
-- assertion-nya jadi "warn tidak diperiksa", warn yang diizinkan didaftar
-- eksplisit di bawah dan warn apa pun di luar daftar itu dianggap gagal.
-- Begitu Lobby dibuat atau place di-publish, baris yang bersangkutan hilang
-- sendiri dan test tetap hijau.

local ALLOWED_WARNINGS = {
	-- Place belum di-publish: PlayerDataService sudah sengaja turun ke data
	-- default di memori, dan ini warn yang memberi tahu caranya.
	"DataStore tidak tersedia",
	"DataStore tidak aktif",
	-- assets/Lobby.rbxmx belum ada (M5 menyisakan ini).
	"Lobby tidak lengkap",
	-- Papan leaderboard butuh OrderedDataStore, yang juga tidak ada di place
	-- yang belum di-publish. Satu warn per tingkat kesulitan, dan teksnya
	-- menyebut tingkatnya -- jadi keduanya tidak terbaca sebagai warn identik
	-- yang berulang oleh assertion di bawah.
	"papan normal tidak tersedia",
	"papan hard tidak tersedia",
}

local EXPECTED_LINES = {
	"[CodeVerse] server booting",
	"[CodeVerse] relative require OK",
	"[RewardService] siap",
	"[MapService] Arena siap",
	"[MatchService] siap",
	"[BossService] siap",
	"[ProgressionService] siap",
	"[LeaderboardService] siap",
}

-- Berapa KALI sebuah baris muncul di log, bukan cuma apakah dia ada.
--
-- `T.logFind` berhenti di kecocokan pertama, jadi baris yang tercetak dua kali
-- lolos darinya tanpa suara. Itu bukan kekhawatiran teoretis: cache `require`
-- milik konteks plugin pernah membuat seluruh rantai boot jalan dua kali, dan
-- gejala satu-satunya adalah "[MapService] Arena siap" yang tercetak dua kali
-- (lihat tests/studio/README.md bagian Mekanismenya, lapis 3). Semua assertion
-- lain tetap hijau dalam keadaan itu.
local function logCount(needle: string): number
	local count = 0
	for _, entry in T.log() do
		if string.find(entry.text, needle, 1, true) ~= nil then
			count += 1
		end
	end
	return count
end

T.main(function()
	-- Rantai boot tidak instan: host memanggil Run() lalu script ini juga
	-- mulai, jadi urutannya tidak dijamin. Tunggu penanda terakhir.
	local booted = T.waitUntil(function()
		return T.logContains("[ProgressionService] siap")
	end, 30)
	T.ok("boot.selesai", booted, string.format("%d baris log terekam", #T.log()))

	for _, line in EXPECTED_LINES do
		T.ok("boot.log: " .. line, T.logContains(line))
	end

	-- Baris MapService diperiksa isinya, bukan cuma keberadaannya: "Arena siap"
	-- yang melaporkan 0 lane berarti Arena.rbxmx ter-mount tapi strukturnya
	-- salah, dan itu kegagalan yang terlihat sukses.
	local arenaLine = T.logFind("[MapService] Arena siap")
	T.ok(
		"boot.arena.3lane",
		arenaLine ~= nil and string.find(arenaLine, "3 lane", 1, true) ~= nil,
		arenaLine
	)
	T.ok(
		"boot.arena.waypointTerCache",
		arenaLine ~= nil and string.find(arenaLine, "Lane1=7, Lane2=7, Lane3=7", 1, true) ~= nil,
		arenaLine
	)

	-- BOOT-02 menuntut barisnya TEPAT SATU, dan dua assertion di atas tidak
	-- menjangkau itu. Baris kedua berarti `MapService.getArena()` membaca map
	-- dua kali — artinya `arenaResolved` tidak memegang cache-nya, atau ada dua
	-- salinan modul yang hidup berbarengan, dan dua musuh bisa berjalan di dua
	-- kumpulan waypoint yang berbeda tanpa ada yang terlihat salah.
	T.eq("boot.arena.barisSiapTepatSatu", logCount("[MapService] Arena siap"), 1)

	-- Sisi lain dari kejadian yang sama: init.server.luau mencetak baris ini di
	-- module scope, jadi dua baris = rantai boot jalan dua kali.
	T.eq("boot.initServerJalanSekali", logCount("[CodeVerse] server booting"), 1)

	-- Arena ADA di place ini, jadi warn Arena tidak boleh muncul SAMA SEKALI.
	-- Diperiksa terpisah dari `boot.tidakAdaWarnTakTerduga` karena warn ini yang
	-- paling mungkin lolos: dia memang bukan warn tak terduga kalau map-nya
	-- hilang, dan tanpa assertion ini satu-satunya gejalanya adalah angka lane 0
	-- di baris "Arena siap" yang tidak pernah tercetak.
	T.eq(
		"boot.mapService.warnArenaTidakPernah",
		logCount("[MapService] Arena tidak bisa dipakai"),
		0
	)

	-- BOOT-03 menuntut warn MapService "tidak berulang tiap frame". Yang bisa
	-- diperiksa dari sini adalah bentuk yang sama untuk warn Lobby, yang memang
	-- muncul di place ini (assets/Lobby.rbxmx belum ada): `getLobby()` dipanggil
	-- beberapa service dan warn-nya dijaga bendera sekali-pakai `lobbyWarned`,
	-- jadi angka 2 berarti bendera itu tidak bekerja.
	--
	-- Batas ATAS, bukan sama dengan satu: begitu Lobby dibuat angkanya jadi nol,
	-- dan itu kemajuan, bukan kegagalan. Alasannya sama dengan ALLOWED_WARNINGS
	-- di atas file ini.
	local lobbyWarnCount = logCount("[MapService] Lobby tidak lengkap")
	T.ok("boot.mapService.warnLobbyTidakBerulang", lobbyWarnCount <= 1, lobbyWarnCount)

	-- Hanya keluaran milik game yang dihitung: Studio ikut mencetak ke Output
	-- yang sama, dan sampahnya muncul tidak menentu (lihat T.gameErrors di
	-- lib/prelude.luau — ini ketahuan karena membuat test ini gagal di satu
	-- dari tiga run dengan pesan "ContentId: rbxassetid://..." milik Studio).
	local errors = T.gameErrors()
	T.ok("boot.tidakAdaError", #errors == 0, table.concat(errors, " || "))

	-- Yang dibuang tetap dicetak, supaya tidak ada pesan yang hilang tanpa
	-- jejak dan pembaca hasil run bisa menilai sendiri.
	local foreign = T.foreignMessages()
	T.pass(
		"boot.pesanBukanMilikGameYangDiabaikan",
		string.format("%d: %s", #foreign, table.concat(foreign, " || "))
	)

	local unexpected = {}
	local allowedCount = 0
	for _, warning in T.gameWarnings() do
		local isAllowed = false
		for _, allowed in ALLOWED_WARNINGS do
			if string.find(warning, allowed, 1, true) ~= nil then
				isAllowed = true
				break
			end
		end
		if isAllowed then
			allowedCount += 1
		else
			table.insert(unexpected, warning)
		end
	end
	T.ok("boot.tidakAdaWarnTakTerduga", #unexpected == 0, table.concat(unexpected, " || "))
	T.pass(
		"boot.warnYangDiizinkan",
		string.format("%d warn, semuanya ada di daftar yang diizinkan", allowedCount)
	)

	-- Bentuk umum dari "tidak ada warn yang berulang tiap frame" (BOOT-03):
	-- tidak ada warn milik game yang teksnya PERSIS sama muncul lebih dari
	-- sekali. Diperiksa sebagai teks utuh, bukan per awalan service, karena
	-- setiap warn di src/ menyebut service DAN alasannya — dua sebab yang
	-- berbeda tidak menghasilkan teks yang identik, jadi duplikat selalu berarti
	-- warn yang sama keluar dua kali.
	--
	-- Ini melengkapi daftar izin di atas, yang menyaring warn menurut ISINYA dan
	-- karena itu melewatkan warn yang diizinkan tapi tercetak 400 kali.
	local warnCounts: { [string]: number } = {}
	local repeated: { string } = {}
	for _, warning in T.gameWarnings() do
		local seen = (warnCounts[warning] or 0) + 1
		warnCounts[warning] = seen
		if seen == 2 then
			table.insert(repeated, warning)
		end
	end
	T.ok("boot.tidakAdaWarnIdentikBerulang", #repeated == 0, table.concat(repeated, " || "))

	-- State awal yang dihasilkan wiring itu. Dibaca dari service yang sama
	-- dengan yang dipakai init.server.luau — script ini disuntik sebagai Script
	-- server, jadi cache require-nya berbagi (lihat host.luau).
	local Services = game.ServerScriptService.Server.Services
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local MatchService = require(Services.MatchService)
	local LeaderboardService = require(Services.LeaderboardService)

	T.eq("boot.state", MatchService.getState(), "Lobby")
	T.eq("boot.coreHpPenuh", CoreService.getHp(), CoreService.getMaxHp())
	T.ok("boot.coreTidakHancur", not CoreService.isDestroyed())
	T.eq("boot.tidakAdaMusuh", EnemyService.activeCount(), 0)
	T.eq("boot.jumlahLane", EnemyService.laneCount(), 3)

	-- Arena benar-benar ada sebagai Instance, bukan cuma angka di log.
	local arena = MapService.getArena()
	T.ok("boot.arena.bukanNil", arena ~= nil)
	if arena ~= nil then
		T.ok("boot.arena.corePart", arena.corePart ~= nil and arena.corePart:IsA("BasePart"))
		T.eq("boot.arena.laneDiArena", #arena.lanes, 3)
		T.ok(
			"boot.arena.corePositionWajar",
			arena.corePosition.Magnitude == arena.corePosition.Magnitude,
			tostring(arena.corePosition)
		)
	end

	-- Separuh LB-00 yang bisa dibuktikan tanpa Player: remote-nya BENAR-BENAR
	-- ada di engine, dan dia RemoteFunction. Separuh sisanya -- bahwa
	-- InvokeServer menjawab tanpa menggantung -- butuh client, jadi tetap
	-- manual.
	--
	-- Perhatikan apa yang TIDAK dibuktikan dua baris ini: `Remotes.luau`
	-- membuat Instance-nya di lingkup modul, jadi remote ini akan ada begitu
	-- ada satu script saja yang me-require Remotes -- bahkan kalau
	-- LeaderboardService tidak pernah jalan. Keberadaannya karena itu bukan
	-- bukti bahwa `OnServerInvoke` terpasang, dan remote yang ada tanpa handler
	-- justru bentuk paling buruk: client yang memanggilnya menggantung
	-- selamanya, tanpa error.
	--
	-- Yang membuktikan handler-nya terpasang adalah baris log
	-- `[LeaderboardService] siap` di EXPECTED_LINES, karena start() yang
	-- mencetaknya juga yang memasang handler-nya. Dua assertion ini dan baris
	-- log itu harus dibaca bersama.
	local getLeaderboard = game.ReplicatedStorage.Remotes:FindFirstChild("GetLeaderboard")
	T.ok("boot.remote.getLeaderboardAda", getLeaderboard ~= nil)
	T.ok(
		"boot.remote.getLeaderboardRemoteFunction",
		getLeaderboard ~= nil and getLeaderboard:IsA("RemoteFunction")
	)

	-- Tanpa OrderedDataStore, papan harus kosong dan DIAM: tabel kosong, bukan
	-- nil dan bukan error. Inilah jalur yang dilewati tiap orang yang baru
	-- clone repo ini, jadi dia yang paling sering dijalankan dan paling jarang
	-- diperiksa.
	local board = LeaderboardService.getBoard("normal")
	T.ok("boot.papan.bukanNil", type(board) == "table")
	T.eq("boot.papan.kosongTanpaDataStore", #board, 0)
	T.eq("boot.papan.tingkatTakDikenalKosong", #LeaderboardService.getBoard("tidakAda"), 0)

	-- Musuh belum boleh bergerak di Lobby: init.server.luau memanggil
	-- setRunning(false) tepat setelah start(), dan ini memastikan itu memang
	-- yang terjadi di engine.
	T.ok("boot.musuhTidakBergerakDiLobby", not EnemyService.isRunning())
end)
