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
		weapons = { weapon_starter = { level = 1 } },
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
			weapons = { weapon_starter = { level = def.maxLevel } },
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
			weapons = { weapon_starter = { level = 1 }, weapon_ranged = { level = 1 } },
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
			weapons = { weapon_starter = { level = 1 }, weapon_boss_a = { level = 1 } },
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

return cases
