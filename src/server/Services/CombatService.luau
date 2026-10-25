--!strict
-- CombatService.luau — validasi serangan pemain (bagian 3.7).
--
-- Client cuma mengirim NIAT: `Attack(direction)`. Semua sisanya diputuskan di
-- sini (bagian 1.2): senjata apa yang dipakai, level berapa, damage berapa,
-- cooldown sudah lewat atau belum, dan musuh mana yang kena. Tidak ada satu
-- angka pun dari client yang dipakai selain arah bidik, dan arah itu pun
-- dinormalisasi lalu dibatasi — client tidak bisa mengirim arah sepanjang 1000
-- stud untuk menjangkau musuh di luar `range`.
--
-- Soal uji kena yang longgar: alasannya panjang dan ditulis di HitTest.luau.
-- Ringkasnya, musuh digerakkan server jadi posisi di layar pemain selalu
-- tertinggal sebesar latensi, dan raycast setebal nol akan sering bilang tidak
-- kena padahal pemain membidik tepat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Config = require(Shared.Config)
local DataSchema = require(Shared.Modules.DataSchema)
local HitTest = require(Shared.Modules.HitTest)
local ProgressionRules = require(Shared.Modules.ProgressionRules)
local RateLimit = require(Shared.Modules.RateLimit)
local Types = require(Shared.Modules.Types)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Modules.Weapons)

local EnemyService = require(script.Parent.EnemyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CombatService = {}

export type Modifiers = {
	damageMult: number,
	cooldownMult: number,
}

local NEUTRAL: Modifiers = { damageMult = 1, cooldownMult = 1 }

-- Gerbang "boleh menyerang sekarang". Disuntik dari luar, bukan di-require dari
-- MatchService, supaya tidak ada lingkaran require dan supaya M1 bisa jalan
-- sebelum MatchService ada.
local gate: (Player) -> boolean = function(_player: Player)
	return false
end

-- Pengali tim dari Toko Match (M3). Disuntik dengan alasan yang sama.
local modifiers: () -> Modifiers = function()
	return NEUTRAL
end

-- 20 panggilan `Attack` per detik (bagian 3.6). Senjata tercepat punya cooldown
-- 0.25 detik = 4 serangan per detik, jadi batas ini longgar untuk pemain normal
-- dan tetap menutup spam.
local limiter = RateLimit.newRegistry({ Attack = 20 }, 20)

local lastAttackAt: { [number]: number } = {}
local started = false

function CombatService.setGate(fn: (Player) -> boolean)
	gate = fn
end

function CombatService.setModifiers(fn: () -> Modifiers)
	modifiers = fn
end

-- Senjata yang benar-benar dipakai pemain, menurut data di server.
--
-- Keputusannya ada di `ProgressionRules.equippedWeapon`, bukan di sini, dan itu
-- bukan sekadar perapian: `MatchService.onSelectLoadout` memeriksa kepemilikan
-- lewat fungsi murni yang sama. Dulu dua tempat ini punya pemeriksaan sendiri,
-- dan bedanya tidak kelihatan -- yang di sana menolak dengan pesan, yang di
-- sini DIAM-DIAM jatuh ke starter. Begitu `Config.DEV_ALL_WEAPONS` ada, selisih
-- sekecil apa pun di antara keduanya berarti pemain memilih Packet Rifle lalu
-- mengayunkan Patch Wrench tanpa satu pesan error pun.
-- Mengembalikan `def` DAN stat yang sudah jadi, bukan `def` dan level.
-- Menerjemahkan level jadi stat adalah pekerjaan `Balance.weaponStats`, dan
-- pemanggil yang memegang level mentah pasti akan menghitung salah satu stat
-- sendiri cepat atau lambat -- lalu melewatkan efek alur pada stat itu.
local function resolveWeapon(player: Player): (Weapons.WeaponDef, Types.WeaponStats)
	local data = PlayerDataService.get(player)
	if data == nil then
		-- Data belum termuat: starter level 1 tanpa alur, bukan error.
		-- Dipanggil tiap serangan, jadi tidak ada tempat untuk melapor di sini.
		local starter = Weapons.weapon_starter
		return starter, Balance.weaponStats(starter, { level = 1, path = DataSchema.NO_PATH })
	end

	local def, level = ProgressionRules.equippedWeapon(data, Weapons, Config.DEV_ALL_WEAPONS)
	-- Alur dibaca dari save senjata ITU, bukan dari `def`: `equippedWeapon`
	-- bisa jatuh ke starter, dan memakai alur senjata yang gagal dipakai akan
	-- memberi starter efek alur yang bukan miliknya.
	local save = data.weapons[def.id]
	return def,
		Balance.weaponStats(def, {
			level = level,
			path = if save ~= nil then save.path else DataSchema.NO_PATH,
		})
end

local function characterOrigin(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function toVec(v: Vector3): HitTest.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

type Candidate = {
	id: number,
	distance: number,
}

-- Kumpulkan musuh yang kena, paling dekat dulu, maksimal `projectiles` buah.
-- `stats` dan bukan `def` untuk range dan jumlah proyektil: alur upgrade bisa
-- mengubah keduanya, dan membaca `def` di sini berarti senjata yang
-- jangkauannya dinaikkan alur tetap menguji kena di jangkauan dasarnya. `def`
-- tetap dibutuhkan untuk `kind`, yang bukan stat dan tidak pernah berubah.
local function collectTargets(
	def: Weapons.WeaponDef,
	stats: Types.WeaponStats,
	origin: Vector3,
	aim: Vector3
): { Candidate }
	local originVec = toVec(origin)
	local aimVec = toVec(aim)
	local candidates: { Candidate } = {}

	for id, enemy in EnemyService.getAll() do
		if enemy.dead then
			continue
		end
		local targetVec = toVec(enemy.position)

		if def.kind == "melee" then
			local reach = stats.range + Balance.MELEE_RADIUS_BONUS
			if HitTest.inCone(originVec, aimVec, targetVec, reach, Balance.MELEE_MIN_COS) then
				table.insert(candidates, {
					id = id,
					distance = HitTest.horizontalDistance(originVec, targetVec),
				})
			end
		else
			local lateral, along =
				HitTest.distanceToAimSegment(originVec, aimVec, targetVec, stats.range)
			if lateral <= Balance.RANGED_RADIUS then
				-- Diurutkan berdasarkan jarak SEPANJANG garis bidik, bukan jarak
				-- ke pemain: musuh yang pertama dilewati proyektil yang kena
				-- lebih dulu.
				table.insert(candidates, { id = id, distance = along })
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local limit = math.max(1, stats.projectiles)
	while #candidates > limit do
		table.remove(candidates)
	end
	return candidates
end

local function onAttack(player: Player, rawDirection: unknown)
	local now = os.clock()

	if not RateLimit.check(limiter, player.UserId, "Attack", now) then
		return
	end

	-- Validasi argumen: client bisa mengirim apa saja (nil, tabel, string 1MB).
	if typeof(rawDirection) ~= "Vector3" then
		return
	end
	local direction = rawDirection :: Vector3
	-- NaN dan inf lolos dari typeof tapi meracuni semua perbandingan
	-- sesudahnya, jadi dicek di sini sekali.
	local magnitude = direction.Magnitude
	if magnitude ~= magnitude or magnitude == math.huge or magnitude < 1e-3 then
		return
	end

	if not gate(player) then
		return
	end

	local origin = characterOrigin(player)
	if origin == nil then
		return
	end

	local def, stats = resolveWeapon(player)
	local mods = modifiers()

	local cooldown = stats.cooldown * math.max(0.1, mods.cooldownMult)
	local last = lastAttackAt[player.UserId]
	-- Toleransi 50 ms: client yang jujur pun bisa mengirim sedikit lebih cepat
	-- karena jitter jaringan, dan menolaknya terasa seperti serangan hilang.
	if last ~= nil and now - last < cooldown - 0.05 then
		return
	end
	lastAttackAt[player.UserId] = now

	local damage = stats.damage * math.max(0, mods.damageMult)
	if damage <= 0 then
		return
	end

	for _, candidate in collectTargets(def, stats, origin, direction.Unit) do
		EnemyService.damage(candidate.id, damage, player)
	end
end

function CombatService.start()
	if started then
		return
	end
	started = true

	Remotes.Events.Attack.OnServerEvent:Connect(function(player: Player, direction: unknown)
		onAttack(player, direction)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player.UserId] = nil
		RateLimit.forget(limiter, player.UserId)
	end)
end

-- Dipanggil saat match baru dimulai: cooldown dari match sebelumnya tidak boleh
-- menahan serangan pertama.
function CombatService.resetCooldowns()
	table.clear(lastAttackAt)
end

return CombatService
