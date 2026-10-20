extends Node2D
# Meyve Topla: başında sepet taşıyan kirpiyle ağaçtan düşen meyveleri topla.
# Bu script oyunun akışını yönetir (durumlar, dokunma, nesne döngüsü, güçlendirmeler, kombo).
# Ayrıntılar: oyuncu.gd, dusen_nesne.gd, bolum_yoneticisi.gd, bolumler.gd, agac.gd,
# arka_plan.gd, efektler.gd, arayuz.gd. Tasarım notları: TASARIM.md

const Item := preload("res://oyunlar/meyve_topla/dusen_nesne.gd")
const Player := preload("res://oyunlar/meyve_topla/oyuncu.gd")
const TreeView := preload("res://oyunlar/meyve_topla/agac.gd")
const Backdrop := preload("res://oyunlar/meyve_topla/arka_plan.gd")
const Effects := preload("res://oyunlar/meyve_topla/efektler.gd")
const LevelManager := preload("res://oyunlar/meyve_topla/bolum_yoneticisi.gd")
const Hud := preload("res://oyunlar/meyve_topla/arayuz.gd")
const Data := preload("res://oyunlar/meyve_topla/bolumler.gd")
const G := "res://oyunlar/meyve_topla/gorseller/"

enum State { START, BANNER, PLAYING, CELEBRATING, RETRY }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

@export_group("Kirpi")
## Kirpinin parmağı ne kadar çabuk yakaladığı (büyük = daha az gecikme).
@export var follow_sharpness: float = 9.0
## Kirpinin en yüksek yürüme hızı (piksel/sn).
@export var player_max_speed: float = 1300.0
## Kirpinin ekrandaki boyutu (yatay ekranda ağaç kısa, kirpi biraz küçük olur).
@export var player_scale: float = 0.8

@export_group("Düşen nesneler")
## Nesnenin dalda bekleme süresi (uyarı dahil, sn).
@export var hang_time: float = 1.2
## Düşmeden önce dalın sallandığı süre (sn).
@export var warning_time: float = 0.7
## Düşen nesnelerin ekrandaki boyutu (piksel).
@export var item_size: float = 76.0
## Aynı anda ekranda en fazla kaç nesne olsun.
@export var max_items: int = 5

## Yatay ekranda ağaç kısa olduğu için düşme hızı bölüm verisinin bu kadarı olur.
@export var fall_speed_scale: float = 0.8

@export_group("Güçlendirmeler")
@export var power_duration: float = 6.0
@export var big_basket_scale: float = 1.6
## Yavaşlatma güçlendirmesinde zamanın akış hızı.
@export var slow_factor: float = 0.5
## Mıknatısın meyveleri çektiği yatay mesafe.
@export var magnet_range: float = 300.0
@export var magnet_strength: float = 520.0

@export_group("Oyun")
@export var hearts_max: int = 3
## Kaç meyvede bir kombo efekti çıksın.
@export var combo_step: int = 5
## Zemin çizgisinin ekranın altından yüksekliği.
@export var ground_margin: float = 70.0
@export var celebration_time: float = 2.2
@export var banner_time: float = 1.0

const WORDS := ["Harika!", "Süper!", "Tebrikler!"]
const POWER_ICONS := {"buyuk_sepet": "guc_sepet", "miknatis": "guc_miknatis", "yavas": "guc_yavas"}

@onready var world: Node2D = $World
@onready var backdrop: Backdrop = $World/Background
@onready var tree_view: TreeView = $World/Tree
@onready var shadows: Node2D = $World/Shadows
@onready var items: Node2D = $World/Items
@onready var player: Player = $World/Player
@onready var glow_layer: Node2D = $World/GlowLayer
@onready var effects: Effects = $World/Effects
@onready var levels: LevelManager = $Levels
@onready var hud: Hud = $UI/Hud

var state: State = State.START
var hearts: int = 3
var combo: int = 0
var active_power: String = ""
var power_left: float = 0.0
var run_id: int = 0              # ekran değişince eski beklemeler devam etmesin
var ground_y: float = 650.0
var screen := Vector2(1280, 720)
var _textures := {}


func _ready() -> void:
	SesYoneticisi.muzik("meyve_topla", self)
	screen = get_viewport_rect().size
	ground_y = screen.y - ground_margin

	backdrop.build(screen, ground_y, glow_layer)
	tree_view.build(screen, ground_y)
	backdrop.tinted = [tree_view]
	backdrop.soft_tinted = [player]
	backdrop.refresh()

	player.position = Vector2(screen.x / 2.0, ground_y)
	player.target_x = screen.x / 2.0
	player.scale = Vector2.ONE * player_scale
	player.min_x = 80.0
	player.max_x = screen.x - 80.0
	player.follow_sharpness = follow_sharpness
	player.max_speed = player_max_speed
	effects.world = world

	levels.load_progress()
	levels.spawn_requested.connect(_on_spawn_requested)
	levels.progress_changed.connect(_on_progress_changed)
	levels.level_completed.connect(_on_level_completed)
	hud.back_pressed.connect(_go_to_start)
	hud.menu_pressed.connect(SahneGecis.ana_menuye_don)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.start_pressed.connect(_start_game)
	hud.reset_pressed.connect(_reset_progress)

	backdrop.set_phase(Data.get_level(levels.saved_index)["background"], 0.0)
	_go_to_start()
	IpucuEli.ekle(self, "meyve_topla", _ipucu)


# İpucu eli: kirpinin altında parmakla sağa sola kaydır
func _ipucu() -> Dictionary:
	if state != State.PLAYING:
		return {}
	return IpucuEli.kaydir_yatay(IpucuEli.ekran_konumu(player, Vector2(0.0, 30.0)), 320.0)


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


func _item_texture(kind: String) -> Texture2D:
	match LevelManager.category_of(kind):
		"meyve":
			return _texture(G + "meyveler/" + kind + ".svg")
		"guc":
			return _texture(G + "guc_kabarcik.svg")
	return _texture(G + kind + ".svg")


# --- Dokunma: parmağın x'i kirpinin hedefidir (y önemsiz, kirpi parmağın altında kalmaz) ---

func _unhandled_input(event: InputEvent) -> void:
	if state == State.START:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		player.target_x = (event as InputEventScreenTouch).position.x
	elif event is InputEventScreenDrag:
		player.target_x = (event as InputEventScreenDrag).position.x


# --- Ekranlar ve akış ---

func _go_to_start() -> void:
	run_id += 1
	get_tree().paused = false
	state = State.START
	levels.spawning = false
	_clear_items(false)
	_end_power()
	player.target_x = screen.x / 2.0
	backdrop.set_phase(Data.get_level(levels.saved_index)["background"], 1.0)
	hud.show_start(levels.saved_index + 1, levels.saved_index > 0)


func _start_game() -> void:
	player.clear_stack()
	levels.start_level(levels.saved_index)
	_begin_level()


func _reset_progress() -> void:
	levels.reset_progress()
	hud.set_level_badge(1)
	backdrop.set_phase(Data.get_level(0)["background"], 1.0)


# Bölüm başı: kalpler dolar, "Bölüm N" afişi, gerekirse arka plan değişir, sonra oyun başlar
func _begin_level() -> void:
	run_id += 1
	var my_run := run_id
	state = State.BANNER
	hearts = hearts_max
	combo = 0
	hud.show_play()
	hud.set_hearts(hearts, hearts_max, false)
	var target := levels.target_fruit()
	var bar_fruit: String = target if target != "" else (levels.level["fruits"] as Array)[0]
	hud.set_bar_fruit(_item_texture(bar_fruit), target != "")
	hud.set_progress(0, levels.goal(), false)
	backdrop.set_phase(levels.background(), 2.0)
	SesYoneticisi.ezgi("bolum_gecisi")
	hud.show_banner(tr("Bölüm %d") % (levels.level_index + 1), banner_time)
	var wait := banner_time + 0.2
	if target != "":
		await get_tree().create_timer(banner_time * 0.8, false).timeout
		if my_run != run_id:
			return
		hud.announce_target(_item_texture(target))
		wait = 1.8
	await get_tree().create_timer(wait, false).timeout
	if my_run != run_id:
		return
	state = State.PLAYING
	levels.spawning = true


func _on_progress_changed(count: int, goal: int) -> void:
	hud.set_progress(count, goal, true)


func _on_level_completed() -> void:
	run_id += 1
	var my_run := run_id
	state = State.CELEBRATING
	_clear_items(true)
	_end_power()
	levels.save_progress(levels.level_index + 1)
	player.dance(celebration_time)
	SesYoneticisi.ezgi("kutlama")
	SesYoneticisi.efekt("konfeti", -4.0)
	effects.confetti(screen)
	effects.sparkle_ring(player.basket_position())
	hud.show_cheer(tr(WORDS.pick_random()), celebration_time - 0.6)
	await get_tree().create_timer(celebration_time, false).timeout
	if my_run != run_id:
		return
	levels.start_level(levels.level_index + 1)
	_begin_level()


# Kalpler bitti: nazik bir "tekrar" animasyonuyla aynı bölüm baştan başlar
func _retry_level() -> void:
	run_id += 1
	var my_run := run_id
	state = State.RETRY
	levels.spawning = false
	_clear_items(true)
	_end_power()
	await get_tree().create_timer(0.7, false).timeout
	if my_run != run_id:
		return
	hud.show_retry()
	SesYoneticisi.efekt("yukselis", -3.0)
	hud.set_progress(0, levels.goal(), true)
	await get_tree().create_timer(2.0, false).timeout
	if my_run != run_id:
		return
	levels.start_level(levels.level_index)
	_begin_level()


func _pause() -> void:
	if state == State.START:
		return
	get_tree().paused = true
	hud.show_pause()


func _resume() -> void:
	hud.hide_pause()
	get_tree().paused = false


# --- Düşen nesneler ---

func _on_spawn_requested(kind: String, windy: bool) -> void:
	if state != State.PLAYING or items.get_child_count() >= max_items:
		return
	var branch := _pick_branch()
	if branch < 0:
		return
	var category := LevelManager.category_of(kind)
	var item: Item = Item.new()
	items.add_child(item)
	var size := item_size * (1.2 if category == "guc" else 1.0)
	item.setup(kind, category, _item_texture(kind), size, tree_view.branches[branch], tree_view.tip_offset(branch),
		hang_time, warning_time, levels.fall_speed() * fall_speed_scale, ground_y, windy, shadows, _texture(G + "golge.svg"))
	item.branch_index = branch
	item.color = Data.FRUIT_COLORS.get(kind, Color("b8b8c8"))
	if kind == "curuk_elma":
		item.add_fly(_texture(G + "sinek.svg"))
	if category == "guc":
		item.add_power_icon(_texture(G + POWER_ICONS[kind] + ".svg"), _texture(G + "parilti.svg"))
	item.warning_started.connect(_on_item_warning)


# Boş bir dal seç; ilk bölümlerde kirpiye yakın dallar tercih edilir
func _pick_branch() -> int:
	var busy := {}
	for item: Item in items.get_children():
		if item.phase == Item.Phase.HANGING:
			busy[item.branch_index] = true
	var free: Array[int] = []
	for i in tree_view.branches.size():
		if not busy.has(i):
			free.append(i)
	if free.is_empty():
		return -1
	if levels.level_index < 3:
		var near := free.filter(func(i: int) -> bool:
			return absf(tree_view.branches[i].position.x - player.position.x) < screen.x * 0.4)
		if not near.is_empty():
			return near.pick_random()
	return free.pick_random()


func _on_item_warning(item: Item) -> void:
	tree_view.shake(item.branch_index, warning_time)
	effects.leaves(tree_view.tip_position(item.branch_index) - world.position, 3)


func _process(delta: float) -> void:
	if state == State.START:
		return
	var dt := delta * (slow_factor if active_power == "yavas" else 1.0)
	if state == State.PLAYING:
		levels.update(dt, active_power == "" and not _power_on_screen())
	_update_items(dt, delta)
	if active_power != "":
		power_left -= delta
		hud.update_power(power_left / power_duration)
		if power_left <= 0.0:
			SesYoneticisi.efekt("guc_bitti")
			_end_power()


func _update_items(dt: float, real_delta: float) -> void:
	var catch_y := player.catch_line_y()
	var half_width := player.catch_half_width()
	for item: Item in items.get_children():
		if item.is_queued_for_deletion():
			continue
		var event := item.step(dt)
		if item.phase != Item.Phase.FALLING:
			continue
		# Mıknatıs: yakındaki sayılan meyveler sepete doğru kayar
		if active_power == "miknatis" and item.category == "meyve" and levels.counts(item.kind):
			if absf(player.position.x - item.base_x) < magnet_range:
				item.base_x = move_toward(item.base_x, player.position.x, magnet_strength * real_delta)
		# Sepetin ağız çizgisini bu karede geçti mi?
		var crossed := item.prev_y < catch_y and item.position.y >= catch_y
		if state == State.PLAYING and crossed and absf(item.position.x - player.position.x) <= half_width + item.radius * 0.35:
			_on_catch(item)
		elif event == "landed":
			_on_landed(item)


func _on_catch(item: Item) -> void:
	var pos := item.position
	var side := signf(item.position.x - player.position.x)
	if side == 0.0:
		side = 1.0
	match item.category:
		"meyve":
			if levels.counts(item.kind):
				player.add_fruit(item.picture, pos)
				effects.burst(Vector2(pos.x, player.catch_line_y()), item.color)
				hud.fly_icon(item.picture, pos + world.position)
				item.queue_free()
				combo += 1
				# Art arda tuttukça "pop" biraz incelir
				SesYoneticisi.efekt("pop", -3.0, 1.0 + minf(combo, 8) * 0.025)
				if combo % combo_step == 0:
					SesYoneticisi.efekt("basari_parlak", -2.0)
					effects.sparkle_ring(player.position + Vector2(0, -105))
					effects.popup_text(player.position + Vector2(0, -250), "x%d" % (floori(float(combo) / combo_step) + 1))
				levels.add_catch()
			else:
				# Hedef olmayan meyve cezasız seker
				item.bounce_off(side)
				SesYoneticisi.efekt("boing_kisa", -7.0)
				player.bump()
				effects.puff(Vector2(pos.x, player.catch_line_y()))
		"kotu":
			item.knock_away(side)
			# Komik "bonk", sersemleme, sonra yumuşak can kaybı
			SesYoneticisi.efekt("bonk")
			_sound_later(0.12, "sersem", -2.0)
			_sound_later(0.45, "yumusak_dusus", -6.0)
			combo = 0
			hearts -= 1
			hud.set_hearts(hearts, hearts_max, true)
			player.dizzy()
			effects.shake(13.0, 0.35)
			effects.puff(Vector2(pos.x, player.catch_line_y()))
			if hearts <= 0:
				_retry_level()
		"guc":
			effects.pop(pos)
			SesYoneticisi.efekt("guc_al")
			item.pop()
			_start_power(item.kind)


# Oyun duraklatılınca bekleyen ses de bekler
func _sound_later(delay: float, sound: String, volume_db: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(SesYoneticisi.efekt.bind(sound, volume_db))


func _on_landed(item: Item) -> void:
	if item.category == "meyve" and levels.counts(item.kind):
		combo = 0  # ceza yok, sadece art arda sayacı sıfırlanır
	effects.puff(Vector2(item.position.x, ground_y - 6.0))
	item.land()


func _clear_items(animated: bool) -> void:
	for item: Item in items.get_children():
		if animated:
			item.vanish()
		else:
			item.queue_free()


func _power_on_screen() -> bool:
	for item: Item in items.get_children():
		if item.category == "guc" and item.phase != Item.Phase.DONE:
			return true
	return false


# --- Güçlendirmeler ---

func _start_power(kind: String) -> void:
	_end_power()
	active_power = kind
	power_left = power_duration
	match kind:
		"buyuk_sepet":
			player.set_big(true, big_basket_scale)
		"miknatis":
			player.set_magnet(true)
			player.set_power_icon(_texture(G + "guc_miknatis.svg"))
		"yavas":
			player.set_power_icon(_texture(G + "guc_yavas.svg"))
	hud.show_power(kind)


func _end_power() -> void:
	if active_power == "":
		return
	match active_power:
		"buyuk_sepet":
			player.set_big(false)
		"miknatis":
			player.set_magnet(false)
	player.set_power_icon(null)
	hud.hide_power()
	active_power = ""
