# CodeVerse: Konsep Game

> Status: draft konsep v1. Nama musuh, boss, senjata, dan mata uang masih
> placeholder dan akan diputuskan belakangan. Di dokumen ini semuanya disebut
> berdasarkan fungsinya.

## Ringkasan

CodeVerse adalah game **wave survival co-op** di Roblox. Player berperan sebagai
tim IT yang menjaga **Core Server** di tengah map dari serangan malware yang
datang bergelombang. Setiap 5 wave muncul boss dengan mekanik yang meniru sifat
malware aslinya. Di luar match ada progres permanen (upgrade senjata, senjata
baru dari material boss, tingkat kesulitan) supaya player punya alasan untuk
main lagi.

| | |
|---|---|
| Genre | Wave survival, co-op |
| Platform | Roblox (PC, mobile, konsol) |
| Jumlah player per match | 1 sampai 4 |
| Durasi satu match | 10 sampai 15 menit |
| Target pemain | Umur 13+, pelajar dan mahasiswa |
| Nilai tambah | Mengenalkan jenis malware dan cara pencegahannya lewat gameplay |

## Storyline singkat

Sebuah perusahaan diserang malware. Core Server, pusat seluruh data perusahaan,
jadi sasaran utama. Player adalah tim IT yang dipanggil untuk menahan serangan
sampai sistem berhasil dipulihkan. Makin lama bertahan, ancaman yang datang
makin besar, sampai muncul ancaman terakhir yang harus dikalahkan.

## Core loop

```
Lobby -> pilih senjata & tingkat kesulitan -> Match (wave demi wave, boss tiap 5 wave)
      -> menang / kalah -> Reward -> Upgrade / Craft -> buka tingkat berikutnya -> Lobby
```

## Alur satu match

1. Player di lobby memilih senjata dan tingkat kesulitan, lalu masuk ke arena.
2. Match dimulai: HP Core Server penuh, wave 1, koin match 0.
3. Musuh muncul dari beberapa titik spawn dan berjalan ke Core Server.
4. Player menyerang musuh. Setiap musuh yang kalah memberi **koin match**.
5. Musuh yang sampai ke Core Server mengurangi HP-nya.
6. Wave selesai saat semua musuh habis, lalu ada **jeda 20 detik** untuk belanja
   di **Toko Match**.
7. Setiap wave kelipatan 5 adalah **boss wave**.
8. Match berakhir saat:
   - **Kalah:** HP Core Server habis.
   - **Menang:** wave terakhir selesai (v1: wave 10).
9. Reward dihitung dan disimpan, player kembali ke lobby.

## Dua lapis progres

| Lapisan | Mata uang | Dipakai untuk | Reset? |
|---|---|---|---|
| Dalam match | Koin match | Upgrade stat sementara, item bantu (penghalang, turret kecil) | Ya, tiap match |
| Luar match | Koin permanen, material boss, XP | Upgrade senjata, craft senjata boss, perk | Tidak |

Kalah tetap dapat koin permanen sesuai wave yang dicapai, supaya player yang
belum kuat tetap merasa ada kemajuan.

## Musuh (placeholder berdasarkan perilaku)

| ID | Perilaku | Analogi malware |
|---|---|---|
| `basic` | Lambat, HP kecil | Adware / pop-up |
| `fast` | Cepat, HP kecil | Worm |
| `stealth` | Tak terlihat beberapa detik | Spyware |
| `tank` | Lambat, HP besar | Rootkit |
| `swarm` | Datang berkelompok | Botnet |

v1 cukup `basic`, `fast`, dan `tank`.

## Boss (v1: 2 boss)

| ID | Wave | Mekanik | Analogi | Drop |
|---|---|---|---|---|
| `boss_splitter` | 5 | Saat HP turun ke 66% dan 33%, membelah jadi beberapa musuh kecil | Worm | Material A |
| `boss_locker` | 10 | Mengunci Toko Match dan memanggil minion sampai boss mati | Ransomware | Material B |

Setelah boss kalah, muncul **kartu info** singkat: malware apa yang dia wakili
dan cara mencegahnya. Ini bagian edukasinya.

## Senjata (v1: 3 senjata)

| ID | Tipe | Cara dapat |
|---|---|---|
| `weapon_starter` | Jarak dekat, damage sedang | Default |
| `weapon_ranged` | Jarak jauh, damage kecil, cepat | Beli pakai koin permanen |
| `weapon_boss_a` | Serangan membelah jadi 3 | Craft pakai Material A |

Setiap senjata bisa di-upgrade dari level 1 sampai 10 (damage, kecepatan
serang, jangkauan).

## Tingkat kesulitan

| ID | HP musuh | Reward | Cara buka |
|---|---|---|---|
| `normal` | x1.0 | x1.0 | Default |
| `hard` | x1.8 | x1.6 | Menang di Normal |

Tingkat berikutnya (`critical`, dst.) masuk setelah v1.

## Reward akhir match

- Koin permanen: berdasarkan wave tertinggi yang dicapai, plus bonus kalau menang
- XP untuk level player
- Material boss yang di-drop selama match
- First clear: kemenangan pertama di suatu tingkat membuka tingkat berikutnya

## Gamifikasi

- **Lifecycle:** onboarding (tutorial dan wave awal) -> scaffolding (grinding,
  boss pertama) -> mastery (tingkat Hard, craft senjata, leaderboard).
- **Kenyamanan:** kesulitan naik bertahap, match pendek, kalah tetap dapat
  reward, musuh menyesuaikan jumlah player.
- **Points / Badges / Leaderboard:** koin dan XP, title (setelah v1),
  leaderboard wave tertinggi.
- **Model pembelajaran:** experiential learning. Mekanik boss meniru sifat
  malware, lalu kartu info menjelaskan malware tersebut.

## Lingkup v1

Masuk v1:

- 1 map arena + area lobby
- 10 wave, 3 jenis musuh, 2 boss
- 3 senjata, upgrade senjata level 1 sampai 10
- Toko Match sederhana
- Koin permanen, XP, material boss, craft 1 senjata
- 2 tingkat kesulitan
- Leaderboard wave tertinggi
- Save progress (DataStore)

Setelah v1:

- Sampai 25 wave dan 5 boss
- Tingkat `critical` dan seterusnya
- Kelas/peran player, perk
- Bonus harian, title, skin
- Map tambahan
- Lobby dan arena di place terpisah dengan TeleportService

## Yang masih perlu diputuskan

- Nama game final (sementara: CodeVerse)
- Nama dan desain musuh, boss, senjata, mata uang, material
- Gaya visual (low poly, kartun, neon/cyber)
- Teks kartu info untuk tiap malware
