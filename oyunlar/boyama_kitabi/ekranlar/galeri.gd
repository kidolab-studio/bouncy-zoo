class_name ColoringGallery
extends Control
# Galeri: kaydedilen eserlerin küçük resimleri, en yeni en başta, kaydırılabilir ızgara.
# Esere dokununca boyama ekranında kaldığı yerden açılır. Her eserin köşesinde hep görünen bir çöp
# kutusu var; ona dokununca kazara silinmesin diye büyük bir onay (✓ / ✗) çıkar.
# Galeri boşsa şövale ve gülen boya kalemi görseli ile yeni resim düğmesi görünür.

const BackButton := preload("res://ortak/basili_geri_dugmesi.gd")
const G := "res://oyunlar/boyama_kitabi/gorseller/"
const BG := Color("eef7ff")
const OUT := Color("3b2f6b")
const COLUMNS := 4
const TOP := 118.0
const GAP := 26.0
const TRASH := 84.0                   # kartın sağ üst köşesindeki çöp kutusu
const FULL_HINT_DELAY := 0.35          # galeri doluyken çöp kutuları açılış geçişinden sonra sallanır

var game: Node
var back: Control
var new_button: ColoringIconButton
var _grid: Control
var _cards: Array[Control] = []
var _trashes: Array[Control] = []     # _cards ile aynı sırada
var _empty: TextureRect
var _scroller := ColoringScroller.new()
var _owners := {}
var _pressed_card: Control
var _trash_card: Control              # onayı sorulan eser
var _confirm: Control                 # onay katmanı
var _yes: ColoringIconButton
var _no: ColoringIconButton


func setup(owner_game: Node) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = BackButton.new()
	back.size = Vector2(96, 96)
	back.completed.connect(func() -> void: game.show_home())
	add_child(back)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.clip_contents = true
	add_child(_grid)
	_empty = TextureRect.new()
	_empty.texture = load(G + "bos_galeri.svg")
	_empty.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_empty.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	new_button = _button("yeni_resim", 150)
	new_button.accent = Color("ff7a9a")
	add_child(new_button)
	_reload()
	resized.connect(_layout)
	_layout()


func _button(icon: String, side: float) -> ColoringIconButton:
	var button := ColoringIconButton.new()
	button.icon = load(G + icon + ".svg")
	button.size = Vector2(side, side)
	button.icon_scale = 0.72
	return button


func _reload() -> void:
	for card in _cards:
		card.queue_free()
	for trash in _trashes:
		trash.queue_free()
	_cards.clear()
	_trashes.clear()
	for art in ColoringArtworks.gallery_list():
		_cards.append(_make_card(art))
	_empty.visible = _cards.is_empty()
	new_button.visible = _cards.is_empty()


func _make_card(art: Dictionary) -> Control:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("art", art)
	var texture := ColoringArtworks.thumbnail(art["id"])
	card.draw.connect(func() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffd27a")
		box.set_corner_radius_all(18)
		box.border_color = OUT
		box.set_border_width_all(4)
		box.shadow_color = Color(0.23, 0.18, 0.42, 0.18)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 5)
		card.draw_style_box(box, Rect2(Vector2.ZERO, card.size))
		var inner := Rect2(Vector2(14, 14), card.size - Vector2(28, 28))
		card.draw_rect(inner, Color.WHITE)
		if texture:
			card.draw_texture_rect(texture, inner, false)
		card.draw_rect(inner, OUT, false, 3.0))
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	_grid.add_child(card)
	var trash := _button("cop", TRASH)
	trash.accent = Color("ff5b6e")
	trash.set_meta("card", card)
	_grid.add_child(trash)
	_trashes.append(trash)
	return card


func _layout() -> void:
	# Çentikli telefonlarda kenar payı güvenli alan kadar büyür
	var side_left := EkranYardimcisi.kenar_payi(SIDE_LEFT, 40.0)
	var side_right := EkranYardimcisi.kenar_payi(SIDE_RIGHT, 40.0)
	back.position = Vector2(side_left, 14)
	_grid.position = Vector2(side_left, TOP)
	_grid.size = Vector2(size.x - side_left - side_right, size.y - TOP)
	var width := (_grid.size.x - GAP * (COLUMNS - 1)) / COLUMNS
	var card_size := Vector2(width, (width - 28.0) * 0.75 + 28.0)
	var rows := ceili(_cards.size() / float(COLUMNS))
	_scroller.max_offset = maxf(0.0, rows * (card_size.y + GAP) + 30.0 - _grid.size.y)
	_scroller.offset = minf(_scroller.offset, _scroller.max_offset)
	for i in _cards.size():
		_cards[i].size = card_size
		_cards[i].position = Vector2((i % COLUMNS) * (width + GAP), 18.0 + (i / COLUMNS) * (card_size.y + GAP) - _scroller.offset)
		# Kartın içinde kalır; ızgara kenarları kestiği için dışarı taşarsa görünmez
		_trashes[i].position = _cards[i].position + Vector2(card_size.x - TRASH - 4.0, 4.0)
	var empty_size := Vector2(480, 360)
	_empty.size = empty_size
	_empty.position = Vector2((size.x - empty_size.x) * 0.5 - 90.0, (size.y - empty_size.y) * 0.5 + 20.0)
	new_button.position = Vector2(_empty.position.x + empty_size.x + 30.0, size.y * 0.5 - new_button.size.y * 0.5 + 40.0)
	new_button.pivot_offset = new_button.size * 0.5
	if _confirm:
		_confirm.size = size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)


func _process(delta: float) -> void:
	if _scroller.step(delta):
		_layout()


# --- Dokunma ---

func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index, event.position)
	elif event is InputEventScreenDrag and _owners.get(event.index) is String:
		if _scroller.drag(event.position):
			_release_card()
			_layout()


func _buttons() -> Array[Control]:
	var result: Array[Control] = []
	if _confirm:
		result.append_array([_yes, _no])
		return result
	result.append(back)
	if new_button.visible:
		result.append(new_button)
	result.append_array(_trashes)
	return result


func _down(index: int, pos: Vector2) -> void:
	for button in _buttons():
		# Kaydırılıp ızgaranın dışına çıkan (görünmeyen) çöp kutusuna dokunulmaz
		if button in _trashes and not _grid.get_global_rect().has_point(pos):
			continue
		if button.get_global_rect().grow(6.0).has_point(pos):
			_owners[index] = button
			button.press()
			return
	if _confirm:
		return
	if _grid.get_global_rect().has_point(pos) and not _owners.values().has("grid"):
		_owners[index] = "grid"
		_scroller.press(pos)
		for card in _cards:
			if card.get_global_rect().has_point(pos):
				_pressed_card = card
				var tween := card.create_tween()
				tween.tween_property(card, "scale", Vector2.ONE * 0.95, 0.08)


func _up(index: int, pos: Vector2) -> void:
	if not _owners.has(index):
		return
	var owner: Variant = _owners[index]
	_owners.erase(index)
	if owner is String:
		var was_scrolling := _scroller.scrolling
		_scroller.release()
		var card := _pressed_card
		_release_card()
		if not was_scrolling and card and card.get_global_rect().has_point(pos):
			var art: Dictionary = card.get_meta("art")
			game.sounds.play("sayfa")
			game.open_coloring(art["page"], art["id"], "gallery")
		return
	var button: Control = owner
	button.release()
	if button == back or not button.get_global_rect().grow(6.0).has_point(pos):
		return
	if button == new_button:
		game.sounds.play("tik")
		game.show_picker()
	elif button in _trashes:
		game.sounds.play("tik")
		_open_confirm(button.get_meta("card"))
	elif button == _yes:
		_delete_confirmed()
	elif button == _no:
		game.sounds.play("tik")
		_close_confirm()


func _release_card() -> void:
	if _pressed_card:
		var tween := _pressed_card.create_tween()
		tween.tween_property(_pressed_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pressed_card = null


## Galeri dolu (yeni resim açılamadı): çöp kutuları kırmızı halkayla iki kez sallanır, "birini sil" der
func hint_full() -> void:
	var tween := create_tween()
	tween.tween_interval(FULL_HINT_DELAY)
	tween.tween_callback(_shake_trashes.bind(true))
	tween.tween_interval(0.6)
	tween.tween_callback(_shake_trashes.bind(true))
	tween.tween_interval(0.8)
	tween.tween_callback(_shake_trashes.bind(false))


func _shake_trashes(on: bool) -> void:
	for trash: ColoringIconButton in _trashes:
		trash.selected = on
		if on:
			trash.shake()
	if on:
		game.sounds.play("tik")


# --- Silme: çöp kutusu → onay ---

func _open_confirm(card: Control) -> void:
	_trash_card = card
	var art: Dictionary = card.get_meta("art")
	_confirm = Control.new()
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.size = size
	var picture := ColoringArtworks.thumbnail(art["id"])
	_confirm.draw.connect(func() -> void:
		_confirm.draw_rect(Rect2(Vector2.ZERO, _confirm.size), Color(0.18, 0.13, 0.3, 0.55))
		var frame := Rect2(_confirm.size * 0.5 - Vector2(230, 230), Vector2(460, 360))
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffd27a")
		box.set_corner_radius_all(24)
		box.border_color = OUT
		box.set_border_width_all(5)
		_confirm.draw_style_box(box, frame)
		var inner := frame.grow(-18)
		_confirm.draw_rect(inner, Color.WHITE)
		if picture:
			_confirm.draw_texture_rect(picture, inner, false))
	add_child(_confirm)
	_yes = _button("onay", 130)
	_no = _button("iptal", 130)
	_yes.icon_scale = 0.9
	_no.icon_scale = 0.9
	for button in [_no, _yes]:
		_confirm.add_child(button)
		button.pivot_offset = button.size * 0.5
	_yes.position = size * 0.5 + Vector2(40, 150)
	_no.position = size * 0.5 + Vector2(-170, 150)
	_confirm.modulate.a = 0.0
	var tween := _confirm.create_tween()
	tween.tween_property(_confirm, "modulate:a", 1.0, 0.15)


func _close_confirm() -> void:
	if _confirm:
		_confirm.queue_free()
	_confirm = null
	_trash_card = null


func _delete_confirmed() -> void:
	var card := _trash_card
	var art: Dictionary = card.get_meta("art")
	ColoringArtworks.delete_art(art["id"])
	game.sounds.play("sil")
	_close_confirm()
	_trashes[_cards.find(card)].hide()
	var tween := card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * 0.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, 0.25)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_reload()
		_layout())
