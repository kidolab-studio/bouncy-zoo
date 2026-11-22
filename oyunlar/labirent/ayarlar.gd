extends RefCounted
# Labirent ayarları (tek yer). Oyunun kendisi, çizim ve testler bunu preload eder.
# (Autoload adı kullanma: testler bu dosyayı -s ile çalışan script'ten yükler.)

## Hayvanlar: gorseller/hayvanlar/<ad>.svg (+ <ad>_mutlu.svg), sesler/<ad>.wav; yemeği gorseller/yiyecekler/<yemek>.svg
const ANIMALS := {
	"tavsan": "havuc", "sincap": "palamut", "fare": "peynir", "kedi": "balik", "kopek": "kemik",
	"kus": "tohum", "maymun": "muz", "panda": "bambu", "inek": "ot", "ayi": "bal",
}

## Zeminler: tahtanın rengi, duvar (çalı / taş / kar) renkleri, ekranın arka plan rengi
##   floor   tahta zemini     path   hayvanın geçtiği yolun izi
##   wall    duvarın dolgusu   light  duvarın üstündeki parlaklık   back  arka plan
const GROUNDS := {
	"cimen": {"floor": Color("c8eea0"), "path": Color("f4ffe0"), "wall": Color("4fae55"), "light": Color("8fd884"), "back": Color("dff5c8")},
	"orman": {"floor": Color("b9dc95"), "path": Color("eaf7d6"), "wall": Color("2f8a4e"), "light": Color("62b874"), "back": Color("cfe8bd")},
	"bahce": {"floor": Color("ffe4ec"), "path": Color("fffaf2"), "wall": Color("e9799e"), "light": Color("ffb3c9"), "back": Color("ffeef2")},
	"kum": {"floor": Color("f8e3ae"), "path": Color("fffaea"), "wall": Color("c99868"), "light": Color("e8c39b"), "back": Color("d6f0fb")},
	"kar": {"floor": Color("eef6ff"), "path": Color("ffffff"), "wall": Color("8cc7ea"), "light": Color("d4ecfb"), "back": Color("dbeaf8")},
}

## Bölümler (sıra = bölüm sırası). Harita: '#' duvar, '.' yol, 'S' hayvanın başladığı yer, 'Y' yemek, '*' yıldız.
## Hücreler tek sayılı satır / sütunlarda (1, 3, 5...); aralarındaki karakter '#' ise o iki hücre arasında duvar var.
## Çift satır ve sütunların kesiştiği yerler (köşeler) hep '#'. Izgara 4x3'ten 9x5'e büyür, çıkmaz sokaklar artar.
const LEVELS: Array[Dictionary] = [
	{"animal": "tavsan", "ground": "cimen", "map": [
		"#########",
		"#S......#",
		"#######.#",
		"#..*....#",
		"#.#######",
		"#......Y#",
		"#########"]},
	{"animal": "sincap", "ground": "orman", "map": [
		"#########",
		"#S..#...#",
		"###.#.#.#",
		"#.#.#*#.#",
		"#.#.#.#.#",
		"#.....#Y#",
		"#########"]},
	{"animal": "fare", "ground": "bahce", "map": [
		"###########",
		"#S#.......#",
		"#.#.#####.#",
		"#.#.#.....#",
		"#.###.###.#",
		"#....*#..Y#",
		"###########"]},
	{"animal": "kedi", "ground": "kum", "map": [
		"###########",
		"#S#......*#",
		"#.###.###.#",
		"#.....#...#",
		"#######.###",
		"#....*#.#.#",
		"#.#####.#.#",
		"#........Y#",
		"###########"]},
	{"animal": "kopek", "ground": "cimen", "map": [
		"#############",
		"#S..#.......#",
		"###.#.#.###.#",
		"#.#.#.#.#*#.#",
		"#.#.#.#.#.#.#",
		"#.#.#.#*#.#.#",
		"#.#.###.#.#.#",
		"#.......#..Y#",
		"#############"]},
	{"animal": "kus", "ground": "bahce", "map": [
		"#############",
		"#*.........Y#",
		"###########.#",
		"#.......#...#",
		"#.###.#.#.###",
		"#...#*#.#.#.#",
		"###.#.###.#.#",
		"#S..#.......#",
		"#############"]},
	{"animal": "maymun", "ground": "orman", "map": [
		"###############",
		"#S#.........#.#",
		"#.#.###.###.#.#",
		"#.#.#..*#.#.#.#",
		"#.#.#.###.#.#.#",
		"#.#.#.#...#...#",
		"#.###.#.#.###.#",
		"#.....#*#....Y#",
		"###############"]},
	{"animal": "panda", "ground": "orman", "map": [
		"###############",
		"#S....#*#.....#",
		"#####.#.#.###.#",
		"#.#...#.#.#.#.#",
		"#.#.###.#.#.#.#",
		"#.#.#.......#.#",
		"#.#.#.#######.#",
		"#.#.#.#.......#",
		"#.#.###.#####.#",
		"#..*....#....Y#",
		"###############"]},
	{"animal": "inek", "ground": "cimen", "map": [
		"#################",
		"#*#.....#......Y#",
		"#.#.###.#.#.###.#",
		"#.#..*#...#.#.#.#",
		"#.#########.#.#.#",
		"#...........#...#",
		"#############.###",
		"#...........#.#.#",
		"#.#####.#####.#.#",
		"#S....#....*....#",
		"#################"]},
	{"animal": "ayi", "ground": "orman", "map": [
		"#################",
		"#*#*..........#.#",
		"#.#######.###.#.#",
		"#.........#.#...#",
		"###########.###.#",
		"#S..#.........#Y#",
		"#.#.#.#######.#.#",
		"#.#.#..*....#...#",
		"#.#########.#####",
		"#...............#",
		"#################"]},
	{"animal": "tavsan", "ground": "kar", "map": [
		"###################",
		"#S#...........#...#",
		"#.###.#######.#.#.#",
		"#.....#*...*#*#.#.#",
		"#########.###.#.#.#",
		"#.........#...#.#.#",
		"#.#######.#.#####.#",
		"#.......#.#.#.....#",
		"#.#####.###.#.###.#",
		"#.....#.......#..Y#",
		"###################"]},
	{"animal": "kopek", "ground": "kum", "map": [
		"###################",
		"#*............#*.Y#",
		"#############.###.#",
		"#.#.........#.....#",
		"#.#.#.###########.#",
		"#.#.#....*......#.#",
		"#.#.#########.###.#",
		"#...#.......#.....#",
		"#.#####.###.#######",
		"#S......#.........#",
		"###################"]},
]

## Yerleşim (tasarım alanında, 1280x720)
const TOP := 128.0            # üstte geri düğmesi ve yıldızlar için boşluk
const BOTTOM := 24.0
const SIDE := 100.0           # yanlarda (çentikli telefonda da tahta güvenli alanda kalsın)
const MAX_CELL := 170.0       # küçük labirentte hücre en fazla bu kadar (hayvan çok büyümesin)
const BOARD_PAD := 0.18       # tahtanın labirent çevresindeki payı (hücre boyunun oranı)
const WALL_WIDTH := 0.26      # duvar kalınlığı (hücre boyunun oranı)
const ANIMAL_SIZE := 0.86     # hayvan ve yemek boyu (hücre boyunun oranı)
const FOOD_SIZE := 0.7

## Hareket (ekran pikseli / saniye; hücre boyuna göre ölçeklenir)
const SPEED := 10.0           # hayvanın en yüksek hızı: saniyede bu kadar hücre
const LOOK_AHEAD := 1.6       # hayvan parmağa yaklaşmak için en fazla bu kadar hücre ileriye bakar (duvarın ardını görmez)
const GRAB_RADIUS := 0.85     # hayvanı tutmak için parmak bu kadar hücre yakına değmeli (en az MIN_GRAB px)
const MIN_GRAB := 100.0
const STAR_RADIUS := 0.35     # yıldız hayvan bu kadar hücre yaklaşınca toplanır
const BUMP_DISTANCE := 0.7    # parmak hayvandan bu kadar hücre uzakta ve hayvan ilerleyemiyorsa: duvar

## Süreler (saniye)
const APPEAR_TIME := 0.5
const EAT_TIME := 1.1
const CELEBRATION_TIME := 1.2
const FINALE_TIME := 3.2


static func level_count() -> int:
	return LEVELS.size()


static func map_of(index: int) -> PackedStringArray:
	return PackedStringArray(LEVELS[index]["map"])


static func animal_of(index: int) -> String:
	return LEVELS[index]["animal"]


static func food_of(index: int) -> String:
	return ANIMALS[animal_of(index)]


static func ground_of(index: int) -> Dictionary:
	return GROUNDS[LEVELS[index]["ground"]]


static func animal_path(animal: String, happy: bool = false) -> String:
	return "res://oyunlar/labirent/gorseller/hayvanlar/%s%s.svg" % [animal, "_mutlu" if happy else ""]


static func food_path(food: String) -> String:
	return "res://oyunlar/labirent/gorseller/yiyecekler/%s.svg" % food


## Haritanın hücre sayısı (sütun, satır)
static func grid_size(map: PackedStringArray) -> Vector2i:
	return Vector2i((map[0].length() - 1) / 2, (map.size() - 1) / 2)


## Hücre boyu ve labirentin (duvar çizgilerinin) ekrandaki yeri. screen: görünen alan, area: tasarım alanı
static func board_rect(map: PackedStringArray, screen: Vector2, area: Rect2) -> Rect2:
	var cells := Vector2(grid_size(map))
	var top := area.position.y + TOP
	var avail := Vector2(area.size.x - SIDE * 2.0, area.end.y - BOTTOM - top)
	# Tahtanın payı da sığsın: labirent + iki yanda BOARD_PAD hücre
	var cell := minf(MAX_CELL, minf(avail.x / (cells.x + BOARD_PAD * 2.0), avail.y / (cells.y + BOARD_PAD * 2.0)))
	var size := cells * cell
	return Rect2(Vector2(screen.x / 2.0 - size.x / 2.0, top + (avail.y - size.y) / 2.0), size)


## Haritadaki ilk 'ch' karakterinin hücresi (yoksa -1, -1)
static func find_cell(map: PackedStringArray, ch: String) -> Vector2i:
	for y in map.size():
		var x := map[y].find(ch)
		if x >= 0:
			return Vector2i((x - 1) / 2, (y - 1) / 2)
	return Vector2i(-1, -1)


static func cells_with(map: PackedStringArray, ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.size():
		for x in map[y].length():
			if map[y][x] == ch:
				out.append(Vector2i((x - 1) / 2, (y - 1) / 2))
	return out


## İki komşu hücre arasında yol var mı (duvar yok)
static func is_open(map: PackedStringArray, a: Vector2i, b: Vector2i) -> bool:
	var mid := a + b + Vector2i.ONE   # harita koordinatında: (2a+1 + 2b+1) / 2
	return map[mid.y][mid.x] != "#"


static func neighbors(map: PackedStringArray, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size := grid_size(map)
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and is_open(map, cell, n):
			out.append(n)
	return out


## Başlangıçtan her hücreye en kısa yol: {hücre: önceki hücre}
static func bfs(map: PackedStringArray, from: Vector2i) -> Dictionary:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for n in neighbors(map, cell):
			if not prev.has(n):
				prev[n] = cell
				queue.append(n)
	return prev


## from'dan to'ya en kısa yol (iki ucu da dahil; yol yoksa boş)
static func solution(map: PackedStringArray, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := bfs(map, from)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var cell := to
	while cell != from:
		out.push_front(cell)
		cell = prev[cell]
	out.push_front(from)
	return out


## Tablodaki hataları verir (oyun açılışta, testler her çalışmada denetler)
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if LEVELS.is_empty():
		out.append("hiç bölüm yok")
	var last_cells := 0
	for i in LEVELS.size():
		var name := "Bölüm %d" % (i + 1)
		var level: Dictionary = LEVELS[i]
		if not ANIMALS.has(level.get("animal", "")):
			out.append("%s: hayvan bilinmiyor (%s)" % [name, level.get("animal")])
			continue
		if not GROUNDS.has(level.get("ground", "")):
			out.append("%s: zemin bilinmiyor (%s)" % [name, level.get("ground")])
		var map := map_of(i)
		var problem := _map_problem(map)
		if problem != "":
			out.append("%s: %s" % [name, problem])
			continue
		var size := grid_size(map)
		if size.x * size.y < last_cells:
			out.append("%s: labirent öncekinden küçük (bölümler kolaydan zora)" % name)
		last_cells = size.x * size.y
		var start := find_cell(map, "S")
		var reach := bfs(map, start)
		if not reach.has(find_cell(map, "Y")):
			out.append("%s: yemeğe yol yok" % name)
		for star in cells_with(map, "*"):
			if not reach.has(star):
				out.append("%s: yıldıza yol yok (%s)" % [name, star])
		if reach.size() != size.x * size.y:
			out.append("%s: ulaşılamayan hücre var" % name)
	for animal in ANIMALS:
		for path in [animal_path(animal), animal_path(animal, true), food_path(ANIMALS[animal]),
				"res://oyunlar/labirent/sesler/%s.wav" % animal]:
			if not ResourceLoader.exists(path):
				out.append("%s: dosya yok (%s)" % [animal, path])
	return out


static func _map_problem(map: PackedStringArray) -> String:
	if map.size() < 5 or map.size() % 2 == 0 or map[0].length() < 5 or map[0].length() % 2 == 0:
		return "harita boyu tek sayı ve en az 5 olmalı"
	for y in map.size():
		if map[y].length() != map[0].length():
			return "satır %d öbürleriyle aynı uzunlukta değil" % (y + 1)
		for x in map[y].length():
			var ch := map[y][x]
			if not ch in ["#", ".", "S", "Y", "*"]:
				return "bilinmeyen karakter '%s' (satır %d)" % [ch, y + 1]
			var edge := x == 0 or y == 0 or x == map[y].length() - 1 or y == map.size() - 1
			if (edge or (x % 2 == 0 and y % 2 == 0)) and ch != "#":
				return "kenar ya da köşe duvar değil (satır %d, sütun %d)" % [y + 1, x + 1]
			if x % 2 == 1 and y % 2 == 1 and ch == "#":
				return "hücre duvar olamaz (satır %d, sütun %d)" % [y + 1, x + 1]
			if (x + y) % 2 == 1 and not ch in ["#", "."]:
				return "hücre arasına yalnızca '#' ya da '.' (satır %d, sütun %d)" % [y + 1, x + 1]
	for ch in ["S", "Y"]:
		if "".join(map).count(ch) != 1:
			return "tam bir tane '%s' olmalı" % ch
	return ""
