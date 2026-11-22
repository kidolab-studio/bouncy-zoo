extends SceneTree
# Labirent tablo testi (headless). Proje kökünden:
#   godot --headless --path . -s res://oyunlar/labirent/testler/tablo_testi.gd
# Denetler: ayarlar.gd problems() boş; her bölüm çözülebilir ve yol bölümlerle uzuyor; 7 ekran oranında (çentikli ve
# çentiksiz) tahta tasarım alanının ve güvenli alanın içinde, üstteki geri düğmesine binmiyor, hücre (sürükleme
# koridoru) yeterince büyük; yol ağında hayvan duvardan geçemiyor, köşeleri dönüyor ve yemeğe varabiliyor.

const Settings := preload("res://oyunlar/labirent/ayarlar.gd")
const Walker := preload("res://oyunlar/labirent/yol_agi.gd")
const DESIGN := Vector2(1280, 720)
const RATIOS := [16.0 / 9.0, 18.0 / 9.0, 19.5 / 9.0, 20.0 / 9.0, 21.0 / 9.0, 4.0 / 3.0, 16.0 / 10.0]
const NOTCH := 96.0               # ekran testindeki çentik taklidinin en geniş yanı (EkranYardimcisi yatayda iki yana aynı verir)
const BACK_BUTTON_BOTTOM := 120.0 # geri düğmesinin alt kenarı (sahnede 20 + 100)
const MIN_CELL := 100.0           # en büyük labirentte bile hücre (hayvan) en az bu kadar

var _fails := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	for problem in Settings.problems():
		_check(false, "ayarlar: " + problem)
	_check_solutions()
	_check_layout()
	_check_walker()
	if _fails == 0:
		print("labirent tablo_testi: TAMAM (%d bölüm, %d ekran oranı)" % [Settings.level_count(), RATIOS.size()])
	else:
		printerr("labirent tablo_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


func _check_solutions() -> void:
	var last := 0
	for i in Settings.level_count():
		var map := Settings.map_of(i)
		var path := Settings.solution(map, Settings.find_cell(map, "S"), Settings.find_cell(map, "Y"))
		_check(path.size() >= 4, "Bölüm %d: yol çok kısa (%d hücre)" % [i + 1, path.size()])
		_check(path.size() + 3 >= last, "Bölüm %d: yol öncekinden çok kısa (%d < %d)" % [i + 1, path.size(), last])
		last = maxi(last, path.size())


func _check_layout() -> void:
	for ratio in RATIOS:
		var screen := Vector2(DESIGN.x, DESIGN.x / ratio) if ratio < DESIGN.x / DESIGN.y else Vector2(DESIGN.y * ratio, DESIGN.y)
		var area := Rect2((screen - DESIGN) / 2.0, DESIGN)
		var name := "%.0fx%.0f" % [screen.x, screen.y]
		for i in Settings.level_count():
			var map := Settings.map_of(i)
			var rect := Settings.board_rect(map, screen, area)
			var cell := rect.size.x / Settings.grid_size(map).x
			var board := rect.grow(cell * Settings.BOARD_PAD)
			_check(is_equal_approx(cell, rect.size.y / Settings.grid_size(map).y), "%s, bölüm %d: hücre kare değil" % [name, i + 1])
			_check(area.grow(0.5).encloses(board), "%s, bölüm %d: tahta tasarım alanının dışına taşıyor (%s)" % [name, i + 1, board])
			_check(board.position.x >= NOTCH and board.end.x <= screen.x - NOTCH, "%s, bölüm %d: tahta çentikli ekranda güvenli alanın dışında" % [name, i + 1])
			_check(board.position.y >= BACK_BUTTON_BOTTOM, "%s, bölüm %d: tahta geri düğmesinin altına girmiyor" % [name, i + 1])
			_check(cell >= MIN_CELL, "%s, bölüm %d: hücre küçük (%.0f px)" % [name, i + 1, cell])


# Yol ağı: parmağı yemeğe giden yol boyunca gezdirince hayvan yemeğe varır; duvarın ardına çekince geçmez
func _check_walker() -> void:
	for i in Settings.level_count():
		var map := Settings.map_of(i)
		var rect := Settings.board_rect(map, DESIGN, Rect2(Vector2.ZERO, DESIGN))
		var start := Settings.find_cell(map, "S")
		var food := Settings.find_cell(map, "Y")
		var walker := Walker.new()
		walker.setup(map, rect, start)
		var visited := {start: true}
		for cell in Settings.solution(map, start, food):
			for frame in 60:
				var result := walker.step(walker.center(cell), Settings.SPEED * walker.cell / 60.0)
				for c in result["entered"]:
					visited[c] = true
				_check(_on_network(walker), "Bölüm %d: hayvan yol ağının dışında (%s)" % [i + 1, walker.position()])
				if walker.position().distance_to(walker.center(cell)) < 0.5:
					break
		_check(walker.from_cell == food and walker.t == 0.0, "Bölüm %d: hayvan yemeğe varamadı (%s)" % [i + 1, walker.from_cell])
		_check(visited.size() == Settings.solution(map, start, food).size(), "Bölüm %d: yol dışı hücreye girdi" % (i + 1))
		# Duvar: başlangıçta, duvarla ayrılmış her komşu hücreye çekince hayvan yerinden çıkmaz
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = start + d
			var size := Settings.grid_size(map)
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y or Settings.is_open(map, start, n):
				continue
			walker.setup(map, rect, start)
			var bumped := false
			for frame in 30:
				var result := walker.step(walker.center(n), Settings.SPEED * walker.cell / 60.0)
				bumped = bumped or result["bumped"]
			_check(walker.nearest_cell() != n, "Bölüm %d: hayvan duvardan geçti (%s → %s)" % [i + 1, start, n])


func _on_network(walker: Walker) -> bool:
	return walker.t == 0.0 or Settings.is_open(walker.map, walker.from_cell, walker.to_cell)
