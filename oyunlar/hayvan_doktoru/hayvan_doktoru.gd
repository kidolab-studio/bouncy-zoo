extends Control
# Hayvan Doktoru (ClinicGame): 4-8 yaş, yatay ekran, hiç yazı yok. Her gün bekleme odasındaki bankta üç hasta hayvan
# oturur (belirtileri görünür); çocuk birine dokunur, hasta muayene masasına geçer. Sağdaki rafta bu ziyaretin aletleri
# durur; sırası gelen parlar, çocuk onu tutup hastaya sürükler. Her ziyaret stetoskopla başlar (göğse basılı tut →
# kalp atışı, başın üstünde rahatsızlığın simgesi çıkar), sonra rahatsızlığın aletleri sırayla gelir (ör. sıyrık:
# pamukla sil → merhem sür → yara bandı yapıştır). Hasta iyileşince sevinir, gider; banktaki yerinde kalp kalır. Üç
# hasta bitince gün biter (üstte bir yıldız dolar), yeni günün hastaları gelir. 10. günden sonra ortak final ekranı
# (OyunBitti; sonsuz klinik: rastgele hastalar). Skor, süre, can yok; sırası gelmeyen alet sadece kıpırdar.
# İyileşen her hasta albüme bir çıkartma verir (hayvan × rahatsızlık); albüm bekleme odasının sağ üstündeki düğmeyle
# açılır (album.gd).
# Geri: albüm açıksa kapatır; tedavide hastayı banka geri gönderir (noktaları baştan açılır); bekleme odasında ana
# menüye çıkar.
#
# Ayarlar ayarlar.gd'de. Dokunmayı bu script okur: aynı anda tek parmak alet tutar (ikinci parmak yok sayılır),
# geri düğmesine düşen dokunuş düğmeye gider. Aletin etkisi aletin ucunda (alet.gd tip_global) hesaplanır:
# RUB sürtüldükçe, HOLD noktada durdukça, PLACE noktaya bırakılınca, PULL noktadan tutulup dışarı çekilince,
# FEED ağızda durdukça işler.

const Patient := preload("res://oyunlar/hayvan_doktoru/hasta.gd")
const Spot := preload("res://oyunlar/hayvan_doktoru/tedavi_noktasi.gd")
const Tool := preload("res://oyunlar/hayvan_doktoru/alet.gd")
const Tray := preload("res://oyunlar/hayvan_doktoru/alet_rafi.gd")
const Background := preload("res://oyunlar/hayvan_doktoru/arka_plan.gd")
const Bubble := preload("res://oyunlar/hayvan_doktoru/dusunce_balonu.gd")
const Effects := preload("res://oyunlar/hayvan_doktoru/efektler.gd")
const Sounds := preload("res://oyunlar/hayvan_doktoru/sesler.gd")
const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const Stars := preload("res://oyunlar/hayvan_doktoru/yildizlar.gd")
const Album := preload("res://oyunlar/hayvan_doktoru/album.gd")
const Sticker := preload("res://oyunlar/hayvan_doktoru/cikartma.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/hayvan_doktoru/gorseller/kart_doktor.svg")
const SAVE_PATH := "user://hayvan_doktoru.cfg"

## Bir harekette en fazla bu kadar yol sayılır (parmak sıçrarsa nokta birden bitmesin)
const MAX_STEP := 90.0
## Basılı tutulan alet noktadayken sesin / efektin aralığı (sn): stetoskopta kalp, damlalıkta damla
const HOLD_TICK := {"stetoskop": 0.6, "damla": 0.3}

enum State { TRANSITION, WAITING, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@onready var background: Background = $Background
@onready var patient_layer: Node2D = $Patient
@onready var bubble: Bubble = $Bubble
@onready var effects: Effects = $Effects
@onready var stars: Stars = $Stars
@onready var tray: Tray = $Tray
@onready var tool: Tool = $Tool
@onready var album: Album = $Album
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds

var state: State = State.TRANSITION
var day: int = 0                       # gün (bölüm), 0'dan
var endless: bool = false              # sonsuz klinik (oyun bittikten sonra)
## Bekleme odasındaki hastalar: {"animal", "ailment", "patient" (Patient ya da null), "done", "sneeze" (sn)}
var waiting: Array[Dictionary] = []
var current: int = -1                  # tedavideki hastanın waiting sırası (-1: bekleme odası)
var patient: Patient                   # tedavideki hasta
var ailment: String = ""
var steps: Array[String] = []         # bu ziyaretin aletleri sırayla (0: stetoskop)
var step: int = 0
var patient_size: float = 400.0
var waiting_size: float = 260.0        # banktaki hastaların boyu
var table_top: Vector2                 # minderin üst ortası (hastanın ayakları)
var seats: Array[Vector2] = []         # banktaki yerler (ayakların değdiği nokta)
var idle_time: float = 0.0
var run_id: int = 0                    # hasta değişince eski beklemeler devam etmesin

var _finger: int = -1
var _last_point: Vector2
var _moved: float = 0.0                # son karede parmağın aldığı yol (döngü sesi için)
var _on_patient: bool = false          # alet şu an hastanın üstünde (döngü sesi için)
var _step_busy: bool = false           # adım değişiyor: kısa süre etki sayılmaz
var _place_time: float = 0.0
var _hold_contact: bool = false        # basılı tutulan alet şu an noktada
var _hold_tick: float = 0.0
var _pulling: Spot = null              # cımbızla tutulan diken
var _pull_nearest: float = INF         # cımbızın ucunun dikene en yakın olduğu uzaklık (yarıçap biriminde)
var _wince_wait: float = 0.0
var _day_info: Dictionary = {}
var _move: Tween                       # hastanın bank ile masa arasındaki geçişi


func _ready() -> void:
	for problem in Settings.problems():
		push_error("Hayvan Doktoru ayarları: " + problem)
	_load_progress()
	back_button.completed.connect(_on_back)
	album.sticker_tapped.connect(_on_sticker_tapped)
	album.page_turned.connect(func() -> void: sounds.play("sayfa", randf_range(0.95, 1.1)))
	stars.setup(Settings.DAYS.size())
	_layout()
	EkranYardimcisi.degisince(_layout)
	get_viewport().size_changed.connect(_layout)
	_start_day(day, false)
	IpucuEli.ekle(self, "hayvan_doktoru", _ipucu)
	OyunBitti.kisayol(self, _dev_finish_day)
	if OyunBitti.tamamlandi_mi("hayvan_doktoru"):
		_oyun_bitti(true)


func _exit_tree() -> void:
	_set_back_capture(false)


# Tedavideyken ya da albüm açıkken Android geri tuşu / Escape oyunun kendi geri davranışını kullanır
func _set_back_capture(on: bool) -> void:
	if on:
		SahneGecis.geri_yakalayici = _inner_back
	elif SahneGecis.geri_yakalayici.is_valid() and SahneGecis.geri_yakalayici.get_object() == self:
		SahneGecis.geri_yakalayici = Callable()


func _on_back() -> void:
	if current == -1 and not album.shown:
		SahneGecis.ana_menuye_don()
	else:
		back_button.reset()                 # sahne değişmiyor: düğme yeniden çalışsın
		_inner_back()


# Oyunun içindeki geri: albümü kapatır ya da tedavideki hastayı banka gönderir
func _inner_back() -> void:
	if album.shown:
		_close_album()
	else:
		_back_to_bench()


func _open_album() -> void:
	album.open()
	sounds.play("sayfa")
	_set_back_capture(true)


func _close_album() -> void:
	album.close()
	_finger = -1
	sounds.play("pop", 0.9)
	_set_back_capture(false)


func _on_sticker_tapped(animal: String) -> void:
	sounds.set_voice(Settings.animal(animal))
	sounds.play("ses", randf_range(0.98, 1.06))


# Başlangıç ipucu eli: bekleme odasında bir hastaya dokun; tedavide sırası gelen aleti raftan noktaya sürükle (aletin
# ucu parmağın üstünde durduğu için el noktanın biraz altına iner). Albüm açıkken ve geçişlerde gösterilmez.
func _ipucu() -> Dictionary:
	if album.shown or _finger != -1 or _step_busy:
		return {}
	if state == State.WAITING:
		for w in waiting:
			if not w["done"] and is_instance_valid(w["patient"]):
				return IpucuEli.dokun(w["patient"].center_global())
		return {}
	if state != State.PLAYING or not is_instance_valid(patient):
		return {}
	var below := Vector2(0.0, Tool.lift_for(patient_size))
	for spot in patient.spots:
		if spot.needs(steps[step]):
			return IpucuEli.surukle(tray.slot_position(step), IpucuEli.izle(spot, below))
	return {}


# Son gün bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "hayvan_doktoru", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.DAYS.size(), "kisa": kisa,
		"bolum_baslat": func(i: int) -> void: _start_day(i, false),
		"bastan": func() -> void: _start_day(0, false),
		"sonsuz": func() -> void: _start_day(0, true),
	})


# --- Yerleşim ---

# Yerleşim ayarlar.gd layout()'tan (tablo testi de aynısını denetler); arka plan ekranın tamamını kaplar; gün
# yıldızları üstte, albüm düğmesi sağ üstte
func _layout() -> void:
	var screen := get_viewport_rect().size
	var area := EkranYardimcisi.tasarim_alani()
	var top := back_button.position.y + back_button.size.y
	var plan := Settings.layout(screen, area, EkranYardimcisi.kenar_payi(SIDE_RIGHT, 40.0), top)
	patient_size = plan["patient"]
	table_top = plan["table_top"]
	waiting_size = plan["waiting"]
	seats = plan["seats"]
	background.layout(screen, table_top, plan["table_width"], area)
	var xs: Array[float] = []
	for seat in seats:
		xs.append(seat.x)
	background.set_bench(plan["bench_top"], plan["bench_width"], xs)
	tray.layout(plan["tray_center"], plan["tray_radius"], plan["tray_height"])
	for k in waiting.size():
		var p: Patient = waiting[k]["patient"]
		if is_instance_valid(p) and k != current:
			p.position = seats[k]
			p.scale = Vector2.ONE * waiting_size / p.size
	if patient:
		patient.position = table_top
		patient.scale = Vector2.ONE * patient_size / patient.size
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 560.0)
	stars.layout(Vector2(maxf(screen.x / 2.0, stars_left + stars_width / 2.0), back_button.position.y + back_button.size.y / 2.0), stars_width)
	var album_r := back_button.size.x * 0.56
	var album_at := Vector2(screen.x - EkranYardimcisi.kenar_payi(SIDE_RIGHT, 40.0) - album_r - 6.0, back_button.position.y + back_button.size.y / 2.0)
	album.layout(screen, area, album_at, album_r)


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	if SahneGecis.gecis_suruyor:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if back_button.handle_touch(touch):
			return
		if album.shown:
			# Albüm açıkken dokunuşlar albüme gider (kaydırma, oklar, çıkartmalar)
			if touch.pressed and _finger == -1:
				_finger = touch.index
				album.press(touch.position)
			elif not touch.pressed and touch.index == _finger:
				_finger = -1
				album.release(touch.position)
			return
		if touch.pressed:
			if _finger == -1:
				_touch_down(touch.index, touch.position)
		elif touch.index == _finger:
			_touch_up()
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _finger and not album.shown:
		_touch_move(drag.position)


# Bekleme odasında dokunulan hasta masaya geçer; tedavide raftaki sırası gelen alet tutulur, sırası gelmeyen kıpırdar
func _touch_down(index: int, point: Vector2) -> void:
	idle_time = 0.0
	if state == State.WAITING:
		if album.button_contains(point):
			_open_album()
			return
		for k in waiting.size():
			var p: Patient = waiting[k]["patient"]
			if not waiting[k]["done"] and is_instance_valid(p) and p.contains(point):
				_select(k)
				return
		return
	if current == -1:
		return
	var slot := tray.slot_at(point)
	if slot == -1:
		return
	if slot != step or state != State.PLAYING or _step_busy:
		tray.wiggle(slot)
		return
	_finger = index
	_last_point = point
	_place_time = 0.0
	_hold_contact = false
	tool.set_tool(steps[step], patient_size)
	tool.begin(point, tray.slot_position(step), tray.icon_width())
	tray.empty_slot = step
	sounds.play("pop", randf_range(0.95, 1.1))


func _touch_move(point: Vector2) -> void:
	var distance := minf(point.distance_to(_last_point), MAX_STEP)
	_last_point = point
	idle_time = 0.0
	_moved += distance
	tool.move(point)
	if tool.kind == Settings.Kind.RUB:
		_rub(distance)


# Parmak kalktı: yerleştirilecek alet hedefin üstündeyse yapışır, değilse alet rafa uçar
func _touch_up() -> void:
	if tool.kind == Settings.Kind.PLACE and state == State.PLAYING and not _step_busy:
		var spot := _spot_under_tip()
		if spot:
			_place(spot)
			return
	_release_tool()


func _release_tool() -> void:
	_finger = -1
	if _pulling:
		_pulling.set_pull(0.0)              # yarım çekilen diken yerine döner
		_pulling = null
	var slot := tray.tools.find(tool.id)
	tool.return_to(tray.slot_position(slot), tray.icon_width(), tray.show_slot.bind(slot))
	if is_instance_valid(patient):
		patient.unwatch()


# Uygulama arka plana giderse ya da pencere odağı kaybolursa parmak bırakılmış sayılır
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if _finger != -1:
			_release_tool()


# --- Aletin etkisi ---

## Aletin ucunun altındaki, bu aleti bekleyen nokta (yoksa null)
func _spot_under_tip() -> Spot:
	if not is_instance_valid(patient):
		return null
	var tip := tool.tip_global()
	for spot in patient.spots:
		if spot.needs(tool.id) and spot.hit(tip, Settings.HIT_RADIUS):
			return spot
	return null


func _can_work() -> bool:
	return state == State.PLAYING and not _step_busy and _finger != -1 and is_instance_valid(patient)


# Sürtülen alet distance kadar yol aldı: ucunun altındaki noktalar işlenir, hasta tepki verir
func _rub(distance: float) -> void:
	if not _can_work() or distance <= 0.0:
		return
	for spot in patient.spots:
		if spot.needs(tool.id) and spot.hit(tool.tip_global(), Settings.HIT_RADIUS):
			_react(spot)
			var path := Settings.SPOT_RADIUS * spot.global_scale.x * Settings.RUB_PATH
			if spot.work(distance / path):
				_spot_done(spot)
	_check_step()


# Alet noktaya etki ederken hastanın tepkisi
func _react(spot: Spot) -> void:
	match tool.id:
		"pamuk", "cimbiz":
			patient.wince()
			if _wince_wait <= 0.0:
				_wince_wait = randf_range(1.5, 2.5)
				sounds.play("kikir", randf_range(1.1, 1.25))
		"kulak_cubugu", "pudra":
			patient.relief()
			if _wince_wait <= 0.0:
				_wince_wait = randf_range(1.5, 2.5)
				sounds.play("kikir", randf_range(0.95, 1.1))
		"damla":
			if spot.look == "goz":
				patient.wince()
			else:
				patient.listen()
		"stetoskop", "termometre":
			patient.listen()
		"dis_fircasi":
			patient.open_mouth()
		_:
			patient.relief()


func _spot_done(spot: Spot) -> void:
	sounds.play("temiz", randf_range(0.95, 1.08))
	effects.sparkle(spot.global_position, patient_size * 0.5)


# Yerleştirilecek alet (bant, sargı) noktaya oturdu
func _place(spot: Spot) -> void:
	_finger = -1
	spot.work(1.0)
	patient.relief()
	patient.unwatch()
	sounds.play(tool.id if tool.id == "sargi" else "bant", randf_range(0.95, 1.08))
	effects.sparkle(spot.global_position, patient_size * 0.5)
	var slot := tray.tools.find(tool.id)
	tool.stick_to(tool.tip_global(), tray.show_slot.bind(slot))
	_check_step()


# Bu adımın aletini bekleyen nokta kalmadıysa adım biter
func _check_step() -> void:
	if not is_instance_valid(patient) or step >= steps.size():
		return
	for spot in patient.spots:
		if spot.needs(steps[step]):
			return
	_finish_step()


# Sırası gelen görünmez hedefler (göğüs, ağız) sarı halkayla belirir
func _update_targets() -> void:
	if not is_instance_valid(patient):
		return
	for spot in patient.spots:
		spot.active = step < steps.size() and spot.needs(steps[step])


# Adım bitti: elindeki alet rafa döner, sıradaki alet parlar; stetoskoptan sonra düşünce balonu; son adımda iyileşir
func _finish_step() -> void:
	var finished := steps[step]
	step += 1
	tray.advance()
	if _finger != -1:
		_release_tool()
	_update_targets()
	if step >= steps.size():
		_finish_patient()
		return
	var my_run := run_id
	_step_busy = true
	sounds.play("adim")
	if finished == Settings.EXAM_TOOL:
		var icon := Settings.tool_texture(Settings.AILMENTS[ailment]["icon"])
		bubble.show_icon(icon, patient.head_top_global(), patient_size * 0.36)
		for spot in patient.spots:
			if spot.needs(steps[step]):
				spot.pulse()
	else:
		patient.hop()
	await get_tree().create_timer(0.5).timeout
	if my_run != run_id:
		return
	_step_busy = false
	if finished == Settings.EXAM_TOOL:
		await get_tree().create_timer(Settings.BUBBLE_TIME - 0.5).timeout
		if my_run == run_id:
			bubble.hide_bubble()


# --- Gün ve hasta akışı ---

# Yeni gün: bekleme odasına üç hasta soldan sırayla gelip banka oturur
func _start_day(index: int, endless_mode: bool) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	if _finger != -1:
		_release_tool()
	album.close()
	_set_back_capture(false)
	endless = endless_mode
	day = index
	current = -1
	patient = null
	tray.hide_tray()
	bubble.hide_bubble()
	if endless:
		stars.set_current(Settings.DAYS.size())
	else:
		stars.set_current(day)
		_save_progress()
	for w in waiting:
		if is_instance_valid(w["patient"]):
			w["patient"].queue_free()
	waiting.clear()
	_day_info = Settings.day_info(day, endless)
	var used: Array[String] = []
	for k in Settings.DAY_PATIENTS:
		var name: String = _day_info["ailments"][k]
		var choices := Settings.animals_for(name).filter(func(a: String) -> bool: return not a in used)
		var animal: String = choices.pick_random()
		used.append(animal)
		var p := Patient.new()
		patient_layer.add_child(p)
		p.setup(Settings.animal(animal), patient_size)
		p.position = seats[k]
		p.scale = Vector2.ONE * waiting_size / p.size
		_add_spots(p, name)
		p.shivering = name == "ates"
		p.appear(0.15 + k * 0.3)
		waiting.append({"animal": animal, "ailment": name, "patient": p, "done": false, "sneeze": randf_range(1.5, 3.0)})
	_show_bench()
	await get_tree().create_timer(0.15 + Settings.DAY_PATIENTS * 0.3 + 0.5).timeout
	if my_run != run_id:
		return
	state = State.WAITING


# Hastanın noktaları: stetoskobun yeri (göğüs) ve rahatsızlığın noktaları (diken ve benek sayısı günden)
func _add_spots(p: Patient, name: String) -> void:
	p.add_spot("dinle", [Settings.EXAM_TOOL] as Array[String], Settings.EXAM_REGION, Settings.SPOT_RADIUS)
	for info: Dictionary in Settings.AILMENTS[name]["spots"]:
		var spot_steps: Array[String] = []
		spot_steps.assign(info["steps"])
		var count := int(info.get("count", 1))
		if info["look"] == "benek":
			count = int(_day_info.get("rash", count))
		var thorns := int(_day_info.get("thorns", info.get("thorns", 1)))
		for k in count:
			p.add_spot(info["look"], spot_steps, info["region"], Settings.SPOT_RADIUS, {"thorns": thorns})


# Bekleme odası görünür: bank, iyileşenlerin yerinde kalp, bekleyen hastalar, gün yıldızları
func _show_bench() -> void:
	var done: Array[bool] = []
	for w in waiting:
		done.append(w["done"])
		var p: Patient = w["patient"]
		if is_instance_valid(p) and p != patient:
			p.show()
			create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	background.set_waiting(true, done)
	stars.show()
	album.show_button = true
	_set_back_capture(false)


# Banktaki hasta masaya geçer: diğerleri kaybolur, masa ve alet rafı gelir
func _select(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	current = index
	idle_time = 0.0
	_step_busy = false
	var w: Dictionary = waiting[index]
	patient = w["patient"]
	ailment = w["ailment"]
	steps = Settings.visit_steps(ailment)
	step = 0
	sounds.set_voice(Settings.animal(w["animal"]))
	sounds.play("pop", 0.9)
	for k in waiting.size():
		var other: Patient = waiting[k]["patient"]
		if k != index and is_instance_valid(other):
			var fade := create_tween()
			fade.tween_property(other, "modulate:a", 0.0, 0.2)
			fade.tween_callback(other.hide)
	stars.hide()
	album.show_button = false
	background.set_waiting(false)
	if _move:
		_move.kill()
	_move = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move.tween_property(patient, "position", table_top, 0.45)
	_move.parallel().tween_property(patient, "scale", Vector2.ONE * patient_size / patient.size, 0.45)
	patient.hop()
	_update_targets()
	tray.set_tools(steps)
	_set_back_capture(true)
	await get_tree().create_timer(0.6).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


# Tedavi yarıda bırakıldı (geri): hasta banktaki yerine döner, noktaları baştan açılır
func _back_to_bench() -> void:
	if current == -1 or state == State.CELEBRATING:
		return
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	if _finger != -1:
		_release_tool()
	tray.hide_tray()
	bubble.hide_bubble()
	var p := patient
	var seat := seats[current]
	patient = null
	current = -1
	p.clear_spots()
	_add_spots(p, ailment)
	p.unwatch()
	if _move:
		_move.kill()
	_move = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_property(p, "position", seat, 0.4)
	_move.parallel().tween_property(p, "scale", Vector2.ONE * waiting_size / p.size, 0.4)
	_show_bench()
	await get_tree().create_timer(0.45).timeout
	if my_run == run_id:
		state = State.WAITING


# Hasta iyileşti: mutlu yüz, sesi, kalpler ve yıldızlar, dans; sonra gider, bekleme odasına dönülür
func _finish_patient() -> void:
	var my_run := run_id
	state = State.CELEBRATING
	_step_busy = false
	for spot in patient.spots:
		spot.finish_all()                # geliştirici kısayolu adımları atlarsa
	patient.shivering = false
	tray.hide_tray()
	bubble.hide_bubble()
	_set_back_capture(false)
	await get_tree().create_timer(0.3).timeout
	if my_run != run_id:
		return
	patient.cure()
	patient.dance(0.0, 3)
	sounds.play("ses", randf_range(0.98, 1.06))
	sounds.play("iyilesti")
	effects.hearts(patient.head_top_global(), patient_size)
	effects.stars(patient.center_global(), patient_size * 0.6)
	_give_sticker(waiting[current]["animal"], ailment, patient.head_top_global())
	await get_tree().create_timer(Settings.CELEBRATION_TIME).timeout
	if my_run != run_id:
		return
	waiting[current]["done"] = true
	waiting[current]["patient"] = null
	patient.leave(0.0)
	patient = null
	current = -1
	state = State.TRANSITION
	await get_tree().create_timer(0.6).timeout
	if my_run != run_id:
		return
	_show_bench()
	if waiting.all(func(w: Dictionary) -> bool: return w["done"]):
		_finish_day()
	else:
		state = State.WAITING


# Çıkartma kazanıldı: hastanın başından büyüyerek çıkar, albüm düğmesinin yerine uçup küçülür; kaydedilir
func _give_sticker(animal: String, name: String, from: Vector2) -> void:
	album.add(animal, name)
	_save_album()
	var sticker := Sticker.new()
	sticker.z_index = 25
	add_child(sticker)
	sticker.setup(animal, name, patient_size * 0.42, true)
	sticker.position = from + Vector2(0.0, -patient_size * 0.1)
	sticker.scale = Vector2.ZERO
	var tween := sticker.create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(sounds.play.bind("cikartma"))
	tween.tween_property(sticker, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(sticker, "position", album.button_center, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sticker, "scale", Vector2.ONE * 0.3, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(sticker.queue_free)


# Üç hasta da iyileşti: gün yıldızı dolar, konfeti; son günden sonra final, yoksa yeni gün
func _finish_day() -> void:
	run_id += 1
	var my_run := run_id
	state = State.CELEBRATING
	if not endless:
		stars.complete(day)
	sounds.play("gun_sonu")
	effects.confetti(90)
	await get_tree().create_timer(Settings.DAY_END_TIME).timeout
	if my_run != run_id:
		return
	if not endless and day >= Settings.DAYS.size() - 1:
		_finale()
		return
	_start_day(day + 1, endless)


# Son gün de bitti: büyük kutlama, sonra ortak final ekranı (gün seç / baştan oyna / sonsuz klinik / ana menü)
func _finale() -> void:
	var my_run := run_id
	sounds.play("final")
	effects.finale(patient_size * 0.6)
	stars.celebrate_all()
	await get_tree().create_timer(Settings.FINALE_TIME).timeout
	if my_run != run_id:
		return
	_oyun_bitti(false)


# Geliştirici kısayolu (F9): bugünün bütün hastaları iyileşmiş sayılır, gün biter
func _dev_finish_day() -> void:
	if state == State.TRANSITION or state == State.CELEBRATING:
		return
	run_id += 1
	if _finger != -1:
		_release_tool()
	tray.hide_tray()
	bubble.hide_bubble()
	for w in waiting:
		w["done"] = true
		if is_instance_valid(w["patient"]):
			w["patient"].queue_free()
		w["patient"] = null
	patient = null
	current = -1
	_show_bench()
	_finish_day()


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	day = clampi(int(config.get_value("ilerleme", "gun", 0)), 0, Settings.DAYS.size() - 1)
	if config.has_section("album"):
		for key in config.get_section_keys("album"):
			if config.get_value("album", key, false):
				album.stickers[key] = true


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("ilerleme", "gun", day)
	GuvenliKayit.save_config(config, SAVE_PATH)


# Albüm sonsuz klinikte de kaydedilir
func _save_album() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	for key: String in album.stickers:
		config.set_value("album", key, true)
	GuvenliKayit.save_config(config, SAVE_PATH)


# --- Her kare: basılı tutma, çekme, ağza verme, yerleştirme, belirtiler, döngü sesi, ipucu ---

func _process(delta: float) -> void:
	_wince_wait -= delta
	_on_patient = false
	if _finger != -1 and is_instance_valid(patient):
		var tip := tool.tip_global()
		patient.watch(tip)
		_on_patient = patient.contains(tip)
		if Settings.TOOLS[tool.id].get("mouth", false):
			_open_mouth_near(tip)
		match tool.kind:
			Settings.Kind.HOLD, Settings.Kind.FEED:
				_hold(delta)
			Settings.Kind.PLACE:
				_wait_place(delta)
			Settings.Kind.PULL:
				_pull()
	_symptoms(delta)
	# Sürtme sesi: alet hastanın üstünde hareket ettikçe
	var level := 0.0
	var loop: String = Settings.TOOLS.get(tool.id, {}).get("loop", "")
	if _finger != -1 and _on_patient and loop != "":
		level = clampf(_moved / maxf(delta, 0.001) / 900.0, 0.0, 1.0)
	_moved = 0.0
	sounds.set_loop(loop if level > 0.0 else "", level, delta)
	# Uzun süre dokunulmazsa: bekleme odasında bir hasta zıplar; tedavide sırası gelen alet kıpırdar, noktalar parlar
	if state in [State.WAITING, State.PLAYING] and _finger == -1 and not album.shown:
		idle_time += delta
		if idle_time >= Settings.HINT_DELAY:
			idle_time = 0.0
			_idle_hint()


func _idle_hint() -> void:
	if state == State.WAITING:
		var left := waiting.filter(func(w: Dictionary) -> bool: return not w["done"] and is_instance_valid(w["patient"]))
		if not left.is_empty():
			left.pick_random()["patient"].hop()
		return
	if not is_instance_valid(patient):
		return
	tray.wiggle(step)
	for spot in patient.spots:
		if spot.needs(steps[step]):
			spot.pulse()


# Kaşık ya da diş fırçası ağza yaklaşınca hasta ağzını açar
func _open_mouth_near(tip: Vector2) -> void:
	if not _can_work():
		return
	for spot in patient.spots:
		if spot.needs(tool.id) and spot.hit(tip, Settings.FEED_OPEN):
			patient.open_mouth()


# Basılı tutulan alet (ve ağızdaki kaşık) noktanın üstünde durdukça işler; ucunda dolum halkası
func _hold(delta: float) -> void:
	var spot := _spot_under_tip() if _can_work() else null
	if spot == null:
		tool.hold = 0.0
		_hold_contact = false
		return
	if not _hold_contact:
		_hold_contact = true
		_hold_tick = 0.0
		if tool.id == "buz":
			sounds.play("buz", randf_range(0.95, 1.08))
	_react(spot)
	_hold_tick -= delta
	if _hold_tick <= 0.0 and HOLD_TICK.has(tool.id):
		_hold_tick = HOLD_TICK[tool.id]
		if tool.id == "damla":
			sounds.play("damla", randf_range(0.9, 1.15))
			effects.drops(tool.tip_global(), patient_size, 1)
		else:
			sounds.play("kalp")
			effects.hearts(spot.global_position, patient_size * 0.3, 1)
	var finished := spot.work(delta / float(Settings.TOOLS[tool.id]["time"]))
	tool.hold = 1.0 if finished else 1.0 - spot.amount
	if finished:
		if tool.kind == Settings.Kind.FEED:
			patient.swallow()
			sounds.play("yut", randf_range(0.95, 1.08))
		_spot_done(spot)
		_check_step()


# Cımbız: dikenin üstüne gelince diken tutulur; uç, dikene en çok yaklaştığı yerden PULL_DISTANCE kadar uzaklaşınca
# diken çıkar (önce kenarına değip sonra üstüne gelen parmak da tam çekmiş olur)
func _pull() -> void:
	if not _can_work():
		return
	var tip := tool.tip_global()
	if _pulling == null:
		var spot := _spot_under_tip()
		if spot:
			_pulling = spot
			_pull_nearest = INF
			sounds.play("pop", 1.25)
		else:
			return
	var from_thorn := tip.distance_to(_pulling.global_position) / (_pulling.radius * _pulling.global_scale.x)
	_pull_nearest = minf(_pull_nearest, from_thorn)
	var distance := from_thorn - _pull_nearest
	_pulling.set_pull(distance / Settings.PULL_DISTANCE)
	_react(_pulling)
	if distance < Settings.PULL_DISTANCE:
		return
	var spot := _pulling
	_pulling = null
	effects.sparkle(spot.thorn_point(), patient_size * 0.3)
	sounds.play("cek", randf_range(0.95, 1.1))
	if spot.pull_out():
		_spot_done(spot)
		_check_step()


# Yerleştirilecek alet hedefin üstünde biraz durursa parmak kalkmadan da yapışır
func _wait_place(delta: float) -> void:
	var spot := _spot_under_tip() if _can_work() else null
	if spot == null:
		_place_time = 0.0
		return
	_place_time += delta
	if _place_time >= Settings.PLACE_HOLD:
		_place(spot)


# Belirtiler (bekleme odasındaki ve tedavideki hastalarda): nezleli hasta mendil sürülene kadar ara sıra hapşırır;
# ateşli hasta buz konana kadar titrer
func _symptoms(delta: float) -> void:
	if not state in [State.WAITING, State.PLAYING] or album.shown:
		return
	for k in waiting.size():
		var w: Dictionary = waiting[k]
		var p: Patient = w["patient"]
		if w["done"] or not is_instance_valid(p) or (state == State.PLAYING and k != current):
			continue
		if w["ailment"] == "ates":
			p.shivering = p.spots.any(func(s: Spot) -> bool: return s.look == "ates" and not s.done())
		if w["ailment"] != "nezle" or not p.spots.any(func(s: Spot) -> bool: return s.look == "nezle" and not s.done()):
			continue
		w["sneeze"] -= delta
		if w["sneeze"] <= 0.0:
			w["sneeze"] = randf_range(Settings.SNEEZE_GAP.x, Settings.SNEEZE_GAP.y)
			_sneeze(p)


func _sneeze(p: Patient) -> void:
	p.sneeze()
	var my_run := run_id
	await get_tree().create_timer(0.36).timeout
	if my_run != run_id or not is_instance_valid(p):
		return
	sounds.play("hapsu", randf_range(0.95, 1.1))
	effects.drops(p.nose_global(), patient_size * p.scale.x, 5, Vector2.LEFT, 60.0)
