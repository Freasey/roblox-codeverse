--!strict
-- Bosses.luau — definisi boss v1 (CONCEPT.md: boss_splitter wave 5,
-- boss_locker wave 10) beserta teks kartu info yang muncul setelah boss kalah.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Types = require("./Types")

export type BossDef = Types.BossDef

local Bosses: { [string]: BossDef } = {
	boss_splitter = {
		id = "boss_splitter",
		name = "Splitter",
		analogy = "Worm",
		wave = 5,
		baseHp = 2500,
		speed = 7,
		attackDamage = 80,
		attackInterval = 2.0,
		-- Boss berjalan lurus ke base dan tidak memburu pemain. Aggro kecil,
		-- bukan nol: tetap memukul yang menghalanginya tepat di depan base.
		-- Rancangan tidak menetapkan angka boss, jadi dua baris ini pilihan
		-- implementasi, bukan keputusan desain.
		targeting = { prefer = "base", aggroRadius = 10, leashRadius = 15 },
		matchCoins = 120,
		dropMaterial = "material_a",
		mechanic = {
			kind = "splitter",
			thresholds = { 0.66, 0.33 },
			spawnEnemyId = "fast",
			spawnCount = 4,
		},
		infoCard = {
			title = "Worm",
			body = "Worm menggandakan dirinya sendiri dan menyebar ke komputer lain "
				.. "lewat jaringan, tanpa perlu kamu membuka file apa pun. Itu sebabnya "
				.. "Splitter pecah jadi banyak musuh kecil saat HP-nya turun.",
			prevention = {
				"Pasang update sistem operasi begitu tersedia.",
				"Nyalakan firewall dan tutup port yang tidak dipakai.",
				"Pisahkan jaringan tamu dari jaringan kerja.",
			},
		},
	},
	boss_locker = {
		id = "boss_locker",
		name = "Locker",
		analogy = "Ransomware",
		wave = 10,
		baseHp = 6000,
		speed = 6,
		attackDamage = 120,
		attackInterval = 2.0,
		targeting = { prefer = "base", aggroRadius = 10, leashRadius = 15 },
		matchCoins = 250,
		dropMaterial = "material_b",
		mechanic = {
			kind = "locker",
			locksShop = true,
			summonEnemyId = "basic",
			summonCount = 3,
			summonInterval = 8,
		},
		infoCard = {
			title = "Ransomware",
			body = "Ransomware mengunci file korban lalu meminta tebusan untuk membukanya. "
				.. "Locker meniru itu dengan mengunci Toko Match: selama dia hidup, "
				.. "kamu tidak bisa membeli apa pun.",
			prevention = {
				"Simpan backup rutin di tempat yang terpisah dari jaringan.",
				"Jangan buka lampiran atau tautan dari pengirim yang tidak dikenal.",
				"Batasi hak akses akun, jangan semua orang jadi administrator.",
			},
		},
	},
}

return Bosses
