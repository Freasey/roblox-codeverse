--!strict
-- ProgressionRules.luau — syarat upgrade, beli, dan craft senjata.
--
-- Kenapa dipisah dari ProgressionService: tabel bagian 3.6 memberi tiga remote
-- (`UpgradeWeapon`, `BuyWeapon`, `CraftWeapon`) yang masing-masing punya daftar
-- syarat, dan kriteria penerimaan M5 adalah pemain bisa "upgrade senjata, craft
-- senjata boss, membuka Hard, keluar, join lagi, dan semua progres masih ada".
-- Syarat-syarat itu menyentuh data permanen pemain — yang paling mahal kalau
-- salah, karena kesalahannya tersimpan. Jadi logikanya ditaruh di modul murni
-- dan dites, bukan diperiksa dengan mencoba-coba di Studio.
--
-- Semua fungsi di sini MEMBACA data dan tidak mengubah apa pun. Yang mengubah
-- adalah ProgressionService lewat PlayerDataService.update.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

-- Balance dan DataSchema di-require di sini, dan arahnya disengaja: keduanya
-- modul murni yang cuma bergantung ke Types, jadi tidak ada lingkaran. Yang
-- diambil dari sana satu angka dan satu string -- `PATH_BRANCH_LEVEL` dan
-- `NO_PATH` -- dan menyalinnya ke sini sebagai literal berarti dua tempat yang
-- bisa bergeser diam-diam: titik percabangan yang digeser di Balance tapi tidak
-- di sini menghasilkan aturan yang menagih pilihan alur di level yang salah.
local Balance = require("./Balance")
local DataSchema = require("./DataSchema")
local Types = require("./Types")

local ProgressionRules = {}

-- Nama state yang membolehkan perubahan progres permanen. String, bukan tipe
-- State milik MatchService: modul ini harus tetap bisa di-require Lune.
--
-- Kenapa hanya Lobby (bagian 3.6): upgrade di tengah wave berarti damage
-- berubah di tengah pertarungan, dan beli senjata di tengah match berarti
-- pemain bisa mengganti loadout setelah melihat musuh apa yang datang.
ProgressionRules.ALLOWED_STATE = "Lobby"

export type Context = {
	state: string,
	data: Types.PlayerData,
}

-- --------------------------------------------------------------------------
-- Kepemilikan senjata: satu pintu untuk MEMAKAI
-- --------------------------------------------------------------------------

-- Senjata yang boleh DIPAKAI pemain, sebagai { [weaponId] = WeaponSave }.
--
-- Kenapa fungsi, bukan `data.weapons` langsung: ada DUA tempat di server yang
-- memeriksa kepemilikan sebelum senjata dipakai, dan keduanya gagal dengan cara
-- yang berbeda --
--
--   `MatchService.onSelectLoadout`  -> menolak, membalas ActionResult
--   `CombatService.resolveWeapon`   -> DIAM-DIAM jatuh ke starter
--
-- Kalau cuma yang pertama mengenal flag dev, pemain bisa memilih Packet Rifle
-- lalu mengayunkan Patch Wrench tanpa satu pesan error pun: pilihannya diterima,
-- tombolnya berubah, damage-nya tidak. Bug seperti itu tidak pernah dilaporkan
-- karena tidak ada yang kelihatan rusak. Jadi dua-duanya memanggil fungsi ini,
-- dan flag dev cuma punya satu tempat untuk berlaku.
--
-- `devAllWeapons` dikirim sebagai argumen, bukan dibaca dari Config di dalam
-- modul ini: modul ini harus tetap bisa di-require Lune, dan test harus bisa
-- menguji kedua keadaan flag tanpa menyentuh konstanta global. Pola yang sama
-- dengan `priceGrowth` di `ShopRules`.
--
-- Level senjata yang BENAR-BENAR dimiliki selalu menang atas level 1 yang
-- diberikan flag: menyetel flag tidak boleh menurunkan senjata yang sudah
-- di-upgrade pemain jadi level 1.
function ProgressionRules.ownedWeapons(
	data: Types.PlayerData,
	defs: { [string]: Types.WeaponDef },
	devAllWeapons: boolean
): { [string]: Types.WeaponSave }
	local owned: { [string]: Types.WeaponSave } = {}

	if devAllWeapons then
		-- Alur `"none"`, bukan alur pertama senjata itu: flag dev memberi akses,
		-- bukan progres. Senjata pinjaman yang datang dengan alur sudah terpilih
		-- akan membuat pemain mengukur senjata yang bukan senjata yang akan dia
		-- punya kalau dia membelinya.
		for id in defs do
			owned[id] = { level = 1, path = DataSchema.NO_PATH }
		end
	end

	-- Tabel BARU, bukan `data.weapons` yang di-mutasi: pemanggil mana pun yang
	-- menulis ke hasil fungsi ini tidak boleh bisa menyentuh data pemain.
	--
	-- `save.path` dinormalkan di sini, dan di sini SAJA. Tipenya non-optional
	-- karena `DataSchema.migrate` menjaminnya untuk setiap save yang pernah
	-- dimuat server atau client; yang tidak lewat migrate cuma tabel yang
	-- dibuat tangan (fixture test, data yang diedit dari command bar). Satu
	-- normalisasi di pintu yang sudah dilewati semua pembaca jauh lebih murah
	-- daripada melonggarkan tipenya jadi `string?` dan memaksa setiap pembaca
	-- menangani nil untuk keadaan yang tidak pernah terjadi di jalur sungguhan.
	for id, save in data.weapons do
		if defs[id] ~= nil then
			owned[id] = { level = save.level, path = save.path or DataSchema.NO_PATH }
		end
	end

	return owned
end

-- Senjata yang sedang dipakai, dan levelnya. Satu-satunya jalan yang boleh
-- dipakai saat MENGHITUNG DAMAGE.
--
-- Jatuh ke starter kalau `equippedWeapon` tidak dimiliki atau tidak ada di
-- `defs`. Jatuhnya memang diam-diam, dan itu disengaja: ini dipanggil tiap
-- serangan, jadi tidak ada tempat untuk melapor, dan senjata yang hilang dari
-- data tidak boleh membuat serangan pemain berhenti sama sekali. Gerbang yang
-- BERBICARA ada di `onSelectLoadout`, yang memakai `ownedWeapons` yang sama --
-- jadi pilihan yang diterima di sana tidak akan pernah jatuh di sini.
--
-- Levelnya di-clamp ke `[1, maxLevel]`: save lama dari skema sebelumnya, atau
-- data yang diedit tangan, tidak boleh memberi stat di luar kurva.
function ProgressionRules.equippedWeapon(
	data: Types.PlayerData,
	defs: { [string]: Types.WeaponDef },
	devAllWeapons: boolean
): (Types.WeaponDef, number)
	local owned = ProgressionRules.ownedWeapons(data, defs, devAllWeapons)
	local starter = defs.weapon_starter

	local def = defs[data.equippedWeapon]
	local save = owned[data.equippedWeapon]
	if def == nil or save == nil then
		if starter == nil then
			-- Tidak bisa terjadi dengan Weapons.luau yang ada sekarang, tapi
			-- mengembalikan nil dari fungsi bertipe non-nil akan error di
			-- pemanggil, jauh dari penyebabnya.
			error("ProgressionRules.equippedWeapon: weapon_starter tidak ada di defs")
		end
		local starterSave = owned.weapon_starter
		return starter,
			math.clamp(if starterSave ~= nil then starterSave.level else 1, 1, starter.maxLevel)
	end

	return def, math.clamp(save.level, 1, def.maxLevel)
end

-- Tiga fungsi di bawah SENGAJA memeriksa `context.data.weapons` langsung, bukan
-- `ownedWeapons` di atas.
--
-- Mereka mengubah data permanen, dan flag dev tidak boleh menyentuh jalur itu.
-- Lewat `ownedWeapons`, `canBuy` akan menjawab "sudah kamu miliki" untuk semua
-- senjata selama flag hidup, dan `canUpgrade` akan membolehkan pemain membayar
-- koin sungguhan untuk menaikkan level senjata yang tidak dia miliki -- yang
-- berarti `data.weapons[id] = { level = 2 }` masuk DataStore. Itu persis
-- kerusakan permanen yang membuat flag ini harus hidup di memori saja.
--
-- Jadi batasnya: `ownedWeapons` untuk MEMAKAI, `data.weapons` untuk MEMBELI,
-- CRAFT, dan UPGRADE.

-- --------------------------------------------------------------------------
-- Alur upgrade: tiga cabang, dipilih sekali, permanen
-- --------------------------------------------------------------------------

-- Alur dengan id ini, atau nil.
function ProgressionRules.findPath(def: Types.WeaponDef, pathId: string): Types.WeaponPathDef?
	for _, path in def.paths do
		if path.id == pathId then
			return path
		end
	end
	return nil
end

-- Apakah upgrade BERIKUTNYA dari senjata ini harus menyertakan pilihan alur.
--
-- Syaratnya dua: pemain belum pernah memilih, DAN level sesudah upgrade sudah
-- mencapai titik percabangan.
--
-- Perhatikan `>=`, bukan `==`. Normalnya ini cuma pernah benar tepat saat naik
-- dari 3 ke 4, karena level naik satu-satu dan pilihannya tersimpan begitu
-- diterima. Tapi `>=` juga memperbaiki data yang entah bagaimana sudah lewat
-- level 4 dengan `path` masih "none" -- save dari sebelum fitur ini ada, atau
-- data yang diedit tangan. Dengan `==`, pemain seperti itu terjebak: dia tidak
-- akan pernah ditagih memilih, jadi senjatanya berjalan tanpa alur sampai level
-- 10 dan tidak ada satu pun pesan yang memberitahunya.
--
-- Dipakai dua pihak: server untuk menolak upgrade tanpa `pathId`, dan client
-- untuk tahu kapan panel pemilihan alur harus muncul. Satu fungsi, supaya
-- panelnya tidak bisa muncul di level yang berbeda dari level yang menagihnya.
-- Tidak menerima `def`, walau pemanggilnya hampir selalu punya satu: titik
-- percabangannya satu angka untuk semua senjata (`Balance.PATH_BRANCH_LEVEL`),
-- dan menerima `def` yang tidak dibaca berarti berpura-pura bisa berbeda per
-- senjata.
function ProgressionRules.pathChoiceRequired(save: Types.WeaponSave): boolean
	if save.path ~= DataSchema.NO_PATH then
		return false
	end
	return save.level + 1 >= Balance.PATH_BRANCH_LEVEL
end

-- Upgrade: dimiliki, belum max, koin cukup (bagian 3.6), dan -- sejak alur
-- upgrade ada -- pilihan alur yang sah di titik percabangan.
--
-- `pathId` diabaikan di level yang bukan titik percabangan: mengirimnya di
-- level 6 tidak menggeser apa pun, dan itu lebih baik daripada menolak, karena
-- client yang mengirimnya terus-menerus bukan client yang menyerang -- cuma
-- client yang tidak melacak level.
--
-- Fungsi ini satu-satunya tempat yang menegakkan "tidak bisa balik".
function ProgressionRules.canUpgrade(
	def: Types.WeaponDef?,
	context: Context,
	price: number,
	pathId: string?
): (boolean, string?)
	if context.state ~= ProgressionRules.ALLOWED_STATE then
		return false, "Upgrade cuma bisa di lobby."
	end
	if def == nil then
		return false, "Senjata itu tidak ada."
	end

	local save = context.data.weapons[def.id]
	if save == nil then
		return false, "Senjata itu belum kamu miliki."
	end
	if save.level >= def.maxLevel then
		return false, string.format("%s sudah level maksimum (%d).", def.name, def.maxLevel)
	end

	-- Alur diperiksa SEBELUM koin. Urutannya penting untuk pesan yang masuk
	-- akal: pemain yang belum memilih alur dan koinnya juga kurang harus
	-- diberitahu soal pilihan alurnya, karena itu yang perlu dia putuskan dulu.
	-- Dibalik, dia menabung sampai cukup lalu baru tahu ada pilihan permanen
	-- yang menunggunya.
	local asked = if pathId ~= nil and pathId ~= DataSchema.NO_PATH then pathId else nil

	if ProgressionRules.pathChoiceRequired(save) then
		if asked == nil then
			return false,
				string.format(
					"Level %d %s mengunci satu dari %d alur upgrade selamanya. Pilih dulu.",
					Balance.PATH_BRANCH_LEVEL,
					def.name,
					#def.paths
				)
		end
		if ProgressionRules.findPath(def, asked) == nil then
			return false, string.format("%s tidak punya alur itu.", def.name)
		end
	elseif asked ~= nil and save.path ~= DataSchema.NO_PATH and asked ~= save.path then
		-- Pemain yang mencoba ganti alur. Ditolak dengan menyebut alur yang
		-- sudah terpilih, bukan dengan kalimat umum: dia sedang menguji apakah
		-- "permanen" benar-benar permanen, dan jawabannya harus menyebut apa
		-- yang dia punya sekarang.
		local chosen = ProgressionRules.findPath(def, save.path)
		return false,
			string.format(
				"%s sudah di alur %s, dan itu tidak bisa diganti.",
				def.name,
				if chosen ~= nil then chosen.name else save.path
			)
	end
	-- Sisa kasusnya: `asked` dikirim di level 1 sampai 3, sebelum titik
	-- percabangan. Diabaikan, tidak ditolak, dan `pathToApply` yang memastikan
	-- dia juga tidak tersimpan -- level 1 sampai 3 itu masa percobaan, dan
	-- membiarkan client mengunci alur di situ membuang seluruh gunanya.

	if context.data.coins < price then
		return false,
			string.format("Koin kurang: butuh %d, ada %d.", price, math.floor(context.data.coins))
	end

	return true, nil
end

-- Alur yang harus DITULIS ke save oleh upgrade ini, atau nil kalau upgrade ini
-- tidak mengubah alur.
--
-- Dipisah dari `canUpgrade` supaya ProgressionService tidak perlu mengulang
-- percabangannya sendiri untuk memutuskan apakah `entry.path` disentuh.
-- Mengulangnya di sana berarti dua tempat yang harus setuju soal kapan alur
-- tersimpan, dan yang satu bisa menulis alur untuk upgrade yang `canUpgrade`
-- terima tanpa pilihan.
function ProgressionRules.pathToApply(
	def: Types.WeaponDef,
	save: Types.WeaponSave,
	pathId: string?
): string?
	if pathId == nil or pathId == DataSchema.NO_PATH then
		return nil
	end
	-- Syarat yang sama dengan yang menagih pilihannya. Tanpa baris ini, client
	-- bisa mengunci alur di level 1 dengan mengirim `pathId` pada upgrade
	-- pertama -- `canUpgrade` mengabaikannya di situ, jadi tidak ada yang
	-- menolaknya, dan masa percobaan level 1 sampai 3 hilang tanpa jejak.
	if not ProgressionRules.pathChoiceRequired(save) then
		return nil
	end
	if ProgressionRules.findPath(def, pathId) == nil then
		return nil
	end
	return pathId
end

-- Beli: belum dimiliki, bisa dibeli, koin cukup (bagian 3.6).
function ProgressionRules.canBuy(def: Types.WeaponDef?, context: Context): (boolean, string?)
	if context.state ~= ProgressionRules.ALLOWED_STATE then
		return false, "Beli senjata cuma bisa di lobby."
	end
	if def == nil then
		return false, "Senjata itu tidak ada."
	end
	if context.data.weapons[def.id] ~= nil then
		return false, string.format("%s sudah kamu miliki.", def.name)
	end
	if def.acquire.method ~= "buy" then
		return false, string.format("%s tidak dijual dengan koin.", def.name)
	end

	local cost = def.acquire.coinCost
	if cost == nil or cost <= 0 then
		-- Data yang tidak lengkap: senjata bermetode `buy` tanpa harga akan
		-- jadi senjata gratis kalau dibiarkan lolos.
		return false, "Harga senjata itu belum diatur."
	end
	if context.data.coins < cost then
		return false,
			string.format("Koin kurang: butuh %d, ada %d.", cost, math.floor(context.data.coins))
	end

	return true, nil
end

-- Craft: belum dimiliki, material cukup (bagian 3.6).
function ProgressionRules.canCraft(def: Types.WeaponDef?, context: Context): (boolean, string?)
	if context.state ~= ProgressionRules.ALLOWED_STATE then
		return false, "Craft cuma bisa di lobby."
	end
	if def == nil then
		return false, "Senjata itu tidak ada."
	end
	if context.data.weapons[def.id] ~= nil then
		return false, string.format("%s sudah kamu miliki.", def.name)
	end
	if def.acquire.method ~= "craft" then
		return false, string.format("%s tidak dibuat dengan material.", def.name)
	end

	local needed = def.acquire.materials
	if needed == nil or next(needed) == nil then
		return false, "Bahan senjata itu belum diatur."
	end

	for materialId, amount in needed do
		local owned = context.data.materials[materialId] or 0
		if owned < amount then
			return false,
				string.format("Material kurang: %s %d dari %d.", materialId, owned, amount)
		end
	end

	return true, nil
end

-- Kesulitan yang terbuka oleh `clears` pemain. Dipakai RewardService: first
-- clear `normal` membuka `hard` (bagian 3.1 dan M5).
--
-- Mengembalikan daftar id yang BARU terbuka, supaya pemanggil bisa
-- memberitahukannya di layar hasil tanpa membandingkan dua tabel sendiri.
function ProgressionRules.newlyUnlockedDifficulties(
	data: Types.PlayerData,
	defs: { [string]: Types.DifficultyDef }
): { string }
	local unlocked: { string } = {}

	for id, def in defs do
		if data.unlockedDifficulties[id] == true then
			continue
		end
		if def.unlockedByDefault then
			table.insert(unlocked, id)
			continue
		end
		local requires = def.unlockedBy
		if requires ~= nil and data.clears[requires] == true then
			table.insert(unlocked, id)
		end
	end

	-- Urut supaya hasilnya deterministik: urutan iterasi tabel Luau tidak
	-- dijamin, dan daftar ini masuk ke payload MatchResult yang dilihat pemain.
	table.sort(unlocked)
	return unlocked
end

return ProgressionRules
