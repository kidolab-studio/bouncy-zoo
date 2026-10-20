extends Node2D
# Zıpla Zıpla (JumpGame): kurbağa, ekranın ortasında üst üste dizilmiş ve sağa-sola kayan basamaklara
# zıplayarak tırmanır. Ekrana (ya da boşluk tuşuna) basınca hemen zıplar; konma kararı zıplama anında
# yatay çakışmayla verilir (deterministik, fizik motoru yok). Iskalarsa kendi basamağına geri konar;
# üzerinde durulan basamak bir süre sonra titreyip solar ve ufalanır, kurbağa üstündeyse düşer ve oyun
# biter. Bütün denge ayarları denge.tres.
#
# Durumlar: READY (ilk dokunuşu bekler) -> PLAYING -> FALLING (komik düşüş) -> GAME_OVER (panel).

signal state_changed(state: State)
signal reward_collected(reward: JumpRewardType)
signal step_climbed(step: int)

enum State { READY, PLAYING, FALLING, GAME_OVER }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bütün denge ayarları (hız, genişlik, kaybolma, ödüller, konma toleransı...). Değiştirmek için denge.tres'i aç.
@export var balance: JumpBalance
## Basılı tutunca ana menüye dönme süresi (saniye).
@export var hold_to_exit: float = 0.6
## Konunca kameranın yukarı kayma süresi (saniye).
@export var camera_time: float = 0.45

const SAVE_PATH := "user://zipla_zipla.cfg"
const Player := preload("res://oyunlar/zipla_zipla/kurbaga.gd")
const Spawner := preload("res://oyunlar/zipla_zipla/basamak_uretici.gd")
const Hud := preload("res://oyunlar/zipla_zipla/arayuz.gd")
const Background := preload("res://oyunlar/zipla_zipla/arka_plan.gd")
const Sounds := preload("res://oyunlar/zipla_zipla/sesler.gd")

@onready var world: Node2D = $World
@onready var platforms_layer: Node2D = $World/Platforms
@onready var player: Player = $World/Player
@onready var spawner: Spawner = $Spawner
@onready var hud: Hud = $UI/Hud
@onready var background: Background = $Background
@onready var sounds: Sounds = $Sounds

var state: State = State.READY
var steps: int = 0                # tırmanılan (en son konulan) basamak
var rewards: int = 0              # sayaçtaki ödül puanı
var best_steps: int = 0
var back_touch: int = -1          # geri düğmesini tutan parmak (-1: yok)
var _camera_y: float = 0.0        # World düğümünün y konumu
var _camera_tween: Tween
var _run_id: int = 0              # yeni oyunda eski beklemeler devam etmesin
var _replaying: bool = false


func _ready() -> void:
	for problem in balance.problems():
		push_error("Zıpla Zıpla: " + problem)
	best_steps = load_best()
	spawner.balance = balance
	spawner.layer = platforms_layer
	spawner.build()
	for platform in spawner.pool:
		platform.warning_started.connect(_on_platform_warning)
		platform.crumbled.connect(_on_platform_crumbled)
	player.landed.connect(_on_player_landed)
	player.returned.connect(_on_player_returned)
	player.missed.connect(_on_player_missed)
	hud.back_button.hold_time = hold_to_exit
	hud.back_button.completed.connect(SahneGecis.ana_menuye_don)
	_new_game()
	var ipucu := IpucuEli.ekle(self, "zipla_zipla", _ipucu)
	ipucu.engel = func() -> bool: return hud._hand.visible   # oyunun kendi başlangıç eli görünürken çekilir


# Başlangıç ipucu eli: kurbağanın yanında ekrana dokun (kurbağa zıplar)
func _ipucu() -> Dictionary:
	if state != State.READY and state != State.PLAYING:
		return {}
	return IpucuEli.dokun(_to_screen(player.position) + Vector2(120.0, -40.0))


# --- Durumlar ---

func _new_game() -> void:
	_run_id += 1
	steps = 0
	rewards = 0
	var screen := get_viewport_rect().size
	spawner.reset(screen.x / 2.0, screen.x)
	player.place(spawner.platform(0), 0.0)
	_move_camera(0, false)
	hud.set_count(0, false)
	_set_state(State.READY)
	hud.show_hint(_to_screen(player.position) + Vector2(80, -60))


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


func _game_over() -> void:
	_set_state(State.GAME_OVER)
	var is_new_best := steps > best_steps
	if is_new_best:
		best_steps = steps
	save_result(steps, rewards)
	hud.show_game_over(rewards, steps, best_steps, is_new_best)
	sounds.play("oyun_sonu")
	if is_new_best:
		get_tree().create_timer(0.9).timeout.connect(_play_if_run.bind("rekor", _run_id))


func _play_if_run(sound: String, my_run: int) -> void:
	if my_run == _run_id:
		sounds.play(sound)


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
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_on_press(-2, Vector2(-1000, -1000))
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
		State.READY:
			# İlk dokunuş: 1. basamak kurbağanın tam üstünde bekliyor, zıplama hep başarılı
			hud.hide_hint()
			_set_state(State.PLAYING)
			_jump()
			spawner.platform(1).frozen = false
		State.PLAYING:
			_jump()
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


# --- Zıplama ve konma ---

# Konma kararı tam burada, dokunma anında verilir: kurbağanın yatay aralığı üstteki basamakla en az
# land_overlap_ratio kadar çakışıyorsa konar. Havadayken yeni dokunuşlar yok sayılır.
func _jump() -> void:
	if player.is_airborne():
		return
	var target: Node2D = spawner.platform(steps + 1)
	var lands: bool = target != null and target.can_land(player.position.x, balance.player_width, balance.land_overlap_ratio)
	var target_offset := 0.0
	if lands:
		target_offset = player.position.x - target.position.x
	player.jump(target if lands else null, target_offset, balance.jump_rise_time, balance.step_gap, balance.jump_clearance)
	sounds.play("zipla", randf_range(0.95, 1.08))


func _on_player_landed(platform: Node2D) -> void:
	steps = platform.index
	step_climbed.emit(steps)
	sounds.play("kon", randf_range(0.95, 1.05))
	player.slide_to(platform.settle_offset(player.offset, balance.player_width, balance.edge_slide), balance.slide_time)
	platform.start_timer(balance.vanish_for(steps), balance.warn_for(steps))
	if platform.reward.has_reward():
		var from: Vector2 = platform.reward.sprite_global_position()
		var reward: JumpRewardType = platform.reward.collect()
		sounds.play("cin", randf_range(0.97, 1.1))
		reward_collected.emit(reward)
		hud.fly_reward(reward.texture, from, reward.sparkle_color, _on_reward_arrived.bind(reward.points, _run_id))
	spawner.advance(steps)
	_move_camera(steps, true)


# Iskalayıp kendi basamağına geri kondu: yeni basamak sayılmaz, kaybolma süresi sıfırlanmaz
func _on_player_returned(_platform: Node2D) -> void:
	sounds.play("kon", randf_range(0.85, 0.95))


func _on_reward_arrived(points: int, my_run: int) -> void:
	if my_run != _run_id:
		return
	rewards += points
	hud.set_count(rewards, true)


func _on_player_missed() -> void:
	if state == State.PLAYING:
		_set_state(State.FALLING)
		sounds.play("dus")


func _on_platform_warning(platform: Node2D) -> void:
	if platform == player.platform:
		sounds.play("titre")


func _on_platform_crumbled(platform: Node2D) -> void:
	# Geride kalıp ekrandan çıkmış basamağın ufalanması duyulmasın
	if _to_screen(platform.position).y < get_viewport_rect().size.y + 40.0:
		sounds.play("ufalan", randf_range(0.95, 1.05))
	if platform == player.platform and not player.is_airborne():
		player.drop()
		_on_player_missed()


# --- Kamera ---

# Kurbağanın basamağı ekran yüksekliğinin player_screen_ratio oranında dursun
func _camera_for(step: int) -> float:
	return get_viewport_rect().size.y * balance.player_screen_ratio + step * balance.step_gap


func _move_camera(step: int, animate: bool) -> void:
	if _camera_tween:
		_camera_tween.kill()
	var target := _camera_for(step)
	if animate:
		_camera_tween = create_tween()
		_camera_tween.tween_property(self, "_camera_y", target, camera_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_camera_y = target
		world.position = Vector2(0, _camera_y)


func _to_screen(world_pos: Vector2) -> Vector2:
	return world_pos + world.position


func _process(_delta: float) -> void:
	world.position = Vector2(0, _camera_y)
	background.set_height(_camera_y - _camera_for(0))
	# Düşen kurbağa ekranın altından çıkınca oyun biter
	if state == State.FALLING and _to_screen(player.position).y > get_viewport_rect().size.y + 260.0:
		_game_over()


# --- Kayıt: user://zipla_zipla.cfg ([rekor] basamak, odul). Ana menü rozeti rekor basamağı gösterir. ---

static func load_best() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("rekor", "basamak", 0))


static func save_result(climbed: int, collected: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("rekor", "basamak", maxi(climbed, int(config.get_value("rekor", "basamak", 0))))
	config.set_value("rekor", "odul", maxi(collected, int(config.get_value("rekor", "odul", 0))))
	GuvenliKayit.save_config(config, SAVE_PATH)
