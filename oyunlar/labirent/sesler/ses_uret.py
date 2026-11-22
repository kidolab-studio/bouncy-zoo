# Labirent sesleri: sadece Python standart kütüphanesiyle üretilir.
# Çalıştırma: py ses_uret.py   (bu klasöre .wav yazar, sonunda hepsini denetler)
# Ortak yardımcılar ortak/ses/sentez.py içinde; bütün sesler save_loudness() ile aynı algılanan yüksekliğe eşitlenir.
#
# - Oyun sesleri: tut (hayvan tutulunca), adim (hayvan bir hücre ilerleyince; oyun perdeyi gamda yükseltir),
#   duvar (duvara değince yumuşak "tup"), yildiz (yoldaki yıldız), yemek (çiğneme), bolum_sonu, final.
# - Hayvan sesleri: tavşan, maymun, fare, ayı, sincap, panda ve kuş Hayvanları Besle'nin ses_uret.py'sindeki
#   sentezle burada yeniden üretilir (o dosya içe aktarılır, ona dokunulmaz). kedi.wav, kopek.wav ve inek.wav
#   Hayvanları Besle'den bayt bayt KOPYADIR (o da Müzik Kutusu'ndan; CC0 kayıtlar, bkz. CREDITS.md).

import importlib.util
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES = os.path.join(HERE, "..", "..")
sys.path.insert(0, os.path.join(GAMES, "..", "ortak", "ses"))
from sentez import bell, check_all, envelope, lowpass, melody, mix, noise, note, bandpass, save_loudness, silence, sweep  # noqa: E402

_spec = importlib.util.spec_from_file_location("besle_ses", os.path.join(GAMES, "hayvan_besle", "sesler", "ses_uret.py"))
besle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(besle)

TARGET = 0.1
COPIED = ("kedi.wav", "kopek.wav", "inek.wav")


def save(name: str, samples: list, target: float = TARGET) -> None:
    save_loudness(HERE, name, samples, target)


def step() -> list:
    # Adım: kısa, tok, tahta gibi "tok" (oyun perdesini gamda yükseltir)
    out = sweep(520, 380, 0.09, 0.002, 38.0, 0.8)
    mix(out, bell(note("E6"), 0.12, 30.0), 0.0, 0.2)
    return lowpass(out, 4000)


def bump() -> list:
    # Duvar: yumuşak, pes "tup" (ceza gibi değil; çalı yaprağı hışırtısı)
    out = sweep(240, 150, 0.14, 0.004, 22.0, 0.9)
    mix(out, envelope(bandpass(noise(0.12, 7), 1500, 5000), 0.005, 30.0), 0.0, 0.18)
    return lowpass(out, 2500)


def star() -> list:
    # Yıldız: iki parlak çan
    out = bell(note("E6"), 0.6, 6.0)
    mix(out, bell(note("B6"), 0.5, 7.0), 0.07, 0.5)
    mix(out, bell(note("E7"), 0.4, 9.0), 0.14, 0.25)
    return out


def eat() -> list:
    # Yemek: "hım hım" çiğneme, yutma ve sonunda küçük mutlu çan
    out = silence(0.95)
    mix(out, besle.chew(), 0.0)
    mix(out, besle.gulp(), 0.45, 0.8)
    mix(out, bell(note("G6"), 0.35, 8.0), 0.66, 0.25)
    return out


def level_end() -> list:
    # Bölüm sonu: yukarı tırmanan neşeli kısa ezgi (labirentten çıkış)
    out = melody(["G4", "C5", "E5", "G5", "C6"], 0.1, 0.8)
    mix(out, bell(note("E7"), 0.6, 6.0), 0.42, 0.22)
    return out


def grab() -> list:
    return besle.pop()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    save("tut.wav", grab(), TARGET * 0.8)
    save("adim.wav", step(), TARGET * 0.7)
    save("duvar.wav", bump(), TARGET * 0.8)
    save("yildiz.wav", star())
    save("yemek.wav", eat())
    save("bolum_sonu.wav", level_end())
    save("final.wav", besle.finale())
    save("tavsan.wav", besle.rabbit())
    save("maymun.wav", besle.monkey())
    save("fare.wav", besle.mouse(), TARGET * 0.8)
    save("ayi.wav", besle.bear())
    save("sincap.wav", besle.squirrel(), TARGET * 0.85)
    save("panda.wav", besle.panda())
    save("kus.wav", besle.bird(), TARGET * 0.8)
    for name in COPIED:
        shutil.copyfile(os.path.join(GAMES, "hayvan_besle", "sesler", name), os.path.join(HERE, name))
        print(name, "(Hayvanları Besle'den kopya)")
    if not check_all(HERE):
        print("\nDenetim: SORUN VAR")
        sys.exit(1)
    print("\nDenetim: hepsi tamam")
