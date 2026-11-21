extends Node2D
# Sağdaki alet rafı: üç alet (sünger, duş, havlu) yukarıdan aşağı banyo sırasıyla. Sırası gelen alet sarı
# halkayla parlar ve hafifçe nabız gibi atar; çocuk onu tutup hayvanın üstüne sürükler (alet parmaktayken
# rafta yeri boş görünür, bırakınca uçarak geri gelir: alet.gd). Biten aletler soluk ve yeşil tikli,
# sıradakiler soluk. Sırası gelmeyen alete dokununca sadece kıpırdar (wiggle).

const TEXTURES: Array[Texture2D] = [
	preload("res://oyunlar/hayvan_banyosu/gorseller/sunger.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/dus.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/havlu.svg"),
]
const OUT := Color("3b2f6b")
const GLOW := Color("ffd23f")
const DONE := Color("5cc95c")

var radius: float = 66.0
var spacing: float = 155.0
var step: int = 0
## Yeri boş görünen raf (alet parmakta ya da rafa dönüyor); -1: hiçbiri
var empty_slot: int = -1

var _icons: Array[Sprite2D] = []
var _wiggle: Array[float] = [0.0, 0.0, 0.0]
var _pop: Array[float] = [0.0, 0.0, 0.0]   # alet rafa dönünce / sırası gelince kısa zıplama
var _time: float = 0.0


func _ready() -> void:
	for i in TEXTURES.size():
		var icon := Sprite2D.new()
		icon.texture = TEXTURES[i]
		add_child(icon)
		_icons.append(icon)
	_place()


# center: rafın ortası (ortadaki alet), r: bir yuvanın yarıçapı
func layout(center: Vector2, r: float) -> void:
	position = center
	radius = r
	spacing = r * 2.35
	_place()


func _place() -> void:
	for i in _icons.size():
		_icons[i].position = slot_local(i)
	queue_redraw()


func slot_local(index: int) -> Vector2:
	return Vector2(0.0, (index - 1) * spacing)


func slot_position(index: int) -> Vector2:
	return to_global(slot_local(index))


## Raftaki aletin ekrandaki genişliği (alet rafa dönerken bu boya küçülür)
func icon_width() -> float:
	return radius * 1.45


## Noktadaki yuva (cömert alan); yoksa -1
func slot_at(point: Vector2) -> int:
	for i in TEXTURES.size():
		if point.distance_to(slot_position(i)) <= radius * 1.3 * global_scale.x:
			return i
	return -1


# Yeni bölüm: ilk alet sırada, raf zıplayarak gelir
func reset() -> void:
	step = 0
	empty_slot = -1
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Adım bitti: sıradaki alet parlar
func advance() -> void:
	step += 1
	if step < TEXTURES.size():
		_pop[step] = 1.0


func wiggle(index: int) -> void:
	_wiggle[index] = 1.0


# Alet rafa döndü: yeri dolar, kısa zıplar
func show_slot(index: int) -> void:
	if empty_slot == index:
		empty_slot = -1
		_pop[index] = 1.0


func hide_tray() -> void:
	create_tween().tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	_time += delta
	for i in _icons.size():
		_wiggle[i] = move_toward(_wiggle[i], 0.0, delta * 2.2)
		_pop[i] = move_toward(_pop[i], 0.0, delta * 3.0)
		var icon := _icons[i]
		var size := TEXTURES[i].get_size()
		var base := icon_width() / maxf(size.x, size.y)
		var beat := 1.0 + 0.06 * sin(_time * 5.0) if i == step else 1.0
		icon.visible = i != empty_slot
		icon.scale = Vector2.ONE * base * beat * (1.0 + 0.25 * sin(_pop[i] * PI))
		icon.rotation = sin(_wiggle[i] * 18.0) * 0.3 * _wiggle[i]
		icon.position = slot_local(i) + Vector2(sin(_wiggle[i] * 22.0) * radius * 0.12 * _wiggle[i], 0.0)
		icon.modulate = Color.WHITE if i == step else Color(1, 1, 1, 0.45)
	queue_redraw()


func _draw() -> void:
	for i in TEXTURES.size():
		var p := slot_local(i)
		var current := i == step
		if current:
			# Sırası gelen: nabız gibi atan sarı halka
			var glow := radius + 12.0 + 4.0 * sin(_time * 5.0)
			draw_circle(p, glow, Color(GLOW, 0.35))
		draw_circle(p + Vector2(0, 5), radius + 4.0, Color(OUT, 0.18))
		draw_circle(p, radius + 5.0, GLOW.darkened(0.15) if current else OUT)
		draw_circle(p, radius, Color.WHITE if current else Color(1, 1, 1, 0.75))
		if i < step:
			# Biten alet: sağ üstte yeşil tik
			var c := p + Vector2(radius * 0.68, -radius * 0.68)
			var r := radius * 0.3
			draw_circle(c, r + 3.0, OUT)
			draw_circle(c, r, DONE)
			draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.1, 0.35) * r, c + Vector2(0.5, -0.35) * r]),
				Color.WHITE, maxf(3.0, r * 0.28), true)
