# CodeVerse: Test Cases v1

Dokumen ini adalah **satu-satunya dokumen pengujian manual** di repo ini. Dia
menggabungkan dua dokumen yang dulu terpisah: daftar test case bernomor yang
dipetakan ke kriteria "Selesai kalau" di
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md), dan checklist verifikasi Studio yang
langkah-langkahnya ditulis sambil melihat kode aslinya. `docs/STUDIO_CHECKLIST.md`
dihapus; semua isinya yang tidak ada di tempat lain — termasuk seluruh tabel
keputusan implementasi — pindah ke sini.

> ## Baca ini dulu
>
> **Tidak satu baris pun kode M1 sampai M5 pernah dimainkan sebagai game di
> Roblox Studio.** Yang sudah hijau: `stylua --check`, `selene`,
> `luau-lsp analyze`, 303 unit test Lune, `rojo build`, dan — sejak harness
> `tests/studio` ada — sisi server yang dijalankan engine sungguhan dalam mode
> Run (lihat [bagian 3.2](#32-cakupan-harness-studio)). Lolos type check bukan
> berarti jalan di engine, dan jalan di mode Run bukan berarti bisa dimainkan:
> mode Run tidak punya Player sama sekali. Yang tetap tidak bisa diperiksa tanpa
> manusia di Studio: apakah UI-nya kelihatan dan posisinya benar, apakah serangan
> terasa kena saat ping tinggi, apakah state machine-nya berpindah pada waktu
> yang benar, dan apakah data tersimpan lalu terbaca lagi.
>
> Jadi dokumen ini **bukan formalitas dan bukan lampiran yang diisi belakangan.**
> Dia gerbang pertama yang sebenarnya. Baris yang GAGAL di sini adalah bug nyata
> yang belum pernah ada yang lihat, bukan kesalahan pemakaian — dan beberapa
> perilaku yang kelihatan salah sebenarnya disengaja (lihat
> [bagian 5](#5-yang-sudah-diketahui-sebelum-playtest)).

## 1. Cara memakai dokumen ini

Dokumen ini dipakai **dua kali**, dengan tujuan berbeda.

**Per milestone, sebagai gerbang.** Tiap kriteria "Selesai kalau" di
DEVELOPMENT_PLAN.md bagian 4 punya minimal satu test case di sini. Sebuah
milestone baru boleh dicentang kalau seluruh test case miliknya hijau —
pemetaannya ada di
[bagian 19](#19-pemetaan-ke-kriteria-selesai-kalau). Yang mengisi: developer
sendiri, karena yang dicari di tahap ini adalah "fiturnya jalan atau tidak".

**Di M7 (alpha test), sebagai lampiran laporan.** Seluruh dokumen dijalankan
sekali lagi dari atas ke bawah, kolom Status diisi ulang dari kosong, dan hasil
itulah lampiran black-box test untuk laporan (lihat pemetaan GDLC di
DEVELOPMENT_PLAN.md bagian 5: tahap *Alpha testing* → output "Hasil black-box
test"). Yang mengisi di tahap ini sebaiknya **anggota tim yang bukan penulis
kodenya**, karena yang dicari di alpha justru asumsi yang cuma jelas di kepala
developer.

Isi kolom **Status**:

| Isi | Arti |
|---|---|
| `-` | Belum dites. Nilai awal semua baris. |
| `OK` | Sesuai kolom "Hasil yang diharapkan", seluruhnya. Sebagian sesuai bukan `OK`. |
| `GAGAL` | Tidak sesuai. Tulis apa yang terjadi di kolomnya, atau buka issue dan catat nomornya di situ. |
| `BLOK` | Tidak bisa dijalankan karena prasyaratnya belum ada (lihat kolom Jalankan?), **atau** karena prakondisinya tidak bisa dicapai dengan kode dan data yang ada sekarang. Bukan lulus dan bukan gagal; syarat menjalankannya lagi ditulis di kolom Prakondisi baris itu. |
| `N/A` | Fiturnya dipotong (DEVELOPMENT_PLAN.md bagian 9), jadi test-nya tidak berlaku lagi. |

Kolom **Jalankan?** menandai apa yang dibutuhkan baris itu. Ini yang memisahkan
"bisa dites hari ini" dari "harus menunggu":

| Kode | Arti |
|---|---|
| `solo` | Cukup F5 sendirian. Bisa dijalankan sekarang. |
| `2P` / `4P` | Butuh **Test → Clients and Servers** dengan 2 atau 4 client. |
| `LAG` | Butuh **Network Simulation** di tab Test. |
| `EDIT` | Butuh perubahan sementara di kode atau data. **Balikkan sebelum commit.** |
| `PUB` | Butuh place sudah di-publish sekali **dan** API Services dicentang. Tanpa itu dijamin gagal karena alasan yang salah — lihat [bagian 2](#2-persiapan-studio). |
| `LIVE` | Butuh server live, bukan Studio. Studio tidak bisa mensimulasikan satu pemain keluar lalu **join lagi** ke sesi yang sama. |
| `BELUM` | Fiturnya belum diimplementasikan sama sekali. Statusnya `BLOK` sampai kodenya ada. |

Kode bisa digabung (`4P+LAG`). Kalau satu baris butuh `PUB`, `LIVE`, atau
`BELUM`, **jangan dijalankan lalu dicatat GAGAL** — itu bukan bug, dan satu baris
GAGAL yang penyebabnya prasyarat akan menenggelamkan baris GAGAL yang sungguhan.

Ringkasan apa yang bisa dikerjakan hari ini:

| Kelompok | Bisa sekarang (`solo`/`2P`/`4P`/`LAG`/`EDIT`) | Tertunda (`PUB`/`LIVE`) | Belum ada (`BELUM`) |
|---|---|---|---|
| BOOT, MATCH, WAVE, CORE, COMBAT, SHOP, BOSS, HUD | hampir semuanya, termasuk **keenam efek alur upgrade** (COMBAT-18 sampai COMBAT-25) — enam dari delapan baris itu `solo+EDIT`, satu butuh `2P`, dan satu (COMBAT-25) sudah `OK` lewat harness | sedikit | — |
| PROG | reward, level, XP, dan statistik dalam satu sesi — **upgrade senjata, pilihan alur, beli, dan craft tidak**, lihat di bawah | semua yang menyangkut "keluar, join lagi, masih ada" | — |
| MP | ready check, cash **per pemain**, 4 player | semua rejoin | — |
| DATA | DATA-01, DATA-09a, DATA-11, DATA-12 | sisanya | — |
| SEC | semuanya, SEC-08 termasuk | — | — |
| MOVE | semuanya — gerak tidak butuh prasyarat apa pun, dan MOVE-07 yang membuktikan pemain lain ikut melihat sikap badan butuh `2P`. Kelompoknya ada di [bagian 21](#21-gerak-pemain-move), sesudah kedua bagian meta | — | — |
| LB | LB-00 | LB-01 sampai LB-05 (`PUB`) — OrderedDataStore butuh place yang sudah di-publish | — |

Kolom terakhir **kosong seluruhnya** sejak M6 bagian leaderboard mendarat: LB
adalah kelompok terakhir yang isinya `BELUM`, dan sekarang yang tersisa di sana
cuma syarat publish. Kode `BELUM` tetap didefinisikan di atas karena fitur yang
belum ada bisa muncul lagi, bukan karena ada baris yang memakainya.

**Tiga kelompok baris berstatus `BLOK`, dan sebab ketiganya bukan prasyarat
yang belum ada melainkan fitur yang sengaja dimatikan atau dipindahkan.** Tidak
satu pun boleh dicatat GAGAL: kodenya tidak berubah, aturannya masih benar dan
unit test-nya masih lulus — cuma keadaannya tidak bisa dicapai dari dalam game.
Syarat menjalankannya lagi ditulis di kolom Prakondisi tiap barisnya.

1. **Senjata yang belum dimiliki.** Ketiga senjata terbuka sejak awal lewat
   `Config.DEFAULT_DATA.weapons` ([bagian 4.2](#42-angka-patokan)), jadi seluruh
   baris yang menguji "senjata belum dimiliki" tidak punya keadaan yang bisa
   dicapai. Enam baris: MATCH-22, MATCH-23, PROG-10, PROG-12, PROG-13, dan
   PROG-18. Syarat menjalankannya lagi sama untuk keenamnya:
   `Config.DEFAULT_DATA.weapons` dikembalikan jadi `weapon_starter` saja.
2. **Kelima item Toko Match.** `Config.MATCH_SHOP_ITEMS_ENABLED = false`, dan
   penolakannya di server — bukan cuma panelnya yang disembunyikan
   ([bagian 11](#11-toko-match-shop)). Dua belas baris: SHOP-01 sampai
   SHOP-06, SHOP-09, SHOP-12, SHOP-16, SHOP-20, SHOP-21, SHOP-22, ditambah
   CORE-05 dan MP-14.
   Syaratnya satu: `Config.MATCH_SHOP_ITEMS_ENABLED = true`.
3. **Upgrade senjata dari lobby.** Upgrade pindah ke dalam match dan dibayar
   cash, dan `ProgressionService` **tidak menyambung remote `UpgradeWeapon`**
   lagi — handler lobbynya diparkir sebagai
   `ProgressionService.upgradeFromLobby` dan tidak tersambung ke apa pun
   ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)). Sebelas baris:
   PROG-08, PROG-09, PROG-19 sampai PROG-26, dan HUD-07. Syarat
   menjalankannya lagi satu baris di `ProgressionService.start()` yang
   menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — dan itu berarti
   **dua** handler untuk remote yang sama, jadi lihat dulu alasan
   pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match).

## 2. Persiapan Studio

### 2.1 Sekali saja, sebelum test apa pun

1. `rokit install` di root repo (butuh rojo, lune, stylua, selene, luau-lsp).
2. `rojo serve default.project.json`.
3. Buka Studio, buat place baru, install plugin Rojo, **Connect**.
4. **Game Settings → Security → Enable Studio Access to API Services** dicentang.
   Tanpa ini `PlayerDataService` tidak bisa menyentuh DataStore dan mengeluarkan
   satu warn soal itu saat boot.

### 2.2 Kotak DataStore — baca sebelum menyalahkan kode

**DataStore belum bisa dites sampai place-nya di-publish sekali.** Roblox menolak
akses DataStore dari place yang belum pernah di-publish ke web, apa pun isi Game
Settings. Sebelum itu `PlayerDataService` menjalankan pemain dengan **data default
di memori** dan tidak pernah menulis apa pun (`loaded` di-set false sehingga
`save()` berhenti di gerbang pertamanya), lalu mencetak:

```
[PlayerDataService] <nama> jalan dengan data default di memori. Progres TIDAK
tersimpan. Publish place-nya sekali, lalu centang Game Settings -> Security ->
Enable Studio Access to API Services.
```

Penolakan yang sama berlaku untuk **OrderedDataStore**, yang dipakai papan
leaderboard. `LeaderboardService` turun ke papan kosong di memori dengan pola
yang sama — satu warn per tingkat kesulitan, tidak ada error — jadi seluruh
[bagian 15](#15-leaderboard-lb) kecuali LB-00 juga berkode `PUB`.

Konsekuensinya: **semua baris berkode `PUB` dijamin gagal** sebelum langkah
publish dilakukan — termasuk seluruh [bagian 17](#17-persistence-datastore-data)
dan kriteria penerimaan M5 ("keluar, join lagi, dan semua progres masih ada").
Gameplay per match tetap bisa dites penuh, dan progres yang dibuat dalam satu
sesi (koin, level senjata, material) tetap berlaku di sesi itu — hilangnya baru
saat playtest di-stop.

Langkah publish: **File → Publish to Roblox** sekali, centang API Services,
restart Studio. Sesudah itu warn di atas harus hilang dari Output.

### 2.3 Multi-client

**Test → Clients and Servers**, pilih jumlah client (2 sampai 4), lalu **Start**.
Tiap client jadi jendela sendiri dan ada satu jendela server. **Output jendela
server itulah yang dipantau** untuk semua kriteria "tidak ada error". Test solo
cukup F5.

Yang **tidak bisa** dilakukan Studio: satu client keluar lalu **join lagi** ke
sesi yang sama. Menutup jendela client memang mensimulasikan disconnect, tapi
tidak ada cara membukanya kembali dengan UserId yang sama. Itu sebabnya seluruh
test rejoin berkode `LIVE`.

### 2.4 Network simulation

**Test → Network Simulation → Bad Internet** (atau **Terrible**). Dipakai baris
berkode `LAG`. **Matikan lagi setelah selesai**, kalau tidak semua test
berikutnya ikut terasa aneh dan kamu akan mengejar bug yang tidak ada.

### 2.5 Command bar

Test keamanan di [bagian 16](#16-keamanan-remote-sec) dijalankan dari **command
bar jendela client**, bukan server: **Test → Current: Client**, lalu

```lua
local R = game:GetService("ReplicatedStorage").Remotes
```

Yang dinilai bukan cuma "aksinya ditolak", tapi juga **tidak ada error di Output
server**. Server yang error karena argumen sampah berarti validasinya kurang,
walaupun aksinya gagal.

### 2.6 Map: Arena sudah ada, Lobby belum

`assets/Arena.rbxmx` **sudah ada di repo**, sudah ter-mount ke `Workspace.Arena`,
dan strukturnya sudah diverifikasi terhadap kontrak penanda DEVELOPMENT_PLAN.md
bagian 3.4: `CoreServer` adalah Model dengan `PrimaryPart` bernama `Core`,
`Lanes` berisi `Lane1`, `Lane2`, dan `Lane3` yang masing-masing punya tujuh
waypoint bernama `1` sampai `7` berurutan, dan `PlayerSpawn` adalah
SpawnLocation. Kontrak itu sama persis dengan yang dipenuhi `ArenaBuilder`
sekarang — yang berubah siapa yang merakitnya, bukan bentuk yang dibaca
`MapService`.

`assets/Lobby.rbxmx` **tidak perlu dibuat lagi**, dan prosedur enam langkah
yang dulu ada di sini sudah dihapus seluruhnya. Sejak 2026-10-26 lobby dibangun
`ArenaBuilder` saat server start, bersama arena dan latar belakangnya, dari
`ArenaLayout`. Tidak ada file yang perlu disimpan dari Studio.

Hal yang sama berlaku untuk arena: `assets/Arena.rbxmx` masih ada di repo dan
masih ter-mount, tapi dia **bukan lagi arena yang kamu mainkan** — builder
merakit arena baru di luar Workspace lalu menukarnya. File itu sengaja
dibiarkan sebagai jaring pengaman: kalau builder gagal di tengah jalan, yang
tersisa arena graybox lama alih-alih place tanpa lantai sama sekali.

Perlu **mengubah** layout arena (jumlah waypoint, jaraknya, ukuran lantai)? Setel
konstanta di bagian atas `scripts/build_arena.luau`, jalankan di command bar
(script-nya idempoten: `Workspace.Arena` yang lama dihapus dulu), lalu Save to
File menimpa `assets/Arena.rbxmx`.

> **Prosedur edit map, jangan dilewati.** Rojo satu arah: begitu
> `assets/Arena.rbxmx` ter-mount, apa pun yang kamu ubah pada `Workspace.Arena`
> di Studio akan **hilang** pada sync berikutnya. Alurnya selalu: edit di Studio
> → **Save to File** menimpa file di `assets/` → baru commit. Versi lengkapnya
> ada di [README bagian "Mengedit map"](../README.md#mengedit-map); yang di sini
> cuma sebanyak yang dibutuhkan untuk menjalankan test di bawah.

## 3. Yang sudah terverifikasi di luar dokumen ini

Ada dua macam cakupan dari luar dokumen ini, dan keduanya tidak boleh
dicampur. [Bagian 3.1](#31-tidak-perlu-dites-lagi-di-sini) adalah hal yang
**tidak perlu dites lagi** sama sekali. [Bagian 3.2](#32-cakupan-harness-studio)
adalah cakupan **sebagian**: dia memendekkan kerja tangan untuk beberapa baris
M1, satu baris M5, dan — sejak papan leaderboard mendarat — separuh LB-00 di
M6. Empat baris sudah hijau karenanya dan disebut satu per satu di situ;
sisanya tetap `-`, karena sebagian sesuai bukan `OK`.

### 3.1 Tidak perlu dites lagi di sini

Tiga hal di bawah **tidak perlu dites lagi** di sini. Dicatat supaya tidak ada
yang mengetesnya ulang, dan supaya kalau salah satunya pecah, jelas bahwa itu
regresi.

| Yang sudah terverifikasi | Di mana | Catatan |
|---|---|---|
| Lint, format, type check, 303 unit test Lune, `rojo build` | CI (`.github/workflows/ci.yml`) | Modul murni di `src/shared/Modules` sudah punya test: pembagian musuh per wave jumlahnya persis `Balance.enemyCount`, ambang boss cuma terpicu sekali, seluruh daftar penolakan toko dan progres, kurva level yang aman terhadap XP inf/NaN, material drop boss cocok dengan bahan craft, daftar state yang membolehkan loadout diganti (`MatchRules.canSelectLoadout`), kedua keadaan flag `DEV_ALL_WEAPONS` di `ProgressionRules.ownedWeapons` / `.equippedWeapon`, seluruh aturan alur upgrade — kapan pilihan ditagih (`pathChoiceRequired`), urutan pemeriksaan `canUpgrade` (alur sebelum koin, level maksimum sebelum keduanya), alur yang tidak bisa diganti, dan alur yang **tidak** tersimpan sebelum titik percabangan (`pathToApply`) — dan sejak langkah 7, aritmetika efek alur yang punya umur di `tests/CombatEffects.spec.luau`: terkuat-menang di `CombatEffects.merge`, slow zona yang diambil terkuat sementara dps-nya dijumlahkan, pemilihan korban splash yang mengecualikan target utama (`withinRadius`), dan urutan deterministik `nearest` untuk penularan tanda. Plus dua test yang menjaga kosakata `effects` dari **dua arah**: kunci di `Weapons.luau` yang tidak ada di `Balance.PATH_EFFECT_KEYS` ditolak, dan kunci di `PATH_EFFECT_KEYS` yang tidak dipakai satu alur pun juga ditolak — yang pertama menangkap salah tulis yang diam-diam tidak pernah terbaca, yang kedua menangkap kosakata mati yang tetap terbaca sebagai janji. Sejak M6 bagian leaderboard, ditambah tiga belas test `tests/LeaderboardRules.spec.luau` untuk aturan papan wave tertinggi: catatan yang tidak pernah turun dan yang menolak wave 0, negatif, serta NaN (`isRecord`), pemecah seri `userId` yang membuat urutan papan deterministik walau dua pemain punya wave sama, `rank` yang mengembalikan daftar baru dan **tidak** mengurutkan daftar masukan di tempat, dan satu test yang mengikat `merge` ke `isRecord` supaya keduanya tidak bisa berbeda pendapat — kalau berbeda, papan di layar menunjukkan angka yang tidak pernah tersimpan, dan selisihnya baru ketahuan setelah server restart. Dua test terakhir, dan keduanya datang bersama ketiga senjata yang terbuka sejak awal di `Config.DEFAULT_DATA.weapons`: bahwa tiap id di tabel itu benar-benar ada di `Weapons.luau` — id yang salah tulis **tidak** menghasilkan error, dia cuma disaring diam-diam oleh `ownedWeapons` dan senjata yang dijanjikan tidak pernah muncul di lobby — dan bahwa ketiganya bisa **di-upgrade**, bukan cuma dipakai, yaitu persis hal yang `Config.DEV_ALL_WEAPONS` tidak bisa berikan. Yang terakhir masuk, 26 test `tests/MoveRules.spec.luau` untuk aturan gerak pemain, dan modul itu didahulukan karena dia satu-satunya yang di-require **dua sisi jaringan**: histeresis sprint dibuktikan dari kedua arahnya sekaligus — di bawah ambang sprint tidak boleh MULAI, tapi sprint yang sudah jalan harus LANJUT, dan kalau kedua ambangnya disamakan yang terlihat bukan sprint yang mati melainkan kecepatan dan animasi yang berkedip puluhan kali per detik — lalu sprint di tempat yang memulihkan alih-alih menguras, clamp stamina di kedua ujung pada dt sebesar frame yang tersendat, `isStance` yang menolak nil/angka/boolean/tabel **tanpa error** karena muatan remote bisa berisi apa saja dan error di handler remote menjatuhkan satu frame gerak untuk semua pemain, dan satu test yang menyapu seluruh kombinasi masukan `resolveStance` untuk membuktikan nilai baliknya **selalu** punya kecepatan dan tinggi lompat — itu yang mengikat atribut `Stance` yang ditulis server ke animator yang membacanya di tiap client. Yang **tidak** ada di daftar ini dan perlu disadari: empat modul murni yang masuk bersama lapisan tampilan pada 2026-10-26 — `ArenaLayout`, `EnemyVisuals`, `Poses`, `WeaponVisuals` — belum punya satu unit test pun (`CharacterDesign` ikut masuk hari itu lalu dicabut lagi bersama rancangan karakternya). |
| **Relative require jalan di engine Roblox** (DEVELOPMENT_PLAN.md bagian 1.5) | Playtest Studio pertama, lalu tiap run harness (`boot.log: [CodeVerse] relative require OK`) | Place lokal dijalankan dan eksekusi sampai masuk ke `PlayerDataService`, artinya seluruh rantai require di atasnya sukses — termasuk `require(Shared.Config)`, dan `Config.luau` baris 5 adalah `require("./Modules/Types")`. Rencana cadangan di bagian 1.5 **tidak** dipakai. |
| **API web Roblox tidak boleh dipanggil di module scope** | Playtest Studio pertama | `GetDataStore` dulu dipanggil di module scope `PlayerDataService`; di place yang belum pernah di-publish, Roblox melempar error tepat di baris itu, require-nya gagal, dan SELURUH script server mati sebelum satu baris pun jalan — dengan pesan "Requested module experienced an error while loading" yang tidak menunjuk ke penyebabnya. Sudah diperbaiki jadi lazy + `pcall`. **Aturan ini berlaku untuk semua kode berikutnya:** `DataStoreService`, `OrderedDataStore`, `MessagingService`, `HttpService`, `MarketplaceService`, dan sejenisnya hanya dipanggil di dalam fungsi. |

### 3.2 Cakupan harness Studio

`tests/studio` menjalankan sisi server game ini di dalam Roblox Studio asli dari
command line (`lune run tests/studio/run`). Mekanismenya: `run-in-roblox`
membuka place hasil `rojo build`, script-nya memanggil `RunService:Run()` — itu
tombol **Run**, jadi seluruh `Script` server benar-benar dieksekusi engine — lalu
sebuah `Script` test disuntik ke `ServerScriptService` supaya dia berbagi cache
`require` dengan `init.server.luau` dan memanggil service yang sungguh hidup,
bukan salinan. Penjelasan lengkapnya ada di
[tests/studio/README.md](../tests/studio/README.md).

Batasnya satu, dan dia menentukan segalanya: **mode Run tidak punya Player.**
`Players:CreateLocalPlayer` ditolak engine, jadi tidak ada karakter, tidak ada
Humanoid, tidak ada input, tidak ada kamera, dan tidak ada satu pun
`LocalScript` yang jalan. Apa pun di kolom "Hasil yang diharapkan" yang
menyebut HUD, panel, bar HP, klik, atau posisi karakter berada di luar
jangkauannya secara permanen — bukan karena harness-nya belum selesai.

Run terakhir: **258 assertion lulus, 0 gagal, 22 dilewati, exit 0**, dari lima
case: `boot`, `enemy_core`, `remote_reject`, `core_wave`, dan `path_effects`.
Yang dilewati itu **bukan lulus**, dan kedua puluh duanya punya **tiga** sebab
yang berbeda — dulu dua, dan yang ketiga datang bersama `path_effects`.

**Tiga belas** dari `remote_reject`: kedelapan handler remote C → S memanggil
`RateLimit.check(player.UserId)` sebelum memvalidasi argumennya, jadi tanpa
Player mereka error karena nil player sebelum jalur validasinya tersentuh —
delapan SKIP untuk handler-nya, empat lagi untuk varian argumen
`RequestAction`, dan satu untuk `GetProfile` yang memanggil
`PlayerDataService.waitFor(player)`. Itu milik
[bagian 16](#16-keamanan-remote-sec) dan tetap harus dijalankan dari command bar
client.

**Empat** dari `boot`, `core_wave`, dan `enemy_core` butuh mata manusia,
Humanoid, atau transisi state yang tidak bisa terjadi tanpa Player:
`warna.terlihatPemainTanpaHud` (butuh melihat arenanya),
`habis.stateBerubahKeEnded` dan `habis.musuhDibersihkanSaatMatchBerakhir`
(dua-duanya lewat `MatchService.endMatch`, yang cuma jalan dari
`WaveActive`/`Intermission`), dan `damage.pukulanKePlayer` di `enemy_core`
(butuh Humanoid untuk diukur).

**Lima sisanya** dari `path_effects`, dan sebabnya satu: **tiga dari enam efek
alur masuk lewat `CombatService.onAttack`**, yang menuntut `Player` sungguhan
beserta karakternya untuk membaca titik asal dan arah bidik — dan harness tidak
bisa membuat satu pun, karena `Players:CreateLocalPlayer` ditolak engine dengan
"lacking capability LocalUser". Kelimanya: `splash.korbanDiSekitarTitikKena`,
`splash.targetUtamaTidakKenaDuaKali`, `kerucut.melebarDiTingkat2`,
`bertahan.damageKePlayerDikurangi`, dan `tanda.menularKeMusuhTerdekat`. Itu
sebab yang **berbeda** dari tiga belas SKIP `remote_reject`, yang juga soal
Player: di sana yang error adalah `RateLimit.check(player.UserId)` di gerbang
pertama handler-nya, di sini jalur kodenya baik-baik saja dan yang tidak ada
cuma pemanggilnya. Kelima baris itu milik [bagian 10](#10-combat-combat) dan
tetap tugas playtest manusia (COMBAT-18 sampai COMBAT-22).

Angka 13, 4, 5, dan 22 semuanya benar dan bukan salah tulis: 13 + 4 + 5 = 22,
dan tiga angka pertama itu tiga sebab yang berbeda, bukan tiga potongan dari
satu sebab.

Keenam assertion yang **baru** di run terakhir seluruhnya di case `boot`, dan
isinya papan leaderboard. Yang dibuktikan ada dua hal. Pertama, remote-nya
**benar-benar terdaftar di engine** sesudah boot dan dia `RemoteFunction`,
bukan `RemoteEvent` (`boot.remote.getLeaderboardAda`,
`boot.remote.getLeaderboardRemoteFunction`), dan `[LeaderboardService] siap`
ikut muncul di jejak log boot. Kedua, **jalur tanpa DataStore diam**:
`LeaderboardService.getBoard("normal")` mengembalikan tabel kosong — bukan
`nil`, bukan error — dan tingkat yang tidak dikenal juga
(`boot.papan.bukanNil`, `boot.papan.kosongTanpaDataStore`,
`boot.papan.tingkatTakDikenalKosong`). Itu jalur yang dilewati setiap orang
yang baru clone repo ini, jadi dia yang paling sering jalan dan paling jarang
diperiksa. Dua warn ikut masuk daftar warn yang diizinkan di `boot` — `papan
normal tidak tersedia` dan `papan hard tidak tersedia` — karena
OrderedDataStore tidak ada di place yang belum di-publish; teksnya menyebut
tingkatnya, jadi keduanya tidak terbaca sebagai warn identik yang berulang.

Satu assertion lagi masuk bersama arena baru: **lane ketiga**. Harness dulu
mematok dua lane di empat tempat, dan arena yang dibangun `ArenaBuilder` punya
tiga. Yang berubah bukan cuma angkanya -- `lane.musuhBerjalanDiLaneNyaSendiri`
ikut berubah CARA mengukurnya, dari jarak ke garis lurus antara waypoint
pertama dan terakhir, jadi jarak ke rantai segmen. Versi garis lurus benar
selama `build_arena.luau` yang menaruh waypoint pada satu heading; `ArenaLayout`
membelokkan lane, dan garis lurus memotong tikungannya -- musuh yang berjalan
tepat di jalurnya terbaca puluhan stud melenceng.

**Seluruh lapisan tampilan tidak bisa dibuktikan harness sama sekali**, dan
bukan karena harness-nya kurang: pose karakter, rancangan senjata, efek, dan
sikap badan semuanya butuh Player beserta karakternya, dan harness tidak bisa
membuat Player (`CreateLocalPlayer` -> *lacking capability LocalUser*). Empat
modul murni yang masuk bersamanya (`ArenaLayout`, `EnemyVisuals`, `Poses`,
`WeaponVisuals`) juga **belum punya unit test**; `MoveRules` sudah punya, tapi
yang dibuktikannya keputusan, bukan tampilannya. Jadi untuk semua itu, playtest
bukan lapisan terakhir -- dia satu-satunya.

Satu hal yang HARUS dilihat di detik pertama playtest, dan tidak ada satu pun
lapisan lain yang bisa melihatnya: **avatar yang muncul harus avatar akun
sendiri**, lengkap dengan baju, rambut, dan topinya. Rancangan karakter
"Teknisi IT" dicabut pada 2026-10-26, dan yang menggantikannya adalah avatar
pemain apa adanya. Kalau yang muncul justru badan polos tanpa baju, sebabnya
cuma satu: `StarterPlayer.LoadCharacterAppearance` di place itu masih `false`
dan belum tersiram, karena properti itu tinggal di properti place, bukan di
file mana pun. `default.project.json` sudah menyetelnya `true` untuk place yang
dibangun dari nol, dan `CharacterService.start()` menyetelnya lagi saat server
hidup untuk place lama -- jadi kalau masih polos juga, yang gagal salah satu
dari kedua jalur itu, bukan avatarnya.

Dua hal soal papan yang **tidak** bisa dibuktikan harness, dan keduanya bukan
karena harness-nya kurang. `InvokeServer` butuh client, jadi separuh LB-00 —
bahwa panggilannya kembali tanpa menggantung — tetap kerja tangan. Dan
OrderedDataStore butuh place yang sudah di-publish, jadi LB-01 sampai LB-05
tidak punya tempat penyimpanan untuk diuji sama sekali: yang dibuktikan di
sini justru bahwa ketiadaan itu tidak menjatuhkan apa pun.

Akibatnya untuk kolom Status: **tiga baris M1 dan satu baris M5 dibuktikan
seluruhnya dan sudah `OK`** — WAVE-12, CORE-04, CORE-06, dan COMBAT-25 (zona
jebakan tidak terbawa ke match berikutnya, dibuktikan
`zona.dibuangSaatClearAll`). WAVE-11 sempat `OK` dan turun lagi ke
`-` setelah rancangan ulang arena: harapannya sekarang menuntut musuh yang
sampai **berhenti dan tetap ada** di cincin sekitar Core, dan bagian "bar HP-nya
masih di atasnya" tidak bisa dibuktikan tanpa client. Keempat yang `OK` tidak
punya bagian client di kolom harapannya: yang diuji gerak musuh, pembagian lane,
HP Core, warna sebuah Part, dan HP satu musuh yang tidak diserang — semuanya
milik server.

Sisanya tetap `-`, dan aturan di [bagian 1](#1-cara-memakai-dokumen-ini) berlaku
apa adanya: sebagian sesuai bukan `OK`. Empat yang paling dekat tapi tidak lolos
patut disebut, supaya tidak ada yang menaikkannya belakangan tanpa alasan baru:
**BOOT-06** (jalur lane 1 terbukti utuh, tapi lane 2 tidak disentuh dan flag
`DEBUG_VISIBLE_WAYPOINTS` memang untuk dilihat mata), **CORE-03** (HP berhenti
tepat di 0 dan `onDestroyed` menyala sekali, tapi transisi ke `Ended` dan
pembersihan arena ada di `MatchService.endMatch` yang tidak bisa dicapai tanpa
Player), **COMBAT-23** (slow terbukti benar-benar memperlambat gerak Part —
rasio terukur 0.36 untuk pengali 0.40 — tapi yang menyetel slow itu di match
adalah serangan pemain lewat `onAttack`, dan harness memanggil `applySlow`
langsung), dan **COMBAT-24** (zona terbukti memberi damage sebanding waktu dan
memperlambat, tapi zonanya ditaruh `addZone` langsung, bukan ditinggalkan oleh
tembakan pemain).

Untuk baris yang masih `-`, tabel di bawah menyebut bagian mana yang sudah
berdiri sendiri, supaya kerja tangannya lebih pendek dan bukan diulang dari nol.

| ID | Sudah dibuktikan harness | Masih butuh tangan |
|---|---|---|
| BOOT-02 | Baris `[MapService] Arena siap` isinya persis `3 lane, waypoint di-cache (Lane1=7, Lane2=7, Lane3=7)` (`boot.arena.3lane`, `boot.arena.waypointTerCache`), dan sekarang juga **dihitung**: baris itu muncul tepat sekali (`boot.arena.barisSiapTepatSatu`), `[CodeVerse] server booting` tepat sekali — dua baris berarti rantai boot jalan dua kali (`boot.initServerJalanSekali`), warn `MapService` soal Arena nol kali (`boot.mapService.warnArenaTidakPernah`), dan tidak ada warn milik game yang teksnya identik muncul lebih dari sekali (`boot.tidakAdaWarnIdentikBerulang`) | Cuma satu hal: karakter muncul di `Arena/PlayerSpawn`. Bagian "tepat satu baris" sudah tidak perlu dihitung dengan mata |
| BOOT-06 | Jalur lane 1 **utuh dan berurutan**: satu musuh diikuti 100 sampel dari awal lane sampai Core, jarak terdekat ke tiap waypoint 1–7 di bawah 1.2 stud, dan nomor sampel saat kedekatan itu terjadi naik rapi `@1 @16 @33 @49 @66 @83 @99` (`waypoint.urutan1Sampai7`). Urutan nama waypoint datang dari sort **angka**, diuji dengan nama yang memuat "10" supaya sort string memberi hasil berbeda (`waypoint.urutanDariSortAngkaBukanString`) | Lane 2 tidak disentuh, dan flag `DEBUG_VISIBLE_WAYPOINTS` memang untuk dilihat mata. Nomor sampel yang naik sudah menutup lompat-balik dan zig-zag besar; yang tersisa untuk mata cuma kehalusan geraknya |
| WAVE-03 | Musuh `basic` berjalan mengikuti lane mendekat ke Core (`gerak.*`, sama dengan BOOT-06), dan HP-nya dipatok per wave: 100 / 115 / 160 / 235 di wave 1 / 2 / 5 / 10, dengan `maxHp == hp` (`skalaHp.*`) | Angka 8 stud/detik — harness jalan sekitar 8 Hz, jadi durasi absolut dari sana tidak bisa dibandingkan dengan playtest. Dan jumlah serangan sampai mati: menyerang butuh karakter |
| WAVE-07 | HP `basic` dipatok di empat wave sekaligus — 100 / 115 / 160 / 235 di wave 1 / 2 / 5 / 10, naik monoton, dan rasio wave 5 berbanding wave 1 tepat 1.600 (`skalaHp.*`). Patokannya dirangkai ulang dari `Enemies.basic.baseHp` dan `Balance.HP_PER_WAVE`, bukan dari `Balance.enemyHp` yang dipakai kode spawn itu sendiri — kalau patokannya fungsi yang sama, yang terbukti cuma 1 == 1 | Jumlah serangan sampai mati (4 di wave 1, 7 di wave 5): menyerang butuh karakter. Angka HP-nya sendiri tidak perlu dihitung lagi |
| CORE-01 | HP Core 1000 / 1000 dan Core belum hancur tepat setelah boot (`boot.coreHpPenuh`, `boot.coreTidakHancur`, `prasyarat.coreHpPenuh`) | Bahwa HUD menampilkannya: "Core 1000 / 1000" dan bar penuh adalah UI client |
| CORE-02 | **Kelima angka damage ke base per pukulan sudah dipatok**, semuanya lewat jalur asli `step()` → `enterAttackingBase()` → `CoreService.damage()`, dan terukur di engine persis `attackDamage * 0.2`: `basic` 5, `fast` 3, `tank` 12, Splitter 16, Locker 24 (`damageTipe.*.hpCoreTurunSebesarSatuPukulan`). **Pukulan yang berulang** juga dipatok, bukan cuma yang pertama (`damage.pukulanBerulang`, `.besarPukulanKedua`, `.pukulanKetigaDanSeterusnya`), begitu juga musuhnya yang **tetap hidup** setelah sampai (`damage.musuhTetapHidupSetelahSampai`, `.stateAttackingBase`, `.ringSlotTerisi`). Plus patokan yang menjawab pertanyaan yang mudah salah: `tank` di `hard` + 4 player tetap memukul 12 sementara HP-nya ikut naik jadi 1476 (`damageTipe.hard4Player.hpCoreTurunAngkaDasar`, `.hpIkutPengali`) — jadi "tidak ada pengali yang sampai ke entitas ini" tidak bisa jadi penjelasan alternatif | Cuma tampilan **bar Core** di HUD. Menggiring `tank` dan dua boss sampai ke Core — yang menuntut mencapai wave 5 dan 10 — sudah tidak perlu |
| CORE-03 | HP berhenti **tepat di 0** dan tidak pernah negatif walau di-damage tiga kali HP yang ada, `onDestroyed` menyala tepat sekali dengan HP sudah 0, damage dan heal sesudahnya ditolak, dan musuh yang sampai lewat jalur normal (`step` → `enterAttackingBase`) tetap memukul tanpa pernah menembus 0 — `isClear()` juga tetap false walaupun Core sudah hancur, jadi tidak ada yang bisa diam-diam membuatnya true sebagai jalan pintas (`habis.*`) | Transisi state ke `Ended` dan pembersihan arena: keduanya di `MatchService.endMatch`, yang cuma terpanggil dari handler `onDestroyed` saat state `WaveActive` atau `Intermission` — dan state tidak bisa keluar dari `Lobby` tanpa Player |
| COMBAT-21 | Pemilihan musuh terdekat untuk penularan tanda dipatok unit test `CombatEffects.nearest`, termasuk pemecah seri lewat id yang membuat hasilnya deterministik walau dua musuh berjarak sama persis. Dan bahwa tanda yang menempel benar-benar mengalikan damage dipatok `tanda.damageDikaliTanpaPemain` di engine | Siapa yang **ditulari**, dan bahwa target utama tidak ikut terpilih dua kali: penularannya dipasang `CombatService.onAttack`, yang butuh Player (`tanda.menularKeMusuhTerdekat` SKIP) |
| COMBAT-23 | Slow benar-benar sampai ke gerak Part, bukan cuma ke angka: satu musuh diukur di dua jendela yang sama panjang, dan rasio jarak tempuhnya **0.36** untuk pengali 0.40 (`slow.jarakTurunSesudahDiperlambat`). Musuhnya juga tidak berhenti total (`slow.musuhTidakBerhentiTotal`), yang menutup "pengalinya dipakai sebagai pengganti kecepatan". Dan pukulan **lemah** tidak membatalkan slow kuat yang masih aktif (`slow.pukulanLemahTidakMembatalkan`), jadi `applySlow` terbukti lewat `CombatEffects.merge` dan bukan menimpa langsung | Bahwa **serangan pemain** yang memasangnya: harness memanggil `EnemyService.applySlow` langsung, sementara di match angkanya datang dari `stats.effects.slowMult` lewat `onAttack`. Dan bahwa pemain **melihat** musuh melambat |
| COMBAT-24 | Zona memberi damage **sebanding waktu dan bukan sekali habis** (`zona.damageSebandingWaktuBukanSekaliHabis`), HP musuh turun tanpa ada yang menyerangnya (`zona.hpMusuhTurunTanpaDiserang`), zona di luar radius tidak kena (`zona.diLuarRadiusTidakKena`), dan ketiga API-nya aman untuk id musuh yang sudah mati (`jaga.efekPadaIdMatiTidakError`, `jaga.posisiIdMatiNil`) | Bahwa **tembakan pemain** yang meninggalkan zonanya, bahwa zona cuma lahir dari serangan yang mengenai sesuatu, dan bahwa perlambatan zonanya terlihat. Harness memanggil `EnemyService.addZone` langsung di titik yang dia pilih sendiri |
| LB-00 | Remote `GetLeaderboard` **ada di `ReplicatedStorage/Remotes` sesudah boot** dan dia `RemoteFunction` (`boot.remote.getLeaderboardAda`, `boot.remote.getLeaderboardRemoteFunction`). Perhatikan apa yang dua baris itu TIDAK buktikan: `Remotes.luau` membuat Instance-nya di lingkup modul, jadi remote ini ada begitu ada satu script saja yang me-require `Remotes` — bahkan kalau `LeaderboardService` tidak pernah jalan. Yang membuktikan `OnServerInvoke` terpasang adalah baris log `[LeaderboardService] siap`, karena `start()` yang mencetaknya juga yang memasangnya; ketiganya harus dibaca bersama. Papan kosongnya juga sudah dipatok (`boot.papan.*`) | Bahwa `InvokeServer("normal")` **kembali** dan tidak menggantung: itu butuh client, dan mode Run tidak punya satu pun |

Tiga belas baris M1 sisanya **tidak disentuh harness sama sekali** dan dikerjakan
dari nol: BOOT-03 (butuh map-nya dihilangkan, dan menilai HUD), WAVE-07, WAVE-13,
WAVE-15, CORE-03, serta seluruh COMBAT M1 — COMBAT-01 sampai COMBAT-05,
COMBAT-10, COMBAT-13, COMBAT-15. Semuanya bermuara ke satu sebab yang sama:
menyerang butuh karakter, dan bar HP musuh, bar Core, serta jarak pandang
kamera butuh client.

Harness ini **tidak jalan di CI** (butuh instalasi Studio), jadi angka di atas
berasal dari satu run manual dan bisa basi. Jalankan ulang
`lune run tests/studio/run` sebelum memakai tabel ini sebagai alasan melewatkan
sesuatu.

## 4. Kontrak remote dan angka patokan

Dua tabel di bawah ini **dibaca dari kode, bukan dari rencana**. Dipakai sebagai
acuan oleh test case di bawah, supaya tidak ada baris yang menyebut nama remote
atau angka yang tidak ada.

### 4.1 Remote yang benar-benar terdaftar

Sumber: `src/shared/Remotes.luau`. Yang ditandai ★ **tidak ada** di tabel
DEVELOPMENT_PLAN.md bagian 3.6 dan ditambahkan karena milestone-nya memintanya
tapi tabel itu tidak menyediakan jalurnya (alasan lengkap di
[bagian 20.1](#201-keputusan-lintas-milestone)).

| Nama | Arah | Payload | Rate limit | Validasi server |
|---|---|---|---|---|
| `DataLoaded` | S → C | data player lengkap | — | — |
| `DataChanged` | S → C | data player lengkap | — | Dikirim otomatis oleh `PlayerDataService.update` |
| `RequestAction` | C → S | string aksi | 2/detik | Cuma `"claimDailyBonus"` yang dikenal |
| `MatchState` | S → C | `{ state, wave, timer, coreHp, coreMaxHp }` | — | — |
| `MatchCoins` | S → C | `number` (cash **pemain itu sendiri**; nama remotenya tetap `MatchCoins`) | — | Dikirim `FireClient`, **bukan** `FireAllClients`: saldo sekarang milik masing-masing orang, jadi angka di keempat client memang **berbeda-beda** |
| `MatchResult` | S → C | `{ won, waveReached, coins, xp, materials, unlocked }` | — | — |
| `SetReady` | C → S | `boolean` | 2/detik | Hanya state `Lobby`, `Loadout`, dan `Countdown` (dua yang terakhir khusus untuk **membatalkan**: cuma `Lobby` yang bisa memulai fase `Loadout`) |
| `SelectLoadout` | C → S | `weaponId, difficultyId` | 2/detik | Hanya state `Lobby` dan `Loadout`, dari daftar `MatchRules.LOADOUT_STATES`; senjata dimiliki **menurut `ProgressionRules.ownedWeapons`**, jadi `Config.DEV_ALL_WEAPONS` ikut berlaku di sini kalau dinyalakan — hari ini flag itu `false` dan ketiga senjata sudah dimiliki lewat `Config.DEFAULT_DATA.weapons` ([bagian 4.2](#42-angka-patokan)), jadi penolakan "Senjata itu belum kamu miliki." tidak punya id yang bisa memicunya (SEC-02); tingkat terbuka. Di luar dua state itu ditolak dengan `ActionResult` "Loadout sudah terkunci sampai match selesai." |
| `Attack` | C → S | `Vector3` arah bidik | **20/detik** | `Vector3` yang bukan nol / NaN / inf; state `WaveActive`; pemain ada di `participants`; Core belum hancur; karakter hidup; cooldown senjata |
| `MoveIntent` | C → S | sikap badan yang diminta (`walk` / `sprint` / `crouch`) dan permintaan dash | lihat `MovementService` | Sikap badan yang **diminta** client; yang memutuskan server. `MoveRules.resolveStance` yang menolak sprint saat stamina habis, dan `MovementService` yang menulis `WalkSpeed` dan `JumpHeight` — jadi client yang mengirim `sprint` terus-menerus tidak lari lebih lama daripada staminanya mengizinkan. Nama sikap yang tidak dikenal jatuh ke `walk`, bukan ditolak. **Menggantikan `SetCrouch`**, yang dicabut bersama `CrouchService` pada 2026-10-26 |
| `EnemyHit` | S → C | `{ id, damage, position }` | — | Untuk efek saja — **belum ada yang memakainya**, lihat [bagian 5](#5-yang-sudah-diketahui-sebelum-playtest) |
| `BuyShopItem` | C → S | `itemId` | 2/detik | **Dimatikan.** Pemain ada di `participants` diperiksa **lebih dulu**, lalu `Config.MATCH_SHOP_ITEMS_ENABLED` — yang `false`, jadi peserta mana pun dibalas "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata." dan seluruh gerbang di bawahnya tidak pernah tersentuh. Gerbang itu masih utuh dan masih punya unit test-nya: state `Intermission`; toko tidak terkunci; item ada; jatah belum habis (**cuma `shop_barrier` yang masih punya jatah**); cash cukup untuk **harga sekarang**, bukan harga dasar |
| `ShopState` ★ | S → C | `{ open, locked, purchases, suspended }` | — | `suspended` = upgrade tim disandera Locker: pembeliannya masih tercatat di `purchases`, tapi pengalinya kembali ke dasar sampai boss mati. **Selama item toko dimatikan, `purchases` selalu kosong dan `suspended` tidak menyandera apa pun** — lihat catatan di [bagian 11](#11-toko-match-shop) |
| `MatchUpgradeState` ★ | S → C | `{ weaponId, level, path }` | — | Level dan alur yang berlaku **di match ini** untuk pemain itu, dikirim `FireClient`. Dikirim saat join, saat tiap upgrade diterima, dan saat `reset()` — jadi di awal match isinya selalu `level = 1, path = "none"`. Dibaca `MatchStore.getUpgradeState()`, dan itu satu-satunya sumber angka di panel toko: panel tidak menghitung level sendiri dari apa pun |
| `BossState` ★ | S → C | `{ bossId, hp, maxHp, alive }` | — | Disiarkan paling cepat tiap 0.2 detik dan cuma kalau HP-nya berubah |
| `ShowInfoCard` | S → C | `bossId` | — | Dikirim hanya ke peserta match |
| `UpgradeWeapon` | C → S | `weaponId, pathId?` | 2/detik | **Pemiliknya sekarang `ShopService`, bukan `ProgressionService`**, dan dibayar **cash** bukan koin. Gerbangnya, berurutan: pemain ada di `participants`; `weaponId` harus **sama persis dengan `data.equippedWeapon`** (kalau tidak: "Senjata itu bukan yang sedang kamu pakai.") — lalu `MatchUpgradeRules.canUpgrade`: toko tidak dikunci Locker; state **`Intermission`**; senjatanya ada; belum level maks; **pilihan alur yang sah** kalau upgrade ini mencapai titik percabangan; alur yang sudah terpilih **tidak bisa diganti sampai match itu selesai**; cash cukup. Urutan itu disengaja, dari yang paling tidak bisa diubah pemain ke yang paling bisa: kunci boss, state, level maksimum, **alur, baru cash** — "cash kurang" satu-satunya alasan yang bisa dibereskan dengan bermain, jadi menampilkannya saat yang sebenarnya salah adalah level maksimum membuat pemain menabung untuk sesuatu yang tidak akan pernah bisa dibeli. `pathId` opsional: argumen yang bukan string **dibuang jadi nil**, bukan membatalkan aksi. `pathId` di level 1-3 **diabaikan, tidak ditolak**, dan `ProgressionRules.pathToApply` — fungsi yang **sama** yang dipakai upgrade lobby — memastikan dia juga tidak tersimpan. Yang naik `matchWeapons` di ShopService, **bukan** `data.weapons[id].level`: umurnya satu match dan dibuang `ShopService.reset()` |
| `BuyWeapon` | C → S | `weaponId` | 2/detik | State `Lobby`; belum dimiliki; `acquire.method == "buy"`; harga terdefinisi; koin cukup |
| `CraftWeapon` | C → S | `weaponId` | 2/detik | State `Lobby`; belum dimiliki; `acquire.method == "craft"`; material cukup |
| `ActionResult` ★ | S → C | `{ action, ok, reason }` | — | — |
| `GetProfile` | C → S (function) | tidak menerima argumen | 2/detik | Selalu mengembalikan data pemain yang memanggil; yang kena throttle dibalas `nil` |
| `GetLeaderboard` | C → S (function) | `difficultyId` → `{ { userId, name, wave } }` atau `nil` | 2/detik | Tingkat kesulitan harus ada di `Difficulties` (`LeaderboardRules.normalizeDifficulty`) — id dari client dipakai **menyusun nama OrderedDataStore**, jadi string apa pun yang lolos berarti satu store baru per tebakan client. Yang kena throttle dan tingkat yang tidak dikenal sama-sama dibalas `nil`, bukan error. `OnServerInvoke`-nya **tidak pernah yield**: dia menjawab dari papan yang sudah ada di memori dan paling banyak **menjadwalkan** pembacaan ulang, dengan jarak minimum 15 detik per tingkat |

**`UpgradeWeapon` punya satu handler, dan itu bukan lagi yang di
`ProgressionService`.** Handler lobbynya masih ada dan masih benar, diparkir
sebagai `ProgressionService.upgradeFromLobby`, tapi `start()` **tidak
menyambungkannya ke remote mana pun**. Akibatnya untuk yang menjalankan test:
`R.UpgradeWeapon:FireServer(...)` dari state `Lobby` sekarang sampai ke
`ShopService`, yang menolaknya dengan **"Kamu bukan peserta match ini."** —
bukan "Upgrade cuma bisa di lobby.", karena `participants` kosong di `Lobby`.
Pesan lama itu tidak bisa dipicu dari mana pun lagi. Alasan pencabutannya,
yang penting kalau ada yang berniat menyambungkannya kembali "sementara", ada
di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match).

**`GetLeaderboard` sekarang terdaftar — bersama handler-nya, bukan
sebelumnya.** Urutan itu syarat, bukan kebetulan: `RemoteFunction` yang sudah
ada di `ReplicatedStorage` tapi belum punya `OnServerInvoke` membuat client
yang memanggilnya **menggantung selamanya**, tanpa error dan tanpa timeout.
Jadi namanya baru ditambahkan ke `FUNCTION_NAMES` di `Remotes.luau` pada
langkah yang sama dengan `LeaderboardService.start()`, yang memasang
handler-nya — dan `init.server.luau` memanggil `start()` itu **sebelum**
gerbang arena, supaya place tanpa `assets/Arena.rbxmx` tidak punya remote yang
terdaftar tanpa handler.

Harness tidak bisa menjaga pasangan itu secara langsung, dan itu perlu
disadari: `Remotes.luau` membuat Instance remote-nya di lingkup modul, jadi
`boot.remote.getLeaderboardAda` akan tetap hijau walaupun `start()` tidak
pernah dipanggil. Yang menjaganya baris log `[LeaderboardService] siap` di case
yang sama. Yang mengetesnya dengan tangan LB-00 dan SEC-08.

Seluruh remote C → S di tabel ini punya rate limit. `RequestAction` dan
`GetProfile` dulu tidak (temuan T6); registry-nya ada di `init.server.luau`, bukan
di service, karena wiring kedua remote itu juga di situ. Yang memeriksa
kelengkapannya adalah SEC-14.

### 4.2 Angka patokan

Semua dari `src/shared/Modules/`. Kalau balancing disetel ulang di M7, yang
diperiksa test case di bawah tetap **arah** perubahannya (naik / turun / monoton),
tapi angka di tabel ini harus ikut diperbarui.

**Senjata** (`Weapons.luau`, damage pada level 1):

| id | Nama | Jenis | Damage | Cooldown | Range | Proyektil | Didapat |
|---|---|---|---|---|---|---|---|
| `weapon_starter` | Patch Wrench | melee | 25 | 0.5 s | 12 stud | 1 | default |
| `weapon_ranged` | Packet Rifle | ranged | 14 | 0.25 s | 60 stud | 1 | beli 1500 koin |
| `weapon_boss_a` | Fork Bomb | ranged | 30 | 0.6 s | 45 stud | 3 | craft `material_a` x5 |

**Kolom "Didapat" menjelaskan isi `Weapons.luau`, bukan apa yang harus dilalui
pemain hari ini: ketiga senjata terbuka sejak awal, dan itu SEMENTARA**
(permintaan Daffa, 2026-10-25). `Config.DEFAULT_DATA.weapons` sekarang memuat
ketiganya di level 1 dengan `path = "none"`, jadi pemain baru lahir sudah
memiliki Patch Wrench, Packet Rifle, dan Fork Bomb sekaligus. Dua akibatnya
untuk baris test di bawah. Pertama, tombol **"Beli"** dan **"Craft"** di panel
lobby tidak akan pernah muncul lagi, dan penolakan yang menyebut harga atau
resep tidak akan pernah terbaca: `canBuy` dan `canCraft` memeriksa "sudah kamu
miliki" **lebih dulu** daripada metode dan harganya, jadi aturannya tidak
dihapus dan masih benar — cuma tidak tercapai. Kedua, baris senjata di panel
lobby **tidak lagi memuat "Level N/10"** sama sekali: sejak upgrade pindah ke
dalam match, tidak ada level permanen yang bisa ditampilkan di situ, dan
barisnya sekarang berbunyi `damage N · jarak dekat/jauh · 3 alur`. Tombol aksi
di baris senjata yang **sudah dimiliki** tidak mengirim apa pun — ketiganya
sudah dimiliki, jadi tombol itu tidak punya pekerjaan di lobby lagi.

Dilakukan lewat `DEFAULT_DATA` dan **bukan** lewat `Config.DEV_ALL_WEAPONS`, dan
bedanya bukan gaya. Flag itu memberi senjata di **memori** saja, sementara
`canUpgrade` membaca `data.weapons` langsung — lewat flag, senjatanya bisa
dipakai tapi upgrade-nya ditolak "belum kamu miliki" selamanya, yaitu senjata
gratis yang tidak bisa di-upgrade sama sekali dan separuh dari yang diminta.
Lewat `DEFAULT_DATA`, `DataSchema.reconcile` menuliskannya ke data pemain, jadi
senjatanya **benar-benar dimiliki**: bisa dipakai, bisa di-upgrade, dan ikut
tersimpan. Alasan lengkapnya beserta konsekuensi membalikkannya ada di komentar
`src/shared/Config.luau`. `acquire` di `Weapons.luau` sengaja **tidak**
disentuh — harga 1.500 untuk Packet Rifle dan resep `material_a` x5 untuk Fork
Bomb masih ada di data dan menunggu dinyalakan lagi.

Baris yang jadi **tidak bisa dijalankan** selama ini berlaku ditandai `BLOK` di
tempatnya masing-masing, dengan syarat menjalankannya ditulis di kolom
Prakondisi: MATCH-22, MATCH-23, PROG-10, PROG-12, PROG-13, dan PROG-18. SEC-06
dan SEC-07 tetap dijalankan tapi sebagian harapannya bergeser.

Level maksimum ketiganya 10. Damage level *n* = `baseDamage * (1 + 0.12*(n-1))` →
starter: 25, 28, 31, 34, 37, 40, 43, 46, 49, 52.

**Upgrade senjata pindah dari lobby ke dalam match, dan mata uangnya ikut
pindah.** Yang dibayar sekarang **cash**, di Toko Match, tiap jeda antar wave —
bukan koin permanen di lobby. Harganya `Balance.matchUpgradePrice(fromLevel)`:
base **150**, tumbuh **x1.35** tiap level. Sembilan langkah dari level 1 ke 10:

| Dari level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | Total |
|---|---|---|---|---|---|---|---|---|---|---|
| Harga (cash) | **150** | 202 | 273 | 369 | 498 | 672 | 908 | 1.225 | **1.654** | **5.951** |

Anggaran satu run penuh: **5.300** cash dari hadiah wave (per pemain, berapa pun
jumlah pemain — lihat di bawah) ditambah cash dari membunuh, yaitu sekitar
**1.394** solo dan **513** per orang di tim berempat. Jadi totalnya **6.694**
solo dan **5.813** berempat, melawan 5.951 untuk satu senjata penuh. Bacaannya:
**level 10 bisa dicapai dalam satu run, tapi cuma kalau hampir seluruh cash
ditumpahkan ke satu senjata** — dan di tim berempat bahkan itu pun kurang
beberapa ratus. Ada sembilan jeda antar wave dan sembilan kali upgrade, jadi
"satu upgrade tiap jeda" memang bentuk yang dituju, bukan kebetulan. Angka ini
**tebakan pertama yang menunggu playtest**; kalau terasa salah, yang digeser
`Balance.MATCH_UPGRADE_BASE_PRICE` dan `MATCH_UPGRADE_PRICE_GROWTH`, bukan
rumusnya.

Kurva upgrade **lobby** yang lama — `Balance.upgradePrice`, base 50 tumbuh 1.35,
yaitu **50, 67, 91, 123, 166, 224, 302, 408, 551** (total 1.982 koin) — masih
ada di `Balance.luau` dan masih benar, tapi **tidak dipakai satu pun jalur yang
hidup**: remote yang memanggilnya sudah tidak tersambung
([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)). Jangan memakai angka itu
sebagai harapan baris test mana pun selama upgrade hidup di dalam match.

**Satu fungsi yang menghasilkan stat senjata, dan cuma satu.** Angka di tabel di
atas dan kurva damage per level sekarang dibaca lewat
`Balance.weaponStats(def, save)`, yang mengembalikan
`{ damage, cooldown, range, projectiles, effects }` sekaligus.
`Balance.weaponDamage(def, level)` masih ada tapi cuma dipakai `weaponStats`
sebagai dasar kurva levelnya — dia bukan lagi jalan yang boleh dipakai pemanggil
untuk menghitung damage. Yang ikut berubah dan bisa dilihat saat playtest:
`collectTargets` di `CombatService` memakai `stats.range` dan `stats.projectiles`,
bukan `def.range` / `def.projectiles` lagi. Jadi jangkauan dan jumlah musuh yang
kena sekali serang datang dari jalur yang sama dengan damage-nya, dan satu
pemanggil tidak bisa lagi menerapkan alur ke damage saja tapi lupa ke cooldown —
selisih seperti itu tidak terlihat sampai ada yang mengukurnya dengan stopwatch.

**Pohon upgrade: level 1-10, dengan satu titik percabangan — dan sejak toko
upgrade pindah ke dalam match, yang mengikat cuma sampai match itu selesai.**
Bentuk pohonnya tidak disentuh sama sekali; yang berubah umurnya. Level dan alur
hidup di `matchWeapons` milik ShopService, dibuang `ShopService.reset()` saat
kembali ke `Lobby`, jadi **tiap match dimulai lagi dari level 1 tanpa alur**.
Titik percabangannya tetap level 4 (`Balance.PATH_BRANCH_LEVEL` = **4**):

| Level | Yang terjadi |
|---|---|
| 1, 2, 3 | damage generik +12% per level. Belum ada pilihan — ini masa percobaan |
| **4** | **titik percabangan**: pilih 1 dari 3 alur, mengikat sampai match ini selesai. Tingkat 1 alur itu terbuka |
| 5, 6 | damage generik |
| **7** | tingkat 2 alur yang sudah dipilih |
| 8, 9 | damage generik |
| **10** | tingkat 3 alur yang sudah dipilih |

Titik percabangannya di level 4 dan bukan level 1 supaya pemain pernah
**memakai** senjatanya sebelum dipaksa memilih. Ketiga level tingkat
alur (4, 7, 10) datang dari satu konstanta `TIER_LEVELS` di `Weapons.luau`, bukan
diulang sebagai literal per senjata, jadi ketiga senjata tidak bisa berbeda tanpa
ada yang menyadarinya.

Sembilan alur yang ada sekarang (`Weapons.luau`, kolom id adalah apa yang
disimpan `matchWeapons` di ShopService dan dikirim ke client lewat
`MatchUpgradeState.path` — **bukan** lagi `data.weapons[id].path`, yang masih
ada di skema data tapi tidak dibaca satu pun jalur yang hidup):

| Senjata | id | Nama alur | Tema |
|---|---|---|---|
| Patch Wrench | `a` | Ayunan Berat | Pukulan lebih jarang tapi jauh lebih sakit, lalu mengenai beberapa musuh sekaligus |
| Patch Wrench | `b` | Ayunan Cepat | Serangan beruntun yang memperlambat musuh yang kena |
| Patch Wrench | `c` | Bertahan | Bertahan di dekat Core: damage yang masuk ke kamu dikurangi |
| Packet Rifle | `a` | Sniper | Tembakan jarang, jangkauan sangat jauh, dan akhirnya menembus |
| Packet Rifle | `b` | Semburan | Tembakan sangat cepat dengan jangkauan yang dipendekkan |
| Packet Rifle | `c` | Dukungan | Menandai musuh supaya seluruh tim memberi damage lebih besar ke musuh itu — paling kuat di tim 3-4 orang, paling lemah solo |
| Fork Bomb | `a` | Shotgun | Banyak proyektil sekaligus, tapi harus dekat |
| Fork Bomb | `b` | Ledakan | Satu proyektil yang meledak dan mengenai musuh di sekitar titik kena |
| Fork Bomb | `c` | Jebakan | Titik kena meninggalkan zona yang memperlambat musuh yang melewatinya |

Id-nya cuma `a`, `b`, `c` dan **berulang antar senjata**: `path = "a"` di Patch
Wrench berarti Ayunan Berat, `path = "a"` di Packet Rifle berarti Sniper. Jadi
membaca `path` tanpa melihat senjata mana yang memuatnya tidak memberitahu apa
pun. Dan satu tempat yang sekarang **tidak** boleh dipakai memeriksanya:
`R.GetProfile:InvokeServer().weapons[...]` — alur yang dipilih di dalam match
tidak pernah sampai ke sana. Yang membawanya `MatchUpgradeState`, dan yang
menampilkannya judul panel toko.

**Sejak langkah 7 tiap tingkat alur benar-benar berlaku.** Sebelum ini ketiga
tingkat tiap alur cuma punya `level` dan `summary`, dan memilih alur mengunci
keputusan permanen tanpa memberi apa pun. Sekarang tiap tingkat membawa
`damageMult`, `cooldownMult`, `cooldown`, `range`, `projectiles`, atau `effects`,
dan `Balance.weaponStats` menerapkannya **berurutan dari tingkat terendah** ke
tingkat tertinggi yang levelnya sudah terbuka. Empat aturan penggabungan yang
menentukan setiap angka di tabel berikutnya, dan semuanya mudah terbaca salah:

- `damageMult` dan `cooldownMult` **menumpuk** (dikalikan ke hasil sebelumnya).
- `cooldown`, `range`, dan `projectiles` nilai **absolut** yang **ditimpa**
  tingkat yang lebih tinggi. Dalam satu tingkat, `cooldown` absolut diterapkan
  **sesudah** `cooldownMult`, jadi tingkat yang menulis `cooldown = 0.32` benar
  menghasilkan 0.32 dan bukan 0.32 dikali apa pun.
- kunci di `effects` **digabung per kunci**: yang tidak disebut tingkat
  berikutnya **dipertahankan**. Itu sebabnya Ayunan Cepat tingkat 3 cuma menulis
  `slowMult` dan `slowSeconds` tingkat 2 tetap berlaku.
- Lantai di akhir, di satu tempat: `cooldown` minimal **0.05**, `projectiles`
  minimal **1**, `damage` dan `range` tidak boleh negatif.

**Dasar kurva levelnya tidak berubah**: `baseDamage * (1 + 0.12*(level-1))`
dihitung lebih dulu, lalu pengali alur dikenakan ke hasil itu. Jadi damage dasar
di level 4 / 7 / 10 tetap 34 / 43 / 52 (Patch Wrench), 19.04 / 24.08 / 29.12
(Packet Rifle), dan 40.8 / 51.6 / 62.4 (Fork Bomb) sebelum alurnya menyentuhnya.

**Sembilan alur x tiga tingkat, dengan stat yang benar-benar berlaku.** Kolom
"Yang berubah di tingkat ini" adalah isi `WeaponPathTier`-nya apa adanya; kolom
"Stat jadi" adalah hasil `Balance.weaponStats` pada level tingkat itu, yaitu
angka yang bisa dihitung di muka sebelum playtest:

| Senjata | Alur | Tingkat (level) | Yang berubah di tingkat ini | Stat jadi di level itu |
|---|---|---|---|---|
| Patch Wrench | `a` Ayunan Berat | 1 (L4) | `damageMult` 1.5, `cooldownMult` 1.4 | damage **51**, cooldown **0.7 s**, range 12, proyektil 1 |
| Patch Wrench | `a` Ayunan Berat | 2 (L7) | `effects.coneMinCos` **-0.1** | damage **64.5**, cooldown **0.7 s**, range 12, proyektil 1, kerucut ~96° |
| Patch Wrench | `a` Ayunan Berat | 3 (L10) | `projectiles` 3 | damage **78**, cooldown **0.7 s**, range 12, proyektil **3**, kerucut ~96° |
| Patch Wrench | `b` Ayunan Cepat | 1 (L4) | `cooldown` **0.32** | damage **34**, cooldown **0.32 s**, range 12, proyektil 1 |
| Patch Wrench | `b` Ayunan Cepat | 2 (L7) | `effects.slowMult` 0.65, `slowSeconds` 1.5 | damage **43**, cooldown **0.32 s**, slow **x0.65 selama 1.5 s** |
| Patch Wrench | `b` Ayunan Cepat | 3 (L10) | `cooldown` **0.25**, `effects.slowMult` 0.5 | damage **52**, cooldown **0.25 s**, slow **x0.5 selama 1.5 s** |
| Patch Wrench | `c` Bertahan | 1 (L4) | `effects.damageTakenMult` 0.75 | damage **34**, cooldown 0.5 s, range 12, damage masuk **x0.75** |
| Patch Wrench | `c` Bertahan | 2 (L7) | `range` **18**, `damageMult` 1.2 | damage **51.6**, cooldown 0.5 s, range **18**, damage masuk x0.75 |
| Patch Wrench | `c` Bertahan | 3 (L10) | `effects.damageTakenMult` 0.55 | damage **62.4**, cooldown 0.5 s, range **18**, damage masuk **x0.55** |
| Packet Rifle | `a` Sniper | 1 (L4) | `damageMult` 1.8, `cooldownMult` 1.6 | damage **34.272**, cooldown **0.4 s**, range 60, proyektil 1 |
| Packet Rifle | `a` Sniper | 2 (L7) | `range` **90** | damage **43.344**, cooldown **0.4 s**, range **90** |
| Packet Rifle | `a` Sniper | 3 (L10) | `projectiles` 3 | damage **52.416**, cooldown **0.4 s**, range **90**, proyektil **3** |
| Packet Rifle | `b` Semburan | 1 (L4) | `cooldown` **0.15**, `damageMult` 0.8 | damage **15.232**, cooldown **0.15 s**, range 60 |
| Packet Rifle | `b` Semburan | 2 (L7) | `range` **40**, `damageMult` 1.1 | damage **21.1904** (0.8 x 1.1 = **x0.88** dari dasar), cooldown **0.15 s**, range **40** |
| Packet Rifle | `b` Semburan | 3 (L10) | `projectiles` 2, `cooldown` **0.12** | damage **25.6256**, cooldown **0.12 s**, range **40**, proyektil **2** |
| Packet Rifle | `c` Dukungan | 1 (L4) | `effects.markMult` 1.25, `markSeconds` 4 | damage **19.04**, cooldown 0.25 s, range 60 — tanda **x1.25 selama 4 s** |
| Packet Rifle | `c` Dukungan | 2 (L7) | `effects.markMult` 1.4 | damage **24.08**, tanda **x1.4 selama 4 s** |
| Packet Rifle | `c` Dukungan | 3 (L10) | `effects.markSpread` 2 | damage **29.12**, tanda x1.4 / 4 s, **menular ke 2 musuh terdekat** |
| Fork Bomb | `a` Shotgun | 1 (L4) | `projectiles` 5, `range` **30** | damage **40.8**, cooldown 0.6 s, range **30**, proyektil **5** |
| Fork Bomb | `a` Shotgun | 2 (L7) | `damageMult` 1.3 | damage **67.08**, cooldown 0.6 s, range **30**, proyektil **5** |
| Fork Bomb | `a` Shotgun | 3 (L10) | `projectiles` 7 | damage **81.12**, cooldown 0.6 s, range **30**, proyektil **7** |
| Fork Bomb | `b` Ledakan | 1 (L4) | `projectiles` 1, `effects.splashRadius` 8, `splashMult` 0.5 | damage **40.8**, cooldown 0.6 s, proyektil **1**, splash **8 stud x0.5 = 20.4** |
| Fork Bomb | `b` Ledakan | 2 (L7) | `cooldownMult` 0.8 | damage **51.6**, cooldown **0.48 s**, proyektil 1, splash 8 stud x0.5 = **25.8** |
| Fork Bomb | `b` Ledakan | 3 (L10) | `effects.splashRadius` 12, `splashMult` 0.75 | damage **62.4**, cooldown **0.48 s**, proyektil 1, splash **12 stud x0.75 = 46.8** |
| Fork Bomb | `c` Jebakan | 1 (L4) | `effects.zoneRadius` 8, `zoneSeconds` 3, `zoneSlowMult` 0.6 | damage **40.8**, cooldown 0.6 s, proyektil 3 — zona **8 stud, 3 s, slow x0.6** |
| Fork Bomb | `c` Jebakan | 2 (L7) | `effects.zoneRadius` 12, `zoneSlowMult` 0.45 | damage **51.6** — zona **12 stud, 3 s, slow x0.45** |
| Fork Bomb | `c` Jebakan | 3 (L10) | `effects.zoneDps` 6 | damage **62.4** — zona 12 stud, 3 s, slow x0.45, **6 damage/detik** |

Tiga hal di tabel itu yang paling mudah salah dibaca, dan ketiganya **benar**:
Ayunan Berat tingkat 2 dan 3 **tidak** menyentuh damage lagi, jadi damage-nya
tetap dasar x1.5 dari tingkat 1; Semburan tingkat 2 memberi `damageMult` 1.1
yang **menumpuk** di atas 0.8 tingkat 1 jadi x0.88, bukan menggantinya jadi
x1.1; dan Dukungan sama sekali **tidak** menaikkan damage senjatanya sendiri —
seluruh kekuatannya ada di tanda, yang berlaku untuk semua orang.

**Kosakata `effects`** (`Balance.PATH_EFFECT_KEYS`, dan ada unit test yang
menolak kunci di `Weapons.luau` yang tidak ada di daftar ini). Kolom "Dibaca di"
penting untuk mendiagnosis: kunci yang salah tulis tidak error, dia cuma tidak
pernah terbaca, dan gejalanya "alur itu tidak terasa":

| Kunci | Arti | Dibaca di |
|---|---|---|
| `coneMinCos` | ganti `Balance.MELEE_MIN_COS`; **lebih kecil = kerucut lebih lebar** | `CombatService.collectTargets`, saat `HitTest.inCone` |
| `slowMult` | pengali speed musuh yang **kena pukulan**, ikut dia ke mana pun | `CombatService.onAttack` → `EnemyService.applySlow` |
| `slowSeconds` | berapa lama slow pukulan itu bertahan | sama |
| `damageTakenMult` | pengali damage musuh yang masuk ke **pemain** pemakai senjata itu | `EnemyService` loop `step`, lewat `CombatService.getPlayerDamageTakenMult` yang disuntik di `init.server.luau` |
| `splashRadius` | radius ledakan dari titik kena | `CombatService.onAttack` → `CombatEffects.withinRadius` |
| `splashMult` | pengali damage untuk korban splash | sama |
| `markMult` | pengali damage ke musuh yang ditandai, **dari siapa pun** | `EnemyService.damage` |
| `markSeconds` | berapa lama tanda itu bertahan | `CombatService.onAttack` → `EnemyService.applyMark` |
| `markSpread` | berapa musuh terdekat ikut ditandai | `CombatService.onAttack` → `CombatEffects.nearest` |
| `zoneRadius` | radius zona yang ditinggalkan di titik kena | `CombatService.onAttack` → `EnemyService.addZone` |
| `zoneSeconds` | umur zona itu | sama |
| `zoneSlowMult` | pengali speed musuh **di dalam** zona, berhenti begitu dia keluar | `EnemyService` loop `step`, tiap frame |
| `zoneDps` | damage per detik dari zona | sama |

**Slow punya dua pasang kunci, dan itu bukan duplikasi.** `slowMult` /
`slowSeconds` menempel ke **MUSUH** yang kena pukulan dan ikut dia ke mana pun
dia jalan; `zoneSlowMult` / `zoneSeconds` menempel ke **TEMPAT** dan berhenti
begitu musuhnya keluar dari radius. Dua umur yang berbeda, jadi dua nama.
Keduanya bisa aktif sekaligus dan **dikalikan** di `step`: Ayunan Cepat tingkat 3
(x0.5) di atas zona Jebakan tingkat 2 (x0.45) membuat `basic` berjalan
`8 * 0.5 * 0.45` = **1.8 stud/detik**, dan itu disengaja — dua pemain yang
masing-masing membayar alurnya sendiri memang sedang menumpuk dua efek.

**Enam mekanik yang bisa salah dibaca sebagai bug**, dan semuanya keputusan:

1. **Dua slow yang bertumpuk: yang terkuat menang, dan yang terlama menang**
   (`CombatEffects.merge`). Pukulan lemah **tidak** membatalkan slow kuat yang
   masih aktif. Kalau "terbaru menang", Ayunan Cepat yang memukul tiap 0.25
   detik akan membuat musuh kadang melambat kadang tidak tanpa pola. Berlaku
   sama untuk tanda, cuma arah "lebih kuat"-nya terbalik: pengali lebih **besar**
   yang menang.
2. **Zona yang bertumpuk memakai slow terkuat, tapi dps-nya dijumlahkan.**
   Alasannya ada di komentar `CombatEffects.zoneSlowAt` dan `zoneDamageAt`: tiga
   zona slow 55% yang dikalikan jadi x0.091, yaitu musuh yang praktis berhenti
   dari tiga tembakan biasa, dan itu tidak dijanjikan satu pun tingkat alur.
   Damage satu-satunya efek yang penjumlahannya tidak menghasilkan keadaan
   ekstrem, jadi dua jebakan yang bertumpuk memang dua jebakan.
3. **Tanda menaikkan damage dari SIAPA PUN**, bukan cuma dari penandanya:
   pengalinya diterapkan di `EnemyService.damage`, jadi turret Toko Match,
   splash pemain lain, dan damage per detik zona semuanya ikut terkali. Itu yang
   membuat Dukungan **paling kuat di tim berempat dan paling lemah solo** — dan
   itu disengaja, dia memberi alasan mekanis untuk main bareng.
4. **Splash mengecualikan target yang sudah kena penuh.** Tanpa itu target utama
   kena dua kali — sekali penuh, sekali lagi dikali `splashMult` — dan damage
   senjatanya terlihat lebih besar daripada yang tertulis di panel.
5. **Zona dan splash cuma lahir dari serangan yang MENGENAI sesuatu.** Titik
   kenanya posisi musuh **pertama** yang kena, dibaca sebelum musuh itu
   di-damage. Tembakan ke udara tidak meninggalkan apa pun — kalau dia
   meninggalkan zona, pemain bisa melapisi seluruh lane tanpa membidik apa pun.
6. **`damageTakenMult` mengurangi damage, bukan menghentikan pukulan.** Jadwal
   pukulan musuh berikutnya **tetap** disetel walau pengalinya mengecilkan
   damage sampai hampir nol; musuh yang berhenti memukul juga tidak akan pernah
   terlihat menyerang. Pengali di luar rentang (0, 1] **diabaikan**
   (`CombatService.getPlayerDamageTakenMult` mengembalikan 1): nol berarti
   pemain tidak bisa mati, dan di atas 1 berarti alur bertahan yang justru
   menaikkan damage masuk — dua-duanya cuma bisa datang dari data alur yang
   rusak, dan dua-duanya tidak akan dilaporkan pemain yang diuntungkan.

**Dan satu kekurangan yang diketahui, bukan kelupaan: zona tidak kelihatan di
layar sama sekali.** `EnemyService` menyimpannya sebagai tabel Lua tanpa satu
Part pun, jadi tidak ada apa-apa yang terlihat di tempat zona berada — yang
dibutuhkan langkah 7 adalah efeknya bekerja, dan menggambarnya butuh Part dan
aset. **Jangan melaporkan ini sebagai bug.** Akibatnya untuk playtest: musuh
yang melambat dan kehilangan HP di tempat yang terlihat kosong adalah hal yang
benar (T15 di
[bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug)). Zona ikut
dibuang `EnemyService.clearAll()`, jadi dia tidak terbawa ke match berikutnya
(COMBAT-25).

**Angka turunan yang paling berguna saat playtest.** Semuanya dihitung dari
tabel di atas, dan semuanya bisa diperiksa dengan menghitung klik — jadi inilah
yang membuat "alurnya berlaku" bisa dinilai tanpa alat ukur.

Patch Wrench, tiga alur yang sama senjatanya, di tiga level tingkat alurnya:

| | L4 alur `a` | L4 alur `b` | L4 alur `c` | L7 `a` | L7 `b` | L7 `c` | L10 `a` | L10 `b` | L10 `c` |
|---|---|---|---|---|---|---|---|---|---|
| Damage | **51** | 34 | 34 | **64.5** | 43 | 51.6 | **78** | 52 | 62.4 |
| Cooldown | **0.7 s** | **0.32 s** | 0.5 s | 0.7 s | 0.32 s | 0.5 s | 0.7 s | **0.25 s** | 0.5 s |
| Damage/detik | 72.9 | **106.3** | 68 | 92.1 | **134.4** | 103.2 | 111.4 (x3 target) | **208** | 124.8 |
| Serangan untuk `basic` wave 1 (100 HP) | **2** | 3 | 3 | **2** | 3 | 2 | 2 | 2 | 2 |
| Serangan untuk `tank` wave 1 (400 HP) | **8** | 12 | 12 | **7** | 10 | 8 | **6** | 8 | 7 |

Baris `basic` wave 1 itu yang paling cepat dipakai dan juga yang paling mudah
menipu: di level 10 ketiga alur sama-sama **2** serangan, karena 100 HP terlalu
sedikit untuk memisahkan 52 dari 78. Yang memisahkan ketiganya di level 10
adalah `tank` (6 / 8 / 7) dan cooldown-nya. Di **level 4** `basic` sudah cukup:
**2 serangan untuk alur `a`, 3 untuk `b` dan `c`**, dan itu angka paling murah
untuk membuktikan alurnya sampai ke `CombatService`.

Pengurangan damage ke pemain, alur Patch Wrench `c` Bertahan. Kolom "tanpa
alur" sama dengan [aritmetika serangan](#42-angka-patokan) di atas:

| Penyerang | Damage/pukulan tanpa alur | Pukulan sampai mati tanpa alur | x0.75 (L4) | Pukulan | x0.55 (L10) | Pukulan |
|---|---|---|---|---|---|---|
| `basic` | 25 | 4 | 18.75 | **6** | 13.75 | **8** |
| `fast` | 15 | 7 | 11.25 | **9** | 8.25 | **13** |
| `tank` | 60 | 2 | 45 | **3** | 33 | **4** |
| Splitter | 80 | 2 | 60 | 2 | 44 | **3** |
| Locker | 120 | **1** | 90 | **2** | 66 | **2** |

Baris Locker yang paling tegas: tanpa alur dia membunuh pemain HP penuh dengan
**satu** pukulan, dan tingkat 1 Bertahan sudah membuatnya butuh **dua**. Baris
Splitter yang paling tumpul: **2** pukulan tanpa alur dan **2** juga di tingkat
1, jadi jangan memakai Splitter untuk menguji tingkat 1 — angka yang tidak
bergerak di situ bukan bukti apa pun.

Splash, alur Fork Bomb `b` Ledakan, terhadap `basic` wave 1 (100 HP):

| | Target utama | Korban splash | Radius | Serangan untuk target utama | Serangan untuk korban splash |
|---|---|---|---|---|---|
| L4 (x0.5) | **40.8** | **20.4** | 8 stud | 3 | 5 |
| L7 (x0.5) | **51.6** | **25.8** | 8 stud | 2 | 4 |
| L10 (x0.75) | **62.4** | **46.8** | 12 stud | 2 | 3 |

Tanda, alur Packet Rifle `c` Dukungan, terhadap `basic` wave 1 (100 HP). Urutan
di `onAttack` menentukan satu hal yang akan terlihat aneh: `EnemyService.damage`
dipanggil **sebelum** `applyMark`, jadi **tembakan yang memasang tanda itu
sendiri tidak ikut terkali** — yang terkali tembakan kedua dan seterusnya:

| | Damage senjata | Tembakan pertama (belum bertanda) | Tembakan berikutnya | Tembakan sampai `basic` mati | Tanpa tanda |
|---|---|---|---|---|---|
| L4 (tanda x1.25) | 19.04 | 19.04 | **23.8** | **5** | 6 |
| L7 (tanda x1.4) | 24.08 | 24.08 | **33.712** | **4** | 5 |
| L10 (tanda x1.4, menular 2) | 29.12 | 29.12 | **40.768** | **3** | 4 |

Dan karena tanda berlaku untuk semua sumber damage: turret Toko Match yang
memberi **12** memberi **15** ke musuh bertanda x1.25 dan **16.8** ke musuh
bertanda x1.4, dan satu zona Jebakan tingkat 3 yang memberi 6 dps memberi 8.4
dps di musuh bertanda x1.4.

Zona, alur Fork Bomb `c` Jebakan, terhadap musuh yang **berdiri diam** di dalam
zona sepanjang umurnya (3 detik):

| | Radius | Slow | Speed `basic` (8) di dalamnya | dps | Damage total kalau musuh tidak keluar |
|---|---|---|---|---|---|
| L4 | 8 stud | x0.6 | 4.8 | 0 | **0** |
| L7 | 12 stud | x0.45 | 3.6 | 0 | **0** |
| L10 | 12 stud | x0.45 | 3.6 | **6** | **18** |

Tingkat 1 dan 2 memberi **nol** damage, dan itu benar: dua tingkat pertama cuma
memperlambat. Musuh yang kehilangan HP dari zona cuma mungkin di level 10.

Kerucut melee, alur Patch Wrench `a` Ayunan Berat tingkat 2: ambangnya turun
dari `Balance.MELEE_MIN_COS` **0.2** (≈ **78.5°** setengah sudut) ke **-0.1**
(≈ **95.7°**). Jadi ayunannya mengenai musuh yang sudah **di belakang garis
samping** pemain, lebih dari separuh lingkaran di sekitarnya — dan arah
angkanya terbalik dari yang intuitif: **lebih kecil berarti lebih lebar.**

Jangkauan yang berubah, dengan toleransi uji kena-nya ikut dihitung. Melee
memakai `stats.range + Balance.MELEE_RADIUS_BONUS` (5 stud), ranged memakai
`stats.range` apa adanya dengan silinder radius 5 di sekitar garis bidik:

| Senjata dan alur | Range dasar | Range sesudah alur | Jangkauan efektif |
|---|---|---|---|
| Patch Wrench `c` L7 | 12 | **18** | 23 stud (melee, +5) |
| Packet Rifle `a` L7 | 60 | **90** | 90 stud |
| Packet Rifle `b` L7 | 60 | **40** | 40 stud |
| Fork Bomb `a` L4 | 45 | **30** | 30 stud |

Yang **tidak** berubah: baris `summary` tetap janji ke pemain. Panel pemilihan
alur menampilkannya apa adanya, dan pemain mengunci pilihan permanen
berdasarkan apa yang dia baca di situ — jadi `summary` yang menyebut angka yang
tidak dihasilkan `weaponStats` adalah **GAGAL**, bukan placeholder yang tidak
apa-apa. Semua angka di tabel di atas bisa dibandingkan baris per baris dengan
`summary`-nya di `Weapons.luau`, dan itu pemeriksaan yang bisa dilakukan tanpa
membuka Studio sama sekali.

**Serangan musuh, mekanismenya dulu.** Musuh punya **satu** angka serangan,
`attackDamage`, dan satu jadwal, `attackInterval`. Satu angka itu berarti dua hal
berbeda karena dikalikan dua pengali yang berbeda saat dipakai: ke base dikali
`Balance.BASE_DAMAGE_MULT` = **0.2**, ke player dikali
`Balance.PLAYER_DAMAGE_MULT` = **1.0**. Base punya 1000 HP, player 100 — jadi base
efektif 5000 HP, 50x lebih tahan, dan itulah yang membuat satu angka bisa
dipakai untuk dua sasaran. Pukulan **pertama** tidak menunggu interval:
`nextStrikeAt` lahir 0, jadi musuh memukul begitu dia menempel atau begitu
pemain masuk jarak pukul (6 stud), lalu tiap `attackInterval` sesudahnya.

`attackDamage` **tidak** dikali pengali apa pun selain dua di atas — tidak oleh
wave, tidak oleh jumlah player, dan **tidak oleh pengali difficulty**. Yang
dikali `hpMult` cuma HP musuh. Jadi `tank` di `hard` dengan 4 player tetap
men-damage base 12 per pukulan dan tetap membunuh pemain dalam 2 pukulan; yang
berubah cuma berapa lama dia bertahan.

**Musuh** (`Enemies.luau`, nilai dasar wave 1 / normal / 1 player):

| id | Nama | Analogi | HP | Speed | `attackDamage` | `attackInterval` | Damage ke base / pukulan | Cash | Bentuk graybox |
|---|---|---|---|---|---|---|---|---|---|
| `basic` | Pop-up Swarmling | Adware | 100 | 8 | 25 | 1.2 s | **5** | 5 | kubus oranye 3x3x3 |
| `fast` | Worm Runner | Worm | 60 | 16 | 15 | 0.8 s | **3** | 7 | balok hijau 2x2x4 |
| `tank` | Rootkit Hulk | Rootkit | 400 | 5 | 60 | 1.5 s | **12** | 15 | kubus ungu 6x6x6 |

**Boss** (`Bosses.luau`):

| id | Nama | Analogi | Wave | HP | `attackDamage` | `attackInterval` | Damage ke base / pukulan | Cash | Drop | Bentuk |
|---|---|---|---|---|---|---|---|---|---|---|
| `boss_splitter` | Splitter | Worm | 5 | 2500 | 80 | 2.0 s | **16** | 120 | `material_a` x1 | kubus merah 9x9x9 |
| `boss_locker` | Locker | Ransomware | 10 | 6000 | 120 | 2.0 s | **24** | 250 | `material_b` x1 | kubus merah 11x11x11 |

Splitter membelah di **66% dan 33%** HP, masing-masing memunculkan **4 `fast`**.
Locker memanggil **3 `basic` tiap 8 detik** dan mengunci toko selama hidup.

**Aritmetika serangan.** Angka mentah di dua tabel di atas tidak bisa dinilai
mata; yang bisa dinilai adalah dua bacaan turunannya. Keduanya dihitung dari
`attackDamage`, `attackInterval`, 100 HP player, dan 1000 HP base:

| Tipe | Pukulan membunuh player | Lama sampai player mati | DPS ke base | Pukulan dalam 60 detik | HP base hilang kalau 1 lolos sepanjang wave (~60 s) |
|---|---|---|---|---|---|
| `basic` | 4 | 3.6 s | 4.2 | 51 | ~255 (**26%**) |
| `fast` | 7 | 4.8 s | 3.8 | 76 | ~228 (**23%**) |
| `tank` | **2** | 1.5 s | 8.0 | 41 | ~492 (**49%**) |
| Splitter | **2** | 2.0 s | 8.0 | 31 | ~496 (**50%**) |
| Locker | **1** | 0 s | 12.0 | 31 | ~744 (**74%**) |

Pukulan membunuh player = `ceil(100 / attackDamage)`; lamanya =
`(pukulan - 1) * attackInterval`, karena pukulan pertama jatuh seketika — Locker
membunuh pemain dengan satu pukulan pada detik dia menyentuhnya. Pukulan dalam
60 detik = `1 + floor(60 / attackInterval)`, dan HP base yang hilang = angka itu
dikali kolom damage per pukulan.

Bacaannya, dan ini yang dipakai menilai apakah balancing-nya masih benar setelah
disetel ulang: **satu `basic` yang dibiarkan menempel sepanjang satu wave
memakan seperempat base, satu `tank` memakan separuh, dan tiga kebocoran yang
dibiarkan berarti kalah.** `tank` membunuh pemain dalam dua pukulan memang
kasar; yang mengimbanginya kecepatan 5 stud/detik, paling lambat di game, jadi
dia bisa dihindari.

**Profil target** (`Enemies.luau`, `targeting`). Yang menentukan apakah musuh
meninggalkan lane adalah `prefer`, bukan besar aggro-nya:

| Tipe | `prefer` | aggro | leash | Terlihat seperti |
|---|---|---|---|---|
| `basic` | base | 14 | 21 | jalan ke base, memukul pemain yang menghalangi **tanpa keluar lane** |
| `fast` | player | 25 | 37.5 | **keluar lane** memburu pemain, lalu kembali ke lane |
| `tank` | base | 8 | 12 | praktis tidak peduli pemain, lurus ke Core |
| Splitter, Locker | base | 10 | 15 | lurus ke base, memukul yang menghalangi di depan base |

Jarak pukulnya sendiri terpisah dari aggro dan sama untuk semua tipe:
`EnemyAI.STRIKE_RANGE` = **6 stud**, horizontal (melompat tidak melepaskan
musuh). Dan satu aturan yang mengikat semuanya: **musuh yang sudah menempel di
base tidak bisa ditarik keluar lagi** — `attacking_base` tidak punya jalan
keluar selain mati, jadi berdiri di sebelahnya tidak akan menunda kerusakan.

**Toko Match sekarang menjual UPGRADE SENJATA, bukan item.** Yang ditawarkan
tiap jeda antar wave cuma satu hal: menaikkan satu level senjata yang sedang
dipakai pemain itu, beserta ketiga alurnya, dibayar cash dengan kurva harga di
atas. Panelnya satu baris, bukan daftar — fase `Loadout` sudah mengunci senjata
yang dipakai sampai match selesai, jadi tidak pernah ada lebih dari satu senjata
yang bisa di-upgrade di situ. Isinya: judul **"Nama · level N/10"**, baris
status **"N cash"**, baris detail **"damage X · jeda Y · jangkauan Z"** dengan
baris kedua **"sesudah upgrade: ..."**, dan satu tombol **"Upgrade — N cash"**.
Di titik percabangan (level 4) tombol itu diganti **tiga kartu alur berjajar**,
masing-masing dengan tombol **"Pilih <nama alur>"**.

**Kelima item di tabel berikut DIMATIKAN** lewat
`Config.MATCH_SHOP_ITEMS_ENABLED = false`, dan penolakannya **di server**
(`ShopService.onBuy`), bukan cuma panelnya yang disembunyikan: client yang
dimodifikasi tetap bisa menembakkan `BuyShopItem`, dan fitur yang masih bisa
dibeli lewat remote bukan fitur yang dimatikan. Definisi item, `ShopRules`,
efeknya, dan unit test-nya **dibiarkan utuh dan masih lulus** — yang mati
pintunya. Tabel di bawah dan seluruh kurva harganya tetap ditulis di sini
karena dia yang berlaku lagi begitu flag itu `true`, dan karena sebelas baris
test di bawah menilai angka-angka ini.

**Toko Match** (`ShopItems.luau`, urutan tampil dari `ShopItems.order`) —
**dimatikan, lihat di atas**:

| # | id | Nama | Harga dasar | Maks beli | Efek |
|---|---|---|---|---|---|
| 1 | `shop_damage_up` | Exploit Patch | 200 | **tak terbatas** | Damage semua pemain **+10% per pembelian, linear** |
| 2 | `shop_fire_rate` | Overclock | 200 | **tak terbatas** | Cooldown semua pemain **-8% per pembelian, linear**, lantai 0.4x |
| 3 | `shop_core_repair` | Hotfix | 150 | **tak terbatas** | Pulihkan **15% dari 1000 = 150 HP** Core, **langsung saat dibeli** |
| 4 | `shop_barrier` | Firewall Block | 100 | **5** | Tahan musuh di **semua lane** 6 detik per pembelian, berlaku **wave berikutnya** |
| 5 | `shop_turret` | Scanner Turret | 250 | **tak terbatas** | Turret: 12 damage tiap 1 detik, radius 70 stud, mengelilingi Core |

**Yang membatasi pembelian sekarang harga, bukan jumlahnya.** Empat dari lima
item di atas dulu punya jatah (5, 5, 3, dan 2); jatah itu dihapus dan diganti
harga yang naik `x1.25` tiap kali **item yang sama** dibeli:
`harga = floor(harga_dasar * 1.25^jumlah_yang_sudah_dibeli)`. Harga satu item
tidak terpengaruh pembelian item lain — sepuluh Exploit Patch tidak menaikkan
harga Scanner Turret sama sekali. Rumusnya ditulis di sini supaya angka di tabel
berikut bisa dihitung ulang kalau `Balance.SHOP_PRICE_GROWTH` atau harga dasarnya
disetel di M7, bukan dihafal:

| Pembelian ke- | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Exploit Patch / Overclock (200) | 200 | 250 | 312 | 390 | 488 | 610 | 762 | 953 | 1192 | 1490 |
| Hotfix (150) | 150 | 187 | 234 | 292 | 366 | 457 | 572 | 715 | 894 | 1117 |
| Scanner Turret (250) | 250 | 312 | 390 | 488 | 610 | 762 | 953 | 1192 | 1490 | 1862 |
| Firewall Block (100) | 100 | 125 | 156 | 195 | 244 | — | — | — | — | — |

Sepuluh Exploit Patch berturut-turut memakan **6.647** cash, bukan 2.000 (harga
dasar x10). Yang 3 lebih rendah dari jumlah geometris eksaknya (6.650,58)
bukan salah hitung: harga dibulatkan ke bawah **setiap** pembelian, bukan sekali
di akhir, dan 6.647 itu yang benar-benar dipotong dari kolam. Cash diperiksa
terhadap harga **sekarang**, bukan harga dasar: cash tepat satu di bawahnya
ditolak, cash tepat sebesarnya diterima. Dan **tombol di panel toko menampilkan
harga sekarang** — tombol yang masih menulis harga dasar sementara cash
terpotong lebih banyak adalah GAGAL, bukan pembulatan.

**`shop_barrier` satu-satunya yang batasnya dipertahankan**, dan itu disengaja.
Empat item lain menambah **kemampuan**, yang tetap harus dipakai pemain; yang ini
menambah **waktu musuh tertahan**, 6 detik per pembelian di semua lane. Dua puluh
tumpuk berarti 120 detik tahan dan wave-nya lewat tanpa pemain menyentuh apa pun,
jadi harga yang naik tidak menolong — yang dibeli bukan kekuatan melawan wave,
tapi penghapusan wave itu sendiri. Alasan ini ada di komentar `ShopItems.luau`.
Lima Firewall Block memakan **820** cash, dan pembelian ke-6 ditolak — bukan
dengan "Cash tim kurang", walaupun harganya kalau jatahnya ada akan 305.

**Cash sekarang PER PEMAIN, bukan satu kolam tim.** Itu berubah bersama toko
upgrade, dan alasannya ada di bentuk barangnya: upgrade senjata milik satu
orang, jadi kalau empat pemain berbagi satu kolam untuk barang pribadi, tiap
orang cuma kebagian seperempat dan yang paling cepat menekan tombol memakai
uang bersama untuk dirinya sendiri. Tiga akibatnya yang langsung terlihat saat
test:

- **Saldo di keempat client berbeda-beda**, dan itu benar. `MatchCoins` dikirim
  `FireClient`, bukan `FireAllClients` (tabel remote di
  [bagian 4.1](#41-remote-yang-benar-benar-terdaftar)). Baris test yang dulu
  menuntut "angkanya sama di keempat client" sekarang menuntut yang
  **sebaliknya**.
- **Cash dari musuh yang mati masuk ke YANG MEMBUNUHNYA** (`EnemyService.onDied`
  membawa `Player?`). Musuh yang mati **tanpa pembunuh yang bisa ditunjuk** —
  zona jebakan, turret, mekanik boss — dibayarkan ke **semua peserta**:
  membiarkannya hangus berarti alur Jebakan menghasilkan lebih sedikit cash
  justru karena dia bekerja sendiri, dan itu menghukum alur yang dipilih pemain.
- **Hadiah per wave dibayarkan ke tiap peserta**, masing-masing sebesar angka
  penuh di tabel di bawah — bukan satu angka yang dibagi.

**Hadiah cash per wave** (`Balance.waveCash(wave, isBossWave)`). Ini **bukan**
koin permanen: dia masuk ke cash yang habis tiap match dan di-reset tiap
`Countdown`. Rumusnya `200 + 50 * (wave - 1)`, lalu **wave boss dikali 2** —
dan **tidak ada lagi pengali jumlah pemain**. Wave boss dikenali dari `bossId`
di `Waves.luau`, bukan dari daftar nomor wave, jadi boss baru yang ditambahkan
nanti ikut terkali dua tanpa menyentuh `Balance.luau`.

| Wave | 1 | 2 | 3 | 4 | 5 (boss) | 6 | 7 | 8 | 9 | 10 (boss) | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Hadiah per pemain | 200 | 250 | 300 | 350 | **800** | 450 | 500 | 550 | 600 | **1300** | **5.300** |

Angka itu **sama untuk solo, duo, dan tim berempat**: 5.300 per pemain, berapa
pun jumlah mereka. Pengali jumlah pemain yang dulu ada (solo x4, duo x2, sisanya
x1) **dihapus bersama `Balance.waveReward` dan `Balance.playerCountMultiplier`**
— ada unit test yang memeriksa kedua nama itu memang sudah hilang. Gunanya dulu
menyamakan kolam **tim** lintas jumlah pemain; sekarang yang disamakan anggaran
**per pemain**, dan itu sudah tercapai tanpa pengali. Jadi angka 21.200 solo /
10.600 duo / 5.300 berempat yang pernah ditulis di dokumen ini **tidak berlaku
lagi di mana pun**.

Hadiah diberikan **juga untuk wave terakhir** (wave 10), sebelum match
dinyatakan menang. Tiap pemberian mencetak satu baris di Output server, dan
teksnya ikut berubah:
`[ShopService] hadiah wave N: X cash untuk tiap peserta`.

**Kesulitan** (`Difficulties.luau`): `normal` hpMult 1.0 / rewardMult 1.0, terbuka
default. `hard` hpMult **1.8** / rewardMult **1.6**, terbuka setelah first clear
`normal`.

**Konstanta lain** (`Balance.luau`): Core HP 1000. Maks musuh aktif sekaligus
**40**, sisanya masuk antrian. Jeda antar spawn 0.9 detik. **Loadout 20 detik**,
Countdown 10 detik, Intermission 20 detik, layar hasil 10 detik.

Empat angka itu milik `MatchService`, bukan `Balance.luau`
(`MatchService.LOADOUT_SECONDS`, `.COUNTDOWN_SECONDS`, `.INTERMISSION_SECONDS`,
`.ENDED_SECONDS`), dan yang baru cuma yang pertama: **`Lobby -> Loadout (20 s)
-> Countdown (10 s) -> WaveActive`**, jadi dari menekan Ready sampai musuh
pertama muncul sekarang **30 detik**, bukan 10. Rancangan menyebut rentang
15-20 dan yang dipakai batas atasnya, dengan alasan yang ditulis di komentar
konstanta itu: fase ini harus cukup untuk **empat** pemain membaca tiga baris
senjata dan memilih, bukan cuma satu — dan biaya dari terlalu panjang cuma
menunggu, sementara biaya dari terlalu pendek adalah pemain masuk match dengan
senjata yang bukan pilihannya. Baris boot `[MatchService] siap, ...` tetap
cuma menyebut countdown dan intermission (BOOT-01), jadi 20 detik Loadout
tidak bisa diperiksa dari Output — yang memeriksanya MATCH-02 dan MATCH-11.

Toleransi uji kena: melee radius +5 stud di luar `range` dengan kerucut
`cos >= 0.2` (~78 derajat setengah sudut), ranged silinder radius 5 stud di
sekitar garis bidik. Angka kerucut itu **defaultnya**, bukan satu-satunya:
`CombatService.collectTargets` memakai `stats.effects.coneMinCos` kalau alur
senjatanya menyetelnya, dan Patch Wrench alur `a` tingkat 2 menurunkannya ke
-0.1 (~96 derajat). `range` juga dibaca dari `stats.range`, bukan `def.range`,
jadi tiga alur menggesernya (lihat tabel jangkauan di atas).

**Jumlah musuh biasa per wave** = `floor(6 + 2*wave*(1 + 0.25*(player-1)))`:

| Wave | 1 player | 2 player | 3 player | 4 player |
|---|---|---|---|---|
| 1 | 8 | **8** | 9 | 9 |
| 2 | 10 | 11 | 12 | 13 |
| 5 | 16 | 18 | 21 | 23 |
| 10 | 26 | 31 | 36 | **41** |

Dua angka yang ditebalkan itu penting dan dua-duanya bikin test case lama salah.
Di **wave 1, solo dan 2 player sama-sama 8 musuh** (pembulatan ke bawah dari
8.5), jadi test "2 player musuhnya lebih banyak" tidak boleh dilakukan di wave 1.
Dan **cuma wave 10 dengan 4 player (41) yang melewati batas 40 musuh aktif** —
wave 8 dan 9 dengan 4 player cuma 34 dan 37, jadi antrian spawn tidak bisa
diamati di sana.

**Serangan yang dibutuhkan untuk membunuh satu `basic`** dengan `weapon_starter`
level 1 (25 damage), solo normal: wave 1 = **4**, wave 2 = 5, wave 5 = 7,
wave 10 = 10. Dengan 2 player di wave 1 = 6; dengan 4 player = 9; di `hard`
wave 1 = 8.

Di wave 1 solo normal (`basic` 100 HP) ketiga senjata cuma memberi **dua** angka
yang berbeda, dan itu yang menentukan senjata mana yang bisa dipakai menguji
pergantian loadout: `weapon_starter` 25 damage = **4** serangan,
`weapon_ranged` 14 damage = **8**, `weapon_boss_a` 30 damage = **4**. Angka itu
yang dipakai membuktikan pergantian senjata
benar-benar sampai ke perhitungan damage (MATCH-18, MATCH-22) — dan juga
sebabnya Fork Bomb **tidak boleh** dipakai untuk itu: 4 serangan, sama dengan
starter, jadi senjata yang diam-diam jatuh ke starter akan terlihat lulus.
Rumusnya `ceil(hp / damage)`; `projectiles` tidak mengubahnya, karena jumlah
proyektil menentukan berapa **musuh** yang kena sekali serang, bukan berapa
damage yang masuk ke satu musuh. Ketiga angka itu dibaca dari
`Balance.weaponStats`, jadi **ketiganya cuma berlaku untuk senjata level 1 sampai
3** — yaitu senjata yang belum melewati titik percabangan. Sejak langkah 7 tiap
tingkat alur benar-benar menggeser damage, cooldown, jangkauan, atau jumlah
proyektil, jadi hitungan serangan di atas **tidak** lagi berlaku apa pun alur
yang dipilih pemain: untuk level 4 ke atas pakai tabel per alur di atas. Dua
akibat praktis untuk baris test di bawah: MATCH-18 dan MATCH-22 harus dijalankan
dengan senjata yang masih **level 1** supaya angka 4 dan 8 itu yang berlaku, dan
baris mana pun yang menghitung serangan pada level 4 atau lebih harus menyebut
alur mana yang terpilih.

**Reward akhir match**: koin = `floor((10*wave + (menang ? 50 : 0)) * rewardMult)`,
XP = `20*wave + (menang ? 100 : 0)`. XP **tidak** dikali rewardMult. Jadi wave 10
menang di normal = **150 koin + 300 XP**; di hard = **240 koin + 300 XP**; wave 4
kalah/keluar = **40 koin + 80 XP**. Kurva level: XP untuk naik dari level *n* =
`floor(100 * 1.25^(n-1))` → 100, 125, 156, 195, 244, ...

## 5. Yang sudah diketahui sebelum playtest

Verifikasi dokumen ini terhadap kode menemukan tujuh hal yang akan membuat test
case di bawah gagal **sebelum Studio dibuka sekali pun**. Lima di antaranya sudah
ditutup di `src/` (commit `4a2a84c`); dua sisanya ternyata bukan temuan sama
sekali, tapi keputusan yang disengaja. Ketujuhnya tetap dicatat di sini supaya
yang menjalankan test tidak membuang waktu mendiagnosis ulang, dan supaya tidak
ada yang menulis "GAGAL, penyebab tidak diketahui" untuk sesuatu yang sudah
dijelaskan.

Sejak itu empat hal berubah besar: perilaku musuh (`docs/ARENA_REDESIGN.md`
bagian 4 dan 5), ekonomi cash (bagian 6), fase `Loadout` beserta ketiga senjata
yang terbuka sejak awal (bagian 2, dan [bagian 4.2](#42-angka-patokan) untuk
cara yang dipakai sekarang), dan pohon tiga alur upgrade beserta isi efek
tiap tingkatnya (bagian 3 dan lampiran A). **Langkah 1 sampai 7 sudah mendarat,
jadi seluruh rancangan ulang arena selesai** (`docs/STATUS.md`).
Sembilan akibatnya **pasti** terlihat salah waktu dimainkan padahal benar — satu
di antaranya terlihat seperti game yang menggantung, satu seperti harga toko yang
berubah sendiri, satu seperti tombol Ready yang tidak jalan, satu seperti senjata
yang rusak justru sesudah di-upgrade, satu seperti musuh yang kehilangan HP tanpa
ada yang menyerangnya, dan satu seperti damage yang berbeda ke musuh yang sama
tanpa sebab. Itu
[bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug),
dan di antara seluruh bagian 5 itulah yang paling perlu dibaca sebelum Studio
dibuka.

### 5.1 Temuan yang sudah ditutup

Baris-baris di bawah **tidak lagi berlaku**. Disimpan dengan perbaikannya karena
beberapa test case di bawah ditulis untuk kondisi lamanya, dan karena kalau salah
satunya muncul lagi, itu regresi — bukan temuan baru.

| # | Temuan | Yang diperbaiki | Akibatnya sekarang |
|---|---|---|---|
| T1 | **`MatchResult` ditembakkan dua kali, yang kedua berisi nol.** `src/server/init.server.luau` masih menyambung `MatchService.onMatchEnded` dan mengirim payload `coins = 0, xp = 0, materials = {}, unlocked = {}` — sisa M2, waktu RewardService belum ada. `RewardService` mengirim payload yang benar lewat sinyal yang sama, dan tersambung lebih dulu. `Signal.Fire` menjalankan handler dalam urutan penyambungan, dan `ResultController.show()` menimpa isi layar tiap kali payload datang. Jadi yang dilihat pemain adalah yang NOL. | Blok sisa M2 dihapus dari `init.server.luau`, beserta komentar yang menjelaskan kenapa angkanya nol — komentar itu sudah tidak berlaku. Sekarang cuma `RewardService` yang mengirim `MatchResult`. | Layar hasil menampilkan angka yang sama dengan print `[RewardService]` dan dengan header panel lobby. PROG-01 sampai PROG-04, PROG-06, PROG-07, BOSS-09, dan HUD-02 menilai layar hasil apa adanya. Kalau layar hasil dan header lobby **berbeda**, itu temuan baru: dua jalur yang menghitung tidak sama. |
| T2 | **Kunci toko Locker tidak bisa dilihat dari UI, dan pesan penolakannya tidak pernah terpakai.** Panel toko hanya muncul saat state `Intermission`; Locker cuma hidup saat `WaveActive`; dan wave tidak bisa dinyatakan bersih selama boss hidup — jadi tidak pernah ada Intermission sambil Locker hidup. Selain itu `ShopRules.canBuy` memeriksa state **sebelum** `locked`, jadi penolakan saat Locker hidup selalu berbunyi "Toko cuma buka saat jeda antar wave.", bukan "Toko dikunci. Kalahkan boss-nya dulu." | Dua-duanya: `ShopRules.canBuy` memeriksa `locked` **sebelum** `state`, dan panel toko ikut terlihat saat `ShopState.locked` — bukan cuma saat `Intermission`. Dua unit test baru di `tests/ShopRules.spec.luau` mengunci urutan yang sekarang. | SHOP-10 ditulis ulang: kuncinya sekarang dibuktikan langsung dari panel toko, tanpa listener di command bar. SHOP-14 diberi pengecualian — "panel tidak terlihat di luar `Intermission`" sekarang berlaku **kecuali** saat toko dikunci. **Lanjutannya:** membuat kuncinya terlihat menyelesaikan masalah UI, tapi tidak masalah yang lebih dalam — kunci itu tetap tidak menolak apa pun, karena toko memang sudah tertutup saat `WaveActive` dan wave 10 tidak punya `Intermission` sesudahnya. Mekaniknya diganti: Locker sekarang **menyandera upgrade tim yang sudah dibeli** (`ShopState.suspended`), yang menggigit tepat di `WaveActive` tempat dia hidup. Lihat baris "Mekanik Locker" di [bagian 20](#20-keputusan-yang-diambil-tanpa-menanyakan-dulu), dan SHOP-16. |
| T3 | **`ActionResult` untuk `BuyShopItem` tidak ditampilkan di mana pun.** Satu-satunya yang mendengarkan `ActionResult` adalah `LobbyController`, dan panel lobby disembunyikan di luar state `Lobby`/`Countdown` — sejak fase `Loadout` ada, di luar `Lobby`/`Loadout`/`Countdown`. | `ShopController` punya pendengarnya sendiri dan menampilkan alasannya di baris status panel toko. Dua-duanya menyaring lewat `payload.action` supaya tidak saling menampilkan balasan milik panel lain. Pesannya ditahan 4 detik dengan penanda waktu: `MatchState` dikirim tiap 0.2 detik dan tiap paketnya memanggil `render()`, jadi tanpa penahan itu pesan hilang sebelum selesai dibaca — termasuk yang di `LobbyController`, yang selama ini memang tidak pernah terbaca. | Penolakan pembelian terlihat pemain **di setiap kondisi yang bisa dia capai dengan mengklik**: saat panel terlihat (`Intermission` atau toko terkunci). Penolakan di luar itu (SHOP-07 di `WaveActive` biasa, SHOP-08 di `Lobby`, SHOP-13 bukan-peserta) cuma bisa dipicu lewat remote manual — tidak ada tombol di sana — jadi baris-baris itu tetap memakai listener di command bar. |
| T5 | **Durasi penghalang tidak konsisten antara blokir dan visualnya.** Lane diblokir `6 detik x jumlah pembelian`, tapi Part dindingnya dihapus setelah 6 detik saja. | Durasinya dioper dari `applyBarriers` ke `placeBarrier`, jadi dinding dan blokirnya memakai angka yang sama. | SHOP-05 mengharapkan dinding hilang **tepat** saat musuh mulai jalan lagi: 6 detik untuk satu pembelian, 12 detik untuk dua. |
| T6 | **`RequestAction` dan `GetProfile` belum punya rate limit.** | Keduanya lewat registry `RateLimit` di `init.server.luau` dengan batas 2/detik, dengan `RateLimit.forget` di `Players.PlayerRemoving`. `GetProfile` itu RemoteFunction, jadi yang kena throttle dibalas `nil` — `ProfileStore` di client sudah memperlakukan balasan nil sebagai "data belum ada" dan tetap menunggu `DataLoaded`. | SEC-09 dan SEC-10 mengharapkan throttle. SEC-14 sekarang **LULUS**: seluruh remote C → S punya rate limit. |

### 5.2 Yang kelihatan salah tapi disengaja

Dua baris ini **bukan bug dan tidak akan diperbaiki di v1**. Dicatat supaya tidak
ada yang melaporkannya sebagai temuan baru setiap kali dokumen ini diisi.

| # | Perilaku | Kenapa begitu |
|---|---|---|
| T4 | **`EnemyHit` diterima client lalu dibuang.** `init.client.luau` menyambungnya dengan handler kosong. | Efek hit masuk di M7 (`FxController`). Sampai itu ada, tidak ada efek hit dan tidak ada angka damage sama sekali; satu-satunya umpan balik serangan adalah bar HP musuh turun. COMBAT-01 sudah disesuaikan. |
| T7 | **`BindToClose` sengaja tidak jalan di Studio** (`PlayerDataService` langsung `return` kalau `RunService:IsStudio()`). | "Stop di Studio memicu BindToClose" salah; yang menyimpan saat Stop adalah `PlayerRemoving`. DATA-06 dipecah jadi dua baris, dan jalur BindToClose-nya berkode `LIVE`. |

### 5.3 Perilaku baru yang akan terlihat seperti bug

Empat belas baris di bawah datang dari enam perubahan yang berbeda, dan semuanya
cuma masuk akal kalau mekanisme sebelumnya dibaca dulu. Perubahan keempat
menyumbang tiga baris sendiri (T14, T15, T16), karena langkah 7 mengubah arahnya:
baris T14 yang lama mencatat alur yang **tidak** melakukan apa-apa, dan sekarang
yang perlu dicatat justru sebaliknya.

**Perubahan pertama — musuh yang lolos.** **Dulu** musuh yang mencapai ujung lane
men-damage Core sekali sebesar `coreDamage` lalu dihapus dari arena; kebocoran
berarti kehilangan HP satu kali, dan arena **dijamin** bersih cepat atau lambat.
**Sekarang** musuh yang mencapai ujung lane berhenti di base, mengambil satu slot
cincin di sekitar Core, tetap hidup, dan memukul tiap `attackInterval` detik
sampai pemain membunuhnya — dan musuh juga bisa memukul dan membunuh pemain.
Dua jaminan lama hilang karena itu, dan keduanya hilang **dengan sengaja**;
akibatnya T8, T9, dan T10.

**Perubahan kedua — ekonomi cash.** **Dulu** cash cuma datang dari
musuh yang mati, 5 sampai 15 per musuh, dan seluruh isi toko dibatasi jumlah
pembelian: harga satu item tidak pernah berubah, dan tiap tombol memuat sisa
jatahnya. **Sekarang** tiap wave yang selesai memberi hadiah cash yang beberapa
kali lebih besar daripada seluruh cash dari musuh wave itu, dan empat dari lima
item toko tidak punya jatah lagi — yang membatasinya harga yang naik x1.25 tiap
kali item yang sama dibeli. Keduanya satu paket: hadiah besar tanpa harga yang
naik berarti toko habis diborong di wave 3-4, dan harga yang naik tanpa hadiah
besar berarti pembelian kedua tidak akan pernah terjangkau. Itu T11 dan T12 —
dan T11 cuma bisa dilihat lagi kalau item tokonya dinyalakan, karena perubahan
**kelima** di bawah mematikan kelimanya.

**Perubahan ketiga — fase `Loadout`.** **Dulu** state machine-nya
`Lobby -> Countdown -> WaveActive`: begitu semua pemain Ready, hitung mundur 10
detik langsung jalan, dan panel lobby tetap terlihat sepanjang `Countdown`
dengan **seluruh** tombolnya mati bersama-sama — kesulitan, "Pakai", dan
"Upgrade/Beli/Craft". Satu-satunya tempat memilih senjata adalah `Lobby`, jadi
yang dipakai match adalah apa pun yang terpilih sebelum Ready. **Sekarang** ada
satu fase di antaranya, `Loadout` 20 detik, dan tombolnya tidak lagi mati
bersama: selama fase itu tombol kesulitan dan "Pakai" **hidup** sementara
"Upgrade/Beli/Craft" **mati**, lalu di `Countdown` semuanya mati dan loadout
terkunci sampai match selesai. Itu T13.

**Perubahan keempat — pohon tiga alur upgrade, dan sejak langkah 7 isi
efeknya.** **Dulu** upgrade senjata adalah satu tombol, satu harga, dan satu
akibat: level naik satu, damage naik 12%, dan itu seluruh ceritanya. Tidak ada
keputusan di dalamnya — pemain yang punya koin menekan tombolnya, dan tidak ada
cara menekannya dengan salah. **Lalu langkah 6** menambahkan keputusan permanen
di level 4 tapi belum mengisinya: tingkat alurnya ada di `Weapons.luau` sebagai
nama, tema, dan tiga baris `summary`, tanpa satu angka stat, jadi memilih alur
mengunci keputusan terbesar di seluruh progres permanen lalu tidak mengubah apa
pun yang bisa diukur. **Sekarang langkah 7 mengisinya, dan arah masalahnya
terbalik.** Tiap tingkat benar-benar berlaku — damage, cooldown, jangkauan, dan
jumlah proyektil bisa bergeser **besar** di satu level — dan empat mekanik baru
masuk ke arena bersamanya: slow yang menempel ke musuh, zona yang menempel ke
tempat, tanda yang menaikkan damage dari siapa pun, dan pengurangan damage yang
masuk ke pemain. Tiga di antaranya **tidak punya satu pun tanda visual**, jadi
yang dilihat pemain adalah akibat tanpa sebab. Itu T14, T15, dan T16.

**Perubahan kelima — Toko Match tidak menjual item lagi, dia menjual upgrade
senjata.** **Dulu** toko menjual lima item berefek **tim** dari satu kolam cash
**tim**, sementara upgrade senjata hidup di lobby, dibayar **koin permanen**,
dan alur yang dipilih di level 4 mengunci senjata itu **selamanya**. **Sekarang**
kelima item dimatikan di server (`Config.MATCH_SHOP_ITEMS_ENABLED`), yang dijual
tiap jeda adalah upgrade senjata pemain itu sendiri, cash jadi **milik
masing-masing pemain**, dan level beserta alurnya **dimulai ulang tiap match**.
Tiga baris terakhir tabel di bawah datang dari situ: saldo yang berbeda di tiap
layar (T17), senjata yang kembali ke level 1 tiap match (T18), dan mekanik
andalan boss wave 10 yang jadi hampa karena tidak ada lagi yang bisa disandera
(T19).

**Perubahan keenam — jongkok, dan yang tidak ikut dengannya.** **Dulu** tidak
ada jongkok sama sekali. **Sekarang** tombol C (atau Ctrl kiri) menurunkan badan
1.2 stud dan memotong kecepatan jalan jadi setengah, dan server yang
menuliskannya supaya ketiga pemain lain ikut melihatnya. Yang perlu diketahui
sebelum menilai: Roblox **tidak punya state jongkok bawaan** -- `Humanoid` punya
Running, Jumping, Freefall, Seated, dan tidak ada Crouching -- jadi jongkok di
sini dirakit dari properti, bukan dipanggil. Lutut yang menekuk butuh aset
animasi yang belum ada di proyek ini, jadi yang terjadi badan turun sementara
kaki tetap lurus — sampai sistem gerak yang sekarang masuk dan menggantikannya
seluruhnya. Pose jongkoknya **dihitung** seperti pose lain, jadi lututnya
benar-benar menekuk; T20 ditutup sebelum sempat dilihat siapa pun. Yang tersisa
T21: Shift, C, dan Q semuanya keyboard, jadi pemain di layar sentuh tidak bisa
lari, jongkok, maupun dash.

Angka untuk keenamnya ada di [bagian 4.2](#42-angka-patokan), yang sejak
langkah 7 memuat tabel sembilan alur x tiga tingkat beserta damage, cooldown,
jangkauan, dan jumlah serangan yang bisa dihitung di muka — dan sejak toko
upgrade mendarat, juga kurva harga upgrade dalam match beserta anggaran satu
run penuh.

| # | Perilaku | Kenapa begitu |
|---|---|---|
| T8 | **Wave tertunda selama masih ada musuh hidup di base, dan tidak ada batas waktunya.** Nomor wave tidak naik, state tetap `Bertahan!`, `Intermission` dan panel Toko Match tidak muncul, sementara bar Core terus turun satu langkah tiap interval pukulan. Bisa berlangsung selama pemain membiarkannya. | `WaveService.isWaveClear()` tetap menuntut nol musuh aktif dan nol antrian, dan jaminan bahwa itu pasti tercapai sudah tidak ada. Tidak ditambal dengan "musuh di base tidak dihitung" (rancangan bagian 5): kebocoran jadi menghukum dua kali — HP Core dan waktu belanja — tanpa satu aturan tambahan. **Ini bukan hang dan bukan sinyal `onAllClear` yang hilang.** Bedakan dari hang yang sesungguhnya dengan satu pertanyaan: apakah masih ada musuh hidup di arena, termasuk yang berdiri menempel di Core? Kalau ada, itu T8. Kalau arena benar-benar kosong dan state tetap `WaveActive` lebih dari satu detik, itu bug — jaring pengaman `WaveService` memeriksanya dua kali per detik. Dan T8 tidak bisa menggantung permanen: kalau pemain tidak mampu, Core habis dan match berakhir kalah. Dites WAVE-20. |
| T9 | **Pemain bisa mati, dan itu hal baru.** Sebelum ini tidak ada satu pun `TakeDamage` di `src/server`, jadi kematian pemain tidak punya konsekuensi apa pun dan tidak pernah terjadi karena musuh. Sekarang `fast` memburu pemain, dan tipe lain memukul pemain yang berdiri dalam 6 stud dari mereka. | Respawn 5 detik (`Balance.RESPAWN_SECONDS`, disetel eksplisit ke `Players.RespawnTime`), di `Arena/PlayerSpawn`, **tanpa sistem nyawa** — mati cuma berarti kehilangan waktu, dan waktu itu mahal karena musuh terus memukul base selama pemain tidak ada. Selama mati, `Attack` ditolak karena `CombatService.characterOrigin` mengembalikan nil untuk karakter mati (COMBAT-10), dan itu bukan rate limit yang salah. Dites COMBAT-16 dan COMBAT-17. |
| T10 | **Slot cincin tidak dipakai ulang, jadi cincinnya melebar selama match berjalan.** | Nomor slot (`ringSlotNext` di `EnemyService`) naik terus dan tidak pernah dipakai ulang: slot yang dibebaskan musuh mati tidak boleh langsung diberikan ke musuh lain, kalau tidak dua musuh bisa berdiri di titik yang sama persis saat yang pertama mati tepat sebelum yang kedua sampai. Akibatnya yang terlihat: dengan banyak kebocoran, cincinnya makin lebar dari Core — itu wajar, bukan bug. Dua musuh di titik yang **sama persis** tetap GAGAL tanpa pengecualian: `EnemyAI.ringSlotOffset` memberi tiap cincin radiusnya sendiri (10, 14, 18, 22, ...), jadi tidak ada dua nomor slot yang bisa berbagi tempat berapa pun banyaknya kebocoran. Dihitung ulang tiap match (`clearAll` me-reset nomornya). Dites WAVE-19, dan dipatok unit test `EnemyAI` lintas tiga cincin. |
| T11 | **TIDAK BISA DILIHAT selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`) — baris ini disimpan karena dia berlaku lagi persis seperti tertulis begitu flag itu `true`. **Harga item toko berubah tiap kali dibeli, dan itu akan terlihat seperti bug.** Exploit Patch yang tadi 200 jadi 250, lalu 312, lalu 390. Tombolnya juga tidak lagi memuat "· sisa N" untuk empat dari lima item, jadi baris yang dulu berbunyi "200 cash · sisa 5 — ..." sekarang berbunyi "250 cash — ...". | Jatah pembelian (`maxPurchases`) diganti harga yang naik x1.25 per pembelian item yang sama; kurvanya di [bagian 4.2](#42-angka-patokan). Alasannya ada di hadiah per wave di baris berikutnya: toko yang seluruh itemnya dibatasi cuma bisa menyerap 3.450 cash, sementara hadiah wave saja sudah memberi 5.300 — habis diborong di wave 3-4, lalu sisa wave-nya cash-nya tidak ada gunanya. Harga yang naik membuat uang selalu punya tujuan. **Yang bukan bug:** angka di tombol berubah sendiri antar pembelian, dan empat item tidak punya "· sisa N" lagi. **Yang GAGAL:** tombol menulis satu angka tapi kolam terpotong angka lain — harga di tombol dan potongan cash dihitung dari sumber yang sama (`ShopRules.priceFor` dengan `purchases` sebelum dinaikkan), jadi selisih di antara keduanya berarti salah satu sisi memakai `def.cost`. Dites SHOP-20, dan `shop_barrier` yang batasnya memang dipertahankan dites SHOP-22. |
| T12 | **Saldo cash melompat ratusan sampai ribuan di detik wave selesai.** Wave 1 melompat dari sekitar 40 ke sekitar 240; wave 10 menambah 1.300 sekaligus. Jauh lebih besar daripada 5 cash per `basic` yang jadi satu-satunya sumber sebelum ini. | Hadiah cash per wave, `200 + 50*(wave-1)`, wave boss x2, **per pemain dan tanpa pengali jumlah pemain**. Angka dan kurvanya di [bagian 4.2](#42-angka-patokan). Lompatannya memang ordenya segitu: hadiah satu wave sengaja beberapa kali lebih besar daripada seluruh cash dari musuh wave itu, karena cash dari musuh saja tidak pernah cukup untuk membeli apa pun yang berarti sejak wave awal. **Yang bukan bug:** saldo naik tanpa ada musuh yang mati, tepat saat state pindah ke `Intermission`. **Yang GAGAL:** tidak ada lompatan sama sekali, atau angkanya tidak cocok dengan baris `[ShopService] hadiah wave N: ...` di Output server. Hadiah masuk **cash** yang habis tiap match, jadi jangan mencarinya di **koin** permanen di panel lobby — itu mata uang yang lain, dan hadiah per wave tidak akan pernah muncul di sana. Dites SHOP-17 sampai SHOP-19 dan SHOP-23, SHOP-24. |
| T13 | **Menekan Ready tidak lagi langsung memulai hitung mundur, dan tombol Upgrade/Beli/Craft mendadak mati walau panelnya masih terlihat.** Yang muncul di HUD setelah Ready adalah **"Pilih senjata · 20s"**, bukan "Match mulai dalam · 10s" — dan "Match mulai dalam · 10s" baru datang 20 detik kemudian, jadi dari Ready sampai musuh pertama ada **30 detik**, tiga kali lebih lama dari sebelumnya. Di panel lobby selama 20 detik itu, tombol kesulitan dan "Pakai" tetap biru dan bisa diklik sementara "Beli 1500" / "Craft" jadi abu-abu — dan sejak upgrade pindah ke dalam match, tombol "Upgrade 50" tidak ada lagi di panel ini sama sekali. | Fase `Loadout` (`MatchService.LOADOUT_SECONDS` = 20) disisipkan antara `Lobby` dan `Countdown`, dan dia ada supaya pemilihan senjata punya tempatnya sendiri: sesudah fase ini loadout **terkunci sampai match selesai**, termasuk saat `Intermission`. Tombol yang hidup dan yang mati ditentukan dua daftar yang berbeda, dan bedanya disengaja: "Pakai" dan kesulitan memakai `MatchRules.canSelectLoadout` (`Lobby` + `Loadout`), sementara upgrade/beli/craft memakai `ProgressionRules.ALLOWED_STATE` yang tetap **`Lobby` saja** — ketiganya mengubah data permanen, dan memilih alur upgrade permanen (ARENA_REDESIGN bagian 3) di bawah timer 20 detik adalah keputusan besar yang diambil terburu-buru. Baris petunjuk panel lobby yang mengatakannya ke pemain: **"Pilih senjata sekarang — terkunci setelah ini. Upgrade-nya nanti di dalam match, tiap jeda wave."** **Yang bukan bug:** Ready yang tidak memulai hitung mundur, 30 detik sebelum wave 1, panel lobby yang masih terlihat dengan sebagian tombol mati, dan tingkat kesulitan yang masih bisa diganti setelah Ready. **Yang GAGAL:** tombol "Pakai" yang **mati** selama `Loadout` — fase itu justru dibuat untuk menekannya, dan tombol mati di situ membuat seluruh fasenya tidak ada artinya; `SelectLoadout` yang masih **diterima** di `Intermission` (atau `Countdown`, `WaveActive`, `Ended`), karena kuncinya tidak boleh berhenti di batas fase saja; panel lobby yang **hilang** selama `Loadout`; dan tingkat kesulitan yang dipilih **di dalam** fase itu diabaikan tanpa pesan apa pun, yang berarti `lockDifficulty()` kembali dipanggil di awal fase alih-alih di akhirnya. Dites MATCH-02, MATCH-03, MATCH-17 sampai MATCH-21, dan dipatok unit test `MatchRules.canSelectLoadout`. |
| T14 | **Satu upgrade mengubah rasa senjata secara besar, dan satu alur akan dilaporkan sebagai senjata yang rusak.** Di level 4 damage dan kecepatan serangan tidak lagi bergeser 12% — mereka melompat. Patch Wrench alur `a` Ayunan Berat jadi **damage 51** tapi **cooldown 0.7 detik**, dari 0.5: pemain yang baru membayar 91 koin akan merasa senjatanya jadi **lebih lambat** dan melaporkannya sebagai bug, karena yang paling cepat terasa adalah jedanya dan bukan damage-nya. Packet Rifle alur `b` Semburan arah kebalikannya: cooldown 0.25 jadi **0.15** tapi damage turun jadi **15.232**, lebih kecil daripada 19.04 yang dia punya satu level sebelumnya. Dan di level 7 Semburan **memendekkan jangkauannya sendiri** dari 60 jadi 40 stud, sementara Fork Bomb alur `a` Shotgun sudah memendekkannya dari 45 jadi 30 di level 4 — upgrade yang membuat senjata tidak bisa lagi menjangkau musuh yang tadi kena. | Ini langkah 7 bekerja, bukan rusak: setiap angka di atas ada di `Weapons.luau` sebagai `damageMult`, `cooldownMult`, `cooldown`, `range`, atau `projectiles`, dan `Balance.weaponStats` menerapkannya dengan pengali yang **menumpuk** dan nilai absolut yang **ditimpa** tingkat lebih tinggi. Tabel lengkap sembilan alur x tiga tingkat, beserta damage per detik dan jumlah serangan yang bisa dihitung di muka, ada di [bagian 4.2](#42-angka-patokan). Pertukaran yang terasa buruk itu memang isi alurnya — alur yang cuma menaikkan semuanya bukan pilihan, cuma tombol. Dan itu sebabnya `summary` wajib benar: pemain mengunci pilihan permanen dari apa yang dia baca di panel, jadi "jeda antar serangan x1.4" harus tertulis di situ **sebelum** dia menekan konfirmasi. **Yang bukan bug:** cooldown yang naik, damage yang turun, dan jangkauan yang memendek sesudah upgrade; dua senjata yang sama di alur berbeda yang sekarang bertarung **sangat** berbeda; dan `basic` wave 1 yang di level 10 butuh **2** serangan di ketiga alur, karena 100 HP terlalu sedikit untuk memisahkan damage 52 dari 78 (pakai `tank`: 6 / 8 / 7). **Yang GAGAL:** stat yang **tidak** bergeser sama sekali sesudah titik percabangan — itu langkah 7 yang tidak sampai ke `weaponStats`; angka yang berbeda dari tabel bagian 4.2; `summary` yang menjanjikan angka yang tidak dihasilkan `weaponStats`; pilihan yang **tidak tersimpan** (`R.GetProfile:InvokeServer().weapons["weapon_starter"].path` masih `"none"` sesudah upgrade yang diterima); pilihan yang **bisa diganti** lewat upgrade berikutnya dengan `pathId` lain; panel yang menagih pilihan di level **selain** titik percabangan atau yang **tidak** muncul saat naik ke level 4; dan `path` yang masih **`nil`** di data yang sudah tersimpan sekali. Dites PROG-19 sampai PROG-28, COMBAT-12, COMBAT-19, COMBAT-20, DATA-12, DATA-13, dan dipatok unit test `ProgressionRules` serta `Balance.weaponStats`. |
| T15 | **Musuh melambat dan kehilangan HP tanpa ada apa pun yang terlihat menyentuhnya.** Dua gejala yang berbeda dari satu sebab. Pertama, musuh yang lewat satu titik di lane mendadak berjalan setengah kecepatan lalu normal lagi beberapa stud kemudian, dan di titik itu **tidak ada apa-apa di layar** — bukan Part, bukan efek, bukan dekal. Kedua, bar HP musuh turun pelan-pelan sementara tidak ada pemain yang menyerang, tidak ada turret dalam jangkauan, dan tidak ada angka damage di mana pun. Ketiga, dan ini yang paling membingungkan: dua musuh yang berdiri **berdampingan** bisa berjalan dengan kecepatan berbeda, karena yang satu kena slow yang menempel ke dirinya dan yang satu tidak. | Zona jebakan (Fork Bomb alur `c`). **Zona tidak punya Instance apa pun** — `EnemyService` menyimpannya sebagai tabel Lua dengan posisi, radius, dan waktu kedaluwarsa, dan tidak ada satu Part pun yang digambar di situ. Itu **kekurangan yang diketahui, bukan kelupaan**: menggambarnya butuh Part dan aset, dan yang dibutuhkan langkah 7 adalah efeknya bekerja. Jangan melaporkannya sebagai bug. Dua gejala pertama juga berasal dari dua kunci yang berbeda dan harus dibedakan: `zoneSlowMult` memperlambat (tingkat 1 dan 2, x0.6 lalu x0.45) sementara `zoneDps` baru ada di tingkat **3** (6 damage/detik), jadi musuh yang melambat tanpa kehilangan HP adalah alur yang belum level 10 — bukan dps yang hilang. Dan gejala ketiga dari pembagian yang disengaja: `slowMult` menempel ke **MUSUH** dan ikut dia ke mana pun, `zoneSlowMult` menempel ke **TEMPAT** dan berhenti begitu musuh keluar radius; keduanya dikalikan di loop `step`, jadi musuh yang kena dua-duanya bisa berjalan 1.8 stud/detik. **Yang bukan bug:** tidak ada apa pun yang terlihat di posisi zona; musuh yang melambat lalu normal lagi tanpa sebab terlihat; HP yang turun tanpa penyerang; dan dua musuh berdampingan dengan kecepatan berbeda. **Yang GAGAL:** zona yang terbawa ke match berikutnya — gejalanya musuh pertama wave 1 yang jalannya aneh tanpa ada yang menembaknya, dan `EnemyService.clearAll()` memang membuang daftar zonanya (COMBAT-25); zona yang lahir dari tembakan yang **tidak mengenai apa pun**, karena titik kenanya dibaca dari posisi musuh pertama yang kena dan tembakan tanpa korban melewatkan seluruh blok itu; dan zona yang **tidak pernah habis** walau `zoneSeconds` 3 detik sudah lewat. Dites COMBAT-24 dan COMBAT-25, dan dipatok unit test `CombatEffects` plus harness Studio `path_effects`. |
| T16 | **Musuh yang sama menerima damage yang berbeda dari serangan yang sama, dan yang kedua juga tanpa tanda visual.** Satu `basic` wave 1 kadang mati dalam 4 tembakan Packet Rifle dan kadang 5, dari pemain yang sama dengan senjata yang sama. Turret Toko Match yang jelas-jelas memberi 12 kadang memberi 16.8. Dan di tim berempat: pemain yang memakai **Patch Wrench** melihat damage-nya naik tanpa dia mengubah apa pun, karena yang menandai musuhnya pemain lain dengan **Packet Rifle**. | Tanda (Packet Rifle alur `c` Dukungan). Pengalinya diterapkan di **`EnemyService.damage`**, bukan di `CombatService`, dan itu seluruh bedanya antara "tanda menaikkan damage penandanya" dan "tanda menaikkan damage siapa pun": turret, splash pemain lain, dan damage per detik zona semuanya lewat fungsi yang sama, jadi semuanya ikut terkali. Itu yang membuat Dukungan **paling kuat di tim berempat dan paling lemah solo** — disengaja, dia memberi alasan mekanis untuk main bareng alih-alih cuma pengali reward. Tandanya juga tidak punya tanda visual apa pun, sama seperti zona di T15. Satu urutan yang akan terlihat seperti setengah bekerja dan sebenarnya benar: `EnemyService.damage` dipanggil **sebelum** `applyMark` di `onAttack`, jadi **tembakan yang memasang tanda itu sendiri tidak ikut terkali** — yang terkali tembakan kedua dan seterusnya (angkanya di [bagian 4.2](#42-angka-patokan)). Dan dua tanda yang bertumpuk: **yang terkuat menang, bukan yang terbaru** (`CombatEffects.merge`), jadi tembakan dari pemain yang alurnya masih tingkat 1 (x1.25) **tidak** menurunkan tanda x1.4 yang masih aktif. **Yang bukan bug:** damage yang berbeda ke musuh yang sama; damage pemain lain yang naik tanpa dia melakukan apa pun; turret dan zona yang ikut terkali; tembakan pertama yang belum terkali; dan tanda yang hilang sendiri setelah `markSeconds` (4 detik) habis. **Yang GAGAL:** tanda yang cuma menaikkan damage penandanya — itu pengalinya pindah ke `CombatService` dan seluruh alasan alur ini hilang; tanda lemah yang **menurunkan** tanda kuat yang masih aktif; dan penularan (tingkat 3, `markSpread` 2) yang mengenai target utama dua kali alih-alih dua musuh **lain** yang terdekat. Dites COMBAT-21 dan COMBAT-22, dan dipatok unit test `CombatEffects.nearest` plus `tanda.*` di harness `path_effects`. |
| T17 | **Saldo cash berbeda di tiap layar, dan pemain yang tidak membunuh apa-apa tertinggal jauh.** Di tim berempat, pemain yang membunuh paling banyak bisa punya 1.200 cash sementara yang menjaga Core punya 900 — angka di HUD keempat client **tidak lagi sama**, dan tombol upgrade mati di satu layar sementara hidup di layar sebelahnya. Panel toko satu pemain juga bisa menampilkan level 5 sementara pemain lain masih level 3. | Cash sekarang **per pemain**, bukan satu kolam tim: `MatchCoins` dikirim `FireClient` dan `MatchUpgradeState` juga ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)). Yang dibeli dengan cash sekarang **upgrade senjata milik satu orang**, dan kolam bersama untuk barang pribadi berarti tiap orang cuma kebagian seperempat sambil yang tercepat menekan tombol memakai uang bersama untuk dirinya sendiri. Hadiah per wave tetap **sama rata** — tiap peserta menerima angka penuh — jadi selisih antar pemain cuma datang dari cash membunuh, dan itu memang yang seharusnya membedakan mereka. **Yang bukan bug:** empat angka berbeda di empat client; pemain yang mati berkali-kali tertinggal level senjatanya; dan musuh yang mati karena zona, turret, atau mekanik boss memberi cash ke **semua** peserta sekaligus (tidak ada pembunuh yang bisa ditunjuk). **Yang GAGAL:** saldo yang **sama persis** di keempat client — itu `FireAllClients` yang kembali, dan gejalanya tiap client menampilkan saldo pemain yang terakhir berubah; cash dari musuh yang masuk ke orang yang tidak membunuhnya; dan hadiah per wave yang **dibagi** jumlah peserta alih-alih dibayarkan penuh ke tiap orang. Dites MP-04, MP-15, SHOP-23, dan SHOP-24. |
| T18 | **Senjata kembali ke level 1 tiap match, dan alur yang dipilih match lalu hilang.** Pemain yang menutup match di level 9 alur Sniper memulai match berikutnya di level 1 tanpa alur, dengan panel toko yang kembali menawarkan upgrade pertama seharga 150. Panel lobby juga **tidak lagi menampilkan level sama sekali** — barisnya cuma `damage 25 · jarak dekat · 3 alur`. | Level dan alur hidup di `matchWeapons` milik ShopService, yang dibuang `ShopService.reset()` saat kembali ke `Lobby`, dan `data.weapons[id].level` yang permanen **tidak dibaca `CombatService` lagi**. Itu bukan efek samping dari cash yang habis, itu intinya: alur yang terkunci selamanya cuma pernah dialami **sekali** per senjata, sementara alur yang dipilih ulang tiap match adalah keputusan yang diambil berkali-kali dengan keadaan yang berbeda — yang pertama progres, yang kedua gameplay. **Yang bukan bug:** level 1 di awal tiap match; alur yang bisa berbeda dari match sebelumnya; panel lobby tanpa angka level; dan `GetProfile` yang `weapons[...]`-nya tidak pernah bergerak lagi. **Yang GAGAL:** level yang **terbawa** ke match berikutnya — itu `reset()` yang tidak dipanggil, dan gejalanya musuh wave 1 yang mati jauh lebih cepat dari biasanya; alur yang masih bisa diganti **di dalam satu match yang sama**; dan `data.weapons[id].level` yang ikut naik saat upgrade diterima. Dites SHOP-29 dan SHOP-30. |
| T19 | **Mekanik andalan boss wave 10 tidak melakukan apa-apa yang bisa diukur.** Locker tetap mengunci toko dan Output tetap mencetak `[Locker] boss mati, upgrade tim dipulihkan`, tapi damage pemain **tidak turun sedikit pun** selama dia hidup, dan tidak ada angka mana pun yang berubah saat dia mati. | Sandera Locker menyandera **upgrade TIM yang dibeli dari kelima item toko** — `ShopService.getModifiers()` mengoper tabel pembelian kosong selama `suspended`. Tanpa item, `purchases` selalu kosong, jadi pengali yang disandera memang sudah pengali dasar: **tidak ada yang bisa disandera**. Upgrade senjata dalam match **tidak** ikut disandera, dan itu disengaja — dia milik satu pemain, bukan tim. Jadi mekanik yang dulu paling menggigit sekarang hampa sampai dia diarahkan ke sesuatu yang lain, dan ini **kekurangan yang diketahui, bukan bug yang baru ditemukan**. **Yang bukan bug:** damage yang tidak berubah saat Locker hidup; baris "upgrade tim disandera" di HUD yang tidak diikuti perubahan angka apa pun; dan kedua baris log Locker yang tetap muncul. **Yang GAGAL:** toko yang **tidak** terkunci saat Locker hidup (kuncinya masih berlaku dan masih menolak upgrade senjata, dengan pesan "Toko dikunci. Kalahkan boss-nya dulu."), dan sandera yang **terbawa** ke match berikutnya. Akibatnya untuk kolom Status: SHOP-16 dan bagian BOSS-07/BOSS-08 yang menilai sanderanya **tidak bisa membuktikan apa pun** dan berstatus `BLOK` sampai item toko dinyalakan lagi atau mekaniknya diarahkan ulang. |
| T20 | ~~**Jongkok tidak menekuk lutut.**~~ **Ditutup 2026-10-26 tanpa pernah dilihat siapa pun**, karena sistem gerak yang menggantikannya menghitung pose jongkok seperti pose lain. Baris ini disimpan supaya yang membaca riwayatnya tahu bahwa keterbatasan itu nyata dan bagaimana dia hilang, bukan karena masih perlu dicek. | — |
| T21 | **Tidak ada cara bergerak selain jalan di layar sentuh.** Pemain mobile bisa menyerang (tap) tapi tidak bisa lari, jongkok, maupun dash. | Shift, C, dan Q semuanya keyboard; tombol di layar belum ada. Diminta sebagai hotkey, jadi dikerjakan sebagai hotkey. **Bukan GAGAL**, tapi juga bukan keadaan akhir: kalau mobile termasuk yang didukung, dia butuh tiga tombol sendiri di HUD |

### 5.4 Teks client: ketiganya sudah diperbarui

Tiga teks di client pernah menggambarkan dunia sebelum toko upgrade mendarat,
dan ketiganya sudah dibetulkan (2026-10-26). Dicatat di sini alih-alih dihapus
karena yang berubah **kata-katanya**, dan baris test yang menilai kata-kata itu
harus tahu bunyi yang mana yang sekarang benar:

| Di mana | Yang tertulis sekarang |
|---|---|
| `HudController`, angka cash di HUD | **"N cash"**, tanpa kata "tim". Saldonya milik pemain yang melihat layar itu |
| `TutorialController`, langkah `lobby` | "Pilih senjata di panel kiri, lalu tekan Ready." Lobby tidak lagi menjanjikan upgrade |
| `TutorialController`, langkah `intermission` | "Toko Match buka di kanan: di situ senjatamu naik level, dibayar cash. Cash-mu sendiri, dan habis saat match selesai." |
| `TutorialController`, langkah `ended` | "Koin dan XP dari match ini tersimpan permanen. Level senjata tidak: tiap match dimulai lagi dari level 1." |
| `TutorialController`, langkah `countdown` | Ditambah kalimat kedua: "Tekan C untuk jongkok; jalanmu jadi setengah kecepatan." Itu satu-satunya tempat tombol jongkok diberitahukan ke pemain |

HUD-01 menilai angka cash di HUD dan HUD-05 menilai kelima langkah panduan,
jadi keduanya sekarang menilai teks yang memang ada. **Tidak ada lagi kegagalan
yang sudah diketahui di dokumen ini** — kalau sebuah baris gagal, dia temuan
baru.

## 6. Boot dan map (BOOT)

Acuan: DEVELOPMENT_PLAN.md bagian 1.4 dan 3.4. Kelompok ini dijalankan **paling
dulu** — kalau BOOT gagal, tidak ada gunanya menjalankan yang lain.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| BOOT-01 | Rojo connected, place baru | F5, lihat Output server | `[CodeVerse] server booting (place N)` lalu `[CodeVerse] relative require OK — 10 wave tervalidasi`. Lalu baris siap: `[RewardService] siap`, `[MapService] Arena siap: ...`, `[MatchService] siap, 10 wave, countdown 10s, intermission 20s`, `[BossService] siap, 2 boss dengan mekanik yang dikenal`, `[ProgressionService] siap`. Tidak ada error | M0 | solo | - |
| BOOT-02 | Repo ter-sync; arena dibangun `ArenaBuilder` saat server start, jadi tidak ada prasyarat file | F5, lihat Output server | `[MapService] Arena siap: 3 lane, waypoint di-cache (Lane1=7, Lane2=7, Lane3=7)` — tepat satu baris, tanpa warn dari `MapService` soal Arena. Karakter muncul di `Arena/PlayerSpawn`, bukan di tengah lane | M1 | solo | - |
| BOOT-03 | Rename `assets/Arena.rbxmx` sementara supaya map tidak ada, restart `rojo serve`, F5 | Lihat Output server dan HUD | **Tepat satu** warn `[MapService] Arena tidak bisa dipakai: Workspace.Arena tidak ada. Gameplay tidak dijalankan. ...`. Tidak ada warn kedua dan tidak ada warn yang berulang tiap frame. HUD tetap muncul dengan "Wave 0 / 10", "Di lobby", bar Core penuh. Menekan Ready tidak memulai apa pun. **Balikkan nama filenya setelah test** | M1 | solo+EDIT | - |
| BOOT-04 | **Harapannya TERBALIK sejak 2026-10-26.** Lobby dibangun `ArenaBuilder` saat server start, jadi tidak ada lagi keadaan "lobby belum ada" | F5, lihat Output server | **Tidak ada** warn `[MapService] Lobby tidak lengkap`, dan `Workspace.Lobby` berisi `ReadyPad` beserta `SpawnLocation`. Warn itu kalau muncul sekarang **temuan sungguhan**: builder-nya gagal, dan sebabnya ada di warn `[ArenaBuilder]` di atasnya. Dulu baris ini menuntut warn-nya ADA; pemain muncul di spawn arena | M5 | solo | - |
| BOOT-05 | Buat `assets/Lobby.rbxmx` lewat `scripts/build_lobby.luau` (prosedur di [2.6](#26-map-arena-sudah-ada-lobby-belum)), sync, F5 | Lihat Output server | **Tidak ada** warn `[MapService] Lobby tidak lengkap`. Kalau masih ada, nama instance-nya tidak persis `SpawnLocation` dan `ReadyPad`. Lobby ada di Z = 400, jauh di belakang arena (lantai arena berakhir di Z = 120), dan dari lobby musuh di arena tidak terlihat | M5 | solo | - |
| BOOT-06 | Lobby sudah ada | Ubah `DEBUG_VISIBLE_WAYPOINTS = true` di `scripts/build_arena.luau`, jalankan di command bar, Save to File, sync, F5. Perhatikan jalur satu musuh dari spawn sampai Core | Musuh lewat waypoint **1 → 2 → 3 → ... → 7** dalam satu garis mulus menuju Core. **Tidak** zig-zag, tidak melompat, tidak berputar di satu waypoint. Balikkan flag debug-nya setelah test | M1 | solo+EDIT | - |

> Kalau lane-nya nanti ditambah sampai 10 waypoint atau lebih, **ulangi BOOT-06**.
> Di bawah 10 waypoint, sort string dan sort angka memberi hasil yang sama, jadi
> bug urutan baru bisa muncul setelah ada waypoint bernama "10".

## 7. Alur match dan state machine (MATCH)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3.

Satu state disisipkan sejak langkah 5 rancangan ulang arena, dan dia menggeser
beberapa baris di bawah. Urutannya sekarang:

```
Lobby -> Loadout (20 s) -> Countdown (10 s) -> WaveActive <-> Intermission -> Ended -> Lobby
```

`Lobby -> Countdown` langsung **sudah tidak ada**: menekan Ready saat semua
pemain siap masuk ke `Loadout`, dan `Countdown` cuma bisa dicapai dari sana.
Dua fase pra-match itu sama-sama memeriksa "semua pemain di server siap" tiap
tick, jadi membatalkan Ready atau pemain baru yang join membatalkan
**dua-duanya** kembali ke `Lobby` (MATCH-15, MATCH-16). Yang membedakan
keduanya cuma apa yang boleh diklik: di `Loadout` senjata dan tingkat kesulitan
masih bisa diganti, di `Countdown` tidak ada lagi, dan sesudah itu loadout
terkunci sampai match selesai (T13 di
[bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug)).

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| MATCH-01 | Server baru start, 1 player join | Lihat HUD dan posisi karakter | HUD atas menampilkan "Wave 0 / 10", "Di lobby", bar "Core 1000 / 1000". Panel **Lobby** muncul di kiri layar dengan tombol Ready di bawah. Tidak ada musuh di arena | M2 | solo | - |
| MATCH-02 | State `Lobby`, 1 player | Tekan tombol **Ready** di panel lobby, lalu tunggu sampai hitungannya habis tanpa menyentuh apa pun | State jadi **"Pilih senjata · 20s"** — bukan "Match mulai dalam · 10s", karena Ready sekarang masuk fase `Loadout` dulu — dan hitungannya turun tiap detik. Tombolnya berubah jadi "Batal siap" dan baris petunjuk panel lobby berbunyi "Pilih senjata sekarang — terkunci setelah ini. Upgrade-nya nanti di dalam match, tiap jeda wave.". Setelah 20 detik state berganti jadi **"Match mulai dalam · 10s"**, dan wave 1 baru mulai 10 detik sesudahnya — **30 detik** dari Ready, bukan 10 (T13 di [bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug)). **`Lobby/ReadyPad` tidak melakukan apa pun** — dia cuma penanda posisi, tombol Ready yang sesungguhnya ada di UI | M2 | solo | - |
| MATCH-03 | State `Countdown` (tekan Ready, lalu tunggu 20 detik fase `Loadout` lewat lebih dulu — di `Loadout` perubahan ini justru **diterima**, lihat MATCH-17 sampai MATCH-19) | Coba ubah senjata dan tingkat kesulitan dari panel lobby, lalu ulangi lewat `R.SelectLoadout:FireServer("weapon_starter", "normal")` dari command bar client | Panel lobby tetap terlihat tapi tombol kesulitan, "Pakai", dan "Upgrade/Beli/Craft" **semuanya** mati — di `Countdown` tidak ada lagi tombol lobby yang hidup. Lewat remote: ditolak dengan `ActionResult` **"Loadout sudah terkunci sampai match selesai."** dan `equippedWeapon` tidak berubah. Pesan lamanya "Cuma bisa ganti loadout di lobby." sudah tidak ada sama sekali, dan kalau dia yang muncul berarti ada jalur kedua yang memeriksa state. Yang dipakai match adalah loadout yang terpilih **sampai fase `Loadout` berakhir**, bukan yang terpilih sebelum Ready | M2 | solo | - |
| MATCH-04 | State `Countdown` | Tunggu timer habis | State jadi "Bertahan!" dan wave jadi 1. Musuh pertama muncul hampir langsung, lalu satu per ~0.9 detik, bergantian lane 1 dan lane 2. Serangan player aktif | M2 | solo | - |
| MATCH-05 | State `WaveActive` di wave 1 | Habiskan semua musuh wave itu | State jadi "Jeda — toko buka · 20s", musuh berhenti bergerak, panel **Toko Match** muncul di kanan layar | M2 | solo | - |
| MATCH-06 | State `Intermission` setelah wave 1 | Tunggu timer 20 detik habis | State kembali "Bertahan!", nomor wave jadi 2, musuh wave 2 spawn, panel toko **hilang** | M2 | solo | - |
| MATCH-07 | State `WaveActive`, jangan menyerang sama sekali | Biarkan musuh sampai ke Core sampai HP 0 | Layar hasil **"Core Server jebol"** muncul dengan wave tercapai. Output server mencetak `[MatchService] match selesai: kalah di wave N (normal), 1 peserta` dan `[CodeVerse] Core Server hancur` | M2 | solo | - |
| MATCH-08 | State `WaveActive` di wave 10 | Habiskan seluruh musuh wave 10 termasuk boss dan minion yang dipanggilnya | Tidak masuk `Intermission`; langsung layar hasil **"Core Server aman!"** | M2 | solo | - |
| MATCH-09 | Layar hasil muncul | Tunggu 10 detik | Layar hasil tertutup sendiri (layar ini **tidak punya tombol tutup** — dia mengikuti state server, bukan timer sendiri); state kembali "Di lobby"; wave kembali 0; player kembali ke area lobby | M2 | solo | - |
| MATCH-10 | Satu match sudah selesai, state `Lobby`, server **tidak** di-restart | Tekan Ready lagi dan mainkan match kedua | Match kedua jalan dari wave 1 dengan Core HP penuh, cash **tiap pemain** 0 dan senjatanya kembali ke level 1 tanpa alur (SHOP-30), tidak ada musuh sisa, tidak ada turret sisa dari match sebelumnya. Jalurnya sama dengan match pertama: `Lobby` → `Loadout` 20 detik → `Countdown` 10 detik, jadi fase pemilihan senjata **muncul lagi** dan senjata maupun tingkat kesulitan bisa diganti di situ — kalau Ready di match kedua langsung masuk `Countdown`, Ready-nya ditangani jalur lain. Ini kriteria M2 yang paling mudah bocor: state yang tidak di-reset (wave, participants, cooldown serangan, antrian spawn, pembukuan pembelian) baru kelihatan di match kedua | M2 | solo | - |
| MATCH-11 | **Tiga** state yang punya timer: `Loadout`, `Countdown`, dan `Intermission` | Bandingkan timer di HUD dengan hitungan detik asli di ketiganya | Timer turun kira-kira satu per detik (server menyiarkannya tiap 0.2 detik, HUD membulatkan ke atas) dan berhenti saat state berganti. Angka awalnya **20 / 10 / 20** sesuai [bagian 4.2](#42-angka-patokan). Tidak ada timer negatif dan tidak ada angka yang nyangkut — perhatikan khusus **detik pergantian `Loadout` → `Countdown`**: timer di-set ke 10 **sebelum** state di-set, jadi tidak boleh ada satu paket pun yang menampilkan "Match mulai dalam · 0s" atau angka negatif sisa dari Loadout | M2 | solo | - |
| MATCH-12 | State `WaveActive`, masih ada musuh hidup atau musuh di antrian spawn | Tunggu beberapa detik tanpa membunuh musuh | Nomor wave **tidak** naik dan state tidak pindah ke `Intermission` selama musuh wave itu belum habis | M2 | solo | - |
| MATCH-13 | State `WaveActive` | Tekan Ready, lalu `R.SetReady:FireServer(true)` dari command bar client | Tidak terjadi apa-apa; state tetap `WaveActive`; tidak ada error di Output server. Gerbangnya sekarang membolehkan **tiga** state (`Lobby`, `Loadout`, `Countdown`) dan `WaveActive` bukan salah satunya, jadi yang diuji di sini tetap penolakan — bukan pembatalan seperti di MATCH-15 | M2 | solo | - |
| MATCH-14 | Dua match selesai berurutan tanpa restart server | Lihat layar hasil match kedua | Hasil match kedua dihitung dari match kedua saja (wave, koin, material), tidak menumpuk hasil match pertama | M2 | solo | - |
| MATCH-15 | **Dua percobaan, satu baris**: (a) state `Loadout`, timer 20 detik masih jalan; (b) state `Countdown`, hitung mundur masih jalan | Tekan **"Batal siap"** di masing-masing | Di dua-duanya timer berhenti dan state kembali "Di lobby", match tidak dimulai, dan tombolnya kembali jadi "Ready". Satu baris untuk dua fase karena kodenya memang satu syarat yang sama (`everyoneReady()`) yang diperiksa tiap tick di kedua cabang — tapi dua-duanya tetap harus dijalankan, karena cabangnya ditulis **dua kali** di `tick()` dan satu cabang yang kelewat tidak akan terlihat dari cabang yang lain. Batal dari `Loadout` adalah satu-satunya jalan keluar dari 20 detik itu: tanpa gerbang itu fase baru ini tidak bisa dibatalkan sama sekali | M2 | solo | - |
| MATCH-16 | Match di server live, dua pemain Ready sehingga masuk `Loadout`. Ulangi sekali lagi setelah fase itu lewat, saat `Countdown` | Pemain ketiga join saat timer masih jalan — sekali di `Loadout`, sekali di `Countdown` | Di **dua-duanya** timer **dibatalkan** dan state kembali `Lobby` — pemain baru otomatis belum Ready, jadi syarat "semua pemain di server siap" tidak lagi terpenuhi, dan syarat itu diperiksa tiap tick di kedua fase. Lihat [tabel keputusan M2](#202-keputusan-m2). Perhatikan bahwa fase `Loadout` memperlebar jendela waktunya dari 10 detik jadi 30, jadi pembatalan ini sekarang **tiga kali lebih mudah terpicu** di server yang ramai daripada saat baris ini pertama ditulis. Berkode `LIVE` karena sesi Clients and Servers di Studio memulai semua client berbarengan; tidak ada cara menambah pemain di tengah sesi | M2 | LIVE | - |
| MATCH-17 | State `Loadout` (tekan Ready dan jangan tunggu sampai habis), 1 player | Lihat panel lobby dan coba klik tiap tombolnya satu per satu | Panel lobby **tetap terlihat**, tidak hilang seperti di `WaveActive`. Yang **hidup**: tombol tingkat kesulitan yang sudah terbuka, dan tombol "Pakai" pada baris senjata yang belum dipakai. Yang **mati**: "Pakai" pada senjata yang sedang dipakai. Tombol aksi di baris senjata yang sudah dimiliki **tidak melakukan apa pun di state mana pun** — upgrade pindah ke dalam match, jadi tidak ada lagi tombol "Upgrade N" yang perlu dimatikan di sini. Ketiga senjata dimiliki sejak awal ([bagian 4.2](#42-angka-patokan)), jadi **tidak ada** tombol "Beli 1500" maupun "Craft" di panel ini — baris yang menampilkan salah satunya berarti `Config.DEFAULT_DATA.weapons` tidak sampai ke data pemain. Baris petunjuk di bawah panel berbunyi **"Pilih senjata sekarang — terkunci setelah ini. Upgrade-nya nanti di dalam match, tiap jeda wave."**, warna abu-abu biasa. Mengklik tombol yang mati **tidak mengirim apa pun** ke server. Panel Toko Match tetap tidak terlihat. Kalau "Pakai" ikut mati di sini, itu GAGAL dan bukan hal kecil: fase ini satu-satunya gunanya menekan tombol itu (T13) | M2 | solo | - |
| MATCH-18 | `weapon_starter` yang sedang dipakai; `weapon_ranged` dimiliki sejak awal, jadi tidak ada yang perlu dibeli dulu ([bagian 4.2](#42-angka-patokan)). **Dua-duanya harus level 1** — angka 8 dan 4 di kolom harapan datang dari damage 14 dan 25, dan sejak langkah 7 alur yang terpilih menggesernya ([bagian 4.2](#42-angka-patokan)). State `Lobby`, solo `normal` | Tekan Ready. **Setelah** state jadi "Pilih senjata · 20s", tekan "Pakai" di baris Packet Rifle, biarkan 20 detik habis, lalu hitung serangan untuk membunuh satu `basic` di wave 1 | "Pakai" diterima: judul barisnya berubah jadi **"Packet Rifle (dipakai)"** dan `ActionResult` yang balas berisi `ok = true` (tanpa alasan). Di wave 1, satu `basic` (100 HP) mati **tepat setelah 8 serangan**, bukan 4 — Packet Rifle 14 damage, Patch Wrench 25 ([bagian 4.2](#42-angka-patokan)). 4 serangan berarti pilihan di dalam fase `Loadout` diterima di UI tapi tidak sampai ke `CombatService.resolveWeapon`, dan itu persis kegagalan diam-diam yang membuat fase ini butuh test sendiri. Serangannya juga mengenai musuh di 40-55 stud, bukan cuma 17 (COMBAT-07) | M5 | solo | - |
| MATCH-19 | `hard` sudah terbuka (PROG-06), state `Lobby`, tombol kesulitan menunjuk **Normal**, solo | Tekan Ready. **Setelah** state jadi "Pilih senjata · 20s", tekan tombol **Hard**, biarkan 20 detik habis, lalu hitung serangan untuk membunuh satu `basic` di wave 1 | Tombol Hard bisa diklik di fase ini (MATCH-17) dan pilihannya **berlaku**: `basic` wave 1 butuh **8** serangan `weapon_starter` level 1 (HP 180 = 100 x hpMult 1.8), bukan 4, dan print akhir match berbunyi `... (hard)`. **Ini kasus regresi**, bukan fitur baru: `lockDifficulty()` dulu dipanggil saat semua pemain Ready, dan `SelectLoadout` membawa `weaponId` **dan** `difficulty` dalam satu remote — jadi mengunci di awal fase berarti tingkat yang dipilih di dalam fase diabaikan **tanpa pesan apa pun** sementara senjatanya diterima. Satu remote, dua argumen, cuma satu yang berlaku: tidak ada cara pemain menebaknya. 4 serangan di sini berarti `lockDifficulty()` kembali dipanggil terlalu awal | M5 | solo | - |
| MATCH-20 | State `Lobby`, `weapon_ranged` dimiliki dan **sedang dipakai** dari match sebelumnya (judul barisnya bertanda "(dipakai)") | Tekan Ready dan **jangan sentuh apa pun** selama 20 detik fase `Loadout`, lalu hitung serangan untuk membunuh satu `basic` di wave 1 | Match jalan dengan **Packet Rifle**, senjata terakhir yang dipakai: 8 serangan, bukan 4. Tidak memilih **tidak** mengembalikan loadout ke starter dan tidak ada penalti apa pun. Ini tidak butuh satu baris kode pun — `data.equippedWeapon` permanen, jadi tidak memilih berarti tidak mengubahnya — dan itu sebabnya yang diuji di sini justru bahwa **tidak ada** yang me-reset-nya saat fase berakhir | M2 | solo | - |
| MATCH-21 | State `Intermission` (habiskan wave 1 dan tunggu panel toko muncul). Pasang listener dulu di command bar client: `R.ActionResult.OnClientEvent:Connect(print)` | `R.SelectLoadout:FireServer("weapon_starter", "normal")`, lalu ulangi saat `WaveActive` dan saat `Ended` | Ketiganya ditolak dengan `ActionResult` **"Loadout sudah terkunci sampai match selesai."** dan `equippedWeapon` tidak berubah — kuncinya berlaku di **seluruh** state setelah `Loadout`, bukan cuma `Countdown`. `Intermission` yang paling penting di antara ketiganya: itu satu-satunya jeda nyaman di tengah match, jadi itu juga satu-satunya tempat pemain punya waktu untuk mencoba menukar senjata setelah melihat musuh apa yang datang. Tidak ada panel yang bisa diklik di `Intermission` untuk ini (panel lobby sudah hilang), jadi remote manual satu-satunya cara memicunya. Tidak ada error di Output server | M2 | solo | - |
| MATCH-22 | **TIDAK BISA DIJALANKAN selama ketiga senjata terbuka sejak awal** ([bagian 4.2](#42-angka-patokan)). Baris ini menguji `Config.DEV_ALL_WEAPONS` pada pemain yang **belum pernah** membeli Packet Rifle, dan prakondisi itu sekarang mustahil: `Config.DEFAULT_DATA.weapons` memberikan Packet Rifle ke setiap pemain baru, jadi tidak ada lagi keadaan "dimiliki menurut flag tapi tidak menurut `data.weapons`" yang justru menjadi seluruh isi baris ini. **Jangan dicatat GAGAL** — statusnya `BLOK`, dan syarat menjalankannya lagi satu: `Config.DEFAULT_DATA.weapons` dikembalikan jadi `weapon_starter` saja. Sesudah itu baris ini berlaku apa adanya. Langkah aslinya disimpan utuh di bawah karena flag-nya **tidak** dihapus dan aturannya masih benar. Prakondisi aslinya: **ubah `Config.DEV_ALL_WEAPONS` jadi `true`** di `src/shared/Config.luau`, sync, F5. Player yang **belum pernah** membeli Packet Rifle — periksa dulu lewat `R.GetProfile:InvokeServer().weapons` dari command bar client, isinya harus cuma `weapon_starter`, **dan `weapon_starter` harus level 1 dengan `path = "none"`** — angka 8 dan 4 di kolom harapan hanya berlaku untuk damage 14 dan 25, dan starter yang sudah lewat titik percabangan memberi angka lain ([bagian 4.2](#42-angka-patokan)). Flag dev memberi Packet Rifle **level 1**, jadi damage-nya 14 apa adanya dan alurnya `"none"`. Solo `normal` | Di panel lobby lihat baris Packet Rifle, tekan "Pakai", Ready, lewati 20 detik `Loadout`, lalu hitung serangan untuk membunuh satu `basic` di wave 1. Terakhir baca lagi `R.GetProfile:InvokeServer().weapons`. **Balikkan `Config.luau` sebelum commit** | Baris Packet Rifle menampilkan dua hal yang kelihatan bertentangan dan dua-duanya benar: tombol **"Pakai" hidup** sementara tombol aksinya tetap **"Beli 1500"** — "Pakai" memakai `ProgressionRules.ownedWeapons` yang ikut flag, tombol beli memakai `data.weapons` yang tidak. "Pakai" **diterima** server. Lalu yang dibuktikan baris ini: di wave 1 satu `basic` mati setelah **8** serangan, dengan jangkauan **60 stud**. Delapan serangan artinya dia benar-benar **MENGAYUN seperti Packet Rifle**, bukan cuma terpilih di UI. **4 serangan adalah GAGAL**, dan ini jebakan utuhnya: `MatchService.onSelectLoadout` menolak dengan pesan sementara `CombatService.resolveWeapon` **diam-diam jatuh ke starter**, jadi kalau cuma yang pertama mengenal flag, pemain memilih Packet Rifle lalu mengayunkan Patch Wrench **tanpa satu pesan error pun** — bug yang tidak pernah dilaporkan karena tidak ada yang kelihatan rusak. Dan `weapons` di akhir harus **masih cuma `weapon_starter`**: flag hidup di memori saja, jadi senjata hasil flag tidak boleh pernah masuk `data.weapons` dan dari sana ke DataStore. Kalau Packet Rifle muncul di situ, akun itu progresnya rusak permanen dan rusaknya baru kelihatan setelah flag dimatikan | M5 | solo+EDIT | BLOK |
| MATCH-23 | **TIDAK BISA DIJALANKAN, sebab yang sama dengan MATCH-22** dan dengan syarat yang sama untuk menjalankannya lagi: dia lanjutan MATCH-22, dan yang dia uji adalah senjata yang **hilang lagi** begitu flag dimatikan — keadaan yang tidak bisa dicapai selama senjatanya memang dimiliki di `data.weapons`. Statusnya `BLOK`, bukan GAGAL. Prakondisi aslinya: lanjutan MATCH-22 di player yang sama, `equippedWeapon` masih `weapon_ranged` dari sana, lalu **balikkan `Config.DEV_ALL_WEAPONS` jadi `false`**, sync, F5 | Lihat baris Packet Rifle di panel lobby, lalu Ready, lewati `Loadout`, lalu hitung serangan untuk membunuh satu `basic` di wave 1. Lalu `R.SelectLoadout:FireServer("weapon_ranged", "normal")` dari command bar client di state `Lobby` | Tombol "Pakai" pada Packet Rifle **mati** lagi dan remote-nya ditolak dengan "Senjata itu belum kamu miliki." — bukan dengan pesan kunci loadout, karena di `Lobby` gerbang state-nya lolos lebih dulu. Judul barisnya **tetap bertanda "(dipakai)"**, karena itu dibaca dari `data.equippedWeapon` yang memang masih berisi `weapon_ranged`. Dan serangannya **kembali 4**, bukan 8: `ProgressionRules.equippedWeapon` jatuh ke starter tanpa pesan apa pun. Kejatuhan diam-diam itu **disengaja** dan bukan GAGAL — dia dipanggil tiap serangan, jadi tidak ada tempat untuk melapor, dan senjata yang hilang dari data tidak boleh membuat serangan pemain berhenti sama sekali. Gerbang yang berbicara ada di `onSelectLoadout`, dan itu yang baru saja ditolak. Yang GAGAL di sini cuma dua: serangan yang **berhenti sama sekali**, atau error di Output server | M5 | solo+EDIT | BLOK |

## 8. Wave dan spawn (WAVE)

Acuan: DEVELOPMENT_PLAN.md bagian 1.3, 3.4, 3.5.

> **Setiap jumlah serangan di kelompok ini mengandaikan `weapon_starter` level 1
> dengan `path = "none"`**, yaitu damage 25 apa adanya. Sejak langkah 7 rancangan
> ulang arena tingkat alur benar-benar menggeser damage — Patch Wrench alur `a`
> sudah 51 di level 4 dan 78 di level 10 ([bagian 4.2](#42-angka-patokan)) — jadi
> baris di bawah yang dijalankan dengan senjata ter-upgrade akan memberi angka
> yang **berbeda dan tetap benar**, dan itu bukan bug HP musuh. Yang diuji di
> sini penskalaan HP musuh, bukan senjatanya, jadi senjatanya yang harus
> dipertahankan di titik awal.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| WAVE-01 | Match baru mulai, solo | Amati musuh wave 1 | **Hanya `basic`** (kubus oranye) — itu seluruh komposisi wave 1 di `Waves.luau` — sebanyak 8 buah. Output server mencetak `[WaveService] wave 1: 8 musuh biasa di 3 lane, 1 player` | M2 | solo | - |
| WAVE-02 | Match solo, kesulitan `normal` | Mainkan dari wave 1 sampai match berakhir | Nomor wave jalan 1 → 2 → ... → 10 tanpa lompat atau mengulang. Wave 5 dan 10 adalah boss wave | M2 | solo | - |
| WAVE-03 | Match wave 1 | Ikuti satu musuh `basic` dari spawn sampai Core, dan hitung serangan untuk membunuh satu | Bergerak lambat (8 stud/detik) mengikuti lane sampai Core. Mati **tepat setelah 4 serangan** `weapon_starter` level 1 (100 HP / 25 damage) | M1 | solo | - |
| WAVE-04 | Wave 2 atau lebih (komposisinya berisi `fast`) | Bandingkan `fast` (balok hijau) dengan `basic` di wave yang sama | `fast` jelas lebih cepat sampai ke Core (16 vs 8 stud/detik) dan HP-nya lebih kecil — di wave 2, `fast` mati dalam 3 serangan, `basic` dalam 5 | M2 | solo | - |
| WAVE-05 | Wave 4 atau lebih (komposisinya berisi `tank`) | Serang satu `tank` (kubus ungu) dan hitung serangan sampai mati | Butuh jauh lebih banyak: di wave 4 sekitar **24 serangan** (580 HP). Gerakannya paling lambat (5 stud/detik) | M2 | solo | - |
| WAVE-06 | Dua playtest terpisah, sama-sama `normal`: solo dan 2 player, dimainkan sampai **wave 2** | Baca baris `[WaveService] wave 2: ...` di Output server di dua playtest itu | Solo = **10** musuh, 2 player = **11** musuh. **Jangan membandingkan di wave 1** — di wave 1 solo dan 2 player sama-sama 8 musuh karena pembulatan ke bawah dari 8.5, dan itu benar, bukan bug | M2 | 2P | - |
| WAVE-07 | Match solo | Hitung serangan untuk membunuh satu `basic` di wave 1 dan di wave 5 | Wave 1 = 4 serangan (HP 100), wave 5 = **7** serangan (HP 160). HP musuh naik 15% per wave | M1 | solo | - |
| WAVE-08 | Dua playtest terpisah, `basic` di wave 1: solo dan 2 player | Bandingkan serangan untuk membunuh satu `basic` | Solo = 4 serangan (HP 100), 2 player = **6** serangan (HP 135). HP naik 35% per player tambahan | M2 | 2P | - |
| WAVE-09 | `hard` sudah terbuka; dua playtest solo wave 1, `normal` dan `hard` | Bandingkan serangan untuk membunuh satu `basic` | `normal` = 4 serangan (HP 100), `hard` = **8** serangan (HP 180, pengali 1.8) | M5 | solo | - |
| WAVE-10 | Playtest **4 player** sampai **wave 10** — satu-satunya wave yang jumlah musuhnya (41) melewati batas 40 | Amati jumlah musuh aktif di arena selama wave 10 berjalan | Musuh aktif tidak pernah lebih dari 40 sekaligus; musuh dari antrian menyusul spawn setelah musuh lain mati; wave tetap bisa diselesaikan. Kalau wave tidak pernah bersih, **periksa dulu apakah ada musuh yang berdiri menempel di Core** — wave yang tertunda karena kebocoran adalah hal yang benar (WAVE-20), dan cuma kalau arena sudah benar-benar kosong itu berarti antrian bocor. Alternatif tanpa 4 client: naikkan `Balance.COUNT_BASE` sementara | M2 | 4P (atau solo+EDIT) | - |
| WAVE-11 | Match berjalan | Ikuti satu musuh dari titik spawn sampai Core | Musuh melewati waypoint 1 sampai 7 berurutan; tidak memotong jalur dan tidak melompat balik. Sampai di waypoint terakhir dia **berhenti dan tetap ada**: tidak hilang, bar HP-nya masih di atasnya, dia bergeser ke satu titik di cincin sekitar Core dan menghadap Core. Satu-satunya yang menghapusnya adalah pemain yang membunuhnya. Jalurnya dicakup lebih detail oleh BOOT-06, apa yang dia lakukan di base oleh WAVE-17 dan CORE-02 | M1 | solo | - |
| WAVE-12 | Arena 3 lane | Amati spawn selama satu wave | Musuh datang dari ketiga lane **bergantian satu-satu** (lane dibagikan round-robin, bukan acak), bukan menumpuk di satu lane. Delapan musuh wave 1 karena itu terbagi **3-3-2**, bukan rata | M1 | solo | OK |
| WAVE-13 | Match berjalan | Pukul satu musuh sekali, jangan sampai mati | Bar HP kecil (BillboardGui) di atas musuh ikut turun dan panjangnya sesuai sisa HP. Warnanya hijau di atas 50%, kuning di atas 25%, merah di bawahnya | M1 | solo | - |
| WAVE-14 | Wave selesai, state `Intermission` | Amati arena selama jeda | Tidak ada musuh yang masih berjalan dan tidak ada sisa antrian spawn dari wave sebelumnya — state ini baru bisa masuk kalau musuh aktif **dan** antrian dua-duanya nol | M2 | solo | - |
| WAVE-15 | Match berjalan, ada musuh jauh di ujung lane | Menjauh dari musuh sampai lebih dari ~140 stud | Bar HP musuh **hilang dari pandangan** di luar jarak itu (`MaxDistance` 140), lalu muncul lagi saat didekati. Ini bukan bug: tanpa batas jarak, 40 BillboardGui tetap dirender walaupun cuma beberapa piksel | M1 | solo | - |
| WAVE-16 | Wave 4 atau lebih (punya tiga tipe musuh) | Amati urutan kemunculan musuh | Tipe musuh **tercampur** — putaran demi putaran tiap tipe menyumbang satu, bukan semua `basic` dulu lalu semua `fast` lalu semua `tank`. Urutan antrian itu persis urutan kemunculan, jadi kalau terurut per tipe pemain menghadapi komposisi yang berbeda dari yang dirancang | M2 | solo | - |
| WAVE-17 | Wave 1, satu `basic` dibiarkan jalan sampai ujung lane tanpa diserang | Amati musuh itu selama ~15 detik setelah dia berhenti di base, lalu berdiri di sebelahnya, lalu bunuh dia | Tiga hal, berurutan. (1) Musuhnya **tidak hilang**: modelnya tetap ada, bar HP-nya tetap penuh, dia berdiri sekitar 10 stud dari pusat Core dan menghadap Core. (2) Bar Core turun **5 poin tiap 1.2 detik**, berulang, bukan sekali — dalam 15 detik sekitar 13 pukulan, bar jatuh dari 1000 ke sekitar 935. Pukulan pertama jatuh **seketika** saat dia menempel, bukan 1.2 detik sesudahnya. (3) Berdiri tepat di sebelahnya **tidak menariknya keluar** dari base: dia tetap memukul Core dan tidak berbalik mengejar. Setelah dibunuh, modelnya hilang dan bar Core **berhenti turun sama sekali** | M1 | solo | - |
| WAVE-18 | Wave 2 atau lebih (komposisinya berisi `fast`), karakter hidup | Berdiri ~20 stud di samping lane, menyamping dari jalur, dan amati `fast`, `basic`, dan `tank` yang lewat. Lalu berdiri tepat **di atas** jalur satu `basic` (dalam 6 stud darinya). Lalu lari menjauh dari `fast` yang sedang mengejar, lebih dari 40 stud | `fast` (balok hijau) **memutus jalur lane** dan datang lurus ke arah karakter — aggro 25 stud. `basic` dan `tank` dari jarak itu **tidak bergeser sedikit pun** dari lane: aggro-nya 14 dan 8 stud, dan yang menentukan bukan cuma radius itu — `prefer = "base"` berarti mereka tidak pernah keluar lane sama sekali. `basic` yang kita halangi langsung **memukul dari tempatnya berdiri** (HP karakter turun 25 tiap 1.2 detik) sambil tetap di lane, tidak mendekat dan tidak menjauh. `fast` yang kehilangan kita di luar leash 37.5 stud **kembali ke lane** dan melanjutkan ke arah Core — dia tidak pernah kembali ke waypoint yang ada **di belakangnya**, jadi memancingnya mundur berulang kali tidak bisa menahannya di tengah arena selamanya | M1 | solo | - |
| WAVE-19 | Wave 4 atau lebih, biarkan **minimal 6** musuh sampai ke base tanpa dibunuh (boleh juga naikkan `Balance.COUNT_BASE` sementara supaya tidak perlu menunggu) | Amati kumpulan musuh di sekitar Core dari atas, lalu coba serang satu per satu | Musuhnya berdiri **terpisah di sepanjang cincin** sekitar Core, bukan bertumpuk di satu titik: 12 posisi di radius 10, jarak antar tetangga sekitar 5.2 stud — cukup untuk memisahkan `tank` yang 6x6x6. Tiap bar HP bisa dibaca sendiri dan tiap musuh bisa dibidik sendiri tanpa ikut mengenai tetangganya. Musuh ke-13 dan sesudahnya berdiri di **cincin kedua** radius 14, bergeser setengah langkah sudut sehingga tidak tepat di belakang slot cincin pertama. Dua musuh yang berdiri **di titik yang sama persis** adalah GAGAL, tanpa pengecualian: tiap cincin punya radiusnya sendiri (10, 14, 18, ...), jadi nomor slot berapa pun tidak bisa berbagi tempat. Cincin yang makin lebar saat kebocoran menumpuk itu wajar — lihat T10 di [bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug) | M1 | solo (atau solo+EDIT) | - |
| WAVE-20 | Wave 1 berjalan. Biarkan **satu** `basic` sampai ke base, lalu habiskan **semua** musuh lain wave itu sampai antrian spawn juga kosong | Tunggu 30 detik tanpa menyentuh musuh yang menempel di base, amati HUD dan panel toko. Lalu bunuh musuh terakhir itu | Selama musuh di base masih hidup: state tetap **"Bertahan!"**, nomor wave tetap 1 dan **tidak** naik, panel **Toko Match tidak muncul**, dan bar Core terus turun 5 poin tiap 1.2 detik (~130 poin dalam 30 detik). **Ini benar, bukan hang** — wave tidak bisa dinyatakan bersih selama masih ada kebocoran yang hidup, dan Intermission memang ikut tertunda (T8 di [bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug), rancangan bagian 5). Begitu musuh terakhir itu mati, state pindah ke **"Jeda — toko buka · 20s"** dalam **maksimal 0.5 detik** dan panel toko muncul. Yang GAGAL bukan penundaannya, tapi dua hal lain: arena yang sudah benar-benar kosong (nol musuh, nol antrian) tapi state tetap `WaveActive` lebih dari satu detik, atau Core yang berhenti kehilangan HP padahal musuhnya masih menempel | M2 | solo | - |

## 9. Core Server (CORE)

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| CORE-01 | Match baru mulai | Lihat bar Core di HUD | "Core 1000 / 1000", bar penuh | M1 | solo | - |
| CORE-02 | State `WaveActive`, ada musuh berjalan. Satu tipe per percobaan; `tank` butuh wave 4, dua boss butuh wave 5 dan 10 (atau pindahkan `bossId` sementara, prosedurnya di [bagian 12](#12-boss-boss)) | Biarkan satu musuh sampai ke base, catat bar Core tepat sebelum pukulan pertama, lalu hitung penurunannya per pukulan | Bar Core turun **sebesar satu angka tetap, berulang tiap `attackInterval`**, bukan sekali: `basic` **5 tiap 1.2 s**, `fast` **3 tiap 0.8 s**, `tank` **12 tiap 1.5 s**, Splitter **16 tiap 2.0 s**, Locker **24 tiap 2.0 s**. Pukulan pertama jatuh seketika saat musuh menempel. Angkanya = `attackDamage * 0.2`, dan **tidak** dipengaruhi difficulty: `tank` di `hard` tetap 12 per pukulan — yang dikali 1.8 cuma HP musuh. Penurunan baru berhenti kalau musuhnya dibunuh (WAVE-17) atau Core habis | M1 | solo (atau solo+EDIT untuk boss) | - |
| CORE-03 | State `WaveActive`, HP Core hampir habis, dan **ada musuh yang sudah menempel di base** | Biarkan musuh terus memukul sampai HP Core 0 | HP berhenti **tepat di 0**, tidak pernah negatif, dan layar hasil "Core Server jebol" muncul. Seluruh musuh **dibersihkan dari arena, termasuk yang menempel di base** — cincin di sekitar Core ikut kosong, bukan tertinggal berdiri di sana — dan tidak ada pukulan yang masuk setelah itu: bar Core tetap 0 dan tidak ada angka yang bergerak lagi. Output mencetak `[CodeVerse] Core Server hancur` dan `[MatchService] match selesai: kalah di wave N` | M1 | solo | - |
| CORE-04 | State `Intermission` atau `Lobby` | Tunggu tanpa melakukan apa-apa | HP Core tidak berkurang sama sekali — di luar `WaveActive` seluruh loop musuh berhenti, jadi musuh tidak bergerak **dan** tidak memukul. Perhatikan bahwa `Intermission` sendiri cuma bisa dimasuki setelah arena bersih (WAVE-20), jadi tidak akan ada musuh di base yang bisa diamati di sini | M1 | solo | OK |
| CORE-05 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, HP Core sudah berkurang, cash tim ≥ 150 | Beli **Hotfix** | HP Core naik **150** (15% dari 1000) **langsung saat dibeli**, bukan di wave berikutnya; tidak pernah melebihi 1000. Kalau Core sudah penuh, saldo tetap terpotong dan bar tidak berubah — itu benar, bukan bug | M3 | solo | BLOK |
| CORE-06 | Match berjalan, HP Core turun bertahap | Perhatikan warna Part Core di arena | Warnanya bergeser dari warna asli ke merah seiring HP-nya turun, jadi kondisi Core terlihat tanpa melihat HUD | M1 | solo | OK |

## 10. Combat (COMBAT)

Acuan: DEVELOPMENT_PLAN.md bagian 3.7, dan untuk COMBAT-18 sampai COMBAT-25
`ARENA_REDESIGN.md` lampiran A.

> **Tiga prasyarat yang berlaku untuk setiap angka damage di kelompok ini, dan
> ketiganya mudah terlewat.**
>
> 1. **Jangan beli Exploit Patch atau Overclock di match yang sedang dipakai
>    mengukur.** `CombatService.onAttack` mengalikan pengali toko **di atas**
>    `stats.damage` dan `stats.cooldown` yang sudah termasuk alur
>    (`damage = stats.damage * mods.damageMult`), jadi satu Exploit Patch
>    menggeser setiap angka di bawah 10% dan membuatnya tidak bisa dibandingkan
>    dengan tabel [bagian 4.2](#42-angka-patokan). Damage splash ikut terkali,
>    karena dia dihitung dari `damage` yang sudah dikali. **Hari ini prasyarat
>    ini gratis**: kelima item dimatikan, jadi pengali toko selalu 1.0 — tapi
>    dia berlaku lagi begitu `Config.MATCH_SHOP_ITEMS_ENABLED` dinyalakan.
> 2. **Level dan alur senjata harus seperti yang ditulis di kolom Prakondisi.**
>    Sejak langkah 7 rancangan ulang arena, tingkat alur menggeser damage,
>    cooldown, jangkauan, dan jumlah proyektil, jadi baris yang tidak menyebut
>    level dijalankan dengan senjata **di bawah titik percabangan** (level 1
>    sampai 3) dan baris COMBAT-18 ke atas menyebut level dan alurnya persis.
> 3. **`Config.DEFAULT_DATA.weapons` TIDAK LAGI menentukan level dan alur yang
>    berlaku di arena.** Ini yang paling mudah membuat seluruh kelompok ini
>    terbaca GAGAL padahal yang salah cuma persiapannya. `CombatService`
>    membaca level dan alur dari **save dalam match** milik ShopService
>    (`CombatService.setMatchWeaponSource(ShopService.getMatchWeapon)` di
>    `init.server.luau`), bukan dari `data.weapons` — jadi menulis
>    `{ level = 7, path = "a" }` di `Config.DEFAULT_DATA` sekarang **tidak
>    mengubah satu angka pun di arena**, dan juga tidak terlihat di panel lobby
>    yang sudah tidak menampilkan level. Jalan pintas yang menggantikannya ada
>    di kotak [bagian 13](#13-progres-permanen-dan-data-player-prog), dan yang
>    paling murah di antaranya: ubah kembalian `MatchUpgradeRules.freshSave()`
>    jadi `{ level = 7, path = "a" }`, lalu **balikkan sebelum commit**.
>
> Jadi notasi `{ level = N, path = "x" }` di kolom Prakondisi kelompok ini
> sekarang berarti **save dalam match** — apa yang dikembalikan
> `ShopService.getMatchWeapon` untuk pemain itu, yang juga yang ditampilkan
> judul panel toko sebagai "Nama · level N/10". Dia dicapai dengan dua cara:
> membeli upgrade-nya di jeda antar wave dengan cash, atau mengedit
> `freshSave()` di atas. Keadaan itu **hilang tiap match selesai**, jadi tiap
> percobaan dimulai dari match yang baru.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| COMBAT-01 | State `WaveActive`, `weapon_starter` ter-equip, musuh di depan karakter dalam 17 stud | Klik kiri | Musuh terkena: **bar HP-nya turun**. Tidak ada efek hit dan tidak ada angka damage — itu M7 (`FxController`), dan `EnemyHit` diterima client lalu dibuang (keputusan T4). Bar HP turun adalah satu-satunya umpan balik yang benar sekarang | M1 | solo | - |
| COMBAT-02 | Musuh HP tinggal sedikit | Serang sampai HP-nya 0 | Musuh hilang dari arena tanpa sisa model; angka cash di HUD naik sesuai tipe musuh (`basic` +5, `fast` +7, `tank` +15). Cash itu masuk ke **kamu**, bukan ke kolam tim: yang membunuh yang dibayar ([bagian 4.2](#42-angka-patokan)). Labelnya masih berbunyi "N cash tim" dan itu teks yang belum menyusul ([bagian 5.4](#54-teks-yang-belum-menyusul-perubahan)) — yang dinilai di baris ini angkanya, bukan katanya | M1 | solo | - |
| COMBAT-03 | `weapon_starter` **level 1 sampai 3** — di bawah titik percabangan, supaya kerucut dan jangkauannya yang dasar. Musuh **di belakang** karakter, atau lebih dari 17 stud di depan | Klik kiri | Tidak ada damage ke musuh itu; tidak ada error di Output server. Kerucut melee ~78 derajat setengah sudut dengan jangkauan `range` 12 + 5 stud toleransi. Kedua angka itu **berhenti berlaku di atas level 3**: alur `a` tingkat 2 melebarkan kerucutnya ke ~96 derajat (COMBAT-19) dan alur `c` tingkat 2 menaikkan `range` ke 18 sehingga jangkauan efektifnya 23 stud. Jadi baris ini dijalankan dengan senjata di bawah titik percabangan, dan musuh yang kena di level 7 bukan regresi dari baris ini | M1 | solo | - |
| COMBAT-04 | State `WaveActive`, `weapon_starter` **di bawah level 4** (cooldown-nya 0.5 apa adanya; empat alur menggesernya ke 0.7, 0.32, atau 0.25 — [bagian 4.2](#42-angka-patokan)), musuh di depan | Klik secepat mungkin, jauh lebih cepat dari cooldown 0.5 detik | Damage yang masuk mengikuti cooldown senjata (maksimal ~2 kali per detik), bukan kecepatan klik. **Server yang menolak kelebihannya**, dengan toleransi 50 ms untuk jitter jaringan. Serangan berlebih diabaikan tanpa error | M1 | solo | - |
| COMBAT-05 | Network Simulation **Bad Internet** atau **Terrible**, musuh `fast` sedang bergerak | Serang musuh `fast` yang berjalan 10 kali sambil membidik ke arahnya | Minimal 8 dari 10 kena. Sesekali tidak kena itu normal; **sering** tidak kena berarti toleransinya masih terlalu ketat. Kalau gagal, naikkan `Balance.MELEE_RADIUS_BONUS` — **jangan** mencari bug di `HitTest`, karena penyebabnya memang latensi, bukan geometri | M1 | LAG | - |
| COMBAT-06 | Network Simulation masih aktif, `weapon_ranged` ter-equip | Tembak musuh `fast` yang bergerak 10 kali | Sebagian besar kena: yang dipakai **silinder radius 5 stud di sekitar garis bidik**, bukan garis setebal nol. (Bagian 3.7 menyebut "spherecast"; yang diimplementasikan silinder, dan itu memenuhi maksudnya) | M5 | LAG | - |
| COMBAT-07 | `weapon_ranged` dimiliki dan ter-equip **di bawah level 4**, musuh sekitar 40-55 stud jauhnya | Bidik dan serang | Musuh jauh terkena damage tanpa perlu mendekat (`range` 60 stud). Angka 60 itu range **dasar**, dan dua dari tiga alur Packet Rifle menggesernya di level 7: alur `a` Sniper ke **90** dan alur `b` Semburan ke **40** — jadi musuh pada 50 stud yang kena di baris ini **tidak** kena lagi di Semburan level 7, dan itu bukan regresi (PROG-28) | M5 | solo | - |
| COMBAT-08 | `weapon_ranged` ter-equip, musuh **jelas** di luar 60 stud — lebih dari 5 stud melewati batas | Bidik dan serang | Tidak ada damage; tidak ada error. Proyeksinya di-clamp di 60 stud, jadi musuh yang cuma beberapa stud melewati batas masih bisa kena silinder radius 5 — itu toleransi yang disengaja, bukan bug | M5 | solo | - |
| COMBAT-09 | `weapon_boss_a` ter-equip — dimiliki sejak awal, jadi tidak perlu di-craft dulu ([bagian 4.2](#42-angka-patokan)) — tiga musuh **sejajar di garis bidik** (bukan sekadar berkerumun) | Bidik melewati ketiganya dan serang sekali | Sampai **3 musuh** kena dalam satu serangan, dipilih yang paling dulu dilewati garis bidik (`projectiles = 3`). Bukan "membelah jadi 3 proyektil" — yang diimplementasikan adalah satu silinder bidik yang mengenai maksimal 3 musuh. Angka 3 itu `projectiles` **dasar**, dan ketiga alur Fork Bomb menggesernya: `a` Shotgun ke 5 di level 4 lalu 7 di level 10, dan `b` Ledakan turun ke **1** di level 4 (yang mengenai beberapa musuh di situ splash-nya, bukan proyektilnya — COMBAT-18). Jadi baris ini dijalankan dengan Fork Bomb di bawah level 4 | M5 | solo | - |
| COMBAT-10 | Karakter player mati / sedang respawn saat `WaveActive` | Coba menyerang | Serangan ditolak server (origin tidak ada kalau Humanoid mati); tidak ada damage; tidak ada error | M1 | solo | - |
| COMBAT-11 | State `Lobby` atau `Intermission` | Coba menyerang lewat klik, lalu lewat `R.Attack:FireServer(Vector3.new(0, 0, 1))` dari command bar client | Tidak ada damage ke musuh mana pun; server menolak karena state salah; tidak ada error | M2 | solo | - |
| COMBAT-12 | `weapon_starter` level 1, lalu di-upgrade ke level 5 **di dalam match lewat panel Toko Match** (bukan di lobby — upgrade lobby sudah tidak ada); `basic` di wave 2 di dua kondisi itu. Empat upgrade dari level 1 memakan `150 + 202 + 273 + 369` = **994** cash, jadi jeda setelah wave 3 titik paling awal yang terjangkau tanpa edit; dengan `Balance.MATCH_UPGRADE_BASE_PRICE = 1` keempatnya muat di jeda pertama (`solo+EDIT`). Jalan ke level 5 melewati titik percabangan, jadi satu alur harus dipilih di level 4 — dan **alurnya harus `c` Bertahan**, bukan sembarang alur. Sejak langkah 7 pilihannya menggeser damage: tingkat 1 alur `c` cuma menyetel `effects.damageTakenMult`, jadi dia satu-satunya yang membiarkan kurva damage generik terbaca apa adanya | Hitung serangan untuk membunuh satu musuh | Level 1 (25 damage) = **5** serangan, level 5 alur `c` (37 damage) = **4** serangan. Kurva damage upgrade terasa di match. Yang membuat baris ini butuh alur yang disebut: alur `a` Ayunan Berat di level 5 memberi `37 * 1.5` = **55.5** damage dan **3** serangan, jadi menjalankan baris ini dengan alur `a` memberi angka yang benar tapi bukan angka yang diuji — dan angka 4 yang muncul dengan alur `a` berarti `damageMult` tidak sampai ke `weaponStats`. Alur `b` Ayunan Cepat juga memberi 4 serangan, tapi cooldown-nya 0.32 dan jumlah serangan yang sama itu datang dalam separuh waktu, jadi penghitungan dengan stopwatch jadi tidak bisa dibandingkan | M5 | solo | - |
| COMBAT-13 | `weapon_starter` ter-equip **di bawah level 10**, beberapa musuh berdekatan di depan | Serang sekali | **Hanya satu** musuh yang kena, yang terdekat (`projectiles = 1`). Serangan yang mengenai beberapa musuh sekaligus adalah milik `weapon_boss_a` (COMBAT-09), bukan starter — **kecuali** Patch Wrench alur `a` Ayunan Berat di **level 10**, yang menyetel `projectiles = 3` dan mengenai sampai 3 musuh dengan damage penuh masing-masing. Jadi tiga musuh yang kena di level 10 alur `a` adalah hal yang benar, dan baris ini dijalankan di bawah level 10 supaya yang diuji tetap perilaku dasarnya | M1 | solo | - |
| COMBAT-14 | State `Intermission` (panel toko terbuka) dan `Lobby` (panel lobby terbuka) | Klik tombol di panel itu, lalu amati Output server dan HP musuh | Kliknya tidak memicu serangan. Catatan: di v1 ini **tidak bisa benar-benar membuktikan apa pun**, karena di kedua state itu `Attack` sudah ditolak gerbang state, dan selama `WaveActive` tidak ada satu pun tombol UI yang terlihat. Penjaga "input yang sudah dipakai UI tidak diteruskan" memang ada di `InputController`, tapi baru bisa diuji sungguhan setelah M7 menambah tombol UI yang aktif di tengah wave. Dicatat supaya tidak lupa diulang saat itu | M3 | solo | - |
| COMBAT-15 | State `WaveActive`, musuh di depan | **Tahan** tombol kiri, jangan klik berulang | Serangan terkirim terus selama tombol ditahan (client mengirim 8 kali per detik, server menerapkan cooldown senjata). Tidak perlu mengklik berkali-kali | M1 | solo | - |
| COMBAT-16 | Wave 2 atau lebih (komposisinya berisi `fast`), karakter HP penuh 100, **jangan menyerang sama sekali** | Berdiri di dekat lane sampai satu `fast` datang mengejar, biarkan dia memukul sampai karakter mati, lalu hitung detik sampai karakter kembali | Bar HP karakter turun **15 tiap 0.8 detik** — pukulan pertama jatuh begitu `fast` masuk 6 stud, tidak menunggu interval — dan karakter **mati setelah 7 pukulan**, sekitar 4.8 detik. Karakter kembali **5 detik** sesudahnya (`Balance.RESPAWN_SECONDS`) di `Arena/PlayerSpawn` dengan HP penuh 100, **tanpa** kehilangan nyawa, cash tim, atau progres apa pun — tidak ada sistem nyawa di v1. Selama mati, klik tidak men-damage musuh mana pun dan Output server tidak mengeluarkan error (COMBAT-10). Musuh yang membunuh kita **melepas targetnya** dan kembali berjalan ke base, tidak menunggu di tempat kita mati. Sementara kita mati, musuh di base **terus memukul Core** — bar Core tetap turun selama 5 detik itu | M1 | solo | - |
| COMBAT-17 | Satu tipe per percobaan, karakter HP penuh 100, jangan menyerang. `tank` butuh wave 4; dua boss butuh wave 5 dan 10 (atau pindahkan `bossId` sementara) | Berdiri dalam 6 stud dari musuh itu dan hitung pukulan sampai karakter mati | Jumlah pukulannya tetap dan bisa dihitung: `basic` **4** (25 per pukulan tiap 1.2 s), `fast` **7** (15 / 0.8 s), `tank` **2** (60 / 1.5 s), Splitter **2** (80 / 2.0 s), Locker **1** (120 / 2.0 s — satu pukulan dari HP penuh langsung mematikan). Angka ini **tidak** berubah di `hard` dan tidak berubah dengan jumlah player: `attackDamage` tidak dikali pengali difficulty, cuma HP musuh yang dikali. `basic` dan `tank` memukul **dari tempatnya berdiri di lane** tanpa mengejar (WAVE-18) | M1 | solo (atau solo+EDIT untuk boss) | - |
| COMBAT-18 | Fork Bomb dimiliki dan ter-equip di **level 4 alur `b` Ledakan** (save dalam match; lihat kotak prasyarat di atas — tiga upgrade dengan cash di jeda, atau `freshSave()` yang dikembalikan `{ level = 4, path = "b" }`). Wave 2 atau lebih, dan **tiga `basic` yang berkerumun** dalam 8 stud satu dari yang lain — paling mudah di cincin base, karena musuh yang sudah menempel di situ tidak bergerak lagi | Bidik satu musuh di tengah kerumunan dan serang **sekali**. Catat HP ketiganya sebelum dan sesudah | Proyektilnya **1**, bukan 3 (tingkat 1 menyetel `projectiles = 1`), jadi cuma **satu** musuh yang kena penuh — tapi ketiganya kehilangan HP. Target utama turun **40.8**, dua tetangganya turun **20.4** masing-masing (`splashMult` 0.5 dari damage penuh, radius 8 stud). Bar HP ketiganya turun dari satu klik, dan **tidak ada apa pun yang terlihat meledak** — tidak ada efek splash, sama seperti zona di T15. **Yang paling penting di baris ini:** target utama turun **40.8 dan bukan 61.2**. Kalau dia turun 61.2 dia kena dua kali — sekali penuh, sekali lagi sebagai korban splash-nya sendiri — dan gejalanya cuma damage senjata yang terlihat lebih besar daripada yang tertulis di panel, yaitu kegagalan termahal di antara seluruh efek alur karena tidak ada yang akan melaporkannya. `CombatService.onAttack` mengecualikannya lewat tabel `struck` yang dioper ke `CombatEffects.withinRadius`. Musuh yang **lebih dari 8 stud** dari titik kena tidak boleh turun sedikit pun. Lalu ulangi di **level 10** (`{ level = 10, path = "b" }`): target utama **62.4**, korban splash **46.8**, radius **12 stud** — jadi kerumunan yang sama sekarang mengenai lebih banyak musuh. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| COMBAT-19 | `weapon_starter` ter-equip di **level 7 alur `a` Ayunan Berat** (save dalam match `{ level = 7, path = "a" }`; lihat kotak prasyarat di atas — `Config.DEFAULT_DATA` tidak lagi berpengaruh di sini). Satu musuh berdiri **di samping** karakter, kira-kira tegak lurus arah pandang, dalam 17 stud | Hadap lurus ke depan sehingga musuh itu ada di sisi kiri atau kanan, lalu klik. Ulangi dengan musuh yang jelas **di belakang** karakter | Musuh di samping **kena**: ambang kerucutnya turun dari `Balance.MELEE_MIN_COS` 0.2 (≈78.5° setengah sudut) ke **-0.1** (≈**95.7°**), jadi ayunannya sekarang mencakup lebih dari separuh lingkaran di sekitar pemain dan musuh yang sudah sedikit di belakang garis samping ikut kena. Musuh yang **jelas di belakang** tetap tidak kena — 95.7° bukan 180°. Bandingkan dengan COMBAT-03 yang dijalankan dengan senjata level 1: musuh di samping yang **tidak** kena di situ dan **kena** di sini adalah seluruh buktinya. Arah angkanya terbalik dari yang intuitif dan itu yang paling mudah salah dikodekan: **cos yang lebih kecil berarti kerucut lebih lebar**, jadi kalau musuh di samping justru berhenti kena sesudah upgrade ini, tandanya `coneMinCos` dipakai dengan perbandingan yang terbalik. Damage-nya juga sekaligus terbaca: **64.5**, bukan 43. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| COMBAT-20 | `weapon_starter` ter-equip di **level 4 alur `c` Bertahan** (`{ level = 4, path = "c" }`), karakter HP penuh 100, **jangan menyerang sama sekali**. Wave 2 atau lebih supaya ada `fast` | Berdiri dalam 6 stud dari satu `basic` dan hitung pukulan sampai karakter mati. Ulangi dengan `fast`. Lalu ulangi keduanya dengan `{ level = 10, path = "c" }` | Damage masuk dikali **0.75** di level 4: `basic` 25 jadi **18.75** per pukulan dan karakter mati setelah **6** pukulan (bukan 4), `fast` 15 jadi **11.25** dan mati setelah **9** (bukan 7). Di level 10 pengalinya **0.55**: `basic` **8** pukulan, `fast` **13**. **Jaraknya tetap `attackInterval` yang sama** — 1.2 detik untuk `basic`, 0.8 untuk `fast` — karena alur ini mengurangi damage, **bukan** membuat musuh berhenti memukul; jadwal pukulan berikutnya tetap disetel. Musuh yang terlihat **berhenti memukul** adalah GAGAL, dan gejalanya terbalik dari yang diharapkan: pemain merasa dilindungi sempurna, bukan merasa dirugikan, jadi tidak ada yang melaporkannya. Baris ini juga sekaligus menguji satu batas yang tidak bisa dicapai lewat UI: pengali di luar rentang (0, 1] **diabaikan** dan `CombatService.getPlayerDamageTakenMult` mengembalikan 1 — jadi `{ level = 4, path = "c" }` dengan `effects.damageTakenMult` diubah sementara ke 0 atau ke 1.5 di `Weapons.luau` harus memberi damage **penuh** 25, bukan nol dan bukan 37.5. Balikkan kedua file sebelum commit | M5 | solo+EDIT | - |
| COMBAT-21 | Packet Rifle dimiliki dan ter-equip di **level 10 alur `c` Dukungan** (`{ level = 10, path = "c" }` pada `weapon_ranged`). Wave 2 atau lebih dengan **empat atau lebih** `basic` berkerumun di cincin base, dan catat HP semuanya | Tembak **satu** musuh di kerumunan sekali, lalu tembak **musuh lain yang berdekatan dengannya** sekali, lalu baca HP keduanya | Tembakan pertama memberi **29.12** ke target dan menandai **tiga** musuh: targetnya sendiri plus **dua musuh terdekat dari titik kena** (`markSpread` 2). Tembakan kedua ke salah satu musuh yang **tertular** memberi **40.768**, yaitu 29.12 x1.4 — itu buktinya penularannya sampai. Musuh keempat yang lebih jauh tetap menerima **29.12**. Dua hal yang akan terlihat aneh dan dua-duanya benar: tembakan pertama ke target utama **tidak** ikut terkali 1.4 (`EnemyService.damage` dipanggil sebelum `applyMark`), dan **tidak ada tanda visual apa pun** di musuh yang tertular. **Yang GAGAL:** cuma target utama yang terkali di tembakan berikutnya — berarti `markSpread` tidak dibaca; atau tiga musuh yang ditandai ternyata termasuk target utama **dua kali** sehingga cuma dua musuh total yang bertanda, karena `CombatEffects.nearest` menerima tabel `struck` sebagai `exclude` dan target utama seharusnya sudah tidak ikut dipilih. Pilihan "musuh terdekat" itu deterministik lewat pemecah seri id, jadi mengulang percobaan yang sama harus menandai **dua musuh yang sama**, bukan dua yang berbeda tiap kali. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| COMBAT-22 | **Dua client.** Client A memakai Packet Rifle **level 7 alur `c` Dukungan**, client B memakai Patch Wrench **level 1** (jadi damage-nya 25 apa adanya dan mudah dihitung). Level dan alur A dicapai dari dalam match — enam upgrade dengan cash, atau `freshSave()` yang dikembalikan `{ level = 7, path = "c" }` (lihat kotak prasyarat di atas). Perhatikan bahwa edit `freshSave()` berlaku untuk **kedua** pemain sekaligus, jadi B harus dibiarkan di level 7 alur `c` juga atau dipakai senjata yang alurnya tidak menyentuh damage; kalau B harus benar-benar level 1, jalurnya cuma membeli upgrade untuk A dengan cash. Packet Rifle sudah dimiliki sejak awal, jadi tidak ada flag yang perlu dinyalakan supaya A bisa memakainya. Wave 2 atau lebih, satu `basic` di cincin base, catat HP-nya | B menyerang `basic` itu **sekali** dan catat selisih HP. Lalu A menembaknya sekali (yang memasang tanda). Lalu B menyerang **sekali lagi** dan catat selisihnya | Serangan B yang pertama memberi **25**. Serangan B yang **kedua** memberi **35** — 25 x1.4 — walaupun B tidak mengubah apa pun, tidak meng-upgrade apa pun, dan senjatanya tidak punya `effects` sama sekali. Itu seluruh guna alur Dukungan, dan ini satu-satunya baris di dokumen ini yang bisa membuktikannya: tandanya diterapkan di `EnemyService.damage`, jadi dia berlaku untuk **semua** sumber damage, bukan cuma untuk penandanya. Tembakan A sendiri memberi **24.08** (belum terkali, karena `damage` dipanggil sebelum `applyMark`). Tanda habis setelah **4 detik** (`markSeconds`), jadi serangan B yang ketiga lebih dari 4 detik sesudah tembakan A kembali memberi **25** — itu bukan tanda yang rusak. **Yang GAGAL:** serangan B yang kedua tetap 25, yang berarti pengalinya pindah ke `CombatService` dan berlaku cuma untuk penandanya; atau B justru memberi 35 **sebelum** A menembak, yang berarti ada tanda yang lahir tanpa ada yang memasangnya. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | 2P | - |
| COMBAT-23 | `weapon_starter` ter-equip di **level 7 alur `b` Ayunan Cepat** (`{ level = 7, path = "b" }`). Wave 2 atau lebih, satu `fast` sedang **berjalan di lane** (bukan mengejar, supaya kecepatannya yang terukur dan bukan arahnya) | Pukul `fast` itu sekali saat dia lewat, lalu amati geraknya selama dua detik berikutnya. Lalu ulangi dengan `{ level = 10, path = "b" }` | `fast` yang kena **jelas melambat**: speed-nya 16 jadi **10.4** (x0.65) selama **1.5 detik**, lalu kembali normal sendiri. Di level 10 pengalinya **x0.5** jadi **8.0**, dan durasinya masih 1.5 detik — tingkat 3 cuma menulis `slowMult`, dan `slowSeconds` tingkat 2 **dipertahankan** karena `effects` digabung per kunci. Slow ini **menempel ke musuh**, jadi dia ikut ke mana pun musuhnya jalan — bedakan dari zona di COMBAT-24 yang berhenti begitu musuh keluar radius. Satu pukulan berikutnya yang lebih **lemah** tidak boleh membatalkan yang kuat: dengan cooldown 0.32 detik pemain memukul beberapa kali dalam satu durasi slow, dan kalau "terbaru menang" musuhnya akan kadang melambat kadang tidak tanpa pola. Harness sudah membuktikan slow benar-benar sampai ke gerak Part (rasio 0.36 untuk pengali 0.40) dan bahwa pukulan lemah tidak membatalkannya, jadi yang tersisa di sini **cuma** bahwa `stats.effects.slowMult` dari alur ini yang memasangnya lewat `onAttack` — dan bahwa pemain bisa melihatnya. Musuh yang **berhenti total** adalah GAGAL: pengalinya dipakai sebagai pengganti kecepatan, bukan pengali. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| COMBAT-24 | Fork Bomb ter-equip di **level 10 alur `c` Jebakan** (`{ level = 10, path = "c" }`; dimiliki sejak awal, tidak ada flag yang perlu dinyalakan). Wave 2 atau lebih, satu musuh sudah menempel di cincin base sehingga dia **berdiri diam**, dan catat HP-nya | Tembak musuh yang berdiri diam itu **sekali**, lalu jangan sentuh apa pun selama 3 detik dan amati HP-nya. Lalu tembak **ke udara** (tidak mengenai musuh mana pun) dan amati tempat itu. Lalu ulangi dengan `{ level = 4, path = "c" }` | Tembakan itu memberi **62.4** sekaligus meninggalkan zona di titik kena: **radius 12 stud, umur 3 detik, slow x0.45, 6 damage per detik**. Jadi HP musuh terus turun sesudah tembakannya berhenti, total kira-kira **18** selama 3 detik, lalu berhenti sendiri. Musuh lain yang masuk radius itu ikut melambat ke **3.6 stud/detik** untuk `basic` dan keluar dari pengaruhnya begitu dia melewati batas 12 stud — zona menempel ke **TEMPAT**, bukan ke musuh. **Tidak ada Part, efek, atau apa pun yang terlihat di titik itu** (T15); itu kekurangan yang diketahui dan bukan bug. Tembakan **ke udara tidak meninggalkan zona apa pun**: titik kenanya dibaca dari posisi musuh pertama yang kena, jadi serangan tanpa korban melewati seluruh blok itu — zona yang lahir dari tembakan kosong adalah GAGAL, karena pemain bisa melapisi seluruh lane tanpa membidik apa pun. Di level 4 zonanya **radius 8, slow x0.6, dan dps 0**: musuh melambat tapi HP-nya **tidak** turun sedikit pun, dan itu benar — `zoneDps` baru ada di tingkat 3. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| COMBAT-25 | Fork Bomb ter-equip di **level 10 alur `c` Jebakan** (sama dengan COMBAT-24). Satu match dijalankan sampai selesai — menang atau kalah — dengan beberapa zona ditinggalkan di dekat Core **di detik-detik terakhir**, lalu match **kedua** dimulai tanpa restart server | Di match kedua, catat HP musuh pertama wave 1 begitu dia muncul dan amati selama beberapa detik **tanpa menyerangnya sama sekali** | HP musuh pertama **tidak turun sedikit pun** selama tidak ada yang menyerangnya: `EnemyService.clearAll()` membuang seluruh daftar zona bersama musuhnya, jadi tidak ada zona dari match sebelumnya yang masih hidup. Umur zona cuma 3 detik sehingga membiarkannya hampir tidak terlihat — tapi "hampir" itu match baru yang wave 1-nya dimulai dengan zona perlambat dan dps dari match sebelumnya, dan gejalanya musuh pertama yang jalannya aneh dan kehilangan HP tanpa ada yang menembaknya, di detik ketika belum ada apa pun yang bisa dicurigai. Dibuktikan **seluruhnya** oleh harness Studio (`zona.dibuangSaatClearAll` di `path_effects`, yang menaruh zona dps 200 lalu memanggil `clearAll` lalu memeriksa HP musuh baru), dan harapannya tidak punya bagian client sama sekali — jadi baris ini `OK` tanpa perlu dijalankan tangan, sesuai [bagian 3.2](#32-cakupan-harness-studio) | M5 | solo | OK |

## 11. Toko Match (SHOP)

Acuan: DEVELOPMENT_PLAN.md bagian 3.6 dan M3. Harga upgrade, kurva harga item
yang lama, dan hadiah cash per wave ada di [bagian 4.2](#42-angka-patokan).

**Yang dijual toko ini berubah, dan itu membelah kelompok ini jadi dua.**
Mekanismenya dulu: Toko Match menjual lima item berefek **tim** (Exploit Patch,
Overclock, Hotfix, Firewall Block, Scanner Turret) dari satu kolam cash **tim**,
dengan harga yang naik x1.25 tiap kali item yang sama dibeli; sementara upgrade
senjata hidup di lobby, dibayar koin permanen, dan alur yang dipilih di level 4
mengunci senjata itu selamanya.

Sekarang kelima item **dimatikan** lewat `Config.MATCH_SHOP_ITEMS_ENABLED`, dan
yang dijual tiap jeda antar wave adalah **upgrade senjata pemain itu sendiri**
beserta ketiga alurnya, dibayar cash. Dua akibat yang menentukan bagaimana
kelompok ini dibaca:

- **Dua belas baris di bawah menguji fitur yang dimatikan** dan berstatus
  `BLOK`:
  SHOP-01 sampai SHOP-06, SHOP-09, SHOP-12, SHOP-16, SHOP-20, SHOP-21, dan
  SHOP-22 (ditambah CORE-05 dan MP-14 di kelompok lain). Penolakannya **di
  server**, bukan cuma panel yang disembunyikan, jadi tidak ada jalan memutar
  lewat remote. Baris-barisnya **tidak dihapus**: aturan, harga, efek, dan unit
  test-nya masih benar dan masih lulus, dan satu baris di `Config.luau`
  (`MATCH_SHOP_ITEMS_ENABLED = true`) membuat semuanya bisa dijalankan lagi apa
  adanya.
- **Delapan baris baru, SHOP-25 sampai SHOP-32, menguji toko upgrade.** Panel
  yang muncul saat jeda, harga per level, cash yang berkurang persis sebesar
  angka di tombol, tiga kartu alur di level 4, alur yang tidak bisa diganti di
  match yang sama, level yang kembali 1 di match berikutnya, tombol yang mati
  saat cash kurang, dan kunci Locker yang — berbeda dari pembelian item —
  **masih benar-benar menolak sesuatu**.

Satu hal lagi yang menggeser setiap angka saldo di bawah: **cash sekarang per
pemain, bukan satu kolam tim** ([bagian 4.2](#42-angka-patokan)). Baris yang
dulu menuntut "angkanya sama di keempat client" sekarang menuntut sebaliknya.
Perilaku itu dijelaskan sebagai T17, T18, dan T19 di
[bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug).

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| SHOP-01 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission` | Lihat panel Toko Match di kanan layar | Lima item **dalam urutan ini**: Exploit Patch (200), Overclock (200), Hotfix (150), Firewall Block (100), Scanner Turret (250). Urutannya dari `ShopItems.order` — kalau berubah-ubah tiap kali client dibuka, daftar itu tidak dipakai. Header menampilkan "N cash tim", dan angkanya naik setiap musuh mati selama wave berjalan **dan melompat sekali saat wave selesai** (hadiah per wave, SHOP-17). Hanya **Firewall Block** yang memuat "· sisa N" — empat item lain tak terbatas, jadi barisnya berbunyi "200 cash — ..." tanpa sisa. Baris yang memuat "· sisa N" untuk kelima item berarti jatah yang sudah dihapus masih dipakai | M3 | solo | BLOK |
| SHOP-02 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, cash tim ≥ 200, Exploit Patch **belum pernah dibeli** di match ini, dan `weapon_starter` **level 1 dengan `path = "none"`** — dua angka serangan di kolom harapan dihitung dari damage 25, dan pengali toko berlaku **di atas** damage yang sudah termasuk alur, jadi senjata ter-upgrade memberi angka lain ([bagian 4.2](#42-angka-patokan)) | Beli **Exploit Patch**, lanjut ke wave berikutnya, hitung serangan untuk membunuh satu `tank` | Cash turun 200 — itu harga pembelian **pertama**; yang kedua 250 dan seterusnya naik x1.25 (SHOP-20). Damage semua pemain naik **+10% linear** (bukan berlipat): satu pembelian 1.1x, lima pembelian 1.5x — bukan 1.61x. Paling mudah diukur di `tank` karena HP-nya besar. Di `basic` wave 2, satu Exploit Patch belum mengubah jumlah serangan (tetap 5); tiga pembelian membuatnya 4 | M3 | solo | BLOK |
| SHOP-03 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, cash tim ≥ 200 | Beli **Overclock**, lanjut ke wave berikutnya | Jeda antar serangan terasa lebih pendek: cooldown turun **-8% linear per pembelian**, dengan lantai 0.4x. Tahan klik kiri dan bandingkan ritme bar HP musuh turun, sebelum dan sesudah beli | M3 | solo | BLOK |
| SHOP-04 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, HP Core sudah berkurang | Beli **Hotfix** | Lihat CORE-05: +150 HP langsung, tidak melebihi 1000 | M3 | solo | BLOK |
| SHOP-05 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, cash tim ≥ 100 untuk bagian pertama dan ≥ 281 untuk bagian kedua (pembelian ke-2 dan ke-3 berharga 125 dan 156). Penumpukan durasi dihitung **per jeda**, bukan per match, jadi pembelian dari jeda sebelumnya tidak ikut memperpanjang | Beli **Firewall Block** satu kali, lanjut ke wave berikutnya. Lalu ulangi dengan membeli **dua** kali | Dinding biru tembus pandang muncul di tengah **kedua** lane tepat saat wave berikutnya mulai, dan musuh di lane itu **berhenti bergerak** 6 detik, lalu jalan lagi. Dua pembelian menggandakan **durasi blokirnya** jadi 12 detik, bukan jumlah dindingnya — dan dindingnya hilang **tepat** saat musuh mulai jalan lagi, 12 detik juga. Kalau dinding hilang di detik 6 sementara musuh masih tertahan, temuan T5 kembali | M3 | solo | BLOK |
| SHOP-06 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, cash tim ≥ 250, dan Scanner Turret belum pernah dibeli di match ini | Beli **Scanner Turret**, lanjut ke wave berikutnya. Lalu beli turret kedua — harganya **312**, bukan 250 lagi | Balok hijau-kebiruan muncul mengelilingi Core (radius 26 stud). Saat wave jalan, dia menembak musuh terdekat sendiri — 12 damage tiap 1 detik, radius 70 stud — dan HP musuh turun tanpa kamu menyerang. Musuh yang mati karena turret tetap memberi cash **tim**. Turret kedua muncul di sudut berbeda, tidak menumpuk. Turret **tidak** menembak saat `Intermission` | M3 | solo | BLOK |
| SHOP-07 | State `WaveActive`, sebagai peserta. Pasang listener dulu di command bar client: `R.ActionResult.OnClientEvent:Connect(print)` | `R.BuyShopItem:FireServer("shop_barrier")` | Ditolak dengan **"Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata."** — bukan lagi "Toko cuma buka saat jeda antar wave." Gerbang `Config.MATCH_SHOP_ITEMS_ENABLED` diperiksa **sesudah** keanggotaan peserta tapi **sebelum** `ShopRules.canBuy`, jadi penolakan state untuk `BuyShopItem` tidak bisa dipicu dari mana pun selama item dimatikan — yang menggantikannya SHOP-31, lewat `UpgradeWeapon`. Cash tidak berubah; tidak ada efek item; tidak ada error di Output server. Yang dinilai di sini penolakan itu **di server**: client yang dimodifikasi tetap bisa menembakkan remote ini, dan fitur yang masih bisa dibeli lewat remote bukan fitur yang dimatikan | M3 | solo | - |
| SHOP-08 | State `Lobby`, listener `ActionResult` masih terpasang | `R.BuyShopItem:FireServer("shop_barrier")` | Ditolak, tapi alasannya **berbeda** dari SHOP-07: **"Kamu bukan peserta match ini."** — di Lobby `participants` sudah dikosongkan, dan pemeriksaan peserta jalan sebelum pemeriksaan state. Cash tidak berubah | M3 | solo | - |
| SHOP-09 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, cash tim **kurang** dari harga item, dan Scanner Turret **belum pernah dibeli** di match ini — kalau sudah, harga di pesan penolakan bukan 250 lagi tapi harga sekarang (312, 390, ...) | Perhatikan tombol **Scanner Turret** (250), lalu coba klik, lalu ulangi lewat `R.BuyShopItem:FireServer("shop_turret")` | Tombolnya abu-abu dan **mengkliknya tidak mengirim apa pun**. Lewat remote: ditolak dengan "Cash tim kurang: butuh 250, ada N." — dan alasan itu **ikut muncul merah di baris status panel toko** selama 4 detik, lalu kembali ke "N cash tim". Cash tidak jadi negatif; item tidak aktif di wave berikutnya. Tombol yang harganya di bawah saldo kelihatan biru dan bisa diklik | M3 | solo | BLOK |
| SHOP-10 | Wave dengan `boss_locker`, boss masih hidup | Lihat kanan layar saat Locker spawn, lalu `R.UpgradeWeapon:FireServer("weapon_starter")` dari command bar client (ganti id-nya dengan senjata yang kamu pakai), lalu kalahkan boss-nya | Saat Locker spawn, panel Toko Match **muncul walau masih `WaveActive`**, dengan baris status merah **"Dikunci — kalahkan boss-nya dulu"** dan tombol upgrade-nya abu-abu. Output server mencetak `[Locker] toko dikunci, memanggil 3 basic tiap 8 detik`. `UpgradeWeapon` ditolak dengan **"Toko dikunci. Kalahkan boss-nya dulu."** — bukan "Upgrade cuma bisa saat jeda antar wave." — dan alasan itu muncul di baris status panel. Urutan itu yang diuji: `MatchUpgradeRules.canUpgrade` memeriksa `locked` **sebelum** state, jadi pemain tahu bedanya "dikunci boss" dan "belum waktunya". Setelah boss mati: Output mencetak `[Locker] boss mati, upgrade tim dipulihkan`, dan panel hilang sampai `Intermission` datang. **`BuyShopItem` tidak bisa dipakai menguji ini lagi** — dia berhenti di gerbang item yang dimatikan sebelum `locked` sempat diperiksa | M4 | solo | - |
| SHOP-11 | Sementara pindahkan `bossId = "boss_locker"` ke wave 1 di `Waves.luau` **dan** ubah `wave = 1` di `Bosses.luau` — `Waves.validate()` memeriksa keduanya cocok dan akan mencetak warn saat boot kalau cuma satu yang diubah | Kalahkan `boss_locker` di wave 1, masuk `Intermission`, tekan tombol Upgrade di panel toko | Panel terbuka normal (baris status menampilkan cash, bukan "Dikunci") dan upgrade **diterima**: level naik satu, cash turun 150, Output mencetak `[ShopService] <nama> upgrade weapon_starter ke level 2 (150 cash), sisa N`. Kunci dilepas saat boss mati. **Balikkan kedua file sebelum commit** | M4 | solo+EDIT | - |
| SHOP-12 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: Satu match selesai setelah membeli **Exploit Patch 3x**, Overclock 1x, dan **Scanner Turret 2x**. Catat harga yang tertulis di tombolnya di jeda terakhir: Exploit Patch **390**, Overclock **250**, Scanner Turret **390** | Tekan Ready lagi, mulai match kedua, dan lihat panel toko di jeda pertama match itu | Saldo cash **0** saat hitung mundur match kedua (di-reset saat `Countdown`, bukan saat wave mulai, supaya pemain melihatnya sebelum wave pertama). Tiap tombol kembali ke **harga dasar**: Exploit Patch 200, Overclock 200, Hotfix 150, Firewall Block 100 · sisa 5, Scanner Turret 250 — bukan 390 / 250 / 390 dari match pertama. Harga di tombol dihitung dari pembukuan `purchases`, jadi harga dasar yang kembali adalah bukti paling langsung bahwa pembukuannya di-reset. **Tidak ada turret sisa** di sekitar Core. Buff damage dan attack speed tidak terbawa — kalau musuh wave 1 match kedua mati lebih cepat dari biasanya, pembukuan pembelian tidak di-reset | M3 | solo | BLOK |
| SHOP-13 | Match sedang `WaveActive`, lalu masuk dengan pemain **baru** yang bukan peserta. Listener `ActionResult` terpasang di client pemain itu | Dari client pemain baru: `R.BuyShopItem:FireServer("shop_barrier")`, lalu `R.UpgradeWeapon:FireServer("weapon_starter")` | **Dua-duanya** ditolak dengan "Kamu bukan peserta match ini." — pemain yang ditahan di lobby tidak boleh membelanjakan cash maupun menaikkan senjatanya di match yang sedang berjalan. Pemeriksaan peserta ada **sebelum** gerbang item yang dimatikan, jadi inilah satu-satunya penolakan `BuyShopItem` yang pesannya tidak berubah sama sekali | M3 | LIVE | - |
| SHOP-14 | State `Lobby` dan `WaveActive`, **tanpa** `boss_locker` di wave itu | Lihat kanan layar di dua state itu | Panel Toko Match **tidak terlihat** sama sekali di luar `Intermission`. Satu-satunya pengecualian adalah toko yang dikunci Locker, yang sengaja ikut menampilkan panelnya — lihat SHOP-10. Aturan yang dipakai client satu: `MatchUpgradeRules.OPEN_STATE`, yang nilainya **sama** dengan `ShopRules.OPEN_STATE` dan dijaga unit test supaya tetap sama — dua nilai yang berbeda berarti panel terbuka dengan seluruh tombolnya ditolak server | M3 | solo | - |
| SHOP-15 | Masuk wave Locker, **jangan bunuh boss-nya** — biarkan Core hancur. Setelah kembali ke lobby, tekan Ready lagi dan selesaikan wave 1 | Lihat panel toko di jeda setelah wave 1 match kedua, dan lihat baris state di HUD sepanjang match kedua | Panel **buka normal**: baris statusnya menampilkan cash, bukan "Dikunci", dan tombol upgrade bisa diklik. Baris state HUD **tidak** memuat "upgrade tim disandera" kapan pun di match kedua. Ini jalur yang paling mudah bocor, dan ada dua hal yang bisa bocor: kunci toko dan sandera upgrade. Yang **masih bisa dibuktikan** di sini cuma yang pertama — selama item toko dimatikan, sanderanya tidak menyandera apa pun (T19), jadi "damage yang diam-diam kembali ke dasar" tidak punya gejala yang bisa diukur. Ulangi juga dengan cara keluar lain: saat wave Locker berjalan, tutup semua client (match dibatalkan). Hasilnya harus sama | M4 | solo+EDIT | - |
| SHOP-16 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: Match solo `normal` sampai wave 10 (`boss_locker`). Di `Intermission` setelah wave 8, beli **Exploit Patch tepat 5 kali** — 200 + 250 + 312 + 390 + 488 = **1.640** cash, dan tombolnya harus berakhir menampilkan **610** (harga ke-6). Dulu 5 adalah jatah maksimumnya; sekarang 5 cuma angka yang dipilih supaya pengalinya bulat **1,5x** dan hasilnya bisa dihitung di muka | Hitung serangan untuk membunuh satu `basic` tiga kali, dengan `weapon_starter` level 1: (a) saat **wave 9**, (b) saat **wave 10 dengan Locker hidup**, pada minion `basic` yang dia panggil, (c) setelah **Locker mati**, pada minion `basic` yang masih hidup. Saat (b), lihat juga harga di baris Exploit Patch di panel toko yang ikut muncul terkunci | Inilah mekanik Locker yang sebenarnya menggigit — analogi ransomware: dia menyandera yang sudah kamu miliki, bukan melarangmu berbelanja. Damage jadi 1,5x linear, jadi 25 per serangan jadi 37,5. (a) `basic` wave 9 punya 220 HP → **6** serangan, bukan 9. (b) minion `basic` wave 10 punya 235 HP → **10** serangan, persis angka "belum pernah upgrade sama sekali" di [bagian 4.2](#42-angka-patokan), dan baris state HUD memuat **"upgrade tim disandera"**. (c) `basic` yang sama → **7** serangan, dan teks itu hilang. Pembelian tidak hilang: selama Locker hidup, baris Exploit Patch di panel toko yang terkunci tetap menampilkan **610 cash** — harga pembelian ke-6, yang cuma bisa dihitung dari 5 pembelian yang masih tercatat. Kalau di situ tertulis **200**, yang disandera bukan cuma efeknya tapi pembukuannya juga, dan itu GAGAL | M4 | solo | BLOK |
| SHOP-17 | Match solo `normal`, wave 1, belum upgrade apa pun. Panel toko belum terlihat (masih `WaveActive`) | Habiskan seluruh **8** `basic` wave 1 sendirian, catat angka cash di header panel toko begitu panel itu muncul, dan baca Output server. Lalu habiskan wave 2 dan catat ulang. Terakhir, catat **koin** di header panel lobby (`Level N · M koin`) **sebelum** match dimulai dan lagi setelah match ini berakhir dengan cara apa pun | **Baris ini membandingkan dua mata uang sekaligus, dan itu seluruh gunanya.** Selama wave 1 berjalan cash naik 5 tiap `basic` yang **kamu** bunuh, jadi 8 musuh = **40** cash. Di detik wave dinyatakan bersih, Output mencetak satu baris: `[ShopService] hadiah wave 1: 200 cash untuk tiap peserta` — **200, bukan 800**: pengali jumlah pemain sudah dihapus bersama `Balance.waveReward`. Header panel toko yang muncul sesudahnya menampilkan **240 cash**. Wave 2: hadiahnya **250**, dan saldo naik tepat 250 di detik wave selesai, **di luar** cash dari musuh wave 2 yang sudah masuk satu-satu sebelumnya. Sekarang sisi satunya: **cash** habis saat match selesai dan cuma bisa dibelanjakan di Toko Match, sementara **koin** di panel lobby permanen. Hadiah per wave masuk ke yang **pertama**, jadi angka koin di panel lobby **tidak boleh bergerak sama sekali** selama match berjalan: selisihnya sebelum dan sesudah match tetap mengikuti rumus akhir match (`10*wave + 50` kalau menang, `x rewardMult`) — ratusan, dan datang sekali di akhir, bukan per wave | M3 | solo | - |
| SHOP-18 | Match solo `normal` sampai **wave 5** (`boss_splitter`). Catat hadiah wave 4 dan wave 6 juga | Baca tiga baris `[ShopService] hadiah wave N: ...` untuk wave 4, 5, dan 6 | Wave 4 = **350**, wave 5 = **800**, wave 6 = **450**, semuanya per peserta. Wave 5 bukan 400: dia **dikali dua** karena punya boss, jadi `(200 + 50*4) * 2`. Yang dinilai bukan angka 800-nya saja tapi bentuk kurvanya — hadiah wave boss harus **dua kali** hadiah wave itu kalau boss-nya tidak ada, dan karena itu wave 5 lebih besar daripada wave 6 **dan** wave 7 (500) sekaligus. Wave boss dikenali dari `bossId` di `Waves.luau`, bukan dari nomor wave yang ditulis tangan. Tanpa memainkan lima wave: pindahkan `bossId = "boss_splitter"` ke wave 1 dengan prosedur di [bagian 12](#12-boss-boss), lalu hadiah wave 1 harus **400**, bukan 200. **Balikkan kedua file sebelum commit** | M3 | solo (atau solo+EDIT) | - |
| SHOP-19 | Match solo `normal` dimainkan sampai **menang** di wave 10. Baris ini ikut terbukti sendiri setiap kali satu match penuh dimainkan (WAVE-02, MP-03), jadi tidak perlu sesi sendiri | Habiskan Locker dan seluruh minionnya, lalu baca **dua baris terakhir** Output server berurutan | `[ShopService] hadiah wave 10: 1300 cash untuk tiap peserta` muncul **lebih dulu**, baru `[MatchService] match selesai: menang di wave 10 (normal), 1 peserta`. Hadiahnya `(200 + 50*9) * 2` = 1.300: wave terakhir juga wave boss, jadi dia hadiah **terbesar di seluruh match**. Yang GAGAL adalah baris `[ShopService]` yang **tidak muncul sama sekali** untuk wave 10 — wave terakhir yang menyatakan match menang lalu berhenti akan melewatkan hadiahnya tanpa satu error pun, dan yang hilang justru yang paling besar. Saldonya tidak bisa diperiksa di layar: panel toko sudah hilang di state `Ended`, jadi Output server satu-satunya buktinya | M3 | solo | - |
| SHOP-20 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission` di jeda setelah wave 2, solo — kolam sudah di atas **1.200** cash (840 dari wave 1 ditambah 1.000 hadiah wave 2 dan cash dari musuhnya). Exploit Patch belum pernah dibeli di match ini | Beli **Exploit Patch empat kali berturut-turut**. Sebelum tiap klik, catat angka harga di barisnya; sesudah tiap klik, catat saldo "N cash tim" di header | Angka di baris Exploit Patch berjalan **200 → 250 → 312 → 390 → 488**, dan saldo turun persis sebesar angka yang tertulis **sebelum** klik — bukan 200 empat kali, dan bukan harga berikutnya. Total yang hilang dari kolam = **1.152**. Harga naik `x1.25` per pembelian, dibulatkan ke bawah tiap kali ([bagian 4.2](#42-angka-patokan)). Baris Overclock, Hotfix, Firewall Block, dan Scanner Turret **tidak berubah sama sekali** selama ini — harga satu item cuma dinaikkan pembelian item yang sama. Angka di tombol yang tidak cocok dengan potongan cash adalah GAGAL: keduanya dihitung dari fungsi yang sama, jadi selisihnya berarti satu sisi memakai harga dasar | M3 | solo | BLOK |
| SHOP-21 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission` di jeda setelah wave 5, solo — kolam di atas **4.100** cash | Beli melewati batas yang dulu berlaku untuk tiga item: **Exploit Patch 6 kali** (dulu maks 5), **Hotfix 4 kali** (dulu maks 3), **Scanner Turret 3 kali** (dulu maks 2) | Semuanya **diterima**. Tidak ada satu pun penolakan "Jatah ... sudah habis", dan tidak ada tombol yang mati karena jumlah. Harga pembelian terakhir tiap item: Exploit Patch ke-6 = **610**, Hotfix ke-4 = **292**, Scanner Turret ke-3 = **390**; totalnya 2.250 + 863 + 952 = **4.065** cash. Tiga baris itu juga **tidak** memuat "· sisa N" sama sekali — teks itu cuma ada di Firewall Block. Efeknya ikut: damage tim jadi **1,6x** (6 x +10% linear), Core dipulihkan 150 HP per Hotfix sampai mentok 1000, dan turret ketiga muncul di sudut ketiga mengelilingi Core tanpa menumpuk di atas dua yang sudah ada | M3 | solo | BLOK |
| SHOP-22 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: State `Intermission`, kolam di atas **850** cash, Firewall Block belum pernah dibeli di match ini. Listener `ActionResult` terpasang di command bar client | Beli **Firewall Block lima kali**, catat harga dan sisa di barisnya tiap kali. Lalu coba klik tombolnya, lalu `R.BuyShopItem:FireServer("shop_barrier")` | Lima pembelian pertama diterima dengan harga **100 → 125 → 156 → 195 → 244** (total **820**), dan teks sisanya turun **5 → 4 → 3 → 2 → 1 → 0**. Sesudah yang kelima tombolnya **abu-abu** dan barisnya memuat "· sisa 0"; mengkliknya tidak mengirim apa pun. Lewat remote, pembelian ke-6 **ditolak** dengan **"Jatah Firewall Block sudah habis (5)."** — bukan "Cash tim kurang", walaupun cash-nya memang masih di atas harga ke-6 (305) — dan alasan itu muncul merah di baris status panel toko selama 4 detik. Kolam **tidak** terpotong. Ini satu-satunya item yang batasnya dipertahankan, dan alasannya di [bagian 4.2](#42-angka-patokan): yang dibeli bukan kekuatan melawan wave tapi waktu musuh tertahan, jadi 20 tumpuk = 120 detik dan wave-nya lewat tanpa pemain menyentuh apa pun | M3 | solo | BLOK |
| SHOP-23 | Sesi **2 client**, keduanya Ready, `normal`, wave 1. Atur supaya **satu pemain membunuh semua musuh** dan yang satu lagi tidak menyerang sama sekali | Habiskan wave 1, baca baris `[ShopService] hadiah wave 1: ...` di Output jendela server, lalu bandingkan angka cash di **kedua** client | Hadiahnya **200 cash untuk tiap peserta** — bukan 400, dan bukan 200 yang dibagi dua: tiap pemain menerima angka penuh, dan barisnya cuma dicetak sekali. Wave 1 dengan 2 player tetap 8 musuh (pembulatan ke bawah dari 8,5 — [bagian 4.2](#42-angka-patokan)), jadi cash dari musuhnya 40 dan semuanya masuk ke **yang membunuh**. Saldo akhirnya: pembunuh **240**, yang diam **200** — dan **itulah yang diuji**: angka di kedua client **harus berbeda**. Angka yang sama persis di dua layar berarti `MatchCoins` kembali `FireAllClients`, dan gejalanya tiap client menampilkan saldo pemain yang terakhir berubah | M3 | 2P | - |
| SHOP-24 | Sesi **4 client**, keempatnya Ready, `normal`, wave 1 | Habiskan wave 1 dan baca baris `[ShopService] hadiah wave 1: ...`. Lalu ulangi dengan **3 client** | 4 player: hadiahnya **200 cash untuk tiap peserta** — sama dengan solo dan sama dengan duo, karena pengali jumlah pemain sudah tidak ada. 3 player: **juga 200**. Satu baris log untuk seluruh tim, empat (atau tiga) pembayaran. Wave 1 dengan 4 player ada 9 musuh dan dengan 3 player juga 9, jadi 45 cash dari musuh dibagi menurut siapa yang membunuh — bukan dibagi rata. Yang GAGAL: hadiah yang **mengecil** seiring jumlah pemain naik (pengalinya diimplementasikan sebagai pembagian), hadiah yang dibayarkan **sekali** lalu dibagi di antara peserta, dan saldo yang sama persis di keempat client | M3 | 4P | - |
| SHOP-25 | Match solo `normal`, Patch Wrench dipakai, wave 1 baru selesai sehingga state `Intermission` dan cash **240** (40 dari 8 `basic` + 200 hadiah wave) | Lihat panel di kanan layar | Satu baris, bukan daftar — fase `Loadout` sudah mengunci senjata yang dipakai, jadi tidak pernah ada lebih dari satu senjata yang bisa di-upgrade di sini. Isinya persis empat bagian: judul **"Patch Wrench · level 1/10"**, baris status **"240 cash"**, baris detail **"damage 25 · jeda 0.50s · jangkauan 12"** dengan baris kedua **"sesudah upgrade: damage 28 · jeda 0.50s · jangkauan 12"**, dan satu tombol **"Upgrade — 150 cash"** yang biru dan bisa diklik. **Tidak ada satu pun item** (Exploit Patch, Overclock, Hotfix, Firewall Block, Scanner Turret) — kalau salah satunya masih terlihat, panelnya belum ditulis ulang. Angka level dan alur datang dari remote `MatchUpgradeState`, bukan dihitung client: di awal match dia selalu `level = 1, path = "none"` | M3 | solo | - |
| SHOP-26 | Lanjutan SHOP-25: `Intermission` dengan 240 cash, belum upgrade apa pun di match ini | Catat angka di tombol, klik **Upgrade** sekali, lalu catat judul, baris status, baris detail, dan angka di tombol lagi. Baca juga Output server | Cash turun **persis 150** — angka yang tertulis di tombol **sebelum** klik, bukan harga level berikutnya — jadi baris status jadi **"90 cash"**. Judul jadi **"Patch Wrench · level 2/10"**, baris detail jadi "damage 28 ..." dengan "sesudah upgrade: damage 31 ...", dan tombol jadi **"Upgrade — 202 cash"** lalu **mati** (abu-abu), karena 90 < 202. Output server mencetak satu baris: `[ShopService] <nama> upgrade weapon_starter ke level 2 (150 cash), sisa 90`. Kurva harganya `150 x 1.35^(level-1)` dibulatkan ke bawah tiap langkah: **150, 202, 273, 369, 498, 672, 908, 1225, 1654** ([bagian 4.2](#42-angka-patokan)). Angka di tombol yang tidak cocok dengan cash yang hilang adalah GAGAL: keduanya dari `MatchUpgradeRules.priceFor` dengan save yang **sama**, jadi selisihnya berarti satu sisi membaca save sesudah naik | M3 | solo | - |
| SHOP-27 | Lanjutan SHOP-26: cash **90**, harga berikutnya **202**. Listener `ActionResult` terpasang di command bar client | Coba klik tombol yang abu-abu, lalu `R.UpgradeWeapon:FireServer("weapon_starter")` | Kliknya **tidak mengirim apa pun**. Lewat remote: ditolak dengan **"Cash kurang: butuh 202, ada 90."** dan alasan itu muncul merah di baris status panel selama 4 detik, lalu kembali ke "90 cash". Level tidak berubah; cash tidak jadi negatif. Cash diperiksa **paling akhir** di `canUpgrade`, dan itu yang diuji di sini: dia satu-satunya alasan yang bisa dibereskan pemain dengan bermain, jadi dia tidak boleh menutupi alasan yang lain. Ulangi di senjata yang sudah level 10 untuk membuktikan urutannya: yang pulang **"... sudah level maksimum."**, bukan soal cash, walaupun cash-nya juga kurang | M3 | solo | - |
| SHOP-28 | Senjata di **level 3** di dalam match. Tanpa edit: tiga upgrade (150 + 202 + 273 = **625** cash) yang paling awal terjangkau di jeda setelah wave 3. Dengan `Balance.MATCH_UPGRADE_BASE_PRICE = 1` kesembilan upgrade jadi **1, 1, 1, 2, 3, 4, 6, 8, 11** (total 37) dan semuanya muat di jeda pertama — **balikkan sebelum commit** | Lihat panel di jeda berikutnya, lalu tekan tombol konfirmasi pada alur **kedua** (`b`, Ayunan Cepat) — bukan yang pertama, supaya "jatuh ke alur pertama" tidak bisa lolos sebagai lulus | Tombol tunggal **diganti tiga kartu alur berjajar**, bukan satu per satu dan bukan dropdown: tiap kartu memuat nama alur, temanya, ketiga baris `summary` beserta levelnya (4, 7, 10), dan tombolnya sendiri **"Pilih <nama alur>"**. Baris detail berbunyi "Level 4 mengunci satu alur sampai match ini selesai. Baca ketiganya dulu — 369 cash." Sesudah konfirmasi: level jadi **4**, cash turun **369**, panel kembali ke bentuk satu tombol, dan Output mencetak `[ShopService] <nama> upgrade weapon_starter ke level 4 alur b (369 cash), sisa N` — **bagian "alur b" cuma muncul di baris yang mengunci alurnya**, tidak di upgrade lain. Yang GAGAL: panel yang menagih pilihan di level **selain** 4; kartu yang muncul satu per satu; dan upgrade ke level 4 yang **diterima tanpa** memilih alur (lewat remote tanpa argumen kedua hasilnya harus "Level 4 Patch Wrench mengunci satu dari 3 alur sampai match selesai. Pilih dulu.") | M3 | solo (atau solo+EDIT) | - |
| SHOP-29 | Lanjutan SHOP-28, **di match yang sama**: senjata di level 4 dengan alur `b` terpilih, cash cukup untuk upgrade berikutnya | `R.UpgradeWeapon:FireServer("weapon_starter", "a")`, lalu `FireServer("weapon_starter", "c")`, lalu `FireServer("weapon_starter", "b")`, lalu `FireServer("weapon_starter")` tanpa argumen kedua | Dua yang pertama **ditolak**, dan pesannya menyebut alur yang sudah dipunyai **dengan namanya**: **"Patch Wrench sudah di alur Ayunan Cepat sampai match ini selesai."** — nama, bukan id `"b"`. Level dan cash tidak berubah. Dua yang terakhir **diterima**: mengirim alur yang **sama** bukan percobaan ganti alur, dan client lama yang cuma mengirim `weaponId` tetap bisa upgrade di level yang tidak menagih pilihan. Perhatikan kalimatnya: dia menyebut **"sampai match ini selesai"**, bukan "permanen" — dan itu yang dibuktikan SHOP-30 | M3 | solo | - |
| SHOP-30 | Satu match diselesaikan (menang atau kalah) sesudah senjata dinaikkan minimal ke level 4 dengan satu alur terpilih. Catat level, alur, dan cash terakhir di panel toko | Kembali ke lobby, lihat baris senjata di panel lobby, lalu tekan Ready dan mainkan match kedua tanpa restart server. Lihat panel toko di jeda pertama match kedua, dan hitung serangan untuk membunuh satu `basic` wave 1 | Di lobby, baris senjata berbunyi `damage 25 · jarak dekat · 3 alur` — **tanpa "Level N/10"**: tidak ada level permanen yang bisa ditampilkan. Di match kedua, panel toko kembali ke **"Patch Wrench · level 1/10"**, saldo **0 cash** sudah sejak hitung mundur (di-reset saat `Countdown`, bukan saat wave mulai), tombolnya kembali **"Upgrade — 150 cash"**, dan `basic` wave 1 butuh **4** serangan seperti senjata yang belum pernah disentuh. Level dan alur dibuang `ShopService.reset()` saat kembali ke `Lobby`. Yang GAGAL: level yang **terbawa** ke match kedua — gejalanya musuh wave 1 mati jauh lebih cepat dari biasanya; dan `R.GetProfile:InvokeServer().weapons["weapon_starter"]` yang **ikut naik** sesudah upgrade dalam match, karena yang naik seharusnya `matchWeapons` di ShopService dan bukan data permanen | M3 | solo | - |
| SHOP-31 | Match berjalan. Listener `ActionResult` terpasang di command bar client | `R.UpgradeWeapon:FireServer("weapon_starter")` saat **`WaveActive`**, lalu saat **`Countdown`**, lalu di **`Lobby`**. Lalu, saat `Intermission`, `FireServer("weapon_boss_a")` — senjata yang **tidak** sedang dipakai. Lalu `FireServer("weapon_starter", "alur_karangan")` saat senjatanya **level 3** | Empat pesan yang berbeda, dan bedanya yang diuji: `WaveActive` dan `Countdown` dibalas **"Upgrade cuma bisa saat jeda antar wave."**; `Lobby` dibalas **"Kamu bukan peserta match ini."** (participants kosong di lobby, dan pemeriksaan peserta ada paling depan) — **bukan** "Upgrade cuma bisa di lobby.", yang sudah tidak bisa dipicu dari mana pun sejak remote ini pindah ke ShopService; senjata yang bukan dipakai dibalas **"Senjata itu bukan yang sedang kamu pakai."**; dan alur karangan di titik percabangan dibalas **"Patch Wrench tidak punya alur itu."** Level dan cash tidak bergerak sama sekali, dan Output server bersih | M3 | solo | - |
| SHOP-32 | Match 2 client, `Intermission`, keduanya peserta dan keduanya punya cash cukup | Pemain A upgrade senjatanya dua kali; pemain B tidak menyentuh apa pun, cuma melihat panelnya | Panel **B tidak berubah sama sekali**: judulnya tetap "level 1/10", tombolnya tetap "Upgrade — 150 cash", dan saldonya tidak turun sepeser pun. Ini kebalikan dari MP-14, yang menguji pembukuan item yang memang dibagi tim — upgrade senjata milik **satu orang**, jadi `matchWeapons` dan cash keduanya per UserId dan `MatchUpgradeState` dikirim `FireClient`. Yang GAGAL: level B yang ikut naik, saldo B yang ikut turun, atau panel B yang menampilkan nama senjata A — ketiganya berarti satu state per server dipakai untuk sesuatu yang per pemain | M3 | 2P | - |

## 12. Boss (BOSS)

Acuan: CONCEPT.md tabel boss, DEVELOPMENT_PLAN.md M4.

> **Cara mengetes tanpa memainkan empat wave dulu:** sementara pindahkan
> `bossId` ke wave 1 di `Waves.luau` **dan** ubah `wave` boss itu di
> `Bosses.luau` ke 1. `Waves.validate()` memeriksa keduanya cocok, jadi kalau
> lupa mengubah salah satunya server akan mencetak warn saat boot. **Balikkan
> keduanya sebelum commit.** Baris yang butuh ini berkode `EDIT`.

> **Mekanik andalan Locker jadi hampa, dan itu harus dibaca sebelum menilai
> BOSS-07, BOSS-08, dan SHOP-16.** Mekanismenya dulu: selama Locker hidup,
> upgrade **tim** yang sudah dibeli dari kelima item toko disandera — damage
> dan attack speed kembali ke nilai dasar sampai boss mati, dan itu analogi
> ransomware yang menggigit tepat di `WaveActive` tempat dia hidup.
> Sekarang kelima item itu dimatikan, jadi pembukuan `purchases` selalu kosong
> dan pengali yang disandera memang sudah pengali dasar: **tidak ada yang bisa
> disandera.** Upgrade senjata dalam match sengaja **tidak** ikut disandera —
> dia milik satu pemain, bukan tim. Akibatnya: kunci tokonya masih benar-benar
> menolak sesuatu (SHOP-10 dan SHOP-32 menguji itu lewat `UpgradeWeapon`), dan
> kedua baris log Locker masih muncul, tapi **tidak ada satu angka pun yang
> berubah saat dia hidup atau saat dia mati**. SHOP-16 — satu-satunya baris
> yang mengukur sanderanya — berstatus `BLOK`, dan bagian BOSS-07/BOSS-08 yang
> menyebut sandera cuma bisa menilai log-nya. Lihat T19 di
> [bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug).

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| BOSS-01 | Match berjalan sampai wave 5 | Amati awal wave 5 | Kubus merah besar (9x9x9) muncul **lebih dulu** dari musuh biasa, di lane 1 — boss diantre sebelum musuh biasa dengan sengaja, karena mekanik membelah cuma bermakna kalau boss ada sejak awal wave. Panel bar HP boss muncul di bawah HUD utama bertulisan **"Splitter — Worm"** dan persentase HP. Persentase turun saat boss diserang, dan **tidak lebih sering dari 5 kali per detik** (disiarkan paling cepat tiap 0.2 detik dan cuma kalau angkanya berubah — kalau bar-nya berkedip tiap frame, dua pembatas itu tidak bekerja) | M4 | solo | - |
| BOSS-02 | `boss_splitter` hidup, HP masih di atas 66% | Serang boss sampai HP-nya turun melewati 66% | **4 musuh `fast`** muncul **di posisi boss saat itu**, menyebar melingkar sekitar 6 stud, dan langsung melanjutkan ke Core dari waypoint yang sama dengan boss — bukan dari awal lane. Boss tetap hidup | M4 | solo | - |
| BOSS-03 | `boss_splitter` HP di antara 66% dan 33% | Terus serang sampai HP melewati 33% | 4 `fast` lagi. Pembelahan di 66% **tidak terulang** — total hanya dua kali sepanjang hidup boss, berapa kali pun dia dipukul | M4 | solo | - |
| BOSS-04 | Sesi 2 client, keduanya Ready, kalahkan boss | Baca Output server dan `materials` dari kedua client lewat `R.GetProfile:InvokeServer().materials` | `[BossService] drop material_a x1 ke 2 peserta`, dan **kedua** pemain dapat material — bukan cuma yang menyerang paling banyak atau yang memberi pukulan terakhir | M4 | 2P | - |
| BOSS-05 | `boss_splitter` baru mati | Amati layar client | Bar HP boss hilang. **Kartu info malware** muncul di tengah layar: badge "KARTU INFO MALWARE", judul **"Worm"**, satu paragraf penjelasan, dan **tiga** butir cara mencegah — teksnya dari `Bosses.luau`. Bisa ditutup dengan tombol **Tutup**, dan hilang sendiri setelah 18 detik kalau dibiarkan. Gameplay lanjut normal selama kartu terbuka | M4 | solo | - |
| BOSS-06 | Match berjalan sampai wave 10 | Amati awal wave 10 | Kubus merah sangat besar (11x11x11) muncul, bar HP boss bertulisan **"Locker — Ransomware"** | M4 | solo | - |
| BOSS-07 | `boss_locker` hidup | Tunggu beberapa saat tanpa membunuh boss | Tiap **8 detik**, 3 musuh `basic` muncul **dari awal lane** — beda dari Splitter dengan sengaja: Locker memanggil bantuan dari luar, bukan memecah dirinya. Soal kunci tokonya lihat SHOP-10, yang sekarang dibuktikan lewat `UpgradeWeapon` dan bukan `BuyShopItem`. Soal sandera upgrade-nya: baris log-nya masih muncul, tapi **tidak ada angka yang berubah** selama item toko dimatikan — lihat kotak di atas dan SHOP-16 | M4 | solo | - |
| BOSS-08 | `boss_locker` baru mati | Amati arena beberapa detik | Minion berhenti dipanggil; minion yang masih hidup tidak menambah minion baru. Output server mencetak `[Locker] boss mati, upgrade tim dipulihkan` — baris itu tetap dicetak walaupun yang dipulihkan tidak ada (kotak di atas), jadi yang dinilai di sini baris log dan berhentinya panggilan minion, bukan damage yang kembali | M4 | solo | - |
| BOSS-09 | `boss_locker` HP tinggal sedikit, wave 10 | Habiskan boss, lalu habiskan minion yang masih berjalan | `material_b` masuk ke data pemain (cek lewat `R.GetProfile:InvokeServer().materials` dari command bar client); kartu info "Ransomware" muncul; match berakhir **menang**. Wave 10 belum bersih sampai minion juga habis. Baris "Material: ..." di layar hasil ikut menyebut `material_b`, dan harus cocok dengan apa yang dilaporkan `GetProfile` | M4 | solo | - |
| BOSS-10 | Satu match dengan kedua boss dikalahkan sudah selesai, state `Lobby` | Buka panel lobby dan lihat baris Fork Bomb, lalu baca `R.GetProfile:InvokeServer().materials` | `material_a` dan `material_b` masing-masing bertambah 1 per boss, dan jumlahnya tetap setelah kembali ke lobby. Baris Fork Bomb **tidak** lagi menampilkan "craft: material_a N/5" dan **tidak** menampilkan level: senjatanya sudah dimiliki sejak awal ([bagian 4.2](#42-angka-patokan)) dan level hidup di dalam match, jadi barisnya berbunyi "damage 30 · jarak jauh · 3 alur". Yang dinilai di sini cuma jumlah materialnya di `GetProfile`, bukan barisnya. **Sebelum place di-publish, material ini ada di memori saja dan hilang saat playtest di-stop** — itu bukan bug M4, lihat [kotak DataStore](#22-kotak-datastore--baca-sebelum-menyalahkan-kode) | M4 | solo | - |
| BOSS-11 | Playtest 4 player, wave dengan boss | Amati bar HP boss di keempat client sambil boss diserang | Persentase sama di semua client dan turun bersamaan — server satu-satunya sumber angkanya | M4 | 4P | - |
| BOSS-12 | `boss_splitter` sudah membelah dua kali dan masih ada musuh pecahan hidup | Habiskan boss-nya saja, lalu amati arena | Musuh pecahan **dibiarkan hidup**, dan wave **belum** dinyatakan bersih sampai mereka juga habis. Itu bagian dari mekaniknya: kalau pecahan dihapus saat boss mati, ambang 33% tidak ada konsekuensinya bagi pemain yang langsung membunuh boss sesudahnya | M4 | solo | - |
| BOSS-13 | Sesi 2 client, keduanya peserta. Tutup client ke-2 **sebelum** boss mati, lalu kalahkan boss | Join lagi dengan akun yang sama | Material-nya dibayarkan saat dia rejoin, dan Output mencetak `[BossService] material tertunda dibayarkan ke <nama>`. Dropnya tidak boleh hilang hanya karena dia sedang tidak di server pada detik boss mati | M4 | LIVE | - |
| BOSS-14 | `boss_splitter` HP penuh. Sementara naikkan `Weapons.weapon_starter.baseDamage` supaya satu serangan menurunkan HP boss dari ~70% ke ~20% | Serang boss sekali dengan damage besar itu | **8 musuh `fast`** muncul, bukan 4: dua ambang terlewati sekaligus dalam satu serangan. Ini kasus pinggir yang punya unit test, dan yang kalau salah membuat boss kehilangan satu fase tanpa ada yang error. Balikkan `Weapons.luau` setelah test | M4 | solo+EDIT | - |

## 13. Progres permanen dan data player (PROG)

Acuan: DEVELOPMENT_PLAN.md bagian 3.1, 3.5, M5.

> **Upgrade senjata tidak ada lagi di kelompok ini.** Dia pindah ke dalam
> match, dibayar cash, dan diuji di [bagian 11](#11-toko-match-shop) lewat
> SHOP-25 sampai SHOP-32. Yang tersisa di sini progres **permanen**: koin, XP,
> level akun, material, tingkat yang terbuka, dan statistik.
>
> **Dan satu jalan pintas lama yang sekarang menyesatkan.** Sampai sebelum ini,
> cara menyiapkan senjata di level dan alur tertentu adalah menulis
> `Config.DEFAULT_DATA.weapons.weapon_starter = { level = 7, path = "a" }`.
> Itu **tidak berpengaruh apa-apa lagi**: `CombatService` membaca level dan
> alur dari save **dalam match** milik ShopService
> (`CombatService.setMatchWeaponSource(ShopService.getMatchWeapon)` di
> `init.server.luau`), dan panel lobby tidak menampilkan level sama sekali.
> Senjata akan tetap berjalan di level 1 tanpa alur, tanpa satu pesan pun yang
> menunjukkan kenapa — jadi baris yang dijalankan dengan jalan pintas itu akan
> terbaca GAGAL padahal yang salah persiapannya.
>
> **Tiga jalan pintas yang benar**, dipakai seluruh baris COMBAT-18 sampai
> COMBAT-25, COMBAT-12, dan SHOP-28:
>
> 1. **Beli upgrade-nya di dalam match**, tiap jeda antar wave, dengan cash.
>    Tanpa edit apa pun. Harganya 150, 202, 273, 369, 498, 672, 908, 1.225,
>    1.654 ([bagian 4.2](#42-angka-patokan)), jadi level 4 terjangkau di jeda
>    setelah wave 3 dan level 7 sekitar jeda setelah wave 6. Ini satu-satunya
>    jalan yang juga menguji ekonominya sendiri.
> 2. **`Balance.MATCH_UPGRADE_BASE_PRICE = 1`** (`solo+EDIT`). Kesembilan
>    upgrade jadi 1, 1, 1, 2, 3, 4, 6, 8, 11 — total **37** cash, jadi seluruh
>    jalan dari level 1 ke 10 muat di jeda pertama. Ini yang paling rapi kalau
>    yang diuji tingkat alur di level 7 dan 10, karena dia tidak menyentuh satu
>    pun aturan, cuma harganya. Perhatikan bahwa dia **ikut mengubah angka di
>    SHOP-26, SHOP-27, dan SHOP-28**, jadi jangan dibiarkan menyala saat
>    menjalankan ketiganya.
> 3. **Kembalian `MatchUpgradeRules.freshSave()` diubah** jadi
>    `{ level = 7, path = "a" }` (`solo+EDIT`). Senjata lahir di level itu
>    setiap match, jadi tidak ada satu pun klik yang perlu dilakukan. Dua
>    peringatannya: dia berlaku untuk **semua pemain sekaligus** (jadi baris
>    2 client seperti COMBAT-22 tidak bisa memakainya untuk membedakan dua
>    pemain), dan `path` harus diisi alur yang **benar** untuk baris yang
>    dijalankan — `"none"` di level 7 berarti senjatanya berjalan tanpa alur,
>    yaitu kurva generik apa adanya, dan setiap angka efek di baris itu akan
>    nol tanpa satu pesan pun.
>
> Ketiganya hilang sendiri saat match selesai, jadi tidak ada yang bisa bocor
> ke DataStore lewat jalur ini. Yang tetap menyentuh file yang di-commit cuma
> nomor 2 dan 3 — **balikkan sebelum commit**.
>
> **Supaya tidak perlu memainkan 15 match untuk mengetes reward:** sementara
> ubah `Config.DEFAULT_DATA.coins` ke 50000 dan restart playtest. Balikkan
> sebelum commit, dan kalau place-nya sudah di-publish, naikkan
> `Config.DATASTORE_NAME` dulu atau pakai akun uji sendiri — `DEFAULT_DATA`
> yang terbawa ke DataStore berarti akun yang dipakai mencoba lahir dengan
> progres yang tidak dia bayar. Koin itu sendiri sekarang **tidak punya
> pembeli**: upgrade pindah ke cash, dan beli senjata tidak tercapai selama
> ketiganya dimiliki sejak awal, jadi yang diuji dengan koin cuma angkanya
> naik dengan benar.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| PROG-01 | Match dimenangkan di `normal` wave 10; catat koin dan XP sebelum match | Baca Output server, lalu layar hasil, lalu header panel lobby setelah kembali | Output: `[RewardService] <nama>: wave 10 menang, +150 koin, +300 xp, naik N level, membuka hard`. Header lobby naik **tepat 150 koin**, dan layar hasil menampilkan "Koin: +150" / "XP: +300" — **angka yang sama** dengan print server dan header. Tiga tempat itu harus cocok: kalau layar hasil bilang "+120 koin" tapi header naik 100, ada dua jalur yang menghitung berbeda. Kalau layar hasil menampilkan +0 sementara print server benar, temuan T1 kembali | M5 | solo | - |
| PROG-02 | Dua match di wave yang sama: satu kalah, satu menang | Bandingkan print `[RewardService]` kedua match | Match kalah lebih kecil: bonus menang adalah +50 koin dan +100 XP. Wave 4 kalah = 40 koin / 80 XP; wave 4 menang (kalau wave terakhir dipindah) = 90 koin / 180 XP | M5 | solo | - |
| PROG-03 | Match berakhir kalah di wave rendah (misal wave 2) | Baca print `[RewardService]` dan header lobby | Tetap dapat koin dan XP sesuai wave yang dicapai (wave 2 = 20 koin / 40 XP), bukan nol | M5 | solo | - |
| PROG-04 | XP player tinggal sedikit dari ambang level berikutnya (level 1 butuh 100 XP, level 2 butuh 125, dst) | Selesaikan satu match | Level naik; XP sisa dihitung benar (tidak hilang, tidak negatif); print `[RewardService]` memuat ", naik N level"; header lobby menampilkan level baru. Satu match penuh yang menang (300 XP) bisa menaikkan beberapa level sekaligus di awal | M5 | solo | - |
| PROG-05 | Catat `highestWave`, `matchesPlayed`, `wins` lewat `R.GetProfile:InvokeServer().stats` | Selesaikan satu match menang di wave tinggi, lalu satu match yang berakhir di wave lebih rendah | `matchesPlayed` +1 tiap match, `wins` +1 hanya saat menang, `highestWave` naik saat rekor baru dan **tidak turun** saat wave lebih rendah | M5 | solo | - |
| PROG-06 | Player belum pernah menang di `normal`; `clears` kosong; tombol **Hard (terkunci)** mati di panel lobby | Menangkan satu match di `normal` (wave 10 bersih), kembali ke lobby | Tombol **Hard** jadi aktif dan bisa dipilih. Print `[RewardService]` memuat ", membuka hard". Menangkan lagi di `normal`: print **TIDAK** lagi memuat "membuka hard" — kalau masih, daftar yang baru terbuka dibandingkan salah dan pemain akan melihat pesan itu setiap match selamanya | M5 | solo | - |
| PROG-07 | `hard` sudah terbuka | Pilih **Hard**, Ready, selesaikan satu match; bandingkan dengan match `normal` di wave yang sama | Musuh butuh lebih banyak serangan (hpMult 1.8 — lihat WAVE-09). Koin lebih besar: wave 10 menang di hard = **240 koin** vs 150 di normal (rewardMult 1.6). **XP sama, 300** — kesulitan menaikkan koin, bukan level | M5 | solo | - |
| PROG-08 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` level 1, koin permanen ≥ 2000 | Tekan tombol upgrade berulang kali sampai level 10, catat harga tiap kali. **Upgrade yang keempat (level 3 → 4) tidak akan langsung jadi** — di situ panel pemilihan alur muncul; pilih satu alur, lanjutkan, dan teruskan sampai level 10 | Level naik 1 tiap tekan; damage di baris detail naik (25 → 28 → 31 → ...); harga naik **50, 67, 91, 123, 166, 224, 302, 408, 551**; koin di header turun sesuai harga; baris petunjuk menampilkan "Berhasil." sebentar. Angka damage di baris detail itu **berhenti mengikuti kurva generik begitu alur terpilih**, dan itu yang berubah sejak langkah 7: dengan alur `c` Bertahan dia tetap 34 di level 4 lalu melompat ke **51.6** di level 7 (`damageMult` 1.2 di tingkat 2), dengan alur `a` Ayunan Berat dia sudah **51** di level 4, dan dengan alur `b` Ayunan Cepat dia 34 di level 4 tapi cooldown-nya yang berubah. Jadi baris ini harus mencatat **alur mana** yang dipilih, kalau tidak kolom damage-nya tidak bisa dinilai benar atau salah; tabel sembilan alur x tiga tingkat ada di [bagian 4.2](#42-angka-patokan). Yang **tidak** terganggu titik percabangan adalah **harga**: kesembilan angka di atas berlaku apa pun alur yang dipilih. Pilihan alurnya mencetak satu baris sendiri di Output server: `[ProgressionService] <nama> mengunci alur <nama alur> untuk weapon_starter -- permanen`, **terpisah** dari baris `upgrade ... ke level 4`. Di level 10 tombolnya jadi **"Level maks"** dan mati, dan `R.UpgradeWeapon:FireServer("weapon_starter")` ditolak dengan "Patch Wrench sudah level maksimum (10)." — bukan dengan pesan soal alur, karena level maksimum diperiksa lebih dulu | M5 | solo | BLOK |
| PROG-09 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: Koin permanen **kurang** dari harga upgrade, dan senjatanya di level yang **tidak** menagih pilihan alur — level 1 atau 2, bukan level 3 | Coba klik tombol upgrade, lalu ulangi lewat remote | Tombolnya mati dan kliknya tidak mengirim apa pun. Lewat remote: ditolak dengan "Koin kurang: butuh N, ada M." di baris petunjuk panel lobby. Level senjata tidak berubah; koin tidak jadi negatif. Prakondisi level itu bukan kehati-hatian berlebih: alur diperiksa **sebelum** koin, jadi senjata level 3 tanpa alur dengan koin kurang dibalas pesan soal **pilihan alur**, bukan soal koin (PROG-19) — dan baris ini akan terbaca GAGAL padahal yang terjadi benar | M5 | solo | BLOK |
| PROG-10 | **TIDAK BISA DIJALANKAN selama ketiga senjata terbuka sejak awal** ([bagian 4.2](#42-angka-patokan)): `weapon_ranged` sudah dimiliki setiap pemain baru, jadi tombol "Beli 1500" tidak pernah muncul dan `canBuy` berhenti di "sudah kamu miliki." sebelum harganya diperiksa. Statusnya `BLOK`, bukan GAGAL. Syarat menjalankannya lagi: `Config.DEFAULT_DATA.weapons` dikembalikan jadi `weapon_starter` saja. Prakondisi aslinya: `weapon_ranged` belum dimiliki, koin ≥ 1500 | Tekan **Beli 1500** di baris Packet Rifle, lalu **Pakai**, lalu Ready dan masuk wave | Koin turun 1500. Baris jadi "Level 1/10 · damage 14 · jarak jauh", tombolnya berubah jadi "Upgrade 50", tombol "Pakai" jadi aktif. Judulnya bertanda **(dipakai)** setelah di-equip. Di wave, serangan mengenai musuh sampai 60 stud. Yang **masih** bisa dibuktikan hari ini tanpa edit apa pun: baris Packet Rifle sudah berbunyi "Level 1/10 · damage 14 · jarak jauh" dengan tombol "Upgrade 50" sejak pemain pertama kali join, dan "Pakai" langsung hidup | M5 | solo+EDIT | BLOK |
| PROG-11 | `weapon_ranged` sudah dimiliki — sekarang berlaku untuk **setiap** pemain sejak join pertama ([bagian 4.2](#42-angka-patokan)), jadi tidak ada yang perlu disiapkan | `R.BuyWeapon:FireServer("weapon_ranged")` dari command bar client | Ditolak dengan "Packet Rifle sudah kamu miliki."; koin tidak berkurang lagi; level senjata tidak ter-reset. Ini satu-satunya baris beli/craft yang **naik** nilainya sejak senjatanya dibuka semua: dia menjaga gerbang yang sekarang dilewati setiap pemanggilan `BuyWeapon` | M5 | solo | - |
| PROG-12 | **TIDAK BISA DIJALANKAN selama ketiga senjata terbuka sejak awal** ([bagian 4.2](#42-angka-patokan)): Fork Bomb sudah dimiliki, jadi tombol "Craft" tidak pernah muncul dan `canCraft` berhenti di "sudah kamu miliki." sebelum resepnya diperiksa. Statusnya `BLOK`, bukan GAGAL, dan syarat menjalankannya lagi sama dengan PROG-10. Prakondisi aslinya: `material_a` ≥ 5, `weapon_boss_a` belum dimiliki. Satu boss men-drop 1, jadi butuh lima kali — atau sementara ubah `Weapons.weapon_boss_a.acquire.materials` ke `{ material_a = 1 }` | Tekan **Craft** di baris Fork Bomb, lalu **Pakai** | `material_a` berkurang 5; Fork Bomb jadi dimiliki di level 1 ("Level 1/10 · damage 30 · jarak jauh"); bisa di-equip dan serangannya mengenai sampai 3 musuh (COMBAT-09) | M5 | solo+EDIT | BLOK |
| PROG-13 | **TIDAK BISA DIJALANKAN, sebab yang sama dengan PROG-12** dan dengan syarat yang sama: pesan "Material kurang" ada di `canCraft` **sesudah** pemeriksaan "sudah kamu miliki", jadi dia tidak pernah tercapai selama Fork Bomb dimiliki sejak awal. `BLOK`, bukan GAGAL. Prakondisi aslinya: `material_a` **kurang** dari 5 | Coba klik Craft, lalu ulangi lewat remote | Tombolnya mati. Lewat remote: ditolak dengan "Material kurang: material_a N dari 5."; material tidak berkurang; senjata tidak masuk | M5 | solo+EDIT | BLOK |
| PROG-14 | Player punya progres campur: koin, level akun, XP, `equippedWeapon` yang bukan starter, `hard` terbuka, material sisa, dan statistik yang sudah bergerak. **Catat semua angkanya** lewat `R.GetProfile:InvokeServer()`. Perhatikan bahwa `weapons[...].level` tidak bisa lagi dibuat berbeda-beda dari dalam game — level senjata hidup di dalam match dan tidak pernah disimpan — jadi yang dibandingkan di sini sisanya | Stop playtest, F5 lagi (atau di server live: keluar, tunggu semenit, join lagi) | Semua angka sama persis seperti sebelum keluar. Tidak ada field yang kembali ke default dan tidak ada yang dobel. **Ini test paling penting di dokumen ini** dan satu-satunya yang membuktikan dua lapis progres di CONCEPT.md benar-benar bekerja — dan dia **dijamin gagal** sebelum place di-publish sekali, lihat [kotak DataStore](#22-kotak-datastore--baca-sebelum-menyalahkan-kode) | M5 | PUB | - |
| PROG-15 | Senjata tertentu ter-equip sebelum keluar | Keluar, join lagi, langsung mulai match | `equippedWeapon` masih senjata yang sama dan senjata itulah yang dipakai di match | M5 | PUB | - |
| PROG-16 | Player yang `stats.matchesPlayed`-nya 0 (atau naikkan `Config.DATASTORE_NAME` ke nama baru supaya datanya kosong) | Join dan mainkan satu match dari lobby | Data default terbentuk: **ketiga senjata di level 1 dengan `path = "none"`** dan ketiga barisnya berbunyi "damage N · jarak dekat/jauh · 3 alur" — **tidak ada** "Level N/10" (level hidup di dalam match sekarang), tidak ada baris "Belum dimiliki", tidak ada "Beli 1500", dan tidak ada "Craft" ([bagian 4.2](#42-angka-patokan)). 0 koin, hanya `normal` terbuka. Panel **PANDUAN** muncul (HUD-05). Match bisa diselesaikan tanpa perlu beli apa pun. Baris ini sekaligus pemeriksaan termurah bahwa `Config.DEFAULT_DATA.weapons` benar-benar sampai ke data pemain lewat `DataSchema.migrate` | M5 | solo | - |
| PROG-17 | Match sedang berjalan (state apa pun selain `Lobby`), dan **satu percobaan khusus saat `Loadout`** — tekan Ready dan jangan tunggu 20 detiknya habis | `R.BuyWeapon:FireServer("weapon_ranged")`, lalu `R.CraftWeapon:FireServer("weapon_boss_a")`. Lalu, terpisah, `R.UpgradeWeapon:FireServer("weapon_starter")` | Dua yang pertama ditolak: "Beli senjata cuma bisa di lobby." dan "Craft cuma bisa di lobby." Koin dan material tidak berubah sama sekali. `Loadout` percobaan yang paling penting di antaranya, karena di situ panelnya masih terlihat dan `SelectLoadout` justru **diterima**: dua remote ini memakai `ProgressionRules.ALLOWED_STATE` yang tetap **`Lobby` saja**, bukan daftar state loadout. Yang **ketiga sekarang berbeda** dan bukan lagi bagian dari kelompok ini: `UpgradeWeapon` dipegang ShopService, jadi di `Loadout`, `Countdown`, dan `WaveActive` dia dibalas "Upgrade cuma bisa saat jeda antar wave." dan di `Intermission` dia **diterima** — itu SHOP-31, bukan baris ini | M5 | solo | - |
| PROG-18 | **TIDAK BISA DIJALANKAN selama ketiga senjata terbuka sejak awal** ([bagian 4.2](#42-angka-patokan)), dan ini yang paling mudah salah dicatat GAGAL: kedua remote **tetap menolak**, tapi dengan pesan yang **berbeda** dari yang ditulis di kolom harapan. `canBuy` dan `canCraft` memeriksa "sudah kamu miliki" **sebelum** `acquire.method`, jadi yang pulang sekarang "Fork Bomb sudah kamu miliki." dan "Packet Rifle sudah kamu miliki." — gerbang metode tidak pernah tersentuh. Statusnya `BLOK`, dan syarat menjalankannya lagi sama dengan PROG-10. Prakondisi aslinya: state `Lobby`, koin dan material cukup | `R.BuyWeapon:FireServer("weapon_boss_a")`, lalu `R.CraftWeapon:FireServer("weapon_ranged")` | Ditolak: "Fork Bomb tidak dijual dengan koin." dan "Packet Rifle tidak dibuat dengan material." Senjata craft tidak bisa dibeli dengan koin, dan senjata beli tidak bisa di-craft | M5 | solo+EDIT | BLOK |
| PROG-19 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` **level 3** dengan `path` masih `"none"` (jalan pintas 1 di kotak di atas, atau tiga klik upgrade dari data baru). Koin cukup | Tekan tombol upgrade sekali. Lalu, tanpa menyentuh panelnya, jalankan `R.UpgradeWeapon:FireServer("weapon_starter")` dari command bar client | Upgrade **tidak jadi**: level tetap 3, koin tidak terpotong. Panel pemilihan alur muncul, dan dia menampilkan **ketiga alur sekaligus** — bukan satu per satu, bukan dropdown — masing-masing dengan nama, tema, dan ketiga baris `summary` beserta levelnya (4, 7, 10), persis seperti di [bagian 4.2](#42-angka-patokan). Panel juga menyatakan pilihannya permanen dan menyebut harga upgrade-nya (91). Lewat remote tanpa `pathId`, server membalas `ActionResult` `ok = false` dengan **"Level 4 Patch Wrench mengunci satu dari 3 alur upgrade selamanya. Pilih dulu."** Panel yang **tidak** muncul adalah GAGAL walaupun remote-nya menolak dengan benar: pilihan permanen yang ditagih tanpa tempat membaca isinya adalah jebakan, dan rancangan bagian 3 menyebutnya syarat yang bukan opsional | M5 | solo+EDIT | BLOK |
| PROG-20 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: Panel pemilihan alur dari PROG-19 sedang terbuka | Tekan tombol konfirmasi pada alur **kedua** (`b`, Ayunan Cepat) — bukan yang pertama, supaya "jatuh ke alur pertama" tidak bisa lolos sebagai lulus. Lalu baca Output server, lalu `R.GetProfile:InvokeServer().weapons["weapon_starter"]` | Upgrade diterima: level jadi 4, koin turun 91, panel **tertutup sendiri** karena `ActionResult` datang `ok = true`. Output server memuat **dua** baris, dan yang pertama ini yang membuktikan servernya menerima alur yang benar: `[ProgressionService] <nama> mengunci alur Ayunan Cepat untuk weapon_starter -- permanen`, lalu `[ProgressionService] <nama> upgrade weapon_starter ke level 4 (91 koin)`. `GetProfile` mengembalikan `{ level = 4, path = "b" }` — `path` **tidak** `"none"` dan **tidak** `nil`. Damage di baris detail jadi **34**, yaitu kurva generik apa adanya — dan itu benar **khusus untuk alur `b`**, karena tingkat 1 Ayunan Cepat menyetel `cooldown` 0.32 dan tidak menyentuh damage sama sekali. Yang berubah dan harus ikut terbaca di panel adalah **jeda antar serangan: 0.5 jadi 0.32 detik**. Kalau alur `a` yang dipilih, damage-nya jadi **51** dan cooldown **0.7**; 34 di situ berarti `damageMult` tidak sampai ke `weaponStats` (T14) | M5 | solo+EDIT | BLOK |
| PROG-21 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` level 4 atau 5 dengan `path = "b"` (hasil PROG-20, atau jalan pintas 2 di kotak di atas dengan `path = "b"`). Koin cukup | `R.UpgradeWeapon:FireServer("weapon_starter", "a")` dari command bar client, lalu `FireServer("weapon_starter", "c")` | **Dua-duanya ditolak**, level dan koin tidak berubah, dan `path` tetap `"b"`. Pesannya menyebut alur yang **sudah dipunyai** dengan namanya: **"Patch Wrench sudah di alur Ayunan Cepat, dan itu tidak bisa diganti."** Nama, bukan id `"b"`, dan bukan kalimat umum seperti "alur tidak bisa diganti" — pemain yang mengirim ini sedang menguji apakah "permanen" benar-benar permanen, dan jawabannya harus menyebut apa yang dia punya sekarang. Ini satu-satunya tempat di seluruh kode yang menegakkan "tidak bisa balik", jadi penerimaan di sini berarti seluruh pohon alur tidak punya arti | M5 | solo+EDIT | BLOK |
| PROG-22 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` **level 3** dengan `path` masih `"none"`, koin cukup | `R.UpgradeWeapon:FireServer("weapon_starter", "alur_karangan")`, lalu `FireServer("weapon_starter", "d")`, lalu `FireServer("weapon_starter", "Ayunan Cepat")`, lalu `FireServer("weapon_starter", "A")`, lalu `FireServer("weapon_starter", 4)` | Kelimanya **tidak** menaikkan level dan tidak memotong koin, dan `path` tetap `"none"` sesudah semuanya. Empat yang pertama dibalas **"Patch Wrench tidak punya alur itu."**: `"d"` ditolak walau bentuknya mirip id yang sah; `"Ayunan Cepat"` ditolak karena yang divalidasi adalah **id** alur, bukan namanya — nama itu yang dibaca pemain di panel, id-nya yang tersimpan; dan `"A"` ditolak karena pembandingannya `path.id == pathId` apa adanya, jadi huruf besar bukan id yang sama. Yang terakhir beda: `4` bukan string, jadi dia **dibuang jadi nil** di `onUpgrade` sebelum sampai ke validasi alur, dan yang dibalas adalah penolakan "Pilih dulu" dari PROG-19 — bukan "tidak punya alur itu". Satu hal yang perlu diketahui sebelum menilai baris ini: id alur ketiga senjata sama-sama `a`, `b`, `c` ([bagian 4.2](#42-angka-patokan)), jadi **tidak ada** id milik satu senjata yang bisa dikirim ke senjata lain untuk memicu penolakan ini — satu-satunya cara mencapainya adalah id yang tidak ada di `def.paths` sama sekali. Itu sebabnya daftar di atas memakai karangan dan variasi ejaan, bukan "alur milik Packet Rifle" | M5 | solo+EDIT | BLOK |
| PROG-23 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: **Data baru**, `weapon_starter` level 1 dengan `path = "none"` (jangan pakai jalan pintas 1 atau 2 — baris ini butuh level 1 yang asli). Koin cukup | `R.UpgradeWeapon:FireServer("weapon_starter", "a")` dari command bar client. Lalu baca `R.GetProfile:InvokeServer().weapons["weapon_starter"]`. Lalu upgrade **sekali lagi** supaya levelnya jadi 3, lalu tekan tombol upgrade sekali lagi | Upgrade pertama **diterima** — `pathId` di level 1 diabaikan, **tidak ditolak**, karena client yang mengirimnya terus-menerus bukan client yang menyerang, cuma client yang tidak melacak level. Tapi `GetProfile` mengembalikan `{ level = 2, path = "none" }`: alurnya **tidak tersimpan**. Output server **tidak** memuat baris `mengunci alur` sama sekali. Dan buktinya yang paling tegas ada di langkah terakhir: saat naik ke level 4, panel pemilihan alur **masih menagih** pilihan seperti di PROG-19. Kalau `path` sudah `"a"` sesudah upgrade pertama — atau kalau panelnya tidak muncul lagi di level 4 — masa percobaan level 1-3 hilang tanpa jejak, dan client bisa mengunci alur pemain di upgrade pertamanya. Ini kasus regresi untuk `ProgressionRules.pathToApply`, dan dia gagal **diam-diam**: tidak ada error, tidak ada pesan, cuma pemain yang terkunci di alur yang tidak pernah dia baca | M5 | solo+EDIT | BLOK |
| PROG-24 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` level 5 dengan `path = "b"` (jalan pintas 2 di kotak di atas), koin cukup | `R.UpgradeWeapon:FireServer("weapon_starter")` — **tanpa** argumen kedua. Lalu `FireServer("weapon_starter", "b")` — dengan alur yang sama dengan yang sudah terpilih | **Dua-duanya diterima**, jadi level 5 → 6 → 7. Yang pertama membuktikan client lama yang cuma mengirim `weaponId` tetap bisa upgrade di level yang tidak butuh pilihan; yang kedua membuktikan mengirim alur yang **sama** bukan percobaan ganti alur dan tidak ditolak. Panel pemilihan alur **tidak** muncul untuk keduanya, dan Output server tidak memuat baris `mengunci alur` — alurnya tidak disentuh, cuma levelnya yang naik. Perhatikan level 7 yang didarati upgrade kedua: itu titik tingkat 2 alur, dan dia **tidak** menagih apa pun karena pilihannya sudah diambil di level 4 — tapi tingkat 2-nya **terbuka tanpa diminta**, dan itu yang harus ikut terbaca. Damage mendarat di **43**, yaitu kurva generik apa adanya, karena tingkat 2 Ayunan Cepat cuma menyetel `effects.slowMult` 0.65 dan `slowSeconds` 1.5 — bukan damage ([bagian 4.2](#42-angka-patokan)). Jadi yang berubah di level 7 ini tidak kelihatan di panel sama sekali, cuma di arena: musuh yang kena pukulan sekarang melambat 35% selama 1.5 detik (COMBAT-23). Dengan alur `a` atau `c` angka damage-nya **bukan** 43 — 64.5 dan 51.6 — jadi baris ini cuma berlaku untuk `path = "b"` seperti yang ditulis di prakondisi | M5 | solo+EDIT | BLOK |
| PROG-25 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: Minimal dua senjata dengan alur yang **berbeda** sudah terpilih — misal `weapon_starter` level 7 alur `b` dan `weapon_ranged` level 4 alur `c`. Catat keduanya lewat `R.GetProfile:InvokeServer().weapons` | Keluar dari server, tunggu semenit, join lagi, baca `weapons` lagi | `path` tiap senjata sama persis seperti sebelum keluar — `"b"` dan `"c"`, bukan `"none"`, bukan `nil`, dan **tidak tertukar** antar senjata. Levelnya juga. Ini yang membuktikan keputusan permanen itu benar-benar permanen melewati satu siklus save/load, dan dia tidak bisa dites di Studio tanpa DataStore: di sana `weapons` cuma hidup di memori, jadi `path` yang "bertahan" di situ cuma berarti tabelnya tidak disentuh. Kalau `path` pulang sebagai `"none"`, pemain kehilangan keputusan yang tidak bisa dia ambil lagi; kalau pulang sebagai `nil`, lihat DATA-12 | M5 | PUB | BLOK |
| PROG-26 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: `weapon_starter` **level 3** dengan `path` masih `"none"`. Dijalankan dua kali: sekali dengan koin **cukup** (≥ 91), sekali dengan koin **kurang** (misal 50) | (a) Buka panelnya lalu tekan tombol batal. (b) Buka lagi lalu konfirmasi satu alur saat koin kurang. (c) Buka lagi lalu tekan Ready dan biarkan state pindah ke `Loadout`. (d) Dengan koin kurang, buka panelnya dan baca ketiga alurnya | (a) Panel tertutup dan **tidak ada apa pun yang terkirim**: level, koin, dan `path` tidak berubah, dan Output server tidak memuat satu baris pun dari `ProgressionService`. (b) `ActionResult` datang `ok = false` dengan "Koin kurang: butuh 91, ada 50." dan panel **tetap terbuka** — alasannya harus bisa dibaca, dan panel yang menutup sendiri atas penolakan menyembunyikannya. Bandingkan dengan PROG-20, tempat `ok = true` justru menutup panelnya: dua arah yang berbeda dari satu payload yang sama. (c) Panel tertutup sendiri begitu state keluar dari `Lobby` — upgrade cuma bisa di `Lobby` (PROG-17), jadi panel yang masih terbuka di `Loadout` cuma bisa mengirim sesuatu yang pasti ditolak. (d) Tombol konfirmasi ketiga alur **mati**, tapi nama, tema, dan ketiga baris `summary` ketiganya tetap **terbaca** — membaca tidak boleh butuh koin, karena pemain yang sedang menabung untuk level 4 justru dia yang paling butuh tahu apa yang akan dia putuskan. Panel yang kosong atau tidak bisa dibuka saat koin kurang adalah GAGAL | M5 | solo+EDIT | BLOK |
| PROG-27 | **Tiga percobaan, satu baris**, dan ketiganya lewat jalan pintas 3 di kotak di atas: kembalian `MatchUpgradeRules.freshSave()` diubah berturut-turut jadi `{ level = 4, path = "a" }`, `{ level = 4, path = "b" }`, dan `{ level = 4, path = "c" }`. Patch Wrench dipakai, satu `basic` di wave 1 (100 HP) untuk tiap percobaan. **Balikkan sebelum commit** | Baca angka damage dan jeda di baris detail **panel Toko Match** (jeda pertama sudah cukup — senjatanya lahir di level 4), lalu hitung serangan untuk membunuh satu `basic` | **Ketiganya berbeda, dan di sinilah pohon alur pertama kali berarti sesuatu.** Alur `a`: damage **51**, jeda **0.70s**, `basic` mati dalam **2** serangan. Alur `b`: damage **34**, jeda **0.32s**, **3** serangan. Alur `c`: damage **34**, jeda **0.50s**, **3** serangan. Angka di baris detail panel toko harus cocok dengan tabel [bagian 4.2](#42-angka-patokan) sampai pembulatannya, dan jumlah serangannya harus cocok dengan angka itu — panel yang benar sementara arenanya memberi angka lain berarti `weaponStats` dipakai di satu sisi saja. Yang membedakan `b` dari `c` cuma jedanya, jadi stopwatch (atau ritme bar HP turun) yang memisahkan keduanya, bukan jumlah serangan | M5 | solo+EDIT | - |
| PROG-28 | **Dua percobaan**, keduanya lewat jalan pintas 3: `MatchUpgradeRules.freshSave()` dikembalikan `{ level = 7, path = "b" }` lalu `{ level = 10, path = "b" }`. Packet Rifle di-equip di fase `Loadout` — dimiliki sejak awal, jadi tidak ada flag yang perlu dinyalakan. **Balikkan sebelum commit** | Baca damage, jeda, dan jangkauan di baris detail panel Toko Match. Lalu di match, tembak satu musuh pada **50 stud** dan satu musuh pada **35 stud** | Level 7: damage **21.1904**, jeda **0.15s**, jangkauan **40 stud**. Level 10: damage **25.6256**, jeda **0.12s**, jangkauan **40 stud**, dan satu tembakan menembus **2** musuh. Musuh pada 50 stud **tidak kena** di kedua level — Semburan tingkat 2 memendekkan jangkauannya sendiri dari 60 jadi 40, dan itu upgrade yang membuat senjata tidak bisa lagi menjangkau musuh yang tadi kena (T14). Musuh pada 35 stud kena di kedua level | M5 | solo+EDIT | - |

## 14. Multiplayer dan rejoin (MP)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3 (aturan join dan rejoin), M6.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| MP-01 | 2 client, state `Lobby` | Tekan Ready di satu client saja, tunggu beberapa detik, baru Ready di client kedua | Tidak ada timer yang jalan saat baru satu player Ready — state tetap "Di lobby". Baris petunjuk di panel pemain yang sudah Ready berbunyi "Kamu siap. Menunggu pemain lain." Setelah **semua player di server** Ready, yang mulai adalah fase **`Loadout`** ("Pilih senjata · 20s"), bukan hitung mundur; "Match mulai dalam · 10s" baru 20 detik sesudahnya. Baris petunjuk di kedua client ikut berubah jadi "Pilih senjata sekarang — terkunci setelah ini. Upgrade-nya nanti di dalam match, tiap jeda wave." | M6 | 2P | - |
| MP-02 | 4 client, state `Lobby` | Ready di keempat client, lalu amati keempat layar selama 20 detik fase `Loadout` | Fase `Loadout` mulai setelah yang terakhir Ready, dan **keempat** client menampilkan "Pilih senjata · 20s" dengan angka yang sama — timernya satu, milik server. Keempat pemain bisa menekan "Pakai" dan tombol kesulitan di jendelanya masing-masing selama fase itu, bebas satu sama lain (pilihan senjata per pemain; kesulitan yang menang adalah yang paling mudah di antara pilihan mereka, MP-13). Hitung mundur 10 detik menyusul, lalu keempat player masuk arena saat `WaveActive`. Dua puluh detik dipilih justru untuk kasus ini — empat orang membaca tiga baris senjata, bukan satu | M6 | 4P | - |
| MP-03 | 4 client, match mulai | Mainkan satu match penuh wave 1 sampai 10 termasuk kedua boss | Match jalan lancar sampai layar hasil; musuh dan boss terlihat sama di semua client; **tidak ada error di Output jendela server** | M6 | 4P | - |
| MP-04 | 4 client, state `WaveActive` | Satu player saja yang membunuh beberapa musuh, lalu bandingkan angka cash di keempat layar | Cash naik **hanya di layar pemain yang membunuh**, sebesar tipe musuhnya (`basic` +5, `fast` +7, `tank` +15). Tiga layar lain **tidak bergerak sama sekali**. Ini kebalikan dari harapan baris ini sebelumnya: cash bukan lagi satu kolam tim, dia milik masing-masing pemain, dan `MatchCoins` dikirim `FireClient` ([bagian 4.2](#42-angka-patokan)). Satu pengecualian yang harus dibedakan: musuh yang mati **tanpa pembunuh yang bisa ditunjuk** — zona jebakan, turret, mekanik boss — dibayarkan ke **semua** peserta sekaligus, jadi empat layar yang naik bersamaan saat tidak ada yang menyerang bukan bug. Yang GAGAL: keempat layar naik bersamaan saat satu pemain memukul musuh dengan senjatanya | M6 | 4P | - |
| MP-05 | 4 client, satu match selesai | Bandingkan print `[RewardService]` keempat player dan data permanen masing-masing | Setiap player dapat koin dan XP di datanya sendiri, dengan **jumlah yang sama** (dihitung dari wave yang dicapai), bukan satu kantong yang dibagi empat | M6 | 4P | - |
| MP-06 | 4 client, state `WaveActive` di wave 3 atau lebih; catat cash **pemain yang akan keluar** dan level senjatanya di panel toko | Tutup satu jendela client, tunggu satu wave, lalu join lagi dengan player yang sama | Player itu masuk kembali ke arena (spawn di `Arena/PlayerSpawn`), bukan ditahan di lobby; Output mencetak `[MatchService] <nama> rejoin ke match berjalan`; HUD-nya menampilkan state, wave, dan HP Core terkini; **cash dan level senjatanya utuh** — keduanya disimpan per UserId dan tidak dihapus saat dia keluar, dengan alasan yang sama seperti `participants`: saldo yang hangus karena koneksi putus sebentar adalah hukuman untuk sesuatu yang bukan salahnya. Hadiah wave yang jatuh **selama dia tidak ada** memang tidak dia terima — yang dibayar cuma peserta yang sedang terhubung | M6 | LIVE | - |
| MP-07 | Match sedang `WaveActive` dengan peserta yang sudah terdaftar | Join dengan player **baru** yang belum pernah ikut match itu | Player baru muncul di `Lobby/SpawnLocation` dan **tidak** dipindahkan ke arena; HUD-nya tetap menampilkan state dan wave yang berjalan supaya dia tahu match sedang jalan; `Attack`-nya ditolak server (tidak ada damage sama sekali) | M6 | LIVE | - |
| MP-08 | Player baru dari MP-07 masih di lobby | Tunggu match selesai sampai state `Lobby`, lalu tekan Ready bersama yang lain | Player baru bisa ikut match berikutnya secara normal | M6 | LIVE | - |
| MP-09 | 2 client, state `WaveActive`, keduanya peserta | Tutup client ke-2 di tengah wave, amati; lalu tutup client pertama juga | Setelah client ke-2 ditutup: match **terus jalan** untuk pemain pertama, tidak ada pembatalan. Setelah semua peserta keluar: Output mencetak `[MatchService] semua peserta keluar, match dibatalkan dan kembali ke Lobby`, state kembali `Lobby`, musuh dibersihkan, server tidak nyangkut di `WaveActive`. Join lagi setelah itu masuk lobby dan bisa mulai match baru. Pembatalan **bukan** kekalahan: `onMatchEnded` tidak ditembakkan, jadi tidak ada reward yang dihitung dua kali | M6 | 2P | - |
| MP-10 | 2 client, state `WaveActive` di wave 4 | Satu player keluar dan **tidak** kembali; biarkan match lanjut sampai selesai | Output mencetak `[RewardService] <nama>: wave 4 tidak selesai/kalah, +40 koin, +80 xp` **saat dia keluar** — tanpa bonus menang, tapi tetap dapat reward sesuai wave saat dia keluar. Player yang tinggal tetap bisa menyelesaikan match | M6 | 2P | - |
| MP-11 | 2 client, cash sudah terkumpul dan senjata salah satu pemain sudah di atas level 1, state `Intermission` | Satu peserta disconnect lalu rejoin, lalu upgrade senjatanya di panel toko | Cash **dan** level senjata pemain itu masih utuh setelah rejoin (tidak hangus dan tidak dobel); panel toko langsung menampilkan judul "Nama · level N/10" dan saldo yang benar begitu dia masuk, tanpa menunggu upgrade berikutnya — `broadcastCashTo` dan `broadcastUpgradeStateTo` dipanggil di `Players.PlayerAdded`. Upgrade sesudah rejoin memakai cash yang sama dan melanjutkan dari level yang sama | M6 | LIVE | - |
| MP-12 | 4 client, wave 10 dengan `boss_locker` dan minion | Amati Output jendela server selama wave 10 sampai layar hasil | Tidak ada error atau warning berulang; game tetap responsif | M6 | 4P | - |
| MP-13 | 2 client, `hard` terbuka untuk keduanya. Satu pemain memilih **Hard**, satu memilih **Normal** | Keduanya Ready, masuk wave 1, hitung serangan untuk membunuh satu `basic`. Ulangi dengan pilihannya ditekan **di dalam** fase `Loadout`, bukan di `Lobby` | Match jalan di **Normal** — yang paling mudah di antara pilihan mereka. 4 serangan, bukan 8. Alasannya di [tabel keputusan M2](#202-keputusan-m2): `hard` harus dibuka per pemain, jadi aturan yang mengambil yang lebih sulit bisa memaksa pemain ikut match di tingkat yang belum dia buka. Hasilnya **sama** apakah pilihannya ditekan di `Lobby` atau di `Loadout`: `lockDifficulty()` dipanggil saat **meninggalkan** `Loadout`, jadi yang dibandingkan adalah pilihan terakhir tiap pemain pada detik fase itu berakhir (MATCH-19) | M6 | 2P | - |
| MP-14 | **TIDAK BISA DIJALANKAN selama kelima item toko dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`, [bagian 4.2](#42-angka-patokan)): `ShopService.onBuy` menolak pembelian apa pun di server dengan "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata.", dan panel toko tidak lagi memuat satu pun item. `BLOK`, bukan GAGAL — definisi item, `ShopRules`, efeknya, dan unit test-nya masih utuh dan masih lulus. Syarat menjalankannya lagi: `Config.MATCH_SHOP_ITEMS_ENABLED = true`. Prakondisi aslinya: 2 client, state `Intermission`, kolam di atas **1.400** cash. Hotfix dan Firewall Block belum pernah dibeli di match ini | Pemain A membeli **Hotfix** tiga kali, lalu **Firewall Block** lima kali. Pemain B tidak menyentuh apa pun — cuma melihat panelnya | Saldo di layar pemain B **ikut turun**, dan sebesar harga yang naik: **150, 187, 234** untuk Hotfix. Harga di baris Hotfix di layar **B juga naik** mengikuti, jadi tombol B menampilkan 187 lalu 234 lalu **292** tanpa B membeli apa pun — pembukuan `purchases` dibagi tim, bukan per pemain, dan harga dihitung dari pembukuan itu. Lalu untuk Firewall Block: setelah pembelian **kelima**, tombol Firewall Block di layar **B juga mati** dan barisnya memuat "· sisa 0". Satu kolam, satu pembukuan, dua layar. Perhatikan bahwa Hotfix **tidak** bisa dipakai menguji jatah yang habis — jatahnya sudah dihapus, dan satu-satunya item yang masih dibatasi adalah Firewall Block | M3 | 2P | BLOK |
| MP-15 | 4 client, match berjalan sampai minimal jeda kedua, keempatnya ikut menyerang dengan porsi yang berbeda-beda | Di `Intermission`, bandingkan **keempat** panel toko berdampingan: saldo, judul, dan harga di tombol | Empat saldo yang **berbeda**, dan level senjata yang bisa berbeda juga. Hadiah wave membuat keempatnya naik dengan angka yang **sama** di detik wave selesai; yang memisahkan mereka cash dari membunuh. Tiap panel menampilkan **senjata pemain itu sendiri** dengan levelnya sendiri — panel yang menampilkan nama senjata pemain lain berarti `MatchUpgradeState` disiarkan ke semua client alih-alih dikirim per pemain. Yang GAGAL: empat saldo yang sama persis, atau level yang ikut naik di panel pemain yang tidak membeli apa pun | M6 | 4P | - |

## 15. Leaderboard (LB)

**Kelompok ini tidak lagi `BELUM`.** `LeaderboardRules`,
`LeaderboardService`, remote `GetLeaderboard`, dan panel papan di lobby sudah
ada. Yang menghalangi sekarang satu hal, dan bukan kodenya: **OrderedDataStore
ditolak di place yang belum pernah di-publish**, alasan yang sama persis dengan
DataStore biasa —
[kotak bagian 2.2](#22-kotak-datastore--baca-sebelum-menyalahkan-kode) berlaku
apa adanya untuk papan ini. Jadi LB-01 sampai LB-05 berkode `PUB`. Tanpa
publish, papannya **kosong tapi diam** — tabel kosong, satu warn per tingkat
kesulitan, tidak ada error dan tidak ada yang menggantung — dan itu yang benar,
bukan bug yang perlu dicatat.

LB-00 bisa dijalankan sekarang, dan separuhnya sudah dijaga harness Studio
(lihat [bagian 3.2](#32-cakupan-harness-studio)).

Bentuk papannya, supaya langkah di bawah tidak perlu menebak: panel ada di sisi
**kanan** layar dan cuma terlihat saat state `Lobby` dan `Loadout` — dua state
yang sama dengan panel lobby (`MatchRules.canSelectLoadout`). Sisi kanan itu
juga dipakai panel toko, tapi toko cuma muncul saat `Intermission`, jadi
keduanya tidak pernah tampil bersamaan. Dua tab, **Normal** dan **Hard**,
sepuluh baris berformat `1.  Nama  --  wave 7`, dan baris milik pemain sendiri
diwarnai aksen. Papannya diminta ulang saat start, saat ganti tab, saat state
kembali ke `Lobby`, dan tiap 20 detik selama panel terlihat.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| LB-00 | — | `print(game.ReplicatedStorage.Remotes:FindFirstChild("GetLeaderboard"))` lalu `print(game.ReplicatedStorage.Remotes.GetLeaderboard:InvokeServer("normal"))`, dua-duanya dari command bar client | Yang pertama mencetak remote-nya, bukan `nil`. Yang kedua **kembali**, dan mengembalikan tabel — kosong kalau place belum di-publish, dan itu benar. Yang dinilai di sini bukan isinya tapi bahwa panggilannya selesai: `OnServerInvoke` menjawab dari papan di memori dan tidak pernah yield, jadi tidak ada jalur yang bisa menggantungkan client. Separuh pertama sudah dipatok harness (`boot.remote.getLeaderboardAda`, `boot.remote.getLeaderboardRemoteFunction`) | M6 | solo | - |
| LB-01 | API Services aktif; panel papan terlihat di lobby, tab **Normal** | Selesaikan satu match di `normal` sampai wave tertentu, kembali ke lobby | Wave tertinggi player tercatat dan tampil di papan `normal` dengan nama player. Pencatatannya terjadi saat match selesai, untuk peserta yang **masih terhubung** — peserta yang keluar di tengah match sudah dicatat sendiri saat dia keluar, dengan wave yang dia capai saat itu | M6 | PUB | - |
| LB-02 | `hard` sudah terbuka | Selesaikan satu match di `hard` dengan wave berbeda dari catatan `normal`, lalu bandingkan kedua tab | Catatan `hard` dan `normal` terpisah; wave di `hard` tidak menimpa catatan `normal` dan sebaliknya. Pemisahnya bukan filter saat membaca melainkan **store yang berbeda**: `HighestWave_v1_normal` dan `HighestWave_v1_hard` (`LeaderboardRules.storeNameFor`). Yang dicari kalau baris ini gagal: sepuluh teratas satu tab berisi catatan tingkat yang lain | M6 | PUB | - |
| LB-03 | Sudah ada catatan wave tinggi (misal wave 8) | Selesaikan match baru yang berakhir di wave lebih rendah (misal wave 3), lihat papan, lalu ulangi setelah restart server | Catatan di papan tetap wave 8; tidak turun — di papan yang tampil **maupun** setelah restart. Dua tempat itu memang dua pembukuan yang berbeda (papan memori lewat `merge`, penyimpanan lewat transform `UpdateAsync`), dan keduanya memakai `isRecord` yang sama. Papan yang "turun sendiri" baru sesudah restart berarti keduanya tidak lagi sepakat | M6 | PUB | - |
| LB-04 | Papan terlihat di lobby, server tidak di-restart | Selesaikan match yang memecahkan rekor, kembali ke lobby | Papan ikut terupdate tanpa perlu restart server atau rejoin, paling lambat pada permintaan berikutnya (panel meminta ulang saat state kembali ke `Lobby`, dan tiap 20 detik sesudahnya). Rekor baru **dijahit ke papan memori**, bukan memicu pembacaan ulang OrderedDataStore — jadi angka yang muncul datang dari `merge`, bukan dari `GetSortedAsync` | M6 | PUB | - |
| LB-05 | 2 client dengan wave tertinggi berbeda | Lihat papan dari kedua client, di tab yang sama | Urutan sesuai wave tertinggi (yang lebih tinggi di atas); angka tiap player benar; **kedua client melihat urutan yang sama**, dan baris milik pemain yang sedang melihat diwarnai aksen di masing-masing client. Dua pemain yang wave-nya kebetulan sama tidak boleh bertukar baris saat papan di-refresh — pemecah serinya `userId` menaik | M6 | PUB+2P | - |

## 16. Keamanan remote (SEC)

Acuan: DEVELOPMENT_PLAN.md bagian 3.6 (kolom "Validasi server") dan bagian 6
("Tes keamanan remote"). Kontrak remote yang sebenarnya ada di
[bagian 4.1](#41-remote-yang-benar-benar-terdaftar).

Semua baris di bagian ini dijalankan dari **command bar jendela client**
(Test → Current: Client), dengan `local R = game:GetService("ReplicatedStorage").Remotes`.
Pola argumen yang dicoba untuk tiap remote: `nil`, angka negatif, tipe yang salah
(string di tempat angka dan sebaliknya, tabel, `Instance`), id yang tidak ada di
modul definisi, jumlah argumen kurang atau lebih, dan spam melebihi rate limit.

Yang dinilai sama untuk semua baris, jadi tidak diulang di tiap kolom:
**aksinya tidak terjadi, data player maupun state match tidak berubah, dan Output
jendela server bersih** — tidak ada stack trace, tidak ada warning berulang.
Server yang error karena argumen sampah dianggap GAGAL walaupun aksinya tidak
jadi.

Satu catatan yang berlaku untuk semua: **argumen yang tipenya salah atau id-nya
tidak dikenal dibuang tanpa balasan apa pun.** `ActionResult` cuma dikirim untuk
penolakan yang punya alasan yang bisa diberitahukan ke pemain (state salah,
belum dimiliki, cash atau koin kurang). Jadi "tidak ada `ActionResult`" bukan
kegagalan.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| SEC-01 | State `Lobby`, lalu ulangi saat `WaveActive` | `R.SetReady:FireServer(nil)`, `FireServer(-1)`, `FireServer("true")`, `FireServer({})`, `FireServer()`, lalu `for _ = 1, 200 do R.SetReady:FireServer(true) end` | Ready hanya berubah untuk boolean yang sah, dan hanya saat `Lobby`, `Loadout`, atau `Countdown` (dua yang terakhir diizinkan khusus untuk **membatalkan**; cuma dari `Lobby` yang bisa memulai fase `Loadout`). Argumen lain diabaikan. Spam dibatasi **2 per detik** dan sisanya dibuang tanpa error; fase `Loadout` tidak terpicu berulang dan timernya tidak ter-reset oleh `FireServer(true)` kedua | M6 | solo | - |
| SEC-02 | State `Lobby` | `R.SelectLoadout:FireServer(nil, nil)`, `FireServer(1, 2)`, `FireServer("weapon_tidak_ada", "normal")`, `FireServer("weapon_starter", "critical")`, `FireServer("weapon_ranged", "normal")`, `FireServer("weapon_starter", "hard")` sebelum hard terbuka, `FireServer({}, {})`, lalu spam 200x | Loadout hanya berubah untuk senjata yang **dimiliki** dan tingkat yang **terbuka**. `"critical"` dan id yang tidak ada dibuang tanpa balasan — `critical` memang belum ada di v1. `FireServer("weapon_starter", "hard")` sebelum hard terbuka membalas `ActionResult` dengan `ok = false` dan **"Tingkat kesulitan itu belum terbuka."**, dan `equippedWeapon` **tidak** berubah. Spam dibatasi 2 per detik. **`"weapon_ranged"` bukan lagi contoh penolakan**: ketiga senjata dimiliki sejak awal ([bagian 4.2](#42-angka-patokan)), jadi yang dulu ditolak "Senjata itu belum kamu miliki." sekarang **diterima** — `equippedWeapon` memang berganti jadi `weapon_ranged`, dan itu yang benar. Penolakan "belum kamu miliki" tidak punya satu pun id yang bisa memicunya hari ini: id yang tidak ada di `Weapons.luau` berhenti lebih dulu di gerbang id dan dibuang tanpa balasan. Jadi kembalikan `equippedWeapon` ke `weapon_starter` sesudah baris ini kalau baris berikutnya mengandalkannya. Perhatikan urutan gerbangnya: **state diperiksa paling dulu**, jadi di luar `Lobby` dan `Loadout` seluruh daftar argumen di atas dibalas pesan yang sama, "Loadout sudah terkunci sampai match selesai." (MATCH-21) — baris ini harus dijalankan di `Lobby` atau validasi argumennya tidak pernah tersentuh | M6 | solo | - |
| SEC-03 | State `WaveActive` sebagai peserta, lalu ulangi sebagai player yang bukan peserta | `R.Attack:FireServer()`, `FireServer(-1)`, `FireServer("depan")`, `FireServer(Vector3.new(0, 0, 0))`, `FireServer(Vector3.new(0/0, 0, 0))`, `FireServer(Vector3.new(1e9, 1e9, 1e9))`, `FireServer({})`, lalu `for _ = 1, 500 do R.Attack:FireServer(Vector3.new(0, 0, -1)) end` | Hanya `Vector3` dengan magnitude wajar yang diproses. Arah nol, NaN, dan inf ditolak sebelum dipakai. Arah ekstrem dinormalisasi jadi arah biasa, tidak membuat damage aneh dan tidak menjangkau musuh di luar `range`. Serangan dari player di luar `participants` ditolak. Spam dibatasi **20 per detik** di rate limit **dan** cooldown senjata di atasnya — musuh tidak mati lebih cepat dari ~2 serangan per detik dengan starter | M6 | solo | - |
| SEC-04 | State `Intermission`, lalu ulangi saat `WaveActive` dan `Lobby` | `R.BuyShopItem:FireServer()`, `FireServer(123)`, `FireServer("shop_tidak_ada")`, `FireServer({ id = "shop_barrier" })`, lalu spam 100x dengan id valid | Argumen yang bukan string dibuang tanpa balasan; sisanya ditolak. **Selama item toko dimatikan, peserta mana pun dibalas "Toko item sudah tidak ada. Yang dijual sekarang upgrade senjata." sebelum id-nya diperiksa sama sekali**, jadi yang dibuktikan baris ini sekarang bahwa pintu yang dimatikan benar-benar tertutup di server: cash **tidak pernah berubah**, tidak ada item yang aktif di wave berikutnya, tidak ada turret yang muncul, dan Output server bersih. Dengan `MATCH_SHOP_ITEMS_ENABLED = true` baris ini kembali menguji gerbang aslinya: hanya id yang ada di `ShopItems.luau` dan hanya saat `Intermission` yang diproses, dan spam tidak membuat item terbeli melebihi cash karena cash dipotong **sebelum** efeknya dijalankan | M6 | solo | - |
| SEC-05 | State **`Intermission`** sebagai peserta — bukan `Lobby` lagi: remote ini pindah ke `ShopService` dan dari lobby semuanya berhenti di "Kamu bukan peserta match ini." sebelum argumennya diperiksa | `R.UpgradeWeapon:FireServer()`, `FireServer(42)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_boss_a")` saat yang dipakai Patch Wrench, lalu spam 200x saat cash cuma cukup untuk satu level. Lalu argumen **kedua**: `FireServer("weapon_starter", {})`, `FireServer("weapon_starter", 1)`, `FireServer("weapon_starter", "a", "b")`, dan `FireServer("weapon_starter", "none")` | `nil` dan angka di argumen pertama dibuang tanpa balasan. Id yang tidak ada dan senjata yang bukan sedang dipakai dibalas "Senjata itu bukan yang sedang kamu pakai." — gerbangnya `data.equippedWeapon`, bukan daftar kepemilikan, jadi senjata yang dimiliki tapi tidak dipakai ikut ditolak. Spam **tidak** menaikkan beberapa level dengan bayar sekali: rate limit 2/detik, dan cash dipotong sebelum save diganti. Cash tidak pernah negatif. Argumen kedua: tabel dan angka **dibuang jadi nil** (bukan membatalkan aksi), argumen ketiga diabaikan, dan `"none"` diperlakukan sebagai tidak memilih — jadi di bawah titik percabangan keempatnya menaikkan level seperti biasa, dan **tepat di titik percabangan** keempatnya ditolak dengan tagihan pilihan alur. Satu yang tidak lagi berlaku: tidak ada koin permanen yang bisa berkurang di baris ini | M6 | solo | - |
| SEC-06 | State `Lobby`. Ketiga senjata dimiliki sejak awal ([bagian 4.2](#42-angka-patokan)), jadi tidak ada yang perlu disiapkan — dan itu yang menggeser separuh harapan baris ini | `R.BuyWeapon:FireServer()`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_starter")`, `FireServer("weapon_boss_a")`, lalu spam 100x `FireServer("weapon_ranged")` | Yang **tetap** diuji dan tetap jadi isi baris ini: argumen `nil`, angka, dan id yang tidak ada dibuang tanpa error dan tanpa `ActionResult`, spam di-throttle 2/detik, koin tidak berkurang sama sekali, dan Output server bersih. Yang **bergeser**: ketiga id yang sah sekarang dibalas **"... sudah kamu miliki."**, termasuk `weapon_boss_a` — pesan "tidak dijual dengan koin" ada di `canBuy` sesudah pemeriksaan kepemilikan, jadi dia tidak tercapai selama senjatanya dimiliki (PROG-18). Penolakan yang **tidak** menyebut kepemilikan di sini bukan GAGAL dengan sendirinya, tapi berarti urutan gerbang `canBuy` berubah dan PROG-18 harus dibaca ulang | M6 | solo | - |
| SEC-07 | State `Lobby`, `material_a` berapa pun. Sama dengan SEC-06, ketiga senjata dimiliki sejak awal | `R.CraftWeapon:FireServer()`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_ranged")`, lalu spam 100x `FireServer("weapon_boss_a")` | Yang **tetap** diuji: argumen sampah dibuang tanpa error, spam di-throttle, **material tidak berkurang sedikit pun** dan tidak pernah negatif, Output server bersih. Yang **bergeser**: `weapon_ranged` dan `weapon_boss_a` sama-sama dibalas **"... sudah kamu miliki."**, bukan "tidak dibuat dengan material" dan bukan "Material kurang" — dua pesan itu ada di `canCraft` sesudah pemeriksaan kepemilikan (PROG-13, PROG-18). Yang GAGAL tetap sama: material yang berkurang oleh percobaan yang ditolak | M6 | solo | - |
| SEC-08 | State apa pun; place boleh belum di-publish | `R.GetLeaderboard:InvokeServer()`, `InvokeServer(nil)`, `InvokeServer(-1)`, `InvokeServer("tidakAda")`, `InvokeServer({})`, `InvokeServer("normal", "hard")`, lalu `for _ = 1, 100 do R.GetLeaderboard:InvokeServer("normal") end` | Tidak pernah error — tidak di client, tidak di server. Tingkat yang tidak dikenal (termasuk `nil`, angka, dan tabel) dibalas **`nil`**, bukan error dan bukan tabel kosong: id itu dipakai menyusun nama OrderedDataStore, jadi yang tidak ada di `Difficulties` harus berhenti di gerbang. Panggilan yang kena throttle (**2/detik**) juga dibalas `nil`, dengan alasan yang sama seperti `GetProfile` di SEC-10 — `error()` di dalam `OnServerInvoke` muncul di client sebagai error yang tidak bisa dia tangani dengan rapi, dan client memperlakukan `nil` sebagai "papan belum ada" lalu membiarkan papan lamanya. Spam 100x **tidak membanjiri OrderedDataStore**: `OnServerInvoke` menjawab dari papan di memori dan cuma menjadwalkan pembacaan ulang, dengan jarak minimum **15 detik** per tingkat, jadi seluruh spam itu menghasilkan paling banyak satu `GetSortedAsync`. Argumen kedua dan seterusnya diabaikan | M6 | solo | - |
| SEC-09 | State apa pun | `R.RequestAction:FireServer()`, `FireServer(-1)`, `FireServer("aksi_tidak_ada")`, `FireServer({})`, `FireServer("claimDailyBonus")`, lalu spam 500x | Aksi yang tidak dikenal diabaikan tanpa error dan tanpa `ActionResult`. `"claimDailyBonus"` tidak memberi koin karena `lastLogin` baru di-set saat load, jadi selisihnya belum lewat 86400 detik — itu benar. Spam 500x **di-throttle 2/detik** — sisanya diabaikan tanpa error dan tanpa `ActionResult`, dan tidak ada perubahan data sama sekali | M6 | solo | - |
| SEC-10 | State apa pun, dua player di server | `R.GetProfile:InvokeServer()`, `InvokeServer(nil)`, `InvokeServer(-1)`, `InvokeServer(<UserId player lain>)`, lalu panggil 100x berturut-turut | Yang dikembalikan **selalu** data player yang memanggil — fungsinya tidak menerima argumen sama sekali, jadi apa pun yang dikirim diabaikan. Tidak pernah error. Pemanggilan 100x berturut-turut **di-throttle 2/detik**, dan yang kena throttle mengembalikan `nil` — bukan error, supaya client yang menunggu nilai balik tidak kena error yang tidak bisa dia tangani. Catatan: kalau data pemain belum siap, pemanggilan bisa menggantung sampai 90 detik lalu juga mengembalikan `nil` — itu batas yang disengaja, bukan hang, dan dari sisi client dua-duanya terbaca sama: `ProfileStore` tetap menunggu `DataLoaded` | M6 | solo | - |
| SEC-11 | 2 client, match berjalan | Dari satu client, spam seluruh remote C → S bergantian terus-menerus selama 30 detik | Server tetap responsif untuk client kedua (musuh tetap bergerak, HUD tetap update); pelaku di-throttle di **setiap** remote C → S; tidak ada error di Output server | M6 | 2P | - |
| SEC-12 | Match berjalan | Dari command bar client, ubah angka di salinan modul shared yang ter-replikasi ke client (misal `require(game.ReplicatedStorage.Shared.Modules.Weapons).weapon_starter.baseDamage = 9999`), lalu serang musuh | Damage yang masuk **tidak berubah** — server memakai salinan modulnya sendiri dan tidak pernah percaya angka dari client. Begitu juga harga di toko dan di panel lobby: mengubahnya di client cuma mengubah teks tombol, pembeliannya tetap divalidasi server | M6 | solo | - |
| SEC-13 | Match berjalan | Panggil `:FireServer()` pada remote yang arahnya **S → C**: `R.MatchState`, `R.MatchCoins`, `R.MatchResult`, `R.EnemyHit`, `R.ShopState`, `R.BossState`, `R.ShowInfoCard`, `R.ActionResult`, `R.DataLoaded`, `R.DataChanged` | Tidak terjadi apa pun dan **tidak ada error di Output server** — tidak ada satu pun dari remote itu yang punya `OnServerEvent` tersambung. Yang dicari di sini adalah remote S → C yang diam-diam dipakai dua arah | M6 | solo | - |
| SEC-14 | Inventaris, bukan percobaan | Bandingkan daftar remote C → S di `Remotes.luau` dengan registry `RateLimit` di tiap service dan di `init.server.luau` | Setiap remote C → S punya rate limit: `Attack` 20/detik; `SetReady`, `SelectLoadout`, `BuyShopItem`, `UpgradeWeapon`, `BuyWeapon`, `CraftWeapon`, `RequestAction`, `GetProfile`, `GetLeaderboard` 2/detik. Tidak ada yang tertinggal — itu item M6 "Rate limit di semua remote". Registry `GetLeaderboard` ada di `LeaderboardService`, bukan di `init.server.luau`, karena wiring remote-nya juga di situ | M6 | solo | - |

## 17. Persistence DataStore (DATA)

Acuan: DEVELOPMENT_PLAN.md bagian 3.2 dan bagian 6 ("Tes data"). Hampir semua
baris di sini butuh **place yang sudah di-publish** dan **Enable Studio Access to
API Services** — baca [kotak DataStore](#22-kotak-datastore--baca-sebelum-menyalahkan-kode)
dulu.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| DATA-01 | Dua player baru (belum punya save) join hampir berbarengan di satu server | Mainkan satu match sampai salah satu dari mereka mencapai wave yang lebih tinggi atau mengalahkan satu boss, lalu bandingkan `stats`, `materials`, dan `clears` kedua player lewat `R.GetProfile:InvokeServer()` dari masing-masing client | Angka player kedua **tidak ikut bergerak** saat yang pertama berubah — tabel bersarang dua player tidak berbagi referensi yang sama. Ini test eksplisit untuk bug deep copy (bagian 3.2 poin 1), dan dia **bisa dijalankan tanpa publish**: tanpa DataStore, data default tetap di-deep-copy per pemain. Catatan: `weapons` **tidak bisa lagi dipakai sebagai probe** di baris ini — level dan alur hidup di dalam match dan tidak pernah ditulis ke data pemain, jadi tabel itu tetap identik untuk semua orang dan kesamaannya bukan bukti apa pun | M0 | 2P | - |
| DATA-02 | Save lama dari sebelum ada field baru. Caranya: main sebentar dengan satu nama DataStore, lalu tambahkan field baru ke `Config.DEFAULT_DATA`, lalu join lagi dengan nama DataStore yang **sama** | Join dengan player itu setelah skema diperluas | Field baru terisi nilai default; nilai lama (koin, level, XP) tidak berubah dan tidak ter-reset; field baru **di dalam** `stats` juga terisi — `reconcile` turun ke tabel bersarang | M0 | PUB | - |
| DATA-03 | Player sudah login; catat koin, lalu ubah progres (selesaikan satu match supaya koin, XP, dan `stats` naik — upgrade senjata **tidak** bisa dipakai lagi untuk ini, dia tidak menyentuh data permanen) | Tunggu lebih dari **120 detik** (`Config.AUTOSAVE_INTERVAL`) tanpa keluar, lalu Stop playtest dan join lagi | Progres yang dibuat sebelum autosave masih ada. Catatan: Stop di Studio juga memicu `PlayerRemoving` yang menyimpan, jadi test ini tidak bisa mengisolasi autosave dari jalur itu — yang dibuktikan adalah "tidak ada yang hilang", dan autosave-nya terbukti di server live lewat DATA-06b | M5 | PUB | - |
| DATA-04 | Match berjalan di wave 4, player adalah peserta | Keluar di tengah match, lalu join lagi | Reward sesuai wave saat keluar sudah tersimpan (40 koin / 80 XP untuk wave 4); tidak ada progres yang hilang; koin **tidak bertambah dua kali**. Pembukuan "sudah dibayar" direset saat `Countdown`, bukan saat match selesai — kalau direset saat `Ended`, keluar-lalu-rejoin jadi cara menggandakan reward | M6 | PUB+LIVE | - |
| DATA-05 | Player baru saja keluar dari server | Join lagi secepat mungkin, saat session lock mungkin masih dipegang | Player **tidak** mendapat data kosong/default. Dia masuk dengan datanya yang benar, atau di-kick dengan pesan **"Gagal memuat data kamu. Coba join ulang sekitar 30 detik lagi."** Batas waktunya: 3 putaran lock x (5 percobaan UpdateAsync dengan backoff 2-4-8-8 + jeda 4 detik) ≈ 80 detik paling buruk — bukan menggantung ratusan detik (bagian 3.2 poin 2) | M6 | PUB | - |
| DATA-06a | Player punya progres yang baru diubah dan belum sempat autosave | Stop playtest di Studio, lalu F5 lagi | Progres terakhir tersimpan. Yang menyimpannya adalah `PlayerRemoving`, **bukan** `BindToClose` — `BindToClose` langsung `return` kalau `RunService:IsStudio()` (keputusan T7) | M5 | PUB | - |
| DATA-06b | Server live dengan pemain di dalamnya | Shutdown server dari dashboard Roblox, lalu join lagi | Progres terakhir tersimpan lewat `BindToClose` (Roblox memberi ~30 detik). Ini satu-satunya cara mengetes jalur itu | M5 | LIVE | - |
| DATA-07 | Catat koin, XP, dan material dengan teliti | Lakukan siklus keluar–join cepat tiga kali berturut-turut tanpa main | Angkanya sama persis setiap kali; tidak ada reward atau material yang bertambah sendiri karena save/load berulang | M6 | PUB | - |
| DATA-08 | Dua player dengan progres jelas berbeda (misal satu level 1, satu level 10) | Join berbarengan, lihat data masing-masing di lobby, keluar, join lagi | Tiap player melihat datanya sendiri; tidak ada data yang tertukar antar player sebelum maupun sesudah rejoin | M6 | PUB+2P | - |
| DATA-09a | API Services **dimatikan** atau place belum di-publish, di **Studio** | Join, mainkan satu match, Stop, F5 lagi | Output memuat **satu** warn saat boot (`[PlayerDataService] DataStore tidak aktif. Publish place-nya sekali, ...`) dan **satu** warn per pemain (`... jalan dengan data default di memori. Progres TIDAK tersimpan. ...`) — bukan banjir error. Game tetap bisa dimainkan penuh dengan data default. Progres hilang saat Stop, dan itu benar: `loaded` di-set false sehingga `save()` tidak pernah menulis, jadi **data lama tidak ditimpa dengan data default** | M6 | solo | - |
| DATA-09b | DataStore tidak tersedia di **server live** | Join | Pemain di-kick dengan **"Layanan data sedang bermasalah. Coba join ulang beberapa saat lagi."** — di server live pemain tidak boleh dijalankan dengan data kosong, karena autosave berikutnya akan menimpa progresnya sendiri | M6 | LIVE | - |
| DATA-10 | Player sudah login dan datanya siap | Amati panel lobby tepat setelah join | Panel menampilkan **"Memuat data..."** sampai data datang, lalu langsung angka yang benar. **Tidak ada momen** UI menampilkan nilai default (koin 0, level 1) padahal datanya bukan itu (bagian 3.2 poin 3 dan 4). Data dikirim lewat `DataLoaded` begitu `onLoaded` menyala, dan client juga menariknya lewat `GetProfile` kalau siaran pertamanya terlewat | M0 | solo | - |
| DATA-11 | Repo baru di-clone, place belum di-publish — **kondisi default yang akan dilihat semua orang pertama kali** | F5 | Server boot normal, gameplay jalan penuh, dan yang muncul di Output cuma dua warn DataStore dari DATA-09a. Tidak ada error. Baris ini ada supaya baseline-nya tercatat: kalau di sini sudah ada error, jangan lanjut ke kelompok lain | M0 | solo | - |
| DATA-12 | Mekanismenya dulu: `PlayerDataService` memanggil `DataSchema.migrate(data, Config.DEFAULT_DATA)`, **bukan** `reconcile`, dan `migrate` = `reconcile` lalu `fillWeaponPaths`. Untuk mensimulasikan save lama tanpa publish, sementara ubah `Config.DEFAULT_DATA.weapons` jadi `{ weapon_starter = { level = 6 }, weapon_ranged = { level = 9 }, weapon_boss_a = { level = 4, path = "c" } }` — dua senjata **tanpa** `path` sama sekali, satu dengan `path` yang sudah terpilih. Perhatikan bahwa `migrate` ikut jalan di jalur tanpa DataStore (`loadWithoutDataStore`), jadi baris ini bisa dijalankan di Studio. Selama edit itu terpasang, `luau-lsp analyze` akan mengeluh soal `path` yang hilang dari `Types.WeaponSave` — itu benar dan justru intinya: field yang hilang itu yang sedang disimulasikan, dan tipenya menuntutnya ada | Join, lalu baca `R.GetProfile:InvokeServer().weapons` | Ketiga senjata punya field `path`: `weapon_starter` dan `weapon_ranged` **`"none"`** — string, bukan `nil` dan bukan field yang hilang — sementara `weapon_boss_a` **tetap `"c"`**, tidak tertimpa. Level ketiganya tidak berubah (6, 9, 4). Dua senjata itu memang titik yang membuat `migrate` perlu ada: `reconcile` sendiri cuma mengisi field hilang dari `Config.DEFAULT_DATA`, dan senjata yang dibeli atau di-craft **sebelum** alur upgrade ada tidak punya default yang bisa dia pakai untuk kunci `path`. Lalu buka panel lobby: `weapon_starter` level 6 dengan `path = "none"` harus **ditagih memilih** saat tombol upgrade ditekan, walaupun levelnya sudah jauh melewati 4 — itu `>=` di `pathChoiceRequired`, bukan `==`. Senjata yang **tidak** ditagih di kondisi itu adalah GAGAL, dan gagalnya diam: pemiliknya berjalan tanpa alur sampai level 10 tanpa satu pesan pun. Balikkan `Config.DEFAULT_DATA` sebelum commit | M5 | solo+EDIT | - |
| DATA-13 | Save **sungguhan** dari sebelum alur upgrade ada. Caranya sama dengan DATA-02: main sebentar dengan satu `Config.DATASTORE_NAME` **sebelum** langkah 6 di-checkout (atau dengan `path` dihapus dari `Config.DEFAULT_DATA`), lalu join lagi dengan nama DataStore yang **sama** sesudah langkah 6 ada | Join, baca `weapons`, keluar, join lagi, baca lagi | Tiap senjata di save lama pulang dengan `path = "none"` dan level yang **tidak berubah**, dan tetap begitu melewati satu siklus keluar–join. Baris ini yang membuktikan migrasinya jalan terhadap JSON yang benar-benar pernah ditulis DataStore, bukan terhadap tabel Lua yang disusun di memori: field bernilai `nil` **hilang total** saat disimpan, jadi save lama dan "sudah dimigrasi tapi belum memilih" cuma bisa dibedakan kalau yang kedua menyimpan string `"none"` — dan kalau `path` pulang sebagai `nil` di sini, perbedaan itu sudah hilang untuk selamanya pada akun itu. **Separuh baris ini tidak bisa dijalankan lagi**: bagian "pilih satu alur lalu buktikan dia bertahan" butuh penulis ke `data.weapons[id].path`, dan sejak upgrade pindah ke dalam match tidak ada satu pun jalur yang menulis ke situ (PROG-25). Yang tersisa di sini migrasinya, dan itu tetap berharga: dia yang menjaga save lama tidak pulang rusak | M5 | PUB | - |

## 18. HUD, layar hasil, dan tutorial (HUD)

Baris di bawah mengunci hal kecil yang paling sering ketinggalan saat mengerjakan
milestone lain, dan ikut jadi bahan alpha test.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| HUD-01 | Match berjalan | Perhatikan HUD atas selama satu wave penuh | "Wave N / 10", teks state, angka cash, dan bar "Core x / 1000" semuanya terlihat dan terupdate. Angka cash itu **milik pemain yang melihat layar itu** — di 4 client isinya empat angka yang berbeda (MP-15). Labelnya masih berbunyi "N cash tim" dan kata "tim" itu **salah sejak cash jadi per pemain**: teks yang belum menyusul, bukan angka yang salah ([bagian 5.4](#54-teks-yang-belum-menyusul-perubahan)). Teks state: `Di lobby`, **`Pilih senjata · Ns`**, `Match mulai dalam · Ns`, `Bertahan!`, `Jeda — toko buka · Ns`, `Match selesai` — enam teks untuk enam state, dari `HudController.STATE_TEXT`. State yang tidak punya teksnya di tabel itu ditampilkan **apa adanya** sebagai nama state Inggris (`Loadout`), jadi "Loadout · 20s" di HUD berarti labelnya yang hilang, bukan state-nya yang salah. Tidak ada nilai yang nyangkut di angka lama — HUD tidak menghitung apa pun sendiri, semuanya dari payload server | M2 | solo | - |
| HUD-02 | Match berakhir — dites dua kali, menang dan kalah | Lihat layar hasil | Judul "Core Server aman!" (hijau) atau "Core Server jebol" (merah), lalu "Wave tercapai: N", "Koin: +N", "XP: +N", baris "Material: ..." kalau ada, baris "Terbuka: ..." kalau ada, lalu "Kembali ke lobby sebentar lagi...". Payload-nya `MatchResult` dari bagian 3.6, dan angkanya harus sama dengan print `[RewardService]` di Output server. Layar hasil yang menampilkan +0 sementara print server benar berarti temuan T1 kembali | M2 | solo | - |
| HUD-03 | State `Lobby` setelah satu match | Buka panel lobby | Header "Level N · M koin" dan baris senjata menampilkan damage dasar dan jumlah alur **terkini**, bukan angka sebelum match. Baris senjata **tidak** memuat level: upgrade hidup di dalam match dan dimulai ulang tiap match, jadi "Level N/10" di lobby akan selalu berbunyi "Level 1/10" selamanya — angka yang tidak pernah bergerak, yang terbaca sebagai progres yang rusak ([bagian 4.2](#42-angka-patokan)) | M5 | solo | - |
| HUD-04 | Match berjalan tanpa boss, lalu wave dengan boss | Perhatikan panel di bawah HUD utama | Panel bar HP boss **tidak terlihat** selama tidak ada boss hidup, dan muncul begitu `BossState` melaporkan boss hidup. Hilang lagi setelah boss mati | M4 | solo | - |
| HUD-05 | Player baru (`stats.matchesPlayed` = 0) | Mainkan satu match dari lobby sampai selesai | Panel **PANDUAN** muncul di bawah layar, satu langkah per momen baru, masing-masing **sekali saja** per sesi: di lobby, **saat fase memilih senjata**, saat hitung mundur, saat wave 1, saat wave 2, saat jeda pertama, saat boss pertama muncul, dan saat match selesai — delapan langkah, satu per state atau momen. Langkah `Loadout` berbunyi "20 detik memilih senjata. Setelah fase ini loadout terkunci sampai match selesai, jadi pilih sekarang." dan itu cocok dengan MATCH-17. **Tiga langkah lain sekarang SALAH dan sudah diketahui** ([bagian 5.4](#54-teks-yang-belum-menyusul-perubahan)): langkah lobby menyuruh pemain mengupgrade di panel kiri "cuma bisa di sini", langkah jeda menyebut cash "milik tim", dan langkah akhir menyuruh memakai koin "di lobby untuk upgrade senjata" — ketiganya menjanjikan mekanik yang sudah pindah atau sudah tidak ada. Yang benar: upgrade cuma bisa **di dalam match, tiap jeda wave**, dan cash milik masing-masing pemain. Baris ini `GAGAL` di bagian teks sampai ketiganya diperbarui — panduan yang menyuruh pemain menekan tombol yang tidak mengirim apa pun lebih buruk daripada tidak ada panduan. Tiap panel hilang sendiri setelah 12 detik, dan panduan jeda **tidak** muncul sembilan kali dalam satu match | M5 | solo | - |
| HUD-06 | Satu match sudah diselesaikan (`matchesPlayed` ≥ 1) | Kembali ke lobby dan mulai match kedua | Panduan **tidak muncul lagi**. Di Studio tanpa DataStore, `matchesPlayed` ada di memori saja, jadi restart playtest akan membuat panduannya muncul lagi — itu benar, bukan bug | M5 | solo | - |
| HUD-07 | **TIDAK BISA DIJALANKAN: upgrade senjata tidak ada lagi di lobby.** `ProgressionService.start()` tidak menyambung remote `UpgradeWeapon` ke apa pun — handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` ([bagian 4.1](#41-remote-yang-benar-benar-terdaftar)) — dan yang memegang remote itu sekarang `ShopService`, yang menolak dari `Lobby` dengan "Kamu bukan peserta match ini." Tombol upgrade di panel lobby juga sudah tidak mengirim apa pun. `BLOK`, bukan GAGAL: `ProgressionRules`, `Balance.upgradePrice`, dan handler lobbynya masih utuh dan unit test-nya masih lulus. Syarat menjalankannya lagi: satu baris di `ProgressionService.start()` yang menyambungkan `UpgradeWeapon` ke `upgradeFromLobby` — **dan baca dulu alasan pencabutannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match), karena menyambungnya kembali berarti dua handler untuk satu remote.** Yang menguji aturan yang sama di tempatnya yang sekarang: SHOP-26 (harga dan potongan cash), SHOP-27 (cash kurang), SHOP-28 (tiga kartu alur di level 4), SHOP-29 (alur tidak bisa diganti), SHOP-30 (level kembali 1 tiap match), dan SHOP-31 (state dan argumen salah). Prakondisi aslinya: State `Lobby`, koin kurang dari harga upgrade, senjatanya di level 1 atau 2 — bukan level 3, yang dibalas pesan soal pilihan alur alih-alih soal koin (PROG-09) | Panggil `R.UpgradeWeapon:FireServer("weapon_starter")` dari command bar client | Alasan penolakan muncul di **baris petunjuk** di bawah panel lobby, warna merah, lalu kembali ke teks biasa setelah ~4 detik. Pembelian yang berhasil menampilkan "Berhasil." warna hijau. Tanpa ini, penolakan server terlihat sama seperti tombol yang rusak | M5 | solo | BLOK |
| HUD-08 | Kartu info boss sedang terbuka, lalu boss kedua dikalahkan sebelum kartu pertama hilang | Amati kartu | Kartu kedua menggantikan yang pertama dan **tidak** ikut tertutup oleh timer kartu pertama. Tombol **Tutup** menutupnya langsung | M4 | solo+EDIT | - |

## 19. Pemetaan ke kriteria "Selesai kalau"

Tabel ini yang dipakai sebagai **gerbang milestone**: sebuah milestone boleh
dicentang kalau seluruh test case di kolom kanan hijau. Kriteria diambil kata per
kata dari DEVELOPMENT_PLAN.md bagian 4.

Kolom **Tertunda** menyebut baris mana di kriteria itu yang **tidak bisa
dijalankan sekarang**, dan kenapa. Sebuah milestone dengan baris tertunda belum
bisa dicentang — tapi dia juga tidak sedang gagal.

| Milestone | Kriteria "Selesai kalau" | Test case | Tertunda |
|---|---|---|---|
| M0 | CI hijau, test Lune jalan | Di luar dokumen ini — lihat [bagian 3](#3-yang-sudah-terverifikasi-di-luar-dokumen-ini) | — |
| M0 | Dua player baru yang di-load berbarengan punya tabel `weapons` yang **berbeda** | DATA-01, DATA-10, DATA-11, BOOT-01 | DATA-02 (`PUB`) menambah bukti migrasi skema, tapi bukan syarat kriteria ini |
| M1 | Solo playtest bisa membunuh musuh | COMBAT-01, COMBAT-02, COMBAT-03, COMBAT-04, COMBAT-10, COMBAT-13, COMBAT-15, COMBAT-16, COMBAT-17, WAVE-03, WAVE-07, WAVE-11, WAVE-12, WAVE-13, WAVE-15, WAVE-17, WAVE-18, WAVE-19, BOOT-02, BOOT-06 | — |
| M1 | Core yang HP-nya habis memicu kalah | CORE-01, CORE-02, CORE-03, CORE-04, CORE-06, BOOT-03 | — |
| M1 | Serangan terasa kena saat dites dengan ping tinggi (Network simulation) | COMBAT-05 | — |
| M2 | Satu match penuh bisa dimainkan dari lobby sampai hasil | MATCH-01 sampai MATCH-09, MATCH-11, MATCH-12, MATCH-13, MATCH-15, MATCH-16, MATCH-17, MATCH-20, MATCH-21, WAVE-01, WAVE-02, WAVE-04, WAVE-05, WAVE-14, WAVE-16, WAVE-20, COMBAT-11, HUD-01, HUD-02 | MATCH-16 berkode `LIVE`. MATCH-17, MATCH-20, dan MATCH-21 menutup fase `Loadout`, yang **tidak** punya kriteria "Selesai kalau" sendiri — dia datang dari `ARENA_REDESIGN.md` bagian 2 dan dipetakan ke sini karena dia bagian dari jalur "dari lobby sampai hasil" |
| M2 | Bisa diulang tanpa restart server | MATCH-10, MATCH-14, SHOP-12 | — |
| M2 | Scaling jumlah dan HP musuh per player; batas musuh aktif + antrian | WAVE-06, WAVE-08, WAVE-10 | Semuanya butuh `2P`/`4P` |
| M3 | Beli item mengubah gameplay di wave berikutnya | SHOP-01 sampai SHOP-06, SHOP-14, SHOP-20, SHOP-21, CORE-05, COMBAT-14 | **Kriteria ini tidak bisa dicentang:** kelima item dimatikan di server (`Config.MATCH_SHOP_ITEMS_ENABLED = false`), jadi sepuluh dari sebelas barisnya `BLOK` — yang tersisa cuma SHOP-14 (panel muncul di state yang benar) dan COMBAT-14. Yang menggantikan isinya di game yang sekarang: **upgrade senjata mengubah gameplay di wave berikutnya**, SHOP-25 sampai SHOP-30. Syarat mengembalikannya satu baris di `Config.luau` |
| M3 | Tidak bisa beli di luar jeda atau dengan cash kurang (dicoba lewat remote manual) | SHOP-07, SHOP-08, SHOP-09, SHOP-12, SHOP-22, SHOP-27, SHOP-31, SEC-04, SEC-05 | SHOP-13 (`LIVE`) menutup kasus bukan-peserta. SHOP-09, SHOP-12, dan SHOP-22 `BLOK` bersama item tokonya; yang membuktikan gerbangnya hari ini SHOP-27 (cash kurang) dan SHOP-31 (state salah, senjata salah, alur karangan) — keduanya lewat `UpgradeWeapon`, pintu belanja yang masih hidup |
| M3 | Cash match, reset tiap match | MP-04, MP-15, SHOP-17, SHOP-18, SHOP-19, SHOP-23, SHOP-24, SHOP-30 | **Kriterianya sendiri bergeser:** DEVELOPMENT_PLAN menulis "koin match per tim", dan cash sekarang **per pemain** ([bagian 4.2](#42-angka-patokan)) — jadi yang diuji bukan lagi "satu angka yang sama di semua layar" tapi kebalikannya. Alasannya di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match). MP-04, MP-15, SHOP-23, dan SHOP-24 butuh `2P`/`4P`. SHOP-30 menutup bagian "reset tiap match", yang sekarang ikut membuang level dan alur senjata. SHOP-12 yang dulu menutup bagian itu `BLOK` bersama item tokonya |
| M4 | Kedua boss bisa dikalahkan dengan mekaniknya berjalan | BOSS-01, BOSS-02, BOSS-03, BOSS-05 sampai BOSS-09, BOSS-12, BOSS-14, SHOP-10, SHOP-11, SHOP-15, SHOP-16, HUD-04, HUD-08 | **SHOP-16 `BLOK`**: mekanik sandera Locker menyandera upgrade tim dari kelima item toko, dan tanpa item tidak ada yang bisa disandera — mekanik andalan boss wave 10 jadi hampa sampai dia diarahkan ke sesuatu yang lain (T19, dan kotak di awal [bagian 12](#12-boss-boss)). SHOP-11 dan SHOP-15 bergeser ke `UpgradeWeapon`; SHOP-10 — kunci tokonya — **masih benar-benar menolak sesuatu** dan jadi satu-satunya bagian mekanik itu yang bisa dibuktikan |
| M4 | Material tercatat di data player setelah match | BOSS-04, BOSS-09, BOSS-10 | BOSS-04 butuh `2P`; BOSS-13 (`LIVE`) menutup kasus peserta yang disconnect; persistensi sesungguhnya butuh `PUB` |
| M5 | Player baru bisa main | PROG-16, HUD-05, HUD-06, BOOT-04, BOOT-05 | — |
| M5 | Dapat reward | PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, HUD-03 | — |
| M5 | Upgrade senjata | SHOP-25 sampai SHOP-32, COMBAT-12, PROG-27, PROG-28 | **Pindah tempat, bukan hilang.** Upgrade senjata tidak ada lagi di lobby: dia dibeli dengan cash di dalam match, dan sepuluh baris PROG yang dulu menutup kriteria ini (PROG-08, PROG-09, PROG-19 sampai PROG-26) berstatus `BLOK` dengan syarat menjalankannya ditulis di tiap barisnya. Yang menutupnya sekarang SHOP-25 sampai SHOP-32 untuk **aturannya** (harga, potongan cash, tiga kartu alur di level 4, alur yang tidak bisa diganti dalam satu match, level yang kembali 1 di match berikutnya, state dan argumen yang salah), dan COMBAT-12, PROG-27, PROG-28 untuk **isinya**, yaitu bahwa tingkat alur yang terpilih benar-benar menggeser stat. Yang **hilang** dari cakupan: persistensi pilihan alur — tidak ada lagi yang disimpan, jadi tidak ada lagi yang bisa dibuktikan bertahan |
| M5 | Enam efek alur upgrade jalan di arena (slow, zona, tanda, splash, kerucut lebar, pengurangan damage masuk) | COMBAT-18, COMBAT-19, COMBAT-20, COMBAT-21, COMBAT-22, COMBAT-23, COMBAT-24, COMBAT-25 | Isi efek per alur datang dari `ARENA_REDESIGN.md` **lampiran A** — yang sampai langkah 7 mendarat memang berjudul "belum diputuskan", jadi DEVELOPMENT_PLAN tidak pernah menuliskan kriteria untuknya. Kelompok ini **tidak punya kriteria "Selesai kalau" sendiri** sama sekali, dan dipetakan ke M5 karena keenam efeknya cuma bisa dicapai lewat upgrade senjata ke level 4, 7, atau 10 di alur tertentu. Pola yang sama dengan hadiah cash per wave (M3) dan pohon alur (baris di atas). COMBAT-25 sudah **`OK`** lewat harness Studio. COMBAT-22 butuh `2P` dan itu memang intinya: tanda yang menaikkan damage pemain **lain** tidak bisa dibuktikan solo. Enam sisanya `solo+EDIT`, dan **jalan pintasnya berubah**: `Config.DEFAULT_DATA.weapons` tidak lagi menentukan level dan alur yang berlaku di arena, jadi yang dipakai sekarang `MatchUpgradeRules.freshSave()` atau membeli upgrade-nya dengan cash di dalam match (kotak [bagian 13](#13-progres-permanen-dan-data-player-prog) dan **harus dibalikkan sebelum commit**. Yang **tidak** bisa dipendekkan oleh harness: splash, kerucut lebar, penularan tanda, dan pengurangan damage masuk — tiga yang pertama masuk lewat `CombatService.onAttack` yang menuntut Player, yang terakhir butuh Humanoid untuk diukur. Itu lima SKIP `path_effects` di [bagian 3.2](#32-cakupan-harness-studio). Slow, zona, dan tanda sudah **sebagian** dibuktikan harness, dan bagian mana persisnya ada di tabel di bagian itu |
| M5 | Craft senjata boss | PROG-12, PROG-13, PROG-18, COMBAT-09 | **PROG-12, PROG-13, dan PROG-18 `BLOK`** selama ketiga senjata terbuka sejak awal ([bagian 4.2](#42-angka-patokan)): Fork Bomb sudah dimiliki, jadi tidak ada tombol Craft dan `canCraft` berhenti di "sudah kamu miliki." Kriteria ini **tidak bisa dicentang** sampai `Config.DEFAULT_DATA.weapons` dikembalikan jadi `weapon_starter` saja. Yang tersisa hijau cuma COMBAT-09, dan dia menguji senjatanya **dipakai**, bukan didapat |
| M5 | Membuka Hard | PROG-06, PROG-07, WAVE-09, MATCH-19 | MATCH-19 memakai `hard` sebagai alat ukur, bukan sebagai yang diuji: dia kasus regresi untuk `lockDifficulty()` yang dipindah ke akhir fase `Loadout` |
| M5 | Keluar, join lagi, dan semua progres masih ada | PROG-14, PROG-15, PROG-25, DATA-03, DATA-06a, DATA-12, DATA-13 | **Seluruhnya `PUB`** kecuali DATA-12 — kriteria ini tidak bisa dites sama sekali sampai place-nya di-publish sekali. **PROG-25 `BLOK` dan separuh DATA-13 ikut gugur**: `data.weapons[id].path` tidak punya penulis lagi sejak upgrade pindah ke dalam match, jadi "pilihan alur bertahan melewati rejoin" bukan lagi sesuatu yang bisa diuji — yang tersisa di DATA-13 migrasinya, yang tetap menjaga save lama tidak pulang rusak; DATA-12 bisa dijalankan sekarang karena `DataSchema.migrate` ikut jalan di jalur tanpa DataStore, tapi yang dia buktikan cuma migrasinya, bukan persistensinya |
| M5 | Senjata `weapon_ranged` dan `weapon_boss_a` jalan di CombatService | PROG-10, COMBAT-06, COMBAT-07, COMBAT-08, COMBAT-09, MATCH-18, MATCH-22, MATCH-23 | COMBAT-06 butuh `LAG`. **PROG-10, MATCH-22, dan MATCH-23 `BLOK`** selama ketiga senjata terbuka sejak awal ([bagian 4.2](#42-angka-patokan)) — ketiganya menguji keadaan "belum dimiliki" atau "dimiliki cuma menurut flag", dan dua-duanya tidak bisa dicapai lagi. Yang **tidak** ikut terhalang justru inti kriterianya: COMBAT-06 sampai COMBAT-09 dan MATCH-18 mengukur senjata yang terpilih benar-benar sampai ke perhitungan damage, bukan cuma ke teks tombol, dan kelimanya sekarang bisa dijalankan **tanpa edit apa pun** karena senjatanya sudah di tangan sejak join pertama |
| M6 | Playtest 4 player lewat Studio (Test → Clients and Servers) lancar | MP-01, MP-02, MP-03, MP-04, MP-05, MP-12, MP-13, MP-14, BOSS-04, BOSS-11, WAVE-06, WAVE-08, WAVE-10, DATA-01 | Semuanya butuh `2P`/`4P`, dan itu memang isi kriterianya. MATCH-16 (pemain join saat `Loadout` atau `Countdown`) berkode `LIVE` karena Studio tidak bisa menambah pemain di tengah sesi |
| M6 | Rejoin di tengah match berhasil | MP-06, MP-07, MP-08, MP-09, MP-10, MP-11, DATA-04, DATA-05, DATA-07, DATA-08 | MP-09 dan MP-10 bisa dites sekarang dengan `2P`. **Sisanya `LIVE`** — Studio tidak bisa mensimulasikan join ulang dengan UserId yang sama |
| M6 | Leaderboard (`LeaderboardService` + papan di lobby) | LB-00 sampai LB-05, SEC-08 | **LB-01 sampai LB-05 berkode `PUB`** — OrderedDataStore ditolak di place yang belum pernah di-publish, jadi kriteria ini tidak bisa ditutup sampai langkah publish dilakukan, persis seperti baris M5 "keluar, join lagi". Yang berubah: halangannya bukan lagi kode yang belum ada. LB-00 dan SEC-08 bisa dijalankan sekarang (`solo`), dan separuh LB-00 sudah dipatok harness Studio |
| M6 | Rate limit di semua remote | SEC-14, SEC-01 sampai SEC-07, SEC-11 | — |
| M6 | Tidak ada error di output server | MP-03, MP-12, SEC-01 sampai SEC-14, DATA-09a, DATA-09b, BOOT-01 | DATA-09b (`LIVE`). SEC-08 tidak lagi tertunda: remote-nya ada, dan jalur tanpa OrderedDataStore memang salah satu yang harus dibuktikan bersih |
| M7 | Tidak ada bug blocker dari alpha | Seluruh dokumen ini diisi sekali lagi dari atas ke bawah, kolom Status dikosongkan dulu | Baris `BELUM` dan `PUB` harus sudah hilang pada titik ini |
| M8 | Publish versi `Saved`, cek di server live | Seluruh baris `LIVE` dijalankan di server live: MATCH-16, MP-06, MP-07, MP-08, MP-11, BOSS-13, SHOP-13, DATA-04, DATA-06b, DATA-09b | — |

Kalau nanti ada kriteria yang berubah di DEVELOPMENT_PLAN.md, **tabel ini yang
pertama harus ikut diperbarui** — dia satu-satunya tempat yang menjamin tidak ada
kriteria yang kehilangan test case-nya.

## 20. Keputusan yang diambil tanpa menanyakan dulu

Bagian ini bukan test case. Isinya keputusan implementasi yang **tidak disebut
rencana development** dan yang jawabannya mengubah arah, jadi dipilih yang paling
konservatif lalu dicatat. Dipindahkan dari `docs/STUDIO_CHECKLIST.md` apa adanya
karena tidak ada tempat lain yang menyimpannya — dan karena beberapa test case di
atas langsung mengacu ke sini saat hasilnya terasa aneh tapi sebenarnya benar.

### 20.1 Keputusan lintas milestone

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Mapping `assets/` di `default.project.json` saat filenya belum ada | Mapping **ditambahkan sekarang**, memakai `"$path": { "optional": "..." }` | Diuji empiris: `"$path": "assets/Arena.rbxmx"` biasa membuat `rojo build` **gagal keras** ("could not be turned into a Roblox Instance") dan CI jadi merah. Bentuk `optional` membuat rojo melewatkan path yang tidak ada tanpa error, lalu otomatis memakainya begitu filenya muncul. Jadi mapping-nya tidak perlu ditunda sampai assetnya ada. |
| Tabrakan fisik musuh | `CanCollide = false` | Musuh adalah Part **anchored** yang digerakkan lewat `CFrame`. Part anchored yang bertabrakan dengan karakter akan mendorong pemain ke dalam geometry atau menahan musuh di tempat. Uji kena serangan tidak memakai tabrakan sama sekali (bagian 3.7), jadi tidak ada yang hilang. |
| Tiga remote tambahan di luar tabel bagian 3.6 | `BossState`, `ShopState`, `ActionResult` ditambahkan | Milestone-nya memintanya tapi tabel 3.6 tidak menyediakan jalurnya: HP bar boss (M4) tidak punya tempat di payload `MatchState` yang sudah dipatok, pembukuan pembelian per item (M3) tidak boleh ditebak client — dulu untuk sisa jatah, sekarang juga untuk menghitung harga sekarang di tombol — dan penolakan server tanpa jalur balasan membuat pemain mengira tombolnya rusak. Ketiganya **penambahan**, bukan penggantian nama, jadi tidak ada yang bergeser dari tabel 3.6. Alasan lengkapnya ada di komentar `src/shared/Remotes.luau`. |
| `GetLeaderboard` dari tabel bagian 3.6 | **Didaftarkan bersama handler-nya, dalam satu langkah** — sampai M6 bagian leaderboard dikerjakan, namanya sengaja tidak ada di `FUNCTION_NAMES` | `RemoteFunction` yang sudah ada di `ReplicatedStorage` tapi belum punya `OnServerInvoke` membuat client yang memanggilnya **menggantung selamanya**: tanpa error, tanpa timeout, dan tanpa apa pun di Output yang menunjuk ke penyebabnya. Jadi nama di tabel remote tidak boleh mendahului service yang memasang handler-nya, dan urutan itu berlaku untuk setiap `RemoteFunction` berikutnya. Dijaga `boot.remote.getLeaderboardAda` dan `boot.remote.getLeaderboardRemoteFunction`; dites LB-00 dan SEC-08. |

### 20.2 Keputusan M2

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Cash peserta yang disconnect | **DIGANTI di [bagian 20.8](#208-keputusan-toko-upgrade-dalam-match):** cash sekarang per pemain, dan yang menjaganya tidak hangus pembukuan per UserId yang tidak dihapus saat pemain keluar. Yang dipilih dulu: tidak bisa hangus, karena **cash disimpan sebagai satu kolam milik TIM**, bukan per pemain | Rencana development menyarankan "disimpan, jangan hangus". Kolam tim menyelesaikan itu tanpa kode tambahan: tidak ada saldo per pemain yang bisa hilang saat dia disconnect, dan saat rejoin dia langsung melihat saldo tim yang sama. Ini juga yang diminta M3 ("koin match per TIM") dan bagian 3.7 ("tambah koin match ke tim"). |
| Semua peserta keluar di tengah match | Match **dibatalkan**, state kembali ke `Lobby`, dan `onMatchEnded` **tidak** ditembakkan | Rencana development menyebut konsekuensi kalau tidak dibatalkan: server nyangkut di `WaveActive` tanpa pemain. Pembatalan sengaja bukan kekalahan — kalau `onMatchEnded` ditembakkan, RewardService akan menghitung reward untuk peserta yang sudah tidak ada di server, padahal reward mereka sudah dibayar satu per satu saat masing-masing keluar (bagian 3.3). |
| Dua pemain memilih kesulitan berbeda | Ambil yang **paling mudah** di antara pilihan mereka | Tidak disebut rencana development. `hard` harus dibuka dulu per pemain (bagian 3.1), jadi aturan apa pun yang mengambil yang lebih sulit bisa memaksa pemain ikut match pada tingkat yang belum dia buka. Mengambil yang termudah tidak pernah bisa melakukan itu. Diukur dari `hpMult`, bukan urutan tabel, supaya menambah tingkat baru nanti tidak perlu menyentuh fungsinya. Dites MP-13. |
| Pemain baru join saat fase pra-match (`Loadout` atau `Countdown`) | Fase itu **dibatalkan**, kembali ke Lobby — berlaku untuk **dua-duanya**, bukan cuma hitung mundur | Syarat masuk Countdown di bagian 3.3 adalah "semua player di server menekan Ready". Pemain yang baru join otomatis belum Ready, jadi syaratnya tidak lagi terpenuhi. Memeriksa syarat itu terus-menerus (bukan sekali saat masuk) adalah tafsir paling lurus dari aturannya, dan mencegah match dimulai dengan pemain yang tidak pernah menyatakan siap. Sejak fase `Loadout` ada, syarat yang sama diperiksa tiap tick di **kedua** cabang pra-match: kalau cuma `Countdown` yang memeriksanya, 20 detik pertama jadi jendela tempat pemain baru bisa masuk tanpa membatalkan apa pun, dan match dimulai dengan pemain yang tidak pernah Ready — jendela yang dua kali lebih lebar dari yang ditutup. Dites MATCH-15 dan MATCH-16. |
| Tombol Ready ditaruh di mana | `LobbyController`, versi minimal saat M2 | Rencana development menaruh tombol Ready di `LobbyController`, yang milestone-nya M5. Tapi tanpa tombol itu tidak ada cara memulai match dan kriteria M2 tidak bisa diverifikasi sama sekali. Jadi file-nya dibuat lebih awal dengan isi minimal, dan panel senjata/kesulitan/upgrade/craft menempel ke panel yang sama di M5. |
| Satu loop timer atau satu task per state | **Satu loop**, dijalankan tiap 0.2 detik | State machine yang tiap transisinya memulai `task.delay` sendiri akan punya beberapa timer hidup bersamaan setelah satu transisi dibatalkan, dan yang lama tetap menyala. Konsekuensi yang terlihat di test: timer di HUD bergerak dalam langkah 0.2 detik, bukan mulus per frame (MATCH-11). |

### 20.3 Keputusan M3

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Efek `shop_damage_up` dan `shop_fire_rate`: per pemain atau per tim | **Per tim** | M3 menyebut "upgrade damage tim". Selain itu cash adalah satu kolam milik tim, jadi efek per-pembeli membuat pemain pertama yang menekan tombol memakai uang bersama untuk keuntungan pribadi. Deskripsi item di `ShopItems.luau` ikut diubah supaya tidak lagi berbunyi "senjatamu". |
| Penghalang dipasang di lane mana | **Semua lane**, dan beberapa pembelian menumpuk **durasinya** | Tabel bagian 3.6 memaku payload `BuyShopItem` jadi `itemId` saja, tanpa argumen lane. Menambah argumen berarti menyimpang dari tabel yang milestone berikutnya ikut pakai, dan menebak lane mana yang dimaksud pemain lebih buruk daripada efek yang jelas dan bisa diprediksi. Durasi yang menumpuk dipilih karena dua penghalang di lane yang sama pada waktu yang sama tidak menahan musuh dua kali lebih kuat. Dites SHOP-05. Dulu dinding visualnya hilang lebih cepat daripada blokirnya (temuan T5); sudah disamakan. |
| Penghalang berlaku kapan | **Wave berikutnya**, bukan saat dibeli | Toko cuma buka saat `Intermission`, dan saat itu tidak ada musuh yang bergerak. Dipasang langsung berarti 6 detiknya habis sebelum ada yang perlu ditahan. |
| Posisi turret | Ditentukan **server**, mengelilingi Core, sudutnya dari nomor pembelian | Alasan yang sama dengan penghalang: payload-nya cuma `itemId`. Sudut dari nomor pembelian memastikan turret kedua tidak muncul menumpuk di atas yang pertama. |
| Pengali efek: linear atau berlipat | **Linear** (5 x +10% = 1.5x, bukan 1.61x), dengan lantai cooldown 0.4 | Harga item tetap, jadi efek yang berlipat akan meledak di pembelian terakhir. Linear juga bisa dihitung sendiri oleh pemain. Lantainya ada supaya menaikkan step nanti tidak bisa membuat cooldown senjata hilang sama sekali. |
| Siapa yang boleh membeli | Hanya pemain yang ada di `participants` | Tidak disebut bagian 3.6, tapi mengikuti aturan yang sama dengan `Attack`: pemain yang ditahan di lobby bukan bagian dari match yang sedang berjalan (bagian 3.3), jadi dia tidak boleh membelanjakan cash tim. Dites SHOP-08 dan SHOP-13. |
| Panel toko disembunyikan atau ditandai saat terkunci | **Ditandai**, bukan disembunyikan | Kalau disembunyikan, pemain tidak tahu bedanya "belum waktunya" dan "dikunci Locker", padahal yang kedua adalah mekanik yang harus dia sadari. Keputusannya benar, tapi kesempatan melihatnya dulu tidak pernah ada: panel cuma muncul saat `Intermission` dan toko cuma terkunci saat `WaveActive` (temuan T2). Panel sekarang ikut muncul saat `ShopState.locked`, jadi kuncinya memang terlihat. |
| Mekanik Locker: melarang membeli atau menyandera yang sudah dibeli | **Menyandera yang sudah dibeli** (`ShopState.suspended`), dan kunci tokonya dipertahankan sebagai penanda. **Sejak item toko dimatikan, yang disandera tidak ada**: `purchases` selalu kosong, jadi mekanik ini hampa dan yang masih menolak sesuatu justru kunci toko yang dulu dianggap cuma penanda (T19, dan kotak di awal [bagian 12](#12-boss-boss)) | Melarang membeli tidak menolak apa pun. Toko cuma buka saat `Intermission`, Locker cuma hidup saat `WaveActive`, dan wave 10 adalah wave terakhir v1 sehingga tidak ada `Intermission` sesudahnya — jadi kuncinya selalu benar secara hampa, dan muatan edukasi boss ini tidak pernah sampai ke pemain. Ransomware juga tidak melarang korban berbelanja; dia menyandera yang sudah dimiliki korban. Jadi selama Locker hidup, pengali damage dan attack speed kembali ke dasar sementara `purchases` tetap utuh — dites di SHOP-16, kebocoran antar match-nya di SHOP-15. Kuncinya tetap dipasang karena membuat pesan penolakan benar saat pemain mengklik panel yang terlihat. |

### 20.4 Keputusan M4

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Jalur HP boss ke client | Remote baru `BossState` | M4 minta "HP bar boss di HUD", dan payload `MatchState` yang sudah dipatok tabel bagian 3.6 tidak punya tempat untuk HP boss. Ini penambahan, bukan penggantian nama, jadi tidak ada yang bergeser dari tabel itu. |
| Material untuk peserta yang sedang disconnect saat boss mati | Dicatat sebagai **tertunda** dan dibayarkan saat dia rejoin | Bagian 3.3 mengizinkan peserta rejoin dan melanjutkan, jadi dropnya tidak boleh hilang hanya karena dia sedang tidak di server pada detik boss mati. Pembukuannya juga dipakai mengisi payload `MatchResult` di M5. Dites BOSS-13. |
| Posisi musuh pecahan Splitter | Dari **posisi boss saat itu**, melanjutkan dari waypoint yang sama | Inti mekaniknya adalah ancaman yang tiba-tiba dekat (Worm yang menyebar), bukan gelombang baru dari jauh. Disebar melingkar 6 stud karena musuh digerakkan lewat CFrame dan tidak bertabrakan satu sama lain — tanpa sebaran mereka menumpuk jadi satu dan pemain cuma melihat satu musuh dengan HP bar bertumpuk. |
| Posisi minion Locker | Dari **awal lane** | Beda dari Splitter dengan sengaja: Locker memanggil payload tambahan dari luar, bukan memecah dirinya sendiri. Bedanya juga membuat dua mekanik itu terasa berbeda saat dimainkan, bukan cuma beda angka. |
| Musuh pecahan saat boss mati | **Dibiarkan hidup** | Wave belum bersih sampai mereka juga habis, dan itu memang bagian dari mekaniknya. Menghapusnya saat boss mati akan membuat ambang 33% tidak ada konsekuensinya kalau pemain langsung membunuh boss sesudahnya. Dites BOSS-12. |
| Boss dibedakan dari apa | `mechanic.kind`, bukan id boss | `Types.BossMechanic` sudah ditulis sebagai tagged union untuk ini. Menambah boss baru yang memakai mekanik yang sama jadi tidak perlu menyentuh `BossService`. |
| Kartu info ditutup bagaimana | Tombol **Tutup** DAN hilang sendiri setelah 18 detik | Kartu muncul tepat setelah boss mati, dan saat itu bisa masih ada musuh pecahan berjalan ke Core. Pemain yang ingin terus bertarung tidak boleh dipaksa membaca dulu, tapi yang ingin membaca juga tidak boleh kehilangan kartunya karena salah klik. Dites HUD-08. |

### 20.5 Keputusan M5

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Mapping `Lobby` di `default.project.json` | **Ditambahkan sekarang** sebagai `"$path": { "optional": "assets/Lobby.rbxmx" }` | Diuji empiris: `"$path": "assets/Lobby.rbxmx"` biasa membuat `rojo build` gagal keras selama filenya belum ada, jadi CI merah — itu sebabnya mapping-nya ditunda. Bentuk `optional` melewatkan path yang tidak ada tanpa error dan otomatis memakainya begitu filenya muncul. Konsekuensinya user tidak perlu menyentuh file proyek setelah men-generate lobby — satu langkah manual yang mudah terlupa jadi hilang. |
| Kurva level | `100 * 1.25^(level-1)` XP per level, maksimum 100 kenaikan per panggilan | Bagian 3.5 memberi rumus XP per match tapi tidak memberi kurva levelnya. Angkanya dipilih supaya match pertama yang kalah di wave 1 (20 XP) tidak langsung naik level, dan sepuluh match penuh yang menang mendarat di level 5 sampai 20 — dites eksplisit. Batas 100 kenaikan ada bukan karena ada yang bisa memberi XP sebanyak itu secara sah, tapi karena satu nilai XP yang rusak (inf, atau angka raksasa dari data korup) akan membuat loopnya berjalan selamanya dan menggantung thread yang memanggilnya; di server itu berarti pemain yang tidak pernah dapat reward tanpa ada yang tahu kenapa. |
| Urutan penyambungan `PlayerRemoving` | `RewardService.start()` dipanggil **sebelum** `PlayerDataService.start()` | Keduanya mendengarkan `Players.PlayerRemoving`, dan PlayerDataService menyimpan lalu MENGHAPUS cache data pemain di situ. Handler Roblox dijalankan dalam urutan penyambungan, jadi kalau PlayerDataService disambung lebih dulu, RewardService tidak punya data lagi untuk dibayar — dan pemain yang keluar di tengah match kehilangan rewardnya, tepat kasus yang diwajibkan bagian 3.3. Dites MP-10. |
| Pembayaran dobel | Pembukuan `paid` per UserId, direset saat **Countdown**, bukan saat match selesai | Pemain yang keluar di wave 7 sudah dibayar. Kalau pembukuannya dihapus saat `Ended`, dia bisa ikut dibayar lagi di akhir match yang sama kalau sempat rejoin — jadi keluar-lalu-rejoin menggandakan reward. Dites DATA-04. |
| Material boss di layar hasil | Dibaca dari pembukuan BossService, **tidak** ditambahkan lagi | BossService sudah membayarkan materialnya saat boss mati (M4). Menambahkannya lagi di RewardService berarti satu boss memberi dua kali. |
| Tutorial | **Teks panduan saja, tanpa wave latihan**, dan seluruhnya di client | M5 mengizinkan "bisa berupa wave latihan dengan teks panduan" — jadi teks saja sudah memenuhi. Wave latihan butuh state keenam di MatchService, dan bagian 3.3 eksplisit bahwa service lain tidak boleh menambah atau mengubah state: menambah state demi tutorial menyentuh bagian paling rapuh dari seluruh sistem untuk keuntungan yang bisa didapat dengan teks. Dibuat di client karena semua yang diperlukan sudah ada di sana (`MatchState` memberi state dan wave, data pemain memberi `stats.matchesPlayed`), jadi tutorialnya tidak menambah satu remote pun. Dites HUD-05. |
| "Pemain baru" diukur dari apa | `stats.matchesPlayed < 1` | Satu-satunya penanda yang sudah ada di skema bagian 3.1 dan yang artinya tidak ambigu. Menambah field `tutorialDone` berarti menambah field skema untuk sesuatu yang bisa disimpulkan. Dites HUD-06. |
| ReadyPad: tombol atau penanda | **Penanda posisi**; tombol Ready yang sesungguhnya ada di UI | Bagian 3.4 cuma menyebut "Part untuk tanda siap". Tombol UI bisa dipakai di mobile (CONCEPT.md menargetkan mobile) dan tidak bergantung pada pemain berhasil menginjak satu Part. ReadyPad tetap dibuat dan tetap dibaca MapService supaya kontrak bagian 3.4 utuh. Dites MATCH-02. |
| Posisi lobby | Z = 400, 280 stud di belakang tepi arena | Lobby dan arena ada di satu place (bagian 1.1), jadi pemain yang ditahan di lobby harus dipisahkan dengan **jarak**, bukan dengan kode. Pada jarak itu pemain di lobby tidak bisa melihat atau menjangkau musuh di arena. Dites BOOT-05 dan MP-07. |

### 20.6 Keputusan rancangan ulang arena

Baris di bawah datang dari `docs/ARENA_REDESIGN.md` bagian 2, 3, 4, 5, dan 6
beserta lampiran A, bukan dari DEVELOPMENT_PLAN.md — jadi tidak ada kriteria
"Selesai kalau" yang memaksanya, dan semuanya pilihan. Empat akar perubahannya
terpisah. Yang pertama dan paling mengubah rasa main: musuh yang lolos **tidak
hilang lagi**, dan dari situ lahir sembilan baris pertama tabel ini. Yang kedua
menyangkut uang: **tiap wave yang selesai memberi hadiah cash tim**, dan hadiah
sebesar itu memaksa batas jumlah pembelian di Toko Match diganti harga yang
naik — empat baris berikutnya, ditambah satu baris tentang nama kedua mata
uangnya. Yang ketiga menyangkut pilihan sebelum match: **senjata dipilih di
fase sendiri lalu terkunci**, dan ketiga senjata dibuka sejak awal lewat
`Config.DEFAULT_DATA` — lima baris sesudahnya. Yang keempat menyangkut progres
permanen: **upgrade senjata bercabang tiga di level 4, sekali dan selamanya**,
dan karena pilihannya masuk DataStore, hampir setiap keputusan di tujuh baris
sesudah itu dipilih dengan pertanyaan yang sama — apa yang terjadi pada data
yang sudah tersimpan kalau ini salah.

Lalu langkah 7 mengisi efek tiap tingkat, dan pertanyaannya berganti. Yang masuk
arena bukan lagi angka yang dihitung sekali per serangan tapi **efek yang punya
umur dan bisa bertumpuk**: slow, zona, tanda, dan pengurangan damage masuk.
Pertanyaan yang membentuk **tujuh baris terakhir** jadi "apa yang dilihat pemain
kalau dua efek bertemu" — dan hampir setiap jawabannya dipilih karena alternatif
yang lebih sederhana menghasilkan sesuatu yang pemain akan laporkan sebagai bug
tanpa pernah bisa menunjuk penyebabnya.

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Musuh yang mencapai ujung lane | **Berhenti di base, tetap hidup, memukul berulang** tiap `attackInterval` sampai dibunuh pemain | Sebelumnya dia men-damage Core sekali lalu dihapus sendiri, jadi kebocoran berarti satu kali kehilangan HP dan arena pasti bersih sendiri. Kebocoran yang menetap mengubah "aku kehilangan 5 HP" jadi "aku kehilangan 5 HP per 1.2 detik sampai aku mengurusnya", dan itu yang membuat `tank` akhirnya punya arti — dulu dia cuma 15 dari 1000. Dites WAVE-11, WAVE-17, CORE-02. |
| Satu angka serangan atau dua (ke base dan ke player) | **Satu** `attackDamage`, dikali dua pengali di titik pemakaian: `BASE_DAMAGE_MULT` 0.2 dan `PLAYER_DAMAGE_MULT` 1.0 | Base 1000 HP dan player 100 HP terpaut 50x. Dua angka terpisah per tipe berarti dua tabel balancing yang bisa saling bertentangan tanpa ada yang sadar; satu angka dengan dua pengali berarti satu tempat untuk disetel dan satu rasio untuk diperdebatkan. Angkanya sendiri ditetapkan **dari sisi player** (berapa pukulan sampai mati), lalu dibaca ke sisi base lewat aritmetika kebocoran — kalau dibalik, hasilnya musuh yang mengelupas base 1 HP per detik. Aritmetikanya ada di [bagian 4.2](#42-angka-patokan). |
| Pengali difficulty ikut menaikkan serangan musuh? | **Tidak.** Cuma HP yang dikali `hpMult` | `hard` yang menaikkan damage sekaligus HP menggandakan kesulitannya dua kali di satu pengali, dan pukulan yang membunuh pemain dalam satu hit tidak punya ruang untuk dinaikkan lagi: `tank` sudah 2 pukulan, Locker sudah 1. Yang dinaikkan `hard` adalah berapa lama musuh bertahan, bukan seberapa cepat pemain mati. Dites CORE-02 dan COMBAT-17. |
| Musuh mana yang boleh meninggalkan lane untuk mengejar pemain | **Hanya yang `prefer = "player"`** — di v1 cuma `fast`. Yang lain memukul pemain yang menghalangi dari tempatnya berdiri | Musuh tidak punya collision maupun pathfinding, jadi pengejaran garis lurus bisa menembus dinding atau keluar arena. Membatasi pengejaran ke satu tipe membatasi masalah itu ke satu tipe juga, dan tetap memberi tiga rasa berbeda dari satu bentuk profil yang sama: `tank` tidak peduli pemain, `basic` memukul kalau dihalangi, `fast` memburu. Dites WAVE-18. |
| Musuh yang sudah menempel di base, bisa ditarik keluar lagi? | **Tidak.** `attacking_base` tidak punya jalan keluar selain mati | Kalau mendekat bisa menariknya keluar, pemain bisa menunda kerusakan tanpa membunuh apa pun — dan karena wave baru selesai saat arena bersih, wave-nya bisa digantung selamanya oleh pemain yang cuma berdiri di dekat Core. Dites WAVE-17. |
| Kembali ke lane setelah pengejaran selesai | Ke waypoint terdekat yang ada **di depannya**, bukan yang terdekat secara umum | Kalau boleh mundur, pemain bisa menarik satu musuh maju-mundur tanpa batas dan wave-nya tidak akan pernah berakhir. Dites WAVE-18. |
| Penumpukan musuh di base | **Slot cincin**: 12 posisi per cincin, radius tumbuh per cincin (10, 14, 18, ...), nomor slot **tidak pernah dipakai ulang** | Tanpa collision, 20 musuh yang berhenti di titik yang sama jadi satu gumpalan yang tidak bisa dibidik satu-satu. Nomor slot tidak dipakai ulang supaya slot yang dibebaskan musuh mati tidak langsung diberikan ke musuh lain yang sedang datang — dua musuh bisa berdiri di titik yang sama persis kalau yang pertama mati tepat sebelum yang kedua sampai. Harganya: cincinnya melebar selama match berjalan, dan itu diterima. Radiusnya tumbuh per cincin (10, 14, 18, ...) supaya jumlah cincin tidak terbatas tanpa dua slot pernah berbagi tempat — versi pertama memakai satu radius luar untuk semua cincin dan membuat slot 24 berdiri tepat di posisi slot 12. Dites WAVE-19 dan unit test `EnemyAI`. |
| Wave boleh dinyatakan bersih sementara masih ada musuh di base? | **Tidak**, dan jaminan "arena pasti bersih" memang dibuang — bukan ditambal dengan "musuh di base tidak dihitung" | Efek sampingnya yang justru dicari: Intermission dan Toko Match tertunda selama masih ada kebocoran, sambil base terus kehilangan HP. Kebocoran menghukum dua kali, HP dan waktu belanja, tanpa satu aturan tambahan. Dan ini tidak bisa menggantung permanen — kalau pemain tidak mampu, Core habis dan match berakhir kalah. Konsekuensinya untuk yang playtest: satu wave yang "tidak mau selesai" adalah hal yang benar, dan itu yang paling mudah salah dilaporkan. Dites WAVE-20, dijelaskan di T8. |
| Konsekuensi kematian pemain | **Respawn biasa 5 detik di spawn arena, tanpa sistem nyawa** | Sebelum ini musuh tidak bisa menyentuh pemain sama sekali, jadi `RESPAWN_SECONDS` tidak punya arti. Sistem nyawa menambah state, UI, dan aturan multiplayer ("apa yang terjadi kalau satu pemain habis nyawa") untuk sesuatu yang sudah dihukum cukup oleh waktu: selama pemain tidak ada, musuh di base terus memukul. Angkanya ditulis eksplisit, bukan dibiarkan memakai default Roblox yang kebetulan juga 5 detik, supaya kesulitan game tidak bisa bergeser karena default engine berubah. Dites COMBAT-16. |
| Hadiah per wave masuk mata uang yang mana | **Cash** — kolam milik tim yang habis tiap match, bukan koin permanen per pemain | Pengali jumlah pemain (solo x4) cuma koheren untuk kolam tim, dan itu argumen terkuatnya. Kalau hadiahnya masuk koin permanen, main solo jadi **4x lebih efisien per orang** untuk farming, dan game co-op yang menghukum main bareng akan dimainkan solo oleh semua orang. Kolam cash dibagi tim, jadi x4 solo cuma menormalkan daya beli per orang — tidak memberi solo keuntungan yang dibawa keluar dari match. Dites SHOP-17, yang secara eksplisit memeriksa koin permanen **tidak** ikut naik. |
| Pengali jumlah pemain: kurva atau tangga | **DIHAPUS SELURUHNYA** bersama `Balance.waveReward` dan `Balance.playerCountMultiplier` — hadiah sekarang per pemain, dan anggaran satu pemain tidak lagi bergantung pada berapa orang yang ikut ([bagian 20.8](#208-keputusan-toko-upgrade-dalam-match)). Yang dipilih dulu: **tangga** — 1 pemain x4, 2 pemain x2, 3 atau lebih x1 | Tangga dengan tiga nilai bisa dihitung di kepala dan dibaca dari satu baris Output; kurva (misal `4/playerCount`) memberi 1,33 untuk 3 pemain dan membuat tiap angka hadiah harus dihitung ulang sebelum bisa dinilai. Ambangnya di 3, bukan 4, karena efek Toko Match sudah berlaku untuk seluruh tim: tim berempat mendapat 4x nilai dari tiap cash, jadi tim 3 dan 4 orang sudah berada di sisi yang sama dari pertukaran itu. Jumlah pemain yang tidak masuk akal (nol, negatif, NaN) jatuh ke **x4**, bukan ke nol — hadiah yang terlalu besar langsung terlihat saat playtest, hadiah yang diam-diam hilang tidak. Dites SHOP-23 dan SHOP-24, dan dipatok unit test `Balance`. |
| Hadiah untuk wave terakhir | **Diberikan**, dan urutannya dipatok: hadiah ditembakkan **sebelum** pengecekan wave terakhir | Cabang wave terakhir memanggil `endMatch(true)` lalu `return`, jadi hadiah yang ditaruh sesudahnya tidak akan pernah diberikan untuk wave 10 — dan wave 10 adalah wave boss, jadi yang hilang justru hadiah **terbesar di seluruh match** (5.200 untuk solo). Kegagalannya juga tidak mencetak error apa pun: pemain cuma menang dengan cash yang tidak pernah dia lihat, di detik terakhir sebelum kolamnya di-reset. Urutan itu satu-satunya yang benar, dan itu sebabnya dia punya test sendiri. Dites SHOP-19. |
| Batas jumlah pembelian di Toko Match | **Tidak berlaku selama kelima itemnya dimatikan** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`) — keputusannya tetap benar dan berlaku lagi apa adanya kalau flag itu dinyalakan. Yang dipilih: **dihapus untuk empat item, diganti harga yang naik x1.25 per pembelian item yang sama.** `shop_barrier` tetap dibatasi 5 | Dengan hadiah per wave, solo mengumpulkan sekitar **21.200** cash sepanjang 10 wave, sementara toko yang seluruh itemnya dibatasi cuma bisa menyerap **3.450**: habis diborong di wave 3-4, lalu enam wave sisanya cash-nya tidak ada gunanya. Menurunkan hadiahnya bukan perbaikannya, karena alasan x4-nya valid — yang salah batas jumlahnya. Dengan harga yang naik, 10 tumpuk Exploit Patch memakan 6.647 cash alih-alih 2.000: uang selalu punya tujuan, dan kelebihan pasokan solo terkoreksi lewat harga, bukan lewat tembok yang membuat sisa cash tidak ada gunanya. `shop_barrier` ditinggalkan dari daftar itu karena empat item lain menambah **kemampuan**, yang tetap harus dipakai, sementara dia menambah **waktu musuh tertahan** — 20 tumpuk berarti 120 detik dan wave-nya lewat tanpa pemain menyentuh apa pun, jadi harga yang naik tidak membatasi apa pun yang perlu dibatasi. Konsekuensinya untuk yang playtest: harga di tombol berubah sendiri antar pembelian, dan itu T11. Dites SHOP-20 sampai SHOP-22. |
| Di mana senjata dipilih, dan berapa lama fasenya | **Fase `Loadout` sendiri antara `Lobby` dan `Countdown`, 20 detik** — batas atas rentang 15-20 di rancangan | Sebelumnya `Lobby` satu-satunya tempat memilih dan `Countdown` menyusul langsung, jadi pemilihan senjata tidak punya momennya sendiri: pemain yang menekan Ready sudah selesai memilih, mau tidak mau. Dengan alur upgrade yang permanen (rancangan bagian 3), pilihan itu jadi terlalu besar untuk ditumpangkan ke panel lobby yang juga dipakai upgrade dan belanja. Panjangnya dipilih **20, bukan 15**, karena fase ini harus cukup untuk **empat** pemain membaca tiga baris senjata dan memilih, bukan cuma satu — dan karena biayanya tidak simetris: terlalu panjang berarti menunggu, terlalu pendek berarti pemain masuk match dengan senjata yang bukan pilihannya. Harganya 30 detik dari Ready sampai musuh pertama, tiga kali sebelumnya, dan itu yang paling mudah salah dilaporkan sebagai tombol Ready yang rusak (T13). Dites MATCH-02, MATCH-11, MATCH-17. |
| Sampai kapan loadout terkunci | **Sejak `Countdown` sampai match selesai**, termasuk sepanjang `Intermission` | Alasan aslinya masih berlaku — ganti senjata di tengah wave berarti damage berubah tanpa biaya apa pun — dan alur upgrade yang permanen menambah alasan kedua yang lebih kuat: kalau senjata bisa ditukar tiap jeda, pilihan alur yang tidak bisa dibatalkan itu tidak ada artinya, karena pemain cukup berpindah ke senjata yang alurnya cocok untuk wave berikutnya. `Intermission` yang paling penting ditutup, bukan `Countdown`: itu satu-satunya jeda nyaman di tengah match, jadi satu-satunya tempat pemain punya waktu menukar senjata **setelah** melihat musuh apa yang datang. Daftar state-nya ditaruh di satu tempat (`MatchRules.LOADOUT_STATES`) karena pembacanya dua dan di sisi jaringan yang berbeda: server menolak remote, client mematikan tombol — dua daftar terpisah berarti tombol yang kelihatan bisa diklik tapi selalu ditolak, atau tombol mati di fase yang justru dibuat untuk menekannya. Dites MATCH-03 dan MATCH-21. |
| Kapan tingkat kesulitan dikunci | **Saat meninggalkan `Loadout` menuju `Countdown`**, bukan saat semua pemain Ready | Dulu dikunci saat Ready karena `Countdown` menyusul langsung dan tidak ada apa pun di antaranya. Sekarang ada 20 detik, dan `SelectLoadout` membawa `weaponId` **dan** `difficulty` dalam satu remote — jadi mengunci di awal fase berarti tingkat yang dipilih pemain **di dalam** fase itu diabaikan tanpa pesan apa pun sementara senjatanya diterima. Satu remote, dua argumen, cuma satu yang berlaku: tidak ada cara pemain menebak mana yang. Memindahkan kuncinya ke akhir fase membuat keduanya berlaku atau keduanya tidak. Yang diambil tetap tingkat **paling mudah** di antara pilihan pemain ([20.2](#202-keputusan-m2)), cuma waktunya yang bergeser. Dites MATCH-19, dan lintas pemain di MP-13. |
| Upgrade, beli, dan craft dibuka di `Loadout`? | **Tidak.** Tetap `Lobby` saja (`ProgressionRules.ALLOWED_STATE`), jadi tombolnya mati sepanjang fase itu walau panelnya terlihat | Menggodanya jelas: panelnya sudah terbuka, pemainnya sudah memikirkan senjata, dan membiarkan upgrade di situ cuma soal memperluas satu daftar state. Tapi ketiganya mengubah **data permanen**, dan sejak langkah 6 upgrade memang membawa pilihan alur yang tidak bisa dibatalkan — keputusan sebesar itu diambil di bawah timer 20 detik yang terus berjalan adalah keputusan yang diambil terburu-buru, dan rancangan bagian 3 eksplisit bahwa pilihan permanen tanpa waktu membaca angkanya bukan keputusan tapi jebakan. Jadi batasnya jatuh di sumbu yang sama dengan flag dev: `Loadout` untuk **memakai**, `Lobby` untuk **mengubah apa yang dimiliki**. Harganya satu baris petunjuk yang harus menjelaskannya ("Pilih senjata sekarang — terkunci setelah ini. Upgrade-nya nanti di dalam match, tiap jeda wave."), karena tombol mati tanpa alasan terlihat seperti tombol rusak. Dites MATCH-17 dan PROG-17. |
| Cara membuka semua senjata selama development | **Lewat `Config.DEFAULT_DATA.weapons`** — ketiganya ditulis di situ di level 1 dengan `path = "none"`, dan `Config.DEV_ALL_WEAPONS` ditinggalkan `false`. Sementara, permintaan Daffa 2026-10-25 | Flag `DEV_ALL_WEAPONS` adalah cara yang **pertama** dipakai, dan dia cuma menyelesaikan separuh soalnya. Dia memberi senjata di **memori** saja, lewat `ProgressionRules.ownedWeapons`, sementara `canUpgrade` membaca `data.weapons` **langsung** — dan itu bukan kelalaian, itu syarat: lewat `ownedWeapons`, `canUpgrade` akan membolehkan pemain membayar koin sungguhan untuk menaikkan level senjata yang tidak dia miliki, dan `data.weapons[id] = { level = 2 }` masuk DataStore. Akibatnya untuk yang mau mencoba: senjata gratis yang **tidak bisa di-upgrade sama sekali**, ditolak "belum kamu miliki" di tombol yang kelihatan hidup, tanpa cara menebak kenapa. Yang diminta justru sembilan alur upgrade-nya, jadi separuh yang hilang itu separuh yang penting. Lewat `DEFAULT_DATA`, `DataSchema.reconcile` menuliskan ketiganya ke data pemain, jadi senjatanya **benar-benar dimiliki**: bisa dipakai, bisa di-upgrade, dan ikut tersimpan. Harganya dua, dan dua-duanya disadari. Pertama, `canBuy`/`canCraft` tidak pernah tercapai lagi — aturannya tidak dihapus dan masih benar, tapi PROG-10, PROG-12, PROG-13, PROG-18, MATCH-22, dan MATCH-23 jadi `BLOK`. Kedua, begitu data pernah tersimpan, ketiga senjata itu ada di DataStore dan tidak bisa dibedakan dari senjata yang dibeli: menghapus dua baris di `Config.luau` **tidak** mengambilnya kembali, yang mengambilnya cuma menaikkan `Config.DATASTORE_NAME`. Hari ini biayanya nol karena place-nya belum pernah di-publish. Flag-nya **tidak** dihapus dan seluruh batasnya masih berlaku: `ownedWeapons` untuk MEMAKAI, `data.weapons` langsung untuk MEMBELI, CRAFT, dan UPGRADE. Dipatok dua unit test: tiap id di `DEFAULT_DATA.weapons` benar-benar ada di `Weapons.luau` (id yang salah tulis tidak error, cuma disaring diam-diam), dan ketiganya lolos `canUpgrade`. Dites PROG-16 |
| Nama mata uang dalam match: "koin" atau "cash" | **"cash" untuk yang dibaca PEMAIN, "coins" untuk yang cuma dibaca programmer** — HUD, panel toko, pesan penolakan, tutorial, dan log server memakai *cash*; `MatchCoins`, `ShopService.addCoins`, `context.coins`, dan `Enemies[...].matchCoins` tetap memakai *coins* | Dua mata uang pernah sama-sama disebut "koin": yang satu milik tim, habis tiap match, cuma untuk Toko Match; yang satu milik satu pemain, permanen, cuma untuk upgrade senjata. Nama yang sama membuat pemain **menabung mata uang yang salah untuk barang yang dia incar** — dia melihat angka naik ratusan tiap wave dan menunggu bisa membeli upgrade senjata yang tidak akan pernah terjangkau olehnya, dan satu-satunya tanda bahwa dia salah adalah angka yang tidak pernah naik di panel yang lain. Tidak ada error, tidak ada pesan, dan tidak ada yang akan melaporkannya sebagai bug. Nama field dan nama remote sengaja **tidak** ikut berganti: tabel DEVELOPMENT_PLAN.md bagian 3.6 memaku nama remote, dan mengubahnya berarti mengubah kontrak jaringan untuk sebuah pergantian kata di layar. Jadi batasnya satu kalimat: kalau sebuah nama dibaca pemain, dia "cash"; kalau dia cuma dibaca programmer, dia tetap coins. Alasan lengkapnya di header `src/server/Services/ShopService.luau`. Dites SHOP-01, SHOP-09, dan SHOP-17 — yang terakhir membandingkan kedua mata uang dalam satu baris |
| Di level berapa pohon upgrade bercabang | **Level 4**, bukan level 1 (`Balance.PATH_BRANCH_LEVEL`). Bentuknya tidak berubah saat upgrade pindah ke dalam match; yang berubah umurnya — pilihannya mengikat sampai match itu selesai, bukan selamanya ([bagian 20.8](#208-keputusan-toko-upgrade-dalam-match)) | Di level 1 pilihannya jatuh sebelum pemain pernah **memakai** senjatanya: dia memilih dari tiga deskripsi, bukan dari pengalaman, dan satu-satunya informasi yang dia punya adalah teks yang ditulis orang yang membuat alurnya. Level 1-3 jadi masa percobaan — tiga level yang dibayar dan dipakai dulu, lalu keputusannya diambil oleh pemain yang sudah tahu senjatanya terasa seperti apa. Harganya: tiga level pertama tidak punya keputusan di dalamnya, dan tiga upgrade pertama tiap senjata terasa persis seperti sebelum fitur ini ada. Itu diterima — pilihan permanen yang diambil tanpa informasi bukan keputusan, itu jebakan, dan pemain yang merasa terjebak di level 10 berhenti main, bukan mulai dari awal. Dites SHOP-28 (PROG-19 dan PROG-23 yang dulu mengujinya `BLOK` bersama upgrade lobby). |
| `path` yang belum dipilih: `nil` atau string | **String `"none"`** (`DataSchema.NO_PATH`), eksplisit di `Config.DEFAULT_DATA` juga | Field bernilai `nil` **hilang total** saat tabelnya disimpan sebagai JSON ke DataStore. Jadi dengan `nil`, sesudah satu kali save "belum memilih" dan "save dari sebelum fitur ini ada" jadi tabel yang sama persis, dan tidak ada kode yang bisa membedakannya lagi — selamanya, untuk akun itu. Dengan `"none"`, yang pertama punya field bernilai `"none"` dan yang kedua tidak punya field sama sekali, jadi migrasi punya sesuatu untuk dikenali. Ini keputusan yang biayanya nol di hari ini dan tidak bisa dibatalkan besok, jadi diambil sekarang. Dites DATA-12, DATA-13, dan PROG-25. |
| `pathChoiceRequired`: level sesudah upgrade `== 4` atau `>= 4` | **`>=`** | Dengan `==`, aturannya cuma pernah benar tepat saat naik dari 3 ke 4 — dan itu cukup untuk data yang lahir sesudah fitur ini ada, karena level naik satu-satu dan pilihannya tersimpan begitu diterima. Yang tidak tertangani adalah save yang **sudah** lewat level 4 dengan `path` masih `"none"`: senjata yang dibeli atau di-craft sebelum fitur ini ada, atau data yang diedit tangan. Pemain seperti itu tidak akan pernah ditagih memilih, jadi senjatanya berjalan tanpa alur sampai level 10 dan tidak ada satu pun pesan yang memberitahunya — dia membayar sembilan upgrade untuk pohon yang tidak pernah dia masuki. `>=` menagihnya pada upgrade berikutnya apa pun levelnya. Dites DATA-12. |
| Urutan pemeriksaan di `canUpgrade` | **Level maksimum, lalu alur, lalu koin** — jadi alur sebelum koin tapi sesudah level maksimum | Dua urutan yang dipilih, dua alasan. **Alur sebelum koin:** pemain yang belum memilih sekaligus kekurangan koin punya dua hal yang kurang, dan yang harus dia tahu dulu adalah yang menuntut keputusan, bukan yang menuntut waktu. Dibalik, dia menabung sampai cukup lalu baru menemukan ada pilihan permanen yang menunggu di detik dia menekan tombol — persis keadaan terburu-buru yang seluruh bagian 3 rancangan dibuat untuk menghindari. **Level maksimum tetap paling dulu:** senjata level 10 tanpa alur (data lama; lihat baris `>=` di atas) tidak punya upgrade berikutnya untuk membawa pilihan itu, jadi menagih alur di situ memberi pemain pesan yang tidak punya jalan keluar. Dites PROG-09 dan PROG-08. |
| Satu `weaponStats` atau beberapa fungsi stat | **Satu fungsi** `Balance.weaponStats(def, save)` yang mengembalikan `{ damage, cooldown, range, projectiles, effects }`. `damageMult`/`cooldownMult` **menumpuk**, `range`/`projectiles` nilai **absolut** yang ditimpa tingkat lebih tinggi | `CombatService` butuh keempat angka itu dalam satu tarikan napas tiap serangan, dan alur upgrade bisa mengubah keempatnya. Dengan fungsi terpisah per stat, satu pemanggil yang lupa menerapkan alur pada **salah satu** stat menghasilkan senjata yang damage-nya ikut alur tapi cooldown-nya tidak — dan selisih seperti itu tidak terlihat sampai ada yang mengukurnya dengan stopwatch, jadi dia bisa hidup sampai alpha. Satu fungsi juga jadi satu-satunya tempat efek alur dipasang, dan itu terbayar di langkah 7: mengisi kesembilan alur tidak menyentuh satu baris pun di luar `Weapons.luau` dan tempat yang **membaca** `stats.effects`. Pengali yang menumpuk vs nilai absolut bukan selera: alur seperti "cooldown turun di tingkat 1, turun lagi di tingkat 3" cuma bisa ditulis apa adanya kalau pengalinya menumpuk, sementara "jangkauan jadi 90" yang ditulis dua kali di dua tingkat tidak boleh jadi 180. `cooldown` punya lantai 0.05 dan `projectiles` minimum 1 di satu tempat, bukan di pemanggil: cooldown nol dari data alur yang rusak berarti serangan tanpa batas, dan gerbang cooldown `CombatService` tidak akan menolaknya karena `now - last < 0` selalu false. `Balance.weaponDamage` ditinggalkan sebagai dasar kurva level supaya kurvanya bisa dites terpisah dari penggabungan alur. Dipatok unit test `Balance`. |
| Alur dengan id yang tidak dikenal di `save.path` | **Diperlakukan seperti belum memilih** — bukan jatuh ke alur pertama | Bisa terjadi dari data yang diedit tangan, atau dari id alur yang diubah sesudah ada pemain yang memilihnya. Jatuh ke alur pertama berarti pemain melihat stat dari alur yang **tidak** dia pilih dan tidak ada satu pun pesan soal itu — memberi alur yang salah secara diam-diam lebih buruk daripada tidak memberi apa pun, karena yang pertama tidak bisa dilaporkan ("senjataku terasa aneh") sementara yang kedua bisa dilihat di panel. Keputusan ini juga sebabnya tema dan id alur **tidak boleh diubah sembarangan** sesudah ada pemain yang memilih: `save.path` menyimpan id-nya, jadi mengganti arti alur `"a"` berarti semua pemilih `"a"` mendapat alur berbeda tanpa pernah menyetujuinya. Dipatok unit test `Balance.weaponStats`. |
| `migrate` sebagai pintu terpisah dari `reconcile` | **`DataSchema.migrate(data, defaults)` = `reconcile` lalu `fillWeaponPaths`**, dan `PlayerDataService` memanggil `migrate` di **kedua** jalur load | `reconcile` mengisi field yang hilang dari `Config.DEFAULT_DATA`, dan satu-satunya senjata di sana `weapon_starter`. Jadi senjata yang **dibeli atau di-craft** sebelum alur upgrade ada punya `{ level = n }` tanpa `path`, dan `reconcile` tidak punya default untuk kunci yang tidak dia kenal — dia bukan rusak, dia memang fungsi umum yang tidak tahu apa pun soal senjata, dan menambahkan pengetahuan itu ke dalamnya berarti satu fungsi umum yang pelan-pelan jadi daftar migrasi. Kalau langkah keduanya dilewatkan, hasilnya **bukan error**: `save.path` nil berarti `weaponStats` tidak menemukan alur apa pun, jadi senjata level 10 milik pemain lama berjalan tanpa alur, lebih lemah daripada yang dia bayar, tanpa satu pesan pun. Disatukan jadi satu fungsi supaya dua tempat yang memuat data pemain tidak bisa menjalankan satu langkah tanpa yang lain, dan migrasi skema berikutnya menempel di situ juga. Dites DATA-12 dan DATA-13. |
| Slow: satu pasang kunci atau dua | **Dua pasang.** `slowMult` / `slowSeconds` menempel ke **MUSUH** dan ikut dia ke mana pun; `zoneSlowMult` / `zoneSeconds` menempel ke **TEMPAT** dan berhenti begitu musuh keluar radius | Dua umur yang benar-benar berbeda, dan satu nama untuk keduanya memaksa pembaca menebak yang mana. Yang menempel ke musuh disimpan di `Enemy.slow` dan dibaca `CombatEffects.multOf`; yang menempel ke tempat disimpan di daftar `zones` milik `EnemyService` dan dibaca `CombatEffects.zoneSlowAt` **dengan posisi musuh sebagai argumen tiap frame**. Itu bukan detail implementasi: zona harus ikut mengenai musuh yang **baru spawn** sesudah zonanya dibuat, dan harus berhenti mengenai musuh yang berjalan keluar — dua hal yang tidak mungkin kalau pengalinya disimpan di musuhnya. Satu nama juga akan membuat "slow 55% selama 3 detik" ambigu antara "musuh ini lambat 3 detik" dan "siapa pun yang di sini lambat selama 3 detik ke depan". Keduanya **dikalikan** di loop `step`, bukan diambil yang terkuat, karena keduanya datang dari alur yang berbeda dan masing-masing sumbernya sendiri sudah dibatasi. Dites COMBAT-23 dan COMBAT-24, dijelaskan di T15. |
| Dua slow (atau dua tanda) yang bertumpuk: siapa yang menang | **Yang terkuat menang, dan yang terlama menang** (`CombatEffects.merge`), bukan yang terbaru | "Terbaru menang" lebih sederhana dan salah dengan cara yang tidak bisa didiagnosis. Ayunan Cepat tingkat 3 memukul tiap **0.25 detik** dengan slow x0.5 selama 1.5 detik, jadi dalam satu durasi slow ada enam pukulan; satu pukulan lemah dari sumber lain di antaranya akan **membatalkan** slow kuat yang masih aktif, dan pemain melihat musuh yang kadang melambat kadang tidak **tanpa pola** — lalu melaporkannya sebagai slow yang rusak, yang tidak bisa direproduksi karena yang memicunya urutan kedatangan pukulan. Dengan terkuat-menang efeknya monoton dan bisa diprediksi. "Terlama menang" menempel di situ karena efek baru yang lebih kuat tapi lebih **pendek** tidak boleh memotong sisa umur yang sudah dijanjikan; dan karena yang lemah tidak pernah diterapkan, dia juga tidak bisa memperpanjang umur yang kuat lewat pintu belakang. Arah "lebih kuat"-nya dioper sebagai argumen `strongerIsSmaller`, bukan dua fungsi: untuk slow pengali lebih **kecil** yang kuat, untuk tanda lebih **besar**, dan dua fungsi yang isinya sama kecuali satu tanda perbandingan adalah dua tempat yang bisa menyimpang. Dipatok unit test `CombatEffects.merge`, dan di engine oleh `slow.pukulanLemahTidakMembatalkan` serta `tanda.tandaLemahTidakMenurunkan`. |
| Zona yang bertumpuk: slow dan dps digabung bagaimana | **Slow diambil yang terkuat, dps dijumlahkan** (`CombatEffects.zoneSlowAt` dan `zoneDamageAt`) | Dua aturan yang berbeda di satu fungsi yang berdampingan, dan itu sengaja. Kalau slow dikalikan, tiga zona x0.45 jadi **x0.091** — musuh yang praktis berhenti dari tiga tembakan biasa, dan itu bukan yang dijanjikan satu pun tingkat alur; pemain yang menembak tiga kali ke titik yang sama mendapat kemampuan yang tidak dia beli. Damage satu-satunya efek di daftar ini yang **penjumlahannya tidak menghasilkan keadaan ekstrem**: dua jebakan yang bertumpuk memang dua jebakan, 12 dps bukan nilai yang mengubah sifat permainan, dan "zona kedua tidak melakukan apa pun" justru yang akan terlihat seperti bug. Pemisahannya juga yang membuat tingkat 1 dan 2 memberi **nol** damage apa pun banyaknya zona yang bertumpuk, karena `zoneDps` baru ada di tingkat 3 — jadi "zona tidak men-damage" bukan gejala, itu levelnya. Dipatok unit test `CombatEffects`, dan di engine oleh `zona.damageSebandingWaktuBukanSekaliHabis`. |
| Di mana pengali tanda diterapkan | **Di `EnemyService.damage`**, bukan di `CombatService.onAttack` | Ini seluruh bedanya antara "tanda menaikkan damage penandanya" dan "tanda menaikkan damage **siapa pun**". Turret Toko Match, splash dari pemain lain, dan damage per detik zona semuanya lewat `EnemyService.damage`, jadi di situ semuanya ikut terkali dengan satu baris, sementara di `CombatService` yang terkali cuma serangan pemain — dan alur Dukungan yang cuma menaikkan damage pemiliknya adalah alur damage biasa dengan nama yang menyesatkan. Harganya nyata dan diterima: alur ini **paling kuat di tim berempat dan paling lemah solo**, karena nilainya berbanding lurus dengan jumlah sumber damage yang menembaki musuh bertanda. Itu disengaja — dia memberi alasan **mekanis** untuk main bareng alih-alih cuma pengali reward, dan itu satu-satunya mekanik co-op di seluruh v1. Satu akibat yang akan terlihat setengah bekerja: `damage` dipanggil **sebelum** `applyMark` di `onAttack`, jadi tembakan yang memasang tanda tidak ikut terkali; membaliknya berarti satu tembakan memberi damage yang dikali tanda yang belum ada saat tembakan itu dilepas. Dites COMBAT-21 dan COMBAT-22, dijelaskan di T16. |
| Splash: target utama ikut jadi korbannya sendiri? | **Tidak.** Semua yang sudah menerima damage penuh dikecualikan lewat tabel `struck` yang dioper sebagai `exclude` ke `CombatEffects.withinRadius` | Tanpa pengecualian itu target utama kena **dua kali** — sekali penuh, sekali lagi dikali `splashMult` — jadi Fork Bomb Ledakan tingkat 1 memberi `40.8 + 20.4` = 61.2 ke target yang panelnya menulis 40.8. Itu kegagalan **termahal** di antara seluruh efek alur, dan bukan karena besarnya: gejalanya cuma damage yang lebih besar daripada yang tertulis, dan **tidak ada satu pun pemain yang melaporkan senjatanya terlalu kuat**. Jadi dia akan hidup sampai alpha, lalu sampai rilis, lalu ditemukan saat ada yang membandingkan panel dengan bar HP. Dikecualikan **semua** yang kena, bukan cuma yang pertama, karena alur lain bisa mengenai beberapa target sekaligus (`projectiles` 3, 5, 7) dan target kedua punya masalah yang sama persis. Dipatok unit test `CombatEffects.withinRadius`; di harness dia SKIP karena butuh Player, jadi COMBAT-18 yang membuktikannya. |
| Dari mana zona dan splash berangkat | **Dari posisi musuh PERTAMA yang kena**, dibaca lewat `EnemyService.getPosition` **sebelum** musuh itu di-damage. Serangan yang tidak mengenai apa pun tidak meninggalkan apa pun | Tiga alternatif, dan ketiganya lebih buruk. **Dari posisi pemain:** ledakan muncul di kaki pemain alih-alih di tempat dia menembak. **Dari ujung garis bidik:** zona lahir dari setiap tembakan ke udara, jadi pemain bisa **melapisi seluruh lane** dengan zona slow tanpa membidik apa pun — Fork Bomb Jebakan jadi senjata penghalang area dengan cooldown 0.6 detik, bukan alur jebakan. **Dari posisi musuh sesudah di-damage:** musuh yang mati di pukulan itu sudah lepas dari `active` dan Part-nya di-Destroy, jadi posisinya nil dan zona terbesar — yang ditinggalkan pukulan yang membunuh — justru yang paling sering hilang. Dan kalau target pertama hilang di antara `collectTargets` dan pembacaan itu (mati karena turret atau zona di frame yang sama), splash dan zona **dilewati** alih-alih ditebak dari posisi pemain: ledakan di tempat yang pemainnya tidak menembak lebih sulit dipercaya daripada ledakan yang tidak terjadi. Dites COMBAT-18 dan COMBAT-24. |
| Zona digambar atau tidak | **Tidak digambar sama sekali** — tabel Lua di `EnemyService`, tanpa satu Part pun | Kekurangan yang **diketahui dan diterima**, bukan kelupaan, dan dicatat di sini supaya tidak ada yang melaporkannya sebagai bug. Yang dibutuhkan langkah 7 adalah efeknya **bekerja**; menggambarnya butuh Part, ukuran, warna, dan transparansi yang masuk ke daftar entri graybox seperti `VISUALS` milik musuh, dan seluruh prioritas rancangan ini logika sebelum efek ([ARENA_REDESIGN.md](ARENA_REDESIGN.md) bagian 0). Harganya langsung terasa dan harus ditulis di dokumen ini dua kali: musuh yang melambat dan kehilangan HP di tempat yang **terlihat kosong** (T15), dan satu alur yang tidak bisa dinilai "terasa enak atau tidak" di playtest karena pemainnya tidak tahu di mana zonanya. Satu hal yang **tidak** ikut ditunda walau Part-nya belum ada: zona dibuang `clearAll()` bersama musuhnya, karena zona sisa match sebelumnya yang tidak kelihatan adalah bug yang mustahil didiagnosis dari dalam game. Dites COMBAT-24 dan COMBAT-25. |

### 20.7 Keputusan M6 (leaderboard)

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Satu store untuk semua tingkat, atau satu per tingkat | **Satu OrderedDataStore per tingkat kesulitan** (`HighestWave_v1_<id>`), key = UserId, value = wave tertinggi | `GetSortedAsync` mengurutkan **seluruh** store, bukan bagian yang diminta. Kalau catatan `normal` dan `hard` tinggal di satu store dengan key gabungan, papan `hard` harus membaca seluruh catatan `normal` lebih dulu lalu membuangnya satu per satu — dan sepuluh teratas yang diminta bisa habis dipakai catatan tingkat yang salah, sehingga papannya kosong padahal datanya ada. Itu LB-02. Versi di nama store ikut naik kalau artinya berubah: store lama tidak bisa dihapus, dan catatan yang artinya sudah berbeda lebih buruk daripada papan kosong. |
| `OnServerInvoke` boleh yield atau tidak | **Tidak pernah yield.** Dia menjawab dari papan yang sudah ada di memori dan paling banyak **menjadwalkan** pembacaan ulang | Kalau dia memanggil `GetSortedAsync` sendiri, client yang membuka lobby ikut menunggu panggilan web — dan saat DataStore sedang throttle, menunggunya bisa puluhan detik. Papan yang terlambat satu menit masih papan; lobby yang membeku bukan lobby. Ini juga yang membuat LB-00 bisa dipenuhi tanpa syarat apa pun soal isi papannya: yang dijanjikan cuma bahwa panggilannya kembali. |
| Rekor baru: baca ulang store, atau jahit ke papan memori | **Dijahit ke papan memori** lewat `LeaderboardRules.merge` | `GetSortedAsync` punya kuota sendiri, dan satu match empat pemain akan memanggilnya empat kali beruntun untuk hasil yang sudah diketahui. Menjahitnya di memori yang membuat papan ikut terupdate tanpa restart server (LB-04). Pembacaan ulang berkala tetap ada — 60 detik, dengan jarak minimum 15 detik per tingkat — karena server **lain** menulis ke store yang sama dan tanpa itu papan di sini tidak akan pernah melihat rekor pemain yang sedang main di tempat lain. |
| Di mana aturan "catatan tidak pernah turun" tinggal | **Satu fungsi, `LeaderboardRules.isRecord`, dipakai dua tempat**: transform `UpdateAsync` dan `merge` papan memori | Dua pembukuan untuk angka yang sama, dan keduanya harus sepakat. Kalau tidak, papan di layar bisa menunjukkan angka yang lebih tinggi daripada yang benar-benar tersimpan — dan selisihnya tidak terlihat sampai server restart, saat papannya "turun sendiri". Gejala seperti itu mustahil dilacak dari dalam game, jadi aturannya ditarik keluar jadi modul murni yang punya test sendiri, termasuk satu test yang memang hanya menjaga agar keduanya tidak berbeda pendapat. Dites LB-03. |
| Dari mana nilai lama dibaca saat menulis rekor | **Dari DALAM transform `UpdateAsync`**, bukan lewat `GetAsync` terpisah | Dua panggilan berarti dua titik waktu, dan di antara keduanya server lain bisa menulis rekor yang lebih tinggi — yang lalu ditimpa rekor lebih rendah dari sini. `UpdateAsync` membaca dan menulis dalam satu transaksi, jadi di situlah satu-satunya tempat yang benar untuk membaca nilai lamanya. Transformnya mengembalikan `nil` untuk **membatalkan** tulisan kalau bukan rekor; alternatifnya mengembalikan nilai lama, dan itu satu tulisan DataStore untuk setiap match yang tidak memecahkan rekor. |
| Siapa yang dicatat saat match selesai | **Hanya peserta yang masih terhubung** | Peserta yang sudah keluar dicatat sendiri saat dia keluar, dengan wave yang dia capai **saat itu**. Mencatatnya lagi di akhir match akan memberinya wave yang dicapai orang lain setelah dia pergi. Aturan yang sama dipakai `RewardService` untuk membayar reward, dan dua pembukuan yang memakai aturan berbeda untuk match yang sama akan saling bertentangan di layar. Dites LB-01. |

### 20.8 Keputusan toko upgrade dalam match

Baris di bawah datang dari satu perubahan: **Toko Match tidak menjual item
lagi, dia menjual upgrade senjata.** Kelima item dimatikan, upgrade senjata
pindah dari lobby ke dalam match dan dibayar cash, dan cash berhenti jadi
kolam tim. Tidak ada satu pun kriteria "Selesai kalau" yang memintanya — jadi
seluruh isi tabel ini pilihan, dan beberapa di antaranya **membatalkan
keputusan yang sudah dicatat di 20.2, 20.3, dan 20.6**. Baris yang dibatalkan
ditandai di tempatnya masing-masing alih-alih dihapus: keputusan yang hilang
tanpa jejak akan diambil lagi dari awal oleh orang berikutnya, dengan alasan
yang sama dan hasil yang sama.

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Kelima item toko: dihapus atau dimatikan | **Dimatikan lewat satu flag** (`Config.MATCH_SHOP_ITEMS_ENABLED = false`), definisi item, `ShopRules`, efek, dan unit test-nya dibiarkan utuh | Kodenya masih benar; yang berubah cuma apa yang dijual toko hari ini. Menghapusnya berarti membuang lima item berefek tim beserta aturan harga yang sudah diuji, lalu menulis ulang semuanya kalau nanti dipakai lagi — dan menulis ulang dari ingatan tidak pernah menghasilkan hal yang sama. Dengan flag, mengembalikannya satu baris, dan sebelas baris test di dokumen ini tetap berlaku apa adanya |
| Penolakan item: di client atau di server | **Di server**, `ShopService.onBuy`, dengan pesan yang menyebut apa yang menggantikannya | Menyembunyikan panel di client cuma menghilangkan tombolnya. Client yang dimodifikasi tetap bisa menembakkan `BuyShopItem`, dan fitur yang masih bisa dibeli lewat remote bukan fitur yang dimatikan. Pesannya menyebut penggantinya ("Yang dijual sekarang upgrade senjata.") karena penolakan tanpa alasan terlihat persis seperti tombol yang rusak. Dites SHOP-07 dan SEC-04 |
| Cash: satu kolam tim atau per pemain | **Per pemain** (`MatchCoins` jadi `FireClient`, pembukuan per UserId) | Ini yang dipaksa oleh apa yang dijual toko. Kolam tim **benar** selama yang dibeli efek tim; begitu yang dibeli **barang pribadi**, dia salah: empat pemain yang berbagi satu kolam untuk upgrade senjata masing-masing berarti tiap orang kebagian seperempat, dan yang paling cepat menekan tombol memakai uang bersama untuk dirinya sendiri — satu pemain bisa menghabiskan hadiah empat orang untuk senjatanya sendiri, dan tiga lainnya tidak punya cara menghalanginya. Harganya: saldo berbeda di tiap layar, yang akan terbaca seperti desync (T17), dan keputusan 20.2 soal disconnect harus dijawab ulang. Dites MP-04, MP-15, SHOP-23, SHOP-24 |
| Cash dari musuh yang mati masuk ke siapa | **Ke yang membunuhnya**; musuh yang mati **tanpa pembunuh yang bisa ditunjuk** dibayarkan ke semua peserta | Begitu cash jadi milik pribadi, "masuk ke tim" tidak punya tempat lagi untuk masuk. Yang tidak punya pembunuh — zona jebakan, turret, mekanik boss — tidak boleh hangus: alur Jebakan membunuh justru dengan bekerja sendiri, jadi menghanguskannya berarti menghukum alur yang dipilih pemain dengan cash yang lebih sedikit, dan itu balancing yang tidak pernah diniatkan satu pun tingkat alur |
| Hadiah per wave: dibagi atau penuh ke tiap peserta | **Penuh ke tiap peserta**, dan pengali jumlah pemain dihapus | Dibagi, tim berempat berarti seperempat anggaran per orang untuk harga upgrade yang sama — main bareng jadi menghukum, di game co-op. Penuh ke tiap orang membuat anggaran satu pemain tidak bergantung sama sekali pada berapa orang yang ikut, dan itu juga yang membuat pengali jumlah pemain tidak punya pekerjaan lagi: gunanya dulu menyamakan kolam **tim** lintas jumlah pemain, dan yang disamakan sekarang anggaran **per pemain**. Totalnya 5.300 per pemain untuk satu run penuh, berapa pun jumlah mereka |
| Level dan alur: permanen atau diulang tiap match | **Diulang tiap match** — `matchWeapons` di ShopService, dibuang `ShopService.reset()` saat kembali ke `Lobby`, dan `data.weapons[id].level` tidak dibaca `CombatService` lagi | Ini bukan efek samping dari cash yang habis tiap match, ini yang dicari. Alur yang terkunci selamanya cuma pernah **dialami sekali** per senjata: sesudah pemain memilih Sniper, seluruh sisa umur akun itu dia bermain Sniper, dan dua alur lain jadi teks yang dia baca sekali lalu tidak pernah lagi. Alur yang dipilih ulang tiap match adalah **keputusan yang diambil berkali-kali** dengan keadaan yang berbeda-beda — komposisi tim, wave yang sedang dihadapi, cash yang ada — dan itu yang membuat sembilan alur benar-benar dimainkan, bukan dibaca. Yang pertama progres, yang kedua gameplay. Harganya: tidak ada lagi progres senjata yang bisa dipamerkan lintas match, dan `data.weapons[id].level` jadi field yang tersimpan tanpa pembaca. Dites SHOP-29 dan SHOP-30 |
| Aturan alur: disalin ke modul baru atau dibaca dari `ProgressionRules` | **Dibaca dari `ProgressionRules`** — `MatchUpgradeRules` tidak menduplikasi satu pun aturan alur: kapan pilihan ditagih (`pathChoiceRequired`), alur mana yang sah (`findPath`), dan alur mana yang tersimpan (`pathToApply`) semuanya fungsi yang sama yang dipakai upgrade lobby | Menyalinnya menggoda karena modul barunya jadi berdiri sendiri dan bisa dibaca tanpa membuka file lain. Tapi dua salinan aturan yang sama akan **bergeser pelan-pelan** — satu diperbaiki, satu lagi tidak — dan gejalanya yang paling mungkin: panel menawarkan pilihan alur di level yang ditolak server, atau sebaliknya server menagih pilihan yang panelnya tidak pernah tampilkan. Tidak ada error, tidak ada log, cuma tombol yang kadang ditolak. Yang **memang** ditulis di modul baru cuma yang benar-benar baru: mata uangnya cash, gerbangnya `Intermission`, dan harganya `Balance.matchUpgradePrice` |
| `UpgradeWeapon`: dicabut dari ProgressionService atau dibiarkan tersambung | **Dicabut.** Handler lobbynya diparkir sebagai `ProgressionService.upgradeFromLobby` dan tidak tersambung ke remote mana pun | Membiarkannya tersambung terlihat aman: gerbang state-nya berbeda (`Lobby` di sana, `Intermission` di sini), jadi hari ini keduanya tidak pernah menerima tembakan yang sama. Tapi `OnServerEvent` boleh punya **banyak pendengar**, dan dua handler akan sama-sama dijalankan untuk **tiap** tembakan — yang menyelamatkan cuma kebetulan bahwa gerbangnya tidak bertabrakan. Satu perubahan state di salah satu sisi (upgrade dibuka di `Loadout`, atau toko dibuka di `Lobby` untuk sesuatu) membuat satu upgrade dipotong **dua kali dari dua mata uang yang berbeda**, dan yang pertama terlihat pemain cuma koin permanen yang berkurang tanpa sebab — kerusakan yang masuk DataStore dan tidak bisa dibatalkan. Diparkir dan bukan dihapus supaya menyalakannya lagi tetap satu baris, dan supaya dia tidak terbaca sebagai kode mati yang aman dihapus. Akibatnya untuk test: sepuluh baris PROG dan HUD-07 `BLOK` ([bagian 13](#13-progres-permanen-dan-data-player-prog)) |
| Panel upgrade: daftar senjata atau satu baris | **Satu baris**, senjata yang sedang dipakai saja, dan `weaponId` dari client cuma **diperiksa kecocokannya** dengan `data.equippedWeapon` | Fase `Loadout` sudah mengunci senjata yang dipakai sampai match selesai, jadi daftar tiga baris berarti dua baris yang tidak bisa diapa-apakan. Dan id dari client tidak dipakai memilih senjata mana yang naik, cuma dicocokkan: tombol yang ditekan di panel lama — sesudah pemain ganti senjata — tidak boleh diam-diam menaikkan senjata yang lain. Dites SHOP-25 dan SHOP-31 |
| Harga upgrade dalam match | `Balance.matchUpgradePrice`, base **150** tumbuh **1.35** — sembilan langkah totalnya **5.951** melawan anggaran 6.694 solo dan 5.813 berempat | Dipilih terhadap anggaran yang benar-benar masuk, bukan dikarang: level 10 **bisa** dicapai dalam satu run, tapi cuma kalau hampir seluruh cash ditumpahkan ke satu senjata dan nyaris tidak ada yang tersisa — dan di tim berempat bahkan itu kurang beberapa ratus. Itu yang membuat tiap jeda jadi pilihan, bukan formalitas. Ada sembilan jeda dan sembilan upgrade, jadi "satu upgrade tiap wave" memang bentuk yang dituju. Ini **tebakan pertama yang menunggu playtest**; yang digeser nanti dua konstantanya, bukan rumusnya |
| Upgrade ikut disandera Locker? | **Tidak.** Yang disandera cuma pengali tim dari item toko | Sandera itu analogi ransomware terhadap milik **tim**; upgrade senjata milik satu orang, dan menyandera milik pribadi satu pemain di wave terakhir berarti dia kehilangan seluruh belanjaan satu match tanpa cara mengembalikannya. Akibat yang harus diterima dan dicatat: selama item toko dimatikan, mekanik itu tidak menyandera apa pun sama sekali (T19) |

### 20.9 Keputusan gerak pemain

Jongkok diminta Daffa pada 2026-10-26, dan **dikerjakan dua kali**. Versi
pertama mendarat hari itu juga: jongkok saja, tanpa efek gameplay, tombol C.
Versi kedua datang beberapa jam kemudian dari `Gameplay.rbxl` — sikap badan
dengan stamina — dan keduanya mengikat tombol yang sama serta menulis
`WalkSpeed` yang sama, jadi yang pertama dicabut. Tabel ini mencatat keputusan
yang BERLAKU; baris terakhir mencatat yang dicabut, supaya alasan versi
pertama tidak diambil lagi dari awal oleh orang berikutnya.

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Berapa sikap badan | **Tiga**: walk, sprint, crouch — plus dash sebagai tindakan sesaat | Soal yang mendasarinya minta empat tindakan: idle, run, jump, crouch. Empat tombol yang bisa ditekan kapan saja memenuhi soal tapi tidak pernah jadi KEPUTUSAN: lari terus selalu lebih baik daripada berjalan, dan jongkok tidak pernah ada alasannya sama sekali |
| Apa yang mengikat ketiganya | **Stamina.** Sprint menguras 18/detik dan cuma saat benar-benar bergerak, walk memulihkan 14, jongkok memulihkan 26 | Itu yang membuat jongkok punya alasan: dia cara tercepat memulihkan tenaga. Pemain yang terjepit harus memilih — mundur sambil jongkok memulihkan, atau membakar sisa stamina untuk dash menembus |
| Ambang mulai sprint vs ambang berhenti | **Berbeda** (mulai di 18, berhenti di 0) | Kalau sama, pemain yang staminanya habis berganti sprint/walk puluhan kali per detik: satu frame regen menaikkannya di atas ambang, satu frame drain menjatuhkannya. Kecepatan berkedip, dan animasi ikut berkedip bersamanya |
| Siapa yang menegakkannya | **Server** (`MovementService` membaca `MoveRules`); client cuma mengirim niat lewat `MoveIntent` | `Humanoid.WalkSpeed` yang disetel client memang berlaku, jadi gerak tidak bisa dibuat anti-curang sepenuhnya. Yang bisa: satu sumber angka, server yang menulis, dan bar stamina di layar dihitung dari modul yang sama supaya dia tidak pernah bercerita berbeda dari yang server izinkan |
| Lompat sambil jongkok | **Tidak bisa** — `JUMP_HEIGHTS.crouch` nol, bukan angka kecil | Lompatan kecil saat jongkok terbaca sebagai lompatan yang GAGAL, dan pemain akan terus mencobanya. Nol setidaknya jelas |
| Animasi lutut menekuk | **Dihitung**, bukan diputar dari klip (`Poses`) | Klip butuh aset animasi yang di-upload ke Roblox, dan proyek ini belum punya satu pun asset id. Pose yang dihitung tidak butuh aset apa pun, dan dia juga yang membuat jongkok terlihat seperti jongkok |
| Tombol gerak di layar sentuh | **Belum ada** (T21) | Diminta sebagai hotkey, jadi dikerjakan sebagai hotkey |
| ~~Jongkok tanpa efek gameplay sama sekali~~ | **Dicabut 2026-10-26** bersama `CrouchService`, `CrouchRules`, remote `SetCrouch`, dan delapan unit test-nya | Alasannya masih benar dan masih layak dibaca: jongkok dipicu client, jadi keuntungan apa pun yang digantungkan padanya gratis bagi yang mencurangi. Yang menjawabnya di sistem baru bukan "tidak ada keuntungan" melainkan **stamina**: keuntungan jongkok cuma pemulihan tenaga, dan tenaga yang dipulihkan tanpa benar-benar melambat tetap harus dibelanjakan lewat server |

## 21. Gerak pemain (MOVE)

Acuan: tidak ada. Gerak pemain diminta Daffa pada 2026-10-26 dan bukan bagian
dari milestone mana pun, jadi kelompok ini tidak punya baris di
[bagian 19](#19-pemetaan-ke-kriteria-selesai-kalau) dan tidak menggerbangkan
apa-apa. Ditaruh paling belakang, sesudah kedua bagian meta, supaya penomoran
bagian 19 dan 20 beserta seluruh tautan ke dalamnya tidak bergeser.

Mekanismenya dulu, karena dia menentukan apa yang masuk akal diuji di sini.
**Roblox tidak punya sikap badan bawaan**: `Humanoid` punya Running, Jumping,
Freefall, dan Seated, dan tidak ada Crouching maupun Sprinting. Jadi ketiganya
dirakit — `WalkSpeed` dan `JumpHeight` disetel server per sikap, dan pose
badannya **dihitung tiap frame** oleh `Poses` lalu dituliskan ke Motor6D oleh
`CharacterAnimatorController`. Angkanya satu tempat, `MoveRules`.

Tiga hal yang perlu dibaca sebelum menilai barisnya:

- **Stamina yang mengikat ketiganya.** Sprint menguras 18 per detik dan cuma
  saat benar-benar bergerak; walk memulihkan 14; jongkok memulihkan 26. Dash
  membayar 25 di muka. Jadi jongkok bukan hiasan: dia cara tercepat memulihkan
  tenaga, dan itu satu-satunya alasan seseorang mau berjalan lebih lambat.
- **Ambang mulai sprint (18) berbeda dari ambang berhenti (0),** dan itu
  disengaja. Kalau kamu melihat kecepatan berkedip cepat saat stamina habis,
  histeresisnya tidak bekerja — itu temuan, bukan selera.
- **Server yang menulis `WalkSpeed`.** Client cuma mengirim niat lewat
  `MoveIntent`. Itu yang membuat MOVE-07 jadi baris paling penting di kelompok
  ini: dia satu-satunya yang membuktikan pemain lain melihat sikap badan yang
  sama.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| MOVE-01 | Karakter hidup, stamina penuh | Tahan **Shift** sambil berjalan, amati bar stamina | Jalan jelas lebih cepat (25 vs 16 stud/detik) dan bar stamina **turun** selama benar-benar bergerak | — | solo | - |
| MOVE-02 | Lanjutan MOVE-01 | Berdiri **diam** sambil tetap menahan Shift | Bar stamina **tidak turun**. Menguras saat diam berarti pemain yang lupa melepas tombol kehilangan tenaga tanpa pernah tahu sebabnya | — | solo | - |
| MOVE-03 | Stamina sengaja dihabiskan sampai nol dengan sprint | Tetap tahan Shift dan terus bergerak selama 10 detik | Sikap turun ke walk, lalu **tidak berkedip bolak-balik** antara lari dan jalan. Pemulihan mengangkatnya kembali ke sprint hanya setelah stamina melewati 18, bukan begitu menyentuh angka di atas nol | — | solo | - |
| MOVE-04 | Karakter hidup | Tekan **C**, lalu jalan; amati karakter dari kamera orang ketiga | Jongkok: badan turun, **lutut benar-benar menekuk**, dan jalannya paling lambat (7 stud/detik). Kalau badannya turun tapi kakinya tetap lurus, `Poses` tidak terpasang — lihat Output untuk `[CharacterAnimatorController]` | — | solo | - |
| MOVE-05 | Sedang jongkok | Tekan **Space** | **Tidak melompat sama sekali.** Lompatan kecil saat jongkok terbaca sebagai lompatan yang gagal, jadi nol disengaja | — | solo | - |
| MOVE-06 | Sedang jongkok, stamina di bawah separuh | Diam jongkok selama 3 detik, amati bar stamina | Bar naik **lebih cepat** daripada saat berdiri diam (26 vs 14 per detik). Ini satu-satunya hal yang membuat jongkok berguna; kalau lajunya sama, jongkok tidak punya alasan | — | solo | - |
| MOVE-07 | Sesi **2 client**, keduanya karakternya hidup dan saling terlihat | Pemain A jongkok lalu lari. Amati dari **layar pemain B** | Di layar B, karakter A ikut jongkok dan ikut lari — pose DAN kecepatannya. Pose dihitung di tiap client dari sikap yang direplikasi, jadi kalau A terlihat berdiri di layar B, yang putus replikasi sikapnya, bukan animasinya | — | 2P | - |
| MOVE-08 | Stamina penuh, karakter hidup | Tekan **Q** | Dash: lonjakan cepat ke arah hadap selama ~0.22 detik, dan stamina **langsung berkurang 25** di awal, bukan bertahap | — | solo | - |
| MOVE-09 | Stamina di bawah 25 | Tekan **Q** | **Tidak ada dash**, dan stamina tidak berkurang. Dash yang terpicu tapi tidak bergerak jauh lebih buruk daripada dash yang jelas ditolak | — | solo | - |
| MOVE-10 | Match `WaveActive`, sebagai peserta, satu jenis musuh di arena | Serang satu musuh sambil **berdiri** dan catat damage dari print `[CombatService]`; ulangi sambil **jongkok** dan sambil **lari** | **Angka damage-nya sama di ketiganya.** Sikap badan tidak menyentuh apa pun yang dihitung CombatService, dan baris ini yang menjaganya tetap begitu | — | solo | - |
| MOVE-11 | Match `WaveActive`, musuh sedang memukul pemain | Jongkok di sebelah musuh yang sedang memukul | Musuh **tetap memukul dengan damage yang sama**. Jongkok bukan mekanik menghindar | — | solo | - |
| MOVE-12 | Sedang jongkok atau lari, lalu biarkan musuh membunuh karakternya | Mati; tunggu respawn 5 detik | Karakter respawn **berdiri dengan stamina penuh**, dan sikapnya kembali walk tanpa perlu menekan apa pun | — | solo | - |
| MOVE-13 | Sesi di emulator layar sentuh Studio (atau perangkat sungguhan) | Cari cara lari, jongkok, atau dash | **Tidak ada.** Ketiganya keyboard; ini kekurangan yang diketahui, bukan GAGAL. Lihat T21 | — | solo | N/A |
