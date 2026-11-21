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
#   balon (ateşin "fışş"ı ve yükselen çanlar), kasaba (dostça "düt düt" ve bisiklet zili)

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
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
