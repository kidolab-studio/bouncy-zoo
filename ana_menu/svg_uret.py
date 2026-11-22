# Ana menü görsellerini üretir. Proje kökünden:  python ana_menu/svg_uret.py
#
# 1) Oyun kartlarının görselleri: ana_menu/kartlar/<oyun>.svg
#    Her kart, o oyunun kendi SVG'lerinden (oyunlar/ klasöründen okunur, oyunlara dokunulmaz) birleştirilir.
#    Tuval 320x300, merkez (0, 0): viewBox="-160 -150 320 300". Parça yerleştirme Godot'taki Sprite2D gibidir:
#    parca(dosya, genislik, (x, y), aci) → dosya genislik kadar geniş, merkezi (x, y)'de, aci radyan döndürülmüş.
# 2) Kategori sekmesi simgeleri: ana_menu/gorseller/sekme_<kategori>.svg (120x120)
# 3) Ses düğmesi simgeleri: ana_menu/gorseller/ses_<mod>.svg (120x120; hepsi açık / sadece efektler / sessiz)
#    ve bilgi düğmesinin simgesi: ana_menu/gorseller/bilgi.svg
#
# Yeni oyun: KARTLAR'a bir fonksiyon ekle (ya da oyunun tek bir SVG'sini parca() ile ortala), betiği çalıştır,
# sonra Godot'u açıp yeni SVG'nin içe aktarma ayarını 2x + mipmap yap (diğer kartlarınki gibi).

import math
import os
import re

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
O = os.path.join(KOK, "oyunlar")
KART_KLASORU = os.path.join(KOK, "ana_menu", "kartlar")
GORSEL_KLASORU = os.path.join(KOK, "ana_menu", "gorseller")

_sayac = [0]


def _oku(yol):
    with open(os.path.join(O, yol), encoding="utf-8") as f:
        return f.read()


def _yaz(yol, icerik):
    with open(yol, "w", encoding="utf-8", newline="\n") as f:
        f.write(icerik)


def _boyut(kok_etiketi):
    """<svg ...> etiketinden (genişlik, yükseklik, viewBox)"""
    def sayi(ad):
        m = re.search(r'\b%s="([\d.]+)' % ad, kok_etiketi)
        return float(m.group(1)) if m else None
    m = re.search(r'viewBox="([^"]+)"', kok_etiketi)
    kutu = [float(v) for v in m.group(1).replace(",", " ").split()] if m else None
    w, h = sayi("width"), sayi("height")
    if kutu is None:
        kutu = [0.0, 0.0, w, h]
    return (w or kutu[2]), (h or kutu[3]), kutu


def _renk_degistir(govde, renk_haritasi):
    for eski, yeni in renk_haritasi.items():
        govde = re.sub(re.escape(eski), yeni, govde, flags=re.IGNORECASE)
    return govde


def _siluet(govde, renk):
    """Bütün dolgu, çizgi ve degrade renklerini tek renge çevirir (Gölge Eşleştirme'deki gölge gibi)"""
    govde = re.sub(r'(fill|stroke|stop-color)="(?!none)[^"]*"', r'\1="%s"' % renk, govde)
    govde = re.sub(r'(fill|stroke|stop-color):\s*(?!none)[^;"]+', r'\1:%s' % renk, govde)
    return govde


def parca(dosya, genislik, konum=(0, 0), aci=0.0, opaklik=1.0, ayna=False, merkez=None, olcek_y=1.0,
          renkler=None, siluet=None):
    """Oyunun SVG'sini, Sprite2D gibi yerleştirilmiş bir <g> olarak döndürür.
    merkez: parçanın kendi tuvalinde (x, y) noktası konuma gelir (varsayılan: tuvalin ortası)."""
    metin = _oku(dosya)
    metin = re.sub(r"<\?xml[^>]*\?>", "", metin)
    metin = re.sub(r"<!--.*?-->", "", metin, flags=re.S)
    m = re.search(r"<svg\b[^>]*>", metin)
    kok_etiketi = m.group(0)
    govde = metin[m.end():metin.rindex("</svg>")]
    w, h, kutu = _boyut(kok_etiketi)
    # Kimlikler çakışmasın: her parçanın id'lerine önek
    _sayac[0] += 1
    onek = "p%d_" % _sayac[0]
    govde = re.sub(r'\bid="([^"]+)"', lambda k: 'id="%s%s"' % (onek, k.group(1)), govde)
    govde = re.sub(r"url\(#([^)]+)\)", lambda k: "url(#%s%s)" % (onek, k.group(1)), govde)
    govde = re.sub(r'(xlink:href|href)="#([^"]+)"', lambda k: '%s="#%s%s"' % (k.group(1), onek, k.group(2)), govde)
    if renkler:
        govde = _renk_degistir(govde, renkler)
    if siluet:
        govde = _siluet(govde, siluet)
    s = genislik / w
    mx, my = merkez if merkez else (w / 2.0, h / 2.0)
    donusum = "translate(%.2f %.2f)" % konum
    if aci:
        donusum += " rotate(%.2f)" % math.degrees(aci)
    donusum += " scale(%.4f %.4f)" % (-s if ayna else s, s * olcek_y)
    donusum += " translate(%.2f %.2f)" % (-mx, -my)
    donusum += " scale(%.4f %.4f) translate(%.2f %.2f)" % (w / kutu[2], h / kutu[3], -kutu[0], -kutu[1])
    ek = ' opacity="%.2f"' % opaklik if opaklik < 1.0 else ""
    return '<g transform="%s"%s>%s</g>\n' % (donusum, ek, govde)


def grup(icerik, konum=(0, 0), olcek=1.0, aci=0.0, ek=""):
    donusum = "translate(%.2f %.2f)" % konum
    if aci:
        donusum += " rotate(%.2f)" % math.degrees(aci)
    if olcek != 1.0:
        donusum += " scale(%.4f)" % olcek
    return '<g transform="%s"%s>\n%s</g>\n' % (donusum, ek, "".join(icerik))


def kart_svg(icerik):
    return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            'width="320" height="300" viewBox="-160 -150 320 300">\n%s</svg>\n' % "".join(icerik))


# --- Kartlar (her biri oyunun kendi parçalarıyla) ---

def ucan_kus():
    return [
        parca("meyve_topla/gorseller/bulut.svg", 150, (-62, 64), opaklik=0.95),
        parca("ucan_kus/kus_2.svg", 214, (12, -10), -0.08),
    ]


def dondurmaci():
    return [grup([
        parca("dondurmaci/gorseller/kulah.svg", 100, (0, 58)),
        parca("dondurmaci/gorseller/top_yaban_mersini.svg", 118, (0, -12)),
        parca("dondurmaci/gorseller/top_cilek.svg", 118, (0, -64)),
    ], (0, 4), 0.98)]


def yol_yap():
    return [
        parca("yol_yap/gorseller/hediye_kutu.svg", 140, (44, 42)),
        parca("yol_yap/gorseller/hediye_kapak.svg", 162, (56, -30), 0.28),
        parca("yol_yap/gorseller/bilye.svg", 110, (-66, 50)),
        parca("cikarma/gorseller/yildiz.svg", 40, (-34, -44), 0.2),
    ]


def hafiza():
    return [
        parca("hafiza/temalar/hayvanlar/arka.svg", 140, (-46, 6), -0.22),
        grup([
            parca("hafiza/gorseller/kart_on.svg", 150, (0, 0)),
            parca("hafiza/temalar/hayvanlar/aslan.svg", 120, (0, -3)),
        ], (38, 8), aci=0.14),
    ]


def meyve_topla():
    return [grup([
        parca("meyve_topla/gorseller/kirpi_ayak.svg", 50, (-34, -12)),
        parca("meyve_topla/gorseller/kirpi_hazir.svg", 190, (0, -90)),
        parca("meyve_topla/gorseller/kirpi_ayak.svg", 50, (24, -10)),
        parca("meyve_topla/gorseller/sepet_arka.svg", 200, (0, -200)),
        parca("meyve_topla/gorseller/meyveler/elma.svg", 56, (-42, -228), -0.2),
        parca("meyve_topla/gorseller/meyveler/portakal.svg", 56, (40, -228), 0.2),
        parca("meyve_topla/gorseller/meyveler/cilek.svg", 58, (0, -250)),
        parca("meyve_topla/gorseller/sepet_on.svg", 200, (0, -200)),
    ], (0, 130), 0.8)]


def golge_eslestirme():
    # Oyundaki siluet rengi (golge.gdshader: shadow_color)
    tavsan = "golge_eslestirme/esyalar/hayvanlar/tavsan.svg"
    return [
        parca(tavsan, 170, (-44, 8), -0.06, siluet="#292E66", opaklik=0.58),
        parca(tavsan, 170, (44, 0), 0.1),
    ]


def kostebek():
    cukur = 236.0 / 320.0
    agiz = (0, 62)
    yer = (0, agiz[1] - 104.0 * cukur)
    return [
        parca("kostebek/gorseller/cukur_arka.svg", 236, agiz),
        parca("kostebek/gorseller/kostebek.svg", 256 * cukur, yer),
        parca("kostebek/gorseller/yuz_normal.svg", 256 * cukur, yer),
        parca("kostebek/gorseller/kask.svg", 256 * cukur, yer),
        parca("kostebek/gorseller/cukur_on.svg", 236, agiz),
    ]


def toplama():
    seker = "toplama/nesneler/seker.svg"
    return [
        parca(seker, 132, (-76, 8), -0.15),
        parca("toplama/gorseller/arti.svg", 50, (-8, 8)),
        parca(seker, 120, (60, -32), 0.12),
        parca(seker, 120, (66, 48), -0.08),
    ]


def cikarma():
    seker = "cikarma/nesneler/seker.svg"
    return [
        parca(seker, 120, (-70, -32), -0.12),
        parca(seker, 120, (-64, 48), 0.08),
        parca("cikarma/gorseller/eksi.svg", 50, (4, 8)),
        parca(seker, 132, (74, 8), 0.15, opaklik=0.4),
    ]


def araba_yarisi():
    # Arabanın 360x224 tuvali; şoför (aslan) ve direksiyon camın içine kırpılır (oyundaki gibi)
    g = "araba_yarisi/gorseller/"
    ic = _oku(g + "araba_ic.svg")
    cam = re.search(r'<path d="([^"]+)"', ic).group(1)
    kirpma = '<clipPath id="araba_cam"><path d="%s"/></clipPath>\n' % cam
    ic_parca = [
        parca(g + "araba_ic.svg", 360, (180, 112)),
        '<g clip-path="url(#araba_cam)">\n',
        parca(g + "hayvanlar/aslan.svg", 0.6 * 256, (182, 82)),
        parca(g + "direksiyon.svg", 360, (180, 112)),
        "</g>\n",
    ]
    tuval = ['<defs>%s</defs>\n' % kirpma] + ic_parca + [parca(g + "araba_kirmizi.svg", 360, (180, 112))]
    for x in (98.0, 262.0):
        tuval.append(parca(g + "teker.svg", 88, (x, 178)))
    k = 0.72
    return [
        parca(g + "bayrak.svg", 80, (86, -44), 0.1),
        '<g transform="translate(%.2f %.2f) scale(%.3f)">\n%s</g>\n' % (-6 - 180 * k, 70 - 218 * k, k, "".join(tuval)),
    ]


def zipla_zipla():
    g = "zipla_zipla/gorseller/"
    basamak_y = 54.0
    genislik = 170.0
    yuzey = basamak_y + (20.0 - 50.0) * genislik / 160.0      # basamağın üst kenarı
    govde = (10.0, yuzey - (238.0 - 128.0) * 156.0 / 256.0)
    return [
        parca(g + "basamak_cim.svg", genislik, (10, basamak_y)),
        parca(g + "kurbaga_bacak.svg", 156, govde),
        parca(g + "kurbaga_bacak.svg", 156, govde, ayna=True),
        parca(g + "kurbaga_govde.svg", 156, govde),
        parca(g + "kurbaga_yuz_normal.svg", 156, govde),
        parca(g + "lolipop.svg", 84, (-92, -28), -0.3),
    ]


def sihirli_bahce():
    return [
        parca("sihirli_bahce/gorseller/bitkiler/aycicegi_4.svg", 214, (40, -18), 0.06),
        parca("sihirli_bahce/gorseller/kese_pembe.svg", 112, (-66, 44), -0.22),
        parca("cikarma/gorseller/yildiz.svg", 38, (-78, -50), 0.2),
    ]


def muzik_kutusu():
    g = "muzik_kutusu/gorseller/"
    return [
        parca(g + "ikon_ksilofon.svg", 222, (4, 16), -0.06),
        parca(g + "nota_cift.svg", 72, (-80, -62), -0.2, renkler={"#FFFFFF": "#FF6FB5"}),
        parca(g + "nota.svg", 56, (92, -66), 0.2, renkler={"#FFFFFF": "#4AA3FF"}),
    ]


def robot_fabrikasi():
    p = "robot_fabrikasi/gorseller/parcalar/"
    robot = []
    for yon in (-1, 1):
        robot.append(parca(p + "kol_sari.svg", 108, (yon * 54.6, -128), yon * -0.28, merkez=(80, 26)))
    for yon in (-1, 1):
        robot.append(parca(p + "tekerlek_mavi.svg", 70, (yon * 42.0, -35)))
    robot += [
        parca(p + "govde_kare_kirmizi.svg", 130, (0, -114)),
        parca("robot_fabrikasi/gorseller/boyun.svg", 44, (0, -165), olcek_y=0.35),
        parca(p + "kafa_daire_mavi.svg", 112, (0, -206)),
        parca(p + "anten_yesil.svg", 76, (0, -283)),
    ]
    # Yanık gözler (oyunda robot uyanınca çizilen ışıklar)
    for yon in (-1, 1):
        x, y = yon * 11.0, -206 + 6.3
        robot.append('<circle cx="%.1f" cy="%.1f" r="16" fill="#80FFFF" opacity="0.22"/>' % (x, y))
        robot.append('<circle cx="%.1f" cy="%.1f" r="6.6" fill="#99FFFF"/>' % (x, y))
        robot.append('<circle cx="%.1f" cy="%.1f" r="2.3" fill="#FFFFFF"/>\n' % (x - 2, y - 2))
    return [
        parca(p + "disli_sari.svg", 88, (-86, 56), 0.3),
        grup(robot, (26, 112), 0.74),
    ]


def tren_rayi():
    # Tren Rayı: ray üstünde lokomotif ve yolcu vagonu (penceresinde tavşan), bacadan yükselen duman pufları
    g = "tren_rayi/gorseller/"
    sahne = [
        parca(g + "ray_duz.svg", 160, (-80, 0)),
        parca(g + "ray_duz.svg", 160, (80, 0)),
        parca(g + "vagon_yolcu_kirmizi.svg", 128, (-76, 0)),
        parca(g + "hayvanlar/tavsan.svg", 50, (-90, -10)),
        parca(g + "lokomotif.svg", 166, (70, 0)),
    ]
    duman = [
        parca(g + "duman.svg", 40, (112, -38), opaklik=0.95),
        parca(g + "duman.svg", 54, (96, -82), opaklik=0.9),
        parca(g + "duman.svg", 70, (66, -128), opaklik=0.85),
    ]
    return [grup(sahne, (-2, 58), 1.03, -0.16), grup(duman, (-2, 58), 1.03)]


def hayvan_besle():
    # Hayvanları Besle: ağzı açık mutlu tavşan, yanında tabakta havuç ve üstünde kalpler
    g = "hayvan_besle/gorseller/"
    return [
        parca(g + "tabak.svg", 128, (74, 100)),
        parca(g + "yiyecekler/havuc.svg", 96, (78, 58), 0.5),
        parca(g + "kart_tavsan.svg", 206, (-40, 6)),
        parca(g + "kalp.svg", 40, (40, -92), -0.2),
        parca(g + "kalp.svg", 28, (80, -116), 0.25),
    ]


def hayvan_banyosu():
    # Hayvan Banyosu: köpüklü küvette başında köpük olan mutlu köpek, yanında sünger ve uçuşan kabarcıklar.
    # Küvetin iki parçası suyun merkezinden (320, 64) aynı noktaya oturur; köpeğin ayakları suyun içinde.
    g = "hayvan_banyosu/gorseller/"
    su = (0, 34)
    return [
        parca(g + "kuvet_arka.svg", 300, su, merkez=(320, 64)),
        parca(g + "kart_kopek.svg", 200, (0, 44), merkez=(128, 246)),
        parca(g + "kuvet_on.svg", 300, su, merkez=(320, 64)),
        parca(g + "sunger.svg", 92, (104, -92), 0.3),
        parca(g + "kabarcik.svg", 40, (-112, -60)),
        parca(g + "kabarcik.svg", 26, (-90, -108)),
        parca(g + "kabarcik.svg", 30, (120, -10)),
    ]


def siradaki_ne():
    # Sıradaki Ne?: üstte kırmızı-mavi boncuk dizisi ve sonda soru işaretli boş yuva, altta gülen renkli tırtıl
    g = "siradaki_ne/gorseller/"
    dizi = []
    # (sağ üst köşe ilerleme rozetine kalır: dizi biraz aşağıda)
    for k, renk in enumerate(("kirmizi", "mavi", "kirmizi", "mavi")):
        x = -126 + k * 54
        dizi.append(parca(g + "parcalar/boncuk_yuvarlak_%s.svg" % renk, 58, (x, -70 + 5 * math.sin(k * 0.9 + 0.4))))
    return dizi + [
        parca(g + "yuva.svg", 64, (92, -70)),
        parca(g + "kart_tirtil.svg", 236, (0, 62)),
    ]


def yapboz():
    # Yapboz: arkada hafif eğik çiftlik resmi, önde gülen yapboz parçası (sağ üst köşe ilerleme rozetine kalır)
    g = "yapboz/gorseller/"
    return [
        parca(g + "resimler/ciftlik.svg", 224, (-32, -26), -0.07),
        parca(g + "kart_yapboz.svg", 210, (40, 66)),
    ]


def boyama_kitabi():
    # Boyama Kitabı: yarısı boyanmış kedi sayfası ve boya kalemleri, yanında boya kovası
    g = "boyama_kitabi/gorseller/"
    return [
        parca(g + "kart.svg", 300, (6, -4)),
        parca(g + "kova.svg", 92, (-104, 92), -0.15),
        parca(g + "kova_renk.svg", 92, (-104, 92), -0.15, renkler={"#FFFFFF": "#4AA3FF"}),
    ]


def balik_tutma():
    # Balık Tutma: dalgalı su üstünde kayıkta oltalı penguen; oltanın ucundaki ağda palyaço balığı, suda sıçrayan balık
    g = "balik_tutma/gorseller/"
    # Su: dalgalı üst kenar + alt yarım elips (çokgen; Godot'nun SVG çizicisi yatay teğetli eğride degradeyi kaybedebiliyor)
    ust = [(x, 60 + 5 * math.sin(x / 14.0)) for x in range(-150, 151, 6)]
    alt = [(150 * math.cos(math.radians(a)), 60 + 84 * math.sin(math.radians(a))) for a in range(0, 181, 6)]
    dalga = " ".join("%.1f,%.1f" % p for p in ust)
    su = ('<defs><linearGradient id="bt_su" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8FE3F0"/>'
          '<stop offset="1" stop-color="#3A9FD8"/></linearGradient></defs>\n'
          '<polygon points="%s" fill="url(#bt_su)" stroke="#2E6FA8" stroke-width="4" stroke-linejoin="round"/>\n'
          '<polyline points="%s" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.85"/>\n'
          % (" ".join("%.1f,%.1f" % p for p in ust + alt), dalga))
    kabarcik = "".join('<circle cx="%d" cy="%d" r="%d" fill="#FFFFFF" fill-opacity="0.35" stroke="#FFFFFF" stroke-width="2"/>' % c
                       for c in ((-100, 104, 7), (-84, 124, 5), (40, 118, 6)))
    return [
        su,
        parca(g + "baliklar/kirmizi_top.svg", 74, (74, 104), -0.35),
        kabarcik + "\n",
        parca(g + "olta.svg", 150, (-11, -3), -0.5, merkez=(10, 18)),
        parca(g + "penguen_olta.svg", 150, (-68, -30)),
        parca(g + "kayik_on.svg", 230, (-52, 44)),
        parca(g + "ag.svg", 72, (121, -14)),
        parca(g + "baliklar/palyaco.svg", 56, (121, 2), 0.2),
    ]


def kule_yapma():
    # Kule Yapma: zemin kat + iki kat + çatı (pencerelerde hayvanlar), yanda halatta sallanan kat
    g = "kule_yapma/gorseller/"

    def kat(ad, ic, y, hayvan, pencereler, boy):
        parcalar = [parca(g + "katlar/%s.svg" % ic, genislik[ad], (0, y))]
        for px, py in pencereler:
            parcalar.append(parca(g + "hayvanlar/%s.svg" % hayvan, boy, (px, y + py + (128 - 104) * boy / 256 + 4)))
        parcalar.append(parca(g + "katlar/kat_%s.svg" % ad, genislik[ad], (0, y)))
        return parcalar

    genislik = {"zemin": 260, "pembe": 240, "balkon": 240, "cati": 270}
    kule = []
    kule += kat("zemin", "ic_zemin", -75, "tavsan", [(-76, -15), (76, -15)], 80)
    kule += kat("balkon", "ic_kare", -210, "panda", [(-56, -4), (56, -4)], 82)
    kule += kat("pembe", "ic_kare", -330, "penguen", [(-56, -4), (56, -4)], 82)
    kule += kat("cati", "ic_cati", -465, "aslan", [(0, 21)], 66)
    asili = [parca(g + "katlar/ic_kare.svg", 240, (0, 0)),
             parca(g + "hayvanlar/zurafa.svg", 82, (-56, 4)), parca(g + "hayvanlar/zurafa.svg", 82, (56, 4)),
             parca(g + "katlar/kat_tente.svg", 240, (0, 0))]
    # Halatlar kancadan (kartın üst kenarının dışından) katın üst köşelerine
    halat = ('<g stroke="#3A2E52" stroke-width="8" stroke-linecap="round"><line x1="0" y1="-320" x2="-86" y2="-58"/>'
             '<line x1="0" y1="-320" x2="86" y2="-58"/></g>\n'
             '<g stroke="#B8B0CC" stroke-width="3.4" stroke-linecap="round"><line x1="0" y1="-320" x2="-86" y2="-58"/>'
             '<line x1="0" y1="-320" x2="86" y2="-58"/></g>\n')
    return [
        grup(kule, (-58, 148), 0.52),
        grup([halat] + asili, (86, -22), 0.46, 0.2),
    ]


def _tonlar(eski, yeni):
    """Büyükten Küçüğe şablon tonlarını (açık, çok açık, kendisi, koyu, çok koyu) bir renkten ötekine çevirir"""
    def karistir(a, b, t):
        a, b = [int(a[k:k + 2], 16) for k in (1, 3, 5)], [int(b[k:k + 2], 16) for k in (1, 3, 5)]
        return "#%02X%02X%02X" % tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))
    def tonlar(c):
        return [karistir(c, "#FFFFFF", 0.6), karistir(c, "#FFFFFF", 0.3), c, karistir(c, "#3B2F6B", 0.25), karistir(c, "#3B2F6B", 0.55)]
    return dict(zip(tonlar(eski), tonlar(yeni)))


def buyukten_kucuge():
    # Büyükten Küçüğe: yıldızlı halka kulesi ve yan yana büyükten küçüğe üç iç içe bebek
    g = "buyukten_kucuge/gorseller/"
    k = g + "kaynak/"
    kule = [
        parca(k + "direk.svg", 126, (-92, 38)),
        parca(k + "halka.svg", 116, (-92, 89), renkler=_tonlar("#FF5A6E", "#5CC95C")),
        parca(k + "halka.svg", 94, (-92, 61), renkler=_tonlar("#FF5A6E", "#4FA8FF")),
        parca(k + "halka.svg", 74, (-92, 38), renkler=_tonlar("#FF5A6E", "#FFB13D")),
        parca(g + "yildiz.svg", 54, (-92, -70), 0.2),
    ]
    bebekler = []
    for x, w in ((6, 104), (82, 78), (128, 56)):
        h = w * 298 / 200
        for yari in ("alt", "ust"):
            bebekler.append(parca(k + "bebek_tavsan_%s.svg" % yari, w, (x, 132 - h / 2)))
    return kule + bebekler


KARTLAR = {
    "kule_yapma": kule_yapma,
    "balik_tutma": balik_tutma,
    "ucan_kus": ucan_kus, "dondurmaci": dondurmaci, "yol_yap": yol_yap, "hafiza": hafiza,
    "meyve_topla": meyve_topla, "golge_eslestirme": golge_eslestirme, "kostebek": kostebek,
    "toplama": toplama, "cikarma": cikarma, "araba_yarisi": araba_yarisi, "zipla_zipla": zipla_zipla,
    "sihirli_bahce": sihirli_bahce, "muzik_kutusu": muzik_kutusu, "robot_fabrikasi": robot_fabrikasi,
    "tren_rayi": tren_rayi, "hayvan_besle": hayvan_besle, "boyama_kitabi": boyama_kitabi,
    "buyukten_kucuge": buyukten_kucuge, "hayvan_banyosu": hayvan_banyosu, "siradaki_ne": siradaki_ne,
    "yapboz": yapboz,
}


# --- Sekme simgeleri (120x120): kalın koyu çerçeve, parlak oyuncak renkleri ---

MUREKKEP = "#3B2F6B"


def _parlak(renk_ust, renk_alt, kimlik):
    return ('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
            % (kimlik, renk_ust, renk_alt))


def _simge(defs, govde):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">\n'
            '<defs>%s</defs>\n%s</svg>\n' % (defs, govde))


def sekme_hepsi():
    # 2x2 renkli kareler: "hepsi"
    renkler = [("#FF9CB8", "#F2557E"), ("#9ED0FF", "#3E8EEB"), ("#FFE27A", "#F5B400"), ("#9BEAB5", "#35B96A")]
    defs = "".join(_parlak(u, a, "k%d" % i) for i, (u, a) in enumerate(renkler))
    govde = ""
    for i in range(4):
        x = 14 + (i % 2) * 48
        y = 14 + (i // 2) * 48
        govde += ('<rect x="%d" y="%d" width="44" height="44" rx="13" fill="url(#k%d)" stroke="%s" stroke-width="5"/>'
                  '<rect x="%d" y="%d" width="18" height="8" rx="4" fill="#FFFFFF" opacity="0.55"/>\n'
                  % (x, y, i, MUREKKEP, x + 8, y + 7))
    return _simge(defs, govde)


def sekme_hareket():
    # Koşan ayakkabı ve hız çizgileri
    defs = _parlak("#FFB37A", "#FF6A3D", "ayakkabi")
    govde = (
        # hız çizgileri
        '<g stroke="%s" stroke-width="6" stroke-linecap="round" opacity="0.55">'
        '<line x1="6" y1="50" x2="26" y2="50"/><line x1="2" y1="66" x2="22" y2="66"/><line x1="8" y1="82" x2="26" y2="82"/></g>\n'
        # taban
        '<path d="M30 84 L104 84 C112 84 116 90 114 96 C112 101 107 102 100 102 L36 102 C30 102 26 98 26 93 C26 88 27 84 30 84 Z" '
        'fill="#FFFFFF" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
        # gövde
        '<path d="M32 86 C30 70 32 52 38 36 C40 31 45 29 50 31 L62 36 C66 38 70 38 72 35 L76 30 C78 27 82 27 84 30 '
        'C92 44 102 56 110 66 C116 73 114 84 106 86 Z" fill="url(#ayakkabi)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
        # bağcıklar
        '<g stroke="%s" stroke-width="4.5" stroke-linecap="round"><line x1="58" y1="46" x2="74" y2="42"/>'
        '<line x1="62" y1="56" x2="80" y2="51"/><line x1="66" y1="66" x2="86" y2="60"/></g>\n'
        # parlaklık
        '<path d="M42 44 C44 40 47 38 50 39" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.7"/>\n'
    ) % (MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP)
    return _simge(defs, govde)


def sekme_bulmaca():
    # Yapboz parçası
    defs = _parlak("#8CC8FF", "#2F7FE0", "yapboz")
    yol = ("M24 36 L46 36 C44 30 44 22 52 18 C60 14 70 18 70 26 C70 30 69 33 67 36 L92 36 "
           "L92 58 C98 56 106 56 109 63 C112 71 106 80 98 80 C96 80 94 79 92 78 L92 102 "
           "L24 102 L24 79 C28 81 34 81 38 76 C42 70 40 61 33 59 C30 58 27 59 24 60 Z")
    govde = (
        '<path d="%s" fill="url(#yapboz)" stroke="%s" stroke-width="5.5" stroke-linejoin="round"/>\n'
        '<path d="M32 46 L44 46" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" opacity="0.6"/>\n'
        '<circle cx="56" cy="24" r="4" fill="#FFFFFF" opacity="0.6"/>\n'
    ) % (yol, MUREKKEP)
    return _simge(defs, govde)


def sekme_yaratici():
    # Fırça ve boya damlası
    defs = (_parlak("#E3A66A", "#B06A32", "sap") + _parlak("#FF9CC6", "#F0468A", "boya")
            + _parlak("#E6E9F2", "#A7AEC4", "metal"))
    govde = (
        # boya lekesi
        '<path d="M18 92 C14 82 24 74 34 78 C40 70 54 72 56 82 C64 84 64 96 56 100 C50 108 30 108 24 102 C16 102 14 96 18 92 Z" '
        'fill="url(#boya)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
        '<circle cx="70" cy="104" r="6" fill="url(#boya)" stroke="%s" stroke-width="4"/>\n'
        '<g transform="rotate(40 66 54)">'
        # sap
        '<rect x="58" y="4" width="18" height="58" rx="9" fill="url(#sap)" stroke="%s" stroke-width="5"/>'
        '<rect x="62" y="10" width="5" height="30" rx="2.5" fill="#FFFFFF" opacity="0.45"/>'
        # metal bilezik
        '<rect x="55" y="58" width="24" height="16" rx="4" fill="url(#metal)" stroke="%s" stroke-width="5"/>'
        # kıllar
        '<path d="M56 74 L78 74 C80 88 74 100 67 106 C60 100 54 88 56 74 Z" fill="url(#boya)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>'
        '</g>\n'
    ) % (MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP)
    return _simge(defs, govde)


def sekme_ogren():
    # Oyuncak harf/sayı küpü: önde "A", yanda "1"
    defs = _parlak("#9BEAB5", "#2FAE62", "on") + _parlak("#FFE27A", "#E9A800", "yan") + _parlak("#C9F5D8", "#8FE0AE", "ust")
    govde = (
        '<path d="M20 44 L44 26 L102 26 L78 44 Z" fill="url(#ust)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
        '<path d="M78 44 L102 26 L102 84 L78 102 Z" fill="url(#yan)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
        '<rect x="20" y="44" width="58" height="58" rx="6" fill="url(#on)" stroke="%s" stroke-width="5"/>\n'
        # A harfi
        '<path d="M34 92 L46 54 L52 54 L64 92 L56 92 L53.5 83 L44.5 83 L42 92 Z M46.5 76 L51.5 76 L49 67 Z" '
        'fill="#FFFFFF" stroke="%s" stroke-width="3" stroke-linejoin="round" fill-rule="evenodd"/>\n'
        # 1 rakamı (yan yüzde, eğik)
        '<path d="M86 50 L94 44 L94 80 L88 84.5 L88 55 L85 57.5 Z" fill="#FFFFFF" stroke="%s" stroke-width="2.5" stroke-linejoin="round"/>\n'
        '<rect x="26" y="50" width="16" height="6" rx="3" fill="#FFFFFF" opacity="0.5"/>\n'
    ) % (MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP)
    return _simge(defs, govde)


# --- Ses düğmesi simgeleri (120x120) ---

def _hoparlor(ust, alt):
    defs = _parlak(ust, alt, "hop")
    govde = ('<path d="M12 46 C12 43 14 41 17 41 L32 41 L54 22 C57 19.5 62 21 62 25 L62 95 C62 99 57 100.5 54 98 '
             'L32 79 L17 79 C14 79 12 77 12 74 Z" fill="url(#hop)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>\n'
             '<path d="M20 48 L30 48" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" opacity="0.55"/>\n'
             % MUREKKEP)
    return defs, govde


def _dalgalar():
    return ('<g fill="none" stroke="%s" stroke-width="7" stroke-linecap="round">'
            '<path d="M74 46 C80 53 80 67 74 74"/><path d="M86 36 C98 50 98 70 86 84"/></g>\n' % MUREKKEP)


def ses_hepsi():
    # Hoparlör, ses dalgaları ve küçük bir nota: müzik de efektler de açık
    defs, govde = _hoparlor("#B9A8FF", "#7B6CF6")
    defs += _parlak("#FFB3CF", "#FF6F9C", "nota")
    govde += ('<g fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"><path d="M74 48 C80 55 80 65 74 72"/></g>\n'
              '<path d="M108 22 L108 70" stroke="%s" stroke-width="5.5" stroke-linecap="round"/>\n'
              '<path d="M108 22 C110 32 118 34 117 46" fill="none" stroke="%s" stroke-width="5.5" stroke-linecap="round"/>\n'
              '<ellipse cx="99" cy="72" rx="11" ry="8.5" transform="rotate(-22 99 72)" fill="url(#nota)" stroke="%s" stroke-width="5"/>\n'
              '<ellipse cx="96" cy="69" rx="4" ry="2.5" transform="rotate(-22 96 69)" fill="#FFFFFF" opacity="0.6"/>\n'
              % (MUREKKEP, MUREKKEP, MUREKKEP, MUREKKEP))
    return _simge(defs, govde)


def ses_efekt():
    # Hoparlör ve ses dalgaları (müzik kapalı, efektler açık)
    defs, govde = _hoparlor("#9ED0FF", "#3E8EEB")
    return _simge(defs, govde + _dalgalar())


def ses_kapali():
    # Soluk hoparlör ve yumuşak çarpı
    defs, govde = _hoparlor("#E4E1EE", "#AFA8C6")
    govde += ('<g stroke="%s" stroke-width="7" stroke-linecap="round">'
              '<line x1="78" y1="46" x2="104" y2="72"/><line x1="104" y1="46" x2="78" y2="72"/></g>\n' % MUREKKEP)
    return _simge(defs, govde)


SES_SIMGELERI = {"hepsi": ses_hepsi, "efekt": ses_efekt, "kapali": ses_kapali}


def bilgi():
    # Bilgi düğmesinin "i" simgesi (ebeveyn kapısı: Lisanslar ekranı)
    defs = _parlak("#9B8CFF", "#6A5AE8", "bilgi")
    govde = ('<circle cx="60" cy="26" r="15" fill="url(#bilgi)" stroke="%s" stroke-width="6"/>\n'
             '<rect x="45" y="50" width="30" height="62" rx="15" fill="url(#bilgi)" stroke="%s" stroke-width="6"/>\n'
             % (MUREKKEP, MUREKKEP))
    return _simge(defs, govde)


SEKMELER = {"hepsi": sekme_hepsi, "hareket": sekme_hareket, "bulmaca": sekme_bulmaca,
            "yaratici": sekme_yaratici, "ogren": sekme_ogren}


if __name__ == "__main__":
    os.makedirs(KART_KLASORU, exist_ok=True)
    for ad, fonksiyon in KARTLAR.items():
        _sayac[0] = 0
        _yaz(os.path.join(KART_KLASORU, ad + ".svg"), kart_svg(fonksiyon()))
    for ad, fonksiyon in SEKMELER.items():
        _yaz(os.path.join(GORSEL_KLASORU, "sekme_%s.svg" % ad), fonksiyon())
    for ad, fonksiyon in SES_SIMGELERI.items():
        _yaz(os.path.join(GORSEL_KLASORU, "ses_%s.svg" % ad), fonksiyon())
    _yaz(os.path.join(GORSEL_KLASORU, "bilgi.svg"), bilgi())
    print("%d kart, %d sekme, %d ses simgesi yazıldı" % (len(KARTLAR), len(SEKMELER), len(SES_SIMGELERI)))
