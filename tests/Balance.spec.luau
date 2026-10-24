-- Balance.spec.luau — rumus angka di docs/DEVELOPMENT_PLAN.md bagian 3.5.
-- Yang dites bukan nilai persisnya (itu akan disetel setelah playtest), tapi
-- sifat yang harus tetap benar berapa pun angkanya: monoton naik, kalah < menang.

local Balance = require("../src/shared/Modules/Balance")
local Enemies = require("../src/shared/Modules/Enemies")
local Bosses = require("../src/shared/Modules/Bosses")
local Weapons = require("../src/shared/Modules/Weapons")
local Difficulties = require("../src/shared/Modules/Difficulties")
local Waves = require("../src/shared/Modules/Waves")

local normal = Difficulties.normal
local hard = Difficulties.hard

local cases = {}

table.insert(cases, {
	name = "HP musuh naik tiap wave",
	run = function()
		for _, def in Enemies do
			local previous = -math.huge
			for wave = 1, 10 do
				local hp = Balance.enemyHp(def, wave, normal, 1)
				assert(
					hp > previous,
					string.format("%s: HP wave %d tidak lebih besar dari sebelumnya", def.id, wave)
				)
				previous = hp
			end
		end
	end,
})

table.insert(cases, {
	name = "HP wave 1 sama dengan baseHp pada normal, 1 player",
	run = function()
		assert(
			Balance.enemyHp(Enemies.basic, 1, normal, 1) == Enemies.basic.baseHp,
			"ada pengali tak terduga di wave 1"
		)
	end,
})

table.insert(cases, {
	name = "difficulty hard bikin musuh lebih tebal dari normal",
	run = function()
		assert(
			Balance.enemyHp(Enemies.tank, 3, hard, 2) > Balance.enemyHp(Enemies.tank, 3, normal, 2),
			"hpMult hard tidak berlaku"
		)
		assert(
			Balance.bossHp(Bosses.boss_splitter, hard, 1)
				> Balance.bossHp(Bosses.boss_splitter, normal, 1),
			"hpMult hard tidak berlaku ke boss"
		)
	end,
})

table.insert(cases, {
	name = "HP musuh naik kalau player bertambah",
	run = function()
		local previous = -math.huge
		for playerCount = 1, 4 do
			local hp = Balance.enemyHp(Enemies.basic, 5, normal, playerCount)
			assert(hp > previous, "HP tidak naik saat player bertambah")
			previous = hp
		end
	end,
})

table.insert(cases, {
	name = "jumlah musuh naik tiap wave dan tiap tambahan player",
	run = function()
		for playerCount = 1, 4 do
			local previous = -math.huge
			for wave = 1, 10 do
				local count = Balance.enemyCount(wave, playerCount)
				assert(count > previous, "jumlah musuh tidak naik antar wave")
				assert(count == math.floor(count), "jumlah musuh harus bulat")
				previous = count
			end
		end
		assert(
			Balance.enemyCount(5, 4) > Balance.enemyCount(5, 1),
			"jumlah musuh tidak naik dengan jumlah player"
		)
	end,
})

table.insert(cases, {
	name = "reward kalah lebih kecil dari reward menang",
	run = function()
		for wave = 1, 10 do
			assert(
				Balance.rewardCoins(wave, false, normal) < Balance.rewardCoins(wave, true, normal),
				"koin kalah tidak lebih kecil dari koin menang"
			)
			assert(
				Balance.rewardXp(wave, false) < Balance.rewardXp(wave, true),
				"xp kalah tidak lebih kecil dari xp menang"
			)
		end
	end,
})

table.insert(cases, {
	name = "kalah tetap memberi reward",
	run = function()
		assert(Balance.rewardCoins(1, false, normal) > 0, "kalah di wave 1 tidak dapat koin")
		assert(Balance.rewardXp(1, false) > 0, "kalah di wave 1 tidak dapat xp")
	end,
})

table.insert(cases, {
	name = "difficulty hard memberi koin lebih banyak",
	run = function()
		assert(
			Balance.rewardCoins(10, true, hard) > Balance.rewardCoins(10, true, normal),
			"rewardMult hard tidak berlaku"
		)
	end,
})

table.insert(cases, {
	name = "harga upgrade naik monoton",
	run = function()
		local previous = -math.huge
		for level = 1, 9 do
			local price = Balance.upgradePrice(level)
			assert(price > previous, string.format("harga dari level %d tidak naik", level))
			assert(price == math.floor(price), "harga harus bulat")
			previous = price
		end
	end,
})

table.insert(cases, {
	name = "damage senjata naik monoton sampai level maksimum",
	run = function()
		for _, def in Weapons do
			local previous = -math.huge
			for level = 1, def.maxLevel do
				local damage = Balance.weaponDamage(def, level)
				assert(
					damage > previous,
					string.format("%s: damage level %d tidak naik", def.id, level)
				)
				previous = damage
			end
			assert(
				Balance.weaponDamage(def, 1) == def.baseDamage,
				"damage level 1 bukan baseDamage"
			)
		end
	end,
})

table.insert(cases, {
	name = "batas musuh aktif cukup besar untuk wave terberat",
	run = function()
		-- Batas ini (bagian 1.3) menahan spawn, bukan membuangnya, jadi wave
		-- yang jumlahnya di atas batas tetap bisa diselesaikan. Yang perlu
		-- dicek adalah batasnya tidak lebih kecil dari jumlah musuh satu wave
		-- paling ringan — kalau sampai begitu, wave 1 solo pun langsung
		-- mengantre dan prototipe terasa macet.
		assert(Balance.MAX_ACTIVE_ENEMIES > 0, "batas musuh aktif harus positif")
		assert(
			Balance.MAX_ACTIVE_ENEMIES >= Balance.enemyCount(1, 1),
			"wave 1 solo seharusnya tidak sampai mengantre"
		)
	end,
})

table.insert(cases, {
	name = "wave terberat memang melebihi batas musuh aktif, jadi antrian wajib ada",
	run = function()
		-- Ini bukan test atas kode, tapi atas asumsinya: kalau wave terberat
		-- ternyata di bawah batas, antrian spawn jadi kode mati dan bagian 1.3
		-- perlu dibaca ulang.
		local heaviest = Balance.enemyCount(10, 4)
		assert(
			heaviest > Balance.MAX_ACTIVE_ENEMIES,
			string.format(
				"wave 10 x 4 player cuma %d musuh, di bawah batas %d — antrian jadi tidak pernah terpakai",
				heaviest,
				Balance.MAX_ACTIVE_ENEMIES
			)
		)
	end,
})

table.insert(cases, {
	name = "konstanta gerak dan spawn masuk akal",
	run = function()
		assert(Balance.SPAWN_INTERVAL > 0, "jeda spawn harus positif")
		assert(Balance.CORE_MAX_HP > 0, "HP core harus positif")

		-- WAYPOINT_REACH harus lebih besar dari perpindahan satu frame musuh
		-- tercepat, kalau tidak musuh bisa melewati waypoint dan berputar.
		local fastest = 0
		for _, def in Enemies do
			fastest = math.max(fastest, def.speed)
		end
		local perFrameAt30Fps = fastest / 30
		assert(
			Balance.WAYPOINT_REACH > perFrameAt30Fps,
			string.format(
				"WAYPOINT_REACH %.2f lebih kecil dari perpindahan satu frame (%.2f stud pada 30 fps)",
				Balance.WAYPOINT_REACH,
				perFrameAt30Fps
			)
		)
	end,
})

-- --------------------------------------------------------------------------
-- Hadiah koin match per wave
-- --------------------------------------------------------------------------

local function isBossWave(wave: number): boolean
	local def = Waves.get(wave)
	return def ~= nil and def.bossId ~= nil
end

table.insert(cases, {
	name = "pengali jumlah pemain: solo x4, duo x2, 3 atau lebih x1",
	run = function()
		assert(Balance.playerCountMultiplier(1) == 4, "solo x4")
		assert(Balance.playerCountMultiplier(2) == 2, "duo x2")
		assert(Balance.playerCountMultiplier(3) == 1, "trio x1")
		assert(Balance.playerCountMultiplier(4) == 1, "empat x1")
	end,
})

table.insert(cases, {
	name = "jumlah pemain tidak masuk akal diperlakukan sebagai solo, bukan nol",
	run = function()
		-- Hadiah yang terlalu besar langsung terlihat saat playtest; hadiah yang
		-- diam-diam hilang tidak.
		for _, bad in { 0, -3, 0 / 0 } do
			assert(
				Balance.playerCountMultiplier(bad) == 4,
				string.format("playerCount %s harus jatuh ke x4", tostring(bad))
			)
		end
	end,
})

table.insert(cases, {
	name = "kurva hadiah per wave cocok dengan rancangan, dengan wave boss dikali dua",
	run = function()
		-- Dites pada pengali x1 (3-4 pemain) supaya yang diuji kurvanya sendiri,
		-- bukan kurva dikali pengali pemain.
		local expected = { 200, 250, 300, 350, 800, 450, 500, 550, 600, 1300 }
		for wave, want in expected do
			local got = Balance.waveReward(wave, 3, isBossWave(wave))
			assert(got == want, string.format("wave %d harus %d koin, dapat %d", wave, want, got))
		end
	end,
})

table.insert(cases, {
	name = "wave boss dikenali dari Waves, bukan dari nomor yang ditulis tangan",
	run = function()
		-- Kalau boss baru ditambahkan nanti dengan mengisi `bossId`, hadiahnya
		-- ikut terkali dua tanpa menyentuh Balance. Yang diuji di sini: wave
		-- yang punya bossId memang dapat dua kali wave tetangganya yang tidak.
		for wave = 1, 10 do
			if isBossWave(wave) then
				local withBoss = Balance.waveReward(wave, 3, true)
				local withoutBoss = Balance.waveReward(wave, 3, false)
				assert(
					withBoss == withoutBoss * 2,
					string.format("wave boss %d harus dua kali wave biasa", wave)
				)
			end
		end
	end,
})

table.insert(cases, {
	name = "total sepuluh wave: 5300 untuk tim besar, 21200 untuk solo",
	run = function()
		-- Angka inti rancangan bagian 6. 21.200 solo itu yang membuat batas
		-- jumlah di Toko Match harus diganti harga yang naik -- toko yang semua
		-- itemnya dibatasi cuma bisa menyerap 3.450.
		local function total(playerCount: number): number
			local sum = 0
			for wave = 1, 10 do
				sum += Balance.waveReward(wave, playerCount, isBossWave(wave))
			end
			return sum
		end
		assert(total(3) == 5300, string.format("tim 3-4 harus 5300, dapat %d", total(3)))
		assert(total(2) == 10600, string.format("duo harus 10600, dapat %d", total(2)))
		assert(total(1) == 21200, string.format("solo harus 21200, dapat %d", total(1)))
	end,
})

table.insert(cases, {
	name = "hadiah naik monoton antar wave biasa, dan tidak pernah negatif",
	run = function()
		local previous = 0
		for wave = 1, 10 do
			local reward = Balance.waveReward(wave, 3, false)
			assert(reward > previous, string.format("wave %d harus di atas sebelumnya", wave))
			previous = reward
		end
	end,
})

table.insert(cases, {
	name = "nomor wave tidak wajar memberi nol, bukan angka negatif atau NaN",
	run = function()
		for _, bad in { 0, -5, 0 / 0, math.huge } do
			local reward = Balance.waveReward(bad, 1, false)
			assert(
				reward == 0,
				string.format("wave %s harus 0, dapat %s", tostring(bad), tostring(reward))
			)
		end
	end,
})

return cases
