extends "res://oyunlar/siradaki_ne/tema.gd"
# Tırtıl: renkli halkalar sola bakan başın arkasına dizilir, tırtıl bir dalın üstünde durur. Bitince
# kıpır kıpır sürünerek sola, ekrandan çıkar.

const TEX_HEAD: Texture2D = preload("res://oyunlar/siradaki_ne/gorseller/tirtil_bas.svg")
const BRANCH := Color("a8703f")
const LEAF := Color("6cc453")
## Halka SVG'sinde ayakların altı (160'lık tuvalde y = 154): parçanın ortasından aşağı oran
const FEET := (154.0 - 80.0) / 160.0

var head: Sprite2D


func decorate() -> void:
	head = Sprite2D.new()
	head.texture = TEX_HEAD
	head.scale = Vector2.ONE * plan.piece * 1.02 / TEX_HEAD.get_width()
	head.position = plan.slots[0] + Vector2(-plan.cell * 0.92, -plan.piece * 0.06)
	head.z_index = 3
	row.add_child(head)
	head.set_meta("home", head.position)


func _draw() -> void:
	var y: float = plan.slots[0].y + plan.piece * FEET + 8.0
	var left: float = plan.slots[0].x - plan.cell * 2.0
	var right: float = plan.slots[plan.slots.size() - 1].x + plan.cell * 0.9
	var pts := PackedVector2Array()
	for k in 13:
		var x := lerpf(left, right, k / 12.0)
		pts.append(Vector2(x, y + sin(k * 0.8) * 5.0))
	draw_polyline(pts, OUTLINE, 32.0, true)
	draw_polyline(pts, BRANCH, 22.0, true)
	draw_circle(pts[pts.size() - 1], 16.0, OUTLINE)
	draw_circle(pts[pts.size() - 1], 11.0, BRANCH)
	for k in [2, 6, 10]:
		var p := pts[k] + Vector2(0.0, 10.0)
		var leaf := PackedVector2Array()
		for a in 16:
			var t := a / 16.0 * TAU
			leaf.append(p + Vector2(cos(t) * 30.0 + 26.0, sin(t) * 13.0 + 18.0).rotated(0.5))
		draw_colored_polygon(leaf, LEAF)
		leaf.append(leaf[0])
		draw_polyline(leaf, OUTLINE, 4.0, true)


func finish() -> void:
	var distance: float = plan.slots[plan.slots.size() - 1].x + plan.cell * 2.0
	var tween := create_tween()
	tween.tween_method(_crawl.bind(distance), 0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for k in 5:
		get_tree().create_timer(k * 0.45).timeout.connect(func() -> void:
			if is_inside_tree():
				sounds.play("surun", 1.0 + k * 0.05))
	await tween.finished


func _crawl(t: float, distance: float) -> void:
	row.position.x = -distance * t
	var phase := t * TAU * 5.0
	for i in pieces.size():
		var piece: Node2D = pieces[i]
		if piece:
			piece.position.y = plan.slots[i].y - absf(sin(phase - i * 0.6)) * 16.0
	head.position.y = (head.get_meta("home") as Vector2).y - absf(sin(phase + 0.6)) * 16.0
