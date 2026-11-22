# Noktaları Birleştir SVG üreticisi (sadece Python standart kütüphanesi).
# Çalıştırma: py svg_uret.py   (bu klasöre ve alt klasörlerine yazar)
# Stil Yapboz ile aynı: koyu mor hat, radyal / doğrusal gradyanlı parlak dolgular, beyaz parıltılar.
# Yardımcılar Yapboz'un (o da Hayvanları Besle'nin) svg_uret.py'sinden içe aktarılır; o dosyalara dokunulmaz.
# Bu oyunda hayvan yok.
#
# Her resim TEK BİR dış hat tanımından üretilir (noktalar + her parçanın isteğe bağlı eğrisi). Böylece
# çocuğun çizdiği çizgi ile renkli çizimin dış hattı birebir aynıdır:
# - resimler/<ad>_sahne.svg: arka plandaki sahne (gökyüzü, çimen, deniz...), köşeleri yuvarlak, 1200x900
# - resimler/<ad>.svg: ortaya çıkan nesne (saydam zemin, 1200x900; dış hattı noktaların hattı)
# - resimler/noktalar.json: oyunun okuduğu noktalar, eğriler, hat kalınlığı ve nesnenin dönme / zıplama noktası
# - kart_kalem.svg: final ekranının karakteri (gülen kurşun kalem), ileride menü kartı
# yildiz.svg, isilti.svg Hayvanları Besle'den kopya.
#
# Hat tanımı: dots = [(x, y), ...] sırayla 1, 2, 3...; curves[i] = (kx, ky) ise i. noktadan sonrakine giden
# parça bu kontrol noktasıyla ikinci dereceden eğridir (None: düz). Son parça son noktadan 1. noktaya döner.
# Nesnenin parçaları hattın içinde kalır; en üstte hat LINE kalınlığında çizilir (oyun da aynı kalınlıkta çizer).

import importlib.util
import json
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")

_spec = importlib.util.spec_from_file_location("yapboz_svg", os.path.join(GAMES, "yapboz", "gorseller", "svg_uret.py"))
yapboz = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(yapboz)
besle = yapboz.besle

OUT = besle.OUT
radial, linear, light, dark, mix = besle.radial, besle.linear, besle.light, besle.dark, besle.mix
cloud, flower, tuft, shine, at = yapboz.cloud, yapboz.flower, yapboz.tuft, yapboz.shine, yapboz.at
Pic = yapboz.Pic
W, H = 1200, 900
CORNER = 48          # sahnenin yuvarlak köşesi
LINE = 14            # nesnenin dış hattı (oyundaki çizgi de bu kalınlıkta; noktalar.json "line")
SW = 6               # iç çizgiler

DATA: dict = {}


def st(width: float = SW) -> str:
    return besle.st(width)


def write(name: str, w: float, h: float, body: str, defs: str = "") -> None:
    besle.HERE = HERE
    besle.write(name, w, h, body, defs)


def copy(src: str, name: str) -> None:
    with open(os.path.join(GAMES, src), encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(name)


def outline_d(dots: list, curves: list) -> str:
    d = f"M{dots[0][0]:g} {dots[0][1]:g}"
    for i in range(len(dots)):
        x, y = dots[(i + 1) % len(dots)]
        c = curves[i]
        d += f" Q{c[0]:g} {c[1]:g} {x:g} {y:g}" if c else f" L{x:g} {y:g}"
    return d + " Z"


def save_picture(name: str, dots: list, curves: list, pivot: tuple, scene: Pic, obj: Pic) -> None:
    # Sahne: köşeleri yuvarlak kart (oyunda beyaz kâğıdın içinde durur)
    clip = f'    <clipPath id="kart"><rect width="{W}" height="{H}" rx="{CORNER}"/></clipPath>\n'
    write(f"resimler/{name}_sahne.svg", W, H, f'  <g clip-path="url(#kart)">\n{scene.body}  </g>\n', scene.defs + clip)
    # Nesne: en üstte dış hat (oyundaki çizgiyle aynı)
    body = obj.body + f'  <path d="{outline_d(dots, curves)}" fill="none" {st(LINE)}/>\n'
    write(f"resimler/{name}.svg", W, H, body, obj.defs)
    DATA[name] = {"dots": [list(p) for p in dots], "curves": [list(c) if c else None for c in curves], "pivot": list(pivot)}


def save_data() -> None:
    path = os.path.join(HERE, "resimler", "noktalar.json")
    data = {"size": [W, H], "line": LINE, "pictures": DATA}
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("resimler/noktalar.json")


def clip_def(cid: str, d: str) -> str:
    return f'    <clipPath id="{cid}"><path d="{d}"/></clipPath>\n'


def sky(pic: Pic, top: str, bottom: str, horizon: float = H) -> None:
    gid = pic.uid("gok")
    pic.add(f'  <rect width="{W}" height="{horizon:g}" fill="url(#{gid})"/>\n', linear(gid, [(0, top), (1, bottom)]))


def sun(pic: Pic, x: float, y: float, r: float) -> None:
    yapboz.sun(pic, x, y, r)


def sparkle(x: float, y: float, r: float, color: str = "#FFFFFF", opacity: float = 0.9) -> str:
    # Dört köşeli parıltı
    k = r * 0.28
    d = f"M{x:g} {y - r:g} Q{x + k:g} {y - k:g} {x + r:g} {y:g} Q{x + k:g} {y + k:g} {x:g} {y + r:g} Q{x - k:g} {y + k:g} {x - r:g} {y:g} Q{x - k:g} {y - k:g} {x:g} {y - r:g} Z"
    return f'  <path d="{d}" fill="{color}" opacity="{opacity:g}"/>\n'


def grass_strip(pic: Pic, y: float, seed: int, colors: tuple = ("#9BE07A", "#62BC52")) -> None:
    # Ekranın altını kaplayan dalgalı çimen, üstünde ot öbekleri
    gid = pic.uid("cimen")
    pic.add(f'  <path d="M0 {y:g} Q300 {y - 26:g} 600 {y - 6:g} Q900 {y + 14:g} 1200 {y - 16:g} L1200 {H} L0 {H} Z" fill="url(#{gid})"/>\n',
            linear(gid, [(0, colors[0]), (1, colors[1])]))
    rng = random.Random(seed)
    for _ in range(18):
        pic.add(tuft(rng.uniform(20, 1180), rng.uniform(y + 30, H - 10), rng.uniform(0.7, 1.1), "#4FA544"))


# --- 1. Ev (5 nokta) ---

def house() -> None:
    dots = [(330, 770), (330, 450), (600, 190), (870, 450), (870, 770)]
    curves = [None] * 5
    scene = Pic()
    sky(scene, "#8FD3FF", "#E6F7FF")
    sun(scene, 150, 140, 62)
    scene.add(cloud(470, 110, 0.85) + cloud(1010, 150, 1.0) + cloud(770, 70, 0.5))
    # Uzak tepeler
    g1, g2 = scene.uid("tepe"), scene.uid("tepe")
    scene.add(f'  <path d="M0 610 Q180 520 380 580 Q600 500 820 570 Q1010 510 1200 560 L1200 900 L0 900 Z" fill="url(#{g1})"/>\n',
              linear(g1, [(0, "#C2EFA0"), (1, "#9BDB7A")]))
    scene.add(f'  <path d="M0 690 Q260 640 600 676 Q920 708 1200 660 L1200 900 L0 900 Z" fill="url(#{g2})"/>\n',
              linear(g2, [(0, "#A6E487"), (1, "#7FCB62")]))
    # Ağaç (solda), çalılar, çit
    yapboz.tree(scene, 170, 790, 1.05, "#FF4F5E")
    for bx, by, bs in ((975, 790, 1.0), (1110, 800, 0.85)):
        shapes = "".join(f'<circle cx="{bx + dx * bs:g}" cy="{by + dy * bs:g}" r="{r * bs:g}"/>' for dx, dy, r in
                         ((-44, -20, 34), (0, -40, 44), (44, -20, 34)))
        scene.add(f'  <g fill="{OUT}" stroke="{OUT}" stroke-width="12">{shapes}</g>\n  <g fill="#5DBB4F">{shapes}</g>\n')
        scene.add(shine(bx - 12 * bs, by - 62 * bs, 14 * bs, 6 * bs, -25, 0.6))
        for fx, fy in ((-30, -34), (14, -58), (36, -18)):
            scene.add(f'  <circle cx="{bx + fx * bs:g}" cy="{by + fy * bs:g}" r="{7 * bs:g}" fill="#FF8FB8" stroke="#D9577F" stroke-width="2"/>\n')
    scene.add(yapboz.fence(890, 1200, 760, 0.8))
    # Çimen ve kapıya giden taş yol
    grass_strip(scene, 770, 4)
    gy = scene.uid("yol")
    scene.add(f'  <path d="M545 770 L655 770 Q700 840 760 900 L440 900 Q500 840 545 770 Z" fill="url(#{gy})" {st(5)}/>\n',
              linear(gy, [(0, "#F3DDB0"), (1, "#E2BD82")]))
    for sx, sy, sw in ((600, 800, 60), (585, 846, 80), (612, 886, 96)):
        scene.add(f'  <ellipse cx="{sx}" cy="{sy}" rx="{sw / 2:g}" ry="12" fill="#D9AE70" opacity="0.6"/>\n')
    rng = random.Random(8)
    for _ in range(9):
        fx = rng.choice([rng.uniform(40, 400), rng.uniform(800, 1160)])
        scene.add(flower(fx, rng.uniform(800, 850), rng.uniform(0.9, 1.2), rng.choice(["#FF6FA8", "#FFD23F", "#A46BFF", "#FFFFFF"])))

    obj = Pic()
    roof_d = "M330 450 L600 190 L870 450 Z"
    # Baca (çatının arkasında) ve duman
    gb = obj.uid("baca")
    obj.add(f'  <rect x="728" y="246" width="74" height="190" fill="url(#{gb})" {st()}/>\n', linear(gb, [(0, "#E8735A"), (1, "#B9483C")], 1, 0))
    for k in range(3):
        obj.add(f'  <path d="M{732 + (k % 2) * 34} {290 + k * 40} h34" stroke="#9C3A34" stroke-width="4"/>\n')
    obj.add(f'  <rect x="716" y="230" width="98" height="28" rx="8" fill="#8E3B3B" {st()}/>\n')
    for k, (sx, sy, sr) in enumerate(((770, 200, 18), (800, 150, 24), (850, 96, 30))):
        puff = "".join(f'<circle cx="{sx + dx * sr:g}" cy="{sy + dy * sr:g}" r="{r * sr:g}"/>' for dx, dy, r in
                       ((-0.7, 0.2, 0.7), (0, -0.25, 0.95), (0.75, 0.15, 0.75)))
        obj.add(f'  <g opacity="{0.95 - k * 0.15:g}"><g fill="#D5DEEE" stroke="#D5DEEE" stroke-width="8">{puff}</g>'
                f'<g fill="#FFFFFF">{puff}</g></g>\n')
    # Duvar
    gw = obj.uid("duvar")
    obj.add(f'  <rect x="330" y="440" width="540" height="330" fill="url(#{gw})" {st()}/>\n', linear(gw, [(0, "#FFF1CF"), (1, "#FFD99A")]))
    for k in range(1, 7):
        obj.add(f'  <path d="M336 {470 + k * 44} H864" stroke="#F2C27A" stroke-width="4" opacity="0.6"/>\n')
    # Çatı: kiremit sıraları çatının içine kırpılır
    gr, cr = obj.uid("cati"), obj.uid("catikirp")
    obj.add(f'  <path d="{roof_d}" fill="url(#{gr})" {st()}/>\n',
            linear(gr, [(0, "#FF8A6E"), (1, "#E5483F")]) + clip_def(cr, roof_d))
    tiles = ""
    for row, y in enumerate(range(250, 450, 46)):
        x = 330 + (row % 2) * 30
        while x < 880:
            tiles += f'<path d="M{x - 30} {y} Q{x} {y + 40} {x + 30} {y}" fill="none" stroke="#C23A36" stroke-width="5" stroke-linecap="round"/>'
            x += 60
    obj.add(f'  <g clip-path="url(#{cr})">{tiles}</g>\n')
    obj.add(shine(470, 330, 60, 12, -44, 0.45))
    # Saçak
    obj.add(f'  <rect x="330" y="438" width="540" height="30" rx="6" fill="#B33C3C" {st()}/>\n')
    # Çatı penceresi
    obj.add(f'  <circle cx="600" cy="346" r="46" fill="#FFFDF5" {st()}/>\n')
    gg = obj.uid("cam")
    glass = radial(gg, [(0, "#E8F7FF"), (0.6, "#9ED8FF"), (1, "#5FB2F0")], 0.35, 0.3, 0.8)
    obj.add(f'  <circle cx="600" cy="346" r="32" fill="url(#{gg})" {st(5)}/>\n'
            f'  <path d="M600 314 V378 M568 346 H632" stroke="#FFFDF5" stroke-width="7"/>\n', glass)
    obj.add(shine(588, 332, 10, 5, -40, 0.9))
    # Pencereler: cam, çerçeve, kepenk, çiçek saksısı
    for wx in (395, 705):
        for sx in (wx - 34, wx + 100):
            obj.add(f'  <rect x="{sx}" y="516" width="34" height="108" rx="6" fill="#5DBB8F" {st(5)}/>\n')
            for k in range(4):
                obj.add(f'  <path d="M{sx + 6} {534 + k * 22} H{sx + 28}" stroke="#3E9A6E" stroke-width="4"/>\n')
        obj.add(f'  <rect x="{wx}" y="510" width="100" height="120" rx="10" fill="#FFFDF5" {st()}/>\n')
        obj.add(f'  <rect x="{wx + 12}" y="522" width="76" height="96" rx="6" fill="url(#{gg})" {st(5)}/>\n')
        obj.add(f'  <path d="M{wx + 50} 522 V618 M{wx + 12} 570 H{wx + 88}" stroke="#FFFDF5" stroke-width="8"/>\n')
        obj.add(shine(wx + 32, 542, 12, 5, -40, 0.85))
        for k, c in enumerate(("#FF6FA8", "#FFD23F", "#A46BFF", "#FF6FA8")):
            fx = wx + 14 + k * 24
            obj.add(f'  <circle cx="{fx}" cy="632" r="13" fill="{c}" stroke="{dark(c, 0.35)}" stroke-width="3"/>\n'
                    f'  <circle cx="{fx}" cy="632" r="5" fill="#FFF3B0"/>\n')
        obj.add(f'  <rect x="{wx - 8}" y="638" width="116" height="26" rx="6" fill="#B9784A" {st(5)}/>\n')
    # Kapı
    gd = obj.uid("kapi")
    door = "M540 770 L540 640 Q540 580 600 580 Q660 580 660 640 L660 770 Z"
    obj.add(f'  <path d="{door}" fill="url(#{gd})" {st()}/>\n', linear(gd, [(0, "#8A7BFF"), (1, "#5A4BD6")], 1, 0))
    obj.add(f'  <path d="M562 760 V650 Q562 604 600 602 Q638 604 638 650 V760" fill="none" stroke="#4A3CB8" stroke-width="5"/>\n')
    obj.add(f'  <circle cx="600" cy="630" r="16" fill="url(#{gg})" {st(4)}/>\n')
    obj.add(f'  <circle cx="640" cy="690" r="9" fill="#FFD23F" {st(4)}/>\n')
    obj.add(shine(568, 620, 10, 18, 0, 0.35))
    obj.add(f'  <rect x="520" y="752" width="160" height="18" rx="5" fill="#C9C2DE" {st(5)}/>\n')
    # Duvar parıltısı
    obj.add(shine(380, 490, 30, 10, -20, 0.5))
    save_picture("ev", dots, curves, (600, 770), scene, obj)


# --- 2. Yelkenli (5 nokta) ---

def sailboat() -> None:
    dots = [(250, 600), (380, 742), (840, 742), (960, 600), (600, 130)]
    curves = [(282, 704), (610, 776), (928, 704), (812, 318), (390, 318)]
    scene = Pic()
    sky(scene, "#9AD9FF", "#FFF0D8", 700)
    sun(scene, 1040, 150, 64)
    scene.add(cloud(230, 120, 0.9) + cloud(760, 80, 0.6) + cloud(1090, 330, 0.55))
    # Uzakta ada
    gi = scene.uid("ada")
    scene.add(f'  <path d="M40 690 Q120 610 230 650 Q300 600 380 690 Z" fill="url(#{gi})" {st(5)}/>\n',
              linear(gi, [(0, "#9FDC7E"), (1, "#5FB24E")]))
    for px, py, s in ((150, 640, 0.9), (250, 630, 1.1)):
        b = f'  <path d="M0 0 Q4 -40 -6 -80" fill="none" stroke="#9A6A3E" stroke-width="10" stroke-linecap="round"/>\n'
        for a in (-150, -110, -60, -20):
            r = math.radians(a)
            b += f'  <path d="M-6 -80 Q{-6 + 34 * math.cos(r):.1f} {-96 + 30 * math.sin(r):.1f} {-6 + 62 * math.cos(r):.1f} {-70 + 46 * math.sin(r):.1f}" fill="none" stroke="#4FA544" stroke-width="12" stroke-linecap="round"/>\n'
        scene.add(at(b, px, py, s))
    # Deniz: sıra sıra dalgalar
    gs = scene.uid("deniz")
    scene.add(f'  <rect y="680" width="{W}" height="{H - 680}" fill="url(#{gs})"/>\n', linear(gs, [(0, "#6CCBF5"), (1, "#2F8FD6")]))
    for k, y in enumerate((700, 740, 790, 845, 890)):
        x = -40 + (k % 2) * 50
        waves = ""
        while x < W + 60:
            waves += f'<path d="M{x} {y} q25 -16 50 0 q25 16 50 0" fill="none" stroke="#FFFFFF" stroke-width="{4 + k}" stroke-linecap="round" opacity="{0.35 + k * 0.08:g}"/>'
            x += 160
        scene.add(f'  {waves}\n')
    # Şamandıra
    scene.add(f'  <path d="M1060 790 L1072 720 L1108 720 L1120 790 Z" fill="#FF5A6E" {st(5)}/>\n'
              f'  <rect x="1066" y="744" width="48" height="18" fill="#FFFFFF"/>\n'
              f'  <path d="M1060 790 L1072 720 L1108 720 L1120 790 Z" fill="none" {st(5)}/>\n'
              f'  <circle cx="1090" cy="708" r="12" fill="#FFD23F" {st(4)}/>\n')
    for sx, sy in ((520, 230), (880, 420), (140, 400)):
        scene.add(sparkle(sx, sy, 16))

    obj = Pic()
    # Ana yelken (kırmızı-beyaz çizgili) ve flok (sarı)
    main = "M600 130 Q390 318 250 600 L600 600 Z"
    jib = "M600 130 L600 600 L960 600 Q812 318 600 130 Z"
    cm = obj.uid("yelkenkirp")
    obj.add(f'  <path d="{main}" fill="#FFFDF5" {st()}/>\n', clip_def(cm, main))
    stripes = "".join(f'<rect x="200" y="{y}" width="420" height="58" fill="#FF5A6E"/>' for y in range(190, 600, 116))
    obj.add(f'  <g clip-path="url(#{cm})">{stripes}<path d="M600 130 Q470 330 400 600" fill="none" stroke="#3B2F6B" stroke-width="4" opacity="0.25"/></g>\n')
    obj.add(f'  <path d="{main}" fill="none" {st()}/>\n')
    gj = obj.uid("flok")
    obj.add(f'  <path d="{jib}" fill="url(#{gj})" {st()}/>\n', linear(gj, [(0, "#FFE680"), (1, "#FFB627")], 1, 0.4))
    for k in range(1, 4):
        obj.add(f'  <path d="M600 {130 + k * 118} Q{700 + k * 40} {200 + k * 118} {640 + k * 80} 600" fill="none" stroke="#E59A1E" stroke-width="4" opacity="0.5"/>\n')
    obj.add(shine(500, 330, 40, 10, -60, 0.5) + shine(690, 300, 34, 9, 55, 0.55))
    # Gövde: mavi, beyaz şerit ve lombozlar
    hull = "M250 600 Q282 704 380 742 Q610 776 840 742 Q928 704 960 600 Z"
    gh, ch = obj.uid("govde"), obj.uid("govdekirp")
    obj.add(f'  <path d="{hull}" fill="url(#{gh})" {st()}/>\n', linear(gh, [(0, "#5AB0FF"), (1, "#2D6FD0")]) + clip_def(ch, hull))
    obj.add(f'  <g clip-path="url(#{ch})"><rect x="200" y="590" width="800" height="34" fill="#FFFFFF"/>'
            f'<path d="M200 700 Q600 740 1000 700 L1000 800 L200 800 Z" fill="#244F9E" opacity="0.35"/></g>\n')
    obj.add(f'  <path d="M246 600 H964" {st(8)}/>\n')
    for px in (420, 520, 620, 720, 820):
        obj.add(f'  <circle cx="{px}" cy="664" r="19" fill="#FFFDF5" {st(5)}/>\n'
                f'  <circle cx="{px}" cy="664" r="11" fill="#9ED8FF"/>\n'
                f'  <circle cx="{px - 4}" cy="660" r="4" fill="#FFFFFF"/>\n')
    obj.add(shine(330, 640, 24, 8, 40, 0.5))
    # Direk ve bayrak
    obj.add(f'  <path d="M600 604 V96" stroke="{OUT}" stroke-width="20" stroke-linecap="round"/>\n'
            f'  <path d="M600 600 V100" stroke="#B9784A" stroke-width="9" stroke-linecap="round"/>\n')
    obj.add(f'  <path d="M606 92 Q650 84 690 104 Q650 112 606 134 Z" fill="#4FD18B" {st(5)}/>\n')
    # Gövdenin altında köpük
    for fx in (330, 450, 600, 750, 880):
        obj.add(f'  <ellipse cx="{fx}" cy="{752 + (fx % 3) * 3}" rx="46" ry="12" fill="#FFFFFF" opacity="0.85"/>\n')
    save_picture("yelkenli", dots, curves, (600, 742), scene, obj)


# --- 3. Taç (5 nokta) ---

def crown() -> None:
    dots = [(330, 720), (870, 720), (930, 300), (600, 190), (270, 300)]
    curves = [(600, 740), (920, 520), (790, 470), (410, 470), (280, 520)]
    scene = Pic()
    # Mor kadife perde ve ışık
    sky(scene, "#5B3C9E", "#9C6BD8")
    for k in range(9):
        x = k * 150
        scene.add(f'  <path d="M{x - 10} 0 Q{x + 40} 450 {x - 10} 900" fill="none" stroke="#4A2E86" stroke-width="22" opacity="0.35"/>\n')
    gl = scene.uid("isik")
    scene.add(f'  <ellipse cx="600" cy="480" rx="520" ry="430" fill="url(#{gl})"/>\n',
              f'    <radialGradient id="{gl}" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF4C2" stop-opacity="0.8"/>'
              f'<stop offset="1" stop-color="#FFF4C2" stop-opacity="0"/></radialGradient>\n')
    # Saçaklı perde üstü
    scene.add(f'  <path d="M0 0 H1200 V70 Q1100 120 1000 70 Q900 120 800 70 Q700 120 600 70 Q500 120 400 70 Q300 120 200 70 Q100 120 0 70 Z" fill="#D9364F" {st(5)}/>\n')
    for x in range(100, 1200, 200):
        scene.add(f'  <path d="M{x} 92 L{x} 130" stroke="#FFC233" stroke-width="6"/><circle cx="{x}" cy="138" r="12" fill="#FFC233" {st(4)}/>\n')
    # Kırmızı yastık ve püsküller
    gc = scene.uid("yastik")
    scene.add(f'  <path d="M170 760 Q160 700 260 690 Q600 650 940 690 Q1040 700 1030 760 Q1040 830 940 840 Q600 880 260 840 Q160 830 170 760 Z" '
              f'fill="url(#{gc})" {st()}/>\n', radial(gc, [(0, "#FF7A8A"), (0.6, "#E2384F"), (1, "#A82240")], 0.45, 0.3, 0.8))
    scene.add(f'  <path d="M240 760 Q600 730 960 760" fill="none" stroke="#FFC233" stroke-width="7" stroke-dasharray="4 14" stroke-linecap="round"/>\n')
    for tx in (180, 1020):
        lines = "".join(f'<path d="M{tx + dx} 806 L{tx + dx * 1.4:g} 846" stroke="#E59A1E" stroke-width="4" stroke-linecap="round"/>'
                        for dx in (-10, 0, 10))
        scene.add(f'  <path d="M{tx - 16} 800 Q{tx} 788 {tx + 16} 800 L{tx + 24} 850 Q{tx} 862 {tx - 24} 850 Z" fill="#FFC233" {st(5)}/>\n'
                  f'  {lines}\n  <rect x="{tx - 18}" y="790" width="36" height="14" rx="6" fill="#E59A1E" {st(4)}/>\n'
                  f'  <circle cx="{tx}" cy="772" r="17" fill="#FFC233" {st(5)}/>\n' + shine(tx - 5, 766, 6, 3, -40, 0.9))
    for sx, sy, r in ((160, 260, 22), (1040, 230, 26), (240, 520, 14), (980, 520, 16), (600, 120, 0)):
        if r:
            scene.add(sparkle(sx, sy, r, "#FFF4C2"))

    obj = Pic()
    body = outline_d(dots, curves)
    gb, cb = obj.uid("altin"), obj.uid("tackirp")
    obj.add(f'  <path d="{body}" fill="url(#{gb})" {st()}/>\n',
            linear(gb, [(0, "#FFF09A"), (0.45, "#FFC93D"), (1, "#E59A1E")]) + clip_def(cb, body))
    # İç gölge, yansıma şeritleri ve alt bant
    obj.add(f'  <g clip-path="url(#{cb})">'
            f'<path d="M270 300 Q420 520 600 420 Q780 520 930 300 L930 360 Q780 560 600 470 Q420 560 270 360 Z" fill="#E59A1E" opacity="0.35"/>'
            f'<path d="M380 300 L460 720 L520 720 L430 300 Z" fill="#FFFFFF" opacity="0.35"/>'
            f'<rect x="200" y="600" width="800" height="140" fill="#F2A92E"/>'
            f'<rect x="200" y="600" width="800" height="22" fill="#FFE27A"/></g>\n')
    obj.add(f'  <path d="M318 600 Q600 620 882 600" fill="none" {st()}/>\n')
    # Bant taşları
    gems = [("#FF4F6E", 600, 664, 34), ("#4FA8FF", 455, 664, 26), ("#4FA8FF", 745, 664, 26), ("#4FD18B", 355, 664, 18), ("#4FD18B", 845, 664, 18)]
    for color, gx, gy, r in gems:
        gid = obj.uid("tas")
        obj.add(f'  <path d="M{gx} {gy - r} L{gx + r} {gy} L{gx} {gy + r} L{gx - r} {gy} Z" fill="url(#{gid})" {st(5)}/>\n'
                + shine(gx - r * 0.3, gy - r * 0.35, r * 0.28, r * 0.14, -40, 0.9),
                radial(gid, [(0, light(color, 0.6)), (0.6, color), (1, dark(color, 0.3))], 0.35, 0.3, 0.8))
    # Ortada büyük kalp taş, yanlarda yuvarlak taşlar
    gh = obj.uid("kalp")
    obj.add(f'  <path d="M600 540 C540 500 530 440 570 430 Q592 426 600 450 Q608 426 630 430 C670 440 660 500 600 540 Z" fill="url(#{gh})" {st(5)}/>\n'
            + shine(580, 450, 9, 5, -40, 0.9), radial(gh, [(0, "#FFB3C6"), (0.6, "#FF4F7E"), (1, "#C22B5A")], 0.35, 0.3, 0.8))
    for gx, gy, c in ((395, 470, "#A66BFF"), (805, 470, "#A66BFF")):
        gid = obj.uid("yuvarlak")
        obj.add(f'  <circle cx="{gx}" cy="{gy}" r="24" fill="url(#{gid})" {st(5)}/>\n' + shine(gx - 8, gy - 9, 7, 4, -40, 0.9),
                radial(gid, [(0, light(c, 0.6)), (0.6, c), (1, dark(c, 0.3))], 0.35, 0.3, 0.8))
    # Uçlarda inciler
    for px, py in dots[2:]:
        gid = obj.uid("inci")
        obj.add(f'  <circle cx="{px}" cy="{py - 26}" r="30" fill="url(#{gid})" {st()}/>\n' + shine(px - 10, py - 38, 9, 5, -40, 0.95),
                radial(gid, [(0, "#FFFFFF"), (0.6, "#F4EEFF"), (1, "#C9BEE8")], 0.35, 0.3, 0.8))
    obj.add(sparkle(420, 390, 18) + sparkle(800, 360, 14) + sparkle(560, 300, 12))
    save_picture("tac", dots, curves, (600, 720), scene, obj)


# --- Kart / final karakteri: gülen kurşun kalem ---

def card_pencil() -> None:
    defs = (linear("govde", [(0, "#FFD23F"), (0.5, "#FFE680"), (1, "#F2A92E")], 0, 1)
            + linear("silgi", [(0, "#FFB3C6"), (1, "#FF7A9A")]) + linear("metal", [(0, "#E6E9F5"), (0.5, "#FFFFFF"), (1, "#AEB5D0")])
            + linear("ahsap", [(0, "#FFE1B8"), (1, "#E8B57A")]) + besle.EYE_DEFS)
    b = ""
    # Kalemin ucundan çıkan noktalı iz ve renkli noktalar
    b += f'  <path d="M246 178 Q222 244 140 236 Q96 230 54 240" fill="none" stroke="#8A6CF0" stroke-width="7" stroke-linecap="round" stroke-dasharray="2 16"/>\n'
    for x, y, c in ((200, 232, "#4FD18B"), (128, 234, "#4FA8FF"), (54, 240, "#FF5A6E")):
        b += f'  <circle cx="{x}" cy="{y}" r="12" fill="{c}" {st(5)}/>\n'
        b += f'  <circle cx="{x - 4}" cy="{y - 4}" r="3.5" fill="#FFFFFF" opacity="0.8"/>\n'
    # Eğik kalem (ucu sağ aşağıda): silgi, metal halka, sarı gövde, ahşap uç, grafit
    g = '  <g transform="translate(150 112) rotate(30) scale(0.82) translate(-180 -130)">\n'
    g += f'    <rect x="40" y="96" width="44" height="68" rx="18" fill="url(#silgi)" {st(7)}/>\n'
    g += f'    <rect x="74" y="92" width="34" height="76" rx="6" fill="url(#metal)" {st(7)}/>\n'
    g += f'    <path d="M84 94 V166 M96 94 V166" stroke="#9AA2C2" stroke-width="4"/>\n'
    g += f'    <rect x="104" y="94" width="150" height="72" fill="url(#govde)" {st(7)}/>\n'
    g += f'    <path d="M108 118 H250 M108 142 H250" stroke="#E59A1E" stroke-width="4" opacity="0.6"/>\n'
    g += f'    <path d="M254 94 L318 130 L254 166 Z" fill="url(#ahsap)" {st(7)}/>\n'
    g += f'    <path d="M296 118 L318 130 L296 142 Z" fill="#4A3F6E"/>\n'
    g += f'    <path d="M254 94 L318 130 L254 166" fill="none" {st(7)}/>\n'
    g += f'    <ellipse cx="140" cy="106" rx="30" ry="5" fill="#FFFFFF" opacity="0.75"/>\n'
    g += '  </g>\n'
    b += g
    # Yüz (gövdenin ortasında, dik)
    cx, cy = 152, 106
    for dx in (-16, 16):
        b += f'  <ellipse cx="{cx + dx}" cy="{cy - 4}" rx="8" ry="11" fill="url(#goz)"/>\n'
        b += f'  <ellipse cx="{cx + dx - 3}" cy="{cy - 8}" rx="3.2" ry="3.6" fill="#FFFFFF"/>\n'
    b += "".join(f'  <ellipse cx="{cx + dx}" cy="{cy + 11}" rx="8" ry="5" fill="url(#yanak)"/>\n' for dx in (-26, 26))
    b += f'  <path d="M{cx - 11} {cy + 7} Q{cx} {cy + 9} {cx + 11} {cy + 7} Q{cx + 9} {cy + 23} {cx} {cy + 23} Q{cx - 9} {cy + 23} {cx - 11} {cy + 7} Z" fill="#8A2A4A" {st(4)}/>\n'
    b += f'  <path d="M{cx - 6} {cy + 19} Q{cx} {cy + 15} {cx + 6} {cy + 19} Q{cx} {cy + 23} {cx - 6} {cy + 19} Z" fill="#FF7FA3"/>\n'
    write("kart_kalem.svg", 300, 260, b, defs)


if __name__ == "__main__":
    card_pencil()
    copy("hayvan_besle/gorseller/yildiz.svg", "yildiz.svg")
    copy("hayvan_besle/gorseller/isilti.svg", "isilti.svg")
    house()
    sailboat()
    crown()
    save_data()
