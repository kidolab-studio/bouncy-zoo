extends "res://oyunlar/siradaki_ne/tema.gd"
# Hayvan geçidi: hayvanlar bir tepenin üstündeki yolda sıraya girer. Bitince zıplaya zıplaya sağa
# yürüyüp ekrandan çıkar.

const SAND := Color("f5dca4")
const SAND_DARK := Color("e0bf7a")
## Hayvan SVG'sinde ayakların altı (256'lık tuvalde y = 249; ortası 128): parçanın ortasından aşağı oran
const FEET := (249.0 - 128.0) / 256.0


func _draw() -> void:
	var y: float = plan.slots[0].y + plan.piece * FEET
	var road := Rect2(-20.0, y - 22.0, plan.screen.x + 40.0, 40.0)
	draw_rect(road.grow_individual(0.0, 5.0, 0.0, 5.0), OUTLINE)
	draw_rect(road, SAND)
	for k in int(plan.screen.x / 90.0) + 1:
		draw_circle(Vector2(30.0 + k * 90.0 + (k % 3) * 17.0, y + (k % 2) * 8.0 - 4.0), 4.0, SAND_DARK)


func finish() -> void:
	var distance: float = plan.screen.x - plan.slots[0].x + plan.cell
	var tween := create_tween()
	tween.tween_method(_march.bind(distance), 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for k in 8:
		get_tree().create_timer(k * 0.3).timeout.connect(func() -> void:
			if is_inside_tree():
				sounds.play("adim", 0.9 + (k % 3) * 0.1))
	await tween.finished


func _march(t: float, distance: float) -> void:
	row.position.x = distance * t
	var phase := t * TAU * 6.0
	for i in pieces.size():
		var piece: Node2D = pieces[i]
		if piece:
			piece.position.y = plan.slots[i].y - absf(sin(phase - i * 0.7)) * 20.0
			piece.rotation = 0.08 * sin(phase - i * 0.7)
