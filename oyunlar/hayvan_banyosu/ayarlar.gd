extends RefCounted
# Hayvan Banyosu ayarları (tek yer). Oyunun kendisi ve testler bunu preload eder.

## Bölümler: her bölüm bir hayvan (sıra = bölüm sırası). Hayvan verisi hayvanlar/<ad>.tres
const ANIMALS: Array[String] = ["kedi", "kopek", "tavsan", "inek", "maymun", "fare", "ayi", "sincap", "panda", "kus"]
## Bölüm başına çamur lekesi sayısı (ANIMALS ile aynı uzunlukta)
const SPOTS: Array[int] = [3, 3, 3, 4, 4, 4, 5, 5, 6, 6]

## Banyo adımları sırayla: sünger (çamur → köpük), duş (köpük → ıslak), havlu (ıslak → temiz)
const STEPS: Array[String] = ["sunger", "dus", "havlu"]

## Lekenin yarıçapı (hayvanın 256'lık tuvalinde)
const SPOT_RADIUS := 25.0
## Bir lekeyi bir adımda bitirmek için parmağın lekenin üstünde alması gereken yol (leke yarıçapının katı)
const RUB_PATH := 3.4
## Parmak lekenin bu kadar dışından da sayılır (leke yarıçapının katı; cömert)
const HIT_RADIUS := 1.8
## Lekeler arası en az uzaklık (leke yarıçapının katı)
const SPOT_GAP := 1.9
## Lekeler suyun altında kalmasın: tuvalde bu yükseklikten aşağısı (gövdenin alt kısmı) kullanılmaz
const WATER_LINE := 212.0

## Hiç dokunulmazsa kalan lekeler bu kadar saniyede bir parlar
const HINT_DELAY := 6.0
## Bölüm sonu kutlaması (sonra kendiliğinden sonraki hayvan)
const CELEBRATION_TIME := 2.4
## Son bölümden sonraki büyük kutlama
const FINALE_TIME := 5.0


static func level_count() -> int:
	return ANIMALS.size()


static func animal(index: int) -> BathAnimalData:
	return load("res://oyunlar/hayvan_banyosu/hayvanlar/%s.tres" % ANIMALS[index]) as BathAnimalData
