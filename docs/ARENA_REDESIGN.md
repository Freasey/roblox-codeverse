# Rancangan ulang alur arena

> Draft rancangan, **belum dikode**. Dokumen ini menjelaskan mekanisme yang ada
> sekarang lalu apa yang berubah, supaya keputusannya bisa ditimbang sebelum
> ada satu baris pun yang ditulis.
>
> Dibuat 2026-10-24, pada commit `0729cda`.

## 0. Lingkup dan keputusan yang sudah diambil

Lingkupnya **arena saja**. Lobby ditunda; semua yang di bawah ini berlaku untuk
sesi arena, dan titik masuknya nanti tinggal digeser kalau lobby jadi.

Dan prioritasnya **logika, bukan efek**. Senjata di game ini sekarang belum
punya aset visual apa pun — `assets/` cuma berisi `Arena.rbxmx`, tidak ada model
senjata, tidak ada `Tool`, tidak ada entri graybox seperti `VISUALS` yang dipakai
musuh. Senjata saat ini murni angka di `Weapons.luau`. Jadi bentuk, nama final,
dan efek per alur **sengaja ditunda**: yang dirancang di sini adalah kerangkanya
— data model, aturan, dan titik tempat efek nanti dipasang. Isi konkret 9 alur
ditaruh di lampiran sebagai contoh, bukan sebagai keputusan.

Tiga keputusan yang sudah diambil:

1. Hadiah per wave masuk **koin match** (kolam tim untuk Toko Match), bukan koin
   permanen. Alasannya di bagian 6.
2. Selama masa development, **semua senjata dianggap terbuka**, lewat flag dev —
   bukan dengan menulisnya ke data tersimpan.
3. Pilihan alur upgrade **tidak bisa dibatalkan**.

## 1. Senjata yang ada sekarang

| ID | Nama | Tipe | Damage | Cooldown | Range | Proyektil | Cara dapat |
|---|---|---|---|---|---|---|---|
| `weapon_starter` | Patch Wrench | melee | 25 | 0.5s | 12 | 1 | default |
| `weapon_ranged` | Packet Rifle | ranged | 14 | 0.25s | 60 | 1 | beli 1500 koin |
| `weapon_boss_a` | Fork Bomb | ranged | 30 | 0.6s | 45 | 3 | craft 5x material_a |

Level 1-10, dan satu-satunya yang berubah per level sekarang adalah damage
(`Balance.DAMAGE_PER_LEVEL = 0.12`, linear). Cooldown, range, dan jumlah
proyektil tidak pernah berubah, padahal `CONCEPT.md` menjanjikan ketiganya naik.
Jadi slot untuk "3 alur" sebenarnya sudah kosong menunggu diisi.

## 2. Pemilihan senjata di awal arena

### Mekanismenya sekarang

Senjata dipilih lewat remote `SelectLoadout(weaponId, difficulty)`.
`MatchService.onSelectLoadout` **menolak kalau state bukan `Lobby`** — alasannya
ditulis di kodenya sendiri: ganti senjata di tengah wave berarti damage berubah
tanpa biaya apa pun. Pilihannya disimpan permanen ke `data.equippedWeapon`, dan
saat menyerang `CombatService.resolveWeapon` membacanya ulang dari data server.

### Yang berubah

Satu fase baru sebelum `Countdown`, sebut saja **`Loadout`**, 15-20 detik:

```
Loadout -> Countdown -> WaveActive -> Intermission -> ... -> Ended
```

- Semua peserta memilih senjata di fase ini.
- Yang tidak memilih sampai waktu habis memakai senjata terakhirnya.
- Setelah fase ini **terkunci sampai match selesai**, termasuk saat
  Intermission. Alasan aslinya masih berlaku, dan dengan alur upgrade yang
  permanen, bebas tukar senjata tiap wave membuat pilihan alur tidak ada
  artinya.

### Jebakan "semua senjata terbuka"

Ada **dua** tempat yang memeriksa kepemilikan, bukan satu:

| Tempat | Perilaku kalau senjata tidak dimiliki |
|---|---|
| `MatchService.onSelectLoadout` | tolak, balas `ActionResult` |
| `CombatService.resolveWeapon` | **diam-diam jatuh ke starter** |

Kalau cuma yang pertama dibuka, pemain bisa memilih Packet Rifle lalu
mengayunkan Patch Wrench, tanpa pesan error apa pun — bug yang sulit dilacak
karena tidak ada yang mengeluh. Jadi flag dev harus lewat **satu fungsi murni**
yang dipakai kedua tempat:

```lua
-- src/shared/Modules/ProgressionRules.luau (atau modul murni baru)
Progression.ownedWeapons(data) -> { [weaponId]: WeaponSave }
```

Dia mengembalikan gabungan senjata default dan isi `data.weapons`; saat
`Config.DEV_ALL_WEAPONS = true` dia mengembalikan **semua** senjata, dengan level
1 untuk yang belum dimiliki.

**Jangan** menulis ketiga senjata ke `data.weapons` lewat
`PlayerDataService.update` sebagai jalan pintas. Itu masuk DataStore, dan setelah
itu tidak ada cara membedakan senjata hasil flag dev dari senjata yang benar-benar
dibeli pemain. Flag dev harus hidup di memori saja.

## 3. Kerangka tiga alur upgrade

Bagian ini **struktur**, bukan isi. Isi efeknya ditunda (lampiran A).

### Bentuk pohonnya

Level 1-10 tetap, tapi dibelah:

| Level | Yang terjadi |
|---|---|
| 1-3 | generik, +12% damage per level seperti sekarang. Belum ada pilihan |
| **4** | **titik percabangan** — pilih 1 dari 3 alur, permanen. Tingkat 1 alur itu aktif |
| 5, 6 | damage generik |
| **7** | tingkat 2 alur yang sudah dipilih |
| 8, 9 | damage generik |
| **10** | tingkat 3 alur yang sudah dipilih |

Jadi satu senjata = satu keputusan permanen; tiga senjata = tiga keputusan.
Kurva harga yang ada (`UPGRADE_BASE_PRICE = 50`, tumbuh 1.35) tidak perlu
disentuh.

Percabangannya di level 4 dan bukan level 1 karena pemain harus pernah
**memakai** senjatanya sebelum dipaksa memilih selamanya. Level 1-3 itu masa
percobaannya.

### Data model

Sekarang `WeaponSave = { level: number }`. Jadi:

```lua
export type WeaponSave = {
    level: number,
    path: string, -- "none" | "a" | "b" | "c"
}
```

Satu detail yang akan menggigit kalau dilewat: **defaultnya harus `"none"`,
bukan `nil`.** `DataSchema.reconcile` mengisi field yang hilang dari
`Config.DEFAULT_DATA`, dan `nil` tidak bertahan di JSON — field bernilai nil
hilang total saat disimpan, jadi "belum memilih" dan "data lama sebelum fitur ini
ada" jadi tidak bisa dibedakan. String `"none"` bisa.

Menambah field baru tidak perlu menaikkan `Config.DATASTORE_NAME` — itu sudah
dijelaskan di komentar `Config.DEFAULT_DATA`.

### Aturan, dan di mana ditegakkan

Semuanya di modul murni `ProgressionRules.luau` supaya bisa dites Lune:

1. Naik ke level 4 **wajib** menyertakan `pathId`. Tanpa itu, tolak.
2. Kalau `save.path ~= "none"` dan `pathId` yang diminta berbeda, **tolak** dengan
   alasan yang jelas. Ini satu-satunya tempat yang menegakkan "tidak bisa balik".
3. `pathId` harus salah satu alur milik senjata itu, dibaca dari definisi di
   server, bukan dari apa pun yang dikirim client.

Signature remote berubah: `UpgradeWeapon(weaponId)` menjadi
`UpgradeWeapon(weaponId, pathId?)`.

### Resolusi stat

`Balance.weaponDamage(def, level)` sebaiknya diganti satu fungsi:

```lua
Balance.weaponStats(def, save) -> {
    damage, cooldown, range, projectiles, effects
}
```

Satu fungsi murni, satu file test, dan `CombatService.resolveWeapon` tinggal
memanggilnya sekali. Ini juga titik tunggal tempat efek alur nanti dipasang —
selama efeknya belum diputuskan, `effects` boleh tabel kosong dan seluruh
kerangkanya tetap bisa dikode, dites, dan dimainkan.

### Satu syarat UI yang bukan opsional

Karena pilihannya permanen, pemain harus bisa melihat **isi ketiga alur beserta
angkanya** sebelum menekan konfirmasi. Pilihan permanen yang diambil tanpa
informasi itu bukan keputusan, itu jebakan — dan pemain yang merasa terjebak di
level 10 berhenti main, bukan mulai dari awal.

## 4. Musuh menyerang base dan player

### Mekanismenya sekarang

Musuh **bukan Humanoid** dan tidak memakai PathfindingService. Dia Model dengan
Part anchored yang digerakkan server lewat `CFrame` mengikuti waypoint lane,
semuanya dalam **satu loop Heartbeat**. Saat `waypointIndex` melewati waypoint
terakhir, `arriveAtCore()` jalan: `CoreService.damage(coreDamage)` sekali, lalu
`removeEnemy()`. Musuhnya **hilang**.

Dan musuh **tidak pernah menyentuh player sama sekali**: tidak ada satu pun
`TakeDamage` di seluruh `src/server`.

Jadi yang diminta mengubah dua hal sekaligus — musuh jadi punya *state* (jalan,
menyerang) dan punya *target*.

### Yang berubah

`coreDamage` (serangan sekali pakai) diganti `attackDamage` + `attackInterval`,
plus dua knob baru:

```lua
Balance.BASE_DAMAGE_MULT   = 0.2  -- damage musuh ke base
Balance.PLAYER_DAMAGE_MULT = 1.0  -- ke player; titik masuk efek pengurang damage nanti
```

State per musuh:

```
walking --(sampai ujung lane)--> attacking_base
walking --(player masuk aggro)--> chasing --> attacking_player
chasing --(target mati / lepas leash)--> walking
```

Musuh yang menyerang base **tetap hidup** dan terus memukul. Yang membunuhnya
cuma pemain.

### Angka, dan aritmetika yang menentukannya

Ini bagian yang paling mudah salah. Core 1000 HP dengan damage x0.2 berarti Core
**efektif 5000 HP**, sementara player cuma 100 HP — base 50x lebih tahan.
Akibatnya satu angka damage yang menakutkan bagi player hampir tidak terasa di
base, dan sebaliknya.

Jadi angka serangan ditetapkan **dari sisi player** (berapa pukulan sampai mati),
lalu HP Core yang disetel dari aritmetika kebocoran. Kalau dibalik, hasilnya
musuh yang mengelupas base 1 HP/detik.

Usulan, player tetap 100 HP:

| Tipe | Serangan | Interval | Pukulan membunuh player | DPS ke base | HP base hilang kalau 1 lolos sepanjang wave (~60s) |
|---|---|---|---|---|---|
| `basic` | 25 | 1.2s | 4 (4.8s) | 4.2 | ~250 (25%) |
| `fast` | 15 | 0.8s | 7 (5.6s) | 3.8 | ~225 (22%) |
| `tank` | 60 | 1.5s | **2** (1.5s) | 8.0 | ~480 (48%) |
| Splitter | 80 | 2.0s | 2 | 8.0 | - |
| Locker | 120 | 2.0s | 1 | 12.0 | - |

Bacaannya: satu `basic` lolos seluruh wave = seperempat base; satu `tank` lolos =
separuh base; tiga kebocoran yang dibiarkan = mati. Dan `tank` akhirnya jadi
benar-benar "yang tidak boleh lolos" — sekarang dia cuma 15 dari 1000, praktis
tidak ada artinya.

`tank` membunuh player dalam 2 pukulan memang kasar, tapi kecepatannya 5
stud/detik, paling lambat di game. Dia bisa dihindari; itu yang membuat angkanya
adil.

### Prioritas target

Satu profil kecil per **tipe** musuh, bukan logika per musuh:

```lua
targeting = { prefer = "base" | "player", aggroRadius = n, leashRadius = n }
```

| Tipe | prefer | aggro | Terasa seperti |
|---|---|---|---|
| `basic` | base | 14 | jalan ke base, memukul kalau dihalangi |
| `fast` | player | 25 | pengganggu, memburu pemain dulu |
| `tank` | base | 8 | tidak peduli pemain, lurus ke Core |

Nanti `stealth` -> player dengan aggro besar, `swarm` -> base dengan aggro nol.

### Dua masalah yang timbul dari desain tanpa pathfinding

**Pengejaran keluar jalur.** Mengejar player berarti meninggalkan waypoint, dan
musuh tidak punya collision (`CanCollide = false`) maupun pathfinding — jadi
pengejaran garis lurus bisa menembus dinding atau keluar arena. Pengamannya:
aggro kecil (14-25 stud), leash 1.5x aggro, dan saat target mati atau lepas
leash, musuh kembali ke **waypoint terdekat yang ada di depannya**, bukan yang
terdekat secara umum. Kalau boleh mundur, pemain bisa menarik satu musuh
maju-mundur selamanya dan wave-nya tidak akan pernah selesai.

**Penumpukan di base.** 20 musuh yang berhenti di titik yang sama akan menumpuk
jadi satu gumpalan, karena tidak ada collision yang memisahkan. Perlu **slot
cincin** di sekitar Core: misal 12 posisi di radius 10, musuh ke-n mengambil slot
`n mod 12`, sisanya cincin kedua di radius 14.

## 5. Konsekuensi terbesar: syarat wave selesai

Ini yang paling penting dan paling tidak kelihatan.

`WaveService.isWaveClear()` butuh `EnemyService.isClear()` — nol musuh aktif, nol
antrian. Selama ini itu **dijamin** terjadi, karena musuh yang sampai di Core
menghilang sendiri. Begitu musuh yang lolos tetap hidup, jaminan itu hilang:
**wave tidak bisa selesai sampai pemain membunuh musuh yang sudah menempel di
base.**

Usulannya: jaminan itu memang dibuang, jangan ditambal dengan "musuh di base
tidak dihitung". Efek sampingnya justru bagus — Intermission dan Toko Match
tertunda selama masih ada kebocoran, sambil base terus kehilangan 4-8 HP/detik.
Kebocoran jadi menghukum dua kali, HP dan waktu belanja, tanpa satu aturan
tambahan.

Dan ini tidak bisa menggantung permanen: kalau pemain benar-benar tidak mampu,
Core habis dan match berakhir kalah. Macet yang berujung selesai, bukan macet
yang butuh restart server.

### Respawn

Sekarang kematian player tidak ada konsekuensinya, karena musuh tidak bisa
membunuhnya. Untuk v1: respawn biasa 5 detik di spawn arena, tanpa sistem nyawa.
`CombatService.characterOrigin` sudah mengembalikan nil untuk karakter mati, jadi
"tidak bisa menyerang saat mati" sudah jalan sendiri.

## 6. Hadiah per wave

### Kenapa koin match, bukan koin permanen

Ada dua mata uang: **koin match** (satu kolam milik tim, habis tiap match, dipakai
di Toko Match) dan **koin permanen** (per pemain, untuk upgrade senjata).

Pengali jumlah pemain — solo x4, duo x2, 3-4 pemain x1 — hanya koheren untuk koin
match, dan itu argumen terkuatnya. Kolam koin match dibagi tim, jadi x4 solo
menormalkan daya beli per orang. Koin permanen itu milik pribadi; kalau hadiah
per wave masuk ke sana, main solo jadi **4x lebih efisien per orang** untuk
farming, dan game co-op yang menghukum main bareng akan dimainkan solo oleh
semua orang.

Perhatikan ini sudah separuh adil dengan sendirinya: efek Toko Match berlaku
untuk **seluruh tim**, jadi tim 4 orang mendapat 4x nilai per koin yang
dibelanjakan. 200 untuk tim berempat kira-kira setara 800 untuk solo.

### Kurva

| Wave | 1 | 2 | 3 | 4 | 5 (boss) | 6 | 7 | 8 | 9 | 10 (boss) |
|---|---|---|---|---|---|---|---|---|---|---|
| Hadiah | 200 | 250 | 300 | 350 | **800** | 450 | 500 | 550 | 600 | **1300** |

Rumusnya `200 + 50 * (wave - 1)`, dan wave boss x2 karena boss yang membuat wave
itu terasa sebagai puncak. Total 5.300. Lalu dikali pengali pemain:

| Jumlah pemain | Pengali |
|---|---|
| 1 | x4 |
| 2 | x2 |
| 3 atau 4 | x1 |

### Masalah yang dibawa pengali x4

Seluruh isi Toko Match sekarang **cuma bisa menyerap 2.950 koin** — lima item,
semuanya dibatasi (`maxPurchases` 5/5/3/5/2). Solo dengan pengali x4 akan
mengumpulkan **21.200** koin sepanjang 10 wave: dia memborong habis seluruh toko
di wave 3-4, lalu enam wave sisanya koinnya tidak ada gunanya.

Perbaikannya bukan menurunkan hadiahnya, karena alasan x4-nya valid. Yang salah
`maxPurchases`. Usulan: **ganti batas jumlah jadi harga yang naik.**

- `maxPurchases = 0` (tak terbatas) untuk damage up, fire rate, turret, repair
- harga naik x1.25 per pembelian item yang sama

Dengan begitu 10 tumpuk damage up memakan 6.650 koin, bukan 1.000. Uang selalu
punya tujuan, dan kelebihan pasokan solo terkoreksi lewat harga, bukan lewat
tembok. Lantai cooldown (`Balance.SHOP_COOLDOWN_FLOOR = 0.4`) sudah ada, jadi
fire rate tak terbatas pun tidak bisa menghapus cooldown.

Satu efek samping yang perlu diketahui: boss **Locker** mematikan seluruh efek
Toko Match selama dia hidup. Dengan upgrade tak terbatas, tim yang menumpuk 10
tingkat damage akan merasakan kehilangan itu jauh lebih keras di wave 10.
Menurutku itu bagus — mekanik sanderanya jadi benar-benar terasa — tapi itu
keputusan balancing, bukan kebetulan.

## 7. Yang ikut pecah

Playtest M1 sedang jalan dengan 18 case tersisa. Rancangan ini membatalkan
sebagian daftar itu:

| Yang terdampak | Kenapa |
|---|---|
| **CORE-02** | mematok lima angka damage ke Core (`basic` 5, `fast` 4, `tank` 15, Splitter 25, Locker 40). Kelimanya hilang — `coreDamage` berubah jadi DPS |
| **WAVE-11** | secara eksplisit menguji musuh yang sampai di Core "langsung dihapus, bukan berhenti menumpuk". Itu persis perilaku yang sekarang diminta. Case-nya bukan gagal, tapi terbalik |
| `tests/studio/cases/enemy_core.luau` | assertion `damage.musuhDibersihkanSetelahSampai` dan `damage.tidakDamageBerulang` akan merah, dan memang **seharusnya** merah |
| **WAVE-07** | masih sah, tapi angkanya bergeser begitu alur upgrade mengubah damage |

Artinya: **kerjakan rancangan ini dulu, baru playtest.** Kalau playtest jalan
lebih dulu, sebagian sorenya dipakai memverifikasi perilaku yang sebentar lagi
dihapus — termasuk tiga case yang angkanya baru dipatok di harness pada commit
terakhir.

## 8. Urutan kerja yang diusulkan

Disusun supaya tiap langkah bisa dites sebelum langkah berikutnya menumpuk di
atasnya:

1. **Serangan musuh ke base dan player.** `attackDamage` + `attackInterval`,
   state machine musuh, dua knob Balance, slot cincin di base. Yang paling
   mengubah rasa main, dan paling bisa diuji harness tanpa Player (kecuali
   damage ke player).
2. **Syarat wave selesai + respawn.** Langsung setelah (1), karena (1) yang
   merusaknya.
3. **Perbaiki harness dan `TEST_CASES.md`** untuk perilaku baru. Sebelum fitur
   lain menumpuk.
4. **Hadiah per wave + perubahan sink Toko Match.** Berdiri sendiri, tidak
   bergantung ke (1)-(3).
5. **Fase `Loadout` + flag dev semua senjata terbuka.** Berdiri sendiri juga.
6. **Kerangka 3 alur upgrade** — data model, aturan tidak-bisa-balik,
   `Balance.weaponStats`, dengan `effects` masih kosong.
7. **Isi efek per alur** (lampiran A), setelah (1)-(6) terbukti jalan.

## Lampiran A: contoh isi 9 alur (belum diputuskan)

**Ini belum keputusan.** Ditulis supaya kerangka di bagian 3 bisa diuji terhadap
sesuatu yang konkret, dan supaya kelihatan bahwa 9 alur **tidak** berarti 9
mekanik baru.

### Kosakata efek, dan biaya kodingnya

| Efek | Status di kode sekarang |
|---|---|
| damage, cooldown, range | sudah ada di `WeaponDef` |
| banyak target melee / tembus (pierce) ranged | sudah ada — `projectiles`. Untuk ranged, `collectTargets` mengurutkan musuh sepanjang garis bidik lalu memotong di `projectiles`, jadi pierce gratis |
| kerucut melee lebih lebar | sudah ada — `Balance.MELEE_MIN_COS` di `HitTest.inCone` |
| slow saat kena | **baru**: `Enemy` butuh pengali speed + waktu kedaluwarsa |
| damage masuk dikurangi | **baru**: inilah "efek khusus" pengurang damage |
| splash | **baru**, tapi tipis: panggil `EnemyService.damage` ke musuh di radius titik kena |
| mark (musuh ditandai, damage semua orang naik) | **baru**: satu field di `Enemy`, dibaca di `EnemyService.damage` |

Empat mekanik baru untuk sembilan alur.

### Patch Wrench (melee)

| Alur | Tema | L4 | L7 | L10 |
|---|---|---|---|---|
| A | ayunan berat | damage x1.5, cooldown x1.4 | kerucut lebar (cos 0.2 -> -0.1) | kena 3 musuh sekaligus |
| B | ayunan cepat | cooldown 0.5 -> 0.32 | slow 35% selama 1.5s | cooldown 0.25, slow 50% |
| C | bertahan | damage masuk x0.75 | range 12 -> 18, damage x1.2 | damage masuk x0.55 |

### Packet Rifle (ranged)

| Alur | Tema | L4 | L7 | L10 |
|---|---|---|---|---|
| A | sniper | damage x1.8, cooldown x1.6 | range 60 -> 90 | tembus 3 musuh |
| B | semburan | cooldown 0.25 -> 0.15, damage x0.8 | range 60 -> 40, damage x1.1 | tembus 2, cooldown 0.12 |
| C | dukungan | musuh yang kena ditandai, +25% damage dari siapa pun selama 4s | tanda jadi +40% | tanda menular ke 2 musuh terdekat |

### Fork Bomb (ranged, 3 proyektil)

| Alur | Tema | L4 | L7 | L10 |
|---|---|---|---|---|
| A | shotgun | proyektil 3 -> 5, range 45 -> 30 | damage x1.3 | proyektil -> 7 |
| B | ledakan | proyektil 3 -> 1, splash radius 8 (50% damage) | cooldown x0.8 | splash radius 12, 75% damage |
| C | jebakan | titik kena meninggalkan zona slow 40% selama 3s | radius naik, slow 55% | zona memberi damage kecil per detik |

Satu catatan desain dari daftar ini: alur dukungan Packet Rifle paling kuat di
3-4 pemain dan paling lemah solo. Itu disengaja — dia memberi alasan mekanis
untuk main bareng, bukan cuma pengali reward.
