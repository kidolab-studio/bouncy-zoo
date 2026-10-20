class_name ColoringToolBar
extends Control
# Araç çubuğu (sağ kenar): geri al, kaydet, kova, fırça, gökkuşağı fırçası, damga, silgi, temizle.
# Altında seçili aracın seçenekleri: fırça ve silgide 3 kalınlık, damgada 6 damga.
# Seçili aracın simgesi (kova boyası, fırça ucu, damga) seçili renge boyanır.
# Temizle basılı tutulunca çalışır (halka dolar). Dokunmayı ekran yönetir: contains / press / release.

signal tool_chosen(id: String)
signal option_chosen(index: int)
signal undo_pressed
signal save_pressed
signal clear_completed

const G := "res://oyunlar/boyama_kitabi/gorseller/"
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const StampTool := preload("res://oyunlar/boyama_kitabi/araclar/damga.gd")
const CELL := 88.0
const BUTTON := 80.0
const OPTION := 66.0
const CLEAR_HOLD := 1.5

## Araçlar: kimlik, simge, renklenen katman (varsa), seçenek türü
const TOOLS := [
	{"id": "kova", "icon": "kova", "tint": true, "options": ""},
	{"id": "firca", "icon": "firca", "tint": true, "options": "size"},
	{"id": "gokkusagi", "icon": "gokkusagi", "tint": false, "options": "size"},
	{"id": "damga", "icon": "damga", "tint": true, "options": "stamp"},
	{"id": "silgi", "icon": "silgi", "tint": false, "options": "size"},
]
const SIZE_DOTS := [0.18, 0.3, 0.46]     # kalınlık düğmelerindeki noktanın yarıçapı (düğmeye oranla)

var color: Color = Color.WHITE
var current: String = "kova"
var undo_button: ColoringIconButton
var save_button: ColoringIconButton
var clear_button: Control
var _tool_buttons := {}                   # id -> düğme
var _options: Array[ColoringIconButton] = []
var _option_kind: String = ""
var _option_selected := {"size": 1, "stamp": 0}
var _eraser_size: int = 1
var _pressed: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	undo_button = _button(load(G + "geri_al.svg"))
	save_button = _button(load(G + "kaydet.svg"))
	for tool in TOOLS:
		var button := _button(load(G + tool["icon"] + ".svg"))
		if tool["tint"]:
			button.tint_icon = load(G + tool["icon"] + "_renk.svg")
		_tool_buttons[tool["id"]] = button
	clear_button = HoldButton.new()
	clear_button.icon = load(G + "temizle.svg")
	clear_button.double_tap = false     # resmi silmek bilerek yapılsın: sadece basılı tutunca
	clear_button.hold_time = CLEAR_HOLD
	clear_button.size = Vector2(BUTTON, BUTTON)
	clear_button.completed.connect(_on_clear)
	add_child(clear_button)
	resized.connect(_layout)
	select_tool("kova")
	_layout()


func _button(icon: Texture2D) -> ColoringIconButton:
	var button := ColoringIconButton.new()
	button.icon = icon
	button.size = Vector2(BUTTON, BUTTON)
	add_child(button)
	return button


func _layout() -> void:
	var grid := [[undo_button, save_button], [_tool_buttons["kova"], _tool_buttons["firca"]],
		[_tool_buttons["gokkusagi"], _tool_buttons["damga"]], [_tool_buttons["silgi"], clear_button]]
	for row in grid.size():
		for column in 2:
			var button: Control = grid[row][column]
			button.position = Vector2(size.x * 0.5 + (column - 1) * CELL + (CELL - BUTTON) * 0.5, row * CELL + (CELL - BUTTON) * 0.5)
			button.pivot_offset = button.size * 0.5
	_layout_options()
	queue_redraw()


func options_rect() -> Rect2:
	var top := 4 * CELL + 14.0
	return Rect2(Vector2(size.x * 0.5 - CELL, top), Vector2(CELL * 2.0, maxf(0.0, size.y - top)))


func _layout_options() -> void:
	var area := options_rect()
	var step := minf(OPTION + 8.0, (area.size.y - 12.0) / 3.0)
	for i in _options.size():
		var button := _options[i]
		var column := i % 2
		var row := i / 2
		if _option_kind == "size":
			# Kalınlıklar: iki sütuna sığmayan üçüncüsü ortada
			column = i % 2 if i < 2 else -1
		var x := area.position.x + (CELL * (column + 0.5) if column >= 0 else CELL)
		button.size = Vector2(OPTION, OPTION)
		button.position = Vector2(x - OPTION * 0.5, area.position.y + 8.0 + row * step)
		button.pivot_offset = button.size * 0.5


func contains(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)


func press(point: Vector2) -> void:
	_pressed = _button_at(point)
	if _pressed == clear_button:
		clear_button.press()
	elif _pressed:
		_pressed.press()


func release(point: Vector2) -> void:
	var button := _pressed
	_pressed = null
	if button == null:
		return
	button.release()
	if button == clear_button or not button.contains(point):
		return
	if button == undo_button:
		undo_pressed.emit()
	elif button == save_button:
		save_pressed.emit()
	elif button in _options:
		_choose_option(_options.find(button))
	else:
		for id in _tool_buttons:
			if _tool_buttons[id] == button:
				select_tool(id)
				tool_chosen.emit(id)


func cancel() -> void:
	if _pressed:
		_pressed.release()
	_pressed = null


func _button_at(point: Vector2) -> Control:
	var buttons: Array = [undo_button, save_button, clear_button]
	buttons.append_array(_tool_buttons.values())
	buttons.append_array(_options)
	for button: Control in buttons:
		if button.is_visible_in_tree() and button.get_global_rect().grow(4.0).has_point(point):
			return button
	return null


func _on_clear() -> void:
	clear_completed.emit()
	# Düğme bir sonraki basışa hazır olsun
	clear_button.set("_done", false)
	clear_button.set("_progress", 0.0)
	clear_button.release()
	clear_button.queue_redraw()


func select_tool(id: String) -> void:
	current = id
	for key in _tool_buttons:
		_tool_buttons[key].selected = key == id
	var kind: String = ""
	for tool in TOOLS:
		if tool["id"] == id:
			kind = tool["options"]
	_build_options(kind)


func set_color(value: Color) -> void:
	color = value
	for tool in TOOLS:
		if tool["tint"]:
			_tool_buttons[tool["id"]].tint = value
	for button in _options:
		button.tint = value
		button.queue_redraw()


## Seçili seçenek: kalınlık (0..2) ya da damga (0..5)
func option() -> int:
	if current == "silgi":
		return _eraser_size
	return _option_selected.get(_option_kind, 0)


func _build_options(kind: String) -> void:
	for button in _options:
		button.queue_free()
	_options.clear()
	_option_kind = kind
	if kind == "size":
		for i in SIZE_DOTS.size():
			var button := _button(null)
			var dot: float = SIZE_DOTS[i]
			button.extra_draw = func(b: ColoringIconButton) -> void:
				var dot_color := b.tint if current != "silgi" else Color("ff9ab8")
				if current == "gokkusagi":
					dot_color = Color.from_hsv(0.08 + 0.3 * i, 0.7, 1.0)
				var r := b.size.x * dot * 0.5
				b.draw_circle(b.size * 0.5, r, dot_color)
				b.draw_arc(b.size * 0.5, r, 0.0, TAU, 32, ColoringIconButton.OUT, 3.0, true)
			_options.append(button)
	elif kind == "stamp":
		for i in StampTool.KINDS.size():
			# Seçili renkli katman altta (tint_icon), yüz ve parıltılar üstte (extra_draw)
			var button := _button(null)
			button.tint_icon = StampTool.fill_texture(i)
			button.icon_scale = 0.78
			var top := StampTool.top_texture(i)
			button.extra_draw = func(b: ColoringIconButton) -> void:
				var side := (minf(b.size.x, b.size.y) - 8.0) * b.icon_scale
				b.draw_texture_rect(top, Rect2((b.size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
			_options.append(button)
	var selected := option()
	for i in _options.size():
		_options[i].selected = i == selected
		_options[i].accent = Color("8a6cf0")
	set_color(color)
	_layout_options()
	queue_redraw()


func _choose_option(index: int) -> void:
	if current == "silgi":
		_eraser_size = index
	else:
		_option_selected[_option_kind] = index
	for i in _options.size():
		_options[i].selected = i == index
	option_chosen.emit(index)


func _draw() -> void:
	if _options.is_empty():
		return
	var area := options_rect()
	var used := Rect2(area.position, Vector2(area.size.x, 0.0))
	for button in _options:
		used = used.merge(Rect2(button.position, button.size))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1, 1, 1, 0.55)
	panel.set_corner_radius_all(26)
	draw_style_box(panel, used.grow_individual(4, 4, 4, 8))
