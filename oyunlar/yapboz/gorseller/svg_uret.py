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


# --- 2. Kırmızı tren (2x2) ---

def pine(pic: Pic, x: float, y: float, s: float, color: str = "#3FAE5A") -> None:
    # Çam ağacı; (x, y) gövdenin dibi
    gid = pic.uid("cam")
    defs = linear(gid, [(0, light(color, 0.25)), (1, dark(color, 0.1))])
    b = f'  <rect x="{x - 10 * s:g}" y="{y - 40 * s:g}" width="{20 * s:g}" height="{40 * s:g}" fill="#9C6040" {st(4)}/>\n'
    for k, (w, top, bottom) in enumerate(((80, 120, 30), (64, 170, 80), (46, 215, 130))):
        b += f'  <path d="M{x - w * s:g} {y - bottom * s:g} L{x:g} {y - top * s - 40 * s:g} L{x + w * s:g} {y - bottom * s:g} Q{x:g} {y - bottom * s + 12 * s:g} {x - w * s:g} {y - bottom * s:g} Z" fill="url(#{gid})" {st(5)}/>\n'
    b += shine(x - 20 * s, y - 150 * s, 8 * s, 18 * s, 25, 0.5)
    pic.add(b, defs)


def rails(y: float) -> str:
    b = ""
    for x in range(-20, W + 40, 46):
        b += f'  <rect x="{x}" y="{y - 6}" width="28" height="30" rx="4" fill="#B07A4A" {st(3.5)}/>\n'
    for dy in (0, 16):
        b += f'  <rect x="-10" y="{y + dy - 4}" width="{W + 20}" height="9" rx="4" fill="#9AA6C6" {st(3.5)}/>\n'
    return b


def wheel(x: float, y: float, r: float, color: str = "#FF5A6E") -> str:
    b = f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="{OUT}"/>\n'
    b += f'  <circle cx="{x:g}" cy="{y:g}" r="{r * 0.78:g}" fill="{color}"/>\n'
    for a in range(0, 180, 45):
        rad = math.radians(a)
        b += f'  <path d="M{x + r * 0.7 * math.cos(rad):.1f} {y + r * 0.7 * math.sin(rad):.1f} L{x - r * 0.7 * math.cos(rad):.1f} {y - r * 0.7 * math.sin(rad):.1f}" stroke="{dark(color, 0.35)}" stroke-width="{max(3, r * 0.1):g}"/>\n'
    b += f'  <circle cx="{x:g}" cy="{y:g}" r="{r * 0.22:g}" fill="#FFD23F" {st(3)}/>\n'
    return b


def wagon(pic: Pic, x: float, y: float, w: float, color: str, riders: list) -> None:
    # Açık vagon, içinde hayvanlar; (x, y) vagon gövdesinin sol alt köşesi (tekerlerin üstü)
    gid = pic.uid("vagon")
    defs = linear(gid, [(0, light(color, 0.25)), (1, dark(color, 0.1))])
    h = 110
    for k, name in enumerate(riders):
        animal_head(pic, name, x + w * (k + 0.5) / len(riders), y - h - 40, 0.55)
    b = f'  <rect x="{x:g}" y="{y - h:g}" width="{w:g}" height="{h:g}" rx="12" fill="url(#{gid})" {st()}/>\n'
    b += f'  <rect x="{x - 8:g}" y="{y - h - 10:g}" width="{w + 16:g}" height="20" rx="8" fill="{dark(color, 0.15)}" {st(5)}/>\n'
    for k in range(3):
        px = x + 22 + k * (w - 44) / 2
        b += f'  <circle cx="{px:g}" cy="{y - h / 2 + 6:g}" r="13" fill="#FFD23F" {st(3.5)}/>\n'
    b += shine(x + 40, y - h + 26, 26, 6, 0, 0.6)
    b += wheel(x + w * 0.24, y + 18, 36, "#4A6FE0") + wheel(x + w * 0.76, y + 18, 36, "#4A6FE0")
    pic.add(b, defs)


def locomotive(pic: Pic, x: float, y: float) -> None:
    # Kırmızı buharlı lokomotif, sağa gider; (x, y) gövdenin sol alt köşesi. Yüzü yok (tanınmış bir karakteri
    # çağrıştırmasın diye).
    g1, g2 = pic.uid("lok"), pic.uid("kazan")
    defs = linear(g1, [(0, "#FF7A6E"), (1, "#D9413E")]) + linear(g2, [(0, "#FF8A7A"), (0.5, "#FF5A5A"), (1, "#C93A3E")])
    # Sürücü panda kabinde
    animal_head(pic, "panda", x + 75, y - 158, 0.46)
    b = ""
    # Kabin
    b += f'  <path d="M{x:g} {y:g} L{x:g} {y - 230:g} L{x + 150:g} {y - 230:g} L{x + 150:g} {y:g} Z M{x + 26:g} {y - 200:g} L{x + 26:g} {y - 130:g} L{x + 124:g} {y - 130:g} L{x + 124:g} {y - 200:g} Z" fill="url(#{g1})" fill-rule="evenodd" {st()}/>\n'
    b += f'  <rect x="{x - 18:g}" y="{y - 256:g}" width="186" height="30" rx="10" fill="#7A2B40" {st()}/>\n'
    # Kazan
    b += f'  <rect x="{x + 150:g}" y="{y - 150:g}" width="250" height="120" rx="20" fill="url(#{g2})" {st()}/>\n'
    for k in range(3):
        bx = x + 200 + k * 70
        b += f'  <rect x="{bx:g}" y="{y - 150:g}" width="14" height="120" fill="#FFD23F" {st(3.5)}/>\n'
    # Baca ve kubbe
    b += f'  <path d="M{x + 320:g} {y - 150:g} L{x + 314:g} {y - 230:g} L{x + 296:g} {y - 254:g} L{x + 380:g} {y - 254:g} L{x + 362:g} {y - 230:g} L{x + 356:g} {y - 150:g} Z" fill="#4A4F70" {st()}/>\n'
    b += f'  <path d="M{x + 220:g} {y - 150:g} Q{x + 222:g} {y - 192:g} {x + 250:g} {y - 192:g} Q{x + 278:g} {y - 192:g} {x + 280:g} {y - 150:g} Z" fill="#FFD23F" {st(5)}/>\n'
    # Ön: far ve tampon
    b += f'  <circle cx="{x + 404:g}" cy="{y - 112:g}" r="20" fill="#FFF3A8" {st(5)}/>\n'
    b += f'  <path d="M{x + 400:g} {y - 30:g} L{x + 400:g} {y + 6:g} L{x + 460:g} {y + 40:g} L{x + 460:g} {y + 10:g} Z" fill="#FFD23F" {st(5)}/>\n'
    b += f'  <rect x="{x - 10:g}" y="{y - 40:g}" width="420" height="40" rx="10" fill="#3B2F6B"/>\n'
    b += shine(x + 200, y - 130, 60, 7, 0, 0.55) + shine(x + 30, y - 214, 30, 6, 0, 0.5)
    b += wheel(x + 70, y + 8, 62) + wheel(x + 220, y + 26, 44) + wheel(x + 330, y + 26, 44)
    b += f'  <path d="M{x + 70:g} {y + 8:g} L{x + 330:g} {y + 26:g}" stroke="#C9D3E8" stroke-width="10" stroke-linecap="round"/>\n'
    b += f'  <path d="M{x + 70:g} {y + 8:g} L{x + 330:g} {y + 26:g}" fill="none" {st(3)}/>\n'
    pic.add(b, defs)


def steam(x: float, y: float, s: float) -> str:
    shapes = "".join(f'<circle cx="{x + dx * s:g}" cy="{y + dy * s:g}" r="{r * s:g}"/>' for dx, dy, r in
                     ((0, 0, 30), (-26, 10, 22), (26, 8, 24), (6, -20, 24)))
    return (f'  <g fill="#D9E2F2" stroke="#D9E2F2" stroke-width="{10 * s:g}">{shapes}</g>\n'
            f'  <g fill="#FFFFFF">{shapes}</g>\n' + shine(x - 8 * s, y - 14 * s, 10 * s, 5 * s, -20, 0.9))


def signal(x: float, y: float, s: float) -> str:
    b = f'  <rect x="-6" y="-200" width="12" height="200" fill="#7A84A8" {st(4)}/>\n'
    b += f'  <rect x="-30" y="-230" width="60" height="44" rx="14" fill="#4A4F70" {st(5)}/>\n'
    b += f'  <circle cx="-12" cy="-208" r="11" fill="#5CC95C" {st(3)}/>\n  <circle cx="12" cy="-208" r="11" fill="#FF5A6E" opacity="0.35" {st(3)}/>\n'
    return at(b, x, y, s)


def train() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#8ED2FF"), (1, "#E2F5FF")])
    pic.defs += linear("dag", [(0, "#B9A8F0"), (1, "#9C8BDF")])
    pic.defs += linear("tepe1", [(0, "#B6EA94"), (1, "#8ED36E")]) + linear("cayir", [(0, "#8ED96A"), (1, "#5DB64C")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    pic.add(cloud(220, 110, 0.9) + cloud(640, 70, 0.7))
    pic.add(bird_v(470, 150, 0.9) + bird_v(510, 172, 0.7) + bird_v(860, 230, 0.8))
    # Dağlar ve tepeler
    pic.add('  <path d="M-20 520 L180 260 L300 400 L420 300 L620 520 Z" fill="url(#dag)"/>\n')
    pic.add('  <path d="M180 260 L140 312 L170 306 L188 326 L210 300 L232 306 Z M420 300 L388 342 L410 338 L424 354 L440 336 L458 342 Z" fill="#FFFFFF"/>\n')
    pic.add('  <path d="M700 520 L900 330 L1040 450 L1120 380 L1240 520 Z" fill="url(#dag)" opacity="0.9"/>\n')
    pic.add('  <path d="M0 560 Q300 470 620 540 Q900 480 1200 540 L1200 900 L0 900 Z" fill="url(#tepe1)"/>\n')
    for tx, ty, ts in ((70, 560, 1.0), (180, 580, 0.8), (520, 560, 0.7), (600, 575, 0.55), (1150, 570, 0.8)):
        pine(pic, tx, ty, ts)
    pic.add('  <path d="M0 640 Q600 610 1200 640 L1200 900 L0 900 Z" fill="url(#cayir)"/>\n')
    pic.add(signal(40, 780, 0.9))
    # Buhar bacadan sağ üste yükselir
    pic.add(steam(1010, 440, 0.8) + steam(1050, 350, 1.1) + steam(1100, 240, 1.4) + steam(1140, 110, 1.6))
    pic.add(rails(790))
    wagon(pic, 70, 740, 240, "#4FA8FF", ["ayi", "fare"])
    wagon(pic, 360, 740, 250, "#5CC95C", ["kedi", "tavsan"])
    pic.add(f'  <path d="M310 712 L360 712 M610 712 L660 712" {st(8)}/>\n')
    locomotive(pic, 660, 740)
    rng = random.Random(21)
    for k in range(18):
        fx, fy = rng.uniform(20, 1180), rng.uniform(840, 885)
        pic.add(tuft(fx + 16, fy + 30, 0.8))
        pic.add(flower(fx, fy, 0.85, ["#FF6FA8", "#FFD23F", "#FFFFFF", "#A46BFF", "#FF8A3D"][k % 5]))
    pic.add(butterfly(300, 470, 0.9, "#FFB84D", "#FF8FC8", 10))
    pic.save("tren")


# --- 3. Meyve sepeti (2x2) ---

def apple(pic: Pic, x: float, y: float, r: float, color: str = "#FF4F5E", happy: bool = False) -> None:
    gid = pic.uid("elma")
    defs = ten(gid, color)
    b = f'  <path d="M{x:g} {y - r * 0.75:g} Q{x + r * 0.05:g} {y - r * 1.15:g} {x + r * 0.2:g} {y - r * 1.25:g}" fill="none" stroke="#8E5532" stroke-width="{r * 0.12:g}" stroke-linecap="round"/>\n'
    b += f'  <ellipse cx="{x + r * 0.45:g}" cy="{y - r * 1.05:g}" rx="{r * 0.35:g}" ry="{r * 0.16:g}" transform="rotate(-25 {x + r * 0.45:g} {y - r * 1.05:g})" fill="#5DBB4F" {st(4)}/>\n'
    b += (f'  <path d="M{x:g} {y - r * 0.7:g} C{x + r * 0.5:g} {y - r * 1.05:g} {x + r * 1.1:g} {y - r * 0.6:g} {x + r:g} {y + r * 0.05:g} '
          f'C{x + r * 0.95:g} {y + r * 0.75:g} {x + r * 0.4:g} {y + r * 1.05:g} {x:g} {y + r * 0.85:g} '
          f'C{x - r * 0.4:g} {y + r * 1.05:g} {x - r * 0.95:g} {y + r * 0.75:g} {x - r:g} {y + r * 0.05:g} '
          f'C{x - r * 1.1:g} {y - r * 0.6:g} {x - r * 0.5:g} {y - r * 1.05:g} {x:g} {y - r * 0.7:g} Z" fill="url(#{gid})" {st()}/>\n')
    b += shine(x - r * 0.45, y - r * 0.3, r * 0.2, r * 0.1, -40, 0.85)
    if happy:
        b += eye(x - r * 0.3, y + r * 0.05, r * 0.16, (0, 0)) + eye(x + r * 0.3, y + r * 0.05, r * 0.16, (0, 0))
        b += smile(x, y + r * 0.35, r * 0.2, 4)
        b += "".join(f'  <ellipse cx="{x + dx * r:g}" cy="{y + r * 0.35:g}" rx="{r * 0.13:g}" ry="{r * 0.07:g}" fill="#FFFFFF" opacity="0.45"/>\n' for dx in (-0.55, 0.55))
    pic.add(b, defs)


def orange(pic: Pic, x: float, y: float, r: float) -> None:
    gid = pic.uid("portakal")
    defs = ten(gid, "#FF9F40")
    b = f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{gid})" {st()}/>\n'
    rng = random.Random(int(x))
    for k in range(10):
        a, d = rng.uniform(0, math.tau), rng.uniform(0.2, 0.8) * r
        b += f'  <circle cx="{x + d * math.cos(a):.1f}" cy="{y + d * math.sin(a):.1f}" r="2.5" fill="#E07B28" opacity="0.6"/>\n'
    b += f'  <ellipse cx="{x + r * 0.15:g}" cy="{y - r * 0.92:g}" rx="{r * 0.3:g}" ry="{r * 0.12:g}" transform="rotate(20 {x + r * 0.15:g} {y - r * 0.92:g})" fill="#5DBB4F" {st(4)}/>\n'
    b += shine(x - r * 0.4, y - r * 0.4, r * 0.22, r * 0.1, -40, 0.85)
    pic.add(b, defs)


def banana(x: float, y: float, s: float, rot: float = 0) -> str:
    b = f'  <path d="M-80 -10 Q-20 60 80 -20 Q86 -30 80 -36 Q-10 30 -70 -26 Z" fill="#FFE066" {st(5)}/>\n'
    b += f'  <path d="M-66 -10 Q-10 36 70 -18" fill="none" stroke="#F0B43A" stroke-width="4" stroke-linecap="round"/>\n'
    b += f'  <path d="M80 -36 L92 -44" {st(8)}/>\n  <path d="M-80 -10 L-88 -16" {st(8)}/>\n'
    b += shine(-30, -2, 18, 4, 20, 0.7)
    return at(b, x, y, s, rot)


def grapes(pic: Pic, x: float, y: float, s: float) -> None:
    gid = pic.uid("uzum")
    defs = ten(gid, "#A46BFF")
    b = f'  <path d="M{x:g} {y - 70 * s:g} Q{x + 6 * s:g} {y - 96 * s:g} {x + 20 * s:g} {y - 104 * s:g}" fill="none" stroke="#8E5532" stroke-width="{6 * s:g}" stroke-linecap="round"/>\n'
    b += f'  <path d="M{x:g} {y - 80 * s:g} Q{x - 40 * s:g} {y - 110 * s:g} {x - 60 * s:g} {y - 80 * s:g} Q{x - 30 * s:g} {y - 70 * s:g} {x:g} {y - 80 * s:g} Z" fill="#5DBB4F" {st(4)}/>\n'
    for row, (n, dy) in enumerate(((4, -50), (3, -18), (3, 12), (2, 40), (1, 66))):
        for k in range(n):
            gx = x + (k - (n - 1) / 2) * 30 * s
            b += f'  <circle cx="{gx:g}" cy="{y + dy * s:g}" r="{17 * s:g}" fill="url(#{gid})" {st(4)}/>\n'
            b += f'  <circle cx="{gx - 5 * s:g}" cy="{y + (dy - 6) * s:g}" r="{4 * s:g}" fill="#FFFFFF" opacity="0.8"/>\n'
    pic.add(b, defs)


def pear(pic: Pic, x: float, y: float, s: float) -> None:
    gid = pic.uid("armut")
    defs = ten(gid, "#B5E35A")
    b = f'  <path d="M{x:g} {y - 70 * s:g} Q{x + 2 * s:g} {y - 92 * s:g} {x + 12 * s:g} {y - 100 * s:g}" fill="none" stroke="#8E5532" stroke-width="{6 * s:g}" stroke-linecap="round"/>\n'
    b += (f'  <path d="M{x:g} {y - 72 * s:g} C{x + 26 * s:g} {y - 72 * s:g} {x + 24 * s:g} {y - 30 * s:g} {x + 40 * s:g} {y - 6 * s:g} '
          f'C{x + 66 * s:g} {y + 30 * s:g} {x + 50 * s:g} {y + 70 * s:g} {x:g} {y + 70 * s:g} C{x - 50 * s:g} {y + 70 * s:g} {x - 66 * s:g} {y + 30 * s:g} {x - 40 * s:g} {y - 6 * s:g} '
          f'C{x - 24 * s:g} {y - 30 * s:g} {x - 26 * s:g} {y - 72 * s:g} {x:g} {y - 72 * s:g} Z" fill="url(#{gid})" {st()}/>\n')
    b += shine(x - 22 * s, y + 10 * s, 10 * s, 20 * s, 15, 0.7)
    pic.add(b, defs)


def strawberry(x: float, y: float, s: float, rot: float = 0) -> str:
    b = f'  <path d="M0 -28 C30 -30 40 -6 30 14 C20 34 6 44 0 46 C-6 44 -20 34 -30 14 C-40 -6 -30 -30 0 -28 Z" fill="#FF4F5E" {st(4.5)}/>\n'
    for px, py in ((-14, -10), (0, -14), (14, -10), (-18, 8), (0, 4), (18, 8), (-8, 24), (8, 24)):
        b += f'  <ellipse cx="{px}" cy="{py}" rx="2.5" ry="3.5" fill="#FFE8A0"/>\n'
    b += f'  <path d="M-22 -26 L-8 -32 L0 -44 L8 -32 L22 -26 L8 -22 L0 -18 L-8 -22 Z" fill="#5DBB4F" {st(3.5)}/>\n'
    return at(b, x, y, s, rot)


def watermelon(x: float, y: float, s: float, rot: float = 0) -> str:
    b = f'  <path d="M-90 0 A90 90 0 0 0 90 0 Z" fill="#3FAE5A" {st(5)}/>\n'
    b += '  <path d="M-80 0 A80 80 0 0 0 80 0 Z" fill="#E8FFD0"/>\n'
    b += '  <path d="M-72 0 A72 72 0 0 0 72 0 Z" fill="#FF5A6E"/>\n'
    b += f'  <path d="M-90 0 L90 0" {st(5)}/>\n'
    for px, py in ((-40, 16), (-10, 30), (20, 22), (44, 10), (0, 52), (-30, 44), (34, 42)):
        b += f'  <ellipse cx="{px}" cy="{py}" rx="4" ry="7" fill="{OUT}"/>\n'
    return at(b, x, y, s, rot)


def pineapple(pic: Pic, x: float, y: float, s: float) -> None:
    gid = pic.uid("ananas")
    defs = ten(gid, "#FFC233")
    b = ""
    for a, h in ((-30, 90), (-12, 110), (6, 120), (24, 100), (40, 80)):
        b += f'  <path d="M{x:g} {y - 70 * s:g} Q{x + (a - 20) * s:g} {y - (70 + h * 0.6) * s:g} {x + a * s * 1.6:g} {y - (70 + h) * s:g} Q{x + (a + 10) * s:g} {y - (70 + h * 0.4) * s:g} {x + 10 * s:g} {y - 70 * s:g} Z" fill="#5DBB4F" {st(4)}/>\n'
    b += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{58 * s:g}" ry="{80 * s:g}" fill="url(#{gid})" {st()}/>\n'
    clip = pic.uid("ananaskes")
    defs += f'    <clipPath id="{clip}"><ellipse cx="{x:g}" cy="{y:g}" rx="{58 * s:g}" ry="{80 * s:g}"/></clipPath>\n'
    lines = ""
    for k in range(-5, 6):
        lines += f'<path d="M{x + k * 26 * s - 90 * s:g} {y - 90 * s:g} L{x + k * 26 * s + 90 * s:g} {y + 90 * s:g}"/><path d="M{x + k * 26 * s + 90 * s:g} {y - 90 * s:g} L{x + k * 26 * s - 90 * s:g} {y + 90 * s:g}"/>'
    b += f'  <g clip-path="url(#{clip})" stroke="#D98A1E" stroke-width="{4 * s:g}">{lines}</g>\n'
    b += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{58 * s:g}" ry="{80 * s:g}" fill="none" {st()}/>\n'
    b += shine(x - 26 * s, y - 34 * s, 10 * s, 22 * s, 20, 0.6)
    pic.add(b, defs)


def ladybug(x: float, y: float, s: float, rot: float = 0) -> str:
    b = f'  <circle cx="0" cy="-26" r="14" fill="{OUT}"/>\n'
    b += f'  <ellipse cx="0" cy="0" rx="30" ry="32" fill="#FF4F5E" {st(4)}/>\n  <path d="M0 -30 L0 32" {st(3.5)}/>\n'
    for px, py, r in ((-14, -10, 6), (14, -10, 6), (-16, 12, 5), (16, 12, 5)):
        b += f'  <circle cx="{px}" cy="{py}" r="{r}" fill="{OUT}"/>\n'
    b += f'  <circle cx="-5" cy="-30" r="3" fill="#FFFFFF"/><circle cx="5" cy="-30" r="3" fill="#FFFFFF"/>\n'
    return at(b, x, y, s, rot)


def bee(x: float, y: float, s: float, rot: float = 0) -> str:
    b = ""
    for sx in (-1, 1):
        b += f'  <ellipse cx="{sx * 10}" cy="-24" rx="12" ry="16" transform="rotate({sx * 25} {sx * 10} -24)" fill="#FFFFFF" fill-opacity="0.85" {st(3)}/>\n'
    b += f'  <ellipse cx="0" cy="0" rx="28" ry="20" fill="#FFD23F" {st(4)}/>\n'
    b += f'  <path d="M-6 -19 Q-2 0 -6 19 M8 -18 Q12 0 8 18" stroke="{OUT}" stroke-width="7"/>\n'
    b += f'  <path d="M-28 0 L-38 0" {st(4)}/>\n'
    b += eye(16, -4, 5, (0.2, 0)) + smile(18, 6, 4, 2.5)
    return at(b, x, y, s, rot)


def basket(pic: Pic, x: float, y: float, w: float, h: float) -> tuple:
    # Hasır sepet; (x, y) alt orta. Arka kenar ve ön gövde ayrı (meyveler arasına girer)
    g1 = pic.uid("sepet")
    defs = linear(g1, [(0, "#E8B070"), (1, "#B97A44")])
    top = y - h
    back = f'  <ellipse cx="{x:g}" cy="{top:g}" rx="{w / 2:g}" ry="{h * 0.14:g}" fill="#8E5532" {st(5)}/>\n'
    back += f'  <path d="M{x - w * 0.36:g} {top:g} Q{x:g} {top - h * 1.0:g} {x + w * 0.36:g} {top:g}" fill="none" stroke="{OUT}" stroke-width="22" stroke-linecap="round"/>\n'
    back += f'  <path d="M{x - w * 0.36:g} {top:g} Q{x:g} {top - h * 1.0:g} {x + w * 0.36:g} {top:g}" fill="none" stroke="#D99A5A" stroke-width="12" stroke-linecap="round"/>\n'
    front = f'  <path d="M{x - w / 2:g} {top:g} Q{x:g} {top + h * 0.28:g} {x + w / 2:g} {top:g} L{x + w * 0.4:g} {y:g} Q{x:g} {y + h * 0.12:g} {x - w * 0.4:g} {y:g} Z" fill="url(#{g1})" {st()}/>\n'
    for k in range(1, 4):
        yy = top + k * h / 4
        ww = w / 2 - (w * 0.1) * k / 4
        front += f'  <path d="M{x - ww:g} {yy:g} Q{x:g} {yy + h * 0.22:g} {x + ww:g} {yy:g}" fill="none" stroke="#8E5532" stroke-width="4"/>\n'
    for k in range(-4, 5):
        front += f'  <path d="M{x + k * w * 0.1:g} {top + h * 0.12:g} L{x + k * w * 0.085:g} {y + h * 0.05:g}" stroke="#8E5532" stroke-width="3" opacity="0.6"/>\n'
    front += f'  <path d="M{x - w / 2:g} {top:g} Q{x:g} {top + h * 0.28:g} {x + w / 2:g} {top:g}" fill="none" stroke="#F2C88A" stroke-width="14"/>\n'
    front += f'  <path d="M{x - w / 2:g} {top:g} Q{x:g} {top + h * 0.28:g} {x + w / 2:g} {top:g}" fill="none" {st(4)}/>\n'
    return back, front, defs


def fruits() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#9ED8FF"), (1, "#E6F7FF")])
    pic.defs += linear("cayir", [(0, "#A6E47C"), (1, "#6CC453")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    pic.add(cloud(760, 100, 0.85) + cloud(1060, 200, 0.6))
    sun(pic, 1080, 90, 54)
    pic.add('  <path d="M0 440 Q300 380 600 430 Q900 380 1200 420 L1200 900 L0 900 Z" fill="url(#cayir)"/>\n')
    for tx, ty, ts in ((700, 440, 0.32), (760, 446, 0.25), (1150, 430, 0.3)):
        tree(pic, tx, ty, ts)
    # Sol üstte kiraz dalı
    pic.add(tube("M-20 60 Q160 120 330 90 Q420 76 470 40", "#9C6040", 22))
    for lx, ly, a in ((120, 80, 30), (220, 120, -20), (330, 70, 20), (420, 90, -30)):
        pic.add(f'  <ellipse cx="{lx}" cy="{ly}" rx="38" ry="16" transform="rotate({a} {lx} {ly})" fill="#5DBB4F" {st(4)}/>\n')
    for cx, cy in ((170, 200), (210, 215), (300, 180), (340, 190)):
        pic.add(f'  <path d="M{cx} {cy} Q{cx + 10} {cy - 60} {(cx // 100) * 100 + 60} {108 if cx < 250 else 92}" fill="none" stroke="#6E9A3A" stroke-width="5"/>\n')
        pic.add(f'  <circle cx="{cx}" cy="{cy}" r="22" fill="#E8283E" {st(4.5)}/>\n' + shine(cx - 7, cy - 7, 6, 3, -30, 0.9))
    pic.add(butterfly(430, 300, 1.0, "#7FD3FF", "#FFE066", -12) + bee(900, 300, 1.0, 10) + bee(990, 360, 0.7, -8))
    # Piknik örtüsü (kareli)
    clip = "ortukes"
    pic.defs += f'    <clipPath id="{clip}"><path d="M-40 640 L1240 600 L1240 920 L-40 920 Z"/></clipPath>\n'
    squares = ""
    for row in range(-2, 8):
        for col in range(-2, 22):
            if (row + col) % 2 == 0:
                squares += f'<rect x="{col * 70 - row * 6}" y="{600 + row * 50}" width="70" height="50"/>'
    pic.add(f'  <path d="M-40 640 L1240 600 L1240 920 L-40 920 Z" fill="#FFFFFF"/>\n  <g clip-path="url(#{clip})" fill="#FF6F7E" opacity="0.85">{squares}</g>\n')
    pic.add(f'  <path d="M-40 640 L1240 600" {st()}/>\n')
    # Sepet ve meyveler
    back, front, defs = basket(pic, 600, 800, 460, 230)
    pic.add(back, defs)
    grapes(pic, 460, 500, 1.1)
    pineapple(pic, 610, 410, 1.0)
    pear(pic, 770, 490, 1.0)
    apple(pic, 515, 525, 62, "#FF4F5E", True)
    orange(pic, 690, 530, 58)
    pic.add(front)
    # Muz sepetin kenarında
    pic.add(banana(640, 600, 1.25, -4))
    # Örtüdeki meyveler
    pic.add(watermelon(170, 760, 1.25, -8))
    apple(pic, 960, 760, 50, "#8ED94A")
    apple(pic, 1080, 800, 46, "#FF4F5E")
    pic.add(strawberry(330, 840, 1.0, -15) + strawberry(260, 860, 0.85, 20) + strawberry(880, 860, 0.9, 10))
    pic.add(ladybug(1110, 660, 0.9, 20) + ladybug(80, 650, 0.7, -30))
    pic.add(flower(60, 520, 0.9, "#FF6FA8") + flower(1150, 500, 0.9, "#A46BFF") + flower(400, 480, 0.8, "#FFFFFF") + flower(980, 470, 0.8, "#FFD23F"))
    pic.save("meyve")


# --- 5. Uzay (3x2) ---

def head_svg(pic: Pic, name: str, x: float, y: float, s: float) -> str:
    # animal_head gibi, ama çizimi döndürür (kırpılmış bir pencerenin içine konmak için)
    bd, b, hd, h = besle.ANIMALS[name]()
    p = pic.uid("k") + "_"
    pic.defs += prefixed(hd + besle.EYE_DEFS, p)
    return at(prefixed(h + face(name), p), x - 128 * s, y - 132 * s, s)


def sparkle_star(x: float, y: float, r: float, color: str = "#FFE680") -> str:
    d = f"M{x:g} {y - r:g} Q{x + r * 0.18:g} {y - r * 0.18:g} {x + r:g} {y:g} Q{x + r * 0.18:g} {y + r * 0.18:g} {x:g} {y + r:g} Q{x - r * 0.18:g} {y + r * 0.18:g} {x - r:g} {y:g} Q{x - r * 0.18:g} {y - r * 0.18:g} {x:g} {y - r:g} Z"
    return f'  <path d="{d}" fill="{color}"/>\n'


def moon(pic: Pic, x: float, y: float, r: float) -> None:
    gid = pic.uid("ay")
    defs = radial(gid, [(0, "#FFFBE0"), (0.6, "#F4E7A8"), (1, "#D9C77A")])
    b = f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{gid})" {st()}/>\n'
    for dx, dy, cr in ((-0.45, -0.35, 0.2), (0.4, -0.45, 0.13), (0.5, 0.35, 0.18), (-0.3, 0.55, 0.1), (0.05, -0.7, 0.08)):
        b += f'  <circle cx="{x + dx * r:g}" cy="{y + dy * r:g}" r="{cr * r:g}" fill="#E2D08A" stroke="#CDB86A" stroke-width="3"/>\n'
    # Uykulu gülen yüz
    for dx in (-0.28, 0.22):
        b += f'  <path d="M{x + (dx - 0.1) * r:g} {y + 0.02 * r:g} Q{x + dx * r:g} {y + 0.12 * r:g} {x + (dx + 0.1) * r:g} {y + 0.02 * r:g}" fill="none" {st(5)}/>\n'
    b += smile(x - 0.03 * r, y + 0.24 * r, 0.12 * r, 4.5)
    b += "".join(f'  <ellipse cx="{x + dx * r:g}" cy="{y + 0.22 * r:g}" rx="{r * 0.1:g}" ry="{r * 0.06:g}" fill="#FF9FB0" opacity="0.6"/>\n' for dx in (-0.48, 0.42))
    pic.add(b, defs)


def ringed_planet(pic: Pic, x: float, y: float, r: float) -> None:
    g1 = pic.uid("gezegen")
    defs = ten(g1, "#FF9F6A")
    rx, ry = r * 1.75, r * 0.45

    def ring(sweep: int) -> str:
        # Halkanın yarısı: sweep 1 üst (arka) yay, 0 alt (ön) yay
        arc = f"M{x - rx:g} {y:g} A{rx:g} {ry:g} 0 0 {sweep} {x + rx:g} {y:g}"
        return (f'  <g transform="rotate(-18 {x:g} {y:g})" fill="none"><path d="{arc}" stroke="{OUT}" stroke-width="26"/>'
                f'<path d="{arc}" stroke="#FFD87A" stroke-width="14"/></g>\n')
    b = ring(1)
    b += f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{g1})" {st()}/>\n'
    for dy, w in ((-0.4, 0.8), (0.05, 0.95), (0.45, 0.8)):
        b += f'  <path d="M{x - r * w:g} {y + dy * r:g} Q{x:g} {y + (dy + 0.12) * r:g} {x + r * w:g} {y + dy * r:g}" fill="none" stroke="#E87A4A" stroke-width="{r * 0.1:g}" stroke-linecap="round" opacity="0.7"/>\n'
    b += ring(0)
    b += shine(x - r * 0.45, y - r * 0.5, r * 0.22, r * 0.1, -35, 0.8)
    pic.add(b, defs)


def small_planet(pic: Pic, x: float, y: float, r: float, color: str, spots: str) -> None:
    gid = pic.uid("gezegen")
    defs = ten(gid, color)
    b = f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{gid})" {st()}/>\n'
    for dx, dy, cr in ((-0.35, -0.2, 0.25), (0.3, 0.3, 0.2), (0.25, -0.45, 0.12)):
        b += f'  <circle cx="{x + dx * r:g}" cy="{y + dy * r:g}" r="{cr * r:g}" fill="{spots}" opacity="0.7"/>\n'
    b += shine(x - r * 0.4, y - r * 0.45, r * 0.2, r * 0.09, -35, 0.8)
    pic.add(b, defs)


def earth(pic: Pic, x: float, y: float, r: float) -> None:
    gid, clip = pic.uid("dunya"), pic.uid("dunyakes")
    defs = ten(gid, "#4FA8FF") + f'    <clipPath id="{clip}"><circle cx="{x:g}" cy="{y:g}" r="{r:g}"/></clipPath>\n'
    b = f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="url(#{gid})"/>\n'
    land = (f'<path d="M{x - r * 0.8:g} {y - r * 0.3:g} Q{x - r * 0.4:g} {y - r * 0.8:g} {x:g} {y - r * 0.5:g} Q{x + r * 0.1:g} {y - r * 0.1:g} {x - r * 0.3:g} {y + r * 0.1:g} Q{x - r * 0.6:g} {y + r * 0.3:g} {x - r * 0.8:g} {y - r * 0.3:g} Z"/>'
            f'<path d="M{x + r * 0.2:g} {y + r * 0.3:g} Q{x + r * 0.7:g} {y:g} {x + r * 0.9:g} {y + r * 0.4:g} Q{x + r * 0.6:g} {y + r * 0.9:g} {x + r * 0.2:g} {y + r * 0.3:g} Z"/>')
    b += f'  <g clip-path="url(#{clip})" fill="#5CC95C">{land}</g>\n'
    b += f'  <circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="none" {st()}/>\n'
    b += shine(x - r * 0.4, y - r * 0.45, r * 0.2, r * 0.09, -35, 0.8)
    pic.add(b, defs)


def rocket(pic: Pic, x: float, y: float, s: float, rot: float) -> None:
    # Roket (yerel: burun y = -260, taban y = 160); penceresinde tavşan
    g1, g2, clip, nose = pic.uid("roket"), pic.uid("alev"), pic.uid("pencere"), pic.uid("burun")
    defs = linear(g1, [(0, "#C9D3E8"), (0.4, "#FFFFFF"), (1, "#AEB9D6")], 1, 0)
    defs += linear(g2, [(0, "#FFF3A8"), (0.5, "#FFB627"), (1, "#FF5A3E")])
    body = "M0 -260 C90 -180 100 -40 80 160 L-80 160 C-100 -40 -90 -180 0 -260 Z"
    defs += f'    <clipPath id="{nose}"><path d="{body}"/></clipPath>\n'
    b = f'  <path d="M-50 190 Q-60 290 0 380 Q60 290 50 190 Z" fill="url(#{g2})" {st(5)}/>\n'
    b += '  <path d="M-24 190 Q-28 250 0 300 Q28 250 24 190 Z" fill="#FFFBE0"/>\n'
    b += f'  <path d="M-60 160 L-50 196 L50 196 L60 160 Z" fill="#7A84A8" {st(5)}/>\n'
    for sx in (-1, 1):
        b += f'  <path d="M{sx * 78} 40 Q{sx * 150} 90 {sx * 160} 200 L{sx * 82} 160 Z" fill="#FF5A6E" {st()}/>\n'
    b += f'  <path d="{body}" fill="url(#{g1})"/>\n'
    b += f'  <g clip-path="url(#{nose})"><rect x="-120" y="-280" width="240" height="110" fill="#FF5A6E"/><rect x="-120" y="100" width="240" height="20" fill="#4A8FF0"/>'
    b += f'<path d="M-100 -170 L100 -170" fill="none" {st(5)}/></g>\n'
    b += f'  <path d="{body}" fill="none" {st()}/>\n'
    b += f'  <path d="M0 120 L0 196" {st(5)}/>\n'
    # Pencere ve tavşan
    pic.defs += f'    <clipPath id="{clip}"><circle cx="0" cy="-40" r="52"/></clipPath>\n'
    b += f'  <circle cx="0" cy="-40" r="64" fill="#4A6FE0" {st()}/>\n  <circle cx="0" cy="-40" r="52" fill="#BFE6FF"/>\n'
    b += f'  <g clip-path="url(#{clip})">\n{head_svg(pic, "tavsan", 0, -20, 0.5)}  </g>\n'
    b += '  <path d="M-34 -70 A40 40 0 0 1 10 -84" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity="0.8"/>\n'
    b += f'  <circle cx="0" cy="-40" r="52" fill="none" {st(5)}/>\n'
    b += shine(-46, -120, 10, 28, 15, 0.7)
    pic.add(at(b, x, y, s, rot), defs)


def astronaut(pic: Pic, x: float, y: float, s: float, rot: float) -> None:
    # Astronot kedi (yerel: kask ortası 0, -60)
    g1, clip = pic.uid("giysi"), pic.uid("kask")
    defs = linear(g1, [(0, "#FFFFFF"), (1, "#C9D3E8")])
    pic.defs += f'    <clipPath id="{clip}"><circle cx="0" cy="-60" r="66"/></clipPath>\n'
    b = f'  <rect x="-84" y="-30" width="40" height="120" rx="14" fill="#9AA6C6" {st(5)}/>\n'
    for sx, a in ((-1, 30), (1, -40)):
        b += tube(f"M{sx * 50} 10 Q{sx * 100} {20 if sx < 0 else -10} {sx * 110} {60 if sx < 0 else -40}", "#F4F7FF", 34)
        b += f'  <circle cx="{sx * 112}" cy="{64 if sx < 0 else -44}" r="18" fill="#FF8A3D" {st(4)}/>\n'
    for sx in (-1, 1):
        b += tube(f"M{sx * 24} 90 L{sx * 34} 150", "#F4F7FF", 36)
        b += f'  <rect x="{sx * 34 - 24}" y="140" width="48" height="26" rx="10" fill="#FF8A3D" {st(4)}/>\n'
    b += f'  <rect x="-60" y="-10" width="120" height="120" rx="40" fill="url(#{g1})" {st()}/>\n'
    b += f'  <rect x="-32" y="20" width="64" height="40" rx="8" fill="#BFE6FF" {st(4)}/>\n'
    for k, c in enumerate(["#FF5A6E", "#FFD23F", "#5CC95C"]):
        b += f'  <circle cx="{-18 + k * 18}" cy="40" r="6" fill="{c}"/>\n'
    b += f'  <circle cx="0" cy="-60" r="76" fill="#F4F7FF" {st()}/>\n  <circle cx="0" cy="-60" r="66" fill="#2A2160"/>\n'
    b += f'  <g clip-path="url(#{clip})">\n{head_svg(pic, "kedi", 0, -46, 0.6)}  </g>\n'
    b += '  <path d="M-46 -96 A56 56 0 0 1 4 -120" fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" opacity="0.75"/>\n'
    b += f'  <circle cx="0" cy="-60" r="66" fill="none" {st(5)}/>\n'
    pic.add(at(b, x, y, s, rot), defs)


def ufo(pic: Pic, x: float, y: float, s: float) -> None:
    g1, g2 = pic.uid("ufo"), pic.uid("uzayli")
    defs = linear(g1, [(0, "#D7C9FF"), (1, "#8C7BD6")]) + ten(g2, "#7FE07A")
    b = f'  <path d="M-60 40 L-110 190 L110 190 L60 40 Z" fill="#FFF3A8" opacity="0.22"/>\n'
    # Uzaylı
    b += tube("M-22 -82 Q-34 -118 -44 -126", "#7FE07A", 8, 5) + tube("M22 -82 Q34 -118 44 -126", "#7FE07A", 8, 5)
    b += f'  <circle cx="-44" cy="-128" r="9" fill="#FF8FC8" {st(3.5)}/>\n  <circle cx="44" cy="-128" r="9" fill="#FF8FC8" {st(3.5)}/>\n'
    b += f'  <ellipse cx="0" cy="-50" rx="50" ry="46" fill="url(#{g2})" {st()}/>\n'
    b += eye(-18, -58, 14, (0.1, 0.1)) + eye(18, -58, 14, (0.1, 0.1))
    b += f'  <path d="M-16 -30 Q0 -16 16 -30 Q10 -18 0 -18 Q-10 -18 -16 -30 Z" fill="#8A2A4A" {st(3.5)}/>\n'
    # Cam kubbe ve gövde
    b += '  <path d="M-80 0 Q-80 -110 0 -110 Q80 -110 80 0 Z" fill="#BFE6FF" fill-opacity="0.35"/>\n'
    b += f'  <path d="M-80 0 Q-80 -110 0 -110 Q80 -110 80 0" fill="none" {st()}/>\n'
    b += '  <path d="M-56 -60 Q-50 -90 -20 -98" fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" opacity="0.8"/>\n'
    b += f'  <ellipse cx="0" cy="10" rx="160" ry="44" fill="url(#{g1})" {st()}/>\n'
    b += f'  <ellipse cx="0" cy="-2" rx="96" ry="16" fill="#B6A6F0" {st(4)}/>\n'
    for k, c in enumerate(["#FFD23F", "#FF5A6E", "#5CC95C", "#4FA8FF", "#FFD23F"]):
        b += f'  <circle cx="{-110 + k * 55}" cy="{22 + (6 if k in (1, 3) else 0) - (6 if k == 2 else 0)}" r="10" fill="{c}" {st(3.5)}/>\n'
    pic.add(at(b, x, y, s, -8), defs)


def comet(x: float, y: float, s: float) -> str:
    b = '  <path d="M0 -18 Q-140 -30 -260 -60 Q-150 0 -260 60 Q-140 30 0 18 Z" fill="#FFFFFF" opacity="0.35"/>\n'
    b += '  <path d="M0 -12 Q-110 -20 -200 -36 Q-110 0 -200 36 Q-110 20 0 12 Z" fill="#FFE680" opacity="0.6"/>\n'
    b += f'  <circle cx="0" cy="0" r="22" fill="#FFF3A8" {st(5)}/>\n'
    return at(b, x, y, s, 22)


def space() -> None:
    pic = Pic()
    pic.defs += linear("uzay", [(0, "#1B1440"), (0.6, "#2E2468"), (1, "#45348E")])
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#uzay)"/>\n')
    # Bulutsular
    for cx, cy, rx, ry, c in ((260, 520, 300, 160, "#A46BFF"), (900, 420, 340, 180, "#FF6FB5"), (700, 820, 400, 140, "#4FA8FF")):
        pic.add(f'  <ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{c}" opacity="0.18"/>\n')
    rng = random.Random(31)
    for k in range(120):
        pic.add(f'  <circle cx="{rng.uniform(0, W):.1f}" cy="{rng.uniform(0, H):.1f}" r="{rng.uniform(1.2, 3.2):.1f}" fill="#FFFFFF" opacity="{rng.uniform(0.5, 1):.2f}"/>\n')
    for k in range(16):
        pic.add(sparkle_star(rng.uniform(20, W - 20), rng.uniform(20, H - 20), rng.uniform(10, 22)))
    pic.add(comet(560, 90, 0.9))
    moon(pic, 190, 180, 105)
    ringed_planet(pic, 1010, 210, 100)
    small_planet(pic, 470, 790, 56, "#5DD39E", "#3FA878")
    earth(pic, 1120, 830, 70)
    small_planet(pic, 760, 420, 26, "#FF8FC8", "#E86AA0")
    rocket(pic, 620, 340, 1.05, 18)
    astronaut(pic, 210, 640, 0.95, -14)
    ufo(pic, 960, 610, 0.95)
    pic.save("uzay")


# --- 6. Orman (3x2) ---

def owl(x: float, y: float, s: float) -> str:
    b = ""
    for sx in (-1, 1):
        b += f'  <path d="M{sx * 30} -60 L{sx * 44} -96 L{sx * 10} -70 Z" fill="#A86A3E" {st(4.5)}/>\n'
    b += f'  <ellipse cx="0" cy="0" rx="58" ry="72" fill="#A86A3E" {st()}/>\n'
    b += f'  <ellipse cx="0" cy="22" rx="36" ry="44" fill="#F2D2A6"/>\n'
    for px, py in ((-14, 10), (8, 14), (-6, 34), (16, 38), (-16, 54), (6, 58)):
        b += f'  <path d="M{px - 6} {py} L{px} {py + 6} L{px + 6} {py}" fill="none" stroke="#C99A6A" stroke-width="3" stroke-linecap="round"/>\n'
    for sx in (-1, 1):
        b += f'  <path d="M{sx * 50} -10 Q{sx * 74} 30 {sx * 46} 60 Q{sx * 40} 20 {sx * 50} -10 Z" fill="#8E5532" {st(4)}/>\n'
        b += f'  <circle cx="{sx * 24}" cy="-30" r="24" fill="#F2D2A6" {st(4)}/>\n'
        b += eye(sx * 24, -30, 15, (0.05, 0.1))
    b += f'  <path d="M-8 -14 L8 -14 L0 2 Z" fill="#FFB43A" {st(3.5)}/>\n'
    for sx in (-1, 1):
        b += f'  <path d="M{sx * 18} 70 l-6 10 M{sx * 18} 70 l0 12 M{sx * 18} 70 l6 10" stroke="#FFB43A" stroke-width="5" stroke-linecap="round"/>\n'
    return at(b, x, y, s)


def beehive(x: float, y: float, s: float) -> str:
    b = f'  <path d="M0 -150 L0 -110" {st(6)}/>\n'
    for k, (w, yy) in enumerate(((40, -100), (64, -66), (80, -26), (74, 14), (50, 48))):
        b += f'  <ellipse cx="0" cy="{yy}" rx="{w}" ry="26" fill="{"#FFC233" if k % 2 == 0 else "#F0A82A"}" {st(5)}/>\n'
    b += f'  <ellipse cx="0" cy="-6" rx="18" ry="14" fill="{OUT}"/>\n'
    b += shine(-36, -60, 14, 6, -20, 0.7)
    b += f'  <path d="M30 40 Q34 70 30 84 Q24 74 26 60" fill="#FFB627" {st(3.5)}/>\n'
    return at(b, x, y, s)


def mushroom(x: float, y: float, s: float, color: str = "#FF4F5E") -> str:
    b = f'  <path d="M-22 0 Q-26 -50 -16 -70 L16 -70 Q26 -50 22 0 Z" fill="#FFF4E0" {st(5)}/>\n'
    b += f'  <path d="M-80 -60 Q-80 -150 0 -150 Q80 -150 80 -60 Q40 -70 0 -70 Q-40 -70 -80 -60 Z" fill="{color}" {st()}/>\n'
    for px, py, r in ((-44, -96, 12), (0, -124, 14), (42, -98, 11), (-14, -84, 8), (22, -80, 7)):
        b += f'  <circle cx="{px}" cy="{py}" r="{r}" fill="#FFFFFF"/>\n'
    b += shine(-40, -126, 14, 6, -30, 0.7)
    return at(b, x, y, s)


def hedgehog(x: float, y: float, s: float) -> str:
    spikes = "M-90 0"
    for k in range(13):
        a = math.pi + k * math.pi / 12
        r1, r2 = 90, 116
        spikes += f" L{r2 * math.cos(a - 0.12):.1f} {r2 * math.sin(a - 0.12) * 0.9:.1f} L{r1 * math.cos(a + 0.06):.1f} {r1 * math.sin(a + 0.06) * 0.9:.1f}"
    spikes += " L90 0 Z"
    b = f'  <path d="{spikes}" fill="#8E5532" {st(5)}/>\n'
    b += f'  <path d="M40 0 Q60 -60 110 -20 Q130 -4 112 6 Q80 14 40 0 Z" fill="#F2D2A6" {st(5)}/>\n'
    b += f'  <circle cx="122" cy="-6" r="9" fill="{OUT}"/>\n'
    b += eye(84, -24, 9, (0.2, 0))
    b += f'  <ellipse cx="96" cy="-6" rx="8" ry="5" fill="#FF9FB0" opacity="0.7"/>\n'
    for px in (-40, 0, 50):
        b += f'  <ellipse cx="{px}" cy="2" rx="14" ry="8" fill="#C7864F" {st(3.5)}/>\n'
    return at(b, x, y, s)


def frog(x: float, y: float, s: float) -> str:
    b = f'  <ellipse cx="0" cy="20" rx="120" ry="34" fill="#5DBB4F" {st(5)}/>\n'
    b += f'  <path d="M0 20 L60 4 L70 24 Z" fill="#7BD3F5"/>\n'
    b += f'  <ellipse cx="0" cy="-10" rx="58" ry="42" fill="#7FD06A" {st()}/>\n'
    for sx in (-1, 1):
        b += f'  <circle cx="{sx * 30}" cy="-46" r="22" fill="#7FD06A" {st(5)}/>\n'
        b += eye(sx * 30, -48, 13, (0, 0.05))
        b += f'  <ellipse cx="{sx * 54}" cy="18" rx="22" ry="12" fill="#6CC453" {st(4)}/>\n'
    b += smile(0, -8, 26, 5)
    b += "".join(f'  <ellipse cx="{sx * 40}" cy="-6" rx="10" ry="6" fill="#FF9FB0" opacity="0.6"/>\n' for sx in (-1, 1))
    return at(b, x, y, s)


def honey_pot(x: float, y: float, s: float) -> str:
    b = f'  <path d="M-46 -60 Q-70 -20 -50 20 Q-40 40 0 40 Q40 40 50 20 Q70 -20 46 -60 Z" fill="#C7864F" {st()}/>\n'
    b += f'  <rect x="-52" y="-74" width="104" height="20" rx="8" fill="#A86A3E" {st(5)}/>\n'
    b += f'  <path d="M-48 -64 Q-40 -40 -30 -56 Q-20 -30 -8 -56 Q4 -36 16 -56 Q28 -40 40 -60 Q48 -66 48 -70 L-48 -70 Z" fill="#FFC233" {st(4)}/>\n'
    b += f'  <path d="M-30 -10 L30 -10 L30 14 L-30 14 Z" fill="#FFF3DC" {st(3.5)}/>\n'
    b += f'  <path d="M-8 2 Q0 -8 8 2 Q0 10 -8 2 Z" fill="#FFC233"/>\n'
    return at(b, x, y, s)


def forest() -> None:
    pic = Pic()
    pic.defs += linear("gok", [(0, "#D7F5B8"), (1, "#F6FCE6")])
    pic.defs += linear("zemin", [(0, "#8ED96A"), (1, "#5DB64C")])
    pic.defs += linear("gol", [(0, "#8FDCFF"), (1, "#4FB2EE")])
    pic.defs += linear("kutuk", [(0, "#B9784A"), (1, "#7A4528")], 1, 0)
    pic.add(f'  <rect width="{W}" height="{H}" fill="url(#gok)"/>\n')
    # Işık huzmeleri ve uzak ağaçlar
    for x0 in (560, 760, 940):
        pic.add(f'  <path d="M{x0} 0 L{x0 + 70} 0 L{x0 - 80} 900 L{x0 - 200} 900 Z" fill="#FFFBD0" opacity="0.4"/>\n')
    for k, tx in enumerate(range(260, 1200, 150)):
        pic.add(f'  <rect x="{tx}" y="200" width="34" height="520" fill="#BFE3A0"/>\n  <circle cx="{tx + 17}" cy="210" r="{90 + (k % 2) * 20}" fill="#B2DE90"/>\n')
    pic.add('  <path d="M0 690 Q300 650 600 690 Q900 640 1200 680 L1200 900 L0 900 Z" fill="url(#zemin)"/>\n')
    # Sol: büyük ağaç, kovuğunda baykuş
    pic.add(f'  <path d="M40 900 Q70 600 60 0 L230 0 Q220 600 260 900 Z" fill="url(#kutuk)" {st()}/>\n')
    for yy in (120, 420, 620):
        pic.add(f'  <path d="M100 {yy} Q120 {yy + 40} 104 {yy + 90}" fill="none" stroke="#6E3E22" stroke-width="5" stroke-linecap="round"/>\n')
    pic.add(f'  <ellipse cx="150" cy="300" rx="74" ry="96" fill="#4A2A18" {st()}/>\n')
    pic.add(owl(150, 300, 0.95))
    # Üst: dallar ve yapraklar
    pic.add(tube("M200 120 Q500 150 760 90 Q900 60 1210 70", "#9C6040", 30))
    pic.add(tube("M760 300 Q900 280 1210 250", "#9C6040", 26))
    rng = random.Random(41)
    for k in range(26):
        lx, ly = rng.uniform(230, 1200), rng.choice([rng.uniform(40, 150), rng.uniform(230, 300)])
        if ly > 200 and lx < 760:
            continue
        a = rng.uniform(-40, 40)
        pic.add(f'  <ellipse cx="{lx:.0f}" cy="{ly:.0f}" rx="34" ry="15" transform="rotate({a:.0f} {lx:.0f} {ly:.0f})" fill="{rng.choice(["#5DBB4F", "#7FD06A", "#4FA544"])}" {st(4)}/>\n')
    pic.add(beehive(560, 280, 1.0))
    pic.add(bee(450, 260, 0.8, -10) + bee(680, 330, 0.9, 12) + bee(620, 190, 0.7, 5))
    animal(pic, "sincap", 1000, 250, 0.75)
    pic.add(butterfly(860, 430, 0.9, "#FF8FC8", "#FFB84D", 15))
    # Alt: mantarlar, kirpi, ayı ve bal, gölet ve kurbağa
    for bx, by, br in ((330, 700, 70), (420, 690, 56), (790, 700, 64), (870, 690, 50), (250, 720, 48)):
        pic.add(f'  <circle cx="{bx}" cy="{by}" r="{br}" fill="#6CC453" {st(5)}/>\n' + shine(bx - br * 0.4, by - br * 0.45, br * 0.25, br * 0.1, -30, 0.4))
    pic.add(mushroom(110, 860, 0.7) + mushroom(200, 880, 0.45, "#FF8A3D"))
    pic.add(hedgehog(380, 860, 0.8))
    animal(pic, "ayi", 600, 880, 1.45)
    pic.add(honey_pot(800, 860, 0.85))
    pic.add(f'  <ellipse cx="1030" cy="830" rx="190" ry="60" fill="url(#gol)" {st()}/>\n')
    pic.add('  <path d="M900 820 Q960 806 1020 820 M1040 846 Q1100 834 1150 846" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.7"/>\n')
    for cx in (870, 1190):
        pic.add(tube(f"M{cx} 860 Q{cx + 6} 760 {cx - 4} 680", "#5DBB4F", 8, 5))
        pic.add(f'  <rect x="{cx - 14}" y="650" width="22" height="56" rx="11" fill="#8E5532" {st(4)}/>\n')
    pic.add(frog(1040, 800, 0.75))
    for k in range(10):
        fx = rng.uniform(260, 860)
        pic.add(tuft(fx, rng.uniform(860, 895), 0.9))
    pic.add(flower(460, 860, 0.8, "#FFFFFF") + flower(880, 700, 0.8, "#FF6FA8") + flower(300, 870, 0.7, "#FFD23F"))
    pic.save("orman")


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
    train()
    fruits()
    space()
    forest()
