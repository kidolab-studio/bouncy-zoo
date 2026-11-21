extends RefCounted
# Yapboz ayarları (tek yer). Oyunun kendisi, kesici, yerleşim ve testler bunu preload eder.
# (Autoload adı kullanma: testler bu dosyayı -s ile çalışan script'ten yükler.)

## Resimler: gorseller/resimler/<ad>.svg (1200x900, svg_uret.py çizer)
##   sound  bitince çalan ses (sesler/<ses>.wav)
##   color  arka planın rengi (resmin havasına uygun pastel)
const PICTURES := {
	"ciftlik": {"sound": "inek", "color": Color("ffe9c7")},
	"tren": {"sound": "tren", "color": Color("d5e7ff")},
	"meyve": {"sound": "meyve", "color": Color("ffdfe4")},
	"deniz": {"sound": "deniz", "color": Color("cdeefa")},
	"uzay": {"sound": "uzay", "color": Color("ddd5f7")},
	"orman": {"sound": "orman", "color": Color("dff2cc")},
	"balonlar": {"sound": "balon", "color": Color("ffe0ec")},
	"kasaba": {"sound": "kasaba", "color": Color("e3dbff")},
}
const PICTURE_SIZE := Vector2(1200.0, 900.0)

## Bölümler (sıra = bölüm sırası):
##   picture  PICTURES'ta bir ad
##   cols     sütun sayısı (2-4), rows: satır sayısı (2-3)
##   ghost    tahtadaki soluk resmin görünürlüğü (0-1; bölüm zorlaştıkça azalır)
## Şimdilik 8 bölüm; resimler geldikçe 12'ye çıkacak (her parça sayısından üçer).
const LEVELS: Array[Dictionary] = [
	{"picture": "ciftlik", "cols": 2, "rows": 2, "ghost": 0.45},
	{"picture": "tren", "cols": 2, "rows": 2, "ghost": 0.42},
	{"picture": "meyve", "cols": 2, "rows": 2, "ghost": 0.4},
	{"picture": "deniz", "cols": 3, "rows": 2, "ghost": 0.38},
	{"picture": "uzay", "cols": 3, "rows": 2, "ghost": 0.36},
	{"picture": "orman", "cols": 3, "rows": 2, "ghost": 0.34},
	{"picture": "balonlar", "cols": 3, "rows": 3, "ghost": 0.3},
	{"picture": "kasaba", "cols": 4, "rows": 3, "ghost": 0.24},
]

## Çıkıntı (birimi: hücrenin kısa kenarı). Komşu çıkıntılar çakışmasın diye toplamı küçük tutuldu.
const NECK := 0.085          # boynun yarı genişliği
const HEAD := 0.12           # yuvarlak başın yarıçapı
const NECK_HEIGHT := 0.06    # boynun boyu (baş bunun üstünde)
const FILLET := 0.06         # kenardan boyna yumuşak geçiş
const KNOB_SHIFT := 0.05     # çıkıntının kenar ortasından en fazla kayması (kenar boyuna göre)
const KNOB_SIZE_JITTER := 0.08

## Yerleşim (tasarım alanında, 1280x720)
const TOP := 132.0           # üstte geri düğmesi ve yıldızlar için boşluk
const BOTTOM := 26.0
const SIDE := 40.0           # ekran kenarından en az pay (güvenli alan daha büyükse o)
const GAP := 26.0            # tahtayla tepsiler arası
const BOARD_MAX_HEIGHT := 560.0
const BOARD_MIN_HEIGHT := 400.0
## Tepsideki parçanın kısa kenarı en az bu kadar (değilse tahta küçülür, tepsilere yer açılır)
const MIN_TRAY_PIECE := 90.0
## Parça tepsideki yuvasının bu kadarını kaplar; tepside en fazla tahtadaki boyunun bu katı
const TRAY_FILL := 0.84
const MAX_TRAY_RATIO := 0.75
## Tepsideki parçalar yuvalarında bu kadar (parça boyunun oranı) rastgele kayar: dağınık dursun.
## Yatayda az: tahtaya bakan çıkıntı tahtaya binmesin
const TRAY_JITTER := Vector2(0.02, 0.08)
## Çıkıntı hücrenin kenarından en fazla bu kadar taşar (hücrenin kısa kenarına göre; NECK_HEIGHT + baş)
const KNOB_REACH := 0.3
const MIN_TOUCH := 120.0

## Sürükleme
const GRAB_PADDING := 1.1     # yakalama alanı hücrenin bu katı
const DRAG_GROW := 1.04       # tutulan parça tahtadaki boyunun bu katı
const DRAG_LIFT := 0.22       # parça parmağın bu kadar (hücre boyu oranı) üstünde durur
const SNAP := 0.45            # parça yerine bu kadar (hücrenin kısa kenarı oranı) yakın bırakılırsa oturur

## Süreler (saniye)
const LOOK_TIME := 1.2        # bölüm başında resmin tamamı görünür
const SCATTER_TIME := 0.55
const SCATTER_STAGGER := 0.07
const SEAT_TIME := 0.2
const BACK_TIME := 0.4
const CELEBRATION_TIME := 1.4
const FINALE_TIME := 3.2


static func level_count() -> int:
	return LEVELS.size()


static func picture_path(picture: String) -> String:
	return "res://oyunlar/yapboz/gorseller/resimler/%s.svg" % picture


## Tablodaki hataları verir (oyun açılışta, testler her çalışmada denetler)
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if LEVELS.is_empty():
		out.append("hiç bölüm yok")
	for i in LEVELS.size():
		var level: Dictionary = LEVELS[i]
		var name := "Bölüm %d" % (i + 1)
		if not PICTURES.has(level["picture"]):
			out.append("%s: resim tabloda yok (%s)" % [name, level["picture"]])
		elif not ResourceLoader.exists(picture_path(level["picture"])):
			out.append("%s: resim dosyası yok (%s)" % [name, picture_path(level["picture"])])
		if int(level["cols"]) < 2 or int(level["cols"]) > 4 or int(level["rows"]) < 2 or int(level["rows"]) > 3:
			out.append("%s: ızgara uygun değil (%dx%d)" % [name, level["cols"], level["rows"]])
		if float(level["ghost"]) < 0.0 or float(level["ghost"]) > 1.0:
			out.append("%s: soluk resim değeri 0-1 arasında olmalı" % name)
	for picture in PICTURES:
		if not ResourceLoader.exists("res://oyunlar/yapboz/sesler/%s.wav" % PICTURES[picture]["sound"]):
			out.append("%s: ses dosyası yok (%s)" % [picture, PICTURES[picture]["sound"]])
	return out
