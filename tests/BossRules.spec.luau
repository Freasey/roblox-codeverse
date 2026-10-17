-- BossRules.spec.luau — ambang mekanik boss (Splitter wave 5).
--
-- Tiga test pertama di bawah menutup kasus pinggir yang masing-masing membuat
-- boss kehilangan satu fase tanpa ada yang error, dan yang tidak akan pernah
-- kelihatan dari playtest biasa: satu serangan yang melewati dua ambang
-- sekaligus, ambang yang terpicu berulang, dan boss yang mati langsung dari HP
-- penuh.

local BossRules = require("../src/shared/Modules/BossRules")
local Bosses = require("../src/shared/Modules/Bosses")

local cases = {}

local THRESHOLDS = { 0.66, 0.33 }

table.insert(cases, {
	name = "ambang belum terlewati saat HP masih di atasnya",
	run = function()
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.9, {})
		assert(#crossed == 0, string.format("dapat %d ambang, harus 0", #crossed))
	end,
})

table.insert(cases, {
	name = "satu ambang terlewati",
	run = function()
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.5, {})
		assert(#crossed == 1, string.format("dapat %d ambang, harus 1", #crossed))
		assert(crossed[1] == 1, "harus ambang pertama (0.66)")
	end,
})

table.insert(cases, {
	name = "satu serangan besar melewati DUA ambang sekaligus",
	run = function()
		-- Ini yang paling mudah salah: implementasi yang cuma memeriksa
		-- "fraksi sekarang di bawah ambang berikutnya" akan memicu satu dan
		-- menelan yang lain, jadi boss kehilangan satu fase.
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.2, {})
		assert(#crossed == 2, string.format("dapat %d ambang, harus 2", #crossed))
	end,
})

table.insert(cases, {
	name = "dua ambang sekaligus diurutkan dari tertinggi ke terendah",
	run = function()
		-- Fase harus dijalankan berurutan. Kalau 33% jalan sebelum 66%, urutan
		-- efeknya kebalik dan itu akan terlihat aneh di playtest tanpa ada yang
		-- bisa menunjuk penyebabnya.
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.0, {})
		assert(#crossed == 2, "harus dua")
		assert(THRESHOLDS[crossed[1]] > THRESHOLDS[crossed[2]], "ambang tertinggi harus lebih dulu")
	end,
})

table.insert(cases, {
	name = "urutan benar walau data ambangnya tidak urut",
	run = function()
		-- Bosses.luau menulisnya sudah urut, tapi mengandalkan itu berarti
		-- mengubah urutan di data akan mengubah urutan fase tanpa ada yang
		-- menyadarinya.
		local unsorted = { 0.33, 0.66 }
		local crossed = BossRules.newlyCrossed(unsorted, 0.1, {})
		assert(#crossed == 2, "harus dua")
		assert(unsorted[crossed[1]] == 0.66, "0.66 harus lebih dulu")
	end,
})

table.insert(cases, {
	name = "ambang yang sudah terpicu tidak terpicu lagi",
	run = function()
		-- Tanpa ini, Splitter membelah setiap kali dipukul di bawah 66%.
		local triggered = { [1] = true }
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.5, triggered)
		assert(#crossed == 0, string.format("dapat %d, harus 0", #crossed))
	end,
})

table.insert(cases, {
	name = "ambang kedua tetap bisa terpicu setelah yang pertama",
	run = function()
		local triggered = { [1] = true }
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.2, triggered)
		assert(#crossed == 1, string.format("dapat %d, harus 1", #crossed))
		assert(crossed[1] == 2, "harus ambang kedua (0.33)")
	end,
})

table.insert(cases, {
	name = "simulasi damage bertahap memicu tiap ambang tepat sekali",
	run = function()
		local triggered: { [number]: boolean } = {}
		local total = 0
		-- 100 serangan kecil dari HP penuh sampai nol.
		for step = 100, 0, -1 do
			local crossed = BossRules.newlyCrossed(THRESHOLDS, step / 100, triggered)
			for _, index in crossed do
				triggered[index] = true
				total += 1
			end
		end
		assert(total == #THRESHOLDS, string.format("%d pemicuan, harus %d", total, #THRESHOLDS))
	end,
})

table.insert(cases, {
	name = "boss yang mati dari HP penuh tetap memicu semua ambang",
	run = function()
		-- Kalau mekaniknya dilewatkan di sini, membunuh boss dengan satu
		-- serangan besar membuat mekaniknya tidak pernah jalan sama sekali.
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0, {})
		assert(#crossed == #THRESHOLDS, "semua ambang harus terpicu")
	end,
})

table.insert(cases, {
	name = "fraksi tepat di ambang dianggap terlewati",
	run = function()
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0.66, {})
		assert(#crossed == 1, "fraksi tepat 0.66 harus memicu ambang 0.66")
	end,
})

table.insert(cases, {
	name = "daftar ambang kosong tidak error",
	run = function()
		local crossed = BossRules.newlyCrossed({}, 0.1, {})
		assert(#crossed == 0, "harus kosong")
	end,
})

table.insert(cases, {
	name = "NaN tidak memicu apa pun",
	run = function()
		-- Perbandingan apa pun dengan NaN false, jadi membiarkannya akan
		-- menghasilkan "tidak ada yang terlewati" secara kebetulan, bukan
		-- karena disengaja.
		local crossed = BossRules.newlyCrossed(THRESHOLDS, 0 / 0, {})
		assert(#crossed == 0, "NaN tidak boleh memicu")
	end,
})

table.insert(cases, {
	name = "fraction aman untuk maxHp nol dan nilai di luar batas",
	run = function()
		assert(BossRules.fraction(50, 0) == 0, "maxHp 0 harus jadi 0, bukan inf")
		assert(BossRules.fraction(-10, 100) == 0, "HP negatif harus di-clamp ke 0")
		assert(BossRules.fraction(500, 100) == 1, "HP di atas maxHp harus di-clamp ke 1")
		assert(BossRules.fraction(0 / 0, 100) == 0, "HP NaN harus jadi 0")
		assert(BossRules.fraction(50, 100) == 0.5, "kasus normal")
	end,
})

table.insert(cases, {
	name = "ambang boss_splitter di data v1 masuk akal",
	run = function()
		local mechanic = Bosses.boss_splitter.mechanic
		assert(mechanic.kind == "splitter", "boss_splitter harus memakai mekanik splitter")
		assert(#mechanic.thresholds > 0, "harus ada ambang")
		local previous = math.huge
		for _, value in mechanic.thresholds do
			assert(value > 0 and value < 1, string.format("ambang %.2f di luar (0,1)", value))
			assert(value < previous, "ambang harus turun monoton")
			previous = value
		end
		assert(mechanic.spawnCount > 0, "spawnCount harus positif")
	end,
})

table.insert(cases, {
	name = "mekanik boss_locker di data v1 masuk akal",
	run = function()
		local mechanic = Bosses.boss_locker.mechanic
		assert(mechanic.kind == "locker", "boss_locker harus memakai mekanik locker")
		assert(mechanic.summonInterval > 0, "summonInterval harus positif")
		assert(mechanic.summonCount > 0, "summonCount harus positif")
		assert(mechanic.locksShop, "Locker harus mengunci toko — itu inti mekaniknya")
	end,
})

table.insert(cases, {
	name = "tiap boss punya material drop dan kartu info yang terisi",
	run = function()
		for bossId, def in Bosses do
			assert(
				def.dropMaterial ~= "",
				string.format("boss '%s' tidak punya dropMaterial", bossId)
			)
			assert(
				def.infoCard.title ~= "",
				string.format("boss '%s' kartu infonya tanpa judul", bossId)
			)
			assert(
				#def.infoCard.body > 40,
				string.format("boss '%s' kartu infonya terlalu pendek", bossId)
			)
			assert(
				#def.infoCard.prevention > 0,
				string.format("boss '%s' kartu infonya tanpa cara pencegahan", bossId)
			)
		end
	end,
})

return cases
