extends Control
# Sıradaki Ne? (PatternGame): 4-8 yaş, yatay ekran, hiç yazı yok. Ekranın ortasında bir örüntü dizisi
# (AB, AAB, ABB, ABC, AABB) durur; çocuk alttaki seçeneklerden doğru parçayı boş yuvaya sürükler.
# Tema her bölümde değişir: boncuk kolye, parti bayrakları, çiçek bahçesi, tırtıl, hayvan geçidi.
# 15 bölüm; sonra ortak final ekranı (OyunBitti). Skor, süre, can yok; yanlış parça yumuşakça geri döner.
#
# Bu sahne bölüm akışını yönetir: bölümü üretir (bolum_uretici.gd, ayarlar.gd), temanın düğümünü kurar
# (THEMES; ortak taban tema.gd), bitince kutlar ve sonrakine geçer; üstte metinsiz ilerleme yıldızları,
# ortak geri düğmesi, başlangıç ipucu eli, kayıt. Dokunmayı ortak DragInput (ortak/surukleme_girdisi.gd)
# okur: aynı anda tek parmak bir parça tutar.

const Settings := preload("res://oyunlar/siradaki_ne/ayarlar.gd")
const Generator := preload("res://oyunlar/siradaki_ne/bolum_uretici.gd")
const PatternTheme := preload("res://oyunlar/siradaki_ne/tema.gd")
const Background := preload("res://oyunlar/siradaki_ne/arka_plan.gd")
const Effects := preload("res://oyunlar/siradaki_ne/efektler.gd")
const Stars := preload("res://oyunlar/siradaki_ne/yildizlar.gd")
const Sounds := preload("res://oyunlar/siradaki_ne/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/siradaki_ne/gorseller/kart_tirtil.svg")
const SAVE_PATH := "user://siradaki_ne.cfg"
## Temalar ve script'leri. Yeni tema: tema.gd'yi extends eden script + buraya kayıt + ayarlar.gd THEMES / pool()
const THEMES := {
	"kolye": preload("res://oyunlar/siradaki_ne/tema_kolye.gd"),
	"bayrak": preload("res://oyunlar/siradaki_ne/tema_bayrak.gd"),
	"bahce": preload("res://oyunlar/siradaki_ne/tema_bahce.gd"),
	"tirtil": preload("res://oyunlar/siradaki_ne/tema_tirtil.gd"),
	"gecit": preload("res://oyunlar/siradaki_ne/tema_gecit.gd"),
}

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@onready var background: Background = $Background
@onready var holder: Node2D = $Board
@onready var effects: Effects = $Effects
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
var plan: Generator.Plan
var generator := Generator.new()
var board: PatternTheme
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	for problem in Settings.problems():
		push_error("Sıradaki Ne?: " + problem)
	_load_progress()
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	drag_input.back_button = back_button
	drag_input.enabled = false
	drag_input.grab_padding = Settings.GRAB_PADDING
	drag_input.drag_scale = Settings.DRAG_SCALE
	drag_input.drop_tolerance = Settings.DROP_TOLERANCE
	stars.setup(Settings.level_count())
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	IpucuEli.ekle(self, "siradaki_ne", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			_on_completed())
	if OyunBitti.tamamlandi_mi("siradaki_ne"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "siradaki_ne", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.level_count(), "kisa": kisa,
		"bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if board:
		await _clear_level()
	stars.setup(Settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: doğru parçayı ilk boş yuvaya sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or board == null or drag_input.active_touch != -1 or board.playing_row:
		return {}
	var move := board.hint_move()
	if move.is_empty():
		return {}
	return IpucuEli.surukle(IpucuEli.ekran_konumu(move[0]), board.row.get_global_transform_with_canvas() * move[1])


func _layout_static() -> void:
	var screen := get_viewport_rect().size
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 760.0)
	stars.layout(Vector2(maxf(screen.x / 2.0, stars_left + stars_width / 2.0), back_button.position.y + back_button.size.y / 2.0), stars_width)


# Ekran boyutu değişirse (masaüstünde pencere) bölüm yeni boyuta göre baştan kurulur
func _on_resized() -> void:
	_layout_static()
	if state == State.PLAYING:
		_start_level(level_index)
	elif plan:
		background.layout(get_viewport_rect().size, plan.floor_y)


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.TRANSITION
	drag_input.cancel()
	level_index = index
	_save_progress()
	stars.set_current(index)
	if board:
		board.queue_free()
	generator.side = maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, Settings.SIDE), EkranYardimcisi.kenar_payi(SIDE_RIGHT, Settings.SIDE))
	plan = generator.generate(index, get_viewport_rect().size, EkranYardimcisi.tasarim_alani())
	background.show_theme(plan.theme, plan.screen, plan.floor_y)
	board = THEMES[plan.theme].new()
	holder.add_child(board)
	board.setup(plan, sounds, effects, drag_input)
	board.completed.connect(_on_completed)
	board.build()
	drag_input.lift = plan.cell * Settings.DRAG_LIFT
	await get_tree().create_timer(0.9).timeout
	if my_run != run_id:
		return
	state = State.PLAYING
	board.play_row()


func _on_completed() -> void:
	if state != State.PLAYING:
		return
	state = State.CELEBRATING
	var my_run := run_id
	drag_input.cancel()
	await get_tree().create_timer(0.3).timeout
	if my_run != run_id:
		return
	await board.celebrate()
	if my_run != run_id:
		return
	await board.finish()
	if my_run != run_id:
		return
	stars.complete(level_index)
	if level_index >= Settings.level_count() - 1:
		_finale()
		return
	sounds.play("bolum_sonu")
	await get_tree().create_timer(Settings.CELEBRATION_TIME).timeout
	if my_run != run_id:
		return
	await _clear_level()
	if my_run != run_id:
		return
	_start_level(level_index + 1)


# Son bölüm bitti: büyük kutlama, sonra ortak final ekranı (bölüm seç / baştan oyna / ana menü)
func _finale() -> void:
	var my_run := run_id
	sounds.play("final")
	effects.finale(minf(plan.screen.x, plan.screen.y) * 0.3)
	stars.celebrate_all()
	await get_tree().create_timer(Settings.FINALE_TIME).timeout
	if my_run != run_id:
		return
	await _clear_level()
	if my_run != run_id:
		return
	_oyun_bitti(false)


func _clear_level() -> void:
	state = State.TRANSITION
	drag_input.cancel()
	await board.leave()
	board.queue_free()
	board = null


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
