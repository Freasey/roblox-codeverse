--!strict
-- Types.luau — tipe yang dipakai bersama server & client.
--
-- Tipe data player ditulis manual, BUKAN di-infer dari Config.DEFAULT_DATA
-- lewat `typeof`. Alasannya ada di docs/DEVELOPMENT_PLAN.md bagian 3.1:
-- inferensi bikin `weapons` cuma punya key `weapon_starter`, dan `materials`
-- jadi tabel kosong tanpa informasi tipe — dua-duanya error di mode strict.

export type WeaponSave = {
	level: number,
	-- Alur upgrade yang dipilih di level 4, permanen. `"none"` berarti belum
	-- memilih.
	--
	-- Defaultnya STRING `"none"`, bukan `nil`, dan itu bukan selera: field
	-- bernilai nil hilang total saat tabelnya disimpan sebagai JSON ke
	-- DataStore, jadi "belum memilih" dan "data lama dari sebelum fitur ini
	-- ada" tidak bisa dibedakan lagi sesudah satu kali save. Dengan `"none"`,
	-- keduanya tetap bisa dibedakan: yang pertama punya field bernilai "none",
	-- yang kedua tidak punya field sama sekali.
	--
	-- Tipenya non-optional, dan yang MEMBUAT itu benar adalah
	-- `DataSchema.migrate`, bukan type checker: dia mengisi `"none"` untuk
	-- setiap senjata yang belum punya, dan `PlayerDataService` memanggilnya di
	-- kedua jalur yang memuat data pemain. Jadi setiap save yang pernah dilihat
	-- server atau client memenuhi tipe ini.
	--
	-- Yang TIDAK lewat migrate: tabel yang dibuat tangan -- fixture test, dan
	-- data yang diedit dari command bar. Untuk itu `ProgressionRules.ownedWeapons`
	-- menormalkan `save.path or "none"` sekali, di satu tempat, supaya pembaca
	-- lain tidak perlu mengulanginya. Kalau ada pembaca BARU yang menerima save
	-- dari luar kedua jalur itu, dia ikut lewat `ownedWeapons` -- jangan
	-- menambah `or "none"` kedua, dan jangan melonggarkan tipe ini jadi
	-- `string?`, karena itu memaksa setiap pembaca menangani nil untuk keadaan
	-- yang tidak pernah terjadi di jalur sungguhan.
	path: string,
}

export type PlayerStats = {
	highestWave: number,
	matchesPlayed: number,
	wins: number,
}

export type PlayerData = {
	schemaVersion: number,
	coins: number,
	level: number,
	xp: number,
	playtimeSeconds: number,
	lastLogin: number,
	equippedWeapon: string,
	weapons: { [string]: WeaponSave },
	materials: { [string]: number },
	unlockedDifficulties: { [string]: boolean },
	clears: { [string]: boolean },
	stats: PlayerStats,
}

-- Cara sebuah senjata didapat. `default` otomatis dimiliki player baru,
-- `buy` pakai koin permanen, `craft` pakai material drop boss.
export type WeaponAcquire = {
	method: "default" | "buy" | "craft",
	coinCost: number?,
	materials: { [string]: number }?,
}

-- Satu tingkat dari satu alur upgrade: apa yang terbuka di level berapa.
--
-- Pengali dan nilai absolut dicampur, dan pembagiannya mengikuti bentuk
-- efeknya, bukan kerapian:
--
--   `damageMult` / `cooldownMult`  PENGALI, menumpuk di atas kurva level yang
--                                  sudah ada -- "damage x1.5" harus tetap
--                                  berarti x1.5 di level 10.
--   `cooldown`                     NILAI ABSOLUT yang menimpa, untuk alur yang
--                                  menyatakan targetnya langsung ("cooldown
--                                  0.5 -> 0.32", lalu "0.25" di tingkat 3).
--   `range` / `projectiles`        NILAI ABSOLUT yang menimpa, karena alurnya
--                                  menyatakannya begitu ("range 60 -> 90",
--                                  "tembus 3 musuh"), dan pengali di sana cuma
--                                  memaksa pembaca menghitung sendiri.
--
-- Cooldown punya DUA bentuk, dan itu bukan kelebihan pilihan: lampiran A
-- rancangan menyatakannya dengan dua cara, dan satu bentuk saja memaksa salah
-- satunya dihitung manual. Alur "ayunan berat" menulis "cooldown x1.4" --
-- pengali, karena yang dimaksud "lebih lambat sekian persen". Alur "ayunan
-- cepat" menulis "cooldown 0.5 -> 0.32" lalu "cooldown 0.25" -- target absolut,
-- karena yang dimaksud angka akhirnya. Menerjemahkan yang kedua jadi pengali
-- menghasilkan `0.78125` di tingkat 3 (supaya 0.64 x 0.78125 = 0.5), angka yang
-- tidak bisa diperiksa siapa pun dengan membaca.
--
-- Satu tingkat sebaiknya memakai salah satu, bukan dua-duanya. Kalau dua-duanya
-- ada, `cooldownMult` dipakai dulu lalu `cooldown` menimpa hasilnya -- jadi
-- pengalinya tidak berpengaruh apa-apa, yang membuat tingkat seperti itu
-- menyesatkan untuk dibaca walau tidak salah untuk dihitung.
--
-- `summary` itu teks yang dilihat pemain SEBELUM dia memilih, dan itu syarat:
-- pilihan permanen yang diambil tanpa melihat isinya bukan keputusan, itu
-- jebakan (ARENA_REDESIGN.md bagian 3).
--
-- `effects` untuk yang tidak bisa dinyatakan sebagai stat senjata: slow, damage
-- masuk yang dikurangi, splash, tanda. Kosong sampai langkah 7 rancangan ulang
-- mengisinya; yang ada sekarang kerangkanya.
export type WeaponPathTier = {
	level: number,
	summary: string,
	damageMult: number?,
	cooldownMult: number?,
	cooldown: number?,
	range: number?,
	projectiles: number?,
	effects: { [string]: number }?,
}

-- Satu alur upgrade. Tiga per senjata, dipilih sekali di level 4 dan tidak
-- bisa diganti.
export type WeaponPathDef = {
	id: string,
	name: string,
	theme: string,
	tiers: { WeaponPathTier },
}

export type WeaponDef = {
	id: string,
	name: string,
	kind: "melee" | "ranged",
	baseDamage: number,
	cooldown: number, -- detik antar serangan
	range: number, -- stud
	projectiles: number, -- jumlah proyektil/sapuan per serangan
	maxLevel: number,
	acquire: WeaponAcquire,
	-- Daftar berurutan, bukan map: urutan iterasi tabel Luau tidak dijamin,
	-- dan ini urutan tombol yang dilihat pemain saat memilih selamanya.
	paths: { WeaponPathDef },
}

-- Stat senjata yang sudah jadi, sesudah level dan alur diperhitungkan. Satu
-- tabel, satu fungsi yang menghasilkannya (`Balance.weaponStats`), supaya tidak
-- ada dua tempat yang menghitung damage dengan cara yang sedikit berbeda.
export type WeaponStats = {
	damage: number,
	cooldown: number,
	range: number,
	projectiles: number,
	effects: { [string]: number },
}

-- Profil target per TIPE musuh, bukan per musuh. Satu tabel kecil yang dibaca
-- EnemyAI; menaruhnya di definisi berarti menambah tipe musuh baru tidak
-- menyentuh satu baris pun logika AI.
--
-- `prefer` menentukan ke mana musuh berjalan kalau tidak ada target di
-- jangkauan. `aggroRadius` jarak mulai mengejar player; `leashRadius` jarak
-- berhenti mengejar, dan dia HARUS lebih besar dari aggro -- kalau sama,
-- musuh akan bergetar masuk-keluar status mengejar di batasnya.
export type TargetProfile = {
	prefer: "base" | "player",
	aggroRadius: number,
	leashRadius: number,
}

export type EnemyDef = {
	id: string,
	name: string,
	analogy: string, -- jenis malware yang diwakili
	baseHp: number,
	speed: number, -- stud per detik
	-- Damage SEKALI PUKUL, bukan sekali sampai. Musuh yang mencapai base tidak
	-- lagi hilang: dia berhenti dan memukul tiap `attackInterval` detik sampai
	-- dibunuh pemain. Angka mentah ini dipakai untuk player; untuk base dia
	-- dikali Balance.BASE_DAMAGE_MULT.
	attackDamage: number,
	attackInterval: number, -- detik antar pukulan
	targeting: TargetProfile,
	matchCoins: number, -- koin match yang dijatuhkan
}

-- Teks edukatif yang muncul setelah boss kalah (CONCEPT.md: kartu info).
export type InfoCard = {
	title: string,
	body: string,
	prevention: { string },
}

-- Mekanik boss ditulis sebagai tagged union supaya BossService bisa
-- membedakannya lewat `mechanic.kind` tanpa menebak dari id.
export type SplitterMechanic = {
	kind: "splitter",
	thresholds: { number }, -- fraksi HP tempat boss membelah
	spawnEnemyId: string,
	spawnCount: number,
}

export type LockerMechanic = {
	kind: "locker",
	locksShop: boolean,
	summonEnemyId: string,
	summonCount: number,
	summonInterval: number, -- detik
}

export type BossMechanic = SplitterMechanic | LockerMechanic

export type BossDef = {
	id: string,
	name: string,
	analogy: string,
	wave: number,
	baseHp: number,
	speed: number,
	attackDamage: number,
	attackInterval: number,
	targeting: TargetProfile,
	matchCoins: number,
	dropMaterial: string,
	mechanic: BossMechanic,
	infoCard: InfoCard,
}

-- Satu baris komposisi wave: `count` dihitung Balance.enemyCount, `share`
-- menentukan berapa bagian dari jumlah itu yang jadi musuh ini.
export type WaveEntry = {
	enemyId: string,
	share: number,
}

export type WaveDef = {
	index: number,
	entries: { WaveEntry },
	bossId: string?,
}

export type DifficultyDef = {
	id: string,
	name: string,
	hpMult: number,
	rewardMult: number,
	unlockedByDefault: boolean,
	unlockedBy: string?, -- id difficulty yang harus di-clear dulu
}

export type ShopItemDef = {
	id: string,
	name: string,
	description: string,
	cost: number, -- koin match
	maxPurchases: number, -- per match, 0 = tak terbatas
}

return {}
