extends Node2D
# Yapboz arka planı: bütün görünen alanı kaplayan pastel renk ve üstünde hafif puantiye (21:9 ve 4:3'te
# boşluk kalmaz). Renk resme göre değişir (ayarlar.gd PICTURES color), geçiş yumuşaktır.

const DOT_SPACING := 64.0

var color: Color = Color("ffe9c7"):
	set(value):
		color = value
		queue_redraw()

var _size: Vector2
var _tween: Tween


func layout(screen: Vector2) -> void:
	_size = screen
	queue_redraw()


func show_color(target: Color) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", target, 0.5)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), color)
	var dot := color.lightened(0.35)
	var line := 0
	var y := DOT_SPACING * 0.5
	while y < _size.y + DOT_SPACING:
		var x := DOT_SPACING * (0.5 if line % 2 == 0 else 1.0)
		while x < _size.x + DOT_SPACING:
			draw_circle(Vector2(x, y), 9.0, dot)
			x += DOT_SPACING
		y += DOT_SPACING * 0.75
		line += 1
	# Kenarlarda hafif koyuluk: göz ortaya gitsin
	var edge := color.darkened(0.06)
	draw_rect(Rect2(0.0, _size.y - 40.0, _size.x, 40.0), Color(edge, 0.5))
