extends "res://oyunlar/siradaki_ne/tema.gd"
# Boncuk kolye: boncuklar duvardaki iki iğneye asılı bir ipe dizilir. Bitince bir hayvan gelir, kolye
# küçülüp U biçiminde sarkarak onun boynuna takılır.

const CORD := Color("fff1d6")
const PIN := Color("ffc93d")
## Kolyenin hayvanın boynundaki uçları ve sarkması (hayvan SVG'sinin 256'lık tuvalinde)
const NECK := Vector2(0.0, 56.0)       # boynun ortası, tuvalin ortasına göre
const NECK_HALF := 66.0
const NECK_DROP := 44.0

var _pins: bool = true
var _bend: float = 0.0
var _bend_amount: float = 0.0


func _ends() -> Array:
	var lift := Vector2(0.0, -plan.cell * 0.32)
	return [plan.slots[0] + Vector2(-plan.cell * 0.72, 0.0) + lift, plan.slots[plan.slots.size() - 1] + Vector2(plan.cell * 0.72, 0.0) + lift]


func _draw() -> void:
	if _pins:
		for p in _ends():
			draw_circle(p, 15.0, OUTLINE)
			draw_circle(p, 10.0, PIN)
			draw_circle(p + Vector2(-3, -3), 3.5, Color.WHITE)


func _draw_track() -> void:
	var pts := points()
	var line := PackedVector2Array()
	if row.scale.x > 0.99:
		var ends := _ends()
		line.append(ends[0])
		line.append_array(pts)
		line.append(ends[1])
	else:
		line = pts
	cord(smooth(line), 7.0, CORD, 4.0)


func finish() -> void:
	_pins = false
	queue_redraw()
	var screen := plan.screen
	var size := minf(plan.area.size.y * 0.62, 460.0)
	var animal := Sprite2D.new()
	animal.texture = load("res://oyunlar/siradaki_ne/gorseller/parcalar/hayvan_%s.svg" % Settings.ANIMALS[randi() % Settings.ANIMALS.size()])
	var base_scale := Vector2.ONE * size / animal.texture.get_width()
	animal.position = Vector2(screen.x / 2.0, plan.area.position.y + plan.area.size.y * 0.56)
	animal.scale = Vector2.ZERO
	add_child(animal)
	move_child(animal, 0)                  # dizinin (kolyenin) arkasında
	var appear := animal.create_tween()
	appear.tween_property(animal, "scale", base_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await appear.finished
	# Kolye küçülür ve boynuna kayar; ortası U gibi sarkar
	var unit := size / 256.0
	var x0: float = plan.slots[0].x
	var x1: float = plan.slots[plan.slots.size() - 1].x
	var s := NECK_HALF * 2.0 * unit / (x1 - x0)
	var neck := animal.position + NECK * unit
	var target := neck - s * Vector2((x0 + x1) / 2.0, plan.slots[0].y)
	_bend_amount = NECK_DROP * unit / s
	var tween := create_tween().set_parallel()
	tween.tween_property(row, "scale", Vector2.ONE * s, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(row, "position", target, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_bend, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tween.finished
	sounds.play("kolye")
	effects.sparkle(neck + Vector2(0.0, NECK_DROP * unit), size * 0.5)
	effects.stars(neck, size * 0.4)
	var hop := animal.create_tween()
	for k in 2:
		hop.tween_property(animal, "scale", base_scale * Vector2(1.08, 0.92), 0.12)
		hop.tween_property(animal, "scale", base_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.1).timeout


func _set_bend(b: float) -> void:
	_bend = b
	var n := plan.slots.size()
	var base_y: float = plan.slots[0].y
	for i in n:
		var piece: Node2D = pieces[i]
		if piece == null:
			continue
		var t := float(i) / maxf(1.0, n - 1) * 2.0 - 1.0
		var y := lerpf(plan.slots[i].y, base_y + _bend_amount * (1.0 - t * t), b)
		piece.position = Vector2(plan.slots[i].x, y)
