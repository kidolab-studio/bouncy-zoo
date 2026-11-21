extends Control
# Hayvan Banyosu (BathGame): 3-6 yaş, yatay ekran, hiç yazı yok. Küvette çamura bulanmış bir hayvan durur;
# sağdaki raftan sırası gelen aleti tutup hayvanın üstüne sürükler: süngerle çamuru köpürtür, duşla köpüğü
# durular, havluyla kurular. Her leke (leke.gd) sırayla çamur → köpük → ıslak → temiz olur. Üç adım bitince
# hayvan silkinir, sevinir; sonraki hayvan gelir. 10 hayvandan (bölüm) sonra ortak final ekranı (OyunBitti).
# Skor, süre, can yok; sırası gelmeyen alete dokununca alet sadece kıpırdar.
#
# Ayarlar ayarlar.gd'de. Dokunmayı bu script okur: aynı anda tek parmak alet tutar (ikinci parmak yok sayılır),
# geri düğmesine düşen dokunuş düğmeye gider.

const Animal := preload("res://oyunlar/hayvan_banyosu/hayvan.gd")
const Spot := preload("res://oyunlar/hayvan_banyosu/leke.gd")
const Tool := preload("res://oyunlar/hayvan_banyosu/alet.gd")
const Tray := preload("res://oyunlar/hayvan_banyosu/alet_rafi.gd")
const Background := preload("res://oyunlar/hayvan_banyosu/arka_plan.gd")
const Bubbles := preload("res://oyunlar/hayvan_banyosu/kabarciklar.gd")
const Effects := preload("res://oyunlar/hayvan_banyosu/efektler.gd")
const Stars := preload("res://oyunlar/hayvan_banyosu/yildizlar.gd")
const Sounds := preload("res://oyunlar/hayvan_banyosu/sesler.gd")
const Settings := preload("res://oyunlar/hayvan_banyosu/ayarlar.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/hayvan_banyosu/gorseller/kart_kopek.svg")
const SAVE_PATH := "user://hayvan_banyosu.cfg"

## Duş parmak dururken de akar: saniyede bu kadar piksel sürtmeye eşit
const SHOWER_FLOW := 260.0
## Bir harekette en fazla bu kadar yol sayılır (parmak sıçrarsa leke birden bitmesin)
const MAX_STEP := 90.0

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@onready var background: Background = $Background
@onready var animal_layer: Node2D = $Animal
@onready var tub_front: Sprite2D = $TubFront
@onready var bubbles: Bubbles = $Bubbles
@onready var effects: Effects = $Effects
@onready var stars: Stars = $Stars
@onready var tray: Tray = $Tray
@onready var tool: Tool = $Tool
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds

var state: State = State.TRANSITION
var level_index: int = 0
var step: int = 0                     # 0 sünger, 1 duş, 2 havlu (ayarlar.gd STEPS)
var animal: Animal
var animal_size: float = 400.0
var water: Vector2                    # suyun merkezi (küvetin ortası)
var tub_width: float = 780.0
var idle_time: float = 0.0
var run_id: int = 0                   # bölüm değişince eski beklemeler devam etmesin

var _finger: int = -1
var _last_point: Vector2
var _moved: float = 0.0               # son karede parmağın aldığı yol (döngü sesi için)
var _step_busy: bool = false          # adım değişiyor: kısa süre sürtme sayılmaz
var _giggle_wait: float = 0.0
var _bubble_wait: float = 0.0


func _ready() -> void:
	_load_progress()
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	stars.setup(Settings.level_count())
	_layout()
	EkranYardimcisi.degisince(_layout)
	get_viewport().size_changed.connect(_layout)
	_start_level(level_index)
	IpucuEli.ekle(self, "hayvan_banyosu", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			_finish_level())
	if OyunBitti.tamamlandi_mi("hayvan_banyosu"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "hayvan_banyosu", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.level_count(), "kisa": kisa,
		"bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if not await _clear_level():
		return
	stars.setup(Settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: sırası gelen aleti raftan alıp bu adımın ilk lekesine sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or _step_busy or _finger != -1 or animal == null:
		return {}
	for spot in animal.spots:
		if spot.needs(step):
			return IpucuEli.surukle(tray.slot_position(step), IpucuEli.izle(spot))
	return {}


# --- Yerleşim ---

# Küvet ve hayvan tasarım alanının ortasında, altta; arka plan ekranın tamamını kaplar; alet rafı sağda
func _layout() -> void:
	var screen := get_viewport_rect().size
	var area := EkranYardimcisi.tasarim_alani()
	animal_size = clampf(area.size.y * 0.56, 260.0, 420.0)
	tub_width = animal_size * 1.95
	var k := tub_width / Background.TUB_WIDTH
	water = Vector2(area.get_center().x, area.end.y - 8.0 - (Background.TUB_HEIGHT - Background.TUB_WATER.y) * k)
	background.layout(screen, water.x, water.y, tub_width)
	Background.place_front(tub_front, water.x, water.y, tub_width)
	bubbles.source = Rect2(water.x - tub_width * 0.36, water.y - 12.0, tub_width * 0.72, 20.0)
	bubbles.bubble_size = animal_size * 0.13
	if animal:
		animal.position = _feet()
		animal.scale = Vector2.ONE * animal_size / animal.size
	tool.set_width(animal_size * 0.42)
	var r := clampf(animal_size * 0.16, 54.0, 70.0)
	tray.layout(Vector2(screen.x - EkranYardimcisi.kenar_payi(SIDE_RIGHT, 40.0) - r - 14.0, area.get_center().y + 30.0), r)
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 560.0)
	stars.layout(Vector2(maxf(screen.x / 2.0, stars_left + stars_width / 2.0), back_button.position.y + back_button.size.y / 2.0), stars_width)


# Hayvanın ayaklarının yeri: suyun çizgisi gövdenin alt kısmında kalacak kadar aşağıda
func _feet() -> Vector2:
	return water + Vector2(0.0, animal_size * 0.02)


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	if OyunBitti.acik or SahneGecis.gecis_suruyor:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if back_button.handle_touch(touch):
			return
		if touch.pressed:
			if _finger == -1:
				_touch_down(touch.index, touch.position)
		elif touch.index == _finger:
			_touch_up()
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _finger:
		_touch_move(drag.position)


# Raftaki sırası gelen alet tutulur; sırası gelmeyen alet kıpırdar; başka yere dokunmak kabarcık patlatır
func _touch_down(index: int, point: Vector2) -> void:
	idle_time = 0.0
	var slot := tray.slot_at(point)
	if slot == -1:
		_pop_bubbles(point, animal_size * 0.08)
		return
	if slot != step or state != State.PLAYING or _step_busy:
		tray.wiggle(slot)
		return
	_finger = index
	_last_point = point
	tool.set_kind(step)
	tool.begin(point, tray.slot_position(step), tray.icon_width())
	tray.empty_slot = step
	sounds.play("pop", randf_range(0.95, 1.1))
	_apply(point, 0.0)


func _touch_move(point: Vector2) -> void:
	var distance := minf(point.distance_to(_last_point), MAX_STEP)
	_last_point = point
	idle_time = 0.0
	_moved += distance
	tool.move(point)
	_apply(point, distance)


# Parmak kalktı (ya da adım bitti): alet rafa uçar
func _touch_up() -> void:
	_finger = -1
	var kind := tool.kind
	tool.return_to(tray.slot_position(kind), tray.icon_width(), tray.show_slot.bind(kind))
	if is_instance_valid(animal):
		animal.unwatch()


func _pop_bubbles(point: Vector2, radius: float) -> void:
	for p in bubbles.pop_near(point, radius):
		sounds.play("kabarcik", randf_range(0.9, 1.3))
		effects.sparkle(p, animal_size * 0.2)


# Uygulama arka plana giderse ya da pencere odağı kaybolursa parmak bırakılmış sayılır
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if _finger != -1:
			_touch_up()


# Alet bu noktada distance kadar sürtüldü: kabarcıklar patlar, hayvan tepki verir, bu adımın lekeleri temizlenir
func _apply(point: Vector2, distance: float) -> void:
	_pop_bubbles(point, tool.width * 0.3)
	if not is_instance_valid(animal):
		return
	animal.watch(point)
	if state != State.PLAYING or _step_busy or distance <= 0.0:
		return
	if animal.contains(point):
		if step == 1:
			animal.squint()
		else:
			animal.tickle()
			if _giggle_wait <= 0.0:
				_giggle_wait = randf_range(2.5, 4.0)
				sounds.play("kikir", randf_range(0.95, 1.15))
		if step == 0 and _bubble_wait <= 0.0:
			_bubble_wait = 0.15
			effects.bubbles(point, animal_size)
	for spot in animal.spots:
		if spot.needs(step) and spot.hit(point, Settings.HIT_RADIUS):
			var path := Settings.SPOT_RADIUS * spot.global_scale.x * Settings.RUB_PATH
			if spot.rub(distance / path):
				_spot_done(spot)
	if _step_complete():
		_finish_step()


func _spot_done(spot: Spot) -> void:
	var done := 0
	for s in animal.spots:
		if not s.needs(step):
			done += 1
	var p := spot.global_position
	match step:
		0:
			sounds.play("kopur", pow(1.06, done))
			effects.bubbles(p, animal_size, 6)
		1:
			sounds.play("pop", pow(1.06, done))
			effects.drops(p, animal_size * 0.4, 6)
		2:
			sounds.play("temiz", pow(1.122, done - 1))
			effects.sparkle(p, animal_size * 0.5)


func _step_complete() -> bool:
	for spot in animal.spots:
		if spot.needs(step):
			return false
	return true


# Adım bitti: parmaktaki alet rafa döner, sıradaki alet parlar; üç adım bitince bölüm biter
func _finish_step() -> void:
	step += 1
	tray.advance()
	if _finger != -1:
		_touch_up()
	if step >= Settings.STEPS.size():
		_finish_level()
		return
	var my_run := run_id
	_step_busy = true
	sounds.play("adim")
	animal.hop()
	await get_tree().create_timer(0.5).timeout
	if my_run != run_id:
		return
	_step_busy = false


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	level_index = index
	step = 0
	idle_time = 0.0
	_step_busy = false
	_save_progress()
	stars.set_current(index)
	var data := Settings.animal(index)
	sounds.set_voice(data)
	animal = Animal.new()
	animal_layer.add_child(animal)
	animal.setup(data, animal_size)
	animal.position = _feet()
	animal.add_spots(Settings.SPOTS[index])
	animal.appear(0.15)
	tray.reset()
	bubbles.enabled = true
	# Suya değdiği an sıçrama
	await get_tree().create_timer(0.5).timeout
	if my_run != run_id:
		return
	effects.drops(water, animal_size, 16, Vector2.UP, 50.0)
	sounds.play("kopur", 0.7)
	await get_tree().create_timer(0.35).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


# Hayvan yıkandı: silkinir (damlalar saçılır), sevinir; yıldız dolar, kutlama, sonraki hayvan
func _finish_level() -> void:
	var my_run := run_id
	state = State.CELEBRATING
	_step_busy = false
	for spot in animal.spots:
		spot.state = Spot.State.CLEAN       # F9 kısayolu adımları atlarsa
	tray.hide_tray()
	await get_tree().create_timer(0.35).timeout
	if my_run != run_id:
		return
	animal.shake_dry()
	sounds.play("silkin")
	effects.drops(animal.center_global(), animal_size, 26)
	await get_tree().create_timer(0.75).timeout
	if my_run != run_id:
		return
	sounds.play("ses", randf_range(0.98, 1.06))
	effects.hearts(animal.head_top_global(), animal_size)
	animal.hop()
	stars.complete(level_index)
	await get_tree().create_timer(0.6).timeout
	if my_run != run_id:
		return
	if level_index >= Settings.level_count() - 1:
		_finale()
		return
	sounds.play("bolum_sonu")
	effects.confetti(90)
	animal.dance(0.0, 4)
	await get_tree().create_timer(Settings.CELEBRATION_TIME).timeout
	if my_run != run_id:
		return
	if not await _clear_level():
		return
	_start_level(level_index + 1)


# Son hayvan da yıkandı: büyük kutlama, sonra ortak final ekranı (bölüm seç / baştan oyna / ana menü)
func _finale() -> void:
	var my_run := run_id
	sounds.play("final")
	effects.finale(animal_size)
	stars.celebrate_all()
	animal.dance(0.0, 8)
	await get_tree().create_timer(Settings.FINALE_TIME).timeout
	if my_run != run_id:
		return
	if not await _clear_level():
		return
	_oyun_bitti(false)


# Hayvan gider; eski beklemeler durur. Beklerken başka bir akış başlamadıysa true döner.
func _clear_level() -> bool:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	_step_busy = false
	if _finger != -1:
		_touch_up()
	if is_instance_valid(animal):
		animal.leave(0.0)
	animal = null
	tray.hide_tray()
	bubbles.enabled = false
	await get_tree().create_timer(0.5).timeout
	return my_run == run_id


# --- Her kare: duş akışı, döngü sesi, ipucu ---

func _process(delta: float) -> void:
	_giggle_wait -= delta
	_bubble_wait -= delta
	# Duş parmak dururken de akar
	if _finger != -1 and step == 1:
		_apply(_last_point, delta * SHOWER_FLOW)
	# Sünger / duş / havlu sesi: parmak hareket ettikçe (duş basılıyken hep)
	var level := 0.0
	if _finger != -1:
		level = clampf(_moved / maxf(delta, 0.001) / 900.0, 0.0, 1.0)
		if tool.kind == 1:
			level = maxf(level, 0.7)
	_moved = 0.0
	sounds.set_loop(Settings.STEPS[tool.kind] if level > 0.0 else "", level, delta)
	# Uzun süre dokunulmazsa sırası gelen alet kıpırdar, bu adımın lekeleri parlar
	if state == State.PLAYING and _finger == -1 and animal:
		idle_time += delta
		if idle_time >= Settings.HINT_DELAY:
			idle_time = 0.0
			tray.wiggle(step)
			for spot in animal.spots:
				if spot.needs(step):
					spot.pulse()


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level_index = clampi(int(config.get_value("ilerleme", "bolum", 0)), 0, Settings.level_count() - 1)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "bolum", level_index)
	GuvenliKayit.save_config(config, SAVE_PATH)
