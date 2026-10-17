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

### `assets/Arena.rbxmx` sudah ada — lewati bagian ini

Arena graybox-nya **sudah ada di repo**, sudah ter-mount ke `Workspace.Arena`,
dan strukturnya sudah diverifikasi terhadap kontrak penanda di bagian 3.4:
`CoreServer` adalah Model dengan `PrimaryPart` bernama `Core`, `Lanes` berisi
`Lane1` dan `Lane2` yang masing-masing punya tujuh waypoint bernama `1` sampai
`7` berurutan, dan `PlayerSpawn` adalah SpawnLocation. Place hasil `rojo build`
sudah dibaca ulang untuk memastikan semuanya sampai utuh.

`assets/Lobby.rbxmx` yang belum ada — itu dibuat di M5.0.

Perlu **mengubah** layout arena (jumlah waypoint, jaraknya, ukuran lantai)?
Setel konstanta di bagian atas `scripts/build_arena.luau`, lalu:

1. View → **Command Bar**.
2. Tempel seluruh isi `scripts/build_arena.luau`, Enter. Script-nya idempoten:
   `Workspace.Arena` yang lama dihapus dulu, jadi aman dijalankan berkali-kali.
3. Script memilih `Workspace.Arena` otomatis. Klik kanan → **Save to File**.
4. Simpan sebagai `assets/Arena.rbxmx`, dan **pastikan tipe filenya `.rbxmx`,
   bukan `.rbxm`.** Studio sering memilih `.rbxm` (binary) sebagai default, dan
   kalau itu yang kepilih, dua hal gagal tanpa satu pun peringatan: file-nya
   kena aturan `*.rbxm` di `.gitignore` jadi tidak akan pernah ter-commit, dan
   mapping Rojo mencari `.rbxmx` jadi arena-nya tidak akan pernah muncul. Ini
   sudah pernah kejadian sekali di project ini.
5. Commit filenya.

Tanpa `Workspace.Arena`, server tetap boot normal, mengeluarkan **satu** warn
dari `MapService`, lalu tidak menjalankan gameplay apa pun. Itu disengaja, bukan
crash — dan justru itu yang dites di M1.1.

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

---

## M4 — Boss

**Yang sudah diverifikasi otomatis:** `BossRules.luau` punya 16 unit test. Tiga
di antaranya menutup kasus pinggir yang masing-masing membuat boss kehilangan
satu fase **tanpa ada yang error** dan tidak akan pernah kelihatan dari playtest
biasa: satu serangan besar yang melewati 66% dan 33% sekaligus (harus memicu
dua-duanya, bukan satu), ambang yang terpicu berulang setiap kali boss dipukul
(harus sekali saja), dan boss yang mati langsung dari HP penuh (semua ambang
harus tetap terpicu). Plus validasi data: tiap boss punya `dropMaterial`, kartu
info dengan judul, isi, dan daftar pencegahan. Lint, type check, `rojo build`
hijau.

**Yang belum diverifikasi sama sekali:** apakah boss-nya benar-benar muncul,
apakah bar HP-nya tampil di tempat yang benar, apakah toko benar-benar terkunci,
dan apakah material masuk ke data pemain.

### M4.1 Splitter di wave 5

Supaya tidak perlu memainkan empat wave dulu tiap kali: sementara ubah
`src/shared/Modules/Waves.luau`, pindahkan `bossId = "boss_splitter"` ke wave 1
(dan `wave = 1` di `Bosses.luau`), sync, tes, lalu **balikkan lagi sebelum
commit**. Validasi `Waves.validate()` memeriksa `boss.wave` cocok dengan wave
yang memakainya, jadi kalau lupa mengubah keduanya server akan mencetak warn
saat boot.

1. F5, Ready, masuk wave yang ada boss-nya.

Diharapkan:
- Kubus merah besar (9x9x9) muncul **lebih dulu** dari musuh biasa, di lane 1.
- Panel **bar HP boss** muncul di bawah HUD utama dengan tulisan
  "Splitter — Worm" dan persentase HP.
- Persentase turun saat boss diserang, dan **tidak lebih sering dari 5 kali per
  detik** (HP disiarkan paling cepat tiap 0.2 detik dan cuma kalau angkanya
  berubah — kalau bar-nya berkedip tiap frame, dua pembatas itu tidak bekerja).
- Saat HP menyentuh **66%**: 4 musuh `fast` muncul **di posisi boss saat itu**,
  menyebar melingkar, dan langsung melanjutkan ke Core dari waypoint yang sama
  dengan boss — bukan dari awal lane.
- Saat HP menyentuh **33%**: 4 musuh `fast` lagi.
- Serang boss dengan damage besar sekaligus (sementara naikkan
  `Balance.DAMAGE_PER_LEVEL` atau `Weapons.weapon_starter.baseDamage`) sehingga
  HP-nya turun dari 70% ke 20% dalam satu serangan. **Harus muncul 8 musuh**,
  bukan 4: dua ambang terlewati sekaligus.
- Boss mati → bar HP boss hilang → **kartu info malware** muncul di tengah
  layar: judul "Worm", satu paragraf penjelasan, dan tiga butir cara mencegah.
- Kartu bisa ditutup dengan tombol **Tutup**, dan hilang sendiri setelah
  18 detik kalau dibiarkan.
- Wave **belum** dinyatakan bersih sampai musuh pecahannya juga habis.

### M4.2 Locker di wave 10

Cara yang sama: pindahkan `bossId = "boss_locker"` ke wave 1 untuk mengetesnya.

1. Masuk wave yang ada Locker-nya.

Diharapkan:
- Kubus merah sangat besar (11x11x11) muncul, bar HP boss bertulisan
  "Locker — Ransomware".
- Output server mencetak `[Locker] toko dikunci, memanggil 3 basic tiap 8 detik`.
- Tiap 8 detik, 3 musuh `basic` muncul **dari awal lane** (beda dari Splitter
  dengan sengaja: Locker memanggil bantuan dari luar, bukan memecah dirinya).
- Selesaikan wave sebelumnya supaya masuk jeda, lalu masuk wave Locker:
  **panel toko tetap terlihat saat jeda** tapi headernya bertulisan
  **"Dikunci — kalahkan boss-nya dulu"** dengan warna merah, dan semua
  tombolnya mati. Panelnya sengaja tidak disembunyikan — kalau disembunyikan,
  pemain tidak tahu bedanya "belum waktunya" dan "dikunci Locker", padahal yang
  kedua adalah mekanik yang harus dia sadari.
- Mencoba `R.BuyShopItem:FireServer("shop_barrier")` dari command bar client
  saat terkunci harus ditolak dengan `ActionResult` "Toko dikunci. Kalahkan
  boss-nya dulu."
- Boss mati → Output mencetak `[Locker] boss mati, toko dibuka lagi`, minion
  berhenti dipanggil, kartu info "Ransomware" muncul.

### M4.3 Kunci toko tidak nyangkut (ini yang paling mudah bocor)

1. Masuk wave Locker, lalu **jangan bunuh boss-nya** — biarkan Core hancur.
2. Setelah kembali ke lobby, tekan Ready lagi dan selesaikan wave 1.

Diharapkan: saat jeda setelah wave 1 match kedua, toko **buka normal**. Kalau
masih bertulisan "Dikunci", kunci dari Locker tidak dilepas lewat jalur
kematian-selain-dibunuh, dan tidak ada pemain yang bisa membukanya lagi.

Ulangi dengan cara keluar lain: saat wave Locker berjalan, tutup semua client
(match dibatalkan). Hasilnya harus sama.

### M4.4 Drop material ke SEMUA peserta — butuh 2 client

1. Sesi 2-player, kedua pemain Ready, kalahkan boss.

Diharapkan:
- **Kedua** pemain dapat material, bukan cuma yang menyerang paling banyak.
  Output server mencetak `[BossService] drop material_a x1 ke 2 peserta`.
- Periksa di command bar **server**:
  `print(game:GetService("ServerScriptService").Server.Services)` lalu baca
  data pemain lewat remote `GetProfile` dari masing-masing client:
  `game:GetService("ReplicatedStorage").Remotes.GetProfile:InvokeServer().materials`
  harus memuat `material_a = 1`.
- **Catatan penting:** sebelum place-nya di-publish sekali, material ini ada di
  memori saja dan hilang saat server mati. Itu bukan bug di M4 — lihat kotak
  DataStore di bagian Persiapan.

2. Ulangi, tapi tutup client ke-2 **sebelum** boss mati, lalu (di server live)
   join lagi dengan akun yang sama.

Diharapkan: material-nya dibayarkan saat dia rejoin, dan Output mencetak
`[BossService] material tertunda dibayarkan ke <nama>`. Peserta yang disconnect
boleh rejoin dan melanjutkan (bagian 3.3), jadi dropnya tidak boleh hilang hanya
karena dia sedang tidak di server saat boss mati.

### Keputusan M4 yang diambil tanpa menanyakan dulu

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Jalur HP boss ke client | Remote baru `BossState` | M4 minta "HP bar boss di HUD", dan payload `MatchState` yang sudah dipatok tabel bagian 3.6 tidak punya tempat untuk HP boss. Ini penambahan, bukan penggantian nama, jadi tidak ada yang bergeser dari tabel itu. |
| Material untuk peserta yang sedang disconnect saat boss mati | Dicatat sebagai **tertunda** dan dibayarkan saat dia rejoin | Bagian 3.3 mengizinkan peserta rejoin dan melanjutkan, jadi dropnya tidak boleh hilang hanya karena dia sedang tidak di server pada detik boss mati. Pembukuannya juga dipakai mengisi payload `MatchResult` di M5. |
| Posisi musuh pecahan Splitter | Dari **posisi boss saat itu**, melanjutkan dari waypoint yang sama | Inti mekaniknya adalah ancaman yang tiba-tiba dekat (Worm yang menyebar), bukan gelombang baru dari jauh. Disebar melingkar 6 stud karena musuh digerakkan lewat CFrame dan tidak bertabrakan satu sama lain — tanpa sebaran mereka menumpuk jadi satu dan pemain cuma melihat satu musuh dengan HP bar bertumpuk. |
| Posisi minion Locker | Dari **awal lane** | Beda dari Splitter dengan sengaja: Locker memanggil payload tambahan dari luar, bukan memecah dirinya sendiri. Bedanya juga membuat dua mekanik itu terasa berbeda saat dimainkan, bukan cuma beda angka. |
| Musuh pecahan saat boss mati | **Dibiarkan hidup** | Wave belum bersih sampai mereka juga habis, dan itu memang bagian dari mekaniknya. Menghapusnya saat boss mati akan membuat ambang 33% tidak ada konsekuensinya kalau pemain langsung membunuh boss sesudahnya. |
| Boss dibedakan dari apa | `mechanic.kind`, bukan id boss | `Types.BossMechanic` sudah ditulis sebagai tagged union untuk ini. Menambah boss baru yang memakai mekanik yang sama jadi tidak perlu menyentuh `BossService`. |
| Kartu info ditutup bagaimana | Tombol **Tutup** DAN hilang sendiri setelah 18 detik | Kartu muncul tepat setelah boss mati, dan saat itu bisa masih ada musuh pecahan berjalan ke Core. Pemain yang ingin terus bertarung tidak boleh dipaksa membaca dulu, tapi yang ingin membaca juga tidak boleh kehilangan kartunya karena salah klik. |

---

## M5 — Progres permanen & lobby

**Yang sudah diverifikasi otomatis:** `ProgressionRules.luau` punya 25 unit test
yang menutup seluruh daftar syarat tiga remote bagian 3.6 — upgrade (dimiliki,
belum max, koin cukup termasuk kurang satu koin), beli (belum dimiliki, metode
`buy`, harga terdefinisi), craft (belum dimiliki, metode `craft`, material cukup
termasuk kurang satu) — plus semuanya ditolak di luar state `Lobby`. Kurva
level diperiksa monoton, aman terhadap XP inf/NaN/negatif, dan loop naik
level-nya dibatasi. Satu test memeriksa material yang di-drop boss **cocok**
dengan bahan craft `weapon_boss_a`: kalau boss men-drop `material_b` sementara
craft butuh `material_c`, senjata itu tidak akan pernah bisa dibuat dan tidak
ada yang error. Lint, type check, `rojo build` hijau, 146 test Lune lulus.

**Yang belum diverifikasi sama sekali, dan sebagian TIDAK BISA diverifikasi
sampai place-nya di-publish:** semua kriteria persistensi. Baca kotak DataStore
di bagian Persiapan — sebelum place di-publish sekali, pemain jalan dengan data
default di memori dan tidak ada yang tersimpan. Jadi kriteria penerimaan M5
("keluar, join lagi, dan semua progres masih ada") **tidak bisa dites sama
sekali** sampai langkah itu dilakukan.

### M5.0 Membuat `assets/Lobby.rbxmx` (lakukan ini dulu)

1. View → **Command Bar**.
2. Tempel seluruh isi `scripts/build_lobby.luau`, Enter.
3. Script memilih `Workspace.Lobby` otomatis. Klik kanan → **Save to File** →
   simpan sebagai `assets/Lobby.rbxmx` di root repo.
4. Commit filenya. **Tidak perlu menyentuh `default.project.json`** — mapping
   `Lobby` sudah ada di sana dalam bentuk
   `"$path": { "optional": "assets/Lobby.rbxmx" }`, yang melewatkan file yang
   belum ada tanpa menggagalkan `rojo build` dan otomatis memakainya begitu
   filenya muncul. (Lihat tabel keputusan di bawah: bentuk `optional` sudah
   diuji empiris, bentuk `$path` biasa memang menggagalkan build.)
5. Restart `rojo serve` dan Connect lagi, lalu F5.

Diharapkan di Output server: **tidak ada** warn `[MapService] Lobby tidak
lengkap`. Kalau masih ada, nama instance-nya tidak persis `SpawnLocation` dan
`ReadyPad`.

Lobby ditaruh di Z = 400, jauh di belakang arena (lantai arena berakhir di
Z = 120). Jaraknya disengaja: karena lobby dan arena ada di satu place
(bagian 1.1), pemain yang ditahan di lobby harus dipisahkan dengan jarak, bukan
dengan kode.

### M5.1 Panel lobby

1. F5. Panel **Lobby** muncul di kiri layar.

Diharapkan:
- Header menampilkan level dan koin permanen.
- Dua tombol kesulitan: **Normal** aktif, **Hard (terkunci)** mati.
- Tiga baris senjata, dalam urutan: Patch Wrench, Packet Rifle, Fork Bomb.
  - Patch Wrench: "Level 1/10 · damage 25 · jarak dekat", judulnya bertanda
    **(dipakai)**, tombol "Pakai" mati (sudah dipakai), tombol "Upgrade 50".
  - Packet Rifle: "Belum dimiliki — 1500 koin", tombol "Beli 1500" mati karena
    koin belum cukup.
  - Fork Bomb: "Belum dimiliki — craft: material_a 0/5", tombol "Craft" mati.
- Tombol **Ready** di bawah.

### M5.2 Upgrade senjata

Supaya tidak perlu memainkan 15 match: dari command bar **server**, naikkan
koin pemain lewat remote contoh yang sudah ada, atau sementara ubah
`Config.DEFAULT_DATA.coins` ke 50000 dan restart playtest.

1. Tekan **Upgrade 50** berulang kali.

Diharapkan:
- Level senjata naik 1 tiap tekan, damage di baris detail naik, dan harga
  tombol naik (50 → 67 → 91 → ...).
- Koin di header turun sesuai harga.
- Di **level 10** tombolnya berubah jadi "Level maks" dan mati.
- Baris petunjuk di bawah menampilkan "Berhasil." sebentar tiap pembelian
  berhasil.

### M5.3 Beli dan craft

1. Dengan koin ≥ 1500, tekan **Beli 1500** di Packet Rifle.

Diharapkan: senjata jadi dimiliki ("Level 1/10 · damage 14 · jarak jauh"),
tombolnya berubah jadi "Upgrade 50", dan tombol "Pakai" jadi aktif.

2. Tekan **Pakai**, lalu Ready dan masuk wave.

Diharapkan: serangan sekarang mengenai musuh **jauh** (sampai 60 stud), bukan
cuma yang di depan. Ini jalur `ranged` di CombatService: silinder di sekitar
garis bidik, bukan kerucut.

3. Kalahkan boss sampai punya `material_a` 5 buah (satu boss men-drop 1, jadi
   lima kali — atau sementara ubah `Weapons.weapon_boss_a.acquire.materials`
   ke `{ material_a = 1 }` untuk mengetesnya).
4. Di lobby, tekan **Craft**.

Diharapkan: Fork Bomb jadi dimiliki, material terpotong, dan saat dipakai satu
serangan mengenai **sampai 3 musuh sekaligus** (`projectiles = 3`).

### M5.4 Reward akhir match

1. Selesaikan satu match sampai menang (atau kalah).

Diharapkan di layar hasil: koin dan XP **bukan nol lagi** (di M2 memang nol,
karena RewardService belum ada). Angkanya harus sama dengan yang masuk ke
header lobby setelah kembali — kalau layar hasil bilang "+120 koin" tapi
header cuma naik 100, ada dua jalur yang menghitung berbeda.

Output server mencetak satu baris per pemain:
`[RewardService] <nama>: wave 10 menang, +150 koin, +300 xp, naik 2 level, membuka hard`

### M5.5 First clear membuka Hard

1. Menangkan satu match di Normal (wave 10 bersih).

Diharapkan:
- Layar hasil memuat baris **"Terbuka: hard"**.
- Setelah kembali ke lobby, tombol **Hard** jadi aktif (tidak lagi "terkunci").
- Menangkan lagi di Normal: layar hasil **TIDAK** lagi memuat "Terbuka: hard".
  Kalau masih, daftar yang baru terbuka dibandingkan salah dan pemain akan
  melihat pesan itu setiap match selamanya.

2. Pilih **Hard**, Ready, masuk wave 1.

Diharapkan: musuh butuh lebih banyak serangan (hpMult 1.8), dan reward koin di
akhir lebih besar (rewardMult 1.6).

### M5.6 Pemain yang keluar di tengah match tetap dapat reward (bagian 3.3)

1. F5, Ready, mainkan sampai wave 4, lalu **tutup client**-nya.

Diharapkan di Output server:
`[RewardService] <nama>: wave 4 tidak selesai/kalah, +40 koin, +80 xp`
— tanpa bonus menang, tapi tetap dapat reward sesuai wave saat dia keluar.

2. Yang penting: pemain itu **tidak boleh dibayar dua kali**. Di server live,
   keluar di wave 4 lalu rejoin dan ikut sampai match selesai harus memberi
   satu pembayaran saja. Kalau dua, keluar-lalu-rejoin jadi cara menggandakan
   reward.

### M5.7 Persistensi — BUTUH PLACE YANG SUDAH DI-PUBLISH

Langkah ini **tidak bisa dijalankan** sampai place-nya di-publish sekali
(File → Publish to Roblox) **dan** Game Settings → Security → Enable Studio
Access to API Services dicentang. Sebelum itu, Output server akan memuat warn
`[PlayerDataService] ... jalan dengan data default di memori. Progres TIDAK
tersimpan.` dan seluruh langkah di bawah dijamin gagal — bukan karena bug.

1. Publish place-nya sekali, centang API Services, restart Studio.
2. F5. Output server **tidak** lagi memuat warn data default di memori.
3. Mainkan satu match, upgrade senjata, beli Packet Rifle.
4. Stop playtest, F5 lagi.

Diharapkan: level, koin, level senjata, senjata yang dibeli, material, dan
`unlockedDifficulties` **semuanya masih ada**. Ini kriteria penerimaan M5 di
rencana development, dan satu-satunya yang membuktikan dua lapis progres di
CONCEPT.md benar-benar bekerja.

5. Tes dobel-save: keluar di tengah match (reward dibayar), lalu join lagi
   cepat. Koin tidak boleh bertambah dua kali untuk match yang sama.

### M5.8 Tutorial pemain baru

1. Pakai akun/karakter yang `stats.matchesPlayed`-nya masih 0 (pemain baru).

Diharapkan: panel **PANDUAN** muncul di bawah layar, satu langkah per momen
baru, masing-masing **sekali saja** per sesi:
- di lobby: "Selamat datang di CodeVerse..."
- saat hitung mundur, saat wave 1, saat wave 2, saat jeda pertama, saat boss
  pertama muncul, dan saat match selesai.
- Tiap panel hilang sendiri setelah 12 detik.

2. Selesaikan satu match, lalu kembali ke lobby.

Diharapkan: panduan **tidak muncul lagi** (`matchesPlayed` sudah ≥ 1). Di
Studio tanpa DataStore, `matchesPlayed` ada di memori saja, jadi restart
playtest akan membuat panduannya muncul lagi — itu benar, bukan bug.

### M5.9 Remote progres tidak bisa disalahgunakan

Dari command bar **client**:

```lua
local R = game:GetService("ReplicatedStorage").Remotes
R.UpgradeWeapon:FireServer()                      -- nil
R.UpgradeWeapon:FireServer(42)                    -- tipe salah
R.UpgradeWeapon:FireServer("weapon_ranged")       -- belum dimiliki
R.BuyWeapon:FireServer("weapon_starter")          -- sudah dimiliki
R.BuyWeapon:FireServer("weapon_boss_a")           -- bukan dijual, tapi craft
R.CraftWeapon:FireServer("weapon_ranged")         -- bukan craft, tapi dijual
R.CraftWeapon:FireServer("weapon_boss_a")         -- material kurang
for _ = 1, 200 do R.UpgradeWeapon:FireServer("weapon_starter") end -- spam
```

Diharapkan: **tidak ada error di Output server**, setiap penolakan membalas
`ActionResult` dengan alasannya (terlihat di baris petunjuk panel lobby), dan
yang paling penting: **koin dan material tidak berubah sama sekali** setelah
semua percobaan di atas. Spam dibatasi 2 per detik.

Ulangi ketiga remote itu **saat match sedang berjalan**. Semuanya harus
ditolak dengan alasan "cuma bisa di lobby".

### Keputusan M5 yang diambil tanpa menanyakan dulu

| Keputusan | Yang dipilih | Alasan |
|---|---|---|
| Mapping `Lobby` di `default.project.json` | **Ditambahkan sekarang** sebagai `"$path": { "optional": "assets/Lobby.rbxmx" }` | Diuji empiris: `"$path": "assets/Lobby.rbxmx"` biasa membuat `rojo build` gagal keras selama filenya belum ada, jadi CI merah — itu sebabnya mapping-nya ditunda. Bentuk `optional` melewatkan path yang tidak ada tanpa error dan otomatis memakainya begitu filenya muncul, jadi masalahnya hilang tanpa perlu menunda. Konsekuensinya user tidak perlu menyentuh file proyek setelah men-generate lobby — satu langkah manual yang mudah terlupa jadi hilang. Mapping `Arena` dibiarkan dalam bentuk `$path` biasa karena filenya sudah ada. |
| Kurva level | `100 * 1.25^(level-1)` XP per level, maksimum 100 kenaikan per panggilan | Bagian 3.5 memberi rumus XP per match tapi tidak memberi kurva levelnya. Angkanya dipilih supaya match pertama yang kalah di wave 1 (20 XP) tidak langsung naik level, dan sepuluh match penuh yang menang mendarat di level 5 sampai 20 — dites eksplisit. Batas 100 kenaikan ada bukan karena ada yang bisa memberi XP sebanyak itu secara sah, tapi karena satu nilai XP yang rusak (inf, atau angka raksasa dari data korup) akan membuat loopnya berjalan selamanya dan menggantung thread yang memanggilnya; di server itu berarti pemain yang tidak pernah dapat reward tanpa ada yang tahu kenapa. |
| Urutan penyambungan `PlayerRemoving` | `RewardService.start()` dipanggil **sebelum** `PlayerDataService.start()` | Keduanya mendengarkan `Players.PlayerRemoving`, dan PlayerDataService menyimpan lalu MENGHAPUS cache data pemain di situ. Handler Roblox dijalankan dalam urutan penyambungan, jadi kalau PlayerDataService disambung lebih dulu, RewardService tidak punya data lagi untuk dibayar — dan pemain yang keluar di tengah match kehilangan rewardnya, tepat kasus yang diwajibkan bagian 3.3. |
| Pembayaran dobel | Pembukuan `paid` per UserId, direset saat **Countdown**, bukan saat match selesai | Pemain yang keluar di wave 7 sudah dibayar. Kalau pembukuannya dihapus saat `Ended`, dia bisa ikut dibayar lagi di akhir match yang sama kalau sempat rejoin — jadi keluar-lalu-rejoin menggandakan reward. |
| Material boss di layar hasil | Dibaca dari pembukuan BossService, **tidak** ditambahkan lagi | BossService sudah membayarkan materialnya saat boss mati (M4). Menambahkannya lagi di RewardService berarti satu boss memberi dua kali. |
| Tutorial | **Teks panduan saja, tanpa wave latihan**, dan seluruhnya di client | M5 mengizinkan "bisa berupa wave latihan dengan teks panduan" — jadi teks saja sudah memenuhi. Wave latihan butuh state keenam di MatchService, dan bagian 3.3 eksplisit bahwa service lain tidak boleh menambah atau mengubah state: menambah state demi tutorial menyentuh bagian paling rapuh dari seluruh sistem untuk keuntungan yang bisa didapat dengan teks. Dibuat di client karena semua yang diperlukan sudah ada di sana (`MatchState` memberi state dan wave, data pemain memberi `stats.matchesPlayed`), jadi tutorialnya tidak menambah satu remote pun. |
| "Pemain baru" diukur dari apa | `stats.matchesPlayed < 1` | Satu-satunya penanda yang sudah ada di skema bagian 3.1 dan yang artinya tidak ambigu. Menambah field `tutorialDone` berarti menambah field skema untuk sesuatu yang bisa disimpulkan. |
| ReadyPad: tombol atau penanda | **Penanda posisi**; tombol Ready yang sesungguhnya ada di UI | Bagian 3.4 cuma menyebut "Part untuk tanda siap". Tombol UI bisa dipakai di mobile (CONCEPT.md menargetkan mobile) dan tidak bergantung pada pemain berhasil menginjak satu Part. ReadyPad tetap dibuat dan tetap dibaca MapService supaya kontrak bagian 3.4 utuh. |
| Posisi lobby | Z = 400, 280 stud di belakang tepi arena | Lobby dan arena ada di satu place (bagian 1.1), jadi pemain yang ditahan di lobby harus dipisahkan dengan **jarak**, bukan dengan kode. Pada jarak itu pemain di lobby tidak bisa melihat atau menjangkau musuh di arena. |
