# Daftar screenshot yang perlu diambil

Buka file ini di sebelah Roblox Studio sambil memotret. Tiga belas gambar,
sekitar sepuluh menit kalau lancar.

**Cara memasangnya:** simpan tiap potret ke `laporan/img/` dengan **nama file
persis seperti di tabel**, lalu laporan dibangun ulang (lihat
[skrip/README.md](skrip/README.md)). Selama sebuah file belum diganti,
tempatnya di laporan diisi kotak penanda bertuliskan "BELUM ADA SCREENSHOT",
jadi tidak ada gambar yang hilang diam-diam.

Ukuran yang pas: 1280x720 atau lebih besar, perbandingan 16:9.

## Sebelum mulai

```bash
cd "C:\Web Program\roblox-codeverse"
lune run tests/run
lune run tests/studio/run
```

Harness Studio **harus jalan sebelum Studio dibuka** — dia membuka instalasi
Studio sendiri dan merebut fokus sekitar 10 detik. Baru sesudah itu buka
Studio, `rojo serve`, Connect, lalu F5.

## Daftar

| No | Nama file | Yang difoto | Cara mendapatkannya | Bab |
|---|---|---|---|---|
| 1 | `s01-lobby-ready.png` | Panel lobby: senjata, kesulitan, tombol Ready | Tekan F5; panel muncul sendiri di state Lobby | 7 |
| 2 | `s02-idle.png` | Karakter berdiri diam, tampak seluruh badan | Jangan sentuh tombol gerak; putar kamera ke samping | 1 |
| 3 | `s03-run.png` | Karakter sedang berlari | Tahan W sambil memotret; kaki harus terlihat melangkah | 1 |
| 4 | `s04-jump.png` | Karakter melompat, kaki di udara | Tekan Space, potret saat masih naik | 1 |
| 5 | `s05-skybox.png` | Langit dan dinding arena | Arahkan kamera ke atas horizon sampai langit mengisi layar | 2 |
| 6 | `s06-arena.png` | Arena tampak luas: Core, dua lane, dinding | Scroll mundur sejauh mungkin, lihat dari atas-belakang Core | 3 |
| 7 | `s07-kamera.png` | Karakter di dua posisi, tetap di tengah layar | Dua potret di tempat berbeda, lalu gabungkan berdampingan | 6 |
| 8 | `s08-hud.png` | HUD: HP Core, wave, timer, cash | Potret di tengah wave 1 saat musuh berjalan | 7 |
| 9 | `s09-toko.png` | Toko Match saat jeda antar wave | Muncul di state Intermission, 20 detik setelah wave selesai | 7 |
| 10 | `s10-boss.png` | Boss wave 5 di arena | Bertahan sampai wave 5; potret sebelum boss membelah | 7 |
| 11 | `s11-kartu-info.png` | Kartu info malware | Muncul otomatis sesudah boss mati, lalu hilang sendiri | 7 |
| 12 | `s12-leaderboard.png` | Papan wave tertinggi di lobby | Butuh place yang sudah di-publish | 7 |
| 13 | `s13-hasil.png` | Layar hasil akhir match | Muncul di state Ended, bertahan 10 detik | 7 |

## Tiga yang perlu diwaspadai

**Nomor 11, kartu info.** Kartu ini punya tombol tutup **dan** hilang sendiri
setelah beberapa detik. Siapkan jari di tombol screenshot sebelum boss mati.

**Nomor 12, leaderboard.** `OrderedDataStore` tidak berfungsi sama sekali di
place yang belum pernah di-publish. Gambar ini baru bisa diambil setelah place
dipublikasikan — sampai saat itu, biarkan kotak penandanya.

**Nomor 7, kamera.** Butuh dua potret yang digabung berdampingan jadi satu
gambar. Yang ditunjukkan adalah karakter berpindah tempat tapi tetap berada di
tengah layar, karena itulah bukti kameranya mengikuti.

## Sekalian: playtest yang tertunda

Sesi Studio ini sekaligus kesempatan menjalankan 24 case M1 yang masih
menunggu di `docs/TEST_CASES.md` — urutan menjalankannya ada di
`docs/STATUS.md` bagian 3. Urutannya tidak sembarangan, jadi baca dulu sebelum
mulai. Screenshot nomor 8 sampai 13 kebetulan jatuh di titik-titik yang sama
dengan beberapa case itu.
