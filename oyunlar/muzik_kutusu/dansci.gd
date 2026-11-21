extends Node2D
# DancingCharacter: sahnede müziğe göre dans eden karakter. Düğümün konumu ayaklarının bastığı noktadır.
# Her notada kick() çağrılır: enerji artar ve karakter zıplar. Enerji yavaşça söner; sıfıra yaklaştıkça dans
# yumuşakça bekleme hâline (nefes alma, hafif baş eğme) karışır. Her karakterin kendi dans hareketi var.
# Kurbağa Zıpla Zıpla'daki parçalardan kurulur; dans ederken ağzı açık (neşeli) yüzü görünür.

enum Move { SWAY, STEP, SPIN, BOUNCE }

const G := "res://oyunlar/muzik_kutusu/gorseller/"
const FEET := 240.0                       # 256'lık tuvalde ayakların alt kenarı

## Enerjinin tamamen sönme süresi (saniye): bu kadar ses çalınmazsa bekleme animasyonuna geçer
@export var calm_time: float = 3.5

var move: Move = Move.SWAY
var energy: float = 0.0
var _body: Node2D                         # ezilip esneme ve sallanma (ayaklardan)
var _face: Sprite2D = null                # sadece kurbağada
var _face_normal: Texture2D
var _face_happy: Texture2D
var _hop: float = 0.0
var _hop_tween: Tween
var _spin: float = 0.0                    # dönüş (2B'de gövde yatayda çevrilir)
var _spin_tween: Tween
var _squash: Vector2 = Vector2.ONE
var _time: float = 0.0
var _phase: float = 0.0


## animal: "tavsan", "panda", "penguen" ya da "kurbaga"; height: ekrandaki boy (piksel)
func setup(animal: String, height: float, dance_move: Move) -> void:
	move = dance_move
	_phase = randf() * TAU
	_body = Node2D.new()
	add_child(_body)
	var unit := height / 256.0
	if animal == "kurbaga":
		for k in 2:
			_part(load(G + "kurbaga_bacak.svg"), unit).flip_h = k == 1
		_part(load(G + "kurbaga_govde.svg"), unit)
		_face_normal = load(G + "kurbaga_yuz_normal.svg")
		_face_happy = load(G + "kurbaga_yuz_zipla.svg")
		_face = _part(_face_normal, unit)
	else:
		_part(load(G + animal + ".svg"), unit)


func _part(texture: Texture2D, unit: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * 256.0 * unit / texture.get_width()
	sprite.position = Vector2(0, (128.0 - FEET) * unit)
	_body.add_child(sprite)
	return sprite


## Bir nota çaldı: enerji artar, karakter zıplar
func kick(strength: float = 1.0) -> void:
	energy = minf(1.0, energy + 0.3 * strength)
	var height := 18.0 + 26.0 * energy
	if _hop_tween:
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(self, "_hop", height, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(self, "_hop", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hop_tween.tween_callback(_land)
	if move == Move.SPIN and randf() < 0.35 and not (_spin_tween and _spin_tween.is_running()):
		_turn(0.45)


# Tek dönüş tween'i ve her dönüş tam turda biter: üst üste binen dönüşler _spin'i yarım turda bırakınca
# gövde (genişliği cos(_spin)) incecik kalıyordu
func _turn(duration: float) -> void:
	if _spin_tween:
		_spin_tween.kill()
	var target := ceilf(_spin / TAU) * TAU
	if target - _spin < PI:
		target += TAU
	_spin_tween = create_tween()
	_spin_tween.tween_property(self, "_spin", target, duration).set_trans(Tween.TRANS_SINE)


func _land() -> void:
	# Yere inince hafifçe ezilir
	_squash = Vector2(1.12, 0.88)
	create_tween().tween_property(self, "_squash", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Şarkı bitti: büyük zıplama ve dönüş
func celebrate() -> void:
	energy = 1.0
	if _hop_tween:
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(self, "_hop", 90.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(self, "_hop", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hop_tween.tween_callback(_land)
	_turn(0.6)


func is_dancing() -> bool:
	return energy > 0.05


func _process(delta: float) -> void:
	_time += delta
	energy = maxf(0.0, energy - delta / calm_time)
	var e := smoothstep(0.0, 0.6, energy)      # dans ile bekleme arasındaki yumuşak geçiş
	var beat := _time * TAU * 2.0 + _phase     # ~120 vuruş/dakika
	var rot := 0.0
	var x := 0.0
	var bob := 0.0
	match move:
		Move.SWAY:
			rot = sin(beat * 0.5) * 0.22
			bob = absf(sin(beat * 0.5)) * 10.0
		Move.STEP:
			x = sin(beat * 0.5) * 22.0
			bob = absf(sin(beat)) * 12.0
			rot = sin(beat) * 0.08
		Move.SPIN:
			rot = sin(beat * 0.5) * 0.12
			bob = absf(sin(beat * 0.5)) * 14.0
		Move.BOUNCE:
			bob = absf(sin(beat * 0.5)) * 22.0
	# Bekleme: yavaş nefes ve hafif baş eğme
	var idle_rot := sin(_time * 0.9 + _phase) * 0.04
	var breath := sin(_time * 2.2 + _phase) * 0.025
	_body.rotation = lerpf(idle_rot, rot, e)
	_body.position = Vector2(x * e, -(_hop + bob * e))
	_body.scale = Vector2((1.0 - breath * (1.0 - e)) * _squash.x * cos(_spin), (1.0 + breath * (1.0 - e)) * _squash.y)
	if _face:
		_face.texture = _face_happy if energy > 0.25 else _face_normal

