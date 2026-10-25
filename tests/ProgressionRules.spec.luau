-- ProgressionRules.spec.luau — syarat upgrade, beli, craft (bagian 3.6), dan
-- kurva level (M5).
--
-- Ini bagian yang paling mahal kalau salah, karena kesalahannya TERSIMPAN:
-- koin yang terpotong dua kali, senjata yang terkunci selamanya, atau `hard`
-- yang tidak pernah terbuka semuanya bertahan di DataStore sampai ada yang
-- memperbaiki datanya satu per satu. Jadi syaratnya diperiksa di sini, bukan
-- dengan mencoba-coba di Studio.

local Balance = require("../src/shared/Modules/Balance")
local Difficulties = require("../src/shared/Modules/Difficulties")
local ProgressionRules = require("../src/shared/Modules/ProgressionRules")
local Weapons = require("../src/shared/Modules/Weapons")

local cases = {}

local function newData(overrides)
	local data = {
		schemaVersion = 1,
		coins = 0,
		level = 1,
		xp = 0,
		playtimeSeconds = 0,
		lastLogin = 0,
		equippedWeapon = "weapon_starter",
		weapons = { weapon_starter = { level = 1, path = "none" } },
		materials = {},
		unlockedDifficulties = { normal = true },
		clears = {},
		stats = { highestWave = 0, matchesPlayed = 0, wins = 0 },
	}
	for key, value in overrides or {} do
		data[key] = value
	end
	return data
end

local function context(data, state)
	return { state = state or "Lobby", data = data }
end

-- Upgrade --------------------------------------------------------------------

table.insert(cases, {
	name = "upgrade boleh kalau dimiliki, belum max, koin cukup",
	run = function()
		local data = newData({ coins = 1000 })
		local ok, reason = ProgressionRules.canUpgrade(Weapons.weapon_starter, context(data), 50)
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "upgrade ditolak di luar lobby",
	run = function()
		-- Upgrade di tengah wave berarti damage berubah di tengah pertarungan.
		local data = newData({ coins = 1000 })
		for _, state in { "Countdown", "WaveActive", "Intermission", "Ended" } do
			local ok = ProgressionRules.canUpgrade(Weapons.weapon_starter, context(data, state), 50)
			assert(not ok, string.format("state %s seharusnya ditolak", state))
		end
	end,
})

table.insert(cases, {
	name = "upgrade ditolak kalau senjata belum dimiliki",
	run = function()
		local data = newData({ coins = 99999 })
		local ok = ProgressionRules.canUpgrade(Weapons.weapon_ranged, context(data), 50)
		assert(not ok, "senjata yang belum dimiliki tidak boleh di-upgrade")
	end,
})

table.insert(cases, {
	name = "upgrade ditolak di level maksimum",
	run = function()
		local def = Weapons.weapon_starter
		local data = newData({
			coins = 99999,
			weapons = { weapon_starter = { level = def.maxLevel, path = "none" } },
		})
		local ok, reason = ProgressionRules.canUpgrade(def, context(data), 50)
		assert(not ok, "level maksimum tidak boleh di-upgrade lagi")
		assert(reason ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "upgrade ditolak kalau koin kurang satu",
	run = function()
		local data = newData({ coins = 49 })
		assert(
			not ProgressionRules.canUpgrade(Weapons.weapon_starter, context(data), 50),
			"koin 49 untuk harga 50 harus ditolak"
		)
		local exact = newData({ coins = 50 })
		assert(
			ProgressionRules.canUpgrade(Weapons.weapon_starter, context(exact), 50),
			"koin tepat sejumlah harga harus cukup"
		)
	end,
})

table.insert(cases, {
	name = "upgrade sampai level 10 harganya naik dan selalu terdefinisi",
	run = function()
		local def = Weapons.weapon_starter
		local previous = -1
		for level = 1, def.maxLevel - 1 do
			local price = Balance.upgradePrice(level)
			assert(price > previous, "harga harus naik")
			assert(price > 0, "harga harus positif")
			previous = price
		end
	end,
})

-- Beli -----------------------------------------------------------------------

table.insert(cases, {
	name = "beli weapon_ranged boleh kalau koin cukup",
	run = function()
		local def = Weapons.weapon_ranged
		local data = newData({ coins = def.acquire.coinCost })
		local ok, reason = ProgressionRules.canBuy(def, context(data))
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "beli ditolak kalau sudah dimiliki",
	run = function()
		local data = newData({
			coins = 99999,
			weapons = {
				weapon_starter = { level = 1, path = "none" },
				weapon_ranged = { level = 1, path = "none" },
			},
		})
		local ok, reason = ProgressionRules.canBuy(Weapons.weapon_ranged, context(data))
		assert(not ok, "senjata yang sudah dimiliki tidak boleh dibeli lagi")
		assert(reason ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "beli ditolak untuk senjata yang bukan dijual",
	run = function()
		-- weapon_boss_a metodenya craft, weapon_starter metodenya default.
		local data = newData({ coins = 99999 })
		assert(
			not ProgressionRules.canBuy(Weapons.weapon_boss_a, context(data)),
			"senjata craft tidak boleh dibeli dengan koin"
		)
		local owned = newData({ coins = 99999 })
		assert(
			not ProgressionRules.canBuy(Weapons.weapon_starter, context(owned)),
			"senjata default sudah dimiliki, tidak boleh dibeli"
		)
	end,
})

table.insert(cases, {
	name = "beli ditolak kalau harganya belum diatur",
	run = function()
		-- Data yang tidak lengkap: senjata bermetode buy tanpa coinCost akan
		-- jadi senjata gratis kalau dibiarkan lolos.
		local broken = {
			id = "weapon_x",
			name = "X",
			kind = "ranged",
			baseDamage = 1,
			cooldown = 1,
			range = 1,
			projectiles = 1,
			maxLevel = 10,
			acquire = { method = "buy" },
		}
		local ok = ProgressionRules.canBuy(broken, context(newData({ coins = 99999 })))
		assert(not ok, "senjata buy tanpa harga harus ditolak")
	end,
})

table.insert(cases, {
	name = "beli ditolak di luar lobby",
	run = function()
		local data = newData({ coins = 99999 })
		assert(
			not ProgressionRules.canBuy(Weapons.weapon_ranged, context(data, "Intermission")),
			"beli senjata di tengah match harus ditolak"
		)
	end,
})

-- Craft ----------------------------------------------------------------------

table.insert(cases, {
	name = "craft weapon_boss_a boleh kalau material cukup",
	run = function()
		local def = Weapons.weapon_boss_a
		local materials = {}
		for materialId, amount in def.acquire.materials do
			materials[materialId] = amount
		end
		local data = newData({ materials = materials })
		local ok, reason = ProgressionRules.canCraft(def, context(data))
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "craft ditolak kalau material kurang satu",
	run = function()
		local def = Weapons.weapon_boss_a
		local materials = {}
		for materialId, amount in def.acquire.materials do
			materials[materialId] = amount - 1
		end
		local data = newData({ materials = materials })
		local ok, reason = ProgressionRules.canCraft(def, context(data))
		assert(not ok, "material kurang satu harus ditolak")
		assert(reason ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "craft ditolak tanpa material sama sekali",
	run = function()
		assert(
			not ProgressionRules.canCraft(Weapons.weapon_boss_a, context(newData())),
			"tanpa material harus ditolak"
		)
	end,
})

table.insert(cases, {
	name = "craft ditolak untuk senjata yang bukan craft",
	run = function()
		local data = newData({ materials = { material_a = 999 } })
		assert(
			not ProgressionRules.canCraft(Weapons.weapon_ranged, context(data)),
			"senjata beli tidak boleh di-craft"
		)
	end,
})

table.insert(cases, {
	name = "craft ditolak kalau sudah dimiliki",
	run = function()
		local data = newData({
			materials = { material_a = 999 },
			weapons = {
				weapon_starter = { level = 1, path = "none" },
				weapon_boss_a = { level = 1, path = "none" },
			},
		})
		assert(
			not ProgressionRules.canCraft(Weapons.weapon_boss_a, context(data)),
			"senjata yang sudah dimiliki tidak boleh di-craft lagi"
		)
	end,
})

table.insert(cases, {
	name = "material drop boss cocok dengan bahan craft weapon_boss_a",
	run = function()
		-- Kalau boss men-drop material_b sementara craft butuh material_c,
		-- senjata itu tidak akan pernah bisa dibuat dan tidak ada yang error.
		local Bosses = require("../src/shared/Modules/Bosses")
		local dropped: { [string]: boolean } = {}
		for _, def in Bosses do
			dropped[def.dropMaterial] = true
		end
		for materialId in Weapons.weapon_boss_a.acquire.materials do
			assert(
				dropped[materialId],
				string.format("craft butuh '%s' tapi tidak ada boss yang men-drop-nya", materialId)
			)
		end
	end,
})

-- Kesulitan ------------------------------------------------------------------

table.insert(cases, {
	name = "hard terbuka setelah normal di-clear",
	run = function()
		local before = newData()
		assert(
			#ProgressionRules.newlyUnlockedDifficulties(before, Difficulties) == 0,
			"belum ada clear, belum ada yang terbuka"
		)

		local after = newData({ clears = { normal = true } })
		local unlocked = ProgressionRules.newlyUnlockedDifficulties(after, Difficulties)
		assert(#unlocked == 1, string.format("dapat %d, harus 1", #unlocked))
		assert(unlocked[1] == "hard", "yang terbuka harus hard")
	end,
})

table.insert(cases, {
	name = "kesulitan yang sudah terbuka tidak dilaporkan lagi",
	run = function()
		-- Kalau dilaporkan terus, layar hasil akan bilang "Terbuka: hard" tiap
		-- kali pemain menang, setiap match, selamanya.
		local data = newData({
			clears = { normal = true },
			unlockedDifficulties = { normal = true, hard = true },
		})
		assert(
			#ProgressionRules.newlyUnlockedDifficulties(data, Difficulties) == 0,
			"tidak boleh ada yang dilaporkan terbuka lagi"
		)
	end,
})

table.insert(cases, {
	name = "clear hard tidak membuka apa pun di v1",
	run = function()
		local data = newData({
			clears = { normal = true, hard = true },
			unlockedDifficulties = { normal = true, hard = true },
		})
		assert(#ProgressionRules.newlyUnlockedDifficulties(data, Difficulties) == 0)
	end,
})

-- Kurva level ----------------------------------------------------------------

table.insert(cases, {
	name = "XP kebutuhan naik level naik monoton",
	run = function()
		local previous = -1
		for level = 1, 30 do
			local needed = Balance.xpForLevel(level)
			assert(needed > previous, string.format("level %d tidak naik", level))
			assert(needed > 0, "kebutuhan XP harus positif")
			previous = needed
		end
	end,
})

table.insert(cases, {
	name = "XP sedikit tidak menaikkan level",
	run = function()
		local level, xp, gained = Balance.applyXp(1, 0, 20)
		assert(level == 1, "20 XP tidak boleh langsung naik level")
		assert(xp == 20, "XP harus tersimpan")
		assert(gained == 0, "tidak ada level yang naik")
	end,
})

table.insert(cases, {
	name = "XP cukup menaikkan satu level dan sisanya disimpan",
	run = function()
		local needed = Balance.xpForLevel(1)
		local level, xp, gained = Balance.applyXp(1, 0, needed + 7)
		assert(level == 2, string.format("harus level 2, dapat %d", level))
		assert(xp == 7, string.format("sisa XP harus 7, dapat %d", xp))
		assert(gained == 1, "harus naik satu level")
	end,
})

table.insert(cases, {
	name = "XP banyak bisa menaikkan beberapa level sekaligus",
	run = function()
		-- Satu match penuh yang menang memberi 300 XP; match pertama pemain
		-- baru harus bisa naik lebih dari satu level.
		local level, _, gained = Balance.applyXp(1, 0, 1000)
		assert(gained >= 2, string.format("harus naik minimal 2 level, dapat %d", gained))
		assert(level == 1 + gained, "level akhir harus konsisten dengan jumlah kenaikan")
	end,
})

table.insert(cases, {
	name = "XP tidak pernah negatif dan level tidak pernah turun",
	run = function()
		local level, xp = Balance.applyXp(5, 10, 0)
		assert(level == 5 and xp == 10, "XP 0 tidak boleh mengubah apa pun")

		local level2, xp2 = Balance.applyXp(5, 10, -500)
		assert(level2 == 5 and xp2 == 10, "XP negatif tidak boleh diterapkan")
	end,
})

table.insert(cases, {
	name = "XP yang bukan angka wajar tidak diterapkan dan tidak menggantung",
	run = function()
		-- inf akan membuat loop naik level berjalan selamanya kalau tidak
		-- ditolak, dan di server itu berarti pemain yang tidak pernah dapat
		-- reward tanpa ada yang tahu kenapa.
		local level, xp, gained = Balance.applyXp(1, 0, math.huge)
		assert(level == 1 and xp == 0 and gained == 0, "inf tidak boleh diterapkan")

		local l2, x2, g2 = Balance.applyXp(1, 0, 0 / 0)
		assert(l2 == 1 and x2 == 0 and g2 == 0, "NaN tidak boleh diterapkan")
	end,
})

table.insert(cases, {
	name = "jumlah kenaikan level dibatasi, bukan tak terbatas",
	run = function()
		local _, _, gained = Balance.applyXp(1, 0, 1e12)
		assert(
			gained <= Balance.MAX_LEVEL_UPS_PER_CALL,
			string.format("naik %d level dalam satu panggilan", gained)
		)
	end,
})

table.insert(cases, {
	name = "sepuluh match yang menang menaikkan level secara masuk akal",
	run = function()
		-- Pemeriksaan atas kurvanya, bukan atas kode: kalau sepuluh match
		-- penuh cuma menaikkan satu level, levelnya tidak berarti apa-apa;
		-- kalau menaikkan tiga puluh, kurvanya terlalu longgar.
		local level, xp = 1, 0
		for _ = 1, 10 do
			level, xp = Balance.applyXp(level, xp, Balance.rewardXp(10, true))
		end
		assert(level >= 5 and level <= 20, string.format("level %d setelah 10 match", level))
	end,
})

-- Kepemilikan senjata ------------------------------------------------------

table.insert(cases, {
	name = "ownedWeapons tanpa flag dev cuma mengembalikan yang di data",
	run = function()
		local owned = ProgressionRules.ownedWeapons(newData(), Weapons, false)
		assert(owned.weapon_starter ~= nil, "starter harus ada")
		assert(owned.weapon_ranged == nil, "ranged belum dibeli")
		assert(owned.weapon_boss_a == nil, "boss_a belum di-craft")
	end,
})

table.insert(cases, {
	name = "ownedWeapons dengan flag dev mengembalikan semua senjata level 1",
	run = function()
		local owned = ProgressionRules.ownedWeapons(newData(), Weapons, true)
		local count = 0
		for id, save in owned do
			count += 1
			assert(Weapons[id] ~= nil, id .. " bukan senjata yang ada")
			assert(save.level == 1, id .. " harus level 1")
		end
		local total = 0
		for _ in Weapons do
			total += 1
		end
		assert(count == total, string.format("%d dari %d senjata", count, total))
	end,
})

table.insert(cases, {
	name = "flag dev tidak menurunkan level senjata yang benar-benar dimiliki",
	run = function()
		-- Kegagalan yang dicegah: menyetel flag lalu melihat Patch Wrench level 8
		-- jadi level 1 di panel lobby, dan damage-nya ikut turun di arena.
		local data = newData({ weapons = { weapon_starter = { level = 8, path = "none" } } })
		local owned = ProgressionRules.ownedWeapons(data, Weapons, true)
		assert(owned.weapon_starter.level == 8, "level asli harus menang")
		assert(owned.weapon_ranged.level == 1, "yang dari flag tetap level 1")
	end,
})

table.insert(cases, {
	name = "ownedWeapons tidak mengembalikan id yang tidak ada di defs",
	run = function()
		-- Save lama dari skema sebelumnya bisa memuat id yang sudah dihapus.
		-- Kalau id itu lolos, `equippedWeapon` bisa menunjuk senjata tanpa def
		-- dan pemanggil mana pun yang membaca `.cooldown` akan error.
		local data = newData({
			weapons = {
				weapon_starter = { level = 1, path = "none" },
				weapon_sudah_dihapus = { level = 3, path = "none" },
			},
		})
		local owned = ProgressionRules.ownedWeapons(data, Weapons, false)
		assert(owned.weapon_sudah_dihapus == nil, "id tanpa def harus dibuang")
	end,
})

table.insert(cases, {
	name = "menulis ke hasil ownedWeapons tidak menyentuh data pemain",
	run = function()
		local data = newData({ weapons = { weapon_starter = { level = 4, path = "none" } } })
		local owned = ProgressionRules.ownedWeapons(data, Weapons, false)
		owned.weapon_starter.level = 99
		assert(data.weapons.weapon_starter.level == 4, "data pemain ikut berubah")
	end,
})

-- Senjata yang dipakai -----------------------------------------------------

table.insert(cases, {
	name = "equippedWeapon mengembalikan senjata dan level dari data",
	run = function()
		local data = newData({
			equippedWeapon = "weapon_ranged",
			weapons = {
				weapon_starter = { level = 1, path = "none" },
				weapon_ranged = { level = 6, path = "none" },
			},
		})
		local def, level = ProgressionRules.equippedWeapon(data, Weapons, false)
		assert(def.id == "weapon_ranged", "def salah: " .. def.id)
		assert(level == 6, "level salah: " .. level)
	end,
})

table.insert(cases, {
	name = "equippedWeapon jatuh ke starter kalau senjatanya tidak dimiliki",
	run = function()
		-- Jatuhnya memang diam-diam; yang dites di sini justru bahwa levelnya
		-- ikut level starter pemain, bukan 1. Pemain level starter 7 yang datanya
		-- rusak tidak boleh mendadak menyerang seperti pemain baru.
		local data = newData({
			equippedWeapon = "weapon_ranged",
			weapons = { weapon_starter = { level = 7, path = "none" } },
		})
		local def, level = ProgressionRules.equippedWeapon(data, Weapons, false)
		assert(def.id == "weapon_starter", "harus jatuh ke starter, dapat " .. def.id)
		assert(level == 7, "level starter salah: " .. level)
	end,
})

table.insert(cases, {
	name = "flag dev membuat senjata yang belum dibeli benar-benar terpakai",
	run = function()
		-- Ini jebakan yang disebut ARENA_REDESIGN bagian 2: kalau cuma gerbang
		-- SelectLoadout yang mengenal flag, pilihan diterima tapi damage-nya
		-- tetap damage starter -- tanpa satu pesan error pun. Jadi kedua sisi
		-- harus lewat sini.
		local data = newData({ equippedWeapon = "weapon_ranged" })

		local tanpaFlag = ProgressionRules.equippedWeapon(data, Weapons, false)
		assert(tanpaFlag.id == "weapon_starter", "tanpa flag harus starter")

		local denganFlag, level = ProgressionRules.equippedWeapon(data, Weapons, true)
		assert(denganFlag.id == "weapon_ranged", "dengan flag harus ranged")
		assert(level == 1, "senjata dari flag mulai level 1")
	end,
})

table.insert(cases, {
	name = "level di luar kurva di-clamp ke rentang senjatanya",
	run = function()
		local data = newData({ weapons = { weapon_starter = { level = 500, path = "none" } } })
		local def, level = ProgressionRules.equippedWeapon(data, Weapons, false)
		assert(level == def.maxLevel, string.format("level %d, maks %d", level, def.maxLevel))

		local rendah = newData({ weapons = { weapon_starter = { level = 0, path = "none" } } })
		local _, levelRendah = ProgressionRules.equippedWeapon(rendah, Weapons, false)
		assert(levelRendah == 1, "level 0 harus jadi 1, dapat " .. levelRendah)
	end,
})

table.insert(cases, {
	name = "flag dev tidak membuka jalur beli, craft, atau upgrade",
	run = function()
		-- Batas yang paling penting di seluruh fitur flag dev: `canBuy` dan
		-- kawan-kawannya membaca `data.weapons` langsung. Kalau mereka ikut
		-- `ownedWeapons`, pemain bisa membayar koin sungguhan untuk meng-upgrade
		-- senjata yang tidak dia miliki, dan hasilnya MASUK DataStore -- kerusakan
		-- permanen dari flag yang seharusnya cuma hidup di memori.
		--
		-- Fungsinya tidak punya parameter flag sama sekali, jadi yang dites di
		-- sini adalah bahwa jawabannya tidak bergeser gara-gara flag itu ada.
		local data = newData({ coins = 99999, materials = { material_a = 99 } })

		local bolehBeli = ProgressionRules.canBuy(Weapons.weapon_ranged, context(data))
		assert(bolehBeli, "ranged yang belum dimiliki harus masih bisa dibeli")

		local bolehUpgrade = ProgressionRules.canUpgrade(Weapons.weapon_ranged, context(data), 100)
		assert(not bolehUpgrade, "ranged yang belum dimiliki tidak boleh di-upgrade")

		local bolehCraft = ProgressionRules.canCraft(Weapons.weapon_boss_a, context(data))
		assert(bolehCraft, "boss_a harus masih bisa di-craft")
	end,
})

-- Alur upgrade: pilihan permanen ---------------------------------------------

local starter = Weapons.weapon_starter

-- Data pemain dengan satu senjata di level dan alur tertentu, koin berlimpah.
-- Koinnya dibuat besar supaya penolakan yang muncul di test di bawah PASTI soal
-- alur, bukan soal koin yang kurang.
local function atLevel(level, path)
	return newData({
		coins = 999999,
		weapons = { weapon_starter = { level = level, path = path or "none" } },
	})
end

table.insert(cases, {
	name = "pilihan alur ditagih tepat saat naik ke titik percabangan",
	run = function()
		local branch = Balance.PATH_BRANCH_LEVEL
		for level = 1, branch - 2 do
			local save = atLevel(level).weapons.weapon_starter
			assert(
				not ProgressionRules.pathChoiceRequired(save),
				string.format("level %d belum boleh ditagih", level)
			)
		end
		local save = atLevel(branch - 1).weapons.weapon_starter
		assert(
			ProgressionRules.pathChoiceRequired(save),
			string.format("naik dari level %d ke %d harus ditagih", branch - 1, branch)
		)

		-- Sudah memilih: tidak ditagih lagi di level mana pun.
		for level = 1, starter.maxLevel do
			local chosen = atLevel(level, "a").weapons.weapon_starter
			assert(
				not ProgressionRules.pathChoiceRequired(chosen),
				string.format("level %d sudah punya alur, tidak boleh ditagih", level)
			)
		end
	end,
})

table.insert(cases, {
	name = "upgrade ke titik percabangan tanpa pathId ditolak",
	run = function()
		local data = atLevel(Balance.PATH_BRANCH_LEVEL - 1)
		local ok, reason = ProgressionRules.canUpgrade(starter, context(data), 1)
		assert(not ok, "harus ditolak tanpa pilihan alur")
		assert(
			reason ~= nil and reason:find("alur") ~= nil,
			"alasan harus menyebut alur: " .. tostring(reason)
		)
	end,
})

table.insert(cases, {
	name = "upgrade ke titik percabangan dengan alur yang sah diterima",
	run = function()
		local data = atLevel(Balance.PATH_BRANCH_LEVEL - 1)
		for _, path in starter.paths do
			local ok = ProgressionRules.canUpgrade(starter, context(data), 1, path.id)
			assert(ok, "alur " .. path.id .. " harus diterima")
		end
	end,
})

table.insert(cases, {
	name = "alur yang bukan milik senjata itu ditolak",
	run = function()
		-- Dibaca dari definisi di server, bukan dari apa pun yang dikirim client.
		local data = atLevel(Balance.PATH_BRANCH_LEVEL - 1)
		local ok, reason = ProgressionRules.canUpgrade(starter, context(data), 1, "alur_karangan")
		assert(not ok, "alur karangan harus ditolak")
		assert(reason ~= nil and reason:find("tidak punya alur") ~= nil, tostring(reason))
	end,
})

table.insert(cases, {
	name = "alur yang sudah terpilih tidak bisa diganti",
	run = function()
		-- Satu-satunya tempat yang menegakkan "tidak bisa balik". Kalau baris ini
		-- hijau sementara kodenya membolehkan, seluruh gunanya tiga alur hilang:
		-- pemain akan menukar alur tiap wave sesuai musuh yang datang.
		local data = atLevel(5, "a")
		local ok, reason = ProgressionRules.canUpgrade(starter, context(data), 1, "b")
		assert(not ok, "ganti alur harus ditolak")
		assert(
			reason ~= nil and reason:find("tidak bisa diganti") ~= nil,
			"alasan harus menyebut alur yang sudah terpilih: " .. tostring(reason)
		)

		-- Mengirim ulang alur yang SAMA bukan percobaan ganti, jadi diterima.
		assert(
			ProgressionRules.canUpgrade(starter, context(data), 1, "a"),
			"mengirim alur yang sama harus diterima"
		)
		-- Dan tidak mengirim apa pun juga diterima: level 5 ke 6 bukan titik
		-- percabangan.
		assert(
			ProgressionRules.canUpgrade(starter, context(data), 1),
			"upgrade biasa sesudah memilih harus diterima"
		)
	end,
})

table.insert(cases, {
	name = "alur tidak bisa dikunci sebelum titik percabangan",
	run = function()
		-- Level 1 sampai 3 masa percobaan. `canUpgrade` MENGABAIKAN pathId di
		-- situ, jadi yang menjaganya `pathToApply`: tanpa itu, client bisa
		-- mengunci alur di upgrade pertama dan tidak ada yang menolaknya.
		local save = atLevel(1).weapons.weapon_starter
		assert(
			ProgressionRules.canUpgrade(starter, context(atLevel(1)), 1, "a"),
			"pathId di level 1 diabaikan, bukan ditolak"
		)
		assert(
			ProgressionRules.pathToApply(starter, save, "a") == nil,
			"alur tidak boleh tersimpan di level 1"
		)
	end,
})

table.insert(cases, {
	name = "pathToApply mengembalikan alur hanya di titik percabangan",
	run = function()
		local save = atLevel(Balance.PATH_BRANCH_LEVEL - 1).weapons.weapon_starter
		assert(ProgressionRules.pathToApply(starter, save, "a") == "a", "harus mengembalikan a")
		assert(ProgressionRules.pathToApply(starter, save, nil) == nil, "nil tetap nil")
		assert(ProgressionRules.pathToApply(starter, save, "none") == nil, '"none" bukan pilihan')
		assert(
			ProgressionRules.pathToApply(starter, save, "alur_karangan") == nil,
			"alur karangan tidak boleh tersimpan"
		)

		-- Yang sudah punya alur tidak boleh ditulis ulang, berapa pun levelnya.
		local sudah = atLevel(Balance.PATH_BRANCH_LEVEL, "a").weapons.weapon_starter
		assert(ProgressionRules.pathToApply(starter, sudah, "b") == nil, "tidak boleh ditimpa")
	end,
})

table.insert(cases, {
	name = "data yang lewat titik percabangan tanpa alur masih bisa memilih",
	run = function()
		-- Save dari sebelum fitur ini ada: level 8, path "none". Dengan `==` di
		-- pathChoiceRequired, pemain ini terjebak selamanya tanpa alur dan tanpa
		-- satu pesan pun. Jadi dia harus ditagih di upgrade berikutnya.
		local data = atLevel(8)
		local save = data.weapons.weapon_starter
		assert(ProgressionRules.pathChoiceRequired(save), "harus ditagih")

		local ok = ProgressionRules.canUpgrade(starter, context(data), 1)
		assert(not ok, "upgrade tanpa alur harus ditolak")
		assert(
			ProgressionRules.canUpgrade(starter, context(data), 1, "c"),
			"dengan alur harus diterima"
		)
		assert(ProgressionRules.pathToApply(starter, save, "c") == "c", "alurnya harus tersimpan")
	end,
})

table.insert(cases, {
	name = "alur ditagih sebelum koin, bukan sesudahnya",
	run = function()
		-- Urutan pesan, bukan urutan kode: pemain yang belum memilih alur DAN
		-- koinnya kurang harus tahu soal pilihan permanennya dulu. Dibalik, dia
		-- menabung sampai cukup lalu baru menemukan ada keputusan yang menunggu.
		local data = newData({
			coins = 0,
			weapons = {
				weapon_starter = { level = Balance.PATH_BRANCH_LEVEL - 1, path = "none" },
			},
		})
		local ok, reason = ProgressionRules.canUpgrade(starter, context(data), 9999)
		assert(not ok, "harus ditolak")
		assert(
			reason ~= nil and reason:find("alur") ~= nil,
			"alasannya harus soal alur, bukan koin: " .. tostring(reason)
		)
	end,
})

table.insert(cases, {
	name = "level maksimum tetap ditolak lebih dulu daripada alur",
	run = function()
		-- Senjata level 10 tanpa alur: `pathChoiceRequired` benar, tapi tidak ada
		-- upgrade lagi untuk ditagih. Yang salah adalah menjawab "pilih alur
		-- dulu" untuk sesuatu yang tidak bisa di-upgrade sama sekali.
		local data = atLevel(starter.maxLevel)
		local ok, reason = ProgressionRules.canUpgrade(starter, context(data), 1)
		assert(not ok, "harus ditolak")
		assert(
			reason ~= nil and reason:find("maksimum") ~= nil,
			"alasannya harus level maksimum: " .. tostring(reason)
		)
	end,
})

return cases
