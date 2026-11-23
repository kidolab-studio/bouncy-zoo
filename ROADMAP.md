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
- İlk premium oyunlar hangileri, sahipleri kim?
- Premium oyunlar menüde ayrı bir sekmede mi olsun, yoksa kendi kategorilerinde kilitli kart olarak mı?
- Ücretsiz deneme olsun mu (ör. her premium oyunun ilk bölümü açık)?
