extends SceneTree
# Yapboz kesici ve yerleşim testi (headless). Proje kökünden:
#   godot --headless --path . -s res://oyunlar/yapboz/testler/kesici_testi.gd
# Denetler:
#   - ayarlar.gd tablosu (problems());
#   - her ızgarada (2x2 ... 4x4) 300 rastgele kesim: çokgenler kendini kesmiyor, üçgenlenebiliyor, alanları
#     hücreye yakın; parçaların alanları toplamı resmin alanına eşit (komşu kenarlar birebir aynı);
#     komşu iki parçanın ortak kenarı aynı noktalardan oluşuyor;
#   - 7 ekran oranında (16:9 ... 4:3, 16:10), çentikli ve çentiksiz, her bölümün yerleşimi: tahta ve tepsiler
#     tasarım alanının içinde, tepsideki parçalar (çıkıntılarıyla) tahtaya binmiyor ve ekranın içinde,
#     tepsideki parça yeterince büyük (MIN_TRAY_PIECE), tahta en az BOARD_MIN_HEIGHT.

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const Cutter := preload("res://oyunlar/yapboz/kesici.gd")
const Layout := preload("res://oyunlar/yapboz/yerlesim.gd")
const SCREENS := [Vector2(1280, 720), Vector2(1440, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1680, 720),
	Vector2(1280, 960), Vector2(1280, 800)]
const GRIDS := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4)]
const ROUNDS := 300
var _fails := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		if _fails <= 40:
			printerr("HATA: " + message)


func _initialize() -> void:
	for problem in Settings.problems():
		_check(false, "ayarlar: " + problem)
	_check_cuts()
	_check_layouts()
	if _fails == 0:
		print("yapboz kesici_testi: TAMAM")
	else:
		printerr("yapboz kesici_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


func _check_cuts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total_area := Settings.PICTURE_SIZE.x * Settings.PICTURE_SIZE.y
	for grid: Vector2i in GRIDS:
		for round in ROUNDS:
			var pieces := Cutter.cut(grid.x, grid.y, Settings.PICTURE_SIZE, rng)
			var name := "%dx%d kesim %d" % [grid.x, grid.y, round]
			_check(pieces.size() == grid.x * grid.y, name + ": parça sayısı yanlış")
			for problem in Cutter.problems(pieces):
				_check(false, name + ": " + problem)
			var area := 0.0
			for piece in pieces:
				area += absf(Cutter._area(piece["points"]))
			_check(absf(area - total_area) < 1.0, name + ": alanların toplamı resimden farklı (%.1f)" % (area - total_area))
			_check_shared_edges(pieces, grid, name)


# Komşu parçalar: sağdaki komşuyla ortak kenarın noktaları ikisinde de aynı (ters sırada)
func _check_shared_edges(pieces: Array[Dictionary], grid: Vector2i, name: String) -> void:
	for piece in pieces:
		var c: int = piece["col"]
		var r: int = piece["row"]
		if c + 1 < grid.x:
			var other: Dictionary = pieces[r * grid.x + c + 1]
			_check(_shared(piece["points"], other["points"]) >= Cutter.ARC_STEPS, "%s: %d,%d ile sağ komşusu birbirine oturmuyor" % [name, c, r])
		if r + 1 < grid.y:
			var below: Dictionary = pieces[(r + 1) * grid.x + c]
			_check(_shared(piece["points"], below["points"]) >= Cutter.ARC_STEPS, "%s: %d,%d ile alt komşusu birbirine oturmuyor" % [name, c, r])


func _shared(a: PackedVector2Array, b: PackedVector2Array) -> int:
	var count := 0
	for p in a:
		for q in b:
			if p.distance_to(q) < 0.001:
				count += 1
				break
	return count


func _check_layouts() -> void:
	for screen: Vector2 in SCREENS:
		var area := Rect2((screen - Vector2(1280, 720)) / 2.0, Vector2(1280, 720))
		for notch in [0.0, 96.0]:
			var side := maxf(Settings.SIDE, notch)
			for i in Settings.level_count():
				var level: Dictionary = Settings.LEVELS[i]
				var cols: int = level["cols"]
				var rows: int = level["rows"]
				var layout := Layout.make(cols, rows, screen, area, side)
				var name := "%dx%d ekran, çentik %d, bölüm %d (%dx%d)" % [screen.x, screen.y, notch, i + 1, cols, rows]
				_check(area.grow(0.5).encloses(layout.board), name + ": tahta tasarım alanının dışında")
				_check(layout.board.size.y >= Settings.BOARD_MIN_HEIGHT - 0.01, name + ": tahta çok küçük")
				_check(Layout.tray_piece(layout) >= Settings.MIN_TRAY_PIECE, name + ": tepsideki parça küçük (%.0f)" % Layout.tray_piece(layout))
				_check(layout.slots.size() == cols * rows, name + ": yuva sayısı yanlış")
				var piece := layout.cell * layout.tray_ratio
				var reach := minf(piece.x, piece.y) * Settings.KNOB_REACH
				var jitter := piece * Settings.TRAY_JITTER
				for slot in layout.slots:
					# Yuvanın kayması da hesaba katılır (TRAY_JITTER)
					var box := Rect2(slot - piece / 2.0, piece).grow(reach).grow_individual(jitter.x, jitter.y, jitter.x, jitter.y)
					_check(not box.intersects(layout.board), name + ": tepsideki parça tahtaya biniyor (%s)" % slot)
					_check(Rect2(Vector2(side, 0), screen - Vector2(side * 2.0, 0)).encloses(Rect2(slot - piece / 2.0, piece)), name + ": tepsideki parça ekranın / güvenli alanın dışında (%s)" % slot)
					_check(area.has_point(slot), name + ": yuva tasarım alanının dışında (%s)" % slot)
