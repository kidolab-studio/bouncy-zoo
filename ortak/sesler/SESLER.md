# Ortak sesler

Bütün indirilen sesler **CC0** (kamu malı): isim vermek gerekmez, ticari kullanım serbest. CC-BY veya lisansı belirsiz ses yok.
"sentez" paketindeki sesler indirilmedi, `ses_hazirla.py` içinde kodla üretildi (bize ait).
Tren sesleri (`tren_*.ogg`) indirilen gerçek buhar kayıtlarından `ses_hazirla.py` içindeki fonksiyonlarla kuruldu.
Dosyalar `ses_hazirla.py` ile hazırlandı: kırpma, gerekirse perde değiştirme ve tiz yumuşatma (alçak geçiren süzgeç),
seviye eşitleme, .ogg Vorbis. Efektler mono, müzikler stereo ve döngülü (`.import` içinde `loop=true`).
Çalma: `ortak/ses_yoneticisi.gd` (autoload `SesYoneticisi`).

Yeniden üretmek için (proje kökünden): `pip install soundfile numpy scipy`, sonra `python ortak/sesler/ses_hazirla.py`.
Paketler proje dışındaki bir önbellek klasörüne indirilir; projeye sadece kullanılan sesler girer.

## Kaynak paketler

| Kısa ad | Paket | Yazar | Sayfa | Lisans |
|---|---|---|---|---|
| interface | Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0 |
| impact | Impact Sounds | Kenney | https://kenney.nl/assets/impact-sounds | CC0 |
| jingles | Music Jingles | Kenney | https://kenney.nl/assets/music-jingles | CC0 |
| digital | Digital Audio | Kenney | https://kenney.nl/assets/digital-audio | CC0 |
| casino | Casino Audio | Kenney | https://kenney.nl/assets/casino-audio | CC0 |
| rpg | RPG Audio | Kenney | https://kenney.nl/assets/rpg-audio | CC0 |
| boing | Boing | aeva | https://opengameart.org/content/boing | CC0 |
| zil | Pleasing Bell Sound Effect | spring-spring | https://opengameart.org/content/pleasing-bell-sound-effect | CC0 |
| yaratik | 80 CC0 creature SFX | rubberduck | https://opengameart.org/content/80-cc0-creature-sfx | CC0 |
| donguler | 30 CC0 SFX loops | rubberduck | https://opengameart.org/content/30-cc0-sfx-loops | CC0 |
| m_ev | Children's Game Music 3 - Home | heartade | https://opengameart.org/content/childrens-game-music-3-home | CC0 |
| m_kus | Flowerbed Fields (loop) | zane-little-music | https://opengameart.org/content/flowerbed-fields-loop | CC0 |
| m_dondurma | Feel Good Island (loop) | antumdeluge | https://opengameart.org/content/feel-good-island-loop | CC0 * |
| m_yol | Cozy Puzzle Jingle / Result | mintodog | https://opengameart.org/content/cozy-puzzle-jingle-result | CC0 |
| m_hafiza | Heavenly Loop | isaiah658 | https://opengameart.org/content/heavenly-loop | CC0 |
| m_meyve | Children's March Theme | cleytonkauffman | https://opengameart.org/content/childrens-march-theme | CC0 |
| buhar_duduk | Steam whistle | bart | https://opengameart.org/content/steam-whistle | CC0 |
| buhar | Steam release sounds | bart | https://opengameart.org/content/steam-release-sounds | CC0 |
| sentez | (bu projede üretildi) | Bouncy Zoo | `ses_hazirla.py` içindeki sentez fonksiyonları | bize ait |

\* Feel Good Island sayfada iki lisanslı (CC0 ve OGA-BY 3.0); CC0 seçeneğiyle kullanıldı. Sayfaya göre orijinal
parça Brandon Morris'in; zorunlu olmasa da istenirse emeği anılabilir.

Denenip kullanılmayan: "dings" (OpenGameArt, CC-BY-SA 4.0), isim verme ve aynı lisansla paylaşma istediği için alınmadı.

## Dosyalar

| Dosya | Paket | Orijinal dosya | İşlem | Nerede |
|---|---|---|---|---|
| dugme_tik.ogg | interface | drop_003.ogg | | düğmeler, menü kartı ve sekmeler |
| geri.ogg | interface | drop_003.ogg | perde 0.75 (daha pes) | geri düğmeleri |
| kutlama.ogg | jingles | jingles_STEEL02.ogg | | bölüm / oyun sonu kutlaması |
| konfeti.ogg | interface | drop_004.ogg + glass_002.ogg | ikisi karıştırıldı, tiz yumuşatma | konfeti |
| yumusak_hayir.ogg | interface | question_002.ogg | tiz yumuşatma | yanlış seçim (nazik) |
| ding.ogg | interface | glass_005.ogg | | Uçan Kuş puan |
| ding_yumusak.ogg | interface | glass_001.ogg | | Hafıza eşleşme |
| pop.ogg | interface | drop_004.ogg | | Meyve Topla meyve, Yol Yap parça alma |
| plop.ogg | interface | drop_002.ogg | | Dondurmacı top ekleme |
| tink.ogg | interface | glass_006.ogg | | Dondurmacı kase |
| basari.ogg | interface | confirmation_001.ogg | | tekrar oyna |
| basari_parlak.ogg | interface | confirmation_003.ogg | | Meyve Topla art arda (kombo) |
| tamamlandi.ogg | interface | confirmation_004.ogg | | sipariş / bölüm tamam |
| yukselis.ogg | interface | maximize_009.ogg | | başlama |
| yildiz_kazanma.ogg | jingles | jingles_PIZZI02.ogg | | yıldız kazanma, Uçan Kuş oyun sonu |
| hediye_acilis.ogg | jingles | jingles_PIZZI10.ogg | | Yol Yap hediye kutusu |
| bolum_gecisi.ogg | jingles | jingles_STEEL10.ogg | | Meyve Topla bölüm başı |
| kanat.ogg | rpg | cloth2.ogg | ilk 0.28 sn, tiz yumuşatma | Uçan Kuş kanat çırpma |
| boing.ogg | boing | boing.flac | ilk 0.75 sn, yumuşak bitiş | Uçan Kuş çarpma |
| boing_kisa.ogg | boing | boing.flac | perde 1.3, ilk 0.42 sn | Yol Yap yay, Meyve Topla seken meyve |
| yumusak_dusus.ogg | digital | highDown.ogg | tiz yumuşatma | can kaybı |
| kapi_zili.ogg | zil | pleasing-bell.wav | | Dondurmacı müşteri geldi |
| tahta_tok.ogg | impact | impactWood_light_001.ogg | | Dondurmacı külah, Yol Yap parça oturdu |
| hayvan_sevinc.ogg | yaratik | cute_03.ogg | tiz yumuşatma | Dondurmacı hayvan sevinci |
| hisirti.ogg | rpg | cloth1.ogg | ilk 0.45 sn, tiz yumuşatma | Yol Yap parça tepsiye döner |
| bilye_yuvarlanma.ogg | donguler | rolling.ogg | tiz yumuşatma, döngülü | Yol Yap bilye yuvarlanırken |
| kart_cevir.ogg | casino | card-place-1.ogg | tiz yumuşatma | Hafıza kart çevirme |
| kart_dagit.ogg | casino | card-slide-1.ogg | tiz yumuşatma | Hafıza kart dağıtma |
| bonk.ogg | interface | bong_001.ogg | | Meyve Topla kötü nesne |
| sersem.ogg | yaratik | ooh.ogg | tiz yumuşatma | Meyve Topla kirpi sersemledi |
| guc_al.ogg | digital | powerUp2.ogg | tiz yumuşatma | Meyve Topla güçlendirme alındı |
| guc_bitti.ogg | digital | phaserDown1.ogg | tiz yumuşatma | Meyve Topla güçlendirme bitti |
| vuus.ogg | sentez | `vuus()` | süzülmüş gürültü (yükselip alçalan rüzgar), tiz yumuşatma | Uçan Kuş hızlanma |
| tren_duduk.ogg | buhar_duduk | steam_whistle.wav | `tren_duduk()`: kaydın sabit bölümünden iki ses birlikte (Sol5 + Si5), kısa + uzun üfleme ("tü-tüüt"), tiz yumuşatma | Tren Rayı: kalkış, istasyona varış, giriş ekranında trene dokunma |
| tren_cufcuf.ogg | buhar | steam hisses - Marker #1.wav, #2, #3, #4 (steam_hisses.zip) | `tren_cufcuf()`: dört kısa puf kalınlaştırılıp 0,3 sn arayla dizildi (ilk vuruş vurgulu), kuyruklar başa sarıldı; dikişsiz döngü | Tren Rayı: tren hareket ederken (perde ve seviye hıza bağlı) |
| tren_fren.ogg | buhar | steam hisses - Marker #3.wav (steam_hisses.zip) | `tren_fren()`: biraz yavaşlatıldı, yumuşak başlangıç, tiz yumuşatma ("pşşş") | Tren Rayı: yolcu duraklarında, eksik yolda ve istasyonda duruş |
| muzik_menu.ogg | m_ev | children_soundtrack_3.wav | 8 cümle (70 BPM, 12 vuruşluk cümleler) alındı, kapanış atıldı; döngü 2. cümleye döner (`.import` `loop_offset=10.285714`), sondaki 80 ms dönüş öncesiyle karıştırıldı; seviye -24 dB (diğer müziklerden biraz kısık) | ana menü |
| muzik_ucan_kus.ogg | m_kus | flowerbed_fields.ogg | tiz yumuşatma (5 kHz) | Uçan Kuş |
| muzik_dondurmaci.ogg | m_dondurma | feel_good_island_loop_0.ogg | | Dondurmacı |
| muzik_yol_yap.ogg | m_yol | Cozy Puzzle Clear (Loop)_BPM85.ogg | tiz yumuşatma | Yol Yap |
| muzik_hafiza.ogg | m_hafiza | Heavenly Loop_0.ogg | | Hafıza |
| muzik_meyve_topla.ogg | m_meyve | Children's March Theme.ogg | tiz yumuşatma | Meyve Topla |

Toplam boyut yaklaşık 5.4 MB.
