# CodeVerse: Test Cases v1

Dokumen ini adalah checklist **black-box test** untuk CodeVerse v1: dites dari
sisi pemain (dan dari command bar client untuk tes keamanan), tanpa melihat isi
kode. Dia dipakai dua kali. **Per milestone:** tiap kriteria "Selesai kalau" di
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) bagian 4 punya minimal satu test case
di sini, jadi sebuah milestone baru boleh dicentang kalau semua test case
miliknya hijau — pemetaannya ada di
[bagian 13](#13-pemetaan-ke-kriteria-selesai-kalau). **Di M7 (alpha test):**
seluruh dokumen dijalankan sekali lagi dari atas ke bawah, dan kolom Status yang
diisi itulah lampiran hasil black-box test untuk laporan. Yang mengisi: siapa
pun yang menjalankan playtest — saat milestone itu developer sendiri; saat alpha
sebaiknya anggota tim yang bukan penulis kodenya, karena yang dicari di alpha
justru asumsi yang cuma jelas di kepala developer.

Arti kolom Status:

| Isi | Arti |
|---|---|
| `-` | Belum dites (nilai awal semua baris) |
| `OK` | Sesuai "Hasil yang diharapkan" |
| `GAGAL` | Tidak sesuai. Tulis apa yang terjadi di kolomnya, atau buka issue dan catat nomornya |
| `N/A` | Fiturnya dipotong (lihat bagian 9 DEVELOPMENT_PLAN.md), jadi test-nya tidak berlaku |

Catatan teknis sebelum mulai:

- **Playtest multi-client lewat Studio: Test → Clients and Servers**, pilih
  jumlah client (2 sampai 4), lalu Start. Tiap client jadi jendela sendiri dan
  ada satu jendela server — Output jendela server itulah yang dipantau untuk
  kriteria "tidak ada error". Test solo cukup F5.
- Test yang menyentuh DataStore butuh **Game Settings → Security → Enable
  Studio Access to API Services** dicentang. Tanpa itu semua baris di
  [bagian 11](#11-persistence-datastore-data) gagal karena alasan yang salah.
- Test latensi memakai **Network simulation** di tab Test Studio (preset lag
  tinggi / ping buatan). Matikan lagi setelah selesai, kalau tidak semua test
  berikutnya ikut terasa aneh.
- Test keamanan di [bagian 10](#10-keamanan-remote-sec) dijalankan dari
  **command bar jendela client** (bukan server), lewat
  `game.ReplicatedStorage.Remotes.<Nama>`. Yang diperiksa bukan cuma "aksinya
  ditolak", tapi juga **tidak ada error di Output server** — server yang error
  karena argumen sampah berarti validasinya kurang, walaupun aksinya gagal.
- Angka patokan di beberapa baris (HP, harga, reward) diambil dari rumus di
  DEVELOPMENT_PLAN.md bagian 3.5. Kalau balancing disetel ulang di M7, yang
  diperiksa tetap **arah** perubahannya (naik / turun / monoton), bukan angka
  mutlaknya.

## 1. Alur match dan state machine (MATCH)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| MATCH-01 | Server baru start, 1 player join | Lihat HUD dan posisi karakter | State `Lobby`; player ada di area lobby; tidak ada musuh di arena; panel upgrade/craft bisa dibuka | M2 | - |
| MATCH-02 | State `Lobby`, 1 player | Tekan Ready (ReadyPad / tombol lobby) | State pindah ke `Countdown`; timer hitung mundur dari 10 detik dan terlihat di HUD | M2 | - |
| MATCH-03 | State `Countdown` | Coba ubah senjata dan tingkat kesulitan dari UI lobby | Pilihan dikunci: yang dipakai match adalah loadout yang terpilih sebelum Ready | M2 | - |
| MATCH-04 | State `Countdown` | Tunggu timer habis | State pindah ke `WaveActive`; wave = 1; musuh mulai spawn; serangan player aktif | M2 | - |
| MATCH-05 | State `WaveActive` di wave 1 (bukan wave terakhir) | Habiskan semua musuh wave itu | State pindah ke `Intermission`; timer 20 detik jalan; Toko Match bisa dibuka | M2 | - |
| MATCH-06 | State `Intermission` setelah wave 1 | Tunggu timer 20 detik habis | State kembali ke `WaveActive`; nomor wave jadi 2; musuh wave 2 spawn | M2 | - |
| MATCH-07 | State `WaveActive`, HP core tersisa sedikit | Biarkan musuh sampai ke core sampai HP 0 | State pindah ke `Ended`; layar hasil menampilkan kalah dan wave yang dicapai | M2 | - |
| MATCH-08 | State `WaveActive` di wave 10 | Habiskan seluruh musuh wave 10 termasuk boss | Tidak masuk `Intermission`; langsung `Ended` dengan layar hasil **menang** | M2 | - |
| MATCH-09 | State `Ended` | Tunggu 10 detik | Layar hasil tertutup; state kembali ke `Lobby`; player kembali ke area lobby | M2 | - |
| MATCH-10 | Satu match sudah selesai (menang atau kalah), state `Lobby`, server **tidak** di-restart | Tekan Ready lagi dan mulai match kedua | Match kedua jalan normal: wave kembali 1, HP core penuh, koin match 0, musuh wave 1 spawn, tidak ada musuh sisa match sebelumnya | M2 | - |
| MATCH-11 | State `Countdown` dan `Intermission` | Bandingkan timer di HUD dengan hitungan detik asli | Timer turun satu per detik dan berhenti di 0 tepat saat state berganti; tidak ada timer negatif | M2 | - |
| MATCH-12 | State `WaveActive`, masih ada musuh hidup atau musuh di antrian spawn | Tunggu beberapa detik tanpa membunuh musuh | Nomor wave **tidak** naik dan state tidak pindah ke `Intermission` selama musuh wave itu belum habis | M2 | - |
| MATCH-13 | State `WaveActive` | Tekan Ready / sentuh ReadyPad | Tidak terjadi apa-apa; state tetap `WaveActive`; tidak ada error di Output server | M2 | - |
| MATCH-14 | Dua match selesai berurutan tanpa restart server | Lihat layar hasil match kedua | Hasil match kedua dihitung dari match kedua saja (wave, koin, material), tidak menumpuk hasil match pertama | M2 | - |

## 2. Wave dan spawn (WAVE)

Acuan: DEVELOPMENT_PLAN.md bagian 1.3, 3.4, 3.5.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| WAVE-01 | Match baru mulai, solo | Amati musuh wave 1: jenis dan jumlahnya | Jenis dan jumlah cocok dengan komposisi wave 1 di `Waves.luau`; tidak ada jenis musuh di luar daftar `Enemies.luau` | M2 | - |
| WAVE-02 | Match solo, kesulitan `normal` | Mainkan dari wave 1 sampai match berakhir | Nomor wave jalan 1 → 2 → ... → 10 tanpa lompat atau mengulang; wave 5 dan 10 adalah boss wave | M2 | - |
| WAVE-03 | Match wave 1 (hanya musuh `basic`) | Ikuti satu musuh `basic` dari spawn sampai core | Bergerak lambat, HP kecil (mati dalam beberapa serangan senjata starter), mengikuti lane sampai core | M1 | - |
| WAVE-04 | Wave yang komposisinya berisi `fast` | Bandingkan kecepatan `fast` dengan `basic` di wave yang sama | `fast` jelas lebih cepat sampai ke core, HP-nya kecil seperti `basic` | M2 | - |
| WAVE-05 | Wave yang komposisinya berisi `tank` | Serang satu `tank` dan hitung jumlah pukulan sampai mati | Butuh jauh lebih banyak pukulan dari `basic`; gerakannya paling lambat | M2 | - |
| WAVE-06 | Dua playtest terpisah: solo dan 2 player, sama-sama wave 1 `normal` | Hitung jumlah musuh wave 1 di dua playtest itu | Jumlah musuh di playtest 2 player lebih banyak dari solo (rumus `count` di 3.5) | M2 | - |
| WAVE-07 | Match solo, musuh `basic` ada di wave 1 dan di wave lebih tinggi | Hitung jumlah pukulan untuk membunuh satu `basic` di wave 1 dan di wave 5 | Di wave 5 butuh lebih banyak pukulan — HP musuh naik tiap wave | M1 | - |
| WAVE-08 | Dua playtest terpisah: solo dan 2 player, musuh `basic` di wave 1 | Bandingkan jumlah pukulan untuk membunuh satu `basic` | Di playtest 2 player butuh lebih banyak pukulan (HP naik mengikuti jumlah player) | M2 | - |
| WAVE-09 | `hard` sudah terbuka; dua playtest solo wave 1, `normal` dan `hard` | Bandingkan jumlah pukulan untuk membunuh satu `basic` | Di `hard` butuh lebih banyak pukulan (pengali HP 1.8) | M5 | - |
| WAVE-10 | Playtest 4 player, wave tinggi (8 sampai 10) yang jumlah musuhnya di atas 40 | Amati jumlah musuh aktif di arena selama wave berjalan | Musuh aktif tidak pernah lebih dari 40 sekaligus; musuh dari antrian menyusul spawn setelah musuh lain mati; total musuh yang muncul tetap sesuai jumlah wave | M2 | - |
| WAVE-11 | Match berjalan, arena dari `assets/Arena.rbxmx` | Ikuti satu musuh dari titik spawn sampai core | Musuh melewati waypoint berurutan (1, 2, 3, ...) dan berhenti di dekat core; tidak memotong jalur dan tidak melompat balik ke waypoint sebelumnya | M1 | - |
| WAVE-12 | Arena graybox dengan 2 lane | Amati spawn selama satu wave | Musuh datang dari kedua lane, bukan menumpuk di satu lane saja | M1 | - |
| WAVE-13 | Match berjalan | Pukul satu musuh sekali, jangan sampai mati | HP bar musuh (BillboardGui) di atasnya ikut turun dan sesuai sisa HP | M1 | - |
| WAVE-14 | Wave selesai, state `Intermission` | Amati arena selama jeda | Tidak ada musuh yang masih berjalan dan tidak ada sisa antrian spawn dari wave sebelumnya | M2 | - |

## 3. Core Server (CORE)

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| CORE-01 | Match baru mulai | Lihat HUD HP core | HP core penuh (`coreHp` = `coreMaxHp`) dan angkanya terlihat di HUD | M1 | - |
| CORE-02 | State `WaveActive`, ada musuh berjalan | Biarkan satu musuh sampai ke Core Server | HP core berkurang; musuh itu hilang (tidak menumpuk di core); HUD ikut turun | M1 | - |
| CORE-03 | State `WaveActive`, HP core hampir habis | Biarkan musuh terus sampai HP core 0 | Match langsung berakhir kalah (state `Ended`); tidak ada HP negatif dan musuh tidak terus menyerang core | M1 | - |
| CORE-04 | State `Intermission` atau `Lobby` | Tunggu tanpa melakukan apa-apa | HP core tidak berkurang sama sekali | M1 | - |
| CORE-05 | State `Intermission`, HP core sudah berkurang, koin match cukup | Beli item repair core di Toko Match | HP core naik; tidak pernah melebihi `coreMaxHp` | M3 | - |

## 4. Combat (COMBAT)

Acuan: DEVELOPMENT_PLAN.md bagian 3.7.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| COMBAT-01 | State `WaveActive`, `weapon_starter` ter-equip, musuh dalam radius di depan karakter | Klik / tap untuk menyerang | Musuh terkena: HP bar-nya turun, ada efek hit / angka damage di client | M1 | - |
| COMBAT-02 | Musuh HP tinggal sedikit | Serang sampai HP-nya 0 | Musuh hilang dari arena; koin match naik; tidak ada sisa model musuh | M1 | - |
| COMBAT-03 | Musuh di belakang karakter atau jelas di luar jangkauan | Klik / tap untuk menyerang | Tidak ada damage ke musuh itu; tidak ada error di Output server | M1 | - |
| COMBAT-04 | State `WaveActive`, musuh di depan | Klik secepat mungkin, jauh lebih cepat dari `attackSpeed` senjata | Damage yang masuk mengikuti cooldown senjata, bukan kecepatan klik; serangan berlebih diabaikan tanpa error | M1 | - |
| COMBAT-05 | Network simulation Studio dengan lag tinggi (ping sekitar 150 sampai 200 ms), musuh `fast` sedang bergerak | Serang musuh `fast` yang sedang berjalan 10 kali sambil membidik ke arahnya | Minimal 8 dari 10 serangan kena — toleransi hit longgar di 3.7 jalan. Kalau sering tidak kena, radius hit perlu diperbesar, bukan di-debug sebagai bug raycast | M1 | - |
| COMBAT-06 | Network simulation lag tinggi masih aktif, `weapon_ranged` ter-equip | Tembak musuh `fast` yang bergerak 10 kali | Sebagian besar tembakan kena: yang dipakai spherecast / radius di sekitar garis bidik, bukan garis setebal nol | M5 | - |
| COMBAT-07 | `weapon_ranged` dimiliki dan ter-equip, musuh jauh tapi masih dalam `range` | Bidik dan serang | Musuh jauh terkena damage tanpa perlu mendekat | M5 | - |
| COMBAT-08 | `weapon_ranged` ter-equip, musuh di luar `range` | Bidik dan serang | Tidak ada damage; tidak ada error | M5 | - |
| COMBAT-09 | `weapon_boss_a` sudah di-craft dan ter-equip, tiga musuh berdekatan di depan | Serang sekali ke arah kerumunan | Serangan membelah jadi 3 dan bisa mengenai lebih dari satu musuh dalam satu serangan | M5 | - |
| COMBAT-10 | Karakter player mati / sedang respawn saat `WaveActive` | Coba menyerang | Serangan ditolak server; tidak ada damage; tidak ada error | M1 | - |
| COMBAT-11 | State `Lobby` atau `Intermission` | Coba menyerang lewat klik, lalu lewat `Attack:FireServer(Vector3.new(0, 0, 1))` dari command bar client | Tidak ada damage ke musuh mana pun; server menolak karena state salah; tidak ada error | M2 | - |
| COMBAT-12 | Senjata yang sama di level 1, lalu di-upgrade ke level 5; musuh sejenis di wave yang sama | Hitung jumlah pukulan untuk membunuh satu musuh di dua kondisi itu | Di level 5 butuh pukulan lebih sedikit — kurva damage upgrade benar-benar terasa di match | M5 | - |

## 5. Toko Match (SHOP)

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| SHOP-01 | State `Intermission` | Buka UI Toko Match | Toko terbuka; daftar item sesuai `ShopItems.luau` dengan harganya; koin match tim terlihat | M3 | - |
| SHOP-02 | State `Intermission`, koin match cukup | Beli upgrade damage tim, lanjut ke wave berikutnya, hitung jumlah pukulan untuk membunuh satu musuh | Koin match berkurang sesuai harga; di wave berikutnya musuh mati dengan pukulan lebih sedikit | M3 | - |
| SHOP-03 | State `Intermission`, koin match cukup | Beli upgrade attack speed, lanjut ke wave berikutnya | Jeda antar serangan terasa lebih pendek di wave berikutnya; koin berkurang | M3 | - |
| SHOP-04 | State `Intermission`, HP core sudah berkurang | Beli repair core | HP core naik dan tidak melebihi maksimum (lihat CORE-05) | M3 | - |
| SHOP-05 | State `Intermission`, koin match cukup | Beli penghalang, pasang di satu lane, lanjut ke wave berikutnya | Musuh di lane itu tertahan sementara, lalu penghalang hilang setelah durasinya habis | M3 | - |
| SHOP-06 | State `Intermission`, koin match cukup | Beli turret kecil, lanjut ke wave berikutnya | Turret menyerang musuh sendiri tanpa input player; musuh yang mati karena turret tetap memberi koin match | M3 | - |
| SHOP-07 | State `WaveActive` | Dari command bar client: `game.ReplicatedStorage.Remotes.BuyShopItem:FireServer("<id item valid>")` | Pembelian ditolak; koin match tidak berkurang; tidak ada efek item; tidak ada error di Output server | M3 | - |
| SHOP-08 | State `Lobby` | Panggil `BuyShopItem:FireServer("<id item valid>")` dari command bar client | Ditolak dengan cara yang sama seperti SHOP-07 | M3 | - |
| SHOP-09 | State `Intermission`, koin match **kurang** dari harga item | Coba beli dari UI, lalu ulangi lewat remote manual | Dua-duanya ditolak; koin tidak jadi negatif; item tidak aktif di wave berikutnya | M3 | - |
| SHOP-10 | Wave 10 berjalan, `boss_locker` masih hidup | Coba buka toko dan beli item, dari UI dan lewat remote manual | Toko ditandai terkunci di UI dan `BuyShopItem` ditolak server selama boss hidup | M4 | - |
| SHOP-11 | Sementara ubah `Waves.luau` supaya `boss_locker` muncul di wave 5 (bukan wave terakhir), lalu playtest | Kalahkan `boss_locker`, masuk `Intermission`, coba beli item | Toko tidak terkunci lagi setelah boss mati dan pembelian berhasil. Balikkan `Waves.luau` setelah test | M4 | - |
| SHOP-12 | Satu match selesai setelah membeli upgrade damage dan attack speed | Mulai match baru di server yang sama | Koin match kembali 0 dan efek item match sebelumnya hilang — damage serta attack speed kembali ke nilai dasar senjata | M3 | - |

## 6. Boss (BOSS)

Acuan: CONCEPT.md tabel boss, DEVELOPMENT_PLAN.md M4.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| BOSS-01 | Match berjalan sampai wave 5 | Amati awal wave 5 | `boss_splitter` muncul (hanya satu); HP bar boss tampil di HUD dan turun saat boss diserang | M4 | - |
| BOSS-02 | `boss_splitter` hidup, HP masih di atas 66% | Serang boss sampai HP-nya turun melewati 66% | Boss membelah: beberapa musuh kecil muncul di sekitarnya; boss tetap hidup dengan sisa HP-nya | M4 | - |
| BOSS-03 | `boss_splitter` HP di antara 66% dan 33% | Terus serang sampai HP melewati 33% | Boss membelah untuk kedua kalinya; pembelahan di 66% tidak terulang (total hanya dua kali) | M4 | - |
| BOSS-04 | `boss_splitter` HP tinggal sedikit, playtest 2 player atau lebih | Habiskan boss | Material A masuk ke data **semua** peserta match, bukan cuma yang memberi pukulan terakhir | M4 | - |
| BOSS-05 | `boss_splitter` baru mati | Amati layar client | Kartu info muncul dengan teks dari `Bosses.luau` (malware apa dan cara mencegahnya), bisa ditutup, dan gameplay lanjut normal setelah ditutup | M4 | - |
| BOSS-06 | Match berjalan sampai wave 10 | Amati awal wave 10 | `boss_locker` muncul; HP bar boss tampil di HUD | M4 | - |
| BOSS-07 | `boss_locker` hidup | Tunggu beberapa saat tanpa membunuh boss | Boss memanggil minion secara berkala; toko terkunci selama boss hidup (lihat SHOP-10) | M4 | - |
| BOSS-08 | `boss_locker` baru mati | Amati arena beberapa detik | Minion berhenti dipanggil; minion yang masih hidup tidak menambah minion baru | M4 | - |
| BOSS-09 | `boss_locker` HP tinggal sedikit | Habiskan boss | Material B masuk ke semua peserta; kartu info `boss_locker` muncul; match berakhir **menang** (wave 10 selesai) | M4 | - |
| BOSS-10 | Satu match dengan kedua boss dikalahkan sudah selesai, state `Lobby` | Buka panel craft / lihat data player | Material A dan Material B tercatat di data player sesuai drop, dan jumlahnya tetap setelah kembali ke lobby | M4 | - |
| BOSS-11 | Playtest 4 player, wave 5 | Amati HP bar boss di keempat client sambil boss diserang | HP bar boss sama di semua client dan turun bersamaan (server yang jadi sumber angkanya) | M6 | - |

## 7. Progres permanen dan data player (PROG)

Acuan: DEVELOPMENT_PLAN.md bagian 3.1, 3.5, M5.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| PROG-01 | Match dimenangkan di `normal`; catat wave yang dicapai serta koin dan XP sebelum match | Lihat layar hasil, lalu bandingkan dengan data player di lobby | Koin permanen dan XP di layar hasil cocok dengan kenaikan di data player, dan ada bonus kemenangan (rumus 3.5) | M5 | - |
| PROG-02 | Dua match di wave yang sama: satu kalah, satu menang | Bandingkan reward kedua match | Reward match kalah lebih kecil dari reward match menang di wave yang sama | M5 | - |
| PROG-03 | Match berakhir kalah di wave rendah (misal wave 2) | Lihat layar hasil dan data player | Tetap dapat koin permanen dan XP sesuai wave yang dicapai, bukan nol | M5 | - |
| PROG-04 | XP player tinggal sedikit dari ambang level berikutnya | Selesaikan satu match | Level naik; XP sisa dihitung benar (tidak hilang, tidak negatif); kenaikan level terlihat di lobby | M5 | - |
| PROG-05 | Catat `highestWave`, `matchesPlayed`, `wins` sebelum match | Selesaikan satu match menang di wave lebih tinggi dari sebelumnya, lalu satu match yang berakhir di wave lebih rendah | `matchesPlayed` +1 tiap match, `wins` +1 saat menang, `highestWave` naik saat rekor baru dan **tidak turun** saat wave lebih rendah | M5 | - |
| PROG-06 | Player belum pernah menang di `normal`; `clears` kosong | Menangkan satu match di `normal`, kembali ke lobby | `hard` terbuka dan bisa dipilih di UI lobby; sebelum menang, `hard` tidak bisa dipilih | M5 | - |
| PROG-07 | `hard` sudah terbuka | Selesaikan satu match di `hard` dan satu di `normal` pada wave yang sama | Reward di `hard` lebih besar (pengali 1.6), musuhnya lebih tahan (lihat WAVE-09) | M5 | - |
| PROG-08 | Senjata di level 1, koin permanen cukup | Upgrade senjata itu berulang sampai level 10, catat harga tiap kali | Level naik 1 sampai 10; harga naik monoton; koin berkurang sesuai harga; di level 10 tombol upgrade mati dan `UpgradeWeapon` ditolak server | M5 | - |
| PROG-09 | Koin permanen **kurang** dari harga upgrade | Coba upgrade dari UI, lalu ulangi lewat remote manual | Dua-duanya ditolak; level senjata tidak berubah; koin tidak jadi negatif | M5 | - |
| PROG-10 | `weapon_ranged` belum dimiliki, koin permanen cukup | Beli `weapon_ranged` di lobby | Koin berkurang; senjata masuk ke daftar milik di level 1; bisa di-equip dan dipakai di match berikutnya | M5 | - |
| PROG-11 | `weapon_ranged` sudah dimiliki | Panggil `BuyWeapon:FireServer("weapon_ranged")` dari command bar client | Ditolak; koin tidak berkurang lagi; level senjata tidak ter-reset | M5 | - |
| PROG-12 | Material A cukup dari drop `boss_splitter`, `weapon_boss_a` belum dimiliki | Craft `weapon_boss_a` di lobby | Material A berkurang sesuai resep; `weapon_boss_a` masuk ke daftar milik; bisa di-equip dan serangannya membelah (lihat COMBAT-09) | M5 | - |
| PROG-13 | Material A **kurang** dari resep | Coba craft dari UI, lalu ulangi lewat remote manual | Dua-duanya ditolak; material tidak berkurang; senjata tidak masuk | M5 | - |
| PROG-14 | Player punya progres campur: koin, level, XP, senjata ter-upgrade, `weapon_ranged` dibeli, `weapon_boss_a` di-craft, `hard` terbuka, material sisa. **Catat semua angkanya** | Keluar dari server (leave), tunggu sekitar satu menit, join lagi | Semua angka sama persis seperti sebelum keluar — ini test paling penting di dokumen ini. Tidak ada field yang kembali ke default dan tidak ada yang dobel | M5 | - |
| PROG-15 | Senjata tertentu ter-equip sebelum keluar | Keluar, join lagi, langsung mulai match | `equippedWeapon` masih senjata yang sama dan senjata itulah yang dipakai di match | M5 | - |
| PROG-16 | Player yang belum pernah main (atau data di-reset lewat key DataStore baru) | Join dan mainkan satu match dari lobby | Data default terbentuk (`weapon_starter` level 1, koin 0, hanya `normal` terbuka); tutorial / teks panduan muncul; match bisa diselesaikan tanpa perlu beli apa pun | M5 | - |

## 8. Multiplayer dan rejoin (MP)

Acuan: DEVELOPMENT_PLAN.md bagian 3.3 (aturan join dan rejoin), M6.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| MP-01 | Test → Clients and Servers dengan 2 client, state `Lobby` | Tekan Ready di satu client saja, tunggu beberapa detik, baru Ready di client kedua | Countdown **tidak** mulai saat baru satu player Ready; mulai setelah semua player di server Ready; status siap tiap player terlihat di UI | M6 | - |
| MP-02 | 4 client, state `Lobby` | Ready di keempat client | Countdown mulai setelah yang terakhir Ready; keempat player masuk arena saat `WaveActive` | M6 | - |
| MP-03 | 4 client, match mulai | Mainkan satu match penuh wave 1 sampai 10 termasuk kedua boss | Match jalan lancar sampai layar hasil; musuh dan boss terlihat sama di semua client; tidak ada error di Output jendela server | M6 | - |
| MP-04 | 4 client, state `WaveActive`, catat koin match | Satu player saja yang membunuh beberapa musuh | Koin match naik untuk **tim** dan terlihat sama di keempat client, bukan hanya milik yang membunuh | M6 | - |
| MP-05 | 4 client, satu match selesai | Bandingkan layar hasil dan data permanen keempat player | Setiap player dapat koin permanen dan XP di datanya sendiri; angka tiap player dihitung terpisah, bukan dibagi dari satu kantong | M6 | - |
| MP-06 | 4 client, state `WaveActive` di wave 3 atau lebih; catat koin match tim | Tutup satu jendela client (simulasi disconnect), tunggu satu wave, lalu join lagi dengan player yang sama | Player itu masuk kembali ke arena (spawn di `Arena/PlayerSpawn`), bukan ditahan di lobby; HUD-nya menampilkan state, wave, dan HP core terkini; koin match tim tidak hangus | M6 | - |
| MP-07 | Match sedang `WaveActive` dengan peserta yang sudah terdaftar | Join dengan player **baru** yang belum pernah ikut match itu | Player baru ditahan di area lobby; HUD-nya memberi tahu match sedang berjalan; dia tidak muncul di arena dan `Attack`-nya ditolak server | M6 | - |
| MP-08 | Player baru dari MP-07 masih di lobby | Tunggu match selesai sampai state `Lobby`, lalu tekan Ready bersama yang lain | Player baru bisa ikut match berikutnya secara normal | M6 | - |
| MP-09 | 2 client, state `WaveActive`, keduanya peserta | Tutup kedua jendela client sehingga tidak ada peserta tersisa | Match dibatalkan: state kembali ke `Lobby`, musuh dibersihkan, server tidak nyangkut di `WaveActive`. Join lagi setelah itu masuk lobby dan bisa mulai match baru | M6 | - |
| MP-10 | 2 client, state `WaveActive` di wave 4 | Satu player keluar dan **tidak** kembali; biarkan match lanjut sampai selesai | Player yang keluar tetap dapat reward sesuai wave saat dia keluar (cek saat dia join lagi); player yang tinggal tetap bisa menyelesaikan match | M6 | - |
| MP-11 | 2 client, koin match tim sudah terkumpul, state `Intermission` | Satu peserta disconnect lalu rejoin, lalu beli item di toko | Koin match tim masih utuh setelah rejoin (tidak hangus dan tidak dobel); pembelian memakai koin yang sama | M6 | - |
| MP-12 | 4 client, wave 10 dengan `boss_locker` dan minion | Amati Output jendela server selama wave 10 sampai layar hasil | Tidak ada error atau warning berulang di Output server; game tetap responsif | M6 | - |

## 9. Leaderboard (LB)

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| LB-01 | API Services aktif; papan leaderboard ada di lobby | Selesaikan satu match di `normal` sampai wave tertentu, kembali ke lobby | Wave tertinggi player tercatat dan tampil di papan leaderboard `normal` dengan nama player | M6 | - |
| LB-02 | `hard` sudah terbuka | Selesaikan satu match di `hard` dengan wave berbeda dari catatan `normal` | Catatan `hard` dan `normal` terpisah; wave di `hard` tidak menimpa catatan `normal` dan sebaliknya | M6 | - |
| LB-03 | Sudah ada catatan wave tinggi (misal wave 8) | Selesaikan match baru yang berakhir di wave lebih rendah (misal wave 3) | Catatan di leaderboard tetap wave 8; tidak turun | M6 | - |
| LB-04 | Papan leaderboard terlihat di lobby, server tidak di-restart | Selesaikan match yang memecahkan rekor, kembali ke lobby | Papan ikut terupdate tanpa perlu restart server atau rejoin | M6 | - |
| LB-05 | 2 client dengan wave tertinggi berbeda | Lihat papan dari kedua client | Urutan di papan sesuai wave tertinggi (yang lebih tinggi di atas); angka tiap player benar | M6 | - |

## 10. Keamanan remote (SEC)

Acuan: DEVELOPMENT_PLAN.md bagian 3.6 (kolom "Validasi server") dan bagian 6
("Tes keamanan remote").

Semua baris di bagian ini dijalankan dari **command bar jendela client**, dengan
`local r = game.ReplicatedStorage.Remotes`. Pola argumen yang dicoba untuk tiap
remote: `nil`, angka negatif, tipe yang salah (string di tempat angka dan
sebaliknya, tabel, `Instance`), id yang tidak ada di modul definisi, jumlah
argumen kurang atau lebih, dan spam melebihi rate limit (misal 100 panggilan
dalam satu detik lewat `for i = 1, 100 do ... end`).

Yang dinilai sama untuk semua baris, jadi tidak diulang di tiap kolom hasil:
**aksinya tidak terjadi, data player maupun state match tidak berubah, dan
Output jendela server bersih** — tidak ada stack trace, tidak ada warning
berulang. Server yang error karena argumen sampah dianggap GAGAL walaupun
aksinya tidak jadi.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| SEC-01 | State `Lobby`, lalu ulangi saat `WaveActive` | `r.SetReady:FireServer(nil)`, `FireServer(-1)`, `FireServer("true")`, `FireServer({})`, `FireServer()`, lalu spam 100x `FireServer(true)` | Ready hanya berubah untuk boolean yang sah dan hanya saat state `Lobby`; argumen lain diabaikan; spam di-throttle dan tidak memicu countdown berulang | M6 | - |
| SEC-02 | State `Lobby` | `r.SelectLoadout:FireServer(nil, nil)`, `FireServer(-1, -1)`, `FireServer("weapon_tidak_ada", "normal")`, `FireServer("weapon_starter", "critical")`, `FireServer("weapon_ranged", "normal")` tanpa memilikinya, `FireServer({}, {})`, lalu spam 100x | Loadout hanya berubah untuk senjata yang **dimiliki** dan tingkat yang **terbuka**; id yang tidak ada ditolak; `critical` (belum ada di v1) ditolak | M6 | - |
| SEC-03 | State `WaveActive` sebagai peserta, lalu ulangi sebagai player yang tidak ikut match | `r.Attack:FireServer(nil)`, `FireServer(-1)`, `FireServer("depan")`, `FireServer(Vector3.new(0, 0, 0))`, `FireServer(Vector3.new(1e9, 1e9, 1e9))`, `FireServer({})`, lalu spam 200x dalam satu detik | Hanya `Vector3` yang wajar diproses; arah nol atau ekstrem tidak membuat damage aneh; serangan dari player di luar `participants` ditolak; spam dibatasi rate limit `Attack` sehingga damage per detik tidak melebihi cooldown senjata | M6 | - |
| SEC-04 | State `Intermission`, lalu ulangi saat `WaveActive` dan `Lobby` | `r.BuyShopItem:FireServer(nil)`, `FireServer(-1)`, `FireServer("item_tidak_ada")`, `FireServer(0)`, `FireServer({ id = "repair" })`, lalu spam 100x dengan id valid saat koin cuma cukup untuk satu | Hanya id yang ada di `ShopItems.luau` dan hanya saat `Intermission` yang diproses; spam tidak membuat item terbeli berkali-kali melebihi koin; koin match tidak pernah negatif | M6 | - |
| SEC-05 | State `Lobby` | `r.UpgradeWeapon:FireServer(nil)`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_ranged")` tanpa memilikinya, `FireServer(123)`, lalu spam 100x dengan senjata milik saat koin cuma cukup untuk satu level | Hanya senjata yang dimiliki, belum level 10, dan koin cukup yang naik level; spam tidak menaikkan beberapa level dengan bayar sekali; koin permanen tidak negatif | M6 | - |
| SEC-06 | State `Lobby`, `weapon_ranged` belum dimiliki | `r.BuyWeapon:FireServer(nil)`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_starter")` (sudah dimiliki), `FireServer("weapon_boss_a")` (harus di-craft), lalu spam 100x `FireServer("weapon_ranged")` saat koin cuma cukup satu kali | Hanya senjata yang memang bisa dibeli, belum dimiliki, dan koin cukup yang masuk; spam tidak memotong koin dua kali; senjata craft-only tidak bisa dibeli dengan koin | M6 | - |
| SEC-07 | State `Lobby`, Material A cukup untuk satu craft | `r.CraftWeapon:FireServer(nil)`, `FireServer(-1)`, `FireServer("weapon_tidak_ada")`, `FireServer("weapon_ranged")` (bukan senjata craft), lalu spam 100x `FireServer("weapon_boss_a")` | Hanya senjata craft yang resepnya terpenuhi yang masuk; spam tidak menghasilkan dua senjata dan material tidak jadi negatif | M6 | - |
| SEC-08 | State apa pun | `r.GetLeaderboard:InvokeServer(nil)`, `InvokeServer(-1)`, `InvokeServer("normal")`, `InvokeServer({})`, lalu panggil 100x berturut-turut | Mengembalikan data valid atau menolak dengan rapi (nil / tabel kosong), tidak pernah error; panggilan berlebih di-rate-limit dan tidak membanjiri OrderedDataStore | M6 | - |
| SEC-09 | Remote lama yang sudah ada di `Remotes.luau` | `r.RequestAction:FireServer(nil)`, `FireServer(-1)`, `FireServer("aksi_tidak_ada")`, `FireServer({})`, lalu spam 100x | Aksi yang tidak dikenal diabaikan; tidak ada perubahan data player; Output server bersih | M6 | - |
| SEC-10 | Remote lama yang sudah ada di `Remotes.luau` | `r.GetProfile:InvokeServer(nil)`, `InvokeServer(-1)`, `InvokeServer(<UserId player lain>)`, lalu panggil 100x berturut-turut | Yang dikembalikan selalu data **player yang memanggil**, tidak pernah data player lain; panggilan berlebih di-rate-limit; tidak pernah error | M6 | - |
| SEC-11 | 2 client, match berjalan | Dari satu client, spam seluruh remote C → S bergantian terus-menerus selama 30 detik | Server tetap responsif untuk client kedua (musuh tetap bergerak, HUD tetap update); pelaku di-throttle; tidak ada error di Output server | M6 | - |
| SEC-12 | Match berjalan | Dari command bar client, ubah angka di salinan modul shared yang ter-replikasi ke client (misal damage senjata), lalu serang musuh | Damage yang masuk tidak berubah — server memakai angkanya sendiri dan tidak pernah percaya angka dari client | M6 | - |

## 11. Persistence DataStore (DATA)

Acuan: DEVELOPMENT_PLAN.md bagian 3.2 dan bagian 6 ("Tes data"). Semua baris di
sini butuh **Enable Studio Access to API Services** dicentang.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| DATA-01 | Dua player baru (belum punya save) join hampir berbarengan di satu server | Di client pertama, upgrade senjata sampai level 3; lalu lihat level senjata di client kedua | Senjata player kedua tetap level 1 — tabel `weapons` dua player tidak berbagi referensi yang sama (bug deep copy di 3.2). Ulangi juga untuk `materials`, `clears`, dan `stats` | M0 | - |
| DATA-02 | Save lama dari sebelum field baru ada (misal save dari awal M0) | Join dengan player itu setelah skema diperluas | Field baru terisi nilai default; nilai lama (koin, level, XP) tidak berubah dan tidak ter-reset; field baru di dalam `stats` juga terisi | M0 | - |
| DATA-03 | Player sudah login; catat koin, lalu ubah progres (misal upgrade senjata) | Tunggu sampai lewat satu interval autosave tanpa keluar, lalu matikan server paksa (Stop di Studio) dan join lagi | Progres yang dibuat sebelum autosave masih ada setelah join ulang | M5 | - |
| DATA-04 | Match berjalan di wave 4, player adalah peserta | Keluar di tengah match (leave), lalu join lagi | Reward sesuai wave saat keluar sudah tersimpan; tidak ada progres yang hilang; koin tidak bertambah dua kali | M6 | - |
| DATA-05 | Player baru saja keluar dari server | Join lagi secepat mungkin (beberapa detik, saat session lock mungkin masih dipegang) | Player **tidak** mendapat data kosong/default: dia masuk dengan datanya yang benar, atau di-kick dengan pesan jelas ("coba join ulang 30 detik lagi") dalam waktu wajar — bukan menggantung ratusan detik di layar tanpa data (3.2 poin 2) | M6 | - |
| DATA-06 | Player punya progres yang baru diubah dan belum sempat autosave | Matikan server (Stop di Studio, memicu `BindToClose`), tunggu selesai, lalu join lagi | Progres terakhir tersimpan; tidak ada yang hilang karena server mati | M5 | - |
| DATA-07 | Catat koin, XP, dan material dengan teliti | Lakukan siklus keluar–join cepat tiga kali berturut-turut tanpa main | Angkanya sama persis setiap kali; tidak ada reward atau material yang bertambah sendiri (dobel) karena save/load berulang | M6 | - |
| DATA-08 | Dua player dengan progres jelas berbeda (misal satu level 1, satu level 10) | Join berbarengan, lihat data masing-masing di lobby, keluar, join lagi | Tiap player melihat datanya sendiri; tidak ada data yang tertukar antar player sebelum maupun sesudah rejoin | M6 | - |
| DATA-09 | API Services dimatikan (atau DataStore sengaja dibuat gagal) | Join, coba main satu match, lalu keluar | Server tidak membanjiri Output dengan error; player diberi tahu atau di-kick dengan rapi; data lama **tidak** ditimpa dengan data default | M6 | - |
| DATA-10 | Player sudah login dan datanya siap | Amati HUD dan lobby tepat setelah join | UI hanya menampilkan data setelah `DataLoaded` diterima; tidak ada momen UI menampilkan nilai default (koin 0, level 1) padahal datanya bukan itu (3.2 poin 3 dan 4) | M0 | - |

## 12. HUD dan layar hasil (HUD)

Baris di bawah ini mengunci hal kecil yang paling sering ketinggalan saat
mengerjakan milestone lain, dan ikut jadi bahan alpha test.

| ID | Prakondisi | Langkah | Hasil yang diharapkan | Milestone | Status |
|---|---|---|---|---|---|
| HUD-01 | Match berjalan | Perhatikan HUD selama satu wave penuh | HP core, nomor wave, koin match, dan timer semuanya terlihat dan terupdate; tidak ada nilai yang nyangkut di angka lama | M2 | - |
| HUD-02 | Match berakhir — dites dua kali, menang dan kalah | Lihat layar hasil | Menampilkan menang/kalah, wave yang dicapai, koin, XP, material, dan tingkat yang terbuka, sesuai payload `MatchResult` di 3.6 | M2 | - |
| HUD-03 | State `Lobby` setelah satu match | Buka panel upgrade dan craft | Panel menampilkan koin, level senjata, dan material terkini, bukan angka sebelum match | M5 | - |

## 13. Pemetaan ke kriteria "Selesai kalau"

Tabel ini yang dipakai sebagai **gerbang milestone**: sebuah milestone boleh
dicentang kalau seluruh test case di kolom kanan hijau. Kriteria M0 ikut
dimasukkan karena sebagian memang bisa dites black-box; sisanya (CI dan unit
test Lune) diverifikasi di CI, bukan di dokumen ini.

| Milestone | Kriteria "Selesai kalau" | Test case |
|---|---|---|
| M0 | CI hijau, test Lune jalan | Di luar dokumen ini (CI) |
| M0 | Dua player baru yang di-load berbarengan punya tabel `weapons` yang berbeda | DATA-01, DATA-02, DATA-10 |
| M1 | Solo playtest bisa membunuh musuh | COMBAT-01, COMBAT-02, COMBAT-03, COMBAT-04, COMBAT-10, WAVE-03, WAVE-07, WAVE-11, WAVE-12, WAVE-13 |
| M1 | Core yang HP-nya habis memicu kalah | CORE-01, CORE-02, CORE-03, CORE-04 |
| M1 | Serangan terasa kena saat dites dengan ping tinggi (Network simulation) | COMBAT-05 |
| M2 | Satu match penuh bisa dimainkan dari lobby sampai hasil | MATCH-01 sampai MATCH-09, MATCH-11, MATCH-12, MATCH-13, WAVE-01, WAVE-02, WAVE-04, WAVE-05, WAVE-06, WAVE-08, WAVE-10, WAVE-14, COMBAT-11, HUD-01, HUD-02 |
| M2 | Bisa diulang tanpa restart server | MATCH-10, MATCH-14, SHOP-12 |
| M3 | Beli item mengubah gameplay di wave berikutnya | SHOP-01 sampai SHOP-06, CORE-05 |
| M3 | Tidak bisa beli di luar jeda atau dengan koin kurang (dicoba lewat remote manual) | SHOP-07, SHOP-08, SHOP-09, SEC-04 |
| M4 | Kedua boss bisa dikalahkan dengan mekaniknya berjalan | BOSS-01 sampai BOSS-09, SHOP-10, SHOP-11 |
| M4 | Material tercatat di data player setelah match | BOSS-04, BOSS-09, BOSS-10 |
| M5 | Player baru bisa main | PROG-16 |
| M5 | Dapat reward | PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, HUD-03 |
| M5 | Upgrade senjata | PROG-08, PROG-09, COMBAT-12 |
| M5 | Craft senjata boss | PROG-12, PROG-13, COMBAT-09 |
| M5 | Membuka Hard | PROG-06, PROG-07, WAVE-09 |
| M5 | Keluar, join lagi, dan semua progres masih ada | PROG-14, PROG-15, PROG-10, PROG-11, DATA-03, DATA-06 |
| M5 | Senjata `weapon_ranged` dan `weapon_boss_a` jalan di CombatService | COMBAT-06, COMBAT-07, COMBAT-08, COMBAT-09 |
| M6 | Playtest 4 player lewat Studio (Test → Clients and Servers) lancar | MP-01, MP-02, MP-03, MP-04, MP-05, BOSS-11, LB-01 sampai LB-05 |
| M6 | Rejoin di tengah match berhasil | MP-06, MP-07, MP-08, MP-09, MP-10, MP-11, DATA-04, DATA-05, DATA-07, DATA-08 |
| M6 | Tidak ada error di output server | MP-12, SEC-01 sampai SEC-12, DATA-09 |
| M7 | Tidak ada bug blocker dari alpha | Seluruh dokumen ini diisi sekali lagi dari atas ke bawah |

Kalau nanti ada kriteria yang berubah di DEVELOPMENT_PLAN.md, tabel ini yang
pertama harus ikut diperbarui — dia satu-satunya tempat yang menjamin tidak ada
kriteria yang kehilangan test case-nya.
