# Hayvan Doktoru SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: python svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Stil ve yardımcılar Hayvanları Besle'nin svg_uret.py'sinden (oradan içe aktarılır, o dosyaya dokunulmaz):
# koyu mor kalın hat, radyal gradyanlı parlak dolgular, beyaz parıltılar.
#
# - hayvanlar/<ad>_govde.svg, <ad>_kafa.svg: Hayvanları Besle'deki çizim fonksiyonlarıyla aynı (256 tuval;
#   göz ve ağız yok, onları hasta_yuzu.gd çizer). Yüz yerleri FACES (Besle) ile aynı.
# - Aletler (raf simgesi ve parmaktaki alet aynı görsel): stetoskop, pamuk, merhem, bant (yara bandı), cimbiz,
#   termometre, surup (şuruplu kaşık), buz (buz kesesi), mendil, dis_fircasi, krem, pudra (pudra ponponu),
#   kulak_cubugu, damla (damlalık), sargi. Çapraz duran aletler yatay çizilip -45° döndürülür (ucu sol altta).
#   Her aletin etki ettiği uç noktası (görselin genişlik / yüksekliğine oranı) ayarlar.gd TOOLS "tip" ile aynı:
#   çalıştırınca TIPS yazdırılır.
# - Belirti katmanları (tedavi_noktasi.gd): yara, kir, merhem_kat (sıyrık); diken; kizarik (kızarıklık), su_damlasi
#   (ter, gözyaşı, damla); benek (kaşıntı), pudra_kat; kopuk (diş macunu köpüğü); sargi_kat (sarılmış bilek).
# - Simgeler (düşünce balonu): simge_siyrik (çapraz iki yara bandı), simge_dis, simge_kulak, simge_goz,
#   simge_kasinti. Diğer rahatsızlıklar simge olarak aletin ya da belirtinin kendi görselini kullanır.
# - album.svg: albüm düğmesinin simgesi; kart_doktor.svg: final ekranı karakteri ve menü kapağının ortası;
#   kart_kedi, kart_tavsan, kart_ayi, kart_panda: menü kapağındaki iyileşmiş hastalar (mutlu yüz + bant / termometre /
#   sargı / buz kesesi).
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
st, shine, radial, linear = besle.st, besle.shine, besle.radial, besle.linear

# Aletlerin uç noktası (genişliğe / yüksekliğe oran); ayarlar.gd TOOLS "tip" ile aynı. Çapraz aletlerinki
# diagonal() doldurur.
TIPS = {
    "stetoskop": (80 / 240, 182 / 240),
    "pamuk": (0.5, 0.55),
    "bant": (0.5, 0.5),
}


def diagonal(name: str, g: str, tip_x: float, defs: str = "", size: float = 220) -> None:
    # Yatay çizilmiş aleti (ucu solda, tip_x'te, y = size / 2) -45° döndürüp yazar; ucu sol alta gelir
    c = size / 2
    dx = tip_x - c
    tx, ty = c + dx * math.cos(math.radians(45)), c - dx * math.sin(math.radians(45))
    TIPS[name] = (tx / size, ty / size)
    write(f"{name}.svg", size, size, f'  <g transform="rotate(-45 {c:g} {c:g})">\n{g}  </g>\n', defs)


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


def blob(cx: float, cy: float, rx: float, ry: float, bumps: int, wobble: float, seed: int, points: int = 48) -> str:
    # Yumuşak, tümsekli kapalı şekil (yara, merhem): yarıçap açıyla dalgalanır
    rnd = random.Random(seed)
    phases = [rnd.uniform(0, math.tau) for _ in range(2)]
    pts = []
    for k in range(points):
        a = math.tau * k / points
        f = 1 + wobble * math.sin(bumps * a + phases[0]) + wobble * 0.5 * math.sin((bumps + 2) * a + phases[1])
        pts.append((cx + rx * f * math.cos(a), cy + ry * f * math.sin(a)))
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


# --- Aletler ---

def stethoscope() -> None:
    # Stetoskop (240x240): altta gümüş göğüs başlığı (uç), yukarı çıkan turkuaz hortum, iki kulaklık
    defs = radial("gumus", [(0, "#FFFFFF"), (0.55, "#D3E2F2"), (1, "#8EA8CC")], 0.38, 0.32, 0.8)
    tube = "#3FC1C9"
    paths = ("M80 146 C80 112 128 122 150 98", "M150 98 C130 74 110 60 116 34", "M150 98 C176 78 198 64 196 38")
    body = ""
    for d in paths:
        body += f'  <path d="{d}" fill="none" stroke="{OUT}" stroke-width="22" stroke-linecap="round"/>\n'
    for d in paths:
        body += f'  <path d="{d}" fill="none" stroke="{tube}" stroke-width="10" stroke-linecap="round"/>\n'
    body += '  <path d="M84 132 C86 116 112 118 130 108" fill="none" stroke="#B8F1F3" stroke-width="3.5" stroke-linecap="round"/>\n'
    for x, y in ((116, 28), (196, 32)):
        body += f'  <circle cx="{x}" cy="{y}" r="11" fill="#6C5CA8" {st(5)}/>\n'
        body += f'  <circle cx="{x - 3}" cy="{y - 3}" r="3" fill="#FFFFFF" opacity="0.7"/>\n'
    body += f'  <circle cx="150" cy="98" r="9" fill="url(#gumus)" {st(5)}/>\n'
    body += f'  <rect x="69" y="134" width="22" height="20" rx="6" fill="url(#gumus)" {st(5)}/>\n'
    body += f'  <circle cx="80" cy="182" r="38" fill="url(#gumus)" {st()}/>\n'
    body += f'  <circle cx="80" cy="182" r="24" fill="#EAF3FC" {st(4)}/>\n'
    body += shine(66, 166, 10, 5, -35, 0.9)
    write("stetoskop.svg", 240, 240, body, defs)


def cotton() -> None:
    # Pamuk (180x160): beyaz, kabarık, hafif mavi gölgeli
    defs = radial("pamuk", [(0, "#FFFFFF"), (0.7, "#FFFFFF"), (1, "#DCE6F6")], 0.4, 0.3, 0.8)
    circles = [(90, 88, 40), (58, 96, 28), (122, 96, 28), (72, 62, 26), (108, 60, 27), (90, 116, 24), (40, 80, 16), (140, 78, 16)]
    shapes = "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in circles)
    body = f'  <g fill="{OUT}" stroke="{OUT}" stroke-width="12">{shapes}</g>\n'
    body += f'  <g fill="url(#pamuk)">{shapes}</g>\n'
    for x, y, r in circles[:6]:
        body += (f'  <path d="M{x - r * 0.5:.1f} {y - r * 0.15:.1f} A{r * 0.6:.1f} {r * 0.6:.1f} 0 0 1 {x - r * 0.05:.1f} {y - r * 0.6:.1f}" '
                 f'fill="none" stroke="#E3ECF8" stroke-width="4" stroke-linecap="round"/>\n')
    write("pamuk.svg", 180, 160, body, defs)


def tube(name: str, body: tuple, label: tuple, symbol: str, dollop: bool) -> None:
    # Krem tüpü (220x220, çapraz): gövde ve etiket renkleri, etiketin üstünde beyaz simge; dollop: ucunda beyaz krem
    defs = linear("tup", [(0, body[0]), (0.5, body[1]), (1, body[2])]) + linear("etiket", [(0, label[0]), (1, label[1])])
    g = f'    <path d="M170 80 L170 140 L80 132 L62 122 L62 98 L80 88 Z" fill="url(#tup)" {st()}/>\n'
    g += f'    <path d="M170 76 L186 76 L186 144 L170 144 Z" fill="{body[2]}" {st(6)}/>\n'
    g += f'    <path d="M176 82 V138 M181 82 V138" fill="none" stroke="{OUT}" stroke-width="2.5" opacity="0.35"/>\n'
    g += f'    <rect x="96" y="92" width="58" height="36" rx="8" fill="url(#etiket)" {st(5)}/>\n'
    g += symbol
    g += f'    <rect x="40" y="100" width="24" height="20" rx="5" fill="#FFFFFF" {st(5)}/>\n'
    g += '    <ellipse cx="96" cy="94" rx="18" ry="4" fill="#FFFFFF" opacity="0.9"/>\n'
    if dollop:
        g += f'    <path d="{blob(32, 110, 12, 10, 3, 0.12, 5, 24)}" fill="#FFFFFF" {st(4)}/>\n'
    diagonal(name, g, 32 if dollop else 40)


HEART = '    <path d="M125 120 C112 112 110 102 117 100 C121 99 124 102 125 105 C126 102 129 99 133 100 C140 102 138 112 125 120 Z" fill="#FFFFFF"/>\n'
DROP = '    <path d="M125 98 C129 106 134 110 134 115 A9 9 0 0 1 116 115 C116 110 121 106 125 98 Z" fill="#FFFFFF"/>\n'


def ointment() -> None:
    # Merhem tüpü: beyaz-mavi gövde, yeşil etiket ve kalp
    tube("merhem", ("#FFFFFF", "#EAF2FF", "#B9CBEA"), ("#8BE08C", "#3FAE5C"), HEART, False)


def lotion() -> None:
    # Kaşıntı kremi: pembe gövde, mor etiket ve damla, ucunda krem
    tube("krem", ("#FFF0F6", "#FFD3E6", "#F3A7C8"), ("#B79CFF", "#8A6CF0"), DROP, True)


def tweezers() -> None:
    # Cımbız (çapraz): iki gümüş kol, arkada birleşik, kollarda pembe tutamak, ucu solda
    defs = linear("gumus", [(0, "#FFFFFF"), (0.5, "#D3E2F2"), (1, "#8EA8CC")])
    g = ""
    for s in (1, -1):
        y = lambda v: 110 + s * v  # noqa: E731
        arm = f"M190 {y(-34)} Q120 {y(-24)} 30 {y(-8)} L30 {y(1)} Q120 {y(-6)} 190 {y(-12)} Z"
        g += f'    <path d="{arm}" fill="url(#gumus)" {st(6)}/>\n'
        g += f'    <rect x="114" y="{110 - s * 17 - 7:g}" width="46" height="14" rx="7" fill="#FF8FB8" {st(4)}/>\n'
    g += f'    <rect x="180" y="72" width="24" height="76" rx="11" fill="url(#gumus)" {st(6)}/>\n'
    g += '    <path d="M187 82 V138" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.8"/>\n'
    diagonal("cimbiz", g, 30, defs)


def thermometer() -> None:
    # Termometre (çapraz): cam gövde, ucunda kırmızı hazne, içinde kırmızı çizgi ve çentikler
    defs = linear("cam", [(0, "#FFFFFF"), (1, "#D8ECFA")]) + radial("hazne", [(0, "#FF9AA8"), (0.6, "#FF4D6A"), (1, "#D92E4C")])
    g = f'    <rect x="56" y="94" width="144" height="32" rx="16" fill="url(#cam)" {st()}/>\n'
    g += '    <rect x="60" y="106" width="70" height="8" rx="4" fill="#FF4D6A"/>\n'
    for k in range(6):
        x = 120 + k * 12
        g += f'    <path d="M{x} 96 V{104 if k % 2 else 108}" stroke="{OUT}" stroke-width="3" stroke-linecap="round" opacity="0.6"/>\n'
    g += f'    <circle cx="52" cy="110" r="20" fill="url(#hazne)" {st()}/>\n'
    g += shine(46, 103, 6, 3, -30, 0.9) + shine(150, 100, 30, 3, 0, 0.8).replace("  <", "    <")
    diagonal("termometre", g, 52, defs)


def spoon() -> None:
    # Şuruplu kaşık (çapraz): gümüş kaşık, çukurunda pembe şurup
    defs = linear("gumus", [(0, "#FFFFFF"), (0.5, "#D3E2F2"), (1, "#8EA8CC")]) + radial("surup", [(0, "#FFC2DA"), (0.6, "#FF6FA8"), (1, "#E0457F")])
    g = f'    <path d="M92 104 L196 100 Q206 100 206 110 Q206 120 196 120 L92 116 Z" fill="url(#gumus)" {st(6)}/>\n'
    g += f'    <ellipse cx="60" cy="110" rx="42" ry="30" fill="url(#gumus)" {st()}/>\n'
    g += f'    <ellipse cx="58" cy="110" rx="31" ry="20" fill="url(#surup)" stroke="#C93A72" stroke-width="3"/>\n'
    g += '    <ellipse cx="48" cy="103" rx="10" ry="4" fill="#FFFFFF" opacity="0.85"/>\n'
    diagonal("surup", g, 60, defs)


def ice_pack() -> None:
    # Buz kesesi (200x170): açık mavi kese, üstte kapak, içinde buz küpleri ve kar tanesi
    defs = radial("kese", [(0, "#E8F7FF"), (0.6, "#A8DDFB"), (1, "#6BB8EE")], 0.4, 0.3, 0.8)
    body = f'  <rect x="76" y="12" width="48" height="34" rx="10" fill="#7C6CF0" {st(6)}/>\n'
    body += f'  <path d="M80 26 H120 M80 36 H120" stroke="#5A4AC8" stroke-width="3"/>\n'
    body += f'  <path d="M40 60 Q40 42 70 42 H130 Q160 42 160 60 Q186 92 172 130 Q160 158 100 158 Q40 158 28 130 Q14 92 40 60 Z" fill="url(#kese)" {st()}/>\n'
    for x, y, a in ((70, 100, -12), (110, 92, 14), (92, 128, 6)):
        body += f'  <rect x="{x - 14}" y="{y - 14}" width="28" height="28" rx="7" transform="rotate({a} {x} {y})" fill="#FFFFFF" stroke="#8CC8F0" stroke-width="3" opacity="0.9"/>\n'
    sx, sy = 136, 124
    for k in range(3):
        a = math.radians(k * 60)
        body += f'  <path d="M{sx - 12 * math.cos(a):.1f} {sy - 12 * math.sin(a):.1f} L{sx + 12 * math.cos(a):.1f} {sy + 12 * math.sin(a):.1f}" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>\n'
    body += shine(62, 66, 20, 7, -20, 0.8)
    TIPS["buz"] = (0.5, 0.6)
    write("buz.svg", 200, 170, body, defs)


def tissue() -> None:
    # Mendil (180x160): hafif buruşuk beyaz kağıt mendil, kenarında mavi noktalar, katlanmış köşe
    body = f'  <path d="M30 34 Q60 26 92 32 Q124 24 152 32 Q160 64 154 92 Q162 120 150 134 Q118 142 90 136 Q58 144 32 134 Q22 104 28 78 Q20 54 30 34 Z" fill="#FFFFFF" {st()}/>\n'
    body += f'  <path d="M152 32 Q150 58 154 72 Q132 62 122 40 Z" fill="#E4EEFA" {st(4)}/>\n'
    for k in range(7):
        body += f'  <circle cx="{44 + k * 15}" cy="122" r="3" fill="#8CC8F0"/>\n'
    body += '  <path d="M48 58 Q72 50 96 56" fill="none" stroke="#E4EEFA" stroke-width="5" stroke-linecap="round"/>\n'
    body += '  <path d="M58 92 Q86 84 116 92" fill="none" stroke="#E4EEFA" stroke-width="5" stroke-linecap="round"/>\n'
    TIPS["mendil"] = (0.5, 0.55)
    write("mendil.svg", 180, 160, body)


def toothbrush() -> None:
    # Diş fırçası (çapraz): turkuaz sap, beyaz-mavi kıllar, üstünde çizgili diş macunu
    defs = linear("sap", [(0, "#8FF0E4"), (1, "#2FB8AE")])
    g = f'    <path d="M78 104 L200 98 Q210 98 210 110 Q210 122 200 122 L78 118 Z" fill="url(#sap)" {st(6)}/>\n'
    g += '    <rect x="150" y="104" width="40" height="10" rx="5" fill="#FFFFFF" opacity="0.6"/>\n'
    g += f'    <rect x="24" y="106" width="60" height="16" rx="7" fill="url(#sap)" {st(6)}/>\n'
    for k in range(5):
        x = 30 + k * 11
        g += f'    <rect x="{x}" y="84" width="9" height="24" rx="3" fill="{"#FFFFFF" if k % 2 == 0 else "#BFE4FF"}" {st(3)}/>\n'
    g += f'    <path d="M28 82 Q36 66 48 76 Q58 62 68 74 Q80 66 84 82 Z" fill="#FFFFFF" {st(4)}/>\n'
    g += '    <path d="M38 76 Q48 70 56 74 M60 72 Q68 68 76 74" fill="none" stroke="#7FD3FF" stroke-width="4" stroke-linecap="round"/>\n'
    diagonal("dis_fircasi", g, 54, defs)


def powder_puff() -> None:
    # Pudra ponponu (180x160): pembe yumuşak yuvarlak ponpon, üstünde saten şerit, çevresinde pudra tozu
    defs = radial("ponpon", [(0, "#FFFFFF"), (0.55, "#FFD6E8"), (1, "#F5A3C7")], 0.4, 0.35, 0.75)
    body = f'  <path d="M68 46 Q90 14 112 46" fill="none" stroke="{OUT}" stroke-width="16" stroke-linecap="round"/>\n'
    body += '  <path d="M68 46 Q90 14 112 46" fill="none" stroke="#B79CFF" stroke-width="8" stroke-linecap="round"/>\n'
    body += f'  <ellipse cx="90" cy="94" rx="62" ry="50" fill="url(#ponpon)" {st()}/>\n'
    body += f'  <path d="M30 86 Q90 70 150 86" fill="none" stroke="#B79CFF" stroke-width="10"/>\n'
    body += f'  <path d="M30 86 Q90 70 150 86" fill="none" {st(3)} opacity="0.5"/>\n'
    rnd = random.Random(9)
    for _ in range(14):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(28, 46)
        body += f'  <circle cx="{90 + d * math.cos(a) * 1.2:.1f}" cy="{104 + d * math.sin(a) * 0.7:.1f}" r="{rnd.uniform(2, 4):.1f}" fill="#FFFFFF" opacity="0.9"/>\n'
    body += shine(62, 104, 14, 6, -30, 0.7)
    TIPS["pudra"] = (0.5, 0.6)
    write("pudra.svg", 180, 160, body, defs)


def cotton_swab() -> None:
    # Kulak çubuğu (çapraz): ince beyaz-mavi çubuk, iki ucunda pamuk
    g = f'    <rect x="40" y="104" width="148" height="12" rx="6" fill="#BFE4FF" {st(5)}/>\n'
    for x in (34, 192):
        g += f'    <ellipse cx="{x}" cy="110" rx="20" ry="15" fill="#FFFFFF" {st(6)}/>\n'
        g += f'    <path d="M{x - 10} 104 Q{x - 2} 100 {x + 6} 103" fill="none" stroke="#E3ECF8" stroke-width="4" stroke-linecap="round"/>\n'
    diagonal("kulak_cubugu", g, 26)


def dropper() -> None:
    # Damlalık (160x220): üstte turuncu lastik, cam gövde, içinde mavi ilaç, ucu altta
    defs = linear("cam", [(0, "#FFFFFF"), (1, "#D8ECFA")], 1, 0) + radial("lastik", [(0, "#FFC59E"), (0.6, "#FF8F5A"), (1, "#E0683A")])
    body = f'  <path d="M58 76 Q50 18 80 14 Q110 18 102 76 Z" fill="url(#lastik)" {st()}/>\n'
    body += f'  <rect x="50" y="72" width="60" height="16" rx="6" fill="#FF8F5A" {st(6)}/>\n'
    body += f'  <path d="M62 88 H98 V170 L84 204 H76 L62 170 Z" fill="url(#cam)" {st()}/>\n'
    body += '  <path d="M66 130 H94 V168 L82 196 H78 L66 168 Z" fill="#6FC3FF" opacity="0.85"/>\n'
    body += '  <path d="M70 96 V160" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" opacity="0.9"/>\n'
    body += shine(70, 34, 7, 12, 10, 0.7)
    TIPS["damla"] = (80 / 160, 206 / 220)
    write("damla.svg", 160, 220, body, defs)


def bandage_roll() -> None:
    # Sargı bezi (200x150): beyaz rulo ve sağa açılan şerit
    defs = radial("rulo", [(0, "#FFFFFF"), (0.7, "#F4F7FF"), (1, "#D5DEF2")])
    body = f'  <path d="M70 118 Q120 132 186 112 L192 136 Q124 156 70 140 Z" fill="#FFFFFF" {st(6)}/>\n'
    body += '  <path d="M90 128 L96 144 M118 132 L122 148 M146 130 L150 146 M172 122 L178 138" stroke="#D5DEF2" stroke-width="3" stroke-linecap="round"/>\n'
    body += f'  <circle cx="70" cy="80" r="56" fill="url(#rulo)" {st()}/>\n'
    for r in (40, 26):
        body += f'  <circle cx="70" cy="80" r="{r}" fill="none" stroke="#D5DEF2" stroke-width="4"/>\n'
    body += f'  <circle cx="70" cy="80" r="12" fill="#E7ECF8" {st(4)}/>\n'
    body += shine(48, 52, 14, 6, -35, 0.9)
    TIPS["sargi"] = (0.45, 0.6)
    write("sargi.svg", 200, 150, body, defs)


def plaster_shapes(cx: float, cy: float, w: float, h: float) -> str:
    # Yara bandı: turuncu-pembe bant, ortada açık ped, kanatlarda delikler ve yıldızlar
    x0, y0 = cx - w / 2, cy - h / 2
    s = f'  <rect x="{x0:g}" y="{y0:g}" width="{w:g}" height="{h:g}" rx="{h / 2:g}" fill="url(#bant)" {st(6)}/>\n'
    pw = w * 0.3
    s += f'  <rect x="{cx - pw / 2:g}" y="{y0 + h * 0.16:g}" width="{pw:g}" height="{h * 0.68:g}" rx="{h * 0.16:g}" fill="#FFF3E8" {st(4)}/>\n'
    for k in range(3):
        for j in range(2):
            s += f'  <circle cx="{cx - pw * 0.27 + k * pw * 0.27:g}" cy="{cy - h * 0.13 + j * h * 0.26:g}" r="{h * 0.045:g}" fill="#F2C9A8"/>\n'
    for side in (-1, 1):
        sx = cx + side * w * 0.33
        s += (f'  <path d="M{sx:g} {cy - h * 0.2:g} L{sx + h * 0.06:g} {cy - h * 0.05:g} L{sx + h * 0.2:g} {cy:g} '
              f'L{sx + h * 0.06:g} {cy + h * 0.05:g} L{sx:g} {cy + h * 0.2:g} L{sx - h * 0.06:g} {cy + h * 0.05:g} '
              f'L{sx - h * 0.2:g} {cy:g} L{sx - h * 0.06:g} {cy - h * 0.05:g} Z" fill="#FFFFFF" opacity="0.9"/>\n')
    s += shine(x0 + h * 0.6, y0 + h * 0.28, h * 0.32, h * 0.08, -6, 0.7)
    return s


PLASTER_DEFS = linear("bant", [(0, "#FFD2B0"), (1, "#FFA98A")])


def plaster() -> None:
    write("bant.svg", 200, 100, plaster_shapes(100, 50, 176, 52), PLASTER_DEFS)


# --- Sıyrık ---

def scrape() -> None:
    # Sıyrık (128x128): pembe-kırmızı yumuşak leke, içinde birkaç sıyrık çizgisi; çocukları korkutmayacak kadar sade
    defs = radial("yara", [(0, "#FFB3B8"), (0.6, "#FF7F8C"), (1, "#EE5A6E")], 0.45, 0.4, 0.7)
    body = f'  <path d="{blob(64, 64, 44, 28, 3, 0.08, 3)}" transform="rotate(-14 64 64)" fill="url(#yara)" stroke="#C94660" stroke-width="4"/>\n'
    for dy, length in ((-10, 46), (2, 58), (14, 40)):
        body += (f'  <path d="M{64 - length / 2:g} {64 + dy + 6:g} Q64 {64 + dy - 4:g} {64 + length / 2:g} {64 + dy - 6:g}" '
                 f'transform="rotate(-14 64 64)" fill="none" stroke="#DE3E5A" stroke-width="4" stroke-linecap="round" opacity="0.75"/>\n')
    body += '  <ellipse cx="44" cy="50" rx="9" ry="4" transform="rotate(-24 44 50)" fill="#FFFFFF" opacity="0.5"/>\n'
    write("yara.svg", 128, 128, body, defs)

    # Kir (128x128): yaranın üstünde kahverengi toz ve küçük taneler
    rnd = random.Random(12)
    dirt = ""
    for k in range(9):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0, 30)
        x, y = 64 + d * math.cos(a) * 1.3, 64 + d * math.sin(a) * 0.8
        r = rnd.uniform(4, 9)
        dirt += f'  <path d="{blob(x, y, r, r * 0.8, 3, 0.18, 30 + k, 24)}" fill="#8A5A30" stroke="#5A3A20" stroke-width="2.5"/>\n'
    for k in range(10):
        x, y = rnd.uniform(26, 102), rnd.uniform(40, 88)
        dirt += f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(1.8, 3.2):.1f}" fill="#6B4222"/>\n'
    write("kir.svg", 128, 128, dirt)

    # Merhem katmanı (128x128): yaranın üstünü örten parlak beyaz krem
    defs = radial("krem", [(0, "#FFFFFF"), (0.7, "#F6FAFF"), (1, "#DCE8F8")], 0.4, 0.35, 0.75)
    body = f'  <path d="{blob(64, 64, 46, 31, 4, 0.1, 21)}" transform="rotate(-14 64 64)" fill="url(#krem)" stroke="#BFD3EE" stroke-width="4"/>\n'
    body += '  <path d="M36 56 Q50 40 72 42" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>\n'
    body += '  <path d="M76 82 Q88 80 96 70" fill="none" stroke="#E4EEFA" stroke-width="4" stroke-linecap="round"/>\n'
    write("merhem_kat.svg", 128, 128, body, defs)


# --- Diğer belirtiler ---

def thorn() -> None:
    # Diken (64x64): tabanı altta, ucu yukarıda hafif kıvrık, yeşil-kahve
    defs = linear("diken", [(0, "#C9A46A"), (1, "#7A5A30")], 1, 0)
    body = f'  <path d="M18 58 Q26 30 40 6 Q42 30 46 58 Z" fill="url(#diken)" {st(4)}/>\n'
    body += '  <path d="M28 50 Q32 32 38 18" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.6"/>\n'
    write("diken.svg", 64, 64, body, defs)


def redness() -> None:
    # Kızarıklık (128x128): kenarı saydam, ortası pembe-kırmızı yumuşak ışıma (hat yok)
    defs = ('    <radialGradient id="kizarik" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FF4D6A" stop-opacity="0.75"/>'
            '<stop offset="0.6" stop-color="#FF6F86" stop-opacity="0.45"/><stop offset="1" stop-color="#FF8FA0" stop-opacity="0"/></radialGradient>\n')
    write("kizarik.svg", 128, 128, '  <circle cx="64" cy="64" r="64" fill="url(#kizarik)"/>\n', defs)


def water_drop() -> None:
    # Su damlası (48x64): ter, gözyaşı ve ilaç damlası; ucu yukarıda
    defs = radial("damla", [(0, "#E6F6FF"), (0.5, "#8FD3FF"), (1, "#3D9BE9")], 0.4, 0.55, 0.7)
    body = '  <path d="M24 4 C30 18 42 30 42 42 A18 18 0 0 1 6 42 C6 30 18 18 24 4 Z" fill="url(#damla)" stroke="#2F6FB5" stroke-width="4" stroke-linejoin="round"/>\n'
    body += '  <ellipse cx="17" cy="40" rx="4" ry="7" fill="#FFFFFF" opacity="0.85"/>\n'
    write("su_damlasi.svg", 48, 64, body, defs)


def spot_shapes(cx: float, cy: float, r: float) -> str:
    # Kaşıntı beneği: kabarık kırmızı daire, açık merkez
    return (f'  <circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="url(#benek)" stroke="#C94660" stroke-width="{r * 0.15:g}"/>\n'
            f'  <circle cx="{cx - r * 0.3:g}" cy="{cy - r * 0.3:g}" r="{r * 0.25:g}" fill="#FFFFFF" opacity="0.55"/>\n')


SPOT_DEFS = radial("benek", [(0, "#FFB3B8"), (0.6, "#FF6F86"), (1, "#E24A66")], 0.45, 0.4, 0.7)


def rash() -> None:
    write("benek.svg", 64, 64, spot_shapes(32, 32, 24), SPOT_DEFS)
    # Pudra katmanı (128x128): beyaz, yumuşak, noktalı toz bulutu
    rnd = random.Random(14)
    body = '  <circle cx="64" cy="64" r="44" fill="#FFFFFF" opacity="0.55"/>\n'
    for _ in range(26):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0, 50)
        body += f'  <circle cx="{64 + d * math.cos(a):.1f}" cy="{64 + d * math.sin(a):.1f}" r="{rnd.uniform(4, 10):.1f}" fill="#FFFFFF" opacity="0.8"/>\n'
    write("pudra_kat.svg", 128, 128, body)


def foam() -> None:
    # Diş macunu köpüğü (128x128): üst üste beyaz daireler, açık mavi gölge
    circles = [(64, 66, 30), (38, 72, 20), (90, 72, 20), (50, 46, 18), (80, 46, 19), (64, 90, 18)]
    shapes = "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in circles)
    body = f'  <g fill="#B8DDF5" stroke="#B8DDF5" stroke-width="7">{shapes}</g>\n  <g fill="#FFFFFF">{shapes}</g>\n'
    for x, y, r in ((44, 40, 5), (86, 62, 4), (60, 86, 4)):
        body += f'  <circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="#7FD3FF" stroke-width="2.5"/>\n'
    write("kopuk.svg", 128, 128, body)


def wrap() -> None:
    # Sarılmış bilek (128x128): beyaz sargı bandı, çapraz katlar, küçük pembe klips
    defs = linear("sargi", [(0, "#FFFFFF"), (1, "#E3E9F7")])
    body = f'  <rect x="10" y="36" width="108" height="56" rx="24" fill="url(#sargi)" {st(6)}/>\n'
    for x in (30, 52, 74, 96):
        body += f'  <path d="M{x - 8} 40 L{x + 8} 88" stroke="#C9D3EA" stroke-width="4" stroke-linecap="round"/>\n'
    body += f'  <rect x="54" y="56" width="20" height="16" rx="4" fill="#FF8FB8" {st(3)}/>\n'
    body += shine(36, 46, 16, 4, -4, 0.8)
    write("sargi_kat.svg", 128, 128, body, defs)


# --- Simgeler (düşünce balonu) ---

def icon_scrape() -> None:
    # Çapraz iki yara bandı (128x128)
    body = ""
    for angle in (-38, 38):
        body += f'  <g transform="rotate({angle} 64 64)">\n{plaster_shapes(64, 64, 118, 38)}  </g>\n'
    write("simge_siyrik.svg", 128, 128, body, PLASTER_DEFS)


def icon_tooth() -> None:
    # Diş (128x128): beyaz azı dişi, yanında kırmızı ağrı çizgileri
    defs = radial("dis", [(0, "#FFFFFF"), (0.7, "#F6F8FF"), (1, "#D5DEF2")])
    body = (f'  <path d="M34 34 Q44 18 64 28 Q84 18 94 34 Q104 54 94 74 Q90 100 82 110 Q74 116 70 98 Q66 84 64 84 '
            f'Q62 84 58 98 Q54 116 46 110 Q38 100 34 74 Q24 54 34 34 Z" fill="url(#dis)" {st(6)}/>\n')
    body += shine(48, 40, 9, 4, -30, 0.9)
    for x1, y1, x2, y2 in ((104, 28, 118, 20), (108, 46, 122, 46), (104, 64, 118, 72)):
        body += f'  <path d="M{x1} {y1} L{x2} {y2}" stroke="#FF4D6A" stroke-width="6" stroke-linecap="round"/>\n'
    write("simge_dis.svg", 128, 128, body, defs)


def icon_ear() -> None:
    # Kulak (128x128): pembe kulak kepçesi, yanında kırmızı ağrı çizgileri
    defs = radial("kulak", [(0, "#FFE1EC"), (0.6, "#FFB3C9"), (1, "#F08AA8")])
    body = f'  <path d="M70 16 Q30 16 28 56 Q28 80 44 92 Q52 98 50 110 Q54 120 66 116 Q78 110 80 94 Q96 80 98 56 Q100 18 70 16 Z" fill="url(#kulak)" {st(6)}/>\n'
    body += f'  <path d="M56 70 Q48 46 66 38 Q82 34 82 54 Q80 66 70 70 Q64 74 66 84" fill="none" {st(5)}/>\n'
    for x1, y1, x2, y2 in ((106, 34, 120, 26), (110, 56, 124, 56), (106, 78, 120, 86)):
        body += f'  <path d="M{x1} {y1} L{x2} {y2}" stroke="#FF4D6A" stroke-width="6" stroke-linecap="round"/>\n'
    write("simge_kulak.svg", 128, 128, body, defs)


def icon_eye() -> None:
    # Göz (128x128): badem biçimli göz, mavi iris, altında gözyaşı damlası
    body = f'  <path d="M14 58 Q64 10 114 58 Q64 104 14 58 Z" fill="#FFFFFF" {st(6)}/>\n'
    body += f'  <circle cx="64" cy="58" r="22" fill="#4FA8FF" {st(5)}/>\n'
    body += f'  <circle cx="64" cy="58" r="10" fill="{OUT}"/>\n'
    body += '  <circle cx="57" cy="50" r="5" fill="#FFFFFF"/>\n'
    body += '  <path d="M86 92 C89 100 94 104 94 109 A8 8 0 0 1 78 109 C78 104 83 100 86 92 Z" fill="#8FD3FF" stroke="#2F6FB5" stroke-width="3.5"/>\n'
    write("simge_goz.svg", 128, 128, body)


def icon_rash() -> None:
    # Kaşıntı (128x128): dört kabarık benek
    body = "".join(spot_shapes(x, y, r) for x, y, r in ((44, 44, 20), (88, 52, 16), (52, 90, 15), (92, 92, 19)))
    write("simge_kasinti.svg", 128, 128, body, SPOT_DEFS)


# --- Albüm ---

def album_icon() -> None:
    # Albüm düğmesi (128x128): mor kapaklı kitap, sırtında şerit, kapağında kalp ve yıldız çıkartması
    defs = linear("kapak", [(0, "#B79CFF"), (1, "#7C5CE6")]) + radial("kalp_c", [(0, "#FFB3C9"), (1, "#FF5C8A")])
    body = f'  <rect x="22" y="14" width="88" height="102" rx="12" fill="#FFF3D6" {st(6)}/>\n'
    body += f'  <rect x="16" y="10" width="88" height="102" rx="12" fill="url(#kapak)" {st(6)}/>\n'
    body += f'  <rect x="16" y="10" width="20" height="102" rx="8" fill="#6A4AD0" {st(5)}/>\n'
    body += f'  <circle cx="70" cy="46" r="20" fill="#FFFFFF" {st(4)}/>\n'
    body += '  <path d="M70 58 C58 50 56 41 62 38 C66 36 69 39 70 42 C71 39 74 36 78 38 C84 41 82 50 70 58 Z" fill="url(#kalp_c)"/>\n'
    body += f'  <circle cx="74" cy="86" r="15" fill="#FFFFFF" {st(4)}/>\n'
    star = " ".join(f"{74 + (10 if k % 2 == 0 else 4.5) * math.sin(math.pi * k / 5):.1f},{86 - (10 if k % 2 == 0 else 4.5) * math.cos(math.pi * k / 5):.1f}" for k in range(10))
    body += f'  <polygon points="{star}" fill="#FFC93D" stroke="#E09A1E" stroke-width="2"/>\n'
    body += shine(48, 24, 14, 4, -10, 0.6)
    write("album.svg", 128, 128, body, defs)


# --- Kart karakteri ---

def card_dog() -> None:
    # Final ekranı (ve ileride menü kartı): boynunda stetoskop, başında yara bandı, gözleri mutlu kapalı gülen köpek
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
    plaster = f'  <g transform="rotate(-24 150 88)">\n{plaster_shapes(150, 88, 64, 22)}  </g>\n'
    tube = "M92 194 Q100 226 128 226 Q156 226 164 194"
    scope = f'  <path d="{tube}" fill="none" stroke="{OUT}" stroke-width="15" stroke-linecap="round"/>\n'
    scope += f'  <path d="{tube}" fill="none" stroke="#3FC1C9" stroke-width="7" stroke-linecap="round"/>\n'
    scope += f'  <path d="M146 222 Q150 234 148 240" fill="none" stroke="{OUT}" stroke-width="12" stroke-linecap="round"/>\n'
    scope += f'  <path d="M146 222 Q150 234 148 240" fill="none" stroke="#3FC1C9" stroke-width="5" stroke-linecap="round"/>\n'
    scope += f'  <circle cx="148" cy="242" r="12" fill="url(#gumus)" {st(5)}/>\n'
    defs = bd + hd.replace(besle.ten("ten", "#E8A45C"), "") + besle.EYE_DEFS + PLASTER_DEFS
    defs += radial("gumus", [(0, "#FFFFFF"), (0.55, "#D3E2F2"), (1, "#8EA8CC")], 0.38, 0.32, 0.8)
    write("kart_doktor.svg", 256, 256, b + scope + h + face + plaster, defs)


def happy_face(name: str) -> str:
    # Mutlu yüz (256 tuval): kapalı yay gözler, pembe yanaklar, açık gülen ağız (kuşta açık gaga); FACES'ten
    f = besle.FACES[name]
    y, dx, rx, ry = f["eye"]
    eye = "#FFFFFF" if f.get("eye_white") else OUT
    face = ""
    for x in (128 - dx, 128 + dx):
        face += f'  <path d="M{x - rx} {y + 4} Q{x} {y - ry - 2} {x + rx} {y + 4}" fill="none" stroke="{eye}" stroke-width="6" stroke-linecap="round"/>\n'
    cy, cdx = f["cheek"]
    face += "".join(f'  <ellipse cx="{x:g}" cy="{cy:g}" rx="17" ry="10" fill="url(#yanak)"/>\n' for x in (128 - cdx, 128 + cdx))
    my, mw = f["mouth"]
    if f.get("beak"):
        face += f'  <path d="M{128 - mw} {my + 2} L128 {my - 9} L{128 + mw} {my + 2} L128 {my + 8} Z" fill="#FF9A3D" {st(4.5)}/>\n'
        face += f'  <path d="M{128 - mw * 0.8} {my + 10} L{128 + mw * 0.8} {my + 10} L128 {my + 26} Z" fill="#E0782A" {st(4.5)}/>\n'
        return face
    k = mw / 13.0
    face += (f'  <path d="M{128 - 16 * k:.1f} {my} Q128 {my - 3} {128 + 16 * k:.1f} {my} Q{128 + 14 * k:.1f} {my + 22 * k:.1f} 128 {my + 22 * k:.1f} '
             f'Q{128 - 14 * k:.1f} {my + 22 * k:.1f} {128 - 16 * k:.1f} {my} Z" fill="#8A2A4A" {st(5)}/>\n')
    face += (f'  <path d="M{128 - 10 * k:.1f} {my + 14 * k:.1f} Q128 {my + 8 * k:.1f} {128 + 10 * k:.1f} {my + 14 * k:.1f} '
             f'Q128 {my + 21 * k:.1f} {128 - 10 * k:.1f} {my + 14 * k:.1f} Z" fill="#FF8FB0"/>\n')
    if f.get("teeth"):
        face += f'  <rect x="{122 * 1:g}" y="{my + 1}" width="5.5" height="8" fill="#FFFFFF" {st(2.5)}/><rect x="128.5" y="{my + 1}" width="5.5" height="8" fill="#FFFFFF" {st(2.5)}/>\n'
    return face


def card_patient(name: str, accessory: str) -> None:
    # Menü kapağındaki iyileşmiş hastalar (256 tuval): mutlu yüzlü hayvan ve tedavisinin izi (bant, termometre,
    # sargı ya da buz kesesi)
    bd, b, hd, h = besle.ANIMALS[name]()
    head_defs = "".join(line + "\n" for line in hd.splitlines() if line and line not in bd)
    defs = bd + head_defs + besle.EYE_DEFS + PLASTER_DEFS
    extra = ""
    f = besle.FACES[name]
    if accessory == "bant":
        extra = f'  <g transform="rotate(-28 96 {f["eye"][0] - 34})">\n{plaster_shapes(96, f["eye"][0] - 34, 60, 20)}  </g>\n'
    elif accessory == "termometre":
        my = f["mouth"][0]
        extra = (f'  <g transform="rotate(-20 150 {my + 6})"><rect x="140" y="{my}" width="58" height="12" rx="6" fill="#FFFFFF" {st(4)}/>'
                 f'<rect x="144" y="{my + 3.5}" width="26" height="5" rx="2.5" fill="#FF4D6A"/>'
                 f'<circle cx="140" cy="{my + 6}" r="8" fill="#FF4D6A" {st(4)}/></g>\n')
    elif accessory == "sargi":
        extra = (f'  <rect x="80" y="226" width="44" height="22" rx="10" fill="#FFFFFF" {st(5)}/>'
                 '<path d="M90 228 L96 246 M102 228 L108 246 M114 228 L118 244" stroke="#C9D3EA" stroke-width="3" stroke-linecap="round"/>\n')
    elif accessory == "buz":
        extra = (f'  <path d="M104 74 Q104 62 116 62 H140 Q152 62 152 74 Q160 88 150 98 Q128 106 106 98 Q96 88 104 74 Z" fill="#A8DDFB" {st(5)}/>'
                 f'<rect x="120" y="50" width="16" height="14" rx="4" fill="#7C6CF0" {st(4)}/>'
                 '<rect x="112" y="76" width="12" height="12" rx="3" fill="#FFFFFF" opacity="0.9"/><rect x="130" y="80" width="12" height="12" rx="3" fill="#FFFFFF" opacity="0.9"/>\n')
    write(f"kart_{name}.svg", 256, 256, b + h + happy_face(name) + extra, defs)


if __name__ == "__main__":
    animals()
    card_dog()
    for animal, thing in (("kedi", "bant"), ("tavsan", "termometre"), ("ayi", "sargi"), ("panda", "buz")):
        card_patient(animal, thing)
    album_icon()
    stethoscope()
    cotton()
    ointment()
    lotion()
    plaster()
    tweezers()
    thermometer()
    spoon()
    ice_pack()
    tissue()
    toothbrush()
    powder_puff()
    cotton_swab()
    dropper()
    bandage_roll()
    scrape()
    thorn()
    redness()
    water_drop()
    rash()
    foam()
    wrap()
    icon_scrape()
    icon_tooth()
    icon_ear()
    icon_eye()
    icon_rash()
    for name, (x, y) in TIPS.items():
        print(f"  tip {name}: Vector2({x:.4f}, {y:.4f})")
    copy("hayvan_besle/gorseller/yildiz.svg", "yildiz.svg")
    copy("hayvan_besle/gorseller/isilti.svg", "isilti.svg")
    copy("hayvan_besle/gorseller/kalp.svg", "kalp.svg")
