--!nocheck
-- run.luau — runner test Studio. Jalankan dengan `lune run tests/studio/run`.
--
-- HANYA JALAN DI MESIN LOKAL YANG PUNYA ROBLOX STUDIO TERPASANG. Runner ini
-- memanggil `run-in-roblox`, yang membuka instalasi Studio asli. CI GitHub
-- (ubuntu-latest) tidak punya Studio, jadi jangan pernah menambahkan step ini
-- ke .github/workflows/ci.yml — yang didapat cuma CI merah yang tidak berarti
-- apa-apa. Unit test Lune di tests/run.luau tetap jalan di CI.
--
-- Alurnya: untuk tiap case, runner menggabungkan lib/prelude.luau + file
-- case-nya jadi satu sumber, menanamkannya ke dalam host.luau, menulis
-- hasilnya ke build/, lalu menyerahkannya ke `run-in-roblox --place --script`.
-- Keluaran Studio dipisahkan berdasarkan awalan `##CV##`, dan exit code runner
-- ditentukan dari situ, bukan dari exit code `run-in-roblox` (yang 0 bahkan
-- kalau script di dalamnya mati).
--
-- Pakai: lune run tests/studio/run [nama-case ...]

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = "tests/studio"
local PLACE = "build/codeverse.rbxl"
local SENTINEL = "##CV##"

type CaseSpec = {
	name: string,
	file: string,
	-- Deadline dipegang host di dalam Studio, bukan di sini: `run-in-roblox`
	-- tidak punya timeout sendiri, jadi satu-satunya yang menjamin prosesnya
	-- berhenti adalah host yang selalu sampai ke akhir.
	deadline: number,
}

local CASES: { CaseSpec } = {
	{ name = "boot", file = "cases/boot.luau", deadline = 90 },
	{ name = "enemy_core", file = "cases/enemy_core.luau", deadline = 150 },
	{ name = "remote_reject", file = "cases/remote_reject.luau", deadline = 120 },
}

-- --------------------------------------------------------------------------
-- Util
-- --------------------------------------------------------------------------

-- Sumber case ditanamkan ke host sebagai literal string Luau. Long bracket
-- dipakai, bukan quote, supaya tidak ada yang perlu di-escape — tapi levelnya
-- harus dipilih supaya penutupnya tidak pernah muncul di dalam sumbernya
-- sendiri, kalau tidak string-nya terpotong di tengah dan errornya sangat
-- membingungkan.
local function longBracket(source: string): string
	local level = 0
	while true do
		local eq = string.rep("=", level)
		if string.find(source, "]" .. eq .. "]", 1, true) == nil then
			return string.format("[%s[\n%s\n]%s]", eq, source, eq)
		end
		level += 1
	end
end

local function readFile(path: string): string
	if not fs.isFile(path) then
		error(string.format("file tidak ada: %s", path), 0)
	end
	return fs.readFile(path)
end

local function ensurePlace()
	-- `wally install` menghapus Packages/ kalau [dependencies] kosong, dan
	-- setelah itu $path "Packages" di default.project.json menunjuk ke
	-- direktori yang tidak ada dan rojo berhenti. Sama dengan yang dilakukan
	-- ci.yml.
	if not fs.isDir("Packages") then
		fs.writeDir("Packages")
	end
	if not fs.isDir("build") then
		fs.writeDir("build")
	end
	print("-> rojo build default.project.json --output " .. PLACE)
	local built = process.exec("rojo", { "build", "default.project.json", "--output", PLACE })
	if not built.ok then
		error(string.format("rojo build gagal (%d):\n%s", built.code, built.stderr), 0)
	end
end

-- --------------------------------------------------------------------------
-- Parsing keluaran
-- --------------------------------------------------------------------------

type Result = { status: string, name: string, detail: string }
type Parsed = {
	results: { Result },
	host: { { key: string, value: string } },
	ended: boolean,
	reported: { passed: number, failed: number, skipped: number },
}

local function parse(stdout: string): Parsed
	local parsed: Parsed = {
		results = {},
		host = {},
		ended = false,
		reported = { passed = 0, failed = 0, skipped = 0 },
	}
	for line in string.gmatch(stdout, "[^\r\n]+") do
		local payload = string.match(line, "^.-" .. SENTINEL .. "(.*)$")
		if payload == nil then
			continue
		end
		local kind = string.match(payload, "^(%a+)")
		if kind == "R" then
			local status, name, detail = string.match(payload, "^R\t([^\t]*)\t([^\t]*)\t?(.*)$")
			if status ~= nil then
				table.insert(parsed.results, {
					status = status,
					name = name or "?",
					detail = detail or "",
				})
			end
		elseif kind == "END" then
			local passed, failed, skipped = string.match(payload, "^END\t(%d+)\t(%d+)\t(%d+)$")
			if passed ~= nil then
				parsed.ended = true
				parsed.reported = {
					passed = tonumber(passed) :: number,
					failed = tonumber(failed) :: number,
					skipped = tonumber(skipped) :: number,
				}
			end
		elseif kind == "HOST" then
			local key, value = string.match(payload, "^HOST\t([^\t]*)\t?(.*)$")
			if key ~= nil then
				table.insert(parsed.host, { key = key, value = value or "" })
			end
		end
	end
	return parsed
end

-- --------------------------------------------------------------------------
-- Satu case
-- --------------------------------------------------------------------------

local function runCase(spec: CaseSpec, prelude: string, hostTemplate: string): Parsed
	local caseSource = prelude
		.. "\n-- ==== "
		.. spec.file
		.. " ====\n"
		.. readFile(ROOT .. "/" .. spec.file)

	-- Tiga placeholder di host.luau ditulis sebagai string literal supaya
	-- file-nya tetap Luau yang sah dan ikut terformat stylua.
	local script = hostTemplate
	script = string.gsub(script, '"__CASE_NAME__"', string.format("%q", spec.name), 1)
	script = string.gsub(
		script,
		'"__DEADLINE_SECONDS__"',
		string.format("%q", tostring(spec.deadline)),
		1
	)
	-- Sumber case diganti paling akhir: isinya bisa memuat teks apa pun,
	-- termasuk yang mirip placeholder lain.
	script = string.gsub(script, '"__CASE_SOURCE__"', function()
		return longBracket(caseSource)
	end, 1)

	local scriptPath = string.format("build/studio-%s.lua", spec.name)
	fs.writeFile(scriptPath, script)

	print(string.format("\n=== %s (deadline %ds) ===", spec.name, spec.deadline))
	print(string.format("-> run-in-roblox --place %s --script %s", PLACE, scriptPath))

	local started = os.clock()
	local invocation = process.exec("run-in-roblox", { "--place", PLACE, "--script", scriptPath })
	local elapsed = os.clock() - started

	local parsed = parse(invocation.stdout .. "\n" .. invocation.stderr)

	for _, entry in parsed.host do
		print(string.format("   host   %-18s %s", entry.key, entry.value))
	end
	for _, result in parsed.results do
		local detail = if result.detail ~= "" then "  -- " .. result.detail else ""
		print(string.format("   %-5s %s%s", result.status, result.name, detail))
	end
	print(
		string.format(
			"   %s: %d lulus, %d gagal, %d dilewati, %.1fs dinding",
			spec.name,
			parsed.reported.passed,
			parsed.reported.failed,
			parsed.reported.skipped,
			elapsed
		)
	)
	if not parsed.ended then
		print("   !! tidak ada baris END: script test mati sebelum selesai")
		print(string.format("   !! run-in-roblox exit=%d", invocation.code))
		-- Keluaran mentah cuma dicetak kalau ada yang salah. Studio mencetak
		-- cukup banyak sampah sehingga menampilkannya selalu bikin hasil yang
		-- benar jadi tidak terbaca.
		for line in string.gmatch(invocation.stdout, "[^\r\n]+") do
			print("   raw    " .. line)
		end
	end
	return parsed
end

-- --------------------------------------------------------------------------
-- Main
-- --------------------------------------------------------------------------

local function main()
	local wanted: { [string]: boolean }? = nil
	if #process.args > 0 then
		wanted = {}
		for _, arg in process.args do
			(wanted :: any)[arg] = true
		end
	end

	ensurePlace()
	local prelude = readFile(ROOT .. "/lib/prelude.luau")
	local hostTemplate = readFile(ROOT .. "/host.luau")

	local totals = { passed = 0, failed = 0, skipped = 0 }
	local broken: { string } = {}
	local ran = 0

	for _, spec in CASES do
		if wanted ~= nil and not wanted[spec.name] then
			continue
		end
		ran += 1
		local parsed = runCase(spec, prelude, hostTemplate)
		totals.passed += parsed.reported.passed
		totals.failed += parsed.reported.failed
		totals.skipped += parsed.reported.skipped
		if not parsed.ended then
			table.insert(broken, spec.name)
		end
		for _, result in parsed.results do
			if result.status == "FAIL" then
				table.insert(
					broken,
					string.format("%s > %s: %s", spec.name, result.name, result.detail)
				)
			end
		end
	end

	print("")
	if ran == 0 then
		print("tidak ada case yang cocok dengan argumen")
		process.exit(1)
	end
	print(
		string.format(
			"%d case: %d assertion lulus, %d gagal, %d dilewati",
			ran,
			totals.passed,
			totals.failed,
			totals.skipped
		)
	)
	if totals.skipped > 0 then
		print("dilewati = tidak dites sama sekali, bukan lulus. Lihat keterangannya di atas.")
	end
	if #broken > 0 then
		print("")
		print("gagal:")
		for _, entry in broken do
			print("  " .. entry)
		end
		process.exit(1)
	end
end

main()
