--!strict
-- FxController.luau: umpan balik visual pertempuran.
--
-- Tiga pekerjaan, semuanya SEPENUHNYA DI CLIENT dan tidak satu pun
-- memengaruhi gameplay:
--   1. memutar potongan musuh yang bertanda `spin` di EnemyVisuals
--   2. percikan dan angka damage saat musuh kena
--   3. guncangan kamera saat Core Server kehilangan HP
--
-- KENAPA EFEK TIDAK BOLEH DIBUAT SERVER
--
-- Percikan dan angka damage adalah benda yang umurnya setengah detik. Dibuat
-- server, tiap percikan jadi satu Instance yang direplikasi ke empat client
-- lalu dihapus, dan pada wave akhir, dengan empat pemain menembak 40 musuh,
-- itu ratusan Instance per detik yang lahir dan mati di jaringan hanya untuk
-- sesuatu yang tidak pernah memengaruhi keputusan siapa pun. Di client,
-- harganya nol bandwidth.
--
-- Konsekuensinya jujur: pemain A tidak melihat percikan di layar pemain B.
-- Itu tidak masalah, yang harus sama di semua layar adalah HP musuh, dan HP
-- memang datang dari server.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponVisuals = require(ReplicatedStorage.Shared.Modules.WeaponVisuals)
local CameraController = require(script.Parent.CameraController)

local FxController = {}

local localPlayer = Players.LocalPlayer
local started = false

local SPARK_LIFETIME = 0.35
local NUMBER_LIFETIME = 0.8

-- Jarak maksimum efek masih digambar. Di luar ini percikannya cuma beberapa
-- piksel dan angkanya tidak terbaca, jadi yang tersisa hanyalah biayanya.
local FX_MAX_DISTANCE = 190

-- Batas efek per detik. Pemain yang menembak senjata tercepat ke kerumunan
-- bisa memicu puluhan EnemyHit per detik; tanpa batas, layar jadi penuh angka
-- dan yang hilang justru informasinya.
local MAX_FX_PER_SECOND = 14
local fxBudget = MAX_FX_PER_SECOND
local lastBudgetAt = 0

local spinJoints: { [Motor6D]: CFrame } = {}
local spinTime = 0

local function cameraPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	return camera.CFrame.Position
end

-- --------------------------------------------------------------------------
-- 1. Potongan musuh yang berputar
-- --------------------------------------------------------------------------

local function scanEnemies()
	local folder = Workspace:FindFirstChild("Enemies")
	if folder == nil then
		return
	end

	for _, model in folder:GetChildren() do
		local body = model:FindFirstChild("Body")
		if body ~= nil then
			for _, child in body:GetChildren() do
				if child:IsA("Motor6D") and not spinJoints[child] then
					-- C0 awal disimpan sekali. Alasannya sama persis dengan
					-- `baseC0` di CharacterAnimatorController: membacanya ulang
					-- setelah sendi diputar akan menjadikan putaran kemarin
					-- sebagai titik nol hari ini, dan potongannya terus
					-- terpelintir makin jauh.
					spinJoints[child] = child.C0
				end
			end
		end
	end
end

local function updateSpins(dt: number)
	spinTime += dt

	for motor, base in spinJoints do
		-- Motor6D yang musuhnya sudah mati ikut hilang dari DataModel. Dibuang
		-- dari tabel di sini, bukan lewat event: `Destroying` untuk ratusan
		-- sendi berarti ratusan sambungan yang harus dijaga, sementara
		-- pemeriksaan ini gratis karena tabelnya memang sudah diputari.
		if motor.Parent == nil then
			spinJoints[motor] = nil
		else
			local rate = motor:GetAttribute("Spin")
			if type(rate) == "number" then
				motor.C0 = base * CFrame.Angles(0, spinTime * rate * math.pi * 2, 0)
			end
		end
	end
end

-- --------------------------------------------------------------------------
-- 2. Percikan dan angka damage
-- --------------------------------------------------------------------------

local function spendBudget(): boolean
	local now = os.clock()
	if now - lastBudgetAt >= 1 then
		lastBudgetAt = now
		fxBudget = MAX_FX_PER_SECOND
	end
	if fxBudget <= 0 then
		return false
	end
	fxBudget -= 1
	return true
end

local function spawnSpark(position: Vector3, damage: number)
	local spark = Instance.new("Part")
	spark.Name = "HitSpark"
	spark.Shape = Enum.PartType.Ball
	-- Besarnya ikut damage, tapi akarnya, bukan damage mentah. Senjata boss
	-- bisa 20 kali lebih kuat dari senjata awal, dan percikan 20 kali lebih
	-- besar akan menutupi musuhnya sendiri.
	local scale = math.clamp(math.sqrt(math.max(damage, 1)) * 0.35, 0.6, 3)
	spark.Size = Vector3.new(scale, scale, scale)
	spark.Position = position
	spark.Color = Color3.fromRGB(255, 232, 170)
	spark.Material = Enum.Material.Neon
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.CastShadow = false
	spark.Transparency = 0.15
	spark.Parent = Workspace

	Debris:AddItem(spark, SPARK_LIFETIME)
end

local function spawnDamageNumber(position: Vector3, damage: number)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position + Vector3.new(0, 2.4, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(70, 22)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = FX_MAX_DISTANCE
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 236, 170)
	label.TextStrokeTransparency = 0.4
	label.Text = tostring(math.floor(damage + 0.5))
	label.Parent = billboard

	Debris:AddItem(anchor, NUMBER_LIFETIME)

	-- Melayang naik sambil memudar. Dibuat dengan satu sambungan Heartbeat yang
	-- memutus dirinya sendiri, bukan dengan TweenService: anchor-nya sudah
	-- dijadwalkan dihapus Debris, dan Tween yang berjalan di atas Instance yang
	-- dihapus di tengah jalan menimbulkan peringatan di Output.
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if anchor.Parent == nil or elapsed >= NUMBER_LIFETIME then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		local t = elapsed / NUMBER_LIFETIME
		anchor.Position = position + Vector3.new(0, 2.4 + t * 3.2, 0)
		label.TextTransparency = t
		label.TextStrokeTransparency = 0.4 + t * 0.6
	end)
end

local function onEnemyHit(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local position = (payload :: any).position
	local damage = (payload :: any).damage
	if typeof(position) ~= "Vector3" or type(damage) ~= "number" then
		return
	end
	if damage ~= damage or damage <= 0 then
		return
	end

	local eye = cameraPosition()
	if eye == nil or (eye - position).Magnitude > FX_MAX_DISTANCE then
		return
	end
	if not spendBudget() then
		return
	end

	spawnSpark(position, damage)
	spawnDamageNumber(position, damage)
end

-- --------------------------------------------------------------------------
-- 3. Tembakan: kilatan moncong dan jejak peluru
-- --------------------------------------------------------------------------
--
-- Dipicu oleh atribut `AttackSeq` yang sama dengan yang dipakai animator.
-- Tidak ada remote baru: kilatan dan jejak harus muncul tepat bersamaan dengan
-- ayunan lengannya, dan satu-satunya cara menjamin itu adalah memakai sumber
-- sinyal yang sama.
--
-- Arah tembakan dibaca dari ARAH TELAPAK TANGAN, bukan dari arah bidik pemain.
-- Arah bidik cuma ada di mesin pemiliknya, client ini tidak tahu ke mana
-- pemain lain membidik, dan server tidak menyiarkannya karena tidak ada
-- keputusan gameplay yang membutuhkannya. Tangan sudah mengikuti pose
-- menyerang, jadi arahnya cukup mendekati untuk sebuah jejak yang hidup 0,07
-- detik.

local TRACER_LIFETIME = 0.07
local FLASH_LIFETIME = 0.05

local function fadeOut(part: BasePart, lifetime: number, from: number)
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if part.Parent == nil or elapsed >= lifetime then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		part.Transparency = from + (1 - from) * (elapsed / lifetime)
	end)
end

local function makeFx(name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = Workspace
	return part
end

local function spawnMuzzleFlash(origin: CFrame)
	local flash =
		makeFx("MuzzleFlash", Vector3.new(1.1, 1.1, 1.1), origin, Color3.fromRGB(255, 226, 150))
	flash.Transparency = 0.1
	Debris:AddItem(flash, FLASH_LIFETIME + 0.02)
	fadeOut(flash, FLASH_LIFETIME, 0.1)

	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 14
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = flash
end

local function spawnTracer(origin: CFrame, length: number)
	-- Satu Part panjang dan tipis, bukan proyektil yang benar-benar terbang.
	-- Peluru yang terbang perlu simulasi tiap frame dan akan tertinggal di
	-- belakang damage yang sudah diterapkan server seketika, pemain akan
	-- melihat musuh mati sebelum pelurunya sampai.
	local tracer = makeFx(
		"Tracer",
		Vector3.new(0.14, 0.14, length),
		origin * CFrame.new(0, 0, -length / 2),
		Color3.fromRGB(180, 235, 255)
	)
	tracer.Transparency = 0.25
	Debris:AddItem(tracer, TRACER_LIFETIME + 0.02)
	fadeOut(tracer, TRACER_LIFETIME, 0.25)
end

local function spawnSwingArc(origin: CFrame)
	-- Jarak dekat tidak punya peluru. Yang digambar busur tipis di depan
	-- pemain: tiga potong pendek dengan sudut berbeda, memudar bersamaan.
	for index = -1, 1 do
		local arc = makeFx(
			"SwingArc",
			Vector3.new(0.18, 2.6, 0.18),
			origin
				* CFrame.Angles(0, math.rad(index * 26), math.rad(index * 14))
				* CFrame.new(0, 0, -2),
			Color3.fromRGB(190, 230, 255)
		)
		arc.Transparency = 0.35
		Debris:AddItem(arc, 0.12)
		fadeOut(arc, 0.1, 0.35)
	end
end

local function onAttackSeq(character: Model)
	local hand = character:FindFirstChild("RightHand")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end

	local eye = cameraPosition()
	if eye == nil or (eye - hand.Position).Magnitude > FX_MAX_DISTANCE then
		return
	end

	local weaponId = character:GetAttribute("Weapon")
	local kind = character:GetAttribute("WeaponKind")

	local muzzle = Vector3.new(0, 0, -2)
	if type(weaponId) == "string" then
		local visual = WeaponVisuals.get(weaponId)
		if visual ~= nil then
			muzzle = visual.muzzle
		end
	end

	local origin = hand.CFrame * CFrame.new(muzzle)

	if kind == "ranged" then
		spawnMuzzleFlash(origin)
		spawnTracer(origin, 70)
		-- Guncangan kecil hanya untuk pemain yang menembak sendiri. Layar yang
		-- ikut berguncang tiap kali rekan setim menembak akan bergetar terus
		-- sepanjang wave.
		if character == localPlayer.Character then
			CameraController.shake(0.045)
		end
	else
		spawnSwingArc(origin)
		if character == localPlayer.Character then
			CameraController.shake(0.03)
		end
	end
end

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("AttackSeq"):Connect(function()
		onAttackSeq(character)
	end)
end

-- --------------------------------------------------------------------------
-- 4. Musuh muncul dan musuh mati
-- --------------------------------------------------------------------------
--
-- Keduanya dibaca dari DataModel langsung, `ChildAdded` dan `ChildRemoved`
-- pada folder `Workspace.Enemies`, bukan dari remote baru.
--
-- Itu pilihan sadar: server sudah mereplikasi Model musuh ke tiap client,
-- jadi kemunculan dan kehilangannya SUDAH sampai ke sini. Menambah remote
-- khusus berarti mengirim informasi yang sama dua kali, dan memberi server
-- pekerjaan tambahan di saat paling sibuk, wave akhir, 40 musuh, empat
-- pemain.

local matchState = "Lobby"

local function spawnBurst(position: Vector3, color: Color3, count: number, spread: number)
	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0.45, math.sin(angle))
		local shard = makeFx(
			"Shard",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(position + direction * 0.5),
			color
		)
		shard.Transparency = 0.1

		-- Pecahan diterbangkan dengan menggeser CFrame tiap frame, bukan dengan
		-- fisika: Part tak ber-anchor di tengah 40 musuh akan ikut tabrakan dan
		-- terpental ke mana-mana, dan 40 kematian beruntun menghasilkan ratusan
		-- benda bersimulasi untuk efek yang hidup sepersepuluh detik.
		local elapsed = 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(dt: number)
			elapsed += dt
			if shard.Parent == nil or elapsed >= 0.4 then
				if connection ~= nil then
					connection:Disconnect()
				end
				return
			end
			local t = elapsed / 0.4
			shard.CFrame = CFrame.new(position + direction * (spread * t))
				* CFrame.Angles(t * 6, t * 4, 0)
			shard.Transparency = 0.1 + 0.9 * t
		end)

		Debris:AddItem(shard, 0.45)
	end
end

local function onEnemyAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local eye = cameraPosition()
	if eye == nil then
		return
	end

	-- Posisi dibaca dari Body, bukan dari GetPivot(): pada saat ChildAdded
	-- menyala, Model-nya sudah masuk tapi Part di dalamnya bisa belum, dan
	-- GetPivot() pada Model kosong mengembalikan titik asal dunia, jadi
	-- efeknya muncul di tengah peta, bukan di gerbang.
	local body = model:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	if (eye - body.Position).Magnitude > FX_MAX_DISTANCE then
		return
	end
	if not spendBudget() then
		return
	end

	-- Gerbang masuk: cincin mendatar yang mengembang lalu hilang.
	local ring = makeFx(
		"SpawnRing",
		Vector3.new(0.4, 1, 1),
		CFrame.new(body.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 150, 90)
	)
	-- `makeFx` mengembalikan BasePart, dan Shape cuma ada di Part. Sasaran
	-- penugasan tidak boleh berupa ekspresi ber-anotasi, jadi lewat nama.
	local ringPart = ring :: Part
	ringPart.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2

	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if ring.Parent == nil or elapsed >= 0.35 then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		local t = elapsed / 0.35
		local width = 2 + t * 14
		ring.Size = Vector3.new(0.4, width, width)
		ring.Transparency = 0.2 + 0.8 * t
	end)

	Debris:AddItem(ring, 0.4)
end

local function onEnemyRemoved(model: Instance)
	if not model:IsA("Model") then
		return
	end
	-- Musuh yang hilang di luar wave berarti pembersihan akhir match
	-- (`EnemyService.clearAll`), bukan kematian. Tanpa penjagaan ini, selesai
	-- wave akan meledakkan empat puluh musuh sekaligus di layar.
	if matchState ~= "WaveActive" then
		return
	end

	local body = model:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	local position = body.Position

	local eye = cameraPosition()
	if eye == nil or (eye - position).Magnitude > FX_MAX_DISTANCE then
		return
	end
	if not spendBudget() then
		return
	end

	-- Warna pecahan mengikuti warna musuhnya, jadi mati-nya Rootkit ungu
	-- terbaca berbeda dari mati-nya Adware jingga.
	spawnBurst(position, body.Color, 6, 4.5)
	CameraController.shake(0.02)
end

local function watchEnemies()
	local folder = Workspace:FindFirstChild("Enemies")
	if folder == nil then
		return false
	end
	folder.ChildAdded:Connect(onEnemyAdded)
	folder.ChildRemoved:Connect(onEnemyRemoved)
	return true
end

-- --------------------------------------------------------------------------
-- 5. Guncangan saat Core kena
-- --------------------------------------------------------------------------

local lastCoreHp: number? = nil

local function onMatchState(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	-- State match dicatat di sini karena `onEnemyRemoved` memakainya untuk
	-- membedakan musuh yang MATI dari musuh yang dibersihkan saat match
	-- berakhir.
	local state = (payload :: any).state
	if type(state) == "string" then
		matchState = state
	end

	local hp = (payload :: any).coreHp
	local maxHp = (payload :: any).coreMaxHp
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 then
		return
	end

	local previous = lastCoreHp
	lastCoreHp = hp

	if previous == nil or hp >= previous then
		return
	end

	-- Besar guncangan sebanding PORSI HP yang hilang, bukan jumlah mentahnya.
	-- Kehilangan 60 HP dari Core berkekuatan 1000 harus terasa sama di tingkat
	-- kesulitan mana pun, dan HP maksimum Core berbeda antar tingkat.
	local fraction = (previous - hp) / maxHp
	CameraController.shake(math.clamp(fraction * 7, 0.08, 0.6))
end

-- --------------------------------------------------------------------------

function FxController.start()
	if started then
		return
	end
	started = true

	Remotes.Events.EnemyHit.OnClientEvent:Connect(onEnemyHit)
	Remotes.Events.MatchState.OnClientEvent:Connect(onMatchState)

	-- Kilatan moncong dan jejak peluru untuk SEMUA pemain, bukan cuma diri
	-- sendiri: melihat rekan setim menembak adalah separuh dari rasa bermain
	-- bersama, dan tanpa itu tiga rekan di layar terlihat cuma berlari-lari.
	local function hook(player: Player)
		player.CharacterAdded:Connect(watchCharacter)
		local current = player.Character
		if current ~= nil then
			watchCharacter(current)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	-- Folder `Enemies` dibuat server saat EnemyService.start(), yang bisa
	-- terjadi SETELAH client ini jalan. Dicoba sekarang; kalau belum ada,
	-- ditunggu kemunculannya, sekali, bukan dengan loop yang terus mencoba.
	if not watchEnemies() then
		task.spawn(function()
			if Workspace:WaitForChild("Enemies", 30) ~= nil then
				watchEnemies()
			end
		end)
	end

	-- Pemain yang mati kehilangan sisa guncangan: layar yang masih berguncang
	-- di atas layar kematian terbaca sebagai macet.
	localPlayer.CharacterAdded:Connect(function()
		lastCoreHp = nil
	end)

	-- Pemindaian musuh baru dilakukan empat kali per detik, bukan tiap frame.
	-- Musuh spawn paling cepat tiap 0.9 detik (Balance.SPAWN_INTERVAL), jadi
	-- menyapu seluruh folder 60 kali per detik mencari sendi baru adalah kerja
	-- yang 59 dari 60 kalinya tidak menemukan apa pun.
	local scanAccumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		scanAccumulator += dt
		if scanAccumulator >= 0.25 then
			scanAccumulator = 0
			scanEnemies()
		end
		updateSpins(dt)
	end)
end

return FxController
