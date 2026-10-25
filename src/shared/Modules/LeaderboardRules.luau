--!strict
-- LeaderboardRules.luau — aturan papan wave tertinggi (M6, LB-01 sampai LB-05).
--
-- Papannya punya SATU aturan yang menentukan segalanya: catatan tidak pernah
-- turun. Match berikutnya yang berakhir di wave lebih rendah tidak menghapus
-- rekor sebelumnya (LB-03). Aturan itu hidup di `isRecord` dan dibaca dua
-- tempat yang berbeda sifatnya:
--
--   * `LeaderboardService` memakainya di dalam `UpdateAsync`, untuk memutuskan
--     apakah tulisan ke OrderedDataStore dibatalkan.
--   * `merge` memakainya untuk papan yang dipegang server di memori.
--
-- Keduanya harus setuju. Kalau tidak, papan di layar pemain bisa menunjukkan
-- angka yang lebih tinggi daripada yang benar-benar tersimpan — dan selisihnya
-- baru ketahuan setelah server restart, saat papannya "turun sendiri".
--
-- Modul murni: tanpa game:GetService, tanpa `script`, tanpa OrderedDataStore.
-- Yang menyentuh DataStore cuma LeaderboardService.

local Types = require("./Types")

local LeaderboardRules = {}

export type Entry = Types.LeaderboardEntry

-- Sepuluh baris. Bukan angka presentasi yang boleh beda di client: ini juga
-- jumlah yang diminta ke `GetSortedAsync`, jadi menaikkannya di satu sisi saja
-- membuat papan yang meminta 10 lalu menampilkan 20 baris kosong.
LeaderboardRules.MAX_ENTRIES = 10

-- Satu OrderedDataStore per tingkat kesulitan, bukan satu store dengan key
-- gabungan. Alasannya `GetSortedAsync` mengurutkan SELURUH store: kalau catatan
-- normal dan hard tinggal di store yang sama, papan "hard" harus membaca
-- seluruh catatan normal lebih dulu dan membuangnya satu per satu, dan sepuluh
-- teratas yang diminta bisa habis dipakai catatan tingkat yang salah (LB-02).
--
-- Versi di nama store ikut naik kalau artinya berubah. Store lama tidak bisa
-- dihapus, dan catatan yang artinya sudah berbeda lebih buruk daripada papan
-- kosong.
function LeaderboardRules.storeNameFor(difficultyId: string): string
	return string.format("HighestWave_v1_%s", difficultyId)
end

-- Id kesulitan dari client dipakai untuk MENYUSUN NAMA STORE, jadi dia tidak
-- boleh lewat tanpa diperiksa: tanpa gerbang ini satu client bisa membuat
-- store baru untuk tiap string yang dia kirim, dan kuota OrderedDataStore
-- dihitung per universe, bukan per store.
--
-- Fungsi yang sama dipakai saat MENULIS catatan. Jadi tingkat yang tidak ada
-- di `difficulties` tidak bisa masuk lewat jalur mana pun.
function LeaderboardRules.normalizeDifficulty(
	value: unknown,
	difficulties: { [string]: Types.DifficultyDef }
): string?
	if type(value) ~= "string" then
		return nil
	end
	if difficulties[value] == nil then
		return nil
	end
	return value
end

-- Apakah `candidate` layak menggantikan `previous`. `previous` nil berarti
-- pemain itu belum punya catatan sama sekali di tingkat ini.
--
-- Wave 0 dan angka negatif ditolak, bukan disimpan sebagai 0: match yang
-- dibatalkan (semua peserta keluar) tidak menembakkan `onMatchEnded`, tapi
-- jalur lain bisa saja memanggil fungsi ini dengan wave yang belum mulai, dan
-- baris "wave 0" di papan tidak berarti apa-apa untuk siapa pun.
function LeaderboardRules.isRecord(previous: number?, candidate: number): boolean
	-- NaN gagal SEMUA perbandingan, termasuk `< 1`, jadi dia harus dibuang
	-- lewat perbandingan dengan dirinya sendiri. Tanpa baris ini NaN lolos ke
	-- OrderedDataStore, dan di sana dia jadi error tulis, bukan nilai aneh.
	if candidate ~= candidate then
		return false
	end
	local wave = math.floor(candidate)
	if wave < 1 then
		return false
	end
	return wave > (previous or 0)
end

-- Urutan tampil: wave terbesar di atas, dan `userId` kecil lebih dulu saat
-- wave-nya sama.
--
-- Pemecah seri itu bukan hiasan. Tanpa dia, dua pemain dengan wave yang sama
-- bisa bertukar baris tiap kali papan di-refresh, karena urutan yang
-- dikembalikan `GetSortedAsync` untuk nilai yang sama tidak dijanjikan stabil.
-- Papan yang barisnya meloncat-loncat sendiri terbaca seperti bug.
local function compare(a: Entry, b: Entry): boolean
	if a.wave ~= b.wave then
		return a.wave > b.wave
	end
	return a.userId < b.userId
end

-- Mengembalikan daftar BARU yang terurut dan dipotong. Daftar masukan tidak
-- disentuh: pemanggilnya menyimpan daftar lama sebagai papan yang sedang
-- tampil, dan mengurutkan di tempat berarti papan itu berubah di tengah
-- perhitungan yang belum tentu dipakai.
function LeaderboardRules.rank(entries: { Entry }, maxEntries: number?): { Entry }
	local limit = maxEntries or LeaderboardRules.MAX_ENTRIES
	local sorted = table.clone(entries)
	table.sort(sorted, compare)
	if #sorted <= limit then
		return sorted
	end
	local trimmed: { Entry } = {}
	for index = 1, limit do
		trimmed[index] = sorted[index]
	end
	return trimmed
end

-- Masukkan satu catatan baru ke papan yang sudah ada, lalu urutkan dan potong.
--
-- Ini yang membuat papan ikut terupdate tanpa restart server (LB-04). Papan
-- TIDAK dibaca ulang dari OrderedDataStore tiap kali ada rekor baru:
-- `GetSortedAsync` punya kuota sendiri, dan match yang selesai dengan empat
-- pemain akan memanggilnya empat kali beruntun untuk hasil yang sudah
-- diketahui.
--
-- Nama ikut diperbarui saat pemain yang sama sudah ada di papan: pemain bisa
-- ganti username, dan baris yang tertulis dengan nama lama akan terlihat
-- seperti orang lain yang kebetulan punya rekor sama.
function LeaderboardRules.merge(
	entries: { Entry },
	userId: number,
	name: string,
	wave: number,
	maxEntries: number?
): { Entry }
	local merged: { Entry } = {}
	local found = false

	for _, entry in entries do
		if entry.userId == userId then
			found = true
			-- Aturan yang sama dengan yang dipakai `UpdateAsync`: catatan tidak
			-- pernah turun, bahkan di papan memori.
			if LeaderboardRules.isRecord(entry.wave, wave) then
				table.insert(merged, { userId = userId, name = name, wave = math.floor(wave) })
			else
				table.insert(merged, { userId = userId, name = name, wave = entry.wave })
			end
		else
			table.insert(merged, entry)
		end
	end

	if not found and LeaderboardRules.isRecord(nil, wave) then
		table.insert(merged, { userId = userId, name = name, wave = math.floor(wave) })
	end

	return LeaderboardRules.rank(merged, maxEntries)
end

return LeaderboardRules
