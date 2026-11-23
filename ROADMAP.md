# Yol Haritası

## Premium oyunlar (tek seferlik ödeme)

**Durum:** Fikir aşamasında, kod yazılmadı. Bouncy Zoo şu an Google Play'de ücretsiz; reklam, internet ve uygulama içi satın alma yok.

**Amaç:** Gelir için mevcut oyunlardan daha detaylı premium oyunlar eklemek. Ebeveyn bir kez ödeme yapınca bütün premium oyunlar açılır.

---

### 1. Model

- Play Console'da tek bir **kalıcı (non-consumable) ürün** olur, ör. `premium_unlock` (çalışma adı "Bouncy Zoo Plus"). Bir kez satın alınır; bütün premium oyunları ve sonradan eklenecek premium oyunları açar.
- Abonelik yok, reklam yok.
- **Şu an ücretsiz olan oyunların hepsi ücretsiz kalır.** Hiçbir ücretsiz oyun sonradan kilitlenmez, yoksa kötü yorum gelir. Premium paket yalnızca yeni, daha uzun ve daha zengin oyunlardan oluşur.
- Play Console'da **Aile Kitaplığı** açılır: bir ebeveyn satın alınca ailedeki diğer hesaplarda da açılır. Ebeveynler için güçlü bir artı.
- Fiyat önerisi: Play'in bölgesel fiyatlandırmasıyla **2,99–4,99 $** aralığı. Türkiye fiyatı ayrıca belirlenir.
- Gerçekçi beklenti: çocuk uygulamalarında ücretsiz kullanıcıların ödemeye geçme oranı genelde **%1–3**. Premium paket mağazada açıkça "daha fazlası" gibi görünmeli.

### 2. Aile politikası ve ebeveyn kapısı (en kritik bölüm)

Uygulama Google Play Aileler politikasına tabidir. Satın almalar ebeveyne yönelik olmalı, çocuk yönlendirilmemeli.

- **Sağlam bir ebeveyn kapısı.** Satın alma ekranı bunun arkasında olur. Bugünkü 3 sn basılı tutma kapısı (`ana_menu/ana_menu.gd`, `EBEVEYN_BEKLEME`) satın alma için yetmez, çünkü çocuklar bunu kolayca yapar. Önerilen kapı yazıyla verilen bir işlem ("yetmiş iki eksi on beş kaç?") ya da rastgele sırayla basılan düğmeler. Soru her açılışta değişir.
- **Çocuğa satın almaya yönlendirme yok:**
  - açılır pencere, "Şimdi al!" düğmesi, geri sayım ya da indirim baskısı yok;
  - karakterler satın almayı istemez ya da teşvik etmez;
  - oyun ortasında hatırlatma yok.
- **Kilitli kart sakin görünür.** Menüde küçük bir kilit rozeti olur (`ana_menu/oyun_karti.gd`'deki rozet düzeniyle). Karta dokununca doğrudan ebeveyn kapısı açılır. Kapının arkasında ebeveyne yönelik kısa bilgi, "Satın al" ve "Satın alımları geri yükle" düğmeleri olur.

### 3. Teknik altyapı (Godot 4.7, Android)

**Faturalama eklentisi**
- Resmi Godot Google Play Billing eklentisi kullanılır (Godot 4 Android eklentisi v2 biçimi). `export_presets.cfg`'de `gradle_build/use_gradle_build=true` zaten açık.

**Yeni ortak dosya: `ortak/premium.gd`** (autoload `Premium`)
- API: `acik_mi() -> bool`, `satin_al()`, `geri_yukle()`, `degisti` sinyali.
- Her açılışta Play'den mevcut satın almaları sorgular. Böylece cihaz değişikliği, yeniden kurulum ve Aile Kitaplığı çalışır.
- Satın alma **3 gün içinde onaylanmalı (acknowledge)**, yoksa Google parayı otomatik iade eder.
- Sonuç `user://premium.cfg`'ye yazılır; çevrimdışıyken bu önbellekten okunur. Play "satın alma yok / iade edildi" derse premium kapanır.
- Bilgisayarda ve testlerde eklenti yoktur. Debug derlemede sahte mod olur (ör. `Premium.deneme_acik = true`), premium oyunlar geliştirme sırasında açılabilsin.

**Menü ve oyunlar**
- `ana_menu/oyun_listesi.gd` `OYUNLAR` kaydına isteğe bağlı `"premium": true` alanı eklenir.
- Kilitli karta dokununca oyun açılmaz, ebeveyn kapısı açılır.
- Premium oyun sahnesi başka bir yoldan açılırsa da sürüm derlemesinde `Premium.acik_mi()` ile kontrol edilir.

**Denetim ve kayıtlar**
- `lisans_denetle.py` (madde 9, `AG_VE_IZIN`) faturalama eklentisi için bilinçli ve dar bir istisna alır, yalnızca `ortak/premium.gd` için. Başka ağ kullanımı yine hata verir.
- Eklentinin eklediği Android izinleri (`com.android.vending.BILLING`) kontrol edilir. INTERNET izni gerekip gerekmediği derlenmiş manifest'ten doğrulanır.
- Lisanslar ekranındaki "İlerlemeyi sıfırla" premium kaydını **silmez**.

**Takım**
- `ortak/premium.gd`, menü değişiklikleri ve ebeveyn kapısı ortak dosyalardır. İki geliştirici de haberdar olmalı; değişiklikler küçük PR'lara bölünür.
- Her premium oyunun sahibi `CLAUDE.md`'deki sahiplik listesine yazılır.

### 4. Metin, gizlilik ve mağaza güncellemeleri

Bugün birçok yerde "uygulama içi satın alma yok" yazıyor. Hepsi premium'un çıktığı **aynı sürümde** güncellenmeli:

- [ ] `ana_menu/lisans_metinleri.gd`: uygulama içindeki gizlilik özeti ("uygulama içi satın alma yoktur") ve `ortak/ceviri/ceviriler.csv`'deki çevirisi.
- [ ] `.playstore/listing.md`: kısa ve uzun açıklamalar (TR "satın alımsız", EN "no in-app purchases"), "Ücretli / ücretsiz" satırı, form cevapları ("Dijital ürün satın alma: Hayır") ve Veri güvenliği gerekçesi.
- [ ] Gizlilik politikası (`kidolab-studio/legal`): satın almanın Google Play üzerinden yapıldığı ve uygulamanın ödeme bilgisi görmediği yazılır.
- [ ] Play Console Veri güvenliği formu: Google Play Faturalandırma'nın işlediği veriler için Google'ın güncel rehberine göre yeniden doldurulur.
- [ ] Mağaza sayfasında "Uygulama içi satın alma içerir" etiketi çıkacak; açıklama buna göre yazılır.
- "Reklamsız" ve "internetsiz" vurgusu korunabilir, çünkü satın alma Play Store uygulaması üzerinden yapılır. Yine de ifade derlenmiş uygulamadaki izinlere bakılarak doğrulanır.

### 5. Play Console hazırlığı (kod dışı, şimdiden başlatılabilir)

- [ ] Ödeme profili (merchant hesabı) ve vergi bilgileri. Onay uzun sürebilir, bu yüzden erken başlanmalı.
- [ ] Uygulama içi ürün: `premium_unlock`, fiyat, bölgesel fiyatlar, Aile Kitaplığı.
- [ ] Lisans test kullanıcıları (gerçek para çekmeden satın alma testi).

### 6. Aşamalar

1. **Hazırlık:** merchant hesabı, ürün tanımı, fiyat kararı, ilk premium oyunların tasarımı.
2. **Altyapı:** `ortak/premium.gd`, ebeveyn kapısı, kilitli kart, geri yükleme, sahte mod. Testler:
   - `ana_menu/testler/menu_testi.gd` kilitli kartın oyunu açmadığını kontrol eder;
   - yeni `ortak/testler/premium_testi.gd`: kapı, kilit, sahte satın alma, geri yükleme.
3. **İlk premium oyunlar:** paket satın almaya değsin diye en az 2–3 detaylı oyunla çıkılır.
4. **Metin, gizlilik, mağaza:** 4. bölümdeki her madde.
5. **Kapalı test:** lisans test kullanıcılarıyla satın alma, iade, geri yükleme, çevrimdışı açılış ve cihaz değiştirme senaryoları.
6. **Yayın:** CHANGELOG'a TR + EN madde, yeni mağaza ekran görüntüleri (`ortak/testler/magaza_ekranlari.gd`), kademeli yayın (ör. önce %20).

### 7. Açık sorular

- Paketin adı ve fiyatı ne olacak?
- İlk premium oyunlar hangileri, sahipleri kim? (İlki karar verildi: Hayvan Doktoru, bkz. 8. bölüm.)
- Premium oyunlar menüde ayrı bir sekmede mi olsun, yoksa kendi kategorilerinde kilitli kart olarak mı?

**Karar verilenler**
- Ücretsiz deneme **yok**: premium kart tamamen kilitli. Ebeveyn oyunu mağaza görsellerinden ve kapının arkasındaki bilgiden tanır.

### 8. İlk premium oyun: Hayvan Doktoru (`oyunlar/hayvan_doktoru/`)

**Durum:** Planlandı, kod yazılmadı. Sahibi: **emirsalihgmrk**. Menü adı "Hayvan Doktoru" / "Animal Doctor". Bu plan yalnızca oyunun kendisini kapsar; faturalama ve ebeveyn kapısı (3. bölüm) ayrı iştir.

**Neden premium:** Mevcut oyunlarda tek etkileşim ve 10–12 bölüm var. Bu oyunda **5 etkileşim türü**, **9 rahatsızlık**, bekleme odasından **hasta seçme**, **günlük akış** (10 gün × 3 hasta), **çıkartma albümü** ve bitince **sonsuz klinik** modu var. Skor, süre, can ve ceza yok. Yazı da yok. İğne ve aşı yok, çocuk korkmasın.

**Akış (bir gün = 3 hasta)**
1. **Bekleme odası:** 3 hasta hayvan oturur, belirtileri görünür (kırmızı burun, hapşırık, dizde yara, patide diken, şiş yanak, kaşınan benekler, topallama...). Çocuk birine dokunur, hayvan muayene masasına zıplar. Köşede albüm düğmesi olur.
2. **Muayene:** Her ziyaret stetoskopla başlar (göğse basılı tut, kalp atışı duyulur). Sonra başın üstünde rahatsızlığın simgesiyle bir düşünce balonu çıkar.
3. **Tedavi:** Sağdaki rafta yalnızca bu rahatsızlığın 2–3 aleti durur. Sırası gelen alet parlar (Hayvan Banyosu'ndaki gibi), sırası gelmeyen yalnızca kıpırdar.
4. **İyileşme:** Yüz hastadan mutluya döner. Hayvan zıplar, sesini çıkarır, kalpler uçar. Albüme bir çıkartma gider. Hasta el sallayarak kapıdan çıkar.
5. 3 hasta bitince **gün sonu** kutlaması olur (10 yıldızdan biri dolar). 10. günden sonra `OyunBitti` gelir, "sonsuz" düğmesiyle rastgele hastalar başlar.

**Etkileşim türleri**

| Tür | Nasıl | Aletler |
|---|---|---|
| Sürt | aleti noktanın üstünde gezdir | pamuk, merhem, krem, pudra, diş fırçası, mendil, kulak çubuğu |
| Basılı tut | aleti noktada tut; dolum aletin kendisinde görünür (cıva yükselir, buz erir) | stetoskop, termometre, buz kesesi, damla |
| Yerleştir | aleti hedefe bırak, yerine oturur | yara bandı, sargı |
| Çek | noktaya dokun, dışarı doğru çek | cımbız (diken) |
| Ağıza ver | kaşığı ağza götür; hayvan ağzını açar, yutar, yüzünü buruşturur, sonra güler | şurup |

**Rahatsızlıklar** (stetoskoptan sonraki adımlar)
1. Sıyrık: pamuk → merhem → yara bandı
2. Diken: cımbız (1–3 diken) → merhem → yara bandı
3. Ateş: termometre → şurup → alına buz
4. Nezle: mendil (burun; arada hapşırır) → şurup
5. Diş ağrısı (şiş yanak): diş fırçası → yanağa buz
6. Kaşıntı (kırmızı benekler): krem → pudra
7. Kulak ağrısı: kulak çubuğu → damla
8. Burkulma (topallama): buz → sargı
9. Gözde toz: göz damlası → mendil

İlk günlerde 1–3. rahatsızlıklar ve az nokta olur. Sonra yenileri açılır. Son günlerde 3 adım ve çok nokta olur (3 diken, 6 benek). Hayvanlar Hayvanları Besle ve Hayvan Banyosu'ndaki 10 hayvandır. Bir günde aynı hayvan iki kez gelmez.

**Çıkartma albümü:** Her hayvan × rahatsızlık çifti için bir çıkartma olur (hayvanın yüzü + rozet, kodla birleştirilir). Dolu çıkartmaya dokununca hayvan sesini çıkarır. Bu, oyunu uzun süre oynatan bir toplama hedefidir.

**Teknik:** Hayvan Banyosu'nun yapısından kopyalanıp uyarlanır, Banyo'ya dokunulmaz. Uyarlanacaklar: alet ve raf (`alet.gd`, `alet_rafi.gd`), hayvan ve yüz (`hayvan.gd`, `hayvan_yuzu.gd`; yüze hasta ve buruşuk ifadeler eklenir), leke yerine genelleşmiş tedavi noktası (`tedavi_noktasi.gd`: sürt / tut / yerleştir / çek). Bütün ayarlar `ayarlar.gd`'de olur (`ANIMALS`, `TOOLS`, `AILMENTS`, `DAYS`, `problems()`). Hayvan çizimleri Besle'nin `svg_uret.py`'sinden gelir. Kayıt dosyası `user://hayvan_doktoru.cfg` (`[ilerleme] gun`, `hasta`; `[album]`).

**Uygulama sırası** (küçük PR'lar, dallar `emir/hayvan-doktoru-*`)
1. İskelet + tek hasta: klinik, hasta, stetoskop ve Sıyrık uçtan uca. F6 ile açılır, menüde yok. Kök `CLAUDE.md` sahiplik listesine eklenir.
2. Basılı tut, çek ve ağıza ver türleri + 9 rahatsızlık.
3. Bekleme odası, günler, kayıt, `OyunBitti`, sonsuz mod.
4. Çıkartma albümü.
5. Cila ve testler: `IpucuEli`, sesler, `tablo_testi.gd` (headless), `oynanis_testi.gd` (pencereli). Ortak testlere kayıt: `oyun_bitti_testi.gd`, `ekran_uyumu_testi.gd`, `ipucu_eli_testi.gd`.
6. **Menü kartı** (ortak dosya, ayrı küçük PR, mem1nce'ye haber verilir): `oyun_listesi.gd` kaydına `"premium": true` eklenir. Premium altyapısı gelene kadar menü bu kartı **yalnızca debug derlemede** gösterir (`OS.is_debug_build()`). Böylece oyun sürüm derlemesine yanlışlıkla ücretsiz girmez, ama menü ve ekran testleri çalışır. CHANGELOG maddesi premium'un yayınlandığı sürümde yazılır.
