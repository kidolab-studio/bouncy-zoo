extends RefCounted
# Noktaları Birleştir ayarları (tek yer). Oyunun kendisi, çizim ve testler bunu preload eder.
# (Autoload adı kullanma: testler bu dosyayı -s ile çalışan script'ten yükler.)

## Resimler: gorseller/resimler/<ad>.svg (nesne) + <ad>_sahne.svg (arka plandaki sahne); noktaları
## gorseller/resimler/noktalar.json'da (hepsini gorseller/svg_uret.py üretir, elle düzenleme)
##   sound  bitince çalan ses (sesler/<ses>.wav)
##   color  oyunun arka plan rengi (resmin havasına uygun pastel)
##   anim   ortaya çıkan nesnenin hareketi: "zipla" (zıplar), "salla" (sallanır), "parla" (zıplar, döner, ışıldar),
##          "uc" (titreyip havalanır, geri iner), "suzul" (burnunu kaldırıp ileri süzülür, geri gelir)
const PICTURES := {
	"ev": {"sound": "ev", "color": Color("d5ecff"), "anim": "zipla"},
	"yelkenli": {"sound": "yelkenli", "color": Color("cdeefa"), "anim": "salla"},
	"tac": {"sound": "tac", "color": Color("e9dcff"), "anim": "parla"},
	"yildiz": {"sound": "yildiz", "color": Color("dcd8fa"), "anim": "parla"},
	"roket": {"sound": "roket", "color": Color("d8d4f5"), "anim": "uc"},
	"semsiye": {"sound": "semsiye", "color": Color("d3ecff"), "anim": "salla"},
	"fener": {"sound": "fener", "color": Color("ffe1d8"), "anim": "parla"},
	"ucak": {"sound": "ucak", "color": Color("d5e9ff"), "anim": "suzul"},
	"lokomotif": {"sound": "lokomotif", "color": Color("dff2cc"), "anim": "zipla"},
}
const DATA_PATH := "res://oyunlar/nokta_birlestir/gorseller/resimler/noktalar.json"

## Bölümler (sıra = bölüm sırası). Nokta sayısı resmin kendisinden gelir (noktalar.json).
const LEVELS: Array[Dictionary] = [
	{"picture": "ev"},
	{"picture": "yelkenli"},
	{"picture": "tac"},
	{"picture": "yildiz"},
	{"picture": "roket"},
	{"picture": "semsiye"},
	{"picture": "fener"},
	{"picture": "ucak"},
	{"picture": "lokomotif"},
]

## Yerleşim (tasarım alanında, 1280x720)
const TOP := 124.0            # üstte geri düğmesi ve yıldızlar için boşluk
const BOTTOM := 22.0
const PAGE_MAX_HEIGHT := 600.0
const PAGE_BORDER := 12.0     # resmin çevresindeki beyaz kâğıt payı
const SHADOW := Vector2(0.0, 10.0)

## Noktalar (ekran pikseli)
const DOT_RADIUS := 25.0
const NEXT_GROW := 1.25       # sıradaki nokta bu kadar büyük (üstüne nabız)
const TOUCH_RADIUS := 62.0    # noktanın dokunma yarıçapı (iki nokta yakınsa aralarının yarısı)
const MIN_DOT_GAP := 110.0    # iki nokta arası ekranda en az bu kadar (problems() denetler)
const NUMBER_SIZE := 30
const SCENE_ALPHA := 0.4      # çizim bitene kadar sahne soluk görünür

## Süreler (saniye)
const SEGMENT_TIME := 0.16    # dokunarak bağlanan noktada çizginin uzaması
const APPEAR_TIME := 0.5      # bölüm başında noktalar sırayla belirir (toplam)
const REVEAL_TIME := 0.6      # renkli resmin belirmesi
const ANIM_TIME := 1.6        # nesnenin hareketi
const CELEBRATION_TIME := 1.2
const FINALE_TIME := 3.2

static var _data: Dictionary = {}


static func level_count() -> int:
	return LEVELS.size()


static func picture_of(index: int) -> String:
	return LEVELS[index]["picture"]


static func object_path(picture: String) -> String:
	return "res://oyunlar/nokta_birlestir/gorseller/resimler/%s.svg" % picture


static func scene_path(picture: String) -> String:
	return "res://oyunlar/nokta_birlestir/gorseller/resimler/%s_sahne.svg" % picture


## noktalar.json (bir kez okunur): {"size": [w, h], "line": hat kalınlığı, "pictures": {ad: {dots, curves, pivot}}}
static func data() -> Dictionary:
	# load(): JSON kaynak olarak yüklenir, dışa aktarılan pakete de girer (FileAccess ile okunursa girmez)
	if _data.is_empty() and ResourceLoader.exists(DATA_PATH):
		var json: JSON = load(DATA_PATH)
		if json and json.data is Dictionary:
			_data = json.data
	return _data


static func picture_size() -> Vector2:
	var size: Array = data().get("size", [1200, 900])
	return Vector2(size[0], size[1])


static func line_width() -> float:
	return float(data().get("line", 14))


## Resmin noktaları (resim koordinatında) ve parça eğrileri (null: düz; Vector2: kontrol noktası)
static func dots_of(picture: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in data()["pictures"][picture]["dots"]:
		out.append(Vector2(p[0], p[1]))
	return out


static func curves_of(picture: String) -> Array:
	var out := []
	for c in data()["pictures"][picture]["curves"]:
		out.append(Vector2(c[0], c[1]) if c is Array else null)
	return out


static func pivot_of(picture: String) -> Vector2:
	var p: Array = data()["pictures"][picture]["pivot"]
	return Vector2(p[0], p[1])


## Resmin ekrandaki yeri (beyaz kâğıt payı hariç). screen: görünen alan, area: tasarım alanı
static func picture_rect(screen: Vector2, area: Rect2) -> Rect2:
	var top := area.position.y + TOP
	var avail := area.end.y - BOTTOM - top
	var page_height := minf(PAGE_MAX_HEIGHT, avail)
	var size := picture_size()
	var height := page_height - PAGE_BORDER * 2.0
	var width := height * size.x / size.y
	return Rect2(screen.x / 2.0 - width / 2.0, top + (avail - page_height) / 2.0 + PAGE_BORDER, width, height)


## Bir resimde iki nokta arasındaki en kısa uzaklık (resim pikseli)
static func min_gap(picture: String) -> float:
	var dots := dots_of(picture)
	var best := INF
	for i in dots.size():
		for j in range(i + 1, dots.size()):
			best = minf(best, dots[i].distance_to(dots[j]))
	return best


## Tablodaki hataları verir (oyun açılışta, testler her çalışmada denetler)
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if LEVELS.is_empty():
		out.append("hiç bölüm yok")
	if not data().has("pictures"):
		out.append("noktalar.json okunamadı (%s)" % DATA_PATH)
		return out
	var scale := picture_rect(Vector2(1280, 720), Rect2(0, 0, 1280, 720)).size.x / picture_size().x
	var counts := []
	for i in LEVELS.size():
		var picture := picture_of(i)
		var name := "Bölüm %d (%s)" % [i + 1, picture]
		if not PICTURES.has(picture):
			out.append("%s: resim PICTURES'ta yok" % name)
			continue
		if not data()["pictures"].has(picture):
			out.append("%s: noktalar.json'da yok" % name)
			continue
		for path in [object_path(picture), scene_path(picture)]:
			if not ResourceLoader.exists(path):
				out.append("%s: dosya yok (%s)" % [name, path])
		var dots := dots_of(picture)
		if dots.size() < 3:
			out.append("%s: en az 3 nokta olmalı" % name)
		if curves_of(picture).size() != dots.size():
			out.append("%s: eğri sayısı nokta sayısıyla aynı olmalı" % name)
		if min_gap(picture) * scale < MIN_DOT_GAP:
			out.append("%s: iki nokta çok yakın (%.0f px < %.0f)" % [name, min_gap(picture) * scale, MIN_DOT_GAP])
		counts.append(dots.size())
	for k in range(1, counts.size()):
		if counts[k] < counts[k - 1]:
			out.append("Bölüm %d: nokta sayısı öncekinden az (bölümler kolaydan zora)" % (k + 1))
	for picture in PICTURES:
		var sound: String = PICTURES[picture]["sound"]
		if not ResourceLoader.exists("res://oyunlar/nokta_birlestir/sesler/%s.wav" % sound):
			out.append("%s: ses dosyası yok (%s)" % [picture, sound])
		if not PICTURES[picture]["anim"] in ["zipla", "salla", "parla", "uc", "suzul"]:
			out.append("%s: hareket türü bilinmiyor (%s)" % [picture, PICTURES[picture]["anim"]])
	return out
