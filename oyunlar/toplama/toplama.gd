extends Control
# Toplama Öğreniyorum (AdditionGame): 4-6 yaş. Ekranda [A] + [B] = [?]; çocuk alttaki sayı
# düğmelerinden toplamı seçer. Skor, can, süre yok. Yanlış düğme nazikçe kaybolur; doğruda rakam
# "?" kartına uçar, nesneler tek tek sonuç kutusuna uçup sayılır, sonra sonraki bölüm.
# Son bölümden sonra büyük kutlama ve 1. bölüme dönüş. Bütün zorluk ayarları ayarlar.tres içinde.
#
# Durumlar: SHOWING (işlem beliriyor) -> WAITING (cevap bekleniyor) -> WRONG (yanlış düğme
# kayboluyor, sonra yine WAITING) ya da CORRECT (uçuş ve sayma) -> LEVEL_DONE / FINALE -> SHOWING.
# Dokunmanın tamamı burada (_input); cevap yalnızca WAITING'de seçilir, böylece art arda hızlı
# dokunuş iki cevabı birden seçemez.

signal state_changed(state: State)

const ObjectBox := preload("res://oyunlar/toplama/nesne_kutusu.gd")
const AnswerButton := preload("res://oyunlar/toplama/cevap_dugmesi.gd")
const Progress := preload("res://oyunlar/toplama/ilerleme_cubugu.gd")
const Effects := preload("res://oyunlar/toplama/kutlama.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const Sounds := preload("res://oyunlar/toplama/sesler.gd")
const TEX_CLOUD: Texture2D = preload("res://oyunlar/toplama/gorseller/bulut.svg")
const SAVE_PATH := "user://toplama.cfg"

enum State { SHOWING, WAITING, WRONG, CORRECT, LEVEL_DONE, FINALE }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bütün zorluk ayarları (aşamalar, 0 kullanımı, yanlış seçenekler, nesneler). ayarlar.tres'i aç.
@export var settings: AdditionSettings

@export_group("Sayma animasyonu")
## Nesnelerin sonuç kutusuna uçması toplamda yaklaşık bu kadar sürer (büyük sayılarda adım kısalır).
@export var count_total_time: float = 3.0
## İki nesne arasındaki süre en az ...
@export var count_step_min: float = 0.14
## ... ve en fazla bu kadar (küçük sayılarda yavaş ve net sayılsın).
@export var count_step_max: float = 0.6
## Bir nesnenin uçuş süresi.
@export var object_flight_time: float = 0.45

@export_group("Diğer süreler")
## Doğru düğmenin "?" kartına uçuş süresi.
@export var answer_flight_time: float = 0.55
## Bölüm sonu kutlamasının süresi (sonra otomatik olarak sonraki bölüm).
@export var celebration_time: float = 1.8
## Son bölümdeki büyük kutlamanın süresi.
@export var finale_time: float = 4.5
## Basılı tutunca ana menüye dönme süresi.
@export var hold_to_exit: float = 0.6

const TOP_AREA := 118.0          # üstte geri düğmesi, ilerleme çubuğu
const SIDE_MARGIN := 40.0
const BOTTOM_MARGIN := 26.0
const BOX_SIZE := Vector2(320, 290)          # A ve B kutularının en küçük boyu (en fazla 10 nesne)
const RESULT_BOX_SIZE := Vector2(364, 290)   # sonuç kutusu daha geniş (en fazla 20 nesne); yükseklik ortak
const MAX_EXTRA_WIDTH := 420.0   # geniş ekranda kutular toplam bu kadar genişleyebilir
const SIGN_SIZE := 70.0
const ROW_GAP := 14.0
const MAX_EXTRA_HEIGHT := 110.0  # uzun ekranda (tablet) kutular en fazla bu kadar uzar
const CARD_OVERHANG := 112.0     # rakam kartının kutunun üstünden taşan kısmı
const COUNTER_OVERHANG := 11.0   # sayaç balonunun kutunun altından taşan kısmı
const BUTTON_SIZE := Vector2(172, 150)
const BUTTON_GAP := 54.0
const BUTTON_COLORS: Array[Color] = [Color("ff7aae"), Color("4fa8ff"), Color("ffb23f"), Color("6fcf5a")]
const QUESTION_COLOR := Color("9d86d8")
const MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11, 12]

@onready var sky: TextureRect = $Sky
@onready var floaters: Node2D = $Floaters
@onready var row: Node2D = $Row
@onready var box_a: ObjectBox = $Row/BoxA
@onready var box_b: ObjectBox = $Row/BoxB
@onready var box_result: ObjectBox = $Row/BoxResult
@onready var plus_sign: Sprite2D = $Row/Plus
@onready var equals_sign: Sprite2D = $Row/Equals
@onready var buttons_layer: Node2D = $Buttons
@onready var flying: Node2D = $Flying
@onready var effects: Effects = $Effects
@onready var progress: Progress = $Progress
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds

var state: State = State.SHOWING
var level_index: int = 0
var generator: ProblemGenerator
var problem: ProblemGenerator.Problem
var buttons: Array[AnswerButton] = []
var texture_index: int = -1
var back_touch: int = -1          # geri düğmesini tutan parmak (-1: yok)
var run_id: int = 0               # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	for issue in settings.problems():
		push_error("Toplama Öğreniyorum: " + issue)
	generator = ProblemGenerator.new(settings)
	_load()
	back_button.hold_time = hold_to_exit
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	_setup_sky()
	_create_floaters()
	progress.setup(settings.level_count(), level_index)
	_layout()
	get_viewport().size_changed.connect(_layout)
	_start_level(level_index)
	IpucuEli.ekle(self, "toplama", _ipucu)
	OyunBitti.kisayol(self, _gelistirici_bitir)
	if OyunBitti.tamamlandi_mi("toplama"):
		_oyun_bitti(true)


# Geliştirici kısayolu (F9, yalnızca debug derlemede): doğru sayı düğmesini seçer
func _gelistirici_bitir() -> void:
	if state != State.WAITING:
		return
	for button in buttons:
		if button.value == problem.answer:
			_choose(button)
			return


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "toplama", "karakter": load("res://ana_menu/kartlar/toplama.svg"), "bolum_sayisi": settings.level_count(),
		"kisa": kisa, "bolum_baslat": _start_level, "bastan": _start_level.bind(0),
	})


# Başlangıç ipucu eli: "?" kartını, sonra sayı düğmelerini gösterir (cevabı vermez; seçim çocuğun)
func _ipucu() -> Dictionary:
	if state != State.WAITING or buttons.is_empty():
		return {}
	return IpucuEli.sira([
		IpucuEli.goster(IpucuEli.ekran_konumu(box_result._card)),
		IpucuEli.goster(IpucuEli.ekran_konumu(buttons[0])),
		IpucuEli.goster(IpucuEli.ekran_konumu(buttons[-1])),
	])


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	if SahneGecis.gecis_suruyor:
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_on_press(touch.index, touch.position)
	elif touch.index == back_touch:
		_release_back()


func _on_press(index: int, pos: Vector2) -> void:
	if back_touch == -1 and back_button.contains(pos):
		back_touch = index
		back_button.press()
		return
	if state == State.WAITING:
		for button in buttons:
			if button.contains(pos):
				_choose(button)
				return
	# Kutudaki nesneye dokunma: sayma yardımı, akışı etkilemez
	if state in [State.SHOWING, State.WAITING, State.WRONG]:
		if box_a.hop_at(pos) or box_b.hop_at(pos):
			sounds.play("dokunma", randf_range(0.95, 1.15))


func _release_back() -> void:
	back_touch = -1
	back_button.release()


# Uygulama arka plana giderse basılı geri düğmesi bırakılır
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and back_touch != -1:
		_release_back()


# --- Cevap ---

func _choose(button: AnswerButton) -> void:
	buttons.erase(button)
	if button.value == problem.answer:
		_run_correct(button)
	else:
		_run_wrong(button)


func _run_wrong(button: AnswerButton) -> void:
	_set_state(State.WRONG)
	var my_run := run_id
	button.reject()
	sounds.play("yanlis")
	await get_tree().create_timer(0.62).timeout
	if my_run == run_id and state == State.WRONG:
		_set_state(State.WAITING)


func _run_correct(button: AnswerButton) -> void:
	_set_state(State.CORRECT)
	var my_run := run_id
	for k in buttons.size():
		buttons[k].fade_out(k * 0.05)
	buttons.clear()
	sounds.play("ucus")
	# Düğme "?" kartının üstüne uçar, rakam karta yerleşir
	var target_scale := box_result.card_global_size() / BUTTON_SIZE.y
	await button.fly_to(box_result.card_global(), target_scale, answer_flight_time).finished
	if my_run != run_id:
		return
	button.queue_free()
	box_result.set_number(str(problem.answer), box_result.number_color)
	sounds.play("dogru")
	effects.sparkle(box_result.card_global(), box_result.card_global_size())
	await get_tree().create_timer(0.45).timeout
	if my_run != run_id:
		return
	await _count_objects(my_run)
	if my_run != run_id:
		return
	_finish_level(my_run)


# A ve B'deki nesneler tek tek sonuç kutusuna uçar; her varışta sayaç bir artar
func _count_objects(my_run: int) -> void:
	var total := problem.answer
	var step := clampf(count_total_time / total, count_step_min, count_step_max)
	var sources: Array[Sprite2D] = box_a.release_objects()
	sources.append_array(box_b.release_objects())
	for k in sources.size():
		var sprite := sources[k]
		sprite.reparent(flying, true)
		var target := box_result.slot_global(k, total)
		var control := (sprite.global_position + target) / 2.0 + Vector2(0.0, -120.0 * row.scale.y)
		var tween := sprite.create_tween()
		tween.tween_method(_move_on_curve.bind(sprite, sprite.global_position, control, target), 0.0, 1.0, object_flight_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(sprite, "rotation", TAU * (1 if k % 2 == 0 else -1), object_flight_time)
		tween.parallel().tween_property(sprite, "scale", Vector2.ONE * box_result.object_scale(sprite.texture) * box_result.global_scale.x, object_flight_time)
		tween.tween_callback(_on_object_arrived.bind(sprite, k + 1, total, my_run))
		await get_tree().create_timer(step).timeout
		if my_run != run_id:
			return
	await get_tree().create_timer(object_flight_time + 0.15).timeout
	if my_run != run_id:
		return


func _move_on_curve(t: float, sprite: Sprite2D, start: Vector2, control: Vector2, target: Vector2) -> void:
	sprite.global_position = start.lerp(control, t).lerp(control.lerp(target, t), t)


func _on_object_arrived(sprite: Sprite2D, number: int, total: int, my_run: int) -> void:
	if my_run != run_id:
		return
	box_result.adopt(sprite, total)
	box_result.set_counter(number)
	sounds.play("sayma", _count_pitch(number, total))


# Sayma sesinin perdesi her sayışta majör gamda bir basamak yükselir; toplam 8'den büyükse
# basamaklar seyrelir, böylece son sayı en fazla bir oktav yukarıda olur.
func _count_pitch(number: int, total: int) -> float:
	var position := roundi((number - 1) * 7.0 / maxf(total - 1, 7.0))
	return pow(2.0, MAJOR_SCALE[position] / 12.0)


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	_set_state(State.SHOWING)
	level_index = index
	_save()
	var stage := settings.stage_for_level(index)
	problem = generator.generate(stage)
	var texture := _next_texture()
	# A ve B'de nesneler aynı boyda; sonuç kutusunda gerekirse daha küçük (uçarken küçülürler)
	var cell := minf(box_a.fit_cell(problem.a), box_b.fit_cell(problem.b))
	box_result.cell = minf(box_result.fit_cell(problem.answer), cell)
	box_result.set_counter(0)
	box_a.set_number(str(problem.a))
	box_b.set_number(str(problem.b))
	box_result.set_number("?", QUESTION_COLOR)
	var step := clampf(1.2 / maxf(problem.a + problem.b, 1), 0.06, 0.16)
	var end_a := box_a.fill(problem.a, texture, cell, 0.15, step)
	var end_b := box_b.fill(problem.b, texture, cell, end_a - 0.2, step)
	_build_buttons(problem.choices, end_b - 0.2)
	await get_tree().create_timer(end_b - 0.2 + buttons.size() * 0.08 + 0.4).timeout
	if my_run == run_id:
		_set_state(State.WAITING)


func _finish_level(my_run: int) -> void:
	var last := level_index >= settings.level_count() - 1
	_set_state(State.FINALE if last else State.LEVEL_DONE)
	progress.complete(level_index)
	box_result.celebrate()
	box_result.celebrate_card()
	effects.sparkle(box_result.global_position, box_result.cell * row.scale.x * 3.0)
	if last:
		sounds.play("final")
		effects.finale(BOX_SIZE.y * row.scale.y * 0.6)
		await get_tree().create_timer(finale_time).timeout
	else:
		sounds.play("bolum")
		effects.confetti(70)
		await get_tree().create_timer(celebration_time).timeout
	if my_run != run_id:
		return
	box_result.clear(true)
	box_result.set_counter(0)
	if last:
		progress.reset()
	await get_tree().create_timer(0.35).timeout
	if my_run != run_id:
		return
	if last:
		_oyun_bitti(false)          # son bölüm: 1. bölüme sessizce dönmek yerine ortak final ekranı
		return
	_start_level(level_index + 1)


# Her bölümde farklı bir nesne (bir öncekiyle aynı olmasın)
func _next_texture() -> Texture2D:
	var count := settings.object_textures.size()
	var next := randi() % count
	if count > 1 and next == texture_index:
		next = (next + 1 + randi() % (count - 1)) % count
	texture_index = next
	return settings.object_textures[next]


func _build_buttons(choices: Array[int], delay: float) -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()
	var colors := BUTTON_COLORS.duplicate()
	colors.shuffle()
	for k in choices.size():
		var button: AnswerButton = AnswerButton.new()
		button.setup(choices[k], colors[k % colors.size()], BUTTON_SIZE)
		buttons_layer.add_child(button)
		buttons.append(button)
		button.appear(delay + k * 0.08)
	_layout_buttons()


# --- Yerleşim ---

func _layout() -> void:
	var screen := get_viewport_rect().size
	# Çentikli telefonlarda kenar payı güvenli alan kadar büyür (iki yanda aynı: satır ortada kalır)
	var side := maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, SIDE_MARGIN), EkranYardimcisi.kenar_payi(SIDE_RIGHT, SIDE_MARGIN))
	back_button.position = Vector2(side, 18.0)
	var bar_left := back_button.position.x + back_button.size.x + 40.0
	var bar_right := screen.x - side
	progress.width = minf(bar_right - bar_left, 760.0)
	progress.position = Vector2((bar_left + bar_right) / 2.0, back_button.position.y + back_button.size.y / 2.0)
	progress.queue_redraw()

	# [A] + [B] = [?] satırı: yüksekliğe göre ölçeklenir. Dar ekranda (16:9) genişlik sınırlar ve
	# satır küçülür; uzun telefonda artan genişlik kutulara verilir (nesneler daha büyük olur).
	var area_top := TOP_AREA
	var area_bottom := screen.y - BOTTOM_MARGIN - BUTTON_SIZE.y - 18.0
	var area_width := screen.x - side * 2.0
	var area_height := area_bottom - area_top
	var overhang := CARD_OVERHANG + COUNTER_OVERHANG
	var min_width := BOX_SIZE.x * 2.0 + RESULT_BOX_SIZE.x + SIGN_SIZE * 2.0 + ROW_GAP * 4.0
	var s := minf(area_height / (BOX_SIZE.y + overhang), 1.3)
	s = minf(s, area_width / min_width)
	var extra := clampf(area_width / s - min_width, 0.0, MAX_EXTRA_WIDTH)
	var box_height := BOX_SIZE.y + clampf(area_height / s - BOX_SIZE.y - overhang, 0.0, MAX_EXTRA_HEIGHT)
	var box_width := BOX_SIZE.x + extra * 0.32
	var result_width := RESULT_BOX_SIZE.x + extra * 0.36
	var x := -(min_width + extra) / 2.0
	for node: Node2D in [box_a, plus_sign, box_b, equals_sign, box_result]:
		var w := SIGN_SIZE
		if node == box_result:
			w = result_width
		elif node != plus_sign and node != equals_sign:
			w = box_width
		node.position = Vector2(x + w / 2.0, 0.0)
		x += w + ROW_GAP
	box_a.set_box_size(Vector2(box_width, box_height))
	box_b.set_box_size(Vector2(box_width, box_height))
	box_result.set_box_size(Vector2(result_width, box_height))
	for mark: Sprite2D in [plus_sign, equals_sign]:
		mark.scale = Vector2.ONE * SIGN_SIZE / mark.texture.get_width()
	row.scale = Vector2(s, s)
	var row_height := (box_height + overhang) * s
	row.position = Vector2(screen.x / 2.0, area_top + (area_height - row_height) / 2.0 + (box_height / 2.0 + CARD_OVERHANG) * s)
	_layout_buttons()


func _layout_buttons() -> void:
	var screen := get_viewport_rect().size
	var count := buttons.size()
	var total := count * BUTTON_SIZE.x + (count - 1) * BUTTON_GAP
	for k in count:
		buttons[k].position = Vector2(screen.x / 2.0 - total / 2.0 + BUTTON_SIZE.x / 2.0 + k * (BUTTON_SIZE.x + BUTTON_GAP),
			screen.y - BOTTOM_MARGIN - BUTTON_SIZE.y / 2.0)


# --- Arka plan ---

func _setup_sky() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color("fff1dc"), Color("fbeaf6"), Color("e3f1ff")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.3, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 64
	texture.height = 256
	sky.texture = texture


func _create_floaters() -> void:
	var screen := get_viewport_rect().size
	for k in 3:
		var cloud := Sprite2D.new()
		cloud.texture = TEX_CLOUD
		var s := randf_range(0.8, 1.2) * 200.0 / TEX_CLOUD.get_width()
		cloud.scale = Vector2(s, s)
		cloud.modulate.a = randf_range(0.5, 0.7)
		cloud.position = Vector2(randf_range(0.0, screen.x), randf_range(120.0, screen.y * 0.6))
		cloud.set_meta("speed", randf_range(6.0, 12.0))
		floaters.add_child(cloud)


func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	for cloud: Sprite2D in floaters.get_children():
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		var half := cloud.texture.get_width() * cloud.scale.x / 2.0
		if cloud.position.x > screen.x + half:
			cloud.position = Vector2(-half, randf_range(120.0, screen.y * 0.6))


# --- Kayıt ---

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level_index = clampi(int(config.get_value("ilerleme", "bolum", 0)), 0, maxi(settings.level_count() - 1, 0))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "bolum", level_index)
	GuvenliKayit.save_config(config, SAVE_PATH)
