extends Node2D
# Parmağı izleyen banyo aleti (BathTool): sünger, duş ya da havlu. Ekrana dokununca parmağın altında belirir,
# parmakla birlikte gezer, parmak kalkınca küçülüp kaybolur. Düğümün konumu parmağın ucu (aletin etki noktası).
# Sünger ve havlu parmağın biraz üstünde, hareket yönüne eğilir ve hızla esner; duş başlığı parmağın üstünde
# durur ve parmağın olduğu yere su akar.

const TEXTURES: Array[Texture2D] = [
	preload("res://oyunlar/hayvan_banyosu/gorseller/sunger.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/dus.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/havlu.svg"),
]
const NOZZLE := Vector2(92, 196)      # dus.svg (240x240) içinde suyun çıktığı nokta (svg_uret.py DUS_NOZZLE)
const WATER := Color(0.55, 0.82, 1.0, 0.85)
const WATER_LIGHT := Color(0.88, 0.97, 1.0, 0.95)

var kind: int = 0                     # 0 sünger, 1 duş, 2 havlu (ayarlar.gd STEPS sırası)
var width: float = 170.0              # aletin ekrandaki genişliği
var active: bool = false

var _sprite: Sprite2D
var _target: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _tween: Tween


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	visible = false
	set_kind(kind)


func set_kind(new_kind: int) -> void:
	kind = new_kind
	_sprite.texture = TEXTURES[kind]
	var s := width / TEXTURES[kind].get_width()
	_sprite.scale = Vector2.ONE * s
	if kind == 1:
		# Duş: başlık parmağın üstünde, suyun çıktığı yer parmaktan water_length yukarıda
		var size := TEXTURES[kind].get_size()
		_sprite.offset = size / 2.0 - NOZZLE
		_sprite.position = Vector2(0.0, -water_length())
	else:
		_sprite.offset = Vector2.ZERO
		_sprite.position = Vector2(0.0, -width * 0.18)
	if active:
		_pop()


func set_width(value: float) -> void:
	width = value
	set_kind(kind)


func water_length() -> float:
	return width * 0.75


func begin(point: Vector2) -> void:
	active = true
	visible = true
	position = point
	_target = point
	_velocity = Vector2.ZERO
	_pop()


func move(point: Vector2) -> void:
	_target = point


func end() -> void:
	if not active:
		return
	active = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


func _pop() -> void:
	if _tween:
		_tween.kill()
	scale = Vector2.ONE * 0.4
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var previous := position
	position = position.lerp(_target, 1.0 - exp(-28.0 * delta))
	_velocity = _velocity.lerp((position - previous) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	var speed := clampf(_velocity.length() / 1500.0, 0.0, 1.0)
	match kind:
		0:
			# Sünger: hareket yönüne eğilir, hızlıyken yatay esner
			_sprite.rotation = clampf(_velocity.x / 3000.0, -0.35, 0.35)
			_sprite.scale = Vector2(1.0 + 0.15 * speed, 1.0 - 0.12 * speed) * width / TEXTURES[0].get_width()
		1:
			_sprite.rotation = clampf(_velocity.x / 6000.0, -0.12, 0.12) + sin(_time * 18.0) * 0.015
		2:
			# Havlu: sürtme yönünde sallanır
			_sprite.rotation = clampf(_velocity.x / 2500.0, -0.4, 0.4) + sin(_time * 6.0) * 0.04
	if kind == 1:
		queue_redraw()


# Duştan akan su: başlığın genişliğince birkaç ince akış, aşağı kayan damla izleri ve dipte küçük sıçrama
func _draw() -> void:
	if kind != 1 or not active:
		return
	var top := Vector2(0.0, -water_length())
	var spread := width * 0.2
	for k in 7:
		var x := (k - 3) / 3.0
		var start := top + Vector2(x * spread, 0.0)
		var end := Vector2(x * spread * 0.45, 0.0)
		draw_line(start, end, Color(WATER, 0.35), 5.0, true)
		for j in 3:
			var t := fmod(_time * 2.6 + j / 3.0 + k * 0.13, 1.0)
			var p := start.lerp(end, t)
			draw_line(p, p + (end - start).normalized() * width * 0.07, WATER_LIGHT, 4.0, true)
	for k in 5:
		var a := PI + PI * (k + 0.5) / 5.0
		var r := width * (0.06 + 0.04 * fmod(_time * 3.0 + k * 0.3, 1.0))
		draw_circle(Vector2(cos(a), sin(a) * 0.5) * r, 3.5, WATER_LIGHT)
