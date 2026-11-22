# Labirent SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: py svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Hayvanlar ve yemekler Hayvanları Besle'nin çizimleridir: onun svg_uret.py'si içe aktarılır (o dosyaya dokunulmaz).
# Orada yüzü oyun kodla çizer; burada gövde + kafa + yüz tek SVG'de birleşir:
# - hayvanlar/<ad>.svg        gülümseyen tam hayvan (256 tuval; labirentte sürüklenen)
# - hayvanlar/<ad>_mutlu.svg  aynı hayvan, gözleri mutlu kapalı, ağzı açık (yemeğe varınca)
# - yiyecekler/<ad>.svg       Hayvanları Besle'den kopya (256 tuval)
# - kart_labirent.svg         menü kartının arkası: küçük labirent tahtası ve havuç
# yildiz.svg, isilti.svg Noktaları Birleştir'den kopya (o da Hayvanları Besle'den).
# Labirentin duvarları ve zemini görsel değil: labirent_cizim.gd kodla çizer.

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
radial, light, dark, st, shine = besle.radial, besle.light, besle.dark, besle.st, besle.shine

## Hayvan → yemek (Hayvanları Besle'deki eşleşmeler; ayarlar.gd ANIMALS ile aynı)
FOODS = {"tavsan": "havuc", "sincap": "palamut", "fare": "peynir", "kedi": "balik", "kopek": "kemik",
         "kus": "tohum", "maymun": "muz", "panda": "bambu", "inek": "ot", "ayi": "bal"}


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    path = os.path.join(HERE, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


# --- Yüz (Hayvanları Besle hayvan_yuzu.gd'nin çizdiğinin SVG hali) ---

def eyes(face: dict, happy: bool) -> str:
    y, dx, rx, ry = face["eye"]
    out = ""
    for x in (128 - dx, 128 + dx):
        if happy:
            color = "#FFFFFF" if face.get("eye_white") else OUT
            out += (f'  <path d="M{x - rx * 0.95:g} {y + ry * 0.15:g} Q{x:g} {y - ry * 0.95:g} {x + rx * 0.95:g} {y + ry * 0.15:g}" '
                    f'fill="none" stroke="{color}" stroke-width="5.5" stroke-linecap="round"/>\n')
            continue
        if face.get("eye_white"):
            out += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{rx * 1.45:g}" ry="{ry * 1.45:g}" fill="#FFFFFF"/>\n'
        out += f'  <ellipse cx="{x:g}" cy="{y:g}" rx="{rx:g}" ry="{ry:g}" fill="url(#goz)"/>\n'
        out += f'  <ellipse cx="{x - rx * 0.35:g}" cy="{y - ry * 0.45:g}" rx="{rx * 0.42:g}" ry="{ry * 0.4:g}" fill="#FFFFFF"/>\n'
        out += f'  <circle cx="{x + rx * 0.35:g}" cy="{y + ry * 0.4:g}" r="{rx * 0.2:g}" fill="#FFFFFF" opacity="0.85"/>\n'
    return out


def cheeks(face: dict) -> str:
    cy, cdx = face["cheek"]
    return "".join(f'  <ellipse cx="{x:g}" cy="{cy:g}" rx="17" ry="10" fill="url(#yanak)"/>\n' for x in (128 - cdx, 128 + cdx))


def teeth(y: float) -> str:
    return "".join(f'  <rect x="{128 + dx:g}" y="{y:g}" width="5.5" height="8" fill="#FFFFFF" {st(2.5)}/>\n' for dx in (-6, 0.5))


def mouth(face: dict, happy: bool) -> str:
    y, w = face["mouth"]
    if face.get("beak"):
        open_ = 14 if happy else 0
        out = ""
        if open_:
            out += f'  <path d="M{128 - w * 0.8:g} {y + 2} L{128 + w * 0.8:g} {y + 2} L128 {y + 14 + open_}" fill="#8A2A4A"/>\n'
        out += (f'  <path d="M{128 - w * 0.85:g} {y + 3 + open_ * 0.6:g} L{128 + w * 0.85:g} {y + 3 + open_ * 0.6:g} L128 {y + 18 + open_}  Z" '
                f'fill="#E0782A" {st(4.5)}/>\n')
        out += f'  <path d="M{128 - w:g} {y + 2} L128 {y - 9} L{128 + w:g} {y + 2} L128 {y + 10} Z" fill="#FF9A3D" {st(4.5)}/>\n'
        return out
    if happy:
        half, depth = w * 1.5, 30
        out = (f'  <path d="M{128 - half:g} {y} Q128 {y - 5} {128 + half:g} {y} A{half:g} {depth} 0 0 1 {128 - half:g} {y} Z" '
               f'fill="#8A2A4A" {st(5)}/>\n')
        out += f'  <ellipse cx="128" cy="{y + depth * 0.66:g}" rx="{half * 0.6:g}" ry="{depth * 0.28:g}" fill="#FF8FB0"/>\n'
        if face.get("teeth"):
            out += teeth(y + 1)
        return out
    # "w" gülümseme
    points = []
    for k in range(17):
        t = k / 16
        points.append(f"{128 - w + 2 * w * t:.1f} {y + 9 * abs(math.sin(math.tau * t)):.1f}")
    out = teeth(y + 2) if face.get("teeth") else ""
    out += f'  <polyline points="{" ".join(points)}" fill="none" {st(5)}/>\n'
    return out


def animal(name: str, happy: bool) -> None:
    bd, b, hd, h = besle.ANIMALS[name]()
    face = besle.FACES[name]
    # Gövde ve kafa aynı gradyanları kullanabilir ("ten", pandada "siyah"); tek SVG'de bir kez tanımlanır (kafanınki)
    ids = re.findall(r'id="([^"]+)"', hd)
    defs = hd + "".join(line + "\n" for line in bd.splitlines() if not any(f'id="{i}"' in line for i in ids)) + besle.EYE_DEFS
    body = b + h + cheeks(face) + mouth(face, happy) + eyes(face, happy)
    write(f"hayvanlar/{name}{'_mutlu' if happy else ''}.svg", 256, 256, body, defs)


# Menü kartının arkası: üstten görülen küçük labirent (oyundaki gibi çit duvarlar), yol izi ve köşede havuç
CARD_MAP = [
    "#########",
    "#...#...#",
    "###.#.#.#",
    "#...#.#.#",
    "#.###.#.#",
    "#.....#.#",
    "#########",
]
CARD_TRAIL = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 2), (1, 2), (2, 2)]


def card_board() -> None:
    c, pad = 66, 22
    w, h = 4 * c + pad * 2, 3 * c + pad * 2
    defs = radial("zemin", [(0, "#E4F8C4"), (1, "#B9E58E")], 0.4, 0.3, 0.9)
    body = f'  <rect x="4" y="4" width="{w - 8}" height="{h - 8}" rx="24" fill="url(#zemin)" {st(6)}/>\n'
    trail = " ".join(f"{'M' if k == 0 else 'L'}{pad + (x + 0.5) * c:g} {pad + (y + 0.5) * c:g}" for k, (x, y) in enumerate(CARD_TRAIL))
    body += f'  <path d="{trail}" fill="none" stroke="#F4FFE0" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>\n'
    lines = ""
    for y, row in enumerate(CARD_MAP):
        for x, ch in enumerate(row):
            if ch != "#" or (x % 2 == 0 and y % 2 == 0):
                continue
            px, py = pad + x * c / 2, pad + y * c / 2
            if x % 2 == 0:
                lines += f"M{px:g} {py - c / 2:g} V{py + c / 2:g} "
            else:
                lines += f"M{px - c / 2:g} {py:g} H{px + c / 2:g} "
    for width, color, shift in ((26, OUT, ""), (16, "#4FAE55", ""), (5, "#8FD884", ' transform="translate(-2 -2)"')):
        body += f'  <path d="{lines}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"{shift}/>\n'
    write("kart_labirent.svg", w, h, body, defs)


if __name__ == "__main__":
    for name in FOODS:
        animal(name, False)
        animal(name, True)
    for food in FOODS.values():
        copy(f"hayvan_besle/gorseller/yiyecekler/{food}.svg", f"yiyecekler/{food}.svg")
    copy("nokta_birlestir/gorseller/yildiz.svg", "yildiz.svg")
    copy("nokta_birlestir/gorseller/isilti.svg", "isilti.svg")
    card_board()
