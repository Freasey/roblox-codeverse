--!nocheck
-- host.luau — sisi PLUGIN dari harness Studio. Bukan modul Lune dan bukan
-- bagian dari game: file ini template yang diisi `run.luau` lalu diserahkan ke
-- `run-in-roblox --script`.
--
-- Kenapa ada dua sisi. `run-in-roblox` menjalankan script yang kita berikan di
-- dalam Studio pada PLUGIN security, di EDIT mode: `RunService:IsRunning()`
-- masih false dan tidak satu pun Script di place yang pernah dieksekusi. Lebih
-- jauh lagi, `require` dari konteks plugin punya cache sendiri — me-require
-- MapService dari sini menghasilkan SALINAN BARU, bukan instance yang dipakai
-- server. (Buktinya: "[MapService] Arena siap" tercetak dua kali.) Jadi plugin
-- tidak bisa memeriksa state server yang sedang jalan.
--
-- Karena itu host ini tidak menguji apa pun sendiri. Dia:
--   1. menyadap LogService SEBELUM apa pun jalan, supaya baris boot yang
--      tercetak lebih dulu dari script test tetap terekam, lalu menuangkannya
--      ke ReplicatedStorage sebagai StringValue supaya sisi server bisa
--      membacanya (dua konteks tidak berbagi variabel Lua, tapi berbagi
--      DataModel);
--   2. menyuntikkan script test sebagai Script biasa di ServerScriptService,
--      yang berarti dia jalan di konteks server dan BERBAGI cache require
--      dengan init.server.luau — ini yang membuat dia bisa memanggil service
--      yang sungguh-sungguh hidup;
--   3. memanggil `RunService:Run()` (ada di plugin security) untuk memulai
--      server, menunggu script test memasang atribut selesai, lalu `Stop()`.
--
-- Deadline-nya ada di sini, bukan di runner: `run-in-roblox` tidak punya
-- timeout, jadi satu-satunya yang menjamin prosesnya berhenti adalah host yang
-- selalu sampai ke akhir.

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Tiga baris di bawah ditulis ulang oleh run.luau sebelum file ini dipakai.
local CASE_NAME = "__CASE_NAME__"
local CASE_SOURCE = "__CASE_SOURCE__"
local DEADLINE_SECONDS = tonumber("__DEADLINE_SECONDS__") or 120

local SENTINEL = "##CV##"
local LOG_FOLDER_NAME = "CodeVerseStudioLog"
local DONE_ATTRIBUTE = "CodeVerseStudioDone"

local function emit(kind: string, ...)
	local parts = { SENTINEL .. kind }
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	print(table.concat(parts, "\t"))
end

-- Jembatan log plugin -> server. Dipasang paling awal: kalau dipasang setelah
-- Run(), baris boot pertama sudah lewat dan test BOOT akan gagal karena alasan
-- yang salah.
local logFolder = Instance.new("Folder")
logFolder.Name = LOG_FOLDER_NAME
logFolder.Parent = ReplicatedStorage

local captured = 0
LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
	-- Jangan merekam suara sendiri: baris hasil test juga lewat print, dan
	-- kalau ikut masuk log, assertion "tidak ada warn" bisa membaca hasilnya
	-- sendiri.
	if string.sub(message, 1, #SENTINEL) == SENTINEL then
		return
	end
	captured += 1
	local entry = Instance.new("StringValue")
	entry.Name = string.format("%05d", captured)
	entry.Value = messageType.Name .. "\t" .. message
	entry.Parent = logFolder
end)

local caseScript = Instance.new("Script")
caseScript.Name = "CodeVerseStudioCase"
caseScript.Source = CASE_SOURCE
caseScript.Parent = ServerScriptService

emit("HOST", "case", CASE_NAME)
emit("HOST", "sourceBytes", #CASE_SOURCE)
emit("HOST", "isRunningBefore", RunService:IsRunning())

local startedAt = os.clock()
local runOk, runErr = pcall(function()
	RunService:Run()
end)
emit("HOST", "runCall", runOk, tostring(runErr))

local finished = false
while os.clock() - startedAt < DEADLINE_SECONDS do
	if workspace:GetAttribute(DONE_ATTRIBUTE) == true then
		finished = true
		break
	end
	task.wait(0.1)
end

emit("HOST", "finished", finished)
emit("HOST", "elapsedSeconds", string.format("%.1f", os.clock() - startedAt))
emit("HOST", "logEntries", captured)

pcall(function()
	RunService:Stop()
end)

emit("HOST", "end")
