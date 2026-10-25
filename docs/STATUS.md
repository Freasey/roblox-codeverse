# Status proyek CodeVerse

Dokumen ini menjawab satu pertanyaan: **di mana kita sekarang, dan apa langkah
berikutnya.** Dia sengaja hidup di repo, bukan di kepala siapa pun dan bukan di
riwayat chat, supaya sesi atau percakapan yang dihapus tidak membawa
informasinya ikut hilang.

`docs/DEVELOPMENT_PLAN.md` menjelaskan **rencana**. Dokumen ini menjelaskan
**kenyataan**. Kalau keduanya berbeda, dokumen ini yang benar — perbarui dia
tiap kali ada milestone tutup atau ada hasil playtest.

Terakhir diperbarui: 2026-10-25, tepat sesudah commit `1796f1c`.

## 1. Ringkasan satu paragraf

Kode untuk **M0 sampai M5 sudah ada di `main` dan CI-nya hijau**: fondasi,
pertarungan, state machine match dengan 10 wave, Toko Match, dua boss, dan
progres permanen plus lobby. M7 dan M8 belum disentuh. Sebagian besar
perilaku game belum pernah dijalankan oleh seorang pemain.

**M6 kodenya sudah lengkap, buktinya belum.** Lima item M6 di
`docs/DEVELOPMENT_PLAN.md`, dan empat di antaranya ternyata sudah terpasang
sejak milestone sebelumnya: ready check menuntut SEMUA pemain di server
(`everyoneReady`), koin match satu kolam tim dengan reward dihitung per
pemain, peserta yang disconnect boleh rejoin dan match dibatalkan kalau
semuanya keluar, dan setiap remote C -> S sudah punya rate limit. Yang
benar-benar belum ada satu baris pun cuma papan leaderboard, dan itu yang
baru mendarat: `LeaderboardService` dengan satu OrderedDataStore per tingkat
kesulitan, `GetLeaderboard` yang akhirnya terdaftar bersama handler-nya, dan
panel papan di lobby.

Jadi yang tersisa di M6 bukan kode, melainkan dua hal yang tidak bisa
dikerjakan dari command line: **playtest 4 client** (MP-01 sampai MP-14) dan
**publish**, karena OrderedDataStore tidak jalan sama sekali di place yang
belum pernah di-publish.

**Rancangan ulang arena SELESAI.** Ketujuh langkah di
`docs/ARENA_REDESIGN.md` bagian 8 sudah mendarat: musuh yang mencapai base
berhenti dan memukul sampai dibunuh, pemain bisa mati, hadiah koin per wave
jalan, harga Toko Match naik tiap pembelian, ada fase `Loadout` 20 detik
sebelum hitung mundur, tiap senjata bercabang jadi tiga alur upgrade permanen
di level 4, dan isi efek kesembilan alur itu sudah terpasang — termasuk empat
mekanik yang sebelumnya tidak ada sama sekali: slow, pengurangan damage yang
masuk ke pemain, splash, dan tanda, plus zona jebakan yang menempel ke tempat.

**Jadi playtest sekarang yang menghalangi, bukan kode.** Playtest ditunda atas
permintaan Daffa (2026-10-25) sampai rancangannya selesai; rancangannya sudah
selesai, jadi alasan penundaannya sudah habis. Prosedurnya lengkap di
[bagian 3](#3-playtest-m1-tugas-daffa). Dua catatan yang perlu dibaca lebih
dulu: angka **jumlah serangan** di beberapa baris (`WAVE-03`, `WAVE-07`,
`SHOP-16`) dihitung untuk senjata TANPA alur, jadi mainkan dengan senjata level
1-3 atau dengan alur yang belum mencapai tingkatnya; dan satu kekurangan yang
diketahui — **zona jebakan tidak kelihatan di layar**, jadi musuh yang melambat
dan kehilangan HP tanpa sebab yang terlihat itu benar, bukan bug (lihat
`docs/TEST_CASES.md` bagian 5.3).

## 2. Apa yang sudah terverifikasi, dan dengan cara apa

Penting dibedakan, karena ketiga lapis ini membuktikan hal yang berbeda:

| Lapis | Cakupan | Status |
| --- | --- | --- |
| Unit test murni (`lune run tests/run`) | Modul murni di `src/shared/Modules/`: aturan toko, balance, boss, hit test, lane, match, progresi, rate limit, papan wave tertinggi | **256 test lulus** |
| CI (lint, type check, build, test) | Seluruh repo tiap push | **hijau di `main`** |
| Harness Studio (`lune run tests/studio/run`) | Boot server, spawn musuh, penolakan remote, HP dan warna Core, urutan waypoint, pembagian lane, serangan berulang ke base per tipe musuh, slot cincin, skala HP per wave, slow dan zona dan tanda alur upgrade, pendaftaran remote papan | **257 assertion lulus, 0 gagal, 22 di-skip** |
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
Tapi batas itu lebih jauh dari yang disangka semula. Apa pun yang dikerjakan
server sendiri bisa dijangkau: musuh digerakkan server lewat `CFrame`, jadi
urutan waypoint, pembagian lane, HP Core, dan warna Part Core semuanya terukur
tanpa Player. Case `core_wave` menutup itu dan membuat **WAVE-12, CORE-04, dan
CORE-06 jadi `OK` tanpa tangan manusia.** (WAVE-11 sempat ikut, lalu turun lagi
ke `-` setelah rancangan ulang arena mengubah harapannya.) Yang benar-benar mentok
cuma yang butuh karakter atau client: menyerang, bar HP, kamera, input.

## 3. Playtest M1 (tugas Daffa)

Tinggal **24 case bertanda M1** di `docs/TEST_CASES.md` (WAVE-12, CORE-04, dan CORE-06 sudah `OK` lewat harness). Naik dari 18, bukan karena ada yang gagal: lima case M1 baru lahir dari rancangan ulang arena (WAVE-17, WAVE-18, WAVE-19, COMBAT-16, COMBAT-17), dan WAVE-11 kembali manual karena harapannya berubah:

```
BOOT-02 BOOT-03 BOOT-06
WAVE-03 WAVE-07 WAVE-11 WAVE-13 WAVE-15 WAVE-17 WAVE-18 WAVE-19
CORE-01 CORE-02 CORE-03
COMBAT-01 COMBAT-02 COMBAT-03 COMBAT-04 COMBAT-05 COMBAT-10 COMBAT-13
COMBAT-15 COMBAT-16 COMBAT-17
```

Sebagian dari 24 itu **sudah terbukti separuh**, dan bagian mana yang tersisa
ditulis per case di `docs/TEST_CASES.md` bagian 3.2. Dua yang paling memendek:
geometri COMBAT-03 (musuh di belakang, musuh di luar jangkauan) dan pemilihan
target terdekat COMBAT-13 sudah dibuktikan unit test di
`tests/HitTest.spec.luau` — yang tersisa cuma memastikan kabelnya tersambung,
bukan menguji ulang matematikanya.

### Urutan menjalankannya

Urutan di bawah bukan selera. Tiga hal di dalamnya akan merusak hasil kalau
ditukar, dan alasannya ditulis di tempatnya masing-masing.

**Lapis 0 — sebelum Studio dibuka.**

```bash
cd "C:\Web Program\roblox-codeverse"
lune run tests/run          # 256 unit test, beberapa detik
lune run tests/studio/run   # harness Studio, ~130 detik
```

Baris `cd` itu bukan basa-basi. Tool di repo ini dikelola rokit, dan rokit
mencari versi tiap tool di `rokit.toml` milik folder tempat kamu berdiri (atau
induknya). Dijalankan dari `~`, `lune` gagal dengan *Failed to find tool 'lune'
in any project manifest file* — yang terbaca seperti lune belum terpasang,
padahal dia terpasang dan cuma tidak ada manifest yang menyebut versinya.
Berlaku untuk semua perintah di dokumen ini, `rojo serve` dan `git status`
termasuk.

Harness ini **harus jalan sebelum Studio dibuka**. Dia membuka instalasi Studio
sendiri (place salinan di `%TEMP%`), merebut fokus sekitar 10 detik, lalu
menutup diri. Perilakunya saat Studio sudah terbuka duluan belum pernah diuji
— lihat `tests/studio/README.md`. Exit code 0 berarti lulus.

**Lapis 1 — BOOT, sebelum apa pun yang lain.** `BOOT-01`, `BOOT-02`. Kalau BOOT
gagal, tidak ada gunanya menjalankan sisanya; yang kelihatan seperti belasan bug
gameplay biasanya satu map yang tidak ter-mount.

**Lapis 2 — main solo, F5.** Tekan **Ready** di panel lobby (solo cukup satu
pemain: `everyoneReady()` benar kalau semua pemain yang hadir ready), countdown
10 detik, lalu wave 1 jalan. Kerjakan dengan Output jendela server terlihat:

```
CORE-01                                          →  sebelum wave mulai
WAVE-03 WAVE-07 WAVE-11 WAVE-13 WAVE-15
COMBAT-01 COMBAT-02 COMBAT-03 COMBAT-04 COMBAT-13 COMBAT-15
WAVE-18                                          →  siapa yang keluar lane
CORE-02 WAVE-17                                  →  biarkan satu `basic` lolos
WAVE-19                                          →  biarkan 6+ lolos sekaligus
COMBAT-16 COMBAT-17                              →  biarkan dirimu dibunuh
COMBAT-10                                        →  serang saat sedang mati
CORE-03                                          →  biarkan Core sampai 0
```

Lima baris terakhir itu lahir dari rancangan ulang arena dan belum pernah
dijalankan siapa pun. Urutannya bukan selera: `WAVE-17` dan `WAVE-19` menuntut
kamu **sengaja membiarkan musuh lolos**, dan sejak musuh yang lolos tidak lagi
menghilang, itu berarti wave-nya tidak akan selesai sampai kamu membunuhnya —
jadi kerjakan keduanya setelah case yang butuh wave berjalan normal, bukan
sebelum.

`CORE-03` ditaruh terakhir di lapis ini karena dia **mengakhiri match**.

Tiga baris yang dulu ada di lapis ini sudah tidak ada lagi: WAVE-12, CORE-04,
dan CORE-06 `OK` lewat harness. WAVE-11 kembali ke lapis ini. Dan tiga yang masih di sini tinggal
sepotong — CORE-02 cuma perlu kamu lihat **bar Core di HUD** turun 5 (kelima
angka damage per tipe sudah dipatok), WAVE-07 cuma **jumlah serangan** (angka
HP-nya sudah dipatok), dan BOOT-02 di lapis 1 cuma **posisi karakter** (hitungan
barisnya sudah otomatis). Rinciannya per case di `docs/TEST_CASES.md` bagian
3.2.

**Lapis 3 — `COMBAT-05`, satu pass sendiri.** Nyalakan **Test → Network
Simulation → Bad Internet**, jalankan hanya case ini, lalu **matikan lagi**.
Jangan digabung dengan lapis 2: dengan lag menyala semua case lain ikut terasa
aneh dan kamu akan mengejar bug yang tidak ada.

**Lapis 4 — dua case `EDIT`, paling akhir.** `BOOT-03` (rename
`assets/Arena.rbxmx`) dan `BOOT-06` (set `DEBUG_VISIBLE_WAYPOINTS = true`).
Keduanya mengubah file di working tree, jadi menjalankannya lebih awal berarti
seluruh sisa playtest dikerjakan di atas repo yang sudah kotor. Setelah selesai,
`git status` harus bersih lagi — itu caranya tahu kedua perubahan sudah
dibalikkan.

Prakondisi `BOOT-06` tertulis "Lobby sudah ada", dan itu **lebih ketat dari yang
dia butuh sebenarnya**: yang dia uji adalah urutan waypoint di arena. Tanpa
lobby, pemain muncul di spawn arena (`BOOT-04`) dan case ini tetap bisa
dijalankan.

**Sisipkan `SHOP-16`** begitu sampai wave 10 di sesi mana pun — alasannya di
bagian 4.

### Dua hal yang jangan dicatat sebagai GAGAL

Keduanya prasyarat yang belum dipenuhi, bukan bug, dan satu baris GAGAL palsu
akan menenggelamkan yang sungguhan:

- Warn `[PlayerDataService] ... jalan dengan data default di memori` — place
  belum di-publish. Lihat bagian 5.
- Warn `[MapService] Lobby tidak lengkap` — `assets/Lobby.rbxmx` belum dibuat.
  Itu justru hasil yang diharapkan `BOOT-04`.

Isi kolom **Status** di `docs/TEST_CASES.md` sambil jalan: `OK`, `GAGAL` (tulis
apa yang terjadi), `BLOK` (prasyarat belum ada), `N/A`. Sebagian sesuai **bukan**
`OK`.

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

- **Damage musuh ke PEMAIN.** Damage ke base dipatok harness untuk kelima tipe,
  tapi memukul pemain butuh Humanoid, jadi harness cuma bisa men-skip-nya
  (`damage.pukulanKePlayer`). Yang terbukti baru pengalinya sendiri lewat unit
  test `EnemyAI.playerDamage`. Jadi "berapa pukulan sampai pemain mati" —
  `basic` 4, `fast` 7, `tank` 2, Splitter 2, Locker 1 — belum pernah diuji
  seorang pun. `COMBAT-16` dan `COMBAT-17` yang menutupnya.

- **Hadiah koin per wave dan harga toko yang naik.** Seluruh angkanya dipatok
  unit test (kurva 200 sampai 1300, total 5.300 / 10.600 / 21.200, dan kurva
  harga 200 sampai 1490), tapi jalurnya dari wave selesai sampai saldo di HUD
  belum pernah dilihat manusia. Yang paling mudah salah dan paling sunyi
  kalau salah: hadiah **wave terakhir**. Kodenya sempat punya urutan yang akan
  melewatkannya, karena `onWaveCleared` memanggil `endMatch` lalu `return`.

- **Fase `Loadout`.** State barunya ada di `MatchService` dan daftar state yang
  membolehkan `SelectLoadout` dipatok unit test (`MatchRules.canSelectLoadout`),
  tapi seluruh fase ini **tidak bisa disentuh harness sama sekali**: keluar dari
  `Lobby` butuh `everyoneReady()`, yang butuh Player, dan harness tidak bisa
  membuat satu pun. Jadi yang belum pernah dilihat: timer 20 detik berjalan,
  tombol mana yang hidup dan mati selama fase itu, dan — yang paling mudah
  salah — bahwa **tingkat kesulitan** yang diganti di dalam fase itu benar-benar
  berlaku. `lockDifficulty()` dipindah ke akhir fase justru untuk itu, dan kalau
  pemindahannya salah, gejalanya adalah tingkat yang dipilih diabaikan tanpa
  pesan apa pun sementara senjatanya diterima.

- **Tiga alur upgrade per senjata.** Seluruh aturannya dipatok unit test
  (`pathChoiceRequired`, `canUpgrade` dengan `pathId`, `pathToApply`,
  `Balance.weaponStats` lintas tiga tingkat), termasuk yang paling mahal kalau
  salah: **alur yang sudah terpilih tidak bisa diganti**, dan alur **tidak bisa
  dikunci sebelum level 4**. Yang belum pernah dilihat manusia: panel
  pemilihannya di layar, dan `data.weapons[id].path` yang benar-benar bertahan
  setelah keluar dan join lagi — yang terakhir butuh place yang sudah
  di-publish, jadi dia terkunci di belakang bagian 5.1.

- **Tiga dari enam efek alur.** Slow, zona jebakan, dan tanda sudah dipatok
  harness di engine sungguhan (`tests/studio/cases/path_effects.luau`): slow
  benar-benar memperlambat Part yang bergerak, zona memberi damage sebanding
  waktu dan terbuang saat `clearAll`, dan tanda mengalikan damage dari sumber
  yang tidak punya pemain. **Tiga sisanya tidak bisa disentuh harness sama
  sekali**, karena ketiganya masuk lewat `CombatService.onAttack` yang menuntut
  Player: **splash**, **kerucut melee yang melebar**, dan **pengurangan damage
  yang masuk ke pemain**. Matematikanya punya unit test
  (`tests/CombatEffects.spec.luau`), tapi kabelnya belum pernah dibuktikan.

  Yang paling mahal di antara ketiganya: splash yang mengenai target utamanya
  **dua kali**. Gejalanya cuma damage yang lebih besar daripada yang tertulis di
  panel — tidak ada error, tidak ada yang kelihatan rusak, dan pemain yang
  diuntungkan tidak akan melaporkannya. `CombatEffects.withinRadius` punya test
  untuk pengecualiannya, tapi yang menyusun daftar pengecualiannya
  `CombatService`, dan bagian itu belum teruji.

- **Papan wave tertinggi.** Aturannya dipatok 13 unit test
  (`tests/LeaderboardRules.spec.luau`), termasuk yang paling mahal kalau
  salah: **catatan tidak pernah turun**, diuji dua kali karena aturan itu
  dipakai di dua tempat yang sifatnya berbeda -- transform `UpdateAsync` yang
  memutuskan tulisan ke OrderedDataStore dibatalkan, dan `merge` yang menjahit
  rekor baru ke papan di memori. Kalau keduanya tidak sepakat, papan di layar
  bisa menunjukkan angka yang lebih tinggi daripada yang tersimpan, dan
  selisihnya baru ketahuan setelah server restart -- papannya "turun sendiri".

  Harness membuktikan dua hal saja, dan keduanya di case `boot`: remote
  `GetLeaderboard` benar-benar terdaftar di engine sebagai RemoteFunction, dan
  jalur tanpa OrderedDataStore menghasilkan papan kosong yang diam. **Sisanya
  terkunci di belakang publish**, karena OrderedDataStore tidak jalan sama
  sekali di place yang belum pernah di-publish: tidak ada satu catatan pun
  yang pernah ditulis atau dibaca sungguhan. Lihat LB-01 sampai LB-05.

- **Zona jebakan tidak punya Part.** Efeknya bekerja; tempatnya tidak terlihat.
  Jadi pemain melihat musuh melambat dan kehilangan HP tanpa sebab yang
  terlihat. Ini kekurangan yang diketahui dan dicatat di `TEST_CASES.md` bagian
  5.3, bukan bug — menggambarnya butuh aset, dan itu M7.

- **`Config.DEV_ALL_WEAPONS`.** Default `false`, jadi jalur ini tidak pernah
  aktif di CI maupun di harness. Unit test memastikan `ownedWeapons` dan
  `equippedWeapon` setuju soal senjata yang sama, termasuk bahwa `canBuy`,
  `canCraft`, dan `canUpgrade` TIDAK ikut flag — tapi "memilih Packet Rifle lalu
  benar-benar mengayunkan Packet Rifle" cuma bisa dibuktikan dengan mengukur
  damage, dan itu butuh Player. Kalau flag ini dinyalakan untuk mencoba senjata,
  **kembalikan ke `false` sebelum commit**; nilainya tidak pernah masuk
  DataStore, tapi pembelian senjata jadi tidak bisa diuji selama dia hidup.

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
  Prosedurnya di bagian 5.1. Sejak M6 ini menghalangi satu hal lagi: papan
  wave tertinggi memakai OrderedDataStore, jadi seluruh kelompok LB ikut
  menunggu di sini. Sampai itu terjadi, papannya muncul di lobby dalam
  keadaan kosong dan server mencetak satu warn per tingkat kesulitan.

### 5.1 Publish, dan main di client Roblox alih-alih di Studio

Studio terasa berat saat F5 bukan karena game-nya berat. Di playtest Studio,
**server dan client jalan di satu proses di laptopmu**: loop `Heartbeat` yang
menggerakkan sampai 40 musuh lewat `CFrame` dan rendering 40 bar HP BillboardGui
jatuh ke CPU yang sama. Di client Roblox, server-nya jalan di mesin Roblox dan
yang tinggal di laptopmu cuma rendering. Jadi publish bukan jalan memutar untuk
menghindari lag; dia memang menghilangkan separuh bebannya.

**Publish pertama harus dari Studio**, dan itu tidak bisa dihindari: Open Cloud
API butuh universe dan place yang sudah ada, jadi tidak ada yang bisa dibuatnya
dari nol. **File -> Publish to Roblox As...**, buat experience baru. Experience
baru default-nya privat, dan itu sudah cukup untuk kamu mainkan sendiri — tidak
perlu dipublikkan. Sesudahnya centang **Game Settings -> Security -> Enable
Studio Access to API Services**, restart Studio, dan warn
`[PlayerDataService] ... data default di memori` harus hilang.

Di layar yang sama, setel **Game Settings -> Players -> Max Players = 4**.
Itu satu-satunya tempat batas pemain ditegakkan: `Config.MAX_PLAYERS` cuma
angka yang diasumsikan rancangan (jumlah musuh per wave dan hadiah koin
dihitung per pemain), dan tidak ada satu baris kode pun yang menolak pemain
kelima. Kalau langkah ini terlewat, place-nya menerima default Roblox dan
wave 1 dengan 12 pemain akan punya musuh tiga kali lipat dari yang pernah
diuji.

**Update berikutnya tidak perlu Studio lagi.** `.github/workflows/publish.yml`
sudah lengkap; yang belum ada tiga nilai, dan ketiganya baru bisa diisi setelah
place-nya ada:

| Di GitHub | Nama | Dari mana |
|---|---|---|
| Secret (environment `roblox`) | `ROBLOX_API_KEY` | Creator Dashboard -> Open Cloud API Keys, izin **Place Management** untuk universe ini |
| Variable | `ROBLOX_UNIVERSE_ID` | Creator Dashboard, halaman experience-nya |
| Variable | `ROBLOX_PLACE_ID` | URL place-nya |

Workflow-nya manual (`workflow_dispatch`) dan punya pilihan `Saved` atau
`Published`: `Saved` mengunggah tanpa mengubah yang sedang dimainkan orang,
`Published` yang membuatnya live. Pakai `Saved` dulu, cek, baru `Published`.

**Apa yang berubah untuk testing.** Di client tidak ada jendela Output. Yang
menggantikannya **F9 -> Developer Console -> tab Server**, dan print server cuma
terlihat di situ kalau kamu pemilik place-nya. Semua baris test yang bilang
"lihat Output server" dibaca dari sana.

**Yang tetap harus di Studio**, dan ini yang menentukan kamu tidak bisa pindah
seluruhnya:

- **Network Simulation cuma ada di Studio.** Dua case berkode `LAG` —
  `COMBAT-05` dan `COMBAT-06` — permanen di Studio. `COMBAT-05` itu syarat
  selesainya M1, jadi Studio tidak bisa ditinggalkan sama sekali.
- **Delapan case berkode `EDIT`** (`BOOT-03`, `BOOT-06`, `WAVE-10`, `SHOP-11`,
  `SHOP-15`, `BOSS-14`, `PROG-12`, `HUD-08`) mengubah kode atau data sementara
  dan mengandalkan sync Rojo, jadi butuh Studio yang ter-Connect.
- **Command bar** (seluruh bagian 16, SEC) cuma ada di Studio.

Dari 24 case M1 yang masih manual, **21 bisa dipindah ke client**; yang tinggal
di Studio `COMBAT-05`, `BOOT-03`, dan `BOOT-06`.

**Yang justru terbuka setelah publish:** 22 case yang sekarang terkunci. Lima
belas berkode `PUB` (`PROG-14`, `PROG-15`, `PROG-25`, `DATA-02`, `DATA-03`,
`DATA-04`, `DATA-05`, `DATA-07`, `DATA-08`, `DATA-13`, dan seluruh `LB-01`
sampai `LB-05`) dan delapan berkode `LIVE` (`MATCH-16`, `SHOP-13`, `BOSS-13`,
`MP-06`, `MP-07`, `MP-08`, `MP-11`, `DATA-04`) — `DATA-04` masuk keduanya. Yang
`LIVE` itu test rejoin, dan Studio memang tidak bisa mensimulasikan satu pemain
keluar lalu **join lagi** ke sesi yang sama.

Angka itu naik dari 15 karena dua sebab yang berbeda. Lima barisnya papan
leaderboard yang baru mendarat. Dua sisanya, `PROG-25` dan `DATA-13`, sudah
berkode `PUB` sejak rancangan ulang arena dan tidak pernah ikut dihitung di
sini — jadi angka lama memang sudah kurang dua sebelum M6 menyentuhnya.

## 6. Milestone yang belum tutup

Checklist lengkapnya ada di `docs/DEVELOPMENT_PLAN.md` bagian 4. Ringkasnya:

- **M6 — Multiplayer & leaderboard.** **Kodenya sudah lengkap** (lihat bagian
  1); yang tersisa playtest 4 client dan publish.
- **M7 — Polish & pengujian.** Model final dari Blender, balancing, optimasi,
  alpha test, beta test.
- **M8 — Rilis.** Icon dan thumbnail, secret `publish.yml`, publish, tag
  `v1.0.0`.

Catatan M6: `GetLeaderboard` sekarang **sudah terdaftar** di `Remotes.luau`,
dan sengaja baru didaftarkan bersama `LeaderboardService` yang memasang
`OnServerInvoke`-nya. Urutan itu syarat, bukan kerapian: `RemoteFunction` yang
ada tapi tidak punya handler membuat client yang memanggilnya menggantung
selamanya -- tanpa error, tanpa timeout, dan tanpa petunjuk apa pun di layar.
Alasan yang sama membuat `LeaderboardService.start()` dipanggil di
`init.server.luau` **sebelum** gerbang arena: kalau dia di bawah, place tanpa
`assets/Arena.rbxmx` akan punya remote tanpa handler. Lihat `LB-00`.

## 7. Utang dokumentasi yang diketahui

- **`tests/studio/COVERAGE.md` persentasenya historis, dan sekarang dua kali
  basi.** Penyebutnya 126,
  dihitung sebelum `STUDIO_CHECKLIST.md` dilebur ke `TEST_CASES.md`; sekarang
  dokumennya memuat 160 case. Pembilangnya juga sudah lewat: dia ditulis untuk
  tiga case harness dengan 82 assertion, sementara sekarang ada lima case
  dengan 257 dan tiga baris M1 yang naik jadi `OK`. Rasio maupun pembilangnya
  belum dihitung ulang; `docs/TEST_CASES.md` bagian 3.2 adalah sumber yang
  benar untuk cakupan harness.

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
