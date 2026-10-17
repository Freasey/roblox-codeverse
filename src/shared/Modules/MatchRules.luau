--!strict
-- MatchRules.luau — keputusan match yang bisa dihitung tanpa DataModel.
--
-- Kenapa dipisah dari MatchService dan WaveService: dua service itu menyentuh
-- Players, RunService, dan Instance, jadi tidak bisa di-require Lune dan tidak
-- bisa dites di CI. Tiga hal di bawah ini justru yang paling mudah salah dan
-- paling sulit dilihat dari playtest, jadi logikanya ditaruh di modul murni:
--
--   1. membagi jumlah musuh satu wave menurut `share` tanpa kehilangan sisa,
--   2. mengurutkan spawn supaya tipe musuh tercampur dan lane terbagi rata,
--   3. memilih kesulitan match dari pilihan beberapa pemain yang bisa berbeda.

local Types = require("./Types")

local MatchRules = {}

-- Bagi `total` musuh menurut bobot `share` tiap entry.
--
-- Pembagian naif (`math.floor(total * share / sum)`) membuang sisa bagi: wave
-- dengan share {3, 1} dan total 10 menghasilkan 7 + 2 = 9 musuh, satu hilang.
-- Satu musuh hilang tidak kelihatan; sepuluh wave x empat player kehilangan
-- belasan musuh dan seluruh kurva kesulitan jadi lebih ringan dari yang
-- dihitung Balance.luau. Jadi pakai metode sisa terbesar: bagi rata dulu, lalu
-- bagikan sisanya ke entry dengan pecahan terbesar.
--
-- Mengembalikan daftar jumlah yang urutannya sama dengan `entries`, dan
-- jumlahnya PERSIS `total`.
function MatchRules.splitByShare(entries: { Types.WaveEntry }, total: number): { number }
	local counts: { number } = {}
	if #entries == 0 or total <= 0 then
		for index = 1, #entries do
			counts[index] = 0
		end
		return counts
	end

	local shareSum = 0
	for _, entry in entries do
		shareSum += math.max(0, entry.share)
	end
	if shareSum <= 0 then
		-- Semua share nol atau negatif: bagi rata, jangan membagi nol.
		local base = total // #entries
		local leftover = total - base * #entries
		for index = 1, #entries do
			counts[index] = base + (if index <= leftover then 1 else 0)
		end
		return counts
	end

	local assigned = 0
	local remainders: { { index: number, fraction: number } } = {}
	for index, entry in entries do
		local exact = total * math.max(0, entry.share) / shareSum
		local floored = math.floor(exact)
		counts[index] = floored
		assigned += floored
		table.insert(remainders, { index = index, fraction = exact - floored })
	end

	-- Sisa dibagikan ke pecahan terbesar. `index` jadi pemecah seri supaya
	-- hasilnya deterministik — dua server dengan input yang sama harus
	-- menghasilkan wave yang sama.
	table.sort(remainders, function(a, b)
		if a.fraction == b.fraction then
			return a.index < b.index
		end
		return a.fraction > b.fraction
	end)

	local leftover = total - assigned
	local position = 1
	while leftover > 0 and #remainders > 0 do
		local target = remainders[position]
		counts[target.index] += 1
		leftover -= 1
		position += 1
		if position > #remainders then
			position = 1
		end
	end

	return counts
end

export type SpawnOrder = {
	enemyId: string,
	laneIndex: number,
}

-- Susun urutan spawn satu wave.
--
-- Kenapa tidak sekadar "semua basic dulu, lalu semua fast": musuh di-spawn satu
-- per SPAWN_INTERVAL, jadi urutan antrian itu persis urutan kemunculan di
-- arena. Kalau diurutkan per tipe, pemain menghadapi 20 basic yang identik lalu
-- 10 fast — bukan campuran yang dirancang di Waves.luau. Jadi antriannya
-- di-interleave: putaran demi putaran, tiap tipe menyumbang satu sampai
-- jatahnya habis.
--
-- Lane dibagikan round-robin, bukan acak, supaya dua lane benar-benar terpakai
-- seimbang. Acak dengan 8 musuh bisa menaruh 7 di satu lane.
function MatchRules.spawnOrder(
	entries: { Types.WaveEntry },
	total: number,
	laneCount: number
): { SpawnOrder }
	local counts = MatchRules.splitByShare(entries, total)
	local remaining = table.clone(counts)
	local lanes = math.max(1, laneCount)

	local order: { SpawnOrder } = {}
	local produced = 0
	local anyLeft = true

	while anyLeft do
		anyLeft = false
		for index, entry in entries do
			if remaining[index] > 0 then
				remaining[index] -= 1
				anyLeft = true
				table.insert(order, {
					enemyId = entry.enemyId,
					laneIndex = produced % lanes + 1,
				})
				produced += 1
			end
		end
	end

	return order
end

-- Pilih kesulitan match dari pilihan beberapa pemain.
--
-- Rencana development tidak menyebut apa yang terjadi kalau dua pemain memilih
-- kesulitan berbeda, jadi dipilih yang paling konservatif: AMBIL YANG PALING
-- MUDAH. Alasannya, kesulitan `hard` harus dibuka dulu per pemain (bagian 3.1),
-- jadi aturan apa pun yang mengambil yang lebih sulit bisa memaksa pemain ikut
-- match pada tingkat yang belum dia buka. Mengambil yang termudah tidak pernah
-- bisa melakukan itu.
--
-- "Paling mudah" diukur dari `hpMult`, bukan dari urutan di tabel, supaya
-- menambah tingkat baru nanti tidak perlu menyentuh fungsi ini. Seri dipecah
-- dengan id supaya hasilnya deterministik.
function MatchRules.easiestDifficulty(
	ids: { string },
	defs: { [string]: Types.DifficultyDef }
): string?
	local bestId: string? = nil
	local bestMult = math.huge

	for _, id in ids do
		local def = defs[id]
		if def ~= nil then
			if
				def.hpMult < bestMult or (def.hpMult == bestMult and bestId ~= nil and id < bestId)
			then
				bestId = id
				bestMult = def.hpMult
			end
		end
	end

	return bestId
end

return MatchRules
