# Arena graybox: cara menghasilkan `assets/Arena.rbxmx`

Arena CodeVerse tidak dibangun dengan klik di Studio, tapi dihasilkan oleh
script: [`scripts/build_arena.luau`](../scripts/build_arena.luau). Alasannya ada
satu dan cukup penting — kode M1 membaca jalur musuh dari **nama** Part
waypoint (`"1"`, `"2"`, `"3"`, ...), dan kalau satu nama saja salah ketik atau
urutannya terbalik, musuh akan jalan ke arah yang salah tanpa ada error apa pun
yang menunjukkan di mana salahnya. Script tidak bisa salah ketik.

Jadi alurnya: script membangun arena di Studio → kamu simpan hasilnya jadi file
→ file itu yang di-commit.

---

## 1. Apa itu command bar

Command bar adalah satu baris input di Roblox Studio tempat kamu bisa menjalankan
kode Luau langsung, sekali jalan, tanpa membuat Script apa pun di Explorer. Kode
yang kamu jalankan di sana berjalan dengan izin plugin — artinya dia boleh
mengubah isi Explorer, dan perubahannya nyata di place yang sedang kamu buka
(bukan cuma saat Play).

Letaknya: tab **View** di ribbon atas → tombol **Command Bar**. Setelah
di-klik, dia muncul sebagai baris input di bawah jendela Studio, biasanya satu
panel dengan **Output**. Kalau Output belum terbuka, buka juga dari **View** →
**Output** — kamu butuh itu untuk membaca hasilnya.

## 2. Jalankan script-nya

1. Buka Roblox Studio, buka place apa pun (place kosong juga cukup — arena ini
   tidak bergantung pada isi place yang lain).
2. Buka [`scripts/build_arena.luau`](../scripts/build_arena.luau) di editor,
   **select all** (Ctrl+A), **copy** (Ctrl+C).
3. Klik command bar, **paste** (Ctrl+V), tekan **Enter**.

Command bar kelihatan seperti input satu baris, jadi script ~270 baris yang
kamu tempel akan tampak terpotong atau jadi satu baris panjang. Itu normal —
yang ditempel tetap utuh dan tetap dijalankan sebagai satu kesatuan saat kamu
tekan Enter.

## 3. Yang seharusnya muncul

Di **Output**, dua baris:

```
[build_arena] Arena dibangun: 2 lane x 7 waypoint. Waypoint pertama 144 stud dari Core, yang terakhir 24 stud. DEBUG_VISIBLE_WAYPOINTS = false
[build_arena] Berikutnya: klik kanan Workspace.Arena > Save to File > simpan sebagai assets/Arena.rbxmx
```

Di **Explorer**, `Workspace.Arena` sudah ada dan sudah dalam keadaan terpilih
(script memilihnya untuk kamu), dengan isi:

```
Arena                   Model
	CoreServer          Model, PrimaryPart = Core
		Base
		Core            Part biru neon, ini PrimaryPart-nya
	Lanes               Folder
		Lane1           Folder: Part "1".."7"
		Lane2           Folder: Part "1".."7"
	PlayerSpawn         SpawnLocation
	Graybox             Folder: Floor, 4 dinding, 2 strip penanda lane
```

Di **viewport**: lantai abu-abu 240x240 stud dengan dinding di keempat sisinya,
satu menara biru menyala di tengah (itu Core Server), dua strip warna di lantai
yang datang dari arah barat-laut dan timur-laut menuju Core (itu jalur musuh),
dan satu pad biru muda di sisi selatan Core (itu PlayerSpawn).

Waypoint-nya **tidak kelihatan**, dan itu memang disengaja: dia penanda yang
dibaca kode, bukan geometry. Kalau kamu mau melihatnya (misal saat menyetel
jaraknya), ubah satu baris di atas script:

```luau
local DEBUG_VISIBLE_WAYPOINTS = true
```

lalu jalankan ulang. Waypoint akan muncul sebagai kubus kuning menyala.
**Kembalikan ke `false`** sebelum menyimpan arena yang mau di-commit.

Script ini idempoten: kalau `Workspace.Arena` sudah ada, dia dihapus dulu lalu
dibangun ulang. Jadi kamu bisa menempel-dan-Enter berkali-kali sambil menyetel
angka tanpa menumpuk arena.

## 4. Simpan jadi `assets/Arena.rbxmx`

Ini langkah yang menghasilkan file untuk repo.

1. Pastikan folder `assets/` sudah ada di repo. Belum ada di commit awal, jadi
   buat saja folder kosongnya dulu.
2. Di Explorer, **klik kanan `Workspace.Arena`** → **Save to File...**
3. Arahkan ke folder `assets/` di dalam checkout repo kamu.
4. Nama file: `Arena`, tipe file: **Roblox Model XML (\*.rbxmx)** — bukan
   `.rbxm`. `.rbxm` itu format biner; `.rbxmx` isinya XML, dan itu yang
   disepakati di [`DEVELOPMENT_PLAN.md`](DEVELOPMENT_PLAN.md) bagian 1.4.
5. Simpan, lalu commit `assets/Arena.rbxmx`.

Catatan kecil: `.gitattributes` menandai `*.rbxmx` sebagai `binary`, jadi `git
diff` tidak akan menampilkan isinya walaupun file-nya XML. Itu memang
disengaja — diff XML Roblox praktis tidak bisa dibaca manusia. Kalau perlu
melihat isinya, buka saja file-nya dengan editor teks.

## 5. Peringatan: setelah mapping Rojo ada, Studio bukan lagi sumber kebenaran

Rojo bekerja **satu arah**: dia membaca file di disk, lalu menimpa Instance yang
bersangkutan di Studio. Begitu `assets/Arena.rbxmx` ter-mount lewat
`default.project.json`, apa pun yang kamu ubah pada `Workspace.Arena` di dalam
Studio akan **hilang pada sync berikutnya** — tanpa peringatan, dan tidak bisa
di-undo.

Mapping itu **belum ada**. `default.project.json` saat ini cuma memetakan
`src/`. Menambahkan ini adalah pekerjaan M1 (lihat
[`DEVELOPMENT_PLAN.md`](DEVELOPMENT_PLAN.md) bagian 1.4 dan checklist M1):

```json
"Workspace": {
  "Arena": { "$path": "assets/Arena.rbxmx" },
  "Lobby": { "$path": "assets/Lobby.rbxmx" }
}
```

Jadi **sampai mapping itu ditambahkan**, Studio aman: Rojo tidak menyentuh
`Workspace.Arena` sama sekali, dan kamu bebas membangun-ulang arena lewat
command bar kapan pun.

**Sesudah mapping itu ada**, aturannya jadi:

1. Edit arena di Studio seperti biasa (atau jalankan ulang generator-nya).
2. **Sebelum** sync apa pun: klik kanan `Workspace.Arena` → **Save to File** →
   timpa `assets/Arena.rbxmx`.
3. Baru commit, baru sync.

Kalau lupa langkah 2, kerjaannya hilang. Mitigasinya manusia, bukan teknis:
kerjakan map dalam sesi terpisah dari coding, dan commit tiap kali selesai satu
sesi.

## 6. Menyetel angkanya

Semua angka yang mungkin mau kamu ubah ada di satu blok konstanta di atas
`scripts/build_arena.luau`, tidak ada yang tertanam di tengah kode:

| Konstanta | Isi |
|---|---|
| `DEBUG_VISIBLE_WAYPOINTS` | tampilkan waypoint sebagai kubus kuning |
| `CORE_POSITION` | titik pusat arena di permukaan lantai; lantai, dinding, lane, dan spawn semuanya relatif ke sini |
| `CORE_BASE_SIZE`, `CORE_SIZE` | alas dan menara Core; `CORE_SIZE` yang jadi `PrimaryPart` |
| `FLOOR_SIZE` | ukuran lantai (240x240, cukup lega untuk 4 pemain) |
| `WALL_HEIGHT`, `WALL_THICKNESS` | dinding pembatas |
| `WAYPOINTS_PER_LANE` | jumlah waypoint per lane |
| `WAYPOINT_SPACING` | jarak antar waypoint, stud |
| `CORE_CLEARANCE` | jarak waypoint terakhir ke pusat Core |
| `WAYPOINT_HEIGHT`, `WAYPOINT_SIZE` | ukuran & tinggi Part penanda |
| `LANE_WIDTH` | lebar strip penanda lane di lantai |
| `LANES` | nama, arah datang, dan warna tiap lane — tambah entri di sini kalau mau lane ketiga |
| `PLAYER_SPAWN_OFFSET`, `PLAYER_SPAWN_SIZE` | posisi & ukuran `PlayerSpawn` relatif Core |

Dua batas yang perlu dijaga kalau kamu menaikkan angkanya, dan dua-duanya ada
sebagai komentar di script:

- Jarak waypoint pertama ke Core = `CORE_CLEARANCE + (WAYPOINTS_PER_LANE - 1) *
  WAYPOINT_SPACING`, sekarang 144 stud. Karena lane-nya diagonal, itu ~102 stud
  di tiap sumbu, sementara setengah-lantai cuma 120 stud. Kalau kamu menambah
  waypoint atau jaraknya, besarkan juga `FLOOR_SIZE` — kalau tidak, titik spawn
  musuh jatuh di luar dinding.
- `CORE_CLEARANCE` tidak boleh lebih kecil dari diagonal alas Core
  (`CORE_BASE_SIZE.X / 2 * sqrt(2)`, sekarang ~17 stud), kalau tidak waypoint
  terakhir menembus alas dan musuh harus memanjat pedestal untuk sampai.

## 7. Kenapa nama waypoint-nya cuma angka

Dari [`DEVELOPMENT_PLAN.md`](DEVELOPMENT_PLAN.md) bagian 3.4: waypoint dibaca
sekali saat server start lalu di-cache sebagai daftar `Vector3`, dan urutannya
diambil dari **nama** Part yang di-sort numerik — bukan dari urutan
`GetChildren()`, karena urutan `GetChildren()` tidak dijamin Roblox.

Konsekuensinya: nama `"1"`, `"2"`, `"3"`, ... harus berurutan dari titik spawn
musuh menuju Core, tanpa nomor yang bolong. Kalau kamu menambah waypoint
manual di Studio, nomornya harus kamu rapikan sendiri. Lebih aman: ubah
`WAYPOINTS_PER_LANE` lalu jalankan ulang generator-nya.
