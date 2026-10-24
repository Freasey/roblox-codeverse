# Status proyek CodeVerse

Dokumen ini menjawab satu pertanyaan: **di mana kita sekarang, dan apa langkah
berikutnya.** Dia sengaja hidup di repo, bukan di kepala siapa pun dan bukan di
riwayat chat, supaya sesi atau percakapan yang dihapus tidak membawa
informasinya ikut hilang.

`docs/DEVELOPMENT_PLAN.md` menjelaskan **rencana**. Dokumen ini menjelaskan
**kenyataan**. Kalau keduanya berbeda, dokumen ini yang benar — perbarui dia
tiap kali ada milestone tutup atau ada hasil playtest.

Terakhir diperbarui: 2026-10-24, pada commit `15a7da4`.

## 1. Ringkasan satu paragraf

Kode untuk **M0 sampai M5 sudah ada di `main` dan CI-nya hijau**: fondasi,
pertarungan, state machine match dengan 10 wave, Toko Match, dua boss, dan
progres permanen plus lobby. M6 sampai M8 belum disentuh. Yang belum terjadi
dan jadi penghalang utama sekarang bukan koding, tapi **playtest manusia**:
sebagian besar perilaku game belum pernah dijalankan oleh seorang pemain.

## 2. Apa yang sudah terverifikasi, dan dengan cara apa

Penting dibedakan, karena ketiga lapis ini membuktikan hal yang berbeda:

| Lapis | Cakupan | Status |
| --- | --- | --- |
| Unit test murni (`lune run tests/run`) | Modul murni di `src/shared/Modules/`: aturan toko, balance, boss, hit test, lane, match, progresi, rate limit | **149 test lulus** |
| CI (lint, type check, build, test) | Seluruh repo tiap push | **hijau di `main`** |
| Harness Studio (`lune run tests/studio/run`) | Boot server, spawn musuh, penolakan remote | **82 assertion lulus, 0 gagal, 13 di-skip** |
| Playtest manusia (`docs/TEST_CASES.md`) | Semua yang butuh pemain sungguhan | **belum dijalankan** |

### Kenapa CI hijau tidak cukup

Ini bukan kehati-hatian berlebihan; sudah pernah terjadi di proyek ini. Pada
satu titik **kelima check CI lulus sementara script server mati saat boot**,
karena `PlayerDataService` memanggil `DataStoreService:GetDataStore()` di
lingkup modul. Lint, type check, dan build tidak pernah menjalankan game, jadi
tidak ada satu pun dari mereka yang bisa melihat itu. Dari situlah
`docs/TEST_CASES.md` dan harness Studio lahir.

### Kenapa harness Studio juga tidak cukup

`run-in-roblox` menjalankan sebuah script di dalam place, tapi **tidak ada
Player yang pernah join** — `CreateLocalPlayer` gagal dengan *lacking
capability LocalUser*. Jadi semua yang butuh karakter, Humanoid, input, atau
HUD tidak bisa diotomatisasi sama sekali. Rinciannya di
`tests/studio/COVERAGE.md`.

Ini bukan masalah yang bisa dipecahkan dengan usaha lebih; itu batas alatnya.
Dari 160 case di `docs/TEST_CASES.md`, hanya 16 yang bisa otomatis penuh.

## 3. Langkah berikutnya: playtest M1 (tugas Daffa)

Ada **22 case bertanda M1** di `docs/TEST_CASES.md`:

```
BOOT-02 BOOT-03 BOOT-06
WAVE-03 WAVE-07 WAVE-11 WAVE-12 WAVE-13 WAVE-15
CORE-01 CORE-02 CORE-03 CORE-04 CORE-06
COMBAT-01 COMBAT-02 COMBAT-03 COMBAT-04 COMBAT-05 COMBAT-10 COMBAT-13 COMBAT-15
```

Urutan yang disarankan:

1. `lune run tests/studio/run` — sekitar 45 detik, menutup case `BISA` tanpa
   membuka Studio.
2. Blok M1 di `docs/TEST_CASES.md`, dari atas.
3. Sisipkan `SHOP-16` begitu sampai wave 10 (alasannya di bagian 4).

**`COMBAT-05` adalah satu-satunya case M1 yang jangan di-skip.** Dia menguji
apakah serangan terasa kena saat ping tinggi, dan itu syarat selesainya M1 di
rencana. Kalau gagal: **naikkan `Balance.MELEE_RADIUS_BONUS`, jangan cari bug
di `HitTest`.** Penyebabnya latensi, bukan geometri — toleransi longgar itu
desain yang disengaja, bukan kelalaian.

## 4. Yang ter-ship tapi belum pernah terbukti jalan

Jujur, karena ini mudah disalahpahami sebagai "sudah beres":

- **Mekanik sandera boss Locker (opsi A).** Locker menonaktifkan efek upgrade
  tim yang sudah dibeli selama dia hidup; `purchases` tetap utuh, cuma efeknya
  nol. Terimplementasi di `ShopService.setSuspended` + `Locker.luau`, dan unit
  test memastikan `ShopRules.modifiers({})` memberi pengali dasar `1`/`1` —
  mekanik ini bergantung pada itu. Tapi **mengukur damage butuh Player dan
  Humanoid**, jadi harness tidak bisa menyentuhnya.

  `SHOP-16` adalah satu-satunya cara tahu dia benar-benar bekerja: hitung
  berapa serangan untuk membunuh satu musuh `basic` tiga kali — sebelum boss
  spawn, saat boss hidup, setelah boss mati. Angka tengah harus naik seperti
  belum pernah upgrade, lalu kembali.

  Kalau angka di fase tengah **tidak** naik, itu bug implementasi
  (`getModifiers` tidak terpanggil ulang saat sandera dipasang), bukan soal
  balancing.

- **Seluruh M2 sampai M5.** Kodenya ada dan CI hijau, tapi belum ada satu pun
  match yang pernah dimainkan dari lobby sampai layar hasil oleh manusia.

## 5. Yang menunggu tindakan di Studio

Dua hal ini tidak bisa dikerjakan dari command line dan menghalangi sebagian
test:

- **`assets/Lobby.rbxmx` belum ada.** Generatornya sudah ada di
  `scripts/build_lobby.luau`; jalankan dari command bar Studio, lalu simpan
  hasilnya sebagai `.rbxmx` (**bukan** `.rbxm` — `.gitignore` punya `*.rbxm`
  dan akan menelan bentuk binernya tanpa bilang apa-apa). `assets/Arena.rbxmx`
  sudah ada dan sudah divalidasi terhadap kontrak marker bagian 3.4.
- **Place harus di-publish sekali** sebelum test DataStore atau persistensi apa
  pun (M5.7). DataStore tidak jalan di place yang belum pernah di-publish.

## 6. Milestone yang belum dikerjakan

Checklist lengkapnya ada di `docs/DEVELOPMENT_PLAN.md` bagian 4. Ringkasnya:

- **M6 — Multiplayer & leaderboard.** Ready check 2-4 player, rejoin peserta,
  `LeaderboardService` (OrderedDataStore), rate limit di semua remote.
- **M7 — Polish & pengujian.** Model final dari Blender, balancing, optimasi,
  alpha test, beta test.
- **M8 — Rilis.** Icon dan thumbnail, secret `publish.yml`, publish, tag
  `v1.0.0`.

Catatan M6: `GetLeaderboard` **sengaja belum didaftarkan** di `Remotes.luau`.
`RemoteFunction` tanpa `OnServerInvoke` membuat client yang memanggilnya
menggantung selamanya, jadi tidak ada lebih baik daripada ada tapi mati. Lihat
`LB-00`.

## 7. Utang dokumentasi yang diketahui

- **`tests/studio/COVERAGE.md` persentasenya historis.** Penyebutnya 126,
  dihitung sebelum `STUDIO_CHECKLIST.md` dilebur ke `TEST_CASES.md`; sekarang
  dokumennya memuat 160 case. Angka-angka itu masih benar sebagai pembilang,
  tapi rasionya tidak. Belum dihitung ulang.

## 8. Kebiasaan kerja yang berlaku di repo ini

- Commit memakai identitas Daffa saja, tanpa trailer co-author.
- Jelaskan mekanismenya dari awal dulu, baru masalahnya.
- Modul murni di `src/shared/Modules/` memakai require string relatif
  (`require("./Types")`) supaya bisa diuji Lune. **Alias `.luaurc` kustom tidak
  diresolusi engine Roblox saat runtime** — dia lolos type check di CI lalu
  gagal di Studio. Alasannya di `DEVELOPMENT_PLAN.md` bagian 1.5.
- **Jangan pernah memanggil API web Roblox di lingkup modul**
  (`DataStoreService`, `OrderedDataStore`, `MessagingService`, `HttpService`,
  `MarketplaceService`). Kegagalan di sana menjatuhkan seluruh script yang
  me-require-nya dengan pesan menyesatkan "Requested module experienced an
  error while loading".
