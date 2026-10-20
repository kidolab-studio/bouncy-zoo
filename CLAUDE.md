# Bouncy Zoo

## Proje bilgisi

- Uygulama adı: **Bouncy Zoo** (Play Store başlığı: **Bouncy Zoo: Kids Games 4-8** İngilizce, **Bouncy Zoo: Çocuk Oyunları 4-8** Türkçe; paket `com.kidolab.bouncyzoo`).
- Repo: [kidolab-studio/bouncy-zoo](https://github.com/kidolab-studio/bouncy-zoo) (eski adresi `mem1nce/mini-games`).
- Gizlilik politikası ayrı repoda yayınlanır (`kidolab-studio/legal`, GitHub Pages): https://kidolab-studio.github.io/legal/bouncy-zoo/privacy-policy
- Durum: Google Play kapalı testi bitmek üzere, üretime geçiş hazırlığı yapılıyor.
- **Bu aşamanın kuralı**: sadece küçük ve güvenli düzeltmeler yap. Büyük yeniden yapılandırma, yeni özellik veya riskli değişiklik yapma; gerekiyorsa önce kullanıcıya sor. Her düzeltmeden sonra ilgili oyunu açıp çalıştığını kontrol et.

Küçük çocuklar (4-8 yaş) için basit eğitici mini oyunlar. Oyun fikirlerini kullanıcı verir, birlikte geliştiririz.
Uygulamanın adı her dilde "Bouncy Zoo" (`application/config/name`; bilgisayarda `user://` klasörü de bu adla: `app_userdata/Bouncy Zoo`). Eski adı "Minik Oyunlar"dı; belgelerde ve kod yorumlarında hâlâ geçebilir.

## Takım çalışması

Bu repoyu iki kişi kullanıyor (git kullanıcı adları): **mem1nce** ve **emirsalihgmrk**. İkisinin Claude'u da bu dosyayı okur.

### Dallarla çalışma

- `main` dalı her zaman çalışan sürümdür. `main`'e doğrudan commit veya push yapma (GitHub'da `main` korumalı: PR olmadan push, force push ve dal silme engelli).
- Her yeni iş için `main`'in güncel halinden yeni bir dal aç: `git checkout main`, `git pull`, sonra `git checkout -b <isim>/<kısa-açıklama>` (ör. `mehmet/meyve-topla-ses`).
- Bir iş = bir dal. Dallar kısa ömürlü olsun.
- İş bitince izin istemeden: dalı push'la, `gh pr create` ile PR aç, `gh pr merge --merge --delete-branch` ile hemen main'e birleştir, sonra main'e dön ve pull yap. (PR açıklamasına neyi değiştirdiğini ve Godot'ta nasıl test edileceğini yaz; yerel dal kaldıysa `git branch -d <dal>` ile sil.)
- PR'da çakışma (conflict) varsa birleştirme; dur ve kullanıcıya açıkla. (İstisna: çakışma sadece `CLAUDE.md` dosyalarındaysa aşağıdaki `CLAUDE.md` kuralına uy.)
- Uzun süren bir işte `main`'deki yenilikleri almak için `main`'i dalına merge et (`git fetch`, sonra `git merge origin/main`). Paylaşılan dallarda rebase yapma.
- Başkasının açık dalında, sahibi istemedikçe commit yapma.
- `gh` kurulu değilse veya giriş yapılmamışsa (`gh auth status`), kullanıcıya kurulum ve giriş adımlarını hatırlat: `winget install GitHub.cli`, terminali yeniden aç, `gh auth login` (GitHub.com → HTTPS → tarayıcı ile giriş).

### Sahiplik ve genel kurallar

- Oyun sahipleri:
  - **emirsalihgmrk**: `golge_eslestirme`, `kostebek`, `toplama`, `cikarma`, `zipla_zipla`, `muzik_kutusu`, `hayvan_besle`, `boyama_kitabi`, `buyukten_kucuge`
  - **mem1nce**: `ucan_kus`, `dondurmaci`, `yol_yap`, `hafiza`, `meyve_topla`, `araba_yarisi`, `sihirli_bahce`, `robot_fabrikasi`, `tren_rayi`, `balik_tutma`, `kule_yapma`
- Herkes sadece kendi oyun klasöründe çalışır. Başkasına ait oyunun dosyalarını açıkça istenmedikçe değiştirme.
- Ortak dosyalar: `project.godot`, `res://ana_menu/`, `res://ortak/`, `CLAUDE.md`. Bunlarda değişiklikleri küçük tut.
- Yeni oyunu yatay yap ve ana menüye kartını ekle; bunu ayrı bir commit olarak yap.
- Küçük ve sık commit at, açık Türkçe commit mesajları yaz.
- Çakışma (conflict) çıkarsa kendi başına çözme ve başkasının değişikliğini asla silme. Dur ve kullanıcıya hangi dosyada ne olduğunu açıkla.
- CLAUDE.md'de çakışma çıkarsa iki tarafı da koru ve devam et. (`.gitattributes` içindeki `CLAUDE.md merge=union` sayesinde yerel `git merge` bunu kendiliğinden yapar. GitHub PR ekranı bu ayarı dikkate almayabilir; PR'da çakışma görünürse dalında `git merge origin/main` yap, iki tarafın satırlarını da bırak (aynı satır iki kez geldiyse birini sil), commit'le, push'la ve PR'ı birleştir.)
- `git push --force`, `git reset --hard` veya geçmişi değiştiren komutları asla kullanma.
- `.godot/` klasörü commit'lenmez. İki geliştirici de Godot 4.7.2 kullanır.

## Proje durumu

- Motor: Godot 4.7, renderer: Mobile (`project.godot`). Hedef: sadece telefon (ileride Android).
- Ekran yönü: **bütün sahneler (ana menü ve bütün oyunlar) yataydır**: çizim boyutu 1280x720 (bilgisayarda test penceresi 800x450), `project.godot` yatay başlar. Oyunun ana sahnesinin kök script'inde `@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"` bulunur (bu değişkeni olmayan sahne de yatay sayılır). SahneGecis hâlâ `"dikey"` değerini destekler (720x1280), ama yeni oyunlar yatay yapılır.
- Ekran ölçekleme: `canvas_items` + `expand` — görünen alan temel boyuttan uzun/geniş olabilir (21:9 telefonda 1680x720, 4:3 tablette 1280x960). Kurallar aşağıdaki **Ekran uyumu** bölümünde.
- Giriş sadece dokunma (`InputEventScreenTouch`). Masaüstünde test için "Emulate Touch From Mouse" açık. Önemli öğeleri kenarlardan uzak tut (yanlardan ~40 px); çentik / kamera deliği için `EkranYardimcisi` güvenli alanını kullan.
- Başlangıç sahnesi: ana menü `res://ana_menu/ana_menu.tscn` (bir oyunu tek başına denemek için o oyunun sahnesini F6 ile çalıştır).

## Uygulama yapısı

- `ana_menu/` — Ana menü (yatay): üstte tek satırda başlık, kategori sekmeleri (Hepsi / Hareket / Bulmaca / Yaratıcı / Öğren) ve düğmeler, altında 5 sütunlu dikey kaydırılan büyük kartlar. **Bütün oyunlar tek listede: `ana_menu/oyun_listesi.gd` `OYUNLAR`** (ad, klasör, sahne, kart görseli, palet rengi, kategori, yön, isteğe bağlı `ilerleme` rozeti ve `yeni` rozeti; alanlar dosyanın başında açıklı). Kart görselleri `ana_menu/kartlar/<klasor>.svg`: `python ana_menu/svg_uret.py` oyunların kendi SVG'lerinden birleştirir (2x + mipmap içe aktar). Kart `oyun_karti.gd`, sekme `sekme.gd`, kaydırma ve dokunma `ana_menu.gd`. **Yeni oyun eklenince** `OYUNLAR`'a bir kayıt ve `svg_uret.py`'ye kart fonksiyonu ekle (ilk sürümde `"yeni": true`). Testler: `ana_menu/testler/menu_testi.gd` (headless; her oyunu menüden açıp Escape ile döner, `user://` kayıtlarını yedekleyip geri yazar), `ekran_testi.gd` (pencereli). Menü testleri headless'ta (kare pencere) `content_scale_aspect = KEEP` ile 1280x720 çizim alanı kullanır. Oyun testleri menüden açarken `OYUNLAR[i]["sahne"]` ve `_kartlar[i]` kullanabilir (aynı sıra).
- **Lisanslar ekranı** (`ana_menu/lisanslar.gd`): menünün sol üstündeki "i" düğmesi 3 sn basılı tutulunca açılır (ebeveyn kapısı; `ortak/basili_geri_dugmesi.gd`, `EBEVEYN_BEKLEME`). Godot lisansı ve bileşenleri motordan okunur (`Engine.get_license_text()` vb.); yazı tipi lisansı ve ses kaynakları `ana_menu/lisans_metinleri.gd`'de. Test: `ana_menu/testler/lisans_testi.gd`. **Dışarıdan yeni bir varlık (ses, yazı tipi, görsel) eklenince** `CREDITS.md`, `LISANSLAR.md`, `LISANS_KANITLARI.md` (sayfa, arşiv kopyası, SHA-256) ve `lisans_metinleri.gd` güncellenir, sonra `python lisans_denetle.py` çalıştırılır (kayıtsız ses, lisanssız yazı tipi, marka adı, ağ bağlantısı ya da `user://` dışına yazma bulursa hata verir; yayından önce de çalıştır); yalnızca CC0 / OFL gibi ticari kullanıma açık lisanslar kullanılır. Görsellerde ve adlarda başka oyun, film ya da marka çağrışımı yapılmaz (inceleme: `LISANSLAR.md`).
- `ortak/sahne_gecis.gd` — autoload `SahneGecis`: `sahne_degistir(yol)`, `ana_menuye_don()`, `sahneyi_yeniden_baslat()`; `geri_yakalayici` (açık bir üst ekran geri tuşunu kendisi karşılamak isterse fonksiyon verir); yumuşak kararma/açılma, geçişte eski sahne durur. Ekran yönü: perde kapalıyken yeni sahnenin `ekran_yonu` değeri okunur, `root.content_scale_size` 720x1280 / 1280x720 yapılır, mobilde `DisplayServer.screen_set_orientation`, bilgisayarda pencere çevrilir; sahne ancak bundan sonra ağaca eklenir (`_ready` doğru boyutla çalışır). F6 ile doğrudan açılan yatay sahne perde kapalıyken döndürülüp yeniden yüklenir. Android geri tuşu (`quit_on_go_back=false`, `NOTIFICATION_WM_GO_BACK_REQUEST`) ve Escape: oyundan ana menüye, ana menüden çıkış.
- **Diller (cihaz diline göre)**: Türkçe (varsayılan kaynak) + İngilizce; başka cihaz dilleri İngilizceye düşer (`internationalization/locale/fallback="en"`). Çeviriler `ortak/ceviri/ceviriler.csv` (`keys,tr,en`; **anahtar = Türkçe metnin kendisi**). Yeni yazı eklenince Türkçe metni yaz ve CSV'ye `tr` + `en` satırı ekle, sonra Godot'ta projeyi aç ya da `godot --headless --import` çalıştır (`.translation` dosyaları yenilenir, commit'le). `Label`/`Button` metinleri (sahnede ya da `label.text = "..."` ile) kendiliğinden çevrilir; **biçimli metinde** `tr("Puan: %d") % x`, **harf harf bölünen sözcükte** (kutlama, başlık) önce `tr()` kullan. Test için dil: `godot --language en` (testleri `--fixed-fps 60` ile çalıştır). Uygulama adı her dilde "Bouncy Zoo" (`config/name`; menü başlığı da aynı). "Bouncy Zoo: Kids Games 4-8" (EN) ve "Bouncy Zoo: Çocuk Oyunları 4-8" (TR) yalnızca mağaza başlığıdır. Mağazaya giden her şey `.playstore/` içinde (oyuna girmez): mağaza metinleri ve Play Console form cevapları `listing.md`; simge ve tanıtım görseli `ortak/simge/simge_uret.py` ile, telefon (`screenshots/telefon`, 1920x1080) ve tablet (`screenshots/tablet`, 1920x1200) ekran görüntüleri (8 oyun) `ortak/testler/magaza_ekranlari.gd` ile üretilir (tablet: `-- res://.playstore/screenshots/tablet 1920x1200`). Çevirilerde de oyun ve uygulama adlarında tescilli sözcük kullanma (Hafıza'nın İngilizce adı bu yüzden "Find the Pairs"; yasaklı adlar `lisans_denetle.py` `MARKALAR` listesinde, gerekçe `LISANSLAR.md`'de).
- `ortak/tema.tres` — proje geneli tema (`gui/theme/custom`): Nunito (değişken font, ağırlıklar `FontVariation` ile; OpenType etiketi sayı olarak yazılmalı: `2003265652` = `wght`), düğme ve panel stilleri, `Baslik` / `KartYazisi` / `Rozet` tip varyasyonları. Fredoka Türkçe "ş" harfini düzgün göstermediği için kullanılmadı.
- `ortak/basili_geri_dugmesi.gd` — ortak geri düğmesi, **çift dokunuşlu** (`double_tap`, varsayılan açık): ilk dokunuşta büyür ve parlar (sayaç / halka yok), ikinci dokunuş `completed` verir; başka bir yere dokunulunca ya da 5 sn dokunulmazsa eski haline döner (ilk dokunuştan sonraki 0.3 sn içindeki dokunuşlar sayılmaz, ekrana vuran çocuk kazara çıkmasın; başka yere dokunuşu düğme kendi `_input`'unda görür). Basılı tutmak da çalışır (`hold_time`, 0.6 sn; halkasız). `double_tap = false`: sadece basılı tutma (ana menüdeki ebeveyn kapısı, Boyama Kitabı'nın temizle düğmesi). API: `press` / `release` / `contains` / `handle_touch(touch)` / `reset()`; `HoldButton.replace(panel)` sahnedeki bir Panel'in yerine geçer; dokunmayı oyun sahnesi yönetir. **Bütün oyunların geri düğmesi bu düğmedir ve aynı görünür** (beyaz, mor çerçeve, ortak ok); tek dokunuşlu geri düğmesi yapma, oyunun geri düğmesinin rengini / ikonunu değiştirme (`bg_color` / `icon` yalnızca geri olmayan işler için).
- **Ekran: `EkranYardimcisi`** (`ortak/ekran_yardimcisi.gd`; `class_name`'li statik yardımcı, her script'ten `EkranYardimcisi.xxx()` diye çağrılır; aynı script `EkranDurumu` adıyla autoload'dur ve ekranı izler): `gorunen_boyut()`, `tasarim_alani()` (görünen alanın ortasındaki 1280x720), `guvenli_alan()` / `guvenli_bosluklar()` (çentik, kamera deliği, yuvarlak köşe, hareket çubuğu; `DisplayServer.get_display_safe_area`'dan, tasarım pikseli; yatayda iki yana aynı boşluk verilir, telefon ters çevrilince düzen değişmez), `degisince(fonksiyon)` (ekran boyutu / güvenli alan değişince çağrılır), `kenar_payi(SIDE_LEFT, 40.0)` (düzen hesabı için kenar payı: güvenli alan boşluğu daha büyükse o), `guvenliye_it(oge)` / `guvenliye_it_grup([a, b])` (konumu kodla verilmiş düğmeleri güvenli alana iter; grup aralarındaki düzeni korur), `guvenli_nokta()`; bilgisayarda çentik taklidi `deneme_bosluklari = Vector4(sol, üst, sağ, alt)`. `ortak/arayuz_koku.tscn`: güvenli alan boşluklarını kendiliğinden uygulayan tam ekran arayüz kökü (yeni oyunların düğmeleri bunun içine). Ortak geri düğmesi kendini güvenli alana alır. Test: `ortak/testler/ekran_uyumu_testi.gd` (pencereli; menüyü ve bütün oyunları 7 telefon / tablet oranında açıp ekran görüntüsü alır, `centik` seçeneği çentiği taklit eder).
- **Sürükle-bırak** (ortak): `ortak/suruklenebilir.gd` (DraggableItem: yakalanınca büyüyüp parmağın `lift` px üstünde yumuşakça izler, `return_home`, `appear` / `disappear` / `hop` / `wiggle`, `grab_distance`, `can_grab()`; nesne script'i bunu `extends` eder) ve `ortak/surukleme_girdisi.gd` (DragInput düğümü: dokunmayı kendisi okur; tek parmak kilidi, basılı geri düğmesi, geçişte / `enabled=false` iken yok sayma, sistem iptali ve uygulama arka planı; sinyaller `item_grabbed` / `item_moved` / `item_dropped` / `item_canceled` / `tapped` / `touched`, `cancel()`; `drop_tolerance` + `drop_area(rect)`: cömert bırakma alanı). Gölge Eşleştirme, Hayvanları Besle ve Büyükten Küçüğe kullanır; nesnenin nereye gideceğine oyun karar verir.
- `ortak/ipucu_eli.gd` (+ `ortak/gorseller/el.svg`) — ipucu eli (`play(nereden, nereye)`, `stop()`, `set_hand_size`): nesnenin üstüne iner, basar, hedefe kayar. Gölge Eşleştirme ve Büyükten Küçüğe kullanır.
- `ortak/ses_havuzu.gd` — küçük `AudioStreamPlayer` havuzu (`play(ad, pitch)`; boş oynatıcı yoksa en eski ses susar). Oyunun `sesler.gd`'si bunu `extends` edip `_init`'te `streams` / `volumes` verir. `ortak/ses/sentez.py`: seslerin Python sentez yardımcıları (oyunların `sesler/ses_uret.py` betikleri içe aktarır; `save` tepeye, `save_loudness` algılanan yüksekliğe göre eşitler; `voice` / `resonate` formantlı hayvan sesi, `check_all(klasör)` wav denetimi).
- **Ses: autoload `SesYoneticisi`** (`ortak/ses_yoneticisi.gd`): `efekt(ad, db, perde)` (±%5 rastgele perde, aynı ses 45 ms içinde birleşir, en fazla 10 ses), `ezgi(ad)` (kutlama; müziği kısar), `dongu_baslat/dongu_durdur` (çalan döngü için `dongu_perde`, `dongu_seviye`), `muzik(ad, self)` (`muzik_<ad>.ogg`, yumuşak geçiş; sahip sahne çıkınca söner), `muzik_hizi(carpan)` (çalan müziği hafifçe hızlandırır; `muzik()` 1'e döndürür). Ses yolları Master → Muzik, Efekt (`default_bus_layout.tres`). Menüdeki ses düğmesi: hepsi açık → sadece efektler → sessiz (`user://ses_ayari.cfg`; sessizde Master kapanır). Arka planda müzik durur. Sesler `ortak/sesler/` (hepsi CC0; kaynaklar `SESLER.md`, üretim `ses_hazirla.py`). Yeni ses eklerken SESLER.md'ye satır ekle.
- `ortak/gorseller/geri.svg` ortak geri simgesi. `ortak/simge/`: simgenin ön/arka plan SVG'leri ve Android PNG'leri; hepsini (`icon.svg` ve `.playstore/icon_512.png` dahil) `python ortak/simge/simge_uret.py` üretir (trambolinde zıplayan aslan; hayvanlar Araba Yarışı'nın çizimlerinden).
- **Geri düğmesi kuralı**: her oyunun ilk ekranında sol üstte geri düğmesi → `SahneGecis.ana_menuye_don()`. Oyun içindeki geri önce oyunun kendi önceki ekranına (bölüm seçme / başlangıç ekranı), oradan ana menüye.

## Oyunlar

- Her oyunun kendine özel notları kendi klasöründeki `CLAUDE.md` içindedir (`oyunlar/<oyun_adi>/CLAUDE.md`). Bir oyunda çalışmadan önce onu oku; oyuna özel yeni notları oraya yaz, bu dosyaya değil.
- Yeni oyun eklerken klasörüne de bir `CLAUDE.md` koy (oyunun kısa tanımı, önemli dosyalar, ayarların yeri, kayıt dosyası).

## Ekran uyumu

Hedef: oyunun ana alanı her telefonda ve tablette aynı boyutta ve ortada görünür; hiçbir şey kesilmez, siyah şerit olmaz, artan alanı arka plan doldurur. Yeni oyun yazarken ve eski oyunu değiştirirken:

- **Sabit ekran boyutu yazma** (1280, 720 ya da `Vector2(1280, 720)` ile konum / sınır hesaplama). Boyutu `EkranYardimcisi.gorunen_boyut()` (ya da `get_viewport_rect().size`) ile al; doğma / yok olma noktalarını ve hareket sınırlarını bundan hesapla.
- **Oynanış alanı ortada**: oyun için gereken her şey `EkranYardimcisi.tasarim_alani()` içinde (ekranın ortasındaki 1280x720) kalır. Geniş ekranda düzeni kenarlara yayma; ekran ortasına göre yerleştir ya da genişliği tasarım genişliğiyle sınırla.
- **Arka plan ekranı kaplar**: 21:9'da (1680x720) yanlarda, 4:3'te (1280x960) altta ve üstte boşluk kalmamalı. Döşenen şeritleri ekran genişliğince tekrarla, gökyüzü / zemin rengini ekranın sonuna kadar çiz.
- **Arayüz güvenli alanda**: düğmeler ve göstergeler bir `CanvasLayer` içinde, köşelere / kenarlara sabitlenir ve çentiğin altında kalmaz. Yeni oyunda `ortak/arayuz_koku.tscn`'i `CanvasLayer`'ın altına koy, öğeleri onun içine anchor'la. Konumu kodla veriyorsan kenar payını `EkranYardimcisi.kenar_payi(SIDE_LEFT / SIDE_RIGHT / SIDE_BOTTOM, pay)` ile al ya da yerleştirdikten sonra `EkranYardimcisi.guvenliye_it_grup([...])` çağır (yan yana duran öğeleri aynı grupta ver, yoksa üst üste binebilirler; geri düğmesi kendini iter, yanında başka öğe varsa onu da aynı gruba koy).
- Ortalanan düzende iki yana aynı payı ver (`maxf(sol, sağ)`), yoksa düzen ortadan kayar.
- `EkranYardimcisi` fonksiyonları statiktir, her script'te çalışır. (Not: `-s` ile çalışan bir test script'i derlenirken autoload'lar henüz yoktur; testin `preload` ettiği script'lerde `SahneGecis` / `SesYoneticisi` gibi autoload adları derleme hatası verir. Bu yüzden ekran yardımcısı autoload adıyla değil sınıf adıyla çağrılır.)
- Dokunma hedefleri küçük ekranda da büyük kalır (en az ~120 px).
- **Kontrol**: `godot --path . --fixed-fps 60 -s res://ortak/testler/ekran_uyumu_testi.gd -- <klasör>` (16:9, 18:9, 19.5:9, 20:9, 21:9, 4:3, 16:10) ve aynısı sonuna `centik` ekleyerek (güvensiz bölge kırmızı görünür; `centik 2520x1080 ucan_kus` gibi çözünürlük / oyun seçilebilir). Görüntülere bak: taşma, kesilme, boşluk, kırmızı bandın altında düğme var mı. Yeni oyunun iç ekranları için testteki `ADIMLAR`'a adım ekle.

## Görsel kontrol

SVG çizince Godot'ta bir SubViewport'a koyup PNG olarak kaydederek bak; kalitesiz görünenleri düzelt. Oyun ekranını da `--fixed-fps 60` ile çalışan bir SceneTree script'iyle ekran görüntüsü alarak kontrol et.

Otomatik testte dokunma olaylarını `root.push_input(event, true)` ile gönder (ikinci parametre olmadan headless'ta koordinatlar pencere ölçeğiyle bozulur). Animasyonlu ekranları, animasyon bitince (ör. ölçek ~1 olunca) çek; ilk karede her şey ölçek 0'dadır. Testlerin yazdığı `user://` kayıtlarını sonunda sil.

## Kurallar

- **Godot 4 ve GDScript** kullan. Godot 3 sözdizimi kullanma
  (ör. `yield` yerine `await`, `connect("x", self, "f")` yerine `x.connect(f)`,
  `export var` yerine `@export var`, `onready var` yerine `@onready var`,
  `KinematicBody2D` yerine `CharacterBody2D`, `update()` yerine `queue_redraw()`).
- **Her oyun kendi klasöründe** olsun: `res://oyunlar/oyun_adi/`
  (sahneler, scriptler ve varsa varlıklar o klasörde). Ortak kod gerekirse `res://ortak/` altına konur.
- **Sade kod**: kısa fonksiyonlar, gereksiz soyutlama yok. Değişken/fonksiyon isimleri **İngilizce** (snake_case), yorumlar **Türkçe** olabilir. Mümkünse tip belirt (`var score: int = 0`).
- **Görsel dosya yoksa şekilleri kodla çiz** (`_draw()`, `draw_circle`, `draw_rect`, `draw_polygon`, `Polygon2D`, `ColorRect`, `StyleBoxFlat` vb.).
- **Çocuk dostu arayüz**:
  - Büyük, renkli, kolay tıklanır/dokunulur öğeler (dokunma alanı en az ~120 px).
  - Yazı çok az; mümkünse simge, renk, şekil ve ses ile anlat.
  - Yanlış cevapta ceza yok; nazik geri bildirim, doğru cevapta görsel kutlama.
  - Hem fare hem dokunmatik ile çalışsın.
- **Her değişiklikten sonra** kullanıcıya Godot'ta nasıl test edeceğini kısaca söyle
  (hangi sahneyi açacak, F6 / F5 ile çalıştırma, neye bakacak).
