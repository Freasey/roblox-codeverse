--!strict
-- EnemyAI.luau — keputusan state dan target musuh, sebagai fungsi murni.
--
-- Kenapa modul terpisah, bukan di dalam EnemyService: EnemyService menyentuh
-- Instance, Signal, dan CoreService, jadi dia tidak bisa dites Lune sama
-- sekali. Yang di sini cuma aritmetika dan percabangan — tidak ada
-- game:GetService, tidak ada Vector3, tidak ada `script` — jadi seluruh tabel
-- keputusannya bisa diuji di CI tanpa membuka Studio. EnemyService tinggal
-- memanggil dan menerjemahkan hasilnya ke CFrame dan TakeDamage.
--
-- Vec3 dipinjam dari HitTest supaya dua modul tidak punya tipe vektor sendiri
-- yang mirip tapi beda.

local HitTest = require("./HitTest")
local Types = require("./Types")

local EnemyAI = {}

export type Vec3 = HitTest.Vec3

-- Empat state, dan transisinya sengaja tidak membentuk siklus yang bisa
-- berputar tanpa maju:
--
--   walking          -> attacking_base    (sampai di ujung lane)
--   walking          -> chasing           (player masuk aggro, prefer player)
--   walking          -> attacking_player  (player masuk aggro, prefer base)
--   chasing          -> attacking_player  (sudah cukup dekat)
--   chasing          -> walking           (target mati atau lepas leash)
--   attacking_player -> walking           (target mati atau menjauh)
--   attacking_base   -> (tetap)           satu-satunya yang mengakhirinya: mati
export type State = "walking" | "attacking_base" | "chasing" | "attacking_player"

export type Candidate = {
	userId: number,
	position: Vec3,
	alive: boolean,
}

-- Jarak sentuh untuk memukul. Dipisahkan dari aggro: aggro menentukan kapan
-- musuh MULAI peduli, ini menentukan kapan dia sudah cukup dekat untuk
-- memukul. Kalau keduanya satu angka, musuh prefer="player" akan memukul dari
-- ujung radius aggro-nya, dan `fast` dengan aggro 25 stud akan menyerang dari
-- jarak yang terlihat seperti bug.
EnemyAI.STRIKE_RANGE = 6

local function isFinitePositive(value: number): boolean
	-- value == value menyaring NaN; NaN lolos dari perbandingan apa pun.
	return value == value and value > 0 and value ~= math.huge
end

-- Damage ke base dan ke player dipisah jadi dua fungsi, bukan satu fungsi
-- dengan flag, supaya pemanggil tidak pernah bisa lupa mengalikan — tidak ada
-- jalan memanggilnya tanpa memilih sasaran.
function EnemyAI.baseDamage(attackDamage: number, baseMult: number): number
	if not isFinitePositive(attackDamage) or not isFinitePositive(baseMult) then
		return 0
	end
	return attackDamage * baseMult
end

function EnemyAI.playerDamage(attackDamage: number, playerMult: number): number
	if not isFinitePositive(attackDamage) or not isFinitePositive(playerMult) then
		return 0
	end
	return attackDamage * playerMult
end

-- Player terdekat yang masih hidup DAN di dalam aggro, atau nil.
--
-- Jaraknya horizontal, mengikuti HitTest: musuh berjalan di tanah dan player
-- bisa melompat, dan musuh yang berhenti mengejar karena pemain melompat ke
-- atas kotak akan terlihat rusak.
function EnemyAI.pickTarget(
	profile: Types.TargetProfile,
	enemyPosition: Vec3,
	candidates: { Candidate }
): Candidate?
	local best: Candidate? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		if not candidate.alive then
			continue
		end
		local distance = HitTest.horizontalDistance(enemyPosition, candidate.position)
		-- `<` bukan `<=`: dengan dua kandidat berjarak sama persis, yang pertama
		-- di daftar yang dipilih, jadi hasilnya tidak bergantung pada urutan
		-- iterasi tabel.
		if distance <= profile.aggroRadius and distance < bestDistance then
			best = candidate
			bestDistance = distance
		end
	end
	return best
end

-- Target dianggap lepas kalau mati atau sudah di luar leash.
--
-- Leash HARUS lebih besar dari aggro (Types.TargetProfile menyebutnya juga).
-- Kalau sama, musuh akan bergetar antara chasing dan walking tepat di batas
-- radius, dan di 8 Hz itu terlihat seperti musuh yang kejang.
function EnemyAI.lostTarget(
	profile: Types.TargetProfile,
	enemyPosition: Vec3,
	target: Candidate?
): boolean
	if target == nil or not target.alive then
		return true
	end
	return HitTest.horizontalDistance(enemyPosition, target.position) > profile.leashRadius
end

function EnemyAI.inStrikeRange(enemyPosition: Vec3, target: Candidate?): boolean
	if target == nil or not target.alive then
		return false
	end
	return HitTest.horizontalDistance(enemyPosition, target.position) <= EnemyAI.STRIKE_RANGE
end

-- State berikutnya. Satu fungsi, tanpa efek samping, supaya seluruh tabel
-- transisi bisa diuji baris per baris.
--
-- `atLaneEnd` dihitung EnemyService dari waypointIndex, bukan di sini: yang di
-- sini tidak tahu apa pun soal lane.
--
-- Aturan yang membentuk fungsi ini: **cuma prefer="player" yang meninggalkan
-- lane.** Musuh prefer="base" yang punya aggro tetap memukul player yang
-- menghalanginya, tapi dari tempat dia berdiri — dia tidak pernah masuk state
-- `chasing`. Itu yang membuat `tank` dengan aggro 8 "tidak peduli pemain" dan
-- `basic` dengan aggro 14 "memukul kalau dihalangi", dengan satu profil yang
-- sama bentuknya. Dan itu juga yang membatasi masalah pengejaran keluar jalur
-- ke satu tipe saja.
--
-- `attacking_base` tidak punya jalan keluar. Begitu musuh menempel di base dia
-- menempel sampai dibunuh; menariknya kembali dengan mendekat berarti pemain
-- bisa menunda kerusakan tanpa membunuh apa pun, dan wave yang menunggu arena
-- bersih jadi bisa digantung selamanya.
function EnemyAI.nextState(
	profile: Types.TargetProfile,
	current: State,
	enemyPosition: Vec3,
	target: Candidate?,
	atLaneEnd: boolean
): State
	if current == "attacking_base" then
		return "attacking_base"
	end

	-- Ujung lane menang atas apa pun: musuh yang sudah di base tidak boleh
	-- ditarik keluar lagi oleh pemain yang berdiri di dekatnya.
	if atLaneEnd then
		return "attacking_base"
	end

	local lost = EnemyAI.lostTarget(profile, enemyPosition, target)
	if lost then
		return "walking"
	end

	if EnemyAI.inStrikeRange(enemyPosition, target) then
		return "attacking_player"
	end

	-- Di luar jarak pukul tapi masih dalam leash: cuma pengejar yang bergerak
	-- ke arahnya. Yang lain kembali berjalan ke base.
	if profile.prefer == "player" then
		return "chasing"
	end
	return "walking"
end

-- Apakah target sudah masuk aggro. Dipisah dari nextState karena nextState
-- dipanggil dengan target yang SUDAH dipilih pickTarget; pemanggil yang
-- memutuskan apakah mencari target baru tiap frame atau mempertahankan yang
-- lama sampai lepas leash.
function EnemyAI.inAggro(
	profile: Types.TargetProfile,
	enemyPosition: Vec3,
	target: Candidate?
): boolean
	if target == nil or not target.alive then
		return false
	end
	return HitTest.horizontalDistance(enemyPosition, target.position) <= profile.aggroRadius
end

-- Jadwal pukulan. Dipakai dua-duanya untuk base dan player.
function EnemyAI.readyToStrike(now: number, nextStrikeAt: number): boolean
	return now >= nextStrikeAt
end

function EnemyAI.scheduleNextStrike(now: number, interval: number): number
	-- Interval yang tidak wajar tidak boleh menghasilkan jadwal NaN, karena
	-- NaN >= apa pun selalu false dan musuhnya akan berhenti memukul
	-- selamanya tanpa pesan apa pun.
	if not isFinitePositive(interval) then
		return now
	end
	return now + interval
end

-- Posisi slot cincin di sekitar base, sebagai OFFSET dari pusat base.
--
-- Deterministik dari nomor slot: musuh ke-n selalu mendapat tempat yang sama,
-- jadi hasilnya bisa diuji dan tidak bergeser antar run. `outerRadius` adalah
-- radius cincin KEDUA, dan selisihnya dari `radius` jadi kenaikan untuk setiap
-- cincin sesudahnya -- jadi jumlah cincinnya tidak terbatas dan tidak ada dua
-- slot yang pernah berbagi tempat.
function EnemyAI.ringSlotOffset(
	slot: number,
	slots: number,
	radius: number,
	outerRadius: number
): Vec3
	if slots < 1 then
		return HitTest.vec(0, 0, 0)
	end
	local index = math.max(0, math.floor(slot))
	local ring = math.floor(index / slots)
	local positionInRing = index % slots
	local step = (math.pi * 2) / slots
	local angle = positionInRing * step
	-- Radius tumbuh PER RING, bukan "dalam atau luar". Versi pertama fungsi ini
	-- memakai outerRadius untuk setiap ring > 0 dengan pergeseran sudut yang
	-- sama, dan akibatnya slot 24 berdiri tepat di posisi slot 12 -- tumpukan
	-- yang justru jadi alasan seluruh mekanisme slot ini ada. Dengan radius
	-- yang berbeda per ring, dua ring tidak bisa bertabrakan apa pun sudutnya.
	local useRadius = radius + (outerRadius - radius) * ring
	angle += step * 0.5 * ring
	return HitTest.vec(math.cos(angle) * useRadius, 0, math.sin(angle) * useRadius)
end

-- Waypoint untuk kembali setelah pengejaran selesai: yang TERDEKAT di antara
-- waypoint yang indexnya >= minIndex.
--
-- Batas `minIndex` itu seluruh gunanya fungsi ini. Tanpa dia, musuh akan
-- kembali ke waypoint terdekat secara umum — yang bisa berada di BELAKANGNYA
-- kalau pemain memancingnya mundur. Pemain lalu bisa menarik satu musuh
-- maju-mundur tanpa batas, dan karena wave baru selesai saat arena bersih,
-- match-nya tidak akan pernah berakhir.
function EnemyAI.rejoinWaypointIndex(
	enemyPosition: Vec3,
	waypoints: { Vec3 },
	minIndex: number
): number
	local count = #waypoints
	if count == 0 then
		return minIndex
	end
	local start = math.max(1, math.floor(minIndex))
	if start > count then
		return count + 1
	end
	local bestIndex = start
	local bestDistance = math.huge
	for index = start, count do
		local distance = HitTest.horizontalDistance(enemyPosition, waypoints[index])
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end
	return bestIndex
end

return EnemyAI
