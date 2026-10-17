--!strict
-- HitTest.luau — geometri uji kena untuk CombatService.
--
-- DARI AWAL, kenapa ini ada dan kenapa longgar. Bagian 1.3 memutuskan musuh
-- digerakkan server lewat CFrame, jadi posisi musuh yang dilihat pemain di
-- layarnya adalah hasil replikasi: selalu tertinggal sebesar latensi. Pemain
-- ping 150 ms membidik musuh di tempat yang menurut server sudah basi ~0.15
-- detik; untuk musuh `fast` (16 stud/detik) itu selisih ~2.4 stud. Raycast
-- setebal nol akan sering bilang "tidak kena" padahal pemain membidik tepat.
--
-- Mitigasi v1 (bagian 3.7, dan ini WAJIB bukan opsional): jangan raycast ketat.
-- Jarak dekat pakai kerucut dengan radius ekstra, jarak jauh pakai silinder di
-- sekitar garis bidik, bukan garis. Ini game co-op PvE — memberi keuntungan ke
-- pemain tidak merugikan siapa pun.
--
-- Kenapa pakai tipe Vec3 sendiri, bukan Vector3 Roblox: modul ini murni supaya
-- bisa dites Lune di CI, dan Lune tidak punya Vector3. CombatService yang
-- mengonversi di batasnya.

local HitTest = {}

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

function HitTest.vec(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

function HitTest.sub(a: Vec3, b: Vec3): Vec3
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function HitTest.dot(a: Vec3, b: Vec3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function HitTest.length(v: Vec3): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Mengembalikan nil untuk vektor nol, supaya pemanggil tidak pernah membagi nol
-- dan menghasilkan NaN yang menjalar ke seluruh perhitungan.
function HitTest.normalize(v: Vec3): Vec3?
	local len = HitTest.length(v)
	if len < 1e-6 then
		return nil
	end
	return { x = v.x / len, y = v.y / len, z = v.z / len }
end

-- Jarak datar (abaikan Y). Dipakai untuk pengecekan jangkauan supaya musuh yang
-- pusat modelnya sedikit lebih tinggi/rendah dari pemain tidak dianggap jauh.
function HitTest.horizontalDistance(a: Vec3, b: Vec3): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Serangan jarak dekat: musuh kena kalau ada di dalam kerucut di depan pemain.
--
-- `range` sudah termasuk radius ekstra (pemanggil menambahkan
-- Balance.MELEE_RADIUS_BONUS). `minCos` adalah cosinus setengah sudut bukaan
-- kerucut: 1 berarti harus tepat lurus, 0 berarti setengah bola di depan,
-- -1 berarti ke segala arah. Arah dibandingkan datar (XZ) saja, karena pemain
-- membidik dengan mouse yang arah Y-nya tidak bisa diandalkan.
function HitTest.inCone(
	origin: Vec3,
	aim: Vec3,
	target: Vec3,
	range: number,
	minCos: number
): boolean
	local distance = HitTest.horizontalDistance(origin, target)
	if distance > range then
		return false
	end
	-- Musuh yang menempel di pemain selalu kena: arah jadi tidak bermakna.
	if distance < 1e-3 then
		return true
	end

	local flatAim = HitTest.normalize(HitTest.vec(aim.x, 0, aim.z))
	if flatAim == nil then
		-- Bidikan tegak lurus ke atas/bawah: tidak ada arah datar yang bisa
		-- dibandingkan, jadi jatuhkan ke "kena kalau cukup dekat".
		return true
	end

	local toTarget = HitTest.normalize(HitTest.vec(target.x - origin.x, 0, target.z - origin.z))
	if toTarget == nil then
		return true
	end

	return HitTest.dot(flatAim, toTarget) >= minCos
end

-- Jarak titik `target` ke segmen bidik yang dimulai di `origin`, menuju `aim`,
-- sepanjang `range`. Proyeksi di-clamp ke [0, range] supaya musuh di belakang
-- pemain atau jauh melewati ujung jangkauan tidak pernah terhitung dekat.
--
-- Mengembalikan (jarak ke garis, jarak sepanjang garis).
function HitTest.distanceToAimSegment(
	origin: Vec3,
	aim: Vec3,
	target: Vec3,
	range: number
): (number, number)
	local direction = HitTest.normalize(aim)
	if direction == nil then
		return math.huge, 0
	end

	local offset = HitTest.sub(target, origin)
	local along = math.clamp(HitTest.dot(offset, direction), 0, range)
	local closest = HitTest.vec(
		origin.x + direction.x * along,
		origin.y + direction.y * along,
		origin.z + direction.z * along
	)
	return HitTest.length(HitTest.sub(target, closest)), along
end

-- Serangan jarak jauh: silinder di sekitar garis bidik, bukan garis setebal nol
-- (bagian 3.7). `radius` adalah toleransi lateral dalam stud.
function HitTest.inAimCylinder(
	origin: Vec3,
	aim: Vec3,
	target: Vec3,
	range: number,
	radius: number
): boolean
	local lateral = HitTest.distanceToAimSegment(origin, aim, target, range)
	return lateral <= radius
end

return HitTest
