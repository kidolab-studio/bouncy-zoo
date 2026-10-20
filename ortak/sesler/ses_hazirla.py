# Ortak seslerin hazırlanması: CC0 paketleri indirir, seçilen sesleri kırpar / yumuşatır / seviyelerini eşitler
# ve bu klasöre .ogg olarak yazar. Hangi sesin nereden geldiği SESLER.md'de (bu listeyle aynı).
#
# Gerekenler: Python 3 + soundfile, numpy, scipy (pip install soundfile numpy scipy). İndirilen paketler proje
# dışında bir önbellek klasörüne açılır (varsayılan: sistem geçici klasörü / minik_sesler_kaynak).
# Çalıştırma (proje kökünden): python ortak/sesler/ses_hazirla.py [önbellek_klasörü] [ses adları...]
# (ad verilirse sadece o sesler yeniden üretilir). "sentez" paketindeki sesler indirilmez, bu dosyada üretilir;
# "kurgu" paketindekiler indirilen kayıtlardan bu dosyadaki bir fonksiyonla kurulur (ör. tren sesleri).
#
# Seviye hedefleri (kısa pencere RMS, dBFS): arayüz -26, efekt -21, ezgi -19, döngü -30, müzik (ortalama) -22;
# tepe -1 dBFS'i geçmez. Efektler mono, müzikler stereo. Oyun içindeki ince ayar SesYoneticisi'nde.

import os
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

import numpy as np
import soundfile as sf
from scipy import signal

BURASI = os.path.dirname(os.path.abspath(__file__))
SR = 44100

KENNEY = "https://kenney.nl/media/pages/assets/"
OGA = "https://opengameart.org/sites/default/files/"
PAKETLER = {
    # ad: (indirme bağlantısı, sayfa)
    "interface": (KENNEY + "interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip", "https://kenney.nl/assets/interface-sounds"),
    "impact": (KENNEY + "impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip", "https://kenney.nl/assets/impact-sounds"),
    "jingles": (KENNEY + "music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip", "https://kenney.nl/assets/music-jingles"),
    "digital": (KENNEY + "digital-audio/216eac4753-1677590265/kenney_digital-audio.zip", "https://kenney.nl/assets/digital-audio"),
    "casino": (KENNEY + "casino-audio/", "https://kenney.nl/assets/casino-audio"),
    "rpg": (KENNEY + "rpg-audio/", "https://kenney.nl/assets/rpg-audio"),
    "boing": (OGA + "boing.flac", "https://opengameart.org/content/boing"),
    "zil": (OGA + "pleasing-bell.wav", "https://opengameart.org/content/pleasing-bell-sound-effect"),
    "yaratik": (OGA + "80-CC0-creature-SFX_0.zip", "https://opengameart.org/content/80-cc0-creature-sfx"),
    "donguler": (OGA + "sfx_loops.zip", "https://opengameart.org/content/30-cc0-sfx-loops"),
    "buhar_duduk": (OGA + "steam_whistle.wav", "https://opengameart.org/content/steam-whistle"),
    "buhar": (OGA + "steam_hisses.zip", "https://opengameart.org/content/steam-release-sounds"),
    "m_ev": (OGA + "children_soundtrack_3.wav", "https://opengameart.org/content/childrens-game-music-3-home"),
    "m_kus": (OGA + "flowerbed_fields.ogg", "https://opengameart.org/content/flowerbed-fields-loop"),
    "m_dondurma": (OGA + "feel_good_island_loop_0.ogg", "https://opengameart.org/content/feel-good-island-loop"),
    "m_yol": (OGA + "ogg_cozy_puzzle_jingle_result.zip", "https://opengameart.org/content/cozy-puzzle-jingle-result"),
    "m_hafiza": (OGA + "Heavenly%20Loop_0.ogg", "https://opengameart.org/content/heavenly-loop"),
    "m_meyve": (OGA + "childrens_march_theme.zip", "https://opengameart.org/content/childrens-march-theme"),
}
# Kenney casino ve rpg paketlerinin tam bağlantısı sayfadan okunur (sürüm kodu değişebilir)

MENU_CUMLE = 12 * 60 / 70     # menü müziğinde bir cümle: 12 vuruş, 70 BPM (parça 0. sn'de başlar)

# ad: (paket, paketteki dosya, tür, işlemler)
#   tür: arayuz / efekt / ezgi / dongu / muzik
#   işlemler: bas/son (sn, kırpma), perde (hız çarpanı: 1.25 = daha tiz ve kısa), alcak (Hz, tiz yumuşatma),
#             ekle (başka bir ses: (paket, dosya, gecikme sn, kazanç)), sonu_sustur (sn, yumuşak kısılma),
#             dikis (sn: döngünün iki ucuna çok kısa kısılma; dikişte "tık" duyulan döngüler için),
#             dongu ((dönüş sn, son sn, geçiş sn): dosya "son"da biter, çalınca "dönüş"e döner (.import loop_offset'i
#             buradan yazılır); sondaki "geçiş" kadar bölüm dönüşten önceki bölümle karıştırılır, ek duyulmaz),
#             seviye (dB: türün hedef seviyesi yerine)
SESLER = {
    # --- Ortak ---
    "dugme_tik": ("interface", "drop_003.ogg", "arayuz", {}),
    "geri": ("interface", "drop_003.ogg", "arayuz", {"perde": 0.75}),
    "kutlama": ("jingles", "jingles_STEEL02.ogg", "ezgi", {}),
    "konfeti": ("interface", "drop_004.ogg", "efekt", {"ekle": ("interface", "glass_002.ogg", 0.09, 0.7), "alcak": 6000}),
    "yumusak_hayir": ("interface", "question_002.ogg", "arayuz", {"alcak": 2500}),
    "ding": ("interface", "glass_005.ogg", "efekt", {}),
    "ding_yumusak": ("interface", "glass_001.ogg", "efekt", {}),
    "pop": ("interface", "drop_004.ogg", "efekt", {}),
    "plop": ("interface", "drop_002.ogg", "efekt", {}),
    "tink": ("interface", "glass_006.ogg", "arayuz", {}),
    "basari": ("interface", "confirmation_001.ogg", "efekt", {}),
    "basari_parlak": ("interface", "confirmation_003.ogg", "efekt", {}),
    "tamamlandi": ("interface", "confirmation_004.ogg", "efekt", {}),
    "yukselis": ("interface", "maximize_009.ogg", "efekt", {}),
    "yildiz_kazanma": ("jingles", "jingles_PIZZI02.ogg", "ezgi", {}),
    "hediye_acilis": ("jingles", "jingles_PIZZI10.ogg", "ezgi", {}),
    "bolum_gecisi": ("jingles", "jingles_STEEL10.ogg", "ezgi", {}),
    # --- Uçan Kuş ---
    "kanat": ("rpg", "cloth2.ogg", "arayuz", {"son": 0.28, "alcak": 3500, "sonu_sustur": 0.12}),
    "boing": ("boing", "boing.flac", "efekt", {"son": 0.75, "sonu_sustur": 0.35}),
    "boing_kisa": ("boing", "boing.flac", "efekt", {"perde": 1.3, "son": 0.42, "sonu_sustur": 0.2}),
    "yumusak_dusus": ("digital", "highDown.ogg", "efekt", {"alcak": 2200}),
    # --- Dondurmacı ---
    "kapi_zili": ("zil", "pleasing-bell.wav", "efekt", {}),
    "tahta_tok": ("impact", "impactWood_light_001.ogg", "arayuz", {}),
    "hayvan_sevinc": ("yaratik", "cute_03.ogg", "efekt", {"alcak": 7000}),
    # --- Yol Yap ---
    "hisirti": ("rpg", "cloth1.ogg", "arayuz", {"son": 0.45, "alcak": 2500, "sonu_sustur": 0.2}),
    "bilye_yuvarlanma": ("donguler", "rolling.ogg", "dongu", {"alcak": 1800}),
    # --- Hafıza ---
    "kart_cevir": ("casino", "card-place-1.ogg", "arayuz", {"alcak": 7000}),
    "kart_dagit": ("casino", "card-slide-1.ogg", "arayuz", {"alcak": 7000}),
    # --- Meyve Topla ---
    "bonk": ("interface", "bong_001.ogg", "efekt", {}),
    "sersem": ("yaratik", "ooh.ogg", "efekt", {"alcak": 5000}),
    "guc_al": ("digital", "powerUp2.ogg", "efekt", {"alcak": 3000}),
    "guc_bitti": ("digital", "phaserDown1.ogg", "efekt", {"alcak": 2500}),
    "vuus": ("sentez", "vuus", "efekt", {"alcak": 2800}),
    # --- Tren Rayı (gerçek buhar kayıtlarından kuruldu; kaynak paketler: buhar_duduk, buhar) ---
    "tren_duduk": ("kurgu", "tren_duduk", "efekt", {"alcak": 5000}),
    "tren_cufcuf": ("kurgu", "tren_cufcuf", "dongu", {}),
    "tren_fren": ("kurgu", "tren_fren", "efekt", {"alcak": 3000, "sonu_sustur": 0.35}),
    # --- Müzikler (döngülü) ---
    # Menü: 8 cümle ve kapanış; kapanış atılır, döngü 2. cümleye döner (giriş sadece ilk çalışta tam duyulur)
    "muzik_menu": ("m_ev", "children_soundtrack_3.wav", "muzik",
                   {"dongu": (MENU_CUMLE, 8 * MENU_CUMLE, 0.08), "seviye": -24.0}),
    "muzik_ucan_kus": ("m_kus", "flowerbed_fields.ogg", "muzik", {"alcak": 5000}),
    "muzik_dondurmaci": ("m_dondurma", "feel_good_island_loop_0.ogg", "muzik", {}),
    "muzik_yol_yap": ("m_yol", "Cozy Puzzle Clear (Loop)_BPM85.ogg", "muzik", {"alcak": 7000}),
    "muzik_hafiza": ("m_hafiza", "Heavenly Loop_0.ogg", "muzik", {}),
    "muzik_meyve_topla": ("m_meyve", "Children's March Theme.ogg", "muzik", {"alcak": 7000}),
}

HEDEF = {"arayuz": -26.0, "efekt": -21.0, "ezgi": -19.0, "dongu": -30.0, "muzik": -22.0}
SIKISTIRMA = {"arayuz": 0.3, "efekt": 0.3, "ezgi": 0.3, "dongu": 0.4, "muzik": 0.55}   # libsndfile vorbis (0 en iyi)
DONGULU = ("dongu", "muzik")


def _indir(url, hedef):
    """Yarıda kesilen indirme yarım dosya bırakmasın: geçici ada yazılır, tamamlanınca asıl ada taşınır.
    Bağlantı koparsa birkaç kez yeniden denenir."""
    if os.path.exists(hedef):
        return
    gecici = hedef + ".indiriliyor"
    for deneme in range(4):
        try:
            print("indiriliyor", url)
            istek = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(istek, timeout=120) as y, open(gecici, "wb") as f:
                while True:
                    parca = y.read(1 << 16)
                    if not parca:
                        break
                    f.write(parca)
                beklenen = y.headers.get("Content-Length")
            if beklenen and int(beklenen) != os.path.getsize(gecici):
                raise IOError("eksik indi: %s / %s bayt" % (os.path.getsize(gecici), beklenen))
            os.replace(gecici, hedef)
            return
        except Exception as hata:  # noqa: BLE001
            print("  indirme hatası (%d. deneme): %s" % (deneme + 1, hata))
    raise IOError("indirilemedi: " + url)


def _kenney_bag(sayfa):
    import re
    istek = urllib.request.Request(sayfa, headers={"User-Agent": "Mozilla/5.0"})
    html = urllib.request.urlopen(istek, timeout=60).read().decode("utf-8", "ignore")
    return re.search(r'https://kenney.nl/media/pages/assets/[^"]+\.zip', html).group(0)


def paket_klasoru(onbellek, ad):
    url, sayfa = PAKETLER[ad]
    klasor = os.path.join(onbellek, ad)
    if os.path.isdir(klasor) and os.listdir(klasor):
        return klasor
    if url.endswith("/"):
        url = _kenney_bag(sayfa)
    dosya = os.path.join(onbellek, ad + "_" + os.path.basename(url).replace("%20", "_"))
    _indir(url, dosya)
    os.makedirs(klasor, exist_ok=True)       # klasör ancak indirme tamamlanınca oluşur
    if dosya.endswith(".zip"):
        with zipfile.ZipFile(dosya) as z:
            z.extractall(klasor)
    else:
        os.replace(dosya, os.path.join(klasor, urllib.parse.unquote(os.path.basename(url))))
    return klasor


def bul(onbellek, paket, ad):
    klasor = paket_klasoru(onbellek, paket)
    for kok, _, dosyalar in os.walk(klasor):
        if ad in dosyalar:
            return os.path.join(kok, ad)
    raise FileNotFoundError(f"{paket}: {ad}")


def oku(yol, stereo):
    veri, sr = sf.read(yol, always_2d=True, dtype="float64")
    if sr != SR:
        veri = signal.resample_poly(veri, SR, sr, axis=0)
    if not stereo:
        veri = veri.mean(axis=1, keepdims=True)
    elif veri.shape[1] == 1:
        veri = np.repeat(veri, 2, axis=1)
    return veri


def alcak_geciren(veri, hz, dongu):
    sos = signal.butter(2, hz, "low", fs=SR, output="sos")
    if dongu:
        # Döngü dikişi bozulmasın: sarmal dolgu ile süz, sonra kırp
        pay = SR
        dolu = np.concatenate([veri[-pay:], veri, veri[:pay]])
        return signal.sosfiltfilt(sos, dolu, axis=0)[pay:-pay]
    return signal.sosfiltfilt(sos, veri, axis=0)


def pencere_rms_max(veri, pencere=0.3):
    x = veri.mean(axis=1)
    n = max(1, int(SR * pencere))
    en = 0.0
    for i in range(0, max(1, len(x) - n + 1), n // 4):
        en = max(en, float(np.sqrt(np.mean(x[i:i + n] ** 2))))
    return en


def vuus(_onbellek=None):
    """Rüzgar "vuuş"u: merkez frekansı yükselip alçalan bant geçiren gürültü, yumuşak çan biçimli zarf"""
    n = int(0.55 * SR)
    t = np.linspace(0.0, 1.0, n)
    gurultu = np.random.default_rng(7).standard_normal(n)
    merkez = 320.0 + 1100.0 * np.sin(np.pi * t ** 0.8) ** 2
    f = 2.0 * np.sin(np.pi * merkez / SR)
    alt = bant = 0.0
    cikis = np.zeros(n)
    for i in range(n):          # durum değişkenli süzgeç (Q ≈ 2.5)
        alt += f[i] * bant
        bant += f[i] * (gurultu[i] - alt - 0.4 * bant)
        cikis[i] = bant
    zarf = t ** 1.2 * (1.0 - t) ** 2.0
    return (cikis * zarf / zarf.max())[:, None]


def _kenar(n, acilis, kapanis):
    """Yumuşak açılıp kapanan zarf (yarım kosinüs kenarlar; süreler sn)"""
    zarf = np.ones(n)
    a, k = min(n, int(acilis * SR)), min(n, int(kapanis * SR))
    zarf[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    zarf[n - k:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
    return zarf


def tren_duduk(onbellek):
    """Oyuncak tren düdüğü "tü-tüüt": gerçek buhar düdüğü kaydının kararlı bölümünden iki ses birlikte
    (Sol5 + Si5, büyük üçlü: neşeli), önce kısa sonra uzun üfleme"""
    ham = oku(bul(onbellek, "buhar_duduk", "steam_whistle.wav"), False)[:, 0]
    duz = ham[int(1.2 * SR):int(2.05 * SR)]           # düdüğün tam açıldığı, sabit bölüm (temel ses 742 Hz)
    sol = signal.resample(duz, int(len(duz) * 742.0 / 784.0))
    si = signal.resample(duz, int(len(duz) * 742.0 / 988.0))
    cikis = np.zeros(int(0.70 * SR))
    for bas, sure, kaynak_bas in ((0.0, 0.15, 0.0), (0.22, 0.46, 0.1)):
        n = int(sure * SR)
        k = int(kaynak_bas * SR)
        ufleme = (sol[k:k + n] + 0.55 * si[k:k + n]) * _kenar(n, 0.022, 0.09)
        i = int(bas * SR)
        cikis[i:i + n] += ufleme
    return cikis[:, None]


def tren_cufcuf(onbellek):
    """Dört vuruşluk "çuf çuf" döngüsü: gerçek buhar kayıtlarından kısa, kalınlaştırılmış puflar; ilk vuruş
    vurgulu. Puf kuyrukları döngünün başına sarıldığı için dikiş duyulmaz. Oyunda hız perdeyle değişir."""
    adim = 0.30
    n = int(4 * adim * SR)
    dongu = np.zeros(n)
    sos = signal.butter(4, [140, 1150], "band", fs=SR, output="sos")
    for i, (kayit, guc) in enumerate((("1", 1.0), ("3", 0.6), ("2", 0.8), ("4", 0.6))):
        ham = oku(bul(onbellek, "buhar", "steam hisses - Marker #%s.wav" % kayit), False)[:, 0]
        parca = ham[:int(0.3 * SR)]
        puf = signal.sosfilt(sos, signal.resample(parca, int(len(parca) / 0.55)))    # 0.55 hız: daha kalın
        t = np.arange(len(puf)) / SR
        puf *= np.minimum(t / 0.014, 1.0) * np.exp(-t / 0.075)
        puf *= guc / np.sqrt(np.mean(puf[:int(0.15 * SR)] ** 2))
        np.add.at(dongu, (int(i * adim * SR) + np.arange(len(puf))) % n, puf)
    return dongu[:, None]


def tren_fren(onbellek):
    """Duruş: yumuşak "pşşş". Gerçek buhar boşaltma kaydı, biraz yavaşlatılmış ve yumuşak başlangıçlı"""
    ham = oku(bul(onbellek, "buhar", "steam hisses - Marker #3.wav"), False)[:, 0]
    parca = ham[:int(0.95 * SR)]
    ses = signal.resample(parca, int(len(parca) / 0.8))
    ses = signal.sosfilt(signal.butter(2, 350, "high", fs=SR, output="sos"), ses)
    return (ses * _kenar(len(ses), 0.04, 0.3))[:, None]


SENTEZ = {"vuus": vuus, "tren_duduk": tren_duduk, "tren_cufcuf": tren_cufcuf, "tren_fren": tren_fren}


def _donus_yaz(ad, saniye):
    """Döngünün dönüş noktasını Godot'nun içe aktarma ayarına (loop_offset) yazar"""
    import re
    yol = os.path.join(BURASI, ad + ".ogg.import")
    if not os.path.exists(yol):
        print(f"  {ad}.ogg.import yok: Godot'ta içe aktarınca loop_offset={saniye:.6f} yap")
        return
    with open(yol, encoding="utf-8") as f:
        metin = f.read()
    with open(yol, "w", encoding="utf-8", newline="\n") as f:
        f.write(re.sub(r"(?m)^loop_offset=.*$", f"loop_offset={saniye:.6f}", metin))


def hazirla(onbellek, ad, paket, dosya, tur, isl):
    dongu = tur in DONGULU
    if paket in ("sentez", "kurgu"):
        veri = SENTEZ[dosya](onbellek)
    else:
        veri = oku(bul(onbellek, paket, dosya), tur == "muzik")
    if "perde" in isl:
        # Hız çarpanı: yeniden örnekleyerek perde ve süre birlikte değişir
        oran = isl["perde"]
        veri = signal.resample(veri, int(len(veri) / oran), axis=0)
    if "ekle" in isl:
        p2, d2, gecikme, kazanc = isl["ekle"]
        ek = oku(bul(onbellek, p2, d2), False) * kazanc
        bas = int(gecikme * SR)
        uzunluk = max(len(veri), bas + len(ek))
        veri = np.pad(veri, ((0, uzunluk - len(veri)), (0, 0)))
        veri[bas:bas + len(ek)] += ek
    if "dongu" in isl:
        donus, son, gecis = (int(round(t * SR)) for t in isl["dongu"])
        aci = np.linspace(0.0, np.pi / 2, gecis)[:, None]
        veri[son - gecis:son] = veri[son - gecis:son] * np.cos(aci) + veri[donus - gecis:donus] * np.sin(aci)
        veri = veri[:son]
        _donus_yaz(ad, donus / SR)
    bas = int(isl.get("bas", 0) * SR)
    son = int(isl["son"] * SR) if "son" in isl else len(veri)
    veri = veri[bas:son]
    if "alcak" in isl:
        veri = alcak_geciren(veri, isl["alcak"], dongu)
    if "dikis" in isl:
        n = int(isl["dikis"] * SR)
        veri[:n] *= np.linspace(0, 1, n)[:, None]
        veri[-n:] *= np.linspace(1, 0, n)[:, None]
    if not dongu:
        # Baştaki ve sondaki sessizliği at (ses dokunuşla hemen başlasın), kısa açılış ve kapanış
        esik = np.abs(veri).max() * 0.003
        aktif = np.where(np.abs(veri).max(axis=1) > esik)[0]
        if len(aktif):
            veri = veri[max(0, aktif[0] - int(0.002 * SR)): aktif[-1] + int(0.02 * SR)]
        acilis = min(len(veri), int(0.003 * SR))
        veri[:acilis] *= np.linspace(0, 1, acilis)[:, None]
        kapanis = min(len(veri), int(isl.get("sonu_sustur", 0.03) * SR))
        veri[-kapanis:] *= np.linspace(1, 0, kapanis)[:, None] ** 2
    # Seviye
    if tur == "muzik":
        olcu = float(np.sqrt(np.mean(veri ** 2)))
    else:
        olcu = pencere_rms_max(veri)
    kazanc = 10 ** (isl.get("seviye", HEDEF[tur]) / 20) / max(olcu, 1e-9)
    tepe = float(np.abs(veri).max()) * kazanc
    if tepe > 10 ** (-1 / 20):
        kazanc *= 10 ** (-1 / 20) / tepe
    veri = veri * kazanc
    cikti = os.path.join(BURASI, ad + ".ogg")
    # libsndfile Vorbis'e uzun tampon tek seferde yazılınca (Windows'ta) yığın taşıyor: parça parça yaz
    with sf.SoundFile(cikti, "w", SR, veri.shape[1], format="OGG", subtype="VORBIS", compression_level=SIKISTIRMA[tur]) as f:
        for i in range(0, len(veri), 4096):
            f.write(veri[i:i + 4096].astype(np.float32))
    return len(veri) / SR, 20 * np.log10(max(pencere_rms_max(veri), 1e-9)), os.path.getsize(cikti)


def main():
    adlar = [a for a in sys.argv[1:] if a in SESLER]
    diger = [a for a in sys.argv[1:] if a not in SESLER]
    onbellek = diger[0] if diger else os.path.join(tempfile.gettempdir(), "minik_sesler_kaynak")
    os.makedirs(onbellek, exist_ok=True)
    toplam = 0
    for ad, (paket, dosya, tur, isl) in SESLER.items():
        if adlar and ad not in adlar:
            continue
        sure, rms, boyut = hazirla(onbellek, ad, paket, dosya, tur, isl)
        toplam += boyut
        print(f"{ad:22s} {tur:7s} {sure:6.2f} sn  rms {rms:6.1f} dB  {boyut // 1024:5d} KB")
    print(f"toplam {toplam / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
