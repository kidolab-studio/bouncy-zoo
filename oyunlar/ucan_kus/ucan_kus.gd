extends Node2D
# Uçan Kuş (yatay ekran): ekrana dokununca kuş zıplar, engellerin arasından geçer, yıldız toplar.
# Engeller desenler halinde gelir (desenler.gd), her zone_length puanda bölge değişir (bolgeler.gd, arka_plan.gd).
# Puan = geçilen engel, yıldız = toplanan yıldız. Çarpınca bir can gider ve oyun bir kademe yavaşlar.

enum State { READY, PLAYING, GAME_OVER }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

# --- Ayarlar (Inspector'dan da değiştirilebilir). Desen listesi desenler.gd, bölgeler bolgeler.gd başında. ---
@export_group("Kuş")
## Yerçekimi (piksel/sn²). Küçük değer = kuş daha yavaş düşer.
@export var gravity: float = 900.0
## Zıplama gücü. Büyük değer = daha yükseğe zıplar (430 ile bir zıplama ~103 px yükselir).
@export var flap_strength: float = 430.0
## Kuşun ulaşabileceği en yüksek düşme hızı.
@export var max_fall_speed: float = 480.0
## Çarpışma yarıçapı. Kuşun görselinden küçük tutuldu, çocuklar için affedici olsun.
@export var bird_hit_radius: float = 30.0
## Kuşun ekranın solundan uzaklığı (ekran genişliğinin oranı).
@export_range(0.15, 0.45) var bird_x_ratio: float = 0.28

@export_group("Direkler")
## Direklerin sola kayma hızı (piksel/sn; 1280 px genişlikte). Daha uzun telefonlarda hız ve mesafe ekran
## genişliğiyle orantılı büyür: her telefonda direkler aynı sürede bir gelir ve aynı süre önceden görünür.
@export var pipe_speed: float = 230.0
## Üst ve alt direk arasındaki boşluk (piksel).
@export var gap_size: float = 250.0
## İki direk arasındaki yatay mesafe (başlangıç hızında). Oyun hızlanınca mesafe de aynı oranda açılır.
@export var pipe_spacing: float = 425.0
## Boşluğun kenarı ekranın üstüne ve çimene bundan fazla yaklaşmaz.
@export var gap_margin: float = 36.0
## Kuşun rahatça tırmanabildiği dikey hız (piksel/sn). Art arda iki boşluk arasındaki en büyük yükseklik
## farkı = bu hız x iki direk arasındaki süre. Büyütürsen desenler daha dik olur.
@export var reach_speed: float = 100.0

@export_group("Desenler ve engeller")
## Bu puana kadar yalnızca kolay desenler gelir ve boşluk biraz daha geniştir.
@export var easy_until_score: int = 10
## İlk kolay puanlarda boşluğun çarpanı.
@export var easy_gap_bonus: float = 1.12
## Desenler arasındaki nefes payı: desenin ilk direğinden önceki mesafenin çarpanı.
@export var breath_spacing: float = 1.5
## Bu puandan sonra kalın direkler gelebilir (ince direkler baştan beri gelir).
@export var thick_pipes_start_score: int = 6
## Bu puandan sonra bazı direkler yavaşça yukarı aşağı hareket eder.
@export var moving_pipes_start_score: int = 15
## Hareketli direkler başladıktan sonra en geç kaç engelde bir hareketli direk gelir.
@export var moving_pipe_every: int = 12
## Hareketin yüksekliği: orta noktadan yukarı ve aşağı (piksel).
@export var moving_pipe_range: float = 45.0
## Bir yukarı-aşağı turun süresi (sn). Büyük değer = daha yavaş.
@export var moving_pipe_period: float = 3.6
## Bu puandan sonra seyrek olarak bulut engel gelir (üstünden ya da altından geçilir).
@export var cloud_start_score: int = 20
## Desenler arasında bulut gelme olasılığı.
@export_range(0.0, 1.0) var cloud_chance: float = 0.3

@export_group("Yıldızlar ve kalp")
## Bir desenin yıldızlı gelme olasılığı.
@export_range(0.0, 1.0) var star_pattern_chance: float = 0.65
## İki direk arasına yay şeklinde dizilen yıldız sayısı (ilki boşluğun içindedir).
@export var stars_per_gap: int = 3
## Yıldız yayının kamburu (piksel): kuşun doğal zıplama yoluna benzesin diye yay hafifçe yukarı kabarır.
@export var star_arc_height: float = 26.0
## Eksik can varken en az kaç engelde bir kalp gelebilir.
@export var heart_every: int = 14
## Yıldız ve kalbin toplanma yarıçapı (cömert tutuldu).
@export var pickup_radius: float = 56.0

@export_group("Bölgeler")
## Kaç puanda bir bölge değişir.
@export var zone_length: int = 10
## Bölge geçişinin süresi (sn).
@export var zone_fade_time: float = 1.6

@export_group("Hızlanma")
## Kaç puanda bir oyun bir kademe hızlanır.
@export var speed_step_points: int = 5
## Her kademede direk hızının artış oranı (0.06 = %6).
@export var speed_step_ratio: float = 0.06
## Hızın üst sınırı: başlangıç hızının en fazla bu katı.
@export var max_speed_factor: float = 1.55
## Kuşun yerçekimi ve zıplaması hıza ne kadar uyar (0 = hiç değişmez, 1 = hızla aynı oranda çabuklaşır).
## Zıplama yüksekliği hep aynı kalır, sadece zıplama daha çabuk olur.
@export_range(0.0, 1.0) var bird_speed_match: float = 0.5
## Boşluk bu kademeden sonra daralmaya başlar.
@export var gap_shrink_start_level: int = 2
## Daralma başlayınca her kademede boşluğun küçülme oranı (0.025 = %2,5).
@export var gap_shrink_per_level: float = 0.025
## Boşluk en fazla başlangıcın bu oranına kadar daralır.
@export_range(0.5, 1.0) var min_gap_ratio: float = 0.84
## Müziğin kademe başına hızlanma oranı (0 = müzik değişmez).
@export var music_speed_per_level: float = 0.008

@export_group("Canlar")
@export var start_lives: int = 3
## Çarptıktan sonra kuşun yanıp söndüğü (dokunulmaz olduğu) süre.
@export var blink_duration: float = 1.5

const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const Desenler := preload("res://oyunlar/ucan_kus/desenler.gd")
const Bolgeler := preload("res://oyunlar/ucan_kus/bolgeler.gd")
const ArkaPlan := preload("res://oyunlar/ucan_kus/arka_plan.gd")
const HEART_TEXTURE: Texture2D = preload("res://oyunlar/ucan_kus/kalp.svg")
const STAR_TEXTURE: Texture2D = preload("res://oyunlar/ucan_kus/gorseller/yildiz.svg")
const CLOUD_TEXTURE: Texture2D = preload("res://oyunlar/ucan_kus/gorseller/bulut_engel.svg")

# Direk genişlikleri (gorseller/svg_uret.py GENISLIKLER ile aynı): çarpışma alanı görselle aynı genişlikte
const PIPE_WIDTHS := {"ince": 84.0, "orta": 120.0, "kalin": 164.0}
const CLOUD_RADII := Vector2(96.0, 46.0)   # bulut engelin çarpışma elipsi (görselden biraz küçük)
const CLOUD_WIDTH := 250.0                 # bulut engelin ekrandaki genişliği
const STAR_SIZE := 60.0                    # toplanan yıldızın ekrandaki boyu
const HEART_SIZE := 72.0
const GROUND_HEIGHT := 70.0
const BASE_WIDTH := 1280.0                 # pipe_speed ve pipe_spacing bu ekran genişliğine göre verilir
const MAX_WIDTH_SCALE := 1.35              # çok geniş ekranlarda yatay ölçek bundan fazla büyümez
const SPAWN_MARGIN := 110.0                # engeller ekranın sağ kenarının bu kadar dışında doğar
const WIND_LINE_COUNT := 8
const SPARKLE_COUNT := 8

@onready var bird: AnimatedSprite2D = $Bird
@onready var pipes: Node2D = $Pipes
@onready var ground: ColorRect = $Ground
@onready var ground_edge: ColorRect = $Ground/GrassEdge
@onready var background: CanvasLayer = $Background
@onready var score_label: Label = $HUD/ScoreLabel
@onready var hearts_box: HBoxContainer = $HUD/HeartsBox
@onready var start_screen: Control = $HUD/StartScreen
@onready var tap_label: Label = $HUD/StartScreen/TapLabel
@onready var game_over_screen: Control = $HUD/GameOverScreen
@onready var result_box: VBoxContainer = $HUD/GameOverScreen/Box
@onready var result_label: Label = $HUD/GameOverScreen/Box/ResultLabel
@onready var restart_button: Button = $HUD/GameOverScreen/Box/RestartButton
@onready var back_panel: Panel = $HUD/BackButton
var back_button: Control

var state: State = State.READY
var bird_velocity: float = 0.0
var score: int = 0                   # geçilen engel sayısı
var stars: int = 0                   # toplanan yıldız sayısı
var lives: int = 0
var blink_left: float = 0.0
var can_restart: bool = false
var time_passed: float = 0.0
var speed_level: int = 0             # hız kademesi: her speed_step_points puanda +1, can kaybında -1
var speed_factor: float = 1.0        # direk hızının çarpanı; kademenin hedefine yumuşakça yaklaşır
var zone: int = 0                    # içinde bulunulan bölge (score / zone_length)

# Engel üretimi
var queue: Array = []                # sıradaki engeller (desenler.gd uret() çıktısı)
var spawned: int = 0                 # doğan engel sayısı (bir engelin sırası = geçilince olacak puan - 1)
var distance_since_spawn: float = 0.0
var next_spawn_distance: float = 0.0
var last_gap_y: float = 0.0
var last_pattern: String = ""
var last_was_cloud: bool = false
var last_heart_index: int = 0
var last_moving_index: int = 0
var rng := RandomNumberGenerator.new()

var pickups: Node2D
var effects: Node2D
var backdrop: Node2D
var star_label: Label
var star_icon: TextureRect
var result_star_label: Label
var hop_tween: Tween
var ground_tween: Tween
var score_base_y: float = 0.0
var star_streak: int = 0
var star_streak_left: float = 0.0
var _pipe_textures := {}


func _ready() -> void:
	SesYoneticisi.muzik("ucan_kus", self)
	rng.randomize()
	back_button = HoldButton.replace(back_panel)
	back_button.completed.connect(_on_back_completed)
	lives = start_lives
	backdrop = ArkaPlan.new()
	background.add_child(backdrop)
	backdrop.kur(_screen_size(), _floor_y(), 0)
	pickups = Node2D.new()
	add_child(pickups)
	move_child(pickups, pipes.get_index() + 1)
	effects = Node2D.new()
	add_child(effects)
	_create_hearts()
	_create_star_counter()
	_apply_ground_colors(Bolgeler.bolge(0), 0.0)
	score_base_y = score_label.position.y
	get_viewport().size_changed.connect(_layout)
	_layout()

	bird.position = _bird_start_position()
	bird.play("flap")
	last_gap_y = bird.position.y

	score_label.visible = false
	game_over_screen.visible = false
	start_screen.visible = true

	# "Başlamak için dokun" yazısı yavaşça yanıp sönsün
	var tween := tap_label.create_tween().set_loops()
	tween.tween_property(tap_label, "modulate:a", 0.35, 0.6)
	tween.tween_property(tap_label, "modulate:a", 1.0, 0.6)
	IpucuEli.ekle(self, "ucan_kus", _ipucu)


# İpucu eli: kuşun önüne dokun (kuş zıplar). Oyun sonu ekranında gösterilmez.
func _ipucu() -> Dictionary:
	if state == State.GAME_OVER:
		return {}
	return IpucuEli.dokun(IpucuEli.ekran_konumu(bird, Vector2(220.0, 0.0)))


func _input(event: InputEvent) -> void:
	# Sadece dokunma ile oynanır (bilgisayarda fare tıklaması dokunmaya çevrilir)
	var touch := event as InputEventScreenTouch
	if touch == null:
		return

	# Geri (basılı tutulur): başlangıç ekranındayken ana menüye, oyun sırasında başlangıç ekranına
	if back_button.handle_touch(touch) or not touch.pressed:
		return

	match state:
		State.READY:
			_start_game()
		State.PLAYING:
			_flap()
		State.GAME_OVER:
			# Düğmenin biraz dışına basılsa da kabul et
			if can_restart and restart_button.get_global_rect().grow(30.0).has_point(touch.position):
				_restart()


func _on_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	if state == State.READY:
		SahneGecis.ana_menuye_don()
	else:
		SahneGecis.sahneyi_yeniden_baslat()


func _process(delta: float) -> void:
	time_passed += delta

	match state:
		State.READY:
			# Başlamadan önce kuş havada hafifçe süzülür, manzara yavaşça akar
			bird.position.y = _bird_start_position().y + sin(time_passed * 3.0) * 15.0
			backdrop.kaydir(pipe_speed * 0.35 * delta, delta)
		State.PLAYING:
			speed_factor = move_toward(speed_factor, _target_speed_factor(), 0.3 * delta)
			_update_bird(delta)
			_update_obstacles(delta)
			_update_pickups(delta)
			_update_blink(delta)
			_check_collisions()
			backdrop.kaydir(_scroll_speed() * delta, delta)
		State.GAME_OVER:
			backdrop.kaydir(0.0, delta)


# --- Oyun akışı ---

func _start_game() -> void:
	state = State.PLAYING
	start_screen.visible = false
	score_label.visible = true
	star_label.get_parent().visible = true
	SesYoneticisi.efekt("yukselis")
	_fill_queue()
	distance_since_spawn = 0.0
	next_spawn_distance = 0.0      # ilk engel hemen doğar
	_flap()


func _flap() -> void:
	bird_velocity = -flap_strength * _bird_pace()
	bird.frame = 0
	SesYoneticisi.efekt("kanat", -3.0)


func _take_hit() -> void:
	if blink_left > 0.0 or state != State.PLAYING:
		return
	lives -= 1
	_update_hearts()
	_change_speed_level(-1)  # çarpınca oyun bir kademe yavaşlar
	# Yumuşak "boing", ardından kısa, üzgün olmayan bir iniş sesi (can gitti)
	SesYoneticisi.efekt("boing", -2.0)
	get_tree().create_timer(0.25).timeout.connect(SesYoneticisi.efekt.bind("yumusak_dusus", -5.0))
	if lives <= 0:
		_game_over()
	else:
		blink_left = blink_duration


func _add_point() -> void:
	score += 1
	score_label.text = str(score)
	SesYoneticisi.efekt("ding", -3.0)
	# Puan yazısı kısa bir an büyüsün
	score_label.pivot_offset = score_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.12)
	if speed_step_points > 0 and score % speed_step_points == 0:
		_change_speed_level(1)
	if _zone_of(score) != zone:
		_enter_zone(_zone_of(score))


func _game_over() -> void:
	state = State.GAME_OVER
	blink_left = 0.0
	bird.modulate.a = 1.0
	bird.pause()
	score_label.visible = false
	star_label.get_parent().visible = false
	result_label.text = tr("Puan: %d") % score
	result_star_label.text = str(stars)
	SesYoneticisi.muzik_hizi(1.0)

	await get_tree().create_timer(0.6).timeout
	SesYoneticisi.ezgi("yildiz_kazanma")
	game_over_screen.modulate.a = 0.0
	game_over_screen.visible = true
	restart_button.pivot_offset = restart_button.size / 2.0
	create_tween().tween_property(game_over_screen, "modulate:a", 1.0, 0.3)

	# Çocuk yanlışlıkla hemen yeniden başlatmasın diye kısa bekleme
	await get_tree().create_timer(0.5).timeout
	can_restart = true


func _restart() -> void:
	can_restart = false
	SesYoneticisi.efekt("basari")
	var tween := create_tween()
	tween.tween_property(restart_button, "scale", Vector2(0.9, 0.9), 0.08)
	tween.tween_property(restart_button, "scale", Vector2.ONE, 0.08)
	tween.tween_callback(get_tree().reload_current_scene)


# --- Hızlanma ---

# Üst sınıra ulaşılan kademe (%6 artış ve 1.55 kat sınırla 8)
func _max_speed_level() -> int:
	if speed_step_ratio <= 0.0 or max_speed_factor <= 1.0:
		return 0
	return ceili(log(max_speed_factor) / log(1.0 + speed_step_ratio) - 0.0001)


func _target_speed_factor() -> float:
	return minf(pow(1.0 + speed_step_ratio, speed_level), maxf(max_speed_factor, 1.0))


# Yatay ölçek: uzun telefonlarda (ör. 20:9) hız ve mesafe genişlikle orantılı büyür
func _width_scale() -> float:
	return clampf(_screen_size().x / BASE_WIDTH, 1.0, MAX_WIDTH_SCALE)


# Engellerin, yıldızların ve manzaranın o anki kayma hızı (piksel/sn)
func _scroll_speed() -> float:
	return pipe_speed * speed_factor * _width_scale()


# Bir kademe sonraki hız çarpanı (üretilen desen ekrana gelene kadar oyun bir kademe hızlanmış olabilir)
func _next_speed_factor() -> float:
	return minf(_target_speed_factor() * (1.0 + speed_step_ratio), maxf(max_speed_factor, 1.0))


# Kuşun zaman ölçeği: hız çarpanını bird_speed_match kadar izler
func _bird_pace() -> float:
	return lerpf(1.0, speed_factor, bird_speed_match)


# Yeni direklerin boşluğu: belli kademeden sonra azar azar daralır, alt sınırın altına inmez
func _current_gap() -> float:
	var shrink := gap_shrink_per_level * maxi(speed_level - gap_shrink_start_level, 0)
	return gap_size * maxf(1.0 - shrink, min_gap_ratio)


func _change_speed_level(change: int) -> void:
	var new_level := clampi(speed_level + change, 0, _max_speed_level())
	if new_level == speed_level:
		return
	speed_level = new_level
	SesYoneticisi.muzik_hizi(1.0 + music_speed_per_level * speed_level)
	if change > 0:
		SesYoneticisi.efekt("vuus", -2.0)
		_spawn_wind_lines()
		_spawn_bird_sparkles()
		_hop_score()


# Ekranın üst ve alt kenarından sağdan sola geçen kısa rüzgar çizgileri
func _spawn_wind_lines() -> void:
	var screen := _screen_size()
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
	for i in WIND_LINE_COUNT:
		var length := randf_range(150.0, 280.0)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
		line.width = randf_range(5.0, 9.0)
		line.gradient = fade
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var band := randf_range(0.0, screen.y * 0.18)
		var y := 130.0 + band if i % 2 == 0 else _floor_y() - 40.0 - band
		line.position = Vector2(screen.x + 20.0, y)
		effects.add_child(line)
		var tween := line.create_tween()
		tween.tween_interval(i * 0.04 + randf() * 0.1)
		tween.tween_property(line, "position:x", -length - 20.0, randf_range(0.5, 0.75))
		tween.tween_callback(line.queue_free)


# Kuşun etrafında kısa süre parlayıp dağılan küçük yıldızlar
func _spawn_bird_sparkles(color := Color(1.0, 0.96, 0.62)) -> void:
	var shape := PackedVector2Array()
	for k in 8:
		shape.append(Vector2.from_angle(k * TAU / 8.0) * (13.0 if k % 2 == 0 else 4.5))
	for i in SPARKLE_COUNT:
		var sparkle := Polygon2D.new()
		sparkle.polygon = shape
		sparkle.color = color
		var direction := Vector2.from_angle(i * TAU / SPARKLE_COUNT + randf_range(-0.25, 0.25))
		sparkle.position = direction * 45.0
		sparkle.scale = Vector2.ZERO
		bird.add_child(sparkle)
		var tween := sparkle.create_tween().set_parallel()
		tween.tween_property(sparkle, "position", direction * randf_range(85.0, 110.0), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "scale", Vector2.ONE * randf_range(0.9, 1.4), 0.18)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.3).set_delay(0.25)
		tween.chain().tween_callback(sparkle.queue_free)


func _hop_score() -> void:
	if hop_tween and hop_tween.is_valid():
		hop_tween.kill()
	hop_tween = create_tween()
	hop_tween.tween_property(score_label, "position:y", score_base_y - 24.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(score_label, "position:y", score_base_y, 0.32) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# --- Bölgeler ---

# Verilen sıradaki engelin (ya da puanın) bölgesi
func _zone_of(count: int) -> int:
	@warning_ignore("integer_division")
	return count / zone_length if zone_length > 0 else 0


# Yeni bölge: manzara ve zemin yumuşakça değişir, kısa bir kutlama olur
func _enter_zone(new_zone: int) -> void:
	zone = new_zone
	var veri := Bolgeler.bolge(zone)
	backdrop.bolge_ayarla(zone, zone_fade_time)
	_apply_ground_colors(veri, zone_fade_time)
	SesYoneticisi.ezgi("bolum_gecisi", -2.0)
	_spawn_bird_sparkles(Color(1.0, 1.0, 1.0))
	_spawn_zone_stars()
	_hop_score()


func _apply_ground_colors(veri: Dictionary, duration: float) -> void:
	if ground_tween and ground_tween.is_valid():
		ground_tween.kill()
	if duration <= 0.0:
		ground.color = veri["zemin"]
		ground_edge.color = veri["zemin_kenar"]
		return
	ground_tween = create_tween().set_parallel()
	ground_tween.tween_property(ground, "color", veri["zemin"], duration)
	ground_tween.tween_property(ground_edge, "color", veri["zemin_kenar"], duration)


# Bölge kutlaması: ekranın altından yukarı doğru saçılıp sönen renkli yıldızlar
func _spawn_zone_stars() -> void:
	var screen := _screen_size()
	var colors := [Color("ffe27a"), Color("ff9cc6"), Color("a9e8cd"), Color("c9b6ff"), Color("ffffff")]
	for i in 26:
		var star := Sprite2D.new()
		star.texture = STAR_TEXTURE
		star.modulate = colors[i % colors.size()]
		star.scale = Vector2.ZERO
		star.position = Vector2(randf_range(0.0, screen.x), _floor_y() + 20.0)
		effects.add_child(star)
		var target := star.position + Vector2(randf_range(-80.0, 80.0), -randf_range(screen.y * 0.3, screen.y * 0.85))
		var boy := randf_range(28.0, 54.0) / STAR_TEXTURE.get_width()
		var tween := star.create_tween().set_parallel()
		tween.tween_property(star, "position", target, 1.1).set_delay(i * 0.015) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2(boy, boy), 0.3).set_delay(i * 0.015)
		tween.tween_property(star, "rotation", randf_range(-1.5, 1.5), 1.1)
		tween.tween_property(star, "modulate:a", 0.0, 0.4).set_delay(0.75 + i * 0.015)
		tween.chain().tween_callback(star.queue_free)


# --- Kuş ---

func _update_bird(delta: float) -> void:
	# Oyun hızlandıkça kuş aynı yüksekliğe daha çabuk zıplayıp iner (yerçekimi pace², zıplama pace ile artar)
	var pace := _bird_pace()
	var fall_limit := max_fall_speed * pace
	bird_velocity = minf(bird_velocity + gravity * pace * pace * delta, fall_limit)
	bird.position.y += bird_velocity * delta

	# Yükselirken yukarı, düşerken aşağı doğru hafifçe eğil
	var target_rotation := clampf(bird_velocity / fall_limit * 0.5, -0.35, 0.5)
	bird.rotation = lerpf(bird.rotation, target_rotation, 8.0 * delta)

	# Tavana çarpınca can gitmez, sadece durur
	if bird.position.y - bird_hit_radius < 0.0:
		bird.position.y = bird_hit_radius
		bird_velocity = maxf(bird_velocity, 0.0)


func _update_blink(delta: float) -> void:
	if blink_left <= 0.0:
		return
	blink_left -= delta
	if blink_left <= 0.0:
		bird.modulate.a = 1.0
	else:
		bird.modulate.a = 0.3 if fmod(blink_left, 0.2) < 0.1 else 1.0


# --- Engeller ---

# Desen üreticisine o anki ekran ve zorluk bilgisini verir
func _pattern_context() -> Dictionary:
	return {
		"ust": gap_margin, "alt": _floor_y() - gap_margin,
		"bosluk": _current_gap(),
		"en_fazla_kayma": reach_speed * pipe_spacing / pipe_speed,
		"nefes": breath_spacing,
		# Bir sonraki engel hep ekranda görünsün: iki engel arası mesafe, kuşla sağ kenar arasını geçmez
		"en_fazla_ara": maxf(1.0, (_screen_size().x - bird.position.x) * 0.92
			/ (pipe_spacing * _next_speed_factor() * _width_scale())),
		"kolay_puan": easy_until_score, "kolay_bosluk": easy_gap_bonus, "en_az_bosluk": gap_size * 0.8,
		"kalin_puan": thick_pipes_start_score,
		"hareketli_puan": moving_pipes_start_score, "hareket_payi": moving_pipe_range,
		"hareketli_sart": spawned + queue.size() - maxi(last_moving_index, moving_pipes_start_score - moving_pipe_every + 3) >= moving_pipe_every,
		"bulut_puan": cloud_start_score, "bulut_sansi": cloud_chance,
		"yildiz_sansi": star_pattern_chance,
		"kalp_izni": lives < start_lives and spawned + queue.size() - last_heart_index >= heart_every,
		"son_desen": last_pattern, "son_bulut": last_was_cloud,
	}


# Sırada hep en az iki engel dursun (yıldız yayı bir sonraki boşluğun yerini bilmek ister)
func _fill_queue() -> void:
	while queue.size() < 2:
		var start_y: float = queue[-1]["y"] if not queue.is_empty() else last_gap_y
		var items: Array = Desenler.uret(spawned + queue.size(), start_y, _pattern_context(), rng)
		last_pattern = items[-1]["desen"]
		last_was_cloud = items[0]["tip"] == "bulut"
		if items[-1]["kalp"]:
			last_heart_index = spawned + queue.size() + items.size()
		if items.any(func(e: Dictionary) -> bool: return float(e["hareket"]) > 0.0):
			last_moving_index = spawned + queue.size() + items.size()
		queue.append_array(items)


func _update_obstacles(delta: float) -> void:
	# Engeller hep aynı sürede bir doğar (başlangıç hızıyla ölçülen mesafe), ama hız çarpanıyla kayar:
	# aralarındaki mesafe hızla orantılı açılır, yani sıklaşmazlar, sadece daha hızlı gelirler
	distance_since_spawn += pipe_speed * delta
	if distance_since_spawn >= next_spawn_distance:
		distance_since_spawn -= next_spawn_distance
		_spawn_next()
	var speed := _scroll_speed()

	for obstacle: Node2D in pipes.get_children():
		obstacle.position.x -= speed * delta
		if obstacle.has_meta("travel"):
			# Hareketli direk: orta noktasının çevresinde yavaşça yukarı aşağı
			var age: float = obstacle.get_meta("age") + delta
			obstacle.set_meta("age", age)
			obstacle.position.y = obstacle.get_meta("base_y") + sin(age * TAU / moving_pipe_period) * obstacle.get_meta("travel")
		elif obstacle.get_meta("tip") == "bulut":
			# Bulut engel yerinde hafifçe salınır (çarpışma merkezi sabit kalır)
			obstacle.get_child(0).position.y = sin(time_passed * 2.0 + obstacle.get_meta("phase")) * 6.0
		var half_width: float = obstacle.get_meta("half_width")
		if not obstacle.get_meta("scored") and obstacle.position.x + half_width < bird.position.x:
			obstacle.set_meta("scored", true)
			_add_point()
		if obstacle.position.x < -half_width - 60.0:
			obstacle.queue_free()


func _spawn_next() -> void:
	var item: Dictionary = queue.pop_front()
	_fill_queue()
	var next: Dictionary = queue[0]
	next_spawn_distance = pipe_spacing * float(next["ara"])
	var x := _screen_size().x + SPAWN_MARGIN
	if item["tip"] == "bulut":
		_spawn_cloud(item, x)
	else:
		_spawn_pipe_pair(item, x)
		_spawn_pickups(item, next, x)
	spawned += 1
	last_gap_y = item["y"]


func _pipe_texture(zone_name: String, thickness: String) -> Texture2D:
	var path := Bolgeler.direk_yolu(zone_name, thickness)
	if not _pipe_textures.has(path):
		_pipe_textures[path] = load(path)
	return _pipe_textures[path]


func _spawn_pipe_pair(item: Dictionary, x: float) -> void:
	# Sütunun stili, engelin geçileceği bölgeye göre seçilir (yeni bölgenin sütunları biraz önceden görünür)
	var veri := Bolgeler.bolge(_zone_of(spawned))
	var texture := _pipe_texture(veri["ad"], item["kalinlik"])
	var gap: float = item["bosluk"]

	# Çiftin merkezi boşluğun ortası
	var pair := Node2D.new()
	pair.position = Vector2(x, item["y"])
	pair.set_meta("tip", "direk")
	pair.set_meta("scored", false)
	pair.set_meta("gap", gap)
	pair.set_meta("half_width", float(PIPE_WIDTHS[item["kalinlik"]]) / 2.0)
	pair.set_meta("desen", item["desen"])
	var colors: Array = veri["direk_renkleri"]
	if not colors.is_empty():
		pair.modulate = colors[rng.randi_range(0, colors.size() - 1)]
	if float(item["hareket"]) > 0.0:
		pair.set_meta("travel", float(item["hareket"]))
		pair.set_meta("base_y", float(item["y"]))
		pair.set_meta("age", 0.0)

	var half_height := texture.get_height() / 2.0
	var top := Sprite2D.new()
	top.texture = texture
	top.flip_v = true
	top.position.y = -gap / 2.0 - half_height
	var bottom := Sprite2D.new()
	bottom.texture = texture
	bottom.position.y = gap / 2.0 + half_height

	pair.add_child(top)
	pair.add_child(bottom)
	pipes.add_child(pair)


func _spawn_cloud(item: Dictionary, x: float) -> void:
	var cloud := Node2D.new()
	cloud.position = Vector2(x, item["y"])
	cloud.set_meta("tip", "bulut")
	cloud.set_meta("scored", false)
	cloud.set_meta("half_width", CLOUD_RADII.x)
	cloud.set_meta("desen", "bulut")
	cloud.set_meta("phase", rng.randf() * TAU)
	var sprite := Sprite2D.new()
	sprite.texture = CLOUD_TEXTURE
	sprite.scale = Vector2.ONE * CLOUD_WIDTH / CLOUD_TEXTURE.get_width()
	cloud.add_child(sprite)
	pipes.add_child(cloud)


# --- Yıldızlar ve kalp ---

# Yıldızlar: boşluğun içinden bir sonraki boşluğa doğru, kuşun doğal uçuş yoluna benzeyen bir yay boyunca dizilir
func _spawn_pickups(item: Dictionary, next: Dictionary, x: float) -> void:
	if item["kalp"]:
		_add_pickup("kalp", Vector2(x, item["y"]))
	if not item["yildiz"]:
		return
	var same_pattern: bool = next["tip"] == "direk" and next["desen"] == item["desen"] and float(next["ara"]) < breath_spacing
	var count := maxi(stars_per_gap, 1) if same_pattern else 1
	# İki direk ekranda bu kadar aralıkla durur (hız çarpanıyla açılır)
	var distance := pipe_spacing * float(next["ara"]) * _target_speed_factor() * _width_scale()
	for k in count:
		if k == 0 and item["kalp"]:
			continue
		var t := float(k) / count
		var y := lerpf(float(item["y"]), float(next["y"]), smoothstep(0.0, 1.0, t)) - sin(t * PI) * star_arc_height
		_add_pickup("yildiz", Vector2(x + distance * t, y))


func _add_pickup(kind: String, pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = HEART_TEXTURE if kind == "kalp" else STAR_TEXTURE
	sprite.position = pos
	sprite.set_meta("tur", kind)
	sprite.set_meta("phase", rng.randf() * TAU)
	var boy := STAR_SIZE / STAR_TEXTURE.get_width() if kind == "yildiz" else HEART_SIZE / HEART_TEXTURE.get_width()
	sprite.scale = Vector2(boy, boy)
	sprite.set_meta("boy", boy)
	pickups.add_child(sprite)


func _update_pickups(delta: float) -> void:
	star_streak_left -= delta
	if star_streak_left <= 0.0:
		star_streak = 0
	var speed := _scroll_speed()
	for pickup: Sprite2D in pickups.get_children():
		if pickup.has_meta("alindi"):
			continue
		pickup.position.x -= speed * delta
		var wobble := sin(time_passed * 4.0 + pickup.get_meta("phase"))
		pickup.rotation = wobble * 0.18
		pickup.scale = Vector2.ONE * float(pickup.get_meta("boy")) * (1.0 + wobble * 0.05)
		if pickup.position.distance_to(bird.position) < pickup_radius:
			_collect(pickup)
		elif pickup.position.x < -80.0:
			pickup.queue_free()    # kaçan yıldız ceza değil, sessizce gider


func _collect(pickup: Sprite2D) -> void:
	pickup.set_meta("alindi", true)
	if pickup.get_meta("tur") == "kalp":
		if lives < start_lives:
			lives += 1
			_update_hearts()
			var heart := hearts_box.get_child(lives - 1) as Control
			heart.pivot_offset = heart.size / 2.0
			var bump := heart.create_tween()
			bump.tween_property(heart, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			bump.tween_property(heart, "scale", Vector2.ONE, 0.25)
		SesYoneticisi.efekt("basari_parlak")
		_spawn_bird_sparkles(Color(1.0, 0.6, 0.75))
	else:
		stars += 1
		star_label.text = str(stars)
		# Art arda toplanan yıldızların sesi biraz incelir
		star_streak = mini(star_streak + 1, 7)
		star_streak_left = 1.2
		SesYoneticisi.efekt("tink", 2.0, 1.0 + (star_streak - 1) * 0.06)
		star_icon.pivot_offset = star_icon.size / 2.0
		var bump := star_icon.create_tween()
		bump.tween_property(star_icon, "scale", Vector2(1.35, 1.35), 0.08)
		bump.tween_property(star_icon, "scale", Vector2.ONE, 0.14)
	# Toplanan şey büyüyüp söner
	var tween := pickup.create_tween().set_parallel()
	tween.tween_property(pickup, "scale", pickup.scale * 1.8, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pickup, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(pickup.queue_free)


# --- Çarpışma ---

func _check_collisions() -> void:
	# Yere değince kuş geri sıçrar (ve bir can gider)
	var floor_y := _floor_y()
	if bird.position.y + bird_hit_radius > floor_y:
		bird.position.y = floor_y - bird_hit_radius
		bird_velocity = -flap_strength * _bird_pace()
		_take_hit()

	if blink_left > 0.0 or state != State.PLAYING:
		return
	for obstacle: Node2D in pipes.get_children():
		if _bird_hits(obstacle):
			_take_hit()
			return


func _bird_hits(obstacle: Node2D) -> bool:
	if obstacle.get_meta("tip") == "bulut":
		# Elips: kuşun yarıçapı kadar büyütülmüş bulutun içinde mi
		var d := bird.position - obstacle.position
		var r := CLOUD_RADII + Vector2(bird_hit_radius, bird_hit_radius)
		return (d.x * d.x) / (r.x * r.x) + (d.y * d.y) / (r.y * r.y) < 1.0
	var half_gap: float = obstacle.get_meta("gap") / 2.0
	var half_width: float = obstacle.get_meta("half_width")
	var left := obstacle.position.x - half_width
	var top_rect := Rect2(left, obstacle.position.y - half_gap - 2000.0, half_width * 2.0, 2000.0)
	var bottom_rect := Rect2(left, obstacle.position.y + half_gap, half_width * 2.0, 2000.0)
	return _circle_hits_rect(bird.position, bird_hit_radius, top_rect) \
		or _circle_hits_rect(bird.position, bird_hit_radius, bottom_rect)


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := center.clamp(rect.position, rect.end)
	return center.distance_to(closest) < radius


# --- Arayüz ---

func _create_hearts() -> void:
	for i in start_lives:
		var heart := TextureRect.new()
		heart.texture = HEART_TEXTURE
		heart.custom_minimum_size = Vector2(60, 60)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hearts_box.add_child(heart)


func _update_hearts() -> void:
	# Kaybedilen kalpler soluk görünür
	for i in hearts_box.get_child_count():
		var heart := hearts_box.get_child(i) as TextureRect
		heart.modulate = Color.WHITE if i < lives else Color(1, 1, 1, 0.2)


func _star_row(icon_size: float, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = STAR_TEXTURE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = "0"
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.25, 0.6))
	label.add_theme_constant_override("outline_size", maxi(10, roundi(font_size / 5.0)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


# Yıldız sayacı: kalplerin altında (oyun sırasında) ve oyun sonu kutusunda (yazısız, simge + sayı)
func _create_star_counter() -> void:
	var row := _star_row(48.0, 46)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.visible = false
	hearts_box.get_parent().add_child(row)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -300.0
	row.offset_right = -44.0
	row.offset_top = hearts_box.offset_bottom + 6.0
	row.offset_bottom = row.offset_top + 56.0
	star_icon = row.get_child(0)
	star_label = row.get_child(1)
	# Çentikli telefonlarda kalpler ve yıldız sayacı çentiğin altında kalmasın
	EkranYardimcisi.guvenliye_it_grup([hearts_box, row])
	var result_row := _star_row(84.0, 80)
	result_box.add_child(result_row)
	result_box.move_child(result_row, result_label.get_index() + 1)
	result_star_label = result_row.get_child(1)


func _layout() -> void:
	# Farklı telefon oranlarında çimen hep en altta, manzara zemin çizgisinde dursun
	var screen := _screen_size()
	ground.position = Vector2(0.0, _floor_y())
	ground.size = Vector2(screen.x, GROUND_HEIGHT)
	bird.position.x = _bird_start_position().x
	if backdrop:
		backdrop.yerlestir(screen, _floor_y())


func _screen_size() -> Vector2:
	return get_viewport_rect().size


func _floor_y() -> float:
	return _screen_size().y - GROUND_HEIGHT


func _bird_start_position() -> Vector2:
	var screen := _screen_size()
	return Vector2(screen.x * bird_x_ratio, _floor_y() * 0.5)
