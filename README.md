# CodeVerse

Roblox experience. Source of truth ada di folder ini — Roblox Studio cuma
dipakai sebagai viewer/playtest lewat Rojo live sync.

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
