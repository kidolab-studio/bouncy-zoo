extends "res://oyunlar/siradaki_ne/tema.gd"
# Çiçek bahçesi: çiçekler uzun bir saksının toprağına dikilir. Bitince sırayla açar (büyüyüp parlar),
# iki kelebek uçup gelir.

const TEX_BUTTERFLY: Texture2D = preload("res://oyunlar/siradaki_ne/gorseller/kelebek.svg")
const WOOD := Color("d9935a")
const WOOD_DARK := Color("b8743f")
const SOIL := Color("7a4a2a")
## Çiçek SVG'sinde sap dibi (160'lık tuvalde y = 154; ortası 80): parçanın ortasından aşağı oran
const BASE := (154.0 - 80.0) / 160.0


func _draw() -> void:
	var soil_y: float = plan.slots[0].y + plan.piece * BASE
	var left: float = plan.slots[0].x - plan.cell * 0.66
	var right: float = plan.slots[plan.slots.size() - 1].x + plan.cell * 0.66
	var box := Rect2(left, soil_y - 8.0, right - left, 70.0)
	draw_rect(box.grow(5.0), OUTLINE)
	draw_rect(box, WOOD)
	draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 18.0), SOIL)
	for k in 2:
		var y := box.position.y + 34.0 + k * 18.0
		draw_line(Vector2(box.position.x + 8.0, y), Vector2(box.end.x - 8.0, y), WOOD_DARK, 3.0)
	draw_rect(Rect2(box.position.x + 6.0, box.position.y + 22.0, box.size.x - 12.0, 5.0), Color(1, 1, 1, 0.25))


func finish() -> void:
	var flowers := []
	for i in pieces.size():
		if pieces[i]:
			flowers.append(pieces[i])
	for k in flowers.size():
		var flower: Node2D = flowers[k]
		var tween := flower.create_tween()
		tween.tween_interval(k * 0.12)
		tween.tween_callback(func() -> void:
			sounds.play("cicek", 1.0 + k * 0.04)
			effects.sparkle(flower.global_position - Vector2(0.0, plan.piece * 0.2), plan.piece * 0.8))
		tween.tween_property(flower, "scale", Vector2(1.22, 1.22), 0.16).set_trans(Tween.TRANS_SINE)
		tween.tween_property(flower, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# İki kelebek iki yandan gelip çiçeklerin üstüne konar
	for side in [-1.0, 1.0]:
		var half := int(flowers.size() / 2.0)
		var target: Node2D = flowers[randi_range(0, half - 1) if side < 0 else randi_range(half, flowers.size() - 1)]
		_butterfly(side, target.position - Vector2(0.0, plan.piece * 0.45))
	await get_tree().create_timer(2.0).timeout


func _butterfly(side: float, land: Vector2) -> void:
	var b := Sprite2D.new()
	b.texture = TEX_BUTTERFLY
	var base := Vector2.ONE * plan.piece * 0.55 / TEX_BUTTERFLY.get_width()
	b.scale = base
	b.z_index = 5
	var start := Vector2(plan.screen.x / 2.0 + side * (plan.screen.x / 2.0 + 80.0), land.y - 160.0)
	b.position = start
	add_child(b)
	var fly := b.create_tween()
	fly.tween_method(func(t: float) -> void:
		b.position = start.lerp(land, t) + Vector2(0.0, sin(t * TAU * 1.5) * 50.0 * (1.0 - t))
		b.scale = Vector2(base.x * (0.35 + 0.65 * absf(cos(t * 30.0))), base.y), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly.tween_property(b, "scale", base, 0.1)
