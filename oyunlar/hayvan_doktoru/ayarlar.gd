extends RefCounted
# Hayvan Doktoru ayarları (tek yer). Oyunun kendisi ve testler bunu preload eder.

## Aletin etki türü: RUB noktanın üstünde gezdirilir, HOLD noktada tutulur, PLACE noktaya bırakılır (yerine oturur),
## PULL noktadan tutulup dışarı çekilir (diken), FEED ağza götürülür (hasta ağzını açar, yutar)
enum Kind { RUB, HOLD, PLACE, PULL, FEED }

## Hastalar bu hayvanlar arasından seçilir; hayvan verisi hayvanlar/<ad>.tres
const ANIMALS: Array[String] = ["kedi", "kopek", "tavsan", "inek", "maymun", "fare", "ayi", "sincap", "panda", "kus"]

## Aletler. kind: etki türü; tip: görselin uç noktası (genişlik / yüksekliğe oran; gorseller/svg_uret.py
## çalıştırınca yazdırır); width: parmaktaki aletin genişliği (hasta boyuna oran); loop: sürterken çalan döngü sesi
## (sesler.gd LOOPS); time: HOLD / FEED aletinin noktada durması gereken süre (sn); mouth: yaklaşınca hasta ağzını açar
const TOOLS := {
	"stetoskop": {"kind": Kind.HOLD, "tip": Vector2(0.3333, 0.7583), "width": 0.5, "time": 1.6},
	"pamuk": {"kind": Kind.RUB, "tip": Vector2(0.5, 0.55), "width": 0.3, "loop": "sil"},
	"merhem": {"kind": Kind.RUB, "tip": Vector2(0.275, 0.725), "width": 0.38, "loop": "merhem"},
	"bant": {"kind": Kind.PLACE, "tip": Vector2(0.5, 0.5), "width": 0.34},
	"cimbiz": {"kind": Kind.PULL, "tip": Vector2(0.2429, 0.7571), "width": 0.4},
	"termometre": {"kind": Kind.HOLD, "tip": Vector2(0.3136, 0.6864), "width": 0.42, "time": 1.6},
	"surup": {"kind": Kind.FEED, "tip": Vector2(0.3393, 0.6607), "width": 0.4, "time": 0.5, "mouth": true},
	"buz": {"kind": Kind.HOLD, "tip": Vector2(0.5, 0.6), "width": 0.34, "time": 1.4},
	"mendil": {"kind": Kind.RUB, "tip": Vector2(0.5, 0.55), "width": 0.3, "loop": "sil"},
	"dis_fircasi": {"kind": Kind.RUB, "tip": Vector2(0.32, 0.68), "width": 0.42, "loop": "fircala", "mouth": true},
	"krem": {"kind": Kind.RUB, "tip": Vector2(0.2493, 0.7507), "width": 0.38, "loop": "merhem"},
	"pudra": {"kind": Kind.RUB, "tip": Vector2(0.5, 0.6), "width": 0.3, "loop": "sil"},
	"kulak_cubugu": {"kind": Kind.RUB, "tip": Vector2(0.23, 0.77), "width": 0.38, "loop": "sil"},
	"damla": {"kind": Kind.HOLD, "tip": Vector2(0.5, 0.9364), "width": 0.22, "time": 1.0},
	"sargi": {"kind": Kind.PLACE, "tip": Vector2(0.45, 0.6), "width": 0.36},
}

## Her ziyaret bununla başlar: göğse basılı tut (kalp atışı), sonra rahatsızlığın simgesi düşünce balonunda çıkar
const EXAM_TOOL := "stetoskop"
const EXAM_REGION := "gogus"

## Noktaların yerleri (hasta.gd region_points hesaplar): gövdede gogus, bacak, pati, deri (gövde ve kafada rastgele,
## yüzün dışında); kafada alin, agiz, disler (ağız; gagası olan hayvana gelmez), burun, yanak, kulak (kulağı olmayana
## gelmez), goz
const REGIONS: Array[String] = ["gogus", "bacak", "pati", "deri", "alin", "agiz", "disler", "burun", "yanak", "kulak", "goz"]
## Noktanın görünüşü (tedavi_noktasi.gd look)
const LOOKS: Array[String] = ["dinle", "agiz", "siyrik", "diken", "ates", "nezle", "dis", "sislik", "benek", "kulak",
	"burkulma", "goz"]

## Rahatsızlıklar. icon: düşünce balonundaki simge (gorseller/<icon>.svg); order: aletler sırayla (rafta bu sırayla
## durur; bir aleti bekleyen nokta kalmayınca sıradaki parlar); spots: noktalar. Her nokta: look (görünüş), region
## (yer), steps (bu noktanın aletleri, order içindeki sırayla), count (kaç tane, varsayılan 1), thorns (diken sayısı).
const AILMENTS := {
	"siyrik": {"icon": "simge_siyrik", "order": ["pamuk", "merhem", "bant"], "spots": [
		{"look": "siyrik", "region": "bacak", "steps": ["pamuk", "merhem", "bant"]}]},
	"diken": {"icon": "diken", "order": ["cimbiz", "merhem", "bant"], "spots": [
		{"look": "diken", "region": "pati", "steps": ["cimbiz", "merhem", "bant"], "thorns": 3}]},
	"ates": {"icon": "termometre", "order": ["termometre", "surup", "buz"], "spots": [
		{"look": "ates", "region": "alin", "steps": ["termometre", "buz"]},
		{"look": "agiz", "region": "agiz", "steps": ["surup"]}]},
	"nezle": {"icon": "mendil", "order": ["mendil", "surup"], "spots": [
		{"look": "nezle", "region": "burun", "steps": ["mendil"]},
		{"look": "agiz", "region": "agiz", "steps": ["surup"]}]},
	"dis": {"icon": "simge_dis", "order": ["dis_fircasi", "buz"], "spots": [
		{"look": "dis", "region": "disler", "steps": ["dis_fircasi"]},
		{"look": "sislik", "region": "yanak", "steps": ["buz"]}]},
	"kasinti": {"icon": "simge_kasinti", "order": ["krem", "pudra"], "spots": [
		{"look": "benek", "region": "deri", "steps": ["krem", "pudra"], "count": 4}]},
	"kulak": {"icon": "simge_kulak", "order": ["kulak_cubugu", "damla"], "spots": [
		{"look": "kulak", "region": "kulak", "steps": ["kulak_cubugu", "damla"]}]},
	"burkulma": {"icon": "sargi", "order": ["buz", "sargi"], "spots": [
		{"look": "burkulma", "region": "pati", "steps": ["buz", "sargi"]}]},
	"goz": {"icon": "simge_goz", "order": ["damla", "mendil"], "spots": [
		{"look": "goz", "region": "goz", "steps": ["damla", "mendil"]}]},
}
## Bütün rahatsızlıklar (testler bu sırayla dener)
const AILMENT_ORDER: Array[String] = ["siyrik", "diken", "ates", "nezle", "dis", "kasinti", "kulak", "burkulma", "goz"]

## Günler (bölümler): her gün bekleme odasına DAY_PATIENTS hasta gelir; çocuk sırayı kendisi seçer. ailments: o günün
## rahatsızlıkları; thorns: dikendeki diken sayısı; rash: kaşıntıdaki benek sayısı. Yeni rahatsızlıklar yavaş yavaş
## açılır, son günlerde noktalar çoğalır.
const DAY_PATIENTS := 3
const DAYS: Array[Dictionary] = [
	{"ailments": ["siyrik", "ates", "nezle"], "thorns": 1, "rash": 3},
	{"ailments": ["diken", "siyrik", "nezle"], "thorns": 1, "rash": 3},
	{"ailments": ["dis", "ates", "diken"], "thorns": 2, "rash": 3},
	{"ailments": ["kasinti", "kulak", "siyrik"], "thorns": 2, "rash": 3},
	{"ailments": ["burkulma", "goz", "dis"], "thorns": 2, "rash": 4},
	{"ailments": ["goz", "kasinti", "ates"], "thorns": 2, "rash": 4},
	{"ailments": ["nezle", "kulak", "burkulma"], "thorns": 3, "rash": 4},
	{"ailments": ["diken", "dis", "goz"], "thorns": 3, "rash": 5},
	{"ailments": ["kasinti", "burkulma", "kulak"], "thorns": 3, "rash": 6},
	{"ailments": ["ates", "goz", "diken"], "thorns": 3, "rash": 6},
]
## Sonsuz klinik (oyun bitince): her gün rastgele, birbirinden farklı rahatsızlıklar
const ENDLESS_THORNS := 3
const ENDLESS_RASH := 5

## Tedavi noktasının yarıçapı (hastanın 256'lık tuvalinde)
const SPOT_RADIUS := 24.0
## Alet noktanın bu kadar dışından da sayılır (yarıçapın katı; cömert)
const HIT_RADIUS := 1.9
## RUB: bir noktayı bitirmek için aletin noktanın üstünde alması gereken yol (yarıçapın katı)
const RUB_PATH := 3.4
## PLACE: alet hedefin üstünde bu kadar durursa parmak kalkmadan da yerine oturur (sn)
const PLACE_HOLD := 0.35
## PULL: diken bu kadar dışarı çekilince çıkar (yarıçapın katı, tuval biriminde)
const PULL_DISTANCE := 2.2
## FEED: kaşık ağza bu kadar yaklaşınca hasta ağzını açar (yarıçapın katı)
const FEED_OPEN := 4.0
## Nezle: hasta bu aralıkla hapşırır (sn, mendil sürülene kadar)
const SNEEZE_GAP := Vector2(3.0, 5.0)

## Hiç dokunulmazsa sırası gelen alet kıpırdar, noktalar parlar (sn)
const HINT_DELAY := 6.0
## Stetoskoptan sonra düşünce balonunun ekranda kaldığı süre (sn)
const BUBBLE_TIME := 1.8
## İyileşme kutlaması (sonra hasta gider, bekleme odasına dönülür)
const CELEBRATION_TIME := 2.2
## Gün sonu kutlaması (sonra yeni günün hastaları gelir)
const DAY_END_TIME := 2.6
## Son günden sonraki büyük kutlama
const FINALE_TIME := 5.0


## Yerleşim (oyun ve tablo testi aynı hesabı kullanır). screen: görünen alan, area: tasarım alanı (ortadaki 1280x720),
## right_pad: sağ kenar payı (güvenli alan), top: geri düğmesinin alt kenarı. Masa ve hasta tasarım alanında, rafın
## soluna kaydırılmış; bank tasarım alanının ortasında; alet rafı sağ kenarda, geri düğmesinin altında.
static func layout(screen: Vector2, area: Rect2, right_pad: float, top: float) -> Dictionary:
	var patient := clampf(area.size.y * 0.58, 260.0, 430.0)
	var table_width := patient * 1.05
	var table_top := Vector2(area.get_center().x - 70.0, area.end.y - table_width * 0.42 - 10.0)
	var waiting := clampf(area.size.y * 0.38, 200.0, 290.0)
	var spacing := waiting * 1.1
	var bench_top := Vector2(area.get_center().x, table_top.y)
	var seats: Array[Vector2] = []
	for k in DAY_PATIENTS:
		seats.append(bench_top + Vector2((k - (DAY_PATIENTS - 1) / 2.0) * spacing, 0.0))
	var r := clampf(patient * 0.16, 54.0, 70.0)
	var tray_top := top + 20.0
	return {
		"patient": patient, "table_width": table_width, "table_top": table_top,
		"waiting": waiting, "bench_top": bench_top, "bench_width": spacing * DAY_PATIENTS, "seats": seats,
		"tray_center": Vector2(screen.x - right_pad - r - 14.0, (tray_top + area.end.y) / 2.0), "tray_radius": r,
		"tray_height": area.end.y - tray_top - 20.0,
	}


## Gün tanımı; sonsuz klinikte rastgele (birbirinden farklı rahatsızlıklar)
static func day_info(index: int, endless: bool) -> Dictionary:
	if not endless:
		return DAYS[clampi(index, 0, DAYS.size() - 1)]
	var names := AILMENT_ORDER.duplicate()
	names.shuffle()
	return {"ailments": names.slice(0, DAY_PATIENTS), "thorns": ENDLESS_THORNS, "rash": ENDLESS_RASH}


static func animal(id: String) -> ClinicAnimalData:
	return load("res://oyunlar/hayvan_doktoru/hayvanlar/%s.tres" % id) as ClinicAnimalData


static func tool_texture(id: String) -> Texture2D:
	return load("res://oyunlar/hayvan_doktoru/gorseller/%s.svg" % id) as Texture2D


## Ziyaretin aletleri sırayla: önce stetoskop, sonra rahatsızlığın aletleri
static func visit_steps(ailment: String) -> Array[String]:
	var steps: Array[String] = [EXAM_TOOL]
	for id: String in AILMENTS[ailment]["order"]:
		steps.append(id)
	return steps


## Bu hayvanda bu yer var mı (kuşun kulağı ve dişi yok)
static func region_available(data: ClinicAnimalData, region: String) -> bool:
	match region:
		"kulak":
			return data.ear != Vector2.ZERO
		"disler":
			return not data.beak
	return true


## Bu rahatsızlık gelebilecek hayvanlar
static func animals_for(ailment: String) -> Array[String]:
	var out: Array[String] = []
	for id in ANIMALS:
		var data := animal(id)
		var ok := true
		for spot: Dictionary in AILMENTS[ailment]["spots"]:
			ok = ok and region_available(data, spot["region"])
		if ok:
			out.append(id)
	return out


## Tablodaki hataları bulur (oyun açılırken ve testlerde çalışır)
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for id in ANIMALS:
		if not ResourceLoader.exists("res://oyunlar/hayvan_doktoru/hayvanlar/%s.tres" % id):
			out.append("hayvan verisi yok: %s" % id)
	for id: String in TOOLS:
		if not ResourceLoader.exists("res://oyunlar/hayvan_doktoru/gorseller/%s.svg" % id):
			out.append("alet görseli yok: %s" % id)
		var info: Dictionary = TOOLS[id]
		if info["kind"] in [Kind.HOLD, Kind.FEED] and not info.has("time"):
			out.append("%s: basılı tutma süresi (time) yok" % id)
	if not TOOLS.has(EXAM_TOOL):
		out.append("muayene aleti TOOLS'ta yok: %s" % EXAM_TOOL)
	for name: String in AILMENTS:
		out.append_array(_ailment_problems(name))
	for name in AILMENT_ORDER:
		if not AILMENTS.has(name):
			out.append("AILMENT_ORDER: tanımsız rahatsızlık: %s" % name)
	var seen := {}
	for i in DAYS.size():
		var names: Array = DAYS[i]["ailments"]
		if names.size() != DAY_PATIENTS:
			out.append("%d. gün: %d hasta olmalı" % [i + 1, DAY_PATIENTS])
		for name: String in names:
			seen[name] = true
			if not AILMENTS.has(name):
				out.append("%d. gün: tanımsız rahatsızlık: %s" % [i + 1, name])
			elif names.count(name) > 1:
				out.append("%d. gün: %s iki kez var" % [i + 1, name])
	for name in AILMENT_ORDER:
		if not seen.has(name):
			out.append("hiçbir günde yok: %s" % name)
	return out


static func _ailment_problems(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var ailment: Dictionary = AILMENTS[name]
	var order: Array = ailment["order"]
	if order.size() > 3:
		out.append("%s: rafta en fazla 4 yuva var (stetoskop + 3 alet)" % name)
	if not ResourceLoader.exists("res://oyunlar/hayvan_doktoru/gorseller/%s.svg" % ailment["icon"]):
		out.append("%s: simge yok: %s" % [name, ailment["icon"]])
	var used := {}
	for spot: Dictionary in ailment["spots"]:
		if not spot["look"] in LOOKS:
			out.append("%s: bilinmeyen görünüş: %s" % [name, spot["look"]])
		if not spot["region"] in REGIONS:
			out.append("%s: bilinmeyen yer: %s" % [name, spot["region"]])
		var last := -1
		for id: String in spot["steps"]:
			used[id] = true
			var index := order.find(id)
			if index < 0:
				out.append("%s: nokta aleti order'da yok: %s" % [name, id])
			elif index <= last:
				out.append("%s: noktanın aletleri order sırasında değil" % name)
			last = index
	for id: String in order:
		if not TOOLS.has(id):
			out.append("%s: alet TOOLS'ta yok: %s" % [name, id])
		if not used.has(id):
			out.append("%s: hiçbir nokta %s beklemiyor" % [name, id])
	if animals_for(name).size() < 2:
		out.append("%s: en az iki hayvana gelebilmeli" % name)
	return out
