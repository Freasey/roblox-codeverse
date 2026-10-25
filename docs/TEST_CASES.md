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
> `luau-lsp analyze`, 183 unit test Lune, `rojo build`, dan — sejak harness
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
| `BLOK` | Tidak bisa dijalankan karena prasyaratnya belum ada (lihat kolom Jalankan?). Bukan lulus dan bukan gagal. |
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
| BOOT, MATCH, WAVE, CORE, COMBAT, SHOP, BOSS, HUD | hampir semuanya | sedikit | — |
| PROG | upgrade, beli, craft, reward dalam satu sesi | semua yang menyangkut "keluar, join lagi, masih ada" | — |
| MP | ready check, koin tim, 4 player | semua rejoin | — |
| DATA | DATA-01, DATA-09a, DATA-11 | sisanya | — |
| SEC | semuanya kecuali SEC-08 | — | SEC-08 |
| LB | — | — | semuanya |

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
`Lanes` berisi `Lane1` dan `Lane2` yang masing-masing punya tujuh waypoint
bernama `1` sampai `7` berurutan, dan `PlayerSpawn` adalah SpawnLocation.
Tidak perlu dibuat lagi.

`assets/Lobby.rbxmx` **belum ada** dan harus dibuat sekali — itu BOOT-04:

1. View → **Command Bar**.
2. Tempel seluruh isi `scripts/build_lobby.luau`, Enter.
3. Script memilih `Workspace.Lobby` otomatis. Klik kanan → **Save to File** →
   simpan sebagai `assets/Lobby.rbxmx` di root repo.
4. **Pastikan tipe filenya `.rbxmx`, bukan `.rbxm`.** Studio sering memilih
   `.rbxm` (binary) sebagai default, dan kalau itu yang kepilih dua hal gagal
   tanpa satu pun peringatan: file-nya kena aturan `*.rbxm` di `.gitignore` jadi
   tidak akan pernah ter-commit, dan mapping Rojo mencari `.rbxmx` jadi lobby-nya
   tidak akan pernah muncul. Ini sudah pernah kejadian sekali di project ini.
5. Commit filenya. **Tidak perlu menyentuh `default.project.json`** — mapping
   `Lobby` sudah ada di sana dalam bentuk
   `"$path": { "optional": "assets/Lobby.rbxmx" }`.
6. Restart `rojo serve`, Connect lagi, F5.

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
M1, tapi tidak satu pun dari baris itu jadi hijau karenanya.

### 3.1 Tidak perlu dites lagi di sini

Tiga hal di bawah **tidak perlu dites lagi** di sini. Dicatat supaya tidak ada
yang mengetesnya ulang, dan supaya kalau salah satunya pecah, jelas bahwa itu
regresi.

| Yang sudah terverifikasi | Di mana | Catatan |
|---|---|---|
| Lint, format, type check, 183 unit test Lune, `rojo build` | CI (`.github/workflows/ci.yml`) | Modul murni di `src/shared/Modules` sudah punya test: pembagian musuh per wave jumlahnya persis `Balance.enemyCount`, ambang boss cuma terpicu sekali, seluruh daftar penolakan toko dan progres, kurva level yang aman terhadap XP inf/NaN, dan material drop boss cocok dengan bahan craft. |
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

Run terakhir: **222 assertion lulus, 0 gagal, 17 dilewati, exit 0**, dari case
`boot`, `enemy_core`, `remote_reject`, dan `core_wave`. Yang 13 dilewati itu **bukan lulus**:
kedelapan handler remote C → S memanggil `RateLimit.check(player.UserId)`
sebelum memvalidasi argumennya, jadi tanpa Player mereka error karena nil player
sebelum jalur validasinya tersentuh — delapan SKIP untuk handler-nya, empat lagi
untuk varian argumen `RequestAction`, dan satu untuk `GetProfile` yang
memanggil `PlayerDataService.waitFor(player)`. Itu milik
[bagian 16](#16-keamanan-remote-sec) dan tetap harus dijalankan dari command bar
client.

Akibatnya untuk kolom Status: **tiga baris M1 dibuktikan seluruhnya dan sudah
`OK`** — WAVE-12, CORE-04, dan CORE-06. WAVE-11 sempat `OK` dan turun lagi ke
`-` setelah rancangan ulang arena: harapannya sekarang menuntut musuh yang
sampai **berhenti dan tetap ada** di cincin sekitar Core, dan bagian "bar HP-nya
masih di atasnya" tidak bisa dibuktikan tanpa client. Ketiga yang `OK` tidak
punya bagian client di kolom harapannya: yang diuji gerak musuh, pembagian lane,
HP Core, dan warna sebuah Part, semuanya milik server.

Sisanya tetap `-`, dan aturan di [bagian 1](#1-cara-memakai-dokumen-ini) berlaku
apa adanya: sebagian sesuai bukan `OK`. Dua yang paling dekat tapi tidak lolos
patut disebut, supaya tidak ada yang menaikkannya belakangan tanpa alasan baru:
**BOOT-06** (jalur lane 1 terbukti utuh, tapi lane 2 tidak disentuh dan flag
`DEBUG_VISIBLE_WAYPOINTS` memang untuk dilihat mata) dan **CORE-03** (HP berhenti
tepat di 0 dan `onDestroyed` menyala sekali, tapi transisi ke `Ended` dan
pembersihan arena ada di `MatchService.endMatch` yang tidak bisa dicapai tanpa
Player).

Untuk baris yang masih `-`, tabel di bawah menyebut bagian mana yang sudah
berdiri sendiri, supaya kerja tangannya lebih pendek dan bukan diulang dari nol.

| ID | Sudah dibuktikan harness | Masih butuh tangan |
|---|---|---|
| BOOT-02 | Baris `[MapService] Arena siap` isinya persis `2 lane, waypoint di-cache (Lane1=7, Lane2=7)` (`boot.arena.2lane`, `boot.arena.waypointTerCache`), dan sekarang juga **dihitung**: baris itu muncul tepat sekali (`boot.arena.barisSiapTepatSatu`), `[CodeVerse] server booting` tepat sekali — dua baris berarti rantai boot jalan dua kali (`boot.initServerJalanSekali`), warn `MapService` soal Arena nol kali (`boot.mapService.warnArenaTidakPernah`), dan tidak ada warn milik game yang teksnya identik muncul lebih dari sekali (`boot.tidakAdaWarnIdentikBerulang`) | Cuma satu hal: karakter muncul di `Arena/PlayerSpawn`. Bagian "tepat satu baris" sudah tidak perlu dihitung dengan mata |
| BOOT-06 | Jalur lane 1 **utuh dan berurutan**: satu musuh diikuti 100 sampel dari awal lane sampai Core, jarak terdekat ke tiap waypoint 1–7 di bawah 1.2 stud, dan nomor sampel saat kedekatan itu terjadi naik rapi `@1 @16 @33 @49 @66 @83 @99` (`waypoint.urutan1Sampai7`). Urutan nama waypoint datang dari sort **angka**, diuji dengan nama yang memuat "10" supaya sort string memberi hasil berbeda (`waypoint.urutanDariSortAngkaBukanString`) | Lane 2 tidak disentuh, dan flag `DEBUG_VISIBLE_WAYPOINTS` memang untuk dilihat mata. Nomor sampel yang naik sudah menutup lompat-balik dan zig-zag besar; yang tersisa untuk mata cuma kehalusan geraknya |
| WAVE-03 | Musuh `basic` berjalan mengikuti lane mendekat ke Core (`gerak.*`, sama dengan BOOT-06), dan HP-nya dipatok per wave: 100 / 115 / 160 / 235 di wave 1 / 2 / 5 / 10, dengan `maxHp == hp` (`skalaHp.*`) | Angka 8 stud/detik — harness jalan sekitar 8 Hz, jadi durasi absolut dari sana tidak bisa dibandingkan dengan playtest. Dan jumlah serangan sampai mati: menyerang butuh karakter |
| WAVE-07 | HP `basic` dipatok di empat wave sekaligus — 100 / 115 / 160 / 235 di wave 1 / 2 / 5 / 10, naik monoton, dan rasio wave 5 berbanding wave 1 tepat 1.600 (`skalaHp.*`). Patokannya dirangkai ulang dari `Enemies.basic.baseHp` dan `Balance.HP_PER_WAVE`, bukan dari `Balance.enemyHp` yang dipakai kode spawn itu sendiri — kalau patokannya fungsi yang sama, yang terbukti cuma 1 == 1 | Jumlah serangan sampai mati (4 di wave 1, 7 di wave 5): menyerang butuh karakter. Angka HP-nya sendiri tidak perlu dihitung lagi |
| CORE-01 | HP Core 1000 / 1000 dan Core belum hancur tepat setelah boot (`boot.coreHpPenuh`, `boot.coreTidakHancur`, `prasyarat.coreHpPenuh`) | Bahwa HUD menampilkannya: "Core 1000 / 1000" dan bar penuh adalah UI client |
| CORE-02 | **Kelima angka damage ke base per pukulan sudah dipatok**, semuanya lewat jalur asli `step()` → `enterAttackingBase()` → `CoreService.damage()`, dan terukur di engine persis `attackDamage * 0.2`: `basic` 5, `fast` 3, `tank` 12, Splitter 16, Locker 24 (`damageTipe.*.hpCoreTurunSebesarSatuPukulan`). **Pukulan yang berulang** juga dipatok, bukan cuma yang pertama (`damage.pukulanBerulang`, `.besarPukulanKedua`, `.pukulanKetigaDanSeterusnya`), begitu juga musuhnya yang **tetap hidup** setelah sampai (`damage.musuhTetapHidupSetelahSampai`, `.stateAttackingBase`, `.ringSlotTerisi`). Plus patokan yang menjawab pertanyaan yang mudah salah: `tank` di `hard` + 4 player tetap memukul 12 sementara HP-nya ikut naik jadi 1476 (`damageTipe.hard4Player.hpCoreTurunAngkaDasar`, `.hpIkutPengali`) — jadi "tidak ada pengali yang sampai ke entitas ini" tidak bisa jadi penjelasan alternatif | Cuma tampilan **bar Core** di HUD. Menggiring `tank` dan dua boss sampai ke Core — yang menuntut mencapai wave 5 dan 10 — sudah tidak perlu |
| CORE-03 | HP berhenti **tepat di 0** dan tidak pernah negatif walau di-damage tiga kali HP yang ada, `onDestroyed` menyala tepat sekali dengan HP sudah 0, damage dan heal sesudahnya ditolak, dan musuh yang sampai lewat jalur normal (`step` → `enterAttackingBase`) tetap memukul tanpa pernah menembus 0 — `isClear()` juga tetap false walaupun Core sudah hancur, jadi tidak ada yang bisa diam-diam membuatnya true sebagai jalan pintas (`habis.*`) | Transisi state ke `Ended` dan pembersihan arena: keduanya di `MatchService.endMatch`, yang cuma terpanggil dari handler `onDestroyed` saat state `WaveActive` atau `Intermission` — dan state tidak bisa keluar dari `Lobby` tanpa Player |

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
| `MatchCoins` | S → C | `number` (koin match tim) | — | — |
| `MatchResult` | S → C | `{ won, waveReached, coins, xp, materials, unlocked }` | — | — |
| `SetReady` | C → S | `boolean` | 2/detik | Hanya state `Lobby` dan `Countdown` (Countdown khusus untuk membatalkan) |
| `SelectLoadout` | C → S | `weaponId, difficultyId` | 2/detik | Hanya state `Lobby`; senjata dimiliki; tingkat terbuka |
| `Attack` | C → S | `Vector3` arah bidik | **20/detik** | `Vector3` yang bukan nol / NaN / inf; state `WaveActive`; pemain ada di `participants`; Core belum hancur; karakter hidup; cooldown senjata |
| `EnemyHit` | S → C | `{ id, damage, position }` | — | Untuk efek saja — **belum ada yang memakainya**, lihat [bagian 5](#5-yang-sudah-diketahui-sebelum-playtest) |
| `BuyShopItem` | C → S | `itemId` | 2/detik | Pemain ada di `participants`; state `Intermission`; toko tidak terkunci; item ada; jatah belum habis (**cuma `shop_barrier` yang masih punya jatah**); koin tim cukup untuk **harga sekarang**, bukan harga dasar |
| `ShopState` ★ | S → C | `{ open, locked, purchases, suspended }` | — | `suspended` = upgrade tim disandera Locker: pembeliannya masih tercatat di `purchases`, tapi pengalinya kembali ke dasar sampai boss mati |
| `BossState` ★ | S → C | `{ bossId, hp, maxHp, alive }` | — | Disiarkan paling cepat tiap 0.2 detik dan cuma kalau HP-nya berubah |
| `ShowInfoCard` | S → C | `bossId` | — | Dikirim hanya ke peserta match |
| `UpgradeWeapon` | C → S | `weaponId` | 2/detik | State `Lobby`; dimiliki; belum level maks; koin cukup |
| `BuyWeapon` | C → S | `weaponId` | 2/detik | State `Lobby`; belum dimiliki; `acquire.method == "buy"`; harga terdefinisi; koin cukup |
| `CraftWeapon` | C → S | `weaponId` | 2/detik | State `Lobby`; belum dimiliki; `acquire.method == "craft"`; material cukup |
| `ActionResult` ★ | S → C | `{ action, ok, reason }` | — | — |
| `GetProfile` | C → S (function) | tidak menerima argumen | 2/detik | Selalu mengembalikan data pemain yang memanggil; yang kena throttle dibalas `nil` |

**`GetLeaderboard` dari tabel bagian 3.6 sengaja BELUM didaftarkan.** Itu
milestone M6, dan `RemoteFunction` tanpa `OnServerInvoke` membuat client yang
memanggilnya **menggantung selamanya**. Jangan mengetesnya dan menyimpulkan bug:
`game.ReplicatedStorage.Remotes.GetLeaderboard` memang `nil` sekarang. Yang
dites adalah SEC-08, dan statusnya `BLOK` sampai `LeaderboardService` ada.

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

Level maksimum ketiganya 10. Damage level *n* = `baseDamage * (1 + 0.12*(n-1))` →
starter: 25, 28, 31, 34, 37, 40, 43, 46, 49, 52. Harga upgrade dari level 1 ke
10: **50, 67, 91, 123, 166, 224, 302, 408, 551** (total 1982 koin).

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

| id | Nama | Analogi | HP | Speed | `attackDamage` | `attackInterval` | Damage ke base / pukulan | Koin match | Bentuk graybox |
|---|---|---|---|---|---|---|---|---|---|
| `basic` | Pop-up Swarmling | Adware | 100 | 8 | 25 | 1.2 s | **5** | 5 | kubus oranye 3x3x3 |
| `fast` | Worm Runner | Worm | 60 | 16 | 15 | 0.8 s | **3** | 7 | balok hijau 2x2x4 |
| `tank` | Rootkit Hulk | Rootkit | 400 | 5 | 60 | 1.5 s | **12** | 15 | kubus ungu 6x6x6 |

**Boss** (`Bosses.luau`):

| id | Nama | Analogi | Wave | HP | `attackDamage` | `attackInterval` | Damage ke base / pukulan | Koin | Drop | Bentuk |
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

**Toko Match** (`ShopItems.luau`, urutan tampil dari `ShopItems.order`):

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

Sepuluh Exploit Patch berturut-turut memakan **6.647** koin, bukan 2.000 (harga
dasar x10). Yang 3 koin lebih rendah dari jumlah geometris eksaknya (6.650,58)
bukan salah hitung: harga dibulatkan ke bawah **setiap** pembelian, bukan sekali
di akhir, dan 6.647 itu yang benar-benar dipotong dari kolam. Koin diperiksa
terhadap harga **sekarang**, bukan harga dasar: koin tepat satu di bawahnya
ditolak, koin tepat sebesarnya diterima. Dan **tombol di panel toko menampilkan
harga sekarang** — tombol yang masih menulis harga dasar sementara koin terpotong
lebih banyak adalah GAGAL, bukan pembulatan.

**`shop_barrier` satu-satunya yang batasnya dipertahankan**, dan itu disengaja.
Empat item lain menambah **kemampuan**, yang tetap harus dipakai pemain; yang ini
menambah **waktu musuh tertahan**, 6 detik per pembelian di semua lane. Dua puluh
tumpuk berarti 120 detik tahan dan wave-nya lewat tanpa pemain menyentuh apa pun,
jadi harga yang naik tidak menolong — yang dibeli bukan kekuatan melawan wave,
tapi penghapusan wave itu sendiri. Alasan ini ada di komentar `ShopItems.luau`.
Lima Firewall Block memakan **820** koin, dan pembelian ke-6 ditolak — bukan
dengan "koin kurang", walaupun harganya kalau jatahnya ada akan 305.

**Hadiah koin match per wave** (`Balance.waveReward`). Ini **bukan** koin
permanen: dia masuk ke kolam koin match milik tim, kolam yang sama yang dipakai
Toko Match dan yang di-reset tiap `Countdown`. Rumusnya
`200 + 50 * (wave - 1)`, lalu **wave boss dikali 2**, lalu dikali pengali jumlah
pemain. Wave boss dikenali dari `bossId` di `Waves.luau`, bukan dari daftar nomor
wave — boss baru yang ditambahkan nanti ikut terkali dua tanpa menyentuh
`Balance.luau`. Kurvanya pada pengali x1:

| Wave | 1 | 2 | 3 | 4 | 5 (boss) | 6 | 7 | 8 | 9 | 10 (boss) | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Hadiah | 200 | 250 | 300 | 350 | **800** | 450 | 500 | 550 | 600 | **1300** | **5.300** |

| Jumlah pemain | Pengali | Total 10 wave |
|---|---|---|
| 1 | **x4** | **21.200** |
| 2 | **x2** | **10.600** |
| 3 atau lebih | **x1** | **5.300** |

Pengalinya tangga, bukan kurva: ambangnya di **3** pemain, jadi tim 3 orang dan
tim 4 orang sama-sama x1. Hadiah solo wave 1 = `200 * 4` = **800** koin, dan itu
160x koin satu `basic`. Pengali besar untuk solo masuk akal karena kolamnya milik
tim dan efek Toko Match berlaku untuk seluruh tim: tim berempat mendapat 4x nilai
dari tiap koin yang dibelanjakan, jadi x4 solo menormalkan daya beli per orang
alih-alih memberi keuntungan. Hadiah diberikan **juga untuk wave terakhir**
(wave 10), sebelum match dinyatakan menang. Tiap pemberian mencetak satu baris di
Output server: `[ShopService] hadiah wave N: X koin tim, kolam jadi Y`.

**Kesulitan** (`Difficulties.luau`): `normal` hpMult 1.0 / rewardMult 1.0, terbuka
default. `hard` hpMult **1.8** / rewardMult **1.6**, terbuka setelah first clear
`normal`.

**Konstanta lain** (`Balance.luau`): Core HP 1000. Maks musuh aktif sekaligus
**40**, sisanya masuk antrian. Jeda antar spawn 0.9 detik. Countdown 10 detik,
Intermission 20 detik, layar hasil 10 detik. Toleransi uji kena: melee radius
+5 stud di luar `range` dengan kerucut `cos >= 0.2` (~78 derajat setengah sudut),
ranged silinder radius 5 stud di sekitar garis bidik.

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

Sejak itu dua hal berubah besar: perilaku musuh (`docs/ARENA_REDESIGN.md` bagian
4 dan 5) dan ekonomi koin match (bagian 6). Langkah 1 sampai 4 sudah ter-commit.
Lima akibatnya **pasti** terlihat salah waktu dimainkan padahal benar — satu di
antaranya terlihat seperti game yang menggantung, dan satu lagi seperti harga
toko yang berubah sendiri. Itu
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
| T3 | **`ActionResult` untuk `BuyShopItem` tidak ditampilkan di mana pun.** Satu-satunya yang mendengarkan `ActionResult` adalah `LobbyController`, dan panel lobby disembunyikan di luar state `Lobby`/`Countdown`. | `ShopController` punya pendengarnya sendiri dan menampilkan alasannya di baris status panel toko. Dua-duanya menyaring lewat `payload.action` supaya tidak saling menampilkan balasan milik panel lain. Pesannya ditahan 4 detik dengan penanda waktu: `MatchState` dikirim tiap 0.2 detik dan tiap paketnya memanggil `render()`, jadi tanpa penahan itu pesan hilang sebelum selesai dibaca — termasuk yang di `LobbyController`, yang selama ini memang tidak pernah terbaca. | Penolakan pembelian terlihat pemain **di setiap kondisi yang bisa dia capai dengan mengklik**: saat panel terlihat (`Intermission` atau toko terkunci). Penolakan di luar itu (SHOP-07 di `WaveActive` biasa, SHOP-08 di `Lobby`, SHOP-13 bukan-peserta) cuma bisa dipicu lewat remote manual — tidak ada tombol di sana — jadi baris-baris itu tetap memakai listener di command bar. |
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

Lima baris di bawah datang dari dua perubahan yang berbeda, dan dua-duanya cuma
masuk akal kalau mekanisme sebelumnya dibaca dulu.

**Perubahan pertama — musuh yang lolos.** **Dulu** musuh yang mencapai ujung lane
men-damage Core sekali sebesar `coreDamage` lalu dihapus dari arena; kebocoran
berarti kehilangan HP satu kali, dan arena **dijamin** bersih cepat atau lambat.
**Sekarang** musuh yang mencapai ujung lane berhenti di base, mengambil satu slot
cincin di sekitar Core, tetap hidup, dan memukul tiap `attackInterval` detik
sampai pemain membunuhnya — dan musuh juga bisa memukul dan membunuh pemain.
Dua jaminan lama hilang karena itu, dan keduanya hilang **dengan sengaja**;
akibatnya T8, T9, dan T10.

**Perubahan kedua — ekonomi koin match.** **Dulu** koin match cuma datang dari
musuh yang mati, 5 sampai 15 per musuh, dan seluruh isi toko dibatasi jumlah
pembelian: harga satu item tidak pernah berubah, dan tiap tombol memuat sisa
jatahnya. **Sekarang** tiap wave yang selesai memberi hadiah koin tim yang
beberapa kali lebih besar daripada seluruh koin musuh wave itu, dan empat dari
lima item toko tidak punya jatah lagi — yang membatasinya harga yang naik x1.25
tiap kali item yang sama dibeli. Keduanya satu paket: hadiah besar tanpa harga
yang naik berarti toko habis diborong di wave 3-4, dan harga yang naik tanpa
hadiah besar berarti pembelian kedua tidak akan pernah terjangkau. Itu T11 dan
T12.

Angka untuk keduanya ada di [bagian 4.2](#42-angka-patokan).

| # | Perilaku | Kenapa begitu |
|---|---|---|
| T8 | **Wave tertunda selama masih ada musuh hidup di base, dan tidak ada batas waktunya.** Nomor wave tidak naik, state tetap `Bertahan!`, `Intermission` dan panel Toko Match tidak muncul, sementara bar Core terus turun satu langkah tiap interval pukulan. Bisa berlangsung selama pemain membiarkannya. | `WaveService.isWaveClear()` tetap menuntut nol musuh aktif dan nol antrian, dan jaminan bahwa itu pasti tercapai sudah tidak ada. Tidak ditambal dengan "musuh di base tidak dihitung" (rancangan bagian 5): kebocoran jadi menghukum dua kali — HP Core dan waktu belanja — tanpa satu aturan tambahan. **Ini bukan hang dan bukan sinyal `onAllClear` yang hilang.** Bedakan dari hang yang sesungguhnya dengan satu pertanyaan: apakah masih ada musuh hidup di arena, termasuk yang berdiri menempel di Core? Kalau ada, itu T8. Kalau arena benar-benar kosong dan state tetap `WaveActive` lebih dari satu detik, itu bug — jaring pengaman `WaveService` memeriksanya dua kali per detik. Dan T8 tidak bisa menggantung permanen: kalau pemain tidak mampu, Core habis dan match berakhir kalah. Dites WAVE-20. |
| T9 | **Pemain bisa mati, dan itu hal baru.** Sebelum ini tidak ada satu pun `TakeDamage` di `src/server`, jadi kematian pemain tidak punya konsekuensi apa pun dan tidak pernah terjadi karena musuh. Sekarang `fast` memburu pemain, dan tipe lain memukul pemain yang berdiri dalam 6 stud dari mereka. | Respawn 5 detik (`Balance.RESPAWN_SECONDS`, disetel eksplisit ke `Players.RespawnTime`), di `Arena/PlayerSpawn`, **tanpa sistem nyawa** — mati cuma berarti kehilangan waktu, dan waktu itu mahal karena musuh terus memukul base selama pemain tidak ada. Selama mati, `Attack` ditolak karena `CombatService.characterOrigin` mengembalikan nil untuk karakter mati (COMBAT-10), dan itu bukan rate limit yang salah. Dites COMBAT-16 dan COMBAT-17. |
| T10 | **Slot cincin tidak dipakai ulang, jadi cincinnya melebar selama match berjalan.** | Nomor slot (`ringSlotNext` di `EnemyService`) naik terus dan tidak pernah dipakai ulang: slot yang dibebaskan musuh mati tidak boleh langsung diberikan ke musuh lain, kalau tidak dua musuh bisa berdiri di titik yang sama persis saat yang pertama mati tepat sebelum yang kedua sampai. Akibatnya yang terlihat: dengan banyak kebocoran, cincinnya makin lebar dari Core — itu wajar, bukan bug. Dua musuh di titik yang **sama persis** tetap GAGAL tanpa pengecualian: `EnemyAI.ringSlotOffset` memberi tiap cincin radiusnya sendiri (10, 14, 18, 22, ...), jadi tidak ada dua nomor slot yang bisa berbagi tempat berapa pun banyaknya kebocoran. Dihitung ulang tiap match (`clearAll` me-reset nomornya). Dites WAVE-19, dan dipatok unit test `EnemyAI` lintas tiga cincin. |
| T11 | **Harga item toko berubah tiap kali dibeli, dan itu akan terlihat seperti bug.** Exploit Patch yang tadi 200 jadi 250, lalu 312, lalu 390. Tombolnya juga tidak lagi memuat "· sisa N" untuk empat dari lima item, jadi baris yang dulu berbunyi "200 koin · sisa 5 — ..." sekarang berbunyi "250 koin — ...". | Jatah pembelian (`maxPurchases`) diganti harga yang naik x1.25 per pembelian item yang sama; kurvanya di [bagian 4.2](#42-angka-patokan). Alasannya ada di hadiah per wave di baris berikutnya: dengan solo mengumpulkan 21.200 koin, toko yang seluruh itemnya dibatasi cuma bisa menyerap 3.450 — habis diborong di wave 3-4, lalu enam wave sisanya koinnya tidak ada gunanya. Harga yang naik membuat uang selalu punya tujuan. **Yang bukan bug:** angka di tombol berubah sendiri antar pembelian, dan empat item tidak punya "· sisa N" lagi. **Yang GAGAL:** tombol menulis satu angka tapi kolam terpotong angka lain — harga di tombol dan potongan koin dihitung dari sumber yang sama (`ShopRules.priceFor` dengan `purchases` sebelum dinaikkan), jadi selisih di antara keduanya berarti salah satu sisi memakai `def.cost`. Dites SHOP-20, dan `shop_barrier` yang batasnya memang dipertahankan dites SHOP-22. |
| T12 | **Saldo koin tim melompat ratusan sampai ribuan di detik wave selesai.** Solo wave 1 melompat dari 40 ke 840; wave 10 solo menambah 5.200 sekaligus. Jauh lebih besar daripada 5 koin per `basic` yang jadi satu-satunya sumber sebelum ini. | Hadiah koin match per wave, `200 + 50*(wave-1)`, wave boss x2, dikali pengali jumlah pemain (solo x4). Angka dan kurvanya di [bagian 4.2](#42-angka-patokan). Lompatannya memang ordenya segitu: hadiah satu wave sengaja beberapa kali lebih besar daripada seluruh koin musuh wave itu, karena koin musuh saja tidak pernah cukup untuk membeli apa pun yang berarti sejak wave awal. **Yang bukan bug:** saldo naik tanpa ada musuh yang mati, tepat saat state pindah ke `Intermission`. **Yang GAGAL:** tidak ada lompatan sama sekali, atau angkanya tidak cocok dengan baris `[ShopService] hadiah wave N: ...` di Output server. Hadiah masuk kolam koin **match**, jadi jangan mencarinya di koin permanen di panel lobby — di sana tidak akan pernah muncul. Dites SHOP-17 sampai SHOP-19 dan SHOP-23, SHOP-24. |

## 6. Boot dan map (BOOT)

Acuan: DEVELOPMENT_PLAN.md bagian 1.4 dan 3.4. Kelompok ini dijalankan **paling
dulu** — kalau BOOT gagal, tidak ada gunanya menjalankan yang lain.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| BOOT-01 | Rojo connected, place baru | F5, lihat Output server | `[CodeVerse] server booting (place N)` lalu `[CodeVerse] relative require OK — 10 wave tervalidasi`. Lalu baris siap: `[RewardService] siap`, `[MapService] Arena siap: ...`, `[MatchService] siap, 10 wave, countdown 10s, intermission 20s`, `[BossService] siap, 2 boss dengan mekanik yang dikenal`, `[ProgressionService] siap`. Tidak ada error | M0 | solo | - |
| BOOT-02 | `assets/Arena.rbxmx` ada dan ter-sync | F5, lihat Output server | `[MapService] Arena siap: 2 lane, waypoint di-cache (Lane1=7, Lane2=7)` — tepat satu baris, tanpa warn dari `MapService` soal Arena. Karakter muncul di `Arena/PlayerSpawn`, bukan di tengah lane | M1 | solo | - |
| BOOT-03 | Rename `assets/Arena.rbxmx` sementara supaya map tidak ada, restart `rojo serve`, F5 | Lihat Output server dan HUD | **Tepat satu** warn `[MapService] Arena tidak bisa dipakai: Workspace.Arena tidak ada. Gameplay tidak dijalankan. ...`. Tidak ada warn kedua dan tidak ada warn yang berulang tiap frame. HUD tetap muncul dengan "Wave 0 / 10", "Di lobby", bar Core penuh. Menekan Ready tidak memulai apa pun. **Balikkan nama filenya setelah test** | M1 | solo+EDIT | - |
| BOOT-04 | `assets/Lobby.rbxmx` belum ada | F5, lihat Output server | Satu warn `[MapService] Lobby tidak lengkap: Workspace.Lobby tidak ada. ...`. Gameplay tetap jalan; pemain muncul di spawn arena | M5 | solo | - |
| BOOT-05 | Buat `assets/Lobby.rbxmx` lewat `scripts/build_lobby.luau` (prosedur di [2.6](#26-map-arena-sudah-ada-lobby-belum)), sync, F5 | Lihat Output server | **Tidak ada** warn `[MapService] Lobby tidak lengkap`. Kalau masih ada, nama instance-nya tidak persis `SpawnLocation` dan `ReadyPad`. Lobby ada di Z = 400, jauh di belakang arena (lantai arena berakhir di Z = 120), dan dari lobby musuh di arena tidak terlihat | M5 | solo | - |
| BOOT-06 | Lobby sudah ada | Ubah `DEBUG_VISIBLE_WAYPOINTS = true` di `scripts/build_arena.luau`, jalankan di command bar, Save to File, sync, F5. Perhatikan jalur satu musuh dari spawn sampai Core | Musuh lewat waypoint **1 → 2 → 3 → ... → 7** dalam satu garis mulus menuju Core. **Tidak** zig-zag, tidak melompat, tidak berputar di satu waypoint. Balikkan flag debug-nya setelah test | M1 | solo+EDIT | - |

> Kalau lane-nya nanti ditambah sampai 10 waypoint atau lebih, **ulangi BOOT-06**.
> Di bawah 10 waypoint, sort string dan sort angka memberi hasil yang sama, jadi
> bug urutan baru bisa muncul setelah ada waypoint bernama "10".

## 7. Alur match dan state machine (MATCH)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| MATCH-01 | Server baru start, 1 player join | Lihat HUD dan posisi karakter | HUD atas menampilkan "Wave 0 / 10", "Di lobby", bar "Core 1000 / 1000". Panel **Lobby** muncul di kiri layar dengan tombol Ready di bawah. Tidak ada musuh di arena | M2 | solo | - |
| MATCH-02 | State `Lobby`, 1 player | Tekan tombol **Ready** di panel lobby | State jadi "Match mulai dalam · 10s" dan hitungannya turun tiap detik. Tombolnya berubah jadi "Batal siap". **`Lobby/ReadyPad` tidak melakukan apa pun** — dia cuma penanda posisi, tombol Ready yang sesungguhnya ada di UI | M2 | solo | - |
| MATCH-03 | State `Countdown` | Coba ubah senjata dan tingkat kesulitan dari panel lobby, lalu ulangi lewat `R.SelectLoadout:FireServer("weapon_starter", "normal")` dari command bar client | Panel lobby tetap terlihat tapi tombol kesulitan, "Pakai", dan "Upgrade/Beli/Craft" semuanya mati. Lewat remote: ditolak dengan `ActionResult` "Cuma bisa ganti loadout di lobby." dan `equippedWeapon` tidak berubah. Yang dipakai match adalah loadout yang terpilih sebelum Ready | M2 | solo | - |
| MATCH-04 | State `Countdown` | Tunggu timer habis | State jadi "Bertahan!" dan wave jadi 1. Musuh pertama muncul hampir langsung, lalu satu per ~0.9 detik, bergantian lane 1 dan lane 2. Serangan player aktif | M2 | solo | - |
| MATCH-05 | State `WaveActive` di wave 1 | Habiskan semua musuh wave itu | State jadi "Jeda — toko buka · 20s", musuh berhenti bergerak, panel **Toko Match** muncul di kanan layar | M2 | solo | - |
| MATCH-06 | State `Intermission` setelah wave 1 | Tunggu timer 20 detik habis | State kembali "Bertahan!", nomor wave jadi 2, musuh wave 2 spawn, panel toko **hilang** | M2 | solo | - |
| MATCH-07 | State `WaveActive`, jangan menyerang sama sekali | Biarkan musuh sampai ke Core sampai HP 0 | Layar hasil **"Core Server jebol"** muncul dengan wave tercapai. Output server mencetak `[MatchService] match selesai: kalah di wave N (normal), 1 peserta` dan `[CodeVerse] Core Server hancur` | M2 | solo | - |
| MATCH-08 | State `WaveActive` di wave 10 | Habiskan seluruh musuh wave 10 termasuk boss dan minion yang dipanggilnya | Tidak masuk `Intermission`; langsung layar hasil **"Core Server aman!"** | M2 | solo | - |
| MATCH-09 | Layar hasil muncul | Tunggu 10 detik | Layar hasil tertutup sendiri (layar ini **tidak punya tombol tutup** — dia mengikuti state server, bukan timer sendiri); state kembali "Di lobby"; wave kembali 0; player kembali ke area lobby | M2 | solo | - |
| MATCH-10 | Satu match sudah selesai, state `Lobby`, server **tidak** di-restart | Tekan Ready lagi dan mainkan match kedua | Match kedua jalan dari wave 1 dengan Core HP penuh, koin match 0, tidak ada musuh sisa, tidak ada turret sisa dari match sebelumnya. Ini kriteria M2 yang paling mudah bocor: state yang tidak di-reset (wave, participants, cooldown serangan, antrian spawn, pembukuan pembelian) baru kelihatan di match kedua | M2 | solo | - |
| MATCH-11 | State `Countdown` dan `Intermission` | Bandingkan timer di HUD dengan hitungan detik asli | Timer turun kira-kira satu per detik (server menyiarkannya tiap 0.2 detik, HUD membulatkan ke atas) dan berhenti saat state berganti. Tidak ada timer negatif dan tidak ada angka yang nyangkut | M2 | solo | - |
| MATCH-12 | State `WaveActive`, masih ada musuh hidup atau musuh di antrian spawn | Tunggu beberapa detik tanpa membunuh musuh | Nomor wave **tidak** naik dan state tidak pindah ke `Intermission` selama musuh wave itu belum habis | M2 | solo | - |
| MATCH-13 | State `WaveActive` | Tekan Ready, lalu `R.SetReady:FireServer(true)` dari command bar client | Tidak terjadi apa-apa; state tetap `WaveActive`; tidak ada error di Output server | M2 | solo | - |
| MATCH-14 | Dua match selesai berurutan tanpa restart server | Lihat layar hasil match kedua | Hasil match kedua dihitung dari match kedua saja (wave, koin, material), tidak menumpuk hasil match pertama | M2 | solo | - |
| MATCH-15 | State `Countdown`, hitung mundur masih jalan | Tekan **"Batal siap"** | Hitung mundur berhenti dan state kembali "Di lobby". Match tidak dimulai | M2 | solo | - |
| MATCH-16 | Match di server live, dua pemain Ready sehingga masuk `Countdown` | Pemain ketiga join saat hitung mundur masih jalan | Hitung mundur **dibatalkan** dan state kembali `Lobby` — pemain baru otomatis belum Ready, jadi syarat "semua pemain di server siap" tidak lagi terpenuhi. Lihat [tabel keputusan M2](#202-keputusan-m2). Berkode `LIVE` karena sesi Clients and Servers di Studio memulai semua client berbarengan; tidak ada cara menambah pemain di tengah sesi | M2 | LIVE | - |

## 8. Wave dan spawn (WAVE)

Acuan: DEVELOPMENT_PLAN.md bagian 1.3, 3.4, 3.5.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| WAVE-01 | Match baru mulai, solo | Amati musuh wave 1 | **Hanya `basic`** (kubus oranye) — itu seluruh komposisi wave 1 di `Waves.luau` — sebanyak 8 buah. Output server mencetak `[WaveService] wave 1: 8 musuh biasa di 2 lane, 1 player` | M2 | solo | - |
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
| WAVE-12 | Arena 2 lane | Amati spawn selama satu wave | Musuh datang dari kedua lane **bergantian satu-satu** (lane dibagikan round-robin, bukan acak), bukan menumpuk di satu lane | M1 | solo | OK |
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
| CORE-05 | State `Intermission`, HP Core sudah berkurang, koin tim ≥ 150 | Beli **Hotfix** | HP Core naik **150** (15% dari 1000) **langsung saat dibeli**, bukan di wave berikutnya; tidak pernah melebihi 1000. Kalau Core sudah penuh, saldo tetap terpotong dan bar tidak berubah — itu benar, bukan bug | M3 | solo | - |
| CORE-06 | Match berjalan, HP Core turun bertahap | Perhatikan warna Part Core di arena | Warnanya bergeser dari warna asli ke merah seiring HP-nya turun, jadi kondisi Core terlihat tanpa melihat HUD | M1 | solo | OK |

## 10. Combat (COMBAT)

Acuan: DEVELOPMENT_PLAN.md bagian 3.7.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| COMBAT-01 | State `WaveActive`, `weapon_starter` ter-equip, musuh di depan karakter dalam 17 stud | Klik kiri | Musuh terkena: **bar HP-nya turun**. Tidak ada efek hit dan tidak ada angka damage — itu M7 (`FxController`), dan `EnemyHit` diterima client lalu dibuang (keputusan T4). Bar HP turun adalah satu-satunya umpan balik yang benar sekarang | M1 | solo | - |
| COMBAT-02 | Musuh HP tinggal sedikit | Serang sampai HP-nya 0 | Musuh hilang dari arena tanpa sisa model; angka "N koin tim" di HUD naik sesuai tipe musuh (`basic` +5, `fast` +7, `tank` +15) | M1 | solo | - |
| COMBAT-03 | Musuh **di belakang** karakter, atau lebih dari 17 stud di depan | Klik kiri | Tidak ada damage ke musuh itu; tidak ada error di Output server. Kerucut melee ~78 derajat setengah sudut dengan jangkauan `range` 12 + 5 stud toleransi | M1 | solo | - |
| COMBAT-04 | State `WaveActive`, musuh di depan | Klik secepat mungkin, jauh lebih cepat dari cooldown 0.5 detik | Damage yang masuk mengikuti cooldown senjata (maksimal ~2 kali per detik), bukan kecepatan klik. **Server yang menolak kelebihannya**, dengan toleransi 50 ms untuk jitter jaringan. Serangan berlebih diabaikan tanpa error | M1 | solo | - |
| COMBAT-05 | Network Simulation **Bad Internet** atau **Terrible**, musuh `fast` sedang bergerak | Serang musuh `fast` yang berjalan 10 kali sambil membidik ke arahnya | Minimal 8 dari 10 kena. Sesekali tidak kena itu normal; **sering** tidak kena berarti toleransinya masih terlalu ketat. Kalau gagal, naikkan `Balance.MELEE_RADIUS_BONUS` — **jangan** mencari bug di `HitTest`, karena penyebabnya memang latensi, bukan geometri | M1 | LAG | - |
| COMBAT-06 | Network Simulation masih aktif, `weapon_ranged` ter-equip | Tembak musuh `fast` yang bergerak 10 kali | Sebagian besar kena: yang dipakai **silinder radius 5 stud di sekitar garis bidik**, bukan garis setebal nol. (Bagian 3.7 menyebut "spherecast"; yang diimplementasikan silinder, dan itu memenuhi maksudnya) | M5 | LAG | - |
| COMBAT-07 | `weapon_ranged` dimiliki dan ter-equip, musuh sekitar 40-55 stud jauhnya | Bidik dan serang | Musuh jauh terkena damage tanpa perlu mendekat (`range` 60 stud) | M5 | solo | - |
| COMBAT-08 | `weapon_ranged` ter-equip, musuh **jelas** di luar 60 stud — lebih dari 5 stud melewati batas | Bidik dan serang | Tidak ada damage; tidak ada error. Proyeksinya di-clamp di 60 stud, jadi musuh yang cuma beberapa stud melewati batas masih bisa kena silinder radius 5 — itu toleransi yang disengaja, bukan bug | M5 | solo | - |
| COMBAT-09 | `weapon_boss_a` sudah di-craft dan ter-equip, tiga musuh **sejajar di garis bidik** (bukan sekadar berkerumun) | Bidik melewati ketiganya dan serang sekali | Sampai **3 musuh** kena dalam satu serangan, dipilih yang paling dulu dilewati garis bidik (`projectiles = 3`). Bukan "membelah jadi 3 proyektil" — yang diimplementasikan adalah satu silinder bidik yang mengenai maksimal 3 musuh | M5 | solo | - |
| COMBAT-10 | Karakter player mati / sedang respawn saat `WaveActive` | Coba menyerang | Serangan ditolak server (origin tidak ada kalau Humanoid mati); tidak ada damage; tidak ada error | M1 | solo | - |
| COMBAT-11 | State `Lobby` atau `Intermission` | Coba menyerang lewat klik, lalu lewat `R.Attack:FireServer(Vector3.new(0, 0, 1))` dari command bar client | Tidak ada damage ke musuh mana pun; server menolak karena state salah; tidak ada error | M2 | solo | - |
| COMBAT-12 | `weapon_starter` level 1, lalu di-upgrade ke level 5; `basic` di wave 2 di dua kondisi itu | Hitung serangan untuk membunuh satu musuh | Level 1 (25 damage) = **5** serangan, level 5 (37 damage) = **4** serangan. Kurva damage upgrade terasa di match | M5 | solo | - |
| COMBAT-13 | `weapon_starter` ter-equip, beberapa musuh berdekatan di depan | Serang sekali | **Hanya satu** musuh yang kena, yang terdekat (`projectiles = 1`). Serangan yang mengenai beberapa musuh sekaligus adalah milik `weapon_boss_a` (COMBAT-09), bukan starter | M1 | solo | - |
| COMBAT-14 | State `Intermission` (panel toko terbuka) dan `Lobby` (panel lobby terbuka) | Klik tombol di panel itu, lalu amati Output server dan HP musuh | Kliknya tidak memicu serangan. Catatan: di v1 ini **tidak bisa benar-benar membuktikan apa pun**, karena di kedua state itu `Attack` sudah ditolak gerbang state, dan selama `WaveActive` tidak ada satu pun tombol UI yang terlihat. Penjaga "input yang sudah dipakai UI tidak diteruskan" memang ada di `InputController`, tapi baru bisa diuji sungguhan setelah M7 menambah tombol UI yang aktif di tengah wave. Dicatat supaya tidak lupa diulang saat itu | M3 | solo | - |
| COMBAT-15 | State `WaveActive`, musuh di depan | **Tahan** tombol kiri, jangan klik berulang | Serangan terkirim terus selama tombol ditahan (client mengirim 8 kali per detik, server menerapkan cooldown senjata). Tidak perlu mengklik berkali-kali | M1 | solo | - |
| COMBAT-16 | Wave 2 atau lebih (komposisinya berisi `fast`), karakter HP penuh 100, **jangan menyerang sama sekali** | Berdiri di dekat lane sampai satu `fast` datang mengejar, biarkan dia memukul sampai karakter mati, lalu hitung detik sampai karakter kembali | Bar HP karakter turun **15 tiap 0.8 detik** — pukulan pertama jatuh begitu `fast` masuk 6 stud, tidak menunggu interval — dan karakter **mati setelah 7 pukulan**, sekitar 4.8 detik. Karakter kembali **5 detik** sesudahnya (`Balance.RESPAWN_SECONDS`) di `Arena/PlayerSpawn` dengan HP penuh 100, **tanpa** kehilangan nyawa, koin tim, atau progres apa pun — tidak ada sistem nyawa di v1. Selama mati, klik tidak men-damage musuh mana pun dan Output server tidak mengeluarkan error (COMBAT-10). Musuh yang membunuh kita **melepas targetnya** dan kembali berjalan ke base, tidak menunggu di tempat kita mati. Sementara kita mati, musuh di base **terus memukul Core** — bar Core tetap turun selama 5 detik itu | M1 | solo | - |
| COMBAT-17 | Satu tipe per percobaan, karakter HP penuh 100, jangan menyerang. `tank` butuh wave 4; dua boss butuh wave 5 dan 10 (atau pindahkan `bossId` sementara) | Berdiri dalam 6 stud dari musuh itu dan hitung pukulan sampai karakter mati | Jumlah pukulannya tetap dan bisa dihitung: `basic` **4** (25 per pukulan tiap 1.2 s), `fast` **7** (15 / 0.8 s), `tank` **2** (60 / 1.5 s), Splitter **2** (80 / 2.0 s), Locker **1** (120 / 2.0 s — satu pukulan dari HP penuh langsung mematikan). Angka ini **tidak** berubah di `hard` dan tidak berubah dengan jumlah player: `attackDamage` tidak dikali pengali difficulty, cuma HP musuh yang dikali. `basic` dan `tank` memukul **dari tempatnya berdiri di lane** tanpa mengejar (WAVE-18) | M1 | solo (atau solo+EDIT untuk boss) | - |

## 11. Toko Match (SHOP)

Acuan: DEVELOPMENT_PLAN.md bagian 3.6 dan M3. Harga, kurva harga yang naik, dan
hadiah koin per wave ada di [bagian 4.2](#42-angka-patokan).

Dua hal berubah di sini sejak langkah 4 rancangan ulang arena, dan keduanya
membuat baris yang menyebut "jatah" perlu dibaca ulang. **Harga naik x1.25 tiap
kali item yang sama dibeli**, dan batas jumlah pembelian dihapus untuk empat dari
lima item — `shop_barrier` satu-satunya yang masih dibatasi 5. Dan **tiap wave
yang selesai memberi hadiah koin tim** yang jauh lebih besar daripada koin musuh:
solo wave 1 = 800 koin. Jadi saldo yang dipakai baris-baris di bawah jauh lebih
mudah terkumpul daripada yang dibayangkan waktu baris itu ditulis, dan harga yang
tertulis di satu baris cuma berlaku kalau item itu **belum pernah dibeli** di
match yang sama. Dua perilaku itu dijelaskan sebagai T11 dan T12 di
[bagian 5.3](#53-perilaku-baru-yang-akan-terlihat-seperti-bug).

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| SHOP-01 | State `Intermission` | Lihat panel Toko Match di kanan layar | Lima item **dalam urutan ini**: Exploit Patch (200), Overclock (200), Hotfix (150), Firewall Block (100), Scanner Turret (250). Urutannya dari `ShopItems.order` — kalau berubah-ubah tiap kali client dibuka, daftar itu tidak dipakai. Header menampilkan "N koin tim", dan angkanya naik setiap musuh mati selama wave berjalan **dan melompat sekali saat wave selesai** (hadiah per wave, SHOP-17). Hanya **Firewall Block** yang memuat "· sisa N" — empat item lain tak terbatas, jadi barisnya berbunyi "200 koin — ..." tanpa sisa. Baris yang memuat "· sisa N" untuk kelima item berarti jatah yang sudah dihapus masih dipakai | M3 | solo | - |
| SHOP-02 | State `Intermission`, koin ≥ 200, dan Exploit Patch **belum pernah dibeli** di match ini | Beli **Exploit Patch**, lanjut ke wave berikutnya, hitung serangan untuk membunuh satu `tank` | Koin turun 200 — itu harga pembelian **pertama**; yang kedua 250 dan seterusnya naik x1.25 (SHOP-20). Damage semua pemain naik **+10% linear** (bukan berlipat): satu pembelian 1.1x, lima pembelian 1.5x — bukan 1.61x. Paling mudah diukur di `tank` karena HP-nya besar. Di `basic` wave 2, satu Exploit Patch belum mengubah jumlah serangan (tetap 5); tiga pembelian membuatnya 4 | M3 | solo | - |
| SHOP-03 | State `Intermission`, koin ≥ 200 | Beli **Overclock**, lanjut ke wave berikutnya | Jeda antar serangan terasa lebih pendek: cooldown turun **-8% linear per pembelian**, dengan lantai 0.4x. Tahan klik kiri dan bandingkan ritme bar HP musuh turun, sebelum dan sesudah beli | M3 | solo | - |
| SHOP-04 | State `Intermission`, HP Core sudah berkurang | Beli **Hotfix** | Lihat CORE-05: +150 HP langsung, tidak melebihi 1000 | M3 | solo | - |
| SHOP-05 | State `Intermission`, koin ≥ 100 untuk bagian pertama dan ≥ 281 untuk bagian kedua (pembelian ke-2 dan ke-3 berharga 125 dan 156). Penumpukan durasi dihitung **per jeda**, bukan per match, jadi pembelian dari jeda sebelumnya tidak ikut memperpanjang | Beli **Firewall Block** satu kali, lanjut ke wave berikutnya. Lalu ulangi dengan membeli **dua** kali | Dinding biru tembus pandang muncul di tengah **kedua** lane tepat saat wave berikutnya mulai, dan musuh di lane itu **berhenti bergerak** 6 detik, lalu jalan lagi. Dua pembelian menggandakan **durasi blokirnya** jadi 12 detik, bukan jumlah dindingnya — dan dindingnya hilang **tepat** saat musuh mulai jalan lagi, 12 detik juga. Kalau dinding hilang di detik 6 sementara musuh masih tertahan, temuan T5 kembali | M3 | solo | - |
| SHOP-06 | State `Intermission`, koin ≥ 250, dan Scanner Turret belum pernah dibeli di match ini | Beli **Scanner Turret**, lanjut ke wave berikutnya. Lalu beli turret kedua — harganya **312**, bukan 250 lagi | Balok hijau-kebiruan muncul mengelilingi Core (radius 26 stud). Saat wave jalan, dia menembak musuh terdekat sendiri — 12 damage tiap 1 detik, radius 70 stud — dan HP musuh turun tanpa kamu menyerang. Musuh yang mati karena turret tetap memberi koin **tim**. Turret kedua muncul di sudut berbeda, tidak menumpuk. Turret **tidak** menembak saat `Intermission` | M3 | solo | - |
| SHOP-07 | State `WaveActive`. Pasang listener dulu di command bar client: `R.ActionResult.OnClientEvent:Connect(print)` | `R.BuyShopItem:FireServer("shop_barrier")` | Ditolak dengan alasan **"Toko cuma buka saat jeda antar wave."**; koin tim tidak berubah; tidak ada efek item; tidak ada error di Output server. Alasannya cuma terlihat di listener, dan itu memang satu-satunya cara di state ini: di `WaveActive` biasa tidak ada panel yang terbuka, jadi tidak ada tombol yang bisa diklik. Yang ditampilkan di panel toko adalah penolakan yang bisa dicapai pemain — lihat SHOP-09 dan SHOP-10 | M3 | solo | - |
| SHOP-08 | State `Lobby`, listener `ActionResult` masih terpasang | `R.BuyShopItem:FireServer("shop_barrier")` | Ditolak, tapi alasannya **berbeda** dari SHOP-07: **"Kamu bukan peserta match ini."** — di Lobby `participants` sudah dikosongkan, dan pemeriksaan peserta jalan sebelum pemeriksaan state. Koin tidak berubah | M3 | solo | - |
| SHOP-09 | State `Intermission`, koin tim **kurang** dari harga item, dan Scanner Turret **belum pernah dibeli** di match ini — kalau sudah, harga di pesan penolakan bukan 250 lagi tapi harga sekarang (312, 390, ...) | Perhatikan tombol **Scanner Turret** (250), lalu coba klik, lalu ulangi lewat `R.BuyShopItem:FireServer("shop_turret")` | Tombolnya abu-abu dan **mengkliknya tidak mengirim apa pun**. Lewat remote: ditolak dengan "Koin tim kurang: butuh 250, ada N." — dan alasan itu **ikut muncul merah di baris status panel toko** selama 4 detik, lalu kembali ke "N koin tim". Koin tidak jadi negatif; item tidak aktif di wave berikutnya. Tombol yang harganya di bawah saldo kelihatan biru dan bisa diklik | M3 | solo | - |
| SHOP-10 | Wave dengan `boss_locker`, boss masih hidup | Lihat kanan layar saat Locker spawn, lalu `R.BuyShopItem:FireServer("shop_barrier")` dari command bar client, lalu kalahkan boss-nya | Saat Locker spawn, panel Toko Match **muncul walau masih `WaveActive`**, dengan baris status merah **"Dikunci — kalahkan boss-nya dulu"** dan seluruh tombolnya abu-abu. Output server mencetak `[Locker] toko dikunci, memanggil 3 basic tiap 8 detik`. `BuyShopItem` ditolak dengan **"Toko dikunci. Kalahkan boss-nya dulu."** — bukan "Toko cuma buka saat jeda antar wave." — dan alasan itu muncul di baris status panel toko. Setelah boss mati: Output server mencetak `[Locker] boss mati, upgrade tim dipulihkan`, dan panel toko hilang sampai `Intermission` datang | M4 | solo | - |
| SHOP-11 | Sementara pindahkan `bossId = "boss_locker"` ke wave 1 di `Waves.luau` **dan** ubah `wave = 1` di `Bosses.luau` — `Waves.validate()` memeriksa keduanya cocok dan akan mencetak warn saat boot kalau cuma satu yang diubah | Kalahkan `boss_locker` di wave 1, masuk `Intermission`, beli item | Toko buka normal dan pembelian berhasil — kunci dilepas saat boss mati. **Balikkan kedua file sebelum commit** | M4 | solo+EDIT | - |
| SHOP-12 | Satu match selesai setelah membeli **Exploit Patch 3x**, Overclock 1x, dan **Scanner Turret 2x**. Catat harga yang tertulis di tombolnya di jeda terakhir: Exploit Patch **390**, Overclock **250**, Scanner Turret **390** | Tekan Ready lagi, mulai match kedua, dan lihat panel toko di jeda pertama match itu | Saldo koin **0** saat hitung mundur match kedua (di-reset saat `Countdown`, bukan saat wave mulai, supaya pemain melihatnya sebelum wave pertama). Tiap tombol kembali ke **harga dasar**: Exploit Patch 200, Overclock 200, Hotfix 150, Firewall Block 100 · sisa 5, Scanner Turret 250 — bukan 390 / 250 / 390 dari match pertama. Harga di tombol dihitung dari pembukuan `purchases`, jadi harga dasar yang kembali adalah bukti paling langsung bahwa pembukuannya di-reset. **Tidak ada turret sisa** di sekitar Core. Buff damage dan attack speed tidak terbawa — kalau musuh wave 1 match kedua mati lebih cepat dari biasanya, pembukuan pembelian tidak di-reset | M3 | solo | - |
| SHOP-13 | Match sedang `WaveActive`, lalu masuk dengan pemain **baru** yang bukan peserta. Listener `ActionResult` terpasang di client pemain itu | Dari client pemain baru: `R.BuyShopItem:FireServer("shop_barrier")` | Ditolak dengan "Kamu bukan peserta match ini." — pemain yang ditahan di lobby tidak boleh membelanjakan koin tim | M3 | LIVE | - |
| SHOP-14 | State `Lobby` dan `WaveActive`, **tanpa** `boss_locker` di wave itu | Lihat kanan layar di dua state itu | Panel Toko Match **tidak terlihat** sama sekali di luar `Intermission`. Satu-satunya pengecualian adalah toko yang dikunci Locker, yang sengaja ikut menampilkan panelnya — lihat SHOP-10 | M3 | solo | - |
| SHOP-15 | Masuk wave Locker, **jangan bunuh boss-nya** — biarkan Core hancur. Setelah kembali ke lobby, tekan Ready lagi dan selesaikan wave 1 | Lihat panel toko di jeda setelah wave 1 match kedua, dan lihat baris state di HUD sepanjang match kedua | Toko **buka normal**, header menampilkan koin bukan "Dikunci". Baris state HUD **tidak** memuat "upgrade tim disandera" kapan pun di match kedua. Ini jalur yang paling mudah bocor, dan sekarang ada dua hal yang bisa bocor: kunci toko, dan sandera upgrade. Kalau keduanya cuma dilepas lewat kematian boss, pemain berikutnya main dengan toko terkunci atau dengan damage yang diam-diam kembali ke dasar — yang kedua jauh lebih sulit disadari. Ulangi juga dengan cara keluar lain: saat wave Locker berjalan, tutup semua client (match dibatalkan). Hasilnya harus sama | M4 | solo+EDIT | - |
| SHOP-16 | Match solo `normal` sampai wave 10 (`boss_locker`). Di `Intermission` setelah wave 8, beli **Exploit Patch tepat 5 kali** — 200 + 250 + 312 + 390 + 488 = **1.640** koin, dan tombolnya harus berakhir menampilkan **610** (harga ke-6). Dulu 5 adalah jatah maksimumnya; sekarang 5 cuma angka yang dipilih supaya pengalinya bulat **1,5x** dan hasilnya bisa dihitung di muka | Hitung serangan untuk membunuh satu `basic` tiga kali, dengan `weapon_starter` level 1: (a) saat **wave 9**, (b) saat **wave 10 dengan Locker hidup**, pada minion `basic` yang dia panggil, (c) setelah **Locker mati**, pada minion `basic` yang masih hidup. Saat (b), lihat juga harga di baris Exploit Patch di panel toko yang ikut muncul terkunci | Inilah mekanik Locker yang sebenarnya menggigit — analogi ransomware: dia menyandera yang sudah kamu miliki, bukan melarangmu berbelanja. Damage jadi 1,5x linear, jadi 25 per serangan jadi 37,5. (a) `basic` wave 9 punya 220 HP → **6** serangan, bukan 9. (b) minion `basic` wave 10 punya 235 HP → **10** serangan, persis angka "belum pernah upgrade sama sekali" di [bagian 4.2](#42-angka-patokan), dan baris state HUD memuat **"upgrade tim disandera"**. (c) `basic` yang sama → **7** serangan, dan teks itu hilang. Pembelian tidak hilang: selama Locker hidup, baris Exploit Patch di panel toko yang terkunci tetap menampilkan **610 koin** — harga pembelian ke-6, yang cuma bisa dihitung dari 5 pembelian yang masih tercatat. Kalau di situ tertulis **200**, yang disandera bukan cuma efeknya tapi pembukuannya juga, dan itu GAGAL | M4 | solo | - |
| SHOP-17 | Match solo `normal`, wave 1, belum membeli apa pun. Panel toko belum terlihat (masih `WaveActive`) | Habiskan seluruh **8** `basic` wave 1, catat angka "N koin tim" di header panel toko begitu panel itu muncul, dan baca Output server. Lalu habiskan wave 2 dan catat ulang. Terakhir, catat koin permanen di header panel lobby **sebelum** match dimulai dan lagi setelah match ini berakhir dengan cara apa pun | Selama wave 1 berjalan koin naik 5 tiap `basic` mati, jadi 8 musuh = **40** koin. Di detik wave dinyatakan bersih, Output mencetak satu baris: `[ShopService] hadiah wave 1: 800 koin tim, kolam jadi 840` — hadiahnya `200 * 4` karena solo dikali empat. Header panel toko yang muncul sesudahnya menampilkan **840 koin tim**, bukan 40. Wave 2: hadiahnya **1.000** (`250 * 4`), dan kolam naik tepat 1.000 di detik wave selesai, **di luar** koin musuh wave 2 yang sudah masuk satu-satu sebelumnya. Hadiah masuk kolam koin **match**, jadi koin permanen **tidak** ikut naik per wave: catat koin permanen di panel lobby sebelum match dan sesudahnya, dan selisihnya harus tetap mengikuti rumus akhir match (`10*wave + 50` kalau menang, `x rewardMult`) — ratusan, bukan ribuan. Kalau koin permanen ikut melompat per wave, hadiahnya masuk mata uang yang salah dan main solo jadi 4x lebih efisien per orang untuk farming | M3 | solo | - |
| SHOP-18 | Match solo `normal` sampai **wave 5** (`boss_splitter`). Catat hadiah wave 4 dan wave 6 juga | Baca tiga baris `[ShopService] hadiah wave N: ...` untuk wave 4, 5, dan 6 | Wave 4 = **1.400** (`350 * 4`), wave 5 = **3.200**, wave 6 = **1.800** (`450 * 4`). Wave 5 bukan 1.600: dia **dikali dua** karena punya boss, jadi `(200 + 50*4) * 2 * 4`. Yang dinilai bukan angka 3.200-nya saja tapi bentuk kurvanya — hadiah wave boss harus **dua kali** hadiah wave itu kalau boss-nya tidak ada, dan karena itu wave 5 lebih besar daripada wave 6 **dan** wave 7 (2.000) sekaligus. Wave boss dikenali dari `bossId` di `Waves.luau`, bukan dari nomor wave yang ditulis tangan. Tanpa memainkan lima wave: pindahkan `bossId = "boss_splitter"` ke wave 1 dengan prosedur di [bagian 12](#12-boss-boss), lalu hadiah wave 1 harus **1.600**, bukan 800. **Balikkan kedua file sebelum commit** | M3 | solo (atau solo+EDIT) | - |
| SHOP-19 | Match solo `normal` dimainkan sampai **menang** di wave 10. Baris ini ikut terbukti sendiri setiap kali satu match penuh dimainkan (WAVE-02, MP-03), jadi tidak perlu sesi sendiri | Habiskan Locker dan seluruh minionnya, lalu baca **dua baris terakhir** Output server berurutan | `[ShopService] hadiah wave 10: 5200 koin tim, kolam jadi Y` muncul **lebih dulu**, baru `[MatchService] match selesai: menang di wave 10 (normal), 1 peserta`. Hadiahnya `(200 + 50*9) * 2 * 4` = 5.200: wave terakhir juga wave boss, jadi dia hadiah **terbesar di seluruh match**. Yang GAGAL adalah baris `[ShopService]` yang **tidak muncul sama sekali** untuk wave 10 — wave terakhir yang menyatakan match menang lalu berhenti akan melewatkan hadiahnya tanpa satu error pun, dan yang hilang justru yang paling besar. Perhatikan bahwa kolamnya tidak bisa diperiksa di layar: panel toko sudah hilang di state `Ended`, jadi Output server satu-satunya buktinya | M3 | solo | - |
| SHOP-20 | State `Intermission` di jeda setelah wave 2, solo — kolam sudah di atas **1.200** koin (840 dari wave 1 ditambah 1.000 hadiah wave 2 dan koin musuhnya). Exploit Patch belum pernah dibeli di match ini | Beli **Exploit Patch empat kali berturut-turut**. Sebelum tiap klik, catat angka harga di barisnya; sesudah tiap klik, catat saldo "N koin tim" di header | Angka di baris Exploit Patch berjalan **200 → 250 → 312 → 390 → 488**, dan saldo turun persis sebesar angka yang tertulis **sebelum** klik — bukan 200 empat kali, dan bukan harga berikutnya. Total yang hilang dari kolam = **1.152**. Harga naik `x1.25` per pembelian, dibulatkan ke bawah tiap kali ([bagian 4.2](#42-angka-patokan)). Baris Overclock, Hotfix, Firewall Block, dan Scanner Turret **tidak berubah sama sekali** selama ini — harga satu item cuma dinaikkan pembelian item yang sama. Angka di tombol yang tidak cocok dengan potongan koin adalah GAGAL: keduanya dihitung dari fungsi yang sama, jadi selisihnya berarti satu sisi memakai harga dasar | M3 | solo | - |
| SHOP-21 | State `Intermission` di jeda setelah wave 5, solo — kolam di atas **4.100** koin | Beli melewati batas yang dulu berlaku untuk tiga item: **Exploit Patch 6 kali** (dulu maks 5), **Hotfix 4 kali** (dulu maks 3), **Scanner Turret 3 kali** (dulu maks 2) | Semuanya **diterima**. Tidak ada satu pun penolakan "Jatah ... sudah habis", dan tidak ada tombol yang mati karena jumlah. Harga pembelian terakhir tiap item: Exploit Patch ke-6 = **610**, Hotfix ke-4 = **292**, Scanner Turret ke-3 = **390**; totalnya 2.250 + 863 + 952 = **4.065** koin. Tiga baris itu juga **tidak** memuat "· sisa N" sama sekali — teks itu cuma ada di Firewall Block. Efeknya ikut: damage tim jadi **1,6x** (6 x +10% linear), Core dipulihkan 150 HP per Hotfix sampai mentok 1000, dan turret ketiga muncul di sudut ketiga mengelilingi Core tanpa menumpuk di atas dua yang sudah ada | M3 | solo | - |
| SHOP-22 | State `Intermission`, kolam di atas **850** koin, Firewall Block belum pernah dibeli di match ini. Listener `ActionResult` terpasang di command bar client | Beli **Firewall Block lima kali**, catat harga dan sisa di barisnya tiap kali. Lalu coba klik tombolnya, lalu `R.BuyShopItem:FireServer("shop_barrier")` | Lima pembelian pertama diterima dengan harga **100 → 125 → 156 → 195 → 244** (total **820**), dan teks sisanya turun **5 → 4 → 3 → 2 → 1 → 0**. Sesudah yang kelima tombolnya **abu-abu** dan barisnya memuat "· sisa 0"; mengkliknya tidak mengirim apa pun. Lewat remote, pembelian ke-6 **ditolak** dengan **"Jatah Firewall Block sudah habis (5)."** — bukan "Koin tim kurang", walaupun koinnya memang masih di atas harga ke-6 (305) — dan alasan itu muncul merah di baris status panel toko selama 4 detik. Kolam **tidak** terpotong. Ini satu-satunya item yang batasnya dipertahankan, dan alasannya di [bagian 4.2](#42-angka-patokan): yang dibeli bukan kekuatan melawan wave tapi waktu musuh tertahan, jadi 20 tumpuk = 120 detik dan wave-nya lewat tanpa pemain menyentuh apa pun | M3 | solo | - |
| SHOP-23 | Sesi **2 client**, keduanya Ready, `normal`, wave 1 | Habiskan wave 1 dan baca baris `[ShopService] hadiah wave 1: ...` di Output jendela server | Hadiahnya **400** koin, bukan 800: dua pemain dikali **x2**, bukan x4. Wave 1 dengan 2 player tetap 8 musuh (pembulatan ke bawah dari 8,5 — [bagian 4.2](#42-angka-patokan)), jadi koin musuhnya tetap 40 dan barisnya berbunyi `kolam jadi 440`. Angkanya **sama di kedua client**: kolam koin match satu, milik tim. Bandingkan dengan 800 di SHOP-17 — separuh hadiah per wave, tapi efek tiap koin yang dibelanjakan berlaku untuk dua orang | M3 | 2P | - |
| SHOP-24 | Sesi **4 client**, keempatnya Ready, `normal`, wave 1 | Habiskan wave 1 dan baca baris `[ShopService] hadiah wave 1: ...`. Lalu ulangi dengan **3 client** | 4 player: hadiahnya **200** koin — pengalinya **x1**, jadi hadiahnya persis rumus dasarnya. Wave 1 dengan 4 player ada 9 musuh, jadi koin musuhnya 45 dan barisnya berbunyi `kolam jadi 245`. 3 player: hadiahnya **juga 200**, bukan 266 — pengalinya tangga dengan ambang di **3 pemain**, jadi 3 dan 4 pemain diperlakukan sama, dan wave 1 juga 9 musuh di dua-duanya. Hadiah yang mengecil terus seiring jumlah pemain naik di atas 3 berarti pengalinya diimplementasikan sebagai pembagian, bukan tangga | M3 | 4P | - |

## 12. Boss (BOSS)

Acuan: CONCEPT.md tabel boss, DEVELOPMENT_PLAN.md M4.

> **Cara mengetes tanpa memainkan empat wave dulu:** sementara pindahkan
> `bossId` ke wave 1 di `Waves.luau` **dan** ubah `wave` boss itu di
> `Bosses.luau` ke 1. `Waves.validate()` memeriksa keduanya cocok, jadi kalau
> lupa mengubah salah satunya server akan mencetak warn saat boot. **Balikkan
> keduanya sebelum commit.** Baris yang butuh ini berkode `EDIT`.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| BOSS-01 | Match berjalan sampai wave 5 | Amati awal wave 5 | Kubus merah besar (9x9x9) muncul **lebih dulu** dari musuh biasa, di lane 1 — boss diantre sebelum musuh biasa dengan sengaja, karena mekanik membelah cuma bermakna kalau boss ada sejak awal wave. Panel bar HP boss muncul di bawah HUD utama bertulisan **"Splitter — Worm"** dan persentase HP. Persentase turun saat boss diserang, dan **tidak lebih sering dari 5 kali per detik** (disiarkan paling cepat tiap 0.2 detik dan cuma kalau angkanya berubah — kalau bar-nya berkedip tiap frame, dua pembatas itu tidak bekerja) | M4 | solo | - |
| BOSS-02 | `boss_splitter` hidup, HP masih di atas 66% | Serang boss sampai HP-nya turun melewati 66% | **4 musuh `fast`** muncul **di posisi boss saat itu**, menyebar melingkar sekitar 6 stud, dan langsung melanjutkan ke Core dari waypoint yang sama dengan boss — bukan dari awal lane. Boss tetap hidup | M4 | solo | - |
| BOSS-03 | `boss_splitter` HP di antara 66% dan 33% | Terus serang sampai HP melewati 33% | 4 `fast` lagi. Pembelahan di 66% **tidak terulang** — total hanya dua kali sepanjang hidup boss, berapa kali pun dia dipukul | M4 | solo | - |
| BOSS-04 | Sesi 2 client, keduanya Ready, kalahkan boss | Baca Output server dan `materials` dari kedua client lewat `R.GetProfile:InvokeServer().materials` | `[BossService] drop material_a x1 ke 2 peserta`, dan **kedua** pemain dapat material — bukan cuma yang menyerang paling banyak atau yang memberi pukulan terakhir | M4 | 2P | - |
| BOSS-05 | `boss_splitter` baru mati | Amati layar client | Bar HP boss hilang. **Kartu info malware** muncul di tengah layar: badge "KARTU INFO MALWARE", judul **"Worm"**, satu paragraf penjelasan, dan **tiga** butir cara mencegah — teksnya dari `Bosses.luau`. Bisa ditutup dengan tombol **Tutup**, dan hilang sendiri setelah 18 detik kalau dibiarkan. Gameplay lanjut normal selama kartu terbuka | M4 | solo | - |
| BOSS-06 | Match berjalan sampai wave 10 | Amati awal wave 10 | Kubus merah sangat besar (11x11x11) muncul, bar HP boss bertulisan **"Locker — Ransomware"** | M4 | solo | - |
| BOSS-07 | `boss_locker` hidup | Tunggu beberapa saat tanpa membunuh boss | Tiap **8 detik**, 3 musuh `basic` muncul **dari awal lane** — beda dari Splitter dengan sengaja: Locker memanggil bantuan dari luar, bukan memecah dirinya. Soal kunci tokonya lihat SHOP-10, soal sandera upgrade-nya lihat SHOP-16 | M4 | solo | - |
| BOSS-08 | `boss_locker` baru mati | Amati arena beberapa detik | Minion berhenti dipanggil; minion yang masih hidup tidak menambah minion baru. Output server mencetak `[Locker] boss mati, upgrade tim dipulihkan` | M4 | solo | - |
| BOSS-09 | `boss_locker` HP tinggal sedikit, wave 10 | Habiskan boss, lalu habiskan minion yang masih berjalan | `material_b` masuk ke data pemain (cek lewat `R.GetProfile:InvokeServer().materials` dari command bar client); kartu info "Ransomware" muncul; match berakhir **menang**. Wave 10 belum bersih sampai minion juga habis. Baris "Material: ..." di layar hasil ikut menyebut `material_b`, dan harus cocok dengan apa yang dilaporkan `GetProfile` | M4 | solo | - |
| BOSS-10 | Satu match dengan kedua boss dikalahkan sudah selesai, state `Lobby` | Buka panel lobby dan lihat baris Fork Bomb, lalu baca `R.GetProfile:InvokeServer().materials` | `material_a` dan `material_b` masing-masing bertambah 1 per boss, dan jumlahnya tetap setelah kembali ke lobby. Baris Fork Bomb menampilkan "craft: material_a N/5". **Sebelum place di-publish, material ini ada di memori saja dan hilang saat playtest di-stop** — itu bukan bug M4, lihat [kotak DataStore](#22-kotak-datastore--baca-sebelum-menyalahkan-kode) | M4 | solo | - |
| BOSS-11 | Playtest 4 player, wave dengan boss | Amati bar HP boss di keempat client sambil boss diserang | Persentase sama di semua client dan turun bersamaan — server satu-satunya sumber angkanya | M4 | 4P | - |
| BOSS-12 | `boss_splitter` sudah membelah dua kali dan masih ada musuh pecahan hidup | Habiskan boss-nya saja, lalu amati arena | Musuh pecahan **dibiarkan hidup**, dan wave **belum** dinyatakan bersih sampai mereka juga habis. Itu bagian dari mekaniknya: kalau pecahan dihapus saat boss mati, ambang 33% tidak ada konsekuensinya bagi pemain yang langsung membunuh boss sesudahnya | M4 | solo | - |
| BOSS-13 | Sesi 2 client, keduanya peserta. Tutup client ke-2 **sebelum** boss mati, lalu kalahkan boss | Join lagi dengan akun yang sama | Material-nya dibayarkan saat dia rejoin, dan Output mencetak `[BossService] material tertunda dibayarkan ke <nama>`. Dropnya tidak boleh hilang hanya karena dia sedang tidak di server pada detik boss mati | M4 | LIVE | - |
| BOSS-14 | `boss_splitter` HP penuh. Sementara naikkan `Weapons.weapon_starter.baseDamage` supaya satu serangan menurunkan HP boss dari ~70% ke ~20% | Serang boss sekali dengan damage besar itu | **8 musuh `fast`** muncul, bukan 4: dua ambang terlewati sekaligus dalam satu serangan. Ini kasus pinggir yang punya unit test, dan yang kalau salah membuat boss kehilangan satu fase tanpa ada yang error. Balikkan `Weapons.luau` setelah test | M4 | solo+EDIT | - |

## 13. Progres permanen dan data player (PROG)

Acuan: DEVELOPMENT_PLAN.md bagian 3.1, 3.5, M5.

> **Supaya tidak perlu memainkan 15 match untuk mengetes upgrade:** sementara
> ubah `Config.DEFAULT_DATA.coins` ke 50000 dan restart playtest. Balikkan sebelum
> commit.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| PROG-01 | Match dimenangkan di `normal` wave 10; catat koin dan XP sebelum match | Baca Output server, lalu layar hasil, lalu header panel lobby setelah kembali | Output: `[RewardService] <nama>: wave 10 menang, +150 koin, +300 xp, naik N level, membuka hard`. Header lobby naik **tepat 150 koin**, dan layar hasil menampilkan "Koin: +150" / "XP: +300" — **angka yang sama** dengan print server dan header. Tiga tempat itu harus cocok: kalau layar hasil bilang "+120 koin" tapi header naik 100, ada dua jalur yang menghitung berbeda. Kalau layar hasil menampilkan +0 sementara print server benar, temuan T1 kembali | M5 | solo | - |
| PROG-02 | Dua match di wave yang sama: satu kalah, satu menang | Bandingkan print `[RewardService]` kedua match | Match kalah lebih kecil: bonus menang adalah +50 koin dan +100 XP. Wave 4 kalah = 40 koin / 80 XP; wave 4 menang (kalau wave terakhir dipindah) = 90 koin / 180 XP | M5 | solo | - |
| PROG-03 | Match berakhir kalah di wave rendah (misal wave 2) | Baca print `[RewardService]` dan header lobby | Tetap dapat koin dan XP sesuai wave yang dicapai (wave 2 = 20 koin / 40 XP), bukan nol | M5 | solo | - |
| PROG-04 | XP player tinggal sedikit dari ambang level berikutnya (level 1 butuh 100 XP, level 2 butuh 125, dst) | Selesaikan satu match | Level naik; XP sisa dihitung benar (tidak hilang, tidak negatif); print `[RewardService]` memuat ", naik N level"; header lobby menampilkan level baru. Satu match penuh yang menang (300 XP) bisa menaikkan beberapa level sekaligus di awal | M5 | solo | - |
| PROG-05 | Catat `highestWave`, `matchesPlayed`, `wins` lewat `R.GetProfile:InvokeServer().stats` | Selesaikan satu match menang di wave tinggi, lalu satu match yang berakhir di wave lebih rendah | `matchesPlayed` +1 tiap match, `wins` +1 hanya saat menang, `highestWave` naik saat rekor baru dan **tidak turun** saat wave lebih rendah | M5 | solo | - |
| PROG-06 | Player belum pernah menang di `normal`; `clears` kosong; tombol **Hard (terkunci)** mati di panel lobby | Menangkan satu match di `normal` (wave 10 bersih), kembali ke lobby | Tombol **Hard** jadi aktif dan bisa dipilih. Print `[RewardService]` memuat ", membuka hard". Menangkan lagi di `normal`: print **TIDAK** lagi memuat "membuka hard" — kalau masih, daftar yang baru terbuka dibandingkan salah dan pemain akan melihat pesan itu setiap match selamanya | M5 | solo | - |
| PROG-07 | `hard` sudah terbuka | Pilih **Hard**, Ready, selesaikan satu match; bandingkan dengan match `normal` di wave yang sama | Musuh butuh lebih banyak serangan (hpMult 1.8 — lihat WAVE-09). Koin lebih besar: wave 10 menang di hard = **240 koin** vs 150 di normal (rewardMult 1.6). **XP sama, 300** — kesulitan menaikkan koin, bukan level | M5 | solo | - |
| PROG-08 | `weapon_starter` level 1, koin permanen ≥ 2000 | Tekan **Upgrade 50** berulang kali sampai level 10, catat harga tiap kali | Level naik 1 tiap tekan; damage di baris detail naik (25 → 28 → 31 → ...); harga naik **50, 67, 91, 123, 166, 224, 302, 408, 551**; koin di header turun sesuai harga; baris petunjuk menampilkan "Berhasil." sebentar. Di level 10 tombolnya jadi **"Level maks"** dan mati, dan `R.UpgradeWeapon:FireServer("weapon_starter")` ditolak dengan "Patch Wrench sudah level maksimum (10)." | M5 | solo | - |
| PROG-09 | Koin permanen **kurang** dari harga upgrade | Coba klik tombol upgrade, lalu ulangi lewat remote | Tombolnya mati dan kliknya tidak mengirim apa pun. Lewat remote: ditolak dengan "Koin kurang: butuh N, ada M." di baris petunjuk panel lobby. Level senjata tidak berubah; koin tidak jadi negatif | M5 | solo | - |
| PROG-10 | `weapon_ranged` belum dimiliki, koin ≥ 1500 | Tekan **Beli 1500** di baris Packet Rifle, lalu **Pakai**, lalu Ready dan masuk wave | Koin turun 1500. Baris jadi "Level 1/10 · damage 14 · jarak jauh", tombolnya berubah jadi "Upgrade 50", tombol "Pakai" jadi aktif. Judulnya bertanda **(dipakai)** setelah di-equip. Di wave, serangan mengenai musuh sampai 60 stud | M5 | solo | - |
| PROG-11 | `weapon_ranged` sudah dimiliki | `R.BuyWeapon:FireServer("weapon_ranged")` dari command bar client | Ditolak dengan "Packet Rifle sudah kamu miliki."; koin tidak berkurang lagi; level senjata tidak ter-reset | M5 | solo | - |
| PROG-12 | `material_a` ≥ 5, `weapon_boss_a` belum dimiliki. Satu boss men-drop 1, jadi butuh lima kali — atau sementara ubah `Weapons.weapon_boss_a.acquire.materials` ke `{ material_a = 1 }` | Tekan **Craft** di baris Fork Bomb, lalu **Pakai** | `material_a` berkurang 5; Fork Bomb jadi dimiliki di level 1 ("Level 1/10 · damage 30 · jarak jauh"); bisa di-equip dan serangannya mengenai sampai 3 musuh (COMBAT-09) | M5 | solo+EDIT | - |
| PROG-13 | `material_a` **kurang** dari 5 | Coba klik Craft, lalu ulangi lewat remote | Tombolnya mati. Lewat remote: ditolak dengan "Material kurang: material_a N dari 5."; material tidak berkurang; senjata tidak masuk | M5 | solo | - |
| PROG-14 | Player punya progres campur: koin, level, XP, senjata ter-upgrade, `weapon_ranged` dibeli, `weapon_boss_a` di-craft, `hard` terbuka, material sisa. **Catat semua angkanya** lewat `R.GetProfile:InvokeServer()` | Stop playtest, F5 lagi (atau di server live: keluar, tunggu semenit, join lagi) | Semua angka sama persis seperti sebelum keluar. Tidak ada field yang kembali ke default dan tidak ada yang dobel. **Ini test paling penting di dokumen ini** dan satu-satunya yang membuktikan dua lapis progres di CONCEPT.md benar-benar bekerja — dan dia **dijamin gagal** sebelum place di-publish | M5 | PUB | - |
| PROG-15 | Senjata tertentu ter-equip sebelum keluar | Keluar, join lagi, langsung mulai match | `equippedWeapon` masih senjata yang sama dan senjata itulah yang dipakai di match | M5 | PUB | - |
| PROG-16 | Player yang `stats.matchesPlayed`-nya 0 (atau naikkan `Config.DATASTORE_NAME` ke nama baru supaya datanya kosong) | Join dan mainkan satu match dari lobby | Data default terbentuk: `weapon_starter` level 1, 0 koin, hanya `normal` terbuka, Packet Rifle "Belum dimiliki — 1500 koin" dengan tombol mati, Fork Bomb "Belum dimiliki — craft: material_a 0/5". Panel **PANDUAN** muncul (HUD-05). Match bisa diselesaikan tanpa perlu beli apa pun | M5 | solo | - |
| PROG-17 | Match sedang berjalan (state apa pun selain `Lobby`) | `R.UpgradeWeapon:FireServer("weapon_starter")`, lalu `R.BuyWeapon:FireServer("weapon_ranged")`, lalu `R.CraftWeapon:FireServer("weapon_boss_a")` | Ketiganya ditolak: "Upgrade cuma bisa di lobby.", "Beli senjata cuma bisa di lobby.", "Craft cuma bisa di lobby." Koin dan material tidak berubah sama sekali | M5 | solo | - |
| PROG-18 | State `Lobby`, koin dan material cukup | `R.BuyWeapon:FireServer("weapon_boss_a")`, lalu `R.CraftWeapon:FireServer("weapon_ranged")` | Ditolak: "Fork Bomb tidak dijual dengan koin." dan "Packet Rifle tidak dibuat dengan material." Senjata craft tidak bisa dibeli dengan koin, dan senjata beli tidak bisa di-craft | M5 | solo | - |

## 14. Multiplayer dan rejoin (MP)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3 (aturan join dan rejoin), M6.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| MP-01 | 2 client, state `Lobby` | Tekan Ready di satu client saja, tunggu beberapa detik, baru Ready di client kedua | Countdown **tidak** mulai saat baru satu player Ready. Baris petunjuk di panel pemain yang sudah Ready berbunyi "Kamu siap. Menunggu pemain lain." Countdown mulai setelah **semua player di server** Ready | M6 | 2P | - |
| MP-02 | 4 client, state `Lobby` | Ready di keempat client | Countdown mulai setelah yang terakhir Ready; keempat player masuk arena saat `WaveActive` | M6 | 4P | - |
| MP-03 | 4 client, match mulai | Mainkan satu match penuh wave 1 sampai 10 termasuk kedua boss | Match jalan lancar sampai layar hasil; musuh dan boss terlihat sama di semua client; **tidak ada error di Output jendela server** | M6 | 4P | - |
| MP-04 | 4 client, state `WaveActive` | Satu player saja yang membunuh beberapa musuh | Angka "N koin tim" naik dan **sama di keempat client**, bukan hanya milik yang membunuh — koin match adalah satu kolam milik tim | M6 | 4P | - |
| MP-05 | 4 client, satu match selesai | Bandingkan print `[RewardService]` keempat player dan data permanen masing-masing | Setiap player dapat koin dan XP di datanya sendiri, dengan **jumlah yang sama** (dihitung dari wave yang dicapai), bukan satu kantong yang dibagi empat | M6 | 4P | - |
| MP-06 | 4 client, state `WaveActive` di wave 3 atau lebih; catat koin tim | Tutup satu jendela client, tunggu satu wave, lalu join lagi dengan player yang sama | Player itu masuk kembali ke arena (spawn di `Arena/PlayerSpawn`), bukan ditahan di lobby; Output mencetak `[MatchService] <nama> rejoin ke match berjalan`; HUD-nya menampilkan state, wave, dan HP Core terkini; koin tim tidak hangus | M6 | LIVE | - |
| MP-07 | Match sedang `WaveActive` dengan peserta yang sudah terdaftar | Join dengan player **baru** yang belum pernah ikut match itu | Player baru muncul di `Lobby/SpawnLocation` dan **tidak** dipindahkan ke arena; HUD-nya tetap menampilkan state dan wave yang berjalan supaya dia tahu match sedang jalan; `Attack`-nya ditolak server (tidak ada damage sama sekali) | M6 | LIVE | - |
| MP-08 | Player baru dari MP-07 masih di lobby | Tunggu match selesai sampai state `Lobby`, lalu tekan Ready bersama yang lain | Player baru bisa ikut match berikutnya secara normal | M6 | LIVE | - |
| MP-09 | 2 client, state `WaveActive`, keduanya peserta | Tutup client ke-2 di tengah wave, amati; lalu tutup client pertama juga | Setelah client ke-2 ditutup: match **terus jalan** untuk pemain pertama, tidak ada pembatalan. Setelah semua peserta keluar: Output mencetak `[MatchService] semua peserta keluar, match dibatalkan dan kembali ke Lobby`, state kembali `Lobby`, musuh dibersihkan, server tidak nyangkut di `WaveActive`. Join lagi setelah itu masuk lobby dan bisa mulai match baru. Pembatalan **bukan** kekalahan: `onMatchEnded` tidak ditembakkan, jadi tidak ada reward yang dihitung dua kali | M6 | 2P | - |
| MP-10 | 2 client, state `WaveActive` di wave 4 | Satu player keluar dan **tidak** kembali; biarkan match lanjut sampai selesai | Output mencetak `[RewardService] <nama>: wave 4 tidak selesai/kalah, +40 koin, +80 xp` **saat dia keluar** — tanpa bonus menang, tapi tetap dapat reward sesuai wave saat dia keluar. Player yang tinggal tetap bisa menyelesaikan match | M6 | 2P | - |
| MP-11 | 2 client, koin tim sudah terkumpul, state `Intermission` | Satu peserta disconnect lalu rejoin, lalu beli item di toko | Koin tim masih utuh setelah rejoin (tidak hangus dan tidak dobel); pembelian memakai koin yang sama | M6 | LIVE | - |
| MP-12 | 4 client, wave 10 dengan `boss_locker` dan minion | Amati Output jendela server selama wave 10 sampai layar hasil | Tidak ada error atau warning berulang; game tetap responsif | M6 | 4P | - |
| MP-13 | 2 client, `hard` terbuka untuk keduanya. Satu pemain memilih **Hard**, satu memilih **Normal** | Keduanya Ready, masuk wave 1, hitung serangan untuk membunuh satu `basic` | Match jalan di **Normal** — yang paling mudah di antara pilihan mereka. 4 serangan, bukan 8. Alasannya di [tabel keputusan M2](#202-keputusan-m2): `hard` harus dibuka per pemain, jadi aturan yang mengambil yang lebih sulit bisa memaksa pemain ikut match di tingkat yang belum dia buka | M6 | 2P | - |
| MP-14 | 2 client, state `Intermission`, kolam di atas **1.400** koin. Hotfix dan Firewall Block belum pernah dibeli di match ini | Pemain A membeli **Hotfix** tiga kali, lalu **Firewall Block** lima kali. Pemain B tidak menyentuh apa pun — cuma melihat panelnya | Saldo di layar pemain B **ikut turun**, dan sebesar harga yang naik: **150, 187, 234** untuk Hotfix. Harga di baris Hotfix di layar **B juga naik** mengikuti, jadi tombol B menampilkan 187 lalu 234 lalu **292** tanpa B membeli apa pun — pembukuan `purchases` dibagi tim, bukan per pemain, dan harga dihitung dari pembukuan itu. Lalu untuk Firewall Block: setelah pembelian **kelima**, tombol Firewall Block di layar **B juga mati** dan barisnya memuat "· sisa 0". Satu kolam, satu pembukuan, dua layar. Perhatikan bahwa Hotfix **tidak** bisa dipakai menguji jatah yang habis — jatahnya sudah dihapus, dan satu-satunya item yang masih dibatasi adalah Firewall Block | M3 | 2P | - |

## 15. Leaderboard (LB)

**Seluruh kelompok ini `BELUM`.** `LeaderboardService` belum ada,
`GetLeaderboard` belum didaftarkan di `Remotes.luau`, dan tidak ada papan di
lobby. Statusnya `BLOK` sampai M6 dikerjakan. Barisnya ditulis sekarang supaya
kriteria M6 punya test case dan supaya tidak ada yang lupa apa yang harus jalan.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| LB-00 | — | `print(game.ReplicatedStorage.Remotes:FindFirstChild("GetLeaderboard"))` dari command bar client | Setelah M6: bukan `nil`, dan `R.GetLeaderboard:InvokeServer("normal")` mengembalikan data tanpa menggantung. Sekarang: `nil`, dan itu **disengaja** — `RemoteFunction` tanpa `OnServerInvoke` membuat client yang memanggilnya menggantung selamanya | M6 | BELUM | - |
| LB-01 | API Services aktif; papan leaderboard ada di lobby | Selesaikan satu match di `normal` sampai wave tertentu, kembali ke lobby | Wave tertinggi player tercatat dan tampil di papan `normal` dengan nama player | M6 | BELUM | - |
| LB-02 | `hard` sudah terbuka | Selesaikan satu match di `hard` dengan wave berbeda dari catatan `normal` | Catatan `hard` dan `normal` terpisah; wave di `hard` tidak menimpa catatan `normal` dan sebaliknya | M6 | BELUM | - |
| LB-03 | Sudah ada catatan wave tinggi (misal wave 8) | Selesaikan match baru yang berakhir di wave lebih rendah (misal wave 3) | Catatan di papan tetap wave 8; tidak turun | M6 | BELUM | - |
| LB-04 | Papan terlihat di lobby, server tidak di-restart | Selesaikan match yang memecahkan rekor, kembali ke lobby | Papan ikut terupdate tanpa perlu restart server atau rejoin | M6 | BELUM | - |
| LB-05 | 2 client dengan wave tertinggi berbeda | Lihat papan dari kedua client | Urutan sesuai wave tertinggi (yang lebih tinggi di atas); angka tiap player benar | M6 | BELUM | - |

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
penolakan yang punya alasan yang bisa diberitahukan ke pemain (state salah, belum
dimiliki, koin kurang). Jadi "tidak ada `ActionResult`" bukan kegagalan.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| SEC-01 | State `Lobby`, lalu ulangi saat `WaveActive` | `R.SetReady:FireServer(nil)`, `FireServer(-1)`, `FireServer("true")`, `FireServer({})`, `FireServer()`, lalu `for _ = 1, 200 do R.SetReady:FireServer(true) end` | Ready hanya berubah untuk boolean yang sah, dan hanya saat `Lobby` atau `Countdown` (Countdown diizinkan khusus untuk **membatalkan**). Argumen lain diabaikan. Spam dibatasi **2 per detik** dan sisanya dibuang tanpa error; countdown tidak terpicu berulang | M6 | solo | - |
| SEC-02 | State `Lobby` | `R.SelectLoadout:FireServer(nil, nil)`, `FireServer(1, 2)`, `FireServer("weapon_tidak_ada", "normal")`, `FireServer("weapon_starter", "critical")`, `FireServer("weapon_ranged", "normal")` tanpa memilikinya, `FireServer("weapon_starter", "hard")` sebelum hard terbuka, `FireServer({}, {})`, lalu spam 200x | Loadout hanya berubah untuk senjata yang **dimiliki** dan tingkat yang **terbuka**. Dua baris terakhir yang bermakna membalas `ActionResult` dengan `ok = false` dan alasannya ("Senjata itu belum kamu miliki.", "Tingkat kesulitan itu belum terbuka.") dan **tidak** mengubah `equippedWeapon`. `"critical"` dan id yang tidak ada dibuang tanpa balasan — `critical` memang belum ada di v1. Spam dibatasi 2 per detik | M6 | solo | - |
| SEC-03 | State `WaveActive` sebagai peserta, lalu ulangi sebagai player yang bukan peserta | `R.Attack:FireServer()`, `FireServer(-1)`, `FireServer("depan")`, `FireServer(Vector3.new(0, 0, 0))`, `FireServer(Vector3.new(0/0, 0, 0))`, `FireServer(Vector3.new(1e9, 1e9, 1e9))`, `FireServer({})`, lalu `for _ = 1, 500 do R.Attack:FireServer(Vector3.new(0, 0, -1)) end` | Hanya `Vector3` dengan magnitude wajar yang diproses. Arah nol, NaN, dan inf ditolak sebelum dipakai. Arah ekstrem dinormalisasi jadi arah biasa, tidak membuat damage aneh dan tidak menjangkau musuh di luar `range`. Serangan dari player di luar `participants` ditolak. Spam dibatasi **20 per detik** di rate limit **dan** cooldown senjata di atasnya — musuh tidak mati lebih cepat dari ~2 serangan per detik dengan starter | M6 | solo | - |
| SEC-04 | State `Intermission`, lalu ulangi saat `WaveActive` dan `Lobby` | `R.BuyShopItem:FireServer()`, `FireServer(123)`, `FireServer("shop_tidak_ada")`, `FireServer({ id = "shop_barrier" })`, lalu spam 100x dengan id valid saat koin cuma cukup untuk satu | Hanya id yang ada di `ShopItems.luau` dan hanya saat `Intermission` yang diproses. Spam tidak membuat item terbeli berkali-kali melebihi koin (koin dipotong **sebelum** efeknya dijalankan, jadi tidak ada celah). Koin tim **tidak pernah negatif** dan **tidak berubah sama sekali** setelah semua percobaan yang ditolak. Kalau turun, ada jalur yang memotong koin sebelum validasinya lengkap. Dengan harga yang naik, spam itu punya cara baru untuk membuat kolam negatif: pembelian pertama lolos, lalu pembelian kedua diperiksa terhadap **harga dasar** sementara yang dipotong **harga sekarang** yang lebih besar. Jadi yang dinilai di sini bukan cuma "tidak negatif" tapi angkanya — setelah spam, sisa kolam harus persis saldo awal dikurangi harga pembelian yang benar-benar diterima | M6 | solo | - |
| SEC-05 | State `Lobby` | `R.UpgradeWeapon:FireServer()`, `FireServer(42)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_ranged")` tanpa memilikinya, lalu spam 200x dengan senjata milik saat koin cuma cukup untuk satu level | Hanya senjata yang dimiliki, belum level 10, dan koin cukup yang naik level. Spam tidak menaikkan beberapa level dengan bayar sekali. Koin permanen tidak negatif | M6 | solo | - |
| SEC-06 | State `Lobby`, `weapon_ranged` belum dimiliki | `R.BuyWeapon:FireServer()`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_starter")` (sudah dimiliki), `FireServer("weapon_boss_a")` (harus di-craft), lalu spam 100x `FireServer("weapon_ranged")` saat koin cuma cukup satu kali | Hanya senjata yang memang dijual, belum dimiliki, dan koin cukup yang masuk. Spam tidak memotong koin dua kali. Senjata craft-only tidak bisa dibeli dengan koin | M6 | solo | - |
| SEC-07 | State `Lobby`, `material_a` cukup untuk satu craft | `R.CraftWeapon:FireServer()`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_ranged")` (bukan senjata craft), lalu spam 100x `FireServer("weapon_boss_a")` | Hanya senjata craft yang resepnya terpenuhi yang masuk. Spam tidak menghasilkan dua senjata dan material tidak jadi negatif | M6 | solo | - |
| SEC-08 | — | Lihat LB-00. `GetLeaderboard` belum ada, jadi `R.GetLeaderboard:InvokeServer(...)` error di **client** sebelum menyentuh server | Setelah M6: mengembalikan data valid atau menolak dengan rapi (nil / tabel kosong), tidak pernah error; panggilan berlebih di-rate-limit dan tidak membanjiri OrderedDataStore | M6 | BELUM | - |
| SEC-09 | State apa pun | `R.RequestAction:FireServer()`, `FireServer(-1)`, `FireServer("aksi_tidak_ada")`, `FireServer({})`, `FireServer("claimDailyBonus")`, lalu spam 500x | Aksi yang tidak dikenal diabaikan tanpa error dan tanpa `ActionResult`. `"claimDailyBonus"` tidak memberi koin karena `lastLogin` baru di-set saat load, jadi selisihnya belum lewat 86400 detik — itu benar. Spam 500x **di-throttle 2/detik** — sisanya diabaikan tanpa error dan tanpa `ActionResult`, dan tidak ada perubahan data sama sekali | M6 | solo | - |
| SEC-10 | State apa pun, dua player di server | `R.GetProfile:InvokeServer()`, `InvokeServer(nil)`, `InvokeServer(-1)`, `InvokeServer(<UserId player lain>)`, lalu panggil 100x berturut-turut | Yang dikembalikan **selalu** data player yang memanggil — fungsinya tidak menerima argumen sama sekali, jadi apa pun yang dikirim diabaikan. Tidak pernah error. Pemanggilan 100x berturut-turut **di-throttle 2/detik**, dan yang kena throttle mengembalikan `nil` — bukan error, supaya client yang menunggu nilai balik tidak kena error yang tidak bisa dia tangani. Catatan: kalau data pemain belum siap, pemanggilan bisa menggantung sampai 90 detik lalu juga mengembalikan `nil` — itu batas yang disengaja, bukan hang, dan dari sisi client dua-duanya terbaca sama: `ProfileStore` tetap menunggu `DataLoaded` | M6 | solo | - |
| SEC-11 | 2 client, match berjalan | Dari satu client, spam seluruh remote C → S bergantian terus-menerus selama 30 detik | Server tetap responsif untuk client kedua (musuh tetap bergerak, HUD tetap update); pelaku di-throttle di **setiap** remote C → S; tidak ada error di Output server | M6 | 2P | - |
| SEC-12 | Match berjalan | Dari command bar client, ubah angka di salinan modul shared yang ter-replikasi ke client (misal `require(game.ReplicatedStorage.Shared.Modules.Weapons).weapon_starter.baseDamage = 9999`), lalu serang musuh | Damage yang masuk **tidak berubah** — server memakai salinan modulnya sendiri dan tidak pernah percaya angka dari client. Begitu juga harga di toko dan di panel lobby: mengubahnya di client cuma mengubah teks tombol, pembeliannya tetap divalidasi server | M6 | solo | - |
| SEC-13 | Match berjalan | Panggil `:FireServer()` pada remote yang arahnya **S → C**: `R.MatchState`, `R.MatchCoins`, `R.MatchResult`, `R.EnemyHit`, `R.ShopState`, `R.BossState`, `R.ShowInfoCard`, `R.ActionResult`, `R.DataLoaded`, `R.DataChanged` | Tidak terjadi apa pun dan **tidak ada error di Output server** — tidak ada satu pun dari remote itu yang punya `OnServerEvent` tersambung. Yang dicari di sini adalah remote S → C yang diam-diam dipakai dua arah | M6 | solo | - |
| SEC-14 | Inventaris, bukan percobaan | Bandingkan daftar remote C → S di `Remotes.luau` dengan registry `RateLimit` di tiap service dan di `init.server.luau` | Setiap remote C → S punya rate limit: `Attack` 20/detik; `SetReady`, `SelectLoadout`, `BuyShopItem`, `UpgradeWeapon`, `BuyWeapon`, `CraftWeapon`, `RequestAction`, `GetProfile` 2/detik. Tidak ada yang tertinggal — itu item M6 "Rate limit di semua remote". `GetLeaderboard` belum didaftarkan sama sekali (lihat LB-00), jadi dia belum termasuk hitungan ini | M6 | solo | - |

## 17. Persistence DataStore (DATA)

Acuan: DEVELOPMENT_PLAN.md bagian 3.2 dan bagian 6 ("Tes data"). Hampir semua
baris di sini butuh **place yang sudah di-publish** dan **Enable Studio Access to
API Services** — baca [kotak DataStore](#22-kotak-datastore--baca-sebelum-menyalahkan-kode)
dulu.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| DATA-01 | Dua player baru (belum punya save) join hampir berbarengan di satu server | Di client pertama, upgrade senjata sampai level 3; lalu lihat level senjata di client kedua lewat panel lobby dan lewat `R.GetProfile:InvokeServer().weapons` | Senjata player kedua tetap **level 1** — tabel `weapons` dua player tidak berbagi referensi yang sama. Ini test eksplisit untuk bug deep copy (bagian 3.2 poin 1), dan dia **bisa dijalankan tanpa publish**: tanpa DataStore, data default tetap di-deep-copy per pemain. Ulangi juga untuk `materials`, `clears`, dan `stats` | M0 | 2P | - |
| DATA-02 | Save lama dari sebelum ada field baru. Caranya: main sebentar dengan satu nama DataStore, lalu tambahkan field baru ke `Config.DEFAULT_DATA`, lalu join lagi dengan nama DataStore yang **sama** | Join dengan player itu setelah skema diperluas | Field baru terisi nilai default; nilai lama (koin, level, XP) tidak berubah dan tidak ter-reset; field baru **di dalam** `stats` juga terisi — `reconcile` turun ke tabel bersarang | M0 | PUB | - |
| DATA-03 | Player sudah login; catat koin, lalu ubah progres (misal upgrade senjata) | Tunggu lebih dari **120 detik** (`Config.AUTOSAVE_INTERVAL`) tanpa keluar, lalu Stop playtest dan join lagi | Progres yang dibuat sebelum autosave masih ada. Catatan: Stop di Studio juga memicu `PlayerRemoving` yang menyimpan, jadi test ini tidak bisa mengisolasi autosave dari jalur itu — yang dibuktikan adalah "tidak ada yang hilang", dan autosave-nya terbukti di server live lewat DATA-06b | M5 | PUB | - |
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

## 18. HUD, layar hasil, dan tutorial (HUD)

Baris di bawah mengunci hal kecil yang paling sering ketinggalan saat mengerjakan
milestone lain, dan ikut jadi bahan alpha test.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Jalankan? | Status |
|---|---|---|---|---|---|---|
| HUD-01 | Match berjalan | Perhatikan HUD atas selama satu wave penuh | "Wave N / 10", teks state, "N koin tim", dan bar "Core x / 1000" semuanya terlihat dan terupdate. Teks state: `Di lobby`, `Match mulai dalam · Ns`, `Bertahan!`, `Jeda — toko buka · Ns`, `Match selesai`. Tidak ada nilai yang nyangkut di angka lama — HUD tidak menghitung apa pun sendiri, semuanya dari payload server | M2 | solo | - |
| HUD-02 | Match berakhir — dites dua kali, menang dan kalah | Lihat layar hasil | Judul "Core Server aman!" (hijau) atau "Core Server jebol" (merah), lalu "Wave tercapai: N", "Koin: +N", "XP: +N", baris "Material: ..." kalau ada, baris "Terbuka: ..." kalau ada, lalu "Kembali ke lobby sebentar lagi...". Payload-nya `MatchResult` dari bagian 3.6, dan angkanya harus sama dengan print `[RewardService]` di Output server. Layar hasil yang menampilkan +0 sementara print server benar berarti temuan T1 kembali | M2 | solo | - |
| HUD-03 | State `Lobby` setelah satu match | Buka panel lobby | Header "Level N · M koin" dan baris senjata menampilkan level, damage, dan material **terkini**, bukan angka sebelum match | M5 | solo | - |
| HUD-04 | Match berjalan tanpa boss, lalu wave dengan boss | Perhatikan panel di bawah HUD utama | Panel bar HP boss **tidak terlihat** selama tidak ada boss hidup, dan muncul begitu `BossState` melaporkan boss hidup. Hilang lagi setelah boss mati | M4 | solo | - |
| HUD-05 | Player baru (`stats.matchesPlayed` = 0) | Mainkan satu match dari lobby sampai selesai | Panel **PANDUAN** muncul di bawah layar, satu langkah per momen baru, masing-masing **sekali saja** per sesi: di lobby, saat hitung mundur, saat wave 1, saat wave 2, saat jeda pertama, saat boss pertama muncul, dan saat match selesai. Tiap panel hilang sendiri setelah 12 detik. Panduan jeda **tidak** muncul sembilan kali dalam satu match | M5 | solo | - |
| HUD-06 | Satu match sudah diselesaikan (`matchesPlayed` ≥ 1) | Kembali ke lobby dan mulai match kedua | Panduan **tidak muncul lagi**. Di Studio tanpa DataStore, `matchesPlayed` ada di memori saja, jadi restart playtest akan membuat panduannya muncul lagi — itu benar, bukan bug | M5 | solo | - |
| HUD-07 | State `Lobby`, koin kurang dari harga upgrade | Panggil `R.UpgradeWeapon:FireServer("weapon_starter")` dari command bar client | Alasan penolakan muncul di **baris petunjuk** di bawah panel lobby, warna merah, lalu kembali ke teks biasa setelah ~4 detik. Pembelian yang berhasil menampilkan "Berhasil." warna hijau. Tanpa ini, penolakan server terlihat sama seperti tombol yang rusak | M5 | solo | - |
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
| M2 | Satu match penuh bisa dimainkan dari lobby sampai hasil | MATCH-01 sampai MATCH-09, MATCH-11, MATCH-12, MATCH-13, MATCH-15, MATCH-16, WAVE-01, WAVE-02, WAVE-04, WAVE-05, WAVE-14, WAVE-16, WAVE-20, COMBAT-11, HUD-01, HUD-02 | MATCH-16 berkode `LIVE` |
| M2 | Bisa diulang tanpa restart server | MATCH-10, MATCH-14, SHOP-12 | — |
| M2 | Scaling jumlah dan HP musuh per player; batas musuh aktif + antrian | WAVE-06, WAVE-08, WAVE-10 | Semuanya butuh `2P`/`4P` |
| M3 | Beli item mengubah gameplay di wave berikutnya | SHOP-01 sampai SHOP-06, SHOP-14, SHOP-20, SHOP-21, CORE-05, COMBAT-14 | — |
| M3 | Tidak bisa beli di luar jeda atau dengan koin kurang (dicoba lewat remote manual) | SHOP-07, SHOP-08, SHOP-09, SHOP-12, SHOP-22, SEC-04 | SHOP-13 (`LIVE`) menutup kasus bukan-peserta |
| M3 | Koin match per tim, reset tiap match | MP-04, MP-14, SHOP-12, SHOP-17, SHOP-18, SHOP-19, SHOP-23, SHOP-24 | MP-04, MP-14, SHOP-23, dan SHOP-24 butuh `2P`/`4P`. SHOP-17 sampai SHOP-19 menutup hadiah koin per wave, yang **tidak** punya kriteria "Selesai kalau" sendiri — dia datang dari `ARENA_REDESIGN.md` bagian 6 dan dipetakan ke sini karena hadiahnya masuk kolam koin match milik tim |
| M4 | Kedua boss bisa dikalahkan dengan mekaniknya berjalan | BOSS-01, BOSS-02, BOSS-03, BOSS-05 sampai BOSS-09, BOSS-12, BOSS-14, SHOP-10, SHOP-11, SHOP-15, SHOP-16, HUD-04, HUD-08 | SHOP-16 adalah mekanik Locker yang sebenarnya menggigit; SHOP-10 cuma penandanya |
| M4 | Material tercatat di data player setelah match | BOSS-04, BOSS-09, BOSS-10 | BOSS-04 butuh `2P`; BOSS-13 (`LIVE`) menutup kasus peserta yang disconnect; persistensi sesungguhnya butuh `PUB` |
| M5 | Player baru bisa main | PROG-16, HUD-05, HUD-06, BOOT-04, BOOT-05 | — |
| M5 | Dapat reward | PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, HUD-03 | — |
| M5 | Upgrade senjata | PROG-08, PROG-09, PROG-17, COMBAT-12, HUD-07 | — |
| M5 | Craft senjata boss | PROG-12, PROG-13, PROG-18, COMBAT-09 | — |
| M5 | Membuka Hard | PROG-06, PROG-07, WAVE-09 | — |
| M5 | Keluar, join lagi, dan semua progres masih ada | PROG-14, PROG-15, DATA-03, DATA-06a | **Seluruhnya `PUB`** — kriteria ini tidak bisa dites sama sekali sampai place-nya di-publish sekali |
| M5 | Senjata `weapon_ranged` dan `weapon_boss_a` jalan di CombatService | PROG-10, COMBAT-06, COMBAT-07, COMBAT-08, COMBAT-09 | COMBAT-06 butuh `LAG` |
| M6 | Playtest 4 player lewat Studio (Test → Clients and Servers) lancar | MP-01, MP-02, MP-03, MP-04, MP-05, MP-12, MP-13, MP-14, BOSS-04, BOSS-11, WAVE-06, WAVE-08, WAVE-10, DATA-01 | Semuanya butuh `2P`/`4P`, dan itu memang isi kriterianya. MATCH-16 (pemain join saat Countdown) berkode `LIVE` karena Studio tidak bisa menambah pemain di tengah sesi |
| M6 | Rejoin di tengah match berhasil | MP-06, MP-07, MP-08, MP-09, MP-10, MP-11, DATA-04, DATA-05, DATA-07, DATA-08 | MP-09 dan MP-10 bisa dites sekarang dengan `2P`. **Sisanya `LIVE`** — Studio tidak bisa mensimulasikan join ulang dengan UserId yang sama |
| M6 | Leaderboard (`LeaderboardService` + papan di lobby) | LB-00 sampai LB-05, SEC-08 | **Seluruhnya `BELUM`** — belum ada satu baris kode pun |
| M6 | Rate limit di semua remote | SEC-14, SEC-01 sampai SEC-07, SEC-11 | — |
| M6 | Tidak ada error di output server | MP-03, MP-12, SEC-01 sampai SEC-14, DATA-09a, DATA-09b, BOOT-01 | SEC-08 (`BELUM`), DATA-09b (`LIVE`) |
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
| `GetLeaderboard` dari tabel bagian 3.6 | **Sengaja belum didaftarkan** | Itu milestone M6, dan `RemoteFunction` tanpa `OnServerInvoke` membuat client yang memanggilnya menggantung selamanya. Lihat LB-00 dan SEC-08. |

### 20.2 Keputusan M2

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Koin match peserta yang disconnect | Tidak bisa hangus, karena **koin match disimpan sebagai satu kolam milik TIM**, bukan per pemain | Rencana development menyarankan "disimpan, jangan hangus". Kolam tim menyelesaikan itu tanpa kode tambahan: tidak ada saldo per pemain yang bisa hilang saat dia disconnect, dan saat rejoin dia langsung melihat saldo tim yang sama. Ini juga yang diminta M3 ("koin match per TIM") dan bagian 3.7 ("tambah koin match ke tim"). |
| Semua peserta keluar di tengah match | Match **dibatalkan**, state kembali ke `Lobby`, dan `onMatchEnded` **tidak** ditembakkan | Rencana development menyebut konsekuensi kalau tidak dibatalkan: server nyangkut di `WaveActive` tanpa pemain. Pembatalan sengaja bukan kekalahan — kalau `onMatchEnded` ditembakkan, RewardService akan menghitung reward untuk peserta yang sudah tidak ada di server, padahal reward mereka sudah dibayar satu per satu saat masing-masing keluar (bagian 3.3). |
| Dua pemain memilih kesulitan berbeda | Ambil yang **paling mudah** di antara pilihan mereka | Tidak disebut rencana development. `hard` harus dibuka dulu per pemain (bagian 3.1), jadi aturan apa pun yang mengambil yang lebih sulit bisa memaksa pemain ikut match pada tingkat yang belum dia buka. Mengambil yang termudah tidak pernah bisa melakukan itu. Diukur dari `hpMult`, bukan urutan tabel, supaya menambah tingkat baru nanti tidak perlu menyentuh fungsinya. Dites MP-13. |
| Pemain baru join saat Countdown | Hitung mundur **dibatalkan**, kembali ke Lobby | Syarat masuk Countdown di bagian 3.3 adalah "semua player di server menekan Ready". Pemain yang baru join otomatis belum Ready, jadi syaratnya tidak lagi terpenuhi. Memeriksa syarat itu terus-menerus (bukan sekali saat masuk) adalah tafsir paling lurus dari aturannya, dan mencegah match dimulai dengan pemain yang tidak pernah menyatakan siap. Dites MATCH-16. |
| Tombol Ready ditaruh di mana | `LobbyController`, versi minimal saat M2 | Rencana development menaruh tombol Ready di `LobbyController`, yang milestone-nya M5. Tapi tanpa tombol itu tidak ada cara memulai match dan kriteria M2 tidak bisa diverifikasi sama sekali. Jadi file-nya dibuat lebih awal dengan isi minimal, dan panel senjata/kesulitan/upgrade/craft menempel ke panel yang sama di M5. |
| Satu loop timer atau satu task per state | **Satu loop**, dijalankan tiap 0.2 detik | State machine yang tiap transisinya memulai `task.delay` sendiri akan punya beberapa timer hidup bersamaan setelah satu transisi dibatalkan, dan yang lama tetap menyala. Konsekuensi yang terlihat di test: timer di HUD bergerak dalam langkah 0.2 detik, bukan mulus per frame (MATCH-11). |

### 20.3 Keputusan M3

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Efek `shop_damage_up` dan `shop_fire_rate`: per pemain atau per tim | **Per tim** | M3 menyebut "upgrade damage tim". Selain itu koin match adalah satu kolam milik tim, jadi efek per-pembeli membuat pemain pertama yang menekan tombol memakai uang bersama untuk keuntungan pribadi. Deskripsi item di `ShopItems.luau` ikut diubah supaya tidak lagi berbunyi "senjatamu". |
| Penghalang dipasang di lane mana | **Semua lane**, dan beberapa pembelian menumpuk **durasinya** | Tabel bagian 3.6 memaku payload `BuyShopItem` jadi `itemId` saja, tanpa argumen lane. Menambah argumen berarti menyimpang dari tabel yang milestone berikutnya ikut pakai, dan menebak lane mana yang dimaksud pemain lebih buruk daripada efek yang jelas dan bisa diprediksi. Durasi yang menumpuk dipilih karena dua penghalang di lane yang sama pada waktu yang sama tidak menahan musuh dua kali lebih kuat. Dites SHOP-05. Dulu dinding visualnya hilang lebih cepat daripada blokirnya (temuan T5); sudah disamakan. |
| Penghalang berlaku kapan | **Wave berikutnya**, bukan saat dibeli | Toko cuma buka saat `Intermission`, dan saat itu tidak ada musuh yang bergerak. Dipasang langsung berarti 6 detiknya habis sebelum ada yang perlu ditahan. |
| Posisi turret | Ditentukan **server**, mengelilingi Core, sudutnya dari nomor pembelian | Alasan yang sama dengan penghalang: payload-nya cuma `itemId`. Sudut dari nomor pembelian memastikan turret kedua tidak muncul menumpuk di atas yang pertama. |
| Pengali efek: linear atau berlipat | **Linear** (5 x +10% = 1.5x, bukan 1.61x), dengan lantai cooldown 0.4 | Harga item tetap, jadi efek yang berlipat akan meledak di pembelian terakhir. Linear juga bisa dihitung sendiri oleh pemain. Lantainya ada supaya menaikkan step nanti tidak bisa membuat cooldown senjata hilang sama sekali. |
| Siapa yang boleh membeli | Hanya pemain yang ada di `participants` | Tidak disebut bagian 3.6, tapi mengikuti aturan yang sama dengan `Attack`: pemain yang ditahan di lobby bukan bagian dari match yang sedang berjalan (bagian 3.3), jadi dia tidak boleh membelanjakan koin tim. Dites SHOP-08 dan SHOP-13. |
| Panel toko disembunyikan atau ditandai saat terkunci | **Ditandai**, bukan disembunyikan | Kalau disembunyikan, pemain tidak tahu bedanya "belum waktunya" dan "dikunci Locker", padahal yang kedua adalah mekanik yang harus dia sadari. Keputusannya benar, tapi kesempatan melihatnya dulu tidak pernah ada: panel cuma muncul saat `Intermission` dan toko cuma terkunci saat `WaveActive` (temuan T2). Panel sekarang ikut muncul saat `ShopState.locked`, jadi kuncinya memang terlihat. |
| Mekanik Locker: melarang membeli atau menyandera yang sudah dibeli | **Menyandera yang sudah dibeli** (`ShopState.suspended`), dan kunci tokonya dipertahankan sebagai penanda | Melarang membeli tidak menolak apa pun. Toko cuma buka saat `Intermission`, Locker cuma hidup saat `WaveActive`, dan wave 10 adalah wave terakhir v1 sehingga tidak ada `Intermission` sesudahnya — jadi kuncinya selalu benar secara hampa, dan muatan edukasi boss ini tidak pernah sampai ke pemain. Ransomware juga tidak melarang korban berbelanja; dia menyandera yang sudah dimiliki korban. Jadi selama Locker hidup, pengali damage dan attack speed kembali ke dasar sementara `purchases` tetap utuh — dites di SHOP-16, kebocoran antar match-nya di SHOP-15. Kuncinya tetap dipasang karena membuat pesan penolakan benar saat pemain mengklik panel yang terlihat. |

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

Baris di bawah datang dari `docs/ARENA_REDESIGN.md` bagian 4, 5, dan 6, bukan
dari DEVELOPMENT_PLAN.md — jadi tidak ada kriteria "Selesai kalau" yang
memaksanya, dan semuanya pilihan. Dua akar perubahannya terpisah. Yang pertama
dan paling mengubah rasa main: musuh yang lolos **tidak hilang lagi**, dan dari
situ lahir sembilan baris pertama tabel ini. Yang kedua menyangkut uang:
**tiap wave yang selesai memberi hadiah koin tim**, dan hadiah sebesar itu
memaksa batas jumlah pembelian di Toko Match diganti harga yang naik —
empat baris terakhir.

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
| Hadiah per wave masuk mata uang yang mana | **Koin match** — kolam milik tim yang habis tiap match, bukan koin permanen per pemain | Pengali jumlah pemain (solo x4) cuma koheren untuk kolam tim, dan itu argumen terkuatnya. Kalau hadiahnya masuk koin permanen, main solo jadi **4x lebih efisien per orang** untuk farming, dan game co-op yang menghukum main bareng akan dimainkan solo oleh semua orang. Kolam koin match dibagi tim, jadi x4 solo cuma menormalkan daya beli per orang — tidak memberi solo keuntungan yang dibawa keluar dari match. Dites SHOP-17, yang secara eksplisit memeriksa koin permanen **tidak** ikut naik. |
| Pengali jumlah pemain: kurva atau tangga | **Tangga** — 1 pemain x4, 2 pemain x2, 3 atau lebih x1 | Tangga dengan tiga nilai bisa dihitung di kepala dan dibaca dari satu baris Output; kurva (misal `4/playerCount`) memberi 1,33 untuk 3 pemain dan membuat tiap angka hadiah harus dihitung ulang sebelum bisa dinilai. Ambangnya di 3, bukan 4, karena efek Toko Match sudah berlaku untuk seluruh tim: tim berempat mendapat 4x nilai dari tiap koin, jadi tim 3 dan 4 orang sudah berada di sisi yang sama dari pertukaran itu. Jumlah pemain yang tidak masuk akal (nol, negatif, NaN) jatuh ke **x4**, bukan ke nol — hadiah yang terlalu besar langsung terlihat saat playtest, hadiah yang diam-diam hilang tidak. Dites SHOP-23 dan SHOP-24, dan dipatok unit test `Balance`. |
| Hadiah untuk wave terakhir | **Diberikan**, dan urutannya dipatok: hadiah ditembakkan **sebelum** pengecekan wave terakhir | Cabang wave terakhir memanggil `endMatch(true)` lalu `return`, jadi hadiah yang ditaruh sesudahnya tidak akan pernah diberikan untuk wave 10 — dan wave 10 adalah wave boss, jadi yang hilang justru hadiah **terbesar di seluruh match** (5.200 untuk solo). Kegagalannya juga tidak mencetak error apa pun: pemain cuma menang dengan koin yang tidak pernah dia lihat, di detik terakhir sebelum kolamnya di-reset. Urutan itu satu-satunya yang benar, dan itu sebabnya dia punya test sendiri. Dites SHOP-19. |
| Batas jumlah pembelian di Toko Match | **Dihapus untuk empat item, diganti harga yang naik x1.25 per pembelian item yang sama.** `shop_barrier` tetap dibatasi 5 | Dengan hadiah per wave, solo mengumpulkan sekitar **21.200** koin sepanjang 10 wave, sementara toko yang seluruh itemnya dibatasi cuma bisa menyerap **3.450**: habis diborong di wave 3-4, lalu enam wave sisanya koinnya tidak ada gunanya. Menurunkan hadiahnya bukan perbaikannya, karena alasan x4-nya valid — yang salah batas jumlahnya. Dengan harga yang naik, 10 tumpuk Exploit Patch memakan 6.647 koin alih-alih 2.000: uang selalu punya tujuan, dan kelebihan pasokan solo terkoreksi lewat harga, bukan lewat tembok yang membuat sisa koin tidak ada gunanya. `shop_barrier` ditinggalkan dari daftar itu karena empat item lain menambah **kemampuan**, yang tetap harus dipakai, sementara dia menambah **waktu musuh tertahan** — 20 tumpuk berarti 120 detik dan wave-nya lewat tanpa pemain menyentuh apa pun, jadi harga yang naik tidak membatasi apa pun yang perlu dibatasi. Konsekuensinya untuk yang playtest: harga di tombol berubah sendiri antar pembelian, dan itu T11. Dites SHOP-20 sampai SHOP-22. |
