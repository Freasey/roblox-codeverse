--!strict
-- init.client.luau — entry point client.
-- Jalan di device tiap player. Apapun di sini bisa dibaca & dimodifikasi
-- pemain yang niat ngecheat, jadi taruh presentasi/input saja di sisi ini.
--
-- Seperti init.server.luau, file ini cuma wiring: require controller, panggil
-- start(). Tidak ada logika di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- `Remotes` tidak lagi di-require di sini. Dulu file ini menyambung `EnemyHit`
-- sendiri sebagai penampung sementara; sekarang tiap remote dipegang
-- controller yang memang memakainya, dan file ini kembali murni wiring.
local Config = require(ReplicatedStorage.Shared.Config)

local Controllers = script.Controllers
local CameraController = require(Controllers.CameraController)
local CharacterAnimatorController = require(Controllers.CharacterAnimatorController)
local FxController = require(Controllers.FxController)
local GuideController = require(Controllers.GuideController)
local HudController = require(Controllers.HudController)
local InfoCardController = require(Controllers.InfoCardController)
local InputController = require(Controllers.InputController)
local LeaderboardController = require(Controllers.LeaderboardController)
local LobbyController = require(Controllers.LobbyController)
local MatchStore = require(Controllers.MatchStore)
local ProfileStore = require(Controllers.ProfileStore)
local ResultController = require(Controllers.ResultController)
local ShopController = require(Controllers.ShopController)
local StanceController = require(Controllers.StanceController)
local TutorialController = require(Controllers.TutorialController)

local localPlayer = Players.LocalPlayer

print(string.format("[%s] client booting untuk %s", Config.GAME_NAME, localPlayer.Name))

-- MatchStore disambung PALING AWAL. Server menyiarkan `MatchState` secara
-- berkala, tapi siaran pertama bisa lewat sebelum controller lain siap, dan
-- store inilah yang menyimpannya supaya controller yang start() belakangan
-- tetap melihat state terkini.
MatchStore.start()
ProfileStore.start()

-- Animator dijalankan lebih dulu daripada controller UI. Bukan soal urutan
-- yang rapi: dia menyambung `Players.PlayerAdded`, dan pemain yang sudah ada
-- di server saat client ini masuk ditangani lewat sapuan awal di dalam
-- start(). Menjalankannya belakangan tidak merusak apa pun, tapi karakter yang
-- spawn di sela-sela itu baru teranimasi satu frame kemudian dan kedipannya
-- terlihat saat masuk lobby.
CharacterAnimatorController.start()

-- Kamera sebelum FX, dan itu bukan kerapian: `FxController` me-require
-- `CameraController` untuk memicu guncangan. Dijalankan terbalik, guncangan
-- pertama bisa tiba sebelum kamera punya nilai awalnya dan hasilnya satu
-- sentakan di frame pertama match.
CameraController.start()
FxController.start()

StanceController.start()
GuideController.start()

HudController.start()
InputController.start()
LobbyController.start()
LeaderboardController.start()
ResultController.start()
ShopController.start()
InfoCardController.start()
TutorialController.start()

-- `EnemyHit` dulu disambung di file ini sebagai listener kosong, menunggu
-- FxController yang belum ada. FxController sekarang ada dan dialah yang
-- memegang remote itu, jadi listener kosongnya dihapus, dua listener untuk
-- satu remote berarti tiap musuh kena memicu dua kali, dan yang kedua tidak
-- melakukan apa pun selain membuat orang mengira ada efek yang tidak muncul.

-- Yang tidak berubah: remote ini tetap UNTUK EFEK SAJA. Tidak ada keputusan
-- gameplay yang boleh diambil darinya; HP musuh yang sebenarnya hidup di
-- server.
