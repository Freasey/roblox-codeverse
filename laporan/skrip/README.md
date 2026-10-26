# Cara membangun ulang laporan

Laporan `.docx` di folder atas **dihasilkan oleh dua skrip ini**, bukan diketik
tangan. Jadi untuk memasang screenshot, jangan sunting dokumennya: timpa file
gambarnya, lalu jalankan ulang. Isi, tata letak, dan nomor gambar menyesuaikan
sendiri.

## Sekali saja, di awal

```bash
cd "C:\Web Program\roblox-codeverse\laporan\skrip"
npm install docx
```

Python butuh Pillow, yang sudah terpasang di Python 3.7 pada mesin ini.

## Tiap kali ada screenshot baru

1. Simpan potret ke `laporan/img/` dengan nama persis seperti di
   [../DAFTAR-SCREENSHOT.md](../DAFTAR-SCREENSHOT.md).
2. Jalankan:

```bash
cd "C:\Web Program\roblox-codeverse\laporan\skrip"
python diagrams.py
node laporan.js
```

`diagrams.py` menggambar ulang kelima diagram **dan** membuat kotak penanda
untuk screenshot yang belum ada. Dia **tidak pernah menimpa file screenshot
yang sudah terpasang** — kalau filenya sudah ada, dia melewatinya dan berkata
begitu di output. Jadi aman dijalankan berkali-kali.

`laporan.js` menyusun ulang `Laporan-Tugas-CodeVerse.docx`.

## Isi kedua skrip

**`diagrams.py`** menghasilkan lima diagram. Angkanya tidak ditebak — geometri
arena dibaca dari konstanta yang sama dengan `scripts/build_arena.luau`
(lantai 240x240 stud, 7 waypoint per lane berjarak 20 stud, waypoint terakhir
24 stud dari Core), dan nama state diambil dari `MatchService.luau`. Kalau
arena atau state machine berubah, angka di skrip ini ikut diperbarui supaya
diagramnya tidak berbohong.

Satu aturan yang dipegang di sini: **data padat tidak digambar ke dalam
gambar.** Tabel pemetaan animasi, daftar durasi state, keterangan arena, dan
keempat elemen gamifikasi semuanya hidup sebagai tabel Word di `laporan.js`,
bukan sebagai piksel. Alasannya sederhana — teks di dalam PNG ikut mengecil
saat gambarnya diperkecil agar muat di halaman, dan pada lebar A4 teks sekecil
itu tidak terbaca lagi. Tabel Word tetap tajam berapa pun ukurannya.

**`laporan.js`** menyusun dokumennya dengan pustaka `docx`. Dua hal yang mudah
salah dan sudah ditangani:

- `docx` **mengabaikan `\n` di dalam satu TextRun**. Blok kode karena itu
  dibangun satu run per baris dengan `break`, kalau tidak seluruh kode menempel
  jadi satu baris panjang.
- Tiap bab mulai di halaman baru lewat `pageBreakBefore` pada judulnya, **bukan**
  lewat paragraf `PageBreak` tersendiri. Paragraf itu ikut mengalir, jadi kalau
  halaman sebelumnya kebetulan penuh dia mendarat di halaman berikutnya dan
  meninggalkan satu halaman kosong melompong.

## Memeriksa hasilnya

Tidak ada LibreOffice di mesin ini, tapi ada Word, jadi pemeriksaan dilakukan
lewat ekspor PDF:

```powershell
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open("C:\Web Program\roblox-codeverse\laporan\Laporan-Tugas-CodeVerse.docx", $false, $true)
$doc.ExportAsFixedFormat("C:\Web Program\roblox-codeverse\laporan\Laporan-Tugas-CodeVerse.pdf", 17)
$doc.Close($false); $word.Quit()
```
