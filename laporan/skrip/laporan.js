// Membangun laporan tugas (.docx) untuk proyek CodeVerse.
// Semua angka di dokumen ini dibaca dari repo, bukan ditebak.
const fs = require("fs");
const path = require("path");
const d = require("docx");

const {
  Document, Packer, Paragraph, TextRun, ImageRun, HeadingLevel, AlignmentType,
  Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle, PageBreak,
  Footer, PageNumber, LevelFormat, convertInchesToTwip,
} = d;

const REPO = "C:\\Web Program\\roblox-codeverse";
const IMG = path.join(REPO, "laporan", "img");
const OUT = path.join(REPO, "laporan", "Laporan-Tugas-CodeVerse.docx");

const CONTENT_W = 9638; // A4 (11906) dikurangi margin kiri+kanan (1134 x 2)
const INK = "1C2026";
const MUTED = "6E7682";
const BLUE = "26608F";
const WARN = "B4453C";
const GREEN = "2E7A4A";

// ---------------------------------------------------------------- util
function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

function p(text, opts) {
  opts = opts || {};
  return new Paragraph({
    alignment: opts.align,
    spacing: { after: opts.after === undefined ? 140 : opts.after, line: 276 },
    indent: opts.indent,
    children: [new TextRun({
      text: text,
      bold: opts.bold,
      italics: opts.italics,
      color: opts.color || INK,
      size: opts.size || 22,
      font: opts.mono ? "Consolas" : undefined,
    })],
  });
}

// Paragraf dengan beberapa potongan: [["teks", {bold:true}], ...]
function rich(parts, opts) {
  opts = opts || {};
  return new Paragraph({
    alignment: opts.align,
    spacing: { after: opts.after === undefined ? 140 : opts.after, line: 276 },
    children: parts.map(function (x) {
      const t = x[0];
      const o = x[1] || {};
      return new TextRun({
        text: t, bold: o.bold, italics: o.italics,
        color: o.color || opts.color || INK,
        size: o.size || opts.size || 22,
        font: o.mono ? "Consolas" : undefined,
      });
    }),
  });
}

// Tiap bab mulai di halaman baru lewat pageBreakBefore, BUKAN lewat paragraf
// PageBreak tersendiri: paragraf itu ikut mengalir, jadi kalau halaman
// sebelumnya kebetulan penuh dia mendarat di halaman berikutnya dan
// meninggalkan satu halaman kosong melompong.
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    pageBreakBefore: true,
    spacing: { before: 0, after: 180 },
    children: [new TextRun({ text: text, bold: true, size: 32, color: INK })],
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 260, after: 120 },
    children: [new TextRun({ text: text, bold: true, size: 25, color: BLUE })],
  });
}

function bullet(text, opts) {
  opts = opts || {};
  return new Paragraph({
    numbering: { reference: "bullets", level: 0 },
    spacing: { after: 80, line: 276 },
    children: [new TextRun({ text: text, size: 22, color: opts.color || INK })],
  });
}

// docx mengabaikan "\n" di dalam satu TextRun, jadi tiap baris jadi run
// tersendiri dengan break — kalau tidak, seluruh kode menempel jadi satu baris.
function code(lines) {
  const arr = Array.isArray(lines) ? lines : [lines];
  return new Paragraph({
    spacing: { before: 60, after: 140 },
    shading: { type: ShadingType.CLEAR, fill: "F4F6F9" },
    indent: { left: 280, right: 280 },
    children: arr.map(function (l, i) {
      return new TextRun({
        text: l, font: "Consolas", size: 19, color: "24323F",
        break: i > 0 ? 1 : 0,
      });
    }),
  });
}

function note(text, color) {
  return new Paragraph({
    spacing: { before: 120, after: 160, line: 276 },
    indent: { left: 280 },
    border: { left: { style: BorderStyle.SINGLE, size: 18, space: 10, color: color || WARN } },
    children: [new TextRun({ text: text, size: 21, color: INK })],
  });
}

let figNo = 0;
function img(file, caption, widthPx) {
  const full = path.join(IMG, file);
  const sz = pngSize(full);
  const w = widthPx || 540;
  const h = Math.round(w * sz.h / sz.w);
  figNo += 1;
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 200, after: 60 },
      children: [new ImageRun({
        data: fs.readFileSync(full),
        transformation: { width: w, height: h },
        type: "png",
      })],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 220 },
      children: [new TextRun({
        text: "Gambar " + figNo + ". " + caption,
        italics: true, size: 19, color: MUTED,
      })],
    }),
  ];
}

function cell(text, opts) {
  opts = opts || {};
  return new TableCell({
    width: { size: opts.w, type: WidthType.DXA },
    shading: opts.fill ? { type: ShadingType.CLEAR, fill: opts.fill } : undefined,
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    children: [new Paragraph({
      spacing: { after: 0, line: 252 },
      children: [new TextRun({
        text: text,
        bold: opts.bold,
        size: opts.size || 20,
        color: opts.color || INK,
        font: opts.mono ? "Consolas" : undefined,
      })],
    })],
  });
}

// rows: array of arrays; tiap sel boleh string atau {t, color, bold, mono}
function table(headers, rows, widths) {
  const sum = widths.reduce(function (a, b) { return a + b; }, 0);
  const scale = CONTENT_W / sum;
  const w = widths.map(function (x) { return Math.round(x * scale); });
  const head = new TableRow({
    tableHeader: true,
    children: headers.map(function (t, i) {
      return cell(t, { w: w[i], bold: true, fill: "EDF1F6", size: 20 });
    }),
  });
  const body = rows.map(function (r) {
    return new TableRow({
      children: r.map(function (c, i) {
        if (typeof c === "string") return cell(c, { w: w[i] });
        return cell(c.t, { w: w[i], color: c.color, bold: c.bold, mono: c.mono });
      }),
    });
  });
  return new Table({
    columnWidths: w,
    width: { size: CONTENT_W, type: WidthType.DXA },
    rows: [head].concat(body),
  });
}

function spacer(n) { return new Paragraph({ spacing: { after: n || 200 }, children: [] }); }

// ---------------------------------------------------------------- isi
const children = [];

// ---- sampul
children.push(spacer(1400));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "LAPORAN TUGAS", bold: true, size: 56, color: INK })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 400 },
  children: [new TextRun({
    text: "Perancangan dan Implementasi Game dengan Konsep Gamifikasi",
    size: 28, color: MUTED,
  })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 80 },
  children: [new TextRun({ text: "Studi kasus:", size: 22, color: MUTED })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 100 },
  children: [new TextRun({ text: "CodeVerse", bold: true, size: 40, color: BLUE })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 900 },
  children: [new TextRun({
    text: "Game wave survival co-op di Roblox, bertema pertahanan dari malware",
    size: 22, color: MUTED,
  })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 60 },
  children: [new TextRun({ text: "Disusun oleh", size: 20, color: MUTED })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 320 },
  children: [new TextRun({ text: "Daffa", bold: true, size: 26, color: INK })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER, spacing: { after: 0 },
  children: [new TextRun({ text: "25 Oktober 2026", size: 20, color: MUTED })],
}));

// ---- daftar isi manual
children.push(h1("Daftar isi"));
const toc = [
  "Catatan pembuka: tentang pemetaan platform",
  "Bab 1  Karakter dan tiga animasinya",
  "Bab 2  Background game",
  "Bab 3  Level arena dan penyusunannya",
  "Bab 4  Character movement",
  "Bab 5  Sinkronisasi animasi dengan tindakan",
  "Bab 6  Sistem kamera",
  "Bab 7  Konsep gamifikasi",
  "Lampiran A  Status verifikasi proyek",
  "Lampiran B  Daftar screenshot",
];
toc.forEach(function (t) {
  children.push(new Paragraph({
    spacing: { after: 90 },
    children: [new TextRun({ text: t, size: 22, color: INK })],
  }));
});

// ---- catatan pembuka
children.push(h1("Catatan pembuka: tentang pemetaan platform"));
children.push(p(
  "Soal tugas ini ditulis untuk Unity Engine dengan game 2D: sprite karakter yang digambar " +
  "di Photoshop atau Piskel, background berlapis, level dari tileset, dan kamera Cinemachine. " +
  "Proyek yang dilaporkan di sini, CodeVerse, dibangun di Roblox dan ruangnya tiga dimensi."));
children.push(p(
  "Laporan ini tidak berpura-pura sebaliknya. Tiap bab disusun dengan urutan yang sama: apa " +
  "yang diminta soal, apa padanannya di Roblox, lalu bukti bahwa padanan itu memang ada di " +
  "proyek. Di beberapa tempat padanannya tidak setara, dan itu ditulis terang-terangan di bab " +
  "masing-masing dengan tanda khusus, bukan disamarkan."));
children.push(p(
  "Alasan pemetaan ini masuk akal: yang dinilai soal sebenarnya bukan Unity-nya, melainkan " +
  "apakah sebuah karakter bisa bergerak dan beranimasi sesuai tindakannya, apakah ada level " +
  "yang dirancang, apakah kamera mengikuti pemain, dan apakah ada konsep gamifikasi yang " +
  "dipikirkan. Ketujuh hal itu bisa ditunjukkan di Roblox."));
children.push(h2("Ringkasan pemetaan"));
children.push(table(
  ["Soal", "Yang diminta (Unity 2D)", "Padanan di CodeVerse (Roblox)", "Status"],
  [
    ["1", "Karakter 2D buatan sendiri, minimal 3 animasi",
      "Rig Humanoid R15 + script Animate bawaan",
      { t: "Sebagian", color: WARN, bold: true }],
    ["2", "Background game dari berbagai assets",
      "Lighting dan Skybox default + dinding arena",
      { t: "Sebagian", color: WARN, bold: true }],
    ["3", "Level platform dari tileset + background bertema",
      "Arena 240x240 stud, 2 lane, 14 waypoint, dibangun oleh script",
      { t: "Ada", color: GREEN, bold: true }],
    ["4", "Idle, run, jump, crouch",
      "Humanoid menangani locomotion; InputController menangani bidikan",
      { t: "Sebagian", color: WARN, bold: true }],
    ["5", "Animasi tersinkron dengan tiap tindakan",
      "Animate membaca HumanoidStateType, pergantian klip otomatis",
      { t: "Ada", color: GREEN, bold: true }],
    ["6", "Kamera 2D dengan Cinemachine",
      "Kamera default Roblox mengikuti karakter; dipakai juga untuk raycast bidikan",
      { t: "Ada", color: GREEN, bold: true }],
    ["7", "Menampilkan konsep gamifikasi",
      "Core loop, dua lapis mata uang, leaderboard, kartu info edukasi, dua tingkat kesulitan",
      { t: "Ada", color: GREEN, bold: true }],
  ],
  [500, 2600, 3900, 1100]));
children.push(spacer(120));
children.push(note(
  "Tiga baris bertanda \"Sebagian\" adalah kekurangan yang nyata, bukan basa-basi merendah. " +
  "Masing-masing dijelaskan di akhir babnya sendiri, lengkap dengan apa yang harus dikerjakan " +
  "untuk menutupnya."));


// ---- BAB 1
children.push(h1("Bab 1  Karakter dan tiga animasinya"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Membuat karakter game 2D yang unik menggunakan Photoshop, Piskel, atau tools lain, " +
  "mengimpornya ke Unity, dan memastikan karakter itu punya setidaknya tiga animasi berbeda " +
  "seperti berjalan, melompat, dan berdiri diam."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Di Roblox, karakter pemain tidak diimpor sebagai sprite. Roblox membuatkannya sendiri saat " +
  "pemain masuk: sebuah Model berisi Humanoid, HumanoidRootPart, dan bagian-bagian tubuh rig " +
  "R15. Avatar yang muncul adalah avatar milik akun pemain, dan itu memang disengaja oleh " +
  "platformnya — identitas visual pemain dibawa dari akunnya, bukan ditentukan oleh game."));
children.push(p(
  "Yang penting untuk soal ini: di dalam setiap karakter itu Roblox juga menyelipkan sebuah " +
  "LocalScript bernama Animate, dan script itulah yang memutar klip animasi sesuai keadaan " +
  "Humanoid. Jadi tiga animasi yang diminta soal — diam, berjalan, melompat — sudah ada sejak " +
  "karakter pertama kali muncul, tanpa satu baris kode pun ditulis di proyek ini."));
children.push(p("Ketiganya ditunjukkan pada tiga gambar berikut."));
img("s02-idle.png", "Animasi pertama: karakter berdiri diam (idle).").forEach(function (x) { children.push(x); });
img("s03-run.png", "Animasi kedua: karakter berlari (run).").forEach(function (x) { children.push(x); });
img("s04-jump.png", "Animasi ketiga: karakter melompat (jump).").forEach(function (x) { children.push(x); });
children.push(h2("Di mana karakter disentuh oleh kode proyek"));
children.push(p(
  "Proyek ini tidak mengubah rig maupun animasinya. Yang dibaca proyek dari karakter cuma dua " +
  "hal, dan keduanya ada di InputController:"));
children.push(code([
  "local humanoid = character:FindFirstChildOfClass(\"Humanoid\")",
  "local root = character.PrimaryPart",
  "    or character:FindFirstChild(\"HumanoidRootPart\")",
]));
children.push(p(
  "Humanoid dibaca untuk tahu apakah pemain masih hidup (Health lebih dari nol), dan " +
  "HumanoidRootPart dibaca sebagai titik asal arah serangan. Selebihnya, gerak dan animasi " +
  "diserahkan penuh ke Roblox.", { after: 60 }));
children.push(note(
  "Kekurangan yang jujur: karakter ini tidak dirancang sendiri di Photoshop atau Piskel. Yang " +
  "bisa dilaporkan adalah rig dan ketiga animasinya, bukan desain visualnya. Kalau penilaian " +
  "menuntut aset karakter buatan sendiri, bab ini belum memenuhinya. Dua jalan keluar yang " +
  "tersedia di Roblox: membuat aksesori atau pakaian sendiri lewat Avatar > Accessory di " +
  "Studio, atau mengunggah paket animasi sendiri dan memasangkannya lewat Animate."));


// ---- BAB 2
children.push(h1("Bab 2  Background game"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Membuat background game untuk permainan platform 2D di Unity, menggunakan berbagai assets " +
  "atau gambar yang tersedia."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Di game 2D, background adalah lapisan gambar yang digambar di belakang pemain, sering " +
  "berlapis-lapis supaya ada efek parallax. Di ruang tiga dimensi lapisan seperti itu tidak " +
  "ada. Yang mengambil perannya ada tiga hal: Skybox, yang menjadi langit ke segala arah; " +
  "Lighting, yang menentukan warna dan arah cahaya; dan geometri yang membatasi pandangan, " +
  "dalam hal ini keempat dinding arena setinggi 20 stud."));
children.push(p(
  "Dinding itu bukan hiasan. Dia yang membuat arena terbaca sebagai ruangan tertutup dan " +
  "menahan pandangan pemain supaya tidak lepas ke kekosongan di luar lantai."));
img("s05-skybox.png", "Latar belakang arena: langit dan dinding pembatas.").forEach(function (x) { children.push(x); });
children.push(note(
  "Kekurangan yang jujur: latar yang terlihat adalah bawaan Roblox, bukan pilihan sendiri. " +
  "File assets/Arena.rbxmx berisi 23 Part, 4 Folder, 2 Model, dan 1 SpawnLocation — tidak ada " +
  "satu pun objek Sky, Atmosphere, atau Lighting di dalamnya. Dokumen konsep proyek " +
  "(docs/CONCEPT.md) masih mencantumkan gaya visual, pilihan antara low poly, kartun, dan " +
  "neon/cyber, di bagian \"yang masih perlu diputuskan\". Jadi bab ini melaporkan keadaan " +
  "sebenarnya: latar ada dan berfungsi, tapi belum dirancang."));


// ---- BAB 3
children.push(h1("Bab 3  Level arena dan penyusunannya"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Membuat platform level yang kreatif menggunakan tileset, dan menambahkan background 2D yang " +
  "sesuai dengan tema level."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Roblox tidak punya tileset. Level disusun dari Part, dan Part tidak menempel ke kisi seperti " +
  "tile. Tapi gagasan inti tileset — satuan berukuran tetap yang diulang untuk menyusun ruang — " +
  "tetap ada di arena ini, dalam bentuk waypoint: titik-titik berjarak sama yang menyusun jalur " +
  "musuh dari tepi arena sampai ke Core Server."));
children.push(p(
  "Satu hal yang membedakan arena ini dari level yang disusun dengan tangan: arena CodeVerse " +
  "tidak dibangun dengan mengklik di Studio, melainkan dihasilkan oleh script " +
  "scripts/build_arena.luau yang dijalankan sekali lewat command bar. Alasannya tercatat di " +
  "docs/ARENA.md dan cukup penting."));
children.push(p(
  "Kode yang menggerakkan musuh membaca urutan jalur dari nama Part waypoint: \"1\", \"2\", " +
  "\"3\", dan seterusnya. Kalau satu nama saja salah ketik atau urutannya terbalik, musuh akan " +
  "berjalan ke arah yang salah tanpa memunculkan error apa pun — bug yang sangat mahal dicari " +
  "karena tidak ada satu pun pesan yang menunjukkan letak salahnya. Script tidak bisa salah " +
  "ketik, maka penyusunan arena diserahkan ke script."));
children.push(h2("Ukuran dan isi arena"));
children.push(table(
  ["Bagian", "Ukuran / jumlah", "Keterangan"],
  [
    ["Lantai", "240 x 240 stud", "Satu Part datar, warna abu-abu gelap"],
    ["Dinding", "4 buah, tinggi 20 stud", "Membatasi arena di keempat sisi"],
    ["Core Server", "14 x 18 x 14 stud, alas 24 x 24", "PrimaryPart; HP 1000; warnanya memudar ke merah seiring HP turun"],
    ["Lane", "2 jalur", "Lane1 ke barat-laut, Lane2 ke timur-laut; musuh dibagi rata"],
    ["Waypoint", "7 per lane, 14 total", "Jarak antar titik 20 stud"],
    ["Jarak jalur", "144 stud sampai 24 stud", "Waypoint pertama 144 stud dari Core, terakhir 24 stud"],
    ["PlayerSpawn", "14 x 14 stud", "44 stud di sebelah selatan Core"],
  ],
  [1700, 2300, 5638]));
children.push(spacer(140));
img("01-arena-layout.png",
  "Layout arena tampak atas, digambar dari konstanta di scripts/build_arena.luau.",
  545).forEach(function (x) { children.push(x); });
img("s06-arena.png", "Arena yang sama dilihat dari dalam game.").forEach(function (x) { children.push(x); });
children.push(note(
  "Kekurangan yang jujur: arena ini masih graybox. Semua Part memakai warna polos tanpa " +
  "material atau tekstur, karena yang diuji pada tahap ini adalah jalur musuh dan jarak " +
  "tempuh, bukan tampilan. Temanya sudah ada di dokumen konsep, tapi belum diwujudkan."));


// ---- BAB 4
children.push(h1("Bab 4  Character movement"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Membuat character movement yang dinamis, dan memastikan karakter dapat melakukan idle, run, " +
  "jump, dan crouch."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Locomotion di Roblox ditangani Humanoid, dan Humanoid sudah terpasang di setiap karakter. " +
  "Pemain menekan tombol, Humanoid mengubah MoveDirection atau memicu lompatan, dan fisika " +
  "menjalankan sisanya. Tiga dari empat tindakan yang diminta soal tersedia tanpa kode " +
  "tambahan; yang keempat tidak."));
children.push(table(
  ["Tindakan", "Input PC", "Input mobile", "Ditangani oleh", "Tersedia"],
  [
    ["Idle", "tidak menekan apa pun", "tidak menyentuh stick", "Humanoid", { t: "Ya", color: GREEN, bold: true }],
    ["Run", "W A S D", "stick virtual", "Humanoid", { t: "Ya", color: GREEN, bold: true }],
    ["Jump", "Space", "tombol lompat", "Humanoid", { t: "Ya", color: GREEN, bold: true }],
    ["Crouch", { t: "belum ada", color: WARN }, { t: "belum ada", color: WARN },
      { t: "belum ada", color: WARN }, { t: "Tidak", color: WARN, bold: true }],
    ["Menyerang", "klik kiri (tahan)", "tap (tahan)", "InputController.luau", { t: "Ya", color: GREEN, bold: true }],
  ],
  [1500, 2000, 1900, 2400, 1000]));
children.push(spacer(140));
children.push(h2("Yang ditambahkan proyek ini di atas gerak bawaan"));
children.push(p(
  "Baris terakhir tabel di atas adalah satu-satunya input yang ditulis sendiri di proyek ini, " +
  "dan rancangannya layak dijelaskan karena menyangkut keamanan. Saat pemain mengklik, client " +
  "tidak mengirim \"aku mengenai musuh nomor 7\" dan tidak mengirim besar damage. Yang dikirim " +
  "hanya satu Vector3: arah bidikan."));
children.push(code("Remotes.Events.Attack:FireServer(direction.Unit)"));
children.push(p(
  "Server yang memutuskan siapa yang kena dan berapa damage-nya. Kalau client boleh menyebut " +
  "target, pemain yang memodifikasi client-nya bisa menyerang musuh dari seberang arena. " +
  "Client tetap membatasi pengiriman ke 8 kali per detik — bukan demi keamanan, karena server " +
  "punya cooldown sendiri, melainkan supaya pemain yang menahan tombol tidak menabrak rate " +
  "limit 20 panggilan per detik dan serangannya mulai dibuang."));
children.push(note(
  "Kekurangan yang jujur: crouch belum ada, dan ini satu-satunya kekurangan di laporan ini " +
  "yang berupa fitur hilang, bukan soal tampilan. Roblox tidak menyediakan crouch bawaan: " +
  "tidak ada HumanoidStateType untuknya dan tidak ada klip animasinya. Untuk menutupnya " +
  "dibutuhkan tiga hal — satu binding tombol di InputController, perubahan WalkSpeed dan " +
  "HipHeight pada Humanoid saat tombol ditahan, dan satu klip animasi jongkok yang diunggah " +
  "sendiri lalu dipasang lewat Animate. Pekerjaan ini sudah diidentifikasi tapi sengaja " +
  "ditunda, dan statusnya dilaporkan apa adanya di sini."));


// ---- BAB 5
children.push(h1("Bab 5  Sinkronisasi animasi dengan tindakan"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Menambahkan animasi yang sesuai ke karakter yang sudah punya character movement, dan " +
  "memastikan animasi tersinkron dengan setiap tindakan karakter."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Di Unity, pekerjaan ini berarti menyusun Animator Controller: membuat state untuk tiap " +
  "animasi, menarik garis transisi di antaranya, dan menentukan parameter yang memicu " +
  "perpindahan. Di Roblox lapisan itu sudah jadi. Humanoid mengumumkan keadaannya lewat " +
  "HumanoidStateType, dan script Animate di dalam karakter mendengarkan pengumuman itu lalu " +
  "mengganti klip yang diputar."));
children.push(p(
  "Akibatnya ada satu sifat yang justru penting untuk proyek ini: animasi tidak bisa melenceng " +
  "dari gameplay, karena tidak ada kode di proyek ini yang memutar animasi secara manual. " +
  "Tidak ada versi kebenaran kedua yang bisa ikut salah."));
img("05-animasi.png",
  "Rantai dari input sampai klip animasi yang benar-benar diputar.",
  630).forEach(function (x) { children.push(x); });
children.push(h2("Pemetaan tiap tindakan ke klip animasinya"));
children.push(table(
  ["Tindakan pemain", "HumanoidStateType", "Klip animasi", "Status di CodeVerse"],
  [
    ["Diam (idle)", { t: "Running, kecepatan 0", mono: true, color: BLUE },
      { t: "idle", mono: true, color: BLUE }, "Ada, bawaan Roblox"],
    ["Lari (run)", { t: "Running, kecepatan > 0", mono: true, color: BLUE },
      { t: "walk / run", mono: true, color: BLUE }, "Ada, bawaan Roblox"],
    ["Lompat (jump)", { t: "Jumping", mono: true, color: BLUE },
      { t: "jump", mono: true, color: BLUE }, "Ada, bawaan Roblox"],
    ["Melayang turun", { t: "Freefalling", mono: true, color: BLUE },
      { t: "freefall", mono: true, color: BLUE }, "Ada, bawaan Roblox"],
    ["Mendarat", { t: "Landed", mono: true, color: BLUE },
      { t: "landed", mono: true, color: BLUE }, "Ada, bawaan Roblox"],
    [{ t: "Jongkok (crouch)", color: WARN }, { t: "tidak ada state bawaan", color: WARN },
      { t: "tidak ada klip bawaan", color: WARN },
      { t: "BELUM ADA", color: WARN, bold: true }],
  ],
  [2300, 2700, 2200, 2438]));
children.push(spacer(140));
children.push(p(
  "Lima baris pertama tersedia tanpa satu baris kode pun ditulis, dan itulah yang dipakai " +
  "laporan ini sebagai bukti untuk soal 1, 4, dan 5. Baris terakhir adalah kekurangan yang " +
  "sudah dijelaskan di Bab 4: Roblox tidak punya crouch bawaan, baik state maupun klipnya."));
children.push(p(
  "Sifat ini sejalan dengan cara seluruh proyek dirancang. Arsitekturnya menempatkan server " +
  "sebagai satu-satunya pemegang kebenaran: HUD tidak menghitung sendiri timer atau HP Core " +
  "melainkan menampilkan apa yang dikirim server, dan layar hasil tidak menghitung sendiri " +
  "reward melainkan menampilkan angka yang benar-benar disimpan. Animasi mengikuti pola yang " +
  "sama, dengan Humanoid sebagai pemegang kebenaran keadaan gerak."));


// ---- BAB 6
children.push(h1("Bab 6  Sistem kamera"));
children.push(h2("Yang diminta soal"));
children.push(p(
  "Mengintegrasikan game dengan sistem kamera 2D menggunakan Cinemachine, dan memastikan " +
  "kamera berfungsi dengan baik serta mengikuti pergerakan karakter."));
children.push(h2("Padanannya di Roblox"));
children.push(p(
  "Cinemachine dipakai di Unity karena Unity tidak menyediakan kamera pengikut siap pakai: " +
  "follow, damping, dan penanganan tabrakan harus dirakit. Roblox menyediakannya sebagai " +
  "bawaan. Setiap pemain punya Workspace.CurrentCamera dengan script kamera yang sudah " +
  "mengikuti karakter, menghaluskan geraknya, dan menghindari tembus dinding. Pekerjaan yang " +
  "di Unity diserahkan ke Cinemachine, di Roblox sudah selesai sebelum game ditulis."));
img("s07-kamera.png",
  "Kamera mengikuti karakter: di dua posisi berbeda, karakter tetap berada di tengah layar."
).forEach(function (x) { children.push(x); });
children.push(h2("Di mana proyek ini benar-benar memakai kamera"));
children.push(p(
  "Walaupun pergerakan kameranya bawaan, proyek ini memakai kamera untuk satu hal yang ditulis " +
  "sendiri: mengubah posisi kursor di layar menjadi titik di dunia. Tanpa langkah ini, klik " +
  "pemain hanyalah dua angka piksel yang tidak berarti apa-apa bagi server."));
children.push(code([
  "local screenPoint = UserInputService:GetMouseLocation()",
  "local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)",
  "local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)",
]));
children.push(p(
  "Raycast-nya sengaja mengabaikan karakter pemain sendiri. Tanpa pengecualian itu, sinar dari " +
  "kamera akan menabrak punggung pemain lebih dulu dan setiap bidikan akan mentok di badan " +
  "sendiri. Kalau sinarnya tidak mengenai apa pun, dipakai titik sejauh 200 stud ke arah " +
  "pandangan sebagai cadangan, sehingga bidikan ke langit tetap menghasilkan arah yang masuk " +
  "akal dan bukan kegagalan diam-diam."));
img("04-kamera-bidik.png",
  "Alur dari kamera ke arah serangan: kamera mengikuti karakter, raycast menentukan titik bidik, " +
  "hanya arahnya yang dikirim ke server.", 640).forEach(function (x) { children.push(x); });


// ---- BAB 7
children.push(h1("Bab 7  Konsep gamifikasi"));
children.push(h2("Yang diminta soal"));
children.push(p("Game harus menampilkan konsep gamifikasi yang sudah dirancang."));
children.push(h2("Konsep yang dirancang"));
children.push(p(
  "CodeVerse adalah game wave survival co-op untuk satu sampai empat pemain. Pemain berperan " +
  "sebagai tim IT yang menjaga Core Server di tengah arena dari serangan malware yang datang " +
  "bergelombang. Satu match berisi 10 wave dan berlangsung sekitar 10 sampai 15 menit, dengan " +
  "boss di wave 5 dan wave 10."));
children.push(p(
  "Nilai tambah yang ditetapkan sejak awal di docs/CONCEPT.md adalah mengenalkan jenis malware " +
  "dan cara pencegahannya lewat gameplay, dengan sasaran pemain umur 13 tahun ke atas."));
img("03-gamifikasi.png",
  "Core loop CodeVerse: satu putaran penuh dari lobby sampai kembali ke lobby.",
  560).forEach(function (x) { children.push(x); });
children.push(h2("Empat elemen gamifikasi dan wujudnya di dalam game"));
children.push(table(
  ["Elemen", "Wujud di dalam game", "File yang mewujudkannya"],
  [
    ["Points dan currency",
      "Dua lapis: cash yang didapat tiap wave dan habis saat match selesai, serta koin permanen dan XP yang tersimpan lintas sesi lewat DataStore",
      { t: "RewardService.luau, ProgressionRules.luau", mono: true }],
    ["Leaderboard",
      "Papan wave tertinggi di lobby, satu OrderedDataStore per tingkat kesulitan; hanya dibaca, tidak memengaruhi gameplay",
      { t: "LeaderboardService.luau", mono: true }],
    ["Edukasi (experiential learning)",
      "Mekanik tiap boss meniru sifat malware aslinya, lalu kartu info muncul menjelaskan malware itu dan cara mencegahnya",
      { t: "Bosses.luau, InfoCardController.luau", mono: true }],
    ["Progresi bertahap",
      "HP musuh naik tiap wave; kalah tetap memberi koin sesuai wave yang dicapai, sehingga tidak ada sesi yang terasa sia-sia",
      { t: "Balance.luau, Difficulties.luau", mono: true }],
  ],
  [1900, 4700, 3038]));
children.push(spacer(140));
children.push(h2("Dua boss dan sisi edukasinya"));
children.push(p(
  "Bagian edukasi tidak disampaikan lewat teks yang ditempel di layar awal, melainkan lewat " +
  "mekanik yang dialami dulu baru dijelaskan. Inilah yang dimaksud model experiential learning " +
  "di dokumen konsep."));
children.push(table(
  ["Boss", "Wave", "Mekanik di dalam game", "Malware yang diwakili"],
  [
    ["boss_splitter", "5", "Saat HP turun ke 66% dan 33%, membelah jadi beberapa musuh kecil", "Worm, yang memperbanyak diri"],
    ["boss_locker", "10", "Mengunci Toko Match dan memanggil minion sampai boss mati", "Ransomware, yang mengunci akses"],
  ],
  [1900, 800, 4300, 2638]));
children.push(spacer(140));
children.push(p(
  "Setelah boss kalah, kartu info muncul berisi penjelasan malware tersebut dan cara " +
  "mencegahnya. Kartu ini punya tombol tutup dan juga hilang sendiri setelah beberapa detik — " +
  "dua cara sekaligus, karena kartu muncul tepat setelah boss mati, saat masih mungkin ada " +
  "musuh pecahan yang berjalan ke Core dan pemain perlu segera kembali bermain."));
children.push(h2("Struktur satu match"));
children.push(p(
  "Satu match dijalankan sebagai state machine dengan enam state. Hanya MatchService yang boleh " +
  "mengubahnya; service lain mendengarkan perubahan itu dan bereaksi. Aturan ini dipegang ketat " +
  "sampai-sampai fitur tutorial sengaja dirancang tanpa wave latihan, supaya tidak perlu " +
  "menambah state keenam ke bagian paling rapuh dari sistem."));
img("02-state-machine.png",
  "Enam state satu match beserta durasi tiap fase.", 640).forEach(function (x) { children.push(x); });
children.push(table(
  ["State", "Durasi", "Yang terjadi"],
  [
    ["Lobby", "sampai semua pemain Ready", "Pilih senjata dan tingkat kesulitan, lihat leaderboard, upgrade dan craft"],
    ["Loadout", "20 detik", "Kesempatan terakhir mengganti senjata; setelah ini senjata terkunci sampai match selesai"],
    ["Countdown", "10 detik", "Hitung mundur sebelum wave pertama"],
    ["WaveActive", "sampai musuh habis", "Musuh berjalan menuju Core; pemain menyerang"],
    ["Intermission", "20 detik", "Toko Match terbuka untuk menaikkan level senjata dengan cash"],
    ["Ended", "10 detik", "Layar hasil, reward disimpan, lalu kembali ke Lobby"],
  ],
  [1700, 2300, 5638]));
children.push(spacer(140));
children.push(h2("Bukti dari dalam game"));
img("s01-lobby-ready.png", "Lobby: pemilihan senjata, tingkat kesulitan, dan tombol Ready.").forEach(function (x) { children.push(x); });
img("s08-hud.png", "HUD saat wave berjalan: HP Core, nomor wave, timer, dan cash tim.").forEach(function (x) { children.push(x); });
img("s09-toko.png", "Toko Match pada jeda antar wave, menjual kenaikan level senjata.").forEach(function (x) { children.push(x); });
img("s10-boss.png", "Boss wave 5, boss_splitter, yang membelah diri saat HP-nya turun.").forEach(function (x) { children.push(x); });
img("s11-kartu-info.png", "Kartu info malware yang muncul setelah boss dikalahkan.").forEach(function (x) { children.push(x); });
img("s12-leaderboard.png", "Papan leaderboard wave tertinggi di lobby.").forEach(function (x) { children.push(x); });
img("s13-hasil.png", "Layar hasil akhir match beserta reward yang disimpan.").forEach(function (x) { children.push(x); });


// ---- LAMPIRAN A
children.push(h1("Lampiran A  Status verifikasi proyek"));
children.push(p(
  "Lampiran ini ada supaya laporan tidak terbaca lebih meyakinkan daripada keadaan " +
  "sebenarnya. Proyek ini diuji berlapis, dan tiap lapis membuktikan hal yang berbeda."));
children.push(table(
  ["Lapis pengujian", "Yang dicakup", "Hasil"],
  [
    ["Unit test murni", "Modul murni di src/shared/Modules: aturan toko, balance, boss, hit test, lane, match, progresi, rate limit, papan wave tertinggi",
      { t: "277 test lulus", color: GREEN, bold: true }],
    ["CI (lint, type check, build, test)", "Seluruh repo, dijalankan tiap push",
      { t: "Hijau di main", color: GREEN, bold: true }],
    ["Harness Studio", "Boot server, spawn musuh, penolakan remote, HP dan warna Core, urutan waypoint, pembagian lane, skala HP per wave",
      { t: "257 assertion lulus, 0 gagal, 22 di-skip", color: GREEN, bold: true }],
    ["Playtest manusia", "Semua yang butuh pemain sungguhan: menyerang, bar HP, kamera, input",
      { t: "Belum dijalankan", color: WARN, bold: true }],
  ],
  [2100, 4700, 2838]));
children.push(spacer(140));
children.push(p(
  "Lapis keempat belum dijalankan, dan itu bukan kelalaian melainkan batas alat. Harness " +
  "Studio menjalankan script di dalam place, tapi tidak ada Player yang pernah join — " +
  "pemanggilan CreateLocalPlayer gagal dengan pesan lacking capability LocalUser. Akibatnya " +
  "semua yang membutuhkan karakter, Humanoid, input, atau HUD tidak bisa diotomatisasi sama " +
  "sekali."));
children.push(note(
  "Konsekuensinya untuk laporan ini: semua screenshot pada Lampiran B harus diambil manual " +
  "dengan menjalankan game di Roblox Studio. Satu catatan tambahan untuk screenshot papan " +
  "leaderboard — OrderedDataStore tidak berfungsi sama sekali di place yang belum pernah " +
  "di-publish, jadi gambar itu baru bisa diambil setelah place dipublikasikan.",
  BLUE));


// ---- LAMPIRAN B
children.push(h1("Lampiran B  Daftar screenshot"));
children.push(p(
  "Tiap gambar di laporan ini yang berasal dari dalam game punya nama file tetap di folder " +
  "laporan/img. Untuk menggantinya, timpa file dengan nama yang sama, lalu bangun ulang " +
  "laporan — gambar akan ikut terbarui di tempatnya tanpa perlu menyunting dokumen."));
const SHOTS = [
  ["s01-lobby-ready", "Panel lobby: senjata, kesulitan, tombol Ready", "Tekan F5; panel muncul sendiri di state Lobby", "7"],
  ["s02-idle", "Karakter berdiri diam, tampak seluruh badan", "Jangan sentuh tombol gerak; putar kamera ke samping", "1"],
  ["s03-run", "Karakter sedang berlari", "Tahan W sambil memotret; kaki harus terlihat melangkah", "1"],
  ["s04-jump", "Karakter melompat, kaki di udara", "Tekan Space, potret saat masih naik", "1"],
  ["s05-skybox", "Langit dan dinding arena", "Arahkan kamera ke atas horizon sampai langit mengisi layar", "2"],
  ["s06-arena", "Arena tampak luas: Core, dua lane, dinding", "Scroll mundur sejauh mungkin, lihat dari atas-belakang Core", "3"],
  ["s07-kamera", "Karakter di dua posisi, tetap di tengah layar", "Dua potret di tempat berbeda, lalu gabungkan berdampingan", "6"],
  ["s08-hud", "HUD: HP Core, wave, timer, cash", "Potret di tengah wave 1 saat musuh berjalan", "7"],
  ["s09-toko", "Toko Match saat jeda antar wave", "Muncul di state Intermission, 20 detik setelah wave selesai", "7"],
  ["s10-boss", "Boss wave 5 di arena", "Bertahan sampai wave 5; potret sebelum boss membelah", "7"],
  ["s11-kartu-info", "Kartu info malware", "Muncul otomatis sesudah boss mati, lalu hilang sendiri", "7"],
  ["s12-leaderboard", "Papan wave tertinggi di lobby", "Butuh place yang sudah di-publish", "7"],
  ["s13-hasil", "Layar hasil akhir match", "Muncul di state Ended, bertahan 10 detik", "7"],
];
children.push(table(
  ["No", "Nama file", "Yang difoto", "Cara mendapatkannya", "Bab"],
  SHOTS.map(function (s, i) {
    return [
      String(i + 1),
      { t: s[0] + ".png", mono: true },
      s[1],
      s[2],
      s[3],
    ];
  }),
  [500, 2100, 2900, 3538, 500]));
children.push(spacer(160));
children.push(note(
  "Selama sebuah file belum diganti, tempatnya di laporan diisi kotak penanda bertuliskan " +
  "BELUM ADA SCREENSHOT beserta petunjuk pengambilannya. Jadi setiap gambar yang belum " +
  "terpasang akan terlihat jelas, tidak hilang diam-diam.", BLUE));

// ---------------------------------------------------------------- dokumen
const doc = new Document({
  creator: "Daffa",
  title: "Laporan Tugas - CodeVerse",
  description: "Laporan tugas game 2D dipetakan ke proyek Roblox CodeVerse",
  // Dipatok eksplisit supaya hasilnya sama di mesin mana pun, bukan ikut
  // default bawaan pustaka.
  styles: {
    default: {
      document: { run: { font: "Times New Roman", size: 22, color: INK } },
    },
  },
  numbering: {
    config: [{
      reference: "bullets",
      levels: [{
        level: 0, format: LevelFormat.BULLET, text: "\u2022",
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 460, hanging: 240 } } },
      }],
    }],
  },
  sections: [{
    properties: {
      page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [new TextRun({
            children: ["Laporan Tugas CodeVerse  |  ", PageNumber.CURRENT],
            size: 18, color: MUTED,
          })],
        })],
      }),
    },
    children: children,
  }],
});

Packer.toBuffer(doc).then(function (buf) {
  fs.writeFileSync(OUT, buf);
  console.log("tulis " + OUT);
  console.log("ukuran " + (buf.length / 1024).toFixed(0) + " KB, " + figNo + " gambar");
});
