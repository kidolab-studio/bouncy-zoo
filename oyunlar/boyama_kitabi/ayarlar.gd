extends RefCounted
# Boyama Kitabı ayarları (tek yer). Hem oyun hem sayfa derleyicisi (sayfalar/derle.gd) buradan okur.

## Tuvalin uzun kenarı (piksel). Değiştirince sayfaları yeniden derle: bölge haritası, çizgiler ve
## fırça katmanı bu boyutta olur. 2048: tablette net, bellekte ~50 MB.
const CANVAS_LONG_SIDE := 2048
## Sayfa seçimindeki küçük resmin genişliği (piksel)
const PAGE_THUMB_WIDTH := 320
## Galerideki eser küçük resminin genişliği (piksel)
const ART_THUMB_WIDTH := 400
## Galerideki en fazla eser. Galeri bütün küçük resimleri birden yüklediği için sınır var. Dolunca yeni
## resim açılmaz: galeri açılır ve çöp kutuları sallanır; çocuk birini silince yeniden yeni resim yapabilir.
const MAX_ARTWORKS := 60

## Kategoriler (sayfa seçimindeki sırayla). Sayfa SVG'leri sayfalar/kaynak/<id>/ klasöründedir.
const CATEGORIES := [
	{"id": "hayvanlar", "icon": "kat_hayvanlar", "color": Color("ff9a3d")},
	{"id": "araclar", "icon": "kat_araclar", "color": Color("3e8eeb")},
	{"id": "oyuncaklar", "icon": "kat_oyuncaklar", "color": Color("ec4f94")},
	{"id": "doga", "icon": "kat_doga", "color": Color("2fae62")},
	{"id": "sekiller", "icon": "kat_sekiller", "color": Color("8a6cf0")},
]

## Derleyicinin denetimleri: tasarım biriminde (sayfa 1024 genişlikte) en küçük görünür bölge alanı
## (~28 birim çaplı daire) ve bir sayfadaki en fazla bölge sayısı (bölge haritası 8 bit)
const MIN_REGION_AREA := 600.0
const MAX_REGIONS := 250

## 16 renk (paletteki sırayla)
const COLORS := [
	Color("ff4b4b"),  # kırmızı
	Color("ff9a2e"),  # turuncu
	Color("ffd93b"),  # sarı
	Color("8ee04f"),  # açık yeşil
	Color("2e9e4f"),  # koyu yeşil
	Color("5cc8ff"),  # açık mavi
	Color("2f4bb8"),  # lacivert
	Color("9a5cf0"),  # mor
	Color("ff5fae"),  # pembe
	Color("ffc2dc"),  # açık pembe
	Color("9a5a32"),  # kahverengi
	Color("f7d2b0"),  # açık ten
	Color("c98f62"),  # koyu ten
	Color("9a9aa6"),  # gri
	Color("2b2433"),  # siyah
	Color("ffffff"),  # beyaz
]
## Boş sayfanın rengi (kova ile silinen bölge de buna döner)
const PAPER := Color("ffffff")
