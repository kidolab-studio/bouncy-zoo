# Sıradaki Ne? sesleri: sadece Python standart kütüphanesiyle üretilir (dışarıdan ses yok).
# Çalıştırma: python ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde. Bütün sesler save_loudness() ile aynı algılanan yüksekliğe
# eşitlenir; yumuşak, kısa, korkutmayan. Olumsuz (hata) sesi yok: yanlış hamlede sadece yumuşak "geri" sesi.
#
# - pop: parça tutulunca
# - nota_0 .. nota_5: parçaların notaları (pentatonik ksilofon; örüntünün A, B, C harfleri 0, 2, 4)
# - geri: yanlış yerden yumuşakça geri dönüş
# - kolye: kolye takılınca parlak çıngırak
# - patlama: parti bayrakları için konfeti patlaması
# - cicek: çiçek açınca yukarı kıvrılan "fuu-ling"
# - surun: tırtıl sürünürken yumuşak kıpırtı (birkaç kez çalınır)
# - adim: geçitte hayvan adımı (kısa, tok)
# - bolum_sonu, final: kutlamalar

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "ortak", "ses"))
from sentez import (RATE, bandpass, bell, check_all, envelope, lowpass, melody, mix, noise, note,  # noqa: E402
                    save_loudness, silence, soft_tone, sweep)

TARGET = 0.1
NOTES = ["C5", "D5", "E5", "G5", "A5", "C6"]


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


def pop() -> list:
    out = sweep(360, 1150, 0.1, 0.003, 36.0, 0.6)
    mix(out, sweep(720, 2300, 0.06, 0.002, 60.0, 0.6), 0.0, 0.15)
    return out


def marimba(name: str) -> list:
    f = note(name)
    out = soft_tone(f, 0.9)
    mix(out, bell(f * 2.0, 0.5, 9.0), 0.0, 0.25)
    mix(out, envelope(bandpass(noise(0.02, 3), 1500, 5000), 0.001, 200.0), 0.0, 0.15)
    return out


def back() -> list:
    out = sweep(520, 300, 0.24, 0.02, 7.0, 0.7)
    return lowpass(out, 1800)


def necklace() -> list:
    # Küçük çanlar art arda: boncukların şıngırtısı
    out = silence(1.0)
    for k, name in enumerate(["E6", "G6", "C7", "E7", "G7"]):
        mix(out, bell(note(name), 0.6, 7.0), k * 0.06, 0.35)
    return out


def popper() -> list:
    # Konfeti patlaması: kısa yumuşak "puf" + saçılan tiz ışıltılar
    out = envelope(lowpass(noise(0.25, 11), 1800), 0.002, 22.0)
    for k, name in enumerate(["C7", "G7", "E7", "C8"]):
        mix(out, bell(note(name), 0.4, 10.0), 0.05 + k * 0.05, 0.12)
    return out


def bloom() -> list:
    out = sweep(500, 1300, 0.3, 0.02, 5.0, 1.4)
    mix(out, bell(note("G6"), 0.6, 6.0), 0.18, 0.3)
    mix(out, bell(note("C7"), 0.6, 6.0), 0.26, 0.2)
    return lowpass(out, 6000)


def crawl() -> list:
    # Tırtıl kıpırtısı: iki kısa yumuşak "vıp"
    out = silence(0.4)
    for k in range(2):
        mix(out, sweep(420, 560, 0.12, 0.01, 18.0, 1.0), k * 0.15, 0.6)
    return lowpass(out, 2500)


def step() -> list:
    # Yumuşak tok adım (çim üstünde pati)
    out = sweep(240, 150, 0.12, 0.002, 30.0, 0.6)
    mix(out, envelope(lowpass(noise(0.05, 7), 1200), 0.001, 70.0), 0.0, 0.35)
    return out


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


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("pop.wav", pop())
    for k, name in enumerate(NOTES):
        save(f"nota_{k}.wav", marimba(name))
    save("geri.wav", back(), TARGET * 0.6)
    save("kolye.wav", necklace(), TARGET * 0.8)
    save("patlama.wav", popper(), TARGET * 0.8)
    save("cicek.wav", bloom(), TARGET * 0.8)
    save("surun.wav", crawl(), TARGET * 0.6)
    save("adim.wav", step(), TARGET * 0.6)
    save("bolum_sonu.wav", level_end())
    save("final.wav", finale())
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
