# CodeVerse

Roblox experience. Source of truth ada di folder ini — Roblox Studio cuma
dipakai sebagai viewer/playtest lewat Rojo live sync.

## Dokumen

| File | Isi |
|---|---|
| [docs/CONCEPT.md](docs/CONCEPT.md) | Konsep game, daftar fitur v1 |
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Keputusan arsitektur, spesifikasi teknis, milestone M0-M8 |
| [docs/TEST_CASES.md](docs/TEST_CASES.md) | **Satu-satunya dokumen pengujian manual.** Persiapan Studio, test case bernomor, pemetaan ke kriteria "Selesai kalau", dan catatan keputusan implementasi |
| [docs/ARENA.md](docs/ARENA.md) | Struktur arena graybox dan cara meng-export-nya |

Kode M1 sampai M5 **belum pernah dijalankan di Roblox Studio** — yang hijau baru
CI (lint, type check, unit test Lune, build). Sebelum menyentuh fitur baru, baca
`docs/TEST_CASES.md`: dokumen itu gerbang pertama yang sebenarnya.

## Setup pertama kali

```bash
rokit install        # pasang semua tool sesuai versi di rokit.toml
wally install        # pasang dependencies Luau (kalau ada)
```

Install extension VS Code yang direkomendasikan (VS Code akan nawarin otomatis,
atau lihat `.vscode/extensions.json`).

## Development loop

```bash
rojo serve           # dev server di localhost:34872
```

Lalu di Roblox Studio: tab **Plugins → Rojo → Connect**. Mulai sekarang tiap
save file `.luau` langsung kesync ke Studio. Tekan F5 buat playtest.

## Perintah lain

```bash
rojo build default.project.json --output build/codeverse.rbxl   # build place file
stylua src/                                                      # format
selene src/                                                      # lint
rojo sourcemap default.project.json --output sourcemap.json      # buat type checking
```

## Struktur

| Path | Jadi Instance apa di Studio |
|---|---|
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared/` | `ReplicatedStorage.Shared` |
| `Packages/` | `ReplicatedStorage.Packages` (dikelola Wally) |
| `assets/` | `Workspace` — map dan model, di-mount mulai M1 |
| `art/` | — sumber Blender (`.blend`), tidak di-mount |

Mapping-nya didefinisikan di `default.project.json`.

File `init.server.luau` / `init.client.luau` jadi Script di node induknya —
itu konvensi Rojo, bukan nama khusus Roblox.

### Aturan client/server

- `src/server/` jalan di server Roblox. **Trusted.** Semua validasi, semua
  perubahan data, semua angka yang penting diputuskan di sini.
- `src/client/` jalan di device player. **Untrusted.** Bisa dibaca dan diubah
  pemain yang niat ngecheat. Isinya cuma input dan presentasi.
- Komunikasi antar keduanya lewat `src/shared/Remotes.luau`. Jangan bikin
  RemoteEvent ad-hoc di tempat lain — susah di-audit.

## Mengedit map

Geometry arena dan lobby dibuat di Studio, tapi yang disimpan di repo adalah
hasilnya: `assets/Arena.rbxmx` dan `assets/Lobby.rbxmx`. Formatnya XML, jadi
masih bisa di-review di git, untuk di-mount ke `Workspace`. Titik spawn, waypoint
lane, dan posisi Core Server ditandai Part bernama khusus supaya kode tidak
bergantung pada koordinat.

> ⚠️ **Rojo bekerja satu arah.** Dia membaca file dari disk lalu menimpa
> Instance yang bersangkutan di Studio — tidak pernah sebaliknya. Begitu
> `assets/Arena.rbxmx` ter-mount, apa pun yang kamu ubah pada `Workspace.Arena`
> di dalam Studio akan **hilang** pada sync berikutnya: tanpa peringatan, tanpa
> bisa di-undo.

Jadi tiap kali ngedit map:

1. Edit arena di Studio seperti biasa.
2. **Sebelum** sync apa pun: klik kanan `Workspace.Arena` → **Save to File** →
   timpa `assets/Arena.rbxmx`.
3. Baru commit.

Lupa langkah 2 = kerjaannya hilang. Mitigasinya kebiasaan, bukan tooling:
kerjakan map di sesi terpisah dari coding, dan commit tiap kali selesai satu
sesi.

Mapping `assets/` **sudah ada** di `default.project.json` sejak M1, jadi
prosedur di atas berlaku sekarang:

```json
"Workspace": {
  "Arena": { "$path": "assets/Arena.rbxmx" },
  "Lobby": { "$path": { "optional": "assets/Lobby.rbxmx" } }
}
```

`assets/Arena.rbxmx` sudah ada di repo; `assets/Lobby.rbxmx` **belum** dan
dibuat sekali lewat `scripts/build_lobby.luau` — langkahnya ada di
[docs/TEST_CASES.md](docs/TEST_CASES.md) bagian 2.6. Bentuk `optional` dipakai
karena `"$path"` biasa membuat `rojo build` gagal keras selama filenya belum
ada; alasan lengkapnya di bagian 20 dokumen itu.

## Aset 3D

Roblox tidak memakai file 3D saat game berjalan. Waktu sebuah mesh di-import,
Studio meng-upload geometrinya ke server Roblox dan dapat sebuah **asset ID**;
`MeshPart` di place cuma menyimpan ID itu di properti `MeshId`. File `.fbx`-nya
sendiri tidak pernah ikut terkirim ke pemain. Artinya format file cuma
menentukan kelancaran saat import, bukan performa game.

Importer menerima `.fbx`, `.obj`, dan `.gltf`/`.glb`. Project ini pakai
**`.blend` sebagai sumber di `art/`, export `.fbx` untuk import** — satu format
yang menutup mesh statis, rigged, dan ber-animasi, dan yang paling banyak
dibahas di panduan export Blender di dokumentasi Roblox.

`art/` sengaja **dipisah** dari `assets/`: `assets/` di-mount Rojo ke dalam
DataModel, jadi file `.blend` tidak boleh nyangkut di sana.

Budget triangle:

| Aset | Target triangle |
|---|---|
| Musuh biasa | 200 sampai 500 |
| Boss | beberapa ribu (cuma satu di layar) |
| Props arena | 100 sampai 300 |

Batas keras Roblox sendiri 20.000 triangle per mesh dan maksimal 4 bone per
vertex, tapi angka itu tidak relevan di sini — constraint yang sebenarnya adalah
40 musuh aktif sekaligus, di platform mobile juga. Low poly bukan pilihan gaya,
tapi kebutuhan performa.

Karena hasil upload jadi asset ID, file `.rbxmx` di `assets/` menyimpan ID itu
di dalamnya. Jadi tiap kali model diubah, alurnya:

export ulang dari Blender → import ulang di Studio (dapat ID baru) → simpan
ulang `.rbxmx` → commit.

Iterasi visual tidak gratis, jadi lebih hemat kalau model diselesaikan dulu di
Blender sebelum masuk Studio.

## Data / "database"

Tidak ada SQL. Persistence pakai `DataStoreService`, dibungkus di
`src/server/Services/PlayerDataService.luau` (sudah ada session lock, autosave,
retry dengan backoff, dan `BindToClose`).

Skema data ada di `src/shared/Config.luau` → `DEFAULT_DATA`. Nambah field baru
di situ aman untuk player lama; fungsi `reconcile` ngisi default tanpa nimpa
data yang sudah ada. Kalau ada perubahan **breaking**, naikkan
`Config.DATASTORE_NAME` ke versi berikutnya.

> ⚠️ DataStore tidak aktif di Studio sampai kamu centang
> **Game Settings → Security → Enable Studio Access to API Services**.

## Publish

**Manual:** Studio → `File → Publish to Roblox`. Pertama kali bikin experience
baru; setelahnya Place ID tersimpan di file `.rbxl` lokal kamu.

**Otomatis:** workflow `.github/workflows/publish.yml` (manual trigger). Butuh
di repo GitHub:

- Secret `ROBLOX_API_KEY` — Open Cloud API key dengan scope `universe-places:write`
- Variable `ROBLOX_UNIVERSE_ID` dan `ROBLOX_PLACE_ID`

API key dibuat di <https://create.roblox.com/dashboard/credentials>.

## Git

Repo git biasa, push ke GitHub seperti project lain. Dua hal:

- `.rbxl` / `.rbxlx` **tidak** di-commit (binary, merge conflict-nya mustahil
  diresolve). Sudah masuk `.gitignore`.
- Jangan pakai **Team Create** bareng Rojo — keduanya saling menimpa. Pilih satu.
