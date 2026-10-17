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
Balance.UPGRADE_BASE_PRICE = 50
Balance.UPGRADE_PRICE_GROWTH = 1.35
Balance.DAMAGE_PER_LEVEL = 0.12

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

return Balance
