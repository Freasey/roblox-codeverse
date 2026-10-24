-- EnemyAI.spec.luau — tabel transisi state musuh, target, dan slot base.
--
-- Yang dites di sini bukan angka balancing-nya (itu akan disetel setelah
-- playtest), tapi sifat yang harus tetap benar apa pun angkanya. Dua di
-- antaranya adalah alasan fungsinya ditulis sama sekali, dan dua-duanya
-- menghasilkan match yang tidak bisa selesai kalau pecah:
--
--   1. `attacking_base` tidak punya jalan keluar. Kalau pemain bisa menarik
--      musuh keluar dari base dengan mendekat, dia bisa menunda kerusakan tanpa
--      membunuh apa pun.
--   2. Musuh tidak pernah kembali ke waypoint di belakangnya. Kalau boleh,
--      pemain bisa memancing satu musuh maju-mundur selamanya, dan karena wave
--      baru selesai saat arena bersih, match-nya tidak akan pernah berakhir.

local Balance = require("../src/shared/Modules/Balance")
local Bosses = require("../src/shared/Modules/Bosses")
local Enemies = require("../src/shared/Modules/Enemies")
local EnemyAI = require("../src/shared/Modules/EnemyAI")
local HitTest = require("../src/shared/Modules/HitTest")

local cases = {}

local origin = HitTest.vec(0, 0, 0)

local chaser = { prefer = "player" :: "player", aggroRadius = 25, leashRadius = 37.5 }
local marcher = { prefer = "base" :: "base", aggroRadius = 14, leashRadius = 21 }

local function candidate(x: number, z: number, alive: boolean?): EnemyAI.Candidate
	return {
		userId = 1,
		position = HitTest.vec(x, 0, z),
		alive = if alive == nil then true else alive,
	}
end

-- --------------------------------------------------------------------------
-- Damage
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "damage ke base dan ke player dihitung dari satu angka serangan",
	run = function()
		assert(EnemyAI.baseDamage(25, 0.2) == 5, "25 x 0.2 harus 5")
		assert(EnemyAI.playerDamage(25, 1.0) == 25, "25 x 1.0 harus 25")
	end,
})

table.insert(cases, {
	name = "angka serangan tidak wajar menghasilkan nol, bukan NaN atau inf",
	run = function()
		local bad = { 0, -5, 0 / 0, math.huge }
		for _, value in bad do
			assert(
				EnemyAI.baseDamage(value, 0.2) == 0,
				string.format("attackDamage %s harus jadi 0", tostring(value))
			)
			assert(
				EnemyAI.playerDamage(25, value) == 0,
				string.format("pengali %s harus jadi 0", tostring(value))
			)
		end
	end,
})

-- --------------------------------------------------------------------------
-- Memilih target
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "target yang dipilih adalah yang terdekat di dalam aggro",
	run = function()
		local picked = EnemyAI.pickTarget(marcher, origin, {
			candidate(10, 0),
			candidate(3, 0),
			candidate(7, 0),
		})
		assert(picked ~= nil, "harus ada yang terpilih")
		assert((picked :: EnemyAI.Candidate).position.x == 3, "yang terdekat harus menang")
	end,
})

table.insert(cases, {
	name = "player mati dan player di luar aggro tidak pernah jadi target",
	run = function()
		assert(
			EnemyAI.pickTarget(marcher, origin, { candidate(3, 0, false) }) == nil,
			"yang mati harus dilewati"
		)
		assert(
			EnemyAI.pickTarget(marcher, origin, { candidate(100, 0) }) == nil,
			"di luar aggro harus nil"
		)
	end,
})

table.insert(cases, {
	name = "ketinggian tidak mempengaruhi aggro",
	run = function()
		-- Jaraknya horizontal: pemain yang melompat ke atas kotak tidak boleh
		-- membuat musuh berhenti peduli.
		local high: EnemyAI.Candidate =
			{ userId = 1, position = HitTest.vec(3, 50, 0), alive = true }
		assert(EnemyAI.pickTarget(marcher, origin, { high }) ~= nil, "beda tinggi tetap kena aggro")
	end,
})

-- --------------------------------------------------------------------------
-- Leash
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "target dianggap lepas kalau nil, mati, atau di luar leash",
	run = function()
		assert(EnemyAI.lostTarget(chaser, origin, nil), "nil harus lepas")
		assert(EnemyAI.lostTarget(chaser, origin, candidate(3, 0, false)), "mati harus lepas")
		assert(EnemyAI.lostTarget(chaser, origin, candidate(100, 0)), "di luar leash harus lepas")
		assert(
			not EnemyAI.lostTarget(chaser, origin, candidate(30, 0)),
			"di dalam leash belum lepas"
		)
	end,
})

table.insert(cases, {
	name = "leash setiap musuh yang ada lebih besar dari aggro-nya",
	run = function()
		-- Kalau sama, musuh bergetar antara chasing dan walking tepat di batas
		-- radius. Di harness Studio yang jalan ~8 Hz itu terlihat seperti musuh
		-- kejang, dan penyebabnya sangat tidak jelas dari gejalanya.
		for id, def in Enemies do
			assert(
				def.targeting.leashRadius > def.targeting.aggroRadius,
				string.format("musuh '%s' leash harus > aggro", id)
			)
		end
		for id, def in Bosses do
			assert(
				def.targeting.leashRadius > def.targeting.aggroRadius,
				string.format("boss '%s' leash harus > aggro", id)
			)
		end
	end,
})

table.insert(cases, {
	name = "setiap musuh yang ada punya angka serangan dan interval yang wajar",
	run = function()
		for id, def in Enemies do
			assert(def.attackDamage > 0, string.format("musuh '%s' attackDamage harus > 0", id))
			assert(def.attackInterval > 0, string.format("musuh '%s' attackInterval harus > 0", id))
		end
		for id, def in Bosses do
			assert(def.attackDamage > 0, string.format("boss '%s' attackDamage harus > 0", id))
			assert(def.attackInterval > 0, string.format("boss '%s' attackInterval harus > 0", id))
		end
	end,
})

-- --------------------------------------------------------------------------
-- Tabel transisi
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "ujung lane membawa musuh ke attacking_base",
	run = function()
		assert(
			EnemyAI.nextState(marcher, "walking", origin, nil, true) == "attacking_base",
			"sampai ujung lane harus menyerang base"
		)
	end,
})

table.insert(cases, {
	name = "attacking_base tidak punya jalan keluar, bahkan dengan player menempel",
	run = function()
		-- Ini yang menjaga wave tetap bisa selesai: kalau pemain bisa menarik
		-- musuh keluar dari base, dia bisa menunda kerusakan tanpa membunuh.
		local states = {
			EnemyAI.nextState(marcher, "attacking_base", origin, candidate(1, 0), false),
			EnemyAI.nextState(chaser, "attacking_base", origin, candidate(1, 0), false),
			EnemyAI.nextState(chaser, "attacking_base", origin, nil, false),
		}
		for _, state in states do
			assert(state == "attacking_base", "attacking_base harus menyerap")
		end
	end,
})

table.insert(cases, {
	name = "hanya musuh prefer player yang meninggalkan lane untuk mengejar",
	run = function()
		-- Target di dalam aggro tapi di luar jarak pukul.
		local far = candidate(20, 0)
		assert(
			EnemyAI.nextState(chaser, "walking", origin, far, false) == "chasing",
			"pengejar harus mengejar"
		)
		-- Profil yang sama jaraknya, tapi prefer base: tetap berjalan ke base.
		local wideMarcher = { prefer = "base" :: "base", aggroRadius = 25, leashRadius = 37.5 }
		assert(
			EnemyAI.nextState(wideMarcher, "walking", origin, far, false) == "walking",
			"prefer base tidak boleh keluar lane"
		)
	end,
})

table.insert(cases, {
	name = "musuh prefer base tetap memukul player yang sudah menempel",
	run = function()
		-- "Memukul kalau dihalangi": dia tidak mengejar, tapi juga tidak
		-- mengabaikan pemain yang berdiri di depannya.
		assert(
			EnemyAI.nextState(marcher, "walking", origin, candidate(2, 0), false)
				== "attacking_player",
			"di jarak pukul harus menyerang player"
		)
	end,
})

table.insert(cases, {
	name = "target lepas membawa musuh kembali berjalan",
	run = function()
		local fromChase = EnemyAI.nextState(chaser, "chasing", origin, candidate(100, 0), false)
		local fromAttack =
			EnemyAI.nextState(chaser, "attacking_player", origin, candidate(3, 0, false), false)
		assert(fromChase == "walking", "lepas leash harus kembali walking")
		assert(fromAttack == "walking", "target mati harus kembali walking")
	end,
})

-- --------------------------------------------------------------------------
-- Jadwal pukulan
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "interval yang tidak wajar tidak menghasilkan jadwal NaN",
	run = function()
		-- NaN >= apa pun selalu false, jadi satu jadwal NaN membuat musuhnya
		-- berhenti memukul selamanya tanpa pesan apa pun.
		for _, bad in { 0, -1, 0 / 0, math.huge } do
			local at = EnemyAI.scheduleNextStrike(100, bad)
			assert(at == at, "jadwal tidak boleh NaN")
			assert(EnemyAI.readyToStrike(100, at), "jadwal rusak harus langsung siap, bukan macet")
		end
	end,
})

table.insert(cases, {
	name = "jadwal normal maju sebesar intervalnya",
	run = function()
		assert(EnemyAI.scheduleNextStrike(100, 1.2) == 101.2, "100 + 1.2")
		assert(not EnemyAI.readyToStrike(100, 101.2), "belum waktunya")
		assert(EnemyAI.readyToStrike(101.2, 101.2), "tepat waktunya sudah boleh")
	end,
})

-- --------------------------------------------------------------------------
-- Slot cincin di base
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "tidak ada dua slot cincin yang pernah berbagi tempat",
	run = function()
		-- Diuji lintas TIGA cincin, bukan satu. Versi pertama test ini cuma
		-- berjalan 0..11 dan membandingkan slot 12 dengan slot 0, jadi dia lulus
		-- sambil tidak pernah menyentuh properti yang justru rusak: slot 24
		-- berdiri tepat di posisi slot 12, karena setiap cincin > 0 memakai
		-- radius dan pergeseran sudut yang sama.
		local slots = Balance.BASE_RING_SLOTS
		local seen: { [string]: number } = {}
		for slot = 0, slots * 3 - 1 do
			local offset = EnemyAI.ringSlotOffset(
				slot,
				slots,
				Balance.BASE_RING_RADIUS,
				Balance.BASE_RING_RADIUS_OUTER
			)
			local key = string.format("%.3f,%.3f", offset.x, offset.z)
			local clash = seen[key]
			assert(
				clash == nil,
				string.format("slot %d berdiri tepat di posisi slot %d", slot, clash or -1)
			)
			seen[key] = slot
		end
	end,
})

table.insert(cases, {
	name = "cincin pertama persis di radius dalam, dan tiap cincin punya radiusnya sendiri",
	run = function()
		local slots = Balance.BASE_RING_SLOTS
		local inner = Balance.BASE_RING_RADIUS
		local outer = Balance.BASE_RING_RADIUS_OUTER
		local function radiusOf(slot: number): number
			local offset = EnemyAI.ringSlotOffset(slot, slots, inner, outer)
			return HitTest.horizontalDistance(origin, offset)
		end
		for slot = 0, slots - 1 do
			assert(math.abs(radiusOf(slot) - inner) < 0.001, "cincin pertama di radius dalam")
		end
		-- Radius naik sebesar selisihnya untuk tiap cincin sesudahnya, jadi
		-- jumlah cincin tidak terbatas tanpa pernah bertumpuk.
		local step = outer - inner
		for ring = 1, 3 do
			local expected = inner + step * ring
			assert(
				math.abs(radiusOf(slots * ring) - expected) < 0.001,
				string.format("cincin ke-%d harus di radius %.1f", ring + 1, expected)
			)
		end
	end,
})

table.insert(cases, {
	name = "slot cincin tidak pecah untuk masukan aneh",
	run = function()
		local zero = EnemyAI.ringSlotOffset(5, 0, 10, 14)
		assert(zero.x == 0 and zero.z == 0, "slots 0 harus mengembalikan offset nol")
		local negative = EnemyAI.ringSlotOffset(-3, 12, 10, 14)
		assert(negative.x == negative.x, "slot negatif tidak boleh NaN")
	end,
})

-- --------------------------------------------------------------------------
-- Kembali ke lane
-- --------------------------------------------------------------------------

table.insert(cases, {
	name = "musuh tidak pernah kembali ke waypoint di belakangnya",
	run = function()
		-- Inti anti-kiting. Musuh dipancing mundur sampai dekat waypoint 1,
		-- tapi waypointIndex-nya sudah 5: hasilnya harus >= 5, walaupun
		-- waypoint 1 yang paling dekat secara jarak.
		local waypoints = {
			HitTest.vec(0, 0, 0),
			HitTest.vec(0, 0, 20),
			HitTest.vec(0, 0, 40),
			HitTest.vec(0, 0, 60),
			HitTest.vec(0, 0, 80),
			HitTest.vec(0, 0, 100),
			HitTest.vec(0, 0, 120),
		}
		local lured = HitTest.vec(0, 0, 1)
		local index = EnemyAI.rejoinWaypointIndex(lured, waypoints, 5)
		assert(index >= 5, string.format("harus >= 5, dapat %d", index))
		assert(index == 5, string.format("yang terdekat di depan adalah 5, dapat %d", index))
	end,
})

table.insert(cases, {
	name = "di antara waypoint yang ada di depan, yang terdekat yang dipilih",
	run = function()
		local waypoints = {
			HitTest.vec(0, 0, 0),
			HitTest.vec(0, 0, 20),
			HitTest.vec(0, 0, 40),
			HitTest.vec(0, 0, 60),
		}
		-- Berdiri di dekat waypoint 3, batas minimum 2.
		local index = EnemyAI.rejoinWaypointIndex(HitTest.vec(0, 0, 38), waypoints, 2)
		assert(index == 3, string.format("harus 3, dapat %d", index))
	end,
})

table.insert(cases, {
	name = "minIndex melewati waypoint terakhir berarti musuh sudah di base",
	run = function()
		local waypoints = { HitTest.vec(0, 0, 0), HitTest.vec(0, 0, 20) }
		local index = EnemyAI.rejoinWaypointIndex(origin, waypoints, 3)
		assert(index == #waypoints + 1, "di luar lane harus tetap di luar lane")
		assert(EnemyAI.rejoinWaypointIndex(origin, {}, 4) == 4, "lane kosong harus aman")
	end,
})

return cases
