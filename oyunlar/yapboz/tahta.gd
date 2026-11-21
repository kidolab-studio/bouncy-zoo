extends Node2D
# Yapboz tahtası (JigsawBoard): ortada çerçeveli resim alanı; içinde soluk resim (ipucu) ve parçaların
# kesik çizgili hatları; iki yanda tepsilerin yumuşak panelleri. Parçalar bu düğümün çocuğudur
# (koordinatları ekranla aynı: düğüm başlangıçta durur).
# Bölüm başında resmin tamamı görünür (show_whole), parçalar dağılınca soluk resim ve hatlar belirir
# (start_play). Bitince tam resim parçaların üstünde belirir, hatlar kaybolur, resim parlar ve zıplar
# (celebrate).

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const Layout := preload("res://oyunlar/yapboz/yerlesim.gd")
const FRAME_COLOR := Color("ffffff")
const FRAME_EDGE := Color("3b2f6b")
const INSIDE := Color("f6f2ff")
const DASH := Color(0.23, 0.18, 0.42, 0.5)
const FRAME_WIDTH := 12.0

var layout: Layout.Layout
var ghost_alpha: float = 0.3
## Resmin çerçevesi (resmin ortasında durur; kutlamada zıplayan bu)
var frame: Node2D

var _ghost: Sprite2D
var _dashes: Node2D
var _full: Sprite2D
var _shine: Polygon2D
var _outlines: Array[PackedVector2Array] = []


func setup(board_layout: Layout.Layout, texture: Texture2D, pieces: Array[Dictionary], ghost: float) -> void:
	layout = board_layout
	ghost_alpha = ghost
	frame = Node2D.new()
	frame.position = layout.board.get_center()
	frame.draw.connect(_draw_frame)
	add_child(frame)
	_ghost = _picture(texture)
	_ghost.modulate.a = 0.0
	frame.add_child(_ghost)
	for piece in pieces:
		var outline := PackedVector2Array()
		for p: Vector2 in piece["points"]:
			outline.append((p - Settings.PICTURE_SIZE / 2.0) * layout.scale)
		outline.append(outline[0])
		_outlines.append(outline)
	_dashes = Node2D.new()
	_dashes.draw.connect(_draw_dashes)
	_dashes.modulate.a = 0.0
	frame.add_child(_dashes)
	# Tam resim: bölüm başında ve sonunda parçaların üstünde
	_full = _picture(texture)
	_full.z_index = 5
	_full.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_child(_full)
	var size := layout.board.size
	_shine = Polygon2D.new()
	_shine.polygon = PackedVector2Array([Vector2(-60, -size.y), Vector2(20, -size.y), Vector2(-20, size.y), Vector2(-100, size.y)])
	_shine.color = Color(1, 1, 1, 0.55)
	_shine.visible = false
	_full.add_child(_shine)
	queue_redraw()


func _picture(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * layout.board.size.x / texture.get_width()
	return sprite


# Tepsilerin yumuşak panelleri
func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.38)
	style.set_corner_radius_all(28)
	for tray in layout.trays:
		draw_style_box(style, tray.grow(8.0))


func _draw_frame() -> void:
	var size := layout.board.size
	var rect := Rect2(-size / 2.0, size)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.2, 0.12, 0.35, 0.18)
	shadow.set_corner_radius_all(26)
	frame.draw_style_box(shadow, Rect2(rect.position + Vector2(0.0, 9.0), rect.size).grow(FRAME_WIDTH + 3.0))
	var style := StyleBoxFlat.new()
	style.bg_color = INSIDE
	style.border_color = FRAME_COLOR
	style.set_border_width_all(int(FRAME_WIDTH))
	style.set_corner_radius_all(22)
	frame.draw_style_box(style, rect.grow(FRAME_WIDTH))
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = FRAME_EDGE
	edge.set_border_width_all(4)
	edge.set_corner_radius_all(24)
	frame.draw_style_box(edge, rect.grow(FRAME_WIDTH + 2.0))


func _draw_dashes() -> void:
	for outline in _outlines:
		_dashed(_dashes, outline, DASH, 3.0, 12.0, 9.0)


# Kesik çizgili çoklu çizgi (çizgiler köşelerden kopmadan devam eder)
static func _dashed(node: CanvasItem, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var at := 0.0
		while at < length:
			var step := minf(left, length - at)
			if on:
				node.draw_line(a.lerp(b, at / length), a.lerp(b, (at + step) / length), color, width, true)
			at += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash if on else gap


## Bölüm başı: resmin tamamı görünür
func show_whole() -> void:
	_full.modulate.a = 1.0
	_ghost.modulate.a = 0.0
	_dashes.modulate.a = 0.0


## Parçalar dağılırken: tam resim kaybolur (parçalar aynı yerde başladığı için fark edilmez), soluk resim
## ve hatlar belirir
func start_play(duration: float) -> void:
	_full.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_ghost, "modulate:a", ghost_alpha, duration)
	tween.tween_property(_dashes, "modulate:a", 1.0, duration)


## Bütün parçalar oturdu: tam resim belirir, hatlar kaybolur, resimde bir parlama geçer, resim zıplar
func celebrate() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_full, "modulate:a", 1.0, 0.35)
	tween.tween_property(_dashes, "modulate:a", 0.0, 0.35)
	await tween.finished
	var width := layout.board.size.x
	_shine.visible = true
	_shine.position.x = -width * 0.6
	var sweep := create_tween()
	sweep.tween_property(_shine, "position:x", width * 0.7, 0.6).set_trans(Tween.TRANS_SINE)
	sweep.tween_callback(func() -> void: _shine.visible = false)
	var bounce := create_tween()
	bounce.tween_property(frame, "scale", Vector2(1.05, 1.05), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce.tween_property(frame, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await bounce.finished


## Bölüm sonu: tahta ve parçalar yumuşakça kaybolur
func leave() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_property(frame, "scale", Vector2(0.92, 0.92), 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished
