extends Control
# Labirent (MazeGame): 4-8 yaş, yatay ekran, yazı yok. Üstten görülen bir labirent tahtasında bir hayvan ve
# labirentin öbür ucunda onun yemeği durur (tavşan → havuç, sincap → palamut...). Çocuk hayvanı parmağıyla tutup
# koridorlarda sürükler; hayvan duvardan geçemez (duvara gelince durur, başını sallar), parmak kalkınca olduğu
# yerde bekler. Geçtiği yolda iz kalır, yoldaki yıldızlar toplanır (isteğe bağlı). Yemeğe varınca hayvan yer,
# sevinir, kendi sesini çıkarır, konfeti, sonraki bölüm. Son bölümden sonra ortak final ekranı (OyunBitti).
# Skor, süre, can yok.
#
# Bu sahne bölüm akışını yönetir: tahtayı (labirent_cizim.gd) kurar, dokunmayı (labirent_girdisi.gd) yorumlar,
# hayvanı yol ağında (yol_agi.gd) yürütür; üstte metinsiz ilerleme yıldızları, ortak geri düğmesi, başlangıç
# ipucu eli, kayıt. Ayarlar ayarlar.gd'de.

const Settings := preload("res://oyunlar/labirent/ayarlar.gd")
const Board := preload("res://oyunlar/labirent/labirent_cizim.gd")
const Walker := preload("res://oyunlar/labirent/yol_agi.gd")
const Background := preload("res://oyunlar/labirent/arka_plan.gd")
const Effects := preload("res://oyunlar/labirent/efektler.gd")
const Stars := preload("res://oyunlar/labirent/yildizlar.gd")
const Sounds := preload("res://oyunlar/labirent/sesler.gd")
const MazeInput := preload("res://oyunlar/labirent/labirent_girdisi.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/labirent/gorseller/hayvanlar/tavsan_mutlu.svg")
const SAVE_PATH := "user://labirent.cfg"
## Hayvan her hücreye varınca adım sesi gamda yükselir (8 notada bir başa döner)
const SCALE_STEPS := [0, 2, 4, 5, 7, 9, 11, 12]

enum State { TRANSITION, PLAYING, CELEBRATING }

@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@onready var background: Background = $Background
@onready var holder: Node2D = $Boards
@onready var effects: Effects = $Effects
@onready var stars: Stars = $Stars
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds
@onready var maze_input: MazeInput = $MazeInput

var state: State = State.TRANSITION:
	set(value):
		state = value
		if maze_input:
			maze_input.enabled = value == State.PLAYING
var level_index: int = 0
var board: Board
var walker := Walker.new()
var dragging: bool = false       # hayvan parmakta
var finger := Vector2.ZERO
var food_cell := Vector2i.ZERO
var last_cell := Vector2i.ZERO   # hayvanın en son vardığı hücre (iz buradan uzar)
var steps: int = 0               # adım sesi perdesi için
var bumped: bool = false         # duvar sesi bir kez çalsın (hayvan yeniden yürüyünce sıfırlanır)
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin


func _ready() -> void:
	for problem in Settings.problems():
		push_error("Labirent: " + problem)
	_load_progress()
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	maze_input.back_button = back_button
	maze_input.enabled = false
	maze_input.pressed.connect(_on_pressed)
	maze_input.moved.connect(_on_moved)
	maze_input.released.connect(_on_released)
	stars.setup(Settings.level_count())
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	IpucuEli.ekle(self, "labirent", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			_on_food_reached())
	if OyunBitti.tamamlandi_mi("labirent"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "labirent", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.level_count(), "kisa": kisa,
		"bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if board:
		await _clear_level()
	stars.setup(Settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: hayvanı yemeğe giden yolda, düz koridor boyunca (en fazla 3 hücre) sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or maze_input.active_touch != -1 or board == null:
		return {}
	var path := Settings.solution(board.map, walker.nearest_cell(), food_cell)
	if path.size() < 2:
		return {}
	var direction := path[1] - path[0]
	var end := 1
	while end + 1 < path.size() and end < 3 and path[end + 1] - path[end] == direction:
		end += 1
	return IpucuEli.surukle(walker.position(), board.cell_center(path[end]))


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
	dragging = false
	maze_input.cancel()
	level_index = index
	_save_progress()
	stars.set_current(index)
	if board:
		board.queue_free()
	var map := Settings.map_of(index)
	background.show_color(Settings.ground_of(index)["back"])
	var rect := Settings.board_rect(map, get_viewport_rect().size, EkranYardimcisi.tasarim_alani())
	board = Board.new()
	holder.add_child(board)
	board.setup(index, rect)
	var start := Settings.find_cell(map, "S")
	walker.setup(map, rect, start)
	food_cell = Settings.find_cell(map, "Y")
	last_cell = start
	steps = 0
	bumped = false
	await board.appear()
	if my_run != run_id:
		return
	state = State.PLAYING


# --- Dokunma ---

func _on_pressed(pos: Vector2) -> void:
	if state != State.PLAYING:
		return
	var grab := maxf(Settings.MIN_GRAB, Settings.GRAB_RADIUS * walker.cell)
	if pos.distance_to(walker.position()) <= grab:
		dragging = true
		finger = pos
		board.set_grabbed(true)
		sounds.play("tut")
	else:
		# Hayvandan uzağa dokunuldu: hayvan başını sallayıp "beni tut" der
		board.wiggle()


func _on_moved(_from: Vector2, to: Vector2) -> void:
	if dragging:
		finger = to


func _on_released() -> void:
	if dragging:
		dragging = false
		if board:
			board.set_grabbed(false)


func _process(delta: float) -> void:
	if not dragging or state != State.PLAYING:
		return
	var result := walker.step(finger, Settings.SPEED * walker.cell * delta)
	board.set_animal_position(walker.position(), result["moved"] > 0.5)
	for cell in result["entered"]:
		_on_cell_entered(cell)
	if state != State.PLAYING:
		return
	board.set_partial(walker.center(last_cell), walker.position())
	_collect_stars()
	if walker.position().distance_to(walker.center(food_cell)) < walker.cell * 0.3:
		_on_food_reached()
		return
	if result["bumped"] and not bumped:
		bumped = true
		board.wiggle()
		sounds.play("duvar")
	elif result["moved"] > 0.5:
		bumped = false


func _on_cell_entered(cell: Vector2i) -> void:
	if cell == last_cell:
		return
	board.add_trail(last_cell, cell)
	last_cell = cell
	var step: int = SCALE_STEPS[steps % SCALE_STEPS.size()]
	steps += 1
	sounds.play("adim", pow(2.0, step / 12.0))


func _collect_stars() -> void:
	for cell in board.stars.keys():
		if walker.position().distance_to(board.cell_center(cell)) < Settings.STAR_RADIUS * walker.cell:
			board.collect_star(cell)
			effects.sparkle(board.cell_center(cell), walker.cell * 0.8)
			sounds.play("yildiz")


# Yemeğe varıldı (ya da F9): hayvan yer, sevinir; sonra sonraki bölüm ya da final
func _on_food_reached() -> void:
	if state != State.PLAYING:
		return
	state = State.CELEBRATING
	dragging = false
	maze_input.cancel()
	var my_run := run_id
	if Settings.neighbors(board.map, last_cell).has(food_cell):
		board.set_partial(walker.center(last_cell), walker.center(food_cell))
	sounds.play("yemek")
	await board.eat()
	if my_run != run_id:
		return
	sounds.play(board.animal_name)
	effects.stars(board.animal.position, walker.cell * 1.2)
	stars.complete(level_index)
	await get_tree().create_timer(Settings.EAT_TIME * 0.5).timeout
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
	dragging = false
	maze_input.cancel()
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
