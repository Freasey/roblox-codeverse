--!strict
-- MatchUpgradeRules.luau — syarat upgrade senjata DI DALAM match, dibayar cash.
--
-- Upgrade senjata pindah dari lobby ke dalam match: yang ditawarkan tiap jeda
-- antar wave bukan lagi lima item tim, melainkan upgrade senjata pemain itu
-- sendiri beserta ketiga alurnya. Yang dibayar cash, dan cash habis tiap match
-- selesai -- jadi level dan alur juga dimulai ulang dari 1 tiap match.
--
-- Itu bukan efek samping, itu intinya: alur yang terkunci selamanya cuma
-- pernah dialami sekali per senjata, sementara alur yang dipilih ulang tiap
-- match adalah keputusan yang diambil berkali-kali dengan keadaan yang
-- berbeda-beda. Yang pertama progres, yang kedua gameplay.
--
-- Modul ini TIDAK menduplikasi satu pun aturan alur. Kapan pilihan ditagih,
-- alur mana yang sah, dan alur mana yang tersimpan semuanya dibaca dari
-- `ProgressionRules` -- fungsi yang sama yang dulu dipakai upgrade lobby.
-- Kalau aturannya disalin ke sini, dua salinan itu akan bergeser pelan-pelan
-- dan gejalanya panel yang menawarkan alur di level yang ditolak server.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local Balance = require("./Balance")
local DataSchema = require("./DataSchema")
local ProgressionRules = require("./ProgressionRules")
local Types = require("./Types")

local MatchUpgradeRules = {}

-- Satu-satunya state yang membuka toko upgrade. Sama dengan `ShopRules.OPEN_STATE`,
-- dan unit test yang menjaga keduanya tetap sama: client memakai SATU aturan
-- untuk memutuskan panel toko terlihat atau tidak, jadi dua nilai yang berbeda
-- berarti panel yang terbuka dengan seluruh tombolnya ditolak server.
MatchUpgradeRules.OPEN_STATE = "Intermission"

-- Senjata yang baru dibawa masuk match: level 1, belum memilih alur.
--
-- Fungsi, bukan konstanta tabel: tabel yang sama dikembalikan ke banyak
-- pemanggil akan dibagikan referensinya, dan satu pemanggil yang menaikkan
-- level akan menaikkannya untuk semua orang sekaligus.
function MatchUpgradeRules.freshSave(): Types.WeaponSave
	return { level = 1, path = DataSchema.NO_PATH }
end

-- Harga naik satu level dari `save`. `math.huge` kalau sudah maksimum, supaya
-- pemanggil yang lupa memeriksa level maksimum tetap gagal di gerbang cash
-- alih-alih diam-diam memberi upgrade gratis.
function MatchUpgradeRules.priceFor(def: Types.WeaponDef, save: Types.WeaponSave): number
	if save.level >= def.maxLevel then
		return math.huge
	end
	return Balance.matchUpgradePrice(save.level)
end

export type Context = {
	state: string,
	cash: number,
	-- Toko dikunci mekanik boss Locker. Dipisah dari "bukan Intermission"
	-- karena pesannya memang beda, dan pemain perlu tahu bedanya.
	locked: boolean,
}

-- Mengembalikan (boleh, alasan kalau tidak boleh). Alasannya sampai ke layar
-- lewat `ActionResult`, jadi dia harus menyebut apa yang kurang -- penolakan
-- tanpa alasan terlihat persis seperti tombol yang rusak.
--
-- Urutan pemeriksaannya menentukan pesan mana yang pemain lihat saat lebih
-- dari satu syarat gagal, dan urutan ini dipilih dari yang paling tidak bisa
-- dia ubah ke yang paling bisa:
--
--   kunci boss -> state -> senjata ada -> level maksimum -> alur -> cash
--
-- Kunci boss sebelum state, dengan alasan yang sama seperti di `ShopRules`.
-- Cash PALING AKHIR: "cash kurang" adalah satu-satunya alasan yang bisa
-- dibereskan pemain dengan bermain, jadi menampilkannya saat yang sebenarnya
-- salah adalah level maksimum akan membuat dia menabung untuk sesuatu yang
-- tidak akan pernah bisa dibeli.
function MatchUpgradeRules.canUpgrade(
	def: Types.WeaponDef?,
	save: Types.WeaponSave,
	context: Context,
	pathId: string?
): (boolean, string?)
	if context.locked then
		return false, "Toko dikunci. Kalahkan boss-nya dulu."
	end
	if context.state ~= MatchUpgradeRules.OPEN_STATE then
		return false, "Upgrade cuma bisa saat jeda antar wave."
	end
	if def == nil then
		return false, "Senjata itu tidak ada."
	end
	if save.level >= def.maxLevel then
		return false, string.format("%s sudah level maksimum.", def.name)
	end

	-- Aturan alur dibaca dari ProgressionRules, bukan ditulis ulang di sini.
	local asked = if pathId ~= nil and pathId ~= DataSchema.NO_PATH then pathId else nil
	if ProgressionRules.pathChoiceRequired(save) then
		if asked == nil then
			return false,
				string.format(
					"Level %d %s mengunci satu dari %d alur sampai match selesai. Pilih dulu.",
					Balance.PATH_BRANCH_LEVEL,
					def.name,
					#def.paths
				)
		end
		if ProgressionRules.findPath(def, asked) == nil then
			return false, string.format("%s tidak punya alur itu.", def.name)
		end
	elseif asked ~= nil and save.path ~= DataSchema.NO_PATH and asked ~= save.path then
		local chosen = ProgressionRules.findPath(def, save.path)
		return false,
			string.format(
				"%s sudah di alur %s sampai match ini selesai.",
				def.name,
				if chosen ~= nil then chosen.name else save.path
			)
	end

	local price = MatchUpgradeRules.priceFor(def, save)
	if context.cash < price then
		return false,
			string.format("Cash kurang: butuh %d, ada %d.", price, math.floor(context.cash))
	end

	return true, nil
end

-- Save sesudah satu upgrade diterima. Mengembalikan tabel BARU: yang lama
-- dipegang pemanggil sebagai keadaan sebelum pembelian, dan mengubahnya di
-- tempat berarti penolakan yang terjadi sesudahnya tidak bisa dibatalkan.
--
-- `pathToApply` yang memutuskan alurnya tersimpan atau tidak, dan itu fungsi
-- yang sama yang dipakai upgrade lobby: alur TIDAK boleh tersimpan sebelum
-- titik percabangan, kalau tidak client bisa mengunci alur di upgrade pertama
-- dan masa percobaan level 1 sampai 3 hilang tanpa jejak.
function MatchUpgradeRules.applyUpgrade(
	def: Types.WeaponDef,
	save: Types.WeaponSave,
	pathId: string?
): Types.WeaponSave
	local applied = ProgressionRules.pathToApply(def, save, pathId)
	return {
		level = math.min(save.level + 1, def.maxLevel),
		path = applied or save.path,
	}
end

return MatchUpgradeRules
