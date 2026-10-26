# -*- coding: utf-8 -*-
"""Diagram untuk laporan tugas CodeVerse.

Semua angka geometri di sini dibaca dari scripts/build_arena.luau dan
src/ (MatchService, Waves, Balance) — bukan ditebak.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = r"C:\Web Program\roblox-codeverse\laporan\img"

FONT_REG = r"C:\Windows\Fonts\arial.ttf"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"
FONT_MONO = r"C:\Windows\Fonts\consola.ttf"

WHITE = (255, 255, 255)
INK = (28, 32, 38)
MUTED = (112, 120, 130)
HAIR = (205, 212, 220)
BOXF = (243, 246, 250)
BOXL = (186, 195, 206)
BLUE = (85, 160, 230)
BLUE_D = (38, 96, 150)
LANE1 = (205, 140, 60)
LANE2 = (90, 190, 140)
FLOOR = (72, 78, 88)
WALL = (52, 57, 66)
COREB = (60, 65, 75)
WAYP = (255, 240, 90)
SPAWN = (120, 200, 255)
WARN = (200, 80, 70)


class D(object):
    """Kanvas dengan supersampling: semua koordinat dalam satuan logis."""

    def __init__(self, w, h, ss=2, bg=WHITE):
        self.ss = ss
        self.w = w
        self.h = h
        self.img = Image.new("RGB", (w * ss, h * ss), bg)
        self.d = ImageDraw.Draw(self.img)

    def f(self, size, bold=False, mono=False):
        path = FONT_MONO if mono else (FONT_BOLD if bold else FONT_REG)
        return ImageFont.truetype(path, max(1, int(round(size * self.ss))))

    def _s(self, pts):
        return [(x * self.ss, y * self.ss) for (x, y) in pts]

    def rect(self, x, y, w, h, fill=None, outline=None, width=1, radius=0):
        box = [x * self.ss, y * self.ss, (x + w) * self.ss, (y + h) * self.ss]
        if radius:
            self.d.rounded_rectangle(
                box, radius=radius * self.ss, fill=fill, outline=outline,
                width=max(1, int(width * self.ss)))
        else:
            self.d.rectangle(box, fill=fill, outline=outline,
                             width=max(1, int(width * self.ss)))

    def poly(self, pts, fill=None, outline=None, width=1):
        self.d.polygon(self._s(pts), fill=fill, outline=outline)
        if outline and width > 1:
            self.d.line(self._s(pts) + [self._s(pts)[0]], fill=outline,
                        width=max(1, int(width * self.ss)))

    def line(self, pts, fill=INK, width=1):
        self.d.line(self._s(pts), fill=fill, width=max(1, int(width * self.ss)))

    def dash(self, p1, p2, fill=INK, width=2, on=9, off=7):
        x1, y1 = p1
        x2, y2 = p2
        total = math.hypot(x2 - x1, y2 - y1)
        if total < 1e-6:
            return
        ux, uy = (x2 - x1) / total, (y2 - y1) / total
        t = 0.0
        while t < total:
            e = min(t + on, total)
            self.line([(x1 + ux * t, y1 + uy * t), (x1 + ux * e, y1 + uy * e)],
                      fill=fill, width=width)
            t = e + off

    def text(self, x, y, s, font, fill=INK, anchor="lt"):
        self.d.text((x * self.ss, y * self.ss), s, font=font, fill=fill,
                    anchor=anchor)

    def arrow(self, p1, p2, fill=INK, width=2, head=9, dashed=False):
        x1, y1 = p1
        x2, y2 = p2
        ang = math.atan2(y2 - y1, x2 - x1)
        bx = x2 - math.cos(ang) * head * 0.9
        by = y2 - math.sin(ang) * head * 0.9
        if dashed:
            self.dash((x1, y1), (bx, by), fill=fill, width=width)
        else:
            self.line([(x1, y1), (bx, by)], fill=fill, width=width)
        left = (x2 - math.cos(ang - 0.42) * head, y2 - math.sin(ang - 0.42) * head)
        right = (x2 - math.cos(ang + 0.42) * head, y2 - math.sin(ang + 0.42) * head)
        self.poly([(x2, y2), left, right], fill=fill)

    def title(self, s, sub=None):
        self.text(self.w / 2.0, 34, s, self.f(33, bold=True), INK, "mm")
        if sub:
            self.text(self.w / 2.0, 72, sub, self.f(21), MUTED, "mm")

    def save(self, name):
        img = self.img.resize((self.w, self.h), Image.LANCZOS)
        path = os.path.join(OUT, name)
        img.save(path, "PNG")
        print("  tulis %s  (%dx%d)" % (name, self.w, self.h))


def box(c, x, y, w, h, label, sub=None, fill=BOXF, line=BOXL, label_size=17,
        label_color=INK, radius=9, lw=2):
    c.rect(x, y, w, h, fill=fill, outline=line, width=lw, radius=radius)
    if sub:
        c.text(x + w / 2.0, y + h / 2.0 - 10, label, c.f(label_size, bold=True),
               label_color, "mm")
        c.text(x + w / 2.0, y + h / 2.0 + 13, sub, c.f(13), MUTED, "mm")
    else:
        c.text(x + w / 2.0, y + h / 2.0, label, c.f(label_size, bold=True),
               label_color, "mm")


# ---------------------------------------------------------------- diagram 1
def arena():
    """Tampak atas arena. Angka dari scripts/build_arena.luau."""
    FLOOR_SIZE = 240.0
    WALL_T = 4.0
    CORE_BASE = 24.0
    CORE = 14.0
    WAYPOINTS = 7
    SPACING = 20.0
    CLEARANCE = 24.0
    LANE_W = 16.0
    SPAWN_OFF = 44.0
    SPAWN_SZ = 14.0
    LANES = [("Lane1", (-1.0, -1.0), LANE1), ("Lane2", (1.0, -1.0), LANE2)]

    W, H = 1180, 1130
    c = D(W, H)
    c.title("Layout arena CodeVerse, tampak atas",
            "digambar dari konstanta di scripts/build_arena.luau — satuan stud Roblox")

    scale = 3.75
    cx, cy = W / 2.0, 610.0

    def P(x, z):
        return (cx + x * scale, cy + z * scale)

    half = FLOOR_SIZE / 2.0
    # dinding (di luar lantai)
    wo = half + WALL_T / 2.0
    span = FLOOR_SIZE + WALL_T * 2
    for sz, oz in (((span, WALL_T), (0, -wo)), ((span, WALL_T), (0, wo)),
                   ((WALL_T, span), (-wo, 0)), ((WALL_T, span), (wo, 0))):
        x0, y0 = P(oz[0] - sz[0] / 2.0, oz[1] - sz[1] / 2.0)
        c.rect(x0, y0, sz[0] * scale, sz[1] * scale, fill=WALL)

    # lantai
    fx, fy = P(-half, -half)
    c.rect(fx, fy, FLOOR_SIZE * scale, FLOOR_SIZE * scale, fill=FLOOR)

    first = CLEARANCE + (WAYPOINTS - 1) * SPACING  # 144 stud

    # strip lane
    for name, d, col in LANES:
        n = math.hypot(d[0], d[1])
        ux, uz = d[0] / n, d[1] / n
        px, pz = -uz, ux  # tegak lurus
        hw = LANE_W / 2.0
        a = P(ux * first + px * hw, uz * first + pz * hw)
        b = P(ux * first - px * hw, uz * first - pz * hw)
        e = P(-px * hw, -pz * hw)
        f = P(px * hw, pz * hw)
        c.poly([a, b, e, f], fill=col)

    # spawn pemain
    sx, sy = P(-SPAWN_SZ / 2.0, SPAWN_OFF - SPAWN_SZ / 2.0)
    c.rect(sx, sy, SPAWN_SZ * scale, SPAWN_SZ * scale, fill=SPAWN)

    # Core
    bx, by = P(-CORE_BASE / 2.0, -CORE_BASE / 2.0)
    c.rect(bx, by, CORE_BASE * scale, CORE_BASE * scale, fill=COREB)
    kx, ky = P(-CORE / 2.0, -CORE / 2.0)
    c.rect(kx, ky, CORE * scale, CORE * scale, fill=BLUE)

    # waypoint
    fs = c.f(17, bold=True)
    for name, d, col in LANES:
        n = math.hypot(d[0], d[1])
        ux, uz = d[0] / n, d[1] / n
        for i in range(1, WAYPOINTS + 1):
            dist = CLEARANCE + (WAYPOINTS - i) * SPACING
            wx, wz = ux * dist, uz * dist
            p = P(wx, wz)
            r = 2.0 * scale + 6
            c.rect(p[0] - r, p[1] - r, r * 2, r * 2, fill=WAYP,
                   outline=(140, 125, 20), width=1)
            c.text(p[0], p[1], str(i), fs, (60, 55, 10), "mm")

    # label — semuanya ditaruh di lantai kosong, bukan di atas strip
    lf = c.f(28, bold=True)
    sf = c.f(21)
    l1 = P(-98, -16)
    c.text(l1[0], l1[1] - 15, "Lane1", lf, (240, 186, 120), "mm")
    c.text(l1[0], l1[1] + 15, "arah barat-laut", sf, (220, 180, 140), "mm")
    l2 = P(98, -16)
    c.text(l2[0], l2[1] - 15, "Lane2", lf, (152, 230, 190), "mm")
    c.text(l2[0], l2[1] + 15, "arah timur-laut", sf, (158, 215, 188), "mm")

    pk = P(0, 26)
    c.text(pk[0], pk[1], "Core Server", lf, WHITE, "mm")
    c.text(pk[0], pk[1] + 31, "HP 1000 — PrimaryPart", sf, (200, 214, 230), "mm")
    ps = P(0, SPAWN_OFF)
    c.text(ps[0], ps[1] + 48, "PlayerSpawn", lf, (235, 240, 245), "mm")

    # ukuran lantai — ditulis di dalam lantai
    c.text(P(0, 106)[0], P(0, 106)[1], "lantai 240 x 240 stud, dinding tinggi 20 stud",
           c.f(22), (176, 184, 196), "mm")

    # jarak waypoint 1 -> core
    p1 = P(-0.7071 * first, -0.7071 * first)
    pc = P(0, 0)
    c.dash(p1, pc, (235, 240, 248), 2, 7, 6)
    lbl = P(-102, -60)
    c.text(lbl[0], lbl[1], "144 stud", c.f(24, bold=True), WHITE, "mm")

    # arah utara
    nx, ny = W - 80, 162
    c.arrow((nx, ny + 46), (nx, ny), MUTED, 2, 11)
    c.text(nx, ny - 20, "U", c.f(24, bold=True), MUTED, "mm")
    c.text(nx, ny + 64, "-Z", c.f(18), MUTED, "mm")

    # Keterangan tidak digambar di sini: isinya ada sebagai tabel Word di Bab 3,
    # di mana teksnya tetap terbaca berapa pun ukuran cetaknya.
    c.text(cx, H - 28, "Kotak kuning bernomor adalah waypoint; tidak terlihat saat bermain.",
           c.f(21), MUTED, "mm")

    c.save("01-arena-layout.png")


# ---------------------------------------------------------------- diagram 2
def states():
    # Durasi tiap state TIDAK digambar di sini: ada sebagai tabel Word di Bab 7.
    W, H = 1420, 600
    c = D(W, H)
    c.title("State machine satu match",
            "enam state di MatchService.luau — hanya MatchService yang boleh mengubahnya")

    bw, bh = 240, 84
    y1 = 168
    gap = 45
    xs = []
    x = (W - (bw * 5 + gap * 4)) / 2.0
    for i in range(5):
        xs.append(x)
        x += bw + gap
    names = ["Lobby", "Loadout", "Countdown", "WaveActive", "Intermission"]
    for i, nm in enumerate(names):
        hi = nm == "WaveActive"
        box(c, xs[i], y1, bw, bh, nm,
            fill=(225, 240, 252) if hi else BOXF,
            line=BLUE if hi else BOXL, lw=3 if hi else 2, label_size=28)
        if i < 4:
            c.arrow((xs[i] + bw, y1 + bh / 2.0), (xs[i + 1] - 6, y1 + bh / 2.0),
                    INK, 3, 13)

    # Intermission -> WaveActive (loop di atas)
    ytop = y1 - 52
    c.line([(xs[4] + bw / 2.0, y1), (xs[4] + bw / 2.0, ytop)], BLUE_D, 3)
    c.line([(xs[4] + bw / 2.0, ytop), (xs[3] + bw / 2.0, ytop)], BLUE_D, 3)
    c.arrow((xs[3] + bw / 2.0, ytop), (xs[3] + bw / 2.0, y1 - 6), BLUE_D, 3, 13)
    c.text((xs[3] + xs[4]) / 2.0 + bw / 2.0, ytop - 22,
           "wave berikutnya, sampai wave 10", c.f(23, bold=True), BLUE_D, "mm")

    # Ended
    ye = 384
    box(c, xs[3], ye, bw, bh, "Ended", fill=(252, 236, 234), line=WARN, lw=3,
        label_size=28)
    c.arrow((xs[3] + bw / 2.0 - 46, y1 + bh), (xs[3] + bw / 2.0 - 46, ye - 6), WARN, 3, 13)
    c.text(xs[3] + bw / 2.0 - 58, (y1 + bh + ye) / 2.0, "Core habis",
           c.f(22, bold=True), WARN, "rm")
    c.text(xs[3] + bw / 2.0 - 58, (y1 + bh + ye) / 2.0 + 26, "= kalah",
           c.f(22, bold=True), WARN, "rm")
    c.arrow((xs[4] + bw / 2.0, y1 + bh), (xs[3] + bw - 8, ye + 18), (70, 140, 90), 3, 13)
    # Rata kanan ke tepi kanvas: rata kiri dari panah membuat teksnya terpotong.
    c.text(W - 24, (y1 + bh + ye) / 2.0, "wave 10 selesai",
           c.f(22, bold=True), (50, 120, 72), "rm")
    c.text(W - 24, (y1 + bh + ye) / 2.0 + 26, "= menang",
           c.f(22, bold=True), (50, 120, 72), "rm")

    # Ended -> Lobby
    yb = ye + bh + 52
    c.line([(xs[3] + bw / 2.0, ye + bh), (xs[3] + bw / 2.0, yb)], INK, 3)
    c.line([(xs[3] + bw / 2.0, yb), (xs[0] + bw / 2.0, yb)], INK, 3)
    c.arrow((xs[0] + bw / 2.0, yb), (xs[0] + bw / 2.0, y1 + bh + 6), INK, 3, 13)
    c.text((xs[0] + xs[3]) / 2.0 + bw / 2.0, yb + 24,
           "reward disimpan, pemain kembali ke lobby", c.f(23, bold=True), INK, "mm")

    c.save("02-state-machine.png")


# ---------------------------------------------------------------- diagram 3
def gamifikasi():
    # Keempat elemen gamifikasi TIDAK digambar di sini: ada sebagai tabel Word
    # di Bab 7, lengkap dengan nama file yang mewujudkannya.
    W, H = 1100, 706
    c = D(W, H)
    c.title("Core loop CodeVerse",
            "satu putaran penuh, dari lobby sampai kembali ke lobby")

    bw, bh = 300, 110
    gap = 40
    xs = [60, 400, 740]
    yr1, yr2 = 142, 326
    steps = [
        (xs[0], yr1, "Lobby", "pilih senjata & kesulitan", False),
        (xs[1], yr1, "Match", "10 wave", False),
        (xs[2], yr1, "Boss", "wave 5 & 10", True),
        (xs[2], yr2, "Kartu info", "edukasi malware", True),
        (xs[1], yr2, "Reward", "koin, XP, material", False),
        (xs[0], yr2, "Upgrade & Craft", "progres permanen", False),
    ]
    for (x, y, nm, sub, hi) in steps:
        box(c, x, y, bw, bh, nm, sub,
            fill=(255, 246, 230) if hi else (225, 240, 252),
            line=(225, 160, 60) if hi else BLUE, lw=3, label_size=28)

    # baris 1 ke kanan
    c.arrow((xs[0] + bw, yr1 + bh / 2.0), (xs[1] - 8, yr1 + bh / 2.0), INK, 3, 14)
    c.arrow((xs[1] + bw, yr1 + bh / 2.0), (xs[2] - 8, yr1 + bh / 2.0), INK, 3, 14)
    # turun ke baris 2
    c.arrow((xs[2] + bw / 2.0, yr1 + bh), (xs[2] + bw / 2.0, yr2 - 8), INK, 3, 14)
    # baris 2 ke kiri
    c.arrow((xs[2] - 8, yr2 + bh / 2.0), (xs[1] + bw + 8, yr2 + bh / 2.0), INK, 3, 14)
    c.arrow((xs[1] - 8, yr2 + bh / 2.0), (xs[0] + bw + 8, yr2 + bh / 2.0), INK, 3, 14)
    # menutup putaran
    c.arrow((xs[0] + bw / 2.0, yr2 - 8), (xs[0] + bw / 2.0, yr1 + bh + 8), BLUE_D, 3, 14)
    # Label ditaruh di KANAN panah, di lorong kosong antara kedua baris: di kiri
    # panah tidak cukup ruang sampai tepi kanvas dan teksnya terpotong.
    c.text(xs[0] + bw / 2.0 + 18, (yr1 + bh + yr2) / 2.0 - 13, "menang di Normal",
           c.f(21, bold=True), BLUE_D, "lm")
    c.text(xs[0] + bw / 2.0 + 18, (yr1 + bh + yr2) / 2.0 + 13, "membuka tingkat Hard",
           c.f(21, bold=True), BLUE_D, "lm")

    # lifecycle pemain
    ny = 500
    nw = 980
    c.rect(60, ny, nw, 166, fill=(248, 250, 252), outline=HAIR, width=3, radius=12)
    c.text(84, ny + 30, "Lifecycle pemain (docs/CONCEPT.md)",
           c.f(25, bold=True), INK, "lm")
    phases = [
        ("Onboarding", ["tutorial teks +", "wave awal ringan"]),
        ("Scaffolding", ["grinding koin,", "boss pertama wave 5"]),
        ("Mastery", ["tingkat Hard, craft", "senjata, leaderboard"]),
    ]
    px = 84
    for i, (nm, subs) in enumerate(phases):
        c.text(px, ny + 76, nm, c.f(23, bold=True), BLUE_D, "lt")
        c.text(px, ny + 106, subs[0], c.f(19), MUTED, "lt")
        c.text(px, ny + 130, subs[1], c.f(19), MUTED, "lt")
        if i < 2:
            c.arrow((px + 258, ny + 96), (px + 294, ny + 96), MUTED, 3, 11)
        px += 320

    c.save("03-gamifikasi.png")


# ---------------------------------------------------------------- diagram 4
def kamera():
    W, H = 1400, 790
    c = D(W, H)
    c.title("Sistem kamera dan bidikan",
            "kamera default Roblox mengikuti karakter; bidikan memakai raycast dari kamera")

    ground = 548
    c.line([(60, ground), (W - 60, ground)], (150, 158, 168), 3)
    c.text(72, ground + 16, "lantai arena", c.f(19), MUTED, "lt")

    # karakter
    chx, chy = 430, ground
    c.rect(chx - 17, chy - 90, 34, 56, fill=BLUE, outline=BLUE_D, width=2, radius=8)
    c.d.ellipse([(chx - 17) * c.ss, (chy - 124) * c.ss,
                 (chx + 17) * c.ss, (chy - 92) * c.ss],
                fill=(246, 206, 160), outline=BLUE_D, width=2 * c.ss)
    c.line([(chx - 14, chy - 34), (chx - 14, chy)], BLUE_D, 6)
    c.line([(chx + 14, chy - 34), (chx + 14, chy)], BLUE_D, 6)
    c.text(chx, chy + 28, "karakter pemain", c.f(22, bold=True), INK, "mm")
    c.text(chx, chy + 54, "HumanoidRootPart", c.f(17, mono=True), MUTED, "mm")

    # kamera
    cmx, cmy = 176, 212
    c.rect(cmx - 66, cmy - 40, 132, 80, fill=(238, 242, 248), outline=INK,
           width=3, radius=9)
    c.poly([(cmx + 66, cmy - 18), (cmx + 104, cmy - 40), (cmx + 104, cmy + 40),
            (cmx + 66, cmy + 18)], fill=(238, 242, 248), outline=INK, width=3)
    c.text(cmx, cmy, "Camera", c.f(26, bold=True), INK, "mm")
    c.text(cmx - 66, cmy + 60, "Workspace.CurrentCamera", c.f(18, mono=True), MUTED, "lt")

    # kamera mengikuti karakter
    c.arrow((cmx + 24, cmy + 48), (chx - 34, chy - 102), (70, 150, 110), 3, 12, dashed=True)
    c.text(96, 368, "kamera mengikuti karakter", c.f(22, bold=True), (50, 120, 72), "lt")
    c.text(96, 396, "(di Unity, ini pekerjaan Cinemachine)",
           c.f(18), (80, 140, 105), "lt")

    # viewport + kursor
    vx = 700
    c.dash((vx, 148), (vx, 462), (170, 178, 190), 3, 9, 7)
    c.text(vx, 128, "bidang layar (viewport)", c.f(19, bold=True), MUTED, "mm")
    curx, cury = vx, 286
    c.poly([(curx, cury), (curx + 9, cury + 27), (curx + 14, cury + 16),
            (curx + 25, cury + 21)], fill=WARN, outline=WARN)
    c.text(curx + 34, cury + 2, "posisi mouse / tap", c.f(21, bold=True), WARN, "lt")
    c.text(curx + 34, cury + 28, "UserInputService:GetMouseLocation()",
           c.f(17, mono=True), MUTED, "lt")

    # ray kamera -> titik bidik
    hitx, hity = 1040, ground
    c.arrow((cmx + 108, cmy), (hitx, hity - 4), WARN, 3, 14)
    c.text(806, 400, "camera:ViewportPointToRay(x, y)", c.f(20, mono=True), WARN, "lm")
    c.text(806, 428, "Workspace:Raycast(...) mengabaikan karakter sendiri",
           c.f(17), MUTED, "lm")
    c.d.ellipse([(hitx - 10) * c.ss, (hity - 10) * c.ss,
                 (hitx + 10) * c.ss, (hity + 10) * c.ss], fill=WARN)
    c.text(hitx, hity + 28, "titik bidik di dunia", c.f(22, bold=True), WARN, "mm")

    # direction
    c.arrow((chx + 24, chy - 62), (hitx - 16, hity - 16), BLUE_D, 3, 14, dashed=True)
    c.text((chx + hitx) / 2.0 + 10, (chy - 62 + hity) / 2.0 - 30,
           "direction = titikBidik - posisiKarakter", c.f(23, bold=True), BLUE_D, "mm")

    # kirim ke server
    sy = 660
    c.rect(220, sy, 420, 74, fill=(225, 240, 252), outline=BLUE, width=3, radius=10)
    c.text(430, sy + 23, "Client", c.f(22, bold=True), BLUE_D, "mm")
    c.text(430, sy + 52, "Attack:FireServer(direction.Unit)", c.f(17, mono=True), INK, "mm")
    c.arrow((650, sy + 37), (742, sy + 37), INK, 3, 13)
    c.rect(752, sy, 420, 74, fill=(236, 246, 239), outline=(70, 150, 110), width=3, radius=10)
    c.text(962, sy + 23, "Server — CombatService", c.f(22, bold=True), (50, 120, 72), "mm")
    c.text(962, sy + 52, "memutuskan kena siapa dan berapa damage", c.f(17), INK, "mm")
    c.text(430, sy + 96, "client cuma mengirim ARAH, satu Vector3", c.f(18), MUTED, "mm")
    c.text(962, sy + 96, "target dan damage tidak pernah dipercaya dari client",
           c.f(18), MUTED, "mm")

    c.save("04-kamera-bidik.png")


# ---------------------------------------------------------------- diagram 5
def animasi():
    # Pemetaan tindakan -> state -> klip TIDAK digambar di sini: ada sebagai
    # tabel Word di Bab 5, supaya teksnya tetap terbaca saat dicetak.
    W, H = 1420, 318
    c = D(W, H)
    c.title("Dari input ke animasi",
            "rantai bawaan Roblox: tidak ada Animator Controller yang perlu disusun sendiri")

    bw, bh = 260, 92
    y1 = 126
    gap = 28
    chain = [
        ("Input", "WASD, Space, stick"),
        ("Humanoid", "MoveDirection, Jump"),
        ("HumanoidStateType", "Running, Jumping"),
        ("Animate", "LocalScript bawaan"),
        ("AnimationTrack", "klip yang diputar"),
    ]
    xs = []
    x = (W - (bw * 5 + gap * 4)) / 2.0
    for i in range(5):
        xs.append(x)
        x += bw + gap
    for i, (nm, sub) in enumerate(chain):
        box(c, xs[i], y1, bw, bh, nm, sub,
            fill=(225, 240, 252), line=BLUE, lw=3, label_size=24)
        if i < 4:
            c.arrow((xs[i] + bw, y1 + bh / 2.0), (xs[i + 1] - 6, y1 + bh / 2.0),
                    INK, 3, 13)
    c.text(W / 2.0, y1 + bh + 40,
           "Pemain menekan tombol, Humanoid berubah state, Animate mengganti klip. "
           "Sinkronisasinya otomatis.",
           c.f(22), MUTED, "mm")

    c.save("05-animasi.png")


# ------------------------------------------------- placeholder screenshot
SHOTS = [
    ("s01-lobby-ready", "Panel lobby: pilih senjata, pilih tingkat kesulitan, tombol Ready",
     "Tekan F5. Panel muncul sendiri saat state Lobby."),
    ("s02-idle", "Karakter berdiri diam (idle), tampak seluruh badan",
     "Jangan sentuh tombol gerak. Putar kamera ke samping karakter."),
    ("s03-run", "Karakter sedang berlari (run)",
     "Tahan W sambil memotret; kaki harus terlihat sedang melangkah."),
    ("s04-jump", "Karakter sedang melompat (jump), kaki di udara",
     "Tekan Space, potret saat masih naik."),
    ("s05-skybox", "Latar belakang arena: langit dan dinding",
     "Arahkan kamera ke atas horizon sampai langit mengisi layar."),
    ("s06-arena", "Arena tampak luas: Core di tengah, dua lane, dinding",
     "Scroll mundur sejauh mungkin, lihat dari atas-belakang Core."),
    ("s07-kamera", "Kamera mengikuti karakter: karakter di dua posisi berbeda",
     "Dua potret di tempat berbeda; karakter tetap di tengah layar."),
    ("s08-hud", "HUD saat wave berjalan: HP Core, nomor wave, timer, cash",
     "Potret di tengah wave 1, saat musuh sedang berjalan."),
    ("s09-toko", "Toko Match saat jeda antar wave",
     "Muncul sendiri di state Intermission, 20 detik setelah wave selesai."),
    ("s10-boss", "Boss wave 5 (boss_splitter) di arena",
     "Bertahan sampai wave 5. Potret sebelum boss membelah."),
    ("s11-kartu-info", "Kartu info malware setelah boss kalah",
     "Muncul otomatis sesudah boss mati, lalu hilang sendiri — siapkan jari."),
    ("s12-leaderboard", "Papan leaderboard wave tertinggi di lobby",
     "Perlu place yang sudah di-publish; OrderedDataStore tidak jalan di place lokal."),
    ("s13-hasil", "Layar hasil akhir match: reward, wave tercapai",
     "Muncul di state Ended, bertahan 10 detik."),
]


def placeholders():
    for i, (name, what, how) in enumerate(SHOTS, start=1):
        # JANGAN menimpa screenshot asli yang sudah dipasang.
        if os.path.exists(os.path.join(OUT, "%s.png" % name)):
            print("  lewati %s.png (sudah ada)" % name)
            continue
        W, H = 1280, 720
        c = D(W, H, bg=(247, 249, 251))
        c.rect(14, 14, W - 28, H - 28, fill=(247, 249, 251), outline=None)
        # bingkai putus-putus
        for (p1, p2) in (((14, 14), (W - 14, 14)), ((W - 14, 14), (W - 14, H - 14)),
                         ((W - 14, H - 14), (14, H - 14)), ((14, H - 14), (14, 14))):
            c.dash(p1, p2, (178, 188, 200), 3, 16, 12)
        c.text(W / 2.0, 250, "S%02d" % i, c.f(78, bold=True), (206, 215, 225), "mm")
        c.text(W / 2.0, 330, "BELUM ADA SCREENSHOT", c.f(26, bold=True), (150, 160, 174), "mm")
        c.text(W / 2.0, 392, what, c.f(21, bold=True), INK, "mm")
        c.text(W / 2.0, 428, how, c.f(17), MUTED, "mm")
        c.text(W / 2.0, 500, "Ganti file ini dengan screenshot asli, nama file tetap sama:",
               c.f(15), MUTED, "mm")
        c.text(W / 2.0, 528, "laporan/img/%s.png" % name, c.f(16, mono=True), BLUE_D, "mm")
        c.text(W / 2.0, 578, "lalu jalankan ulang pembuatan laporan",
               c.f(14), (170, 178, 190), "mm")
        c.save("%s.png" % name)


if __name__ == "__main__":
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    print("Render diagram ke %s" % OUT)
    arena()
    states()
    gamifikasi()
    kamera()
    animasi()
    print("Placeholder screenshot:")
    placeholders()
    print("selesai.")
