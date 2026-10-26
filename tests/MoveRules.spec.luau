-- MoveRules.spec.luau — aturan sikap badan, stamina, dan dash (Soal 4).
--
-- Modul ini di-require DUA SISI: `MovementService` memakainya untuk
-- menegakkan aturan, `StanceController` memakainya untuk menggambar bar
-- stamina. Itu yang membuat test di sini berbeda nilainya dari test modul
-- lain: selisih sekecil apa pun di sini tidak muncul sebagai error, dia
-- muncul sebagai bar di layar yang berbohong tentang apa yang sebenarnya
-- diizinkan server, dan pemain tidak punya cara menyadarinya.
--
-- Yang SENGAJA tidak dites di sini: dorongan dash dan penulisan WalkSpeed.
-- Keduanya menyentuh Humanoid dan BasePart, jadi tempatnya harness Studio,
-- bukan Lune. Yang bisa dites di sini cuma keputusannya, dan keputusan itulah
-- yang dipegang kedua sisi.

local MoveRules = require("../src/shared/Modules/MoveRules")

local cases = {}

-- --------------------------------------------------------------------------
-- Angka yang di-ship
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "validate() lolos dengan angka yang di-ship",
	run = function()
		local ok, err = MoveRules.validate()
		assert(ok, tostring(err))
	end,
})

table.insert(cases, {
	name = "tiap sikap punya kecepatan DAN tinggi lompat",
	run = function()
		-- Sikap yang punya kecepatan tapi tidak punya tinggi lompat tidak
		-- error: `jumpHeightFor` diam-diam mengembalikan tinggi `walk`, dan
		-- pemain melompat setinggi berjalan sambil jongkok.
		for name in MoveRules.SPEEDS do
			assert(
				MoveRules.JUMP_HEIGHTS[name] ~= nil,
				string.format("sikap %s tidak punya tinggi lompat", name)
			)
		end
	end,
})

table.insert(cases, {
	name = "jongkok lebih lambat daripada jalan, sprint lebih cepat",
	run = function()
		assert(MoveRules.SPEEDS.crouch < MoveRules.SPEEDS.walk, "jongkok harus lebih lambat")
		assert(MoveRules.SPEEDS.sprint > MoveRules.SPEEDS.walk, "sprint harus lebih cepat")
	end,
})

table.insert(cases, {
	name = "jongkok tidak bisa melompat sama sekali, bukan melompat kecil",
	run = function()
		-- Nol, bukan angka kecil. Lompatan kecil terbaca sebagai lompatan yang
		-- GAGAL, dan pemain akan terus mencobanya sambil mengira ada bug.
		assert(
			MoveRules.jumpHeightFor("crouch") == 0,
			string.format("tinggi lompat jongkok %f", MoveRules.jumpHeightFor("crouch"))
		)
	end,
})

table.insert(cases, {
	name = "jongkok memulihkan stamina lebih cepat daripada berjalan",
	run = function()
		-- Kalau tidak, tidak ada satu pun alasan untuk menekan tombol jongkok,
		-- dan sikap yang diminta Soal 4 jadi tombol yang cuma memperlambat.
		local crouched = MoveRules.stepStamina(0, "crouch", false, 1)
		local walked = MoveRules.stepStamina(0, "walk", false, 1)
		assert(crouched > walked, string.format("jongkok %f, jalan %f", crouched, walked))
	end,
})

table.insert(cases, {
	name = "ambang sprint dan biaya dash keduanya bisa dicapai",
	run = function()
		-- Keduanya kesalahan yang sama bentuknya: angka yang sah sendirian
		-- tapi menjadikan satu tombol mustahil ditekan. Gejalanya terbaca
		-- sebagai tombol rusak, bukan sebagai angka salah, jadi yang dicari
		-- orang pertama kali adalah input-nya.
		assert(
			MoveRules.SPRINT_START_STAMINA <= MoveRules.MAX_STAMINA,
			"ambang mulai sprint di atas stamina penuh"
		)
		assert(MoveRules.DASH_COST <= MoveRules.MAX_STAMINA, "dash lebih mahal dari stamina penuh")
	end,
})

-- --------------------------------------------------------------------------
-- isStance: gerbang untuk data yang datang dari client
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "isStance menerima ketiga nama sikap",
	run = function()
		assert(MoveRules.isStance("walk"), "walk harus diterima")
		assert(MoveRules.isStance("sprint"), "sprint harus diterima")
		assert(MoveRules.isStance("crouch"), "crouch harus diterima")
	end,
})

table.insert(cases, {
	name = "isStance menolak yang bukan string tanpa error",
	run = function()
		-- `MovementService` meneruskan muatan remote apa adanya ke sini, dan
		-- muatan remote bisa berisi apa saja. Yang dituntut bukan cuma
		-- "menolak", melainkan menolak TANPA error: error di handler remote
		-- menjatuhkan satu frame gerak untuk semua pemain, bukan cuma untuk
		-- client yang nakal.
		assert(not MoveRules.isStance(nil), "nil harus ditolak")
		assert(not MoveRules.isStance(7), "angka harus ditolak")
		assert(not MoveRules.isStance(true), "boolean harus ditolak")
		assert(not MoveRules.isStance({}), "tabel harus ditolak")
	end,
})

table.insert(cases, {
	name = "isStance menolak nama yang hampir benar",
	run = function()
		-- "run" sengaja ikut disebut: `Poses.STATES` memang punya "run", dan
		-- dua kosakata yang mirip tapi tidak sama adalah tempat orang keliru
		-- mengirim nama yang satu ke tempat yang satunya.
		assert(not MoveRules.isStance("sprintt"), "salah ketik harus ditolak")
		assert(not MoveRules.isStance("Sprint"), "beda huruf besar harus ditolak")
		assert(not MoveRules.isStance("run"), "nama state animasi bukan nama sikap")
	end,
})

table.insert(cases, {
	name = "nama sikap 'crouch' dipatok, karena file lain menulisnya literal",
	run = function()
		-- `CharacterAnimatorController` membandingkan atribut `Stance` dengan
		-- string "crouch" langsung, bukan lewat konstanta. Mengganti nama
		-- sikap ini di modul ini TIDAK akan menghasilkan error di mana pun:
		-- pose jongkoknya cuma berhenti muncul, dan karakternya tetap berjalan
		-- pelan seperti biasa. Test ini yang menghentikannya di sini.
		assert(MoveRules.SPEEDS.crouch ~= nil, "nama sikap 'crouch' tidak boleh diganti")
	end,
})

-- --------------------------------------------------------------------------
-- resolveStance: histeresis sprint
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "resolveStance menjatuhkan nama tak dikenal ke walk",
	run = function()
		assert(MoveRules.resolveStance("terbang", 100, false) == "walk", "tak dikenal -> walk")
	end,
})

table.insert(cases, {
	name = "sprint ditolak saat stamina nol, walau sedang sprint",
	run = function()
		assert(MoveRules.resolveStance("sprint", 0, true) == "walk", "stamina nol harus memutus")
		assert(MoveRules.resolveStance("sprint", 0, false) == "walk", "stamina nol harus memutus")
	end,
})

table.insert(cases, {
	name = "MEMULAI sprint butuh ambang, MELANJUTKAN tidak",
	run = function()
		-- Ini inti histeresisnya, dan satu-satunya test di berkas ini yang
		-- kalau dihapus gejalanya langsung terlihat di layar: kalau kedua
		-- ambangnya sama, pemain yang staminanya menipis berganti sprint/walk
		-- puluhan kali per detik — satu frame regen menaikkannya melewati
		-- ambang, satu frame drain menjatuhkannya lagi. Yang terlihat bukan
		-- "sprint mati", melainkan kecepatan DAN animasi yang berkedip.
		local justBelow = MoveRules.SPRINT_START_STAMINA - 1

		assert(
			MoveRules.resolveStance("sprint", justBelow, false) == "walk",
			"di bawah ambang, sprint tidak boleh MULAI"
		)
		assert(
			MoveRules.resolveStance("sprint", justBelow, true) == "sprint",
			"di bawah ambang, sprint yang sudah jalan harus LANJUT"
		)
	end,
})

table.insert(cases, {
	name = "tepat di ambang, sprint boleh mulai",
	run = function()
		-- Perbandingannya `<`, bukan `<=`. Dipatok supaya tidak diam-diam
		-- berubah jadi `<=` saat seseorang merapikan: pergeseran satu satuan
		-- di sini tidak terlihat sama sekali di playtest.
		assert(
			MoveRules.resolveStance("sprint", MoveRules.SPRINT_START_STAMINA, false) == "sprint",
			"tepat di ambang harus boleh mulai"
		)
	end,
})

table.insert(cases, {
	name = "jongkok dan jalan tidak pernah ditahan stamina",
	run = function()
		-- Jongkok adalah cara memulihkan tenaga. Kalau dia ikut menuntut
		-- stamina, pemain yang kehabisan tenaga tidak punya jalan keluar.
		assert(MoveRules.resolveStance("crouch", 0, false) == "crouch", "jongkok selalu boleh")
		assert(MoveRules.resolveStance("walk", 0, false) == "walk", "jalan selalu boleh")
	end,
})

table.insert(cases, {
	name = "apa pun yang dikembalikan resolveStance punya kecepatan dan tinggi lompat",
	run = function()
		-- `MovementService` menulis hasil fungsi ini apa adanya ke atribut
		-- `Stance`, dan dari situ dia dibaca animator di setiap client. Satu
		-- nilai balik yang tidak ada di SPEEDS berarti pemain yang diam-diam
		-- berjalan dengan kecepatan `walk` padahal atributnya bukan `walk`.
		local requests = { "walk", "sprint", "crouch", "terbang", "", "run" }
		local staminas = { 0, 1, MoveRules.SPRINT_START_STAMINA, MoveRules.MAX_STAMINA }
		for _, requested in requests do
			for _, stamina in staminas do
				for _, sprinting in { true, false } do
					local resolved = MoveRules.resolveStance(requested, stamina, sprinting)
					assert(
						MoveRules.SPEEDS[resolved] ~= nil,
						string.format("resolveStance mengembalikan %q", resolved)
					)
					assert(
						MoveRules.JUMP_HEIGHTS[resolved] ~= nil,
						string.format("sikap balik %q tidak punya tinggi lompat", resolved)
					)
				end
			end
		end
	end,
})

-- --------------------------------------------------------------------------
-- stepStamina
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "sprint sambil bergerak menguras",
	run = function()
		local after = MoveRules.stepStamina(100, "sprint", true, 1)
		assert(
			math.abs(after - (100 - MoveRules.SPRINT_DRAIN)) < 1e-6,
			string.format("stamina jadi %f", after)
		)
	end,
})

table.insert(cases, {
	name = "sprint DI TEMPAT tidak menguras, dia memulihkan seperti berjalan",
	run = function()
		-- Pemain yang lupa melepas Shift sambil berdiri diam tidak boleh
		-- kehilangan tenaga: dia tidak punya cara menyadari sebabnya.
		local after = MoveRules.stepStamina(50, "sprint", false, 1)
		assert(
			math.abs(after - (50 + MoveRules.WALK_REGEN)) < 1e-6,
			string.format("sprint di tempat jadi %f, harusnya pulih seperti jalan", after)
		)
	end,
})

table.insert(cases, {
	name = "jongkok memulihkan walau sedang bergerak",
	run = function()
		-- `moving` hanya dipakai sprint. Jongkok sambil mundur dari kepungan
		-- adalah justru cara yang dimaksud untuk memulihkan tenaga.
		local after = MoveRules.stepStamina(0, "crouch", true, 1)
		assert(
			math.abs(after - MoveRules.CROUCH_REGEN) < 1e-6,
			string.format("jongkok bergerak jadi %f", after)
		)
	end,
})

table.insert(cases, {
	name = "stamina tidak pernah melewati batas, di kedua ujung",
	run = function()
		-- dt besar bukan karangan: satu frame yang tersendat (server lag
		-- spike, Studio yang baru selesai compile) benar-benar mengirim dt
		-- sebesar ini, dan tanpa clamp bar stamina jadi negatif atau melebihi
		-- lebar panelnya.
		assert(MoveRules.stepStamina(100, "walk", false, 10) == MoveRules.MAX_STAMINA, "atas")
		assert(MoveRules.stepStamina(1, "sprint", true, 10) == 0, "bawah")
	end,
})

table.insert(cases, {
	name = "dt nol tidak mengubah apa pun",
	run = function()
		-- Heartbeat bisa mengirim dt nol pada frame pertama.
		for _, stance in { "walk", "sprint", "crouch" } do
			assert(
				MoveRules.stepStamina(42, stance, true, 0) == 42,
				string.format("sikap %s mengubah stamina pada dt nol", stance)
			)
		end
	end,
})

table.insert(cases, {
	name = "sprint penuh bertahan cukup lama untuk menyeberangi arena",
	run = function()
		-- Diuji sebagai LANGKAH, bukan sebagai pembagian, supaya yang
		-- dibuktikan jalur yang benar-benar dipakai server tiap frame.
		local stamina = MoveRules.MAX_STAMINA
		local elapsed = 0
		local dt = 1 / 60
		while stamina > 0 and elapsed < 30 do
			stamina = MoveRules.stepStamina(stamina, "sprint", true, dt)
			elapsed += dt
		end
		assert(elapsed >= 4, string.format("sprint cuma bertahan %.1f detik", elapsed))
	end,
})

-- --------------------------------------------------------------------------
-- canDash
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "dash menuntut DUA syarat, dan masing-masing cukup untuk menolak",
	run = function()
		local cost = MoveRules.DASH_COST
		local cooldown = MoveRules.DASH_COOLDOWN

		-- Tenaga cukup, cooldown belum lewat.
		assert(not MoveRules.canDash(100, 10, 10 - cooldown * 0.5), "cooldown harus menolak")
		-- Cooldown sudah lewat, tenaga kurang.
		assert(not MoveRules.canDash(cost - 1, 10, 0), "tenaga kurang harus menolak")
		-- Keduanya terpenuhi.
		assert(MoveRules.canDash(cost, 10, 0), "keduanya terpenuhi harus lolos")
	end,
})

table.insert(cases, {
	name = "dash pertama dalam satu nyawa tidak tertahan cooldown",
	run = function()
		-- `MovementService` memulai `lastDashAt` di -math.huge supaya pemain
		-- yang baru spawn tidak perlu menunggu. Nol tidak akan cukup: `now`
		-- adalah os.clock(), dan nilainya tidak dijamin besar.
		assert(MoveRules.canDash(100, 0, -math.huge), "dash pertama harus boleh")
	end,
})

table.insert(cases, {
	name = "tepat di batas cooldown sudah boleh",
	run = function()
		assert(MoveRules.canDash(100, MoveRules.DASH_COOLDOWN, 0), "tepat di batas harus boleh")
	end,
})

table.insert(cases, {
	name = "dash kedua beruntun selalu tertahan oleh salah satu syarat",
	run = function()
		-- Dua dash beruntun adalah cara paling murah keluar dari arena. Yang
		-- dipatok di sini bukan syarat yang mana yang menahannya, melainkan
		-- bahwa SELALU ADA yang menahan: biaya, cooldown, atau keduanya.
		local afterOne = MoveRules.MAX_STAMINA - MoveRules.DASH_COST
		assert(
			not MoveRules.canDash(afterOne, 0, 0),
			"dash kedua pada saat yang sama harus tertahan"
		)
	end,
})

return cases
