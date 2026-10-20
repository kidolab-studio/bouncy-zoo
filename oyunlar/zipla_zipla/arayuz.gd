extends Control
# GameHUD (UI CanvasLayer içinde): sol üstte ortak geri düğmesi, sağ üstte beyaz kutuda
# lolipop + ödül sayısı, sayaca uçan ödüller, başlangıçtaki "dokun" eli ve oyun bitti paneli
# (ödül, basamak ve rekor: simge + rakam, yazı yok). Dokunmayı ana sahne yönetir (contains / hit_* sorar).

const G := "res://oyunlar/zipla_zipla/gorseller/"
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const TEX_COUNTER: Texture2D = preload(G + "lolipop.svg")
const TEX_STEPS: Texture2D = preload(G + "basamak_ikon.svg")
const TEX_TROPHY: Texture2D = preload(G + "kupa.svg")
const TEX_REPLAY: Texture2D = preload(G + "tekrar.svg")
const TEX_HOME: Texture2D = preload(G + "ev.svg")
const TEX_HAND: Texture2D = preload(G + "el.svg")
const TEX_SPARKLE: Texture2D = preload(G + "isilti.svg")
const OUTLINE := Color("3b2a5a")
const INK := Color("3b2f6b")
const GOLD := Color("ffc928")
const SIDE := 56.0            # yatayda çentik yanlarda olabilir: kenarlardan biraz daha uzak
const TOP := 22.0

var back_button: HoldButton
var _counter: Panel
var _counter_icon: TextureRect
var _counter_label: Label
var _hand: TextureRect
var _hand_tween: Tween
var _over_layer: Control
var _over_panel: Panel
var _over_rewards: Label
var _over_steps: Label
var _over_best: Label
var _over_trophy: TextureRect
var _new_best_glow: TextureRect
var _replay: Panel
var _home: Panel
var _loops: Array[Tween] = []
var _flyers: Array[TextureRect] = []     # sayaca uçan ödül görselleri (tekrar kullanılır)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	back_button = HoldButton.new()
	_place(back_button, Vector4(0, 0, 0, 0), Vector4(SIDE, TOP, SIDE + 116, TOP + 116))

	_counter = _panel(Color(1, 1, 1, 0.96), 34)
	var right := EkranYardimcisi.kenar_payi(SIDE_RIGHT, SIDE)      # çentik sağdaysa sayaç içeri girer
	_place(_counter, Vector4(1, 0, 1, 0), Vector4(-right - 240, TOP + 10, -right, TOP + 106))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_counter_icon = _texture_rect(TEX_COUNTER)
	_counter_icon.custom_minimum_size = Vector2(72, 72)
	row.add_child(_counter_icon)
	_counter_label = _label(60, 0, INK)
	_counter_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(_counter_label)

	_hand = _texture_rect(TEX_HAND)
	_hand.size = Vector2(110, 110)
	_hand.pivot_offset = Vector2(40, 10)
	add_child(_hand)
	_hand.hide()

	_build_game_over()


# --- Yardımcılar (Köstebek arayüzüyle aynı düzen) ---

func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	if control.get_parent() == null:
		add_child(control)
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(font_size: int, outline: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", OUTLINE)
		label.add_theme_constant_override("outline_size", outline)
	return label


func _panel(color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(5)
	style.border_color = INK
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.15, 0.1, 0.3, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _round_button(icon: Texture2D, margin: int) -> Panel:
	var panel := _panel(Color(1, 1, 1, 0.97), 999)
	var rect := _texture_rect(icon)
	panel.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, margin)
	return panel


func _pop(control: Control, from: float) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * from
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _hit(control: Control, pos: Vector2) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().grow(16.0).has_point(pos)


# --- Sayaç ---

func set_count(count: int, animate: bool) -> void:
	_counter_label.text = str(count)
	if animate:
		_pop(_counter, 1.15)
		_counter_icon.pivot_offset = _counter_icon.size / 2.0
		var tween := _counter_icon.create_tween()
		tween.tween_property(_counter_icon, "position:y", _counter_icon.position.y - 14.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_counter_icon, "position:y", _counter_icon.position.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func counter_target() -> Vector2:
	return _counter_icon.get_global_rect().get_center()


# Ödülün kopyası dünyadaki yerinden sayaca uçar (kavis çizerek küçülür); varınca `arrived` çağrılır
func fly_reward(texture: Texture2D, from: Vector2, sparkle: Color, arrived: Callable) -> void:
	var flyer: TextureRect = null
	for candidate in _flyers:
		if not candidate.visible:
			flyer = candidate
			break
	if flyer == null:
		flyer = _texture_rect(texture)
		flyer.size = Vector2(80, 80)
		flyer.pivot_offset = flyer.size / 2.0
		add_child(flyer)
		_flyers.append(flyer)
	flyer.texture = texture
	flyer.show()
	flyer.scale = Vector2.ONE
	flyer.rotation = 0.0
	flyer.position = from - flyer.size / 2.0
	_sparkle_at(from, sparkle)
	var target := counter_target() - flyer.size / 2.0
	var start := from - flyer.size / 2.0
	var control := start + Vector2(-80.0, -160.0)
	# İkinci derece Bezier eğrisi: başlangıç -> kontrol noktası -> sayaç
	var fly := func(t: float) -> void:
		flyer.position = start.lerp(control, t).lerp(control.lerp(target, t), t)
		flyer.scale = Vector2.ONE * lerpf(1.4, 0.7, t)
		flyer.rotation = t * TAU * 0.5
	var tween := flyer.create_tween()
	tween.tween_property(flyer, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(fly, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(flyer.hide)
	tween.tween_callback(arrived)


func _sparkle_at(pos: Vector2, color: Color) -> void:
	for k in 6:
		var glint := _texture_rect(TEX_SPARKLE)
		glint.size = Vector2(40, 40)
		glint.position = pos - glint.size / 2.0
		glint.pivot_offset = glint.size / 2.0
		glint.modulate = color
		add_child(glint)
		var direction := Vector2.from_angle(TAU * k / 6.0 + randf_range(-0.3, 0.3))
		var tween := glint.create_tween()
		tween.tween_property(glint, "position", glint.position + direction * randf_range(50.0, 80.0), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(glint, "scale", Vector2(0.2, 0.2), 0.45)
		tween.parallel().tween_property(glint, "modulate:a", 0.0, 0.45)
		tween.tween_callback(glint.queue_free)


# --- Başlangıç ipucu: kurbağanın yanında dokunan el ---

func show_hint(at: Vector2) -> void:
	_hand.position = at
	_hand.show()
	_hand.modulate.a = 0.0
	if _hand_tween:
		_hand_tween.kill()
	_hand_tween = _hand.create_tween().set_loops()
	_hand_tween.tween_property(_hand, "modulate:a", 1.0, 0.3)
	_hand_tween.tween_property(_hand, "scale", Vector2(0.85, 0.85), 0.18).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(_hand, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_interval(0.5)


func hide_hint() -> void:
	if _hand_tween:
		_hand_tween.kill()
		_hand_tween = null
	var tween := _hand.create_tween()
	tween.tween_property(_hand, "modulate:a", 0.0, 0.15)
	tween.tween_callback(_hand.hide)


# --- Oyun bitti ---

func _stat_column(icon: Control, color: Color) -> Array:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size = Vector2(200, 0)
	icon.custom_minimum_size = Vector2(110, 110)
	column.add_child(icon)
	var label := _label(76, 20, color)
	column.add_child(label)
	return [column, label]


func _build_game_over() -> void:
	_over_layer = Control.new()
	_over_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_over_layer, Vector4(0, 0, 1, 1), Vector4.ZERO)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.22, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_over_panel = _panel(Color("fffaf0"), 60)
	_over_layer.add_child(_over_panel)
	_place(_over_panel, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-380, -270, 380, 270))

	# Üç sütun: ödül, basamak, rekor (simge + rakam)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 30)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_panel.add_child(stats)
	_place(stats, Vector4(0, 0, 1, 0), Vector4(20, 36, -20, 260))
	var rewards := _stat_column(_texture_rect(TEX_COUNTER), Color.WHITE)
	stats.add_child(rewards[0])
	_over_rewards = rewards[1]
	var steps := _stat_column(_texture_rect(TEX_STEPS), Color("8ee05a"))
	stats.add_child(steps[0])
	_over_steps = steps[1]
	var trophy_holder := Control.new()
	trophy_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var best := _stat_column(trophy_holder, GOLD)
	stats.add_child(best[0])
	_over_best = best[1]
	_new_best_glow = _texture_rect(TEX_SPARKLE)
	trophy_holder.add_child(_new_best_glow)
	_place(_new_best_glow, Vector4(0, 0, 1, 1), Vector4(-45, -45, 45, 45))
	_over_trophy = _texture_rect(TEX_TROPHY)
	trophy_holder.add_child(_over_trophy)
	_over_trophy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Düğmeler: küçük ev (ana menü) ve büyük "tekrar oyna"
	_home = _round_button(TEX_HOME, 26)
	_over_panel.add_child(_home)
	_place(_home, Vector4(0.5, 1, 0.5, 1), Vector4(-230, -196, -90, -56))
	_replay = _round_button(TEX_REPLAY, 36)
	_over_panel.add_child(_replay)
	_place(_replay, Vector4(0.5, 1, 0.5, 1), Vector4(-40, -236, 170, -26))
	_over_layer.visible = false


func show_game_over(rewards: int, steps: int, best: int, is_new_best: bool) -> void:
	_over_rewards.text = str(rewards)
	_over_steps.text = str(steps)
	_over_best.text = str(best)
	_new_best_glow.visible = is_new_best
	_over_layer.visible = true
	_over_layer.modulate.a = 0.0
	_over_layer.create_tween().tween_property(_over_layer, "modulate:a", 1.0, 0.25)
	_over_panel.pivot_offset = _over_panel.size / 2.0
	_over_panel.scale = Vector2(0.6, 0.6)
	_over_panel.create_tween().tween_property(_over_panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_new_best:
		_new_best_glow.pivot_offset = _new_best_glow.size / 2.0
		var spin := _new_best_glow.create_tween().set_loops()
		spin.tween_property(_new_best_glow, "rotation", TAU, 3.0).from(0.0)
		_loops.append(spin)
		_over_trophy.pivot_offset = _over_trophy.size / 2.0
		var bounce := _over_trophy.create_tween().set_loops()
		bounce.tween_property(_over_trophy, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(_over_trophy, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
		_loops.append(bounce)
	# "Tekrar oyna" düğmesi hafifçe nabız gibi atar
	_replay.pivot_offset = _replay.size / 2.0
	var pulse := _replay.create_tween().set_loops()
	pulse.tween_interval(0.6)
	pulse.tween_property(_replay, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_replay, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_loops.append(pulse)


func hide_game_over() -> void:
	for loop in _loops:
		loop.kill()
	_loops.clear()
	_over_trophy.scale = Vector2.ONE
	_replay.scale = Vector2.ONE
	var tween := _over_layer.create_tween()
	tween.tween_property(_over_layer, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_over_layer.hide)


func is_game_over_visible() -> bool:
	return _over_layer.visible


func hit_replay(pos: Vector2) -> bool:
	return _hit(_replay, pos)


func hit_home(pos: Vector2) -> bool:
	return _hit(_home, pos)


func press(control_name: String) -> void:
	var control := _replay if control_name == "replay" else _home
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(0.88, 0.88), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
