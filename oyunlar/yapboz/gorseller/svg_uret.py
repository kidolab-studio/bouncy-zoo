# Yapboz SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: python svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Stil ve yardımcılar Hayvanları Besle'nin svg_uret.py'sinden (oradan içe aktarılır, o dosyaya dokunulmaz):
# koyu mor hat, radyal gradyanlı parlak dolgular, beyaz parıltılar. Hayvanlar da Besle'deki çizimler.
#
# - resimler/<ad>.svg: yapboz resimleri, hepsi 1200x900 (4:3; ayarlar.gd PICTURE_SIZE). Her parçada ayırt
#   edici bir ayrıntı olsun diye resmin her yeri dolu: büyük düz alan bırakma (12 parçalık resimde her
#   300x300'lük hücre farklı görünmeli). Ad = ayarlar.gd PICTURES anahtarı.
# - kart_yapboz.svg: ana menü kartı ve final ekranının karakteri (gülen yapboz parçası).
# yildiz.svg, isilti.svg Hayvanları Besle'den kopya.
#
# Not: Godot'nun SVG çizicisi filtre (bulanıklık) çizmez; gölge ve ışık yarı saydam şekillerle yapılır.

import importlib.util
import math
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")

_spec = importlib.util.spec_from_file_location("besle_svg", os.path.join(GAMES, "hayvan_besle", "gorseller", "svg_uret.py"))
besle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(besle)

OUT = besle.OUT
radial, linear, ten, light, dark = besle.radial, besle.linear, besle.ten, besle.light, besle.dark
W, H = 1200, 900
SW = 6  # resimlerde hat kalınlığı (parça tahtada ~0,6 ölçekle görünür)


def st(width: float = SW) -> str:
    return besle.st(width)


def shine(x: float, y: float, rx: float = 18, ry: float = 8, angle: float = -25, opacity: float = 0.8) -> str:
    return besle.shine(x, y, rx, ry, angle, opacity)


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


def prefixed(text: str, prefix: str) -> str:
    # Aynı çizim resimde birden çok kez kullanılınca gradyan adları çakışmasın
    text = re.sub(r'id="([\w-]+)"', lambda m: f'id="{prefix}{m.group(1)}"', text)
    return re.sub(r"url\(#([\w-]+)\)", lambda m: f"url(#{prefix}{m.group(1)})", text)


def at(body: str, x: float, y: float, s: float = 1.0, rot: float = 0.0, flip: bool = False) -> str:
    sx = -s if flip else s
    r = f" rotate({rot:g})" if rot else ""
    return f'  <g transform="translate({x:g} {y:g}){r} scale({sx:g} {s:g})">\n{body}  </g>\n'


class Pic:
    # Bir resmin defs ve gövdesini toplar; her öğe kendi benzersiz gradyan adını alır (uid)
    def __init__(self) -> None:
        self.defs = ""
        self.body = ""
        self._n = 0

    def uid(self, base: str) -> str:
        self._n += 1
        return f"{base}{self._n}"

    def add(self, body: str, defs: str = "") -> None:
        self.body += body
        self.defs += defs

    def save(self, name: str) -> None:
        write(f"resimler/{name}.svg", W, H, self.body, self.defs)


# --- Ortak parçalar ---

def face(name: str) -> str:
    # Besle'deki hayvan yüzü (gözler, yanaklar, gülen ağız)
    data = besle.FACES[name]
    y, dx, rx, ry = data["eye"]
    out = ""
    for x in (128 - dx, 128 + dx):
        if data.get("eye_white"):
            out += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{rx * 1.45:g}" ry="{ry * 1.45:g}" fill="#FFFFFF"/>\n'
        out += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{rx:g}" ry="{ry:g}" fill="url(#goz)"/>\n'
        out += f'  <ellipse cx="{x - rx * 0.35:g}" cy="{y - ry * 0.45:g}" rx="{rx * 0.42:g}" ry="{ry * 0.4:g}" fill="#FFFFFF"/>\n'
    cy, cdx = data["cheek"]
    out += "".join(f'  <ellipse cx="{x:g}" cy="{cy:g}" rx="17" ry="10" fill="url(#yanak)"/>\n' for x in (128 - cdx, 128 + cdx))
    my = data["mouth"][0]
    out += f'  <path d="M114 {my - 2} Q128 {my + 12} 142 {my - 2}" fill="none" {besle.st(6)}/>\n'
    return out


def animal(pic: Pic, name: str, x: float, y: float, s: float, flip: bool = False) -> None:
    # Besle'deki hayvan (256 tuval, ayakların altı y = 246): (x, y) ayakların ortası
    bd, b, hd, h = besle.ANIMALS[name]()
    p = pic.uid("h") + "_"
    defs = prefixed(bd + prefixed(hd, "k") + besle.EYE_DEFS, p)
    body = prefixed(b + prefixed(h, "k") + face(name), p)
    pic.add(at(body, x - (-128 if flip else 128) * s, y - 246 * s, s, flip=flip), defs)


def cloud(x: float, y: float, s: float, color: str = "#FFFFFF", edge: str = "#B9DDF4") -> str:
    shapes = "".join(f'<circle cx="{x + dx * s:g}" cy="{y + dy * s:g}" r="{r * s:g}"/>' for dx, dy, r in
                     ((-62, 10, 34), (-26, -14, 44), (22, -26, 50), (64, -2, 40), (90, 16, 28), (10, 18, 36), (-40, 22, 28)))
    base = f'<rect x="{x - 90 * s:g}" y="{y + 10 * s:g}" width="{180 * s:g}" height="{34 * s:g}" rx="{17 * s:g}"/>'
    return (f'  <g fill="{edge}" stroke="{edge}" stroke-width="{10 * s:g}">{shapes}{base}</g>\n'
            f'  <g fill="{color}">{shapes}{base}</g>\n'
            + shine(x - 10 * s, y - 34 * s, 22 * s, 8 * s, -10, 0.9))


def sun(pic: Pic, x: float, y: float, r: float) -> None:
    gid = pic.uid("gunes")
    defs = radial(gid, [(0, "#FFF6B0"), (0.6, "#FFD84A"), (1, "#FFB627")])
    body = ""
    for k in range(12):
        a = math.radians(k * 30 + 8)
        r1, r2 = r * 1.22, r * (1.62 if k % 2 == 0 else 1.45)
        body += (f'  <path d="M{x + r1 * math.cos(a):.1f} {y + r1 * math.sin(a):.1f} L{x + r2 * math.cos(a):.1f} {y + r2 * math.sin(a):.1f}" '
                 f'stroke="#FFC233" stroke-width="{r * 0.16:g}" stroke-linecap="round"/>\n')
    body += f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{gid})" {st()}/>\n'
    # Gülen yüz
    for dx in (-0.32, 0.32):
        body += f'  <ellipse cx="{x + dx * r:g}" cy="{y - 0.1 * r:g}" rx="{r * 0.09:g}" ry="{r * 0.13:g}" fill="{OUT}"/>\n'
    body += f'  <path d="M{x - r * 0.34:g} {y + r * 0.22:g} Q{x:g} {y + r * 0.56:g} {x + r * 0.34:g} {y + r * 0.22:g}" fill="none" {st(5)}/>\n'
    body += "".join(f'  <ellipse cx="{x + dx * r:g}" cy="{y + 0.22 * r:g}" rx="{r * 0.14:g}" ry="{r * 0.08:g}" fill="#FF8A5C" opacity="0.6"/>\n'
                    for dx in (-0.58, 0.58))
    body += shine(x - r * 0.45, y - r * 0.5, r * 0.22, r * 0.1, -35, 0.85)
    pic.add(body, defs)


def flower(x: float, y: float, s: float, petal: str, center: str = "#FFD23F", stem: bool = True) -> str:
    body = ""
    if stem:
        body += f'  <path d="M{x:g} {y:g} Q{x - 4 * s:g} {y + 22 * s:g} {x:g} {y + 44 * s:g}" fill="none" stroke="#4FA544" stroke-width="{5 * s:g}" stroke-linecap="round"/>\n'
        body += f'  <ellipse cx="{x + 9 * s:g}" cy="{y + 30 * s:g}" rx="{9 * s:g}" ry="{4 * s:g}" transform="rotate(-30 {x + 9 * s:g} {y + 30 * s:g})" fill="#5DBB4F"/>\n'
    for k in range(5):
        a = math.radians(k * 72 - 90)
        body += f'  <circle cx="{x + 11 * s * math.cos(a):.1f}" cy="{y + 11 * s * math.sin(a):.1f}" r="{9 * s:g}" fill="{petal}" stroke="{dark(petal, 0.35)}" stroke-width="{2.5 * s:g}"/>\n'
    body += f'  <circle cx="{x:g}" cy="{y:g}" r="{7 * s:g}" fill="{center}" stroke="{dark(center, 0.4)}" stroke-width="{2.5 * s:g}"/>\n'
    return body


def tuft(x: float, y: float, s: float, color: str = "#4FA544") -> str:
    d = f"M{x - 14 * s:g} {y:g} Q{x - 12 * s:g} {y - 18 * s:g} {x - 20 * s:g} {y - 30 * s:g} Q{x - 4 * s:g} {y - 18 * s:g} {x:g} {y:g} " \
        f"Q{x + 2 * s:g} {y - 26 * s:g} {x + 4 * s:g} {y - 38 * s:g} Q{x + 10 * s:g} {y - 20 * s:g} {x + 8 * s:g} {y:g} " \
        f"Q{x + 14 * s:g} {y - 16 * s:g} {x + 24 * s:g} {y - 24 * s:g} Q{x + 18 * s:g} {y - 10 * s:g} {x + 16 * s:g} {y:g} Z"
    return f'  <path d="{d}" fill="{color}"/>\n'


def butterfly(x: float, y: float, s: float, wing: str, wing2: str, rot: float = 0) -> str:
    body = ""
    for sx in (-1, 1):
        body += f'  <ellipse cx="{sx * 14:g}" cy="-8" rx="14" ry="17" transform="rotate({sx * 22})" fill="{wing}" {st(3.5)}/>\n'
        body += f'  <ellipse cx="{sx * 11:g}" cy="12" rx="9" ry="11" transform="rotate({-sx * 22})" fill="{wing2}" {st(3.5)}/>\n'
        body += f'  <circle cx="{sx * 15:g}" cy="-10" r="4.5" fill="#FFFFFF" opacity="0.75"/>\n'
    body += f'  <ellipse cx="0" cy="2" rx="4.5" ry="17" fill="{OUT}"/>\n'
    for sx in (-1, 1):
        body += f'  <path d="M0 -14 Q{sx * 5} -26 {sx * 11} -29" fill="none" {st(2.5)}/>\n'
    return at(body, x, y, s, rot)


def bird_v(x: float, y: float, s: float) -> str:
    # Uzakta uçan kuş (V)
    return f'  <path d="M{x - 16 * s:g} {y - 4 * s:g} Q{x - 8 * s:g} {y - 12 * s:g} {x:g} {y:g} Q{x + 8 * s:g} {y - 12 * s:g} {x + 16 * s:g} {y - 4 * s:g}" fill="none" {st(4 * s)}/>\n'


def tree(pic: Pic, x: float, y: float, s: float, fruit: str = "") -> None:
    # (x, y) gövdenin dibi
    g1, g2 = pic.uid("yaprak"), pic.uid("govde")
    defs = radial(g1, [(0, "#9BE36B"), (0.6, "#5DBB4F"), (1, "#3E9A41")], 0.4, 0.3, 0.8)
    defs += linear(g2, [(0, "#B9784A"), (1, "#8A5232")], 1, 0)
    body = f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{70 * s:g}" ry="{12 * s:g}" fill="#3A2A4A" opacity="0.15"/>\n'
    body += f'  <path d="M{x - 22 * s:g} {y:g} Q{x - 14 * s:g} {y - 80 * s:g} {x - 18 * s:g} {y - 150 * s:g} L{x + 18 * s:g} {y - 150 * s:g} Q{x + 14 * s:g} {y - 80 * s:g} {x + 22 * s:g} {y:g} Z" fill="url(#{g2})" {st()}/>\n'
    body += f'  <path d="M{x - 6 * s:g} {y - 40 * s:g} Q{x - 2 * s:g} {y - 60 * s:g} {x - 8 * s:g} {y - 80 * s:g}" fill="none" stroke="#7A4528" stroke-width="{4 * s:g}" stroke-linecap="round"/>\n'
    blobs = ((0, -230, 92), (-70, -185, 66), (70, -185, 66), (-44, -130, 58), (46, -130, 58), (0, -150, 70))
    shapes = "".join(f'<circle cx="{x + dx * s:g}" cy="{y + dy * s:g}" r="{r * s:g}"/>' for dx, dy, r in blobs)
    body += f'  <g fill="{OUT}" stroke="{OUT}" stroke-width="{SW * 2}">{shapes}</g>\n  <g fill="url(#{g1})">{shapes}</g>\n'
    for dx, dy, r in ((-30, -250, 26), (40, -200, 20), (-60, -160, 18)):
        body += f'  <circle cx="{x + dx * s:g}" cy="{y + dy * s:g}" r="{r * s:g}" fill="#B6EE8A" opacity="0.6"/>\n'
    if fruit:
        for dx, dy in ((-50, -210), (30, -255), (60, -160), (-20, -150), (10, -200), (-75, -150)):
            fx, fy = x + dx * s, y + dy * s
            body += f'  <circle cx="{fx:g}" cy="{fy:g}" r="{13 * s:g}" fill="{fruit}" {st(3.5)}/>\n'
            body += f'  <circle cx="{fx - 4 * s:g}" cy="{fy - 4 * s:g}" r="{4 * s:g}" fill="#FFFFFF" opacity="0.7"/>\n'
    pic.add(body, defs)


def fence(x0: float, x1: float, y: float, s: float = 1.0) -> str:
    # Beyaz tahta çit: (y) direklerin dibi
    body = ""
    for ry in (y - 70 * s, y - 34 * s):
        body += f'  <rect x="{x0:g}" y="{ry:g}" width="{x1 - x0:g}" height="{14 * s:g}" rx="{5 * s:g}" fill="#FFF8EC" {st(4)}/>\n'
    x = x0 + 20 * s
    while x < x1 - 10 * s:
        body += f'  <path d="M{x - 12 * s:g} {y:g} L{x - 12 * s:g} {y - 86 * s:g} L{x:g} {y - 100 * s:g} L{x + 12 * s:g} {y - 86 * s:g} L{x + 12 * s:g} {y:g} Z" fill="#FFFDF7" {st(4)}/>\n'
        body += f'  <rect x="{x - 8 * s:g}" y="{y - 84 * s:g}" width="{5 * s:g}" height="{70 * s:g}" fill="#FFFFFF" opacity="0.8"/>\n'
        x += 64 * s
    return body


# --- 1. Çiftlik (2x2) ---

def hen(x: float, y: float, s: float, flip: bool = False) -> str:
    # Tavuk; (x, y) ayakların dibi
    b = ""
    for dx in (-8, 8):
        b += f'  <path d="M{dx} -22 L{dx} 0 M{dx - 7} 0 L{dx + 7} 0" fill="none" stroke="#F09A2E" stroke-width="5" stroke-linecap="round"/>\n'
    b += f'  <path d="M-44 -62 Q-62 -86 -48 -98 Q-40 -80 -30 -76 Z" fill="#FFFFFF" {st(4)}/>\n'
    b += f'  <ellipse cx="-6" cy="-50" rx="42" ry="32" fill="#FFFFFF" {st(5)}/>\n'
    b += f'  <path d="M-22 -54 Q-4 -40 14 -54 Q2 -30 -18 -38 Z" fill="#EDE6F5" {st(3.5)}/>\n'
    b += f'  <circle cx="26" cy="-88" r="22" fill="#FFFFFF" {st(5)}/>\n'
    b += f'  <path d="M14 -106 Q16 -122 26 -112 Q30 -126 38 -110 Q46 -116 42 -102 Z" fill="#FF4F5E" {st(3.5)}/>\n'
    b += f'  <path d="M44 -92 L60 -86 L44 -80 Z" fill="#FFB43A" {st(3.5)}/>\n'
    b += f'  <path d="M40 -76 Q44 -66 38 -62 Q32 -68 36 -76 Z" fill="#FF4F5E"/>\n'
    b += f'  <circle cx="32" cy="-92" r="4" fill="{OUT}"/>\n'
    b += shine(-24, -66, 12, 5, -25, 0.9)
    return at(b, x, y, s, flip=flip)


def barn(pic: Pic, x: float, y: float, s: float) -> None:
    # Kırmızı ahır; (x, y) ön yüzün sol alt köşesi
    g1, g2 = pic.uid("ahir"), pic.uid("cati")
    defs = linear(g1, [(0, "#FF6B5E"), (1, "#D9413E")]) + linear(g2, [(0, "#9C3A4C"), (1, "#7A2B40")])
    w, h = 300 * s, 230 * s
    b = ""
    # Gövde ve çatı
    b += f'  <path d="M{x:g} {y:g} L{x:g} {y - h:g} L{x + w / 2:g} {y - h - 120 * s:g} L{x + w:g} {y - h:g} L{x + w:g} {y:g} Z" fill="url(#{g1})" {st()}/>\n'
    for k in range(1, 9):
        yy = y - k * h / 9
        b += f'  <path d="M{x + 6:g} {yy:g} L{x + w - 6:g} {yy:g}" stroke="#C23A3A" stroke-width="3" opacity="0.5"/>\n'
    b += f'  <path d="M{x - 26 * s:g} {y - h + 14 * s:g} L{x + w / 2:g} {y - h - 140 * s:g} L{x + w + 26 * s:g} {y - h + 14 * s:g} L{x + w + 6 * s:g} {y - h + 26 * s:g} L{x + w / 2:g} {y - h - 114 * s:g} L{x - 6 * s:g} {y - h + 26 * s:g} Z" fill="url(#{g2})" {st()}/>\n'
    # Saman kapağı
    hx, hy = x + w / 2, y - h - 30 * s
    b += f'  <path d="M{hx - 40 * s:g} {hy + 40 * s:g} L{hx - 40 * s:g} {hy - 8 * s:g} Q{hx:g} {hy - 46 * s:g} {hx + 40 * s:g} {hy - 8 * s:g} L{hx + 40 * s:g} {hy + 40 * s:g} Z" fill="#FFFDF5" {st(5)}/>\n'
    b += f'  <path d="M{hx - 30 * s:g} {hy + 40 * s:g} L{hx - 30 * s:g} {hy - 2 * s:g} Q{hx:g} {hy - 32 * s:g} {hx + 30 * s:g} {hy - 2 * s:g} L{hx + 30 * s:g} {hy + 40 * s:g} Z" fill="#F7C84A"/>\n'
    for dx in (-20, -6, 8, 20):
        b += f'  <path d="M{hx + dx * s:g} {hy + 40 * s:g} L{hx + (dx + 4) * s:g} {hy + 6 * s:g}" stroke="#D99A2A" stroke-width="3" stroke-linecap="round"/>\n'
    # Büyük kapılar
    dx0, dw, dh = x + 70 * s, 160 * s, 150 * s
    b += f'  <rect x="{dx0:g}" y="{y - dh:g}" width="{dw:g}" height="{dh:g}" fill="#FFFDF5" {st(5)}/>\n'
    for k in range(2):
        px = dx0 + 10 * s + k * dw / 2
        pw = dw / 2 - 20 * s
        b += f'  <rect x="{px:g}" y="{y - dh + 10 * s:g}" width="{pw:g}" height="{dh - 10 * s:g}" fill="#E8483F"/>\n'
        b += f'  <path d="M{px:g} {y - dh + 10 * s:g} L{px + pw:g} {y:g} M{px + pw:g} {y - dh + 10 * s:g} L{px:g} {y:g}" stroke="#FFFDF5" stroke-width="{9 * s:g}"/>\n'
    b += f'  <path d="M{dx0 + dw / 2:g} {y - dh:g} L{dx0 + dw / 2:g} {y:g}" {st(4)}/>\n'
    # Yan pencereler
    for wx in (x + 18 * s, x + w - 52 * s):
        b += f'  <rect x="{wx:g}" y="{y - h + 40 * s:g}" width="{34 * s:g}" height="{34 * s:g}" rx="4" fill="#BFE6FF" {st(4)}/>\n'
        b += f'  <path d="M{wx + 17 * s:g} {y - h + 40 * s:g} V{y - h + 74 * s:g} M{wx:g} {y - h + 57 * s:g} H{wx + 34 * s:g}" stroke="#FFFDF5" stroke-width="4"/>\n'
    b += shine(x + w * 0.22, y - h - 40 * s, 30 * s, 8 * s, -34, 0.55)
    pic.add(b, defs)


def silo(pic: Pic, x: float, y: float, s: float) -> None:
    g1 = pic.uid("silo")
    defs = linear(g1, [(0, "#C9D3E8"), (0.45, "#F4F7FF"), (1, "#9AA6C6")], 1, 0)
    w, h = 90 * s, 280 * s
    b = f'  <path d="M{x:g} {y:g} L{x:g} {y - h:g} Q{x + w / 2:g} {y - h - 70 * s:g} {x + w:g} {y - h:g} L{x + w:g} {y:g} Z" fill="url(#{g1})" {st()}/>\n'
    for k in range(1, 6):
        yy = y - k * h / 6
        b += f'  <path d="M{x:g} {yy:g} Q{x + w / 2:g} {yy + 10 * s:g} {x + w:g} {yy:g}" fill="none" stroke="#8C97B8" stroke-width="3"/>\n'
    b += f'  <path d="M{x:g} {y - h:g} Q{x + w / 2:g} {y - h - 70 * s:g} {x + w:g} {y - h:g} Q{x + w / 2:g} {y - h + 10 * s:g} {x:g} {y - h:g} Z" fill="#7A6FB0" {st(5)}/>\n'
    pic.add(b, defs)


def haystack(x: float, y: float, s: float) -> str:
    b = f'  <path d="M{x - 70 * s:g} {y:g} Q{x - 74 * s:g} {y - 80 * s:g} {x:g} {y - 100 * s:g} Q{x + 74 * s:g} {y - 80 * s:g} {x + 70 * s:g} {y:g} Z" fill="#F7C84A" {st(5)}/>\n'
    rng = random.Random(7)
    for k in range(14):
        hx = x + rng.uniform(-55, 55) * s
        hy = y - rng.uniform(10, 80) * s
        b += f'  <path d="M{hx:g} {hy:g} l{rng.uniform(-10, 10) * s:.1f} {-14 * s:g}" stroke="#D99A2A" stroke-width="3" stroke-linecap="round"/>\n'
    b += shine(x - 26 * s, y - 70 * s, 16 * s, 6 * s, -30, 0.7)
    return b


def farm() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#7CC8FF"), (0.6, "#C9ECFF"), (1, "#EAF8FF")])
    pic.defs += linear("tepe1", [(0, "#B6EA94"), (1, "#8ED36E")]) + linear("tepe2", [(0, "#9BDD72"), (1, "#6CBF54")])
    pic.defs += linear("cayir", [(0, "#8ED96A"), (1, "#5DB64C")])
    pic.defs += linear("yol", [(0, "#F0D3A0"), (1, "#E2B676")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    sun(pic, 140, 130, 66)
    pic.add(cloud(470, 120, 1.0) + cloud(1040, 90, 0.8) + cloud(760, 230, 0.55))
    pic.add(bird_v(620, 70, 1.0) + bird_v(670, 96, 0.8) + bird_v(320, 200, 0.7))
    # Uzak tepeler ve ağaçlar
    pic.add('  <path d="M0 470 Q200 380 420 450 Q640 360 880 440 Q1040 390 1200 430 L1200 620 L0 620 Z" fill="url(#tepe1)"/>\n')
    for tx, ty, ts in ((520, 440, 0.32), (580, 452, 0.26), (980, 432, 0.3)):
        tree(pic, tx, ty, ts)
    pic.add('  <path d="M0 540 Q300 470 600 530 Q900 480 1200 520 L1200 900 L0 900 Z" fill="url(#tepe2)"/>\n')
    # Ahır, silo, ağaç
    silo(pic, 1060, 610, 1.0)
    barn(pic, 740, 620, 1.0)
    tree(pic, 280, 600, 1.15, "#FF4F5E")
    # Çayır ve yol
    pic.add('  <path d="M0 600 Q600 570 1200 600 L1200 900 L0 900 Z" fill="url(#cayir)"/>\n')
    pic.add(f'  <path d="M820 620 Q860 700 760 780 Q690 840 720 900 L900 900 Q860 840 940 770 Q1020 690 960 620 Z" fill="url(#yol)" {st(5)}/>\n')
    pic.add(fence(0, 700, 690, 0.95))
    pic.add(haystack(1110, 720, 0.95))
    # Çiçekler ve ot
    rng = random.Random(3)
    colors = ["#FF6FA8", "#FFD23F", "#A46BFF", "#FF8A3D", "#FFFFFF", "#4A8FF0"]
    for k in range(26):
        fx, fy = rng.uniform(20, 1180), rng.uniform(720, 880)
        if 700 < fx < 960 and fy > 740:
            continue
        pic.add(tuft(fx + 18, fy + 44, 0.9))
        pic.add(flower(fx, fy, rng.uniform(0.8, 1.1), colors[k % len(colors)]))
    animal(pic, "inek", 520, 868, 1.75)
    pic.add(hen(150, 860, 0.95) + hen(1000, 880, 0.75, True))
    pic.add(butterfly(420, 540, 1.0, "#FF8FC8", "#FFB84D", -15) + butterfly(1130, 400, 0.8, "#7FD3FF", "#FFE066", 20))
    pic.save("ciftlik")


# --- 4. Deniz altı (3x2) ---

def eye(x: float, y: float, r: float, look: tuple = (0.15, 0.1)) -> str:
    # Beyaz göz, koyu bebek, parıltı
    px, py = x + look[0] * r, y + look[1] * r
    return (f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="#FFFFFF" {st(max(2.5, r * 0.22))}/>\n'
            f'  <circle cx="{px:g}" cy="{py:g}" r="{r * 0.58:g}" fill="#2A1F45"/>\n'
            f'  <circle cx="{px - r * 0.22:g}" cy="{py - r * 0.24:g}" r="{r * 0.22:g}" fill="#FFFFFF"/>\n')


def smile(x: float, y: float, w: float, width: float = 4) -> str:
    return f'  <path d="M{x - w:g} {y:g} Q{x:g} {y + w * 0.9:g} {x + w:g} {y:g}" fill="none" {st(width)}/>\n'


def tube(d: str, color: str, width: float, edge: float = SW) -> str:
    # Hatlı kalın çizgi (dal, dokunaç, yosun): önce koyu kalın, üstüne renkli ince
    return (f'  <path d="{d}" fill="none" stroke="{OUT}" stroke-width="{width + edge:g}" stroke-linecap="round" stroke-linejoin="round"/>\n'
            f'  <path d="{d}" fill="none" stroke="{color}" stroke-width="{width:g}" stroke-linecap="round" stroke-linejoin="round"/>\n')


def fish(pic: Pic, x: float, y: float, s: float, body: str, stripe: str, flip: bool = False) -> None:
    g1, clip = pic.uid("balik"), pic.uid("balikkes")
    defs = ten(g1, body)
    shape = "M-62 0 C-44 -50 40 -52 66 0 C40 52 -44 50 -62 0 Z"
    defs += f'    <clipPath id="{clip}"><path d="{shape}"/></clipPath>\n'
    b = f'  <path d="M-52 0 L-100 -40 Q-88 0 -100 40 Z" fill="{stripe}" {st(5)}/>\n'
    b += f'  <path d="M-20 -40 Q4 -78 34 -40 Z" fill="{stripe}" {st(5)}/>\n'
    b += f'  <path d="M-6 36 Q8 60 26 38 Z" fill="{stripe}" {st(4)}/>\n'
    b += f'  <path d="{shape}" fill="url(#{g1})"/>\n'
    b += f'  <g clip-path="url(#{clip})" fill="{stripe}">'
    b += '<path d="M-26 -60 Q-12 0 -26 60 L-10 60 Q4 0 -10 -60 Z"/><path d="M14 -60 Q28 0 14 60 L28 60 Q42 0 28 -60 Z"/></g>\n'
    b += f'  <path d="{shape}" fill="none" {st()}/>\n'
    b += eye(36, -10, 13)
    b += f'  <path d="M58 14 Q52 20 46 16" fill="none" {st(4)}/>\n'
    b += shine(-10, -26, 18, 6, -12, 0.8)
    pic.add(at(b, x, y, s, flip=flip), defs)


def turtle(pic: Pic, x: float, y: float, s: float) -> None:
    g1, g2 = pic.uid("kabuk"), pic.uid("deri")
    defs = ten(g1, "#5DBB4F") + ten(g2, "#A8E07A")
    b = ""
    for fx, fy, a in ((-60, -46, -35), (60, -50, 30), (-56, 42, 30), (54, 44, -30)):
        b += f'  <ellipse cx="{fx}" cy="{fy}" rx="34" ry="15" transform="rotate({a} {fx} {fy})" fill="url(#{g2})" {st(5)}/>\n'
    b += f'  <path d="M-92 0 L-112 -8 L-110 8 Z" fill="url(#{g2})" {st(4)}/>\n'
    b += f'  <circle cx="102" cy="-6" r="32" fill="url(#{g2})" {st()}/>\n'
    b += f'  <ellipse cx="0" cy="0" rx="92" ry="62" fill="url(#{g1})" {st()}/>\n'
    b += f'  <path d="M-30 -20 L0 -40 L30 -20 L30 14 L0 32 L-30 14 Z" fill="#7FD06A" {st(4)}/>\n'
    for px, py in ((-62, -10), (62, -10), (-40, 36), (40, 36), (-36, -46), (36, -46)):
        b += f'  <circle cx="{px}" cy="{py}" r="12" fill="#7FD06A" {st(3.5)}/>\n'
    b += eye(112, -14, 10)
    b += smile(114, 6, 10)
    b += f'  <ellipse cx="120" cy="2" rx="7" ry="4" fill="#FF8FA8" opacity="0.7"/>\n'
    b += shine(-36, -36, 22, 7, -15, 0.7)
    pic.add(at(b, x, y, s, -8), defs)


def jellyfish(pic: Pic, x: float, y: float, s: float, color: str) -> None:
    g1 = pic.uid("denizanasi")
    defs = radial(g1, [(0, light(color, 0.6)), (0.7, color), (1, dark(color, 0.15))], 0.4, 0.3, 0.8)
    b = ""
    for k, dx in enumerate((-36, -14, 8, 30)):
        d = f"M{dx} 20 Q{dx - 14} 60 {dx} 90 Q{dx + 14} 120 {dx - 4} 150"
        b += tube(d, light(color, 0.35), 8, 5)
    b += f'  <path d="M-62 24 Q-64 -60 0 -62 Q64 -60 62 24 Q46 34 31 24 Q16 34 0 24 Q-16 34 -31 24 Q-46 34 -62 24 Z" fill="url(#{g1})" {st()}/>\n'
    b += eye(-20, -8, 9) + eye(20, -8, 9)
    b += smile(0, 6, 9)
    b += shine(-30, -40, 14, 6, -30, 0.85)
    pic.add(at(b, x, y, s, 6), defs)


def crab(pic: Pic, x: float, y: float, s: float) -> None:
    g1 = pic.uid("yengec")
    defs = ten(g1, "#FF6B5E")
    b = ""
    for sx in (-1, 1):
        for k in range(3):
            b += tube(f"M{sx * 40} {4 + k * 12} Q{sx * 70} {k * 14 - 6} {sx * 84} {30 + k * 10}", "#FF6B5E", 8, 5)
        b += tube(f"M{sx * 44} -14 Q{sx * 70} -40 {sx * 72} -62", "#FF6B5E", 10, 5)
        # Kıskaç: büyük üst çene, küçük alt çene, arası açık
        b += f'  <path d="M{sx * 66} -58 Q{sx * 50} -96 {sx * 74} -112 Q{sx * 100} -122 {sx * 108} -98 Q{sx * 92} -100 {sx * 84} -86 Z" fill="url(#{g1})" {st(5)}/>\n'
        b += f'  <path d="M{sx * 70} -60 Q{sx * 96} -62 {sx * 104} -82 Q{sx * 90} -80 {sx * 82} -76 Z" fill="url(#{g1})" {st(5)}/>\n'
        b += tube(f"M{sx * 16} -30 L{sx * 20} -58", "#FF6B5E", 6, 4)
        b += eye(sx * 21, -64, 11, (0.0, -0.1))
    b += f'  <ellipse cx="0" cy="0" rx="56" ry="36" fill="url(#{g1})" {st()}/>\n'
    b += smile(0, 4, 14)
    b += "".join(f'  <circle cx="{dx}" cy="-14" r="4" fill="#FFB3A8"/>\n' for dx in (-30, -18, 18, 30))
    b += shine(-24, -18, 14, 5, -15, 0.75)
    pic.add(at(b, x, y, s), defs)


def octopus(pic: Pic, x: float, y: float, s: float) -> None:
    g1 = pic.uid("ahtapot")
    c = "#B07AE8"
    defs = ten(g1, c)
    b = ""
    arms = ((-70, -10, -120, 40, -104, 90, -70), (-50, 0, -88, 70, -40, 110, -10), (-24, 10, -34, 80, -16, 118, -30),
            (24, 10, 34, 80, 16, 118, 30), (50, 0, 90, 66, 60, 112, 20), (70, -10, 126, 30, 120, 86, 70))
    for x0, y0, x1, y1, x2, y2, curl in arms:
        d = f"M{x0} {y0} Q{x1} {y1} {x2} {y2} q{curl * 0.35:g} 18 {curl * 0.5:g} -6"
        b += tube(d, c, 24)
    for x0, y0, x1, y1, x2, y2, curl in arms:
        for t in (0.55, 0.75):
            px = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
            py = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
            b += f'  <circle cx="{px:.1f}" cy="{py:.1f}" r="4" fill="#F1D9FF"/>\n'
    b += f'  <path d="M-84 0 Q-92 -120 0 -124 Q92 -120 84 0 Q60 30 0 30 Q-60 30 -84 0 Z" fill="url(#{g1})" {st()}/>\n'
    for px, py, r in ((-40, -84, 10), (30, -96, 8), (52, -64, 7), (-58, -50, 6)):
        b += f'  <circle cx="{px}" cy="{py}" r="{r}" fill="{dark(c, 0.15)}" opacity="0.6"/>\n'
    b += eye(-28, -30, 18) + eye(28, -30, 18)
    b += f'  <path d="M-16 0 Q0 18 16 0 Q8 12 0 12 Q-8 12 -16 0 Z" fill="#8A2A4A" {st(4)}/>\n'
    b += "".join(f'  <ellipse cx="{dx}" cy="-4" rx="11" ry="6" fill="#FF8FC8" opacity="0.7"/>\n' for dx in (-52, 52))
    b += shine(-36, -100, 22, 8, -25, 0.85)
    pic.add(at(b, x, y, s), defs)


def seaweed(x: float, y: float, h: float, color: str, phase: float = 0) -> str:
    pts = []
    n = 8
    for k in range(n + 1):
        t = k / n
        pts.append((x + math.sin(t * 5 + phase) * 16 * t, y - h * t))
    d = "M" + " L".join(f"{px:.1f} {py:.1f}" for px, py in pts)
    out = tube(d, color, 22)
    for k in range(2, n, 2):
        px, py = pts[k]
        side = 1 if k % 4 == 0 else -1
        out += f'  <ellipse cx="{px + side * 20:.1f}" cy="{py:.1f}" rx="20" ry="9" transform="rotate({side * -30} {px + side * 20:.1f} {py:.1f})" fill="{light(color, 0.15)}" {st(4)}/>\n'
    return out


def coral(x: float, y: float, s: float, color: str) -> str:
    branches = ["M0 0 Q-6 -60 -40 -100 Q-52 -120 -48 -140", "M-24 -70 Q-70 -80 -86 -116",
                "M0 0 Q10 -80 4 -150", "M4 -96 Q40 -110 56 -150", "M8 -40 Q50 -50 74 -90", "M-38 -98 Q-20 -130 -14 -146"]
    out = ""
    for d in branches:
        out += tube(d, color, 22)
    for px, py in ((-48, -140), (-86, -116), (4, -150), (56, -150), (74, -90), (-14, -146)):
        out += f'  <circle cx="{px}" cy="{py}" r="8" fill="{light(color, 0.45)}"/>\n'
    return at(out, x, y, s)


def starfish(x: float, y: float, s: float, color: str, rot: float = 0) -> str:
    pts = []
    for k in range(10):
        r = 46 if k % 2 == 0 else 20
        a = math.radians(-90 + k * 36)
        pts.append(f"{r * math.cos(a):.1f},{r * math.sin(a):.1f}")
    b = f'  <polygon points="{" ".join(pts)}" fill="{color}" {st(5)}/>\n'
    for k in range(5):
        a = math.radians(-90 + k * 72)
        b += f'  <circle cx="{24 * math.cos(a):.1f}" cy="{24 * math.sin(a):.1f}" r="3.5" fill="{light(color, 0.5)}"/>\n'
    b += eye(-8, -4, 6, (0, 0)) + eye(8, -4, 6, (0, 0)) + smile(0, 6, 6, 3)
    return at(b, x, y, s, rot)


def shell(x: float, y: float, s: float, color: str) -> str:
    b = f'  <path d="M0 -30 Q34 -30 36 6 L-36 6 Q-34 -30 0 -30 Z" fill="{color}" {st(4)}/>\n'
    for k in (-24, -12, 0, 12, 24):
        b += f'  <path d="M0 -28 L{k} 6" stroke="{dark(color, 0.25)}" stroke-width="3"/>\n'
    b += f'  <rect x="-10" y="4" width="20" height="10" rx="4" fill="{color}" {st(4)}/>\n'
    return at(b, x, y, s)


def chest(pic: Pic, x: float, y: float, s: float) -> None:
    g1 = pic.uid("sandik")
    defs = linear(g1, [(0, "#C7864F"), (1, "#8E5532")])
    b = ""
    for k, (cx, cy) in enumerate(((-30, -86), (-6, -96), (18, -90), (36, -80), (-44, -76))):
        b += f'  <circle cx="{cx}" cy="{cy}" r="14" fill="#FFD23F" {st(4)}/>\n'
        b += f'  <circle cx="{cx - 4}" cy="{cy - 4}" r="4" fill="#FFFFFF" opacity="0.8"/>\n'
    b += f'  <path d="M-70 -70 Q-70 -120 0 -120 Q70 -120 70 -70 Z" fill="url(#{g1})" {st()}/>\n'
    b += f'  <rect x="-70" y="-74" width="140" height="74" rx="8" fill="url(#{g1})" {st()}/>\n'
    for dx in (-44, 44):
        b += f'  <rect x="{dx - 8}" y="-118" width="16" height="118" fill="#FFC233" {st(4)}/>\n'
    b += f'  <rect x="-14" y="-82" width="28" height="30" rx="5" fill="#FFC233" {st(4)}/>\n'
    b += f'  <circle cx="0" cy="-70" r="5" fill="{OUT}"/>\n'
    b += shine(-30, -104, 16, 5, -10, 0.6)
    pic.add(at(b, x, y, s, -6), defs)


def bubbles(rng: random.Random, n: int, area: tuple) -> str:
    x0, y0, x1, y1 = area
    out = ""
    for k in range(n):
        bx, by, r = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(6, 18)
        out += f'  <circle cx="{bx:.1f}" cy="{by:.1f}" r="{r:.1f}" fill="#FFFFFF" fill-opacity="0.25" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="3"/>\n'
        out += f'  <circle cx="{bx - r * 0.35:.1f}" cy="{by - r * 0.35:.1f}" r="{r * 0.25:.1f}" fill="#FFFFFF" opacity="0.9"/>\n'
    return out


def sea() -> None:
    pic = Pic()
    pic.defs += linear("su", [(0, "#7FE0F5"), (0.45, "#3DB2E8"), (1, "#1F78C8")])
    pic.defs += linear("kum", [(0, "#FFE4A8"), (1, "#F2C477")])
    pic.defs += linear("isik", [(0, "#FFFFFF"), (1, "#FFFFFF")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#su)"/>\n')
    # Yüzeyden gelen ışık huzmeleri
    for x0, w in ((120, 90), (420, 60), (640, 110), (980, 80)):
        pic.add(f'  <path d="M{x0} 0 L{x0 + w} 0 L{x0 + w + 200} 760 L{x0 + 120} 760 Z" fill="#FFFFFF" opacity="0.12"/>\n')
    pic.add('  <path d="M0 0 H1200 V34 Q1150 50 1100 34 Q1050 18 1000 34 Q950 50 900 34 Q850 18 800 34 Q750 50 700 34 Q650 18 600 34 '
            'Q550 50 500 34 Q450 18 400 34 Q350 50 300 34 Q250 18 200 34 Q150 50 100 34 Q50 18 0 34 Z" fill="#C8F4FF" opacity="0.8"/>\n')
    # Uzak kayalar
    pic.add('  <path d="M0 700 Q120 600 240 660 Q330 610 420 680 L420 800 L0 800 Z" fill="#2E8FC4" opacity="0.6"/>\n')
    pic.add('  <path d="M760 700 Q880 590 1000 650 Q1100 600 1200 640 L1200 800 L760 800 Z" fill="#2E8FC4" opacity="0.6"/>\n')
    # Kum
    pic.add(f'  <path d="M0 770 Q300 730 600 770 Q900 805 1200 760 L1200 900 L0 900 Z" fill="url(#kum)" {st()}/>\n')
    rng = random.Random(11)
    for k in range(30):
        pic.add(f'  <circle cx="{rng.uniform(10, 1190):.1f}" cy="{rng.uniform(800, 890):.1f}" r="{rng.uniform(2, 5):.1f}" fill="#D9A55A" opacity="0.7"/>\n')
    # Yosunlar ve mercanlar
    pic.add(seaweed(60, 800, 330, "#3FBF62", 0.0) + seaweed(130, 800, 240, "#2FA855", 1.4) + seaweed(1150, 790, 300, "#3FBF62", 2.2))
    pic.add(coral(960, 800, 1.2, "#FF7FA3") + coral(1080, 810, 0.85, "#FF9F40"))
    pic.add(seaweed(560, 790, 180, "#2FA855", 3.0) + seaweed(840, 795, 210, "#3FBF62", 0.6))
    # Taş ve ahtapot
    pic.add(f'  <ellipse cx="610" cy="800" rx="150" ry="50" fill="#8C97B8" {st()}/>\n' + shine(560, 778, 40, 10, -5, 0.5))
    octopus(pic, 610, 700, 1.15)
    crab(pic, 260, 820, 0.95)
    chest(pic, 1010, 880, 0.85)
    pic.add(shell(380, 870, 0.9, "#FFB3C6") + shell(760, 880, 0.8, "#FFE0A0") + shell(170, 880, 0.7, "#C9B3FF"))
    pic.add(starfish(470, 840, 0.95, "#FF9F40", 12) + starfish(860, 850, 0.8, "#FFD23F", -14))
    # Kabarcıklar (hayvanların arkasında: gözlerin üstüne binmesin), yüzen hayvanlar
    pic.add(bubbles(rng, 26, (20, 60, 1180, 700)))
    fish(pic, 210, 230, 1.25, "#FFD23F", "#FF8A3D")
    turtle(pic, 600, 200, 1.15)
    jellyfish(pic, 1040, 160, 0.95, "#FF8FC8")
    fish(pic, 930, 380, 0.7, "#7FD3FF", "#4A6FE0", True)
    fish(pic, 1060, 440, 0.6, "#A46BFF", "#FFD23F", True)
    fish(pic, 300, 470, 0.75, "#FF6B5E", "#FFFFFF")
    fish(pic, 760, 470, 0.55, "#5DD39E", "#FFF06A")
    pic.save("deniz")


# --- 7. Sıcak hava balonları (3x3) ---

def animal_head(pic: Pic, name: str, x: float, y: float, s: float) -> None:
    # Besle'deki hayvanın yalnızca kafası (yüzüyle); (x, y) kafanın ortası
    bd, b, hd, h = besle.ANIMALS[name]()
    p = pic.uid("k") + "_"
    pic.add(at(prefixed(h + face(name), p), x - 128 * s, y - 132 * s, s), prefixed(hd + besle.EYE_DEFS, p))


def balloon(pic: Pic, x: float, y: float, r: float, colors: list, passenger: str = "") -> None:
    # Sıcak hava balonu; (x, y) zarfın ortası, r yarıçap. colors: dilimlerin renkleri (dıştan içe)
    clip, gid = pic.uid("zarf"), pic.uid("parlak")
    shape = (f"M{x:g} {y - r:g} C{x + r * 1.02:g} {y - r:g} {x + r * 1.05:g} {y + r * 0.32:g} {x + r * 0.24:g} {y + r * 0.98:g} "
             f"L{x - r * 0.24:g} {y + r * 0.98:g} C{x - r * 1.05:g} {y + r * 0.32:g} {x - r * 1.02:g} {y - r:g} {x:g} {y - r:g} Z")
    defs = f'    <clipPath id="{clip}"><path d="{shape}"/></clipPath>\n'
    defs += radial(gid, [(0, "#FFFFFF"), (1, "#FFFFFF")])
    b = ""
    # İpler ve sepet
    by = y + r * 1.42
    for dx0, dx1 in ((-0.24, -0.2), (0.24, 0.2), (-0.08, -0.07), (0.08, 0.07)):
        b += f'  <path d="M{x + dx0 * r:g} {y + r * 0.96:g} L{x + dx1 * r:g} {by:g}" {st(3.5)}/>\n'
    if passenger:
        animal_head(pic, passenger, x, by - r * 0.2, r * 0.0042)
    bw, bh = r * 0.5, r * 0.36
    b2 = f'  <path d="M{x - bw / 2:g} {by:g} L{x + bw / 2:g} {by:g} L{x + bw * 0.42:g} {by + bh:g} L{x - bw * 0.42:g} {by + bh:g} Z" fill="#C7864F" {st(5)}/>\n'
    for k in range(1, 4):
        yy = by + k * bh / 4
        b2 += f'  <path d="M{x - bw * 0.46:g} {yy:g} L{x + bw * 0.46:g} {yy:g}" stroke="#8E5532" stroke-width="3"/>\n'
    for k in range(1, 5):
        xx = x - bw / 2 + k * bw / 5
        b2 += f'  <path d="M{xx:g} {by:g} L{xx + (x - xx) * 0.16:g} {by + bh:g}" stroke="#8E5532" stroke-width="3"/>\n'
    b2 += f'  <rect x="{x - bw * 0.56:g}" y="{by - 6:g}" width="{bw * 1.12:g}" height="12" rx="6" fill="#A86A3E" {st(4)}/>\n'
    # Zarf: dilimler iç içe elipslerle
    env = f'  <path d="{shape}" fill="{colors[0]}"/>\n  <g clip-path="url(#{clip})">\n'
    n = len(colors)
    for k in range(1, n):
        rx = r * (1 - k / n) * 1.04
        env += f'    <ellipse cx="{x:g}" cy="{y + r * 0.1:g}" rx="{rx:g}" ry="{r * 1.3:g}" fill="{colors[k]}"/>\n'
    env += f'    <path d="M{x - r * 1.2:g} {y + r * 0.56:g} L{x + r * 1.2:g} {y + r * 0.56:g} L{x + r * 1.2:g} {y + r * 0.72:g} L{x - r * 1.2:g} {y + r * 0.72:g} Z" fill="#FFFFFF" opacity="0.85"/>\n'
    for k in range(-6, 7):
        cx = x + k * r * 0.2
        env += f'    <circle cx="{cx:g}" cy="{y + r * 0.64:g}" r="{r * 0.045:g}" fill="{colors[1 % n]}"/>\n'
    env += f'    <ellipse cx="{x - r * 0.5:g}" cy="{y - r * 0.2:g}" rx="{r * 0.3:g}" ry="{r * 0.75:g}" fill="#FFFFFF" opacity="0.18"/>\n'
    env += '  </g>\n'
    env += f'  <path d="{shape}" fill="none" {st()}/>\n'
    env += f'  <rect x="{x - r * 0.27:g}" y="{y + r * 0.92:g}" width="{r * 0.54:g}" height="{r * 0.1:g}" rx="4" fill="{dark(colors[0], 0.2)}" {st(4)}/>\n'
    env += shine(x - r * 0.48, y - r * 0.55, r * 0.16, r * 0.07, -40, 0.85)
    pic.add(b + env, defs)
    # Sepet yolcunun önünde
    pic.add(b2)


def rainbow(cx: float, cy: float, r: float, width: float) -> str:
    out = ""
    for k, c in enumerate(["#FF5A6E", "#FF9F40", "#FFD23F", "#5CC95C", "#4FA8FF", "#A66BFF"]):
        rr = r - k * width
        out += f'  <path d="M{cx - rr:g} {cy:g} A{rr:g} {rr:g} 0 0 1 {cx + rr:g} {cy:g}" fill="none" stroke="{c}" stroke-width="{width + 0.5:g}" opacity="0.8"/>\n'
    return out


def house(pic: Pic, x: float, y: float, w: float, h: float, wall: str, roof: str, windows: int = 2, chimney: bool = False) -> None:
    # Ev; (x, y) ön yüzün sol alt köşesi
    g1 = pic.uid("duvar")
    defs = linear(g1, [(0, light(wall, 0.2)), (1, wall)])
    b = ""
    rh = w * 0.5
    if chimney:
        b += f'  <rect x="{x + w * 0.68:g}" y="{y - h - rh * 0.9:g}" width="{w * 0.12:g}" height="{rh * 0.6:g}" fill="#C76B5A" {st(4)}/>\n'
    b += f'  <rect x="{x:g}" y="{y - h:g}" width="{w:g}" height="{h:g}" fill="url(#{g1})" {st(5)}/>\n'
    b += f'  <path d="M{x - w * 0.1:g} {y - h + 2:g} L{x + w / 2:g} {y - h - rh:g} L{x + w * 1.1:g} {y - h + 2:g} Z" fill="{roof}" {st(5)}/>\n'
    b += f'  <path d="M{x + w * 0.1:g} {y - h - 6:g} L{x + w / 2:g} {y - h - rh + 14:g}" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.5"/>\n'
    dw = w * 0.24
    b += f'  <path d="M{x + w / 2 - dw / 2:g} {y:g} L{x + w / 2 - dw / 2:g} {y - h * 0.5:g} Q{x + w / 2:g} {y - h * 0.62:g} {x + w / 2 + dw / 2:g} {y - h * 0.5:g} L{x + w / 2 + dw / 2:g} {y:g} Z" fill="{dark(roof, 0.15)}" {st(4)}/>\n'
    b += f'  <circle cx="{x + w / 2 + dw * 0.25:g}" cy="{y - h * 0.24:g}" r="3" fill="#FFD23F"/>\n'
    ww = w * 0.2
    for k in range(windows):
        wx = x + w * 0.08 if k == 0 else x + w * 0.72
        b += f'  <rect x="{wx:g}" y="{y - h * 0.72:g}" width="{ww:g}" height="{ww:g}" rx="3" fill="#BFE6FF" {st(4)}/>\n'
        b += f'  <path d="M{wx + ww / 2:g} {y - h * 0.72:g} V{y - h * 0.72 + ww:g} M{wx:g} {y - h * 0.72 + ww / 2:g} H{wx + ww:g}" stroke="#FFFFFF" stroke-width="3"/>\n'
    pic.add(b, defs)


def windmill(x: float, y: float, s: float) -> str:
    b = f'  <path d="M-30 0 L-18 -120 L18 -120 L30 0 Z" fill="#FFF3DC" {st(5)}/>\n'
    b += f'  <path d="M-24 -116 L0 -146 L24 -116 Z" fill="#E8483F" {st(5)}/>\n'
    b += f'  <path d="M-9 0 L-9 -26 Q0 -36 9 -26 L9 0 Z" fill="#8E5532" {st(4)}/>\n'
    for a in (20, 110, 200, 290):
        b += f'  <g transform="translate(0 -112) rotate({a})"><rect x="-6" y="-92" width="12" height="88" fill="#FFFFFF" {st(4)}/>'
        b += f'<rect x="6" y="-88" width="22" height="70" fill="#BFE6FF" {st(3.5)}/></g>\n'
    b += f'  <circle cx="0" cy="-112" r="8" fill="#FFD23F" {st(4)}/>\n'
    return at(b, x, y, s)


def duck(x: float, y: float, s: float, flip: bool = False) -> str:
    # Suda yüzen ördek; (x, y) su çizgisi
    b = '  <ellipse cx="0" cy="2" rx="46" ry="8" fill="#FFFFFF" opacity="0.5"/>\n'
    b += f'  <path d="M-40 -6 Q-44 -34 -10 -34 L18 -34 Q26 -60 46 -56 Q64 -52 60 -34 Q58 -24 46 -20 Q44 0 20 0 L-30 0 Q-40 0 -40 -6 Z" fill="#FFE066" {st(4.5)}/>\n'
    b += '  <path d="M-30 -22 Q-10 -6 10 -22" fill="none" stroke="#F0B43A" stroke-width="4" stroke-linecap="round"/>\n'
    b += f'  <path d="M60 -42 L78 -38 L60 -32 Z" fill="#FF9F40" {st(3.5)}/>\n'
    b += f'  <circle cx="50" cy="-44" r="4" fill="{OUT}"/>\n'
    b += shine(-16, -26, 10, 4, -10, 0.8)
    return at(b, x, y, s, flip=flip)


def balloons() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#6FC2FF"), (0.55, "#BFE6FF"), (0.8, "#FFE7C8"), (1, "#FFD9A8")])
    pic.defs += linear("tepe1", [(0, "#C6EE9E"), (1, "#9DDB7A")]) + linear("tepe2", [(0, "#8ED96A"), (1, "#5DB64C")])
    pic.defs += linear("nehir", [(0, "#8FDCFF"), (1, "#4FB2EE")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    pic.add(rainbow(900, 700, 420, 22))
    pic.add(cloud(260, 70, 0.8) + cloud(720, 260, 0.9) + cloud(1110, 380, 0.7) + cloud(80, 470, 0.6))
    pic.add(bird_v(500, 60, 1.0) + bird_v(540, 84, 0.8) + bird_v(1140, 110, 0.9) + bird_v(200, 290, 0.7))
    # Uzak dağlar
    pic.add('  <path d="M0 640 L140 520 L230 590 L360 480 L480 600 L600 540 L720 610 L860 500 L990 590 L1100 520 L1200 580 L1200 700 L0 700 Z" fill="#C9BCF0"/>\n')
    pic.add('  <path d="M360 480 L320 515 L345 512 L362 530 L380 510 L400 515 Z M860 500 L825 530 L848 528 L862 545 L878 526 L895 530 Z" fill="#FFFFFF" opacity="0.9"/>\n')
    # Tarlalar, nehir, köy
    pic.add('  <path d="M0 650 Q300 600 600 650 Q900 700 1200 630 L1200 900 L0 900 Z" fill="url(#tepe1)"/>\n')
    for k, (c, pts) in enumerate((("#F7D86A", "0,700 260,670 330,760 0,800"), ("#B5E07A", "330,760 260,670 560,680 620,780"),
                                  ("#E9B96A", "760,700 1060,670 1200,700 1200,780 900,800"), ("#9DD86C", "620,780 560,680 760,700 900,800"))):
        pic.add(f'  <polygon points="{pts}" fill="{c}" opacity="0.85"/>\n')
        rng = random.Random(k)
    pic.add(f'  <path d="M480 900 Q520 820 640 790 Q780 760 760 700 Q750 670 820 650 L850 652 Q790 690 800 720 Q820 790 680 830 Q580 860 600 900 Z" fill="url(#nehir)" {st(4)}/>\n')
    pic.add('  <path d="M0 800 Q200 760 420 800 L420 900 L0 900 Z M900 820 Q1060 770 1200 800 L1200 900 L900 900 Z" fill="url(#tepe2)"/>\n')
    pic.add(duck(570, 862, 0.85) + duck(720, 796, 0.65, True))
    house(pic, 60, 800, 110, 80, "#FFF1D6", "#E8483F", 2, True)
    house(pic, 220, 790, 90, 70, "#D9F0FF", "#4A8FF0", 1)
    house(pic, 940, 820, 100, 74, "#FFE0EC", "#A46BFF", 2, True)
    house(pic, 1080, 810, 90, 70, "#FFF7C2", "#FF8A3D", 1)
    pic.add(windmill(470, 800, 0.85))
    for tx, ty, ts in ((330, 860, 0.35), (880, 870, 0.32), (1170, 880, 0.3), (40, 880, 0.3)):
        tree(pic, tx, ty, ts)
    rng = random.Random(5)
    for k in range(14):
        fx = rng.choice([rng.uniform(20, 440), rng.uniform(880, 1180)])
        pic.add(flower(fx, rng.uniform(830, 880), 0.7, ["#FF6FA8", "#FFFFFF", "#FFD23F", "#A46BFF"][k % 4]))
    # Balonlar (uzaktan yakına)
    balloon(pic, 640, 130, 52, ["#FF8FC8", "#FFFFFF", "#FF8FC8"])
    balloon(pic, 1080, 520, 62, ["#FF9F40", "#FFD23F", "#FF9F40"])
    balloon(pic, 130, 150, 78, ["#5CC95C", "#A66BFF", "#5CC95C", "#FFE066"], "tavsan")
    balloon(pic, 930, 200, 110, ["#4FA8FF", "#FFFFFF", "#4FA8FF", "#FFFFFF"], "panda")
    balloon(pic, 400, 340, 150, ["#FF5A6E", "#FFD23F", "#FF5A6E", "#FFD23F", "#FF5A6E"], "ayi")
    pic.save("balonlar")


# --- 10. Kasaba (4x3) ---

def kite(x: float, y: float, s: float) -> str:
    b = f'  <path d="M0 -60 L44 0 L0 70 L-44 0 Z" fill="#FF5A6E" {st(5)}/>\n'
    b += f'  <path d="M0 -60 L0 70 M-44 0 L44 0" {st(4)}/>\n'
    b += f'  <path d="M0 -60 L44 0 L0 0 Z M0 0 L-44 0 L0 70 Z" fill="#FFD23F"/>\n'
    b += f'  <path d="M0 -60 L44 0 L0 70 L-44 0 Z" fill="none" {st(5)}/>\n'
    b += f'  <path d="M0 70 Q-20 110 10 140 Q36 170 10 210" fill="none" {st(3)}/>\n'
    for k, (bx, by) in enumerate(((-10, 100), (12, 140), (4, 184))):
        c = ["#4FA8FF", "#5CC95C", "#A66BFF"][k]
        b += f'  <path d="M{bx - 12} {by - 8} L{bx} {by} L{bx - 12} {by + 8} Z M{bx + 12} {by - 8} L{bx} {by} L{bx + 12} {by + 8} Z" fill="{c}" {st(3)}/>\n'
    return at(b, x, y, s, 18)


def shop(pic: Pic, x: float, y: float, w: float, h: float) -> None:
    # Pastane: çizgili tente, vitrinde pastalar (yazı yok)
    g1 = pic.uid("dukkan")
    defs = linear(g1, [(0, "#FFE9D6"), (1, "#FFD2B0")])
    b = f'  <rect x="{x:g}" y="{y - h:g}" width="{w:g}" height="{h:g}" fill="url(#{g1})" {st(5)}/>\n'
    b += f'  <path d="M{x - 8:g} {y - h + 8:g} L{x + w / 2:g} {y - h - 60:g} L{x + w + 8:g} {y - h + 8:g} Z" fill="#FF7FA3" {st(5)}/>\n'
    b += f'  <circle cx="{x + w / 2:g}" cy="{y - h - 18:g}" r="20" fill="#FFFFFF" {st(4)}/>\n'
    b += f'  <path d="M{x + w / 2 - 10:g} {y - h - 12:g} L{x + w / 2 + 10:g} {y - h - 12:g} L{x + w / 2 + 8:g} {y - h - 22:g} L{x + w / 2 - 8:g} {y - h - 22:g} Z" fill="#FF7FA3" {st(3)}/>\n'
    b += f'  <circle cx="{x + w / 2:g}" cy="{y - h - 28:g}" r="4" fill="#FF5A6E"/>\n'
    # Tente
    ay = y - h * 0.66
    n = 6
    sw = (w + 20) / n
    for k in range(n):
        c = "#FF5A6E" if k % 2 == 0 else "#FFFFFF"
        sx = x - 10 + k * sw
        b += f'  <path d="M{sx:g} {ay - 34:g} L{sx + sw:g} {ay - 34:g} L{sx + sw:g} {ay:g} Q{sx + sw / 2:g} {ay + 18:g} {sx:g} {ay:g} Z" fill="{c}" {st(4)}/>\n'
    # Vitrin ve kapı
    vw = w * 0.56
    b += f'  <rect x="{x + 14:g}" y="{ay + 26:g}" width="{vw:g}" height="{y - ay - 50:g}" rx="6" fill="#CFEFFF" {st(4)}/>\n'
    for k, c in enumerate(["#FF8FC8", "#FFD23F", "#A46BFF"]):
        cx = x + 14 + vw * (k + 0.5) / 3
        cy = y - 36
        b += f'  <rect x="{cx - 16:g}" y="{cy - 24:g}" width="32" height="24" rx="5" fill="{c}" {st(3.5)}/>\n'
        b += f'  <path d="M{cx - 16:g} {cy - 18:g} Q{cx - 8:g} {cy - 10:g} {cx:g} {cy - 18:g} Q{cx + 8:g} {cy - 10:g} {cx + 16:g} {cy - 18:g}" fill="none" stroke="#FFFFFF" stroke-width="3"/>\n'
        b += f'  <circle cx="{cx:g}" cy="{cy - 30:g}" r="5" fill="#FF3B4E" {st(2.5)}/>\n'
    b += f'  <path d="M{x + 14:g} {ay + 40:g} L{x + 14 + vw * 0.3:g} {ay + 26:g}" stroke="#FFFFFF" stroke-width="6" opacity="0.7"/>\n'
    dx = x + w * 0.68
    b += f'  <rect x="{dx:g}" y="{ay + 26:g}" width="{w * 0.24:g}" height="{y - ay - 26:g}" fill="#8E5532" {st(4)}/>\n'
    b += f'  <rect x="{dx + 8:g}" y="{ay + 36:g}" width="{w * 0.24 - 16:g}" height="40" rx="4" fill="#CFEFFF" {st(3)}/>\n'
    b += f'  <circle cx="{dx + w * 0.19:g}" cy="{y - 40:g}" r="4" fill="#FFD23F"/>\n'
    pic.add(b, defs)


def tower(pic: Pic, x: float, y: float, w: float, h: float) -> None:
    # Saat kulesi (yazısız kadran)
    g1 = pic.uid("kule")
    defs = linear(g1, [(0, "#D9E4FF"), (0.5, "#F4F7FF"), (1, "#B8C6EE")], 1, 0)
    b = f'  <rect x="{x:g}" y="{y - h:g}" width="{w:g}" height="{h:g}" fill="url(#{g1})" {st(5)}/>\n'
    b += f'  <path d="M{x - 14:g} {y - h + 4:g} L{x + w / 2:g} {y - h - 110:g} L{x + w + 14:g} {y - h + 4:g} Z" fill="#4A6FE0" {st(5)}/>\n'
    b += f'  <path d="M{x + w / 2:g} {y - h - 110:g} L{x + w / 2:g} {y - h - 150:g}" {st(4)}/>\n'
    b += f'  <path d="M{x + w / 2:g} {y - h - 150:g} L{x + w / 2 + 34:g} {y - h - 140:g} L{x + w / 2:g} {y - h - 128:g} Z" fill="#FF5A6E" {st(3.5)}/>\n'
    cx, cy, r = x + w / 2, y - h + 70, w * 0.34
    b += f'  <circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="#FFFDF5" {st(5)}/>\n'
    for k in range(12):
        a = math.radians(k * 30)
        b += f'  <circle cx="{cx + r * 0.78 * math.cos(a):.1f}" cy="{cy + r * 0.78 * math.sin(a):.1f}" r="{3.5 if k % 3 == 0 else 2:g}" fill="{OUT}"/>\n'
    b += f'  <path d="M{cx:g} {cy:g} L{cx:g} {cy - r * 0.6:g} M{cx:g} {cy:g} L{cx + r * 0.42:g} {cy + r * 0.1:g}" {st(5)}/>\n'
    b += f'  <circle cx="{cx:g}" cy="{cy:g}" r="5" fill="#FF5A6E"/>\n'
    for row in range(2):
        for col in range(2):
            wx = x + 22 + col * (w - 74)
            wy = y - h + 140 + row * 80
            b += f'  <path d="M{wx:g} {wy + 46:g} L{wx:g} {wy + 12:g} Q{wx + 15:g} {wy - 4:g} {wx + 30:g} {wy + 12:g} L{wx + 30:g} {wy + 46:g} Z" fill="#FFE58A" {st(4)}/>\n'
    b += f'  <path d="M{cx - 30:g} {y:g} L{cx - 30:g} {y - 60:g} Q{cx:g} {y - 90:g} {cx + 30:g} {y - 60:g} L{cx + 30:g} {y:g} Z" fill="#8E5532" {st(4)}/>\n'
    b += shine(x + 20, y - h + 20, 10, 30, 0, 0.5)
    pic.add(b, defs)


def car(pic: Pic, x: float, y: float, s: float, color: str, flip: bool = False) -> None:
    g1 = pic.uid("araba")
    defs = linear(g1, [(0, light(color, 0.3)), (1, dark(color, 0.1))])
    b = f'  <path d="M-110 -20 Q-112 -54 -80 -58 L-56 -60 Q-36 -104 10 -104 L40 -104 Q70 -104 86 -62 L104 -58 Q122 -52 120 -20 L120 -6 Q120 4 110 4 L-100 4 Q-110 4 -110 -6 Z" fill="url(#{g1})" {st()}/>\n'
    b += f'  <path d="M-40 -62 Q-26 -92 4 -92 L4 -62 Z" fill="#CFEFFF" {st(4)}/>\n'
    b += f'  <path d="M18 -62 L18 -92 L38 -92 Q60 -92 72 -62 Z" fill="#CFEFFF" {st(4)}/>\n'
    b += f'  <path d="M-30 -86 L-14 -86" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>\n'
    b += f'  <rect x="104" y="-46" width="16" height="12" rx="4" fill="#FFF3A8" {st(3)}/>\n'
    b += f'  <rect x="-110" y="-44" width="12" height="12" rx="4" fill="#FF8A8A" {st(3)}/>\n'
    b += f'  <path d="M-12 -50 L-2 -50" {st(4)}/>\n'
    for wx in (-62, 72):
        b += f'  <circle cx="{wx}" cy="4" r="26" fill="#3B2F6B"/>\n  <circle cx="{wx}" cy="4" r="12" fill="#D9DEEE" {st(3)}/>\n'
    b += shine(-60, -44, 26, 6, -4, 0.6)
    pic.add(at(b, x, y, s, flip=flip), defs)


def bus(pic: Pic, x: float, y: float, s: float) -> None:
    g1 = pic.uid("otobus")
    defs = linear(g1, [(0, "#FFE066"), (1, "#FFB627")])
    b = f'  <rect x="-150" y="-150" width="300" height="140" rx="26" fill="url(#{g1})" {st()}/>\n'
    for k in range(4):
        wx = -134 + k * 62
        b += f'  <rect x="{wx}" y="-134" width="48" height="50" rx="8" fill="#CFEFFF" {st(4)}/>\n'
    b += f'  <rect x="114" y="-134" width="30" height="104" rx="6" fill="#CFEFFF" {st(4)}/>\n'
    b += f'  <path d="M-150 -66 L150 -66" stroke="#FF8A3D" stroke-width="10"/>\n'
    b += f'  <rect x="-150" y="-150" width="300" height="140" rx="26" fill="none" {st()}/>\n'
    # Pencerelerde yolcular: kedi ve köpek kulakları
    for k, c in ((0, "#FFA84D"), (2, "#E8A45C")):
        cx = -110 + k * 62
        b += f'  <circle cx="{cx}" cy="-96" r="14" fill="{c}" {st(3.5)}/>\n'
        b += f'  <path d="M{cx - 12} -104 L{cx - 10} -120 L{cx - 2} -108 M{cx + 12} -104 L{cx + 10} -120 L{cx + 2} -108" fill="{c}" {st(3)}/>\n'
        b += f'  <circle cx="{cx - 5}" cy="-98" r="2.5" fill="{OUT}"/><circle cx="{cx + 5}" cy="-98" r="2.5" fill="{OUT}"/>\n'
    b += f'  <rect x="138" y="-40" width="14" height="14" rx="4" fill="#FFF3A8" {st(3)}/>\n'
    for wx in (-96, 92):
        b += f'  <circle cx="{wx}" cy="-8" r="28" fill="#3B2F6B"/>\n  <circle cx="{wx}" cy="-8" r="13" fill="#D9DEEE" {st(3)}/>\n'
    b += shine(-110, -142, 30, 5, 0, 0.7)
    pic.add(at(b, x, y, s), defs)


def traffic_light(x: float, y: float, s: float) -> str:
    b = f'  <rect x="-6" y="-170" width="12" height="170" fill="#7A84A8" {st(4)}/>\n'
    b += f'  <rect x="-26" y="-250" width="52" height="120" rx="14" fill="#4A4F70" {st(5)}/>\n'
    for k, c in enumerate(["#FF5A6E", "#FFD23F", "#5CC95C"]):
        op = "1" if k == 2 else "0.35"
        b += f'  <circle cx="0" cy="{-228 + k * 38}" r="14" fill="{c}" opacity="{op}" {st(3)}/>\n'
    b += f'  <circle cx="-4" cy="-156" r="4" fill="#FFFFFF" opacity="0.8"/>\n'
    return at(b, x, y, s)


def bicycle(x: float, y: float, s: float) -> str:
    b = ""
    for wx in (-50, 50):
        b += f'  <circle cx="{wx}" cy="0" r="34" fill="none" {st(6)}/>\n  <circle cx="{wx}" cy="0" r="5" fill="{OUT}"/>\n'
        for a in range(0, 180, 45):
            r = math.radians(a)
            b += f'  <path d="M{wx + 30 * math.cos(r):.1f} {30 * math.sin(r):.1f} L{wx - 30 * math.cos(r):.1f} {-30 * math.sin(r):.1f}" stroke="#9AA6C6" stroke-width="2"/>\n'
    b += f'  <path d="M-50 0 L-10 0 L24 -50 L-26 -50 Z M-10 0 L-30 -66 M24 -50 L50 0 M24 -50 L18 -72" fill="none" stroke="#4FA8FF" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>\n'
    b += f'  <path d="M-42 -70 L-18 -70" {st(7)}/>\n  <path d="M8 -74 L28 -74" {st(6)}/>\n'
    b += f'  <rect x="30" y="-96" width="36" height="22" rx="4" fill="#C7864F" {st(3.5)}/>\n'
    b += flower(48, -96, 0.5, "#FF6FA8", stem=False)
    return at(b, x, y, s)


def town() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#7CC8FF"), (1, "#DDF3FF")])
    pic.defs += linear("yol", [(0, "#8A90AE"), (1, "#6E7494")])
    pic.defs += linear("kaldirim", [(0, "#F2E6D6"), (1, "#E0CFB8")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    sun(pic, 1080, 110, 62)
    pic.add(cloud(330, 90, 0.85) + cloud(760, 60, 0.6) + cloud(560, 210, 0.5))
    pic.add(bird_v(480, 140, 0.9) + bird_v(520, 160, 0.7) + bird_v(900, 90, 0.8))
    pic.add(kite(110, 130, 1.0))
    balloon(pic, 860, 230, 40, ["#A66BFF", "#FFE066", "#A66BFF"])
    # Uzak binalar (silüet)
    pic.add('  <path d="M0 560 V420 H70 V380 H130 V440 H200 V400 H280 V560 Z M880 560 V430 H950 V370 H1010 V420 H1090 V390 H1200 V560 Z" fill="#B9C9F2"/>\n')
    for wx, wy in ((90, 400), (100, 440), (220, 420), (960, 390), (970, 440), (1120, 410), (1160, 450)):
        pic.add(f'  <rect x="{wx}" y="{wy}" width="14" height="18" fill="#E2EAFF"/>\n')
    # Binalar
    house(pic, 20, 600, 220, 170, "#FFD3E2", "#E8483F", 2, True)
    animal(pic, "kedi", 150, 368, 0.42)
    shop(pic, 300, 600, 250, 200)
    tower(pic, 610, 600, 170, 330)
    house(pic, 860, 600, 200, 160, "#FFF3B0", "#4A8FF0", 2)
    tree(pic, 1130, 600, 0.75)
    tree(pic, 270, 600, 0.45)
    # Kaldırım ve yol
    pic.add(f'  <rect x="-10" y="596" width="{W + 20}" height="60" fill="url(#kaldirim)" {st(5)}/>\n')
    for k in range(0, W, 80):
        pic.add(f'  <path d="M{k} 600 L{k + 20} 652" stroke="#CDBA9E" stroke-width="3"/>\n')
    pic.add(f'  <rect x="-10" y="654" width="{W + 20}" height="260" fill="url(#yol)" {st(5)}/>\n')
    for k in range(-40, W, 140):
        if 330 < k < 640:
            continue
        pic.add(f'  <rect x="{k}" y="772" width="80" height="12" rx="6" fill="#FFFFFF" opacity="0.9"/>\n')
    # Yaya geçidi
    for k in range(6):
        pic.add(f'  <rect x="{400 + k * 34}" y="670" width="22" height="210" fill="#FFFFFF" opacity="0.92"/>\n')
    # Saksılar, posta kutusu, köpek
    for px, c in ((60, "#FF6FA8"), (1000, "#FFD23F")):
        pic.add(f'  <path d="M{px - 26} 600 L{px + 26} 600 L{px + 20} 636 L{px - 20} 636 Z" fill="#E07B5A" {st(4)}/>\n')
        pic.add(flower(px - 12, 584, 0.7, c, stem=False) + flower(px + 12, 580, 0.7, "#FFFFFF", stem=False))
        pic.add(tuft(px, 602, 0.8))
    animal(pic, "kopek", 560, 650, 0.5)
    pic.add(traffic_light(260, 646, 0.9))
    pic.add(bicycle(1080, 640, 0.8))
    car(pic, 180, 860, 1.05, "#FF5A6E")
    bus(pic, 800, 880, 1.15)
    car(pic, 1110, 790, 0.6, "#5CC95C", True)
    pic.save("kasaba")


# --- Karakter: gülen yapboz parçası (menü kartı ve final ekranı) ---

def piece_path(x: float, y: float, s: float, tabs: tuple) -> str:
    # Kare yapboz parçası (kenar s), tabs: (üst, sağ, alt, sol) +1 dışa, -1 içe, 0 düz.
    # Çıkıntı eğrisi oyundaki kesici.gd'ye benzer: boyun, yuvarlak baş.
    def edge(ax, ay, bx, by, sign):
        dx, dy = (bx - ax) / s, (by - ay) / s
        nx, ny = dy, -dx  # kenarın sol tarafı = parçanın dışı (saat yönünde dolaşınca)
        if sign == 0:
            return f" L{bx:.1f} {by:.1f}"
        k = sign * s

        def p(u, v):
            return f"{ax + dx * s * u + nx * k * v:.1f} {ay + dy * s * u + ny * k * v:.1f}"
        return (f" L{p(0.36, 0)} C{p(0.42, 0)} {p(0.44, 0.06)} {p(0.4, 0.12)}"
                f" C{p(0.34, 0.22)} {p(0.4, 0.3)} {p(0.5, 0.3)}"
                f" C{p(0.6, 0.3)} {p(0.66, 0.22)} {p(0.6, 0.12)}"
                f" C{p(0.56, 0.06)} {p(0.58, 0)} {p(0.64, 0)} L{bx:.1f} {by:.1f}")
    t, r, b, left = tabs
    d = f"M{x:g} {y:g}"
    d += edge(x, y, x + s, y, t)
    d += edge(x + s, y, x + s, y + s, r)
    d += edge(x + s, y + s, x, y + s, b)
    d += edge(x, y + s, x, y, left)
    return d + " Z"


def card_piece() -> None:
    defs = ten("parca", "#FF9F40") + ten("parca2", "#4FA8FF") + besle.EYE_DEFS
    body = ""
    # Arkada eğik duran mavi parça
    body += f'  <g transform="rotate(-14 90 150)"><path d="{piece_path(30, 90, 110, (0, 1, 1, 0))}" fill="url(#parca2)" {st(7)}/></g>\n'
    body += shine(70, 118, 16, 7, -40, 0.7)
    # Önde gülen turuncu parça
    body += f'  <path d="{piece_path(110, 56, 140, (1, 1, 1, 0))}" fill="url(#parca)" {st(8)}/>\n'
    body += shine(150, 92, 22, 9, -30, 0.85)
    cx, cy = 182, 124
    for dx in (-26, 26):
        body += f'  <ellipse cx="{cx + dx}" cy="{cy - 6}" rx="11" ry="14" fill="url(#goz)"/>\n'
        body += f'  <ellipse cx="{cx + dx - 4}" cy="{cy - 12}" rx="4.5" ry="5" fill="#FFFFFF"/>\n'
    body += "".join(f'  <ellipse cx="{cx + dx}" cy="{cy + 18}" rx="14" ry="8" fill="url(#yanak)"/>\n' for dx in (-44, 44))
    body += f'  <path d="M{cx - 18} {cy + 14} Q{cx} {cy + 16} {cx + 18} {cy + 14} Q{cx + 16} {cy + 38} {cx} {cy + 38} Q{cx - 16} {cy + 38} {cx - 18} {cy + 14} Z" fill="#8A2A4A" {st(5)}/>\n'
    body += f'  <path d="M{cx - 9} {cy + 32} Q{cx} {cy + 26} {cx + 9} {cy + 32} Q{cx} {cy + 38} {cx - 9} {cy + 32} Z" fill="#FF7FA3"/>\n'
    write("kart_yapboz.svg", 300, 260, body, defs)


if __name__ == "__main__":
    card_piece()
    copy("hayvan_besle/gorseller/yildiz.svg", "yildiz.svg")
    copy("hayvan_besle/gorseller/isilti.svg", "isilti.svg")
    farm()
    sea()
    balloons()
    town()
