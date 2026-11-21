extends Control
# Yapboz (JigsawGame): 4-8 yaş, yatay ekran, hiç yazı yok. Bölüm başında resmin tamamı görünür, sonra
# klasik yapboz parçalarına ayrılıp tahtanın iki yanındaki tepsilere dağılır. Çocuk parçaları tahtaya
# sürükler; parça kendi yerine yakın bırakılınca oturur, başka yere bırakılınca yumuşakça tepsiye döner.
# Bütün parçalar oturunca resim parlar, resme özel ses çalar, sonraki bölüm gelir. Son bölümden sonra
# ortak final ekranı (OyunBitti). Skor, süre, can yok.
#
# Bu sahne bölüm akışını yönetir: parçaları keser (kesici.gd), yerleşimi hesaplar (yerlesim.gd), tahtayı
# (tahta.gd) ve parçaları (parca.gd) kurar; üstte metinsiz ilerleme yıldızları, ortak geri düğmesi,
# başlangıç ipucu eli, kayıt. Dokunmayı ortak DragInput (ortak/surukleme_girdisi.gd) okur: aynı anda tek
# parmak bir parça tutar. Ayarlar ayarlar.gd'de.

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const Cutter := preload("res://oyunlar/yapboz/kesici.gd")
const Layout := preload("res://oyunlar/yapboz/yerlesim.gd")
const Board := preload("res://oyunlar/yapboz/tahta.gd")
const Piece := preload("res://oyunlar/yapboz/parca.gd")
const Background := preload("res://oyunlar/yapboz/arka_plan.gd")
const Effects := preload("res://oyunlar/yapboz/efektler.gd")
const Stars := preload("res://oyunlar/yapboz/yildizlar.gd")
const Sounds := preload("res://oyunlar/yapboz/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const TEX_CHARACTER: Texture2D = preload("res://oyunlar/yapboz/gorseller/kart_yapboz.svg")
const SAVE_PATH := "user://yapboz.cfg"

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
var layout: Layout.Layout
var board: Board
var pieces: Array = []           # bu bölümün parçaları (Piece)
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for problem in Settings.problems():
		push_error("Yapboz: " + problem)
	rng.randomize()
	_load_progress()
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	drag_input.back_button = back_button
	drag_input.enabled = false
	drag_input.grab_padding = Settings.GRAB_PADDING
	drag_input.item_grabbed.connect(_on_grabbed)
	drag_input.item_dropped.connect(_on_dropped)
	drag_input.item_canceled.connect(_on_canceled)
	stars.setup(Settings.level_count())
	_layout_static()
	get_viewport().size_changed.connect(_on_resized)
	_start_level(level_index)
	IpucuEli.ekle(self, "yapboz", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			_solve_all())
	if OyunBitti.tamamlandi_mi("yapboz"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "yapboz", "karakter": TEX_CHARACTER, "bolum_sayisi": Settings.level_count(), "kisa": kisa,
		"bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	if board:
		await _clear_level()
	stars.setup(Settings.level_count())
	_start_level(index)


# Başlangıç ipucu eli: ilk oturmamış parçayı yerine sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or drag_input.active_touch != -1:
		return {}
	var piece = _next_piece()
	if piece == null or piece.settling:
		return {}
	return IpucuEli.surukle(IpucuEli.ekran_konumu(piece), board.get_global_transform_with_canvas() * piece.target)


# İpucu ve testler için: henüz oturmamış ilk parça (soldan sağa, yukarıdan aşağı)
func _next_piece():
	for piece in pieces:
		if not piece.placed:
			return piece
	return null


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
	drag_input.cancel()
	level_index = index
	_save_progress()
	stars.set_current(index)
	if board:
		board.queue_free()
	var level: Dictionary = Settings.LEVELS[index]
	var picture: String = level["picture"]
	var cols: int = level["cols"]
	var rows: int = level["rows"]
	background.show_color(Settings.PICTURES[picture]["color"])
	var side := maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, Settings.SIDE), EkranYardimcisi.kenar_payi(SIDE_RIGHT, Settings.SIDE))
	layout = Layout.make(cols, rows, get_viewport_rect().size, EkranYardimcisi.tasarim_alani(), side)
	var cuts := Cutter.cut(cols, rows, Settings.PICTURE_SIZE, rng)
	var texture: Texture2D = load(Settings.picture_path(picture))
	board = Board.new()
	holder.add_child(board)
	board.setup(layout, texture, cuts, level["ghost"])
	# Parçalar: yuvalara karışık sırada
	var order := range(cuts.size())
	_shuffle(order)
	pieces = []
	for k in cuts.size():
		var data: Dictionary = cuts[k]
		var piece := Piece.new()
		var cell: Rect2 = data["cell"]
		var target := layout.board.position + cell.get_center() * layout.scale
		var slot: Vector2 = layout.slots[order[k]]
		var jitter := layout.cell * layout.tray_ratio * Settings.TRAY_JITTER
		slot += Vector2(rng.randf_range(-jitter.x, jitter.x), rng.randf_range(-jitter.y, jitter.y))
		piece.setup_piece(data, texture, layout.scale, layout.tray_ratio, target, slot)
		piece.visible = false
		board.add_child(piece)
		pieces.append(piece)
	drag_input.items = pieces
	drag_input.drag_scale = Settings.DRAG_GROW / layout.tray_ratio
	drag_input.lift = layout.cell.y * Settings.DRAG_LIFT
	# Önce resmin tamamı, sonra parçalar tepsilere dağılır
	board.show_whole()
	board.modulate.a = 0.0
	board.create_tween().tween_property(board, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(Settings.LOOK_TIME).timeout
	if my_run != run_id:
		return
	board.start_play(Settings.SCATTER_TIME)
	sounds.play("dagil")
	for k in pieces.size():
		pieces[k].visible = true
		pieces[k].scatter(k * Settings.SCATTER_STAGGER, Settings.SCATTER_TIME)
	await get_tree().create_timer(Settings.SCATTER_TIME + pieces.size() * Settings.SCATTER_STAGGER).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


func _shuffle(order: Array) -> void:
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap


# --- Sürükleme ---

func _on_grabbed(item) -> void:
	sounds.play("tut")
	# Tutulan parça diğerlerinin üstünde (ortak DraggableItem z_index'i de büyütür)
	board.move_child(item, board.get_child_count() - 1)


func _on_dropped(item, point: Vector2) -> void:
	var piece = item
	if state != State.PLAYING or piece.placed:
		return
	if point.distance_to(piece.target) <= minf(layout.cell.x, layout.cell.y) * Settings.SNAP:
		_seat(piece)
	else:
		sounds.play("geri")
		piece.return_home(Settings.BACK_TIME, true)


func _on_canceled(item) -> void:
	var piece = item
	if not piece.placed:
		piece.return_home(Settings.BACK_TIME, false)


func _seat(piece) -> void:
	piece.seat(Settings.SEAT_TIME, func() -> void:
		effects.sparkle(piece.target, minf(layout.cell.x, layout.cell.y)))
	sounds.play("otur")
	if _next_piece() == null:
		_on_completed()


# F9 (yalnızca debug): kalan bütün parçaları yerine oturtur
func _solve_all() -> void:
	for piece in pieces:
		if not piece.placed:
			piece.seat(Settings.SEAT_TIME)
	_on_completed()


func _on_completed() -> void:
	if state != State.PLAYING:
		return
	state = State.CELEBRATING
	var my_run := run_id
	drag_input.cancel()
	await get_tree().create_timer(Settings.SEAT_TIME + 0.35).timeout
	if my_run != run_id:
		return
	for piece in pieces:
		piece.hide_outline(0.3)
	await board.celebrate()
	if my_run != run_id:
		return
	var picture: String = Settings.LEVELS[level_index]["picture"]
	sounds.play(Settings.PICTURES[picture]["sound"])
	effects.stars(layout.board.get_center(), minf(layout.board.size.x, layout.board.size.y) * 0.5)
	stars.complete(level_index)
	if level_index >= Settings.level_count() - 1:
		_finale()
		return
	await get_tree().create_timer(0.5).timeout
	if my_run != run_id:
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
	drag_input.cancel()
	drag_input.items = []
	await board.leave()
	board.queue_free()
	board = null
	pieces = []


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
