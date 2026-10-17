--!strict
-- RateLimit.luau — token bucket per player per remote.
--
-- Kenapa perlu: setiap remote C -> S bisa dipanggil berapa kali pun oleh client
-- yang dimodifikasi (bagian 3.6 mewajibkan rate limit di semua remote). Tanpa
-- batas, satu client bisa memanggil `Attack` ribuan kali per detik dan
-- menghabiskan CPU server walaupun tiap panggilan ditolak validasi.
--
-- Kenapa token bucket, bukan "satu panggilan per X detik": burst pendek itu
-- normal (pemain nge-klik cepat, lag spike bikin beberapa paket datang
-- berbarengan). Bucket mengizinkan burst sebesar kapasitasnya lalu memaksa
-- rata-rata jangka panjang tetap di batas.
--
-- Modul murni: `now` selalu dioper pemanggil, tidak ada os.clock() di sini,
-- supaya bisa dites Lune tanpa menunggu waktu nyata.

local RateLimit = {}

export type Bucket = {
	ratePerSecond: number,
	capacity: number,
	tokens: number,
	updatedAt: number,
}

-- `capacity` default = ratePerSecond (burst satu detik).
function RateLimit.new(ratePerSecond: number, capacity: number?): Bucket
	local size = capacity or ratePerSecond
	return {
		ratePerSecond = ratePerSecond,
		capacity = size,
		tokens = size,
		updatedAt = 0,
	}
end

-- Ambil satu token kalau ada. Mengembalikan true kalau panggilan boleh lanjut.
-- Bucket diubah di tempat.
function RateLimit.allow(bucket: Bucket, now: number): boolean
	local elapsed = now - bucket.updatedAt
	if elapsed > 0 then
		bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.ratePerSecond)
		bucket.updatedAt = now
	elseif elapsed < 0 then
		-- Waktu mundur (tidak seharusnya terjadi, tapi jangan sampai bucket
		-- terkunci selamanya kalau iya).
		bucket.updatedAt = now
	end

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

export type Registry = {
	buckets: { [number]: { [string]: Bucket } },
	limits: { [string]: number },
	defaultLimit: number,
}

function RateLimit.newRegistry(limits: { [string]: number }, defaultLimit: number): Registry
	return {
		buckets = {},
		limits = limits,
		defaultLimit = defaultLimit,
	}
end

-- Cek satu panggilan `key` dari `userId`. Bucket dibuat saat pertama dipakai.
function RateLimit.check(registry: Registry, userId: number, key: string, now: number): boolean
	local perPlayer = registry.buckets[userId]
	if perPlayer == nil then
		perPlayer = {}
		registry.buckets[userId] = perPlayer
	end

	local bucket = perPlayer[key]
	if bucket == nil then
		bucket = RateLimit.new(registry.limits[key] or registry.defaultLimit)
		bucket.updatedAt = now
		perPlayer[key] = bucket
	end

	return RateLimit.allow(bucket, now)
end

function RateLimit.forget(registry: Registry, userId: number)
	registry.buckets[userId] = nil
end

return RateLimit
