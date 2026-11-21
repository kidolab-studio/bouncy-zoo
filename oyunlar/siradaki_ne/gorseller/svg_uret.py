# Sıradaki Ne? SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: python svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Stil ve yardımcılar Hayvanları Besle'nin svg_uret.py'sinden (oradan içe aktarılır, o dosyaya dokunulmaz):
# koyu mor kalın hat, radyal gradyanlı parlak dolgular, beyaz parıltılar.
#
# - parcalar/: dizideki ve tepsideki parçalar (dosya adı = ayarlar.gd'deki parça adı)
#     boncuk_<şekil>_<renk>  (160 tuval; şekil: yuvarlak, kup, yildiz, kalp)
#     bayrak_<şekil>_<renk>  (160 tuval; üst kenar y = FLAG_TOP'ta ipe asılı; şekil: ucgen, kare, kirlangic, dalga)
#     cicek_<tür>            (160 tuval; sap dibi y = FLOWER_BASE; lale_<renk>, papatya, aycicegi, menekse)
#     tirtil_<renk>          (160 tuval; tırtılın gövde halkası, altta ayaklar)
#     hayvan_<ad>            (256 tuval; Besle'deki gövde + kafa, yüzü çizilmiş, gülen)
#   Boncuk, bayrak ve tırtılda her rengin kendi iç işareti var (MARKS; renk körü çocuklar için).
# - tirtil_bas.svg (tırtılın başı, sola bakar), yuva.svg (boş yuva: kesik çizgili halka ve soru işareti),
#   kelebek.svg, kart_tirtil.svg (ana menü kartı ve final ekranının karakteri).
# - arka_plan_<tema>.svg (1280x720; zemin çizgisi y = 520, ayarlar.gd FLOOR_Y).
# yildiz.svg, isilti.svg Hayvanları Besle'den kopya.

import importlib.util
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")

_spec = importlib.util.spec_from_file_location("besle_svg", os.path.join(GAMES, "hayvan_besle", "gorseller", "svg_uret.py"))
besle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(besle)

OUT = besle.OUT
st, shine, radial, linear, ten, light, dark = besle.st, besle.shine, besle.radial, besle.linear, besle.ten, besle.light, besle.dark

# ayarlar.gd ile aynı adlar
COLORS = {"kirmizi": "#FF5A64", "mavi": "#4A8FF0", "sari": "#FFD23F", "yesil": "#3FBF62", "mor": "#A46BFF"}
ANIMALS = ["kedi", "tavsan", "inek", "fare", "ayi", "panda"]
# Godot tarafındaki sabitlerle aynı (tema_bayrak.gd, tema_bahce.gd)
FLAG_TOP = 16
FLOWER_BASE = 154


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


def star_points(cx: float, cy: float, r_out: float, r_in: float, n: int = 5, rot: float = -90) -> str:
    pts = []
    for k in range(n * 2):
        r = r_out if k % 2 == 0 else r_in
        a = math.radians(rot + k * 180 / n)
        pts.append("%.1f,%.1f" % (cx + r * math.cos(a), cy + r * math.sin(a)))
    return " ".join(pts)


def heart(cx: float, cy: float, s: float) -> str:
    # s: yarı genişlik
    return (f"M{cx:g} {cy + s * 0.95:g} C{cx - s * 0.2:g} {cy + s * 0.75:g} {cx - s:g} {cy + s * 0.25:g} {cx - s:g} {cy - s * 0.25:g} "
            f"C{cx - s:g} {cy - s * 0.8:g} {cx - s * 0.3:g} {cy - s * 0.95:g} {cx:g} {cy - s * 0.5:g} "
            f"C{cx + s * 0.3:g} {cy - s * 0.95:g} {cx + s:g} {cy - s * 0.8:g} {cx + s:g} {cy - s * 0.25:g} "
            f"C{cx + s:g} {cy + s * 0.25:g} {cx + s * 0.2:g} {cy + s * 0.75:g} {cx:g} {cy + s * 0.95:g} Z")


def mark(color: str, cx: float, cy: float, s: float) -> str:
    # Rengin iç işareti (açık tonla): kırmızı nokta, mavi iki çizgi, sarı zikzak, yeşil baklava, mor halka
    c = light(COLORS[color], 0.62)
    if color == "kirmizi":
        return f'  <circle cx="{cx:g}" cy="{cy:g}" r="{s * 0.34:g}" fill="{c}"/>\n'
    if color == "mavi":
        return "".join(f'  <rect x="{cx - s * 0.55:g}" y="{cy + dy * s - s * 0.1:g}" width="{s * 1.1:g}" height="{s * 0.2:g}" rx="{s * 0.1:g}" fill="{c}"/>\n'
                       for dy in (-0.22, 0.22))
    if color == "sari":
        d = f"M{cx - s * 0.55:g} {cy + s * 0.12:g} L{cx - s * 0.28:g} {cy - s * 0.16:g} L{cx:g} {cy + s * 0.12:g} L{cx + s * 0.28:g} {cy - s * 0.16:g} L{cx + s * 0.55:g} {cy + s * 0.12:g}"
        return f'  <path d="{d}" fill="none" stroke="{dark(COLORS[color], 0.3)}" stroke-width="{s * 0.16:g}" stroke-linecap="round" stroke-linejoin="round"/>\n'
    if color == "yesil":
        return f'  <polygon points="{cx:g},{cy - s * 0.4:g} {cx + s * 0.32:g},{cy:g} {cx:g},{cy + s * 0.4:g} {cx - s * 0.32:g},{cy:g}" fill="{c}"/>\n'
    return f'  <circle cx="{cx:g}" cy="{cy:g}" r="{s * 0.3:g}" fill="none" stroke="{c}" stroke-width="{s * 0.14:g}"/>\n'


# --- Boncuklar ---

def bead(shape: str, color: str) -> None:
    c = COLORS[color]
    defs = ten("dolgu", c)
    cx, cy = 80, 80
    if shape == "yuvarlak":
        body = f'  <circle cx="{cx}" cy="{cy}" r="58" fill="url(#dolgu)" {st()}/>\n'
        body += shine(58, 54, 16, 9)
        m = (cx, cy + 4, 40)
    elif shape == "kup":
        body = f'  <rect x="26" y="26" width="108" height="108" rx="20" fill="url(#dolgu)" {st()}/>\n'
        body += shine(54, 50, 15, 8)
        m = (cx, cy + 4, 42)
    elif shape == "yildiz":
        body = f'  <polygon points="{star_points(cx, cy + 6, 70, 32)}" fill="url(#dolgu)" {st()}/>\n'
        body += shine(64, 58, 9, 5)
        m = (cx, cy + 10, 26)
    else:
        body = f'  <path d="{heart(cx, cy + 2, 64)}" fill="url(#dolgu)" {st()}/>\n'
        body += shine(50, 54, 12, 7, -40)
        m = (cx, cy + 6, 34)
    body += mark(color, *m)
    write(f"parcalar/boncuk_{shape}_{color}.svg", 160, 160, body, defs)


# --- Bayraklar (üst kenar FLAG_TOP'ta ipe asılı) ---

def flag(shape: str, color: str) -> None:
    c = COLORS[color]
    defs = linear("dolgu", [(0, light(c, 0.25)), (1, dark(c, 0.12))])
    t = FLAG_TOP
    if shape == "ucgen":
        d = f"M16 {t} L144 {t} L80 150 Z"
        m = (80, 62, 34)
    elif shape == "kare":
        d = f"M26 {t} L134 {t} L134 136 Q134 144 126 144 L34 144 Q26 144 26 136 Z"
        m = (80, 82, 44)
    elif shape == "kirlangic":
        d = f"M24 {t} L136 {t} L136 150 L80 110 L24 150 Z"
        m = (80, 66, 40)
    else:
        d = f"M22 {t} L138 {t} L138 128 Q118 150 99 128 Q80 106 61 128 Q42 150 22 128 Z"
        m = (80, 72, 42)
    body = f'  <path d="{d}" fill="url(#dolgu)" {st()}/>\n'
    body += f'  <rect x="{18 if shape == "ucgen" else 20}" y="{t - 6}" width="{124 if shape == "ucgen" else 120}" height="14" rx="7" fill="{dark(c, 0.2)}" {st(6)}/>\n'
    body += mark(color, *m)
    body += shine(52, t + 30, 12, 6, -20, 0.6)
    write(f"parcalar/bayrak_{shape}_{color}.svg", 160, 160, body, defs)


# --- Çiçekler (sap dibi FLOWER_BASE'te toprağa girer) ---

def stem() -> tuple:
    defs = linear("yaprak", [(0, "#7EDB6A"), (1, "#3E9E46")])
    b = f'  <path d="M80 {FLOWER_BASE} L80 70" fill="none" stroke="{OUT}" stroke-width="15" stroke-linecap="round"/>\n'
    b += f'  <path d="M80 {FLOWER_BASE} L80 70" fill="none" stroke="#5CC45A" stroke-width="7" stroke-linecap="round"/>\n'
    for sx in (-1, 1):
        y = 128 if sx < 0 else 112
        b += (f'  <path d="M80 {y} Q{80 + sx * 26} {y - 26} {80 + sx * 50} {y - 20} Q{80 + sx * 36} {y + 6} 80 {y} Z" '
              f'fill="url(#yaprak)" {st(6)}/>\n')
    return defs, b


def tulip(color: str) -> None:
    c = COLORS[color]
    defs, body = stem()
    defs += ten("dolgu", c)
    body += f'  <path d="M46 34 L62 50 L80 26 L98 50 L114 34 Q120 82 80 90 Q40 82 46 34 Z" fill="url(#dolgu)" {st()}/>\n'
    body += f'  <path d="M80 30 Q70 58 80 86 Q90 58 80 30 Z" fill="{dark(c, 0.15)}" opacity="0.5"/>\n'
    body += shine(60, 54, 6, 12, 15, 0.7)
    write(f"parcalar/cicek_lale_{color}.svg", 160, 160, body, defs)


def petals(cx: float, cy: float, n: int, length: float, width: float, fill: str, sw: float = 6, pointed: bool = False) -> str:
    out = ""
    for k in range(n):
        a = 360 * k / n
        if pointed:
            out += (f'  <path d="M{cx:g} {cy:g} Q{cx - width:g} {cy - length * 0.6:g} {cx:g} {cy - length:g} Q{cx + width:g} {cy - length * 0.6:g} {cx:g} {cy:g} Z" '
                    f'transform="rotate({a:g} {cx:g} {cy:g})" fill="{fill}" {st(sw)}/>\n')
        else:
            out += (f'  <ellipse cx="{cx:g}" cy="{cy - length * 0.55:g}" rx="{width:g}" ry="{length * 0.5:g}" '
                    f'transform="rotate({a:g} {cx:g} {cy:g})" fill="{fill}" {st(sw)}/>\n')
    return out


def daisy() -> None:
    defs, body = stem()
    defs += radial("orta", [(0, "#FFE680"), (0.7, "#FFC21F"), (1, "#E89A10")])
    body += petals(80, 54, 12, 50, 10, "#FFFFFF", 5)
    body += f'  <circle cx="80" cy="54" r="19" fill="url(#orta)" {st(6)}/>\n'
    body += shine(74, 47, 6, 4)
    write("parcalar/cicek_papatya.svg", 160, 160, body, defs)


def sunflower() -> None:
    defs, body = stem()
    # Not: Godot'nun SVG çizicisi döndürülmüş bu yaprak yollarında degrade dolguyu (ve çizgisini) hiç çizmiyor: düz renk
    defs += radial("orta", [(0, "#A86A3A"), (0.7, "#7A4520"), (1, "#5A3014")])
    body += petals(80, 56, 14, 48, 11, "#FFC233", 5, True)
    body += f'  <circle cx="80" cy="56" r="22" fill="url(#orta)" {st(6)}/>\n'
    for k in range(9):
        a = math.radians(k * 40)
        body += f'  <circle cx="{80 + 11 * math.cos(a):.1f}" cy="{56 + 11 * math.sin(a):.1f}" r="2.6" fill="#3A1F0C" opacity="0.6"/>\n'
    write("parcalar/cicek_aycicegi.svg", 160, 160, body, defs)


def violet() -> None:
    defs, body = stem()
    defs += ten("dolgu", "#8E5CF0")
    body += petals(80, 56, 5, 46, 21, "url(#dolgu)", 6)
    body += f'  <circle cx="80" cy="56" r="11" fill="#FFD84A" {st(5)}/>\n'
    body += shine(66, 34, 7, 4)
    write("parcalar/cicek_menekse.svg", 160, 160, body, defs)


# --- Tırtıl ---

def segment(color: str) -> None:
    c = COLORS[color]
    defs = ten("dolgu", c)
    body = ""
    for x in (56, 104):
        body += f'  <ellipse cx="{x}" cy="146" rx="12" ry="9" fill="{dark(c, 0.35)}" {st(5)}/>\n'
    body += f'  <circle cx="80" cy="84" r="60" fill="url(#dolgu)" {st()}/>\n'
    body += shine(60, 56, 15, 8)
    body += mark(color, 80, 90, 40)
    write(f"parcalar/tirtil_{color}.svg", 160, 160, body, defs)


def caterpillar_head(happy: bool = False) -> tuple:
    # Sola bakan baş (160x160, merkez 84,84): antenler, büyük gözler, gülümseme, pembe yanak
    c = "#8CDB5C"
    defs = ten("bas", c) + besle.EYE_DEFS
    body = ""
    for x, tip in ((62, (40, 10)), (98, (104, 6))):
        body += f'  <path d="M{x} 40 Q{(x + tip[0]) / 2 - 6} 20 {tip[0]} {tip[1]}" fill="none" {st(6)}/>\n'
        body += f'  <circle cx="{tip[0]}" cy="{tip[1]}" r="9" fill="#FF7FA3" {st(5)}/>\n'
    body += f'  <circle cx="84" cy="88" r="62" fill="url(#bas)" {st()}/>\n'
    body += shine(62, 52, 15, 8)
    for x in (62, 100):
        if happy:
            body += f'  <path d="M{x - 12} 82 Q{x} 66 {x + 12} 82" fill="none" {st(6)}/>\n'
        else:
            body += f'  <ellipse cx="{x}" cy="80" rx="12" ry="15" fill="url(#goz)"/>\n'
            body += f'  <ellipse cx="{x - 4}" cy="74" rx="5" ry="6" fill="#FFFFFF"/>\n'
    body += "".join(f'  <ellipse cx="{x}" cy="104" rx="13" ry="8" fill="url(#yanak)"/>\n' for x in (44, 118))
    if happy:
        body += f'  <path d="M66 104 Q80 104 94 104 Q92 124 80 124 Q68 124 66 104 Z" fill="#8A2A4A" {st(5)}/>\n'
    else:
        body += f'  <path d="M68 106 Q80 118 92 106" fill="none" {st(6)}/>\n'
    return defs, body


def caterpillar() -> None:
    defs, body = caterpillar_head()
    write("tirtil_bas.svg", 160, 160, body, defs)


def card_caterpillar() -> None:
    # Ana menü kartı ve final ekranı: sağa doğru kıvrılan üç renkli halka, önde gülen baş
    defs = ""
    body = ""
    for k, (color, x, y) in enumerate((("mor", 232, 150), ("sari", 184, 122), ("mavi", 138, 140))):
        c = COLORS[color]
        defs += ten(f"h{k}", c)
        for fx in (x - 16, x + 16):
            body += f'  <ellipse cx="{fx}" cy="{y + 50}" rx="10" ry="8" fill="{dark(c, 0.35)}" {st(5)}/>\n'
        body += f'  <circle cx="{x}" cy="{y}" r="42" fill="url(#h{k})" {st()}/>\n'
        body += shine(x - 14, y - 20, 11, 6)
        body += mark(color, x, y + 4, 30)
    hdefs, head = caterpillar_head(True)
    defs += hdefs
    body += f'  <g transform="translate(2 46) scale(0.92)">\n{head}  </g>\n'
    write("kart_tirtil.svg", 280, 230, body, defs)


# --- Hayvanlar (Besle'deki çizimler + yüz) ---

def prefixed(text: str, prefix: str) -> str:
    # Gövde ve kafa aynı gradyan adlarını kullanır: kafanınkiler önekle ayrılır
    text = re.sub(r'id="([\w-]+)"', lambda m: f'id="{prefix}{m.group(1)}"', text)
    return re.sub(r"url\(#([\w-]+)\)", lambda m: f"url(#{prefix}{m.group(1)})", text)


def face(name: str) -> str:
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
    out += f'  <path d="M114 {my - 2} Q128 {my + 12} 142 {my - 2}" fill="none" {st(6)}/>\n'
    return out


def animals() -> None:
    for name in ANIMALS:
        bd, b, hd, h = besle.ANIMALS[name]()
        write(f"parcalar/hayvan_{name}.svg", 256, 256, b + prefixed(h, "k") + face(name), bd + prefixed(hd, "k") + besle.EYE_DEFS)


# --- Yuva, kelebek ---

def slot() -> None:
    body = '  <circle cx="80" cy="80" r="62" fill="#FFFFFF" fill-opacity="0.55" stroke="#8C7BD6" stroke-width="7" stroke-dasharray="17 11" stroke-linecap="round"/>\n'
    q = "M60 60 Q60 38 80 38 Q100 38 100 58 Q100 70 88 76 Q80 80 80 92"
    body += f'  <path d="{q}" fill="none" stroke="#8C7BD6" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>\n'
    body += '  <circle cx="80" cy="115" r="8.5" fill="#8C7BD6"/>\n'
    write("yuva.svg", 160, 160, body)


def butterfly() -> None:
    defs = ten("kanat", "#FF8FC8") + ten("kanat2", "#FFB84D")
    body = ""
    for sx in (-1, 1):
        body += f'  <ellipse cx="{60 + sx * 26}" cy="44" rx="26" ry="30" transform="rotate({sx * 20} {60 + sx * 26} 44)" fill="url(#kanat)" {st(6)}/>\n'
        body += f'  <ellipse cx="{60 + sx * 20}" cy="80" rx="17" ry="20" transform="rotate({sx * -20} {60 + sx * 20} 80)" fill="url(#kanat2)" {st(6)}/>\n'
        body += f'  <circle cx="{60 + sx * 28}" cy="42" r="8" fill="#FFFFFF" opacity="0.7"/>\n'
    body += f'  <ellipse cx="60" cy="62" rx="8" ry="34" fill="#5A3E8A" {st(5)}/>\n'
    for sx in (-1, 1):
        body += f'  <path d="M60 30 Q{60 + sx * 8} 14 {60 + sx * 18} 10" fill="none" {st(4)}/>\n'
    write("kelebek.svg", 120, 110, body, defs)


# --- Arka planlar (1280x720, zemin y = 520) ---

def sky(top: str, bottom: str) -> tuple:
    return linear("gok", [(0, top), (1, bottom)]), '  <rect width="1280" height="720" fill="url(#gok)"/>\n'


def cloud(x: float, y: float, s: float) -> str:
    shapes = "".join(f'<circle cx="{x + dx * s:g}" cy="{y + dy * s:g}" r="{r * s:g}"/>' for dx, dy, r in
                     ((0, 0, 34), (38, -14, 42), (80, 2, 32), (40, 14, 30)))
    return f'  <g fill="#FFFFFF" opacity="0.9">{shapes}</g>\n'


def grass(y: float, color: str, dark_color: str) -> str:
    out = f'  <rect x="0" y="{y}" width="1280" height="{720 - y}" fill="{color}"/>\n'
    out += f'  <rect x="0" y="{y}" width="1280" height="10" fill="{dark_color}" opacity="0.5"/>\n'
    for k in range(26):
        x = 20 + k * 50 + (k * 37) % 23
        yy = y + 40 + (k * 53) % 150
        out += f'  <path d="M{x} {yy} l6 -16 l6 16 M{x + 12} {yy} l6 -12 l5 12" fill="none" stroke="{dark_color}" stroke-width="4" stroke-linecap="round" opacity="0.55"/>\n'
    return out


def bg_necklace() -> None:
    defs, body = sky("#FFE3EE", "#FFD0E2")
    for k in range(40):
        x = (k % 10) * 136 + (68 if (k // 10) % 2 else 0) + 30
        y = (k // 10) * 130 + 50
        body += f'  <circle cx="{x}" cy="{y}" r="12" fill="#FFFFFF" opacity="0.45"/>\n'
    # Duvardaki iki çivi gibi asma düğmeleri tema_kolye.gd çizer; burada masa
    defs += linear("masa", [(0, "#E8B07A"), (1, "#C98A52")])
    body += '  <rect x="0" y="520" width="1280" height="200" fill="url(#masa)"/>\n'
    body += f'  <rect x="0" y="512" width="1280" height="18" fill="#F2C493" stroke="{dark("#C98A52", 0.3)}" stroke-width="4"/>\n'
    for y in (580, 650):
        body += f'  <path d="M0 {y} L1280 {y}" stroke="#B87A44" stroke-width="4" opacity="0.5"/>\n'
    write("arka_plan_kolye.svg", 1280, 720, body, defs)


def bg_party() -> None:
    defs, body = sky("#9FD8FF", "#DDF2FF")
    body += cloud(140, 120, 1.0) + cloud(900, 80, 1.2) + cloud(560, 190, 0.7)
    # Uzakta balonlar
    for x, y, c in ((260, 400, "#FF8FB0"), (300, 380, "#FFD23F"), (1030, 390, "#7EC8FF"), (1070, 410, "#B48CFF")):
        body += f'  <path d="M{x} {y + 34} Q{x + 6} {y + 70} {x - 4} {y + 110}" fill="none" stroke="#FFFFFF" stroke-width="3"/>\n'
        body += f'  <ellipse cx="{x}" cy="{y}" rx="26" ry="32" fill="{c}" opacity="0.8"/>\n'
    body += grass(520, "#8EDB6E", "#5DB04A")
    write("arka_plan_bayrak.svg", 1280, 720, body, defs)


def bg_garden() -> None:
    defs, body = sky("#A8E0FF", "#E6F7FF")
    body += cloud(980, 110, 1.0) + cloud(220, 70, 0.8)
    body += f'  <circle cx="1150" cy="130" r="56" fill="#FFE066" opacity="0.9"/>\n'
    # Arkadaki çit
    for k in range(22):
        x = k * 62 - 10
        body += f'  <path d="M{x} 520 L{x} 452 L{x + 20} 436 L{x + 40} 452 L{x + 40} 520 Z" fill="#FFF6E6" stroke="#D9C2A0" stroke-width="4"/>\n'
    body += '  <rect x="0" y="466" width="1280" height="14" fill="#F2E4CC" stroke="#D9C2A0" stroke-width="3"/>\n'
    body += grass(520, "#7FD663", "#52AD44")
    write("arka_plan_bahce.svg", 1280, 720, body, defs)


def bg_caterpillar() -> None:
    defs, body = sky("#D8F5C8", "#F2FCE8")
    defs += linear("yaprak", [(0, "#A6E47C"), (1, "#6CC453")])
    # Köşelerde büyük yapraklar
    for cx, cy, a in ((90, 90, -30), (1200, 120, 30), (60, 430, 20), (1230, 440, -20)):
        body += f'  <ellipse cx="{cx}" cy="{cy}" rx="150" ry="70" transform="rotate({a} {cx} {cy})" fill="url(#yaprak)" opacity="0.7"/>\n'
        body += f'  <path d="M{cx - 130} {cy} L{cx + 130} {cy}" transform="rotate({a} {cx} {cy})" stroke="#5AA846" stroke-width="5" opacity="0.6"/>\n'
    body += grass(520, "#9BDD72", "#6CB850")
    write("arka_plan_tirtil.svg", 1280, 720, body, defs)


def bg_parade() -> None:
    defs, body = sky("#9ED6FF", "#E2F4FF")
    body += cloud(120, 90, 0.9) + cloud(1000, 70, 1.1)
    defs += linear("tepe", [(0, "#A8E68A"), (1, "#7CCB62")])
    body += '  <ellipse cx="300" cy="560" rx="620" ry="330" fill="#B9EBA0"/>\n'
    body += '  <ellipse cx="1050" cy="580" rx="560" ry="330" fill="url(#tepe)"/>\n'
    body += grass(520, "#86D468", "#5CB04A")
    write("arka_plan_gecit.svg", 1280, 720, body, defs)


if __name__ == "__main__":
    for color in COLORS:
        for shape in ("yuvarlak", "kup", "yildiz", "kalp"):
            bead(shape, color)
        for shape in ("ucgen", "kare", "kirlangic", "dalga"):
            flag(shape, color)
        tulip(color)
        segment(color)
    daisy()
    sunflower()
    violet()
    animals()
    caterpillar()
    card_caterpillar()
    slot()
    butterfly()
    bg_necklace()
    bg_party()
    bg_garden()
    bg_caterpillar()
    bg_parade()
    copy("hayvan_besle/gorseller/yildiz.svg", "yildiz.svg")
    copy("hayvan_besle/gorseller/isilti.svg", "isilti.svg")
