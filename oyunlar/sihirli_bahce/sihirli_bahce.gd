extends Node2D
# Sihirli Bahçe ana sahnesi: katmanları ve parçaları kurar, dokunma/sürüklemeyi yönlendirir,
# hava olaylarını (yağmur, güneş, rüzgar, gece) parsellere uygular, toplama ve albümü yönetir,
# yazısız yol gösterir ve bahçeyi kaydeder. Tasarım TASARIM.md'de, notlar CLAUDE.md'de.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bir bitki su/güneş/ay beklerken ilgili hava düğmesinin nabız gibi atmaya başlaması için süre (sn)
@export var hint_delay: float = 3.0
## Toprak çizgisinin ekrandaki yüksekliği (parsellerin ortası)
@export var soil_y: float = 505.0

const Bitkiler := preload("res://oyunlar/sihirli_bahce/bitkiler.gd")
const Kayit := preload("res://oyunlar/sihirli_bahce/kayit.gd")
const Parsel := preload("res://oyunlar/sihirli_bahce/parsel.gd")
const ArkaPlan := preload("res://oyunlar/sihirli_bahce/arka_plan.gd")
const Canlilar := preload("res://oyunlar/sihirli_bahce/canlilar.gd")
const Efektler := preload("res://oyunlar/sihirli_bahce/efektler.gd")
const Hava := preload("res://oyunlar/sihirli_bahce/hava.gd")
const Album := preload("res://oyunlar/sihirli_bahce/album.gd")
const Sesler := preload("res://oyunlar/sihirli_bahce/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const G := "res://oyunlar/sihirli_bahce/gorseller/"
const PACK_SIZE := Vector2(98, 116)
const ICON_SIZE := 104.0

var plots: Array = []
var night := false
var album_data := {}
var hint_done := false

var _world: Node2D
var _background: Node2D
var _critters: Node2D
var _modulate: CanvasModulate
var _light: Node2D
var _effects: Node2D
var _ui: Control
var _weather: Control
var _album: Control
var _sounds: Node
var _packs: Array[TextureRect] = []
var _album_icon: TextureRect
var _back: Control
var _hand: TextureRect
var _rng := RandomNumberGenerator.new()
var _size := Vector2(1280, 720)

var _drag_index := -1                   # sürükleyen parmak
var _drag_kind := ""                    # "pack" ya da "cloud"
var _drag_pack := ""
var _floating: TextureRect
var _back_touch := -1
var _idle := {"cloud": 0.0, "sun": 0.0, "moon": 0.0}
var _save_timer := -1.0
var _hand_time := 0.0
var _busy_weather := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rng.randomize()
	_size = get_viewport_rect().size
	_build_layers()
	_build_ui()
	_load()
	var ipucu := IpucuEli.ekle(self, "sihirli_bahce", _ipucu)
	ipucu.engel = func() -> bool: return _hand.visible and _hand.modulate.a > 0.05   # oyunun ilk ekim eli


# İpucu eli, bahçenin durumuna göre sıradaki adım: sulama bekleyen bitkiye bulutu sürükle, güneş bekleyen
# varsa güneşe dokun, yoksa keseyi boş parsele sürükle
func _ipucu() -> Dictionary:
	if _album.is_busy() or _drag_index != -1:
		return {}
	for plot in plots:
		if plot.need == "water":
			return IpucuEli.surukle(_weather.center("cloud"), get_viewport().get_canvas_transform() * plot.plant_global_top() + Vector2(0.0, -40.0))
	for plot in plots:
		if plot.need == "sun":
			return IpucuEli.dokun(_weather.center("sun"))
	for plot in plots:
		if plot.is_empty():
			return IpucuEli.surukle(IpucuEli.ekran_konumu(_packs[0]), IpucuEli.ekran_konumu(plot, Vector2(0.0, -40.0)))
	return {}


# --- Kurulum ---

func _build_layers() -> void:
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_world = Node2D.new()
	add_child(_world)
	var light_layer := CanvasLayer.new()
	light_layer.layer = 1
	add_child(light_layer)
	_light = Node2D.new()
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	light_layer.add_child(_light)
	_effects = Efektler.new()
	_light.add_child(_effects)
	_sounds = Sesler.new()
	add_child(_sounds)

	_background = ArkaPlan.new()
	_world.add_child(_background)
	_background.setup(_modulate, _light, _effects)
	_critters = Canlilar.new()
	_world.add_child(_critters)
	_critters.setup(_effects, _light)
	_critters.flower_points = _flower_points
	_critters.sound.connect(_play)
	var plot_root := Node2D.new()
	_world.add_child(plot_root)
	# Uçtaki parseller çentiğin altında kalmasın: güvenli alan boşluğu büyükse parseller biraz sıklaşır
	var side := maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT), EkranYardimcisi.kenar_payi(SIDE_RIGHT))
	var spacing := minf(250.0, (_size.x - 100.0 - 2.0 * maxf(side - 60.0, 0.0)) / Kayit.PLOT_COUNT)
	for i in Kayit.PLOT_COUNT:
		var plot: Node2D = Parsel.new()
		plot.position = Vector2(_size.x * 0.5 + (i - 2) * spacing, soil_y)
		plot_root.add_child(plot)
		plot.setup(i, _light, _effects)
		plot.changed.connect(_mark_dirty)
		plot.harvested.connect(_on_harvested)
		plot.plant_event.connect(_on_plant_event)
		plot.sound.connect(_play)
		plots.append(plot)
	_world.add_child(_background.front)


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ui.size = _size
	ui_layer.add_child(_ui)
	_weather = Hava.new()
	_ui.add_child(_weather)
	# Tohum tepsisi: tahta raf ve üç kese
	var tray := Control.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.size = Vector2(PACK_SIZE.x * 3 + 140, 56)
	var bottom: float = EkranYardimcisi.guvenli_bosluklar()["alt"]      # alttaki hareket çubuğu
	tray.position = Vector2((_size.x - tray.size.x) * 0.5, _size.y - 48 - bottom)
	tray.draw.connect(func() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d8a060")
		style.set_corner_radius_all(24)
		style.set_border_width_all(5)
		style.border_color = Color("6e4418")
		style.shadow_color = Color(0.2, 0.1, 0.05, 0.25)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 5)
		tray.draw_style_box(style, Rect2(Vector2.ZERO, tray.size + Vector2(0, 30 + bottom)))
		tray.draw_line(Vector2(20, 14), Vector2(tray.size.x - 20, 14), Color(1, 1, 1, 0.35), 4.0, true))
	_ui.add_child(tray)
	for k in Bitkiler.PACKS.size():
		var pack := _texture_rect(load(G + "kese_%s.svg" % Bitkiler.PACKS[k]), PACK_SIZE)
		pack.position = Vector2(_size.x * 0.5 + (k - 1) * (PACK_SIZE.x + 34) - PACK_SIZE.x * 0.5, _size.y - PACK_SIZE.y - 10 - bottom)
		pack.set_meta("home", pack.position)
		_ui.add_child(pack)
		_packs.append(pack)
	_album_icon = _texture_rect(load(G + "kitap.svg"), Vector2(ICON_SIZE, ICON_SIZE))
	_album_icon.position = Vector2(_size.x - ICON_SIZE - 36, 22)
	_ui.add_child(_album_icon)
	EkranYardimcisi.guvenliye_it(_album_icon)
	_back = HoldButton.new()
	_back.size = Vector2(104, 104)
	_back.position = Vector2(36, 24)
	_back.hold_time = 0.6
	_back.completed.connect(_leave)
	_ui.add_child(_back)
	_hand = _texture_rect(load(G + "el.svg"), Vector2(110, 128))
	_hand.visible = false
	_ui.add_child(_hand)
	var screens := CanvasLayer.new()
	screens.layer = 10
	add_child(screens)
	_album = Album.new()
	_album.sounds = _sounds
	screens.add_child(_album)
	_album.celebration_finished.connect(_bounce_album_icon)


func _texture_rect(texture: Texture2D, box: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = box
	rect.pivot_offset = box / 2.0
	return rect


# --- Kayıt ---

func _load() -> void:
	var state := Kayit.load_state()
	album_data = state["album"]
	hint_done = state["hint_done"]
	night = state["night"]
	_background.set_night(night, false)
	_critters.set_night(night)
	_weather.set_night(night)
	for i in plots.size():
		plots[i].from_dict(state["plots"][i], night)
	_hand.visible = not hint_done


func _state() -> Dictionary:
	var list := []
	for plot in plots:
		list.append(plot.to_dict())
	return {"plots": list, "night": night, "album": album_data, "hint_done": hint_done}


func _mark_dirty() -> void:
	_save_timer = 0.5


func _save_now() -> void:
	_save_timer = -1.0
	Kayit.save_state(_state())


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE]:
		if _save_timer >= 0.0:
			_save_now()


func _leave() -> void:
	_save_now()
	SahneGecis.ana_menuye_don()


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _drag_index:
		_drag_to(drag.position)
		return
	if touch == null:
		return
	if not touch.pressed:
		if touch.index == _back_touch:
			_back.release()
			_back_touch = -1
		if touch.index == _drag_index:
			_drop(touch.position)
		return
	if SahneGecis.gecis_suruyor or _drag_index != -1:
		return
	_on_press(touch.index, touch.position)


func _on_press(index: int, p: Vector2) -> void:
	if _album.is_busy():
		_album.touch(p)
		return
	if _back.contains(p):
		_back_touch = index
		_back.press()
		return
	if _album_icon.get_global_rect().grow(8.0).has_point(p):
		_bounce(_album_icon)
		_play("tik")
		_album.open_album(album_data)
		return
	match _weather.hit(p):
		"cloud":
			_drag_index = index
			_drag_kind = "cloud"
			_weather.begin_drag(p)
			return
		"sun":
			_weather.press("sun")
			_sun()
			return
		"wind":
			_weather.press("wind")
			_wind()
			return
		"moon":
			_weather.press("moon")
			_set_night(not night)
			return
	for k in _packs.size():
		if _packs[k].get_global_rect().grow(8.0).has_point(p):
			_start_pack_drag(index, k, p)
			return
	for plot in plots:
		if plot.basket_contains(p):
			plot.harvest()
			return
	for plot in plots:
		if plot.frog_contains(p):
			plot.tap_frog()
			return
	if _critters.tap(p):
		return
	for plot in plots:
		if plot.plant_contains(p):
			plot.tap_plant(_weather.center("sun"))
			return


# --- Tohum kesesi sürükleme ---

func _start_pack_drag(index: int, k: int, p: Vector2) -> void:
	_drag_index = index
	_drag_kind = "pack"
	_drag_pack = Bitkiler.PACKS[k]
	_play("kese")
	_packs[k].modulate.a = 0.35
	_floating = _texture_rect(_packs[k].texture, PACK_SIZE * 1.12)
	_ui.add_child(_floating)
	_drag_to(p)
	_floating.scale = Vector2(0.9, 0.9)
	_floating.create_tween().tween_property(_floating, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drag_to(p: Vector2) -> void:
	if _drag_kind == "cloud":
		_weather.drag(p)
	elif _floating:
		_floating.position = p - _floating.size * Vector2(0.5, 0.8)
		_floating.rotation = sin(Time.get_ticks_msec() * 0.008) * 0.08
		for plot in plots:
			plot.modulate = Color(1.15, 1.15, 1.05) if plot.is_empty() and plot.contains(p) else Color.WHITE


func _drop(p: Vector2) -> void:
	var kind := _drag_kind
	_drag_index = -1
	_drag_kind = ""
	if kind == "cloud":
		_weather.end_drag()
		_sounds.set_rain(false)
		return
	var k := Bitkiler.PACKS.find(_drag_pack)
	var target: Node2D = null
	for plot in plots:
		plot.modulate = Color.WHITE
		if plot.is_empty() and plot.contains(p):
			target = plot
	var floating := _floating
	_floating = null
	if target:
		# Kese parselin üstünde eğilir, tohum düşer
		var id := Bitkiler.pick(_drag_pack, album_data, _rng)
		var tween := floating.create_tween()
		tween.tween_property(floating, "position", target.global_position + Vector2(-floating.size.x * 0.5, -floating.size.y - 40.0), 0.15)
		tween.tween_property(floating, "rotation", 0.6, 0.15).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func() -> void: target.plant_seed(id))
		tween.tween_property(floating, "modulate:a", 0.0, 0.25)
		tween.tween_callback(floating.queue_free)
		if not hint_done:
			hint_done = true
			_hand.visible = false
			_mark_dirty()
	else:
		var tween := floating.create_tween().set_parallel()
		tween.tween_property(floating, "position", _packs[k].get_meta("home"), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(floating, "rotation", 0.0, 0.3)
		tween.chain().tween_callback(floating.queue_free)
	var pack := _packs[k]
	pack.create_tween().tween_property(pack, "modulate:a", 1.0, 0.3).set_delay(0.2)


# --- Hava olayları ---

func _sun() -> void:
	if _busy_weather:
		return
	_idle["sun"] = 0.0
	if night:
		_busy_weather = true
		_set_night(false)
		await get_tree().create_timer(1.2).timeout
		_busy_weather = false
	_play("gunes")
	var sun_pos: Vector2 = _weather.center("sun") + Vector2(0, 40)
	var any := false
	for plot in plots:
		if plot.wants_sun():
			any = true
			_effects.sun_beam(sun_pos, plot.plant_global_top() + Vector2(0, 30))
			plot.shine()
	_effects.sparkles(sun_pos + Vector2(0, -30), Color("ffe27a"), 12, 60.0)
	if not any:
		for plot in plots:
			plot.gust(0.25)


func _wind() -> void:
	_play("ruzgar")
	_effects.leaf_gust(_size)
	_critters.breeze()
	for plot in plots:
		plot.gust(1.0)
	# Olgun bitkilerin tohumları boş parsellere uçar
	var empty: Array = plots.filter(func(p: Node2D) -> bool: return p.is_empty())
	var ripe: Array = plots.filter(func(p: Node2D) -> bool: return p.is_open())
	ripe.shuffle()
	for source in ripe:
		if empty.is_empty():
			break
		empty.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return absf(a.position.x - source.position.x) < absf(b.position.x - source.position.x))
		var target: Node2D = empty.pop_front()
		var id: String = source.plant_id
		_effects.fly_seed(source.plant_global_top() + Vector2(0, 30), target.global_position + Vector2(0, -12), func() -> void:
			if target.is_empty():
				target.plant_seed(id))


func _set_night(value: bool) -> void:
	night = value
	_idle["moon"] = 0.0
	_play("gece" if value else "gunduz")
	_background.set_night(value, true)
	_critters.set_night(value)
	_weather.set_night(value)
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		for plot in plots:
			plot.set_night(night))
	_mark_dirty()


# --- Toplama ---

func _on_harvested(id: String, from: Vector2) -> void:
	var first := int(album_data.get(id, 0)) == 0
	album_data[id] = int(album_data.get(id, 0)) + 1
	_mark_dirty()
	var to := _album_icon.get_global_rect().get_center()
	if first:
		_album.celebrate(id, from, to)
		return
	_play("topla")
	var flyer := Sprite2D.new()
	flyer.texture = Bitkiler.texture(id, 4)
	flyer.scale = Vector2.ONE * 150.0 / flyer.texture.get_height()
	flyer.position = from
	_ui.add_child(flyer)
	var tween := flyer.create_tween()
	tween.tween_property(flyer, "position", from + Vector2(0, -60), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flyer, "position", to, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(flyer, "scale", Vector2.ONE * 40.0 / flyer.texture.get_height(), 0.55)
	tween.tween_callback(flyer.queue_free)
	tween.tween_callback(_bounce_album_icon)


func _bounce_album_icon() -> void:
	_bounce(_album_icon)
	_effects.sparkles(_album_icon.get_global_rect().get_center(), Color("fff6b0"), 10, 40.0)


func _bounce(control: Control) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_plant_event(kind: String, pos: Vector2) -> void:
	if kind == "kelebekler":
		_critters.spawn_butterflies(pos, 3)


func _flower_points() -> Array:
	var points := []
	for plot in plots:
		if plot.is_open():
			points.append(plot.plant_global_top() + Vector2(0, 40))
	return points


func _play(sound: String) -> void:
	_sounds.play(sound)


# --- Her kare ---

func _process(delta: float) -> void:
	if _save_timer >= 0.0:
		_save_timer -= delta
		if _save_timer < 0.0:
			_save_now()
	# Bulut sürüklenirken altındaki parsele yağmur yağar
	if _drag_kind == "cloud":
		_sounds.set_rain(true)
		var x: float = _weather.rain_x()
		for plot in plots:
			if absf(plot.global_position.x - x) < Parsel.WIDTH * 0.5:
				plot.rain(delta)
	_update_hints(delta)


# Yazısız yol gösterme: ilk ekme için el; bekleyen bitki varsa ilgili hava düğmesi nabız gibi atar
func _update_hints(delta: float) -> void:
	var wants := {"cloud": false, "sun": false, "moon": false}
	for plot in plots:
		if plot.need == "water":
			wants["cloud"] = true
		elif plot.need == "sun":
			wants["sun"] = true
		if plot.is_mature() and Bitkiler.is_night(plot.plant_id) and not night:
			wants["moon"] = true
	for kind in wants:
		if wants[kind] and not (kind == "cloud" and _drag_kind == "cloud"):
			_idle[kind] += delta
		else:
			_idle[kind] = 0.0
		_weather.set_hint(kind, _idle[kind] > hint_delay)
	if _hand.visible:
		_hand_time += delta
		var target: Node2D = null
		for plot in plots:
			if plot.is_empty():
				target = plot
				break
		if target == null or _drag_kind == "pack" or _album.is_busy():
			_hand.modulate.a = 0.0
			return
		# El keseden parsele sürükler gibi gider, bir an durur, başa döner
		var t := fmod(_hand_time, 2.6)
		var start: Vector2 = _packs[0].get_global_rect().get_center() + Vector2(0, -10)
		var end: Vector2 = target.global_position + Vector2(0, -60)
		var k := smoothstep(0.4, 1.8, t)
		_hand.position = start.lerp(end, k) - Vector2(40, 10)
		_hand.modulate.a = smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(2.2, 2.6, t))
		_hand.scale = Vector2.ONE * (0.92 if t > 0.3 and t < 2.0 else 1.0)
