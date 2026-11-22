extends Node2D
# Labirent tahtası (MazeBoard): zemin, hayvanın geçtiği yolun izi, duvarlar (kalın, yuvarlak uçlu çalı / taş /
# kar çizgileri), yıldızlar, yemek ve hayvan. Koordinatlar ekranla aynı. Dokunma yok; oyun (labirent.gd)
# hayvanın yerini yol_agi.gd ile hesaplayıp buraya verir.

const Settings := preload("res://oyunlar/labirent/ayarlar.gd")
const TEX_STAR: Texture2D = preload("res://oyunlar/labirent/gorseller/yildiz.svg")
const OUT := Color("3b2f6b")
const OUTLINE := 5.0          # duvarın ve tahtanın koyu kenar çizgisi

var map: PackedStringArray
var rect: Rect2               # labirentin (duvar çizgilerinin) ekrandaki yeri
var cell := 100.0
var ground: Dictionary
var animal_name := ""

var animal: Node2D            # hayvanın yeri (zıplama / sallanma alt Sprite2D'de)
var food: Sprite2D
var stars := {}               # hücre → Sprite2D (toplanınca silinir)

var _animal_sprite: Sprite2D
var _walls: Node2D
var _trail: Array = []        # [Vector2, Vector2] geçilen kenarlar
var _partial: Array = []      # şu an yürünen kenarın geçilen kısmı
var _walking := 0.0           # yürürken sallanma (0..1)
var _time := 0.0
var _grab_tween: Tween


func setup(index: int, board: Rect2) -> void:
	map = Settings.map_of(index)
	rect = board
	cell = rect.size.x / Settings.grid_size(map).x
	ground = Settings.ground_of(index)
	animal_name = Settings.animal_of(index)
	_walls = Node2D.new()
	_walls.draw.connect(_draw_walls)
	add_child(_walls)
	for star_cell in Settings.cells_with(map, "*"):
		var star := Sprite2D.new()
		star.texture = TEX_STAR
		star.position = cell_center(star_cell)
		star.scale = Vector2.ONE * cell * 0.42 / TEX_STAR.get_width()
		add_child(star)
		stars[star_cell] = star
	food = Sprite2D.new()
	food.texture = load(Settings.food_path(Settings.food_of(index)))
	food.position = cell_center(Settings.find_cell(map, "Y"))
	food.scale = Vector2.ONE * cell * Settings.FOOD_SIZE / food.texture.get_width()
	add_child(food)
	animal = Node2D.new()
	animal.position = cell_center(Settings.find_cell(map, "S"))
	add_child(animal)
	_animal_sprite = Sprite2D.new()
	_animal_sprite.texture = load(Settings.animal_path(animal_name))
	_animal_sprite.scale = Vector2.ONE * animal_size() / _animal_sprite.texture.get_width()
	_animal_sprite.offset = Vector2(0, -_animal_sprite.texture.get_height() * 0.04)
	animal.add_child(_animal_sprite)
	queue_redraw()


func cell_center(c: Vector2i) -> Vector2:
	return rect.position + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func animal_size() -> float:
	return cell * Settings.ANIMAL_SIZE


func board_rect() -> Rect2:
	return rect.grow(cell * Settings.BOARD_PAD)


# --- Hayvan ---

func set_animal_position(pos: Vector2, walking: bool) -> void:
	animal.position = pos
	_walking = 1.0 if walking else _walking


func set_grabbed(grabbed: bool) -> void:
	if _grab_tween:
		_grab_tween.kill()
	_grab_tween = create_tween()
	_grab_tween.tween_property(animal, "scale", Vector2.ONE * (1.15 if grabbed else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Duvara değdi: hayvan başını sallar
func wiggle() -> void:
	var tween := _animal_sprite.create_tween()
	for angle in [-0.16, 0.16, -0.1, 0.0]:
		tween.tween_property(_animal_sprite, "rotation", angle, 0.07)


# Yolun izi: geçilen kenarlar ve şu an yürünen kenarın geçilen kısmı
func add_trail(a: Vector2i, b: Vector2i) -> void:
	_trail.append([cell_center(a), cell_center(b)])
	queue_redraw()


func set_partial(a: Vector2, b: Vector2) -> void:
	_partial = [a, b] if a.distance_to(b) > 1.0 else []
	queue_redraw()


func collect_star(c: Vector2i) -> void:
	var star: Sprite2D = stars[c]
	stars.erase(c)
	var tween := star.create_tween().set_parallel()
	tween.tween_property(star, "scale", star.scale * 2.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "rotation", TAU / 5.0, 0.35)
	tween.tween_property(star, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tween.chain().tween_callback(star.queue_free)


# Yemeğe vardı: hayvan yemeğin üstüne kayar, yemek küçülerek yenir, hayvan mutlu yüzle zıplar
func eat() -> void:
	_walking = 0.0
	set_grabbed(false)
	var tween := create_tween()
	tween.tween_property(animal, "position", food.position, 0.18).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(food, "position", food.position + Vector2(0, cell * 0.12), 0.18)
	tween.tween_callback(func() -> void: _animal_sprite.texture = load(Settings.animal_path(animal_name, true)))
	tween.tween_property(food, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var base := _animal_sprite.scale
	for k in 2:
		tween.tween_property(_animal_sprite, "position:y", -cell * 0.35, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_animal_sprite, "scale", base * Vector2(0.92, 1.1), 0.16)
		tween.tween_property(_animal_sprite, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_animal_sprite, "scale", base * 1.25, 0.16)
	await tween.finished


# --- Bölüm başı / sonu ---

func appear() -> void:
	modulate.a = 0.0
	var center := rect.get_center()
	scale = Vector2.ONE * 0.92
	position = center * (1.0 - scale.x)
	animal.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_method(_set_zoom.bind(center), 0.92, 1.0, Settings.APPEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, Settings.APPEAR_TIME * 0.6)
	tween.tween_property(animal, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func leave() -> void:
	var tween := create_tween()
	tween.tween_method(_set_zoom.bind(rect.get_center()), 1.0, 0.9, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished


# Tahtayı ortasına göre ölçekler (düğüm sol üstte durduğu için konum da değişir)
func _set_zoom(value: float, center: Vector2) -> void:
	scale = Vector2.ONE * value
	position = center * (1.0 - value)


func _process(delta: float) -> void:
	_time += delta
	if _animal_sprite:
		# Yürürken hafif sallanma; durunca yumuşakça düzelir
		_walking = move_toward(_walking, 0.0, delta * 4.0)
		if _walking > 0.0:
			_animal_sprite.rotation = sin(_time * 16.0) * 0.1 * _walking
	if food and food.scale.x > 0.0 and is_instance_valid(food):
		food.rotation = sin(_time * 2.5) * 0.08
	for star in stars.values():
		star.rotation = sin(_time * 2.0 + star.position.x) * 0.15


# --- Çizim ---

func _draw() -> void:
	# Tahta: gölgeli, yuvarlak köşeli zemin
	var box := StyleBoxFlat.new()
	box.bg_color = ground["floor"]
	box.set_corner_radius_all(int(cell * 0.4))
	box.border_color = OUT
	box.set_border_width_all(int(OUTLINE))
	box.shadow_color = Color(OUT, 0.18)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 8)
	draw_style_box(box, board_rect())
	# Zeminde hafif benekler (çimen tutamı / kum tanesi / kar)
	var dot := Color(ground["wall"], 0.12)
	var size := Settings.grid_size(map)
	for y in size.y:
		for x in size.x:
			var c := cell_center(Vector2i(x, y))
			draw_circle(c + Vector2(-0.22, 0.24) * cell, cell * 0.035, dot)
			draw_circle(c + Vector2(0.26, -0.2) * cell, cell * 0.03, dot)
	# Yolun izi
	var width := cell * 0.3
	var trail_color: Color = ground["path"]
	for segment in _trail + ([_partial] if not _partial.is_empty() else []):
		draw_line(segment[0], segment[1], trail_color, width)
		draw_circle(segment[0], width / 2.0, trail_color)
		draw_circle(segment[1], width / 2.0, trail_color)


# Duvarlar: önce hepsinin koyu kenarı, sonra dolgusu, en üstte parlaklık (hepsi tek parça görünsün)
func _draw_walls() -> void:
	var segments := []
	var posts := []
	for y in map.size():
		for x in map[y].length():
			if map[y][x] != "#":
				continue
			var p := rect.position + Vector2(x, y) * cell / 2.0
			if x % 2 == 0 and y % 2 == 0:
				posts.append(p)
			elif x % 2 == 0:
				segments.append([p - Vector2(0, cell / 2.0), p + Vector2(0, cell / 2.0)])
			else:
				segments.append([p - Vector2(cell / 2.0, 0), p + Vector2(cell / 2.0, 0)])
	var w := cell * Settings.WALL_WIDTH
	var passes := [[w + OUTLINE * 2.0, OUT, Vector2.ZERO], [w, ground["wall"], Vector2.ZERO],
		[w * 0.3, ground["light"], Vector2(-0.12, -0.14) * w]]
	for item in passes:
		var line_width: float = item[0]
		var color: Color = item[1]
		var offset: Vector2 = item[2]
		for segment in segments:
			_walls.draw_line(segment[0] + offset, segment[1] + offset, color, line_width)
		for p in posts:
			_walls.draw_circle(p + offset, line_width / 2.0, color)
