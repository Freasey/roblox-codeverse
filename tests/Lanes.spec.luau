-- Lanes.spec.luau — urutan waypoint diambil dari nama yang di-sort NUMERIK
-- (docs/DEVELOPMENT_PLAN.md bagian 3.4).
--
-- Test paling penting di file ini adalah yang memakai 10 waypoint atau lebih:
-- di bawah 10, sort leksikografis dan sort numerik kebetulan memberi hasil yang
-- sama, jadi bug "aku sort string, bukan angka" tidak akan kelihatan. Baru
-- setelah ada "10" barulah "10" < "2" secara leksikografis dan musuh mulai
-- berjalan zig-zag.

local Lanes = require("../src/shared/Modules/Lanes")

local cases = {}

local function assertEqualList(got, expected, label)
	assert(got ~= nil, label .. ": hasilnya nil")
	assert(
		#got == #expected,
		string.format("%s: panjang %d, diharapkan %d", label, #got, #expected)
	)
	for index, value in expected do
		assert(
			got[index] == value,
			string.format("%s: index %d = '%s', diharapkan '%s'", label, index, got[index], value)
		)
	end
end

table.insert(cases, {
	name = "nama yang sudah berurutan tetap berurutan",
	run = function()
		local ordered, problem = Lanes.orderWaypointNames({ "1", "2", "3" })
		assert(problem == nil, tostring(problem))
		assertEqualList(ordered, { "1", "2", "3" }, "urutan")
	end,
})

table.insert(cases, {
	name = "nama yang acak di-sort numerik",
	run = function()
		local ordered, problem = Lanes.orderWaypointNames({ "3", "1", "4", "2" })
		assert(problem == nil, tostring(problem))
		assertEqualList(ordered, { "1", "2", "3", "4" }, "urutan")
	end,
})

table.insert(cases, {
	name = "sort numerik, BUKAN leksikografis (kasus 10 waypoint)",
	run = function()
		local names = { "10", "2", "7", "1", "5", "3", "9", "4", "8", "6" }
		local ordered, problem = Lanes.orderWaypointNames(names)
		assert(problem == nil, tostring(problem))
		assertEqualList(
			ordered,
			{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
			"urutan numerik"
		)
		-- Pengecekan eksplisit: sort leksikografis akan menaruh "10" di depan.
		assert(ordered[1] == "1", "sort leksikografis: '10' jadi pertama")
		assert(ordered[10] == "10", "'10' harus jadi waypoint terakhir")
	end,
})

table.insert(cases, {
	name = "lane kosong ditolak",
	run = function()
		local ordered, problem = Lanes.orderWaypointNames({})
		assert(ordered == nil, "lane kosong seharusnya ditolak")
		assert(problem ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "nama non-angka ditolak",
	run = function()
		local ordered, problem = Lanes.orderWaypointNames({ "1", "Start", "3" })
		assert(ordered == nil, "nama non-angka seharusnya ditolak")
		assert(
			problem ~= nil and string.find(problem, "Start") ~= nil,
			"alasan harus menyebut nama yang salah"
		)
	end,
})

table.insert(cases, {
	name = "nomor yang bolong ditolak",
	run = function()
		-- Kalau ini lolos, musuh akan melompat dari waypoint 2 ke 4 tanpa ada
		-- yang error, dan jalurnya memotong geometry arena.
		local ordered, problem = Lanes.orderWaypointNames({ "1", "2", "4" })
		assert(ordered == nil, "nomor bolong seharusnya ditolak")
		assert(problem ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "nomor dobel ditolak",
	run = function()
		local ordered, problem = Lanes.orderWaypointNames({ "1", "2", "2" })
		assert(ordered == nil, "nomor dobel seharusnya ditolak")
		assert(problem ~= nil, "harus ada alasan")
	end,
})

table.insert(cases, {
	name = "nol dan angka negatif ditolak",
	run = function()
		for _, bad in { "0", "-1" } do
			local ordered = Lanes.orderWaypointNames({ bad, "1" })
			assert(ordered == nil, string.format("'%s' seharusnya ditolak", bad))
		end
	end,
})

table.insert(cases, {
	name = "angka berkoma ditolak",
	run = function()
		local ordered = Lanes.orderWaypointNames({ "1", "1.5", "2" })
		assert(ordered == nil, "'1.5' seharusnya ditolak")
	end,
})

table.insert(cases, {
	name = "nama asli dikembalikan, bukan hasil tostring",
	run = function()
		-- "01" dan "1" sama nilainya, tapi pencarian child di Studio memakai
		-- nama persis. Kalau modul mengembalikan "1" untuk Part bernama "01",
		-- lookup-nya gagal dan lane terbaca kosong.
		local ordered, problem = Lanes.orderWaypointNames({ "2", "01" })
		assert(problem == nil, tostring(problem))
		assertEqualList(ordered, { "01", "2" }, "nama asli")
	end,
})

return cases
