--!strict
-- CharacterService.luau: menjaga agar yang spawn adalah AVATAR ROBLOX MILIK
-- PEMAIN SENDIRI, dan agar di dalam karakter itu cuma ada satu penulis
-- animasi.
--
-- File ini dulunya memasang rancangan karakter "Teknisi IT": seragam, rompi,
-- visor, dan ransel yang dirakit dari Part, di atas badan yang warnanya
-- ditimpa per bagian tubuh. Rancangan itu dicabut pada 2026-10-26 atas
-- permintaan: avatar yang dipakai adalah milik akun pemain, apa adanya.
--
-- Menghapus rancangannya saja TIDAK mengembalikan avatar pemain, dan itu yang
-- membuat file ini masih ada. Tiga hal tersisa:
--
--   1. `StarterPlayer.LoadCharacterAppearance` harus kembali `true`.
--   2. Hanya boleh ada satu script `Animate` di dalam karakter.
--   3. Aksesori milik akun pemain tidak boleh menghentikan raycast bidikan.
--
-- Ketiganya dijelaskan di tempatnya masing-masing di bawah.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local CharacterService = {}

local started = false

-- (1) MENGEMBALIKAN TAMPILAN AKUN PEMAIN.
--
-- Saat karakter spawn, Roblox memuat tampilan akun pemain, yaitu badan,
-- warna kulit, baju, rambut, dan topi, hanya kalau
-- `StarterPlayer.LoadCharacterAppearance` bernilai `true`. Selama rancangan
-- "Teknisi IT" masih dipakai, properti itu sengaja disetel `false`: tanpa itu
-- seragam yang dipasang cuma jadi lapisan di atas rambut dan topi yang
-- berbeda-beda tiap orang.
--
-- Masalahnya, properti itu tinggal di PROPERTI PLACE, bukan di file mana pun
-- di repo ini. Jadi menghapus rancangan dari disk tidak menyentuhnya sama
-- sekali: place yang sudah terlanjur disetel akan tetap menelanjangi avatar
-- setiap pemain, dan tidak ada satu baris kode pun yang bisa ditunjuk sebagai
-- sebabnya saat dicari.
--
-- Baris di bawah yang menutup lubang itu, dan dia sengaja berjalan sekali di
-- `start()`, sebelum pemain pertama sempat spawn. `default.project.json` juga
-- menyetel properti yang sama, supaya place yang dibangun `rojo build` dari
-- nol sudah benar sejak spawn pertama; baris ini yang menolong place LAMA,
-- yang sudah terlanjur menyimpan `false` di dalam dirinya.
local function restoreAppearanceLoading()
	StarterPlayer.LoadCharacterAppearance = true
end

-- (2) MEMASTIKAN HANYA ADA SATU `Animate`.
--
-- Roblox menyisipkan LocalScript bernama `Animate` ke dalam setiap karakter
-- saat spawn, dan script itulah yang memutar klip idle/walk/run/jump bawaan.
-- Penyisipan itu dilewati kalau karakternya sudah punya anak bernama
-- `Animate`, dan `src/character/Animate.client.luau` yang kosong itulah yang
-- menempati tempatnya.
--
-- Kalau keduanya sampai ikut, Animator bawaan dan
-- `CharacterAnimatorController` menulis ke Motor6D yang sama setiap frame.
-- Gejalanya bukan salah satu menang, melainkan karakter yang BERGETAR, dan
-- getaran itu tidak muncul sebagai error di mana pun.
--
-- Pembedanya bukan nama, dua-duanya bernama `Animate`, melainkan ISI: script
-- bawaan Roblox membawa puluhan objek Animation sebagai anak, sementara milik
-- kita kosong melompong. Jadi yang punya anak, itulah yang bawaan.
local function removeDefaultAnimate(character: Model)
	for _, child in character:GetChildren() do
		if child.Name == "Animate" and #child:GetChildren() > 0 then
			child:Destroy()
		end
	end
end

-- (3) AKSESORI AKUN TIDAK IKUT MENGHALANGI BIDIKAN.
--
-- Bidikan pemain adalah raycast dari kamera (`InputController`), dan raycast
-- itu cuma mengecualikan karakter si penembak sendiri. Karakter pemain LAIN
-- tetap bisa menghentikannya, dan itu sudah berlaku sejak dulu untuk badan.
--
-- Yang berubah sejak avatar akun dipakai: aksesori ikut termuat, dan aksesori
-- Roblox bisa jauh lebih besar daripada badan yang memakainya, sayap, topi
-- lebar, atau rambut yang menjulur. Satu rekan setim dengan topi selebar dua
-- stud bisa menghentikan tembakan dari jarak yang pemiliknya sendiri tidak
-- sadari sedang dia halangi.
--
-- `CanQuery = false` mengeluarkan Part dari raycast tanpa menyentuh tampilan
-- maupun tabrakannya. Alasan yang sama dipakai untuk laras senjata di
-- `WeaponService`.
local function silenceAccessory(accessory: Accessory)
	local handle = accessory:FindFirstChild("Handle")
	if handle ~= nil and handle:IsA("BasePart") then
		handle.CanQuery = false
	end
end

-- Dipanggil juga untuk aksesori yang menyusul setelah karakter masuk
-- Workspace. `CharacterAdded` menyala saat Model-nya muncul, dan aksesori
-- akun sebagian baru menempel beberapa frame kemudian; memeriksa sekali saja
-- akan melewatkan justru yang paling besar.
local function hookCharacter(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			silenceAccessory(child)
		end
	end

	-- Koneksi ini tidak perlu diputus sendiri: karakter lama di-Destroy saat
	-- pemain respawn, dan Destroy memutus seluruh koneksi ke instance itu.
	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Accessory") then
			silenceAccessory(child)
		end
	end)

	removeDefaultAnimate(character)
end

function CharacterService.start()
	if started then
		return
	end
	started = true

	restoreAppearanceLoading()

	local function hook(player: Player)
		player.CharacterAdded:Connect(hookCharacter)
		-- Pemain yang karakternya sudah terlanjur spawn sebelum baris ini
		-- jalan (server reload saat ada orang di dalam) tetap kebagian.
		local current = player.Character
		if current ~= nil then
			task.spawn(hookCharacter, current)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return CharacterService
