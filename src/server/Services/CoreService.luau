--!strict
-- CoreService.luau — HP Core Server, satu-satunya hal yang bisa membuat tim
-- kalah.
--
-- Service ini sengaja tidak tahu apa pun soal match, wave, atau musuh: dia cuma
-- angka HP dengan dua sinyal. Yang lain yang bereaksi. Dengan begitu
-- EnemyService bisa memanggil `damage()` tanpa ikut tahu soal MatchService, dan
-- tidak ada lingkaran require (lihat urutan wiring di init.server.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Modules.Balance)
local Signal = require(Shared.Modules.Signal)

local CoreService = {}

-- Ditembakkan setiap HP berubah: (hp, maxHp).
CoreService.onChanged = Signal.new() :: Signal.Signal<number, number>
-- Ditembakkan sekali saat HP mencapai 0. Tidak ditembakkan lagi sebelum reset.
CoreService.onDestroyed = Signal.new() :: Signal.Signal<()>

local maxHp = Balance.CORE_MAX_HP
local hp = maxHp
local destroyed = false

-- Visual opsional: kalau map menyediakan Core dengan PrimaryPart, warnanya
-- ikut turun supaya pemain melihat kondisi Core tanpa melihat HUD. Di-set dari
-- init.server.luau, bukan dibaca dari MapService di sini, supaya service ini
-- tetap tidak bergantung ke map.
local corePart: BasePart? = nil
local baseColor: Color3? = nil
local criticalColor = Color3.fromRGB(230, 70, 70)

local function refreshVisual()
	local part = corePart
	local original = baseColor
	if part == nil or original == nil then
		return
	end
	local fraction = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
	-- Lerp dari warna asli ke merah seiring HP turun.
	part.Color = original:Lerp(criticalColor, 1 - fraction)
end

function CoreService.bindVisual(part: BasePart?)
	corePart = part
	baseColor = if part ~= nil then part.Color else nil
	refreshVisual()
end

function CoreService.getHp(): number
	return hp
end

function CoreService.getMaxHp(): number
	return maxHp
end

function CoreService.isDestroyed(): boolean
	return destroyed
end

function CoreService.reset(newMaxHp: number?)
	maxHp = newMaxHp or Balance.CORE_MAX_HP
	hp = maxHp
	destroyed = false
	refreshVisual()
	CoreService.onChanged:Fire(hp, maxHp)
end

-- Satu tempat untuk memvalidasi jumlah HP, dipakai `damage` dan `heal`.
--
-- Dulu pengecekan ini ditulis dua kali, dan itu sebabnya celahnya juga ada dua
-- kali: keduanya menolak bukan-angka, NaN (`amount ~= amount`), dan nilai <= 0,
-- tapi keduanya meloloskan `math.huge`. Infinity itu angka, sama dengan dirinya
-- sendiri, dan lebih besar dari nol, jadi lolos ketiga penjaga. Akibatnya
-- `hp - math.huge` jadi `-inf`, `math.max(0, -inf)` jadi 0, dan Core hancur
-- seketika tanpa jejak apa pun di log.
--
-- Belum bisa dipicu pemain: `damage` cuma dipanggil EnemyService dengan
-- `enemy.coreDamage` dari modul definisi, dan `heal` dengan konstanta Balance.
-- Tapi begitu salah satu angka itu lahir dari pembagian atau pengali berantai,
-- infinity bisa muncul tanpa ada yang sengaja menulisnya.
local function isValidAmount(amount: unknown): boolean
	return type(amount) == "number"
		and amount == amount -- bukan NaN
		and amount > 0
		and amount ~= math.huge
end

-- Mengembalikan HP yang benar-benar hilang. Argumen divalidasi di sini, bukan
-- di pemanggil: angka negatif akan jadi "serangan yang menyembuhkan" dan NaN
-- membuat HP tidak pernah bisa dibandingkan lagi.
function CoreService.damage(amount: number): number
	if destroyed then
		return 0
	end
	if not isValidAmount(amount) then
		return 0
	end

	local before = hp
	hp = math.max(0, hp - amount)
	refreshVisual()
	CoreService.onChanged:Fire(hp, maxHp)

	if hp <= 0 and not destroyed then
		destroyed = true
		CoreService.onDestroyed:Fire()
	end

	return before - hp
end

-- Mengembalikan HP yang benar-benar dipulihkan. Tidak bisa menghidupkan Core
-- yang sudah hancur: begitu match kalah, `reset()` yang dipakai, bukan heal.
function CoreService.heal(amount: number): number
	if destroyed then
		return 0
	end
	if not isValidAmount(amount) then
		return 0
	end

	local before = hp
	hp = math.min(maxHp, hp + amount)
	refreshVisual()
	CoreService.onChanged:Fire(hp, maxHp)
	return hp - before
end

return CoreService
