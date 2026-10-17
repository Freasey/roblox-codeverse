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
}

local EXPECTED_LINES = {
	"[CodeVerse] server booting",
	"[CodeVerse] relative require OK",
	"[RewardService] siap",
	"[MapService] Arena siap",
	"[MatchService] siap",
	"[BossService] siap",
	"[ProgressionService] siap",
}

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
		"boot.arena.2lane",
		arenaLine ~= nil and string.find(arenaLine, "2 lane", 1, true) ~= nil,
		arenaLine
	)
	T.ok(
		"boot.arena.waypointTerCache",
		arenaLine ~= nil and string.find(arenaLine, "Lane1=7, Lane2=7", 1, true) ~= nil,
		arenaLine
	)

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

	-- State awal yang dihasilkan wiring itu. Dibaca dari service yang sama
	-- dengan yang dipakai init.server.luau — script ini disuntik sebagai Script
	-- server, jadi cache require-nya berbagi (lihat host.luau).
	local Services = game.ServerScriptService.Server.Services
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MapService = require(Services.MapService)
	local MatchService = require(Services.MatchService)

	T.eq("boot.state", MatchService.getState(), "Lobby")
	T.eq("boot.coreHpPenuh", CoreService.getHp(), CoreService.getMaxHp())
	T.ok("boot.coreTidakHancur", not CoreService.isDestroyed())
	T.eq("boot.tidakAdaMusuh", EnemyService.activeCount(), 0)
	T.eq("boot.jumlahLane", EnemyService.laneCount(), 2)

	-- Arena benar-benar ada sebagai Instance, bukan cuma angka di log.
	local arena = MapService.getArena()
	T.ok("boot.arena.bukanNil", arena ~= nil)
	if arena ~= nil then
		T.ok("boot.arena.corePart", arena.corePart ~= nil and arena.corePart:IsA("BasePart"))
		T.eq("boot.arena.laneDiArena", #arena.lanes, 2)
		T.ok(
			"boot.arena.corePositionWajar",
			arena.corePosition.Magnitude == arena.corePosition.Magnitude,
			tostring(arena.corePosition)
		)
	end

	-- Musuh belum boleh bergerak di Lobby: init.server.luau memanggil
	-- setRunning(false) tepat setelah start(), dan ini memastikan itu memang
	-- yang terjadi di engine.
	T.ok("boot.musuhTidakBergerakDiLobby", not EnemyService.isRunning())
end)
