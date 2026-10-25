--!strict
-- ShopService.luau — Toko Match: cash per pemain dan upgrade senjata.
--
-- APA YANG DIJUAL TOKO INI BERUBAH. Dulu lima item berefek tim (Exploit Patch,
-- Overclock, Hotfix, Firewall Block, Scanner Turret). Sekarang yang dijual tiap
-- jeda antar wave adalah UPGRADE SENJATA pemain itu sendiri, beserta ketiga
-- alurnya. Kelima item lama dimatikan lewat `Config.MATCH_SHOP_ITEMS_ENABLED`,
-- bukan dihapus: kodenya masih benar dan menunggu kalau nanti dipakai lagi.
--
-- CASH PER PEMAIN, BUKAN SATU KOLAM TIM, dan itu berubah bersamanya. Upgrade
-- senjata milik satu orang: kalau empat pemain berbagi satu kolam untuk barang
-- pribadi, tiap orang cuma kebagian seperempat dan yang paling cepat menekan
-- tombol memakai uang bersama untuk dirinya sendiri. Satu kolam tim benar
-- selama yang dibeli efek tim; begitu yang dibeli barang pribadi, dia salah.
--
-- LEVEL DAN ALUR DIMULAI ULANG TIAP MATCH. Cash habis tiap match selesai, jadi
-- apa pun yang dibelinya ikut habis. `data.weapons[id].level` yang permanen
-- TIDAK dibaca di sini dan tidak ikut naik -- yang dipakai `matchWeapons` di
-- bawah, yang umurnya satu match.
--
-- DUA MATA UANG, DAN NAMANYA SENGAJA BERBEDA. Yang di sini **cash**: milik
-- tim, habis tiap match selesai, cuma bisa dibelanjakan di Toko Match. Yang di
-- lobby **koin**: milik satu pemain, permanen, dipakai untuk upgrade senjata.
-- Keduanya pernah sama-sama disebut "koin", dan itu membuat pemain menabung
-- mata uang yang salah untuk barang yang dia incar -- satu-satunya tanda
-- bahwa dia salah adalah angka yang tidak pernah naik.
--
-- Yang TIDAK ikut berganti nama: field dan remote. `MatchCoins`, `addCoins`,
-- `context.coins`, dan `Enemies[...].matchCoins` tetap memakai kata coins,
-- karena nama remote dipatok tabel docs/DEVELOPMENT_PLAN.md bagian 3.6 dan
-- mengubahnya berarti mengubah kontrak jaringan untuk sebuah pergantian kata
-- di layar. Jadi: kalau sebuah nama dibaca PEMAIN, dia "cash"; kalau dia cuma
-- dibaca programmer, dia tetap coins.
--
-- Cash pemain yang disconnect TIDAK dihapus saat dia keluar, dengan alasan
-- yang sama seperti `participants` di MatchService: dia boleh rejoin dan
-- melanjutkan match yang sama, dan saldo yang hangus saat koneksi putus
-- sebentar adalah hukuman untuk sesuatu yang bukan salahnya. Yang
-- membersihkannya reset antar match.
--
-- Semua keputusan beli ada di ShopRules.luau (modul murni, ada unit test-nya).
-- Yang tinggal di sini cuma yang butuh runtime Roblox: menerima remote,
-- menyiarkan state, dan menjalankan efeknya di dunia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Config = require(Shared.Config)
local MatchUpgradeRules = require(Shared.Modules.MatchUpgradeRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.Modules.ShopItems)
local ShopRules = require(Shared.Modules.ShopRules)
local Signal = require(Shared.Modules.Signal)
local Types = require(Shared.Modules.Types)
local Weapons = require(Shared.Modules.Weapons)

local CoreService = require(script.Parent.CoreService)
local EnemyService = require(script.Parent.EnemyService)
local MatchService = require(script.Parent.MatchService)
local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShopService = {}

-- (UserId, saldo baru).
ShopService.onCashChanged = Signal.new() :: Signal.Signal<number, number>

local FOLDER_NAME = "ShopEffects"

-- Cash per UserId, bukan satu angka. UserId dan bukan objek Player karena
-- objek Player hilang saat pemain disconnect, dan peserta yang rejoin harus
-- menemukan saldonya utuh -- alasan yang sama dengan `participants` di
-- MatchService.
local cash: { [number]: number } = {}

-- Level dan alur senjata yang berlaku DI DALAM match ini, per UserId. Satu
-- save per pemain, bukan per senjata, karena fase `Loadout` sudah mengunci
-- senjata yang dipakai sampai match selesai.
local matchWeapons: { [number]: Types.WeaponSave } = {}

local purchases: { [string]: number } = {}
local locked = false
local started = false

-- Mekanik boss Locker (M4, analogi ransomware): selama dia hidup, upgrade tim
-- yang SUDAH dibeli disandera — damage dan attack speed kembali ke nilai dasar
-- sampai boss-nya mati.
--
-- Kenapa menyandera yang sudah dibeli, bukan melarang membeli: melarang
-- membeli tidak menolak apa pun. Toko cuma buka saat `Intermission`, Locker
-- cuma hidup saat `WaveActive`, dan wave 10 — wave-nya Locker — adalah wave
-- terakhir v1 sehingga tidak ada `Intermission` sesudahnya. Jadi kunci toko
-- selalu benar secara hampa. Menyandera yang sudah dimiliki justru lebih dekat
-- ke ransomware aslinya, dan efeknya terjadi di `WaveActive` tempat Locker
-- memang hidup.
--
-- Pembukuan `purchases` TIDAK dihapus saat disandera. Yang dikosongkan cuma
-- masukan ke perhitungan di `getModifiers`, jadi begitu Locker mati seluruh
-- upgrade kembali tanpa perlu dicatat ulang di mana pun.
local suspended = false
local NO_PURCHASES: { [string]: number } = {}

-- Penghalang yang dibeli saat Intermission berlaku di wave BERIKUTNYA, bukan
-- sekarang: saat Intermission tidak ada musuh yang berjalan, jadi memasangnya
-- langsung berarti efeknya habis sebelum ada yang perlu ditahan.
local pendingBarriers = 0

type Turret = {
	part: Part,
	position: Vector3,
	nextShotAt: number,
}

local turrets: { Turret } = {}
local effectsFolder: Folder? = nil
local turretLoop: thread? = nil

local limiter = RateLimit.newRegistry({ BuyShopItem = 2, UpgradeWeapon = 2 }, 2)

local function getFolder(): Folder
	local existing = effectsFolder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local found = Workspace:FindFirstChild(FOLDER_NAME)
	if found == nil or not found:IsA("Folder") then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = Workspace
		found = made
	end
	effectsFolder = found :: Folder
	return effectsFolder :: Folder
end

local function cashOf(userId: number): number
	return cash[userId] or 0
end

-- Senjata yang berlaku di match ini untuk pemain itu. Save BARU kalau dia
-- belum pernah upgrade, bukan nil: pemanggilnya menghitung stat, dan nil di
-- sana berarti setiap pembaca harus menangani "belum punya" sendiri-sendiri.
local function matchWeaponOf(userId: number): Types.WeaponSave
	local existing = matchWeapons[userId]
	if existing ~= nil then
		return existing
	end
	return MatchUpgradeRules.freshSave()
end

-- Dikirim ke SATU pemain, bukan FireAllClients: saldo sekarang milik
-- masing-masing orang, dan menyiarkannya ke semua berarti tiap client
-- menampilkan saldo pemain yang terakhir berubah.
local function broadcastCashTo(player: Player)
	Remotes.Events.MatchCoins:FireClient(player, math.floor(cashOf(player.UserId)))
end

local function broadcastUpgradeStateTo(player: Player)
	local data = PlayerDataService.get(player)
	local save = matchWeaponOf(player.UserId)
	Remotes.Events.MatchUpgradeState:FireClient(player, {
		weaponId = if data ~= nil then data.equippedWeapon else "weapon_starter",
		level = save.level,
		path = save.path,
	})
end

local function broadcastToAll()
	for _, player in Players:GetPlayers() do
		broadcastCashTo(player)
		broadcastUpgradeStateTo(player)
	end
end

local function broadcastShopState()
	Remotes.Events.ShopState:FireAllClients({
		open = MatchService.getState() == ShopRules.OPEN_STATE and not locked,
		locked = locked,
		-- Salinan, bukan tabel aslinya: tabel yang dikirim lewat remote
		-- di-serialize saat itu juga, tapi mengirim referensi internal ke luar
		-- modul tetap jalan yang salah — satu pemanggil yang menyimpannya bisa
		-- mengubah pembukuan toko dari luar.
		purchases = table.clone(purchases),
		-- Pemain WAJIB diberi tahu kalau upgrade-nya sedang disandera. Tanpa
		-- ini damage-nya turun tanpa penjelasan dan itu terasa seperti bug,
		-- bukan seperti mekanik boss.
		suspended = suspended,
	})
end

local function clearEffects()
	for _, turret in turrets do
		turret.part:Destroy()
	end
	turrets = {}
	pendingBarriers = 0
	local folder = effectsFolder
	if folder ~= nil then
		folder:ClearAllChildren()
	end
end

function ShopService.reset()
	cash = {}
	-- Level dan alur ikut dibuang. Inilah yang membuat alur jadi keputusan yang
	-- diambil berkali-kali alih-alih sekali seumur akun.
	matchWeapons = {}
	purchases = {}
	locked = false
	-- Jaring pengaman antar match. Kalau Locker mati lewat jalur yang tidak
	-- memanggil onDefeated maupun cleanup (Core hancur di detik yang sama,
	-- match dibatalkan), sanderanya tidak boleh ikut terbawa ke match
	-- berikutnya — itu akan terlihat sebagai damage yang diam-diam mengecil.
	suspended = false
	clearEffects()
	broadcastToAll()
	broadcastShopState()
end

function ShopService.getCash(userId: number): number
	return cashOf(userId)
end

-- Dibaca CombatService lewat suntikan di init.server.luau, bukan lewat require:
-- CombatService tidak boleh bergantung ke service ini, dengan alasan yang sama
-- seperti `setModifiers` dan `setGate`.
function ShopService.getMatchWeapon(userId: number): Types.WeaponSave
	return matchWeaponOf(userId)
end

function ShopService.getPurchases(): { [string]: number }
	return table.clone(purchases)
end

-- Dipanggil mekanik boss Locker (M4). Terpisah dari "toko tutup karena bukan
-- Intermission": pemain perlu tahu bedanya, dan pesannya memang beda.
function ShopService.setLocked(value: boolean)
	if locked == value then
		return
	end
	locked = value
	broadcastShopState()
end

function ShopService.isLocked(): boolean
	return locked
end

-- Dipanggil mekanik boss Locker. Lihat alasan lengkapnya di deklarasi
-- `suspended` di atas.
function ShopService.setSuspended(value: boolean)
	if suspended == value then
		return
	end
	suspended = value
	broadcastShopState()
end

function ShopService.isSuspended(): boolean
	return suspended
end

-- Pengali tim untuk CombatService. Dihitung dari pembukuan pembelian, bukan
-- disimpan sebagai angka yang di-increment: kalau disimpan, satu reset yang
-- terlewat membuat buff match sebelumnya ikut terbawa, dan itu tidak akan
-- kelihatan sampai ada yang mengukur damage-nya.
--
-- Saat disandera Locker, yang dioper adalah tabel kosong — bukan `purchases`
-- yang dihapus. `ShopRules.modifiers` itu fungsi murni dan pembelian kosong
-- menghasilkan pengali dasar, jadi penangguhannya tidak butuh logika baru
-- sama sekali, dan pemulihannya tidak butuh pembukuan cadangan.
function ShopService.getModifiers(): ShopRules.Modifiers
	return ShopRules.modifiers(
		if suspended then NO_PURCHASES else purchases,
		Balance.SHOP_DAMAGE_STEP,
		Balance.SHOP_FIRE_RATE_STEP,
		Balance.SHOP_COOLDOWN_FLOOR
	)
end

local function awardTo(player: Player, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	cash[player.UserId] = cashOf(player.UserId) + amount
	broadcastCashTo(player)
	ShopService.onCashChanged:Fire(player.UserId, cashOf(player.UserId))
end

-- Dibayarkan ke setiap peserta yang sedang terhubung. Dipakai hadiah per wave,
-- dan juga untuk musuh yang mati tanpa pembunuh yang bisa ditunjuk.
local function awardParticipants(amount: number)
	for _, player in Players:GetPlayers() do
		if MatchService.isParticipant(player) then
			awardTo(player, amount)
		end
	end
end

-- Pintu dari luar, dipakai hadiah per wave. Kebijakan angkanya ada di
-- `Balance.waveCash`, waktunya di MatchService, dan penjagaan nilainya di sini
-- -- bukan satu service yang mengurus ketiganya.
function ShopService.addCashToParticipants(amount: number)
	awardParticipants(amount)
end

-- --------------------------------------------------------------------------
-- Efek tiap item
-- --------------------------------------------------------------------------

local function placeBarrier(laneIndex: number, position: Vector3, duration: number)
	local part = Instance.new("Part")
	part.Name = string.format("Barrier%d", laneIndex)
	part.Size = Vector3.new(16, 8, 2)
	part.Color = Color3.fromRGB(90, 170, 240)
	part.Material = Enum.Material.ForceField
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	part.Parent = getFolder()

	-- Dihapus setelah durasinya habis, dengan Debris-style task.delay. Bukan
	-- dibiarkan lalu dibersihkan saat match selesai: pemain harus melihat
	-- penghalangnya hilang tepat saat musuh mulai bergerak lagi, kalau tidak
	-- dia tidak tahu kapan efeknya habis.
	--
	-- Durasinya dioper pemanggil, bukan dibaca dari Balance di sini: beberapa
	-- pembelian menumpuk durasi blokirnya (lihat applyBarriers), dan dinding
	-- yang hilang di detik 6 sementara musuh masih tertahan sampai detik 12
	-- membuat pemain mengira efeknya sudah habis.
	task.delay(duration, function()
		part:Destroy()
	end)
end

-- Penghalang berlaku di SEMUA lane, bukan satu lane pilihan pemain.
-- Alasannya payload remote: bagian 3.6 memaku `BuyShopItem` menerima `itemId`
-- saja, tanpa lane. Menambah argumen lane berarti menyimpang dari tabel itu,
-- dan menebak lane mana yang dimaksud pemain lebih buruk daripada memberi
-- efek yang jelas dan bisa diprediksi.
local function applyBarriers()
	if pendingBarriers <= 0 then
		return
	end
	local count = pendingBarriers
	pendingBarriers = 0

	local arena = MapService.getArena()
	local laneCount = EnemyService.laneCount()
	if laneCount == 0 then
		return
	end

	-- Beberapa pembelian menumpuk durasinya, bukan jumlah penghalangnya:
	-- dua penghalang di lane yang sama pada waktu yang sama tidak menahan
	-- musuh dua kali lebih kuat, tapi menahan dua kali lebih lama jelas iya.
	local duration = Balance.BARRIER_DURATION * count
	for laneIndex = 1, laneCount do
		EnemyService.blockLane(laneIndex, duration)
		if arena ~= nil then
			local lane = arena.lanes[laneIndex]
			-- Digambar di tengah lane, di waypoint pertengahan: di ujung dekat
			-- Core penghalangnya tidak terlihat sebagai penahan, dan di ujung
			-- spawn musuh belum sampai ke sana.
			local middle = lane.waypoints[math.max(1, #lane.waypoints // 2)]
			placeBarrier(laneIndex, middle, duration)
		end
	end
end

local function spawnTurret()
	local arena = MapService.getArena()
	if arena == nil then
		return
	end

	-- Posisi turret ditentukan server, bukan pemain: bagian 3.6 memaku payload
	-- `BuyShopItem` jadi `itemId` saja. Diletakkan mengelilingi Core dengan
	-- sudut yang ditentukan nomor pembelian, jadi turret kedua tidak menumpuk
	-- di atas turret pertama.
	local index = #turrets
	local angle = index * (math.pi * 2 / 4) + math.pi / 4
	local radius = 26
	local position = arena.corePosition
		+ Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)

	local part = Instance.new("Part")
	part.Name = string.format("Turret%d", index + 1)
	part.Size = Vector3.new(3, 6, 3)
	part.Color = Color3.fromRGB(120, 220, 200)
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position)
	part.Parent = getFolder()

	table.insert(turrets, { part = part, position = position, nextShotAt = 0 })
end

local function stepTurrets()
	if #turrets == 0 then
		return
	end
	if MatchService.getState() ~= "WaveActive" then
		return
	end

	local now = os.clock()
	for _, turret in turrets do
		if now < turret.nextShotAt then
			continue
		end

		-- Musuh terdekat dalam jangkauan. Dihitung ulang tiap tembakan dan
		-- tidak disimpan: target yang disimpan bisa sudah mati, dan menyimpan
		-- referensi ke musuh yang sudah dihapus adalah cara paling mudah
		-- membuat turret berhenti menembak selamanya.
		local bestId: number? = nil
		local bestDistance = Balance.TURRET_RANGE
		for id, enemy in EnemyService.getAll() do
			if enemy.dead then
				continue
			end
			local distance = (enemy.position - turret.position).Magnitude
			if distance <= bestDistance then
				bestDistance = distance
				bestId = id
			end
		end

		if bestId ~= nil then
			turret.nextShotAt = now + Balance.TURRET_INTERVAL
			-- Turret tidak dikaitkan ke pemain mana pun: koin dari musuh yang
			-- dibunuhnya masuk ke tim, sama seperti koin lainnya.
			EnemyService.damage(bestId, Balance.TURRET_DAMAGE, nil)
			turret.part.CFrame = CFrame.lookAt(turret.position, turret.position)
		end
	end
end

local EFFECTS: { [string]: () -> () } = {
	shop_core_repair = function()
		CoreService.heal(CoreService.getMaxHp() * Balance.CORE_REPAIR_FRACTION)
	end,
	shop_barrier = function()
		pendingBarriers += 1
	end,
	shop_turret = spawnTurret,
	-- Dua item berikut tidak punya efek langsung: pengaruhnya dibaca
	-- CombatService lewat getModifiers() dari pembukuan pembelian.
	shop_damage_up = function() end,
	shop_fire_rate = function() end,
}

-- --------------------------------------------------------------------------
-- Remote
-- --------------------------------------------------------------------------

local function reject(player: Player, reason: string)
	Remotes.Events.ActionResult:FireClient(player, {
		action = "BuyShopItem",
		ok = false,
		reason = reason,
	})
end

local function onBuy(player: Player, rawId: unknown)
	if not RateLimit.check(limiter, player.UserId, "BuyShopItem", os.clock()) then
		return
	end
	if type(rawId) ~= "string" then
		return
	end
	local itemId = rawId :: string

	-- Yang bukan peserta match tidak boleh membelanjakan koin tim. Tidak
	-- disebut bagian 3.6 secara eksplisit, tapi mengikuti aturan yang sama
	-- dengan `Attack`: pemain yang ditahan di lobby bukan bagian dari match
	-- yang sedang berjalan (bagian 3.3).
	if not MatchService.isParticipant(player) then
		reject(player, "Kamu bukan peserta match ini.")
		return
	end

	-- Kelima item dimatikan, dan penolakannya DI SERVER, bukan cuma dengan
	-- menyembunyikan panelnya di client. Client yang dimodifikasi tetap bisa
	-- menembakkan remote ini, dan fitur yang "dimatikan" tapi masih bisa
	-- dibeli lewat remote bukan fitur yang dimatikan.
	if not Config.MATCH_SHOP_ITEMS_ENABLED then
		reject(player, "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.")
		return
	end

	local def = ShopItems.get(itemId)
	local ok, reason = ShopRules.canBuy(def, {
		state = MatchService.getState(),
		locked = locked,
		coins = cashOf(player.UserId),
		purchases = purchases,
		priceGrowth = Balance.SHOP_PRICE_GROWTH,
	})

	if not ok or def == nil then
		reject(player, reason or "Pembelian ditolak.")
		return
	end

	-- Potong koin dan catat pembelian SEBELUM efeknya dijalankan. Efeknya bisa
	-- yield (task.delay di penghalang) dan dua pembelian dari dua pemain bisa
	-- datang di frame yang sama; memotong dulu berarti tidak ada celah di mana
	-- koin yang sama bisa dibelanjakan dua kali.
	-- Harga dihitung dari `purchases` SEBELUM dinaikkan. Urutannya satu-satunya
	-- yang benar: dibalik, pemain dibebani harga pembelian BERIKUTNYA, dan
	-- selisihnya tidak akan terlihat sampai ada yang membandingkan angka di
	-- tombol dengan koin yang hilang.
	local price = ShopRules.priceFor(def, purchases, Balance.SHOP_PRICE_GROWTH)
	cash[player.UserId] = cashOf(player.UserId) - price
	purchases[def.id] = (purchases[def.id] or 0) + 1

	broadcastCashTo(player)
	broadcastShopState()

	local effect = EFFECTS[def.id]
	if effect ~= nil then
		effect()
	end

	Remotes.Events.ActionResult:FireClient(player, {
		action = "BuyShopItem",
		ok = true,
		reason = nil,
	})

	print(
		string.format(
			"[ShopService] %s beli %s (%d cash), sisa %d",
			player.Name,
			def.id,
			price,
			math.floor(cashOf(player.UserId))
		)
	)
end

-- --------------------------------------------------------------------------
-- Upgrade senjata di dalam match
-- --------------------------------------------------------------------------

local function rejectUpgrade(player: Player, reason: string)
	Remotes.Events.ActionResult:FireClient(player, {
		action = "UpgradeWeapon",
		ok = false,
		reason = reason,
	})
end

local function onUpgradeWeapon(player: Player, rawWeaponId: unknown, rawPathId: unknown)
	if not RateLimit.check(limiter, player.UserId, "UpgradeWeapon", os.clock()) then
		return
	end
	if type(rawWeaponId) ~= "string" then
		return
	end
	-- `pathId` yang bukan string jadi nil, bukan alasan untuk membatalkan:
	-- di level selain titik percabangan dia memang diabaikan, dan menolak
	-- seluruh upgrade karena argumen opsional yang salah bentuk berarti
	-- client lama tidak bisa upgrade sama sekali.
	local pathId: string? = if type(rawPathId) == "string" then rawPathId :: string else nil

	if not MatchService.isParticipant(player) then
		rejectUpgrade(player, "Kamu bukan peserta match ini.")
		return
	end

	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end

	-- Senjata yang di-upgrade adalah senjata yang SEDANG DIPAKAI, bukan yang
	-- dikirim client. Id dari client cuma diperiksa kecocokannya, supaya
	-- tombol yang ditekan di panel lama -- sesudah pemain ganti senjata --
	-- tidak diam-diam menaikkan senjata yang lain.
	if rawWeaponId ~= data.equippedWeapon then
		rejectUpgrade(player, "Senjata itu bukan yang sedang kamu pakai.")
		return
	end

	local def = Weapons[data.equippedWeapon]
	local save = matchWeaponOf(player.UserId)

	local ok, reason = MatchUpgradeRules.canUpgrade(def, save, {
		state = MatchService.getState(),
		cash = cashOf(player.UserId),
		locked = locked,
	}, pathId)

	if not ok or def == nil then
		rejectUpgrade(player, reason or "Upgrade ditolak.")
		return
	end

	-- Harga dibaca dari save SEBELUM naik, dan cash dipotong SEBELUM save
	-- diganti. Dibalik, pemain dibebani harga level berikutnya -- selisih yang
	-- tidak akan terlihat sampai ada yang membandingkan angka di tombol dengan
	-- cash yang hilang.
	local price = MatchUpgradeRules.priceFor(def, save)
	cash[player.UserId] = cashOf(player.UserId) - price
	matchWeapons[player.UserId] = MatchUpgradeRules.applyUpgrade(def, save, pathId)

	broadcastCashTo(player)
	broadcastUpgradeStateTo(player)

	Remotes.Events.ActionResult:FireClient(player, {
		action = "UpgradeWeapon",
		ok = true,
		reason = nil,
	})

	local applied = matchWeapons[player.UserId]
	print(
		string.format(
			"[ShopService] %s upgrade %s ke level %d%s (%d cash), sisa %d",
			player.Name,
			def.id,
			applied.level,
			if applied.path ~= save.path then string.format(" alur %s", applied.path) else "",
			price,
			math.floor(cashOf(player.UserId))
		)
	)
end

function ShopService.start()
	if started then
		return
	end
	started = true

	local valid, problem = ShopItems.validate()
	if not valid then
		warn(string.format("[ShopService] data ShopItems tidak valid: %s", tostring(problem)))
	end

	Remotes.Events.BuyShopItem.OnServerEvent:Connect(onBuy)
	Remotes.Events.UpgradeWeapon.OnServerEvent:Connect(onUpgradeWeapon)

	-- Cash dari musuh yang mati masuk ke YANG MEMBUNUHNYA. Musuh yang mati
	-- tanpa pembunuh yang bisa ditunjuk -- zona jebakan, turret, mekanik boss
	-- -- dibayarkan ke semua peserta: membiarkannya hangus berarti alur
	-- Jebakan menghasilkan lebih sedikit cash justru karena dia bekerja
	-- sendiri, dan itu menghukum alur yang dipilih pemain.
	EnemyService.onDied:Connect(function(enemy, by: Player?)
		if by ~= nil then
			awardTo(by, enemy.matchCoins)
		else
			awardParticipants(enemy.matchCoins)
		end
	end)

	MatchService.onWaveReward:Connect(function(amount: number, waveNumber: number)
		if amount <= 0 then
			return
		end
		awardParticipants(amount)
		print(
			string.format(
				"[ShopService] hadiah wave %d: %d cash untuk tiap peserta",
				waveNumber,
				amount
			)
		)
	end)

	-- Pemain yang baru join -- termasuk yang rejoin ke match berjalan -- harus
	-- langsung melihat saldo dan level senjatanya, bukan menunggu pembelian
	-- berikutnya yang kebetulan menyiarkan ulang.
	Players.PlayerAdded:Connect(function(player)
		broadcastCashTo(player)
		broadcastUpgradeStateTo(player)
	end)

	MatchService.onStateChanged:Connect(function(next: MatchService.State, previous)
		if next == "WaveActive" then
			-- Penghalang yang dibeli saat jeda dipasang sekarang, tepat saat
			-- musuh mulai bergerak lagi.
			if previous == "Intermission" then
				applyBarriers()
			end
		elseif next == "Lobby" then
			ShopService.reset()
		end
		broadcastShopState()
	end)

	-- Match baru: koin dan pembelian dari match sebelumnya tidak boleh
	-- terbawa. Di-reset saat Countdown, bukan saat WaveActive, supaya pemain
	-- sudah melihat saldo 0 sebelum wave pertama mulai.
	MatchService.onStateChanged:Connect(function(next: MatchService.State)
		if next == "Countdown" then
			ShopService.reset()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player.UserId)
	end)

	turretLoop = task.spawn(function()
		while true do
			RunService.Heartbeat:Wait()
			stepTurrets()
		end
	end)

	broadcastToAll()
	broadcastShopState()
end

function ShopService.stop()
	local thread = turretLoop
	if thread ~= nil then
		task.cancel(thread)
		turretLoop = nil
	end
	started = false
end

return ShopService
