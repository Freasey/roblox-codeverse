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
