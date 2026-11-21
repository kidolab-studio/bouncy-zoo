extends RefCounted
# Sıradaki Ne? ayarları (tek yer). Oyunun kendisi, bölüm üretici ve testler bunu preload eder.

## Bölümler (sıra = bölüm sırası):
##   theme    tema (THEMES'te bir ad)
##   pattern  örüntü birimi; harfler simgeleri gösterir (AB, AAB, ABB, ABC, AABB)
##   kind     değişen özellik: renk / sekil / tur (temanın POOLS'unda olmalı)
##   gap      boşluk yeri: son (dizinin sonu) / orta (ilk birimden sonra, sondan önce) / karisik (sonda + ortada)
##   gaps     boşluk sayısı
##   choices  alttaki seçenek sayısı
##   length   (isteğe bağlı) dizinin uzunluğu; yoksa birimin iki katı + 2 (en fazla MAX_LENGTH)
const LEVELS: Array[Dictionary] = [
	{"theme": "kolye", "pattern": "AB", "kind": "renk", "gap": "son", "gaps": 1, "choices": 2},
	{"theme": "bayrak", "pattern": "AB", "kind": "renk", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "bahce", "pattern": "AB", "kind": "tur", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "tirtil", "pattern": "AAB", "kind": "renk", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "gecit", "pattern": "ABB", "kind": "tur", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "kolye", "pattern": "ABC", "kind": "renk", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "bayrak", "pattern": "AB", "kind": "sekil", "gap": "orta", "gaps": 1, "choices": 3},
	{"theme": "bahce", "pattern": "AAB", "kind": "renk", "gap": "orta", "gaps": 1, "choices": 3},
	{"theme": "tirtil", "pattern": "ABC", "kind": "renk", "gap": "orta", "gaps": 1, "choices": 3},
	{"theme": "gecit", "pattern": "AABB", "kind": "tur", "gap": "son", "gaps": 1, "choices": 3},
	{"theme": "kolye", "pattern": "AB", "kind": "sekil", "gap": "son", "gaps": 2, "choices": 4, "length": 8},
	{"theme": "bayrak", "pattern": "ABB", "kind": "renk", "gap": "karisik", "gaps": 2, "choices": 4},
	{"theme": "bahce", "pattern": "ABC", "kind": "tur", "gap": "karisik", "gaps": 2, "choices": 4},
	{"theme": "tirtil", "pattern": "AABB", "kind": "renk", "gap": "karisik", "gaps": 3, "choices": 5},
	{"theme": "gecit", "pattern": "ABC", "kind": "tur", "gap": "karisik", "gaps": 3, "choices": 5},
]
const MAX_LENGTH := 8

## Renkler (parça dosya adlarında). Açıklıkları birbirinden ayrışır; boncuk, bayrak ve tırtılda her rengin
## kendi iç işareti de var (renk körü çocuklar için; gorseller/svg_uret.py MARKS).
const COLORS: Array[String] = ["kirmizi", "mavi", "sari", "yesil", "mor"]
const BEAD_SHAPES: Array[String] = ["yuvarlak", "kup", "yildiz", "kalp"]
const FLAG_SHAPES: Array[String] = ["ucgen", "kare", "kirlangic", "dalga"]
const FLOWERS: Array[String] = ["lale_kirmizi", "papatya", "aycicegi", "menekse"]
## Geçidin hayvanları: renkleri birbirinden kolay ayrılanlar (köpek ve maymun ayıya çok benzediği için yok)
const ANIMALS: Array[String] = ["kedi", "tavsan", "inek", "fare", "ayi", "panda"]

## Temalar:
##   piece  parçanın yuvaya göre boyu (parça SVG'leri 160'lık tuvalde, hayvanlar 256'lık; görünen boy buna göre)
##   sag    dizinin ortası uçlarından bu kadar aşağıda (ip sarkması, tasarım pikseli)
##   wave   dizinin dalgası (tırtıl)
const THEMES := {
	"kolye": {"piece": 0.86, "sag": 46.0, "wave": 0.0},
	"bayrak": {"piece": 0.92, "sag": 34.0, "wave": 0.0},
	"bahce": {"piece": 1.0, "sag": 0.0, "wave": 0.0},
	"tirtil": {"piece": 1.12, "sag": 0.0, "wave": 10.0},
	"gecit": {"piece": 1.28, "sag": 0.0, "wave": 0.0},
}

## Yuva (bir parçanın yeri) en fazla bu kadar geniş; dar ekranda küçülür ama dokunma alanı MIN_TOUCH'tan küçük olmaz
const MAX_CELL := 140.0
const MIN_TOUCH := 120.0
## Dizinin ve seçenek tepsisinin ortası (tasarım alanında, 720'lik yükseklikte)
const ROW_Y := 300.0
const TRAY_Y := 600.0
## Arka planlarda zemin çizgisi (tasarım alanında)
const FLOOR_Y := 520.0
## Seçenekler arası en fazla uzaklık
const TRAY_SPACING := 210.0
## Kenarlarda bırakılan pay (geri düğmesi ve parmak için)
const SIDE := 80.0

## Sürükleme: yakalama alanı görselin bu kadar katı, bırakma toleransı (yuvanın kısa kenarına oran)
const GRAB_PADDING := 1.3
const DROP_TOLERANCE := 0.45
const DRAG_SCALE := 1.12
const DRAG_LIFT := 0.45          # parmağın üstünde, yuva boyuna oran

## Aynı bölümde bu kadar yanlış bırakmadan sonra dizi örüntüyü yeniden çalar (sonra her bu kadar yanlışta bir)
const REPLAY_AFTER := 2
## Bölüm sonu kutlaması (temanın gösterisinden sonra) ve son bölümden sonraki büyük kutlama
const CELEBRATION_TIME := 1.2
const FINALE_TIME := 5.0


static func level_count() -> int:
	return LEVELS.size()


## Temanın bir özelliğe göre seçilebilecek parçaları (dosya adları). Renk / şekil seçiminde öbür özellik
## bütün parçalarda aynıdır (rng ile seçilir).
static func pool(theme: String, kind: String, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	match theme:
		"kolye", "bayrak":
			var prefix := "boncuk" if theme == "kolye" else "bayrak"
			var shapes := BEAD_SHAPES if theme == "kolye" else FLAG_SHAPES
			if kind == "renk":
				var shape := shapes[rng.randi_range(0, shapes.size() - 1)]
				for c in COLORS:
					out.append("%s_%s_%s" % [prefix, shape, c])
			else:
				var color := COLORS[rng.randi_range(0, COLORS.size() - 1)]
				for s in shapes:
					out.append("%s_%s_%s" % [prefix, s, color])
		"bahce":
			if kind == "renk":
				for c in COLORS:
					out.append("cicek_lale_%s" % c)
			else:
				for f in FLOWERS:
					out.append("cicek_%s" % f)
		"tirtil":
			for c in COLORS:
				out.append("tirtil_%s" % c)
		"gecit":
			for a in ANIMALS:
				out.append("hayvan_%s" % a)
	return out


## Her bölümün kurallara uyup uymadığı (oyun açılırken ve testte)
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var rng := RandomNumberGenerator.new()
	for i in LEVELS.size():
		var level: Dictionary = LEVELS[i]
		var name := "Bölüm %d" % (i + 1)
		if not THEMES.has(level["theme"]):
			out.append("%s: tema yok (%s)" % [name, level["theme"]])
			continue
		var p: String = level["pattern"]
		var alphabet := {}
		for ch in p:
			alphabet[ch] = true
		var n_pool := pool(level["theme"], level["kind"], rng).size()
		if n_pool < alphabet.size() + 1:
			out.append("%s: %s/%s için yeterli parça yok" % [name, level["theme"], level["kind"]])
		var length := length_of(level)
		if length < p.length() + int(level["gaps"]) or length > MAX_LENGTH:
			out.append("%s: dizi uzunluğu uygun değil (%d)" % [name, length])
		if int(level["choices"]) < int(level["gaps"]) + 1 or int(level["choices"]) > 5:
			out.append("%s: seçenek sayısı uygun değil" % name)
		if int(level["gaps"]) > length - p.length():
			out.append("%s: boşluklar ilk birime taşıyor" % name)
	return out


static func length_of(level: Dictionary) -> int:
	var p: String = level["pattern"]
	return int(level.get("length", mini(MAX_LENGTH, p.length() * 2 + 2)))
