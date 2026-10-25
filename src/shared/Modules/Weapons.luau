--!strict
-- Weapons.luau — definisi senjata v1 (CONCEPT.md: 3 senjata, level 1 sampai 10).
--
-- Modul murni: tanpa game:GetService, tanpa `script`. Stat per level dan harga
-- upgrade dihitung Balance.luau dari angka dasar di sini.
--
-- Soal `paths`: tiga alur upgrade per senjata, dipilih sekali di level 4 dan
-- permanen (ARENA_REDESIGN.md bagian 3). Yang ada di bawah ini **kerangkanya**
-- -- id, nama, tema, dan tiga tingkat di level 4, 7, dan 10 -- dan tidak satu
-- pun tingkat yang mengubah stat apa pun. Itu disengaja, bukan pekerjaan yang
-- lupa diselesaikan: lampiran A rancangan menulis angkanya dengan judul "belum
-- diputuskan", dan langkah 7 yang memutuskannya.
--
-- Konsekuensinya yang harus diketahui pembaca: memilih alur SEKARANG tidak
-- mengubah apa pun selain mengunci pilihan itu selamanya. `summary` tiap
-- tingkat sudah menyebut apa yang AKAN terbuka, karena panel pemilihan alur
-- membacanya -- jadi kalau salah satu baris di bawah berjanji sesuatu yang
-- tidak dilakukan `Balance.weaponStats`, itu janji yang bohong ke pemain,
-- bukan placeholder yang tidak apa-apa. Langkah 7 mengisi `damageMult`,
-- `cooldownMult`, `range`, `projectiles`, dan `effects` sampai setiap baris
-- `summary` benar.
--
-- Temanya tidak boleh diubah sembarangan sesudah ada pemain yang memilih:
-- `save.path` menyimpan `id`-nya, jadi mengganti arti alur "a" berarti semua
-- pemain yang pernah memilih "a" mendapat alur yang berbeda tanpa pernah
-- menyetujuinya.

local Types = require("./Types")

export type WeaponDef = Types.WeaponDef

local MAX_LEVEL = 10

-- Level tempat tiap tingkat alur terbuka. Dipakai sebagai angka, bukan
-- diulang-ulang sebagai literal, supaya ketiga senjata tidak bisa berbeda
-- tanpa ada yang menyadarinya.
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
						summary = "Damage naik banyak, jeda antar serangan ikut naik.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Kerucut ayunan jadi jauh lebih lebar.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Satu ayunan mengenai sampai tiga musuh.",
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
						summary = "Jeda antar serangan turun banyak.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Musuh yang kena ikut diperlambat sebentar.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Jeda turun lagi, dan perlambatannya jadi lebih berat.",
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
						summary = "Damage yang masuk ke kamu dikurangi.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan dan damage naik.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Damage yang masuk dikurangi lebih banyak lagi.",
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
						summary = "Damage naik banyak, jeda antar tembakan ikut naik.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan naik jauh.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Satu tembakan menembus sampai tiga musuh.",
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
						summary = "Jeda antar tembakan turun banyak, damage per tembakan turun.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jangkauan dipendekkan, damage naik sedikit.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Menembus dua musuh, dan jedanya turun lagi.",
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
						summary = "Musuh yang kena ditandai; damage dari siapa pun ke musuh "
							.. "itu naik sebentar.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Tandanya menaikkan damage lebih banyak.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Tandanya menular ke dua musuh terdekat.",
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
						summary = "Jumlah proyektil naik, jangkauan dipendekkan.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Damage naik.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Jumlah proyektil naik lagi.",
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
						summary = "Jadi satu proyektil, tapi titik kena meledak ke musuh "
							.. "di sekitarnya.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Jeda antar tembakan turun.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Radius dan damage ledakannya naik.",
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
						summary = "Titik kena meninggalkan zona perlambat beberapa detik.",
					},
					{
						level = TIER_LEVELS[2],
						summary = "Radius zonanya naik, perlambatannya lebih berat.",
					},
					{
						level = TIER_LEVELS[3],
						summary = "Zonanya ikut memberi damage kecil per detik.",
					},
				},
			},
		},
	},
}

return Weapons
