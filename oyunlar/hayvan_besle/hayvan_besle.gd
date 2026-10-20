extends Control
# Hayvanları Besle (FeedGame): 2-5 yaş, yatay ekran, hiç yazı yok. Üstte aç hayvanlar, altta masada
# yiyecekler; çocuk her yiyeceği onu yiyen hayvana sürükler. Doğru hayvan yer ve doyar, yanlış hayvan
# kibarca reddeder, boşluğa bırakılan yiyecek sessizce yerine döner. Skor, süre, can yok.
# Hepsi doyunca hayvanlar dans eder ve sonraki bölüme geçilir; son bölümden sonra büyük kutlama ve 1. bölüm.
#
# Bölümler ayarlar.tres'te (FeedSettings), bölümü bolum_uretici.gd (FeedLevelGenerator) üretir.
# Dokunmayı ortak DragInput (ortak/surukleme_girdisi.gd) okur: aynı anda tek parmak bir yiyecek tutar.

signal level_completed(index: int)
signal all_levels_completed

const Animal := preload("res://oyunlar/hayvan_besle/hayvan.gd")
const Food := preload("res://oyunlar/hayvan_besle/yiyecek.gd")
const Background := preload("res://oyunlar/hayvan_besle/arka_plan.gd")
const Effects := preload("res://oyunlar/hayvan_besle/efektler.gd")
const Stars := preload("res://oyunlar/hayvan_besle/yildizlar.gd")
const Sounds := preload("res://oyunlar/hayvan_besle/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const TEX_PLATE: Texture2D = preload("res://oyunlar/hayvan_besle/gorseller/tabak.svg")
const SAVE_PATH := "user://hayvan_besle.cfg"

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bölüm ayarları: aşamalar (bölüm tablosu) ve hayvanlar. Tek yer: ayarlar.tres
@export var settings: FeedSettings

@export_group("Oynanış")
## Bırakma toleransı: hayvanın bırakma alanı (gövde + baş) bu oran kadar daha geniştir.
@export_range(0.0, 1.0) var drop_tolerance: float = 0.35
## Yakalama alanı, yiyecek görselinin bu kadar katı (1'den büyük: görselin biraz dışından da tutulur).
@export_range(1.0, 1.8) var grab_padding: float = 1.35
## Bu kadar saniye hiçbir şey yapılmazsa ipucu: gizli balonlar belirir ya da gereken yiyecek kıpırdar.
@export var hint_delay: float = 8.0
## İpucu olarak (ya da hayvana dokununca) belirten balonun görünme süresi.
@export var bubble_hint_time: float = 3.0
## Basılı tutunca geri dönme süresi (saniye).
@export var hold_to_exit: float = 0.6

@export_group("Görünüm ve animasyon")
## Sürüklerken yiyeceğin büyüme oranı.
@export var drag_scale: float = 1.2
## Sürüklerken yiyecek parmağın ne kadar üstünde dursun (yiyecek boyuna oran).
@export var drag_lift: float = 0.45
## Yiyeceğin yerine dönme süresi.
@export var return_time: float = 0.45
## Bölüm sonu dansının süresi (sonra kendiliğinden sonraki bölüm).
@export var celebration_time: float = 2.6
## Son bölümden sonraki büyük kutlamanın süresi.
@export var finale_time: float = 5.5

const TOP_BAR := 100.0           # üstte geri düğmesi ve yıldızlar
const SIDE_LEFT := 70.0          # hayvan ve tabak dizisinin kenar boşlukları (solda geri düğmesi var)
const SIDE_RIGHT := 40.0
const MAX_ANIMAL := 300.0
const MAX_FOOD := 150.0

@onready var background: Background = $Background
@onready var animals_layer: Node2D = $Animals
@onready var table: Node2D = $Table
@onready var plates_layer: Node2D = $Plates
@onready var foods_layer: Node2D = $Foods
@onready var effects: Effects = $Effects
@onready var stars: Stars = $Stars
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds
@onready var drag_input: DragInput = $DragInput

var state: State = State.TRANSITION:
	set(value):
		state = value
		if drag_input:
			drag_input.enabled = value != State.TRANSITION
var level_index: int = 0
var plan: FeedLevelGenerator.Plan
var generator: FeedLevelGenerator
var animals: Array[Animal] = []
var foods: Array[Food] = []
var plates: Array[Sprite2D] = []
var animal_size: float = 240.0
var food_size: float = 120.0
var table_top: float = 540.0
var idle_time: float = 0.0
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	if settings == null:
		settings = load("res://oyunlar/hayvan_besle/ayarlar.tres")
	for problem in settings.problems():
		push_error("Hayvanları Besle: " + problem)
	generator = FeedLevelGenerator.new(settings)
	_load_progress()
	back_button.hold_time = hold_to_exit
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	drag_input.back_button = back_button
	drag_input.enabled = false
	drag_input.grab_padding = grab_padding
	drag_input.drag_scale = drag_scale
	drag_input.touched.connect(_on_touched)
	drag_input.item_grabbed.connect(_on_food_grabbed)
	drag_input.item_moved.connect(_on_food_moved)
	drag_input.item_dropped.connect(_on_food_dropped)
	drag_input.item_canceled.connect(_on_food_canceled)
	drag_input.tapped.connect(_on_tapped)
	level_completed.connect(_on_level_completed)
	all_levels_completed.connect(_on_all_levels_completed)
	stars.setup(settings.level_count())
	table.draw.connect(func() -> void: Background.draw_table(table, get_viewport_rect().size, table_top))
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	IpucuEli.ekle(self, "hayvan_besle", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			state = State.CELEBRATING
			level_completed.emit(level_index))
	if OyunBitti.tamamlandi_mi("hayvan_besle"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "hayvan_besle", "karakter": load("res://oyunlar/hayvan_besle/gorseller/kart_tavsan.svg"),
		"bolum_sayisi": settings.level_count(), "kisa": kisa, "bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	await _clear_level()
	stars.setup(settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: aç bir hayvanın istediği yiyeceği onun ağzına sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or drag_input.active_touch != -1:
		return {}
	for animal in animals:
		if not animal.wants_more():
			continue
		for food in foods:
			if is_instance_valid(food) and food.can_grab() and animal.accepts(food.data):
				return IpucuEli.surukle(IpucuEli.ekran_konumu(food),
					get_viewport().get_canvas_transform() * animal.mouth_global())
	return {}


# --- Yerleşim ---

func _layout_static() -> void:
	var screen := get_viewport_rect().size
	var table_height := clampf(screen.y * 0.27, 170.0, 280.0)
	table_top = screen.y - table_height
	background.layout(screen, table_top)
	table.queue_redraw()
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 640.0)
	stars.layout(Vector2(maxf(screen.x / 2.0, stars_left + stars_width / 2.0), back_button.position.y + back_button.size.y / 2.0), stars_width)


# Ekran boyutu değişirse (masaüstünde pencere) bölüm yeni boyuta göre yeniden kurulur
func _on_resized() -> void:
	_layout_static()
	if plan != null and state == State.PLAYING:
		for a in animals:
			a.queue_free()
		for f in foods:
			if is_instance_valid(f):
				f.queue_free()
		for p in plates:
			p.queue_free()
		animals.clear()
		foods.clear()
		plates.clear()
		_build_level()


# Hayvanların ve tabakların dizildiği yatay aralık (ikisi aynı aralığa eşit dizilir; üretici buna göre
# hiçbir yiyeceği kendi hayvanının altına koymaz)
func _span() -> Vector2:
	var screen := get_viewport_rect().size
	# Çentikli telefonlarda kenar boşluğu güvenli alan kadar büyür
	var safe: Dictionary = EkranYardimcisi.guvenli_bosluklar()
	var inset := maxf(float(safe["sol"]), float(safe["sag"]))
	if inset <= 0.0:
		return Vector2(SIDE_LEFT, screen.x - SIDE_RIGHT)
	return Vector2(maxf(SIDE_LEFT, inset + 8.0), screen.x - maxf(SIDE_RIGHT, inset + 8.0))


func _build_level() -> void:
	var span := _span()
	var width := span.y - span.x
	var n := plan.animals.size()
	var ground := table_top + 6.0
	# Hayvan boyu: sütuna ve yüksekliğe sığsın (balon başın üstünde yaklaşık 0.65 boy yer kaplar)
	animal_size = minf(minf(width / n * 0.8, (ground - TOP_BAR) / 1.33), MAX_ANIMAL)
	for k in n:
		var animal: Animal = Animal.new()
		animal.sounds = sounds
		animal.effects = effects
		animals_layer.add_child(animal)
		animal.setup(plan.animals[k], plan.wants[k], plan.counts[k], animal_size, plan.bubble_always)
		animal.position = Vector2(span.x + (k + 0.5) * width / n, ground)
		animal.became_full.connect(_on_animal_full)
		animal.appear(0.1 + k * 0.12)
		if plan.bubble_always:
			animal.bubble.show_bubble(0.6 + k * 0.12)
		animals.append(animal)
	# Tabaklar ve üstlerinde yiyecekler (aynı yiyecekten istenen adet kadar)
	var screen := get_viewport_rect().size
	var p_count := plan.plates.size()
	var plate_step := width / p_count
	food_size = minf(minf(plate_step * 0.56, (screen.y - table_top) * 0.72), MAX_FOOD)
	var plate_y := table_top + (screen.y - table_top) * 0.58
	for p in p_count:
		var center := Vector2(span.x + (p + 0.5) * plate_step, plate_y)
		var plate := Sprite2D.new()
		plate.texture = TEX_PLATE
		plate.scale = Vector2.ONE * food_size * 1.75 / TEX_PLATE.get_width()
		plate.position = center + Vector2(0, food_size * 0.22)
		plates_layer.add_child(plate)
		_pop_in(plate, 0.2 + p * 0.1)
		plates.append(plate)
		var food_data: FeedFoodData = plan.plates[p]
		var count := plan.plate_count(food_data)
		for i in count:
			var food: Food = Food.new()
			foods_layer.add_child(food)
			food.setup(food_data, food_size, center + _pile_offset(i, count))
			food.appear(0.35 + p * 0.1 + i * 0.07)
			foods.append(food)
	drag_input.items = foods
	drag_input.lift = food_size * drag_lift


# Aynı tabaktaki yiyecekler hafifçe yana kaymış bir yığın olur (üçüncüsü ortada, üstte)
func _pile_offset(index: int, count: int) -> Vector2:
	var f := food_size
	match count:
		2:
			return [Vector2(-0.24 * f, 0.02 * f), Vector2(0.24 * f, -0.04 * f)][index]
		3:
			return [Vector2(-0.3 * f, 0.04 * f), Vector2(0.3 * f, 0.04 * f), Vector2(0.0, -0.14 * f)][index]
	return Vector2.ZERO


func _pop_in(node: Node2D, delay: float) -> void:
	var target := node.scale
	node.scale = Vector2.ZERO
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "scale", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Dokunma (ortak DragInput sinyalleri) ---

func _on_touched() -> void:
	idle_time = 0.0


func _on_food_grabbed(food: Food) -> void:
	sounds.play("pop", randf_range(0.95, 1.1))
	for animal in animals:
		animal.watch(food.drop_point(), food.data)


func _on_food_moved(food: Food, point: Vector2) -> void:
	for animal in animals:
		animal.watch(point, food.data)


func _on_food_dropped(food: Food, point: Vector2) -> void:
	for animal in animals:
		animal.unwatch()
	var animal := animal_at(point, drop_tolerance)
	if animal == null:
		# Boşluğa bırakıldı: sessizce yerine döner
		food.return_home(return_time, false)
	elif animal.accepts(food.data) and animal.wants_more():
		animal.feed(food)
	else:
		# Yanlış hayvan ya da doymuş: kibarca reddeder, yiyecek yumuşakça yerine döner
		animal.refuse()
		food.return_home(return_time, false)


func _on_food_canceled(food: Food) -> void:
	for animal in animals:
		animal.unwatch()
	food.return_home(return_time, false)


# Hayvana dokunuldu: kıkırdar ve zıplar; balonu gizliyse kısa süre görünür
func _on_tapped(pos: Vector2) -> void:
	var animal := animal_at(pos, 0.0)
	if animal:
		animal.poke(not plan.bubble_always, bubble_hint_time)


# Noktanın üstündeki (bırakma alanı en yakın olan) hayvan
func animal_at(point: Vector2, tolerance: float) -> Animal:
	var best: Animal = null
	var best_distance := INF
	for animal in animals:
		var distance := animal.drop_distance(point, tolerance)
		if distance < best_distance:
			best_distance = distance
			best = animal
	return best


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	level_index = index
	idle_time = 0.0
	_save_progress()
	stars.set_current(index)
	plan = generator.generate(index)
	for animal_data in plan.animals:
		sounds.add_voice(animal_data)
	_build_level()
	await get_tree().create_timer(0.9).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


func _on_animal_full(_animal: Animal) -> void:
	if state != State.PLAYING:
		return
	for animal in animals:
		if not animal.is_full():
			return
	state = State.CELEBRATING
	level_completed.emit(level_index)


func _on_level_completed(index: int) -> void:
	var my_run := run_id
	await get_tree().create_timer(0.7).timeout
	if my_run != run_id:
		return
	# Çeldirici (ve kalan her şey) sessizce kaybolur; tutuluyorsa bırakılır
	drag_input.cancel()
	for food in foods:
		if is_instance_valid(food) and not food.eaten:
			food.disappear(0.0)
	stars.complete(index)
	if index >= settings.level_count() - 1:
		all_levels_completed.emit()
		return
	sounds.play("bolum_sonu")
	effects.confetti(90)
	for k in animals.size():
		animals[k].dance(k * 0.1, 4)
	await get_tree().create_timer(celebration_time).timeout
	if my_run != run_id:
		return
	await _clear_level()
	if my_run != run_id:
		return
	_start_level(index + 1)


# Son bölüm bitti: büyük kutlama, sonra ortak final ekranı (bölüm seç / baştan oyna / ana menü)
func _on_all_levels_completed() -> void:
	var my_run := run_id
	sounds.play("final")
	effects.finale(animal_size)
	stars.celebrate_all()
	for k in animals.size():
		animals[k].dance(k * 0.12, 8)
	await get_tree().create_timer(finale_time).timeout
	if my_run != run_id:
		return
	await _clear_level()
	if my_run != run_id:
		return
	_oyun_bitti(false)


func _clear_level() -> void:
	state = State.TRANSITION
	drag_input.cancel()
	for k in animals.size():
		animals[k].leave(k * 0.06)
	for food in foods:
		if is_instance_valid(food) and not food.eaten:
			food.disappear(0.0)
	for plate in plates:
		var tween := plate.create_tween()
		tween.tween_property(plate, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(plate.queue_free)
	animals.clear()
	foods.clear()
	plates.clear()
	await get_tree().create_timer(0.6).timeout


# --- İpucu ---

func _process(delta: float) -> void:
	if state == State.PLAYING and drag_input.active_touch == -1:
		idle_time += delta
		if idle_time >= hint_delay:
			idle_time = 0.0
			_show_hint()


func _show_hint() -> void:
	var hungry: Array[Animal] = []
	for animal in animals:
		if animal.wants_more():
			hungry.append(animal)
	if hungry.is_empty():
		return
	if not plan.bubble_always:
		# Balonlar gizli: aç hayvanların balonları kısa süre belirir
		for animal in hungry:
			animal.bubble.flash(bubble_hint_time)
			animal.nudge()
		return
	# Balonlar görünür: bir hayvan zıplar, balonu sallanır ve istediği yiyecek kıpırdar
	var animal: Animal = hungry.pick_random()
	animal.nudge()
	animal.bubble.bounce()
	for food in foods:
		if is_instance_valid(food) and food.can_grab() and animal.accepts(food.data):
			food.wiggle()
			break


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level_index = clampi(int(config.get_value("ilerleme", "bolum", 0)), 0, maxi(settings.level_count() - 1, 0))


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "bolum", level_index)
	GuvenliKayit.save_config(config, SAVE_PATH)
