extends Node2D
# Araba Yarışı ana sahnesi: ekranlar arası akış (garaj → harita → yarış → podyum), yarışın durumu,
# dokunma (ekrana basılı tut = gaz), yıldız toplama ve kayıt. Tasarım ve dosyalar TASARIM.md'de.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Geri sayım ışıkları arasındaki süre (sn)
@export var countdown_step: float = 0.8
## Çocuk bu kadar süre ekrana dokunmazsa "basılı tut" eli çıkar (sn)
@export var hint_delay: float = 2.0
## Bitiş çizgisinden podyuma geçiş süresi (sn)
@export var podium_delay: float = 2.4
## İki rakibin taban hızı (en hızlının oranı); pistin "rivals" değeri eklenir
@export var rival_base: Array[float] = [0.83, 0.89]
## Yıldızın toplanma yarıçapı (px)
@export var star_radius: float = 82.0

const SAVE_PATH := "user://araba_yarisi.cfg"
const Pistler := preload("res://oyunlar/araba_yarisi/pistler.gd")
const PistScript := preload("res://oyunlar/araba_yarisi/pist.gd")
const Araba := preload("res://oyunlar/araba_yarisi/araba.gd")
const Gorunum := preload("res://oyunlar/araba_yarisi/araba_gorunum.gd")
const RakipZekasi := preload("res://oyunlar/araba_yarisi/rakip_zekasi.gd")
const CURTAIN := Color("2d2447")
const START_STAGGER := 190.0

enum Screen { GARAGE, MAP, RACE, PODIUM }
enum RaceState { COUNTDOWN, RACING, FINISHED }

@onready var _background: CanvasLayer = $Arkaplan
@onready var _world: Node2D = $Dunya
@onready var _track: Node2D = $Dunya/Pist
@onready var _cars_layer: Node2D = $Dunya/Arabalar
@onready var _stars_layer: Node2D = $Dunya/Yildizlar
@onready var _effects: Node2D = $Dunya/Efektler
@onready var _camera: Camera2D = $Dunya/Kamera
@onready var _hud_layer: CanvasLayer = $Arayuz
@onready var _hud: Control = $Arayuz/Yaris
@onready var _garage: Control = $Ekranlar/Garaj
@onready var _map: Control = $Ekranlar/Harita
@onready var _podium: Control = $Ekranlar/Podyum
@onready var _sounds: Node = $Sesler

var _screen := Screen.GARAGE
var _race_state := RaceState.COUNTDOWN
var _track_index := 0
var _unlocked := 1                  # açık pist sayısı
var _best: Array[int] = []          # her pistte en iyi yıldız (-1: bitirilmedi)
var _color := "kirmizi"
var _driver := 0
var _cars: Array[Node2D] = []       # 0: çocuk, 1-2: rakipler
var _ais: Array = []
var _touches := {}                  # gaz veren dokunuşlar (index -> true)
var _back_touch := -1
var _race_time := 0.0
var _countdown_time := 0.0
var _lights := 0
var _idle_time := 0.0
var _stars_taken := 0
var _finish_order: Array[Node2D] = []
var _finish_timer := 0.0
var _curtain: ColorRect
var _busy := false


func _ready() -> void:
	# Duraklatınca dünya durur; arayüz, ekranlar ve bu script çalışmaya devam eder
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background.process_mode = Node.PROCESS_MODE_PAUSABLE
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	for error in Pistler.validate(PistScript):
		push_error("Araba Yarışı: " + error)
	_load()
	_track.set_stars_layer(_stars_layer)
	_curtain = ColorRect.new()
	_curtain.color = CURTAIN
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.modulate.a = 0.0
	$Ekranlar.add_child(_curtain)
	for screen in [_garage, _map, _podium]:
		screen.sounds = _sounds
	_garage.play_pressed.connect(_transition.bind(_show_map))
	_garage.back_completed.connect(SahneGecis.ana_menuye_don)
	_garage.color_chosen.connect(func(color: String) -> void:
		_color = color
		_save())
	_garage.driver_chosen.connect(func(index: int) -> void:
		_driver = index
		_save())
	_map.track_chosen.connect(func(index: int) -> void: _transition(_start_race.bind(index)))
	_map.back_completed.connect(_transition.bind(_show_garage))
	_podium.next_pressed.connect(_on_next)
	_podium.retry_pressed.connect(func() -> void: _transition(_start_race.bind(_track_index)))
	_podium.back_completed.connect(_transition.bind(_show_map))
	_hud.back_completed.connect(_leave_race)
	_show_garage()
	var ipucu := IpucuEli.ekle(self, "araba_yarisi", _ipucu)
	ipucu.engel = func() -> bool: return _hud._hint.visible   # yarışın kendi "basılı tut" eli görünürken çekilir
	OyunBitti.kisayol(self, func() -> void:
		if _screen == Screen.RACE and _race_state == RaceState.RACING:
			_on_finish(_cars[0]))
	if OyunBitti.tamamlandi_mi("araba_yarisi"):
		_oyun_bitti(true)


# Son pist bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı. Bölüm seç → kendi pist haritası
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "araba_yarisi", "karakter": load("res://oyunlar/araba_yarisi/gorseller/araba_%s.svg" % _color),
		"bolum_sayisi": Pistler.TRACKS.size(), "kisa": kisa,
		"bolum_secme_ekrani": _transition.bind(_show_map), "bastan": _transition.bind(_start_race.bind(0)),
	})


# İpucu eli: yarışta ekrana basılı tut (araba hızlanır)
func _ipucu() -> Dictionary:
	if _screen != Screen.RACE or _race_state != RaceState.RACING or get_tree().paused:
		return {}
	return IpucuEli.basili_tut(get_viewport().get_visible_rect().get_center() + Vector2(0.0, 60.0), 1.4)


# --- Ekranlar ---

# Ekranlar arası kısa kararma: perde kapanınca action çalışır
func _transition(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(action)
	tween.tween_interval(0.05)
	tween.tween_property(_curtain, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _busy = false)


func _hide_all() -> void:
	get_tree().paused = false
	_set_race_visible(false)
	_garage.visible = false
	_map.visible = false
	_podium.hide_screen()
	_sounds.engine_stop()
	_touches.clear()


func _show_garage() -> void:
	_hide_all()
	_screen = Screen.GARAGE
	_garage.show_garage(_color, _driver)


func _show_map() -> void:
	_hide_all()
	_screen = Screen.MAP
	_map.show_map(_unlocked, _best, _color, _driver)


func _set_race_visible(value: bool) -> void:
	_world.visible = value
	_background.visible = value
	_background.set_weather_visible(value)
	_hud_layer.visible = value


func _on_next() -> void:
	if _track_index + 1 < Pistler.TRACKS.size():
		_transition(_start_race.bind(_track_index + 1))
	else:
		_transition(_show_map)


func _leave_race() -> void:
	_transition(_show_map)


# --- Yarış kurulumu ---

func _start_race(index: int) -> void:
	_hide_all()
	_screen = Screen.RACE
	_track_index = index
	_track.build(index)
	var theme_name: String = Pistler.TRACKS[index]["theme"]
	_background.set_theme(theme_name)
	for car in _cars:
		car.queue_free()
	_cars.clear()
	var looks := [{"color": _color, "driver": _driver}]
	looks.append_array(_rival_looks())
	# Arkadaki şeritler önce eklenir (önde çocuğun arabası çizilsin)
	var created := {}
	for lane in [2, 1, 0]:
		var car: Node2D = Araba.new()
		_cars_layer.add_child(car)
		# Rakipler biraz önden başlar (yan görünümde üst üste binmesinler)
		car.setup(_track, lane, looks[lane]["color"], looks[lane]["driver"], _track.start_s + lane * START_STAGGER)
		car.exhaust = _effects.make_exhaust()
		car.add_child(car.exhaust)
		car.move_child(car.exhaust, 0)
		car.jumped.connect(_on_jumped)
		car.landed.connect(_on_landed)
		car.splashed.connect(_on_splashed)
		car.bumped.connect(_on_bumped)
		car.crossed_finish.connect(_on_finish)
		created[lane] = car
	for lane in 3:
		_cars.append(created[lane])
	var bonus: float = Pistler.TRACKS[index]["rivals"]
	_ais = [RakipZekasi.new(rival_base[0] + bonus, 0.0, 34.0), RakipZekasi.new(rival_base[1] + bonus, 2.4, 27.0)]
	_hud.setup_race(looks)
	_set_race_visible(true)
	_camera.snap_to(_cars[0])
	_background.start(_camera.position)
	_race_state = RaceState.COUNTDOWN
	_race_time = 0.0
	_countdown_time = 0.0
	_lights = 0
	_idle_time = 0.0
	_stars_taken = 0
	_finish_order.clear()
	_back_touch = -1
	_sounds.engine_start()


# Rakiplerin rengi ve şoförü çocuğunkilerden farklı; piste göre değişir
func _rival_looks() -> Array:
	var colors: Array = Gorunum.COLOR_NAMES.filter(func(c: String) -> bool: return c != _color)
	var drivers: Array = range(Gorunum.DRIVERS.size()).filter(func(d: int) -> bool: return d != _driver)
	var k := _track_index
	return [
		{"color": colors[(k * 2) % colors.size()], "driver": drivers[(k * 3) % drivers.size()]},
		{"color": colors[(k * 2 + 2) % colors.size()], "driver": drivers[(k * 3 + 4) % drivers.size()]},
	]


# --- Yarış döngüsü ---

func _process(delta: float) -> void:
	if _screen != Screen.RACE:
		return
	if get_tree().paused:
		_sounds.engine_update(0.0, false, delta)
		return
	var player := _cars[0]
	var holding := not _touches.is_empty()
	match _race_state:
		RaceState.COUNTDOWN:
			_countdown(delta)
			player.throttle = holding
			player.exhaust.emitting = holding
		_:
			_race(delta, holding)
	_camera.follow(player, _track.lane_y_at_x(player.position.x, player.lane_offset), delta)
	_background.scroll(_camera.position, delta)
	for i in _cars.size():
		_hud.place_marker(i, _track.progress(_cars[i].s), _cars[i].speed * delta)
	var revving := 0.25 if (_race_state == RaceState.COUNTDOWN and holding) else 0.0
	_sounds.engine_update(maxf(player.speed_ratio(), revving), player.throttle, delta)


func _countdown(delta: float) -> void:
	_countdown_time += delta
	var lights := clampi(int((_countdown_time - 0.5) / countdown_step) + 1, 0, 3)
	if lights > _lights:
		_lights = lights
		_hud.countdown_light(lights)
		_sounds.play("basla" if lights == 3 else "bip")
		if lights == 3:
			_race_state = RaceState.RACING
			_hud.hide_countdown()


func _race(delta: float, holding: bool) -> void:
	_race_time += delta
	var player := _cars[0]
	player.target_speed = Araba.MAX_SPEED if holding and not player.finished else 0.0
	player.throttle = holding and not player.finished
	for i in range(1, _cars.size()):
		var car := _cars[i]
		if car.finished:
			car.target_speed = 0.0
		else:
			var progress: float = _track.progress(car.s)
			car.target_speed = _ais[i - 1].target_speed(car.s, player.s, player.speed, progress, _race_time, player.finished)
		car.throttle = car.target_speed > car.speed + 5.0
	for car in _cars:
		car.step(delta)
	_collect_stars(player)
	# Uzun süre dokunulmazsa ekrana basılı tutan el belirir
	if holding or player.finished:
		_idle_time = 0.0
		_hud.show_hint(false)
	else:
		_idle_time += delta
		if _idle_time > hint_delay and player.speed < Araba.MAX_SPEED * 0.35:
			_hud.show_hint(true)
	if _race_state == RaceState.FINISHED:
		_finish_timer -= delta
		if _finish_timer <= 0.0:
			_show_podium()


func _collect_stars(player: Node2D) -> void:
	var center: Vector2 = player.body_center()
	for star in _track.stars:
		if star["taken"]:
			continue
		var node: Node2D = star["node"]
		if absf(node.position.x - center.x) > star_radius or node.position.distance_to(center) > star_radius:
			continue
		star["taken"] = true
		_effects.star_burst(node.position)
		_sounds.play("yildiz", randf_range(0.95, 1.08))
		var screen_pos := get_viewport().get_canvas_transform() * node.position
		var tween := node.create_tween()
		tween.tween_property(node, "scale", Vector2(1.25, 1.25), 0.1)
		tween.parallel().tween_property(node, "modulate:a", 0.0, 0.1)
		tween.tween_callback(node.hide)
		_stars_taken += 1
		var count := _stars_taken
		_hud.fly_star(screen_pos, func() -> void: _hud.set_stars(count, true))


# --- Araba olayları ---

func _near_player(car: Node2D) -> bool:
	return absf(car.position.x - _cars[0].position.x) < 900.0


func _dust_color() -> Color:
	return _track.theme["ground"][0].lerp(Color.WHITE, 0.45)


func _on_jumped(car: Node2D) -> void:
	if car == _cars[0]:
		_sounds.play("zipla")


func _on_landed(car: Node2D) -> void:
	_effects.dust(car.position, _dust_color(), 9)
	if car == _cars[0]:
		_sounds.play("inis")


func _on_splashed(car: Node2D) -> void:
	_effects.splash(car.position + Vector2(0, -10), _track.theme["puddle"])
	if _near_player(car):
		_sounds.play("su", randf_range(0.95, 1.1))


func _on_bumped(car: Node2D) -> void:
	_effects.dust(car.position, _dust_color(), 5)
	if _near_player(car):
		_sounds.play("kasis", randf_range(0.95, 1.1))


func _on_finish(car: Node2D) -> void:
	_finish_order.append(car)
	if car != _cars[0]:
		return
	_race_state = RaceState.FINISHED
	_finish_timer = podium_delay
	_hud.show_hint(false)
	_sounds.play("bitis")
	var at: Vector2 = _track.finish_position()
	_effects.confetti(at + Vector2(0, -20))
	_effects.confetti(at + Vector2(160, -40))


func _show_podium() -> void:
	# Sıra: bitirenler bitiriş sırasıyla, diğerleri yolda ne kadar ilerideyse
	var order: Array[Node2D] = _finish_order.duplicate()
	var rest: Array[Node2D] = []
	for car in _cars:
		if not order.has(car):
			rest.append(car)
	rest.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.s > b.s)
	order.append_array(rest)
	var looks := []
	for car in order:
		looks.append({"color": car.view.color_name, "driver": car.view.driver_index, "player": car == _cars[0]})
	_save_result()
	var theme_name: String = Pistler.TRACKS[_track_index]["theme"]
	var has_next := _track_index + 1 < Pistler.TRACKS.size()
	_screen = Screen.PODIUM
	_transition(func() -> void:
		_hide_all()
		_screen = Screen.PODIUM
		_podium.show_results(looks, _stars_taken, theme_name, has_next))
	if not has_next:
		# Son pist: podyum biraz görünsün, sonra ortak final ekranı
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if _screen == Screen.PODIUM and not OyunBitti.acik:
				_oyun_bitti(false))


# --- Duraklatma ve dokunma ---

func _pause() -> void:
	get_tree().paused = true
	_hud.set_paused(true)
	_touches.clear()
	_sounds.engine_stop()


func _resume() -> void:
	get_tree().paused = false
	_hud.set_paused(false)
	_sounds.engine_start()


func _input(event: InputEvent) -> void:
	if _screen != Screen.RACE:
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if not touch.pressed:
		if touch.index == _back_touch:
			_hud.back.release()
			_back_touch = -1
		_touches.erase(touch.index)
		return
	if _busy or SahneGecis.gecis_suruyor:
		return
	match _hud.hit(touch.position):
		"back":
			_back_touch = touch.index
			_hud.back.press()
			return
		"pause":
			_sounds.play("tik")
			_pause()
			return
		"resume":
			_sounds.play("tik")
			_resume()
			return
		"retry":
			_sounds.play("tik")
			_transition(_start_race.bind(_track_index))
			return
		"paused":
			return
	_touches[touch.index] = true
	_idle_time = 0.0


func _notification(what: int) -> void:
	# Uygulama arka plana geçerse yarış duraklasın
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _screen == Screen.RACE and not get_tree().paused:
		_pause()


# --- Kayıt ---

func _load() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var count := Pistler.TRACKS.size()
	_unlocked = clampi(int(config.get_value("ilerleme", "acik", 1)), 1, count)
	_best.clear()
	for i in count:
		_best.append(int(config.get_value("yildiz", "pist_%d" % (i + 1), -1)))
	_color = str(config.get_value("garaj", "renk", "kirmizi"))
	if not Gorunum.COLORS.has(_color):
		_color = "kirmizi"
	_driver = clampi(int(config.get_value("garaj", "hayvan", 0)), 0, Gorunum.DRIVERS.size() - 1)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "acik", _unlocked)
	for i in _best.size():
		if _best[i] >= 0:
			config.set_value("yildiz", "pist_%d" % (i + 1), _best[i])
	config.set_value("garaj", "renk", _color)
	config.set_value("garaj", "hayvan", _driver)
	GuvenliKayit.save_config(config, SAVE_PATH)


# Yarış bitti: kaçıncı olursa olsun sonraki pist açılır, en iyi yıldız saklanır
func _save_result() -> void:
	_best[_track_index] = maxi(_best[_track_index], _stars_taken)
	_unlocked = clampi(maxi(_unlocked, _track_index + 2), 1, Pistler.TRACKS.size())
	_save()
