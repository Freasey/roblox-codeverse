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
