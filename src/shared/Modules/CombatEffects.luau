--!strict
-- CombatEffects.luau — matematika efek alur upgrade yang punya UMUR.
--
-- Kenapa modul terpisah, bukan di dalam EnemyService atau CombatService:
-- keduanya menyentuh Instance, Humanoid, dan RunService, jadi tidak bisa
-- di-require Lune dan tidak bisa dites di CI. Yang di sini cuma aritmetika,
-- perbandingan waktu, dan pemilihan dari daftar -- dan justru itu bagian yang
-- paling mudah salah: slow yang hilang terlalu cepat, tanda yang ditimpa
-- pukulan lemah, atau splash yang men-damage target utamanya dua kali.
--
-- Pola yang sama dengan `EnemyAI`: keputusannya di sini, penerjemahan ke CFrame
-- dan TakeDamage di service.
--
-- `Vec3` dipinjam dari HitTest supaya tidak ada tipe vektor ketiga di repo ini,
-- dan jaraknya HORIZONTAL dengan alasan yang sama seperti di HitTest: musuh
-- berjalan di tanah dan pemain bisa melompat, jadi zona yang berhenti bekerja
-- karena pemain melompat akan terlihat rusak.

local HitTest = require("./HitTest")

local CombatEffects = {}

export type Vec3 = HitTest.Vec3

-- Satu efek berwaktu yang menempel ke MUSUH: slow dari pukulan, atau tanda.
--
-- `mult` selalu pengali, dan `expiresAt` selalu waktu absolut (os.clock),
-- bukan sisa durasi: sisa durasi harus dikurangi tiap frame, dan frame yang
-- terlewat (server lag spike) membuat efeknya bertahan lebih lama daripada
-- yang dijanjikan. Waktu absolut tidak bisa salah sebanyak itu.
export type Timed = {
	mult: number,
	expiresAt: number,
}

-- Zona yang menempel ke TEMPAT, bukan ke musuh. Umurnya sendiri, dan musuh
-- yang keluar darinya langsung berhenti terpengaruh.
export type Zone = {
	position: Vec3,
	radius: number,
	slowMult: number,
	dps: number,
	expiresAt: number,
}

-- Kandidat untuk pemilihan splash dan penularan tanda. Bentuknya sengaja
-- mirip `EnemyAI.Candidate` tapi tidak sama: yang ini tidak butuh `userId`
-- atau `alive`, dan menyatukannya akan memaksa pemanggil mengisi field yang
-- tidak berarti apa-apa di sini.
export type Target = {
	id: number,
	position: Vec3,
}

CombatEffects.NEUTRAL_MULT = 1

local function isFinitePositive(value: number): boolean
	-- value == value menyaring NaN; NaN lolos dari perbandingan apa pun.
	return value == value and value > 0 and value ~= math.huge
end

-- Pengali yang masuk akal: lebih dari nol, berhingga, dan tidak NaN. Pengali
-- nol membuat musuh berhenti permanen (slow) atau damage hilang (tanda), dan
-- dua-duanya tidak pernah diminta alur mana pun.
local function sanitizeMult(value: number?): number?
	if value == nil or not isFinitePositive(value) then
		return nil
	end
	return value
end

-- Waktu kedaluwarsa dari sekarang. Durasi yang tidak wajar mengembalikan `now`
-- -- yaitu efek yang langsung habis -- bukan nil dan bukan math.huge: efek
-- permanen yang lahir dari satu angka rusak di data alur jauh lebih sulit
-- didiagnosis daripada efek yang tidak pernah terlihat.
function CombatEffects.expiresAt(now: number, seconds: number?): number
	if seconds == nil or not isFinitePositive(seconds) then
		return now
	end
	return now + seconds
end

function CombatEffects.active(now: number, timed: Timed?): boolean
	if timed == nil then
		return false
	end
	return now < timed.expiresAt
end

-- Gabungkan efek yang sudah ada dengan yang baru datang.
--
-- Aturannya: **yang lebih kuat menang, dan yang lebih lama menang.** Untuk slow
-- "lebih kuat" berarti pengali lebih KECIL; untuk tanda berarti lebih BESAR.
-- Jadi pemanggil memberi `strongerIsSmaller`.
--
-- Kenapa bukan "yang terbaru menang", yang lebih sederhana: Ayunan Cepat
-- memukul tiap 0.25 detik dengan slow 50%, dan Fork Bomb Jebakan punya slow
-- yang berbeda. Dengan "terbaru menang", satu pukulan lemah di antara dua
-- pukulan kuat akan MEMBATALKAN slow yang kuat, dan pemain melihat musuh yang
-- kadang melambat kadang tidak tanpa pola -- lalu melaporkannya sebagai slow
-- yang rusak. Dengan "terkuat menang", efeknya monoton dan bisa diprediksi.
--
-- Dan karena yang lemah tidak pernah diterapkan, dia juga tidak bisa
-- memperpanjang umur efek yang kuat lewat pintu belakang.
function CombatEffects.merge(
	now: number,
	current: Timed?,
	newMult: number?,
	newSeconds: number?,
	strongerIsSmaller: boolean
): Timed?
	local mult = sanitizeMult(newMult)
	if mult == nil then
		-- Tidak ada efek baru: yang lama dipertahankan apa adanya, termasuk
		-- kalau dia sudah kedaluwarsa (pembacanya yang memeriksa umur).
		return current
	end

	local expires = CombatEffects.expiresAt(now, newSeconds)
	if not CombatEffects.active(now, current) or current == nil then
		return { mult = mult, expiresAt = expires }
	end

	local keepCurrent = if strongerIsSmaller then current.mult <= mult else current.mult >= mult
	if keepCurrent then
		return current
	end
	return {
		mult = mult,
		-- Umur yang lebih panjang dipertahankan: efek baru yang lebih kuat tapi
		-- lebih pendek tidak boleh memotong sisa umur yang sudah dijanjikan.
		expiresAt = math.max(current.expiresAt, expires),
	}
end

-- Pengali dari satu efek berwaktu, atau 1 kalau tidak ada atau sudah habis.
function CombatEffects.multOf(now: number, timed: Timed?): number
	if not CombatEffects.active(now, timed) or timed == nil then
		return CombatEffects.NEUTRAL_MULT
	end
	return timed.mult
end

-- Zona yang masih hidup DAN memuat posisi itu, pengalinya digabung.
--
-- Beberapa zona bisa bertumpuk, dan yang dipakai yang PALING kuat, bukan
-- hasil kalinya: tiga zona slow 55% yang dikalikan jadi 0.091, yaitu musuh
-- yang praktis berhenti dari tiga tembakan biasa. Itu bukan yang dijanjikan
-- satu pun tingkat alur.
function CombatEffects.zoneSlowAt(now: number, position: Vec3, zones: { Zone }): number
	local best = CombatEffects.NEUTRAL_MULT
	for _, zone in zones do
		if now >= zone.expiresAt then
			continue
		end
		if HitTest.horizontalDistance(position, zone.position) > zone.radius then
			continue
		end
		if zone.slowMult < best then
			best = zone.slowMult
		end
	end
	return best
end

-- Damage per detik dari zona yang memuat posisi itu. Di SINI yang paling kuat
-- TIDAK dipakai -- dps-nya dijumlahkan, karena dua jebakan yang bertumpuk
-- memang dua jebakan, dan damage adalah satu-satunya efek di daftar ini yang
-- penjumlahannya tidak menghasilkan keadaan ekstrem (musuh berhenti, damage
-- nol) dari beberapa tembakan biasa.
function CombatEffects.zoneDamageAt(
	now: number,
	position: Vec3,
	zones: { Zone },
	deltaTime: number
): number
	if not isFinitePositive(deltaTime) then
		return 0
	end
	local total = 0
	for _, zone in zones do
		if now >= zone.expiresAt or zone.dps <= 0 then
			continue
		end
		if HitTest.horizontalDistance(position, zone.position) > zone.radius then
			continue
		end
		total += zone.dps * deltaTime
	end
	return total
end

-- Buang zona yang sudah habis. Mengembalikan daftar BARU, bukan memodifikasi
-- yang diberikan: pemanggilnya mengiterasi daftar ini di dalam loop frame, dan
-- menghapus elemen dari tabel yang sedang diiterasi adalah salah satu cara
-- paling halus untuk melewatkan elemen tanpa error apa pun.
function CombatEffects.pruneZones(now: number, zones: { Zone }): { Zone }
	local alive: { Zone } = {}
	for _, zone in zones do
		if now < zone.expiresAt then
			table.insert(alive, zone)
		end
	end
	return alive
end

-- Musuh dalam radius dari satu titik, KECUALI yang id-nya ada di `exclude`.
--
-- `exclude` itu seluruh alasan fungsi ini ada: korban splash dipilih di sekitar
-- titik kena, dan target utama yang sudah menerima damage penuh ada di titik
-- itu juga. Tanpa pengecualian, dia kena dua kali -- sekali penuh, sekali lagi
-- dikali `splashMult` -- dan selisihnya terlihat seperti damage senjata yang
-- lebih besar daripada yang tertulis di panel.
function CombatEffects.withinRadius(
	center: Vec3,
	targets: { Target },
	radius: number,
	exclude: { [number]: boolean }?
): { number }
	local hit: { number } = {}
	if not isFinitePositive(radius) then
		return hit
	end
	for _, target in targets do
		if exclude ~= nil and exclude[target.id] then
			continue
		end
		if HitTest.horizontalDistance(center, target.position) <= radius then
			table.insert(hit, target.id)
		end
	end
	return hit
end

-- `count` musuh terdekat dari satu titik, KECUALI yang ada di `exclude`.
--
-- Dipakai penularan tanda (`markSpread`). Urutannya deterministik: jarak dulu,
-- lalu id sebagai pemecah seri -- dua musuh berjarak sama persis tidak boleh
-- membuat hasilnya bergantung pada urutan iterasi tabel, yang di Luau tidak
-- dijamin.
function CombatEffects.nearest(
	center: Vec3,
	targets: { Target },
	count: number,
	exclude: { [number]: boolean }?
): { number }
	local picked: { number } = {}
	if count ~= count or count < 1 then
		return picked
	end

	local sorted: { { id: number, distance: number } } = {}
	for _, target in targets do
		if exclude ~= nil and exclude[target.id] then
			continue
		end
		table.insert(sorted, {
			id = target.id,
			distance = HitTest.horizontalDistance(center, target.position),
		})
	end
	table.sort(sorted, function(a, b)
		if a.distance == b.distance then
			return a.id < b.id
		end
		return a.distance < b.distance
	end)

	local limit = math.min(math.floor(count), #sorted)
	for index = 1, limit do
		table.insert(picked, sorted[index].id)
	end
	return picked
end

return CombatEffects
