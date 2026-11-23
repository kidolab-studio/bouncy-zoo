extends Node2D
# Hastanın başının üstündeki düşünce balonu: stetoskopla dinlenince rahatsızlığın simgesi (ayarlar.gd AILMENTS
# "icon") içinde belirir. Balon bulut biçiminde, kafaya doğru iki küçük daireyle bağlanır; kodla çizilir.
# Düğümün konumu kafanın üstü; balon sağ üste doğru açılır.

const OUT := Color("3b2f6b")
## Bulut tümsekleri: merkeze göre konum ve yarıçap (balon boyuna oran)
const PUFFS := [Vector3(0.0, 0.0, 0.42), Vector3(-0.34, 0.08, 0.28), Vector3(0.34, 0.08, 0.28), Vector3(-0.18, -0.22, 0.28),
	Vector3(0.18, -0.24, 0.3), Vector3(0.0, 0.22, 0.3)]

var size: float = 170.0
var shown: bool = false

var _icon: Sprite2D
var _tween: Tween
var _time: float = 0.0


func _ready() -> void:
	_icon = Sprite2D.new()
	add_child(_icon)
	scale = Vector2.ZERO
	visible = false


func show_icon(texture: Texture2D, head_top: Vector2, bubble_size: float) -> void:
	size = bubble_size
	position = head_top
	_icon.texture = texture
	_icon.position = _center()
	_icon.scale = Vector2.ONE * size * 0.62 / texture.get_width()
	shown = true
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func hide_bubble() -> void:
	if not shown:
		return
	shown = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


func _center() -> Vector2:
	return Vector2(size * 0.45, -size * 0.62)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_icon.rotation = sin(_time * 3.0) * 0.06


func _draw() -> void:
	var c := _center()
	# Kafaya doğru iki küçük daire
	for t: Vector3 in [Vector3(0.08, -0.1, 0.07), Vector3(0.2, -0.26, 0.1)]:
		var p := Vector2(t.x, t.y) * size
		draw_circle(p, t.z * size + 4.0, OUT)
		draw_circle(p, t.z * size, Color.WHITE)
	for puff: Vector3 in PUFFS:
		draw_circle(c + Vector2(puff.x, puff.y) * size, puff.z * size + 5.0, OUT)
	for puff: Vector3 in PUFFS:
		draw_circle(c + Vector2(puff.x, puff.y) * size, puff.z * size, Color.WHITE)
