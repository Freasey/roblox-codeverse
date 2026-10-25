--!strict
-- Balance.luau — semua rumus angka v1 dikumpulkan di sini
-- (docs/DEVELOPMENT_PLAN.md bagian 3.5). Satu tempat untuk disetel setelah
-- playtest, dan satu tempat untuk dites.
--
-- Modul murni: fungsi di sini menerima definisi lewat argumen dan tidak
-- menyentuh game:GetService maupun `script`, jadi bisa dijalankan Lune di CI.

local Types = require("./Types")

local Balance = {}

-- Konstanta rumus. Dipisah dari rumusnya supaya penyetelan balancing tidak
-- perlu menyentuh logika.
Balance.HP_PER_WAVE = 0.15
Balance.HP_PER_EXTRA_PLAYER = 0.35
Balance.COUNT_BASE = 6
Balance.COUNT_PER_WAVE = 2
Balance.COUNT_PER_EXTRA_PLAYER = 0.25
Balance.COINS_PER_WAVE = 10
Balance.COINS_WIN_BONUS = 50
Balance.XP_PER_WAVE = 20
Balance.XP_WIN_BONUS = 100
-- Kurva level. Tidak disebut bagian 3.5, yang cuma menyebut XP per match;
-- angkanya dipilih supaya match pertama (wave 1 kalah, 20 XP) tidak langsung
-- naik level, dan satu match penuh yang menang (300 XP) menaikkan beberapa
-- level di awal lalu makin lambat.
Balance.XP_LEVEL_BASE = 100
Balance.XP_LEVEL_GROWTH = 1.25
Balance.UPGRADE_BASE_PRICE = 50
Balance.UPGRADE_PRICE_GROWTH = 1.35
Balance.DAMAGE_PER_LEVEL = 0.12

-- Batas musuh aktif sekaligus (bagian 1.3). Sisa spawn masuk antrian, bukan
-- dibuang: wave 10 dengan 4 player melebihi angka ini, dan kalau sisanya
-- dibuang wave itu tidak akan pernah bisa diselesaikan.
Balance.MAX_ACTIVE_ENEMIES = 40

-- Jeda antar spawn musuh dalam satu wave. Bukan nol: 30 musuh yang muncul pada
-- frame yang sama langsung menumpuk jadi satu gumpalan dan pemain tidak punya
-- kesempatan mengurangi jumlahnya.
Balance.SPAWN_INTERVAL = 0.9

-- Core Server. Tidak diskalakan terhadap jumlah player: HP musuh sudah naik
-- 35% per player tambahan (HP_PER_EXTRA_PLAYER), jadi menaikkan HP core juga
-- akan menghitung jumlah player dua kali.
Balance.CORE_MAX_HP = 1000

-- Pengali damage serangan musuh. Musuh punya SATU angka `attackDamage`, dan
-- dua pengali ini yang membuat satu angka itu berarti berbeda untuk dua sasaran
-- yang HP-nya terpaut 50x (base 1000, player 100).
--
-- 0.2 bukan angka kosmetik: dia yang membuat base efektif 5000 HP, dan dari
-- situlah aritmetika kebocoran di Enemies.luau dihitung -- satu `basic` lolos
-- sepanjang wave memakan seperempat base. Menaikkannya mempersingkat match
-- jauh lebih cepat daripada yang terlihat.
Balance.BASE_DAMAGE_MULT = 0.2
-- 1.0 sekarang, dan dia ada sebagai titik masuk: pengurang damage dari upgrade
-- atau item nanti dipasang di sini, bukan disebar ke pemanggil.
Balance.PLAYER_DAMAGE_MULT = 1.0

-- Hadiah koin match per wave. Masuk kolam tim, BUKAN koin permanen, dan itu
-- yang membuat pengali jumlah pemain di bawah koheren.
--
-- Kalau hadiah per wave masuk koin permanen, main solo jadi 4x lebih efisien
-- per orang untuk farming, dan game co-op yang menghukum main bareng akan
-- dimainkan solo oleh semua orang. Kolam koin match dibagi tim, jadi x4 solo
-- cuma menormalkan daya beli per orang -- tidak memberi solo keuntungan yang
-- dibawa keluar dari match.
Balance.WAVE_REWARD_BASE = 200
Balance.WAVE_REWARD_PER_WAVE = 50
-- Wave boss dikali dua karena boss yang membuat wave itu terasa sebagai puncak.
Balance.WAVE_REWARD_BOSS_MULT = 2

-- Harga Toko Match naik per pembelian item yang sama, dan ini PENGGANTI batas
-- jumlah (`maxPurchases`), bukan tambahan untuknya.
--
-- Kenapa diganti: dengan hadiah per wave di atas, solo mengumpulkan sekitar
-- 21.200 koin sepanjang 10 wave, sementara toko yang seluruh itemnya dibatasi
-- cuma bisa menyerap 3.450. Artinya toko habis diborong di wave 3-4 dan enam
-- wave sisanya koinnya tidak ada gunanya. Dengan harga yang naik, 10 tumpuk
-- damage up memakan 6.647 koin alih-alih 2.000: uang selalu punya tujuan, dan
-- kelebihan pasokan solo terkoreksi lewat harga, bukan lewat tembok.
Balance.SHOP_PRICE_GROWTH = 1.25

-- Respawn pemain. Sebelum musuh bisa menyerang, kematian pemain tidak punya
-- konsekuensi apa pun dan angka ini tidak berarti; sekarang dia salah satu knob
-- kesulitan yang paling langsung terasa.
--
-- Ditulis eksplisit, bukan dibiarkan memakai default Roblox yang kebetulan juga
-- 5 detik: kalau defaultnya berubah atau ada plugin yang menyetelnya, kesulitan
-- game ini bergeser tanpa satu baris pun di repo ini berubah.
--
-- Tanpa sistem nyawa di v1 (rancangan bagian 5): mati cuma berarti kehilangan
-- waktu, dan waktu itu mahal karena musuh terus memukul base selama pemain
-- tidak ada.
Balance.RESPAWN_SECONDS = 5

-- Slot cincin di sekitar base. Musuh tidak punya collision (CanCollide = false)
-- dan tidak punya pathfinding, jadi dua puluh musuh yang berhenti di titik yang
-- sama akan bertumpuk jadi satu gumpalan yang tidak bisa dibidik satu-satu.
-- Tiap musuh yang mencapai base mengambil satu slot di cincin.
--
-- 12 slot di radius 10 memberi jarak antar slot sekitar 5.2 stud, cukup untuk
-- memisahkan musuh terbesar (`tank` 6x6x6). Yang ke-13 dan seterusnya masuk
-- cincin kedua, bukan menumpuk di cincin pertama.
Balance.BASE_RING_SLOTS = 12
Balance.BASE_RING_RADIUS = 10
Balance.BASE_RING_RADIUS_OUTER = 14

-- Musuh dianggap sampai di sebuah waypoint kalau jaraknya di bawah ini. Harus
-- lebih besar dari perpindahan satu frame musuh tercepat (16 stud/detik pada 60
-- fps = 0.27 stud), kalau tidak musuh bisa melewati waypoint dan berputar-putar.
Balance.WAYPOINT_REACH = 1.5

-- Toleransi uji kena (bagian 3.7). Sengaja longgar: musuh digerakkan server,
-- jadi posisi di layar pemain selalu tertinggal sebesar latensi.
Balance.MELEE_RADIUS_BONUS = 5 -- stud ekstra di luar `range` senjata
Balance.MELEE_MIN_COS = 0.2 -- cos setengah sudut kerucut; 0.2 ~ 78 derajat
Balance.RANGED_RADIUS = 5 -- radius silinder di sekitar garis bidik

-- Toko Match (M3). Efeknya ditambahkan secara linear, bukan dikalikan, supaya
-- lima pembelian jadi 1.5x dan bukan 1.61x: harga tetap, efek tidak meledak,
-- dan pemain bisa menghitung sendiri apa yang dia dapat.
Balance.SHOP_DAMAGE_STEP = 0.10
Balance.SHOP_FIRE_RATE_STEP = 0.08
-- Lantai cooldown. Lima kali -8% linear jadi 0.6; lantainya ada supaya
-- menaikkan step nanti tidak bisa membuat cooldown senjata hilang sama sekali.
Balance.SHOP_COOLDOWN_FLOOR = 0.4
Balance.CORE_REPAIR_FRACTION = 0.15
Balance.BARRIER_DURATION = 6 -- detik musuh tertahan di satu lane
Balance.TURRET_DAMAGE = 12
Balance.TURRET_INTERVAL = 1.0 -- detik antar tembakan
Balance.TURRET_RANGE = 70 -- stud

-- HP satu musuh pada wave tertentu.
function Balance.enemyHp(
	def: Types.EnemyDef,
	wave: number,
	difficulty: Types.DifficultyDef,
	playerCount: number
): number
	return def.baseHp
		* (1 + Balance.HP_PER_WAVE * (wave - 1))
		* difficulty.hpMult
		* (1 + Balance.HP_PER_EXTRA_PLAYER * (playerCount - 1))
end

-- HP boss. Boss tidak ikut penskalaan per wave karena wave-nya sudah tetap;
-- yang berlaku cuma kesulitan dan jumlah player.
function Balance.bossHp(
	def: Types.BossDef,
	difficulty: Types.DifficultyDef,
	playerCount: number
): number
	return def.baseHp * difficulty.hpMult * (1 + Balance.HP_PER_EXTRA_PLAYER * (playerCount - 1))
end

-- Jumlah musuh biasa dalam satu wave.
function Balance.enemyCount(wave: number, playerCount: number): number
	return math.floor(
		Balance.COUNT_BASE
			+ Balance.COUNT_PER_WAVE
				* wave
				* (1 + Balance.COUNT_PER_EXTRA_PLAYER * (playerCount - 1))
	)
end

-- Koin permanen di akhir match. Kalah tetap dapat, sesuai CONCEPT.md.
function Balance.rewardCoins(
	waveReached: number,
	won: boolean,
	difficulty: Types.DifficultyDef
): number
	local base = Balance.COINS_PER_WAVE * waveReached + (if won then Balance.COINS_WIN_BONUS else 0)
	return math.floor(base * difficulty.rewardMult)
end

-- XP akhir match. Tidak dikali rewardMult: kesulitan menaikkan koin, bukan level.
function Balance.rewardXp(waveReached: number, won: boolean): number
	return Balance.XP_PER_WAVE * waveReached + (if won then Balance.XP_WIN_BONUS else 0)
end

-- Harga naik dari level `fromLevel` ke `fromLevel + 1`.
function Balance.upgradePrice(fromLevel: number): number
	return math.floor(Balance.UPGRADE_BASE_PRICE * Balance.UPGRADE_PRICE_GROWTH ^ (fromLevel - 1))
end

-- Kosakata kunci `effects` di `WeaponPathTier`, dan di mana tiap kunci harus
-- dibaca supaya dia berarti apa-apa.
--
-- Ditulis di sini SEBELUM ada satu pun alur yang memakainya, karena kunci di
-- tabel `{ [string]: number }` tidak dijaga type checker: `slowMult` yang
-- ditulis `slowmult` di satu tempat akan diam-diam tidak pernah terbaca, dan
-- gejalanya cuma "alur itu tidak terasa". Jadi daftarnya satu, di sini, dan
-- langkah 7 memakai nama dari daftar ini -- bukan sebaliknya.
--
-- | kunci              | arti                                | dibaca di |
-- |--------------------|-------------------------------------|-----------|
-- | `coneMinCos`       | ganti `MELEE_MIN_COS` (kerucut lebar)| CombatService, saat HitTest.inCone |
-- | `slowMult`         | pengali speed musuh yang kena        | EnemyService |
-- | `slowSeconds`      | berapa lama slow itu bertahan        | EnemyService |
-- | `damageTakenMult`  | pengali damage yang masuk ke PEMAIN  | EnemyService, di jalur TakeDamage |
-- | `splashRadius`     | radius ledakan dari titik kena       | CombatService |
-- | `splashMult`       | pengali damage untuk korban splash   | CombatService |
-- | `markMult`         | pengali damage ke musuh yang ditandai| EnemyService.damage |
-- | `markSeconds`      | berapa lama tanda itu bertahan       | EnemyService |
-- | `markSpread`       | berapa musuh terdekat ikut ditandai  | EnemyService |
-- | `zoneDps`          | damage per detik dari zona jebakan   | CombatService / EnemyService |
--
-- Empat di antaranya butuh mekanik yang belum ada sama sekali (slow, damage
-- masuk yang dikurangi, splash, tanda) -- itu pekerjaan langkah 7, bukan
-- langkah 6, dan daftar ini yang menjadi daftar pekerjaannya.
--
-- Kunci yang tidak ada di daftar ini TIDAK akan dibaca siapa pun. Itu bukan
-- larangan yang ditegakkan kode, jadi menambah kunci baru berarti menambahnya
-- di sini DAN di tempat yang membacanya, dalam satu perubahan yang sama.
Balance.PATH_EFFECT_KEYS = {
	"coneMinCos",
	"slowMult",
	"slowSeconds",
	"damageTakenMult",
	"splashRadius",
	"splashMult",
	"markMult",
	"markSeconds",
	"markSpread",
	"zoneDps",
}

-- Level tempat pemain WAJIB memilih satu dari tiga alur upgrade, permanen.
--
-- Empat dan bukan satu karena pemain harus pernah MEMAKAI senjatanya sebelum
-- dipaksa memilih selamanya; level 1 sampai 3 itu masa percobaannya
-- (ARENA_REDESIGN.md bagian 3).
Balance.PATH_BRANCH_LEVEL = 4

-- Damage senjata pada level tertentu, tanpa alur. Dipakai `weaponStats` sebagai
-- dasar, dan dipisah supaya kurva level bisa dites sendiri terpisah dari
-- penggabungan efek alur.
function Balance.weaponDamage(def: Types.WeaponDef, level: number): number
	return def.baseDamage * (1 + Balance.DAMAGE_PER_LEVEL * (level - 1))
end

-- Alur yang dipilih pemain untuk satu senjata, atau nil kalau belum memilih.
--
-- `save.path` bisa memuat id yang tidak ada di `def.paths`: data lama dari
-- sebelum nama alurnya diubah, atau data yang diedit tangan. Yang
-- dikembalikan nil, bukan alur pertama -- memberi alur yang salah secara diam-
-- diam lebih buruk daripada tidak memberi apa pun, karena pemain melihat stat
-- dari alur yang tidak dia pilih dan tidak ada satu pun pesan soal itu.
local function findPath(def: Types.WeaponDef, pathId: string): Types.WeaponPathDef?
	for _, path in def.paths do
		if path.id == pathId then
			return path
		end
	end
	return nil
end

-- Stat senjata yang sudah jadi: level, alur, dan tingkat alur yang sudah
-- terbuka, digabung jadi satu tabel.
--
-- Kenapa satu fungsi dan bukan `weaponDamage` plus beberapa yang lain:
-- `CombatService` butuh damage, cooldown, range, dan jumlah proyektil dalam
-- satu tarikan napas tiap serangan, dan alur upgrade bisa mengubah keempatnya.
-- Dengan fungsi terpisah, satu pemanggil yang lupa menerapkan alur pada SALAH
-- SATU stat akan menghasilkan senjata yang damage-nya ikut alur tapi
-- cooldown-nya tidak -- dan selisih seperti itu tidak terlihat sampai ada yang
-- mengukurnya dengan stopwatch. Ini juga satu-satunya tempat efek alur
-- dipasang, jadi langkah 7 tidak perlu mencari-cari.
--
-- Tingkat alur diterapkan BERURUTAN dari yang paling rendah: tingkat yang lebih
-- tinggi menimpa `range` dan `projectiles` milik tingkat sebelumnya, dan
-- pengali damage/cooldown-nya saling menumpuk. Itu yang membuat alur seperti
-- "cooldown turun di tingkat 1, turun lagi di tingkat 3" bisa ditulis apa
-- adanya.
function Balance.weaponStats(def: Types.WeaponDef, save: Types.WeaponSave): Types.WeaponStats
	local level = math.clamp(math.floor(save.level), 1, def.maxLevel)

	local stats: Types.WeaponStats = {
		damage = Balance.weaponDamage(def, level),
		cooldown = def.cooldown,
		range = def.range,
		projectiles = def.projectiles,
		effects = {},
	}

	-- Alurnya boleh nil (belum memilih, atau id yang tidak dikenal); yang tidak
	-- boleh dilewati adalah batas-batas di bawah loop ini. Jadi `for` yang
	-- berjalan nol kali, bukan `return` lebih awal.
	local path = findPath(def, save.path)
	local tiers: { Types.WeaponPathTier } = if path ~= nil then path.tiers else {}

	for _, tier in tiers do
		if tier.level > level then
			continue
		end
		if tier.damageMult ~= nil then
			stats.damage *= tier.damageMult
		end
		if tier.cooldownMult ~= nil then
			stats.cooldown *= tier.cooldownMult
		end
		-- Sesudah pengali, bukan sebelum: `cooldown` itu target absolut, jadi
		-- dia harus jadi kata terakhir di tingkat yang menyebutkannya. Urutan
		-- sebaliknya membuat pengali tingkat yang sama mengalikan target itu,
		-- dan "cooldown 0.32" jadi bukan 0.32.
		if tier.cooldown ~= nil then
			stats.cooldown = tier.cooldown
		end
		if tier.range ~= nil then
			stats.range = tier.range
		end
		if tier.projectiles ~= nil then
			stats.projectiles = tier.projectiles
		end
		if tier.effects ~= nil then
			for key, value in tier.effects do
				stats.effects[key] = value
			end
		end
	end

	-- Lantai, bukan pembulatan: cooldown nol atau negatif dari data alur yang
	-- rusak berarti serangan tanpa batas, dan gerbang cooldown di
	-- `CombatService` tidak akan menolaknya karena `now - last < 0` selalu
	-- false. Jadi dibatasi di sini, di satu tempat, bukan di pemanggil.
	stats.cooldown = math.max(0.05, stats.cooldown)
	stats.damage = math.max(0, stats.damage)
	stats.range = math.max(0, stats.range)
	stats.projectiles = math.max(1, math.floor(stats.projectiles))

	return stats
end

-- XP yang dibutuhkan untuk naik DARI level ini ke level berikutnya.
function Balance.xpForLevel(level: number): number
	local clamped = math.max(1, math.floor(level))
	return math.floor(Balance.XP_LEVEL_BASE * Balance.XP_LEVEL_GROWTH ^ (clamped - 1))
end

-- Terapkan XP yang baru didapat, naik level sebanyak yang mampu.
--
-- Mengembalikan (level baru, sisa XP, jumlah level yang naik). Satu match bisa
-- memberi cukup XP untuk naik beberapa level sekaligus (terutama match pertama
-- yang menang di hard), jadi ini loop, bukan satu pengurangan.
--
-- Loop-nya dibatasi MAX_LEVEL_UPS_PER_CALL. Bukan karena ada yang bisa
-- memberi XP sebanyak itu secara sah, tapi karena satu nilai XP yang rusak
-- (inf, atau angka raksasa dari data yang korup) akan membuat loop ini
-- berjalan selamanya dan menggantung thread yang memanggilnya — di server itu
-- berarti pemain yang tidak pernah dapat reward dan tidak pernah tahu kenapa.
Balance.MAX_LEVEL_UPS_PER_CALL = 100

function Balance.applyXp(level: number, xp: number, gained: number): (number, number, number)
	local newLevel = math.max(1, math.floor(level))
	local newXp = math.max(0, xp)

	-- XP yang bukan angka wajar tidak diterapkan sama sekali, bukan di-clamp:
	-- di-clamp berarti data yang rusak tetap menghasilkan reward, dan itu
	-- menyembunyikan penyebabnya.
	if gained ~= gained or gained == math.huge or gained < 0 then
		return newLevel, newXp, 0
	end

	newXp += math.floor(gained)

	local gainedLevels = 0
	while gainedLevels < Balance.MAX_LEVEL_UPS_PER_CALL do
		local needed = Balance.xpForLevel(newLevel)
		if needed <= 0 or newXp < needed then
			break
		end
		newXp -= needed
		newLevel += 1
		gainedLevels += 1
	end

	return newLevel, newXp, gainedLevels
end

-- Pengali jumlah pemain untuk hadiah wave. Tangga, bukan kurva: 1 pemain x4,
-- 2 pemain x2, 3 atau lebih x1.
--
-- Perhatikan bahwa ini sudah separuh adil dengan sendirinya sebelum pengali
-- apa pun: efek Toko Match berlaku untuk SELURUH tim, jadi tim berempat
-- mendapat 4x nilai dari tiap koin yang dibelanjakan. 200 koin untuk tim
-- berempat kira-kira setara 800 untuk solo.
function Balance.playerCountMultiplier(playerCount: number): number
	-- NaN dan jumlah pemain yang tidak masuk akal diperlakukan sebagai solo:
	-- hadiah yang terlalu besar lebih mudah terlihat saat playtest daripada
	-- hadiah yang diam-diam hilang.
	if playerCount ~= playerCount or playerCount <= 1 then
		return 4
	end
	if playerCount < 3 then
		return 2
	end
	return 1
end

-- Hadiah koin match untuk satu wave yang baru selesai.
--
-- `isBossWave` sengaja diminta sebagai argumen, bukan dicari sendiri: modul ini
-- tidak tahu apa pun soal boss, dan membuatnya me-require Waves atau Bosses
-- akan menukar satu argumen dengan satu lingkaran require. Pemanggilnya sudah
-- punya jawabannya: `Waves.get(wave).bossId ~= nil`.
function Balance.waveReward(wave: number, playerCount: number, isBossWave: boolean): number
	if wave ~= wave or wave < 1 or wave == math.huge then
		return 0
	end
	local base = Balance.WAVE_REWARD_BASE + Balance.WAVE_REWARD_PER_WAVE * (math.floor(wave) - 1)
	if isBossWave then
		base *= Balance.WAVE_REWARD_BOSS_MULT
	end
	return math.floor(base * Balance.playerCountMultiplier(playerCount))
end

return Balance
