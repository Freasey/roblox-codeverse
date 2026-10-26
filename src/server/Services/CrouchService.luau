--!strict
-- CrouchService.luau — jongkok, dan yang menuliskannya ke karakter.
--
-- Jongkok di sini CUMA dua hal: badan turun dan jalan jadi setengah kecepatan.
-- Tidak ada efek gameplay sama sekali -- tidak mengurangi damage yang masuk,
-- tidak menambah jangkauan, tidak mengubah apa pun yang dihitung CombatService.
-- Itu disengaja, dan bukan karena belum sempat: jongkok dikendalikan client,
-- dan client yang dimodifikasi bisa mengirim "aku jongkok" tanpa pernah
-- melambat. Jadi keuntungan apa pun yang diberikan karena jongkok adalah
-- keuntungan gratis bagi yang mencurangi dan harga yang sungguhan bagi yang
-- tidak. Selama jongkok cuma memperlambat diri sendiri, tidak ada yang bisa
-- dicurangi darinya.
--
-- KENAPA DI SERVER, padahal yang menekan tombol client. Properti yang ditulis
-- script client cuma berlaku di layar client itu: kalau `HipHeight` dan
-- `WalkSpeed` ditulis di sana saja, pemain melihat dirinya jongkok sementara
-- tiga pemain lain melihatnya berdiri. Yang ditulis server direplikasi ke
-- semua. Client tetap menuliskannya juga, untuk dirinya sendiri, supaya
-- tombolnya tidak menunggu satu perjalanan jaringan -- angkanya dibaca dari
-- `CrouchRules` yang sama, jadi dua tulisan itu tidak bisa berbeda.
--
-- Kecepatan dan HipHeight BERDIRI dicatat saat karakter muncul, bukan dibaca
-- saat jongkok. Dibaca saat jongkok, nilai yang terbaca adalah nilai yang
-- sudah separuh kalau pemain sudah jongkok, dan berdiri kembali akan
-- mengembalikannya ke setengah kecepatan -- pelan-pelan, tiap kali.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CrouchRules = require(Shared.Modules.CrouchRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)

local CrouchService = {}

-- 6 per detik: cukup untuk menekan tombolnya secepat yang manusia bisa, dan
-- jauh di bawah apa pun yang membebani server.
local limiter = RateLimit.newRegistry({ SetCrouch = 6 }, 6)

-- Cuma kecepatan dan HipHeight BERDIRI yang disimpan. Keadaan jongkok itu
-- sendiri tidak: yang menyimpannya Humanoid pemain, dan tabel kedua yang
-- mencatat hal yang sama cuma menunggu sampai keduanya berbeda.
local standing: { [number]: { speed: number, hipHeight: number } } = {}
local started = false

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function apply(player: Player, humanoid: Humanoid, wantCrouch: boolean)
	local base = standing[player.UserId]
	local baseSpeed = if base ~= nil then base.speed else CrouchRules.DEFAULT_SPEED
	local baseHip = if base ~= nil then base.hipHeight else CrouchRules.DEFAULT_HIP_HEIGHT

	humanoid.WalkSpeed = CrouchRules.speedFor(baseSpeed, wantCrouch)
	humanoid.HipHeight = CrouchRules.hipHeightFor(baseHip, wantCrouch)
	-- Kamera cuma berarti bagi pemain yang punya karakter ini, tapi tetap
	-- ditulis di sini: satu tempat yang menulis ketiga properti lebih mudah
	-- dipercaya daripada dua tempat yang masing-masing menulis sebagian.
	humanoid.CameraOffset = Vector3.new(0, CrouchRules.cameraDropFor(wantCrouch), 0)
end

local function onSetCrouch(player: Player, rawWant: unknown)
	if not RateLimit.check(limiter, player.UserId, "SetCrouch", os.clock()) then
		return
	end
	if type(rawWant) ~= "boolean" then
		return
	end
	local wantCrouch = rawWant :: boolean

	local humanoid = humanoidOf(player)
	if humanoid == nil then
		-- Karakter belum ada atau sudah mati. Tidak dibalas `ActionResult`:
		-- pemain yang karakternya mati tidak sedang menunggu kabar soal
		-- jongkoknya, dan karakter berikutnya lahir berdiri sendiri.
		return
	end

	apply(player, humanoid, wantCrouch)
end

function CrouchService.start()
	if started then
		return
	end
	started = true

	Remotes.Events.SetCrouch.OnServerEvent:Connect(onSetCrouch)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			-- Karakter baru lahir berdiri tanpa perlu dibereskan: Humanoid-nya
			-- Humanoid baru, dengan WalkSpeed dan HipHeight default. Yang
			-- dicatat di sini justru angka default itu, karena itulah
			-- "kecepatan berdiri" pemain ini sampai karakternya berganti lagi.
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid == nil or not humanoid:IsA("Humanoid") then
				return
			end
			standing[player.UserId] = {
				speed = humanoid.WalkSpeed,
				hipHeight = humanoid.HipHeight,
			}
		end)

		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				standing[player.UserId] = {
					speed = humanoid.WalkSpeed,
					hipHeight = humanoid.HipHeight,
				}
			end
		end
	end

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		standing[player.UserId] = nil
		RateLimit.forget(limiter, player.UserId)
	end)

	print("[CrouchService] siap")
end

return CrouchService
