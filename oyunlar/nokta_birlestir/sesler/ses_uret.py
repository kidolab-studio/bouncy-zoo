# Noktaları Birleştir sesleri: sadece Python standart kütüphanesiyle üretilir (dışarıdan ses yok).
# Çalıştırma: py ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde. Bütün sesler save_loudness() ile aynı algılanan yüksekliğe
# eşitlenir; yumuşak, kısa, korkutmayan. Olumsuz (hata) sesi yok: yanlış noktada sadece yumuşak bir "bop".
#
# - nokta: nokta bağlanınca (tatlı çan; oyun perdesini numaraya göre gamda yükseltir, küçük bir ezgi olur)
# - yanlis: sırası gelmeyen noktaya dokununca (yumuşak, alçak "bop")
# - kapan: şekil kapanıp renkli resim belirirken (parıltılı yükselen "viyuu")
# - bolum_sonu, final: kutlamalar
# - Resim bitince çalan sesler (ayarlar.gd PICTURES sound): ev (kapı zili "ding-dong"), yelkenli (dalga
#   hışırtısı ve gemi düdüğü "tuut"), tac (kısa tören borusu)

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "ortak", "ses"))
from sentez import (bandpass, bell, check_all, envelope, glide, lowpass, melody, mix, noise, note,  # noqa: E402
                    save_loudness, silence, smooth_env, soft_tone, sweep, voice)

TARGET = 0.1


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


def dot() -> list:
    # Kısa, temiz çan (C6); oyun pitch_scale ile gamdaki notaya çeker
    out = bell(note("C6"), 0.45, 9.0)
    mix(out, bell(note("C7"), 0.3, 12.0), 0.0, 0.18)
    mix(out, sweep(900, 1500, 0.03, 0.001, 80.0, 0.6), 0.0, 0.12)
    return out


def wrong() -> list:
    out = sweep(330, 250, 0.22, 0.01, 10.0, 0.8)
    mix(out, sweep(495, 370, 0.18, 0.01, 12.0, 0.8), 0.0, 0.25)
    return lowpass(out, 1400)


def close() -> list:
    out = sweep(500, 1600, 0.55, 0.02, 3.5, 0.7)
    for k, name in enumerate(["C6", "E6", "G6", "C7", "E7"]):
        mix(out, bell(note(name), 0.5, 7.0), 0.08 + k * 0.07, 0.3)
    mix(out, envelope(bandpass(noise(0.6, 4), 3000, 9000), 0.2, 6.0), 0.0, 0.12)
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


def doorbell() -> list:
    # "Ding-dong": iki yumuşak çan, ikincisi alçak ve uzun
    out = bell(note("E5"), 1.0, 3.2)
    mix(out, bell(note("E6"), 0.6, 5.0), 0.0, 0.25)
    mix(out, bell(note("C5"), 1.4, 2.4), 0.42, 1.0)
    mix(out, bell(note("C6"), 0.8, 4.0), 0.42, 0.25)
    return out


def ship() -> list:
    # Dalga hışırtısı, sonra iki tatlı "tuut" (gemi düdüğü: alçak, yumuşak, korkutmayan)
    out = envelope(lowpass(noise(1.6, 9), 900), 0.4, 1.8)
    for start, s in ((0.25, 0.35), (0.75, 0.6)):
        horn = voice(s, lambda t: glide([(0, 196), (0.06, 220), (s, 216)], t), lambda t, s=s: smooth_env(t, s, 0.05, 0.15),
                     lambda t: [(500, 120, 1.0), (1100, 160, 0.4), (2400, 300, 0.08)], breath=0.04, seed=6)
        mix(out, lowpass(horn, 2600), start, 0.9)
    return out


def fanfare() -> list:
    # Kısa tören borusu: "ta-ta-taa" ve parıltı
    out = silence(1.4)
    for start, name, s in ((0.0, "G4", 0.12), (0.14, "G4", 0.12), (0.28, "C5", 0.5), (0.82, "E5", 0.2), (1.0, "G5", 0.4)):
        f = note(name)
        tone = voice(s, lambda t, f=f: f, lambda t, s=s: smooth_env(t, s, 0.015, 0.08),
                     lambda t: [(900, 160, 1.0), (1700, 220, 0.6), (2800, 300, 0.25)], breath=0.02, seed=8)
        mix(out, tone, start, 0.8)
    for k, name in enumerate(["C7", "E7", "G7"]):
        mix(out, bell(note(name), 0.5, 7.0), 1.05 + k * 0.06, 0.2)
    return out


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("nokta.wav", dot(), TARGET * 0.8)
    save("yanlis.wav", wrong(), TARGET * 0.5)
    save("kapan.wav", close(), TARGET * 0.8)
    save("bolum_sonu.wav", level_end())
    save("final.wav", finale())
    save("ev.wav", doorbell(), TARGET * 0.8)
    save("yelkenli.wav", ship(), TARGET * 0.8)
    save("tac.wav", fanfare(), TARGET * 0.8)
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
