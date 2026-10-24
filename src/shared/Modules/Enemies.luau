--!strict
-- Enemies.luau — definisi musuh v1 (CONCEPT.md: basic, fast, tank).
--
-- Modul murni: tanpa game:GetService, tanpa `script`, supaya bisa dites Lune.
-- Angka di sini adalah nilai dasar pada wave 1, difficulty normal, 1 player.
-- Penskalaannya ada di Balance.luau, bukan di sini.
--
-- `attackDamage` ditetapkan dari sisi PLAYER, bukan dari sisi base, dan itu
-- disengaja. Base punya 1000 HP dan menerima damage dikali
-- Balance.BASE_DAMAGE_MULT = 0.2, jadi efektif 5000 HP, sementara player cuma
-- 100 -- base 50x lebih tahan. Kalau angkanya disetel supaya "terasa" di base,
-- angka yang sama akan membunuh player dalam satu pukulan. Jadi yang dipakai
-- sebagai patokan: berapa pukulan sampai player mati.
--
--   basic  25 / 1.2s  -> 4 pukulan (4.8s), 4.2 DPS ke base
--   fast   15 / 0.8s  -> 7 pukulan (5.6s), 3.8 DPS ke base
--   tank   60 / 1.5s  -> 2 pukulan (1.5s), 8.0 DPS ke base
--
-- Bacaannya di sisi base: satu `basic` lolos sepanjang wave (~60 detik)
-- memakan seperempat base, satu `tank` memakan separuh. `tank` membunuh player
-- dalam dua pukulan memang kasar, dan itu yang membuat dia akhirnya jadi
-- "yang tidak boleh lolos" -- dulu dia cuma 15 dari 1000, praktis tanpa arti.
-- Yang membuatnya adil: kecepatannya 5 stud/detik, paling lambat di game, jadi
-- dia bisa dihindari.

local Types = require("./Types")

export type EnemyDef = Types.EnemyDef

local Enemies: { [string]: EnemyDef } = {
	basic = {
		id = "basic",
		name = "Pop-up Swarmling",
		analogy = "Adware",
		baseHp = 100,
		speed = 8,
		attackDamage = 25,
		attackInterval = 1.2,
		targeting = { prefer = "base", aggroRadius = 14, leashRadius = 21 },
		matchCoins = 5,
	},
	fast = {
		id = "fast",
		name = "Worm Runner",
		analogy = "Worm",
		baseHp = 60,
		speed = 16,
		attackDamage = 15,
		attackInterval = 0.8,
		targeting = { prefer = "player", aggroRadius = 25, leashRadius = 37.5 },
		matchCoins = 7,
	},
	tank = {
		id = "tank",
		name = "Rootkit Hulk",
		analogy = "Rootkit",
		baseHp = 400,
		speed = 5,
		attackDamage = 60,
		attackInterval = 1.5,
		targeting = { prefer = "base", aggroRadius = 8, leashRadius = 12 },
		matchCoins = 15,
	},
}

return Enemies
