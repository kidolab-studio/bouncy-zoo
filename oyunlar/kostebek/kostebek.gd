extends Control
# Köstebek Vurma (MoleGame): çukurlardan köstebek, meyve/sebze ya da bomba çıkar.
# Köstebek +30, meyve +10, bomba 1 can götürür; kaçan hiçbir şey için ceza yok. 3 can bitince oyun biter.
# Skor arttıkça seviye atlanır ve oyun hızlanır; bütün denge değerleri denge.tres (MoleBalance) içinde.
#
# Durumlar: COUNTDOWN (3-2-1) -> PLAYING -> GAME_OVER (skor, rekor, tekrar oyna / ana menü).
# Dokunmanın tamamı burada (_input): her parmak ayrı sayılır, vurma basış anında olur.

signal state_changed(state: State)

const GameState := preload("res://oyunlar/kostebek/oyun_durumu.gd")
const Hole := preload("res://oyunlar/kostebek/cukur.gd")
const Item := preload("res://oyunlar/kostebek/cikan_nesne.gd")
const Spawner := preload("res://oyunlar/kostebek/cikis_yoneticisi.gd")
const Effects := preload("res://oyunlar/kostebek/efektler.gd")
const Hud := preload("res://oyunlar/kostebek/arayuz.gd")
const Sounds := preload("res://oyunlar/kostebek/sesler.gd")

enum State { COUNTDOWN, PLAYING, GAME_OVER }

## Bütün denge ayarları (puanlar, can, seviyeler...). Değiştirmek için denge.tres'i aç.
@export var balance: MoleBalance
## Basılı tutunca ana menüye dönme süresi (saniye).
@export var hold_to_exit: float = 0.6
## Geri sayımda her sayının süresi (saniye).
@export var countdown_step: float = 0.8
## Bombaya dokununca ekran sarsıntısının gücü (piksel).
@export var bomb_shake: float = 12.0

const TOP_AREA := 150.0        # üstte arayüz (geri, skor, kalpler)
const SIDE_MARGIN := 40.0
const BOTTOM_MARGIN := 30.0
# Nesnenin çukurdan taşan kısmının satır hesabına katılan oranı (üstteki satıra biraz taşabilir)
const OVERLAP_SHARE := 0.7
const COUNT_COLORS: Array[Color] = [Color("ff7a9a"), Color("ffa53d"), Color("5cc95c")]
const MOLE_TEXT_COLOR := Color("ffd23f")
const FRUIT_TEXT_COLOR := Color("8ee05a")

@onready var holes_layer: Node2D = $World/Holes
@onready var effects: Effects = $World/Effects
@onready var spawner: Spawner = $Spawner
@onready var hud: Hud = $UI/Hud
@onready var sounds: Sounds = $Sounds

var state: State = State.COUNTDOWN
var game: GameState
var holes: Array[Node2D] = []
var hole_count: int = 0
var back_touch: int = -1          # geri düğmesini tutan parmak (-1: yok)
var _pending_hole_count: int = 0  # seviye yeni çukur düzeni istiyor: çukurlar boşalınca kurulur
var _run_id: int = 0              # durum değişince eski beklemeler devam etmesin
var _replaying: bool = false


func _ready() -> void:
	for problem in balance.problems():
		push_error("Köstebek Vurma: " + problem)
	game = GameState.new(balance)
	game.score_changed.connect(_on_score_changed)
	game.life_lost.connect(_on_life_lost)
	game.level_up.connect(_on_level_up)
	game.game_over.connect(_on_game_over)
	spawner.balance = balance
	spawner.item_spawned.connect(_on_item_spawned)
	hud.back_button.hold_time = hold_to_exit
	hud.back_button.completed.connect(SahneGecis.ana_menuye_don)
	get_viewport().size_changed.connect(_layout_holes)
	_new_game()
	IpucuEli.ekle(self, "kostebek", _ipucu)


# Başlangıç ipucu eli: çukurdan çıkan köstebeğe dokun (o an köstebek yoksa ekranın ortasındaki çukura)
func _ipucu() -> Dictionary:
	if state != State.PLAYING or holes.is_empty():
		return {}
	for hole in holes:
		var item: Node2D = hole.item
		if item != null and item.kind == Item.Kind.MOLE and item.hittable and item.phase != Item.Phase.HIDING:
			var rect: Rect2 = hole.touch_rect(balance.touch_padding, balance.min_touch_size)
			return IpucuEli.dokun(get_viewport().get_canvas_transform() * rect.get_center(), 1)
	var orta := get_viewport_rect().get_center()
	var en_yakin: Node2D = holes[0]
	for hole in holes:
		if IpucuEli.ekran_konumu(hole).distance_to(orta) < IpucuEli.ekran_konumu(en_yakin).distance_to(orta):
			en_yakin = hole
	return IpucuEli.dokun(IpucuEli.ekran_konumu(en_yakin, Vector2(0.0, -40.0)), 1)


# --- Durumlar ---

func _new_game() -> void:
	game.reset()
	effects.clear()
	hud.set_score(0, false)
	hud.set_level(1, false)
	hud.set_lives(game.lives, balance.lives, false)
	spawner.level = balance.level_data(1)
	_pending_hole_count = 0
	if spawner.level.hole_count != hole_count:
		_build_holes(spawner.level.hole_count)
	_set_state(State.COUNTDOWN)


func _set_state(new_state: State) -> void:
	state = new_state
	_run_id += 1
	match state:
		State.COUNTDOWN:
			_run_countdown(_run_id)
		State.PLAYING:
			spawner.start()
		State.GAME_OVER:
			_run_game_over(_run_id)
	state_changed.emit(state)


func _run_countdown(my_run: int) -> void:
	await get_tree().create_timer(0.5).timeout
	for k in 3:
		if my_run != _run_id:
			return
		hud.show_count(str(3 - k), COUNT_COLORS[k])
		sounds.play("bip")
		await get_tree().create_timer(countdown_step).timeout
	if my_run != _run_id:
		return
	sounds.play("bip_son")
	_set_state(State.PLAYING)


func _run_game_over(my_run: int) -> void:
	spawner.stop()
	_pending_hole_count = 0
	for hole in holes:
		if hole.item:
			hole.item.force_hide()
	await get_tree().create_timer(0.8).timeout
	if my_run != _run_id:
		return
	var is_new_best := game.finish()
	hud.show_game_over(game.score, game.best, is_new_best)
	sounds.play("oyun_sonu")


func _replay() -> void:
	if _replaying:
		return
	_replaying = true
	hud.press("replay")
	hud.hide_game_over()
	await get_tree().create_timer(0.25).timeout
	_replaying = false
	_new_game()


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
	if back_touch == -1 and hud.back_button.contains(pos):
		back_touch = index
		hud.back_button.press()
		return
	match state:
		State.PLAYING:
			_try_hit(pos)
		State.GAME_OVER:
			if not hud.is_game_over_visible() or _replaying:
				return
			if hud.hit_replay(pos):
				_replay()
			elif hud.hit_home(pos):
				hud.press("home")
				SahneGecis.ana_menuye_don()


func _release_back() -> void:
	back_touch = -1
	hud.back_button.release()


# Uygulama arka plana giderse basılı geri düğmesi bırakılır
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and back_touch != -1:
		_release_back()


# Dokunulan yerdeki vurulabilir nesneler içinden merkezi en yakın olanı vurur.
# Bir basış en fazla bir nesneyi etkiler; vurulan nesne hemen vurulamaz olur.
func _try_hit(pos: Vector2) -> void:
	var best: Node2D = null
	var best_distance := INF
	for hole in holes:
		var item: Node2D = hole.item
		if item == null or not item.hittable:
			continue
		var rect: Rect2 = hole.touch_rect(balance.touch_padding, balance.min_touch_size)
		if not rect.has_point(pos):
			continue
		var distance := rect.get_center().distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = item
	if best:
		best.receive_hit()   # -> hit sinyali -> _on_item_hit


# --- Nesne olayları ---

func _on_item_spawned(item: Node2D) -> void:
	item.hit.connect(_on_item_hit)
	sounds.play("pop", randf_range(0.9, 1.15))


func _on_item_hit(item: Node2D, result: int) -> void:
	var xform := item.get_global_transform()
	var center: Vector2 = xform * item.visual_rect.get_center()
	var top: Vector2 = xform * Vector2(0.0, item.visual_rect.position.y)
	var size: float = item.visual_rect.size.x * xform.get_scale().x
	match result:
		Item.HitResult.HELMET:
			sounds.play("kask", randf_range(0.95, 1.08))
			effects.helmet_shards(item.helmet_transform())
			item.extend_stay(balance.helmet_extra_time)
		Item.HitResult.MOLE:
			sounds.play("bonk", randf_range(0.95, 1.08))
			effects.sparkle(top, size)
			game.add_points(balance.mole_points, top)
		Item.HitResult.FRUIT:
			sounds.play("cin", randf_range(0.95, 1.12))
			effects.sparkle(center, size, item.color, false)
			game.add_points(balance.fruit_points, top)
		Item.HitResult.BOMB:
			sounds.play("puf")
			effects.smoke(center, size * 1.3)
			effects.shake(bomb_shake, 0.35)
			game.lose_life()


# --- Oyun durumu olayları ---

func _on_score_changed(_score: int, delta: int, at: Vector2) -> void:
	hud.set_score(game.score, true)
	hud.float_text(at, "+%d" % delta, MOLE_TEXT_COLOR if delta >= balance.mole_points else FRUIT_TEXT_COLOR)


func _on_life_lost(lives_left: int) -> void:
	hud.set_lives(lives_left, balance.lives, true)
	get_tree().create_timer(0.12).timeout.connect(sounds.play.bind("can"))


func _on_level_up(level: int) -> void:
	hud.show_level_up(level)
	sounds.play("seviye")
	var data := balance.level_data(level)
	spawner.level = data
	if data.hole_count != hole_count:
		# Yeni çukur düzeni: yeni çıkış yok, çıkanlar inince çukurlar yeniden dizilir
		_pending_hole_count = data.hole_count
		spawner.holding = true


func _on_game_over() -> void:
	_set_state(State.GAME_OVER)


func _process(_delta: float) -> void:
	if _pending_hole_count > 0 and state == State.PLAYING and spawner.active_count() == 0:
		var count := _pending_hole_count
		_pending_hole_count = 0
		_rebuild_holes_during_play(count, _run_id)


func _rebuild_holes_during_play(count: int, my_run: int) -> void:
	_build_holes(count)
	await get_tree().create_timer(0.7).timeout
	if my_run == _run_id:
		spawner.holding = false


# --- Çukurlar ---

func _build_holes(count: int) -> void:
	for hole in holes:
		hole.disappear(0.0)
	holes.clear()
	hole_count = count
	for k in count:
		var hole: Node2D = Hole.new()
		holes_layer.add_child(hole)
		holes.append(hole)
	_layout_holes()
	for k in holes.size():
		holes[k].appear(0.15 + k * 0.05)
	spawner.set_holes(holes)


# Yatay: 6 çukur 3x2, 9 çukur 3x3; dikey: 2x3 / 3x3. Çukur boyu, ekran oranı ne olursa olsun hücreye
# sığacak şekilde (nesnenin çukurdan taşan yüksekliği dahil) hesaplanır; ızgara alana ortalanır.
func _layout_holes() -> void:
	if holes.is_empty():
		return
	var screen := get_viewport_rect().size
	# Çentikli telefonlarda kenar payı güvenli alan kadar büyür (iki yanda aynı: çukurlar ortada kalır)
	var side := maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, SIDE_MARGIN), EkranYardimcisi.kenar_payi(SIDE_RIGHT, SIDE_MARGIN))
	var area := Rect2(side, TOP_AREA, screen.x - side * 2.0, screen.y - TOP_AREA - BOTTOM_MARGIN)
	var landscape := screen.x > screen.y
	var cols := 3 if landscape or hole_count > 6 else 2
	var rows := ceili(hole_count / float(cols))
	var cell := Vector2(area.size.x / cols, area.size.y / rows)
	var extent := Hole.TOP_EXTENT * OVERLAP_SHARE + Hole.BOTTOM_EXTENT
	var s := minf(cell.x * 0.92 / Hole.WIDTH, cell.y * 0.98 / extent)
	for k in holes.size():
		var row := floori(k / float(cols))
		var col := k % cols
		var center := Vector2(area.position.x + (col + 0.5) * cell.x,
			area.position.y + row * cell.y + (cell.y - extent * s) / 2.0 + Hole.TOP_EXTENT * OVERLAP_SHARE * s)
		holes[k].place(center, Hole.WIDTH * s)
