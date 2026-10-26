--!strict
-- CharacterAnimatorController.luau: pemutar animasi karakter.
--
-- Mengambil sudut sendi dari `Shared.Modules.Poses` dan menuliskannya ke
-- Motor6D tiap karakter, sekali per frame.
--
-- KENAPA DI CLIENT, DAN KENAPA UNTUK SEMUA PEMAIN SEKALIGUS
--
-- Perubahan `Motor6D.C0` tidak direplikasi dari client ke mana pun. Kalau
-- controller ini cuma menganimasikan karakter pemiliknya sendiri, hasilnya:
-- tiap pemain melihat dirinya bergerak dan melihat tiga rekan setimnya meluncur
-- kaku. Jadi controller ini menganimasikan SEMUA karakter yang ada di server,
-- dan tiap client melakukannya sendiri untuk dirinya sendiri. Hasil akhirnya
-- sama di semua layar karena masukannya sama.
--
-- Pilihan lain adalah menganimasikan dari server supaya C0-nya direplikasi.
-- Itu ditolak: replikasi properti berjalan jauh lebih jarang daripada frame
-- render, jadi animasinya akan tersendat, dan biayanya naik seiring jumlah
-- pemain. Yang di sini berjalan mulus 60 fps dan tidak memakai bandwidth sama
-- sekali.
--
-- MASUKANNYA HARUS YANG TEREPLIKASI
--
-- Karena karakter pemain lain dianimasikan di sini juga, state-nya hanya boleh
-- disimpulkan dari hal yang memang sampai ke client ini:
--   `Humanoid.FloorMaterial`     : apakah menapak atau melayang
--   `AssemblyLinearVelocity`     : cepat atau diam, naik atau turun
--   `Humanoid.WalkSpeed`         : pembagi supaya amplitudo ikut kecepatan
-- Ketiganya properti yang direplikasi. Niat tombol pemain TIDAK dipakai; dia
-- cuma ada di mesin pemiliknya.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MoveRules = require(ReplicatedStorage.Shared.Modules.MoveRules)
local Poses = require(ReplicatedStorage.Shared.Modules.Poses)
local UiKit = require(script.Parent.UiKit)

local CharacterAnimatorController = {}

local localPlayer = Players.LocalPlayer
local started = false

-- Seberapa cepat pose yang terlihat mengejar pose sasaran. Dipakai sebagai
-- `1 - exp(-dt * RATE)` supaya hasilnya tidak bergantung frame rate: pemain
-- 30 fps dan pemain 144 fps melihat peralihan yang sama cepatnya.
local BLEND_RATE = 14

-- Di bawah kecepatan ini karakter dianggap diam. Tidak nol, karena Humanoid
-- yang berdiri di lantai tetap punya kecepatan sisa yang kecil dan karakternya
-- akan berkedip antara idle dan run kalau ambangnya nol.
local IDLE_SPEED = 1.2

-- Kecepatan acuan untuk amplitudo pose: kecepatan sprint.
--
-- Dulu amplitudo dibagi `Humanoid.WalkSpeed`, dan itu lubangnya, WalkSpeed
-- ikut berubah mengikuti sikap, jadi berjalan dan sprint sama-sama
-- menghasilkan amplitudo 1. Dibagi satu angka TETAP, berjalan menghasilkan
-- 16/25 = 0.64 dan sprint 1.0, jadi langkahnya benar-benar melebar saat lari.
local REFERENCE_SPEED = MoveRules.SPEEDS.sprint

-- Di atas kecepatan jatuh ini, pendaratan dianggap sekeras-kerasnya. Dipilih
-- dari kecepatan jatuh setelah turun dari platform setinggi 6 stud di
-- gravitasi Roblox (sekitar 48 stud/detik).
local HARD_LANDING_SPEED = 55

type Entry = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	joints: { [string]: Motor6D },
	baseC0: { [string]: CFrame },
	current: { [string]: { number } },
	phase: number,
	complete: boolean,
	-- Kemajuan gerakan serangan, 0..1. Nilai >= 1 berarti tidak sedang
	-- menyerang; dimulai dari 0 setiap kali atribut `AttackSeq` berubah.
	attackT: number,
	attackKind: string,
	-- Kemajuan gerakan mendarat, 0..1, dan sekeras apa pendaratannya.
	landT: number,
	landStrength: number,
	wasGrounded: boolean,
	lastFallSpeed: number,
	-- Diisi tiap frame, dibaca panel diagnosis F3.
	debugState: string,
	debugAmp: number,
	debugSpeed: number,
	debugStride: number,
	-- Sendi yang belum ketemu, dan apakah ketiadaannya sudah dilaporkan sekali
	-- ke Output. `age` dipakai sebagai masa tenggang: rig R15 butuh beberapa
	-- frame untuk lengkap, dan melapor di frame pertama akan selalu salah.
	missing: { string },
	reported: boolean,
	age: number,
}

local entries: { [Model]: Entry } = {}

local function collectJoints(character: Model, entry: Entry)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and entry.joints[descendant.Name] == nil then
			-- C0 asal disimpan SEKALI, saat sendi pertama kali terlihat.
			-- Semua pose dihitung relatif terhadapnya, jadi kalau nilai ini
			-- diambil ulang setelah animasi berjalan, pose yang sedang
			-- terpasang ikut terbaca sebagai "asal" dan karakternya pelan-
			-- pelan terpelintir makin jauh tiap kali.
			entry.joints[descendant.Name] = descendant
			entry.baseC0[descendant.Name] = descendant.C0
		end
	end

	local missing: { string } = {}
	for _, name in Poses.JOINTS do
		if entry.joints[name] == nil then
			table.insert(missing, name)
		end
	end

	entry.complete = #missing == 0
	entry.missing = missing
end

-- BUG YANG PERNAH ADA DI SINI, dan kenapa bentuk fungsi ini sekarang begini.
--
-- Versi pertama membaca Humanoid dan HumanoidRootPart dengan `FindFirstChild`
-- lalu `return` kalau salah satunya nil. Itu salah: `CharacterAdded` menyala
-- saat Model karakter masuk Workspace, dan sebagian anaknya, termasuk
-- HumanoidRootPart, baru menyusul beberapa frame kemudian. Jadi fungsi ini
-- hampir selalu keluar lebih awal, karakternya TIDAK PERNAH masuk `entries`,
-- dan tidak ada satu pun error yang tercetak.
--
-- Gejalanya di layar: karakter sama sekali tidak beranimasi. Dan karena
-- StarterCharacterScripts/Animate sudah menggusur animasi bawaan Roblox,
-- yang hilang bukan cuma animasi buatan sendiri, yang hilang SEMUA animasi.
-- Diam total, tanpa satu baris pun di Output yang menunjukkan ada yang salah.
--
-- Pelajarannya ditulis di sini supaya tidak terulang: apa pun yang dibaca dari
-- karakter pada `CharacterAdded` harus DITUNGGU, bukan dibaca sekali.
local function track(character: Model)
	if entries[character] ~= nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	local rootInstance = character:WaitForChild("HumanoidRootPart", 10)

	-- Karakter bisa saja sudah dihapus selama penantian di atas (pemain keluar
	-- tepat saat spawn). Diperiksa lagi, bukan diasumsikan.
	if humanoid == nil or rootInstance == nil or not character:IsDescendantOf(game) then
		return
	end
	local root = rootInstance :: BasePart
	if not root:IsA("BasePart") then
		return
	end
	if entries[character] ~= nil then
		return
	end

	local entry: Entry = {
		character = character,
		humanoid = humanoid,
		root = root,
		joints = {},
		baseC0 = {},
		current = {},
		phase = 0,
		complete = false,
		attackT = 1,
		attackKind = "melee",
		landT = 1,
		landStrength = 0,
		wasGrounded = true,
		lastFallSpeed = 0,
		debugState = "-",
		debugAmp = 0,
		debugSpeed = 0,
		missing = {},
		reported = false,
		age = 0,
		debugStride = 0,
	}

	for _, name in Poses.JOINTS do
		entry.current[name] = { 0, 0, 0, 0, 0, 0 }
	end

	collectJoints(character, entry)
	entries[character] = entry

	-- Serangan diberitahukan server lewat atribut `AttackSeq` yang naik satu
	-- tiap serangan. Yang dipakai perubahannya, bukan nilainya: angka berapa
	-- pun tidak berarti apa-apa, yang berarti adalah bahwa dia berubah.
	--
	-- Jenis senjatanya dibaca SAAT ITU JUGA, bukan disimpan saat track(),
	-- karena pemain bisa berganti senjata tanpa respawn.
	character:GetAttributeChangedSignal("AttackSeq"):Connect(function()
		entry.attackT = 0
		local kind = character:GetAttribute("WeaponKind")
		entry.attackKind = if type(kind) == "string" then kind else "melee"
	end)

	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			entries[character] = nil
		end
	end)
end

local function hook(player: Player)
	player.CharacterAdded:Connect(track)
	player.CharacterRemoving:Connect(function(character: Model)
		entries[character] = nil
	end)
	-- `track` sekarang menunggu (WaitForChild), jadi panggilan langsung di sini
	-- akan menahan `start()` sampai sepuluh detik kalau pemain itu kebetulan
	-- sedang tanpa karakter, dan seluruh controller sesudahnya ikut tertunda.
	-- Handler `CharacterAdded` di atas aman karena event berjalan di thread
	-- sendiri; yang ini harus dibuatkan thread sendiri.
	local current = player.Character
	if current ~= nil then
		task.spawn(track, current)
	end
end

-- State disimpulkan dari properti yang tereplikasi saja (lihat catatan di
-- kepala file). Mengembalikan nama state dan amplitudo 0..1.
local function resolveState(entry: Entry): (string, number)
	local humanoid = entry.humanoid
	local velocity = entry.root.AssemblyLinearVelocity

	-- Dash menang atas segalanya, termasuk atas "sedang melayang". Dash memang
	-- sering dilakukan sambil melompat, dan pose jatuh yang menimpanya akan
	-- menghapus satu-satunya isyarat visual bahwa dash benar-benar terjadi,
	-- padahal dash berharga stamina dan pemain perlu melihat bahwa dia keluar.
	if entry.character:GetAttribute("Dashing") == true then
		return "dash", 1
	end

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if not grounded then
		-- Ambang 2 stud/detik, bukan nol: di puncak lompatan kecepatan
		-- vertikalnya melewati nol, dan dengan ambang nol karakternya akan
		-- berkedip sekali antara jump dan fall tepat di puncak.
		if velocity.Y > 2 then
			return "jump", 1
		end
		return "fall", 1
	end

	local planar = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local amp = math.clamp(planar / REFERENCE_SPEED, 0, 1)

	-- Jongkok dibaca dari ATRIBUT, bukan disimpulkan dari kecepatan. Pemain
	-- yang jongkok diam dan pemain yang berdiri diam sama-sama berkecepatan
	-- nol; yang membedakan keduanya cuma atribut yang ditulis server.
	if entry.character:GetAttribute("Stance") == "crouch" then
		-- Jongkok paling cepat 7 stud/detik. Diukur terhadap kecepatan sprint,
		-- amplitudonya cuma 0.28 dan langkahnya nyaris tak terlihat, jadi
		-- jongkok memakai acuannya sendiri.
		return "crouch", math.clamp(planar / MoveRules.SPEEDS.crouch, 0, 1)
	end

	if planar < IDLE_SPEED then
		return "idle", 0
	end

	return "run", amp
end

local function update(entry: Entry, dt: number)
	-- SENDI YANG BELUM LENGKAP TIDAK LAGI MENGHENTIKAN SEGALANYA.
	--
	-- Versi sebelumnya keluar dari fungsi ini kalau ada satu saja sendi yang
	-- belum ketemu. Niatnya baik, akibatnya buruk: satu nama sendi yang tidak
	-- cocok (rig R6, bagian tubuh yang belum sempat direplikasi, aksesori yang
	-- menyisipkan Motor6D bernama lain) membuat SELURUH karakter diam total,
	-- dan tidak ada apa pun di layar maupun di Output yang menjelaskannya.
	--
	-- Sekarang yang ketemu dianimasikan, yang belum ketemu dilewati, dan
	-- setelah masa tenggang ada satu baris di Output yang menyebut nama sendi
	-- yang hilang. Karakter dengan sebelas dari tiga belas sendi bergerak agak
	-- kaku; itu jauh lebih baik daripada patung yang tidak bisa dilacak.
	if not entry.complete then
		collectJoints(entry.character, entry)
	end

	entry.age += dt
	if not entry.reported and entry.age > 3 then
		entry.reported = true
		if entry.complete then
			print(
				string.format(
					"[CodeVerse] animasi aktif untuk %s (%d sendi)",
					entry.character.Name,
					#Poses.JOINTS
				)
			)
		else
			warn(
				string.format(
					"[CodeVerse] animasi %s berjalan tanpa %d sendi: %s. "
						.. "Kalau rig-nya R6, setel Game Settings > Avatar > Avatar Type ke R15.",
					entry.character.Name,
					#entry.missing,
					table.concat(entry.missing, ", ")
				)
			)
		end
	end

	-- Karakter yang sudah mati dilepas: biarkan Humanoid menjatuhkannya
	-- sendiri. Menahan pose hidup di atas karakter mati membuat mayatnya
	-- berdiri tegak sambil bernapas.
	if entry.humanoid.Health <= 0 then
		for name, joint in entry.joints do
			local base = entry.baseC0[name]
			if base ~= nil then
				joint.C0 = base
			end
		end
		return
	end

	local state, amp = resolveState(entry)

	local velocity = entry.root.AssemblyLinearVelocity
	local planar = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = entry.humanoid.FloorMaterial ~= Enum.Material.Air

	-- ------------------------------------------------------------- mendarat
	-- Kecepatan jatuh terakhir disimpan SELAMA melayang, bukan dibaca saat
	-- menyentuh lantai: pada frame pendaratan, kecepatan vertikalnya sudah
	-- dinolkan engine, jadi membacanya di situ selalu menghasilkan nol dan
	-- setiap pendaratan akan terasa sama ringannya.
	if not grounded then
		entry.lastFallSpeed = math.max(entry.lastFallSpeed, -velocity.Y)
	end
	if grounded and not entry.wasGrounded then
		entry.landT = 0
		entry.landStrength = math.clamp(entry.lastFallSpeed / HARD_LANDING_SPEED, 0.25, 1)
		entry.lastFallSpeed = 0
	end
	entry.wasGrounded = grounded

	-- -------------------------------------------------------- irama langkah
	--
	-- Irama DAN sudut ayun dihitung bersama dari kecepatan sungguhan, dan
	-- keduanya harus dipakai berpasangan, itu yang menjamin telapak kaki
	-- tidak menggeser di lantai. Lihat `Poses.gait`.
	local stride = 0
	local swing: number? = nil

	if state == "run" then
		stride, swing = Poses.gait(planar)
	elseif state == "crouch" then
		-- Jongkok melangkah pendek-pendek: sudut ayunnya dipangkas, dan irama
		-- disesuaikan ulang dari sudut yang sudah dipangkas itu supaya
		-- hubungan kecepatan-langkah tetap utuh.
		local _cadence, fullSwing = Poses.gait(planar)
		swing = fullSwing * 0.55
		local stepLength = 2 * Poses.LEG_LENGTH * math.sin(swing)
		stride = if stepLength > 0.05 then planar / (2 * stepLength) else 0
	elseif state == "idle" then
		-- Napas, bukan langkah: iramanya tetap dan lambat.
		stride = 0.22
	end
	entry.phase += dt * stride

	entry.debugState = state
	entry.debugAmp = amp
	entry.debugSpeed = planar
	entry.debugStride = stride
	-- Dibungkus supaya `phase` tidak tumbuh tanpa batas selama sesi panjang.
	-- Sinus memang tidak peduli, tapi presisi float berkurang pada angka
	-- besar dan lama-lama ayunannya jadi tersentak halus.
	if entry.phase > 1 then
		entry.phase -= math.floor(entry.phase)
	end

	local target = Poses.solve(state, entry.phase, amp, swing)

	-- Gerakan serangan ditimpakan DI ATAS pose yang sedang berjalan, dan hanya
	-- pada sendi yang dipakainya. `Poses.attack` mengembalikan tabel parsial,
	-- jadi kaki tetap melangkah sementara lengan mengayun, pemain bisa
	-- menembak sambil berlari tanpa larinya terputus.
	if entry.attackT < 1 then
		entry.attackT += dt / Poses.attackDuration(entry.attackKind)
		local overlay = Poses.attack(entry.attackKind, entry.attackT)
		for name, value in overlay do
			target[name] = value
		end
	end

	-- Pendaratan ditimpakan SETELAH serangan, jadi dia yang menang kalau
	-- keduanya terjadi bersamaan. Disengaja: pemain yang mendarat sambil
	-- menembak sedang menyerap benturan dengan seluruh badannya, dan lututnya
	-- harus menekuk, ayunan lengannya yang mengalah, bukan sebaliknya.
	if entry.landT < 1 then
		entry.landT += dt / Poses.LAND_DURATION
		local overlay = Poses.land(entry.landT, entry.landStrength)
		for name, value in overlay do
			local existing = target[name]
			if existing == nil then
				target[name] = value
			else
				-- Ditambahkan, bukan menimpa: kaki yang sedang melangkah harus
				-- tetap melangkah sambil menyerap pendaratan.
				local merged = table.clone(existing)
				for index = 1, 6 do
					merged[index] += value[index]
				end
				target[name] = merged
			end
		end
	end

	-- ---------------------------------------------------------- condong
	-- Hanya komponen MENYAMPING yang dipakai. Condong ke depan sudah ada di
	-- dalam pose lari itu sendiri (sebanding `amp`), dan menambahkannya lagi
	-- di sini akan membuat karakter tertunduk dua kali lipat saat sprint.
	if planar > 1 and target.Waist ~= nil then
		local right = entry.root.CFrame.RightVector
		local lateral = Vector3.new(velocity.X, 0, velocity.Z):Dot(right) / REFERENCE_SPEED
		local _pitch, roll = Poses.lean(0, lateral)
		local waist = table.clone(target.Waist)
		waist[3] += roll
		target.Waist = waist
	end

	local alpha = 1 - math.exp(-dt * BLEND_RATE)

	for _, name in Poses.JOINTS do
		local joint = entry.joints[name]
		local base = entry.baseC0[name]
		local goal = target[name]
		local now = entry.current[name]
		if joint ~= nil and base ~= nil and goal ~= nil and now ~= nil then
			for index = 1, 6 do
				now[index] += (goal[index] - now[index]) * alpha
			end
			joint.C0 = base
				* CFrame.new(now[4], now[5], now[6])
				* CFrame.Angles(now[1], now[2], now[3])
		end
	end
end

-- --------------------------------------------------------------------------
-- Panel diagnosis (F3)
-- --------------------------------------------------------------------------
--
-- Ada karena animasi prosedural punya satu sifat yang tidak enak: KEGAGALANNYA
-- SENYAP. Sendi yang tidak ketemu, karakter yang tidak terdaftar, atau state
-- yang nyangkut semuanya menghasilkan gejala yang sama persis di layar,
-- karakter yang tidak bergerak, dan tidak satu pun dari ketiganya mencetak
-- error. Panel ini yang membedakannya, dan membuat laporan "animasinya belum
-- jalan" bisa dijawab dengan angka alih-alih tebakan.
--
-- Dimatikan secara bawaan dan tidak memengaruhi apa pun selain dirinya
-- sendiri.
local debugGui: ScreenGui? = nil
local debugLabel: TextLabel? = nil

local function buildDebugPanel()
	local gui = UiKit.screenGui("AnimDebug", 50)
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = UiKit.panel(gui, "Panel", UDim2.fromOffset(12, 120), UDim2.fromOffset(330, 190))
	panel.BackgroundTransparency = 0.12

	local label = UiKit.label(panel, "Text", UDim2.fromOffset(10, 8), UDim2.fromOffset(310, 174), "")
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextYAlignment = Enum.TextYAlignment.Top

	debugGui = gui
	debugLabel = label
end

local function refreshDebug()
	local label = debugLabel
	local gui = debugGui
	if label == nil or gui == nil or not gui.Enabled then
		return
	end

	local lines = { string.format("karakter terlacak: %d", (function()
		local count = 0
		for _ in entries do
			count += 1
		end
		return count
	end)()) }

	for character, entry in entries do
		local found = 0
		for _, name in Poses.JOINTS do
			if entry.joints[name] ~= nil then
				found += 1
			end
		end
		table.insert(
			lines,
			string.format(
				"%s\n  sendi %d/%d  %s\n  state=%s amp=%.2f\n  laju=%.1f langkah=%.2f/s",
				character.Name,
				found,
				#Poses.JOINTS,
				if entry.complete then "LENGKAP" else "BELUM LENGKAP",
				entry.debugState,
				entry.debugAmp,
				entry.debugSpeed,
				entry.debugStride
			)
		)
	end

	label.Text = table.concat(lines, "\n")
end

function CharacterAnimatorController.start()
	if started then
		return
	end
	started = true

	local ok, err = Poses.validate()
	if not ok then
		warn(string.format("[CodeVerse] data pose tidak valid: %s", tostring(err)))
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	-- Penjaga terakhir: kalau setelah lima detik tidak ada SATU PUN karakter
	-- yang terlacak, laporan per-karakter di `update` tidak akan pernah
	-- tercetak, karena `update` memang tidak pernah dipanggil. Tanpa baris ini
	-- kegagalan paling parah justru yang paling sunyi.
	task.delay(5, function()
		local count = 0
		for _ in entries do
			count += 1
		end
		if count == 0 then
			warn(
				"[CodeVerse] animator tidak melacak satu pun karakter. "
					.. "Karakter akan terlihat kaku total. Periksa apakah "
					.. "Humanoid dan HumanoidRootPart benar-benar ada di karakter."
			)
		end
	end)

	buildDebugPanel()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F3 then
			local gui = debugGui
			if gui ~= nil then
				gui.Enabled = not gui.Enabled
			end
		end
	end)

	local debugAccumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		for _, entry in entries do
			update(entry, dt)
		end

		-- Panel disegarkan lima kali per detik, bukan tiap frame: angka yang
		-- berubah 60 kali per detik tidak bisa dibaca mata, dan menyusun
		-- stringnya tiap frame adalah satu-satunya bagian mahal dari panel ini.
		debugAccumulator += dt
		if debugAccumulator >= 0.2 then
			debugAccumulator = 0
			refreshDebug()
		end
	end)
end

return CharacterAnimatorController
