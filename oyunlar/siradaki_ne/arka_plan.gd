extends Node2D
# Temanın arka planı (gorseller/arka_plan_<tema>.svg, 1280x720): ekranı tamamen kaplar, resimdeki zemin
# çizgisi (y = 520) ekrandaki zemin çizgisine (plan.floor_y) denk gelir. Tema değişince yenisi yumuşakça belirir.

const ART_SIZE := Vector2(1280.0, 720.0)
const ART_FLOOR := 520.0

var _sprite: Sprite2D
var _theme: String = ""


func show_theme(theme: String, screen: Vector2, floor_y: float) -> void:
	if theme != _theme:
		_theme = theme
		var old := _sprite
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://oyunlar/siradaki_ne/gorseller/arka_plan_%s.svg" % theme)
		_sprite.centered = false
		add_child(_sprite)
		if old:
			_sprite.modulate.a = 0.0
			var tween := _sprite.create_tween()
			tween.tween_property(_sprite, "modulate:a", 1.0, 0.45)
			tween.tween_callback(old.queue_free)
	layout(screen, floor_y)


func layout(screen: Vector2, floor_y: float) -> void:
	# Hem genişliği hem zeminin üstünü (520) ve altını (200) kaplayacak kadar büyüt
	var s := maxf(screen.x / ART_SIZE.x, maxf(floor_y / ART_FLOOR, (screen.y - floor_y) / (ART_SIZE.y - ART_FLOOR)))
	for child in get_children():
		var sprite := child as Sprite2D
		sprite.scale = Vector2.ONE * s * ART_SIZE.x / sprite.texture.get_width()
		sprite.position = Vector2(screen.x / 2.0 - ART_SIZE.x * s / 2.0, floor_y - ART_FLOOR * s)
