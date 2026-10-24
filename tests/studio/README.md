# tests/studio — verifikasi fungsional di dalam Roblox Studio, dari command line

Direktori ini hasil sebuah **spike**: pertanyaannya "bisakah verifikasi
fungsional M1–M5 dijalankan dari command line tanpa manusia mengklik di
Studio?", dan jawabannya **bisa, untuk sebagian besar logika server — dan tidak
bisa sama sekali untuk apa pun yang butuh Player**. Dokumen ini menjelaskan
mekanismenya dari awal, lalu batasnya, lalu apa yang tetap harus dikerjakan
manusia.

> **Tidak bisa masuk CI.** Runner di sini membuka instalasi Roblox Studio asli.
> CI GitHub (`ubuntu-latest`) tidak punya Studio, jadi `tests/studio` sengaja
> TIDAK ditambahkan ke `.github/workflows/ci.yml`. Unit test Lune di
> `tests/run.luau` tetap jalan di CI seperti biasa.

## Cara pakai

```bash
rokit install          # run-in-roblox sudah ada di rokit.toml
lune run tests/studio/run
```

Satu case saja:

```bash
lune run tests/studio/run boot
```

Exit code 0 kalau semua assertion lulus. Exit code 1 kalau ada yang gagal atau
ada case yang mati sebelum mencetak baris `END`.

**Saat dijalankan, jendela Roblox Studio terbuka dan MENGAMBIL FOKUS sekitar 10
detik per case, lalu menutup diri sendiri.** Jangan jalankan saat sedang
mengetik di aplikasi lain. Angka terukur ada di bagian
[Efek samping](#efek-samping-terukur) di bawah.

## Mekanismenya

Ada empat lapis, dan masing-masing ada karena satu kendala yang nyata.

**1. `run-in-roblox` menjalankan script di dalam Studio.** Tool dari rojo-rbx
ini membuka place di instalasi Studio lokal, menjalankan satu script di
dalamnya, lalu menyalurkan Output Studio ke stdout. Versi terakhirnya 0.3.0
(Juli 2020) — sudah lama, tapi **masih jalan di Studio sekarang** (diuji
2026-10-18). Dia tersedia sebagai binary di GitHub Releases, jadi tidak perlu
memasang Rust: `rokit add rojo-rbx/run-in-roblox@0.3.0` cukup.

**2. Script itu jalan di EDIT mode, bukan sebagai game.** Ini kendala pertama
dan yang paling mudah disalahpahami. Script yang diberikan ke
`run-in-roblox --script` dieksekusi pada *plugin security* di edit mode:
`RunService:IsRunning()` masih `false`, dan **tidak satu pun `Script` di place
yang pernah dieksekusi**. Jadi `--script print("hello")` memang mencetak
"hello", tapi itu tidak membuktikan apa pun soal game — `init.server.luau`
belum jalan.

Yang membuka jalan: pada plugin security, `RunService:Run()` BOLEH dipanggil.
Itu tombol "Run" Studio — server start, seluruh `Script` jalan, `Heartbeat`
berjalan. Tidak ada client dan tidak ada Player, tapi seluruh sisi server hidup.

**3. Konteks plugin punya cache `require` sendiri.** Kendala kedua, dan yang
paling berbahaya kalau tidak diketahui: me-`require` `MapService` dari script
plugin menghasilkan **salinan baru** dari module itu, bukan instance yang
dipakai server. Buktinya langsung terlihat — `[MapService] Arena siap` tercetak
**dua kali**, dan `CoreService.damage()` pada salinan itu tidak mengubah warna
Core (karena `bindVisual` dipanggil pada instance yang lain). Artinya: harness
yang naif akan menguji salinan mati sambil terlihat hijau.

Solusinya: host plugin tidak menguji apa pun sendiri. Dia membuat
`Instance.new("Script")`, mengisi `.Source`-nya dengan script test (`.Source`
bisa ditulis pada plugin security), dan menempelkannya ke
`ServerScriptService`. Script itu lalu jalan di **konteks server**, berbagi
cache `require` dengan `init.server.luau`, dan karena itu memanggil service yang
**sungguh-sungguh hidup**. Diverifikasi: `Arena siap` sekarang tercetak sekali
saja, dan `CoreService.damage()` dari script suntikan itu MENGUBAH warna part
Core yang di-bind `init.server.luau`.

**4. Log boot tercetak sebelum script test jalan.** Kendala ketiga. Baris
seperti `[MapService] Arena siap` keluar saat boot, dan script test belum tentu
sempat memasang `LogService.MessageOut` sebelum itu. Jadi host plugin yang
menyadap `LogService` — dipasang **sebelum** `Run()` — lalu menuangkan tiap
pesan ke `ReplicatedStorage` sebagai `StringValue`. Dua konteks tidak berbagi
variabel Lua, tapi berbagi DataModel. Sisi server membacanya lewat `T.log()`.

Ringkasnya:

```
lune run tests/studio/run
  └─ rojo build  →  build/codeverse.rbxl
  └─ prelude.luau + cases/X.luau  →  ditanam ke host.luau  →  build/studio-X.lua
  └─ run-in-roblox --place ... --script build/studio-X.lua
       └─ Studio, edit mode, plugin security:  host.luau
            ├─ sadap LogService  →  StringValue di ReplicatedStorage
            ├─ suntik Script ke ServerScriptService  ←  prelude + case
            ├─ RunService:Run()
            └─ tunggu atribut selesai  →  RunService:Stop()
       └─ stdout, baris berawalan ##CV##
  └─ parse  →  exit code
```

## Apa yang BISA dites di sini

Diverifikasi dengan empat case di `cases/`, 183 assertion (183 lulus, 0 gagal, 16 dilewati):

- **Seluruh rantai boot `init.server.luau` di engine sungguhan** — urutan
  `require` yang melingkar, API web yang dipanggil di module scope, nama
  Instance yang salah di `Arena.rbxmx`: semuanya kelas bug yang lolos dari
  stylua, selene, luau-lsp, DAN unit test Lune sekaligus, dan hanya muncul saat
  engine menjalankannya.
- **Semua service yang tidak butuh Player**: `MapService`, `CoreService`,
  `EnemyService`, `WaveService`, `BossService` dan modul mekanik boss-nya.
- **Perilaku sepanjang waktu di atas Instance sungguhan** — musuh di-spawn
  sebagai `Model` di `Workspace`, bergerak lewat `primary.CFrame`, dan jaraknya
  ke Core diukur dari CFrame itu, bukan dari field tabel Lua. Jejak nyata dari
  satu run: `141.9 → 135.9 → 130.9 → 126.1 → 121.3` stud.
- **Validasi argumen pada satu remote** (`RequestAction`), lihat batasnya di
  bawah.

## Apa yang TIDAK BISA, dengan buktinya

**Tidak ada Player, dan tidak bisa dibuat.** `Players:CreateLocalPlayer(1)`
ditolak dengan `The current thread cannot call 'CreateLocalPlayer' (lacking
capability LocalUser)` — baik dari konteks plugin maupun dari server.
`RunService` juga tidak punya `Play`, `PlaySolo`, `StartServer`, atau
`StartClient` (keempatnya `is not a valid member of RunService`). Jadi mode Run
adalah batas atasnya: server tanpa client, tanpa karakter, tanpa Player.

Konsekuensinya, yang **tidak** bisa diotomatiskan dari sini:

- **`MatchService` seluruhnya.** `participants` diisi dari
  `Players:GetPlayers()`, jadi match tidak bisa dimulai. Semua tes state machine
  (`Lobby` → `Countdown` → `WaveActive` → `Intermission` → `Ended`) butuh
  manusia.
- **Tujuh dari delapan handler remote C→S.** `Attack`, `SetReady`,
  `SelectLoadout`, `BuyShopItem`, `UpgradeWeapon`, `BuyWeapon`, `CraftWeapon`
  semuanya diawali `RateLimit.check(limiter, player.UserId, ...)`, yang error
  karena `player` nil sebelum argumennya pernah diperiksa. `cases/remote_reject.luau`
  membuktikan ini, bukan menebaknya: dia menembak ketujuhnya dan memastikan
  ketujuh error yang muncul memang menyebut nil player.
- **Semua Combat.** `characterOrigin(player)` butuh karakter.
- **Semua UI client.** Mode Run tidak menjalankan `LocalScript`.
- **Persistence DataStore.** Place ini belum di-publish; `PlayerDataService`
  sudah sengaja turun ke data default di memori.

Satu catatan teknis yang membuat `RequestAction` bisa dites: `FireServer()`
dipanggil dari `Script` **server** ternyata TETAP menembakkan `OnServerEvent`,
dengan `player` = nil di argumen pertama. Diverifikasi di
`cases/remote_reject.luau` bagian `mekanisme.*`. Jadi handler yang memvalidasi
argumennya SEBELUM menyentuh `player` bisa diuji penuh; yang tidak, tidak bisa
sama sekali.

## Temuan yang sudah ditutup: `math.huge` lolos validasi `CoreService`

**Sudah diperbaiki.** Dicatat di sini karena inilah bug pertama yang ditemukan
harness ini, dan bentuknya menjelaskan kenapa harness ini ada: dia lolos dari
lint, type check, dan 149 unit test, lalu ketangkap pada run pertama di engine
sungguhan.

Dulu tiga assertion gagal:

```
FAIL  tolak.coreDamageAngkaTidakWajar: inf        -- dapat 1000, harap 0
FAIL  tolak.coreHpMasihUtuhSetelahDamageSampah    -- dapat 0, harap 1000
FAIL  tolak.coreHealAngkaTidakWajar: inf          -- dapat 100, harap 0
```

`CoreService.damage()` memvalidasi tiga hal: tipe bukan number, NaN, dan angka
≤ 0. `math.huge` lolos ketiganya — dia number, dia sama dengan dirinya sendiri
jadi bukan NaN, dan dia lebih besar dari nol. Lalu
`math.max(0, hp - math.huge)` = 0: **Core hancur dalam satu panggilan, dan match
langsung kalah.** `CoreService.heal()` punya celah yang identik.

Seberapa serius: **belum bisa dieksploitasi dari client.** Satu-satunya pemanggil
`damage()` adalah `arriveAtCore()`, yang mengirim `enemy.coreDamage` — angka
berhingga yang diambil apa adanya dari `Enemies.luau`/`Bosses.luau`, tanpa
pengali difficulty sama sekali (berbeda dari HP musuh, yang lewat
`Balance.enemyHp`; dipatok di `damageTipe.hard4Player.*`). Jadi ini celah laten di
fungsi yang komentarnya sendiri mengklaim memvalidasi argumennya, bukan lubang
yang terbuka hari ini. Tetap layak ditutup: `CombatService` sudah memeriksa
`magnitude == math.huge` untuk arah serangan, jadi polanya memang dikenal di
repo ini — cuma terlewat di `CoreService`.

Ditutup di `CoreService.isValidAmount`, yang sekarang menolak `math.huge`
bersama NaN, non-number, dan angka <= 0 dalam satu gerbang. Ketiga assertion di
atas sekarang PASS tanpa ada yang diubah di `tests/`.

## Satu flaky yang sudah ditutup, dan satu yang belum

Studio mencetak ke Output yang sama dengan game. Pada satu dari tiga run
berturut-turut, test BOOT gagal karena warn **milik Studio**:

```
ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type
```

Pemisahannya sekarang pakai **allow-list**, bukan deny-list sampah Studio:
daftar sampah Studio bisa bertambah kapan saja tanpa kita tahu, sementara bentuk
keluaran kita dikendalikan repo ini. `T.gameWarnings()` hanya menerima warn yang
diawali `[NamaService]` — dicek, ke-19 pemanggilan `warn()` di `src/` memakai
awalan itu. `T.gameErrors()` hanya menerima error yang menyebut path di bawah
`ServerScriptService` / `ReplicatedStorage` / `ServerStorage`.

**Yang belum ditutup:** `warn("teks tanpa awalan")` yang suatu saat ditambahkan
di `src/` akan dilewatkan harness ini tanpa suara. Karena itu case BOOT ikut
mencetak isi pesan yang dibuang (`boot.pesanBukanMilikGameYangDiabaikan`),
supaya yang membaca hasil run selalu bisa melihat apa yang tidak dihitung.
Kalau nanti ada warn baru di `src/`, pertahankan awalan `[NamaService]`-nya.

## Efek samping terukur

Diukur dengan memantau proses dan jendela foreground tiap 0,5 detik selama satu
run:

| Hal | Hasil |
|---|---|
| Jendela Studio | Terbuka, terlihat (bukan headless) |
| Mencuri fokus | **Ya**, dari t≈1s sampai t≈10,5s |
| Fokus setelah selesai | Kembali ke jendela sebelumnya |
| Durasi per case | 11–16 detik (wall clock) |
| Menutup diri sendiri | Ya, tidak ada proses tertinggal |
| Place yang dibuka | Salinan di `%TEMP%`, bukan `build/codeverse.rbxl` |
| Studio sudah terbuka duluan | Belum diuji — jalankan saat Studio tertutup |

**Frame rate hanya sekitar 8 Hz**, bukan 60 Hz. `EnemyService.step()` memakai
`deltaTime` jadi logikanya tetap benar, tapi granularitasnya kasar: jangan
menulis assertion yang menuntut presisi sub-frame, dan jangan membandingkan
durasi absolut dengan angka yang diamati di playtest manual.

## Menambah case baru

1. Buat `cases/<nama>.luau`. File itu **tidak** standalone: `lib/prelude.luau`
   ditempel di depannya oleh runner, jadi `T` sudah tersedia. Bungkus isinya
   dengan `T.main(function() ... end)` supaya error di tengah jalan tetap
   menghasilkan baris `FAIL` dan `END` — tanpa itu, host menunggu sampai
   deadline dan runner melaporkan timeout, yang menyembunyikan penyebabnya.
2. Daftarkan di `CASES` di `run.luau` dengan `deadline` yang masuk akal.
3. `stylua tests/studio/` — CI memeriksa format `tests/` juga.

File case dimulai dengan `--!nocheck`, bukan `--!strict`. Bukan karena
malas: runner menempelkan `lib/prelude.luau` DI DEPAN file case, jadi directive
yang berlaku untuk file gabungan adalah milik prelude, dan directive di baris 1
file case berakhir di tengah file lalu jadi komentar biasa. Menulis `--!strict`
di situ memberi kesan file ini type-checked padahal tidak; dan kalau suatu hari
directive itu benar-benar berlaku, file case tidak akan lulus strict karena `T`
adalah global yang tidak dideklarasikan.

**Dua jebakan yang sudah pernah menjerat:**

1. **Jembatan log-nya asinkron.** Baris yang di-`print` SELAMA run belum tentu
   langsung terbaca `T.logContains` / `T.logFind`: host baru menuangkan sadapan
   `LogService` ke `ReplicatedStorage` beberapa saat kemudian. Sekali baca
   langsung setelah aksi akan lolos atau gagal tergantung timing — flaky yang
   paling mahal, karena dia hijau di mesinmu. Bungkus dengan
   `T.waitUntil(function() return T.logContains(...) end)`. Case yang cuma
   membaca baris boot tidak kena, karena log itu sudah lama tertuang sebelum
   assertion pertama jalan.

2. **Kebersihan state antar case bergantung pada satu sesi Studio per case.**
   Assertion prasyarat seperti `prasyarat.arenaKosong` dan
   `prasyarat.coreHpPenuh` benar karena runner memanggil `run-in-roblox` sekali
   untuk tiap case, jadi tiap case dapat sesi bersih. Kalau suatu saat beberapa
   case digabung ke satu sesi demi kecepatan, assertion prasyarat di SEMUA case
   mulai saling bergantung pada urutan dan akan gagal dengan cara yang sangat
   membingungkan. Tetap bersihkan jejak di akhir case (`setRunning(false)`,
   `clearAll()`, `CoreService.reset()`) supaya penggabungan itu tetap mungkin.

Pakai `T.skip(nama, alasan)` untuk hal yang harness ini memang tidak bisa
jangkau, dan **sebutkan alasannya**. Runner mencetak jumlah SKIP terpisah dari
PASS dengan pengingat "dilewati = tidak dites sama sekali, bukan lulus",
justru supaya laporan tidak pernah terlihat hijau untuk sesuatu yang tidak
pernah dijalankan.
