--!strict
-- init.client.luau — entry point client.
-- Jalan di device tiap player. Apapun di sini bisa dibaca & dimodifikasi
-- pemain yang niat ngecheat, jadi taruh presentasi/input saja di sisi ini.
--
-- Seperti init.server.luau, file ini cuma wiring: require controller, panggil
-- start(). Tidak ada logika di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Controllers = script.Controllers
local HudController = require(Controllers.HudController)
local InputController = require(Controllers.InputController)
local MatchStore = require(Controllers.MatchStore)
local ProfileStore = require(Controllers.ProfileStore)

local localPlayer = Players.LocalPlayer

print(string.format("[%s] client booting untuk %s", Config.GAME_NAME, localPlayer.Name))

-- MatchStore disambung PALING AWAL. Server menyiarkan `MatchState` secara
-- berkala, tapi siaran pertama bisa lewat sebelum controller lain siap, dan
-- store inilah yang menyimpannya supaya controller yang start() belakangan
-- tetap melihat state terkini.
MatchStore.start()
ProfileStore.start()

HudController.start()
InputController.start()

-- Dipakai nanti oleh controller lain; dibiarkan di sini supaya jelas kalau
-- remote ini memang sudah dipakai client.
Remotes.Events.EnemyHit.OnClientEvent:Connect(function(_payload: unknown)
	-- Efek hit masuk di FxController (M7, bagian 4). Payload-nya sengaja
	-- diabaikan sekarang, bukan dibiarkan tanpa listener, supaya jelas bahwa
	-- remote ini memang untuk efek saja dan tidak membawa keputusan apa pun.
end)
