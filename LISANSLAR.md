# Telif ve lisans incelemesi

İnceleme tarihi: 1 Ekim 2026. Kapsam: projedeki bütün görseller, sesler, yazı tipleri, isimler, uygulama simgesi ve
oyun motoru. Dışarıdan alınan varlıkların kısa listesi `CREDITS.md`'de, ortak seslerin dosya dosya dökümü
`ortak/sesler/SESLER.md`'de durur; bu dosya incelemenin sonucunu ve yapılan değişiklikleri anlatır.
Kanıtlar (kaynak sayfaları, arşiv kopyaları, dosya özetleri) `LISANS_KANITLARI.md`'de; kayıtların tutarlılığı
`python lisans_denetle.py` ile denetlenir.

**Sonuç:** ticari yayına engel bir lisans sorunu bulunmadı. Dışarıdan alınan her şey CC0 ya da OFL lisanslı,
geri kalan her şey projede üretildi. Bir görsel önlem olarak değiştirildi (Uçan Kuş direği), uygulamaya
Lisanslar ekranı eklendi. Arkadaşımın oyunlarındaki iki marka adı (dosya ve sınıf adlarında) temizlendi.

İkinci tur (1 Ekim 2026, akşam): arkadaşımın Müzik Kutusu'na eklediği beş yeni hayvan sesi kaydı incelendi
(hepsi CC0) ve onun oyunlarındaki bulgular, kendi isteğimle düzeltildi.

Üçüncü tur (2 Ekim 2026, yayın öncesi): son incelemeden sonra eklenen çeviri tablosu (`ortak/ceviri/ceviriler.csv`)
ve yeni dosyalar incelendi. Yeni ses ya da yazı tipi yok; tek yeni görsel (`meyve_topla/gorseller/agac_tac_genis.svg`)
projede çizildi. İki İngilizce ad değiştirildi (aşağıda 12. madde), denetim betiği çeviri tablosunu da tarar oldu.

Durum sütunu: **uygun** (sorun yok), **düzeltildi** (bu incelemede değiştirildi), **kontrol edilmeli** (bir insanın
bakması gerekiyor; ayrıntı "Manuel kontrol gerekenler" bölümünde).

## Nasıl incelendi

- **Görseller:** bütün SVG ve PNG dosyaları oyun oyun tabloya dizilip gözle incelendi. Ayrıca SVG'lerin içinde
  dış kaynak izi arandı (çizim programı imzası, gömülü resim, stok site adı, yazı tipi adı); hiçbirinde yok.
- **Sesler:** her ses dosyasının bir üretim betiğinde ya da `SESLER.md`'de karşılığı olduğu denetlendi. İndirilen
  seslerin kaynak sayfaları 1 Ekim 2026'da yeniden açılıp lisansları okundu.
- **İsimler:** kod, dosya adları, sahneler, ekran yazıları ve belgelerde yaklaşık 70 oyun, film ve marka adı arandı.
- **Yazı tipi:** dosyanın içindeki telif ve lisans kayıtları okundu.

## Görseller

| Dosya / klasör | Kaynak | Lisans | Durum |
|---|---|---|---|
| `oyunlar/ucan_kus/` (5 SVG + `gorseller/` 34 SVG) | projede çizildi (`gorseller/svg_uret.py`) | bize ait | **düzeltildi** (direk; aşağıda). Yatay sürümde her bölgenin kendi sütunu var (ağaç gövdesi, bina, buz, palmiye gövdesi, gece sütunu): hepsi başlıksız, yuvarlak uçlu |
| `oyunlar/dondurmaci/gorseller/` (24 SVG) | projede çizildi | bize ait | uygun |
| `oyunlar/yol_yap/gorseller/` (16 SVG) | projede çizildi | bize ait | uygun |
| `oyunlar/hafiza/` (27 SVG) | projede çizildi | bize ait | uygun |
| `oyunlar/meyve_topla/gorseller/` (46 SVG) | projede çizildi | bize ait | uygun |
| `oyunlar/araba_yarisi/gorseller/` (59 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun: arabalarda yüz ya da göz yok, logo yok |
| `oyunlar/sihirli_bahce/gorseller/` (102 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun |
| `oyunlar/robot_fabrikasi/gorseller/` (102 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun: geometrik parçalar, bilinen bir film robotuna benzemiyor |
| `oyunlar/tren_rayi/gorseller/` (80 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun: lokomotif üstten görünüşlü ve yüzsüz |
| `oyunlar/balik_tutma/gorseller/` (88 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun: çöp nesnelerinde (şişe, kutu, poşet) yazı ya da logo yok |
| `oyunlar/kule_yapma/gorseller/` (65 SVG) | projede çizildi (`svg_uret.py`) | bize ait | uygun |
| Arkadaşımın 9 oyunu (311 SVG, 60 PNG) | projede çizildi; boyama sayfaları kendi SVG'lerinden üretildi | bize ait | uygun; bir dosya adı **düzeltildi** (aşağıda) |
| `ana_menu/kartlar/` (20 SVG) | oyunların kendi SVG'lerinden birleştirildi (`ana_menu/svg_uret.py`) | bize ait | uygun |
| `ana_menu/gorseller/` (11 SVG) | projede çizildi | bize ait | uygun |
| `ortak/gorseller/` (2 SVG) | projede çizildi | bize ait | uygun |
| `icon.svg`, `ortak/simge/` (2 SVG, 3 PNG), `.playstore/icon_512.png` | projede çizildi: trambolinde zıplayan aslan, panda ve zürafa (oyunlardaki hayvan çizimleri; `ortak/simge/simge_uret.py`) | bize ait | uygun: Godot logosu değil |

Hiçbir görselde gerçek marka logosu, marka yazısı ya da ambalajı yok.

## Sesler

| Dosya / klasör | Kaynak | Lisans | Durum |
|---|---|---|---|
| `ortak/sesler/` (38 ses) | Kenney ve OpenGameArt paketleri; dökümü `SESLER.md` | CC0 | uygun: 16 kaynak sayfası yeniden doğrulandı |
| `ortak/sesler/tren_duduk.ogg` | OpenGameArt: "Steam whistle" (`steam_whistle.wav`), yükleyen bart, https://opengameart.org/content/steam-whistle | CC0 | uygun: sayfa doğrulandı (1 Ekim 2026) |
| `ortak/sesler/tren_cufcuf.ogg`, `tren_fren.ogg` | OpenGameArt: "Steam release sounds" (`steam_hisses.zip` içinden `steam hisses - Marker #1`-`#4.wav`), yükleyen bart, https://opengameart.org/content/steam-release-sounds | CC0 | uygun: sayfa doğrulandı (1 Ekim 2026) |
| `ortak/sesler/vuus.ogg` | projede kodla üretildi (`ses_hazirla.py`) | bize ait | uygun |
| Oyunların `sesler/` klasörleri (184 wav) | projede Python ile sentezlendi (`ses_uret.py` betikleri) | bize ait | uygun |
| `muzik_kutusu/sesler/kedi.wav`, `kopek.wav` ve `hayvan_besle`'deki kopyaları | OpenGameArt: "Cat Purr & Meow" (Kerzoven), "Dog Barking Mono" (Brandon Morris) | CC0 | uygun: sayfalar doğrulandı |
| `muzik_kutusu/sesler/inek.wav`, `koyun.wav`, `ordek.wav`, `horoz.wav` (inek `hayvan_besle`'de de var) | BigSoundBank (Joseph Sardin): "Cow Moos #1", "Sheep #1", "Ducks", "Rooster Song" | CC0 | uygun: dört sayfa ve sitenin lisans sayfası doğrulandı |
| `muzik_kutusu/sesler/kurbaga.wav` | OpenGameArt: "Ribbit Frog Sounds" (EZduzziteh) | CC0 | uygun: sayfa doğrulandı |
| Müzik Kutusu şarkıları (`sarkilar/`, 3 ezgi) | geleneksel ezgiler: Twinkle Twinkle, Mary Had a Little Lamb, Frère Jacques | kamu malı | uygun |

- `SESLER.md`'deki 42 satır ile `ortak/sesler/` içindeki 42 dosya birebir eşleşiyor; listede olmayan ses yok.
- İki kaynak çift lisanslı (CC0 ve OGA-BY 3.0): "Feel Good Island" ve "Dog Barking Mono". İkisinde de CC0 seçildi.
- "Feel Good Island" döngüsü, Brandon Morris'in özgün parçasından başka bir kullanıcının kırptığı sürüm. Özgün
  parçanın sayfası da CC0 / OGA-BY çift lisanslı, yani yeniden lisanslama geçerli.
- Kaynağı ya da lisansı belirsiz ses bulunmadı; bu yüzden hiçbir ses değiştirilmedi.
- Müzik Kutusu'nun indirilen kayıtları `oyunlar/muzik_kutusu/sesler/CREDITS.md`'de dosya dosya yazılı; özgün
  kayıtlar `sesler/kaynak/` içinde duruyor (`.gdignore` sayesinde uygulamaya girmiyor).

## Yazı tipleri

| Dosya | Kaynak | Lisans | Durum |
|---|---|---|---|
| `ortak/fontlar/Nunito.ttf` | Google Fonts; Copyright 2014 The Nunito Project Authors | SIL Open Font License 1.1 | uygun: lisans dosyası `ortak/fontlar/OFL.txt` projede |

Projede başka yazı tipi yok. SVG'lerin hiçbirinde yazı ya da yazı tipi adı geçmiyor. Nunito'nun lisansında
"ayrılmış yazı tipi adı" (Reserved Font Name) beyanı yok.

## İsimler

| Yer | Bulgu | Durum |
|---|---|---|
| Benim 11 oyunum, `ana_menu/`, `ortak/`, `project.godot` | başka oyun, film ya da marka adı yok ("flappy" dahil) | uygun |
| Uygulama adı "Bouncy Zoo" (eski adı "Minik Oyunlar") | aramada birebir aynı adlı bir uygulama çıkmadı, ama bu kesin kanıt değil | **kontrol edilmeli** |
| İngilizce uygulama adı "Tiny Games" | Google Play'de aynı adlı bir çocuk etkinlik uygulaması var ("Tiny Games - play everyday"); "Minik Games" adı da başka bir çocuk uygulamasında kullanılıyor | **düzeltildi**: "Bouncy Zoo: Kids Games 4-8". Önce düşünülen "Tumble Zoo" adıyla bir oyun olduğu için bu seçildi. Google Play'de çok benzer adlı "Bouncy Zoo Escape" adlı bir hayvan oyunu var; birebir aynı değil, ama mağaza ve marka aramasında bakılmalı (aşağıda "Manuel kontrol gerekenler" 1) |
| Hafıza'nın İngilizce adı "Memory" | "memory®" Ravensburger'in birçok ülkede tescilli markası; şirket adında bu sözcük geçen uygulamalara itiraz etti, 2017'de Amsterdam İstinaf Mahkemesi markayı korudu | **düzeltildi**: "Find the Pairs" |
| Gölge Eşleştirme: bir oyuncak bloğun dosya adı tescilli bir oyuncak markasıydı | yalnızca dosya adında, ekranda görünmüyordu | **düzeltildi**: `blok` |
| Köstebek: sınıf adları tescilli bir oyun adını ("Whac-A-Mole") çağrıştırıyordu | yalnızca kod içinde | **düzeltildi**: `Mole...` |

## Uygulama simgesi ve oyun motoru

| Konu | Bulgu | Durum |
|---|---|---|
| `icon.svg` | özgün çizim; Godot logosu değil | uygun |
| Android simgeleri (`ortak/simge/android_*.png`, `simge_*.png`) | özgün çizim; 4 Ekim 2026'da `export_presets.cfg`'deki başlatıcı simgesi ayarlarına bağlandı | uygun: ilk derlemeden sonra telefonda bakılmalı |
| Açılış ekranı | `ortak/marka/splash.png`: stüdyonun kendi kidolab logosu (Lina's Farm ile aynı dosya); Godot logosu gösterilmiyor | uygun |
| Godot Engine (MIT) | lisans metni uygulamada gösterilmiyordu | **düzeltildi**: Lisanslar ekranı eklendi |
| Godot içindeki üçüncü taraf bileşenler (FreeType, mbedTLS vb.) | bildirimleri gösterilmiyordu | **düzeltildi**: Lisanslar ekranında |

## Yapılan değişiklikler

1. **Uçan Kuş direği** (`oyunlar/ucan_kus/direk.svg`). Direk "gövde + daha geniş dudaklı başlık" biçimindeydi.
   Renkleri farklı olsa da bu siluet Flappy Bird ve Mario borularının en tanınan öğesi. Geniş başlık kaldırıldı,
   uç yuvarlatıldı; renkler, bantlar ve noktalar aynı kaldı. Gövde genişliği çarpışma alanıyla aynı (120 px)
   yapıldı, yani oynanış değişmedi. Kuşa dokunulmadı: mavi, tepelikli vektör çizim, Flappy Bird'ün sarı pikselli
   kuşuna benzemiyor.
2. **Lisanslar ekranı** (`ana_menu/lisanslar.gd`, `ana_menu/lisans_metinleri.gd`). Ana menünün sol üstündeki
   küçük "i" düğmesi 3 saniye basılı tutulunca açılır (ebeveyn kapısı); kısa dokunuşta yalnızca "3 saniye
   basılı tutun" yazısı belirir. İçerik: Godot lisans metni, Nunito telifi ve OFL metni, ses kaynakları,
   Godot içindeki bileşenlerin listesi ve isteğe bağlı tam lisans metinleri. Godot bilgileri çalışırken
   motordan okunur (`Engine.get_license_text()`, `get_copyright_info()`, `get_license_info()`).
3. **Geri tuşu** (`ortak/sahne_gecis.gd`). Lisanslar açıkken Escape ya da Android geri tuşu uygulamadan çıkmak
   yerine ekranı kapatsın diye küçük bir kanca eklendi (`geri_yakalayici`).
4. **`CREDITS.md`**. "Sesler projede sentezlendi" cümlesi ortak ses paketleri eklendikten sonra eksik kalmıştı;
   `SESLER.md`'ye ve bu dosyaya gönderme eklendi.
5. **`.gitignore`**. Python önbellek dosyaları (`__pycache__/`, `*.pyc`) eklendi.
6. **Gölge Eşleştirme: blok adı.** `esyalar/oyuncaklar/` içindeki oyuncak bloğun dosyaları tescilli bir marka
   adını taşıyordu; `blok.svg`, `blok.svg.import`, `blok.tres` olarak yeniden adlandırıldı,
   `bolumler/bolum_03.tres` ve `TASARIM.md` güncellendi. Görsel aynı (genel bir çıkıntılı yapı bloğu).
   Oyunun 10 bölümlük oynanış testi geçti.
7. **Köstebek: sınıf adları.** `WhackBalance` → `MoleBalance`, `WhackLevelData` → `MoleLevelData`; yorumlardaki
   `WhackAMoleGame` → `MoleGame`, `WhackGameState` → `MoleGameState` (`denge.tres` içindeki `script_class`
   dahil). Davranış değişmedi; denge dosyası yeni adlarla yükleniyor.
8. **Hayvanları Besle: derlenmiş Python dosyası.** `gorseller/__pycache__/svg_uret.cpython-314.pyc` repodan
   çıkarıldı (lisans sorunu değildi, repoda durmaması gerekiyordu).
11. **Kanıtlar kaydedildi ve denetim betiği eklendi** (2 Ekim 2026). `LISANS_KANITLARI.md`: 28 kaynak
    sayfasının Internet Archive'daki tarihli kopyası (hepsinin lisansı gösterdiği doğrulandı), ortak seslerde
    kullanılan her orijinal dosyanın SHA-256 özeti, paketlerin içindeki lisans dosyaları. `lisans_denetle.py`:
    kayıtsız ses, lisanssız yazı tipi, dış kaynak izi taşıyan görsel, marka adı ya da ağ bağlantısı eklenirse
    hata verir. `ses_hazirla.py`'deki indirme, yarıda kesilince yarım dosya bırakmayacak şekilde düzeltildi.
10. **Tren Rayı'nın tren sesleri değiştirildi.** Eski düdük, "çuf", kalkış ve fren sesleri oyunun kendi
    betiğinde sinüs ve gürültüyle sentezlenmişti (lisans sorunu yoktu, ama kulağa garip geliyordu). Yerlerine
    OpenGameArt'taki CC0 gerçek buhar kayıtlarından hazırlanan `tren_duduk.ogg`, `tren_cufcuf.ogg` ve
    `tren_fren.ogg` kondu; eski dört `.wav` dosyası ve üretim kodu projeden silindi. Ayrıntı `SESLER.md`'de.
12. **İngilizce adlar ve denetim** (2 Ekim 2026, üçüncü tur). Çeviri tablosunda uygulama adı "Tiny Games" →
    "Bouncy Zoo: Kids Games 4-8" (`project.godot` `config/name_localized`; menü başlığı "Bouncy Zoo"), Hafıza'nın
    adı "Memory" → "Find the Pairs". Lisanslar ekranının İngilizce girişindeki "Nearly all drawings" Türkçesiyle
    aynı olacak şekilde "All drawings" yapıldı (bütün çizimler özgün). `lisans_denetle.py` artık `.csv` dosyalarını
    da tarıyor; marka listesine "memory", oyuncak markaları (Jenga, Brio, Duplo, Playmobil...), Türk çocuk çizgi
    filmleri (Pepee, Niloya, Rafadan Tayfa, Kral Şakir) ve Algida eklendi.
9. **Yeni hayvan sesleri kayıtlara işlendi.** BigSoundBank ve "Ribbit Frog Sounds" kaynakları `CREDITS.md`'ye ve
   Lisanslar ekranına (`ana_menu/lisans_metinleri.gd`) eklendi.

Yazı tipi lisans dosyası (`OFL.txt`) zaten `ortak/fontlar/` içindeydi; eklemeye gerek kalmadı.

## Arkadaşımın oyunları

Ciddi bir sorun yoktu. İlk turda bulunan üç küçük konu ikinci turda düzeltildi (yukarıda 6, 7 ve 8. maddeler);
arkadaşımın bilmesi gerekenler:

1. **Gölge Eşleştirme:** oyuncak bloğun dosyaları artık `esyalar/oyuncaklar/blok.*`. Yeni eşya eklerken dosya
   adlarında marka adı kullanılmamalı.
2. **Köstebek:** sınıflar artık `MoleBalance` ve `MoleLevelData`. Açık bir dalında eski adlar varsa `main`'i
   dalına alırken bu adları güncellemesi gerekir.
3. **Hayvanları Besle:** `__pycache__` klasörü artık repoda izlenmiyor (dosya diskte duruyor, `.gitignore` engelliyor).
4. **Yeni dış kaynak eklerken:** `oyunlar/muzik_kutusu/sesler/CREDITS.md`'deki gibi kaydetmeye devam etsin; ayrıca
   kökteki `CREDITS.md` ve Lisanslar ekranı (`ana_menu/lisans_metinleri.gd`) de güncellenmeli.

Sorun olmayanlar: bütün indirilen hayvan sesleri (CC0, sayfalar doğrulandı, özgün kayıtlar `.gdignore`'lu
klasörde), Müzik Kutusu şarkıları (kamu malı geleneksel ezgiler), boyama sayfaları (kendi SVG'lerinden
üretilmiş).
Turuncu-beyaz çizgili balık gerçek bir tür (palyaço balığı) ve sade çizilmiş; bir film karakterini
kopyalamıyor. Mavi lokomotif yüzsüz, genel bir oyuncak tren. Aslan sesi hâlâ sentez (yer tutucu); gerçek
kayıtla değiştirilirse o da CC0 olmalı ve kaydedilmeli.

## Manuel kontrol gerekenler

1. **Uygulama adı.** "Minik Oyunlar" ve "Bouncy Zoo" için Google Play, App Store ve TÜRKPATENT / EUIPO marka
   sorgusunda aynı ya da çok benzer bir ad var mı bakılmalı. Web aramasında birebir eşleşme çıkmadı, ama Google
   Play'de "Bouncy Zoo Escape" adlı bir hayvan oyunu var (ad çok yakın); mağaza içi arama yapılmadı.
2. **Android simgesi.** Başlatıcı simgeleri `export_presets.cfg`'de `ortak/simge/` altındaki dosyalara bağlandı.
   İlk derlemeden sonra telefonda simgenin kesilmediği ve varsayılan Godot simgesinin kalmadığı kontrol edilmeli.
3. **Sesleri dinlemek.** Lisanslar sayfalardan doğrulandı, ama sesleri dinleyemedim. Tanıdık bir melodiye
   benzeyen bir müzik olursa (özellikle altı müzik döngüsü) haber verilmeli.
4. **Lisans kanıtı (yapıldı).** Kaynak sayfalarının Internet Archive kopyaları ve dosya özetleri
   `LISANS_KANITLARI.md`'ye kaydedildi. İstenirse sayfaların PDF kopyası da ayrıca saklanabilir, ama gerekli değil.
5. **Oyun düzenlerinin benzerliği.** Dondurmacı (konuşma balonunda sipariş, altta kaplar ve tatlar) ve Yol Yap
   (ızgaraya parça yerleştirip bilyeyi hedefe ulaştırma) yaygın oyun türleri; projede sıfırdan tasarlandı ve
   bildiğim bir oyunun birebir kopyası değil. Yine de piyasadaki bütün çocuk oyunlarıyla karşılaştıramadım;
   benzer oyunları bilen birinin ekranlara bir kez bakması iyi olur.
6. **Uçan Kuş'un oynanışı.** "Dokununca kanat çırp, boşluklardan geç" mekaniği Flappy Bird ile aynı türde.
   Oyun mekaniği telifle korunmaz; yine de mağaza açıklamasında ve ekran görüntülerinde "Flappy" adı ya da
   o oyuna gönderme kullanılmamalı.
7. **Araba silueti.** Arabalar yuvarlak hatlı genel bir oyuncak araba; belirli bir modelin kopyası değil ve
   logosu yok. Çok düşük risk, yalnızca bilgi için.

Bu inceleme hukuki görüş değildir; mağazaya göndermeden önce şüpheli görülen noktalar için bir uzmana danışılabilir.
