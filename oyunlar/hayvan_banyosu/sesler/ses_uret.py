# Hayvan Banyosu sesleri: sadece Python standart kütüphanesiyle üretilir.
# Çalıştırma: python ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde; pop, kıkırdama, bölüm sonu ve final Hayvanları Besle'nin
# ses_uret.py'sinden (oradan içe aktarılır, o dosyaya dokunulmaz). Hepsi save_loudness() ile eşitlenir.
#
# - Döngüler (parmak hareket ettikçe açılır, durunca susar; sesler.gd döngü yapar): sunger (köpüklü
#   sürtme), dus (akan su), havlu (yumuşak hışırtı).
# - Kısa sesler: kopur (çamur köpüğe dönünce), temiz (bir leke bitince: tatlı çan), adim (bir adım bitince:
#   yükselen üç nota), silkin (hayvan silkinirken "brrr"), kabarcik (kabarcık patlayınca), pop, kikir,
#   bolum_sonu, final.
# - Hayvan sesleri Hayvanları Besle'den KOPYADIR (bu betik kopyalar): kedi, kopek, inek (CC0 kayıtlar,
#   bkz. CREDITS.md) ve tavsan, maymun, fare, ayi, sincap, panda, kus (orada sentezlenmiş yer tutucular).

import importlib.util
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BESLE = os.path.join(HERE, "..", "..", "hayvan_besle", "sesler")
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "ortak", "ses"))
from sentez import (RATE, bandpass, bell, check_all, envelope, lowpass, melody, mix, noise, note,  # noqa: E402
                    save_loudness, silence, smooth_env, soft_tone, sweep, voice, glide)

_spec = importlib.util.spec_from_file_location("besle_ses", os.path.join(BESLE, "ses_uret.py"))
besle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(besle)

TARGET = 0.1
VOICES = ["kedi", "kopek", "inek", "tavsan", "maymun", "fare", "ayi", "sincap", "panda", "kus"]


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


def seamless(samples: list, fade: float = 0.12) -> list:
    # Sonun son 'fade' saniyesini başa karıştırır: döngü dikişsiz olur
    n = int(RATE * fade)
    body = samples[:-n]
    tail = samples[-n:]
    for i in range(n):
        k = i / n
        body[i] = body[i] * k + tail[i] * (1 - k)
    return body


# --- Döngüler ---

def sponge_loop() -> list:
    # Köpüklü sürtme: yumuşak, ıslak hışırtı ve araya serpilmiş minik kabarcık "plip"leri
    s = 1.4
    out = bandpass(noise(s, 51), 400, 2400)
    out = [v * (0.6 + 0.4 * abs(math.sin(2 * math.pi * 4.0 * i / RATE))) for i, v in enumerate(out)]
    for k in range(9):
        t = 0.05 + k * 0.15 + (0.04 if k % 2 else 0.0)
        f = 900 + (k * 263) % 700
        mix(out, sweep(f, f * 1.8, 0.05, 0.002, 60.0, 0.6), t, 0.35)
    return seamless(lowpass(out, 3500))


def shower_loop() -> list:
    # Akan su: geniş gürültü, hafif çalkantı (yumuşak, yüksek frekansı kısık)
    s = 1.6
    out = bandpass(noise(s, 52), 700, 6000)
    out = [v * (0.8 + 0.2 * math.sin(2 * math.pi * 7.0 * i / RATE) * math.sin(2 * math.pi * 1.3 * i / RATE)) for i, v in enumerate(out)]
    for k in range(12):
        f = 1200 + (k * 331) % 1400
        mix(out, sweep(f, f * 1.5, 0.04, 0.002, 70.0, 0.6), 0.03 + k * 0.13, 0.2)
    return seamless(lowpass(out, 5000))


def towel_loop() -> list:
    # Havlu: pes, pamuklu sürtünme
    s = 1.2
    out = bandpass(noise(s, 53), 200, 1400)
    out = [v * (0.65 + 0.35 * abs(math.sin(2 * math.pi * 3.0 * i / RATE))) for i, v in enumerate(out)]
    return seamless(lowpass(out, 1600))


# --- Kısa sesler ---

def foam_up() -> list:
    # Çamur köpüğe döndü: yukarı süzülen iki yumuşak "blup"
    out = sweep(300, 700, 0.12, 0.004, 22.0, 0.7)
    mix(out, sweep(500, 1100, 0.1, 0.004, 26.0, 0.7), 0.07, 0.6)
    return lowpass(out, 4000)


def clean() -> list:
    # Bir leke bitti: tatlı kısa çan ve ışıltı
    out = bell(note("E6"), 0.45, 8.0)
    mix(out, bell(note("B6"), 0.35, 10.0), 0.05, 0.35)
    return out


def step_done() -> list:
    # Bir adım bitti (alet değişiyor): yükselen üç nota
    out = melody(["C5", "E5", "G5"], 0.09, 0.5)
    mix(out, bell(note("C7"), 0.4, 8.0), 0.22, 0.2)
    return out


def shake() -> list:
    # Silkinme: hızlı titreşen "brrrr" (dudak titremesi gibi) ve saçılan damla hışırtısı
    s = 0.7
    out = voice(s, lambda t: glide([(0, 150), (0.35, 175), (0.7, 140)], t) * (1 + 0.15 * math.sin(2 * math.pi * 26 * t)),
                lambda t: smooth_env(t, s, 0.04, 0.2) * (0.55 + 0.45 * abs(math.sin(2 * math.pi * 13 * t))),
                lambda t: [(500, 120, 1.0), (1300, 200, 0.3)], buzz=0.8, breath=0.2, seed=54)
    spray = envelope(bandpass(noise(0.5, 55), 1800, 7000), 0.02, 6.0)
    mix(out, spray, 0.1, 0.35)
    return lowpass(out, 6000)


def bubble_pop() -> list:
    # Kabarcık patladı: minik, tiz "plip"
    out = sweep(900, 2200, 0.05, 0.001, 70.0, 0.5)
    mix(out, envelope(bandpass(noise(0.02, 56), 2500, 8000), 0.001, 120.0), 0.0, 0.2)
    return out


def copy_voices() -> None:
    for name in VOICES:
        shutil.copyfile(os.path.join(BESLE, name + ".wav"), os.path.join(HERE, name + ".wav"))
        print(name + ".wav (Hayvanları Besle'den kopya)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("sunger.wav", sponge_loop())
    save("dus.wav", shower_loop())
    save("havlu.wav", towel_loop())
    save("kopur.wav", foam_up())
    save("temiz.wav", clean())
    save("adim.wav", step_done())
    save("silkin.wav", shake())
    save("kabarcik.wav", bubble_pop(), TARGET * 0.8)
    save("pop.wav", besle.pop())
    save("kikir.wav", besle.giggle())
    save("bolum_sonu.wav", besle.level_end())
    save("final.wav", besle.finale())
    copy_voices()
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
