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

-- Damage senjata pada level tertentu.
function Balance.weaponDamage(def: Types.WeaponDef, level: number): number
	return def.baseDamage * (1 + Balance.DAMAGE_PER_LEVEL * (level - 1))
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

return Balance
