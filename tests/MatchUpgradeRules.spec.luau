-- MatchUpgradeRules.spec.luau — syarat upgrade senjata di dalam match.
--
-- Dua kelompok yang paling berharga di file ini bukan yang memeriksa harga,
-- tapi yang memeriksa bahwa modul ini TIDAK punya aturan alurnya sendiri: dia
-- memanggil `ProgressionRules` yang sama dengan upgrade lobby. Aturan alur yang
-- disalin akan bergeser pelan-pelan, dan gejalanya panel yang menawarkan alur
-- di level yang ditolak server -- tombol yang terlihat hidup lalu tidak
-- melakukan apa-apa.

local Balance = require("../src/shared/Modules/Balance")
local MatchUpgradeRules = require("../src/shared/Modules/MatchUpgradeRules")
local ShopRules = require("../src/shared/Modules/ShopRules")
local Weapons = require("../src/shared/Modules/Weapons")

local cases = {}

local function save(level: number, path: string?)
	return { level = level, path = path or "none" }
end

local function context(overrides)
	local ctx = { state = MatchUpgradeRules.OPEN_STATE, cash = 1000000, locked = false }
	for key, value in overrides or {} do
		ctx[key] = value
	end
	return ctx
end

table.insert(cases, {
	name = "toko upgrade dan toko item sepakat soal kapan toko buka",
	run = function()
		-- Client memakai SATU aturan untuk memutuskan panel toko terlihat atau
		-- tidak. Dua nilai yang berbeda berarti panel terbuka dengan seluruh
		-- tombolnya ditolak server, atau tertutup saat seharusnya bisa dipakai.
		assert(
			MatchUpgradeRules.OPEN_STATE == ShopRules.OPEN_STATE,
			string.format("%s vs %s", MatchUpgradeRules.OPEN_STATE, ShopRules.OPEN_STATE)
		)
	end,
})

table.insert(cases, {
	name = "senjata yang baru masuk match mulai dari level 1 tanpa alur",
	run = function()
		local fresh = MatchUpgradeRules.freshSave()
		assert(fresh.level == 1, "level awal harus 1")
		assert(fresh.path == "none", "alur awal harus none")
	end,
})

table.insert(cases, {
	name = "freshSave memberi tabel baru tiap dipanggil",
	run = function()
		-- Kalau tabelnya dibagi, satu pemain yang naik level menaikkan level
		-- semua pemain sekaligus -- dan tidak ada error yang menandainya.
		local a = MatchUpgradeRules.freshSave()
		local b = MatchUpgradeRules.freshSave()
		a.level = 7
		assert(b.level == 1, "dua pemanggil tidak boleh berbagi satu tabel")
	end,
})

table.insert(cases, {
	name = "upgrade boleh saat jeda dengan cash cukup",
	run = function()
		local ok, reason = MatchUpgradeRules.canUpgrade(Weapons.weapon_starter, save(1), context())
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "upgrade ditolak di luar jeda antar wave",
	run = function()
		for _, state in { "Lobby", "Loadout", "Countdown", "WaveActive", "Ended" } do
			local ok = MatchUpgradeRules.canUpgrade(
				Weapons.weapon_starter,
				save(1),
				context({ state = state })
			)
			assert(not ok, string.format("state %s seharusnya ditolak", state))
		end
	end,
})

table.insert(cases, {
	name = "toko yang dikunci boss menolak lebih dulu daripada state",
	run = function()
		-- Locker cuma hidup saat WaveActive, jadi kalau state diperiksa lebih
		-- dulu pemain yang kena mekanik boss akan dibilang "tunggu jeda" --
		-- padahal jeda itu baru datang setelah boss-nya mati.
		local ok, reason = MatchUpgradeRules.canUpgrade(
			Weapons.weapon_starter,
			save(1),
			context({ state = "WaveActive", locked = true })
		)
		assert(not ok, "harus ditolak")
		assert(reason ~= nil and string.find(reason, "ikunci") ~= nil, tostring(reason))
	end,
})

table.insert(cases, {
	name = "level maksimum ditolak sebelum cash diperiksa",
	run = function()
		-- Urutannya penting: "cash kurang" adalah satu-satunya alasan yang bisa
		-- dibereskan pemain dengan bermain, jadi menampilkannya untuk senjata
		-- yang sudah maksimum membuat dia menabung untuk sesuatu yang tidak
		-- akan pernah bisa dibeli.
		local def = Weapons.weapon_starter
		local ok, reason =
			MatchUpgradeRules.canUpgrade(def, save(def.maxLevel), context({ cash = 0 }))
		assert(not ok, "harus ditolak")
		assert(reason ~= nil and string.find(reason, "maksimum") ~= nil, tostring(reason))
	end,
})

table.insert(cases, {
	name = "cash kurang satu tetap ditolak",
	run = function()
		local price = Balance.matchUpgradePrice(1)
		local ok = MatchUpgradeRules.canUpgrade(
			Weapons.weapon_starter,
			save(1),
			context({ cash = price - 1 })
		)
		assert(not ok, "cash kurang satu harus ditolak")
		local okTepat =
			MatchUpgradeRules.canUpgrade(Weapons.weapon_starter, save(1), context({ cash = price }))
		assert(okTepat, "cash tepat sejumlah harga harus cukup")
	end,
})

table.insert(cases, {
	name = "harga naik tiap level dan maksimum tidak punya harga",
	run = function()
		local def = Weapons.weapon_starter
		local previous = 0
		for level = 1, def.maxLevel - 1 do
			local price = MatchUpgradeRules.priceFor(def, save(level))
			assert(
				price > previous,
				string.format("level %d: %d tidak lebih mahal dari %d", level, price, previous)
			)
			previous = price
		end
		assert(
			MatchUpgradeRules.priceFor(def, save(def.maxLevel)) == math.huge,
			"level maksimum harus tak terhingga, bukan angka yang bisa dibayar"
		)
	end,
})

-- Alur, lewat ProgressionRules yang sama dengan upgrade lobby ----------------

table.insert(cases, {
	name = "naik ke titik percabangan tanpa memilih alur ditolak",
	run = function()
		local def = Weapons.weapon_starter
		local ok, reason =
			MatchUpgradeRules.canUpgrade(def, save(Balance.PATH_BRANCH_LEVEL - 1), context())
		assert(not ok, "harus menagih pilihan alur")
		assert(reason ~= nil and string.find(reason, "alur") ~= nil, tostring(reason))
	end,
})

table.insert(cases, {
	name = "naik ke titik percabangan dengan alur yang sah diterima",
	run = function()
		local def = Weapons.weapon_starter
		local ok, reason = MatchUpgradeRules.canUpgrade(
			def,
			save(Balance.PATH_BRANCH_LEVEL - 1),
			context(),
			def.paths[1].id
		)
		assert(ok, tostring(reason))
	end,
})

table.insert(cases, {
	name = "alur yang tidak dimiliki senjata itu ditolak",
	run = function()
		local def = Weapons.weapon_starter
		local ok = MatchUpgradeRules.canUpgrade(
			def,
			save(Balance.PATH_BRANCH_LEVEL - 1),
			context(),
			"alur_yang_tidak_ada"
		)
		assert(not ok, "alur asing harus ditolak")
	end,
})

table.insert(cases, {
	name = "alur yang sudah terpilih tidak bisa diganti di match yang sama",
	run = function()
		local def = Weapons.weapon_starter
		local ok, reason = MatchUpgradeRules.canUpgrade(
			def,
			save(Balance.PATH_BRANCH_LEVEL, def.paths[1].id),
			context(),
			def.paths[2].id
		)
		assert(not ok, "ganti alur harus ditolak")
		assert(reason ~= nil and string.find(reason, "sudah di alur") ~= nil, tostring(reason))
	end,
})

table.insert(cases, {
	name = "alur TIDAK tersimpan sebelum titik percabangan",
	run = function()
		-- Tanpa ini client bisa mengunci alur di upgrade pertama, dan masa
		-- percobaan level 1 sampai 3 hilang tanpa jejak.
		local def = Weapons.weapon_starter
		local hasil = MatchUpgradeRules.applyUpgrade(def, save(1), def.paths[1].id)
		assert(hasil.level == 2, "level harus naik")
		assert(hasil.path == "none", "alur belum boleh tersimpan di level 1")
	end,
})

table.insert(cases, {
	name = "alur tersimpan tepat saat naik ke titik percabangan",
	run = function()
		local def = Weapons.weapon_starter
		local hasil = MatchUpgradeRules.applyUpgrade(
			def,
			save(Balance.PATH_BRANCH_LEVEL - 1),
			def.paths[2].id
		)
		assert(hasil.level == Balance.PATH_BRANCH_LEVEL, "level harus sampai titik percabangan")
		assert(hasil.path == def.paths[2].id, "alur harus tersimpan di sini")
	end,
})

table.insert(cases, {
	name = "applyUpgrade tidak mengubah save yang lama",
	run = function()
		local def = Weapons.weapon_starter
		local lama = save(1)
		MatchUpgradeRules.applyUpgrade(def, lama, nil)
		assert(lama.level == 1, "save lama tidak boleh ikut naik")
	end,
})

table.insert(cases, {
	name = "applyUpgrade tidak pernah melewati level maksimum",
	run = function()
		local def = Weapons.weapon_starter
		local hasil = MatchUpgradeRules.applyUpgrade(def, save(def.maxLevel), nil)
		assert(hasil.level == def.maxLevel, "level tidak boleh lewat dari maksimum")
	end,
})

table.insert(cases, {
	name = "tiap senjata bisa naik dari 1 sampai maksimum lewat jalur ini",
	run = function()
		-- Jalur penuh, bukan satu langkah: kalau salah satu senjata punya
		-- jumlah alur atau level maksimum yang berbeda, yang gagal bukan
		-- fungsinya melainkan kombinasinya -- dan itu cuma kelihatan kalau
		-- seluruh tangga dinaiki.
		for id, def in Weapons do
			local current = MatchUpgradeRules.freshSave()
			while current.level < def.maxLevel do
				local pathId = if #def.paths > 0 then def.paths[1].id else nil
				local ok, reason = MatchUpgradeRules.canUpgrade(def, current, context(), pathId)
				assert(ok, string.format("%s level %d: %s", id, current.level, tostring(reason)))
				current = MatchUpgradeRules.applyUpgrade(def, current, pathId)
			end
			assert(
				current.level == def.maxLevel,
				string.format("%s berhenti di level %d", id, current.level)
			)
		end
	end,
})

return cases
