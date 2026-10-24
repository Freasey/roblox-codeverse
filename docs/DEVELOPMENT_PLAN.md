# CodeVerse: Rencana Development v1

Dokumen ini menerjemahkan [CONCEPT.md](CONCEPT.md) jadi pekerjaan teknis di repo
ini. Workflow tetap seperti di README: source of truth di disk, Studio cuma
viewer lewat Rojo.

> **Revisi 2 — 2026-10-17.** Revisi ini menambahkan bagian 0 (asumsi), 1.5 (pola
> require), 1.6 (pipeline aset 3D), dan 9 (rencana pemotongan scope); memperluas
> 1.4, 3.1, 3.2, 3.3, dan 3.7; serta mengubah M0 dan M1. Alasan tiap perubahan
> ditulis di tempatnya, bukan dikumpulkan di satu daftar.

Dokumen ini adalah **rencana**. Untuk keadaan sebenarnya sekarang — milestone
mana yang sudah tutup, apa yang sudah terverifikasi dan dengan cara apa, dan apa
langkah berikutnya — lihat [STATUS.md](STATUS.md). Kalau keduanya berbeda,
STATUS.md yang benar.

## 0. Asumsi dan keputusan

Tiga asumsi di bawah ini dipakai sepanjang dokumen. Kalau ada yang salah,
bagian yang terpengaruh perlu ditulis ulang — jadi koreksi dulu sebelum mulai
M0.

| Asumsi | Dampak kalau salah |
|---|---|
| Tujuannya ganda: laporan kuliah (pemetaan GDLC di bagian 5) **dan** game yang benar-benar dipublikasikan | Kalau murni kuliah, aturan rejoin di 3.3 dan polish di M7 bisa diturunkan drastis |
| Dikerjakan sendirian | Kalau ada tim, pemotongan di bagian 9 tidak perlu dipakai dan M1 sampai M5 bisa paralel |
| Belum ada deadline keras | Kalau ada, bagian 9 wajib dibaca sekarang, bukan nanti |

Keputusan yang sudah diambil dan tidak perlu dibahas ulang:

| Keputusan | Isi | Rinciannya di |
|---|---|---|
| Join di tengah match | Pemain yang belum pernah ikut match berjalan **tidak** bisa masuk; pemain yang tadinya ikut lalu disconnect **boleh** rejoin dan lanjut | 3.3 |
| Aset 3D | Dibuat sendiri di Blender, `.blend` jadi sumber di repo, export `.fbx` untuk import | 1.6 |
| Pola require | Relative string require (`require("./Enemies")`), tanpa alias custom | 1.5 |

## 1. Keputusan arsitektur

### 1.1 Satu place dulu

v1 pakai **satu place**: lobby dan arena ada di server yang sama, dengan
`Players.MaxPlayers = 4`. Satu server = satu tim = satu match pada satu waktu.

Alasannya: TeleportService dan reserved server menambah banyak kasus gagal
(teleport timeout, data belum ke-save sebelum pindah server) yang belum perlu di
v1. Kalau nanti butuh lobby sosial yang ramai, pisahkan jadi place Lobby dan
place Arena (lihat bagian 7).

### 1.2 Server memutuskan semuanya

Mengikuti aturan di README:

- Client cuma kirim **niat** (`Attack` dengan arah bidik, `BuyItem` dengan id
  item, dst).
- Server yang menghitung damage, mengecek koin, mengecek cooldown, dan
  menentukan reward.
- Semua angka balancing ada di modul shared, tapi server tidak pernah memakai
  angka yang dikirim client.

### 1.3 Musuh tanpa Humanoid

Musuh dibuat sebagai `Model` dengan `PrimaryPart` anchored, digerakkan server
lewat `CFrame` mengikuti waypoint jalur (lane). Tidak pakai Humanoid dan
PathfindingService karena:

- jauh lebih ringan untuk 30 sampai 40 musuh aktif sekaligus
- jalur ke Core Server sudah tetap, jadi tidak perlu pathfinding

Batas musuh aktif: `Balance.MAX_ACTIVE_ENEMIES = 40`. Sisa spawn masuk antrian.

Konsekuensi yang menguntungkan dan sebaiknya disadari sekarang: musuh yang cuma
meluncur sepanjang waypoint **tidak butuh rig dan tidak butuh animasi**. Itu
memotong bagian paling makan waktu dari pekerjaan 3D di M7 (lihat 1.6). Rig baru
perlu kalau nanti mau animasi jalan, dan itu masuk bagian 7.

### 1.4 Map disimpan sebagai file di repo

Geometry arena dan lobby dibuat di Studio, lalu disimpan sebagai
`assets/Arena.rbxmx` dan `assets/Lobby.rbxmx` (format XML, masih bisa di-review
di git), dan di-mount lewat `default.project.json` ke `Workspace`. Titik spawn,
waypoint lane, dan posisi Core Server ditandai dengan Part bernama khusus (lihat
bagian 3.4) supaya kode tidak bergantung pada koordinat.

Mapping-nya **belum ada** di `default.project.json` dan harus ditambahkan di M1:

```json
"Workspace": {
  "Arena": { "$path": "assets/Arena.rbxmx" },
  "Lobby": { "$path": "assets/Lobby.rbxmx" }
}
```

**Prosedur edit map — baca ini sebelum menyentuh arena di Studio.** Rojo bekerja
satu arah: dia membaca file di disk lalu menimpa Instance yang bersangkutan di
Studio. Artinya begitu `assets/Arena.rbxmx` ter-mount, apa pun yang kamu ubah
pada `Workspace.Arena` di dalam Studio akan **hilang** pada sync berikutnya,
tanpa peringatan dan tanpa bisa di-undo. Jadi alurnya:

1. Edit arena di Studio seperti biasa.
2. **Sebelum** sync apa pun: klik kanan `Workspace.Arena` → **Save to File** →
   timpa `assets/Arena.rbxmx`.
3. Baru commit.

Kalau lupa langkah 2, kerjaannya hilang. Ini risiko manusia, bukan risiko
teknis, jadi mitigasinya juga manusia: kerjakan map dalam sesi terpisah dari
coding, dan commit tiap kali selesai satu sesi.

### 1.5 Pola require: relative string require

**Dari awal.** Di Roblox, `require` secara historis hanya menerima **Instance**,
bukan string. `require(script.Parent.Enemies)` artinya "ambil ModuleScript
bernama `Enemies` yang bersebelahan denganku di pohon Instance". Pola itu jalan
sempurna di dalam Roblox — dan tidak jalan sama sekali di luar Roblox. Lune,
runtime Luau yang dipakai di CI untuk unit test, tidak punya pohon Instance dan
tidak punya variabel `script`. File apa pun yang memakai pola itu langsung error
begitu di-require dari test.

**Masalahnya.** Rencana testing di bagian 6 mewajibkan test "setiap wave di
`Waves.luau` hanya memakai id musuh yang ada di `Enemies.luau`". Test itu
memaksa `Waves` membaca `Enemies`, jadi harus ada satu cara require yang
dimengerti Roblox **dan** Lune. Syarat "modul harus murni, tidak memanggil
`game:GetService`" saja tidak cukup — `script` sama-sama tidak ada di Lune.

**Keputusan.** Pakai **relative string require**: `require("./Enemies")` untuk
modul sebelahan, `require("../Config")` untuk naik satu tingkat. Luau punya
fitur require-by-string, dan bentuk relatifnya sudah aktif di engine Roblox.
Lune memakai sintaks relatif yang sama. Karena Rojo memetakan folder di disk ke
Folder di pohon Instance satu-ke-satu, `./Enemies` menunjuk modul yang sama di
dua runtime itu: sibling di pohon Instance saat jalan di Roblox, file sebelahnya
di disk saat jalan di Lune. Satu baris kode, tanpa build step, tanpa shim.

**Yang sengaja tidak dipakai: alias custom di `.luaurc`.** Alias seperti
`require("@shared/Enemies")` jalan di Luau standalone dan dikenali luau-lsp
untuk analisis, tapi engine Roblox **belum** mendukung alias custom saat
runtime. Kode yang memakainya lolos type check di CI lalu error di Studio —
kegagalan paling mahal, karena lolos dari semua pengecekan otomatis. `.luaurc`
boleh ada untuk kenyamanan editor, tapi jangan sampai ada alias custom di jalur
require yang benar-benar dieksekusi.

**Verifikasi dulu, jangan diasumsikan.** Tugas pertama M0 adalah smoke test:
satu modul dummy yang me-require sibling-nya secara relatif, dijalankan dua
kali — sekali lewat `lune run`, sekali lewat playtest Studio. Baru setelah
dua-duanya hijau, modul lain ditulis dengan pola ini.

**Rencana cadangan kalau smoke test gagal di Studio.** Ubah modul yang dites
supaya menerima data lewat argumen, bukan me-require: `Waves.validate(enemies)`
daripada `Waves` memanggil `require("./Enemies")` sendiri. Biayanya kecil karena
modul-modul itu memang sudah dirancang murni, dan test tinggal mengoper tabel.
Jadi kegagalan verifikasi ini tidak membatalkan apa pun, cuma menggeser siapa
yang menyusun dependensinya.

**Satu jebakan lagi:** jangan mengandalkan `require(folder)` yang otomatis
mengambil `folder.init`. Perlakuan khusus itu sudah dihapus Roblox. Kalau butuh
modul induk, jadikan foldernya ModuleScript (lewat `init.luau` di Rojo) dan
akses anaknya dengan alias bawaan `@self/Nama` — `@self` berbeda dari alias
custom dan memang didukung.

### 1.6 Pipeline aset 3D

**Dari awal.** Roblox tidak memakai file 3D saat game berjalan. Waktu sebuah
mesh di-import, Studio meng-upload geometrinya ke server Roblox, yang
mengubahnya jadi aset internal dengan sebuah **asset ID**. `MeshPart` di place
cuma menyimpan ID itu di properti `MeshId`; file `.fbx`-nya sendiri tidak pernah
ikut terkirim ke pemain. Jadi format file hanya menentukan kelancaran saat
import, bukan performa game.

Importer Roblox menerima `.fbx`, `.obj`, dan `.gltf`/`.glb`. `.fbx` dan `.gltf`
mendukung hierarki banyak mesh, tekstur PBR, rig, dan data animasi; `.obj` cuma
geometri statis.

**Keputusan: `.blend` sebagai sumber, export `.fbx` untuk import.** Bukan karena
FBX lebih baik secara teknis dari glTF — keduanya didukung penuh — tapi karena
panduan export-settings Blender di dokumentasi Roblox ditulis untuk FBX, dan
hampir semua troubleshooting komunitas (skala salah, orientasi kebalik, normal
kebalik) dibahas dalam konteks FBX. Satu format menutup statis, rigged, dan
ber-animasi, jadi tidak perlu dua pipeline.

**Budget poligon.** Batas keras Roblox adalah 20.000 triangle per mesh dan
maksimal 4 bone per vertex. Batas itu praktis tidak relevan di sini: bagian 1.3
mengizinkan 40 musuh aktif sekaligus dan CONCEPT.md menargetkan mobile juga.
40 x 20.000 = 800.000 triangle, jauh di luar anggaran. Target realistis:

| Aset | Target triangle |
|---|---|
| Musuh biasa | 200 sampai 500 |
| Boss | beberapa ribu (cuma satu di layar) |
| Props arena | 100 sampai 300 |

Low poly di sini bukan sekadar pilihan gaya, tapi kebutuhan performa — dan
kebetulan juga yang paling cepat dikerjakan satu orang.

**Struktur di repo.**

- `art/` untuk file `.blend`. **Terpisah** dari `assets/`, karena `assets/`
  di-mount Rojo ke dalam DataModel dan file `.blend` tidak boleh nyangkut di
  sana.
- `.blend` dan `.fbx` itu binary dan tidak bisa di-merge git. Tandai di
  `.gitattributes` sebagai `binary`, dan satu file hanya diedit satu orang pada
  satu waktu. Untuk low poly ukurannya kecil (puluhan KB sampai beberapa MB),
  jadi Git LFS belum perlu; baru dipertimbangkan kalau tekstur mulai besar.

**Bagian yang menyakitkan, lebih baik tahu sekarang.** Karena hasil upload jadi
asset ID, `assets/Enemies/*.rbxmx` akan menyimpan ID itu di dalamnya. Tiap kali
model diubah, alurnya: export ulang dari Blender → import ulang di Studio (dapat
ID baru) → simpan ulang `.rbxmx` → commit. Iterasi visual tidak gratis. Ada Open
Cloud assets API untuk mengotomatiskannya, tapi itu jelas bukan pekerjaan v1.

## 2. Struktur folder target

```
.luaurc                           opsional, cuma kenyamanan editor —
                                  JANGAN taruh alias custom di jalur require
src/
  server/
    init.server.luau              (sudah ada, nanti cuma bootstrap service)
    Services/
      PlayerDataService.luau      (sudah ada, diperbaiki di M0 — lihat 3.2)
      MatchService.luau           state machine match
      WaveService.luau            jadwal & spawn wave
      EnemyService.luau           entitas musuh, gerak, HP
      BossService.luau            dispatcher perilaku boss
      Bosses/
        Splitter.luau
        Locker.luau
      CombatService.luau          validasi serangan player
      CoreService.luau            HP Core Server
      ShopService.luau            Toko Match (koin match)
      RewardService.luau          hitung & simpan reward akhir match
      ProgressionService.luau     upgrade, beli, craft senjata (lobby)
      LeaderboardService.luau     OrderedDataStore wave tertinggi
  client/
    init.client.luau              (sudah ada, nanti bootstrap controller)
    Controllers/
      InputController.luau        klik/tap -> Remotes.Attack
      HudController.luau          HP core, wave, koin match, timer
      ShopController.luau         UI Toko Match
      LobbyController.luau        menu lobby, pilih senjata & kesulitan
      ResultController.luau       layar hasil match
      InfoCardController.luau     kartu info malware setelah boss
      FxController.luau           efek hit, angka damage
  shared/
    Config.luau                   (sudah ada, skema data diperluas)
    Remotes.luau                  (sudah ada, daftar remote ditambah)
    Modules/
      Types.luau                  tipe bersama (PlayerData, EnemyDef, WeaponDef)
      Weapons.luau                definisi senjata + kurva upgrade
      Enemies.luau                definisi musuh
      Bosses.luau                 definisi boss + teks kartu info
      Waves.luau                  komposisi tiap wave
      Difficulties.luau           pengali tiap tingkat
      ShopItems.luau              item Toko Match
      Balance.luau                rumus murni (HP scaling, reward, harga)
      Signal.luau                 atau pakai sleitnick/signal dari Wally
art/                              sumber Blender, TIDAK di-mount Rojo
  Enemies/*.blend
  Bosses/*.blend
assets/                           di-mount ke Workspace / ReplicatedStorage
  Arena.rbxmx
  Lobby.rbxmx
  Enemies/                        model musuh (.rbxmx)
tests/
  run.luau                        runner Lune
  Smoke.spec.luau                 verifikasi relative require (lihat 1.5)
  Balance.spec.luau
  Waves.spec.luau
```

`Balance.luau`, `Waves.luau`, dan modul definisi lain harus **murni**: tidak
memanggil `game:GetService`, tidak menyentuh `script`, dan hanya me-require
modul murni lain secara relatif. Itu syaratnya supaya bisa dites dengan Lune di
CI.

## 3. Spesifikasi teknis

### 3.1 Skema data player

Tambahkan ke `Config.DEFAULT_DATA`:

```luau
Config.DEFAULT_DATA = {
	schemaVersion = 1,
	coins = 0,              -- koin permanen
	level = 1,
	xp = 0,
	playtimeSeconds = 0,
	lastLogin = 0,

	equippedWeapon = "weapon_starter",
	weapons = {             -- [weaponId] = { level = number }
		weapon_starter = { level = 1 },
	},
	materials = {},         -- [materialId] = jumlah
	unlockedDifficulties = { normal = true },
	clears = {},            -- [difficultyId] = true
	stats = {
		highestWave = 0,
		matchesPlayed = 0,
		wins = 0,
	},
}
```

Tidak perlu naik `DATASTORE_NAME` karena semuanya field baru (non-breaking).

**Tipe `PlayerData` harus ditulis manual, jangan di-infer.** `Config.luau`
sekarang memakai:

```luau
export type PlayerData = typeof(Config.DEFAULT_DATA)
```

Pola itu jalan selama `DEFAULT_DATA` isinya cuma angka dan string, seperti
kondisi sekarang. Begitu skema di atas masuk, dia berhenti jalan:

- `weapons = { weapon_starter = { level = 1 } }` membuat Luau menginfer tipe
  yang **hanya** punya key `weapon_starter`. Akibatnya `data.weapons[weaponId]`
  untuk id apa pun yang lain jadi error tipe.
- `materials = {}` dan `clears = {}` jadi tabel kosong yang tidak punya informasi
  tipe sama sekali, dan ditolak di mode strict.

Karena CI menjalankan `luau-lsp analyze`, ini akan jadi **CI merah**, bukan
sekadar warning. Jadi di M0: deklarasikan tipenya di `Types.luau`, lalu anotasi
`DEFAULT_DATA` dengan tipe itu.

```luau
-- Types.luau
export type WeaponSave = { level: number }
export type PlayerStats = { highestWave: number, matchesPlayed: number, wins: number }
export type PlayerData = {
	schemaVersion: number,
	coins: number,
	level: number,
	xp: number,
	playtimeSeconds: number,
	lastLogin: number,
	equippedWeapon: string,
	weapons: { [string]: WeaponSave },
	materials: { [string]: number },
	unlockedDifficulties: { [string]: boolean },
	clears: { [string]: boolean },
	stats: PlayerStats,
}
```

`Config.PlayerData` tetap boleh di-export sebagai alias ke tipe ini, supaya kode
yang sudah ada (`src/client/init.client.luau` memakai `Config.PlayerData`) tidak
perlu diubah.

### 3.2 Perbaikan wajib di PlayerDataService (dikerjakan di M0)

Empat hal, semuanya dari membaca kode yang sudah ada.

**1. `reconcile` harus deep copy.**

*Dari awal:* `reconcile` adalah fungsi yang mengisi field yang belum ada di data
player lama dengan nilai default dari `Config.DEFAULT_DATA`. Fungsi inilah yang
membuat kamu bisa menambah field baru tanpa merusak save lama — player yang
datanya disimpan sebelum field itu ada akan terisi otomatis saat login
berikutnya. Implementasinya sekarang:

```luau
for key, default in Config.DEFAULT_DATA :: { [string]: any } do
	if data[key] == nil then
		data[key] = default
	end
end
```

*Masalahnya:* di Luau, `data[key] = default` untuk `default` yang berupa tabel
**tidak menyalin tabelnya**, hanya menyalin referensinya. Selama `DEFAULT_DATA`
isinya angka dan string saja, ini tidak kelihatan. Begitu skema 3.1 masuk dan
`DEFAULT_DATA` punya `weapons`, `materials`, `clears`, dan `stats`, semua player
baru akan menunjuk ke **tabel yang sama persis** — satu tabel milik modul
`Config`. Player A meng-upgrade senjata, player B dan C ikut ter-upgrade; lebih
buruk lagi, tabel itu ikut tersimpan ke DataStore semua orang, jadi kerusakannya
permanen.

*Perbaikan:* salin rekursif (`table.clone` per tingkat atau fungsi `deepCopy`
sendiri), dan `reconcile` juga harus **turun** ke tabel bersarang, supaya field
baru di dalam `stats` ikut terisi untuk player yang `stats`-nya sudah ada tapi
belum punya field itu.

**2. Backoff retry-nya terlalu lama.**

*Dari awal:* `retry()` membungkus panggilan DataStore dan mengulanginya kalau
gagal, dengan jeda `2 ^ attempt` detik. `load()` membungkus `retry()` lagi di
dalam loop lock sebanyak `LOCK_RETRY_LIMIT` kali, dengan jeda `LOCK_RETRY_DELAY`
di antaranya. Dua lapis ini perlu — DataStore memang bisa gagal sementara, dan
session lock memang perlu ditunggu.

*Masalahnya:* kalikan angkanya. Satu putaran `retry` dengan
`SAVE_RETRY_COUNT = 5` menunggu 2+4+8+16+32 = **62 detik**. Dikali
`LOCK_RETRY_LIMIT = 6` putaran, plus jeda 5 detik di antaranya, totalnya
**sekitar 400 detik** sebelum player akhirnya di-kick. Komentar di plan revisi
sebelumnya menyebut "sampai 30 detik" — itu salah dan terlalu optimistis hampir
14 kali. Selama 400 detik itu player melihat layar tanpa data sama sekali.

*Perbaikan:* batasi jeda backoff (misal `math.min(2 ^ attempt, 8)`), dan turunkan
`LOCK_RETRY_LIMIT`. Lebih baik kick cepat dengan pesan jelas "coba join ulang
30 detik lagi" daripada menggantung pemain 7 menit.

**3. Satu titik `PlayerAdded` saja.**

*Dari awal:* ada dua tempat yang mendengarkan `Players.PlayerAdded`.
`PlayerDataService.start()` memakainya untuk memanggil `load()`, dan
`src/server/init.server.luau` memakainya untuk memanggil `get()` lalu
`FireClient(DataLoaded)`.

*Masalahnya:* `load()` memanggil `UpdateAsync`, yang **yield**. Begitu dia
yield, Roblox menjalankan handler berikutnya — jadi handler di
`init.server.luau` berjalan ketika `load()` belum selesai dan cache masih
kosong. `get()` mengembalikan `nil` hampir selalu di server live. Kode sekarang
menambal itu dengan `task.wait(1)` lalu coba lagi, tapi satu detik jauh lebih
pendek dari waktu `load()` yang sebenarnya (lihat poin 2), jadi `DataLoaded`
bisa tidak pernah terkirim. Ada bug kedua yang lebih halus: player yang sudah
ada di server **sebelum** `start()` dipanggil di-load lewat loop
`Players:GetPlayers()`, tapi `PlayerAdded` di `init.server.luau` tidak pernah
menyala untuk mereka, jadi mereka tidak dapat `DataLoaded` sama sekali.

*Perbaikan:* hapus `PlayerAdded` di `init.server.luau`. Satu titik masuk di
service, dan yang lain menunggu lewat sinyal di poin 4.

**4. Sinyal "data siap" dan broadcast otomatis.**

Tambahkan `PlayerDataService.onLoaded` (Signal) atau
`PlayerDataService.waitFor(player)`, dan pakai itu sebagai pengganti
`task.wait(1)`. Selain itu, buat `update()` otomatis mengirim `DataChanged` ke
client yang bersangkutan, supaya service lain tidak bisa lupa — sekarang
pengirimannya manual dan tersebar.

### 3.3 State machine match

```
Lobby -> Countdown (10 dtk) -> WaveActive <-> Intermission (20 dtk) -> Ended -> Lobby
                                    |
                                    +-> Ended (core HP 0)
```

| State | Masuk saat | Yang terjadi |
|---|---|---|
| `Lobby` | Server baru / match selesai | Player bebas di lobby, bisa upgrade/craft |
| `Countdown` | Semua player di server menekan Ready (minimal 1) | Hitung mundur, kesulitan dikunci |
| `WaveActive` | Countdown selesai / intermission selesai | WaveService spawn, combat aktif |
| `Intermission` | Semua musuh wave habis dan bukan wave terakhir | Toko Match buka, timer 20 dtk |
| `Ended` | Core HP 0 atau wave terakhir selesai | RewardService jalan, layar hasil, 10 dtk lalu ke Lobby |

`MatchService` memegang state dan menyiarkannya lewat `Remotes.MatchState`
(state, wave, timer). Service lain tidak boleh mengubah state langsung, cukup
memanggil fungsi MatchService (`MatchService.onWaveCleared()`, dst).

**Aturan join dan rejoin.** Pemain yang **belum pernah ikut** match yang sedang
berjalan menunggu di lobby sampai match selesai. Pemain yang **tadinya ikut**
lalu disconnect boleh masuk kembali ke match yang sama dan melanjutkan.

Implementasinya: `MatchService` menyimpan `participants`, satu set `UserId` yang
diisi saat state pindah dari `Countdown` ke `WaveActive` dan baru dikosongkan
saat masuk `Lobby`. Pakai `UserId`, bukan objek `Player`, karena objek `Player`
hilang saat disconnect. Saat ada player join di tengah match:

- `UserId`-nya ada di `participants` → masukkan ke arena, spawn di
  `Arena/PlayerSpawn`, kirim `MatchState` terkini.
- Tidak ada → tahan di lobby, kirim `MatchState` supaya HUD-nya bisa
  menampilkan "match sedang berjalan, tunggu".

Dua catatan yang perlu diputuskan saat mengerjakannya, bukan sekarang: koin
match pemain yang disconnect sebaiknya **tetap disimpan** di `participants`
supaya tidak hangus saat rejoin; dan kalau **semua** peserta disconnect, match
harus dibatalkan dan state kembali ke `Lobby`, kalau tidak server akan nyangkut
di `WaveActive` tanpa pemain.

Pemain yang keluar dan tidak kembali tetap dapat reward sesuai wave saat dia
keluar (dihitung di `RewardService`, disimpan lewat `PlayerDataService.save`
pada `PlayerRemoving`).

### 3.4 Penanda di map

| Nama instance | Isi |
|---|---|
| `Arena/CoreServer` | Model Core Server, `PrimaryPart` jadi target musuh |
| `Arena/Lanes/Lane1/1`, `/2`, ... | Part waypoint berurutan, terakhir di dekat Core |
| `Arena/Lanes/Lane2/...` | Lane kedua, dst |
| `Arena/PlayerSpawn` | SpawnLocation saat match |
| `Lobby/ReadyPad` | Part untuk tanda siap |
| `Lobby/SpawnLocation` | Spawn default |

Waypoint dibaca sekali saat server start lalu di-cache sebagai daftar `Vector3`.
Urutan waypoint diambil dari **nama** Part (`"1"`, `"2"`, ...) yang di-sort
numerik, bukan dari urutan `GetChildren()` — urutan `GetChildren()` tidak
dijamin.

### 3.5 Balancing awal

Semua di `Balance.luau`, angka awal untuk dites lalu disetel:

```luau
-- HP musuh
hp = def.baseHp
	* (1 + 0.15 * (wave - 1))
	* difficulty.hpMult
	* (1 + 0.35 * (playerCount - 1))

-- jumlah musuh biasa per wave
count = math.floor(6 + 2 * wave * (1 + 0.25 * (playerCount - 1)))

-- koin permanen akhir match
coins = math.floor((10 * waveReached + (if won then 50 else 0)) * difficulty.rewardMult)

-- XP
xp = 20 * waveReached + (if won then 100 else 0)

-- harga upgrade senjata ke level n+1
price = math.floor(50 * 1.35 ^ (n - 1))

-- stat senjata di level n
damage = def.baseDamage * (1 + 0.12 * (n - 1))
```

### 3.6 Remotes yang ditambahkan

| Nama | Arah | Payload | Validasi server |
|---|---|---|---|
| `MatchState` | S -> C | `{ state, wave, timer, coreHp, coreMaxHp }` | |
| `MatchCoins` | S -> C | `number` | |
| `SetReady` | C -> S | `boolean` | Hanya saat state `Lobby` |
| `SelectLoadout` | C -> S | `weaponId, difficultyId` | Senjata dimiliki, tingkat terbuka |
| `Attack` | C -> S | `Vector3` arah bidik | Cooldown per senjata, karakter hidup, state `WaveActive`, pemain ada di `participants` |
| `EnemyHit` | S -> C | `{ id, damage, position }` | Untuk efek saja |
| `BuyShopItem` | C -> S | `itemId` | State `Intermission`, toko tidak terkunci, koin match cukup |
| `UpgradeWeapon` | C -> S | `weaponId` | State `Lobby`, dimiliki, belum max, koin cukup |
| `BuyWeapon` | C -> S | `weaponId` | Belum dimiliki, bisa dibeli, koin cukup |
| `CraftWeapon` | C -> S | `weaponId` | Belum dimiliki, material cukup |
| `MatchResult` | S -> C | `{ won, waveReached, coins, xp, materials, unlocked }` | |
| `ShowInfoCard` | S -> C | `bossId` | |
| `GetLeaderboard` | C -> S (function) | | Rate limit |

Semua remote C -> S dirate-limit per player (misal 20 per detik untuk `Attack`,
2 per detik untuk yang lain). Argumen dicek tipe dan isinya sebelum dipakai.

### 3.7 Combat

1. Client mengirim `Attack(direction)` setiap klik/tap.
2. Server cek cooldown berdasarkan `attackSpeed` senjata (tolak kalau terlalu
   cepat, jangan percaya timer client).
3. Jarak dekat: cari musuh dalam radius + sudut di depan karakter.
   Jarak jauh: `workspace:Raycast` dari karakter ke arah bidik sejauh `range`,
   dengan filter hanya folder musuh.
4. Damage diterapkan oleh `EnemyService.damage(id, amount, player)`.
5. Musuh mati: tambah koin match ke **tim** (dibagi rata) dan kirim `EnemyHit`
   untuk efek.

**Soal lag, dan kenapa ini perlu dibahas sekarang.**

*Dari awal:* bagian 1.3 memutuskan musuh digerakkan **server** lewat `CFrame`.
Posisi yang dilihat pemain di layarnya adalah hasil replikasi, jadi selalu
tertinggal sebesar latensi jaringan. Langkah 3 di atas memvalidasi serangan
memakai posisi musuh **menurut server**.

*Masalahnya:* pemain dengan ping 150 ms membidik musuh di posisi yang menurut
server sudah basi sekitar 0.15 detik. Untuk musuh tipe `fast` itu bisa selisih
beberapa stud. Hasilnya: raycast yang secara kode benar akan sering dinyatakan
tidak kena, dan pemain merasa "tembakannya nggak kena" padahal tidak ada bug.
Kalau tidak diantisipasi, ini akan di-debug berjam-jam sebagai bug yang
sebenarnya bukan bug.

*Mitigasi untuk v1 (yang paling murah):* jangan pakai raycast ketat. Pakai
toleransi yang sengaja longgar — radius hit beberapa stud lebih besar dari model
musuh, dan untuk senjata jarak jauh pakai `spherecast`/radius di sekitar garis
bidik, bukan garis setebal nol. Untuk game co-op PvE, memberi keuntungan ke
pemain tidak merugikan siapa pun; tidak ada pemain lain yang dicurangi.

*Yang sengaja tidak dikerjakan di v1:* rekaman riwayat posisi musuh di server
lalu rewind sesuai latensi pemain (lag compensation yang benar). Itu solusi yang
tepat untuk PvP kompetitif, dan terlalu berat untuk kebutuhan di sini.

## 4. Milestone

Setiap milestone diakhiri playtest. Kolom "Selesai kalau" adalah kriteria
penerimaannya.

### M0: Fondasi

- [ ] **Smoke test relative require** (bagian 1.5): satu modul dummy me-require
      sibling-nya, hijau di `lune run` **dan** di playtest Studio. Kerjakan ini
      paling awal — hasilnya menentukan cara penulisan semua modul berikutnya.
- [ ] `Types.luau` dengan `PlayerData` dan kawan-kawan ditulis manual
      (bagian 3.1), `Config.PlayerData` jadi alias ke situ
- [ ] Skema data baru di `Config.luau`, dianotasi dengan tipe itu
- [ ] Perbaikan PlayerDataService: deep copy reconcile, cap backoff, satu titik
      `PlayerAdded`, sinyal `onLoaded`, broadcast otomatis di `update()`
      (bagian 3.2)
- [ ] `Weapons.luau`, `Enemies.luau`, `Bosses.luau`, `Waves.luau`,
      `Difficulties.luau`, `ShopItems.luau`, `Balance.luau` (isi data v1)
- [ ] Signal (tulis sendiri atau `sleitnick/signal` lewat Wally)
- [ ] Runner test Lune (`tests/run.luau`) + test untuk `Balance` dan `Waves`
- [ ] Tambah langkah `lune run tests/run` di `ci.yml`
- [ ] Pin `globalTypes.d.luau` ke tag versi, bukan `main` — sekarang CI
      menariknya dari branch `main` upstream, jadi hasil type check bisa berubah
      tanpa kamu mengubah apa pun

**Selesai kalau:** CI hijau, test Lune jalan, dan dua player baru yang di-load
berbarengan punya tabel `weapons` yang **berbeda** (ini test eksplisit untuk bug
deep copy, bukan sekadar "tidak error").

### M1: Prototipe pertarungan (graybox)

- [ ] Mapping `assets/` di `default.project.json` (bagian 1.4) dan prosedur
      export map ditulis di README
- [ ] Arena graybox: 2 lane, Core Server, PlayerSpawn (`assets/Arena.rbxmx`)
- [ ] `CoreService`: HP, event `onDestroyed`
- [ ] `EnemyService`: spawn musuh `basic`, gerak sepanjang waypoint, kurangi HP
      core saat sampai, HP bar sederhana (BillboardGui)
- [ ] `CombatService` + `InputController`: serangan senjata starter, dengan
      toleransi hit yang longgar (bagian 3.7)
- [ ] Wave statis 1 sampai 3 tanpa state machine lengkap
- [ ] HUD minimal: HP core dan nomor wave

**Selesai kalau:** solo playtest bisa membunuh musuh, core yang HP-nya habis
memicu kalah, dan serangan terasa kena saat dites dengan ping tinggi (Studio:
Network simulation).

### M2: Sistem wave & match

- [ ] `MatchService` dengan state machine lengkap (bagian 3.3), termasuk set
      `participants`
- [ ] `WaveService` membaca `Waves.luau`, 10 wave, musuh `fast` dan `tank`
- [ ] Scaling jumlah dan HP musuh berdasarkan jumlah player
- [ ] Batas musuh aktif + antrian spawn
- [ ] Kondisi menang di wave 10
- [ ] `HudController`: state, timer, HP core, wave
- [ ] `ResultController`: layar menang/kalah, lalu kembali ke lobby

**Selesai kalau:** satu match penuh bisa dimainkan dari lobby sampai hasil, dan
bisa diulang tanpa restart server.

### M3: Toko Match

- [ ] Koin match per tim, reset tiap match
- [ ] `ShopItems.luau`: upgrade damage tim, upgrade attack speed, repair core,
      penghalang (blok lane sebentar), turret kecil
- [ ] `ShopService` + `ShopController`, hanya aktif saat `Intermission`

**Selesai kalau:** beli item mengubah gameplay di wave berikutnya, dan tidak
bisa beli di luar jeda atau dengan koin kurang (dicoba lewat remote manual).

### M4: Boss

- [ ] `BossService` + `Bosses/Splitter.luau` (wave 5)
- [ ] `Bosses/Locker.luau` (wave 10): kunci toko dan panggil minion
- [ ] HP bar boss di HUD
- [ ] Drop material ke semua player yang ikut match
- [ ] `InfoCardController` + teks kartu info di `Bosses.luau`

**Selesai kalau:** kedua boss bisa dikalahkan dengan mekaniknya berjalan, dan
material tercatat di data player setelah match.

### M5: Progres permanen & lobby

- [ ] `RewardService`: koin, XP, level up, material, `stats`, first clear
      membuka `hard`
- [ ] `ProgressionService`: upgrade (level 1 sampai 10), beli `weapon_ranged`,
      craft `weapon_boss_a`
- [ ] Senjata `weapon_ranged` dan `weapon_boss_a` di `CombatService`
- [ ] `LobbyController`: pilih senjata, pilih tingkat kesulitan, tombol Ready,
      panel upgrade dan craft
- [ ] Area lobby (`assets/Lobby.rbxmx`) dengan ReadyPad
- [ ] Tutorial singkat untuk player baru (bisa berupa wave latihan dengan teks
      panduan)

**Selesai kalau:** player baru bisa main, dapat reward, upgrade senjata, craft
senjata boss, membuka Hard, keluar, join lagi, dan semua progres masih ada.

### M6: Multiplayer & leaderboard

- [ ] Ready check untuk 2 sampai 4 player
- [ ] Koin match dibagi tim, reward per player
- [ ] Rejoin peserta match (bagian 3.3), termasuk kasus semua peserta keluar
- [ ] `LeaderboardService` (OrderedDataStore `highestWave` per tingkat) + papan
      di lobby
- [ ] Rate limit di semua remote

**Selesai kalau:** playtest 4 player lewat Studio (Test -> Clients and Servers)
lancar, rejoin di tengah match berhasil, dan tidak ada error di output server.

### M7: Polish & pengujian

- [ ] Model musuh dan boss final dari Blender (bagian 1.6), efek hit, suara
- [ ] Balancing dari hasil playtest (catat di `docs/BALANCE_LOG.md`)
- [ ] Optimasi: cek Script Performance dan MicroProfiler saat wave 10 + 4 player
- [ ] **Alpha test:** anggota tim, black-box test per fitur (checklist di
      `docs/TEST_CASES.md`)
- [ ] **Beta test:** pemain luar, kuesioner (misal skala Likert) soal keseruan
      dan pemahaman materi malware

**Selesai kalau:** tidak ada bug blocker dari alpha, dan hasil beta sudah
direkap.

### M8: Rilis

- [ ] Icon, thumbnail, deskripsi experience
- [ ] Isi secret dan variable untuk `publish.yml`
- [ ] Publish versi `Saved`, cek di server live, lalu `Published`
- [ ] Tag git `v1.0.0`

## 5. Pemetaan ke GDLC

Kalau dipakai untuk laporan kuliah, milestone di atas bisa dipetakan begini:

| Tahap GDLC | Milestone | Output |
|---|---|---|
| Initiation | | `CONCEPT.md` |
| Pre-production | M0 | Dokumen desain, data definisi, arsitektur |
| Production | M1 sampai M6 | Game yang bisa dimainkan |
| Alpha testing | M7 (alpha) | Hasil black-box test |
| Beta testing | M7 (beta) | Hasil kuesioner |
| Release | M8 | Game publik di Roblox |

## 6. Testing

- **Unit test (Lune):** semua modul murni di `src/shared/Modules`. Yang wajib
  ada: HP musuh naik tiap wave, reward kalah < reward menang, harga upgrade naik
  monoton, setiap wave di `Waves.luau` hanya memakai id musuh yang ada di
  `Enemies.luau`, dan dua hasil `reconcile` tidak berbagi tabel yang sama.
- **Playtest Studio:** solo (F5) dan multi-client (Test -> Clients and Servers,
  2 sampai 4 player).
- **Tes keamanan remote:** dari command bar client, panggil remote dengan
  argumen aneh (nil, angka negatif, id yang tidak ada, spam) dan pastikan server
  menolak tanpa error.
- **Tes data:** keluar di tengah match, rejoin cepat, matikan server (Studio:
  centang API Services) dan pastikan progres tidak hilang atau dobel.
- **Tes latensi:** playtest dengan Network simulation di Studio, pastikan
  serangan masih terasa kena (bagian 3.7).

## 7. Setelah v1

- Lobby dan arena di place terpisah (TeleportService + reserved server), supaya
  lobby bisa menampung banyak player
- 25 wave, 5 boss, musuh `stealth` dan `swarm`
- Tingkat `critical` dan seterusnya
- Perk dan kelas player
- Bonus harian, title, skin
- Codex malware: semua kartu info yang sudah terbuka bisa dibaca ulang di lobby
- Animasi jalan untuk musuh (butuh rig, lihat 1.3 dan 1.6)
- Monetisasi, kalau game ini mau serius dipublikasikan — sengaja belum dibahas
  di v1

## 8. Risiko

| Risiko | Mitigasi |
|---|---|
| Lag saat musuh banyak | Musuh tanpa Humanoid, batas musuh aktif, update gerak dikelompokkan |
| Serangan terasa tidak kena karena latensi | Toleransi hit longgar, bukan raycast ketat (3.7) |
| Exploit (damage, koin) | Semua hitungan di server, rate limit, validasi argumen |
| Data hilang, dobel, atau tertukar antar player | Session lock yang sudah ada, deep copy reconcile, tes rejoin, test eksplisit di M0 |
| Rojo menimpa hasil edit map di Studio | Prosedur export di 1.4, map dikerjakan di sesi terpisah |
| Relative require tidak jalan di Studio | Smoke test paling awal di M0, rencana cadangan di 1.5 |
| CI merah karena `globalTypes.d.luau` berubah di upstream | Pin ke tag versi (M0) |
| Scope melebar | Patuhi daftar v1 di CONCEPT.md, fitur baru masuk bagian 7 dulu |
| Waktu habis sebelum v1 selesai | Bagian 9 |

## 9. Rencana pemotongan kalau waktu habis

Bagian ini ditulis sekarang supaya keputusan memotong scope diambil dengan
kepala dingin, bukan panik seminggu sebelum deadline. Urutannya dari yang paling
tidak menyakitkan.

| # | Potong apa | Hemat | Yang hilang |
|---|---|---|---|
| 1 | Satu lane saja, bukan dua | M1, M7 | Variasi taktis; gameplay tetap utuh |
| 2 | `boss_locker` dibuang, menang di wave 10 melawan `boss_splitter` versi lebih kuat | M4 | Satu mekanik boss dan satu kartu info |
| 3 | Craft (`weapon_boss_a`) dibuang, material jadi mata uang upgrade biasa | M5 | Satu loop progres; upgrade senjata tetap ada |
| 4 | Tingkat `hard` dibuang | M5 | Replay value; `first clear` jadi tidak ada gunanya |
| 5 | Leaderboard dibuang | M6 | Kompetisi sosial |
| 6 | Tutorial dibuang, diganti teks statis di lobby | M5 | Onboarding lebih kasar |

**Yang tidak boleh dipotong**, karena menghapusnya membuat game ini bukan
CodeVerse lagi atau membuat laporannya tidak bisa ditulis: wave survival dengan
Core Server, minimal satu boss dengan mekanik yang meniru malware, kartu info
edukasi, progres permanen yang tersimpan, dan alpha/beta test di M7.

Kalau yang kurang justru **waktu untuk aset 3D**, pemotongannya beda dan lebih
murah: pakai Part primitif dengan warna solid untuk semua musuh, dan tunda
seluruh pekerjaan Blender ke setelah v1. Gaya "graybox yang dirapikan" masih
terlihat sengaja kalau warna dan pencahayaannya konsisten, dan itu menghemat
satu milestone penuh.
