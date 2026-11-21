extends "res://ortak/suruklenebilir.gd"
# Yapboz parçası (JigsawPiece): resmin bir parçası, çıkıntılı kenarlarıyla. Yakalanma, parmağı izleme,
# yerine dönme, gelme ve zıplama ortak DraggableItem'dan (ortak/suruklenebilir.gd), dokunma ortak
# DragInput'tan gelir.
#
# Boyut: parçanın kendi ölçeği (scale) tepside 1'dir; görseli (art) tepsi oranında küçük çizilir.
# Tutulunca DragInput onu tahtadaki boyuna büyütür (drag_scale = 1 / tray_ratio), yerine oturunca da
# ölçeği full_scale (= 1 / tray_ratio) olur. Böylece ortak return_home() (ölçeği 1'e döndürür) olduğu
# gibi kullanılır.

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const OUTLINE := Color("3b2f6b")
const SHADOW := Color(0.16, 0.1, 0.3, 0.22)

var col: int = 0
var row: int = 0
## Tahtadaki yeri (ortası; parçanın ebeveyniyle aynı koordinatta)
var target: Vector2
## Yerine oturdu: artık tutulamaz
var placed: bool = false
## Yerine kayıyor (oturma animasyonu kesilmesin)
var settling: bool = false
var tray_ratio: float = 0.5
var cell_size: Vector2           # tahtadaki hücre boyu (px)

var _art: Node2D
var _shadow: Polygon2D
var _outline: Node2D
var _points: PackedVector2Array  # tahta pikselinde, hücre ortasına göre
var _glow: Tween


## data: kesici.gd'nin parça sözlüğü; board_scale: resim pikselinden tahta pikseline;
## start: tepsideki yuvası
func setup_piece(data: Dictionary, texture: Texture2D, board_scale: float, ratio: float, board_target: Vector2, start: Vector2) -> void:
	col = data["col"]
	row = data["row"]
	tray_ratio = ratio
	target = board_target
	var cell: Rect2 = data["cell"]
	cell_size = cell.size * board_scale
	var center := cell.get_center()
	var tex_scale := Vector2(texture.get_width(), texture.get_height()) / Settings.PICTURE_SIZE
	var uv := PackedVector2Array()
	_points = PackedVector2Array()
	for p: Vector2 in data["points"]:
		_points.append((p - center) * board_scale)
		uv.append(p * tex_scale)
	_art = Node2D.new()
	_art.scale = Vector2.ONE * tray_ratio
	add_child(_art)
	_shadow = Polygon2D.new()
	_shadow.polygon = _points
	_shadow.color = SHADOW
	_shadow.position = Vector2(5.0, 7.0)
	_art.add_child(_shadow)
	var picture := Polygon2D.new()
	picture.polygon = _points
	picture.uv = uv
	picture.texture = texture
	picture.antialiased = true
	_art.add_child(picture)
	_outline = Node2D.new()
	_outline.draw.connect(_draw_outline)
	_art.add_child(_outline)
	setup_drag(cell_size.y * tray_ratio, start)


func _draw_outline() -> void:
	var closed := _points.duplicate()
	closed.append(_points[0])
	_outline.draw_polyline(closed, Color(1, 1, 1, 0.55), 5.0, true)
	_outline.draw_polyline(closed, OUTLINE, 2.5, true)


## Tahtadaki boyuna ölçek
func full_scale() -> float:
	return 1.0 / tray_ratio


func can_grab() -> bool:
	return not placed and visible


# Yakalama alanı: hücre dikdörtgeni (biraz büyük); küçük parçada bile en az MIN_TOUCH
func grab_distance(point: Vector2, padding: float) -> float:
	var shown := scale.x * tray_ratio
	var local := (point - position) / shown
	var half := cell_size * 0.5 * padding
	var least := Settings.MIN_TOUCH * 0.5 / shown
	half = Vector2(maxf(half.x, least), maxf(half.y, least))
	if absf(local.x) <= half.x and absf(local.y) <= half.y:
		return point.distance_to(position)
	return INF


# Yerine yumuşakça kayar ve oturur (on_landed: oturunca çağrılır)
func seat(duration: float, on_landed: Callable = Callable()) -> void:
	placed = true
	settling = true
	dragging = false
	home = target
	var full := Vector2.ONE * full_scale()
	var tween := _new_tween()
	tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", full, duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "rotation", 0.0, duration)
	tween.parallel().tween_property(_shadow, "modulate:a", 0.0, duration)
	tween.tween_property(self, "scale", full * Vector2(1.04, 0.97), 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", full, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		z_index = 0
		settling = false)
	if on_landed.is_valid():
		tween.tween_callback(on_landed)


# Bölüm başı: resmin içindeki yerinden (tam boy) tepsideki yuvasına uçar
func scatter(delay: float, duration: float) -> void:
	position = target
	scale = Vector2.ONE * full_scale()
	z_index = Z_DRAGGED
	_shadow.modulate.a = 0.0
	var tween := _new_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "position", home, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow, "modulate:a", 1.0, duration)
	tween.tween_callback(func() -> void: z_index = Z_IDLE)


# İpucu: birkaç kez parlar ve kıpırdar
func glow() -> void:
	if _glow:
		_glow.kill()
	_glow = create_tween()
	for k in 3:
		_glow.tween_property(self, "modulate", Color(1.35, 1.35, 1.2), 0.22).set_trans(Tween.TRANS_SINE)
		_glow.tween_property(self, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_SINE)
	wiggle()


# Bölüm bitti: kenar çizgisi yumuşakça kaybolur
func hide_outline(duration: float) -> void:
	create_tween().tween_property(_outline, "modulate:a", 0.0, duration)
