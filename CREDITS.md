# Emeği Geçenler ve Lisanslar

Dışarıdan alınan her varlık (yazı tipi, görsel, ses) burada listelenir. Yalnızca açık lisanslı (CC0 / OFL) varlıklar kullanılır.

## Yazı tipleri

- **Nunito**: Copyright 2014 The Nunito Project Authors (https://github.com/googlefonts/nunito). SIL Open Font License 1.1 (`ortak/fontlar/OFL.txt`). Kaynak: Google Fonts. Kullanım: `ortak/fontlar/Nunito.ttf` (tema, Toplama ve Çıkarma Öğreniyorum rakamları).

## Görseller ve sesler

- Oyunlardaki bütün SVG görseller projede elle çizildi.
- Oyunların kendi sesleri projede Python ile sentezlendi (`ortak/ses/sentez.py` ve oyunların `sesler/ses_uret.py` betikleri); aşağıdaki kayıtlar hariç.
- Ortak sesler ve müzikler (`ortak/sesler/`) CC0 paketlerinden alındı (Kenney, OpenGameArt); dosya dosya dökümü `ortak/sesler/SESLER.md` içinde.
- Bütün varlıkların telif ve lisans incelemesi `LISANSLAR.md` içinde, kanıtları (arşiv kopyaları, dosya özetleri) `LISANS_KANITLARI.md` içinde. Kayıtların tutarlılığı `python lisans_denetle.py` ile denetlenir. Uygulamadaki Lisanslar ekranının metinleri `ana_menu/lisans_metinleri.gd`'de; buraya ya da `SESLER.md`'ye yeni bir dış kaynak eklenince orası da güncellenmeli.

## İndirilen sesler (CC0)

- **Kedi miyavlaması** (Müzik Kutusu `sesler/kedi.wav`; Hayvanları Besle ve Hayvan Banyosu'nda kopyası): "Cat Purr & Meow", Kerzoven, CC0. Kaynak: https://opengameart.org/content/cat-purr-meow (`cat_mewfood.wav`, `oyunlar/muzik_kutusu/sesler/kaynak/` içinde; `ses_uret.py` keser ve seviyesini ayarlar).
- **Köpek havlaması** (Müzik Kutusu `sesler/kopek.wav`; Hayvanları Besle ve Hayvan Banyosu'nda kopyası): "Dog Barking Mono", Brandon Morris, CC0 (OGA-BY 3.0 ile çift lisanslı; CC0 seçildi). Kaynak: https://opengameart.org/content/dog-barking-mono (`dog_barking_mono.wav`, aynı klasörde).
- **İnek, koyun, ördek, horoz** (Müzik Kutusu `sesler/inek.wav`, `koyun.wav`, `ordek.wav`, `horoz.wav`; inek Hayvanları Besle ve Hayvan Banyosu'nda kopyası): BigSoundBank, Joseph Sardin, CC0. Kaynak: https://bigsoundbank.com ("Cow Moos #1", "Sheep #1", "Ducks", "Rooster Song"); dosya dosya bağlantılar `oyunlar/muzik_kutusu/sesler/CREDITS.md` içinde.
- **Kurbağa** (Müzik Kutusu `sesler/kurbaga.wav`): "Ribbit Frog Sounds", EZduzziteh, CC0. Kaynak: https://opengameart.org/content/ribbit-frog-sounds (`frog_ribbit_03.wav`).
