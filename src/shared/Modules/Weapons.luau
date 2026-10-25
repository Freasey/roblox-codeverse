--!strict
-- Weapons.luau — definisi senjata v1 (CONCEPT.md: 3 senjata, level 1 sampai 10).
--
-- Modul murni: tanpa game:GetService, tanpa `script`. Stat per level dan harga
-- upgrade dihitung Balance.luau dari angka dasar di sini.
--
-- Soal `paths`: tiga alur upgrade per senjata, dipilih sekali di level 4 dan
-- permanen (ARENA_REDESIGN.md bagian 3, dengan angkanya dari lampiran A). Tiap
-- alur punya tiga tingkat, di level 4, 7, dan 10.
--
-- **`summary` adalah janji ke pemain, bukan catatan untuk programmer.** Panel
-- pemilihan alur menampilkannya apa adanya, dan pemain mengunci pilihan
-- permanen berdasarkan apa yang dia baca di situ. Jadi tiap `summary` harus
-- menyebut angka yang BENAR-BENAR dihasilkan `Balance.weaponStats` untuk
-- tingkat itu. Baris yang menjanjikan sesuatu yang tidak dilakukan kodenya
-- bukan placeholder yang tidak apa-apa, dia bohong yang tidak punya cara
-- diketahui pemain.
--
-- Pengali vs nilai absolut (lengkapnya di `Types.WeaponPathTier`):
-- `damageMult`/`cooldownMult` menumpuk, `cooldown`/`range`/`projectiles`
-- ditimpa tingkat yang lebih tinggi. Kunci di `effects` harus ada di
-- `Balance.PATH_EFFECT_KEYS`, dan ada unit test yang menolak yang tidak.
--
-- Temanya dan `id`-nya tidak boleh diubah sesudah ada pemain yang memilih:
-- `save.path` menyimpan `id`-nya, jadi mengganti arti alur "a" berarti semua
-- pemain yang pernah memilih "a" mendapat alur yang berbeda tanpa pernah
-- menyetujuinya.

local Types = require("./Types")

export type WeaponDef = Types.WeaponDef

local MAX_LEVEL = 10

-- Level tempat tiap tingkat alur terbuka. Dipakai sebagai angka, bukan
-- diulang-ulang sebagai literal, supaya ketiga senjata tidak bisa berbeda
-- tanpa ada yang menyadarinya. Tingkat pertama HARUS sama dengan
-- `Balance.PATH_BRANCH_LEVEL`, dan ada unit test yang memeriksanya.
local TIER_LEVELS = { 4, 7, 10 }

local Weapons: { [string]: WeaponDef } = {
	weapon_starter = {
		id = "weapon_starter",
		name = "Patch Wrench",
		kind = "melee",
		baseDamage = 25,
		cooldown = 0.5,
		range = 12,
		projectiles = 1,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "default",
		},
		paths = {
			{
				id = "a",
				name = "Ayunan Berat",
				theme = "Pukulan lebih jarang tapi jauh lebih sakit, lalu mengenai "
					.. "beberapa musuh sekaligus.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Damage x1.5, tapi jeda antar serangan x1.4 (0.5 jadi 0.7 detik).",
						damageMult = 1.5,
						cooldownMult = 1.4,
					},
					{
						level = TIER_LEVELS[2],
						-- cos -0.1 kira-kira 96 derajat setengah sudut: lebih dari
						-- separuh lingkaran di sekitar pemain.
						summary = "Kerucut ayunan melebar dari sekitar 78 jadi 96 derajat.",
						effects = { coneMinCos = -0.1 },
					},
					{
						level = TIER_LEVELS[3],
						summary = "Satu ayunan mengenai sampai 3 musuh, masing-masing damage penuh.",
						projectiles = 3,
					},
				},
			},
			{
				id = "b",
				name = "Ayunan Cepat",
				theme = "Serangan beruntun yang memperlambat musuh yang kena.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Jeda antar serangan 0.5 jadi 0.32 detik.",
						cooldown = 0.32,
					},
					{
						level = TIER_LEVELS[2],
						summary = "Musuh yang kena jalan 35% lebih lambat selama 1.5 detik.",
						effects = { slowMult = 0.65, slowSeconds = 1.5 },
					},
					{
						level = TIER_LEVELS[3],
						summary = "Jeda jadi 0.25 detik, dan perlambatannya jadi 50%.",
						cooldown = 0.25,
						-- `slowSeconds` tidak diulang: tingkat 2 sudah menyetelnya, dan
						-- penggabungan di `Balance.weaponStats` mempertahankan kunci yang
						-- tidak disebut tingkat berikutnya. Mengulangnya membuat tiap
						-- tingkat berpura-pura mengubah sesuatu yang tidak dia ubah --
						-- dan menyetel ulang `slowSeconds` di tingkat 1 nanti akan
						-- diam-diam ditimpa kembali ke 1.5 di sini.
						effects = { slowMult = 0.5 },
					},
				},
			},
			{
				id = "c",
				name = "Bertahan",
				theme = "Bertahan di dekat Core: damage yang masuk ke kamu dikurangi.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Damage musuh ke kamu x0.75.",
						effects = { damageTakenMult = 0.75 },
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan 12 jadi 18 stud, dan damage x1.2.",
						range = 18,
						damageMult = 1.2,
					},
					{
						level = TIER_LEVELS[3],
						summary = "Damage musuh ke kamu x0.55.",
						effects = { damageTakenMult = 0.55 },
					},
				},
			},
		},
	},
	weapon_ranged = {
		id = "weapon_ranged",
		name = "Packet Rifle",
		kind = "ranged",
		baseDamage = 14,
		cooldown = 0.25,
		range = 60,
		projectiles = 1,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "buy",
			coinCost = 1500,
		},
		paths = {
			{
				id = "a",
				name = "Sniper",
				theme = "Tembakan jarang, jangkauan sangat jauh, dan akhirnya menembus.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Damage x1.8, tapi jeda x1.6 (0.25 jadi 0.4 detik).",
						damageMult = 1.8,
						cooldownMult = 1.6,
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan 60 jadi 90 stud.",
						range = 90,
					},
					{
						level = TIER_LEVELS[3],
						summary = "Satu tembakan menembus sampai 3 musuh di garis bidik.",
						projectiles = 3,
					},
				},
			},
			{
				id = "b",
				name = "Semburan",
				theme = "Tembakan sangat cepat dengan jangkauan yang dipendekkan.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Jeda 0.25 jadi 0.15 detik, damage x0.8.",
						cooldown = 0.15,
						damageMult = 0.8,
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan 60 jadi 40 stud, damage x1.1 (jadi x0.88 dari dasar).",
						range = 40,
						damageMult = 1.1,
					},
					{
						level = TIER_LEVELS[3],
						summary = "Menembus 2 musuh, dan jedanya jadi 0.12 detik.",
						projectiles = 2,
						cooldown = 0.12,
					},
				},
			},
			{
				id = "c",
				name = "Dukungan",
				theme = "Menandai musuh supaya SELURUH tim memberi damage lebih besar "
					.. "ke musuh itu. Paling kuat di tim 3-4 orang, paling lemah solo "
					.. "-- itu disengaja.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Musuh yang kena ditandai 4 detik: damage dari siapa pun "
							.. "ke musuh itu x1.25.",
						effects = { markMult = 1.25, markSeconds = 4 },
					},
					{
						level = TIER_LEVELS[2],
						summary = "Tandanya jadi x1.4.",
						effects = { markMult = 1.4 },
					},
					{
						level = TIER_LEVELS[3],
						summary = "Tandanya menular ke 2 musuh terdekat dari yang kena.",
						effects = { markSpread = 2 },
					},
				},
			},
		},
	},
	weapon_boss_a = {
		id = "weapon_boss_a",
		name = "Fork Bomb",
		kind = "ranged",
		baseDamage = 30,
		cooldown = 0.6,
		range = 45,
		projectiles = 3,
		maxLevel = MAX_LEVEL,
		acquire = {
			method = "craft",
			materials = { material_a = 5 },
		},
		paths = {
			{
				id = "a",
				name = "Shotgun",
				theme = "Banyak proyektil sekaligus, tapi harus dekat.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Proyektil 3 jadi 5, jangkauan 45 jadi 30 stud.",
						projectiles = 5,
						range = 30,
					},
					{
						level = TIER_LEVELS[2],
						summary = "Damage x1.3.",
						damageMult = 1.3,
					},
					{
						level = TIER_LEVELS[3],
						summary = "Proyektil jadi 7.",
						projectiles = 7,
					},
				},
			},
			{
				id = "b",
				name = "Ledakan",
				theme = "Satu proyektil yang meledak dan mengenai musuh di sekitar "
					.. "titik kena.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Jadi 1 proyektil, tapi titik kena meledak radius 8 stud "
							.. "dengan damage x0.5 ke musuh di sekitarnya.",
						projectiles = 1,
						effects = { splashRadius = 8, splashMult = 0.5 },
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jeda x0.8 (0.6 jadi 0.48 detik).",
						cooldownMult = 0.8,
					},
					{
						level = TIER_LEVELS[3],
						summary = "Radius ledakan jadi 12 stud dan damage-nya x0.75.",
						effects = { splashRadius = 12, splashMult = 0.75 },
					},
				},
			},
			{
				id = "c",
				name = "Jebakan",
				theme = "Titik kena meninggalkan zona yang memperlambat musuh yang "
					.. "melewatinya.",
				tiers = {
					{
						level = TIER_LEVELS[1],
						summary = "Titik kena meninggalkan zona radius 8 stud selama 3 detik; "
							.. "musuh di dalamnya jalan 40% lebih lambat.",
						effects = { zoneRadius = 8, zoneSeconds = 3, zoneSlowMult = 0.6 },
					},
					{
						level = TIER_LEVELS[2],
						summary = "Zona jadi radius 12 stud, dan perlambatannya 55%.",
						effects = { zoneRadius = 12, zoneSlowMult = 0.45 },
					},
					{
						level = TIER_LEVELS[3],
						summary = "Zona ikut memberi 6 damage per detik ke musuh di dalamnya.",
						effects = { zoneDps = 6 },
					},
				},
			},
		},
	},
}

return Weapons
