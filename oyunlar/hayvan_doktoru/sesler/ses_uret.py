# Hayvan Doktoru sesleri: sadece Python standart kütüphanesiyle üretilir.
# Çalıştırma: python ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde; pop, kıkırdama, gün sonu ve final Hayvanları Besle'nin, temiz, adim ve
# havlu döngüsü Hayvan Banyosu'nun ses_uret.py'sinden (oradan içe aktarılır, o dosyalara dokunulmaz).
# Hepsi save_loudness() ile eşitlenir.
#
# - Döngüler (parmak hareket ettikçe açılır, durunca susar; sesler.gd döngü yapar): sil (pamuk, mendil, pudra,
#   kulak çubuğu: yumuşak hışırtı), merhem (merhem ve krem: ıslak, kaygan sürtünme), fircala (diş fırçası).
# - Kısa sesler: kalp (stetoskopta "güm-güm"), bant (yara bandı yapışınca "çıt"), cek (diken çıkınca), yut (şurup),
#   hapsu (hapşırık), damla (ilaç damlası), buz (buz kesesi), sargi (sargı sarılınca), temiz (bir nokta bitince),
#   adim (bir adım bitince), iyilesti (hasta iyileşince: kısa, neşeli), gun_sonu (üç hasta bitince), final (son gün), sayfa (albüm sayfası),
#   cikartma (çıkartma kazanılınca),
#   pop, kikir.
# - Hayvan sesleri Hayvanları Besle'den KOPYADIR (bu betik kopyalar): kedi, kopek, inek (CC0 kayıtlar,
#   bkz. CREDITS.md) ve tavsan, maymun, fare, ayi, sincap, panda, kus (orada sentezlenmiş yer tutucular).

import importlib.util
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")
BESLE = os.path.join(GAMES, "hayvan_besle", "sesler")
sys.path.insert(0, os.path.join(GAMES, "..", "ortak", "ses"))
from sentez import RATE, bandpass, bell, envelope, lowpass, melody, mix, note, noise, check_all, save_loudness, sweep  # noqa: E402


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


besle = _load("besle_ses", os.path.join(BESLE, "ses_uret.py"))
banyo = _load("banyo_ses", os.path.join(GAMES, "hayvan_banyosu", "sesler", "ses_uret.py"))

TARGET = 0.1
VOICES = ["kedi", "kopek", "inek", "tavsan", "maymun", "fare", "ayi", "sincap", "panda", "kus"]


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


# --- Döngüler ---

def ointment_loop() -> list:
    # Krem sürme: kaygan, ıslak sürtünme; araya yumuşak "şlp"ler
    s = 1.3
    out = bandpass(noise(s, 61), 250, 1800)
    out = [v * (0.55 + 0.45 * abs(math.sin(2 * math.pi * 2.6 * i / RATE))) for i, v in enumerate(out)]
    for k in range(5):
        mix(out, sweep(260 + k * 40, 520 + k * 60, 0.09, 0.006, 18.0, 0.7), 0.06 + k * 0.25, 0.3)
    return banyo.seamless(lowpass(out, 2200))


# --- Kısa sesler ---

def heartbeat() -> list:
    # Stetoskopta kalp: pes iki vuruş ("güm-güm"), ikincisi biraz daha hafif
    out = [0.0] * int(RATE * 0.5)
    for start, gain, freq in ((0.0, 1.0, 70.0), (0.16, 0.7, 62.0)):
        thump = sweep(freq * 1.6, freq, 0.14, 0.004, 26.0, 0.5)
        mix(out, thump, start, gain)
        mix(out, envelope(bandpass(noise(0.05, 62), 80, 400), 0.002, 50.0), start, gain * 0.25)
    return lowpass(out, 500)


def plaster() -> list:
    # Yara bandı yapıştı: kısa kağıt hışırtısı ve yumuşak "çıt"
    out = envelope(bandpass(noise(0.12, 63), 1500, 6000), 0.004, 30.0)
    mix(out, sweep(1300, 700, 0.06, 0.001, 50.0, 0.6), 0.05, 0.8)
    mix(out, sweep(500, 300, 0.08, 0.002, 30.0, 0.6), 0.07, 0.5)
    return lowpass(out, 7000)


def brush_loop() -> list:
    # Diş fırçalama: hızlı ileri geri "fış fış", köpüklü
    s = 1.2
    out = bandpass(noise(s, 64), 1800, 7000)
    out = [v * (0.25 + 0.75 * abs(math.sin(2 * math.pi * 3.3 * i / RATE)) ** 2) for i, v in enumerate(out)]
    for k in range(6):
        f = 1000 + (k * 311) % 800
        mix(out, sweep(f, f * 1.6, 0.04, 0.002, 70.0, 0.6), 0.08 + k * 0.19, 0.25)
    return banyo.seamless(lowpass(out, 7500))


def pull() -> list:
    # Diken çıktı: kısa, tiz "pıt" ve hafif yükselen ışıltı
    out = sweep(700, 1500, 0.05, 0.001, 60.0, 0.5)
    mix(out, banyo.clean()[: int(RATE * 0.25)], 0.04, 0.35)
    return out


def gulp() -> list:
    # Şurup yutuldu: aşağı inen iki yumuşak "glup"
    out = sweep(520, 240, 0.12, 0.004, 24.0, 0.7)
    mix(out, sweep(420, 200, 0.12, 0.004, 24.0, 0.7), 0.16, 0.8)
    return lowpass(out, 3000)


def sneeze() -> list:
    # Hapşırık: iki kısa nefes alma ("ha-ha") ve patlayan "şuu"
    out = [0.0] * int(RATE * 0.75)
    for start, f in ((0.0, 500), (0.18, 650)):
        breath = envelope(bandpass(noise(0.12, 65), f, f * 3), 0.05, 14.0)
        mix(out, breath, start, 0.5)
    burst = envelope(bandpass(noise(0.35, 66), 2200, 7500), 0.006, 9.0)
    mix(out, burst, 0.36, 1.0)
    mix(out, sweep(420, 260, 0.12, 0.004, 22.0, 0.6), 0.36, 0.45)
    return lowpass(out, 8000)


def drip() -> list:
    # İlaç damlası: minik, tiz "plink"
    out = sweep(1200, 2400, 0.06, 0.001, 55.0, 0.4)
    mix(out, sweep(1800, 2600, 0.05, 0.001, 70.0, 0.4), 0.05, 0.4)
    return out


def ice() -> list:
    # Buz kesesi değdi: buz küplerinin tıkırtısı ve serin bir çan
    out = [0.0] * int(RATE * 0.4)
    for k, t in enumerate((0.0, 0.05, 0.09)):
        mix(out, envelope(bandpass(noise(0.03, 67 + k), 3000, 8000), 0.001, 120.0), t, 0.6)
    mix(out, banyo.clean()[: int(RATE * 0.3)], 0.08, 0.3)
    return out


def wrap() -> list:
    # Sargı sarıldı: yumuşak kumaş hışırtısı, sonda "çıt"
    out = envelope(bandpass(noise(0.3, 69), 400, 2500), 0.05, 7.0)
    mix(out, sweep(1100, 700, 0.06, 0.001, 50.0, 0.6), 0.25, 0.7)
    return lowpass(out, 5000)


def cured() -> list:
    # Hasta iyileşti: zıplayan üç nota ve çan
    out = melody(["E5", "G5", "C6"], 0.09, 0.5)
    mix(out, bell(note("E7"), 0.5, 7.0), 0.2, 0.25)
    return out


def page_turn() -> list:
    # Albüm sayfası çevrildi: kısa kağıt hışırtısı
    out = envelope(bandpass(noise(0.25, 71), 1200, 6000), 0.03, 12.0)
    out = [v * (1.0 - i / len(out)) for i, v in enumerate(out)]
    return lowpass(out, 7000)


def sticker() -> list:
    # Çıkartma kazanıldı: yukarı süzülen "fıııt" ve iki parlak çan
    out = sweep(600, 1800, 0.18, 0.004, 10.0, 0.6)
    mix(out, bell(note("G6"), 0.4, 8.0), 0.12, 0.4)
    mix(out, bell(note("C7"), 0.4, 8.0), 0.2, 0.35)
    return out


def copy_voices() -> None:
    for name in VOICES:
        shutil.copyfile(os.path.join(BESLE, name + ".wav"), os.path.join(HERE, name + ".wav"))
        print(name + ".wav (Hayvanları Besle'den kopya)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("sil.wav", banyo.towel_loop())
    save("merhem.wav", ointment_loop())
    save("fircala.wav", brush_loop())
    save("kalp.wav", heartbeat())
    save("bant.wav", plaster())
    save("cek.wav", pull())
    save("yut.wav", gulp())
    save("hapsu.wav", sneeze())
    save("damla.wav", drip(), TARGET * 0.8)
    save("buz.wav", ice())
    save("sargi.wav", wrap())
    save("temiz.wav", banyo.clean())
    save("adim.wav", banyo.step_done())
    save("iyilesti.wav", cured())
    save("sayfa.wav", page_turn())
    save("cikartma.wav", sticker())
    save("gun_sonu.wav", besle.level_end())
    save("final.wav", besle.finale())
    save("pop.wav", besle.pop())
    save("kikir.wav", besle.giggle())
    copy_voices()
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
