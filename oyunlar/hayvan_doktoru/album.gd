extends Node2D
# Çıkartma albümü (StickerAlbum). Kapalıyken bekleme odasının sağ üstünde albüm düğmesi (yeni çıkartma varsa
# nabız gibi atan pembe nokta). Açıkken ekran kararır, ortada albüm: her rahatsızlık bir sayfa (başında simgesi,
# yazı yok), sayfada o rahatsızlığın gelebileceği her hayvanın çıkartması (5 x 2; kazanılmamışlar soluk gölge).
# Sayfa sağa / sola kaydırılarak ya da yandaki büyük oklarla çevrilir; altta sayfa noktaları. Kazanılmış çıkartmaya
# dokununca sallanır, hayvan zıplar ve sesini çıkarır (sticker_tapped). Dokunmayı oyun yönetir: press / release.
# Çıkartmalar stickers sözlüğünde ("<hayvan>_<rahatsızlık>": true; oyun kaydeder).

signal sticker_tapped(animal: String)
signal page_turned

const Sticker := preload("res://oyunlar/hayvan_doktoru/cikartma.gd")
const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const TEX_BUTTON: Texture2D = preload("res://oyunlar/hayvan_doktoru/gorseller/album.svg")
const OUT := Color("3b2f6b")
const PAPER := Color("fff8e8")
const PAPER_EDGE := Color("f0dfb8")
const ARROW := Color("8a6cf0")
const NEW := Color("ff5c8a")
const COLUMNS := 5
const ROWS := 2
## Bu kadar yatay kaydırma sayfayı çevirir (piksel)
const SWIPE := 90.0

var shown: bool = false
## Bekleme odasında düğme görünür, tedavide gizlenir
var show_button: bool = false:
	set(value):
		show_button = value
		queue_redraw()
## Albüm açılmadan kazanılmış yeni çıkartma var: düğmede pembe nokta
var has_new: bool = false
var page: int = 0
var stickers: Dictionary = {}
var button_center := Vector2(1200, 70)
var button_radius: float = 56.0

var _screen := Vector2(1280, 720)
var _panel: Rect2
var _page_node: Node2D
var _slots: Array[Sticker] = []
var _press_point: Vector2
var _pressing: bool = false
var _time: float = 0.0
var _button_pop: float = 0.0
var _tween: Tween


func _ready() -> void:
	_page_node = Node2D.new()
	add_child(_page_node)
	visible = true


## area: tasarım alanı (albüm bunun içinde); button: düğmenin ortası
func layout(screen: Vector2, area: Rect2, button: Vector2, radius: float) -> void:
	_screen = screen
	button_center = button
	button_radius = radius
	var size := Vector2(minf(area.size.x * 0.8, 1000.0), minf(area.size.y * 0.84, 600.0))
	_panel = Rect2(area.get_center() - size / 2.0 + Vector2(0.0, area.size.y * 0.04), size)
	if shown:
		_build_page()
	queue_redraw()


func button_contains(point: Vector2) -> bool:
	return show_button and not shown and point.distance_to(button_center) <= button_radius * 1.25


## Kazanılan çıkartma: düğme zıplar, yeni noktası yanar
func add(animal: String, ailment: String) -> bool:
	var key := "%s_%s" % [animal, ailment]
	var fresh := not stickers.has(key)
	stickers[key] = true
	if fresh:
		has_new = true
	_button_pop = 1.0
	return fresh


func has_sticker(animal: String, ailment: String) -> bool:
	return stickers.has("%s_%s" % [animal, ailment])


func open() -> void:
	shown = true
	has_new = false
	page = clampi(page, 0, Settings.AILMENT_ORDER.size() - 1)
	_build_page()
	_page_node.modulate.a = 0.0
	_page_node.scale = Vector2.ONE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_page_node, "modulate:a", 1.0, 0.25)
	queue_redraw()


func close() -> void:
	if not shown:
		return
	shown = false
	_pressing = false
	_clear_page()
	queue_redraw()


func press(point: Vector2) -> void:
	_pressing = true
	_press_point = point


func release(point: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	var dx := point.x - _press_point.x
	if absf(dx) >= SWIPE:
		turn(-1 if dx > 0.0 else 1)
		return
	if _arrow_rect(-1).has_point(point) and page > 0:
		turn(-1)
		return
	if _arrow_rect(1).has_point(point) and page < Settings.AILMENT_ORDER.size() - 1:
		turn(1)
		return
	for sticker in _slots:
		if sticker.contains(point):
			sticker.wiggle()
			if sticker.filled:
				sticker_tapped.emit(sticker.animal)
			return


## Sayfa çevir: yeni sayfa kaydırma yönünden kayarak gelir
func turn(direction: int) -> void:
	var target := clampi(page + direction, 0, Settings.AILMENT_ORDER.size() - 1)
	if target == page:
		return
	page = target
	_build_page()
	_page_node.position = Vector2(direction * _panel.size.x * 0.25, 0.0)
	_page_node.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_page_node, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_page_node, "modulate:a", 1.0, 0.2)
	page_turned.emit()
	queue_redraw()


## Sayfadaki çıkartmanın ekrandaki yeri (testler ve ipucu için)
func slot_point(index: int) -> Vector2:
	return _slots[index].global_position if index < _slots.size() else Vector2.ZERO


func slot_count() -> int:
	return _slots.size()


func _clear_page() -> void:
	for sticker in _slots:
		sticker.queue_free()
	_slots.clear()


func _build_page() -> void:
	_clear_page()
	var ailment: String = Settings.AILMENT_ORDER[page]
	var animals := Settings.animals_for(ailment)
	var grid := _grid_rect()
	var cell := Vector2(grid.size.x / COLUMNS, grid.size.y / ROWS)
	var size := minf(cell.x, cell.y) * 0.86
	for i in animals.size():
		var sticker := Sticker.new()
		_page_node.add_child(sticker)
		sticker.position = grid.position + Vector2((i % COLUMNS + 0.5) * cell.x, (i / COLUMNS + 0.5) * cell.y)
		sticker.setup(animals[i], ailment, size, has_sticker(animals[i], ailment))
		_slots.append(sticker)


# Çıkartmaların ızgarası: başlık simgesinin altında, okların arasında, noktaların üstünde
func _grid_rect() -> Rect2:
	var top := _panel.position.y + _panel.size.y * 0.22
	var bottom := _panel.end.y - _panel.size.y * 0.1
	var side := _panel.size.x * 0.1
	return Rect2(_panel.position.x + side, top, _panel.size.x - side * 2.0, bottom - top)


func _arrow_rect(direction: int) -> Rect2:
	var r := clampf(_panel.size.y * 0.1, 44.0, 62.0)
	var x := _panel.position.x if direction < 0 else _panel.end.x
	return Rect2(Vector2(x, _panel.get_center().y) - Vector2(r, r) * 1.3, Vector2(r, r) * 2.6)


func _process(delta: float) -> void:
	_time += delta
	_button_pop = move_toward(_button_pop, 0.0, delta * 2.5)
	if show_button or shown:
		queue_redraw()


func _draw() -> void:
	if shown:
		_draw_album()
	elif show_button:
		_draw_button()


func _draw_button() -> void:
	var r := button_radius * (1.0 + 0.2 * sin(_button_pop * PI))
	draw_circle(button_center + Vector2(0, 5), r + 3.0, Color(OUT, 0.18))
	draw_circle(button_center, r + 5.0, OUT)
	draw_circle(button_center, r, Color.WHITE)
	var icon := r * 1.5
	draw_texture_rect(TEX_BUTTON, Rect2(button_center - Vector2(icon, icon) / 2.0, Vector2(icon, icon)), false)
	if has_new:
		var p := button_center + Vector2(r * 0.72, -r * 0.72)
		var dot := r * (0.24 + 0.04 * sin(_time * 6.0))
		draw_circle(p, dot + 4.0, OUT)
		draw_circle(p, dot, NEW)


func _draw_album() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen), Color(OUT, 0.55))
	# Kitap: mor kapak, üstünde kağıt sayfa
	_rounded(_panel.grow(14.0), Color("8a6cf0"), 34, OUT, 6)
	_rounded(_panel, PAPER, 26, PAPER_EDGE, 5)
	# Başlık: rahatsızlığın simgesi, çevresinde yuvarlak
	var ailment: String = Settings.AILMENT_ORDER[page]
	var icon := Settings.tool_texture(Settings.AILMENTS[ailment]["icon"])
	var head := Vector2(_panel.get_center().x, _panel.position.y + _panel.size.y * 0.11)
	var hr := _panel.size.y * 0.085
	draw_circle(head, hr + 4.0, OUT)
	draw_circle(head, hr, Color.WHITE)
	var s := hr * 1.5
	draw_texture_rect(icon, Rect2(head - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	# Oklar
	for direction in [-1, 1]:
		var enabled := (page > 0) if direction < 0 else (page < Settings.AILMENT_ORDER.size() - 1)
		if not enabled:
			continue
		var rect := _arrow_rect(direction)
		var c := rect.get_center()
		var r := rect.size.x / 2.6
		draw_circle(c + Vector2(0, 4), r + 4.0, Color(OUT, 0.2))
		draw_circle(c, r + 5.0, OUT)
		draw_circle(c, r, ARROW)
		var tip := c + Vector2(direction * r * 0.42, 0.0)
		var back := c - Vector2(direction * r * 0.32, 0.0)
		draw_polyline(PackedVector2Array([back + Vector2(0, -r * 0.42), tip, back + Vector2(0, r * 0.42)]), Color.WHITE, r * 0.22, true)
	# Sayfa noktaları
	var count := Settings.AILMENT_ORDER.size()
	var gap := 26.0
	for i in count:
		var p := Vector2(_panel.get_center().x + (i - (count - 1) / 2.0) * gap, _panel.end.y - _panel.size.y * 0.05)
		draw_circle(p, 9.0 if i == page else 6.0, ARROW if i == page else Color(OUT, 0.2))


func _rounded(rect: Rect2, color: Color, radius: int, border: Color, border_width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	draw_style_box(box, rect)
