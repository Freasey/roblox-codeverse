--!nocheck
-- remote_reject.luau — PENOLAKAN REMOTE: remote C->S dipanggil dengan argumen
-- sampah, dan yang diperiksa dua hal sekaligus — aksinya tidak terjadi, DAN
-- server tidak error. Yang kedua yang sering terlupakan: server yang error
-- karena argumen sampah tetap masalah walaupun aksinya gagal, karena satu
-- client jahat bisa mematikan handler untuk semua pemain.
--
-- MEKANISMENYA, dan ini temuan spike yang perlu dibaca sebelum mempercayai
-- hasil file ini. `RemoteEvent:FireServer()` normalnya cuma ada di client, tapi
-- kalau dipanggil dari Script SERVER di Studio, dia TETAP menembakkan
-- `OnServerEvent` — dengan `player` = nil di argumen pertama. Jadi jalur
-- validasi argumen bisa dites tanpa client sungguhan.
--
-- BATASNYA, yang membuat file ini tidak bisa menggantikan bagian 10 di
-- docs/TEST_CASES.md. Karena `player` nil, setiap handler yang menyentuh
-- `player` SEBELUM memvalidasi argumen akan error karena nil itu, bukan karena
-- celah validasi. Di kode sekarang, tujuh dari delapan handler C->S diawali
-- `RateLimit.check(limiter, player.UserId, ...)`, jadi tujuh itu tidak bisa
-- diuji dari sini sama sekali. Mereka dilaporkan SKIP, bukan PASS, dan bagian
-- terakhir file ini membuktikan bahwa penyebab SKIP-nya memang nil player
-- (pesan errornya harus menyebut UserId) dan bukan bug.
--
-- `Players:CreateLocalPlayer` tidak bisa menutup celah ini: dia ditolak dengan
-- "lacking capability LocalUser" baik dari konteks plugin maupun dari server.
-- Tanpa Player, tidak ada yang bisa dilakukan dari sisi ini.

-- Argumen sampah untuk RequestAction. Semuanya harus ditolak oleh
-- `type(action) ~= "string"` yang ada di baris pertama handler-nya, SEBELUM
-- `player` tersentuh — itulah yang membuat remote ini satu-satunya yang bisa
-- diuji penuh di sini.
local GARBAGE = {
	{
		label = "nil",
		build = function()
			return nil
		end,
	},
	{
		label = "angkaNegatif",
		build = function()
			return -1
		end,
	},
	{
		label = "nol",
		build = function()
			return 0
		end,
	},
	{
		label = "boolean",
		build = function()
			return true
		end,
	},
	{
		label = "tabel",
		build = function()
			return { evil = true, nested = { 1, 2, 3 } }
		end,
	},
	{
		label = "vector3",
		build = function()
			return Vector3.new(1, 2, 3)
		end,
	},
	{
		label = "instance",
		build = function()
			return workspace
		end,
	},
	{
		label = "nan",
		build = function()
			return 0 / 0
		end,
	},
	{
		label = "stringPanjang64kb",
		build = function()
			return string.rep("A", 65536)
		end,
	},
}

-- Handler yang tidak bisa dijangkau tanpa Player. Nama remote-nya dipakai juga
-- di bagian pembuktian di bawah.
local PLAYER_GATED = {
	{ remote = "Attack", arg = "bukanVector3" },
	{ remote = "SetReady", arg = "bukanBoolean" },
	{ remote = "SelectLoadout", arg = 123 },
	{ remote = "BuyShopItem", arg = 123 },
	{ remote = "UpgradeWeapon", arg = 123 },
	{ remote = "BuyWeapon", arg = 123 },
	{ remote = "CraftWeapon", arg = 123 },
}

local UNKNOWN_ACTIONS = { "", "notARealAction", "claimDailyBonus ", "CLAIMDAILYBONUS" }

T.main(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage.Shared
	local CoreService = require(Services.CoreService)
	local EnemyService = require(Services.EnemyService)
	local MatchService = require(Services.MatchService)
	local Remotes = require(Shared.Remotes)

	T.waitUntil(function()
		return T.logContains("[ProgressionService] siap")
	end, 30)

	-- --------------------------------------------------------------
	-- Bukti bahwa mekanismenya memang bekerja
	-- --------------------------------------------------------------
	-- Tanpa langkah ini, "tidak ada error" di bawah bisa berarti "remote-nya
	-- memang tidak pernah sampai ke handler", yang akan membuat seluruh case
	-- ini hijau tanpa menguji apa pun.
	local probe = Instance.new("RemoteEvent")
	probe.Name = "StudioHarnessProbe"
	probe.Parent = game.ReplicatedStorage
	local deliveries = {}
	probe.OnServerEvent:Connect(function(...)
		table.insert(deliveries, {
			count = select("#", ...),
			first = (select(1, ...)),
			second = (select(2, ...)),
		})
	end)
	probe:FireServer("payload", 42)
	T.ok(
		"mekanisme.fireServerDariServerSampaiKeHandler",
		T.waitUntil(function()
			return #deliveries >= 1
		end, 5),
		#deliveries
	)
	if #deliveries >= 1 then
		T.eq("mekanisme.argumenLengkap", deliveries[1].count, 3)
		T.eq("mekanisme.playerNil", deliveries[1].first, nil)
		T.eq("mekanisme.argumenPertamaUtuh", deliveries[1].second, "payload")
	end
	probe:Destroy()

	-- --------------------------------------------------------------
	-- RequestAction: argumen sampah
	-- --------------------------------------------------------------
	local errorsBefore = #T.gameErrors()
	local stateBefore = MatchService.getState()
	local waveBefore = MatchService.getWave()
	local hpBefore = CoreService.getHp()
	local enemiesBefore = EnemyService.activeCount()

	for _, garbage in GARBAGE do
		local ok, err = pcall(function()
			Remotes.Events.RequestAction:FireServer(garbage.build())
		end)
		T.ok("tolak.fireTidakMeledakDiPemanggil: " .. garbage.label, ok, err)
	end

	-- Argumen bertipe benar tapi aksinya tidak dikenal: harus jadi no-op, bukan
	-- error. Ini jalur yang paling mungkin dipakai penyerang yang sudah tahu
	-- tipenya.
	for _, action in UNKNOWN_ACTIONS do
		local ok = pcall(function()
			Remotes.Events.RequestAction:FireServer(action)
		end)
		T.ok("tolak.aksiTidakDikenal: " .. string.format("%q", action), ok)
	end

	-- Handler jalan asinkron. Beri waktu supaya error (kalau ada) sudah masuk
	-- log sebelum dihitung.
	task.wait(2)

	local errorsAfter = T.gameErrors()
	local newErrors = {}
	for index = errorsBefore + 1, #errorsAfter do
		table.insert(newErrors, errorsAfter[index])
	end
	T.ok("tolak.tidakAdaErrorDiServer", #newErrors == 0, table.concat(newErrors, " || "))

	-- Aksinya tidak terjadi: tidak ada state yang bergerak.
	T.eq("tolak.stateTidakBerubah", MatchService.getState(), stateBefore)
	T.eq("tolak.waveTidakBerubah", MatchService.getWave(), waveBefore)
	T.eq("tolak.coreHpTidakBerubah", CoreService.getHp(), hpBefore)
	T.eq("tolak.jumlahMusuhTidakBerubah", EnemyService.activeCount(), enemiesBefore)
	T.eq("tolak.pesertaMatchTetapKosong", MatchService.getParticipantCount(), 0)
	T.ok("tolak.coreTidakHancur", not CoreService.isDestroyed())

	-- EnemyService.damage dengan id karangan: jalur ini TIDAK lewat remote
	-- (payload EnemyHit cuma S->C), tapi dia pintu masuk yang sama-sama
	-- menerima id dari luar, dan bisa dites penuh dari sini.
	for _, badId in { -1, 0, 999999, 1.5 } do
		T.eq("tolak.damageIdTidakAda: " .. tostring(badId), EnemyService.damage(badId, 10, nil), 0)
	end
	-- Perhatikan `math.huge` di daftar ini. Komentar di CoreService.damage
	-- menyebut dua hal yang dijaga — angka negatif dan NaN — dan memang
	-- keduanya dijaga. Tapi infinity lolos ketiga syaratnya: dia number, dia
	-- sama dengan dirinya sendiri (jadi bukan NaN), dan dia lebih besar dari
	-- nol. Hasilnya `math.max(0, hp - math.huge)` = 0, alias Core langsung
	-- hancur dalam satu panggilan. Assertion di bawah ini SENGAJA dibiarkan
	-- gagal: inilah temuan nyata dari spike ini, dan src/ tidak disentuh di
	-- cabang ini. CombatService sudah memeriksa `magnitude == math.huge` untuk
	-- arah serangan, jadi polanya memang dikenal di repo ini — cuma terlewat di
	-- sini. Lihat tests/studio/README.md.
	for _, badAmount in { -5, 0, 0 / 0, math.huge } do
		T.eq(
			"tolak.coreDamageAngkaTidakWajar: " .. tostring(badAmount),
			CoreService.damage(badAmount),
			0
		)
	end
	T.eq("tolak.coreHpMasihUtuhSetelahDamageSampah", CoreService.getHp(), hpBefore)

	-- Celah yang sama di jalur sebaliknya, diperiksa terpisah supaya laporannya
	-- menyebut keduanya. Urutannya: damage(math.huge) di atas sudah membawa HP
	-- ke 0 dan `destroyed` jadi true, dan heal() menolak Core yang sudah hancur
	-- lebih dulu dari validasi angkanya — jadi reset() dulu, kalau tidak yang
	-- diuji adalah pagar "sudah hancur", bukan pagar angkanya.
	CoreService.reset()
	T.eq("tolak.coreHealAngkaTidakWajar: -5", CoreService.heal(-5), 0)
	T.eq("tolak.coreHealAngkaTidakWajar: nan", CoreService.heal(0 / 0), 0)
	CoreService.damage(100)
	local healedByInfinity = CoreService.heal(math.huge)
	T.eq("tolak.coreHealAngkaTidakWajar: inf", healedByInfinity, 0)
	CoreService.reset()

	-- --------------------------------------------------------------
	-- Tujuh handler yang tidak bisa dijangkau: buktikan alasannya
	-- --------------------------------------------------------------
	-- Dijalankan PALING AKHIR karena memang menimbulkan error di log, dan error
	-- itu akan mengotori hitungan di atas kalau dijalankan lebih dulu.
	local gatedErrorsBefore = #T.gameErrors()
	for _, entry in PLAYER_GATED do
		local remote = Remotes.Events[entry.remote]
		if remote == nil then
			T.fail("batas.remoteTidakDitemukan: " .. entry.remote)
			continue
		end
		pcall(function()
			remote:FireServer(entry.arg)
		end)
	end
	task.wait(2)
	local gatedErrorsAfter = T.gameErrors()
	local gatedErrors = {}
	for index = gatedErrorsBefore + 1, #gatedErrorsAfter do
		table.insert(gatedErrors, gatedErrorsAfter[index])
	end

	-- Yang dibuktikan: error-nya memang soal nil player, bukan validasi yang
	-- bocor. Kalau suatu hari ada handler yang memvalidasi argumen lebih dulu,
	-- jumlah error di sini turun dan baris ini yang memberi tahu.
	local aboutNilPlayer = 0
	for _, message in gatedErrors do
		if
			string.find(message, "UserId", 1, true) ~= nil
			or string.find(message, "index nil", 1, true) ~= nil
		then
			aboutNilPlayer += 1
		end
	end
	T.ok(
		"batas.errorHandlerBerpagarPlayerSemuanyaKarenaNilPlayer",
		#gatedErrors > 0 and aboutNilPlayer == #gatedErrors,
		string.format(
			"%d error, %d menyebut nil player: %s",
			#gatedErrors,
			aboutNilPlayer,
			table.concat(gatedErrors, " || ")
		)
	)
	for _, entry in PLAYER_GATED do
		T.skip(
			"sec.remote: " .. entry.remote,
			"handler menyentuh player.UserId (RateLimit.check) sebelum memvalidasi "
				.. "argumen; harness ini tidak punya Player dan CreateLocalPlayer ditolak "
				.. "(lacking capability LocalUser). Harus dites manual dari command bar client."
		)
	end
	T.skip(
		"sec.remoteFunction: GetProfile",
		"OnServerInvoke memanggil PlayerDataService.waitFor(player); butuh Player sungguhan."
	)
end)
