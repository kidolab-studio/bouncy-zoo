# Google Play mağaza sayfası ve formlar — Bouncy Zoo

Play Console'a yapıştırılacak metinler ve formlara verilen cevaplar. Paket: `com.kidolab.bouncyzoo`.
Varsayılan dil: Türkçe (tr-TR); ek dil: English (en-US).

Bu klasör (`.playstore/`) mağazaya yüklenen her şeyi tutar; `.gdignore` sayesinde oyuna girmez.
Mağaza metni Play Console'da değişince burası da güncellenir.

## Yüklenecek görseller

| Play Console alanı | Dosya | Boyut |
| --- | --- | --- |
| Uygulama simgesi | `.playstore/icon_512.png` | 512×512 |
| Öne çıkan görsel (feature graphic) | `.playstore/feature_graphic_1024x500.png` | 1024×500 |
| Telefon ekran görüntüleri (8) | `.playstore/screenshots/telefon/01_…08_*.png` | 1920×1080 |
| 7" tablet ekran görüntüleri (8) | `.playstore/screenshots/tablet/01_…08_*.png` | 1920×1200 |
| 10" tablet ekran görüntüleri (8) | `.playstore/screenshots/tablet/01_…08_*.png` (aynı set) | 1920×1200 |

- Simgeyi ve öne çıkan görseli `python ortak/simge/simge_uret.py` üretir.
- Görüntülerde dile bağlı yazı yok; aynı set Türkçe ve İngilizce sayfada kullanılır.
- Ekran görüntülerini yeniden üretmek için (proje kökünden, pencereli; monitör o boyutu almalı):

      godot --path . --fixed-fps 60 -s res://ortak/testler/magaza_ekranlari.gd                                                 # telefon
      godot --path . --fixed-fps 60 -s res://ortak/testler/magaza_ekranlari.gd -- res://.playstore/screenshots/tablet 1920x1200   # tablet

---

## Mağaza metni — Türkçe (tr-TR)

**Uygulama adı** (26 / 30 karakter)

    Bouncy Zoo: Kids Games 4-8

**Kısa açıklama** (67 / 80 karakter)

    4–8 yaş için reklamsız, internetsiz ve neşeli eğitici mini oyunlar.

**Tam açıklama** (1576 / 4000 karakter)

    Bouncy Zoo, küçük çocukların güvenle keşfedebileceği renkli ve sade mini oyunlardan oluşur. Uygulama çevrimdışı çalışır; reklam, uygulama içi satın alma, hesap açma ve kişisel veri toplama içermez.

    Çocuklar büyük dokunma alanları, yumuşak sesler ve sevimli şekillerle kendi hızlarında oynar. Yanlış cevaplarda ceza yoktur; denemek, keşfetmek ve tekrar oynamak teşvik edilir. İlerleme ve Boyama Kitabı eserleri yalnızca cihazda saklanır.

    Mini oyunlar ve geliştirilen beceriler

    Hayvanları Besle — Eşleştirme, ince motor becerileri
    Boyama Kitabı — Yaratıcılık, renk ve el-göz koordinasyonu
    Dondurmacı — Sıralama, örüntü ve yönerge takibi
    Balık Tutma — Dikkat, zamanlama ve koordinasyon
    Sihirli Bahçe — Yaratıcı keşif ve neden-sonuç
    Müzik Kutusu — Dinleme, ritim ve hayvan seslerini keşfetme
    Meyve Topla — Dikkat, tepki ve koordinasyon
    Hafıza — Görsel hafıza ve eşleştirme
    Gölge Eşleştirme — Şekil tanıma ve eşleştirme
    Yol Yap — Planlama ve mekânsal düşünme
    Tren Rayı — Problem çözme ve sıralama
    Büyükten Küçüğe — Boyut karşılaştırma ve sıralama
    Robot Fabrikası — Parça birleştirme ve örüntü
    Köstebek — Tepki ve dikkat
    Uçan Kuş — Zamanlama ve el-göz koordinasyonu
    Kule Yapma — Denge, sıra ve ince motor becerileri
    Toplama — Sayma ve erken matematik
    Araba Yarışı — Yön, zamanlama ve koordinasyon
    Zıpla Zıpla — Ritim ve tepki
    Çıkarma — Erken matematik ve miktar karşılaştırma

    Özellikler

    - Reklamsız ve satın alımsız
    - İnternetsiz oynanış
    - Büyük dokunma hedefleri
    - Türkçe ve İngilizce arayüz
    - Yerel ilerleme ve Boyama Kitabı galerisi
    - Ebeveynler için lisans bilgileri ekranı

---

## Mağaza metni — English (en-US)

**App name** (26 / 30 characters)

    Bouncy Zoo: Kids Games 4-8

**Short description** (62 / 80 characters)

    Ad-free, offline educational mini-games for children ages 4–8.

**Full description** (1558 / 4000 characters)

    Bouncy Zoo is a collection of colorful, simple mini-games designed for young children. The app works offline and includes no ads, in-app purchases, accounts, or collection of personal data.

    Children can explore at their own pace using large touch targets, gentle sounds, and friendly shapes. There are no harsh penalties for mistakes: the app encourages trying, discovering, and playing again. Progress and Coloring Book artwork stay on the device.

    Games and skills

    Feed the Animals — matching and fine motor skills; Coloring Book — creativity, colors, and hand-eye coordination; Ice Cream Maker — ordering, patterns, and following instructions; Fishing — attention, timing, and coordination; Magic Garden — creative exploration and cause and effect; Music Box — listening, rhythm, and animal sounds; Fruit Picking — attention and reaction; Find the Pairs — visual recall and matching; Shadow Match — shape recognition; Build a Road — planning and spatial thinking; Train Tracks — problem solving and sequencing; Big to Small — size comparison; Robot Factory — assembling and patterns; Mole — reaction and attention; Flying Bird — timing and hand-eye coordination; Tower Building — balance and fine motor skills; Addition — counting and early math; Car Race — direction and timing; Jump Jump — rhythm and reaction; Subtraction — early math and comparing quantities.

    Features

    - No ads and no in-app purchases
    - Offline play
    - Large touch targets
    - Turkish and English interface
    - Local progress and Coloring Book gallery
    - License information for parents

---

## Uygulama bilgileri

| Alan | Değer |
| --- | --- |
| Uygulama mı oyun mu | Oyun |
| Kategori | Educational (Eğitici) |
| Ücretli / ücretsiz | Ücretsiz |
| İletişim e-postası | (Play Console geliştirici hesabındaki e-posta) |
| Web sitesi | (isteğe bağlı) https://kidolab-studio.github.io/legal/ |
| Gizlilik politikası | https://kidolab-studio.github.io/legal/bouncy-zoo/privacy-policy |

Etiketler (Play'in listesinden en fazla 5): eğitici / educational, çocuklar için, sevimli / cute, çevrimdışı,
basit / casual. Play Console'daki listede birebir karşılıkları seçilir.

---

## Uygulama içeriği formları (Policy → App content)

**Gizlilik politikası:** yukarıdaki adres (metnin kaynağı `PRIVACY_POLICY.md`).

**Uygulama erişimi:** Tüm işlevler özel erişim gerektirmeden kullanılabilir (giriş, hesap yok).

**Reklamlar:** Hayır, uygulamada reklam yok.

**İçerik derecelendirmesi (IARC anketi):**
- Kategori: Oyun.
- Şiddet, kan, korku: Hayır.
- Cinsellik, çıplaklık: Hayır.
- Kaba dil: Hayır.
- Uyuşturucu, alkol, tütün: Hayır.
- Kumar ya da kumar benzeri (simüle kumar): Hayır. (Oyundaki yıldızlar oyun içinde kazanılır, gerçek parayla ilgisi yok.)
- Kullanıcılar arası iletişim / içerik paylaşımı: Hayır.
- Konum paylaşımı: Hayır.
- Dijital ürün satın alma: Hayır.
- Sınırsız internet erişimi: Hayır.
- Beklenen sonuç: PEGI 3, ESRB Everyone, USK 0 ve eşdeğerleri.

**Hedef kitle ve içerik:**
- Hedef yaş grupları: **5 yaş ve altı** ile **6-8 yaş**. (Tasarım 4-8 yaş; Play'in grupları bu ikisini kapsıyor.)
- Çocukların ilgisini çekebilir mi: Evet (zaten çocuklara yönelik).
- Mağaza sayfası doğrudan çocuklar ve aileler için.
- Aileler politikası gereklilikleri: reklam yok, veri toplanmıyor, oyunda tıklanabilir dış bağlantı yok.
  Lisanslar ekranı ebeveyn kapısının arkasında (menüdeki "i" düğmesi 3 sn basılı tutulur).

**Veri güvenliği (Data safety):**
- Uygulamanız gerekli kullanıcı veri türlerinden herhangi birini topluyor ya da paylaşıyor mu? **Hayır.**
- (Bu cevapla diğer sorular atlanır.) Dayanak: internet izni yok (`export_presets.cfg`: `permissions/internet=false`),
  hiçbir Android izni istenmiyor, reklam / analiz SDK'sı yok, kayıtlar yalnızca cihazda (`user://`) ve buluta
  yedeklenmiyor (`user_data_backup/allow=false`).

**Haber uygulaması / COVID-19 / Devlet uygulaması / Finans özellikleri / Sağlık:** Hayır / geçerli değil.
