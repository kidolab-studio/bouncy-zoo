extends "res://oyunlar/siradaki_ne/tema.gd"
# Parti bayrakları: iki direk arasına gerilmiş ipe bayraklar asılır. Bitince bayraklar dalgalanır,
# direklerin tepesinden konfeti patlar.

const ROPE := Color("ffffff")
const POLE := Color("e9a35c")
const BALL := Color("ff7a8a")
## Bayrak SVG'sinde ipin geçtiği yer (160'lık tuvalde y = 16; ortası 80): parçanın ortasından yukarı oran
const ANCHOR := (80.0 - 16.0) / 160.0


func _poles() -> Array:
	var top_y: float = plan.slots[0].y - plan.piece * ANCHOR - 26.0
	return [Vector2(plan.slots[0].x - plan.cell * 0.78, top_y), Vector2(plan.slots[plan.slots.size() - 1].x + plan.cell * 0.78, top_y)]


func _draw() -> void:
	for top in _poles():
		var rect := Rect2(top.x - 9.0, top.y - 6.0, 18.0, plan.floor_y + 14.0 - top.y)
		draw_rect(rect.grow(5.0), OUTLINE)
		draw_rect(rect, POLE)
		draw_rect(Rect2(rect.position.x + 3.0, rect.position.y, 4.0, rect.size.y), Color(1, 1, 1, 0.35))
		draw_circle(top - Vector2(0.0, 10.0), 19.0, OUTLINE)
		draw_circle(top - Vector2(0.0, 10.0), 14.0, BALL)
		draw_circle(top - Vector2(4.0, 15.0), 4.5, Color.WHITE)


func _draw_track() -> void:
	var poles := _poles()
	var line := PackedVector2Array([poles[0]])
	for p in points():
		line.append(p - Vector2(0.0, plan.piece * ANCHOR))
	line.append(poles[1])
	cord(smooth(line), 5.0, ROPE, 3.5)


func finish() -> void:
	sounds.play("patlama")
	for top in _poles():
		effects.popper(top - Vector2(0.0, 20.0), Vector2(0.35 if top.x < plan.screen.x / 2.0 else -0.35, -1.0))
	effects.confetti(70)
	var tween := create_tween()
	tween.tween_method(_flutter, 0.0, 1.8, 1.8)
	await tween.finished
	_flutter(0.0)
	await get_tree().create_timer(0.2).timeout


func _flutter(t: float) -> void:
	var fade := clampf(1.8 - t, 0.0, 1.0)
	for i in pieces.size():
		var piece: Node2D = pieces[i]
		if piece:
			piece.skew = 0.28 * sin(t * 9.0 + i * 0.9) * fade
			piece.rotation = 0.05 * sin(t * 7.0 + i * 1.3) * fade
