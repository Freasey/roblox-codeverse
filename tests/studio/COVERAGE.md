# Cakupan: apa yang bisa diotomatiskan dari `docs/TEST_CASES.md`

Hasil spike `tests/studio`. Setiap baris di bawah punya dasar bukti, dan
kolom **Dasar** menyebutkan buktinya. Yang belum dicoba disebut "belum dicoba",
bukan ditebak.

Arti label:

| Label | Arti |
|---|---|
| **BISA** | Seluruh isi test case bisa diperiksa dari `tests/studio` tanpa manusia |
| **SEBAGIAN** | Sisi server bisa; sisi HUD/client/Player dari baris yang sama tidak |
| **TIDAK** | Terhalang batas yang sudah dibuktikan (tidak ada Player, client, atau DataStore) |
| **BELUM ADA** | Fiturnya sendiri belum diimplementasikan, jadi belum bisa dinilai |

Arti kolom Dasar:

| Dasar | Arti |
|---|---|
| **lulus** | Ada assertion yang lulus di `tests/studio` sekarang |
| **probe** | Dibuktikan lewat probe yang dijalankan saat spike (hasilnya dikutip di bawah) |
| **terhalang** | Dibuktikan terhalang; alasannya disebut |
| **sejenis** | Hanya butuh kemampuan yang sudah terbukti (require service hidup, baca Instance, majukan waktu, baca log) — case-nya belum ditulis |

## Rekap

| | Jumlah | Dari 126 |
|---|---|---|
| BISA | 16 | 13% |
| SEBAGIAN | 11 | 9% |
| TIDAK | 98 | 78% |
| BELUM ADA | 1 | 1% |

**Jangan dibaca sebagai "22% kerja manual hilang".** Baris SEBAGIAN tetap
menuntut satu lintasan manusia untuk separuh HUD/client-nya, jadi jumlah baris
yang benar-benar tidak perlu disentuh manusia lagi adalah 16 — sekitar
**seperdelapan** dokumen. Yang berubah bukan panjang daftarnya, tapi
**seberapa sering** daftar itu harus diulang: 16 baris itu justru yang paling
lama dikerjakan tangan (menunggu satu wave jalan, menonton boss membelah dua
kali, menghitung musuh aktif di wave 10 dengan 4 client), dan sekarang jadi 45
detik.

## 1. MATCH — alur match dan state machine (14)

| ID | Label | Dasar |
|---|---|---|
| MATCH-01 | SEBAGIAN | lulus — `boot.state` = `Lobby` dan `boot.tidakAdaMusuh` = 0. Sisanya ("player ada di area lobby", "panel upgrade/craft bisa dibuka") butuh Player dan client |
| MATCH-02 … MATCH-14 | TIDAK | terhalang — `participants` diisi dari `Players:GetPlayers()`, dan tidak ada Player yang bisa dibuat (`CreateLocalPlayer` → `lacking capability LocalUser`). Tanpa Ready, tidak ada `Countdown`, `WaveActive`, `Intermission`, atau `Ended` |

## 2. WAVE — wave dan spawn (14)

Kategori ini terbuka karena satu temuan: `MatchService.onWaveStarted` adalah
`Signal`, dan `Fire(n)` bisa dipanggil dari luar. Itu memanggil
`WaveService.startWave(n)` yang sesungguhnya — termasuk `primeSpawnTimer()`,
`setRunning(true)`, spawn boss, dan `MatchRules.spawnOrder`.

| ID | Label | Dasar |
|---|---|---|
| WAVE-01 komposisi wave 1 | BISA | probe — `onWaveStarted:Fire(1)` → `queued=6 active=2`, `getActiveWave()=1`. `defId` tiap musuh bisa dibaca dari `EnemyService.getAll()` |
| WAVE-02 wave 1→10, boss di 5 dan 10 | SEBAGIAN | probe — komposisi tiap wave bisa diperiksa dengan `Fire(n)` untuk n=1..10. Perpindahan **otomatis** antar wave (lewat `Intermission`) milik MatchService → tidak |
| WAVE-03 ikuti satu `basic` ke core | SEBAGIAN | lulus — `gerak.*` dan `damage.*` di `enemy_core`. "mati dalam beberapa serangan senjata starter" butuh Combat → tidak |
| WAVE-04 `fast` vs `basic` | BISA | sejenis — `enemy.speed` dan jarak tempuh terukur; `gerak.jarakKeCoreMenyusutMonoton` membuktikan pengukurannya |
| WAVE-05 `tank` paling lambat | SEBAGIAN | sejenis untuk kecepatan dan `maxHp`; "jumlah pukulan" butuh CombatService → tidak |
| WAVE-06 jumlah musuh naik per player | SEBAGIAN | sejenis lewat `EnemyService.setContext(wave, difficulty, playerCount)`. Lewat jalur asli tidak: `startWave` membaca `MatchService.getParticipantCount()` yang selalu 0 di sini |
| WAVE-07 HP naik per wave | BISA | sejenis — `setContext(1, …)` vs `setContext(5, …)`, baca `enemy.maxHp` |
| WAVE-08 HP naik per jumlah player | BISA | sejenis — sama, lewat argumen `playerCount` |
| WAVE-09 pengali HP `hard` 1.8 | BISA | sejenis — `setContext(…, Difficulties.hard, …)` |
| WAVE-10 musuh aktif tidak lebih dari 40 | BISA | probe — `Fire(5)` menghasilkan `active=5 queued=12` lalu naik; `activeCount()` bisa disampel sepanjang wave |
| WAVE-11 waypoint berurutan, tidak memotong | BISA | lulus — `enemy.waypointIndex` dan `primary.CFrame` keduanya terbaca; `gerak.cframeIkutPositionLua` membuktikan CFrame-nya nyata |
| WAVE-12 musuh datang dari kedua lane | BISA | probe — log `wave 5: 16 musuh biasa di 2 lane`; `enemy.laneIndex` terbaca per musuh |
| WAVE-13 HP bar musuh ikut turun | BISA | sejenis — `enemy.healthFill` adalah `Frame` yang dibuat server, jadi `.Size`-nya terbaca dari sisi server |
| WAVE-14 tidak ada sisa musuh di `Intermission` | SEBAGIAN | lulus untuk `isClear()` / `clearAll()` (`gerak.clearAllMembersihkan`). Transisi ke `Intermission` sendiri milik MatchService → tidak |

## 3. CORE — Core Server (5)

| ID | Label | Dasar |
|---|---|---|
| CORE-01 HP penuh di awal | SEBAGIAN | lulus — `boot.coreHpPenuh`. Bagian "angkanya terlihat di HUD" → tidak |
| CORE-02 musuh sampai core, HP turun, musuh hilang | SEBAGIAN | lulus — `damage.hpCoreBerkurang`, `damage.besarDamagePersis`, `damage.musuhDibersihkanSetelahSampai`, `damage.tidakDamageBerulang`. Bagian HUD → tidak |
| CORE-03 HP 0, tidak negatif | SEBAGIAN | probe — `onDestroyed` tembak, `getHp()`=0 bukan negatif. Bagian "state `Ended`" → tidak: MatchService hanya mengakhiri match dari `WaveActive`/`Intermission`, dan di harness ini state-nya `Lobby` |
| CORE-04 HP tidak turun di `Lobby`/`Intermission` | BISA | lulus — `gerak.coreBelumKena` plus `EnemyService.setRunning(false)` |
| CORE-05 beli repair core | TIDAK | terhalang — `BuyShopItem` lewat `onBuy` yang diawali `RateLimit.check(limiter, player.UserId, …)` |

## 4. COMBAT — combat (12)

| ID | Label | Dasar |
|---|---|---|
| COMBAT-01 … COMBAT-12 | TIDAK | terhalang — `onAttack` diawali `player.UserId`, lalu `characterOrigin(player)` butuh karakter. Tidak ada Player dan tidak ada karakter di mode Run. COMBAT-05 dan COMBAT-06 lebih jauh lagi: keduanya butuh **Network simulation**, fitur UI Studio |

Catatan: `HitTest.luau` sudah punya unit test murni di `tests/HitTest.spec.luau`.
Yang hilang di sini adalah integrasinya, bukan rumusnya.

## 5. SHOP — Toko Match (12)

| ID | Label | Dasar |
|---|---|---|
| SHOP-05 penghalang menahan musuh di satu lane | SEBAGIAN | sejenis — `EnemyService.blockLane(laneIndex, duration)` publik dan efeknya terbaca dari posisi musuh. Pembeliannya sendiri → tidak |
| SHOP-01 … SHOP-04, SHOP-06 … SHOP-12 | TIDAK | terhalang — semuanya lewat `BuyShopItem`, dan `onBuy` menyentuh `player.UserId` di baris pertama. SHOP-01 dan SHOP-10 juga butuh UI client |

## 6. BOSS — boss (11)

Dibuktikan lewat probe: `onWaveStarted:Fire(5)` → `boss_splitter` muncul sebagai
`Workspace.Enemies.boss_splitter_1` dengan HP 2500/2500, membelah dua kali, lalu
`onBossDefeated` tembak, tanpa satu pun error milik game.

| ID | Label | Dasar |
|---|---|---|
| BOSS-01 `boss_splitter` muncul di wave 5, hanya satu | BISA | probe — `bossDefId=boss_splitter`, satu entri `isBoss` di `getAll()`. Bagian "HP bar boss di HUD" → sisi client, tapi `boss.hp` terbaca dari server |
| BOSS-02 membelah saat HP lewat 66% | BISA | probe — turun 40%: `active 5 → 11`, `bossHp=1500` |
| BOSS-03 membelah kedua kali di 33%, yang pertama tidak terulang | BISA | probe — turun lagi 35%: `active 11 → 18`, `bossHp=625` |
| BOSS-04 Material A ke **semua** peserta | TIDAK | terhalang — butuh Player di `participants` |
| BOSS-05 kartu info muncul di client | TIDAK | terhalang — `LocalScript` tidak jalan di mode Run |
| BOSS-06 `boss_locker` muncul di wave 10 | BISA | sejenis — jalur identik dengan BOSS-01, `Fire(10)` |
| BOSS-07 minion dipanggil berkala; toko terkunci | BISA | sejenis — pemanggilan minion terbaca dari `activeCount()` sepanjang waktu. Status terkunci toko terbaca dari sisi server; UI-nya tidak |
| BOSS-08 minion berhenti setelah boss mati | BISA | probe — `bossHidupSetelahMati=false`; `activeCount()` bisa disampel sesudahnya |
| BOSS-09 Material B + kartu info + match menang | TIDAK | terhalang — Player, client, dan MatchService sekaligus |
| BOSS-10 material tercatat di data player | TIDAK | terhalang — Player dan DataStore |
| BOSS-11 HP bar boss sama di 4 client | TIDAK | terhalang — butuh 4 client |

## 7. PROG — progres permanen dan data player (16)

| ID | Label | Dasar |
|---|---|---|
| PROG-01 … PROG-16 | TIDAK | terhalang — semuanya butuh Player, dan sebagian besar juga butuh DataStore yang tidak tersedia di place yang belum di-publish |

Catatan: `ProgressionRules.luau` dan `Balance.luau` sudah punya unit test murni
di `tests/`. Yang hilang di sini adalah jalur dari remote sampai ke data
tersimpan.

## 8. MP — multiplayer dan rejoin (12)

| ID | Label | Dasar |
|---|---|---|
| MP-01 … MP-12 | TIDAK | terhalang — butuh 2 sampai 4 client lewat Test → Clients and Servers. Mode Run tidak punya client sama sekali |

## 9. LB — leaderboard (5)

| ID | Label | Dasar |
|---|---|---|
| LB-01 … LB-05 | TIDAK | terhalang — butuh OrderedDataStore (place belum di-publish) dan papan di lobby (`assets/Lobby.rbxmx` belum ada) |

## 10. SEC — keamanan remote (12)

| ID | Label | Dasar |
|---|---|---|
| SEC-09 `RequestAction` argumen sampah | BISA | lulus — 13 assertion di `remote_reject` (`nil`, `-1`, `0`, boolean, tabel, `Vector3`, `Instance`, NaN, string 64 KB, dan 4 nama aksi tak dikenal), plus `tolak.tidakAdaErrorDiServer` dan enam assertion "state tidak berubah" |
| SEC-01 `SetReady` | TIDAK | terhalang — `MatchService:368: attempt to index nil with 'UserId'` |
| SEC-02 `SelectLoadout` | TIDAK | terhalang — `MatchService:390: attempt to index nil with 'UserId'` |
| SEC-03 `Attack` | TIDAK | terhalang — `CombatService:160: attempt to index nil with 'UserId'` |
| SEC-04 `BuyShopItem` | TIDAK | terhalang — `ShopService:315: attempt to index nil with 'UserId'` |
| SEC-05 `UpgradeWeapon` | TIDAK | terhalang — `ProgressionService`, jalur `prepare(player, …)` |
| SEC-06 `BuyWeapon` | TIDAK | terhalang — sama |
| SEC-07 `CraftWeapon` | TIDAK | terhalang — sama |
| SEC-08 `GetLeaderboard` | BELUM ADA | `Remotes.luau` tidak punya `GetLeaderboard`; fiturnya M6 dan belum dibuat. Baris ini belum bisa dinilai, bukan gagal |
| SEC-10 `GetProfile` | TIDAK | terhalang — `OnServerInvoke` memanggil `PlayerDataService.waitFor(player)` |
| SEC-11 spam seluruh remote 30 detik, 2 client | TIDAK | terhalang — butuh client, dan sebagian besar remote-nya terhalang nil player |
| SEC-12 ubah modul shared ter-replikasi dari client | TIDAK | terhalang — butuh command bar client |

Ketujuh baris TIDAK di atas bukan dugaan: `remote_reject` menembak ketujuh
remote itu dan assertion
`batas.errorHandlerBerpagarPlayerSemuanyaKarenaNilPlayer` memastikan ketujuh
error yang muncul semuanya menyebut nil player. Kalau suatu hari ada handler
yang memvalidasi argumennya lebih dulu, jumlah error itu turun dan assertion
tersebut yang memberi tahu.

## 11. DATA — persistence DataStore (10)

| ID | Label | Dasar |
|---|---|---|
| DATA-01 … DATA-10 | TIDAK | terhalang — `[PlayerDataService] DataStore tidak tersedia: You must publish this place to the web to access DataStore.` Selain itu semuanya butuh Player |

**Belum dicoba:** apakah place yang sudah di-publish dengan *Enable Studio
Access to API Services* membuat DataStore tersedia di dalam `run-in-roblox`.
Secara prinsip itu setelan game di sisi Roblox, bukan isi `.rbxl`, jadi mungkin
ikut berlaku — tapi tidak diuji, dan tanpa Player tetap tidak ada data pemain
untuk disimpan.

## 12. HUD — HUD dan layar hasil (3)

| ID | Label | Dasar |
|---|---|---|
| HUD-01 … HUD-03 | TIDAK | terhalang — seluruhnya UI client; `LocalScript` tidak jalan di mode Run |

## Yang TETAP harus dikerjakan manusia di Studio

Ini tidak berubah apa pun hasil pengembangan harness ini, karena semuanya
terhalang oleh hal yang sama: tidak ada Player dan tidak ada client.

1. **Seluruh alur match** — Ready, countdown, loadout dikunci, wave jalan
   sendiri, layar hasil menang dan kalah. 13 baris MATCH.
2. **Seluruh combat** — butuh karakter yang berdiri di arena. 12 baris COMBAT.
   Dua di antaranya (COMBAT-05, COMBAT-06) butuh Network simulation, fitur UI
   Studio yang tidak punya padanan CLI.
3. **Seluruh UI client** — HUD, panel toko, panel craft, kartu info boss, layar
   hasil. 3 baris HUD plus bagian HUD dari 11 baris SEBAGIAN.
4. **Seluruh multiplayer dan rejoin** — Test → Clients and Servers dengan 2
   sampai 4 client. 12 baris MP.
5. **Seluruh persistence** — butuh place yang sudah di-publish dan API Services
   aktif. 10 baris DATA plus 16 baris PROG.
6. **Tujuh dari delapan tes keamanan remote** — dari command bar jendela
   client. 10 baris SEC.
7. **Seluruh leaderboard** — 5 baris LB.
8. **Semua yang sifatnya rasa** — apakah arena terbaca, apakah serangan terasa
   responsif, apakah 20 detik jeda terasa pas. Tidak ada di tabel mana pun dan
   justru itu inti alpha test di M7. Frame rate harness ini sekitar 8 Hz, jadi
   kesan soal waktu dan kehalusan dari sini **tidak** bisa dipercaya.

## Perkiraan usaha untuk melanjutkan

Sudah ada: 3 case, 94 assertion, 45 detik untuk seluruh suite.

Untuk mengambil 16 baris BISA dan sisi server dari 11 baris SEBAGIAN,
perkiraannya **dua sampai tiga file case baru** (`wave.luau`, `boss.luau`, dan
menambah `core.luau` atau memperluas `enemy_core.luau`), sekitar 600–800 baris.
Semuanya memakai kemampuan yang sudah terbukti, jadi tidak ada risiko penelitian
lagi — tinggal menulis assertion.

Dua biaya yang perlu diterima sebelum memutuskan:

1. **Harness ini menjangkau ke dalam.** `MatchService.onWaveStarted:Fire(5)`
   memanggil sinyal yang di kode produksi hanya ditembakkan dari dalam
   MatchService. Artinya test WAVE dan BOSS memverifikasi apa yang terjadi
   SETELAH sinyal itu ditembakkan, dan **tidak** memverifikasi bahwa
   MatchService menembakkannya pada waktu yang benar. Yang terakhir itu tetap
   milik manusia. Hal yang sama berlaku untuk `EnemyService.setContext`, yang di
   produksi dipanggil oleh WaveService.
2. **Terikat ke API internal service.** Case di sini memanggil `setContext`,
   `queue`, `spawnAt`, `blockLane`, `damage`. Refactor di `src/server/Services/`
   akan mematahkannya, dan karena tidak jalan di CI, matinya baru ketahuan saat
   seseorang menjalankannya secara manual.

Yang membuat biaya itu layak: pada run pertama, harness ini sudah menemukan satu
bug nyata (`math.huge` lolos validasi `CoreService`) yang lolos dari stylua,
selene, luau-lsp, dan 146 unit test Lune sekaligus. Lihat
[README.md](README.md#temuan-mathhuge-lolos-validasi-coreservice).
