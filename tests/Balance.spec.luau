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
-- Cash per wave
-- --------------------------------------------------------------------------
--
-- Cash sekarang masuk PER PEMAIN, bukan ke satu kolam tim, sejak dia jadi mata
-- uang upgrade senjata. Pengali jumlah pemain yang dulu ada di sini (solo x4,
-- duo x2, sisanya x1) ikut hilang bersamanya: gunanya menyamakan kolam TIM
-- lintas jumlah pemain, dan yang disamakan sekarang anggaran per pemain.

local function isBossWave(wave: number): boolean
	local def = Waves.get(wave)
	return def ~= nil and def.bossId ~= nil
end

table.insert(cases, {
	name = "kurva cash per wave cocok dengan rancangan, wave boss dikali dua",
	run = function()
		local expected = { 200, 250, 300, 350, 800, 450, 500, 550, 600, 1300 }
		for wave, want in expected do
			local got = Balance.waveCash(wave, isBossWave(wave))
			assert(got == want, string.format("wave %d harus %d cash, dapat %d", wave, want, got))
		end
	end,
})

table.insert(cases, {
	name = "cash per wave tidak lagi bergantung pada jumlah pemain",
	run = function()
		-- Yang dijaga di sini bukan rumusnya tapi BENTUK fungsinya: dia cuma
		-- menerima wave dan boss. Kalau nanti ada yang menambahkan kembali
		-- argumen jumlah pemain, satu pemain di tim berempat akan kembali
		-- kebagian seperempat anggaran untuk barang yang dipakainya sendiri.
		assert(Balance.playerCountMultiplier == nil, "pengali jumlah pemain harus sudah hilang")
		assert(Balance.waveReward == nil, "waveReward harus sudah diganti waveCash")
	end,
})

table.insert(cases, {
	name = "wave boss dikenali dari Waves, bukan dari nomor yang ditulis tangan",
	run = function()
		-- Kalau boss baru ditambahkan nanti dengan mengisi `bossId`, cash-nya
		-- ikut terkali dua tanpa menyentuh Balance.
		for wave = 1, 10 do
			if isBossWave(wave) then
				local withBoss = Balance.waveCash(wave, true)
				local withoutBoss = Balance.waveCash(wave, false)
				assert(
					withBoss == withoutBoss * 2,
					string.format("wave boss %d harus dua kali wave biasa", wave)
				)
			end
		end
	end,
})

table.insert(cases, {
	name = "satu run penuh memberi 5300 cash per pemain",
	run = function()
		-- Angka ini anggaran yang dipakai `Balance.matchUpgradePrice` untuk
		-- memilih kurvanya. Kalau salah satu digeser tanpa yang lain, upgrade
		-- jadi terlalu murah atau tidak pernah terjangkau -- dan dua-duanya cuma
		-- terasa sebagai "balancing yang aneh", bukan sebagai angka yang salah.
		local sum = 0
		for wave = 1, 10 do
			sum += Balance.waveCash(wave, isBossWave(wave))
		end
		assert(sum == 5300, string.format("harus 5300 per pemain, dapat %d", sum))
	end,
})

table.insert(cases, {
	name = "cash naik monoton antar wave biasa, dan tidak pernah negatif",
	run = function()
		local previous = 0
		for wave = 1, 10 do
			local reward = Balance.waveCash(wave, false)
			assert(reward > previous, string.format("wave %d harus di atas sebelumnya", wave))
			previous = reward
		end
	end,
})

table.insert(cases, {
	name = "nomor wave tidak wajar memberi nol, bukan angka negatif atau NaN",
	run = function()
		for _, bad in { 0, -5, 0 / 0, math.huge } do
			local reward = Balance.waveCash(bad, false)
			assert(
				reward == 0,
				string.format("wave %s harus 0, dapat %s", tostring(bad), tostring(reward))
			)
		end
	end,
})

-- Harga upgrade di dalam match ----------------------------------------------

table.insert(cases, {
	name = "harga upgrade dalam match naik dan totalnya sesuai anggaran satu run",
	run = function()
		-- Kurvanya dipilih terhadap anggaran yang benar-benar masuk: 5.300 dari
		-- hadiah wave ditambah cash dari membunuh. Totalnya 5.951 untuk naik dari
		-- level 1 ke 10, jadi level maksimum bisa dicapai dalam satu run tapi
		-- cuma kalau hampir seluruh cash ditumpahkan ke satu senjata.
		local expected = { 150, 202, 273, 369, 498, 672, 908, 1225, 1654 }
		local sum = 0
		for level, want in expected do
			local got = Balance.matchUpgradePrice(level)
			assert(got == want, string.format("level %d harus %d cash, dapat %d", level, want, got))
			sum += got
		end
		assert(sum == 5951, string.format("total 1 ke 10 harus 5951, dapat %d", sum))
	end,
})

table.insert(cases, {
	name = "level tidak wajar memberi harga tak terhingga, bukan gratis",
	run = function()
		-- Nol atau NaN yang pulang sebagai 0 berarti upgrade gratis, dan itu
		-- tidak akan pernah dilaporkan oleh pemain yang diuntungkan.
		for _, bad in { 0, -4, 0 / 0 } do
			assert(
				Balance.matchUpgradePrice(bad) == math.huge,
				string.format("level %s harus tak terhingga", tostring(bad))
			)
		end
	end,
})

-- Stat senjata dan alur upgrade ---------------------------------------------

-- Senjata sintetis dengan angka alur yang NYATA, sementara `Weapons.luau` masih
-- mengirim tingkat tanpa angka sama sekali (langkah 7 yang mengisinya). Tanpa
-- fixture ini, penggabungan tingkat alur di `weaponStats` tidak teruji sampai
-- angkanya diputuskan -- dan kerangka yang tidak teruji bukan kerangka, cuma
-- kode yang kebetulan belum dipanggil.
local function fakeWeapon()
	return {
		id = "weapon_uji",
		name = "Senjata Uji",
		kind = "ranged",
		baseDamage = 100,
		cooldown = 1,
		range = 50,
		projectiles = 1,
		maxLevel = 10,
		acquire = { method = "default" },
		paths = {
			{
				id = "a",
				name = "Alur A",
				theme = "uji",
				tiers = {
					{
						level = 4,
						summary = "damage x2, cooldown x2, range 80",
						damageMult = 2,
						cooldownMult = 2,
						range = 80,
						effects = { slow = 0.3 },
					},
					{
						level = 7,
						summary = "range 120, tembus 2",
						range = 120,
						projectiles = 2,
					},
					{
						level = 10,
						summary = "cooldown x0.5, slow lebih berat",
						cooldownMult = 0.5,
						effects = { slow = 0.6 },
					},
				},
			},
			{ id = "b", name = "Alur B", theme = "uji", tiers = {} },
		},
	}
end

table.insert(cases, {
	name = "tanpa alur, stat senjata sama dengan stat dasarnya",
	run = function()
		local def = fakeWeapon()
		local stats = Balance.weaponStats(def, { level = 1, path = "none" })
		assert(stats.damage == def.baseDamage, "damage " .. stats.damage)
		assert(stats.cooldown == def.cooldown, "cooldown " .. stats.cooldown)
		assert(stats.range == def.range, "range " .. stats.range)
		assert(stats.projectiles == def.projectiles, "proyektil " .. stats.projectiles)
		assert(next(stats.effects) == nil, "effects harus kosong")
	end,
})

table.insert(cases, {
	name = "alur yang dipilih tidak berlaku sebelum level tingkatnya",
	run = function()
		-- Level 1 sampai 3 itu masa percobaan: alur boleh tersimpan tapi tidak
		-- boleh mengubah satu angka pun sampai level 4.
		local def = fakeWeapon()
		local stats = Balance.weaponStats(def, { level = 3, path = "a" })
		assert(stats.damage == Balance.weaponDamage(def, 3), "damage " .. stats.damage)
		assert(stats.cooldown == def.cooldown, "cooldown " .. stats.cooldown)
		assert(stats.range == def.range, "range " .. stats.range)
	end,
})

table.insert(cases, {
	name = "tingkat alur berlaku tepat di levelnya",
	run = function()
		local def = fakeWeapon()
		local stats = Balance.weaponStats(def, { level = 4, path = "a" })
		assert(stats.damage == Balance.weaponDamage(def, 4) * 2, "damage " .. stats.damage)
		assert(stats.cooldown == 2, "cooldown " .. stats.cooldown)
		assert(stats.range == 80, "range " .. stats.range)
		assert(stats.effects.slow == 0.3, "slow " .. tostring(stats.effects.slow))
	end,
})

table.insert(cases, {
	name = "tingkat yang lebih tinggi menumpuk pengali dan menimpa nilai absolut",
	run = function()
		-- Yang dipatok di sini bentuk penggabungannya, dan dua-duanya pernah
		-- salah di implementasi yang naif: pengali yang DITIMPA alih-alih
		-- ditumpuk (cooldown jadi 0.5 bukan 1), dan nilai absolut yang
		-- DITUMPUK alih-alih ditimpa (range jadi 80*120).
		local def = fakeWeapon()
		local stats = Balance.weaponStats(def, { level = 10, path = "a" })
		assert(stats.cooldown == 1, "cooldown harus 1 x2 x0.5 = 1, dapat " .. stats.cooldown)
		assert(stats.range == 120, "range harus 120 (tingkat 2 menimpa 80)")
		assert(stats.projectiles == 2, "proyektil " .. stats.projectiles)
		assert(stats.effects.slow == 0.6, "tingkat 3 harus menimpa slow tingkat 1")
	end,
})

table.insert(cases, {
	name = "alur yang tidak dikenal diperlakukan seperti belum memilih",
	run = function()
		-- Data lama yang menyimpan id alur yang sudah dihapus. Yang TIDAK boleh
		-- terjadi: jatuh ke alur pertama, karena pemain lalu mendapat alur yang
		-- tidak pernah dia pilih tanpa satu pesan pun.
		local def = fakeWeapon()
		local stats = Balance.weaponStats(def, { level = 10, path = "alur_yang_dihapus" })
		assert(stats.damage == Balance.weaponDamage(def, 10), "damage " .. stats.damage)
		assert(stats.range == def.range, "range " .. stats.range)
		assert(next(stats.effects) == nil, "effects harus kosong")
	end,
})

table.insert(cases, {
	name = "cooldown tidak pernah nol walau pengali alurnya rusak",
	run = function()
		-- Cooldown nol berarti serangan tanpa batas: gerbang di CombatService
		-- memakai `now - last < cooldown`, dan itu selalu false untuk nol.
		local def = fakeWeapon()
		def.paths[1].tiers[1].cooldownMult = 0
		local stats = Balance.weaponStats(def, { level = 4, path = "a" })
		assert(stats.cooldown > 0, "cooldown " .. stats.cooldown)
	end,
})

table.insert(cases, {
	name = "level di luar rentang di-clamp sebelum alur diterapkan",
	run = function()
		local def = fakeWeapon()
		local tinggi = Balance.weaponStats(def, { level = 999, path = "a" })
		local maks = Balance.weaponStats(def, { level = def.maxLevel, path = "a" })
		assert(tinggi.damage == maks.damage, "level 999 harus sama dengan level maks")

		local rendah = Balance.weaponStats(def, { level = 0, path = "none" })
		assert(rendah.damage == def.baseDamage, "level 0 harus diperlakukan level 1")
	end,
})

table.insert(cases, {
	name = "ketiga senjata nyata punya tiga alur dengan tingkat di level yang sama",
	run = function()
		-- Yang dijaga: menambah alur keempat ke satu senjata, atau menggeser
		-- tingkat satu senjata ke level yang berbeda, tidak boleh lolos tanpa
		-- disadari -- pemain tidak punya cara tahu kalau Fork Bomb bercabang di
		-- level 5 sementara dua senjata lain di level 4.
		for _, def in Weapons do
			assert(#def.paths == 3, string.format("%s punya %d alur", def.id, #def.paths))
			local ids: { [string]: boolean } = {}
			for _, path in def.paths do
				assert(not ids[path.id], string.format("%s punya alur %s dobel", def.id, path.id))
				ids[path.id] = true
				assert(
					#path.tiers == 3,
					string.format("%s/%s punya %d tingkat", def.id, path.id, #path.tiers)
				)
				assert(
					path.tiers[1].level == Balance.PATH_BRANCH_LEVEL,
					"tingkat 1 bukan di titik percabangan"
				)
				for index = 2, #path.tiers do
					assert(
						path.tiers[index].level > path.tiers[index - 1].level,
						string.format("%s/%s tingkat %d tidak lebih tinggi", def.id, path.id, index)
					)
				end
				for _, tier in path.tiers do
					assert(
						tier.summary ~= "",
						"tingkat tanpa summary tidak bisa ditampilkan ke pemain"
					)
					assert(
						tier.level <= def.maxLevel,
						"tingkat di atas level maksimum tidak bisa dicapai"
					)
				end
			end
		end
	end,
})

table.insert(cases, {
	name = "cooldown absolut menimpa pengali, dan pengali tingkat lain tetap menumpuk",
	run = function()
		-- Bentuk yang dipakai alur "ayunan cepat": tingkat 1 menyebut target
		-- 0.32, tingkat 3 menyebut 0.25. Dua-duanya absolut, jadi yang terakhir
		-- yang berlaku -- bukan 0.32 x 0.25.
		local def = fakeWeapon()
		def.paths[1].tiers[1] = { level = 4, summary = "cooldown 0.32", cooldown = 0.32 }
		def.paths[1].tiers[2] = { level = 7, summary = "damage x1.1", damageMult = 1.1 }
		def.paths[1].tiers[3] = { level = 10, summary = "cooldown 0.25", cooldown = 0.25 }

		local l4 = Balance.weaponStats(def, { level = 4, path = "a" })
		assert(l4.cooldown == 0.32, "cooldown L4 " .. l4.cooldown)

		local l10 = Balance.weaponStats(def, { level = 10, path = "a" })
		assert(l10.cooldown == 0.25, "cooldown L10 harus 0.25, dapat " .. l10.cooldown)
		assert(
			math.abs(l10.damage - Balance.weaponDamage(def, 10) * 1.1) < 1e-9,
			"pengali damage tingkat 2 harus tetap berlaku, dapat " .. l10.damage
		)
	end,
})

table.insert(cases, {
	name = "di satu tingkat, cooldown absolut jadi kata terakhir atas pengalinya",
	run = function()
		-- Tingkat yang memakai dua-duanya sekaligus sebaiknya tidak ada, tapi
		-- kalau ada, hasilnya harus angka yang tertulis -- bukan angka itu dikali
		-- pengalinya, yang membuat "cooldown 0.4" jadi bukan 0.4.
		local def = fakeWeapon()
		def.paths[1].tiers[1] = {
			level = 4,
			summary = "dua-duanya",
			cooldownMult = 3,
			cooldown = 0.4,
		}
		local stats = Balance.weaponStats(def, { level = 4, path = "a" })
		assert(stats.cooldown == 0.4, "cooldown " .. stats.cooldown)
	end,
})

table.insert(cases, {
	name = "setiap kunci effects yang dipakai alur ada di kosakata Balance",
	run = function()
		-- Kunci di tabel `{ [string]: number }` tidak dijaga type checker, jadi
		-- `slowMult` yang salah tulis jadi `slowmult` akan diam-diam tidak pernah
		-- terbaca -- dan gejalanya cuma "alur itu tidak terasa", yang mudah
		-- disalahartikan sebagai soal balancing. Baris ini yang menangkapnya.
		local known: { [string]: boolean } = {}
		for _, key in Balance.PATH_EFFECT_KEYS do
			assert(not known[key], "kunci " .. key .. " ditulis dobel di kosakata")
			known[key] = true
		end

		for _, def in Weapons do
			for _, path in def.paths do
				for _, tier in path.tiers do
					for key in tier.effects or {} do
						assert(
							known[key],
							string.format(
								"%s/%s L%d memakai kunci effects `%s` yang tidak ada di Balance.PATH_EFFECT_KEYS",
								def.id,
								path.id,
								tier.level,
								key
							)
						)
					end
				end
			end
		end
	end,
})

table.insert(cases, {
	name = "setiap kunci di kosakata Balance benar-benar dipakai satu alur",
	run = function()
		-- Arah sebaliknya dari baris di atas, dan menangkap kegagalan yang
		-- berbeda: kunci yang TERTINGGAL di daftar sesudah alur yang memakainya
		-- diubah. Kosakata mati tidak merusak apa pun yang berjalan, tapi dia
		-- tetap dibaca sebagai janji -- dan pembaca berikutnya akan menulis kode
		-- yang membacanya, lalu bingung kenapa tidak pernah terpanggil.
		local used: { [string]: boolean } = {}
		for _, def in Weapons do
			for _, path in def.paths do
				for _, tier in path.tiers do
					for key in tier.effects or {} do
						used[key] = true
					end
				end
			end
		end

		for _, key in Balance.PATH_EFFECT_KEYS do
			assert(
				used[key],
				string.format(
					"`%s` ada di Balance.PATH_EFFECT_KEYS tapi tidak dipakai satu alur pun di Weapons.luau",
					key
				)
			)
		end
	end,
})

return cases
