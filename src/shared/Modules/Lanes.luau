--!strict
-- Lanes.luau — urutan waypoint sebuah lane.
--
-- Kenapa modul sendiri untuk hal sesederhana ini: docs/DEVELOPMENT_PLAN.md
-- bagian 3.4 eksplisit bahwa urutan waypoint diambil dari NAMA Part ("1", "2",
-- ...) yang di-sort numerik, BUKAN dari urutan `GetChildren()`. Alasannya
-- `GetChildren()` tidak menjamin urutan apa pun, jadi lane bisa terbaca
-- 1-10-2-3 dan musuh berjalan zig-zag — bug yang cuma kelihatan setelah lane
-- punya lebih dari 9 waypoint, karena di bawah itu sort leksikografis dan sort
-- numerik kebetulan sama. Ditaruh di modul murni supaya bisa dites Lune di CI
-- tanpa DataModel.

local Lanes = {}

-- Nama waypoint harus "1".."n" tanpa bolong. Kalau ada yang bolong, musuh akan
-- melompat melewati sebagian jalur tanpa ada yang error — jadi lebih baik
-- ditolak keras dan dilaporkan ke user.
--
-- Mengembalikan (daftar nama terurut, nil) kalau valid, atau (nil, alasan)
-- kalau tidak.
function Lanes.orderWaypointNames(names: { string }): ({ string }?, string?)
	if #names == 0 then
		return nil, "tidak punya satu pun Part waypoint"
	end

	-- Nama aslinya disimpan, bukan cuma angkanya: pencarian child nanti pakai
	-- nama persis, jadi "01" harus tetap "01" meski nilainya 1.
	local entries: { { name: string, value: number } } = {}
	local seen: { [number]: boolean } = {}

	for _, name in names do
		local value = tonumber(name)
		if value == nil or value ~= math.floor(value) or value < 1 then
			return nil,
				string.format(
					"punya child bernama '%s'; nama waypoint harus bilangan bulat mulai dari 1",
					name
				)
		end
		if seen[value] then
			return nil, string.format("punya dua waypoint bernomor %d", value)
		end
		seen[value] = true
		table.insert(entries, { name = name, value = value })
	end

	table.sort(entries, function(a, b)
		return a.value < b.value
	end)

	local ordered: { string } = {}
	for index, entry in entries do
		if entry.value ~= index then
			return nil,
				string.format(
					"nomor waypoint-nya bolong: ada %d tapi tidak ada %d (harus 1 sampai %d tanpa bolong)",
					entry.value,
					index,
					#entries
				)
		end
		table.insert(ordered, entry.name)
	end
	return ordered, nil
end

return Lanes
