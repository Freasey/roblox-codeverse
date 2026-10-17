# CodeVerse: Rencana Development v1

Dokumen ini menerjemahkan [CONCEPT.md](CONCEPT.md) jadi pekerjaan teknis di repo
ini. Workflow tetap seperti di README: source of truth di disk, Studio cuma
viewer lewat Rojo.

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

### 1.4 Map disimpan sebagai file di repo

Geometry arena dan lobby dibuat di Studio, lalu disimpan sebagai
`assets/Arena.rbxmx` dan `assets/Lobby.rbxmx` (format XML, masih bisa
di-review di git), dan di-mount lewat `default.project.json` ke `Workspace`.
Titik spawn, waypoint lane, dan posisi Core Server ditandai dengan Part
bernama khusus (lihat bagian 3.4) supaya kode tidak bergantung pada koordinat.

## 2. Struktur folder target

```
src/
  server/
    init.server.luau              (sudah ada, nanti cuma bootstrap service)
    Services/
      PlayerDataService.luau      (sudah ada)
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
      Types.luau                  tipe bersama (EnemyDef, WeaponDef, dst)
      Weapons.luau                definisi senjata + kurva upgrade
      Enemies.luau                definisi musuh
      Bosses.luau                 definisi boss + teks kartu info
      Waves.luau                  komposisi tiap wave
      Difficulties.luau           pengali tiap tingkat
      ShopItems.luau              item Toko Match
      Balance.luau                rumus murni (HP scaling, reward, harga)
      Signal.luau                 atau pakai sleitnick/signal dari Wally
assets/
  Arena.rbxmx
  Lobby.rbxmx
  Enemies/                        model musuh (.rbxmx), di-mount ke ReplicatedStorage
tests/
  run.luau                        runner Lune
  Balance.spec.luau
  Waves.spec.luau
```

`Balance.luau`, `Waves.luau`, dan modul definisi lain harus **murni** (tidak
memanggil `game:GetService`) supaya bisa dites dengan Lune di CI.

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

### 3.2 Perbaikan wajib di PlayerDataService (dikerjakan di M0)

1. **`reconcile` harus deep copy.** Sekarang default di-assign by reference.
   Begitu `DEFAULT_DATA` berisi tabel (`weapons`, `materials`, `stats`), semua
   player baru akan berbagi tabel yang sama, sehingga upgrade satu player ikut
   mengubah player lain. Ganti dengan `table.clone` rekursif, dan reconcile juga
   turun ke tabel bersarang (misalnya `stats.wins` yang baru ditambah).
2. **Sinyal data siap.** `init.server.luau` sekarang menunggu `task.wait(1)` lalu
   berharap data sudah ada, padahal `load()` bisa makan waktu lebih lama
   (retry lock sampai 30 detik). Tambahkan `PlayerDataService.onLoaded` (Signal)
   atau `PlayerDataService.waitFor(player)` dan pakai itu.
3. **Broadcast perubahan.** `update()` sebaiknya otomatis kirim
   `DataChanged` ke client, supaya service lain tidak lupa.

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

Player yang join saat match berjalan menunggu di lobby sampai match selesai.
Player yang keluar saat match tetap dapat reward sesuai wave saat dia keluar.

`MatchService` memegang state dan menyiarkannya lewat `Remotes.MatchState`
(state, wave, timer). Service lain tidak boleh mengubah state langsung, cukup
memanggil fungsi MatchService (`MatchService.onWaveCleared()`, dst).

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
| `Attack` | C -> S | `Vector3` arah bidik | Cooldown per senjata, karakter hidup, state `WaveActive` |
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

## 4. Milestone

Setiap milestone diakhiri playtest. Kolom "Selesai kalau" adalah kriteria
penerimaannya.

### M0: Fondasi

- [ ] Perbaikan PlayerDataService (bagian 3.2)
- [ ] Skema data baru di `Config.luau`
- [ ] `Types.luau`, `Weapons.luau`, `Enemies.luau`, `Bosses.luau`, `Waves.luau`,
      `Difficulties.luau`, `ShopItems.luau`, `Balance.luau` (isi data v1)
- [ ] Signal (tulis sendiri atau `sleitnick/signal` lewat Wally)
- [ ] Runner test Lune (`tests/run.luau`) + test untuk `Balance` dan `Waves`
- [ ] Tambah langkah `lune run tests/run` di `ci.yml`

**Selesai kalau:** CI hijau, test Lune jalan, player baru dan player lama
sama-sama dapat skema lengkap tanpa berbagi tabel.

### M1: Prototipe pertarungan (graybox)

- [ ] Arena graybox: 2 lane, Core Server, PlayerSpawn (`assets/Arena.rbxmx`)
- [ ] `CoreService`: HP, event `onDestroyed`
- [ ] `EnemyService`: spawn musuh `basic`, gerak sepanjang waypoint, kurangi HP
      core saat sampai, HP bar sederhana (BillboardGui)
- [ ] `CombatService` + `InputController`: serangan senjata starter
- [ ] Wave statis 1 sampai 3 tanpa state machine lengkap
- [ ] HUD minimal: HP core dan nomor wave

**Selesai kalau:** solo playtest bisa membunuh musuh, dan core yang HP-nya
habis memicu kalah.

### M2: Sistem wave & match

- [ ] `MatchService` dengan state machine lengkap (bagian 3.3)
- [ ] `WaveService` membaca `Waves.luau`, 10 wave, musuh `fast` dan `tank`
- [ ] Scaling jumlah dan HP musuh berdasarkan jumlah player
- [ ] Batas musuh aktif + antrian spawn
- [ ] Kondisi menang di wave 10
- [ ] `HudController`: state, timer, HP core, wave
- [ ] `ResultController`: layar menang/kalah, lalu kembali ke lobby

**Selesai kalau:** satu match penuh bisa dimainkan dari lobby sampai hasil,
dan bisa diulang tanpa restart server.

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
- [ ] Penanganan player keluar/masuk di tengah match
- [ ] `LeaderboardService` (OrderedDataStore `highestWave` per tingkat) +
      papan di lobby
- [ ] Rate limit di semua remote

**Selesai kalau:** playtest 4 player lewat Studio (Test -> Clients and Servers)
lancar dan tidak ada error di output server.

### M7: Polish & pengujian

- [ ] Model musuh dan boss final, efek hit, suara
- [ ] Balancing dari hasil playtest (catat di `docs/BALANCE_LOG.md`)
- [ ] Optimasi: cek Script Performance dan MicroProfiler saat wave 10 + 4 player
- [ ] **Alpha test:** anggota tim, black-box test per fitur (checklist di
      `docs/TEST_CASES.md`)
- [ ] **Beta test:** pemain luar, kuesioner (misal skala Likert) soal
      keseruan dan pemahaman materi malware

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

- **Unit test (Lune):** semua modul murni di `src/shared/Modules`. Contoh yang
  wajib ada: HP musuh naik tiap wave, reward kalah < reward menang, harga
  upgrade naik monoton, setiap wave di `Waves.luau` hanya memakai id musuh yang
  ada di `Enemies.luau`.
- **Playtest Studio:** solo (F5) dan multi-client (Test -> Clients and Servers,
  2 sampai 4 player).
- **Tes keamanan remote:** dari command bar client, panggil remote dengan
  argumen aneh (nil, angka negatif, id yang tidak ada, spam) dan pastikan server
  menolak tanpa error.
- **Tes data:** keluar di tengah match, rejoin cepat, matikan server (Studio:
  centang API Services) dan pastikan progres tidak hilang atau dobel.

## 7. Setelah v1

- Lobby dan arena di place terpisah (TeleportService + reserved server),
  supaya lobby bisa menampung banyak player
- 25 wave, 5 boss, musuh `stealth` dan `swarm`
- Tingkat `critical` dan seterusnya
- Perk dan kelas player
- Bonus harian, title, skin
- Codex malware: semua kartu info yang sudah terbuka bisa dibaca ulang di lobby

## 8. Risiko

| Risiko | Mitigasi |
|---|---|
| Lag saat musuh banyak | Musuh tanpa Humanoid, batas musuh aktif, update gerak dikelompokkan |
| Exploit (damage, koin) | Semua hitungan di server, rate limit, validasi argumen |
| Data hilang atau dobel | Session lock yang sudah ada, deep copy reconcile, tes rejoin |
| Rojo dan Studio saling menimpa | Map diedit di Studio lalu disimpan ulang ke `assets/*.rbxmx`, tidak pakai Team Create |
| Scope melebar | Patuhi daftar v1 di CONCEPT.md, fitur baru masuk bagian 7 dulu |
