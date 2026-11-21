extends Node2D
# Sağ alttaki yuvarlak rozet: o anki adımın aleti (sünger / duş / havlu) büyük görünür, altında üç adım
# noktası (biten adımlar dolu). Adım değişince eski alet küçülür, yenisi zıplayarak gelir. Sadece gösterir;
# alet ekranın her yerinde parmağın altında belirir (alet.gd).

const TEXTURES: Array[Texture2D] = [
	preload("res://oyunlar/hayvan_banyosu/gorseller/sunger.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/dus.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/havlu.svg"),
]
const OUT := Color("3b2f6b")
const DOT_DONE := Color("5cc95c")
const DOT_NOW := Color("ffd23f")
const DOT_LATER := Color(0.23, 0.18, 0.42, 0.2)

var radius: float = 78.0
var step: int = 0

var _icon: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	_icon = Sprite2D.new()
	add_child(_icon)
	_set_icon(0)


func _set_icon(index: int) -> void:
	_icon.texture = TEXTURES[index]
	var size := TEXTURES[index].get_size()
	_icon.set_meta("base", radius * 1.45 / maxf(size.x, size.y))
	_icon.scale = Vector2.ONE * float(_icon.get_meta("base"))
	_icon.position = Vector2(0.0, -radius * 0.04)


# Yeni bölüm: ilk adım, rozet zıplayarak gelir
func reset() -> void:
	step = 0
	_set_icon(0)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


# Adım bitti: eski alet küçülür, sonraki zıplar (son adımdan sonra boş rozet tik gibi parlar)
func advance() -> void:
	step += 1
	var tween := create_tween()
	tween.tween_property(_icon, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if step < TEXTURES.size():
		tween.tween_callback(func() -> void:
			_set_icon(step)
			_icon.scale = Vector2.ZERO)
		tween.tween_property(_icon, "scale", Vector2.ONE * radius * 1.45 / _max_side(step), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func hide_badge() -> void:
	create_tween().tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _max_side(index: int) -> float:
	var size := TEXTURES[index].get_size()
	return maxf(size.x, size.y)


func _process(delta: float) -> void:
	_time += delta
	_icon.rotation = sin(_time * 2.5) * 0.06


func _draw() -> void:
	draw_circle(Vector2(0, 6), radius + 4.0, Color(OUT, 0.18))
	draw_circle(Vector2.ZERO, radius + 6.0, OUT)
	draw_circle(Vector2.ZERO, radius, Color.WHITE)
	# Adım noktaları: rozetin altında, yarısı dışarıda
	for i in 3:
		var p := Vector2((i - 1) * radius * 0.42, radius * 0.92)
		var color := DOT_DONE if i < step else (DOT_NOW if i == step else Color.WHITE)
		draw_circle(p, radius * 0.16, OUT)
		draw_circle(p, radius * 0.16 - 4.0, color)
		if i > step:
			draw_circle(p, radius * 0.16 - 4.0, DOT_LATER)
