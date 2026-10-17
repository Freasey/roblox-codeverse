-- run.luau — runner unit test Lune. Jalankan dengan `lune run tests/run`.
--
-- Hanya modul murni di src/shared/Modules yang bisa dites di sini: Lune tidak
-- punya DataModel, jadi apa pun yang memanggil game:GetService atau `script`
-- tidak bisa di-require. Itu sebabnya reconcile dipindah ke DataSchema.luau.

local process = require("@lune/process")

export type Case = { name: string, run: () -> () }

local suites: { { name: string, cases: { Case } } } = {
	{ name = "Smoke", cases = require("./Smoke.spec") },
	{ name = "DataSchema", cases = require("./DataSchema.spec") },
	{ name = "Balance", cases = require("./Balance.spec") },
	{ name = "Waves", cases = require("./Waves.spec") },
	{ name = "Lanes", cases = require("./Lanes.spec") },
	{ name = "HitTest", cases = require("./HitTest.spec") },
	{ name = "RateLimit", cases = require("./RateLimit.spec") },
}

local passed = 0
local failures: { string } = {}

for _, suite in suites do
	print(suite.name)
	for _, case in suite.cases do
		local ok, err = pcall(case.run)
		if ok then
			passed += 1
			print(string.format("  ok    %s", case.name))
		else
			local label = string.format("%s > %s", suite.name, case.name)
			table.insert(failures, string.format("%s\n    %s", label, tostring(err)))
			print(string.format("  FAIL  %s", case.name))
		end
	end
end

print("")
if #failures == 0 then
	print(string.format("%d test lulus", passed))
else
	print(string.format("%d lulus, %d gagal:", passed, #failures))
	for _, failure in failures do
		print("  " .. failure)
	end
	process.exit(1)
end
