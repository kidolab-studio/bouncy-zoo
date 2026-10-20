extends Control
# Hud (UI CanvasLayer içinde): sol üstte ortak çift dokunuşlu geri düğmesi (çocuk ekrana sürekli dokunduğu için
# kazara çıkılmasın), sağ kenarda yazısız, büyük, yuvarlak enstrüman seçme düğmeleri. Dokunmayı ana sahne
# yönetir (back_button.contains / selector_at sorar).

const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const INK := Color("3b2f6b")
const SIDE := 56.0            # yatayda çentik yanlarda olabilir: kenarlardan uzak
const TOP := 22.0
const BUTTON := 132.0
const GAP := 18.0

var back_button: HoldButton
var _buttons: Array[Panel] = []
var _styles: Array[StyleBoxFlat] = []
var _colors: Array[Color] = []
var _selected: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_button = HoldButton.new()
	back_button.position = Vector2(SIDE, TOP)
	back_button.size = Vector2(116, 116)
	add_child(back_button)


## icons / colors: enstrüman düğmelerinin simgeleri ve renkleri (INSTRUMENTS sırasıyla)
func build_selector(icons: Array[Texture2D], colors: Array[Color]) -> void:
	_colors = colors
	for k in icons.size():
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.size = Vector2(BUTTON, BUTTON)
		panel.pivot_offset = panel.size / 2.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_border_width_all(6)
		style.border_color = INK
		style.set_corner_radius_all(999)
		style.shadow_color = Color(0.15, 0.1, 0.3, 0.25)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 5)
		panel.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.texture = icons[k]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		add_child(panel)
		_buttons.append(panel)
		_styles.append(style)


## Düğme sütunu sağ kenarda, top..bottom arasında dikey ortalı
func layout(size: Vector2, top: float, bottom: float) -> void:
	var column := BUTTON * _buttons.size() + GAP * (_buttons.size() - 1)
	var y := top + maxf(0.0, (bottom - top - column) / 2.0)
	for k in _buttons.size():
		_buttons[k].position = Vector2(column_left(size), y + k * (BUTTON + GAP))


func column_left(size: Vector2) -> float:
	# Çentik sağdaysa düğme sütunu güvenli alan kadar içeri girer
	return size.x - EkranYardimcisi.kenar_payi(SIDE_RIGHT, SIDE) - BUTTON


func selector_at(point: Vector2) -> int:
	for k in _buttons.size():
		var rect := _buttons[k].get_global_rect().grow(GAP / 2.0)
		if rect.has_point(point):
			return k
	return -1


func select(index: int, animate: bool) -> void:
	_selected = index
	for k in _buttons.size():
		var on := k == index
		_styles[k].bg_color = _colors[k].lightened(0.55) if on else Color(1, 1, 1, 0.92)
		_styles[k].border_color = _colors[k].darkened(0.25) if on else INK
		_styles[k].set_border_width_all(9 if on else 6)
		var target := Vector2.ONE * (1.1 if on else 0.9)
		var button := _buttons[k]
		button.modulate.a = 1.0 if on else 0.85
		if animate:
			if on:
				button.scale = Vector2.ONE * 0.8
			button.create_tween().tween_property(button, "scale", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			button.scale = target


## Seçili düğmeye yeniden dokunulunca küçük bir zıplama
func bounce(index: int) -> void:
	var button := _buttons[index]
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * 0.98, 0.07)
	tween.tween_property(button, "scale", Vector2.ONE * 1.1, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
