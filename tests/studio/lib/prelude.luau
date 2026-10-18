--!nocheck
-- prelude.luau — sisi SERVER dari harness Studio: assertion, akses log, dan
-- protokol hasil yang bisa dibaca mesin.
--
-- File ini tidak di-require, dia DITEMPEL di depan tiap file di cases/ oleh
-- run.luau, lalu hasilnya disuntikkan sebagai satu Script di
-- ServerScriptService. Alasannya sederhana: script yang diberikan ke
-- `run-in-roblox` tidak punya akses ke disk, jadi tidak ada cara me-require
-- file sebelahnya. Satu file, satu Script.
--
-- Protokol keluarannya baris tab-separated dengan awalan `##CV##`, supaya
-- runner bisa memisahkannya dari keluaran Studio yang lain (Studio sendiri
-- mencetak cukup banyak sampah: MaterialManager, ContentId gagal, dan lain-lain):
--
--   ##CV##R    <PASS|FAIL|SKIP>  <nama>   <keterangan>
--   ##CV##END  <lulus>  <gagal>  <dilewati>
--
-- Tidak ada baris END berarti script test mati di tengah jalan, dan runner
-- memperlakukan itu sebagai kegagalan — bukan sebagai "tidak ada test".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SENTINEL = "##CV##"
local LOG_FOLDER_NAME = "CodeVerseStudioLog"
local DONE_ATTRIBUTE = "CodeVerseStudioDone"

local T = {
	passed = 0,
	failed = 0,
	skipped = 0,
}

-- Keterangan harus aman untuk protokol: tab dan newline dibuang karena
-- keduanya pemisah kolom, dan teks panjang (misal pesan error 1 KB) dipotong.
local function clean(value: any): string
	local text = tostring(value)
	text = string.gsub(text, "[\t\r\n]+", " ")
	if #text > 400 then
		text = string.sub(text, 1, 400) .. " ...(dipotong)"
	end
	return text
end

local function report(status: string, name: string, detail: any)
	print(string.format("%sR\t%s\t%s\t%s", SENTINEL, status, name, clean(detail)))
end

function T.pass(name: string, detail: any?)
	T.passed += 1
	report("PASS", name, detail or "")
end

function T.fail(name: string, detail: any?)
	T.failed += 1
	report("FAIL", name, detail or "")
end

-- SKIP bukan sinonim lulus. Dipakai untuk hal yang harness ini memang tidak
-- bisa jangkau (paling sering: butuh Player sungguhan), dan keterangannya WAJIB
-- menyebut alasannya, supaya laporan tidak pernah terlihat hijau untuk sesuatu
-- yang tidak pernah dites.
function T.skip(name: string, reason: string)
	T.skipped += 1
	report("SKIP", name, reason)
end

function T.ok(name: string, condition: boolean, detail: any?)
	if condition then
		T.pass(name, detail)
	else
		T.fail(name, detail)
	end
end

function T.eq(name: string, actual: any, expected: any)
	if actual == expected then
		T.pass(name, clean(actual))
	else
		T.fail(name, string.format("dapat %s, harap %s", clean(actual), clean(expected)))
	end
end

function T.near(name: string, actual: number, expected: number, tolerance: number)
	local delta = math.abs(actual - expected)
	if delta <= tolerance then
		T.pass(name, string.format("%.3f (selisih %.3f)", actual, delta))
	else
		T.fail(name, string.format("dapat %.3f, harap %.3f +- %.3f", actual, expected, tolerance))
	end
end

-- --------------------------------------------------------------------------
-- Log
-- --------------------------------------------------------------------------
-- Diisi host dari konteks plugin (lihat host.luau). Yang penting: isinya
-- mencakup baris yang tercetak SEBELUM script ini jalan, termasuk seluruh
-- urutan boot init.server.luau. Itu sebabnya log tidak disadap di sini.

export type LogEntry = { level: string, text: string }

function T.log(): { LogEntry }
	local out: { LogEntry } = {}
	local folder = ReplicatedStorage:FindFirstChild(LOG_FOLDER_NAME)
	if folder == nil then
		return out
	end
	local children = folder:GetChildren()
	-- Nama entri di-pad nol oleh host, jadi urutan abjad = urutan waktu.
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		local value = (child :: StringValue).Value
		local level, text = string.match(value, "^([^\t]*)\t(.*)$")
		table.insert(out, { level = level or "Unknown", text = text or value })
	end
	return out
end

local function byLevel(level: string): { string }
	local out: { string } = {}
	for _, entry in T.log() do
		if entry.level == level then
			table.insert(out, entry.text)
		end
	end
	return out
end

function T.warnings(): { string }
	return byLevel("MessageWarning")
end

function T.errors(): { string }
	return byLevel("MessageError")
end

-- --------------------------------------------------------------------------
-- Memisahkan keluaran game dari keluaran Studio
-- --------------------------------------------------------------------------
-- Studio ikut mencetak ke Output yang sama dengan game: plugin bawaannya
-- (MaterialManager) melempar stack trace, dan pemuat asetnya mencetak
-- "ContentId: rbxassetid://... failed due to: Asset type does not match
-- requested type" pada waktu yang tidak tentu. Yang terakhir itu ketahuan
-- karena membuat test BOOT gagal di satu dari tiga run dengan pesan yang sama
-- sekali bukan milik kita — persis jenis flaky yang bikin orang berhenti
-- percaya pada test suite.
--
-- Jadi pemisahannya pakai allow-list, bukan deny-list sampah Studio: daftar
-- sampah Studio bisa bertambah kapan saja tanpa kita tahu, sementara bentuk
-- keluaran kita sendiri dikendalikan repo ini.
--
--   warn milik game  : SELALU diawali "[NamaService]". Dicek: ke-19 pemanggilan
--                      warn() di src/ memakai awalan itu (termasuk
--                      "[CodeVerse]" dari init.server.luau).
--   error milik game : error runtime Roblox selalu diawali path script yang
--                      melemparnya, dan script game selalu berada di bawah
--                      ServerScriptService / ReplicatedStorage / ServerStorage.
--
-- BATASNYA, dan ini harus disebut: `warn("teks tanpa awalan")` yang suatu saat
-- ditambahkan di src/ akan dilewatkan harness ini tanpa suara. Karena itu case
-- BOOT ikut mencetak isi pesan yang DIBUANG, supaya yang membaca hasil run
-- selalu bisa melihat apa yang tidak dihitung.

local GAME_PATH_PREFIXES = {
	"ServerScriptService.",
	"ReplicatedStorage.",
	"ServerStorage.",
	"ReplicatedFirst.",
}

local function looksLikeGameError(text: string): boolean
	for _, prefix in GAME_PATH_PREFIXES do
		if string.find(text, prefix, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- Warn yang berasal dari kode di src/.
function T.gameWarnings(): { string }
	local out: { string } = {}
	for _, text in T.warnings() do
		if string.sub(text, 1, 1) == "[" then
			table.insert(out, text)
		end
	end
	return out
end

-- Error yang berasal dari kode di src/ atau dari script case ini sendiri.
function T.gameErrors(): { string }
	local out: { string } = {}
	for _, text in T.errors() do
		if looksLikeGameError(text) then
			table.insert(out, text)
		end
	end
	return out
end

-- Yang dibuang oleh dua fungsi di atas. Dipakai case untuk melaporkannya,
-- supaya tidak ada pesan yang hilang tanpa jejak.
function T.foreignMessages(): { string }
	local out: { string } = {}
	for _, text in T.warnings() do
		if string.sub(text, 1, 1) ~= "[" then
			table.insert(out, "warn: " .. text)
		end
	end
	for _, text in T.errors() do
		if not looksLikeGameError(text) then
			table.insert(out, "error: " .. text)
		end
	end
	return out
end

-- Pencarian teks apa adanya (plain), bukan pola Lua: baris log penuh tanda
-- kurung siku dan tanda kurung, yang semuanya punya arti khusus di pola Lua.
function T.logFind(needle: string): string?
	for _, entry in T.log() do
		if string.find(entry.text, needle, 1, true) ~= nil then
			return entry.text
		end
	end
	return nil
end

function T.logContains(needle: string): boolean
	return T.logFind(needle) ~= nil
end

-- --------------------------------------------------------------------------
-- Waktu
-- --------------------------------------------------------------------------
-- Catatan yang penting untuk semua test berbasis waktu di sini: Studio yang
-- dijalankan `run-in-roblox` berjalan di sekitar 8 Hz, bukan 60 Hz. Logika yang
-- memakai deltaTime tetap benar, tapi granularitasnya kasar — jangan menulis
-- assertion yang menuntut presisi sub-frame.

function T.waitUntil(predicate: () -> boolean, seconds: number?): boolean
	local deadline = os.clock() + (seconds or 10)
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

-- --------------------------------------------------------------------------
-- Entry point
-- --------------------------------------------------------------------------
-- Dipakai tiap case: `T.main(function() ... end)`. Body dibungkus pcall supaya
-- error di tengah case tetap menghasilkan satu baris FAIL dan satu baris END.
-- Tanpa ini, case yang error akan membuat host menunggu sampai deadline dan
-- runner melaporkan timeout, yang menyembunyikan penyebab sebenarnya.
function T.main(body: () -> ())
	local ok, err = pcall(body)
	if not ok then
		T.fail("case.error", err)
	end
	print(string.format("%sEND\t%d\t%d\t%d", SENTINEL, T.passed, T.failed, T.skipped))
	workspace:SetAttribute(DONE_ATTRIBUTE, true)
end
