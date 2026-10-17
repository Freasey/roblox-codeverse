# Checklist verifikasi Studio

Dokumen ini ada karena satu alasan sederhana: **kode di repo ini ditulis tanpa
pernah dijalankan di Roblox Studio.** Semua yang ada di sini sudah lolos
`stylua --check`, `selene`, `luau-lsp analyze`, `lune run tests/run`, dan
`rojo build` — tapi lolos type check bukan berarti jalan di engine. Yang tidak
bisa diperiksa dari CI:

- apakah UI-nya kelihatan dan posisinya benar di layar,
- apakah musuh benar-benar bergerak dan HP bar-nya terlihat,
- apakah serangan terasa kena saat ping tinggi,
- apakah data tersimpan dan terbaca lagi setelah rejoin.

Dua hal yang **sudah** terverifikasi di Studio oleh playtest pertama, dan tidak
perlu dites ulang:

- **Relative require jalan di engine Roblox** (bagian 1.5). Place lokal
  dijalankan dan eksekusi sampai masuk ke `PlayerDataService`, artinya seluruh
  rantai require di atasnya sukses — termasuk `require(Shared.Config)`, dan
  `Config.luau` baris 5 adalah `require("./Modules/Types")`. Rencana cadangan di
  bagian 1.5 **tidak** dipakai.
- **API web Roblox tidak boleh dipanggil di module scope.** `GetDataStore` dulu
  dipanggil di module scope `PlayerDataService`; di place yang belum pernah
  di-publish, Roblox melempar error tepat di baris itu, require-nya gagal, dan
  SELURUH script server mati sebelum satu baris pun jalan — dengan pesan
  "Requested module experienced an error while loading" yang tidak menunjuk ke
  penyebabnya. Sudah diperbaiki jadi lazy + `pcall`. Aturan ini berlaku untuk
  semua kode berikutnya: `DataStoreService`, `OrderedDataStore`,
  `MessagingService`, `HttpService`, `MarketplaceService`, dan sejenisnya hanya
  dipanggil di dalam fungsi.

Jadi checklist di bawah ini adalah pengganti playtest. Satu bagian per
milestone, dengan langkah konkret dan hasil yang diharapkan. Kalau satu langkah
gagal, catat apa yang terjadi — itu bug nyata, bukan kesalahan pemakaian.

## Persiapan sekali saja

1. `rokit install` di root repo (butuh rojo, lune, stylua, selene, luau-lsp).
2. `rojo serve default.project.json`.
3. Buka Studio, buat place baru, install plugin Rojo, **Connect**.
4. **Game Settings → Security → Enable Studio Access to API Services** harus
   dicentang, kalau tidak `PlayerDataService` tidak bisa membaca DataStore dan
   akan mengeluarkan satu warn soal itu.

> **DataStore belum bisa dites sampai place-nya di-publish sekali.** Roblox
> menolak akses DataStore dari place yang belum pernah di-publish ke web,
> apa pun isi Game Settings. Sebelum itu, `PlayerDataService` menjalankan
> pemain dengan **data default di memori** dan tidak pernah menulis apa pun
> (`loaded` di-set false sehingga `save()` berhenti di gerbang pertamanya).
> Konsekuensinya: semua yang menyentuh progres permanen — `RewardService` dan
> `ProgressionService` di M5 — **tidak bisa diverifikasi** sampai place-nya
> di-publish satu kali. Gameplay per match tetap bisa dites penuh.

### Membuat `assets/Arena.rbxmx` (wajib sebelum apa pun bisa dites)

Repo ini **tidak punya** `assets/Arena.rbxmx` dan `assets/Lobby.rbxmx`, dan
file itu tidak bisa dibuat di luar Studio. Tanpa `Workspace.Arena`, server akan
boot normal, mengeluarkan **satu** warn dari `MapService`, lalu tidak
menjalankan gameplay apa pun. Itu perilaku yang disengaja, bukan crash.

1. View → **Command Bar**.
2. Tempel seluruh isi `scripts/build_arena.luau`, Enter. (File itu datang dari
   PR terpisah; kalau belum ada di branch ini, ambil dari PR "generator arena
   graybox".)
3. Script memilih `Workspace.Arena` otomatis. Klik kanan → **Save to File** →
   simpan sebagai `assets/Arena.rbxmx` di root repo.
4. Commit filenya.

Setelah file itu ada, `rojo build` dan live sync akan otomatis me-mount-nya ke
`Workspace.Arena` — mapping-nya sudah ada di `default.project.json`.

> **Prosedur edit map, jangan dilewati.** Rojo satu arah: begitu
> `assets/Arena.rbxmx` ter-mount, apa pun yang kamu ubah pada `Workspace.Arena`
> di Studio akan **hilang** pada sync berikutnya. Alurnya selalu: edit di
> Studio → **Save to File** timpa `assets/Arena.rbxmx` → baru commit.

---

## Keputusan yang diambil tanpa menanyakan dulu

Tiga hal di bawah tidak disebut rencana development dan jawabannya mengubah
arah, jadi dipilih yang paling konservatif lalu dicatat di sini.

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Mapping `assets/` di `default.project.json` saat filenya belum ada | Mapping **ditambahkan sekarang**, memakai `"$path": { "optional": "..." }` | Diuji empiris: `"$path": "assets/Arena.rbxmx"` biasa membuat `rojo build` **gagal keras** ("could not be turned into a Roblox Instance") dan CI jadi merah. Bentuk `optional` membuat rojo melewatkan path yang tidak ada tanpa error, lalu otomatis memakainya begitu filenya muncul. Jadi mapping-nya tidak perlu ditunda sampai assetnya ada. |
| Tabrakan fisik musuh | `CanCollide = false` | Musuh adalah Part **anchored** yang digerakkan lewat `CFrame`. Part anchored yang bertabrakan dengan karakter akan mendorong pemain ke dalam geometry atau menahan musuh di tempat. Uji kena serangan tidak memakai tabrakan sama sekali (bagian 3.7), jadi tidak ada yang hilang. |
| Tiga remote tambahan di luar tabel bagian 3.6 | `BossState`, `ShopState`, `ActionResult` ditambahkan | Milestone-nya memintanya tapi tabel 3.6 tidak menyediakan jalurnya: HP bar boss (M4) tidak punya tempat di payload `MatchState` yang sudah dipatok, sisa jatah beli per item (M3) tidak boleh ditebak client, dan penolakan server tanpa jalur balasan membuat pemain mengira tombolnya rusak. Ketiganya **penambahan**, bukan penggantian nama, jadi tidak ada yang bergeser dari tabel 3.6. Alasan lengkapnya ada di komentar `src/shared/Remotes.luau`. |

`GetLeaderboard` dari tabel 3.6 **sengaja belum didaftarkan**: itu milestone M6,
dan `RemoteFunction` tanpa `OnServerInvoke` membuat client yang memanggilnya
menggantung selamanya.

---

## M1 — Prototipe pertarungan

**Yang sudah diverifikasi otomatis:** modul `Lanes`, `HitTest`, dan `RateLimit`
punya unit test Lune (31 case baru); `Balance` punya test bahwa wave terberat
memang melebihi `MAX_ACTIVE_ENEMIES` sehingga antrian spawn benar-benar
terpakai; semua file lolos lint, type check, dan `rojo build` dengan mapping
`assets/` aktif.

**Yang belum diverifikasi sama sekali:** semuanya di bawah ini.

### M1.1 Boot tanpa map (lakukan ini dulu, sebelum membuat Arena)

1. Jangan buat `assets/Arena.rbxmx`. Tekan **F5**.
2. Lihat Output server.

Diharapkan:
- `[CodeVerse] server booting (place 0)`
- `[CodeVerse] relative require OK — 10 wave tervalidasi`
- **Tepat satu** warn `[MapService] Arena tidak bisa dipakai: Workspace.Arena
  tidak ada. Gameplay tidak dijalankan. ...`
- Tidak ada error lain, tidak ada warn yang berulang tiap frame.
- HUD muncul di atas layar dengan "Wave 0 / 10", "Di lobby", bar Core penuh.

### M1.2 Boot dengan map

1. Buat `assets/Arena.rbxmx` (lihat Persiapan di atas), sync, F5.
2. Lihat Output server.

Diharapkan:
- `[MapService] Arena siap: 2 lane, waypoint di-cache (Lane1=7, Lane2=7)`
- Tidak ada warn dari `MapService`.
- Karakter muncul di `Arena/PlayerSpawn`, bukan di tengah lane.

### M1.3 Urutan waypoint benar

Ini yang paling mudah salah dan paling sulit dilihat (bagian 3.4).

1. Di Studio, buka `scripts/build_arena.luau`, ubah
   `DEBUG_VISIBLE_WAYPOINTS = true`, jalankan ulang di command bar, simpan
   ulang `assets/Arena.rbxmx`, sync, F5.
2. Perhatikan jalur satu musuh dari awal sampai Core.

Diharapkan: musuh lewat waypoint **1 → 2 → 3 → ... → terakhir** dalam satu
garis mulus menuju Core. **Tidak** zig-zag, tidak melompat, tidak berputar di
satu waypoint.

> Kalau lane-nya ditambah sampai 10 waypoint atau lebih, ulangi test ini.
> Di bawah 10 waypoint, sort string dan sort angka memberi hasil yang sama,
> jadi bug urutan baru muncul setelah ada waypoint bernama "10".

### M1.4 Musuh bergerak, HP bar terlihat, Core berkurang

1. F5, tunggu hitung mundur 5 detik.
2. Jangan menyerang. Biarkan musuh sampai ke Core.

Diharapkan:
- Musuh (kubus oranye = `basic`) meluncur sepanjang lane dengan kecepatan tetap.
- Setiap musuh punya bar HP kecil di atasnya (BillboardGui), hijau penuh.
- Bar HP **hilang dari pandangan** kalau musuh lebih jauh dari ~140 stud.
- Begitu musuh menyentuh Core, musuh hilang dan bar Core di HUD turun 5 poin.
- Warna Core bergeser ke merah seiring HP-nya turun.
- Core 0 → Output server mencetak `[CodeVerse] Core Server hancur`, HUD jadi
  "Match selesai", musuh dibersihkan, tidak ada error.

### M1.5 Serangan kena

1. F5, dekati musuh, klik kiri.

Diharapkan:
- Bar HP musuh turun setiap klik, tidak lebih cepat dari ~2 kali per detik
  (`weapon_starter` cooldown 0.5 detik — server yang menolak kelebihannya,
  bukan client).
- Musuh mati setelah 4 kali kena (25 damage, HP 100 di wave 1 solo).
- Menahan tombol kiri tetap menyerang terus, tidak perlu klik berulang.
- **Mengklik area UI tidak memicu serangan.**
- Mengklik ke arah berlawanan dari musuh **tidak** mengenainya.

### M1.6 Serangan terasa kena saat ping tinggi (bagian 3.7, jangan dilewati)

Ini test yang alasannya paling penting: musuh digerakkan server, jadi posisi di
layar pemain selalu tertinggal sebesar latensi. Kalau test ini gagal, naikkan
`Balance.MELEE_RADIUS_BONUS` / `Balance.RANGED_RADIUS`, jangan mencari bug di
`HitTest`.

1. Studio: **Test → Network Simulation → Bad Internet** (atau Terrible).
2. F5, serang musuh `fast` (kubus hijau, wave 2 ke atas) yang sedang bergerak.

Diharapkan: serangan tetap terasa kena. Sesekali tidak kena itu normal;
**sering** tidak kena berarti toleransinya masih terlalu ketat.

### M1.7 Batas musuh aktif dan antrian

1. F5, lewati wave 1 dan 2 (atau ubah `PROTOTYPE_LAST_WAVE` sementara).
2. Hitung kasar jumlah musuh di layar saat wave 3.

Diharapkan: jumlah musuh yang ada bersamaan tidak pernah melewati
`Balance.MAX_ACTIVE_ENEMIES` (40), dan wave tetap bisa diselesaikan — musuh
sisanya muncul menyusul, tidak hilang. Kalau wave tidak pernah bersih, antrian
bocor.

### M1.8 Remote tidak bisa disalahgunakan

Dari command bar **client** (Test → Current: Client), coba satu per satu:

```lua
local R = game:GetService("ReplicatedStorage").Remotes
R.Attack:FireServer()                      -- nil
R.Attack:FireServer("bukan vector")        -- tipe salah
R.Attack:FireServer(Vector3.new(0, 0, 0))  -- arah nol
R.Attack:FireServer(Vector3.new(0/0, 0, 0))-- NaN
for _ = 1, 500 do R.Attack:FireServer(Vector3.new(0, 0, -1)) end -- spam
```

Diharapkan: **tidak ada error di Output server** untuk semuanya, dan spam tidak
membuat musuh mati lebih cepat dari cooldown senjata.

---

## M2 — Sistem wave & match

**Yang sudah diverifikasi otomatis:** `MatchRules.luau` punya 18 unit test,
termasuk yang memastikan pembagian musuh per wave jumlahnya **persis** sama
dengan `Balance.enemyCount` untuk ke-10 wave x 1 sampai 4 player (pembagian
naif kehilangan sisa bagi, dan satu musuh hilang per wave tidak akan pernah
kelihatan dari playtest — yang kelihatan cuma "kok wave-nya terasa lebih
gampang"). Lint, type check, dan `rojo build` hijau.

**Yang belum diverifikasi sama sekali:** seluruh state machine-nya, karena
setiap transisinya bergantung pada waktu nyata dan pada pemain yang benar-benar
join dan keluar.

`PrototypeDriver` dari M1 sudah dihapus. Match sekarang dimulai dengan menekan
Ready, bukan otomatis 5 detik setelah server boot.

### M2.1 Satu match penuh, solo

1. F5. HUD menampilkan "Wave 0 / 10", "Di lobby". Panel Ready muncul di bawah.
2. Tekan **Ready**.

Diharapkan, berurutan:
- State jadi "Match mulai dalam · 10s" dan hitungannya turun tiap detik.
- Pada 0, state jadi "Bertahan!" dan wave jadi 1. Musuh mulai muncul satu per
  ~0.9 detik, bergantian lane 1 dan lane 2.
- Musuh **tercampur tipenya**, tidak semua `basic` dulu lalu semua `fast`
  (periksa di wave 2 ke atas, yang punya lebih dari satu tipe).
- Wave bersih → state "Jeda — toko buka · 20s", musuh berhenti bergerak.
- Setelah 20 detik, wave 2 mulai. Begitu seterusnya.
- Boss di wave 5 dan 10 **belum ada** (itu M4). Output server mencetak
  `boss diabaikan (BossService belum ada)` dan wave-nya jalan sebagai wave
  biasa. Itu yang diharapkan di M2, bukan bug.
- Wave 10 bersih → layar **"Core Server aman!"** muncul dengan wave tercapai.
  Koin dan XP **0** — RewardService baru masuk di M5, dan menampilkan angka
  yang tidak pernah masuk ke data pemain lebih buruk daripada menampilkan nol.
- 10 detik kemudian layar hilang, state kembali "Di lobby", wave kembali 0.

### M2.2 Kalah

1. F5, tekan Ready, lalu **jangan menyerang sama sekali**.

Diharapkan: Core HP turun sampai 0 → layar **"Core Server jebol"** →
10 detik → kembali ke lobby. Output server mencetak
`[MatchService] match selesai: kalah di wave N (normal), 1 peserta`.

### M2.3 Match bisa diulang tanpa restart server

1. Setelah M2.1 atau M2.2 selesai dan kembali ke lobby, tekan **Ready** lagi.

Diharapkan: match kedua jalan dari wave 1 dengan Core HP penuh, dan tidak ada
musuh sisa dari match sebelumnya. Ini kriteria penerimaan M2 di rencana
development, dan yang paling mudah bocor: state yang tidak di-reset (wave,
participants, cooldown serangan, antrian spawn) baru kelihatan di match kedua.

### M2.4 Ready dibatalkan

1. F5, tekan Ready, lalu tekan **"Batal siap"** saat hitung mundur masih jalan.

Diharapkan: hitung mundur berhenti dan state kembali ke "Di lobby". Match tidak
dimulai.

### M2.5 Join/rejoin (bagian 3.3) — butuh 2 client

Studio: **Test → Clients and Servers → 2 players → Start**.

1. Kedua pemain tekan Ready. Match mulai; keduanya masuk `participants`.
2. Tutup window client ke-2 di tengah wave.

Diharapkan: match **terus jalan** untuk pemain pertama. Output server tidak
mencetak pembatalan.

3. Sekarang tutup window client pertama juga (semua peserta keluar).

Diharapkan: Output server mencetak
`[MatchService] semua peserta keluar, match dibatalkan dan kembali ke Lobby`,
dan state kembali Lobby. **Ini keputusan yang diambil tanpa menanyakan dulu**
— lihat tabel keputusan di bawah.

4. Ulangi dari langkah 1, lalu tutup client ke-2 dan **buka lagi** (Studio:
   mulai sesi 2-player baru tidak bisa rejoin, jadi ini baru bisa dites penuh
   di server live).

Diharapkan di server live: pemain yang rejoin masuk ke arena di
`Arena/PlayerSpawn` dan bisa menyerang lagi. Pemain yang **belum pernah** ikut
match berjalan ditahan di lobby: dia muncul di `Lobby/SpawnLocation` dan
`Attack`-nya ditolak server (tidak ada damage sama sekali), tapi HUD-nya tetap
menampilkan state dan wave yang sedang berjalan.

> Catatan: aturan rejoin penuh adalah kriteria **M6**, bukan M2. Yang harus
> jalan di M2 adalah `participants` berisi UserId dan match tidak ikut mati
> saat satu peserta keluar.

### M2.6 Skala jumlah player

1. Sesi 2-player, kedua pemain Ready, perhatikan Output server di awal wave 1.

Diharapkan: `[WaveService] wave 1: N musuh biasa di 2 lane, 2 player` dengan N
lebih besar daripada saat solo (solo wave 1 = 8 musuh; 2 player = 10). HP musuh
juga naik, tapi itu tidak terlihat dari Output — yang terlihat adalah musuh
butuh lebih banyak serangan untuk mati.

### M2.7 Remote tidak bisa disalahgunakan

Dari command bar **client**:

```lua
local R = game:GetService("ReplicatedStorage").Remotes
R.SetReady:FireServer()                  -- nil
R.SetReady:FireServer("ya")              -- tipe salah
R.SelectLoadout:FireServer(1, 2)         -- tipe salah
R.SelectLoadout:FireServer("weapon_boss_a", "normal") -- belum dimiliki
R.SelectLoadout:FireServer("weapon_starter", "hard")  -- belum terbuka
for _ = 1, 200 do R.SetReady:FireServer(true) end     -- spam
```

Diharapkan: tidak ada error di Output server. Dua baris `SelectLoadout` yang
terakhir mengembalikan `ActionResult` dengan `ok = false` dan alasannya, dan
**tidak** mengubah `equippedWeapon`. Spam dibatasi 2 per detik, dan sisanya
dibuang tanpa error.

Coba juga saat match sedang jalan:

```lua
R.SetReady:FireServer(true)              -- di luar Lobby/Countdown
R.SelectLoadout:FireServer("weapon_starter", "normal") -- di luar Lobby
```

Diharapkan: dua-duanya ditolak. Yang kedua mengirim `ActionResult` "Cuma bisa
ganti loadout di lobby."

### Keputusan M2 yang diambil tanpa menanyakan dulu

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Koin match peserta yang disconnect | Tidak bisa hangus, karena **koin match disimpan sebagai satu kolam milik TIM**, bukan per pemain | Rencana development menyarankan "disimpan, jangan hangus". Kolam tim menyelesaikan itu tanpa kode tambahan: tidak ada saldo per pemain yang bisa hilang saat dia disconnect, dan saat rejoin dia langsung melihat saldo tim yang sama. Ini juga yang diminta M3 ("koin match per TIM") dan bagian 3.7 ("tambah koin match ke tim"). |
| Semua peserta keluar di tengah match | Match **dibatalkan**, state kembali ke `Lobby`, dan `onMatchEnded` **tidak** ditembakkan | Rencana development menyebut konsekuensi kalau tidak dibatalkan: server nyangkut di `WaveActive` tanpa pemain. Pembatalan sengaja bukan kekalahan — kalau `onMatchEnded` ditembakkan, RewardService (M5) akan menghitung reward untuk peserta yang sudah tidak ada di server, padahal reward mereka sudah dibayar satu per satu saat masing-masing keluar (bagian 3.3). |
| Dua pemain memilih kesulitan berbeda | Ambil yang **paling mudah** di antara pilihan mereka | Tidak disebut rencana development. `hard` harus dibuka dulu per pemain (bagian 3.1), jadi aturan apa pun yang mengambil yang lebih sulit bisa memaksa pemain ikut match pada tingkat yang belum dia buka. Mengambil yang termudah tidak pernah bisa melakukan itu. Diukur dari `hpMult`, bukan urutan tabel, supaya menambah tingkat baru nanti tidak perlu menyentuh fungsinya. |
| Pemain baru join saat Countdown | Hitung mundur **dibatalkan**, kembali ke Lobby | Syarat masuk Countdown di bagian 3.3 adalah "semua player di server menekan Ready". Pemain yang baru join otomatis belum Ready, jadi syaratnya tidak lagi terpenuhi. Memeriksa syarat itu terus-menerus (bukan sekali saat masuk) adalah tafsir paling lurus dari aturannya, dan mencegah match dimulai dengan pemain yang tidak pernah menyatakan siap. |
| Tombol Ready ditaruh di mana | `LobbyController`, versi minimal (cuma tombol Ready + teks petunjuk) | Rencana development menaruh tombol Ready di `LobbyController`, yang milestone-nya M5. Tapi tanpa tombol itu tidak ada cara memulai match dan kriteria M2 tidak bisa diverifikasi sama sekali. Jadi file-nya dibuat sekarang dengan isi minimal, dan panel senjata/kesulitan/upgrade/craft menempel ke panel yang sama di M5. |

---

## M3 — Toko Match

**Yang sudah diverifikasi otomatis:** `ShopRules.luau` punya 18 unit test yang
menutup seluruh daftar penolakan bagian 3.6 — di luar `Intermission`, toko
terkunci boss, item tidak ada, jatah habis, koin kurang (termasuk kurang satu
koin, nol, dan negatif) — plus efek kumulatifnya (linear, monoton, berlantai)
dan konsistensi `ShopItems.order` dengan `ShopItems.byId`. Lint, type check, dan
`rojo build` hijau.

**Yang belum diverifikasi sama sekali:** apakah panelnya muncul di tempat yang
benar, apakah penghalang dan turret kelihatan dan benar-benar berpengaruh, dan
apakah efek damage/attack speed terasa di wave berikutnya.

### M3.1 Toko buka dan tutup pada waktu yang benar

1. F5, Ready, selesaikan wave 1.

Diharapkan:
- Saat state "Jeda — toko buka", panel **Toko Match** muncul di kanan layar
  dengan lima item: Exploit Patch, Overclock, Hotfix, Firewall Block, Scanner
  Turret — **dalam urutan itu** (urutannya dari `ShopItems.order`; kalau
  berubah-ubah tiap kali client dibuka, daftar itu tidak dipakai).
- Header menampilkan jumlah koin tim, dan jumlahnya naik setiap musuh mati
  selama wave berjalan.
- Begitu jeda habis dan wave 2 mulai, panelnya **hilang**.

### M3.2 Tombol dinonaktifkan saat koin kurang

1. Di jeda pertama (koin masih sedikit), perhatikan tombol Scanner Turret
   (250 koin).

Diharapkan: tombolnya kelihatan abu-abu dan **mengkliknya tidak melakukan
apa-apa** — tidak mengirim remote, tidak mengurangi koin. Tombol yang harganya
di bawah saldo kelihatan biru dan bisa diklik.

### M3.3 Koin match per TIM, bukan per pemain — butuh 2 client

Sesi 2-player. Kedua pemain Ready.

Diharapkan:
- Kedua pemain melihat **angka koin yang sama persis**, dan angkanya naik
  siapa pun yang membunuh musuhnya.
- Kalau pemain A membeli Hotfix 150 koin, saldo di layar pemain B **ikut
  turun** 150.
- Jatah item juga dibagi tim: setelah A membeli Hotfix 3 kali (jatah maksimum),
  tombol Hotfix di layar B juga mati.

### M3.4 Efek tiap item benar-benar berpengaruh

Beli satu per satu dan lihat efeknya di wave berikutnya:

| Item | Yang harus terlihat |
|---|---|
| **Hotfix** | Bar Core di HUD naik 150 poin (15% dari 1000) **langsung saat dibeli**. Kalau Core sudah penuh, saldo tetap terpotong dan bar tidak berubah — itu benar, bukan bug. |
| **Exploit Patch** | Musuh mati dengan lebih sedikit serangan di wave berikutnya. `basic` wave 2 butuh 5 serangan tanpa buff; dengan satu Exploit Patch (+10%) jadi 5 juga, dengan tiga jadi 4. Lebih mudah diukur dengan menghitung serangan ke `tank`. |
| **Overclock** | Serangan bisa dikirim lebih cepat. Tahan klik kiri dan bandingkan ritme bar HP musuh yang turun, sebelum dan sesudah beli. |
| **Firewall Block** | Dinding biru tembus pandang muncul di tengah **kedua** lane tepat saat wave berikutnya mulai, dan musuh di lane itu **berhenti bergerak** selama 6 detik, lalu jalan lagi dan dindingnya hilang. Membeli dua kali menggandakan **durasinya** (12 detik), bukan jumlah dindingnya. |
| **Scanner Turret** | Balok hijau-kebiruan muncul mengelilingi Core. Saat wave jalan, dia menembak musuh terdekat sendiri (HP musuh turun tanpa kamu menyerang) kira-kira sekali per detik, dalam radius 70 stud. Turret kedua muncul di sudut berbeda, tidak menumpuk di atas yang pertama. |

### M3.5 Koin dan pembelian reset tiap match

1. Selesaikan satu match (menang atau kalah), beli beberapa item di dalamnya.
2. Kembali ke lobby, tekan **Ready** lagi.

Diharapkan: saldo koin **0** saat hitung mundur match kedua, semua tombol toko
kembali ke jatah penuh, dan **tidak ada turret sisa** dari match sebelumnya di
sekitar Core. Buff damage/attack speed juga tidak terbawa — kalau musuh wave 1
match kedua mati lebih cepat dari biasanya, pembukuan pembelian tidak
di-reset.

### M3.6 Server menolak pembelian yang tidak sah

Dari command bar **client**:

```lua
local R = game:GetService("ReplicatedStorage").Remotes
R.BuyShopItem:FireServer()                     -- nil
R.BuyShopItem:FireServer(123)                  -- tipe salah
R.BuyShopItem:FireServer("shop_tidak_ada")     -- id tidak ada
R.BuyShopItem:FireServer("shop_turret")        -- saat wave jalan (bukan jeda)
for _ = 1, 100 do R.BuyShopItem:FireServer("shop_barrier") end -- spam
```

Diharapkan: tidak ada error di Output server. Dua baris terakhir ditolak;
spam-nya dibatasi 2 panggilan per detik dan sisanya dibuang. Yang penting:
**saldo koin tidak berubah sama sekali** setelah semua percobaan di atas. Kalau
turun, ada jalur yang memotong koin sebelum validasinya lengkap.

Coba juga dari pemain yang **bukan peserta** (join saat match berjalan, di
server live): `R.BuyShopItem:FireServer("shop_barrier")` harus ditolak dengan
`ActionResult` "Kamu bukan peserta match ini."

### Keputusan M3 yang diambil tanpa menanyakan dulu

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Efek `shop_damage_up` dan `shop_fire_rate`: per pemain atau per tim | **Per tim** | M3 menyebut "upgrade damage tim". Selain itu koin match adalah satu kolam milik tim, jadi efek per-pembeli membuat pemain pertama yang menekan tombol memakai uang bersama untuk keuntungan pribadi. Deskripsi item di `ShopItems.luau` ikut diubah supaya tidak lagi berbunyi "senjatamu". |
| Penghalang dipasang di lane mana | **Semua lane**, dan beberapa pembelian menumpuk **durasinya** | Tabel bagian 3.6 memaku payload `BuyShopItem` jadi `itemId` saja, tanpa argumen lane. Menambah argumen berarti menyimpang dari tabel yang milestone berikutnya ikut pakai, dan menebak lane mana yang dimaksud pemain lebih buruk daripada efek yang jelas dan bisa diprediksi. Durasi yang menumpuk dipilih karena dua penghalang di lane yang sama pada waktu yang sama tidak menahan musuh dua kali lebih kuat. |
| Penghalang berlaku kapan | **Wave berikutnya**, bukan saat dibeli | Toko cuma buka saat `Intermission`, dan saat itu tidak ada musuh yang bergerak. Dipasang langsung berarti 6 detiknya habis sebelum ada yang perlu ditahan. |
| Posisi turret | Ditentukan **server**, mengelilingi Core, sudutnya dari nomor pembelian | Alasan yang sama dengan penghalang: payload-nya cuma `itemId`. Sudut dari nomor pembelian memastikan turret kedua tidak muncul menumpuk di atas yang pertama. |
| Pengali efek: linear atau berlipat | **Linear** (5 x +10% = 1.5x, bukan 1.61x), dengan lantai cooldown 0.4 | Harga item tetap, jadi efek yang berlipat akan meledak di pembelian terakhir. Linear juga bisa dihitung sendiri oleh pemain. Lantainya ada supaya menaikkan step nanti tidak bisa membuat cooldown senjata hilang sama sekali. |
| Siapa yang boleh membeli | Hanya pemain yang ada di `participants` | Tidak disebut bagian 3.6, tapi mengikuti aturan yang sama dengan `Attack`: pemain yang ditahan di lobby bukan bagian dari match yang sedang berjalan (bagian 3.3), jadi dia tidak boleh membelanjakan koin tim. |
