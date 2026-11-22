extends Node2D
# Bir bölümün sayfası (DotPage): beyaz kâğıt, üstünde soluk sahne, çocuğun çizdiği hat, numaralı noktalar ve
# çizim bitince ortaya çıkan renkli nesne. Dokunmayı oyun okur; bu düğüm yalnızca çizer ve oyunun sorularını
# yanıtlar (dot_at, hits_next, ...). Koordinatlar ekranla aynı (düğüm ekranın sol üstünde durur).
#
# Hat: parça k, k. noktadan k+1. noktaya gider (son parça son noktadan 1. noktaya döner). Parçalar düz ya da
# noktalar.json'daki kontrol noktasıyla eğridir; nesnenin SVG'deki dış hattıyla aynı çizgi.

const Settings := preload("res://oyunlar/nokta_birlestir/ayarlar.gd")
const FONT_FILE: Font = preload("res://ortak/fontlar/Nunito.ttf")
const OUT := Color("3b2f6b")
const NEXT := Color("ff7a45")
const RAINBOW := [Color("ff5a6e"), Color("ff9f40"), Color("ffc93d"), Color("5cc95c"), Color("4fa8ff"), Color("a66bff")]
const CURVE_STEPS := 28

var rect: Rect2                       # resmin ekrandaki yeri
var picture: String = ""
var dots := PackedVector2Array()      # noktalar (ekran)
var done: int = 0                     # bağlanan nokta sayısı
var touch_radius: float = Settings.TOUCH_RADIUS
var rubber: Variant = null            # Vector2: son noktadan parmağa giden kesik çizgi; null: yok

var _scale: float = 1.0
var _paths: Array[PackedVector2Array] = []
var _progress := PackedFloat32Array() # her parçanın çizilen oranı (0-1)
var _appear: float = 0.0              # noktaların sırayla belirmesi (0-1)
var _wiggles := {}                    # nokta -> sallanmanın başladığı an
var _time: float = 0.0
var _font := FontVariation.new()

var _scene: Sprite2D
var _lines: Node2D
var _object: Sprite2D
var _dots_layer: Node2D
var _object_scale: float = 1.0
var _object_home: Vector2


func setup(picture_name: String, picture_rect: Rect2) -> void:
	picture = picture_name
	rect = picture_rect
	_font.base_font = FONT_FILE
	_font.variation_opentype = {2003265652: 900}   # wght
	var size := Settings.picture_size()
	_scale = rect.size.x / size.x
	dots = PackedVector2Array()
	for p in Settings.dots_of(picture):
		dots.append(rect.position + p * _scale)
	var curves := Settings.curves_of(picture)
	_paths.clear()
	for k in dots.size():
		var a := dots[k]
		var b := dots[(k + 1) % dots.size()]
		var path := PackedVector2Array([a])
		if curves[k] != null:
			var c: Vector2 = rect.position + curves[k] * _scale
			for s in range(1, CURVE_STEPS):
				var t := float(s) / CURVE_STEPS
				path.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		path.append(b)
		_paths.append(path)
	_progress.resize(dots.size())
	_progress.fill(0.0)
	# İki nokta yakınsa dokunma alanları çakışmasın
	var gap := Settings.min_gap(picture) * _scale
	touch_radius = minf(Settings.TOUCH_RADIUS, gap / 2.0)

	_scene = _sprite(load(Settings.scene_path(picture)))
	_scene.modulate.a = Settings.SCENE_ALPHA
	_lines = Node2D.new()
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	var texture: Texture2D = load(Settings.object_path(picture))
	_object = _sprite(texture)
	var ratio := texture.get_width() / size.x
	_object_scale = _scale / ratio
	_object.offset = -Settings.pivot_of(picture) * ratio
	_object_home = rect.position + Settings.pivot_of(picture) * _scale
	_object.position = _object_home
	_object.scale = Vector2.ONE * _object_scale
	_object.modulate.a = 0.0
	_dots_layer = Node2D.new()
	_dots_layer.draw.connect(_draw_dots)
	add_child(_dots_layer)
	queue_redraw()


func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rect.position
	sprite.scale = Vector2.ONE * rect.size.x / texture.get_width()
	add_child(sprite)
	return sprite


# --- Oyunun soruları ---

func count() -> int:
	return dots.size()


## Sıradaki nokta (hepsi bağlandıysa -1)
func next_index() -> int:
	return done if done < dots.size() else -1


## Son bağlanan nokta (hiç yoksa -1)
func tail_index() -> int:
	return done - 1


## Parmağın altındaki nokta (en yakını; dokunma yarıçapında değilse -1)
func dot_at(pos: Vector2) -> int:
	var best := -1
	var best_distance := touch_radius
	for i in dots.size():
		var distance := pos.distance_to(dots[i])
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best


## Parmak a'dan b'ye kayarken sıradaki noktanın üstünden geçti mi (hızlı kaydırmada da kaçmasın)
func hits_next(a: Vector2, b: Vector2) -> bool:
	var i := next_index()
	if i < 0:
		return false
	return Geometry2D.get_closest_point_to_segment(dots[i], a, b).distance_to(dots[i]) <= touch_radius


# --- Çizim adımları ---

## Bölüm başı: kâğıt belirir, noktalar sırayla çıkar
func appear() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_method(func(v: float) -> void:
		_appear = v
		_dots_layer.queue_redraw(), 0.0, 1.0, Settings.APPEAR_TIME)
	await tween.finished


## Sıradaki noktayı bağlar; önceki noktadan buna çizgi uzar (animated: dokunarak, false: parmak üstünden geçti)
func connect_next(animated: bool) -> void:
	if next_index() < 0:
		return
	done += 1
	if done >= 2:
		_grow(done - 2, Settings.SEGMENT_TIME if animated else 0.0)
	_dots_layer.queue_redraw()


## Son parça (son noktadan 1. noktaya) kendiliğinden çizilir
func close_shape(time: float) -> void:
	await _grow(dots.size() - 1, time)


func _grow(k: int, time: float) -> void:
	if time <= 0.0:
		_progress[k] = 1.0
		_lines.queue_redraw()
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_progress[k] = maxf(_progress[k], v)
		_lines.queue_redraw(), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func set_rubber(pos: Variant) -> void:
	rubber = pos
	_lines.queue_redraw()


## Yanlış noktaya dokunuldu: nazikçe sallanır
func wiggle(i: int) -> void:
	_wiggles[i] = _time


## Çizim bitti: numaralar söner, sahne renklenir, renkli nesne belirir
func reveal() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_dots_layer, "modulate:a", 0.0, 0.25)
	tween.tween_property(_scene, "modulate:a", 1.0, Settings.REVEAL_TIME)
	tween.tween_property(_object, "modulate:a", 1.0, Settings.REVEAL_TIME * 0.7)
	tween.tween_property(_lines, "modulate:a", 0.0, 0.2).set_delay(Settings.REVEAL_TIME * 0.7)
	var base := Vector2.ONE * _object_scale
	_object.scale = base * 0.94
	tween.tween_property(_object, "scale", base, Settings.REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## Ortaya çıkan nesnenin hareketi (ayarlar.gd PICTURES anim)
func animate(kind: String) -> void:
	var base := Vector2.ONE * _object_scale
	var up := rect.size.y * 0.06
	var tween := create_tween()
	match kind:
		"zipla":
			for k in 2:
				tween.tween_property(_object, "scale", base * Vector2(1.08, 0.9), 0.12)
				tween.tween_property(_object, "scale", base * Vector2(0.95, 1.07), 0.1)
				tween.parallel().tween_property(_object, "position:y", _object_home.y - up, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(_object, "position:y", _object_home.y, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tween.parallel().tween_property(_object, "scale", base, 0.2)
			tween.tween_property(_object, "scale", base * Vector2(1.05, 0.95), 0.08)
			tween.tween_property(_object, "scale", base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		"salla":
			tween.tween_method(func(t: float) -> void:
				var fade := 1.0 - t
				_object.rotation = sin(t * TAU * 2.0) * 0.07 * fade
				_object.position.y = _object_home.y - absf(sin(t * TAU * 2.0)) * up * 0.4 * fade, 0.0, 1.0, Settings.ANIM_TIME)
			tween.tween_callback(func() -> void:
				_object.rotation = 0.0
				_object.position = _object_home)
		"parla":
			tween.tween_property(_object, "position:y", _object_home.y - up * 1.3, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(_object, "scale", base * 1.08, 0.25)
			tween.tween_method(func(t: float) -> void: _object.rotation = sin(t * TAU * 2.0) * 0.08 * (1.0 - t), 0.0, 1.0, 0.7)
			tween.tween_property(_object, "position:y", _object_home.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(_object, "scale", base, 0.25)
			tween.tween_callback(func() -> void: _object.rotation = 0.0)
		"uc":
			# Titrer, havalanır (kâğıdın üstüne taşar), yumuşakça yerine iner
			tween.tween_method(func(t: float) -> void:
				_object.position = _object_home + Vector2(sin(t * 70.0) * 4.0, 0.0), 0.0, 1.0, 0.4)
			tween.tween_property(_object, "position", _object_home - Vector2(0.0, rect.size.y * 0.3), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_property(_object, "position", _object_home, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"suzul":
			# Burnunu kaldırıp ileri yukarı süzülür, sonra yerine döner
			var ahead := _object_home + Vector2(rect.size.x * 0.08, -rect.size.y * 0.1)
			tween.tween_property(_object, "rotation", -0.12, 0.35).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_object, "position", ahead, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(_object, "rotation", 0.06, 0.4).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_object, "position", _object_home, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(_object, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Bölüm sonu: sayfa küçülerek kaybolur
func leave() -> void:
	var center := rect.get_center()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "scale", Vector2.ONE * 0.92, 0.35)
	tween.tween_property(self, "position", center * 0.08, 0.35)   # ortasından küçülsün
	await tween.finished


## Resmin ortası ve boyu (efektler için)
func object_center() -> Vector2:
	return rect.get_center()


# --- Çizim ---

func _process(delta: float) -> void:
	_time += delta
	if _dots_layer and _dots_layer.modulate.a > 0.0:
		_dots_layer.queue_redraw()


func _draw() -> void:
	# Beyaz kâğıt ve gölgesi
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.WHITE
	var radius := int(48.0 * _scale + Settings.PAGE_BORDER)
	paper.set_corner_radius_all(radius)
	paper.shadow_color = Color(OUT, 0.18)
	paper.shadow_size = 16
	paper.shadow_offset = Settings.SHADOW
	paper.border_color = Color("e6defa")
	paper.set_border_width_all(3)
	draw_style_box(paper, rect.grow(Settings.PAGE_BORDER))


func _draw_lines() -> void:
	var width := Settings.line_width() * _scale
	for k in _paths.size():
		if _progress[k] <= 0.0:
			continue
		var points := _partial(_paths[k], _progress[k])
		_lines.draw_polyline(points, OUT, width, true)
		_lines.draw_circle(points[points.size() - 1], width / 2.0, OUT)
	if rubber is Vector2 and done > 0:
		var from := dots[done - 1]
		_lines.draw_dashed_line(from, rubber, Color(OUT, 0.55), width * 0.7, width * 1.6, true, true)
		_lines.draw_circle(rubber, width * 0.9, Color(NEXT, 0.8))


## Yolun baştan t oranındaki kısmı
func _partial(path: PackedVector2Array, t: float) -> PackedVector2Array:
	if t >= 1.0:
		return path
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var left := total * t
	var out := PackedVector2Array([path[0]])
	for i in range(1, path.size()):
		var length := path[i - 1].distance_to(path[i])
		if length >= left:
			out.append(path[i - 1].lerp(path[i], left / maxf(length, 0.001)))
			return out
		out.append(path[i])
		left -= length
	return out


func _draw_dots() -> void:
	var r := Settings.DOT_RADIUS
	var n := dots.size()
	for i in n:
		var grow := clampf(_appear * (n + 2) - i, 0.0, 1.0)
		if grow <= 0.0:
			continue
		grow = ease(grow, -2.0)
		var pos := dots[i] + _wiggle_offset(i)
		if i < done:
			var color: Color = RAINBOW[i % RAINBOW.size()]
			_dots_layer.draw_circle(pos, r * 0.62 * grow, OUT)
			_dots_layer.draw_circle(pos, r * 0.62 * grow - 4.0, color)
			_dots_layer.draw_circle(pos + Vector2(-r * 0.18, -r * 0.18), r * 0.14, Color(1, 1, 1, 0.8))
			continue
		var size := r * grow
		var ring := OUT
		if i == done:
			var pulse := 1.0 + sin(_time * 5.0) * 0.07
			size *= Settings.NEXT_GROW * pulse
			ring = NEXT
			_dots_layer.draw_circle(pos, size * (1.55 + sin(_time * 5.0) * 0.1), Color(NEXT, 0.22))
		_dots_layer.draw_circle(pos + Vector2(0, 3), size, Color(OUT, 0.18))
		_dots_layer.draw_circle(pos, size, ring)
		_dots_layer.draw_circle(pos, size - (6.0 if i == done else 4.0), Color.WHITE)
		_draw_number(str(i + 1), pos, grow, OUT if i != done else NEXT.darkened(0.35))


func _draw_number(text: String, pos: Vector2, grow: float, color: Color) -> void:
	var font_size := int(Settings.NUMBER_SIZE * (0.85 if text.length() > 1 else 1.0) * grow)
	if font_size < 4:
		return
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := pos.y + (_font.get_ascent(font_size) - _font.get_descent(font_size)) / 2.0
	_dots_layer.draw_string(_font, Vector2(pos.x - width / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _wiggle_offset(i: int) -> Vector2:
	if not _wiggles.has(i):
		return Vector2.ZERO
	var age: float = _time - _wiggles[i]
	if age > 0.45:
		_wiggles.erase(i)
		return Vector2.ZERO
	return Vector2(sin(age * 40.0) * 7.0 * (1.0 - age / 0.45), 0.0)
