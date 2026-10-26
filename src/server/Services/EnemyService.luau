--!strict
-- EnemyService.luau — entitas musuh: spawn, gerak, HP, kematian.
--
-- DARI AWAL, tiga keputusan bagian 1.3 yang membentuk seluruh file ini.
--
-- 1. Musuh BUKAN Humanoid dan tidak pakai PathfindingService. Musuh adalah
--    Model dengan PrimaryPart anchored yang digerakkan server lewat CFrame
--    mengikuti waypoint lane. Alasannya: 40 Humanoid aktif sekaligus
--    menjalankan state machine, physics, dan replikasi animasi masing-masing,
--    dan jalur ke Core sudah tetap jadi tidak ada yang perlu dicari.
--
-- 2. SATU loop untuk semua musuh, bukan satu task per musuh. 40 task yang
--    masing-masing memanggil task.wait() berarti 40 penjadwalan per frame dan
--    40 titik yang bisa bocor kalau musuhnya dihapus di tengah wait. Satu
--    Heartbeat memegang seluruh daftar dan berhenti rapi saat daftar kosong.
--
-- 3. Batas musuh aktif Balance.MAX_ACTIVE_ENEMIES dengan ANTRIAN. Sisa spawn
--    ditahan, tidak dibuang: kalau dibuang, wave yang jumlah musuhnya di atas
--    batas tidak akan pernah bisa diselesaikan karena hitungan "musuh sisa"
--    tidak akan pernah mencapai nol.
--
-- Dan satu keputusan dari docs/ARENA_REDESIGN.md bagian 4 yang mengubah bentuk
-- step(): musuh yang sampai di ujung lane TIDAK hilang lagi. Dia mengambil satu
-- slot cincin di sekitar Core dan memukul tiap `attackInterval` detik sampai
-- dibunuh pemain, dan musuh dengan profil `prefer = "player"` bisa keluar lane
-- untuk memburu pemain. Seluruh keputusan state dan targetnya ada di
-- Shared.Modules.EnemyAI — modul murni yang bisa dites tanpa Studio; yang di
-- bawah cuma menerjemahkan hasilnya ke CFrame, TakeDamage, dan CoreService.
--
-- Konsekuensinya disengaja dan disebut bagian 5: `isClear()` tidak lagi dijamin
-- tercapai sendiri. Wave tidak selesai selama masih ada kebocoran yang hidup di
-- base, dan selama itu Core terus kehilangan HP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Bosses = require(Shared.Modules.Bosses)
local CombatEffects = require(Shared.Modules.CombatEffects)
local Enemies = require(Shared.Modules.Enemies)
local EnemyAI = require(Shared.Modules.EnemyAI)
local EnemyVisuals = require(Shared.Modules.EnemyVisuals)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Modules.Signal)
local Types = require(Shared.Modules.Types)

local CoreService = require(script.Parent.CoreService)
local MapService = require(script.Parent.MapService)

local EnemyService = {}

export type Enemy = {
	-- Id numerik, bukan Instance: yang dikirim ke client lewat `EnemyHit` cuma
	-- id, supaya client tidak bisa menyuruh server men-damage "Instance ini".
	id: number,
	defId: string,
	isBoss: boolean,
	hp: number,
	maxHp: number,
	speed: number,
	-- Damage SEKALI PUKUL, bukan sekali sampai: musuh yang mencapai base tidak
	-- hilang lagi, dia berhenti dan memukul tiap `attackInterval` detik. Angka
	-- mentahnya dipakai untuk player; ke base dia dikali
	-- Balance.BASE_DAMAGE_MULT (lihat EnemyAI.baseDamage).
	attackDamage: number,
	attackInterval: number,
	targeting: Types.TargetProfile,
	matchCoins: number,
	laneIndex: number,
	-- Index waypoint yang sedang dituju. Mulai dari 2 karena musuh di-spawn
	-- tepat di waypoint 1.
	waypointIndex: number,
	position: Vector3,
	-- State AI. Seluruh keputusan transisinya ada di EnemyAI, bukan di sini;
	-- yang di bawah cuma menerjemahkan hasilnya ke CFrame dan TakeDamage.
	state: EnemyAI.State,
	-- Waktu (os.clock) pukulan berikutnya. 0 berarti "pukul begitu sampai":
	-- pukulan pertama musuh yang baru menempel tidak menunggu satu interval.
	nextStrikeAt: number,
	-- Target dipegang antar frame, bukan dipilih ulang tiap frame: dengan dua
	-- player berjarak mirip, memilih ulang membuat musuh bergetar di antara
	-- keduanya. Yang dipegang id-nya, bukan Candidate-nya, karena Candidate
	-- dibangun ulang tiap frame dari posisi terbaru.
	targetUserId: number?,
	-- Slot cincin di sekitar base, di-set sekali saat masuk attacking_base.
	ringSlot: number?,
	-- Efek alur upgrade yang MENEMPEL ke musuh ini dan ikut dia ke mana pun
	-- dia jalan (alur "Ayunan Cepat" dan "Dukungan"). Nil berarti belum pernah
	-- kena; yang sudah kedaluwarsa dibiarkan apa adanya dan dibaca lewat
	-- `CombatEffects.multOf`, yang mengembalikan 1 untuk keduanya.
	--
	-- Tidak dibersihkan tiap frame dengan sengaja: menghapus field yang sudah
	-- habis cuma memindahkan pekerjaan yang sama ke tempat yang lebih mudah
	-- dilupakan, dan satu tabel kecil per musuh tidak berarti apa-apa
	-- dibanding Part dan Model yang sudah dia bawa.
	slow: CombatEffects.Timed?,
	mark: CombatEffects.Timed?,
	-- Damage zona yang sudah terkumpul tapi belum diterapkan, dan waktu
	-- penerapan berikutnya. Lihat `ZONE_FLUSH_INTERVAL`.
	zoneDamageAcc: number,
	zoneFlushAt: number,
	model: Model,
	primary: BasePart,
	healthFill: Frame?,
	dead: boolean,
}

-- (musuh, pembunuh) — pembunuh nil kalau musuh mati bukan karena serangan
-- pemain (misal dihapus saat match dibatalkan tidak menembakkan sinyal ini
-- sama sekali; lihat clearAll).
EnemyService.onDied = Signal.new() :: Signal.Signal<Enemy, Player?>
-- Musuh sampai di ujung lane dan MULAI menyerang base. Ditembakkan tepat sekali
-- per musuh, saat transisi masuk `attacking_base` — bukan tiap pukulan. HP Core
-- BELUM berkurang saat sinyal ini menyala; pukulan pertamanya jatuh sesaat
-- sesudahnya di frame yang sama.
EnemyService.onReachedCore = Signal.new() :: Signal.Signal<Enemy>
-- Ditembakkan saat musuh terakhir hilang DAN antrian habis, sekali per wave.
EnemyService.onAllClear = Signal.new() :: Signal.Signal<()>

type QueueEntry = {
	defId: string,
	isBoss: boolean,
	laneIndex: number?,
}

type Context = {
	wave: number,
	difficulty: Types.DifficultyDef,
	playerCount: number,
}

-- Bentuk musuh pindah ke `Shared.Modules.EnemyVisuals`.
--
-- Dulu tabel bentuknya ada persis di sini: satu Part per musuh, dibedakan
-- ukuran dan warna saja. Yang dipindah bukan cuma angkanya, sekarang tiap
-- musuh punya beberapa potongan dengan siluet sendiri, dan alasan tiap bentuk
-- ditulis di modul itu. Dipindah ke Shared karena client juga membacanya:
-- EnemyFxController memutar potongan yang bertanda `spin`.
--
-- Yang TIDAK berubah: ini tetap presentasi, bukan balancing. Tidak ada satu
-- pun angka di EnemyVisuals yang memengaruhi HP, damage, atau uji kena,
-- uji kena memakai jarak ke PrimaryPart (bagian 3.7), bukan geometri Part.

local FOLDER_NAME = "Enemies"

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local active: { [number]: Enemy } = {}
local activeCount = 0
local queue: { QueueEntry } = {}
local queueHead = 1 -- kepala antrian digeser, bukan table.remove(queue, 1)
local nextId = 1
local spawnTimer = 0
local started = false
local running = false
local folder: Folder? = nil
local heartbeat: RBXScriptConnection? = nil
local announcedClear = true

-- Nomor slot cincin berikutnya di sekitar base. Naik terus, tidak pernah dipakai
-- ulang: slot yang dibebaskan musuh mati tidak boleh langsung diberikan ke musuh
-- lain, kalau tidak dua musuh bisa berdiri di titik yang sama persis saat yang
-- pertama mati tepat sebelum yang kedua sampai. Harganya, cincinnya melebar
-- selama wave berjalan. Direset di clearAll() — tanpa itu wave kedua mulai dari
-- slot 40 dan musuhnya berdiri jauh di cincin keempat.
local ringSlotNext = 0

local context: Context = {
	wave = 1,
	difficulty = {
		id = "normal",
		name = "Normal",
		hpMult = 1,
		rewardMult = 1,
		unlockedByDefault = true,
	},
	playerCount = 1,
}

-- Lane yang sedang diblokir penghalang Toko Match (M3): musuh di lane itu
-- berhenti sampai `os.clock()` melewati nilainya.
local laneBlockedUntil: { [number]: number } = {}

-- Zona jebakan (alur Fork Bomb "Jebakan"). Menempel ke TEMPAT, bukan ke musuh,
-- jadi tidak bisa disimpan di `Enemy` -- musuh yang keluar dari zona harus
-- langsung berhenti terpengaruh, dan musuh yang baru spawn dan melewatinya
-- harus ikut terkena walaupun zonanya dibuat sebelum dia ada.
--
-- Tanpa Instance apa pun: zona ini tidak kelihatan di layar. Itu kekurangan
-- yang diketahui dan ditulis di TEST_CASES, bukan kelupaan -- menggambarnya
-- butuh Part dan aset, dan yang dibutuhkan langkah 7 adalah efeknya bekerja.
local zones: { CombatEffects.Zone } = {}

-- Damage zona diterapkan paling cepat tiap interval ini, bukan tiap frame.
--
-- Bukan optimasi spekulatif. `EnemyService.damage` menyiarkan `EnemyHit` ke
-- SEMUA client tiap kali dipanggil, dan zona memanggilnya untuk tiap musuh di
-- dalamnya. Tiap frame berarti 60 siaran per detik per musuh: satu zona radius
-- 12 di tengah kerumunan 20 musuh menghasilkan 1.200 event per detik, untuk
-- damage yang totalnya 6 per detik.
--
-- Damage-nya tidak hilang, cuma ditunda: yang terkumpul di antara dua
-- penerapan disimpan di `enemy.zoneDamageAcc` dan dibayar sekaligus. Jadi
-- totalnya persis sama, dan yang berubah cuma jumlah siaran -- dari 60 per
-- detik jadi 4.
local ZONE_FLUSH_INTERVAL = 0.25

-- Pengali damage yang masuk ke seorang pemain (alur Patch Wrench "Bertahan").
--
-- Disuntik dari luar, bukan dihitung di sini, dengan alasan yang sama seperti
-- `gate` dan `modifiers` di CombatService: angkanya datang dari senjata yang
-- dipakai pemain, yang berarti `PlayerDataService` dan `Weapons` -- dan
-- EnemyService me-require CoreService dan MapService, jadi menambah dua lagi
-- ke arah itu membuat urutan require-nya tidak lagi satu arah.
local playerDamageTakenMult: (number) -> number = function(_userId: number)
	return 1
end

function EnemyService.setPlayerDamageTakenMult(fn: (number) -> number)
	playerDamageTakenMult = fn
end

local function getFolder(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local created = Workspace:FindFirstChild(FOLDER_NAME)
	if created == nil or not created:IsA("Folder") then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = Workspace
		created = made
	end
	folder = created :: Folder
	return folder :: Folder
end

local function makeHealthBar(parent: BasePart, size: Vector3): Frame
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Health"
	billboard.Size = UDim2.fromOffset(60, 8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.2, 0)
	billboard.AlwaysOnTop = false
	-- Tanpa batas jarak, 40 BillboardGui tetap dirender walaupun musuhnya
	-- sejauh 500 stud dan cuma beberapa piksel.
	billboard.MaxDistance = 140
	billboard.Parent = parent

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = background

	return fill
end

local function updateHealthBar(enemy: Enemy)
	local fill = enemy.healthFill
	if fill == nil then
		return
	end
	local fraction = if enemy.maxHp > 0 then math.clamp(enemy.hp / enemy.maxHp, 0, 1) else 0
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if fraction > 0.5
		then Color3.fromRGB(90, 220, 110)
		elseif fraction > 0.25 then Color3.fromRGB(240, 200, 70)
		else Color3.fromRGB(230, 80, 80)
end

-- Potongan hias ditempelkan ke Body yang anchored.
--
-- Yang bertanda `spin` dipasang dengan Motor6D, sisanya dengan WeldConstraint.
-- Bedanya penting: WeldConstraint mengunci mati dan tidak bisa digerakkan
-- siapa pun, sedangkan Motor6D menyisakan satu sendi yang bisa diputar CLIENT
-- lewat C0, tanpa menyentuh server dan tanpa replikasi sama sekali. Itu yang
-- membuat cincin boss bisa berputar 60 fps sementara server tetap cuma
-- memindahkan satu Part per musuh per frame.
local function attachPiece(body: BasePart, piece: EnemyVisuals.Piece, parent: Model)
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Shape = SHAPES[piece.shape] or Enum.PartType.Block
	part.Size = piece.size
	part.Color = piece.color
	part.Transparency = piece.transparency or 0
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local material = (Enum.Material :: any)[piece.material]
	part.Material = if typeof(material) == "EnumItem"
		then material :: Enum.Material
		else Enum.Material.SmoothPlastic

	local offset = CFrame.new(piece.offset)
	local rotation = piece.rotation
	if rotation ~= nil then
		offset = offset
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	end

	part.CFrame = body.CFrame * offset
	part.Parent = parent

	if piece.spin ~= nil then
		local motor = Instance.new("Motor6D")
		motor.Name = piece.name
		motor.Part0 = body
		motor.Part1 = part
		motor.C0 = offset
		motor:SetAttribute("Spin", piece.spin)
		motor.Parent = body
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
end

local function buildModel(defId: string, name: string, position: Vector3): (Model, BasePart, Frame)
	local visual = EnemyVisuals.get(defId)

	local model = Instance.new("Model")
	model.Name = name

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Shape = SHAPES[visual.bodyShape] or Enum.PartType.Block
	part.Size = visual.bodySize
	part.Color = visual.bodyColor
	part.Transparency = visual.bodyTransparency or 0
	local bodyMaterial = (Enum.Material :: any)[visual.bodyMaterial]
	part.Material = if typeof(bodyMaterial) == "EnumItem"
		then bodyMaterial :: Enum.Material
		else Enum.Material.SmoothPlastic
	part.Anchored = true
	-- CanCollide false dengan sengaja: Part anchored yang bertabrakan dengan
	-- karakter pemain akan menembus atau mendorongnya ke dalam geometry, dan
	-- uji kena serangan tidak memakai tabrakan sama sekali (bagian 3.7).
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = CFrame.new(position)
	part.Parent = model
	model.PrimaryPart = part

	-- Potongan dipasang SETELAH Body punya CFrame dan induk. Dua-duanya
	-- syarat: offset dihitung dari `body.CFrame`, jadi Body yang masih di titik
	-- asal akan menempatkan seluruh potongan di tengah peta lalu menyeretnya;
	-- dan Motor6D yang dibuat sebelum kedua Part punya induk tidak membentuk
	-- assembly.
	for _, piece in visual.pieces do
		attachPiece(part, piece, model)
	end

	-- Bar HP dipatok ke tinggi BADAN, bukan ke potongan tertinggi. Potongan
	-- seperti gembok boss menjulur jauh ke atas, dan bar yang mengikutinya akan
	-- melayang terpisah dari musuhnya.
	local fill = makeHealthBar(part, visual.bodySize)
	return model, part, fill
end

local function removeEnemy(enemy: Enemy)
	if active[enemy.id] == nil then
		return
	end
	active[enemy.id] = nil
	activeCount -= 1
	enemy.dead = true
	enemy.model:Destroy()
end

local function queuedCount(): number
	return #queue - queueHead + 1
end

-- Antrian dikosongkan dengan menggeser kepala, bukan table.remove(queue, 1):
-- remove dari depan menggeser seluruh sisa array tiap spawn. Array-nya baru
-- benar-benar dibuang setelah habis.
local function popQueue(): QueueEntry?
	if queuedCount() <= 0 then
		return nil
	end
	local entry = queue[queueHead]
	queueHead += 1
	if queueHead > #queue then
		queue = {}
		queueHead = 1
	end
	return entry
end

local function spawnFromEntry(entry: QueueEntry): Enemy?
	local arena = MapService.getArena()
	if arena == nil then
		return nil
	end

	local laneCount = #arena.lanes
	if laneCount == 0 then
		return nil
	end

	-- Lane acak kalau pemanggil tidak menyebut lane atau menyebut lane yang
	-- tidak ada di map ini (arena bisa punya 1 lane, bisa 2 — lihat bagian 9).
	local requested = entry.laneIndex
	local laneIndex: number
	if requested ~= nil and requested >= 1 and requested <= laneCount then
		laneIndex = requested
	else
		laneIndex = math.random(1, laneCount)
	end
	local lane = arena.lanes[laneIndex]

	local hp: number
	local speed: number
	local attackDamage: number
	local attackInterval: number
	local targeting: Types.TargetProfile
	local matchCoins: number

	if entry.isBoss then
		local def = Bosses[entry.defId]
		if def == nil then
			warn(string.format("[EnemyService] boss '%s' tidak ada di Bosses", entry.defId))
			return nil
		end
		hp = Balance.bossHp(def, context.difficulty, context.playerCount)
		speed = def.speed
		attackDamage = def.attackDamage
		attackInterval = def.attackInterval
		targeting = def.targeting
		matchCoins = def.matchCoins
	else
		local def = Enemies[entry.defId]
		if def == nil then
			warn(string.format("[EnemyService] musuh '%s' tidak ada di Enemies", entry.defId))
			return nil
		end
		hp = Balance.enemyHp(def, context.wave, context.difficulty, context.playerCount)
		speed = def.speed
		attackDamage = def.attackDamage
		attackInterval = def.attackInterval
		targeting = def.targeting
		matchCoins = def.matchCoins
	end

	hp = math.max(1, math.floor(hp + 0.5))

	local id = nextId
	nextId += 1

	local spawnPosition = lane.waypoints[1]
	local model, primary, fill =
		buildModel(entry.defId, string.format("%s_%d", entry.defId, id), spawnPosition)

	local enemy: Enemy = {
		id = id,
		defId = entry.defId,
		isBoss = entry.isBoss,
		hp = hp,
		maxHp = hp,
		speed = speed,
		attackDamage = attackDamage,
		attackInterval = attackInterval,
		targeting = targeting,
		matchCoins = matchCoins,
		laneIndex = laneIndex,
		waypointIndex = 2,
		position = spawnPosition,
		state = "walking",
		nextStrikeAt = 0,
		targetUserId = nil,
		ringSlot = nil,
		zoneDamageAcc = 0,
		zoneFlushAt = 0,
		model = model,
		primary = primary,
		healthFill = fill,
		dead = false,
	}

	updateHealthBar(enemy)
	model.Parent = getFolder()

	active[id] = enemy
	activeCount += 1
	announcedClear = false
	return enemy
end

-- EnemyAI bekerja dengan Vec3 (tabel {x,y,z} milik HitTest), bukan Vector3,
-- supaya modulnya bisa dites tanpa Roblox. Konversinya sama bentuknya dengan
-- CombatService.toVec; keduanya sengaja sepele.
local function toVec(v: Vector3): EnemyAI.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Waypoint lane sebagai Vec3, di-cache per tabel lane. Kuncinya tabel lane-nya
-- sendiri, bukan nomor lane: MapService.invalidate() menghasilkan tabel lane
-- baru, jadi cache-nya otomatis tidak kena dan tidak ada yang perlu
-- membatalkannya manual.
local laneVecCache: { [MapService.Lane]: { EnemyAI.Vec3 } } = {}

local function laneVecs(lane: MapService.Lane): { EnemyAI.Vec3 }
	local cached = laneVecCache[lane]
	if cached ~= nil then
		return cached
	end
	local converted: { EnemyAI.Vec3 } = {}
	for index, waypoint in lane.waypoints do
		converted[index] = toVec(waypoint)
	end
	laneVecCache[lane] = converted
	return converted
end

-- Daftar player untuk SATU frame, dikumpulkan sekali di luar loop musuh.
--
-- Kenapa bukan per musuh: dengan 40 musuh aktif, memanggil Players:GetPlayers()
-- lalu mencari Humanoid dan root part 40 kali per frame berarti ratusan
-- pembacaan properti Instance per frame untuk menjawab pertanyaan yang sama.
-- `byUserId` ada supaya musuh bisa menemukan lagi target yang dipegangnya tanpa
-- menyapu daftar, dan `humanoids` supaya pemukulan tidak perlu mencari karakter
-- ulang.
type PlayerFrame = {
	candidates: { EnemyAI.Candidate },
	byUserId: { [number]: EnemyAI.Candidate },
	humanoids: { [number]: Humanoid },
}

local function collectPlayers(): PlayerFrame
	local candidates: { EnemyAI.Candidate } = {}
	local byUserId: { [number]: EnemyAI.Candidate } = {}
	local humanoids: { [number]: Humanoid } = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			continue
		end
		local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end

		-- Player yang mati tetap masuk daftar dengan alive=false, bukan dibuang:
		-- EnemyAI.lostTarget memakai flag itu untuk melepas target yang baru
		-- mati, dan pickTarget melewatinya sendiri.
		local candidate: EnemyAI.Candidate = {
			userId = player.UserId,
			position = toVec(root.Position),
			alive = humanoid.Health > 0,
		}
		table.insert(candidates, candidate)
		byUserId[player.UserId] = candidate
		humanoids[player.UserId] = humanoid
	end

	return { candidates = candidates, byUserId = byUserId, humanoids = humanoids }
end

-- Musuh sampai di ujung lane: dia BERHENTI di sana dan mulai memukul base.
-- Tidak ada removeEnemy di sini lagi — satu-satunya yang mengakhiri musuh ini
-- adalah pemain yang membunuhnya (lihat docs/ARENA_REDESIGN.md bagian 5: itu
-- juga berarti wave tidak selesai selama masih ada kebocoran yang hidup).
local function enterAttackingBase(enemy: Enemy, corePosition: Vector3)
	enemy.state = "attacking_base"
	enemy.targetUserId = nil

	local slot = ringSlotNext
	ringSlotNext += 1
	enemy.ringSlot = slot

	local offset = EnemyAI.ringSlotOffset(
		slot,
		Balance.BASE_RING_SLOTS,
		Balance.BASE_RING_RADIUS,
		Balance.BASE_RING_RADIUS_OUTER
	)
	-- Y diambil dari musuh, bukan dari Core: pusat Core adalah pusat Part-nya
	-- dan bisa berada beberapa stud di atas tanah. Memakai Y Core akan membuat
	-- seluruh cincin musuh mengapung.
	enemy.position =
		Vector3.new(corePosition.X + offset.x, enemy.position.Y, corePosition.Z + offset.z)

	EnemyService.onReachedCore:Fire(enemy)
end

local function step(deltaTime: number)
	if not running then
		return
	end

	local arena = MapService.getArena()
	if arena == nil then
		return
	end

	-- Zona yang habis dibuang sekali per frame, di sini, SEBELUM musuh dibaca.
	-- Membuangnya di dalam loop musuh berarti satu musuh bisa membaca zona yang
	-- sudah dibuang musuh sebelumnya di frame yang sama, dan dua musuh di titik
	-- yang sama lalu bergerak dengan kecepatan berbeda.
	zones = CombatEffects.pruneZones(os.clock(), zones)

	-- Spawn: satu entri per SPAWN_INTERVAL, dan cuma kalau masih di bawah batas
	-- musuh aktif. Dua syarat terpisah — batas aktif tidak boleh dilewati
	-- walaupun timernya sudah jatuh tempo.
	spawnTimer += deltaTime
	while
		spawnTimer >= Balance.SPAWN_INTERVAL
		and queuedCount() > 0
		and activeCount < Balance.MAX_ACTIVE_ENEMIES
	do
		spawnTimer -= Balance.SPAWN_INTERVAL
		local entry = popQueue()
		if entry == nil then
			break
		end
		spawnFromEntry(entry)
	end
	if queuedCount() == 0 then
		-- Jangan menumpuk timer saat antrian kosong, kalau tidak wave
		-- berikutnya spawn beberapa musuh sekaligus pada frame pertama.
		spawnTimer = math.min(spawnTimer, Balance.SPAWN_INTERVAL)
	end

	local now = os.clock()
	local corePosition = arena.corePosition
	-- Sekali per frame, di luar loop musuh. Lihat collectPlayers.
	local frame = collectPlayers()

	for _, enemy in active do
		if enemy.dead then
			continue
		end

		local lane = arena.lanes[enemy.laneIndex]
		if lane == nil then
			continue
		end
		local waypointCount = #lane.waypoints

		local enemyVec = toVec(enemy.position)
		local profile = enemy.targeting

		-- Kecepatan efektif: slow yang menempel ke musuh DIKALI slow zona di
		-- tempat dia berdiri sekarang. Dua sumber yang dikalikan, bukan diambil
		-- yang terkuat, karena keduanya datang dari alur yang BERBEDA -- pemain
		-- yang satu memakai Ayunan Cepat dan yang satu Jebakan memang sedang
		-- menumpuk dua efek yang masing-masing dia bayar, dan masing-masing
		-- sumbernya sendiri sudah dibatasi (merge mengambil yang terkuat,
		-- zoneSlowAt juga).
		local speedMult = CombatEffects.multOf(now, enemy.slow)
			* CombatEffects.zoneSlowAt(now, enemyVec, zones)
		local effectiveSpeed = enemy.speed * speedMult

		-- Damage zona dikumpulkan tiap frame tapi DIBAYAR tiap
		-- `ZONE_FLUSH_INTERVAL`. Alasannya di konstanta itu.
		--
		-- Dibayar lewat `EnemyService.damage`, bukan dengan menyentuh
		-- `enemy.hp` langsung: lewat sana dia ikut terkali tanda, ikut
		-- menembakkan `EnemyHit`, dan ikut memberi koin match saat dia yang
		-- membunuh. Pembunuhnya `nil` karena zona tidak punya pemilik -- pemain
		-- yang meninggalkannya bisa sudah mati atau keluar.
		enemy.zoneDamageAcc += CombatEffects.zoneDamageAt(now, enemyVec, zones, deltaTime)
		if enemy.zoneDamageAcc > 0 and now >= enemy.zoneFlushAt then
			local owed = enemy.zoneDamageAcc
			-- Dinolkan SEBELUM `damage`, bukan sesudah: `damage` bisa
			-- membunuhnya, dan apa pun yang berjalan dari sana bisa membaca
			-- musuh ini lagi. Menolkannya sesudah berarti ada jendela di mana
			-- utang yang sudah dibayar masih tercatat.
			enemy.zoneDamageAcc = 0
			enemy.zoneFlushAt = now + ZONE_FLUSH_INTERVAL
			EnemyService.damage(enemy.id, owed, nil)
			-- `damage` bisa membunuhnya, dan yang membunuh memanggil
			-- `removeEnemy` lalu `onDied` -- yang pendengarnya bisa memanggil
			-- `clearAll()` sekarang, di tengah loop ini. Jadi pengecekan ini
			-- bukan kehati-hatian kosong; pola yang sama dengan pengecekan
			-- sesudah `CoreService.damage` di bawah.
			if enemy.dead then
				continue
			end
		end

		-- Target: pertahankan yang lama selama belum lepas leash, baru cari yang
		-- baru. Musuh yang sudah menempel di base tidak mencari apa pun —
		-- EnemyAI.nextState tidak akan pernah mengeluarkannya dari state itu,
		-- jadi pekerjaan mencarinya akan terbuang.
		local target: EnemyAI.Candidate? = nil
		if enemy.state ~= "attacking_base" then
			local heldId = enemy.targetUserId
			local held = if heldId ~= nil then frame.byUserId[heldId] else nil
			if held ~= nil and not EnemyAI.lostTarget(profile, enemyVec, held) then
				target = held
			else
				target = EnemyAI.pickTarget(profile, enemyVec, frame.candidates)
			end
			enemy.targetUserId = if target ~= nil then target.userId else nil
		end

		-- Dua anotasi `EnemyAI.State` di bawah WAJIB, bukan gaya: local tanpa
		-- anotasi yang diisi union literal dilebarkan jadi `string` oleh type
		-- checker, dan nilainya lalu tidak bisa dipakai lagi di tempat yang
		-- menuntut State -- termasuk parameter EnemyAI.nextState sendiri.
		local previous: EnemyAI.State = enemy.state
		-- `atLaneEnd` dihitung di sini, bukan di EnemyAI: modul itu tidak tahu
		-- apa pun soal lane.
		local atLaneEnd = enemy.waypointIndex > waypointCount
		local state: EnemyAI.State =
			EnemyAI.nextState(profile, previous, enemyVec, target, atLaneEnd)

		if state == "attacking_base" and previous ~= "attacking_base" then
			enterAttackingBase(enemy, corePosition)
		else
			enemy.state = state
		end

		-- Pulang ke lane setelah pengejaran selesai. minIndex = waypointIndex
		-- musuh saat ini, jadi dia tidak bisa dipancing MUNDUR: tanpa batas itu,
		-- pemain bisa menarik satu musuh maju-mundur selamanya dan wave-nya —
		-- yang baru selesai saat arena bersih — tidak akan pernah berakhir.
		if state == "walking" and (previous == "chasing" or previous == "attacking_player") then
			enemy.waypointIndex =
				EnemyAI.rejoinWaypointIndex(enemyVec, laneVecs(lane), enemy.waypointIndex)
		end

		-- Penghalang Toko Match (M3) menahan musuh yang BERJALAN, bukan yang
		-- sudah menempel: musuh di base dan musuh yang sedang memukul pemain
		-- tidak terpengaruh. State-nya sendiri sudah diperbarui di atas, jadi
		-- musuh yang terblokir tetap bisa mulai memukul pemain yang mendekat.
		local blockedUntil = laneBlockedUntil[enemy.laneIndex]
		-- Dua boolean, bukan satu `if` berantai: perbandingan `state` di dalam
		-- kondisi `continue` ikut menyempitkan tipe `state` untuk seluruh sisa
		-- iterasi, dan cabang-cabang di bawah lalu dianggap mustahil.
		local blocked = blockedUntil ~= nil and now < blockedUntil
		local moving = state == "walking" or state == "chasing"
		if blocked and moving then
			continue
		end

		-- Titik yang dihadapi musuh. Yang menyerang menghadap sasarannya, yang
		-- berjalan menghadap waypoint berikutnya.
		local lookAt: Vector3? = nil

		if state == "walking" then
			local budget = effectiveSpeed * deltaTime
			-- Loop: satu frame bisa melewati lebih dari satu waypoint kalau
			-- waypoint-nya rapat atau frame-nya panjang (server hiccup). Tanpa
			-- loop, musuh akan tersendat satu waypoint per frame.
			while budget > 0 do
				-- Waypoint habis = musuh sudah melewati waypoint terakhir, yang
				-- menurut bagian 3.4 ada di dekat Core.
				if enemy.waypointIndex > waypointCount then
					break
				end
				local waypoint = lane.waypoints[enemy.waypointIndex]

				local offset = waypoint - enemy.position
				local distance = offset.Magnitude

				if distance <= math.max(budget, Balance.WAYPOINT_REACH) then
					enemy.position = waypoint
					enemy.waypointIndex += 1
					budget -= distance
				else
					enemy.position += offset.Unit * budget
					budget = 0
				end
			end

			if enemy.waypointIndex > waypointCount then
				-- Ujung lane tercapai di frame INI. Transisinya dikerjakan
				-- sekarang, bukan ditunda ke frame berikutnya, supaya musuh
				-- tidak pernah berdiri satu frame di luar cincin.
				enterAttackingBase(enemy, corePosition)
				state = "attacking_base"
			else
				lookAt = lane.waypoints[enemy.waypointIndex]
			end
		elseif state == "chasing" and target ~= nil then
			-- Garis lurus ke target, HORIZONTAL saja: posisi yang dipakai
			-- adalah root part pemain yang tingginya beberapa stud di atas
			-- tanah, dan mengejar titik itu dalam 3D akan membuat musuh
			-- mengapung lalu kembali turun saat pemain melompat.
			local goal = Vector3.new(target.position.x, enemy.position.Y, target.position.z)
			local offset = goal - enemy.position
			local distance = offset.Magnitude
			local budget = effectiveSpeed * deltaTime
			if distance > budget then
				enemy.position += offset.Unit * budget
			elseif distance > 1e-3 then
				enemy.position = goal
			end
			lookAt = goal
		end

		if state == "attacking_player" and target ~= nil then
			lookAt = Vector3.new(target.position.x, enemy.position.Y, target.position.z)
			if EnemyAI.readyToStrike(now, enemy.nextStrikeAt) then
				local humanoid: Humanoid? = frame.humanoids[target.userId]
				if humanoid ~= nil then
					-- Pengali alur "Bertahan" dikalikan di SINI, di satu tempat
					-- yang semua damage musuh ke pemain lewat. Jadwal pukulan
					-- berikutnya tetap disetel walau pengalinya mengecilkan
					-- damage sampai hampir nol: alur itu mengurangi damage,
					-- bukan membuat musuh berhenti memukul, dan musuh yang
					-- berhenti memukul pemain berarti dia juga tidak pernah
					-- terlihat menyerang.
					local raw = EnemyAI.playerDamage(enemy.attackDamage, Balance.PLAYER_DAMAGE_MULT)
					humanoid:TakeDamage(raw * playerDamageTakenMult(target.userId))
					enemy.nextStrikeAt = EnemyAI.scheduleNextStrike(now, enemy.attackInterval)
				end
			end
		elseif state == "attacking_base" then
			lookAt = Vector3.new(corePosition.X, enemy.position.Y, corePosition.Z)
			if EnemyAI.readyToStrike(now, enemy.nextStrikeAt) then
				CoreService.damage(EnemyAI.baseDamage(enemy.attackDamage, Balance.BASE_DAMAGE_MULT))
				enemy.nextStrikeAt = EnemyAI.scheduleNextStrike(now, enemy.attackInterval)
			end
		end

		-- CoreService.damage di atas bisa menghancurkan Core, dan MatchService
		-- menjawab itu dengan clearAll() SEKARANG, di tengah loop ini: musuhnya
		-- sudah dead dan Part-nya sudah di-Destroy. Jadi pengecekan ini bukan
		-- kehati-hatian kosong.
		if enemy.dead then
			continue
		end

		-- CFrame.lookAt butuh dua titik yang berbeda.
		local look = lookAt
		if look ~= nil and (look - enemy.position).Magnitude > 0.05 then
			enemy.primary.CFrame = CFrame.lookAt(enemy.position, look)
		else
			enemy.primary.CFrame = CFrame.new(enemy.position)
		end
	end

	if not announcedClear and activeCount == 0 and queuedCount() == 0 then
		announcedClear = true
		EnemyService.onAllClear:Fire()
	end
end

function EnemyService.start()
	if started then
		return
	end
	started = true

	-- Tiap id musuh dan boss harus punya bentuk. Diperiksa di sini, saat boot,
	-- karena kalau tidak gejalanya baru muncul di wave 5 sebagai boss berupa
	-- kubus putih polos, dan "kenapa boss-nya kotak putih" adalah pertanyaan
	-- yang jauh lebih mahal dijawab daripada satu warn saat server menyala.
	local known: { string } = {}
	for id in Enemies do
		table.insert(known, id)
	end
	for id in Bosses do
		table.insert(known, id)
	end
	local visualsOk, visualsErr = EnemyVisuals.validate(known)
	if not visualsOk then
		warn(string.format("[EnemyService] bentuk musuh tidak lengkap: %s", tostring(visualsErr)))
	end

	getFolder()
	heartbeat = RunService.Heartbeat:Connect(step)
end

function EnemyService.stop()
	running = false
	local connection = heartbeat
	if connection ~= nil then
		connection:Disconnect()
		heartbeat = nil
	end
	started = false
end

-- Hidupkan/matikan gerak dan spawn. Dipakai MatchService supaya musuh tidak
-- jalan saat Intermission atau setelah match selesai.
function EnemyService.setRunning(value: boolean)
	running = value
end

function EnemyService.isRunning(): boolean
	return running
end

function EnemyService.setContext(wave: number, difficulty: Types.DifficultyDef, playerCount: number)
	context = {
		wave = wave,
		difficulty = difficulty,
		playerCount = math.max(1, playerCount),
	}
end

-- Masukkan musuh ke antrian spawn. `laneIndex` nil berarti lane acak.
function EnemyService.queue(defId: string, laneIndex: number?)
	table.insert(queue, { defId = defId, isBoss = false, laneIndex = laneIndex })
	announcedClear = false
end

function EnemyService.queueBoss(bossId: string, laneIndex: number?)
	table.insert(queue, { defId = bossId, isBoss = true, laneIndex = laneIndex })
	announcedClear = false
end

-- Dipanggil di awal wave: bikin musuh pertama muncul di frame berikutnya,
-- bukan setelah menunggu satu SPAWN_INTERVAL penuh.
function EnemyService.primeSpawnTimer()
	spawnTimer = Balance.SPAWN_INTERVAL
end

-- Spawn langsung tanpa lewat antrian dan tanpa menghormati batas musuh aktif.
-- Dipakai mekanik boss (Splitter membelah): musuh pecahan harus muncul di
-- posisi boss saat itu, bukan di awal lane, dan tidak boleh tertahan antrian
-- karena itu bagian dari mekaniknya.
function EnemyService.spawnAt(
	defId: string,
	laneIndex: number,
	position: Vector3,
	waypointIndex: number
): Enemy?
	local enemy = spawnFromEntry({ defId = defId, isBoss = false, laneIndex = laneIndex })
	if enemy == nil then
		return nil
	end

	local arena = MapService.getArena()
	local lane = if arena ~= nil then arena.lanes[enemy.laneIndex] else nil
	local maxIndex = if lane ~= nil then #lane.waypoints + 1 else waypointIndex

	enemy.position = position
	enemy.waypointIndex = math.clamp(waypointIndex, 1, maxIndex)
	enemy.primary.CFrame = CFrame.new(position)
	return enemy
end

function EnemyService.activeCount(): number
	return activeCount
end

function EnemyService.queuedCount(): number
	return queuedCount()
end

function EnemyService.isClear(): boolean
	return activeCount == 0 and queuedCount() == 0
end

function EnemyService.get(id: number): Enemy?
	return active[id]
end

function EnemyService.getAll(): { [number]: Enemy }
	return active
end

-- Satu-satunya cara mengurangi HP musuh. Semua validasi ada di sini, bukan di
-- pemanggil: CombatService, turret, dan mekanik boss semuanya lewat sini.
function EnemyService.damage(id: number, amount: number, by: Player?): number
	local enemy = active[id]
	if enemy == nil or enemy.dead then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end

	-- Tanda diterapkan DI SINI, bukan di CombatService, dan itu bedanya antara
	-- "tanda menaikkan damage penandanya" dan "tanda menaikkan damage siapa
	-- pun". Turret Toko Match, splash dari pemain lain, dan damage per detik
	-- zona semuanya lewat fungsi ini, jadi semuanya ikut terkali -- yang
	-- memang yang dijanjikan alur "Dukungan" dan yang membuatnya paling kuat
	-- di tim berempat.
	local amplified = amount * CombatEffects.multOf(os.clock(), enemy.mark)

	local before = enemy.hp
	enemy.hp = math.max(0, enemy.hp - amplified)
	local dealt = before - enemy.hp
	updateHealthBar(enemy)

	-- Payload `EnemyHit` cuma untuk efek di client (bagian 3.6): client tidak
	-- boleh menghitung apa pun dari angka ini.
	Remotes.Events.EnemyHit:FireAllClients({
		id = enemy.id,
		damage = dealt,
		position = enemy.position,
	})

	if enemy.hp <= 0 then
		removeEnemy(enemy)
		EnemyService.onDied:Fire(enemy, by)
		if activeCount == 0 and queuedCount() == 0 and not announcedClear then
			announcedClear = true
			EnemyService.onAllClear:Fire()
		end
	end

	return dealt
end

-- Hapus semua musuh dan antrian tanpa menembakkan onDied — ini pembatalan,
-- bukan kematian, jadi tidak boleh memberi koin match atau drop material.
function EnemyService.clearAll()
	for _, enemy in active do
		enemy.dead = true
		enemy.model:Destroy()
	end
	active = {}
	activeCount = 0
	queue = {}
	queueHead = 1
	spawnTimer = 0
	announcedClear = true
	ringSlotNext = 0
	table.clear(laneBlockedUntil)
	-- Zona ikut dibuang. Umurnya cuma 3 detik, jadi membiarkannya hampir tidak
	-- terlihat -- tapi "hampir" itu match baru yang wave 1-nya dimulai dengan
	-- zona perlambat dari match sebelumnya, dan gejalanya musuh pertama yang
	-- jalannya aneh tanpa ada yang menembaknya.
	zones = {}
end

-- --------------------------------------------------------------------------
-- Efek alur upgrade (ARENA_REDESIGN.md bagian 3 dan lampiran A)
-- --------------------------------------------------------------------------
--
-- Ketiganya dipanggil CombatService saat serangan pemain kena. Keputusan
-- "siapa yang kena" dan "yang mana yang lebih kuat" ada di CombatEffects,
-- yang murni dan dites di CI; yang di sini cuma menyimpan hasilnya.

-- Perlambat satu musuh. Yang lebih kuat menang atas yang lebih lemah selama
-- masih aktif -- alasannya di `CombatEffects.merge`.
function EnemyService.applySlow(id: number, mult: number?, seconds: number?)
	local enemy = active[id]
	if enemy == nil or enemy.dead then
		return
	end
	enemy.slow = CombatEffects.merge(os.clock(), enemy.slow, mult, seconds, true)
end

-- Tandai satu musuh: damage dari SIAPA PUN ke musuh ini dikali, bukan cuma
-- dari pemain yang menandainya. Itu seluruh guna alur "Dukungan", dan itu juga
-- yang membuatnya paling kuat di tim berempat.
function EnemyService.applyMark(id: number, mult: number?, seconds: number?)
	local enemy = active[id]
	if enemy == nil or enemy.dead then
		return
	end
	enemy.mark = CombatEffects.merge(os.clock(), enemy.mark, mult, seconds, false)
end

-- Tinggalkan zona di satu titik.
function EnemyService.addZone(
	position: Vector3,
	radius: number?,
	slowMult: number?,
	dps: number?,
	seconds: number?
)
	if radius == nil or radius ~= radius or radius <= 0 or radius == math.huge then
		return
	end
	local expiresAt = CombatEffects.expiresAt(os.clock(), seconds)
	if expiresAt <= os.clock() then
		-- Durasi yang tidak wajar: tidak ada gunanya menyimpan zona yang sudah
		-- habis, dan `step` akan membuangnya di frame berikutnya juga.
		return
	end
	table.insert(zones, {
		position = toVec(position),
		radius = radius,
		slowMult = if slowMult ~= nil and slowMult > 0 and slowMult < 1 then slowMult else 1,
		dps = if dps ~= nil and dps > 0 and dps ~= math.huge then dps else 0,
		expiresAt = expiresAt,
	})
end

-- Musuh hidup sebagai target untuk CombatEffects: id dan posisi saja.
--
-- Dibangun di sini, bukan dibiarkan CombatService mengiterasi `getAll()`
-- sendiri, supaya "musuh yang sudah mati tidak boleh ikut dipilih" diputuskan
-- satu kali -- splash yang mengenai musuh yang Part-nya sudah di-Destroy tidak
-- error, tapi dia memboroskan damage yang pemainnya tidak pernah lihat ke mana.
-- Posisi satu musuh yang masih hidup, atau nil.
--
-- Ada supaya pemanggil tidak perlu memegang `Enemy` di antara dua pemanggilan:
-- CombatService membaca titik kena dari id, dan di antara `collectTargets` dan
-- pembacaan itu musuhnya bisa sudah mati karena turret atau zona di frame yang
-- sama. Memegang referensi `Enemy` yang sudah lepas dari `active` tidak error,
-- tapi memberi posisi musuh yang Part-nya sudah di-Destroy.
function EnemyService.getPosition(id: number): Vector3?
	local enemy = active[id]
	if enemy == nil or enemy.dead then
		return nil
	end
	return enemy.position
end

function EnemyService.liveTargets(): { CombatEffects.Target }
	local targets: { CombatEffects.Target } = {}
	for id, enemy in active do
		if not enemy.dead then
			table.insert(targets, { id = id, position = toVec(enemy.position) })
		end
	end
	return targets
end

-- Blokir satu lane selama `duration` detik (penghalang Toko Match, M3).
function EnemyService.blockLane(laneIndex: number, duration: number)
	if type(laneIndex) ~= "number" or type(duration) ~= "number" or duration <= 0 then
		return
	end
	local until_ = os.clock() + duration
	local current = laneBlockedUntil[laneIndex]
	if current == nil or current < until_ then
		laneBlockedUntil[laneIndex] = until_
	end
end

function EnemyService.laneCount(): number
	local arena = MapService.getArena()
	return if arena ~= nil then #arena.lanes else 0
end

return EnemyService
