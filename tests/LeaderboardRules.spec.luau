-- LeaderboardRules.spec.luau — aturan papan wave tertinggi (M6).
--
-- Yang paling penting di file ini adalah "catatan tidak pernah turun", dan dia
-- diuji DUA KALI: sekali di `isRecord` yang dipakai saat menulis ke
-- OrderedDataStore, sekali lagi lewat `merge` yang dipakai papan di memori.
-- Dua-duanya perlu, karena pelanggaran di salah satunya tidak terlihat dari
-- yang lain: papan memori yang salah baru ketahuan setelah server restart, dan
-- tulisan yang salah baru ketahuan setelah papan memori dibuang.

local Difficulties = require("../src/shared/Modules/Difficulties")
local LeaderboardRules = require("../src/shared/Modules/LeaderboardRules")

local cases = {}

local function entry(userId: number, wave: number, name: string?)
	return { userId = userId, name = name or string.format("P%d", userId), wave = wave }
end

table.insert(cases, {
	name = "rekor pertama diterima, rekor yang lebih rendah ditolak",
	run = function()
		assert(LeaderboardRules.isRecord(nil, 5), "catatan pertama harus diterima")
		assert(LeaderboardRules.isRecord(5, 8), "wave lebih tinggi harus jadi rekor baru")
		assert(not LeaderboardRules.isRecord(8, 3), "LB-03: wave lebih rendah tidak menimpa")
		assert(not LeaderboardRules.isRecord(8, 8), "wave sama bukan rekor baru")
	end,
})

table.insert(cases, {
	name = "wave 0, negatif, dan NaN tidak pernah jadi catatan",
	run = function()
		assert(not LeaderboardRules.isRecord(nil, 0), "wave 0 tidak berarti apa-apa")
		assert(not LeaderboardRules.isRecord(nil, -3), "wave negatif harus ditolak")
		assert(not LeaderboardRules.isRecord(nil, 0 / 0), "NaN harus ditolak")
		assert(not LeaderboardRules.isRecord(5, 0 / 0), "NaN tidak boleh menimpa rekor")
	end,
})

table.insert(cases, {
	name = "wave pecahan dibulatkan ke bawah sebelum dibandingkan",
	run = function()
		assert(not LeaderboardRules.isRecord(5, 5.9), "5.9 jadi 5, dan 5 bukan rekor atas 5")
		assert(LeaderboardRules.isRecord(5, 6.1), "6.1 jadi 6, dan itu rekor baru")
	end,
})

table.insert(cases, {
	name = "tingkat kesulitan yang tidak dikenal tidak pernah lolos",
	run = function()
		assert(
			LeaderboardRules.normalizeDifficulty("normal", Difficulties) == "normal",
			"normal harus lolos"
		)
		assert(
			LeaderboardRules.normalizeDifficulty("hard", Difficulties) == "hard",
			"hard harus lolos"
		)
		assert(
			LeaderboardRules.normalizeDifficulty("nightmare", Difficulties) == nil,
			"tingkat yang tidak ada harus ditolak"
		)
		assert(LeaderboardRules.normalizeDifficulty(7, Difficulties) == nil, "angka harus ditolak")
		assert(LeaderboardRules.normalizeDifficulty(nil, Difficulties) == nil, "nil harus ditolak")
		assert(LeaderboardRules.normalizeDifficulty({}, Difficulties) == nil, "tabel harus ditolak")
	end,
})

table.insert(cases, {
	name = "tiap tingkat punya store sendiri",
	run = function()
		local normal = LeaderboardRules.storeNameFor("normal")
		local hard = LeaderboardRules.storeNameFor("hard")
		assert(normal ~= hard, "LB-02: catatan normal dan hard tidak boleh satu store")
		assert(string.find(normal, "normal", 1, true) ~= nil, "nama store menyebut tingkatnya")
	end,
})

table.insert(cases, {
	name = "papan terurut menurun, seri dipecah userId",
	run = function()
		local ranked = LeaderboardRules.rank({ entry(3, 4), entry(1, 9), entry(2, 4) })
		assert(ranked[1].userId == 1, "wave 9 harus di atas")
		assert(ranked[2].userId == 2, "seri wave 4: userId kecil lebih dulu")
		assert(ranked[3].userId == 3, "seri wave 4: userId besar menyusul")
	end,
})

table.insert(cases, {
	name = "papan dipotong di batasnya, dan daftar masukan tidak diubah",
	run = function()
		local input = {}
		for index = 1, 15 do
			table.insert(input, entry(index, index))
		end
		local ranked = LeaderboardRules.rank(input, 10)
		assert(#ranked == 10, string.format("dapat %d baris, harus 10", #ranked))
		assert(ranked[1].wave == 15, "yang tertinggi harus ikut")
		assert(ranked[10].wave == 6, "baris ke-10 harus wave 6")
		assert(#input == 15, "daftar masukan tidak boleh ikut dipotong")
		assert(input[1].wave == 1, "daftar masukan tidak boleh ikut diurutkan")
	end,
})

table.insert(cases, {
	name = "rekor baru masuk papan tanpa membaca ulang store",
	run = function()
		local board = LeaderboardRules.merge({ entry(1, 5) }, 2, "Baru", 7)
		assert(#board == 2, "pemain baru harus masuk")
		assert(board[1].userId == 2 and board[1].wave == 7, "yang lebih tinggi naik ke atas")
	end,
})

table.insert(cases, {
	name = "merge menaikkan catatan pemain yang sudah ada, tidak menduplikasinya",
	run = function()
		local board = LeaderboardRules.merge({ entry(1, 5), entry(2, 4) }, 1, "P1", 9)
		assert(#board == 2, string.format("dapat %d baris, harus tetap 2", #board))
		assert(board[1].userId == 1 and board[1].wave == 9, "catatannya harus naik jadi 9")
	end,
})

table.insert(cases, {
	name = "merge tidak pernah menurunkan catatan yang sudah ada",
	run = function()
		local board = LeaderboardRules.merge({ entry(1, 8) }, 1, "P1", 3)
		assert(#board == 1, "tidak ada baris baru")
		assert(board[1].wave == 8, "LB-03: papan memori ikut menahan catatan di 8")
	end,
})

table.insert(cases, {
	name = "merge memperbarui nama pemain yang ganti username",
	run = function()
		local board = LeaderboardRules.merge({ entry(1, 8, "NamaLama") }, 1, "NamaBaru", 3)
		assert(board[1].name == "NamaBaru", "nama harus ikut diperbarui walau wave-nya tidak")
	end,
})

table.insert(cases, {
	name = "papan penuh menolak catatan yang lebih rendah dari baris terakhir",
	run = function()
		local full = {}
		for index = 1, 10 do
			table.insert(full, entry(index, 20 - index))
		end
		local board = LeaderboardRules.merge(full, 99, "Pendatang", 2, 10)
		assert(#board == 10, "papan tetap 10 baris")
		for _, row in board do
			assert(row.userId ~= 99, "catatan di bawah baris terakhir tidak masuk papan")
		end
	end,
})

table.insert(cases, {
	name = "merge dan isRecord selalu sepakat",
	run = function()
		-- Inti kontraknya: papan di memori dan tulisan ke OrderedDataStore
		-- memakai aturan yang sama. Diuji lintas rentang, bukan satu contoh,
		-- karena perbedaan di satu titik saja sudah cukup membuat papan
		-- "turun sendiri" setelah server restart.
		for previous = 1, 10 do
			for candidate = 0, 12 do
				local board = LeaderboardRules.merge({ entry(1, previous) }, 1, "P1", candidate)
				local expected = if LeaderboardRules.isRecord(previous, candidate)
					then candidate
					else previous
				assert(
					board[1].wave == expected,
					string.format(
						"previous %d, candidate %d: papan %d, harusnya %d",
						previous,
						candidate,
						board[1].wave,
						expected
					)
				)
			end
		end
	end,
})

return cases
