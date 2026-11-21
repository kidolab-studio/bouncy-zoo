# Hayvan Banyosu

3-6 yaş, **yatay** ekran, hiç yazı yok, kategori Yaratıcı. Küvette çamura bulanmış bir hayvan durur. Çocuk ekrana dokununca parmağı o anki adımın aletine dönüşür (bir şey tutup sürüklemek gerekmez): **süngerle** çamuru köpürtür, **duşla** köpüğü durular, **havluyla** kurular. Üç adım bitince hayvan silkinir (damlalar saçılır), sesini çıkarır, kalpler uçar; sonraki hayvan gelir. 10 hayvan (bölüm), sonra ortak final ekranı (`OyunBitti`). Skor, süre, can yok; boşluğa sürtmek sadece kabarcık patlatır. Sahibi: emirsalihgmrk.

- **Ayarların yeri (tek yer): `ayarlar.gd`**: `ANIMALS` (bölüm sırası), `SPOTS` (bölüm başına leke: 3-3-3-4-4-4-5-5-6-6), `STEPS`, leke yarıçapı, sürtme yolu (`RUB_PATH`, yarıçapın katı), cömert dokunma alanı (`HIT_RADIUS`), lekeler arası aralık, `WATER_LINE` (tuvalde bunun altına leke konmaz), ipucu ve kutlama süreleri. Duşun dururken akışı (`SHOWER_FLOW`) ve parmak sıçrama sınırı `hayvan_banyosu.gd` başında.
- **Yapı**:
  - `hayvan_banyosu.gd/.tscn` (BathGame): yerleşim, dokunma (tek parmak alet olur, ikinci parmak yok sayılır, geri düğmesine düşen dokunuş düğmeye gider), sürtme kararı (`_apply`), adım ve bölüm akışı, döngü sesi, ipucu, kayıt, OyunBitti.
  - `hayvan.gd` (BathAnimal): Hayvanları Besle'deki `hayvan.gd`'nin sade kopyası (gövde, boyundan dönen kafa, kodla çizilen yüz). `add_spots(n)`: lekeleri gövde/kafa görsellerinin opak piksellerinden rastgele seçer (yüzün ve suyun altının dışında, birbirinden uzak; yer bulunamazsa kurallar gevşer). Kafadaki leke kafayla, gövdedeki gövdeyle hareket eder. Tepkiler: `tickle` (sürtülünce ^ ^ gözler), `squint` (duşta), `shake_dry`, `dance`, `appear` (küvete atlar), `leave`.
  - `hayvan_yuzu.gd`: Besle'deki yüzün kopyası (veri tipi `BathAnimalData`).
  - `leke.gd` (Spot): durum MUD → FOAM → WET → CLEAN; her durumda `amount` 1→0 (`rub`), geçişler yumuşak (çamur solarken köpük büyür, köpük sönerken damlalar belirir). `needs(step)`, `hit`, `pulse` (ipucu).
  - `alet.gd` (BathTool): parmağı izleyen sünger / duş / havlu; duşta suyu `_draw` çizer (başlık parmağın üstünde, su parmağa akar).
  - `alet_rozeti.gd`: sağ altta o anki aletin büyük simgesi ve üç adım noktası.
  - `kabarciklar.gd`: sudan yükselen süs kabarcıkları; alet değince patlar.
  - `arka_plan.gd`: fayans duvar, zemin, paspas ve küvetin arka parçası; `place_front` ön parçayı (sahnede `TubFront`, hayvanın önünde) aynı yere koyar.
  - `efektler.gd` (Besle'den uyarlama; + `drops`, `bubbles`), `yildizlar.gd` (Besle'den kopya), `sesler.gd` (ortak ses havuzu + döngü sesi `set_loop`, hayvan sesi `set_voice`).
  - `hayvan_verisi.gd` (`BathAnimalData`) + `hayvanlar/<ad>.tres`: görseller, ses, yüz yerleri (Besle'deki değerlerle aynı).
- **Görseller** `gorseller/svg_uret.py` (Besle'nin `svg_uret.py`'sini içe aktarır; o dosyaya dokunmaz): hayvan gövde/kafa çizimleri Besle'deki fonksiyonlarla aynı üretilir; aletler, küvet (`kuvet_arka` / `kuvet_on`, suyun merkezi ikisinde de (320, 64)), çamur (3 tür), köpük, damla, kabarcık, `kart_kopek.svg` (menü kartı ve final karakteri). `yildiz`, `isilti`, `kalp` Besle'den kopya. İçe aktarma: SVG 2x + mipmap (koddaki ölçekler doku genişliğinden hesaplanır).
- **Sesler** `sesler/ses_uret.py` (ortak `sentez.py`; pop, kikir, bolum_sonu, final Besle'nin betiğinden): döngüler `sunger`, `dus`, `havlu`; kısa sesler `kopur`, `temiz`, `adim`, `silkin`, `kabarcik`. Hayvan sesleri Besle'den kopyalanır (kedi, köpek, inek CC0 kayıt; diğerleri sentez yer tutucu). WAV `compress/mode=0`.
- **Yeni hayvan**: Besle'nin `svg_uret.py`'sinde çizimi varsa `python gorseller/svg_uret.py` yeter, sesini `ses_uret.py` `VOICES`'a ekle, `hayvanlar/<ad>.tres` yaz, `ayarlar.gd` `ANIMALS` + `SPOTS`'a ekle.
- **Kayıt**: `user://hayvan_banyosu.cfg` (`[ilerleme] bolum`, 0'dan). Ana menü rozeti bunu okur.
- **Test**: `testler/oynanis_testi.gd` (pencereli, `--fixed-fps 60 --resolution 1280x720 -- <klasör>`; menüden açar, 10 bölümü sürterek oynar: leke sayısı ve yeri, boş sürtme, ikinci parmak, geçişte sürtme, adım sırası ve alet değişimi, dururken akan duş, kayıt, final ekranı ve baştan oyna, çift dokunuşlu geri). Kayıtları yedekleyip geri yazar.
