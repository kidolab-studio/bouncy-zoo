extends Control
# Hafıza Kartları: iki karta dokun, aynıysa açık kalır. Bütün eşleri bul.
# Temalar ve bölümler veriler.gd içinde, tek kartın animasyonları kart.gd içinde.

const Data := preload("res://oyunlar/hafiza/veriler.gd")
const Card := preload("res://oyunlar/hafiza/kart.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")

enum State { SELECT, DEALING, PLAYING, CHECKING, CELEBRATING }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

## Bölüm sonu kutlamasının süresi (saniye); sonra sonraki bölüme geçilir.
@export var celebration_time: float = 2.0
## İlk bölümlerde kartların başta açık gösterildiği süre (saniye).
@export var preview_time: float = 2.0
## Eşleşmeyen kartların geri kapanmadan önce açık kaldığı süre (saniye).
@export var mismatch_time: float = 1.0

const TEX_FRONT: Texture2D = preload("res://oyunlar/hafiza/gorseller/kart_on.svg")
const TEX_SHADOW: Texture2D = preload("res://oyunlar/hafiza/gorseller/kart_golge.svg")
const TEX_GLOW: Texture2D = preload("res://oyunlar/hafiza/gorseller/parilti.svg")
const TEX_STAR: Texture2D = preload("res://oyunlar/hafiza/gorseller/yildiz.svg")
const TEX_SPARKLE: Texture2D = preload("res://oyunlar/hafiza/gorseller/isilti.svg")
const TEX_LOCK: Texture2D = preload("res://oyunlar/hafiza/gorseller/kilit.svg")
const TEX_CLOUD: Texture2D = preload("res://oyunlar/hafiza/gorseller/bulut.svg")
const TEX_BUBBLE: Texture2D = preload("res://oyunlar/hafiza/gorseller/kabarcik.svg")

const SAVE_PATH := "user://hafiza.cfg"
const WORDS := ["Harika!", "Süper!", "Tebrikler!"]
const RAINBOW := [Color("ff5a6e"), Color("ff9f40"), Color("ffc93d"), Color("5cc95c"), Color("4fa8ff"), Color("a66bff")]
const BOARD_TOP := 130.0
const LEVEL_BUTTON := 240.0   # bölüm seçme düğmesinin kenarı
const BOARD_BOTTOM_MARGIN := 40.0
const CARD_ASPECT := 1.2          # kart yüksekliği / genişliği
const MAX_CARD_WIDTH := 250.0

@onready var sky: TextureRect = $Sky
@onready var floaters: Node2D = $Floaters
@onready var game: Control = $Game
@onready var cards_layer: Node2D = $Game/Cards
@onready var effects: Node2D = $Game/Effects
@onready var back_panel: Panel = $Game/BackButton
@onready var select_back_panel: Panel = $LevelSelect/BackButton
var back_button: Control
var select_back_button: Control
@onready var cheer: HBoxContainer = $Game/Cheer
@onready var level_select: Control = $LevelSelect
@onready var theme_row: HBoxContainer = $LevelSelect/ThemeRow
@onready var level_grid: GridContainer = $LevelSelect/LevelGrid

var state: State = State.SELECT
var theme_index: int = 0
var level_index: int = 0
var completed := {}                # tema id -> bitirilen bölüm sayısı
var cards: Array = []
var open_cards: Array = []
var run_id: int = 0                # ekran değişince eski beklemeler devam etmesin
var theme_buttons: Array[Panel] = []
var level_buttons: Array[Panel] = []
var pulse_tween: Tween
var sky_gradient := Gradient.new()
var textures := {}                 # yol -> Texture2D önbelleği


func _ready() -> void:
	SesYoneticisi.muzik("hafiza", self)
	back_button = HoldButton.replace(back_panel)
	back_button.completed.connect(_on_back_completed)
	select_back_button = HoldButton.replace(select_back_panel)
	select_back_button.completed.connect(_on_select_back_completed)
	_check_data()
	_load_progress()
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky_gradient
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	sky_texture.width = 16
	sky_texture.height = 256
	sky.texture = sky_texture
	var colors: Array = Data.THEMES[theme_index]["sky"]
	sky_gradient.set_color(0, colors[0])
	sky_gradient.set_color(1, colors[1])
	_create_floaters()
	_create_theme_buttons()
	_show_level_select()
	IpucuEli.ekle(self, "hafiza", _ipucu)


# İpucu eli: kapalı bir karta, sonra başka bir karta dokun (bir kart açıksa sadece ikinciye)
func _ipucu() -> Dictionary:
	if state != State.PLAYING or open_cards.size() >= 2:
		return {}
	var kapali: Array = []
	for card in cards:
		if not card.is_open and not card.is_matched:
			kapali.append(card)
	if open_cards.size() == 1 and kapali.size() >= 1:
		return IpucuEli.dokun(IpucuEli.ekran_konumu(kapali[0]), 1)
	if kapali.size() >= 2:
		return IpucuEli.cift_dokun(IpucuEli.ekran_konumu(kapali[0]), IpucuEli.ekran_konumu(kapali[-1]))
	return {}


func _check_data() -> void:
	var most_pairs := 0
	for level: Dictionary in Data.LEVELS:
		var count: int = level["cols"] * level["rows"]
		if count % 2 != 0:
			push_error("Hafıza: %dx%d bölümünde kart sayısı tek" % [level["cols"], level["rows"]])
		most_pairs = maxi(most_pairs, floori(count / 2.0))
	for theme_data: Dictionary in Data.THEMES:
		if (theme_data["items"] as Array).size() < most_pairs:
			push_error("Hafıza: '%s' temasında en az %d resim olmalı" % [theme_data["id"], most_pairs])


func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]


func _theme_texture(theme_data: Dictionary, file_name: String) -> Texture2D:
	return _texture(theme_data["folder"] + file_name + ".svg")


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	# Geri düğmeleri basılı tutulur; bölüm seçme ekranında ana menüye, oyunda bölüm seçmeye döner
	var back: Control = select_back_button if state == State.SELECT else back_button
	if back.handle_touch(touch) or not touch.pressed:
		return
	var pos := touch.position
	if state == State.SELECT:
		for i in theme_buttons.size():
			if _is_touched(theme_buttons[i], pos):
				SesYoneticisi.efekt("dugme_tik")
				_select_theme(i)
				return
		for i in level_buttons.size():
			if _is_touched(level_buttons[i], pos):
				if i <= _completed_count():
					_press(level_buttons[i])
					SesYoneticisi.efekt("dugme_tik")
					_start_level(i)
				else:
					SesYoneticisi.efekt("yumusak_hayir")
					_shake(level_buttons[i])
				return
		return

	if state != State.PLAYING or open_cards.size() >= 2:
		return
	for card in cards:
		if not card.is_open and not card.is_matched and card.contains(pos):
			card.tap_open()
			SesYoneticisi.efekt("kart_cevir", -2.0)
			open_cards.append(card)
			if open_cards.size() == 2:
				state = State.CHECKING
				_check_pair()
			return


func _on_select_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	SahneGecis.ana_menuye_don()


func _on_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	back_button.reset()
	_show_level_select()


func _is_touched(control: Control, pos: Vector2) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(pos)


# --- Bölüm seçme ekranı ---

func _show_level_select() -> void:
	run_id += 1
	state = State.SELECT
	for card in cards:
		card.queue_free()
	cards.clear()
	open_cards.clear()
	for child in effects.get_children():
		child.queue_free()
	cheer.visible = false
	game.visible = false
	level_select.visible = true
	_update_theme_buttons()
	_build_level_buttons()


func _create_theme_buttons() -> void:
	for i in Data.THEMES.size():
		var theme_data: Dictionary = Data.THEMES[i]
		var button := Panel.new()
		button.custom_minimum_size = Vector2(200, 150)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = _theme_texture(theme_data, theme_data["icon"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		theme_row.add_child(button)
		theme_buttons.append(button)


func _update_theme_buttons() -> void:
	for i in theme_buttons.size():
		var button := theme_buttons[i]
		var selected := i == theme_index
		var accent: Color = Data.THEMES[i]["accent"]
		button.add_theme_stylebox_override("panel", _panel_style(Color.WHITE if selected else Color(1, 1, 1, 0.55), accent if selected else Color(1, 1, 1, 0.8), 8 if selected else 4))
		button.pivot_offset = button.custom_minimum_size / 2.0
		var tween := button.create_tween().set_parallel()
		tween.tween_property(button, "scale", Vector2.ONE * (1.0 if selected else 0.86), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0 if selected else 0.75, 0.25)


func _select_theme(index: int) -> void:
	if index == theme_index:
		_press(theme_buttons[index])
		return
	var old_colors: Array = Data.THEMES[theme_index]["sky"]
	theme_index = index
	_save_progress()
	var new_colors: Array = Data.THEMES[theme_index]["sky"]
	# Gökyüzü renkleri yumuşakça değişsin
	create_tween().tween_method(_blend_sky.bind(old_colors, new_colors), 0.0, 1.0, 0.6)
	_update_theme_buttons()
	_build_level_buttons()


func _blend_sky(t: float, from: Array, to: Array) -> void:
	sky_gradient.set_color(0, (from[0] as Color).lerp(to[0], t))
	sky_gradient.set_color(1, (from[1] as Color).lerp(to[1], t))


func _completed_count() -> int:
	return completed.get(Data.THEMES[theme_index]["id"], 0)


# Bölüm düğmeleri yazı yerine küçük kart ızgarasıyla zorluğu gösterir
func _build_level_buttons() -> void:
	if pulse_tween:
		pulse_tween.kill()
	for button in level_buttons:
		level_grid.remove_child(button)
		button.queue_free()
	level_buttons.clear()

	var theme_data: Dictionary = Data.THEMES[theme_index]
	var back := _theme_texture(theme_data, "arka")
	var done := _completed_count()
	for i in Data.LEVELS.size():
		var level: Dictionary = Data.LEVELS[i]
		var open := i <= done
		var button := Panel.new()
		button.custom_minimum_size = Vector2(LEVEL_BUTTON, LEVEL_BUTTON)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.92), (theme_data["accent"] as Color) if open else Color("c9c3dc"), 6))

		# Küçük kartlardan oluşan ızgara
		var grid := GridContainer.new()
		grid.columns = level["cols"]
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		var cell_w := minf((LEVEL_BUTTON - 60.0 - 6.0 * (level["cols"] - 1)) / level["cols"], (LEVEL_BUTTON - 60.0 - 6.0 * (level["rows"] - 1)) / level["rows"] / CARD_ASPECT)
		for k in level["cols"] * level["rows"]:
			var mini_card := TextureRect.new()
			mini_card.texture = back
			mini_card.custom_minimum_size = Vector2(cell_w, cell_w * CARD_ASPECT)
			mini_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mini_card.stretch_mode = TextureRect.STRETCH_SCALE
			mini_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(mini_card)
		var grid_size := Vector2(cell_w * level["cols"] + 6.0 * (level["cols"] - 1), cell_w * CARD_ASPECT * level["rows"] + 6.0 * (level["rows"] - 1))
		grid.position = (button.custom_minimum_size - grid_size) / 2.0
		grid.modulate = Color.WHITE if open else Color(1, 1, 1, 0.35)
		button.add_child(grid)

		if not open:
			var lock := TextureRect.new()
			lock.texture = TEX_LOCK
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 80)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(lock)
		if i < done:
			var star := TextureRect.new()
			star.texture = TEX_STAR
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.position = Vector2(LEVEL_BUTTON - 74.0, -22)
			star.size = Vector2(80, 80)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(star)

		level_grid.add_child(button)
		level_buttons.append(button)
		# Düğmeler sırayla belirsin
		button.pivot_offset = button.custom_minimum_size / 2.0
		button.scale = Vector2(0.6, 0.6)
		button.modulate.a = 0.0
		var tween := button.create_tween().set_parallel()
		tween.tween_property(button, "scale", Vector2.ONE, 0.45).set_delay(i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.2).set_delay(i * 0.07)

	# Sıradaki bölüm hafifçe nabız gibi atsın
	if done < level_buttons.size():
		var current := level_buttons[done]
		pulse_tween = current.create_tween().set_loops()
		pulse_tween.tween_interval(0.6)
		pulse_tween.tween_property(current, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(current, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_corner_radius_all(40)
	style.shadow_color = Color(0.2, 0.1, 0.3, 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 8)
	return style


# --- Oyun ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	if pulse_tween:
		pulse_tween.kill()
	level_index = index
	state = State.DEALING
	level_select.visible = false
	game.visible = true
	cheer.visible = false
	for card in cards:
		card.queue_free()
	cards.clear()
	open_cards.clear()
	for child in effects.get_children():
		child.queue_free()

	var theme_data: Dictionary = Data.THEMES[theme_index]
	var level: Dictionary = Data.LEVELS[index]
	var cols: int = level["cols"]
	var rows: int = level["rows"]

	# Rastgele resimler seç, her birinden iki kart yap ve karıştır
	var items: Array = (theme_data["items"] as Array).duplicate()
	items.shuffle()
	var deck: Array = []
	for k in floori(cols * rows / 2.0):
		deck.append(items[k])
		deck.append(items[k])
	deck.shuffle()

	# Kart boyutu ekrana sığacak şekilde
	var screen := get_viewport_rect().size
	var area := Rect2(40.0, BOARD_TOP, screen.x - 80.0, screen.y - BOARD_TOP - BOARD_BOTTOM_MARGIN)
	var gap := 22.0 if cols <= 3 else 16.0
	var card_w := minf(minf((area.size.x - gap * (cols - 1)) / cols, (area.size.y - gap * (rows - 1)) / rows / CARD_ASPECT), MAX_CARD_WIDTH)
	var card_size := Vector2(card_w, card_w * CARD_ASPECT)
	var board_size := Vector2(card_size.x * cols + gap * (cols - 1), card_size.y * rows + gap * (rows - 1))
	var origin := area.position + (area.size - board_size) / 2.0

	var back := _theme_texture(theme_data, "arka")
	var deal_from := Vector2(screen.x / 2.0, screen.y + card_size.y)
	for k in deck.size():
		var card: Card = Card.new()
		cards_layer.add_child(card)
		card.setup(deck[k], card_size, TEX_FRONT, _theme_texture(theme_data, deck[k]), back, TEX_SHADOW, TEX_GLOW)
		var cell := Vector2(k % cols, floori(float(k) / cols))
		card.position = origin + cell * (card_size + Vector2(gap, gap)) + card_size / 2.0
		card.deal(deal_from, k * 0.08)
		_sound_later(my_run, k * 0.08, "kart_dagit", -4.0)
		cards.append(card)

	await get_tree().create_timer(deck.size() * 0.08 + 0.6).timeout
	if my_run != run_id:
		return

	if level["preview"]:
		# Kartlar kısa süre açık gösterilir, sonra kapanır
		SesYoneticisi.efekt("kart_cevir", -2.0)
		for k in cards.size():
			cards[k].flip(true)
			await get_tree().create_timer(0.05).timeout
			if my_run != run_id:
				return
		await get_tree().create_timer(preview_time).timeout
		if my_run != run_id:
			return
		SesYoneticisi.efekt("kart_cevir", -2.0)
		for k in cards.size():
			cards[k].flip(false)
			await get_tree().create_timer(0.04).timeout
			if my_run != run_id:
				return
		await get_tree().create_timer(0.45).timeout
		if my_run != run_id:
			return
	state = State.PLAYING


func _check_pair() -> void:
	var my_run := run_id
	var first: Card = open_cards[0]
	var second: Card = open_cards[1]
	await get_tree().create_timer(0.55).timeout  # ikinci kart açılsın
	if my_run != run_id:
		return

	if first.item_id == second.item_id:
		SesYoneticisi.efekt("ding_yumusak")
		first.celebrate()
		second.celebrate()
		_burst_stars(first.global_position, first.card_size)
		_burst_stars(second.global_position, second.card_size)
		open_cards.clear()
		if cards.all(func(card) -> bool: return card.is_matched):
			_level_complete(my_run)
		else:
			state = State.PLAYING
	else:
		await get_tree().create_timer(maxf(mismatch_time - 0.55, 0.1)).timeout
		if my_run != run_id:
			return
		SesYoneticisi.efekt("yumusak_hayir", -3.0)
		_sound_later(my_run, 0.35, "kart_cevir", -4.0)  # sallandıktan sonra kapanır
		first.shake_and_close()
		second.shake_and_close()
		await get_tree().create_timer(0.8).timeout
		if my_run != run_id:
			return
		open_cards.clear()
		state = State.PLAYING


# Bölüm hâlâ aynıysa sesi biraz sonra çal
func _sound_later(my_run: int, delay: float, sound: String, volume_db: float) -> void:
	await get_tree().create_timer(delay).timeout
	if my_run == run_id:
		SesYoneticisi.efekt(sound, volume_db)


func _level_complete(my_run: int) -> void:
	state = State.CELEBRATING
	var theme_id: String = Data.THEMES[theme_index]["id"]
	completed[theme_id] = maxi(completed.get(theme_id, 0), level_index + 1)
	_save_progress()

	await get_tree().create_timer(0.5).timeout
	if my_run != run_id:
		return
	for k in cards.size():
		cards[k].hop(k * 0.04)
	_show_cheer(tr(WORDS.pick_random()))
	SesYoneticisi.ezgi("kutlama")
	SesYoneticisi.efekt("konfeti", -4.0)
	_spawn_confetti(90)
	await get_tree().create_timer(celebration_time).timeout
	if my_run != run_id:
		return
	if level_index + 1 < Data.LEVELS.size():
		_start_level(level_index + 1)
	else:
		_show_level_select()


# --- Efektler ---

func _burst_stars(center: Vector2, card_size: Vector2) -> void:
	for k in 12:
		var sparkle := Sprite2D.new()
		sparkle.texture = TEX_STAR if k % 2 == 0 else TEX_SPARKLE
		sparkle.position = center
		var pixels := randf_range(26.0, 44.0)
		var end_scale := Vector2.ONE * pixels / sparkle.texture.get_width()
		sparkle.scale = end_scale * 0.2
		effects.add_child(sparkle)
		var angle := k * TAU / 12.0 + randf_range(-0.2, 0.2)
		var distance := card_size.x * randf_range(0.55, 0.95)
		var tween := sparkle.create_tween().set_parallel()
		tween.tween_property(sparkle, "position", center + Vector2.from_angle(angle) * distance, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "scale", end_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "rotation", randf_range(-3.0, 3.0), 0.8)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.35).set_delay(0.45)
		tween.chain().tween_callback(sparkle.queue_free)


func _show_cheer(word: String) -> void:
	for child in cheer.get_children():
		child.queue_free()
	cheer.visible = true
	for k in word.length():
		var letter := Label.new()
		letter.text = word[k]
		letter.add_theme_font_size_override("font_size", 112)
		letter.add_theme_color_override("font_color", RAINBOW[k % RAINBOW.size()])
		letter.add_theme_color_override("font_outline_color", Color("3b2a5a"))
		letter.add_theme_constant_override("outline_size", 26)
		letter.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.35, 0.35))
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 10)
		cheer.add_child(letter)
		letter.pivot_offset = letter.get_minimum_size() / 2.0
		letter.scale = Vector2.ZERO
		letter.rotation = randf_range(-0.4, 0.4)
		var tween := letter.create_tween()
		tween.tween_interval(k * 0.06)
		tween.tween_property(letter, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(letter, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Harfler sırayla hafifçe zıplamaya devam eder
		var bounce := letter.create_tween().set_loops()
		bounce.tween_interval(0.7 + k * 0.06)
		bounce.tween_property(letter, "scale", Vector2(1.12, 0.9), 0.12).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(letter, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		bounce.tween_interval(0.5)


# Konfeti: yukarıdan yağmur + alt köşelerden yukarı fırlayan iki konfeti topu
func _spawn_confetti(count: int) -> void:
	var screen := get_viewport_rect().size
	for k in count:
		_fall(_confetti_bit(), screen)
	for k in int(count / 8.0):
		var star := Sprite2D.new()
		star.texture = TEX_STAR
		star.scale = Vector2.ONE * randf_range(30.0, 50.0) / TEX_STAR.get_width()
		_fall(star, screen)
	for k in int(count / 3.0):
		var left := k % 2 == 0
		var start := Vector2(-10.0 if left else screen.x + 10.0, screen.y + 10.0)
		var velocity := Vector2(randf_range(200.0, 620.0) * (1.0 if left else -1.0), -randf_range(1150.0, 1600.0))
		_launch(_confetti_bit(), start, velocity, randf_range(0.0, 0.25))


func _confetti_bit() -> Polygon2D:
	var bit := Polygon2D.new()
	var w := randf_range(6.0, 10.0)
	var h := randf_range(10.0, 16.0)
	bit.polygon = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
	bit.color = RAINBOW.pick_random()
	# Havada dönüyormuş gibi yassılıp açılsın
	var spin := bit.create_tween().set_loops()
	var speed := randf_range(0.15, 0.3)
	spin.tween_property(bit, "scale:x", -1.0, speed).set_trans(Tween.TRANS_SINE)
	spin.tween_property(bit, "scale:x", 1.0, speed).set_trans(Tween.TRANS_SINE)
	return bit


func _fall(node: Node2D, screen: Vector2) -> void:
	node.position = Vector2(randf_range(0.0, screen.x), randf_range(-60.0, -10.0))
	node.rotation = randf() * TAU
	effects.add_child(node)
	var time := randf_range(2.2, 3.2)
	var delay := randf() * 0.3
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position", node.position + Vector2(randf_range(-140.0, 140.0), screen.y + 120.0), time).set_delay(delay)
	tween.tween_property(node, "rotation", node.rotation + randf_range(-6.0, 6.0), time).set_delay(delay)
	tween.chain().tween_callback(node.queue_free)


func _launch(node: Node2D, start: Vector2, velocity: Vector2, delay: float) -> void:
	node.position = start
	effects.add_child(node)
	var time := 3.2
	var tween := node.create_tween().set_parallel()
	tween.tween_method(_move_ballistic.bind(node, start, velocity), 0.0, time, time).set_delay(delay)
	tween.tween_property(node, "rotation", randf_range(-10.0, 10.0), time).set_delay(delay)
	tween.chain().tween_callback(node.queue_free)


# Yukarı atılan bir cismin yolu (yerçekimiyle yavaşlayıp geri düşer)
func _move_ballistic(t: float, node: Node2D, start: Vector2, velocity: Vector2) -> void:
	node.position = start + velocity * t + Vector2(0.0, 450.0) * t * t


# --- Arka plan: yavaş süzülen bulutlar ve kabarcıklar ---

func _create_floaters() -> void:
	var screen := get_viewport_rect().size
	for k in 5:
		var cloud := Sprite2D.new()
		cloud.texture = TEX_CLOUD
		var s := randf_range(0.8, 1.4) * 240.0 / TEX_CLOUD.get_width()
		cloud.scale = Vector2(s, s)
		cloud.modulate.a = randf_range(0.6, 0.9)
		cloud.position = Vector2(randf_range(0.0, screen.x), randf_range(60.0, screen.y * 0.8))
		cloud.set_meta("speed", Vector2(-randf_range(8.0, 18.0), 0.0))
		cloud.set_meta("phase", randf() * TAU)
		floaters.add_child(cloud)
	for k in 10:
		var bubble := Sprite2D.new()
		bubble.texture = TEX_BUBBLE
		var s := randf_range(24.0, 70.0) / TEX_BUBBLE.get_width()
		bubble.scale = Vector2(s, s)
		bubble.modulate.a = randf_range(0.35, 0.7)
		bubble.position = Vector2(randf_range(0.0, screen.x), randf_range(0.0, screen.y))
		bubble.set_meta("speed", Vector2(0.0, -randf_range(12.0, 28.0)))
		bubble.set_meta("phase", randf() * TAU)
		floaters.add_child(bubble)


func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	var time := Time.get_ticks_msec() / 1000.0
	for floater: Sprite2D in floaters.get_children():
		var speed: Vector2 = floater.get_meta("speed")
		var phase: float = floater.get_meta("phase")
		floater.position += speed * delta
		# Hafif dalgalanma
		floater.position += Vector2(cos(time * 0.8 + phase), sin(time * 0.6 + phase)) * 6.0 * delta
		var half := floater.texture.get_size() * floater.scale / 2.0
		if floater.position.x < -half.x:
			floater.position.x = screen.x + half.x
		if floater.position.y < -half.y:
			floater.position = Vector2(randf_range(0.0, screen.x), screen.y + half.y)


func _press(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(0.9, 0.9), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _shake(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	for angle in [0.08, -0.08, 0.05, -0.03, 0.0]:
		tween.tween_property(control, "rotation", angle, 0.06)


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for theme_data: Dictionary in Data.THEMES:
		completed[theme_data["id"]] = clampi(int(config.get_value("ilerleme", theme_data["id"], 0)), 0, Data.LEVELS.size())
	theme_index = clampi(int(config.get_value("ayar", "tema", 0)), 0, Data.THEMES.size() - 1)


func _save_progress() -> void:
	var config := ConfigFile.new()
	for theme_id in completed:
		config.set_value("ilerleme", theme_id, completed[theme_id])
	config.set_value("ayar", "tema", theme_index)
	GuvenliKayit.save_config(config, SAVE_PATH)
