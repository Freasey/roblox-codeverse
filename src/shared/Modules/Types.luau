--!strict
-- Types.luau — tipe yang dipakai bersama server & client.
--
-- Tipe data player ditulis manual, BUKAN di-infer dari Config.DEFAULT_DATA
-- lewat `typeof`. Alasannya ada di docs/DEVELOPMENT_PLAN.md bagian 3.1:
-- inferensi bikin `weapons` cuma punya key `weapon_starter`, dan `materials`
-- jadi tabel kosong tanpa informasi tipe — dua-duanya error di mode strict.

export type WeaponSave = {
	level: number,
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
}

export type EnemyDef = {
	id: string,
	name: string,
	analogy: string, -- jenis malware yang diwakili
	baseHp: number,
	speed: number, -- stud per detik
	coreDamage: number, -- HP Core yang hilang kalau musuh sampai
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
	coreDamage: number,
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
