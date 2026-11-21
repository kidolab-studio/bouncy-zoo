# Yapboz sesleri: sadece Python standart kütüphanesiyle üretilir (dışarıdan ses yok).
# Çalıştırma: python ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde. Bütün sesler save_loudness() ile aynı algılanan yüksekliğe
# eşitlenir; yumuşak, kısa, korkutmayan. Olumsuz (hata) sesi yok: yanlış yerde sadece yumuşak "geri" sesi.
#
# - tut: parça tutulunca (yumuşak pop)
# - otur: parça yerine oturunca (tok "tık" + küçük çan)
# - geri: yanlış yerden tepsiye dönüş
# - dagil: bölüm başında parçalar tepsilere uçarken (hışırtılı "fırr")
# - bolum_sonu, final: kutlamalar
# - Resim bitince çalan sesler (ayarlar.gd PICTURES sound): inek (möö), deniz (fokurdayan kabarcıklar),
#   balon (ateşin "fışş"ı ve yükselen çanlar), kasaba (dostça "düt düt" ve bisiklet zili), tren (düdük ve
#   "çuf çuf"), meyve (kıtır ısırık ve çanlar), uzay (yükselen "fiuuu" ve parıltılar), orman (kuş cıvıltısı),
#   agac_ev (kayan düdükle "viii"), pasta (parti düdüğü ve ezgi), dinozor (sevimli "raar"), kutup (buzlu çanlar)

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "ortak", "ses"))
from sentez import (RATE, bandpass, bell, check_all, envelope, glide, lowpass, melody, mix, noise, note,  # noqa: E402
                    save_loudness, silence, smooth_env, soft_tone, sweep, voice)

TARGET = 0.1


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


def grab() -> list:
    out = sweep(360, 1150, 0.1, 0.003, 36.0, 0.6)
    mix(out, sweep(720, 2300, 0.06, 0.002, 60.0, 0.6), 0.0, 0.15)
    return out


def seat() -> list:
    # Ahşap parçanın yerine oturması: kısa tok vuruş, ardından tatlı bir çan
    out = sweep(520, 260, 0.08, 0.001, 45.0, 0.5)
    mix(out, envelope(bandpass(noise(0.03, 5), 900, 3500), 0.001, 150.0), 0.0, 0.4)
    mix(out, bell(note("E6"), 0.5, 8.0), 0.03, 0.3)
    mix(out, bell(note("B6"), 0.4, 9.0), 0.07, 0.15)
    return out


def back() -> list:
    out = sweep(520, 300, 0.24, 0.02, 7.0, 0.7)
    return lowpass(out, 1800)


def scatter() -> list:
    # Parçalar dağılırken: art arda yumuşak hışırtılar
    out = silence(0.7)
    for k in range(6):
        mix(out, envelope(bandpass(noise(0.12, 20 + k), 1500, 6000), 0.01, 30.0), k * 0.07, 0.5)
        mix(out, sweep(700 + k * 90, 1300 + k * 120, 0.08, 0.004, 40.0, 0.8), k * 0.07, 0.12)
    return lowpass(out, 7000)


def level_end() -> list:
    out = melody(["C5", "E5", "G5", "E5", "C6"], 0.12, 0.8)
    mix(out, bell(note("C7"), 0.6, 6.0), 0.5, 0.25)
    for name in ["C4", "E4", "G4"]:
        mix(out, soft_tone(note(name), 1.0), 0.48, 0.18)
    return out


def finale() -> list:
    lead = ["C5", "D5", "E5", "G5", "A5", "C6", "", "A5", "G5", "E5", "G5", "C6", "", "", "C6", ""]
    out = melody(lead, 0.15, 0.9)
    for start, chord in [(0.0, ["C4", "E4", "G4"]), (0.6, ["F4", "A4", "C5"]), (1.2, ["A3", "C4", "E4"]), (1.8, ["G3", "B3", "D4"]),
                         (2.1, ["C4", "E4", "G4", "C5"])]:
        for name in chord:
            mix(out, soft_tone(note(name), 1.2), start, 0.28)
    for k, name in enumerate(["C7", "E7", "G7", "C8"]):
        mix(out, bell(note(name), 0.5, 7.0), 2.2 + k * 0.07, 0.15)
    return out


def cow() -> list:
    # "Möö": derin, alçak perde; kapalı "m" ile başlayıp "öö"ye açılır (Müzik Kutusu'ndaki sentezle aynı yöntem)
    s = 1.3
    return lowpass(voice(
        s,
        lambda t: glide([(0, 105), (0.35, 128), (1.3, 92)], t),
        lambda t: smooth_env(t, s, 0.12, 0.35),
        lambda t: [(glide([(0, 260), (0.3, 420)], t), 90, 1.0), (glide([(0, 700), (0.3, 1250)], t), 120, 0.5), (2400, 200, 0.12)],
        breath=0.08, seed=3), 3000)


def sea() -> list:
    # Fokurdayan kabarcıklar: yukarı kıvrılan kısa "blup"lar
    out = silence(1.1)
    for k, (start, f0) in enumerate(((0.0, 380), (0.12, 520), (0.2, 440), (0.33, 610), (0.45, 500), (0.56, 700), (0.7, 560))):
        f = f0
        blup = []
        n = int(RATE * 0.09)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            f = f0 * (1 + 2.2 * t / 0.09)
            phase += 2 * math.pi * f / RATE
            blup.append(math.sin(phase) * math.sin(math.pi * t / 0.09))
        mix(out, blup, start, 0.6)
    mix(out, bell(note("G6"), 0.6, 6.0), 0.8, 0.15)
    return lowpass(out, 5000)


def balloon() -> list:
    # Ateşin yumuşak "fışş"ı, üstüne yükselen çanlar (balonlar havalanır)
    out = envelope(lowpass(noise(0.7, 9), 2200), 0.08, 3.5)
    for k, name in enumerate(["C6", "E6", "G6", "C7"]):
        mix(out, bell(note(name), 0.6, 6.0), 0.3 + k * 0.1, 0.3)
    return out


def town() -> list:
    # Dostça "düt düt" (yumuşak iki ton) ve bisiklet zili
    out = silence(1.2)
    for start in (0.0, 0.22):
        horn = []
        n = int(RATE * 0.16)
        for i in range(n):
            t = i / RATE
            v = 0.0
            # Kare dalgaya benzer ama yumuşak: yalnızca ilk birkaç tek harmonik (cızırtı olmasın)
            for f, a in ((440, 1.0), (554, 0.8)):
                for h in (1, 3, 5):
                    v += a / h * math.sin(2 * math.pi * f * h * t)
            horn.append(v * smooth_env(t, 0.16, 0.015, 0.05))
        mix(out, lowpass(horn, 1600), start, 0.35)
    for k in range(2):
        mix(out, bell(note("A6"), 0.5, 8.0), 0.55 + k * 0.12, 0.35)
        mix(out, bell(note("E7"), 0.4, 9.0), 0.55 + k * 0.12, 0.15)
    return out


def whistle_tone(seconds: float, freqs: tuple) -> list:
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        v = sum(math.sin(2 * math.pi * f * t * (1 + 0.004 * math.sin(2 * math.pi * 5 * t))) for f in freqs)
        out.append(v * smooth_env(t, seconds, 0.05, 0.12))
    return out


def train() -> list:
    # Tren düdüğü (iki ton, yumuşak) ve ardından "çuf çuf"
    out = silence(1.3)
    mix(out, whistle_tone(0.32, (660, 830)), 0.0, 0.3)
    mix(out, whistle_tone(0.45, (660, 830)), 0.38, 0.3)
    mix(out, envelope(lowpass(noise(0.8, 4), 2500), 0.02, 2.0), 0.0, 0.05)
    for k in range(4):
        mix(out, envelope(bandpass(noise(0.12, 30 + k), 300, 2000), 0.005, 25.0), 0.9 + k * 0.1, 0.35)
    return lowpass(out, 5000)


def fruit() -> list:
    # Kıtır ısırık (kısa gürültü patlamaları), sonra tatlı "mmm" çanları
    out = silence(1.1)
    for k in range(3):
        mix(out, envelope(bandpass(noise(0.06, 40 + k), 1500, 6000), 0.001, 70.0), k * 0.05, 0.5)
    mix(out, melody(["E5", "G5", "C6"], 0.11, 0.6), 0.3, 0.6)
    return out


def space_sound() -> list:
    # Yükselen "fiuuu" (titrek) ve parıldayan yıldızlar
    out = silence(1.3)
    n = int(RATE * 0.7)
    phase = 0.0
    zap = []
    for i in range(n):
        t = i / RATE
        f = 300 + 900 * (t / 0.7) ** 1.5
        f *= 1 + 0.03 * math.sin(2 * math.pi * 9 * t)
        phase += 2 * math.pi * f / RATE
        zap.append(math.sin(phase) * smooth_env(t, 0.7, 0.05, 0.2))
    mix(out, zap, 0.0, 0.5)
    for k, name in enumerate(["C7", "G6", "E7", "C8"]):
        mix(out, bell(note(name), 0.5, 7.0), 0.55 + k * 0.1, 0.25)
    return out


def chirp(f0: float, f1: float, seconds: float) -> list:
    out = []
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = f0 + (f1 - f0) * t / seconds
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase) * math.sin(math.pi * t / seconds))
    return out


def forest_sound() -> list:
    # Kuş cıvıltısı: hızlı, tiz kıvrılmalar
    out = silence(1.1)
    for k, (start, f0, f1) in enumerate(((0.0, 2600, 3600), (0.09, 2800, 3900), (0.18, 2600, 3600),
                                          (0.45, 3400, 2400), (0.6, 2400, 3800), (0.72, 2500, 3900))):
        mix(out, chirp(f0, f1, 0.07), start, 0.4)
    return lowpass(out, 7000)


def glide_tone(points: list, seconds: float) -> list:
    # Perdesi noktalar arasında kayan yumuşak ton (kayan düdük)
    out = []
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        phase += 2 * math.pi * glide(points, t) / RATE
        out.append((math.sin(phase) + 0.3 * math.sin(2 * phase)) * smooth_env(t, seconds, 0.03, 0.12))
    return out


def treehouse() -> list:
    # Kaydıraktan "viii": yükselip inen kayan düdük, sonra küçük çanlar
    out = silence(1.2)
    mix(out, glide_tone([(0, 520), (0.35, 1250), (0.7, 680)], 0.7), 0.0, 0.5)
    for k, name in enumerate(["G6", "C7", "E7"]):
        mix(out, bell(note(name), 0.5, 7.0), 0.72 + k * 0.08, 0.25)
    return lowpass(out, 6000)


def party() -> list:
    # Parti düdüğü (titrek, vızıltılı ama yumuşak) ve kısa neşeli ezgi
    out = silence(1.4)
    horn = []
    phase = 0.0
    s = 0.45
    for i in range(int(RATE * s)):
        t = i / RATE
        phase += 2 * math.pi * glide([(0, 420), (0.12, 560), (0.45, 540)], t) * (1 + 0.02 * math.sin(2 * math.pi * 12 * t)) / RATE
        horn.append(sum(math.sin(h * phase) / h for h in (1, 2, 3, 4)) * smooth_env(t, s, 0.02, 0.1))
    mix(out, lowpass(horn, 2500), 0.0, 0.4)
    mix(out, melody(["C6", "E6", "G6", "C7"], 0.1, 0.5), 0.5, 0.5)
    return out


def dinosaur() -> list:
    # Sevimli, korkutmayan "raar": alçak ama yumuşak ses teli, "a" ünlüsü, sonra kıkırdayan çanlar
    s = 0.6
    out = silence(1.1)
    roar = voice(
        s,
        lambda t: glide([(0, 150), (0.2, 210), (0.6, 130)], t),
        lambda t: smooth_env(t, s, 0.06, 0.25),
        lambda t: [(glide([(0, 500), (0.2, 750)], t), 110, 1.0), (1150, 140, 0.5), (2500, 220, 0.1)],
        breath=0.15, seed=9)
    mix(out, lowpass(roar, 2500), 0.0, 1.0)
    for k, name in enumerate(["E6", "G6"]):
        mix(out, bell(note(name), 0.4, 8.0), 0.7 + k * 0.1, 0.15)
    return out


def arctic_sound() -> list:
    # Buzlu çanlar (yukarıdan aşağı dökülür) ve yumuşak rüzgâr
    out = envelope(bandpass(noise(1.2, 12), 400, 1800), 0.3, 2.5)
    for k, name in enumerate(["C8", "G7", "E7", "C7", "G6"]):
        mix(out, bell(note(name), 0.6, 6.0), 0.1 + k * 0.09, 0.3)
    return out


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("tut.wav", grab())
    save("otur.wav", seat())
    save("geri.wav", back(), TARGET * 0.6)
    save("dagil.wav", scatter(), TARGET * 0.6)
    save("bolum_sonu.wav", level_end())
    save("final.wav", finale())
    save("inek.wav", cow(), TARGET * 0.9)
    save("deniz.wav", sea(), TARGET * 0.8)
    save("balon.wav", balloon(), TARGET * 0.8)
    save("kasaba.wav", town(), TARGET * 0.8)
    save("tren.wav", train(), TARGET * 0.8)
    save("meyve.wav", fruit(), TARGET * 0.8)
    save("uzay.wav", space_sound(), TARGET * 0.8)
    save("orman.wav", forest_sound(), TARGET * 0.6)
    save("agac_ev.wav", treehouse(), TARGET * 0.7)
    save("pasta.wav", party(), TARGET * 0.8)
    save("dinozor.wav", dinosaur(), TARGET * 0.8)
    save("kutup.wav", arctic_sound(), TARGET * 0.7)
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
