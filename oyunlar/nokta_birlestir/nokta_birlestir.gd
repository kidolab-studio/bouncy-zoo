extends Control
# Noktaları Birleştir (DotsGame): 4-8 yaş, yatay ekran, yazı yok (yalnızca noktaların numaraları). Beyaz
# kâğıtta soluk bir sahne ve numaralı noktalar var. Çocuk noktaları sırayla birleştirir: sıradaki noktaya
# dokunarak ya da parmağını noktadan noktaya kaydırarak (ikisi de olur). Son nokta bağlanınca şekil kendiliğinden
# kapanır, renkli resim belirir ve hareket eder (ev zıplar, yelkenli sallanır...), resme özel ses çalar,
# sonra sonraki bölüm. Son bölümden sonra ortak final ekranı (OyunBitti). Skor, süre, can yok; yanlış noktaya
# dokunulursa nokta nazikçe sallanır.
#
# Bu sahne bölüm akışını yönetir: sayfayı (cizim.gd) kurar, dokunmayı (nokta_girdisi.gd) yorumlar; üstte
# metinsiz ilerleme yıldızları, ortak geri düğmesi, başlangıç ipucu eli, kayıt. Ayarlar ayarlar.gd'de.

const Settings := preload("res://oyunlar/nokta_birlestir/ayarlar.gd")
const Page := preload("res://oyunlar/nokta_birlestir/cizim.gd")
const Background := preload("res://oyunlar/nokta_birlestir/arka_plan.gd")
const Effects := preload("res://oyunlar/nokta_birlestir/efektler.gd")
const Stars := preload("res://oyunlar/nokta_birlestir/yildizlar.gd")
const Sounds := preload("res://oyunlar/nokta_birlestir/sesler.gd")
const DotInput := preload("res://oyunlar/nokta_birlestir/nokta_girdisi.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/nokta_birlestir/gorseller/kart_kalem.svg")
const SAVE_PATH := "user://nokta_birlestir.cfg"
## Bağlanan noktanın sesi gamda yükselir (yarım ses; 8 notada bir başa döner)
const SCALE_STEPS := [0, 2, 4, 5, 7, 9, 11, 12]

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@onready var background: Background = $Background
@onready var holder: Node2D = $Pages
@onready var effects: Effects = $Effects
@onready var stars: Stars = $Stars
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds
@onready var dot_input: DotInput = $DotInput

var state: State = State.TRANSITION:
	set(value):
		state = value
		if dot_input:
			dot_input.enabled = value == State.PLAYING
var level_index: int = 0
var page: Page
var drawing: bool = false        # parmak basılı ve çizgi son noktadan parmağa uzanıyor
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	for problem in Settings.problems():
		push_error("Noktaları Birleştir: " + problem)
	_load_progress()
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	dot_input.back_button = back_button
	dot_input.enabled = false
	dot_input.pressed.connect(_on_pressed)
	dot_input.moved.connect(_on_moved)
	dot_input.released.connect(_on_released)
	stars.setup(Settings.level_count())
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	IpucuEli.ekle(self, "nokta_birlestir", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			_finish_drawing())
	if OyunBitti.tamamlandi_mi("nokta_birlestir"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "nokta_birlestir", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.level_count(), "kisa": kisa,
		"bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if page:
		await _clear_level()
	stars.setup(Settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: ilk noktaya dokun, sonra son noktadan sıradakine kaydır
func _ipucu() -> Dictionary:
	if state != State.PLAYING or dot_input.active_touch != -1 or page == null:
		return {}
	var next := page.next_index()
	if next < 0:
		return {}
	if page.done == 0:
		return IpucuEli.dokun(page.dots[next])
	return IpucuEli.surukle(page.dots[page.tail_index()], page.dots[next])


func _layout_static() -> void:
	var screen := get_viewport_rect().size
	background.layout(screen)
	var stars_left := back_button.position.x + back_button.size.x + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 600.0)
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
	drawing = false
	dot_input.cancel()
	level_index = index
	_save_progress()
	stars.set_current(index)
	if page:
		page.queue_free()
	var picture := Settings.picture_of(index)
	background.show_color(Settings.PICTURES[picture]["color"])
	page = Page.new()
	holder.add_child(page)
	page.setup(picture, Settings.picture_rect(get_viewport_rect().size, EkranYardimcisi.tasarim_alani()))
	await page.appear()
	if my_run != run_id:
		return
	state = State.PLAYING


# --- Dokunma ---

func _on_pressed(pos: Vector2) -> void:
	if state != State.PLAYING:
		return
	var i := page.dot_at(pos)
	if i >= 0 and i == page.next_index():
		_connect(true)
	elif i > page.next_index():
		# Sırası gelmeyen nokta: nazikçe sallanır (bağlanmış noktalara dokunmak bir şey yapmaz)
		page.wiggle(i)
		sounds.play("yanlis")
		return
	# Çizgi son noktadan parmağa uzanır; parmak sıradaki noktanın üstünden geçince o da bağlanır
	drawing = state == State.PLAYING and page.done > 0
	page.set_rubber(pos if drawing else null)


func _on_moved(from: Vector2, to: Vector2) -> void:
	if not drawing or state != State.PLAYING:
		return
	# Hızlı kaydırmada parmak tek hamlede birden çok noktanın üstünden geçebilir
	while state == State.PLAYING and page.hits_next(from, to):
		_connect(false)
	page.set_rubber(to if state == State.PLAYING else null)


func _on_released() -> void:
	drawing = false
	if page:
		page.set_rubber(null)


func _connect(animated: bool) -> void:
	var index := page.next_index()
	page.connect_next(animated)
	var step: int = SCALE_STEPS[index % SCALE_STEPS.size()]
	sounds.play("nokta", pow(2.0, step / 12.0))
	effects.sparkle(page.dots[index], Settings.DOT_RADIUS * 2.0)
	if page.next_index() < 0:
		_on_completed()


# F9 (yalnızca debug): kalan noktaları bağlar
func _finish_drawing() -> void:
	while page.next_index() >= 0 and state == State.PLAYING:
		_connect(false)


func _on_completed() -> void:
	if state != State.PLAYING:
		return
	state = State.CELEBRATING
	drawing = false
	dot_input.cancel()
	page.set_rubber(null)
	var my_run := run_id
	await get_tree().create_timer(Settings.SEGMENT_TIME).timeout
	if my_run != run_id:
		return
	await page.close_shape(0.3)
	if my_run != run_id:
		return
	sounds.play("kapan")
	await page.reveal()
	if my_run != run_id:
		return
	var picture := Settings.picture_of(level_index)
	sounds.play(Settings.PICTURES[picture]["sound"])
	var size := minf(page.rect.size.x, page.rect.size.y)
	effects.stars(page.object_center(), size * 0.5)
	stars.complete(level_index)
	if Settings.PICTURES[picture]["anim"] == "parla":
		_glitter(size)
	await page.animate(Settings.PICTURES[picture]["anim"])
	if my_run != run_id:
		return
	if level_index >= Settings.level_count() - 1:
		_finale()
		return
	sounds.play("bolum_sonu")
	effects.confetti(90)
	await get_tree().create_timer(Settings.CELEBRATION_TIME).timeout
	if my_run != run_id:
		return
	await _clear_level()
	if my_run != run_id:
		return
	_start_level(level_index + 1)


# "parla" hareketinde resmin üstünde sırayla ışıltılar
func _glitter(size: float) -> void:
	var tween := create_tween()
	for k in 5:
		var point := page.rect.get_center() + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.2)) * page.rect.size
		tween.tween_callback(effects.sparkle.bind(point, size * 0.25))
		tween.tween_interval(0.18)


# Son bölüm bitti: büyük kutlama, sonra ortak final ekranı (bölüm seç / baştan oyna / ana menü)
func _finale() -> void:
	var my_run := run_id
	sounds.play("final")
	var screen := get_viewport_rect().size
	effects.finale(minf(screen.x, screen.y) * 0.3)
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
	drawing = false
	dot_input.cancel()
	await page.leave()
	page.queue_free()
	page = null


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
