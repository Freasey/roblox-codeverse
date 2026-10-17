--!strict
-- BossRules.luau — kapan ambang mekanik boss dianggap terlewati.
--
-- Kenapa modul sendiri untuk satu perbandingan angka: ambangnya dipicu oleh
-- damage, dan damage datang dalam potongan sebesar apa pun. Tiga hal yang
-- mudah salah dan semuanya cuma muncul di kasus pinggir:
--
--   1. Satu serangan besar bisa melewati DUA ambang sekaligus (HP 70% kena
--      damage yang menyisakan 20% melewati 0.66 dan 0.33). Implementasi yang
--      cuma memeriksa "fraksi sekarang di bawah ambang berikutnya" akan
--      memicu satu dan menelan yang lain, dan boss kehilangan satu fase
--      tanpa ada yang error.
--   2. Ambang yang sama tidak boleh dipicu dua kali. Boss yang HP-nya terus
--      diserang akan memanggil pemeriksaan ini tiap serangan, jadi tanpa
--      pembukuan "sudah dipicu", Splitter akan membelah setiap kali dipukul
--      di bawah 66%.
--   3. Boss yang mati (HP 0) harus memicu semua ambang yang belum terpicu,
--      bukan melewatkannya — kalau tidak, membunuh boss dengan satu serangan
--      dari 70% langsung ke 0 membuat mekaniknya tidak pernah jalan.
--
-- Modul murni: tanpa game:GetService, tanpa `script`.

local BossRules = {}

-- Ambang mana saja yang BARU terlewati pada fraksi HP ini.
--
-- `thresholds` adalah fraksi HP seperti di Bosses.luau ({ 0.66, 0.33 }).
-- `triggered` adalah pembukuan indeks yang sudah pernah dipicu; tabel ini
-- TIDAK diubah di sini, pemanggil yang mencatat hasilnya — supaya fungsi ini
-- tetap bisa dipanggil berkali-kali dengan input yang sama di unit test.
--
-- Mengembalikan daftar indeks (ke dalam `thresholds`), urut dari ambang
-- tertinggi ke terendah, jadi fase dijalankan dalam urutan yang benar kalau
-- dua-duanya terlewati sekaligus.
function BossRules.newlyCrossed(
	thresholds: { number },
	fraction: number,
	triggered: { [number]: boolean }
): { number }
	local crossed: { number } = {}

	-- NaN tidak boleh memicu apa pun: perbandingan apa pun dengannya false,
	-- jadi dibiarkan akan menghasilkan "tidak ada yang terlewati" secara
	-- kebetulan. Dikembalikan kosong secara eksplisit supaya niatnya jelas.
	if fraction ~= fraction then
		return crossed
	end

	-- Urutkan indeks dari ambang terbesar ke terkecil. Bosses.luau menulisnya
	-- sudah urut, tapi mengandalkan itu berarti mengubah urutan di data akan
	-- mengubah urutan fase tanpa ada yang menyadarinya.
	local order: { number } = {}
	for index = 1, #thresholds do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		if thresholds[a] == thresholds[b] then
			return a < b
		end
		return thresholds[a] > thresholds[b]
	end)

	for _, index in order do
		if not triggered[index] and fraction <= thresholds[index] then
			table.insert(crossed, index)
		end
	end

	return crossed
end

-- Fraksi HP yang aman dibandingkan: 0 kalau maxHp tidak masuk akal, dan
-- selalu di dalam [0, 1].
function BossRules.fraction(hp: number, maxHp: number): number
	if maxHp <= 0 or maxHp ~= maxHp then
		return 0
	end
	if hp ~= hp then
		return 0
	end
	return math.clamp(hp / maxHp, 0, 1)
end

return BossRules
