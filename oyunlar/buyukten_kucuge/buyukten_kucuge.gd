extends Control
# Büyükten Küçüğe (SizeOrderGame): 2-5 yaş, yatay ekran, hiç yazı yok. Çocuk nesneleri boyutlarına göre
# sıralar (büyük/küçük, uzun/kısa). Üç etkinlik türü bölümlere göre dönüşümlü gelir: Halka Kulesi,
# Sıralama Dizisi, İç İçe Bebekler. 15 bölüm; son bölümden sonra büyük kutlama ve 1. bölüm. Skor, süre, can yok.
#
# Bu sahne bölüm akışını yönetir: bölümü üretir (SizeLevelGenerator, ayarlar.tres), etkinliğin sahnesini
# kurar (ACTIVITIES; ortak arayüz etkinlik.gd), bitince kutlar ve sonrakine geçer; boşta kalınca ipucu
# (ortak ipucu eli), üstte metinsiz ilerleme yıldızları, basılı geri düğmesi, kayıt.
# Dokunmayı ortak DragInput (ortak/surukleme_girdisi.gd) okur: aynı anda tek parmak bir nesne tutar.

signal level_completed(index: int)
signal all_levels_completed

const Activity := preload("res://oyunlar/buyukten_kucuge/etkinlik.gd")
const Background := preload("res://oyunlar/buyukten_kucuge/arka_plan.gd")
const Effects := preload("res://oyunlar/buyukten_kucuge/efektler.gd")
const Stars := preload("res://oyunlar/buyukten_kucuge/yildizlar.gd")
const Sounds := preload("res://oyunlar/buyukten_kucuge/sesler.gd")
const HintHand := preload("res://ortak/ipucu_eli.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const SAVE_PATH := "user://buyukten_kucuge.cfg"
## Etkinlik türleri (SizeLevel.kind) ve sahneleri. Yeni tür: etkinlik.gd'yi extends eden sahne + buraya kayıt
const ACTIVITIES := {
	"halka": preload("res://oyunlar/buyukten_kucuge/halka_kulesi.tscn"),
	"dizi": preload("res://oyunlar/buyukten_kucuge/siralama_dizisi.tscn"),
	"bebek": preload("res://oyunlar/buyukten_kucuge/ic_ice_bebekler.tscn"),
}

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bölüm tablosu, boyut kuralları ve nesne türleri. Tek yer: ayarlar.tres
@export var settings: SizeSettings

@export_group("Oynanış")
## Bırakma toleransı: hedef alanı (yuva, direk, bebek) kısa kenarının bu oranı kadar büyütülür (ortak DragInput ayarı).
@export_range(0.0, 1.0) var drop_tolerance: float = 0.4
## Yakalama alanı, nesne görselinin bu kadar katı (en az dokunma alanı ayarlar.tres touch_ratio).
@export_range(1.0, 1.8) var grab_padding: float = 1.15
## Bu kadar saniye hiçbir şey yapılmazsa ipucu: sıradaki doğru nesne parlar, el onu hedefe götürür.
@export var hint_delay: float = 8.0
## Basılı tutunca geri dönme süresi (saniye).
@export var hold_to_exit: float = 0.6

@export_group("Görünüm ve animasyon")
## Sürüklerken nesnenin büyüme oranı.
@export var drag_scale: float = 1.1
## Sürüklerken nesne parmağın ne kadar üstünde dursun (dokunma alanına oran).
@export var drag_lift: float = 0.5
## Bölüm sonu kutlamasının (etkinliğin kendi gösterisinden sonra) süresi.
@export var celebration_time: float = 1.6
## Son bölümden sonraki büyük kutlamanın süresi.
@export var finale_time: float = 5.0

@onready var background: Background = $Background
@onready var holder: Node2D = $Activity
@onready var effects: Effects = $Effects
@onready var hand: HintHand = $Hand
@onready var stars: Stars = $Stars
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds
@onready var drag_input: DragInput = $DragInput

var state: State = State.TRANSITION:
	set(value):
		state = value
		if drag_input:
			drag_input.enabled = value == State.PLAYING
var level_index: int = 0
var plan: SizeLevelGenerator.Plan
var generator: SizeLevelGenerator
var activity: Activity
var idle_time: float = 0.0
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	if settings == null:
		settings = load("res://oyunlar/buyukten_kucuge/ayarlar.tres")
	for problem in settings.problems():
		push_error("Büyükten Küçüğe: " + problem)
	generator = SizeLevelGenerator.new(settings)
	_load_progress()
	back_button.hold_time = hold_to_exit
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	drag_input.back_button = back_button
	drag_input.enabled = false
	drag_input.grab_padding = grab_padding
	drag_input.drag_scale = drag_scale
	drag_input.drop_tolerance = drop_tolerance
	drag_input.touched.connect(_on_touched)
	level_completed.connect(_on_level_completed)
	all_levels_completed.connect(_on_all_levels_completed)
	stars.setup(settings.level_count())
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	var ipucu := IpucuEli.ekle(self, "buyukten_kucuge", _ipucu)
	ipucu.engel = func() -> bool: return hand.visible   # oyunun kendi ipucu eli görünürken çekilir
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			state = State.CELEBRATING
			level_completed.emit(level_index))
	if OyunBitti.tamamlandi_mi("buyukten_kucuge"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "buyukten_kucuge", "karakter": load("res://ana_menu/kartlar/buyukten_kucuge.svg"),
		"bolum_sayisi": settings.level_count(), "kisa": kisa, "bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if activity:
		await _clear_level()
	stars.setup(settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: etkinliğin sıradaki doğru hamlesi (nesneyi hedefine sürükle)
func _ipucu() -> Dictionary:
	if state != State.PLAYING or activity == null or drag_input.active_touch != -1:
		return {}
	var move := activity.hint_move()
	if move.is_empty():
		return {}
	return IpucuEli.surukle(IpucuEli.ekran_konumu(move[0]), activity.get_global_transform_with_canvas() * move[1])


func _layout_static() -> void:
	var screen := get_viewport_rect().size
	background.layout(screen)
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 760.0)
	stars.layout(Vector2(maxf(screen.x / 2.0, stars_left + stars_width / 2.0), back_button.position.y + back_button.size.y / 2.0), stars_width)


# Ekran boyutu değişirse (masaüstünde pencere) bölüm yeni boyuta göre baştan kurulur
func _on_resized() -> void:
	_layout_static()
	if state == State.PLAYING:
		_start_level(level_index)


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	drag_input.cancel()
	hand.stop()
	level_index = index
	idle_time = 0.0
	_save_progress()
	stars.set_current(index)
	if activity:
		activity.queue_free()
	generator.side = maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, SizeLevelGenerator.SIDE), EkranYardimcisi.kenar_payi(SIDE_RIGHT, SizeLevelGenerator.SIDE))
	plan = generator.generate(index, get_viewport_rect().size)
	activity = ACTIVITIES[plan.kind].instantiate()
	holder.add_child(activity)
	activity.setup(plan, sounds, effects, hand, drag_input)
	activity.completed.connect(_on_activity_completed)
	activity.build()
	hand.set_hand_size(plan.touch * 1.5)
	drag_input.lift = plan.touch * drag_lift
	await get_tree().create_timer(0.9).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


func _on_activity_completed() -> void:
	if state != State.PLAYING:
		return
	state = State.CELEBRATING
	level_completed.emit(level_index)


func _on_level_completed(index: int) -> void:
	var my_run := run_id
	drag_input.cancel()
	hand.stop()
	await get_tree().create_timer(0.35).timeout
	if my_run != run_id:
		return
	await activity.celebrate()
	if my_run != run_id:
		return
	stars.complete(index)
	if index >= settings.level_count() - 1:
		all_levels_completed.emit()
		return
	sounds.play("bolum_sonu")
	effects.confetti(90)
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
	effects.finale(minf(plan.screen.x, plan.screen.y) * 0.3)
	stars.celebrate_all()
	for item in activity.items:
		if is_instance_valid(item) and item.visible:
			item.hop(randf() * 0.4, 4)
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
	await activity.leave()
	activity.queue_free()
	activity = null


# --- İpucu ---

func _on_touched() -> void:
	idle_time = 0.0
	if hand.visible:
		hand.stop()


func _process(delta: float) -> void:
	if state == State.PLAYING and drag_input.active_touch == -1:
		idle_time += delta
		if idle_time >= hint_delay:
			idle_time = 0.0
			activity.show_hint()


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
