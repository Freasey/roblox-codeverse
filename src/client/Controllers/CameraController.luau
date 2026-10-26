--!strict
-- CameraController.luau: sistem kamera (Soal 6).
--
-- APA YANG DIKERJAKAN SENDIRI, DAN APA YANG TIDAK
--
-- Cinemachine dipakai di Unity karena Unity tidak menyediakan kamera pengikut
-- siap pakai: follow, damping, tabrakan dengan dinding, dan occlusion harus
-- dirakit sendiri. Roblox sudah menyediakan ketiga hal yang paling sulit itu
--, orbit mouse, pencegahan tembus dinding, dan zoom, lewat PlayerModule
-- bawaannya, dan menulis ulang ketiganya hampir pasti menghasilkan kamera yang
-- lebih buruk, bukan lebih baik.
--
-- Jadi yang ditulis di sini adalah LAPISAN DI ATASNYA, yaitu persis bagian
-- yang membuat Cinemachine berguna dan yang TIDAK disediakan Roblox:
--
--   1. framing   : kamera digeser ke bahu, bukan tepat di belakang kepala,
--                  supaya badan pemain tidak menutupi apa yang dia bidik
--   2. damping   : pergeseran itu dikejar mulus, tidak melompat
--   3. look-ahead,  kamera memimpin sedikit ke arah lari, jadi pemain melihat
--                  ke mana dia menuju dan bukan dari mana dia datang
--   4. FOV kick  : sudut pandang melebar saat sprint dan dash
--   5. shake     : guncangan saat Core kena pukul, meredam sendiri
--
-- Semuanya lewat `Humanoid.CameraOffset` dan `Camera.FieldOfView`. Keduanya
-- memang disediakan Roblox untuk tujuan ini, dan karena dipakai sebagai
-- lapisan, seluruh penanganan tabrakan bawaan tetap bekerja: kamera yang
-- digeser ke bahu tetap tidak akan menembus dinding arena.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local localPlayer = Players.LocalPlayer
local started = false

local BASE_FOV = 70
local SPRINT_FOV = 78
local DASH_FOV = 86

-- Geser ke bahu kanan dan sedikit ke atas. Ke KANAN karena mayoritas pemain
-- membidik dengan tangan kanan dan titik bidik ada di tengah layar; badan yang
-- menutupi titik itu adalah keluhan pertama pada kamera orang-ketiga.
local SHOULDER = Vector3.new(1.9, 0.7, 0)

-- Seberapa jauh kamera memimpin arah lari, dalam stud per (stud/detik).
-- Kecil dengan sengaja: look-ahead yang besar membuat kamera terasa
-- "ditarik-tarik" tiap pemain berbelok.
local LOOK_AHEAD = 0.045
local LOOK_AHEAD_MAX = 2.4

-- Laju pengejaran, dipakai sebagai 1 - exp(-dt * RATE) supaya tidak bergantung
-- frame rate. Offset dikejar lebih lambat daripada FOV: pergeseran posisi yang
-- terlalu cepat terbaca sebagai sentakan, sementara FOV yang lambat terasa
-- seperti kamera yang terlambat bereaksi.
local OFFSET_RATE = 7
local FOV_RATE = 5

-- Guncangan memakai model "trauma": yang disimpan bukan besar guncangan
-- melainkan trauma 0..1 yang meluruh sendiri, dan guncangan yang terlihat
-- adalah trauma KUADRAT. Kuadratnya yang penting, guncangan jadi mereda
-- dengan cepat lalu berekor halus, bukan berhenti mendadak. Ini pola yang sama
-- yang dipakai Cinemachine Impulse.
local TRAUMA_DECAY = 1.9
local SHAKE_MAX = 1.5
local SHAKE_FREQUENCY = 26

local trauma = 0
local currentOffset = Vector3.zero
local currentFov = BASE_FOV
local shakeSeed = 0

-- Dipanggil dari luar (FxController) saat ada yang pantas diguncangkan.
-- `amount` 0..1. Ditambahkan, bukan ditimpa: dua pukulan beruntun harus terasa
-- lebih keras daripada satu, tapi tetap dijepit supaya ledakan beruntun tidak
-- pernah membuat layar tidak terbaca sama sekali.
function CameraController.shake(amount: number)
	if type(amount) ~= "number" or amount ~= amount then
		return
	end
	trauma = math.clamp(trauma + amount, 0, 1)
end

local function characterBits(): (Humanoid?, BasePart?)
	local character = localPlayer.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return humanoid, nil
	end
	return humanoid, root
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local humanoid, root = characterBits()
	if camera == nil or humanoid == nil or root == nil then
		return
	end

	local character = humanoid.Parent
	local stance = if character ~= nil then character:GetAttribute("Stance") else nil
	local dashing = if character ~= nil then character:GetAttribute("Dashing") == true else false

	-- ---------------------------------------------------------------- offset
	local target = SHOULDER

	-- Saat jongkok kamera ikut turun. Kalau tidak, pemain yang jongkok di balik
	-- rak server tetap melihat dari ketinggian berdiri, dan perlindungan yang
	-- didapatnya jadi tidak terlihat sama sekali di layar.
	if stance == "crouch" then
		target = target - Vector3.new(0, 1.5, 0)
	end

	-- Look-ahead dihitung di RUANG LOKAL kamera, bukan ruang dunia: offset-nya
	-- memang ditafsirkan relatif terhadap arah hadap kamera, jadi kecepatan
	-- dunia harus diproyeksikan dulu ke sumbu kamera. Tanpa proyeksi ini,
	-- kamera akan memimpin ke arah yang salah setiap kali pemain memutar
	-- pandangannya.
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 1 then
		local right = camera.CFrame.RightVector
		local forward = -camera.CFrame.LookVector
		local lateral = math.clamp(flat:Dot(right) * LOOK_AHEAD, -LOOK_AHEAD_MAX, LOOK_AHEAD_MAX)
		local depth = math.clamp(flat:Dot(forward) * LOOK_AHEAD, -LOOK_AHEAD_MAX, LOOK_AHEAD_MAX)
		target = target + Vector3.new(lateral, 0, depth)
	end

	local alpha = 1 - math.exp(-dt * OFFSET_RATE)
	currentOffset = currentOffset:Lerp(target, alpha)

	-- ----------------------------------------------------------------- shake
	trauma = math.max(0, trauma - TRAUMA_DECAY * dt)
	local shakeOffset = Vector3.zero
	if trauma > 0 then
		local magnitude = trauma * trauma * SHAKE_MAX
		shakeSeed += dt * SHAKE_FREQUENCY
		-- Tiga sinus berfrekuensi tidak kelipatan satu sama lain. Kalau
		-- frekuensinya kelipatan, ketiga sumbu kembali sefase secara berkala
		-- dan guncangan terasa seperti getaran mesin, bukan benturan.
		shakeOffset = Vector3.new(
			math.sin(shakeSeed * 1.0) * magnitude,
			math.sin(shakeSeed * 1.37 + 1.7) * magnitude * 0.8,
			math.sin(shakeSeed * 0.83 + 3.1) * magnitude * 0.4
		)
	end

	humanoid.CameraOffset = currentOffset + shakeOffset

	-- ------------------------------------------------------------------- FOV
	local targetFov = BASE_FOV
	if dashing then
		targetFov = DASH_FOV
	elseif stance == "sprint" and flat.Magnitude > 4 then
		targetFov = SPRINT_FOV
	end

	currentFov += (targetFov - currentFov) * (1 - math.exp(-dt * FOV_RATE))
	camera.FieldOfView = currentFov
end

function CameraController.start()
	if started then
		return
	end
	started = true

	-- Offset direset tiap respawn. Humanoid-nya memang baru, jadi CameraOffset
	-- -nya nol, tapi nilai yang di-cache di sini tidak, dan tanpa reset
	-- kamera melompat dari posisi karakter lama ke karakter baru.
	localPlayer.CharacterAdded:Connect(function()
		currentOffset = Vector3.zero
		trauma = 0
	end)

	RunService.RenderStepped:Connect(update)
end

return CameraController
