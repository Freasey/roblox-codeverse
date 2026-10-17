-- MatchRules.spec.luau — pembagian musuh per wave, urutan spawn, dan pemilihan
-- kesulitan (docs/DEVELOPMENT_PLAN.md bagian 3.3 dan 3.5).
--
-- Yang paling penting di file ini adalah test "jumlahnya persis sama dengan
-- total". Pembagian naif membuang sisa bagi, dan satu musuh yang hilang per
-- wave tidak akan pernah kelihatan dari playtest — yang kelihatan cuma "kok
-- wave-nya terasa lebih gampang dari yang dihitung".

local Difficulties = require("../src/shared/Modules/Difficulties")
local MatchRules = require("../src/shared/Modules/MatchRules")
local Waves = require("../src/shared/Modules/Waves")

local cases = {}

local function sum(list)
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

table.insert(cases, {
	name = "pembagian share jumlahnya persis sama dengan total",
	run = function()
		local entries = { { enemyId = "a", share = 3 }, { enemyId = "b", share = 1 } }
		for total = 0, 60 do
			local counts = MatchRules.splitByShare(entries, total)
			assert(
				sum(counts) == total,
				string.format("total %d: hasil bagi %d, tidak sama", total, sum(counts))
			)
		end
	end,
})

table.insert(cases, {
	name = "pembagian naif akan kehilangan musuh di kasus ini",
	run = function()
		-- share {3, 1}, total 10. math.floor(10*3/4) + math.floor(10*1/4)
		-- = 7 + 2 = 9. Satu musuh hilang. Metode sisa terbesar harus 8 + 2.
		local counts = MatchRules.splitByShare(
			{ { enemyId = "a", share = 3 }, { enemyId = "b", share = 1 } },
			10
		)
		assert(sum(counts) == 10, string.format("dapat %d, harus 10", sum(counts)))
	end,
})

table.insert(cases, {
	name = "entry dengan share lebih besar dapat jumlah lebih besar",
	run = function()
		local counts = MatchRules.splitByShare(
			{ { enemyId = "banyak", share = 5 }, { enemyId = "sedikit", share = 1 } },
			60
		)
		assert(counts[1] > counts[2], "share lebih besar harus dapat lebih banyak")
	end,
})

table.insert(cases, {
	name = "share yang sama dibagi rata",
	run = function()
		local counts = MatchRules.splitByShare(
			{ { enemyId = "a", share = 1 }, { enemyId = "b", share = 1 } },
			10
		)
		assert(counts[1] == 5 and counts[2] == 5, "share sama harus dibagi rata")
	end,
})

table.insert(cases, {
	name = "total nol dan entry kosong tidak error",
	run = function()
		local counts = MatchRules.splitByShare({ { enemyId = "a", share = 1 } }, 0)
		assert(sum(counts) == 0, "total 0 harus menghasilkan 0")
		local empty = MatchRules.splitByShare({}, 10)
		assert(#empty == 0, "entry kosong harus menghasilkan daftar kosong")
	end,
})

table.insert(cases, {
	name = "share nol tidak membagi nol",
	run = function()
		-- Kalau semua share nol, pembagian `total * share / shareSum` jadi
		-- 0/0 = NaN dan math.floor(NaN) merusak seluruh hasil tanpa error.
		local counts = MatchRules.splitByShare(
			{ { enemyId = "a", share = 0 }, { enemyId = "b", share = 0 } },
			7
		)
		assert(sum(counts) == 7, string.format("dapat %d, harus 7", sum(counts)))
		for _, value in counts do
			assert(value == value, "ada NaN di hasil")
		end
	end,
})

table.insert(cases, {
	name = "hasilnya deterministik",
	run = function()
		-- Dua server dengan input yang sama harus menghasilkan wave yang sama.
		local entries = { { enemyId = "a", share = 2 }, { enemyId = "b", share = 3 } }
		local first = MatchRules.splitByShare(entries, 11)
		for _ = 1, 20 do
			local again = MatchRules.splitByShare(entries, 11)
			for index, value in first do
				assert(again[index] == value, "hasil berubah antar pemanggilan")
			end
		end
	end,
})

table.insert(cases, {
	name = "setiap wave v1 terbagi tanpa kehilangan musuh",
	run = function()
		for _, wave in Waves.list do
			for playerCount = 1, 4 do
				local Balance = require("../src/shared/Modules/Balance")
				local total = Balance.enemyCount(wave.index, playerCount)
				local counts = MatchRules.splitByShare(wave.entries, total)
				assert(
					sum(counts) == total,
					string.format(
						"wave %d, %d player: %d dari %d",
						wave.index,
						playerCount,
						sum(counts),
						total
					)
				)
			end
		end
	end,
})

table.insert(cases, {
	name = "urutan spawn panjangnya sama dengan total",
	run = function()
		local order = MatchRules.spawnOrder(
			{ { enemyId = "a", share = 2 }, { enemyId = "b", share = 1 } },
			12,
			2
		)
		assert(#order == 12, string.format("dapat %d entri, harus 12", #order))
	end,
})

table.insert(cases, {
	name = "urutan spawn mencampur tipe musuh, bukan mengelompokkannya",
	run = function()
		-- Kalau antrian diurutkan per tipe, pemain menghadapi 8 musuh identik
		-- lalu 4 yang lain. Harus tercampur: entri kedua tidak boleh tipe yang
		-- sama dengan entri pertama ketika ada lebih dari satu tipe.
		local order = MatchRules.spawnOrder(
			{ { enemyId = "a", share = 2 }, { enemyId = "b", share = 1 } },
			12,
			2
		)
		assert(order[1].enemyId ~= order[2].enemyId, "dua entri pertama tipenya sama")
	end,
})

table.insert(cases, {
	name = "urutan spawn membagi lane round-robin",
	run = function()
		local order = MatchRules.spawnOrder({ { enemyId = "a", share = 1 } }, 10, 2)
		local perLane = { 0, 0 }
		for _, item in order do
			perLane[item.laneIndex] += 1
		end
		assert(
			perLane[1] == 5 and perLane[2] == 5,
			string.format("lane terbagi %d/%d, harus 5/5", perLane[1], perLane[2])
		)
	end,
})

table.insert(cases, {
	name = "urutan spawn tetap valid untuk satu lane",
	run = function()
		-- Bagian 9 mengizinkan memotong jadi satu lane saja.
		local order = MatchRules.spawnOrder({ { enemyId = "a", share = 1 } }, 5, 1)
		assert(#order == 5, "jumlahnya berubah")
		for _, item in order do
			assert(item.laneIndex == 1, "lane di luar jangkauan")
		end
	end,
})

table.insert(cases, {
	name = "laneCount nol tidak menghasilkan lane 0 atau pembagian nol",
	run = function()
		local order = MatchRules.spawnOrder({ { enemyId = "a", share = 1 } }, 3, 0)
		for _, item in order do
			assert(item.laneIndex >= 1, "laneIndex harus minimal 1")
		end
	end,
})

table.insert(cases, {
	name = "kesulitan yang dipilih adalah yang paling mudah",
	run = function()
		-- Konservatif dengan sengaja: `hard` harus dibuka dulu per pemain, jadi
		-- aturan yang mengambil yang lebih sulit bisa memaksa pemain ikut match
		-- pada tingkat yang belum dia buka.
		local picked = MatchRules.easiestDifficulty({ "hard", "normal" }, Difficulties)
		assert(picked == "normal", string.format("dapat '%s', harus 'normal'", tostring(picked)))
	end,
})

table.insert(cases, {
	name = "pilihan tunggal dipakai apa adanya",
	run = function()
		assert(MatchRules.easiestDifficulty({ "hard" }, Difficulties) == "hard")
		assert(MatchRules.easiestDifficulty({ "normal" }, Difficulties) == "normal")
	end,
})

table.insert(cases, {
	name = "id yang tidak dikenal diabaikan",
	run = function()
		-- Client bisa mengirim id apa saja; yang tidak ada di Difficulties
		-- tidak boleh ikut dipertimbangkan.
		local picked = MatchRules.easiestDifficulty({ "nightmare", "hard" }, Difficulties)
		assert(picked == "hard", string.format("dapat '%s', harus 'hard'", tostring(picked)))
	end,
})

table.insert(cases, {
	name = "daftar kosong atau semuanya tidak dikenal menghasilkan nil",
	run = function()
		assert(MatchRules.easiestDifficulty({}, Difficulties) == nil, "kosong harus nil")
		assert(
			MatchRules.easiestDifficulty({ "nightmare" }, Difficulties) == nil,
			"semua tak dikenal harus nil"
		)
	end,
})

return cases
