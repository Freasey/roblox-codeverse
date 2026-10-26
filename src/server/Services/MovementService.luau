--!strict
-- MovementService.luau: penegak aturan gerak pemain (Soal 4).
--
-- Client mengirim NIAT lewat `Remotes.MoveIntent`; service ini yang memutuskan
-- apakah niat itu jadi kenyataan. Yang dipegang server: kecepatan jalan,
-- tinggi lompat, stamina, dan dorongan dash. Tidak satu pun dari empat itu
-- boleh ditentukan client, `Humanoid.WalkSpeed` yang disetel client memang
-- berlaku di layarnya sendiri, tapi server tidak akan pernah mengakuinya, dan
-- posisi yang dianggap benar tetap milik server.
--
-- Angkanya sendiri tidak ada di file ini. Semuanya di
-- `Shared.Modules.MoveRules`, yang juga di-require client untuk menggambar bar
-- stamina, jadi bar di layar tidak pernah bisa bercerita berbeda dari apa
-- yang ditegakkan di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MoveRules = require(Shared.Modules.MoveRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)

local MovementService = {}

local started = false

type Entry = {
	stance: string,
	requested: string,
	stamina: number,
	lastDashAt: number,
	dashUntil: number,
}

local entries: { [number]: Entry } = {}
local accumulator = 0

-- Atribut dikirim ulang paling cepat 10 kali per detik, bukan tiap frame.
--
-- Atribut direplikasi ke SEMUA client, jadi menuliskannya 60 kali per detik
-- untuk empat pemain berarti 240 pesan per detik untuk angka yang berubah
-- terlalu halus untuk dilihat mata. Sepuluh kali per detik sudah membuat bar
-- stamina terlihat mulus.
local ATTRIBUTE_INTERVAL = 0.1

local function newEntry(): Entry
	return {
		stance = "walk",
		requested = "walk",
		stamina = MoveRules.MAX_STAMINA,
		lastDashAt = -math.huge,
		dashUntil = 0,
	}
end

local function getEntry(userId: number): Entry
	local entry = entries[userId]
	if entry == nil then
		entry = newEntry()
		entries[userId] = entry
	end
	return entry
end

local function characterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return humanoid, nil
	end
	return humanoid, root
end

-- Dorongan dash: kecepatan datar diganti, kecepatan vertikal DIPERTAHANKAN.
--
-- Mempertahankan Y itu syarat, bukan detail. Menimpanya dengan nol membuat
-- pemain yang dash saat melompat langsung membeku di udara lalu jatuh lurus;
-- menimpanya dengan nilai positif menjadikan dash sebagai lompatan kedua tak
-- terbatas yang bisa dipakai memanjat keluar arena.
local function applyDash(player: Player, entry: Entry, now: number): boolean
	local humanoid, root = characterParts(player)
	if humanoid == nil or root == nil then
		return false
	end
	if not MoveRules.canDash(entry.stamina, now, entry.lastDashAt) then
		return false
	end

	-- Arah diambil dari gerak pemain menurut SERVER. Kalau pemain sedang diam,
	-- dash mengikuti arah hadap badannya.
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return false
	end
	flat = flat.Unit

	entry.stamina = math.max(0, entry.stamina - MoveRules.DASH_COST)
	entry.lastDashAt = now
	entry.dashUntil = now + MoveRules.DASH_DURATION

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity =
		Vector3.new(flat.X * MoveRules.DASH_SPEED, velocity.Y, flat.Z * MoveRules.DASH_SPEED)
	return true
end

local function step(dt: number)
	local now = os.clock()

	for _, player in Players:GetPlayers() do
		local entry = entries[player.UserId]
		if entry ~= nil then
			local humanoid, root = characterParts(player)
			if humanoid ~= nil then
				local dashing = now < entry.dashUntil

				-- Apakah pemain benar-benar bergerak, menurut server. Dipakai
				-- supaya sprint di tempat tidak menguras stamina.
				local moving = false
				if root ~= nil then
					local velocity = root.AssemblyLinearVelocity
					moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
				end

				local resolved = MoveRules.resolveStance(
					entry.requested,
					entry.stamina,
					entry.stance == "sprint"
				)
				entry.stance = resolved

				-- Stamina tidak pulih selama dash masih berlangsung: tanpa ini
				-- pemain mendapat sebagian biayanya kembali seketika, dan
				-- cooldown jadi satu-satunya batas dash.
				if not dashing then
					entry.stamina = MoveRules.stepStamina(entry.stamina, resolved, moving, dt)
				end

				humanoid.WalkSpeed = MoveRules.speedFor(resolved)
				humanoid.JumpHeight = MoveRules.jumpHeightFor(resolved)

				local character = humanoid.Parent
				if character ~= nil then
					-- Dua atribut inilah satu-satunya jalan animator di client
					-- mengetahui sikap pemain LAIN. `Humanoid.WalkSpeed` saja
					-- tidak cukup: berjalan pelan karena jongkok dan berjalan
					-- pelan karena baru mulai melangkah terlihat sama dari
					-- kecepatan, padahal pose-nya harus berbeda.
					character:SetAttribute("Stance", resolved)
					character:SetAttribute("Dashing", dashing)
				end
			end
		end
	end

	-- Stamina disiarkan lebih jarang daripada perhitungannya.
	accumulator += dt
	if accumulator >= ATTRIBUTE_INTERVAL then
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local entry = entries[player.UserId]
			local character = player.Character
			if entry ~= nil and character ~= nil then
				character:SetAttribute("Stamina", math.floor(entry.stamina + 0.5))
			end
		end
	end
end

function MovementService.getStamina(userId: number): number
	local entry = entries[userId]
	return if entry ~= nil then entry.stamina else MoveRules.MAX_STAMINA
end

function MovementService.start()
	if started then
		return
	end
	started = true

	local ok, err = MoveRules.validate()
	if not ok then
		warn(string.format("[%s] aturan gerak tidak valid: %s", Config.GAME_NAME, tostring(err)))
	end

	-- 12 per detik. Pemain yang menahan Shift dan C bergantian secepat mungkin
	-- tetap di bawah angka ini, sementara client yang dimodifikasi dan
	-- mengirim ribuan niat per detik dibuang tanpa menyentuh logika apa pun.
	local limiter = RateLimit.newRegistry({ MoveIntent = 12 }, 12)

	Remotes.Events.MoveIntent.OnServerEvent:Connect(function(player: Player, intent: unknown)
		if not RateLimit.check(limiter, player.UserId, "MoveIntent", os.clock()) then
			return
		end
		if type(intent) ~= "string" then
			return
		end

		local entry = getEntry(player.UserId)

		if intent == "dash" then
			applyDash(player, entry, os.clock())
			return
		end

		-- Sikap yang tidak dikenal dibuang DIAM-DIAM, bukan dijatuhkan ke
		-- "walk". Menjatuhkannya ke walk berarti client yang salah ketik
		-- mengirim "sprintt" akan diam-diam membatalkan sprint pemain tiap
		-- frame, dan gejalanya terbaca sebagai sprint yang rusak, bukan
		-- sebagai nama yang salah.
		if not MoveRules.isStance(intent) then
			return
		end
		entry.requested = intent
	end)

	local function hook(player: Player)
		entries[player.UserId] = newEntry()
		player.CharacterAdded:Connect(function()
			-- Sikap dan stamina direset tiap respawn. Tanpa reset, pemain yang
			-- mati saat jongkok hidup kembali dalam keadaan jongkok dan tidak
			-- bisa melompat, tanpa pernah menekan tombolnya.
			entries[player.UserId] = newEntry()
		end)
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		entries[player.UserId] = nil
		RateLimit.forget(limiter, player.UserId)
	end)

	RunService.Heartbeat:Connect(step)
end

return MovementService
