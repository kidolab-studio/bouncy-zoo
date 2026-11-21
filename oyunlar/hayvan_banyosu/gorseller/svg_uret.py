# Hayvan Banyosu SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: python svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Stil ve yardımcılar Hayvanları Besle'nin svg_uret.py'sinden (oradan içe aktarılır, o dosyaya dokunulmaz):
# koyu mor kalın hat, radyal gradyanlı parlak dolgular, beyaz parıltılar.
#
# - hayvanlar/<ad>_govde.svg, <ad>_kafa.svg: Hayvanları Besle'deki çizim fonksiyonlarıyla aynı (256 tuval;
#   göz ve ağız yok, onları hayvan_yuzu.gd çizer). Yüz yerleri FACES (Besle) ile aynı.
# - Aletler: sunger (sünger), dus (el duşu; su başlığın ortasından aşağı akar: DUS_NOZZLE), havlu.
# - Banyo: kuvet_arka (kenarın arkası ve suyun arka yarısı; hayvanın arkasında), kuvet_on (suyun ön yarısı,
#   ön kenar ve küvet gövdesi; hayvanın önünde). Suyun merkezi iki dosyada da aynı yerde: TUB_WATER.
# - Lekeler: camur_1..3 (çamur), kopuk (köpük bulutu), damla (su damlası), kabarcik (sabun kabarcığı).
# - kart_kopek.svg: başında köpükle mutlu köpek (ana menü kartı ve final ekranındaki karakter).
# yildiz.svg, isilti.svg, kalp.svg Hayvanları Besle'den kopya.

import importlib.util
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")

_spec = importlib.util.spec_from_file_location("besle_svg", os.path.join(GAMES, "hayvan_besle", "gorseller", "svg_uret.py"))
besle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(besle)

OUT = besle.OUT
st, shine, radial, linear, ten, light, dark = besle.st, besle.shine, besle.radial, besle.linear, besle.ten, besle.light, besle.dark

# Godot tarafındaki sabitlerle aynı (alet.gd, arka_plan.gd)
DUS_NOZZLE = (92, 196)          # dus.svg içinde suyun çıktığı nokta (240x240)
TUB_SIZE = (640, 280)           # kuvet_on.svg; kuvet_arka.svg 640x130
TUB_WATER = (320, 64, 282, 40)  # suyun elipsi (cx, cy, rx, ry), iki dosyada aynı


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


def blob(cx: float, cy: float, r: float, bumps: int, wobble: float, seed: int, points: int = 48) -> str:
    # Yumuşak, tümsekli kapalı şekil (çamur lekesi, köpük): yarıçap açıyla dalgalanır
    rnd = random.Random(seed)
    phases = [rnd.uniform(0, math.tau) for _ in range(3)]
    pts = []
    for k in range(points):
        a = math.tau * k / points
        rr = r * (1 + wobble * math.sin(bumps * a + phases[0]) + wobble * 0.5 * math.sin((bumps + 2) * a + phases[1]))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    # Noktalardan yumuşak eğri (Catmull-Rom → kübik Bezier)
    d = "M%.1f %.1f " % pts[0]
    n = len(pts)
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += "C%.1f %.1f %.1f %.1f %.1f %.1f " % (c1 + c2 + p2)
    return d + "Z"


# --- Hayvanlar (Besle'deki çizimler) ---

def animals() -> None:
    for name, draw in besle.ANIMALS.items():
        bd, b, hd, h = draw()
        write(f"hayvanlar/{name}_govde.svg", 256, 256, b, bd)
        write(f"hayvanlar/{name}_kafa.svg", 256, 256, h, hd)


# --- Lekeler ---

def mud() -> None:
    # Üç farklı çamur lekesi (128x128): koyu kahve leke, açık kahve parlak yer, çevresinde küçük sıçramalar
    defs = radial("camur", [(0, "#B07A48"), (0.6, "#8A5A30"), (1, "#6B4222")], 0.4, 0.35, 0.75)
    for k in range(3):
        rnd = random.Random(40 + k)
        body = f'  <path d="{blob(64, 64, 40, 3 + k % 2, 0.09, 10 + k)}" fill="url(#camur)" stroke="#5A3A20" stroke-width="4"/>\n'
        for _ in range(3):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(48, 56)
            r = rnd.uniform(5, 8)
            body += (f'  <circle cx="{64 + d * math.cos(a):.1f}" cy="{64 + d * math.sin(a):.1f}" r="{r:.1f}" '
                     f'fill="#7A4C28" stroke="#5A3A20" stroke-width="3"/>\n')
        body += f'  <path d="{blob(52, 50, 13, 3, 0.2, 20 + k)}" fill="#C49260" opacity="0.7"/>\n'
        body += '  <ellipse cx="46" cy="44" rx="7" ry="4" transform="rotate(-30 46 44)" fill="#FFFFFF" opacity="0.45"/>\n'
        write(f"camur_{k + 1}.svg", 128, 128, body, defs)


def foam() -> None:
    # Köpük bulutu (128x128): beyaz, hafif mavi gölgeli, üst üste daireler
    defs = radial("kopuk", [(0, "#FFFFFF"), (0.7, "#FFFFFF"), (1, "#DCE8F8")], 0.4, 0.3, 0.8)
    circles = [(64, 66, 34), (36, 72, 22), (92, 72, 22), (50, 44, 20), (80, 44, 21), (64, 92, 20), (30, 52, 13), (100, 50, 13)]
    shapes = "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in circles)
    body = f'  <g fill="#B8CCE8" stroke="#B8CCE8" stroke-width="7">{shapes}</g>\n'
    body += f'  <g fill="url(#kopuk)">{shapes}</g>\n'
    for x, y, r in circles[:6]:
        body += f'  <path d="M{x - r * 0.55:.1f} {y - r * 0.2:.1f} A{r * 0.6:.1f} {r * 0.6:.1f} 0 0 1 {x - r * 0.1:.1f} {y - r * 0.6:.1f}" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.9"/>\n'
    for x, y, r in ((44, 40, 6), (86, 62, 5), (60, 86, 5)):
        body += f'  <circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="#9EC3EE" stroke-width="2.5"/>\n'
    write("kopuk.svg", 128, 128, body, defs)


def drop() -> None:
    # Su damlası (48x64): ucu yukarıda
    defs = radial("damla", [(0, "#E6F6FF"), (0.5, "#8FD3FF"), (1, "#3D9BE9")], 0.4, 0.55, 0.7)
    body = f'  <path d="M24 4 C30 18 42 30 42 42 A18 18 0 0 1 6 42 C6 30 18 18 24 4 Z" fill="url(#damla)" stroke="#2F6FB5" stroke-width="4" stroke-linejoin="round"/>\n'
    body += '  <ellipse cx="17" cy="40" rx="4" ry="7" fill="#FFFFFF" opacity="0.85"/>\n'
    write("damla.svg", 48, 64, body, defs)


def bubble() -> None:
    # Sabun kabarcığı (64x64): saydam, gökkuşağı kenarlı, parlak
    defs = radial("kabarcik", [(0, "#FFFFFF", ), (0.75, "#E9F6FF"), (1, "#B5D8FF")], 0.5, 0.5, 0.5)
    defs = defs.replace('stop-color="#FFFFFF"/>', 'stop-color="#FFFFFF" stop-opacity="0.1"/>', 1)
    defs = defs.replace('stop-color="#E9F6FF"/>', 'stop-color="#E9F6FF" stop-opacity="0.25"/>')
    body = '  <circle cx="32" cy="32" r="27" fill="url(#kabarcik)" stroke="#8CC4F2" stroke-width="3"/>\n'
    body += '  <path d="M14 26 A20 20 0 0 1 28 12" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>\n'
    body += '  <path d="M44 50 A20 20 0 0 0 52 40" fill="none" stroke="#F7B8E6" stroke-width="3" stroke-linecap="round" opacity="0.8"/>\n'
    body += '  <circle cx="40" cy="18" r="3" fill="#FFFFFF"/>\n'
    write("kabarcik.svg", 64, 64, body, defs)


# --- Aletler ---

def sponge() -> None:
    # Sünger (200x150): sarı gövde, üstte yeşil sert yüz, delikler, üstünde birkaç kabarcık
    defs = linear("sunger", [(0, "#FFE77A"), (1, "#FFC93D")]) + linear("yesil", [(0, "#7EDB7A"), (1, "#3FAE5C")])
    body = f'  <rect x="18" y="58" width="164" height="78" rx="24" fill="url(#sunger)" {st()}/>\n'
    body += f'  <rect x="18" y="40" width="164" height="34" rx="16" fill="url(#yesil)" {st()}/>\n'
    for x, y, rx, ry in ((50, 96, 9, 7), (88, 112, 7, 5), (122, 92, 10, 7), (156, 114, 8, 6), (68, 122, 5, 4), (140, 124, 5, 4)):
        body += f'  <ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#E8A92A"/>\n'
    body += shine(50, 50, 18, 5, -8, 0.6)
    for x, y, r in ((60, 30, 15), (86, 22, 11), (132, 28, 16), (158, 22, 9)):
        body += f'  <circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" stroke="#B8CCE8" stroke-width="4"/>\n'
    write("sunger.svg", 200, 150, body, defs)


def shower() -> None:
    # El duşu (240x240): başlık aşağı bakar (su DUS_NOZZLE'dan çıkar), sap sağ üste uzanır
    nx, ny = DUS_NOZZLE
    defs = linear("krom", [(0, "#FFFFFF"), (0.5, "#CFE3F5"), (1, "#8FB0D6")], 1, 1)
    defs += radial("basl", [(0, "#FFFFFF"), (0.6, "#DCEBFA"), (1, "#9BB8DD")], 0.4, 0.3, 0.8)
    body = f'  <path d="M{nx + 20} {ny - 66} Q{nx + 70} {ny - 120} {nx + 128} {ny - 168}" fill="none" stroke="{OUT}" stroke-width="40" stroke-linecap="round"/>\n'
    body += f'  <path d="M{nx + 20} {ny - 66} Q{nx + 70} {ny - 120} {nx + 128} {ny - 168}" fill="none" stroke="url(#krom)" stroke-width="27" stroke-linecap="round"/>\n'
    body += f'  <path d="M{nx + 44} {ny - 96} Q{nx + 76} {ny - 126} {nx + 112} {ny - 154}" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" opacity="0.8"/>\n'
    # Başlık: üstte dar boyun, altta geniş yüz (perspektifli elips)
    body += f'  <path d="M{nx - 26} {ny - 70} L{nx + 26} {ny - 70} L{nx + 66} {ny - 4} L{nx - 66} {ny - 4} Z" fill="url(#basl)" {st()}/>\n'
    body += f'  <ellipse cx="{nx}" cy="{ny - 4}" rx="66" ry="18" fill="#9BC7F0" {st()}/>\n'
    for k in range(-2, 3):
        for row in (-1, 1):
            if row == 1 and abs(k) == 2:
                continue
            body += f'  <circle cx="{nx + k * 22 + (11 if row == 1 else 0)}" cy="{ny - 4 + row * 6}" r="3.5" fill="#2F6FB5"/>\n'
    body += shine(nx - 26, ny - 48, 12, 6, -60, 0.8)
    write("dus.svg", 240, 240, body, defs)


def towel() -> None:
    # Katlanmış havlu (220x170): pembe, iki beyaz şerit, altta saçak
    defs = linear("havlu", [(0, "#FFC2DC"), (1, "#FF8FBE")])
    body = f'  <path d="M20 40 Q20 24 36 24 H184 Q200 24 200 40 V140 Q200 150 190 150 H30 Q20 150 20 140 Z" fill="url(#havlu)" {st()}/>\n'
    for y in (98, 118):
        body += f'  <rect x="22" y="{y}" width="176" height="9" fill="#FFFFFF" opacity="0.9"/>\n'
    body += f'  <path d="M20 66 H200" fill="none" stroke="#E5679C" stroke-width="5" stroke-linecap="round"/>\n'
    for x in range(36, 190, 16):
        body += f'  <path d="M{x} 150 V164" {st(5)}/>\n'
    body += shine(60, 40, 26, 6, -4, 0.55)
    write("havlu.svg", 220, 170, body, defs)


# --- Küvet ---

def tub() -> None:
    w, h = TUB_SIZE
    cx, cy, rx, ry = TUB_WATER
    rim = 22
    defs = ""
    # Arka: kenarın tamamı ve suyun arka yarısı (hayvanın arkasında)
    back = f'  <ellipse cx="{cx}" cy="{cy}" rx="{rx + rim}" ry="{ry + rim * 0.7:.1f}" fill="#FFFFFF" {st()}/>\n'
    back += f'  <ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#A6DDF9" {st(5)}/>\n'
    write("kuvet_arka.svg", w, 130, back, defs)
    # Ön: suyun ön yarısı + ön kenar + gövde + ayaklar (hayvanın önünde)
    defs = linear("kuvet", [(0, "#FFFFFF"), (0.6, "#F2F8FF"), (1, "#C9DEF5")])
    defs += radial("ayak", [(0, "#FFF0A8"), (0.6, "#FFC93D"), (1, "#E09A1E")])
    orx, ory = rx + rim, ry + rim * 0.7
    body = ""
    for x in (cx - orx * 0.72, cx + orx * 0.72):
        body += f'  <ellipse cx="{x:.1f}" cy="{h - 22}" rx="30" ry="20" fill="url(#ayak)" {st(6)}/>\n'
    tub_body = (f"M{cx - orx} {cy} A{orx} {ory:.1f} 0 0 0 {cx + orx} {cy} "
                f"C{cx + orx - 4} {cy + 110} {cx + orx - 40} {h - 34} {cx + orx - 120} {h - 34} "
                f"H{cx - orx + 120} C{cx - orx + 40} {h - 34} {cx - orx + 4} {cy + 110} {cx - orx} {cy} Z")
    body += f'  <path d="{tub_body}" fill="url(#kuvet)" {st()}/>\n'
    # Suyun ön yarısı: iç elipsin alt yarısı (kenarın içinde)
    # (kesik kenarı çizgisiz: hayvanın olmadığı yerde arka yarıyla birleşik görünür)
    body += f'  <path d="M{cx - rx} {cy} A{rx} {ry} 0 0 0 {cx + rx} {cy} Z" fill="#A6DDF9"/>\n'
    body += f'  <path d="M{cx - rx} {cy} A{rx} {ry} 0 0 0 {cx + rx} {cy}" fill="none" {st(5)}/>\n'
    # Köpükler: ön kenar boyunca ve ortada, hayvanın suya girdiği çizgide (kesik kenarı da örter)
    rnd = random.Random(7)
    foam = ""
    for k in range(17):
        t = k / 16
        a = math.pi * (1 - t)
        x = cx + rx * 0.96 * math.cos(a)
        y = cy + ry * 0.55 * math.sin(a) - 6
        r = rnd.uniform(13, 21) * (0.75 + 0.25 * math.sin(math.pi * t))
        foam += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}"/>'
    for k in range(9):
        x = cx + (k - 4) * 26 + rnd.uniform(-5, 5)
        foam += f'<circle cx="{x:.1f}" cy="{cy + rnd.uniform(-2, 6):.1f}" r="{rnd.uniform(14, 20) * (1 - abs(k - 4) * 0.08):.1f}"/>'
    body += f'  <g fill="#B8CCE8" stroke="#B8CCE8" stroke-width="7">{foam}</g>\n  <g fill="#FFFFFF">{foam}</g>\n'
    # Kenar parıltısı ve gövdede iki yumuşak çizgi
    body += f'  <path d="M{cx - orx + 40} {cy + 70} Q{cx - orx + 60} {cy + 140} {cx - orx + 130} {cy + 160}" fill="none" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.9"/>\n'
    body += f'  <path d="M{cx - 160} {cy + 150} H{cx + 160}" fill="none" stroke="#B5CFF0" stroke-width="6" stroke-linecap="round" opacity="0.7"/>\n'
    write("kuvet_on.svg", w, h, body, defs)


# --- Kart karakteri ---

def card_dog() -> None:
    # Ana menü kartı ve final ekranı: başında köpük, gözleri mutlu kapalı, ağzı açık gülen köpek
    bd, b, hd, h = besle.dog()
    face_data = besle.FACES["kopek"]
    y, dx, rx, ry = face_data["eye"]
    face = ""
    for x in (128 - dx, 128 + dx):
        face += f'  <path d="M{x - rx} {y + 4} Q{x} {y - ry - 2} {x + rx} {y + 4}" fill="none" {st(6)}/>\n'
    cy, cdx = face_data["cheek"]
    face += "".join(f'  <ellipse cx="{x:g}" cy="{cy:g}" rx="17" ry="10" fill="url(#yanak)"/>\n' for x in (128 - cdx, 128 + cdx))
    my = face_data["mouth"][0]
    face += (f'  <path d="M112 {my} Q128 {my - 3} 144 {my} Q142 {my + 22} 128 {my + 22} Q114 {my + 22} 112 {my} Z" fill="#8A2A4A" {st(5)}/>\n'
             f'  <path d="M118 {my + 14} Q128 {my + 8} 138 {my + 14} Q136 {my + 20} 128 {my + 20} Q120 {my + 20} 118 {my + 14} Z" fill="#FF8FB0"/>\n')
    circles = [(108, 70, 22), (134, 62, 26), (160, 74, 18), (88, 80, 14), (124, 84, 14), (150, 88, 12)]
    shapes = "".join(f'<circle cx="{x}" cy="{yy}" r="{r}"/>' for x, yy, r in circles)
    foam = f'  <g fill="#B8CCE8" stroke="#B8CCE8" stroke-width="7">{shapes}</g>\n  <g fill="#FFFFFF">{shapes}</g>\n'
    foam += '  <path d="M118 56 A16 16 0 0 1 132 46" fill="none" stroke="#DCE8F8" stroke-width="5" stroke-linecap="round"/>\n'
    defs = bd + hd.replace(ten("ten", "#E8A45C"), "") + besle.EYE_DEFS
    write("kart_kopek.svg", 256, 256, b + h + face + foam, defs)


if __name__ == "__main__":
    animals()
    mud()
    foam()
    drop()
    bubble()
    sponge()
    shower()
    towel()
    tub()
    card_dog()
    copy("hayvan_besle/gorseller/yildiz.svg", "yildiz.svg")
    copy("hayvan_besle/gorseller/isilti.svg", "isilti.svg")
    copy("hayvan_besle/gorseller/kalp.svg", "kalp.svg")
