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
		for id in defs do
			owned[id] = { level = 1 }
		end
	end

	-- Tabel BARU, bukan `data.weapons` yang di-mutasi: pemanggil mana pun yang
	-- menulis ke hasil fungsi ini tidak boleh bisa menyentuh data pemain.
	for id, save in data.weapons do
		if defs[id] ~= nil then
			owned[id] = { level = save.level }
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

-- Upgrade: dimiliki, belum max, koin cukup (bagian 3.6).
function ProgressionRules.canUpgrade(
	def: Types.WeaponDef?,
	context: Context,
	price: number
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
	if context.data.coins < price then
		return false,
			string.format("Koin kurang: butuh %d, ada %d.", price, math.floor(context.data.coins))
	end

	return true, nil
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
