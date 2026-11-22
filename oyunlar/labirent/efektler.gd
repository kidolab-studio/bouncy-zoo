extends Node2D
# Labirent efektleri (Noktaları Birleştir efektler.gd kopyası; o da Yapboz'dan): ışıltı, yıldız patlaması, bölüm sonunda
# konfeti, son bölümde büyük final. Hepsi tek seferlik CPUParticles2D; bitince kendini siler.

const TEX_STAR: Texture2D = preload("res://oyunlar/labirent/gorseller/yildiz.svg")
const TEX_SPARKLE: Texture2D = preload("res://oyunlar/labirent/gorseller/isilti.svg")
const RAINBOW := [Color("ff5a6e"), Color("ff9f40"), Color("ffd23f"), Color("5cc95c"), Color("4fa8ff"), Color("a66bff")]

var _rainbow := Gradient.new()
var _shrink := Curve.new()
var _confetti_texture: Texture2D


func _ready() -> void:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in RAINBOW.size():
		offsets.append(float(i) / RAINBOW.size())
		colors.append(RAINBOW[i])
	_rainbow.offsets = offsets
	_rainbow.colors = colors
	_rainbow.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_shrink.add_point(Vector2(0.0, 1.0))
	_shrink.add_point(Vector2(1.0, 0.2))
	var image := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for corner in [Vector2i(0, 0), Vector2i(13, 0), Vector2i(0, 21), Vector2i(13, 21)]:
		image.set_pixelv(corner, Color(1, 1, 1, 0))
	_confetti_texture = ImageTexture.create_from_image(image)


func _emitter(texture: Texture2D, amount: int, lifetime: float, pos: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = pos
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	return particles


func _fade(color: Color = Color.WHITE) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.0)])
	return gradient


# Nesne yerine oturunca küçük ışıltı
func sparkle(pos: Vector2, size: float) -> void:
	var glints := _emitter(TEX_SPARKLE, 8, 0.6, pos)
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glints.emission_sphere_radius = size * 0.3
	glints.spread = 180.0
	glints.gravity = Vector2.ZERO
	glints.initial_velocity_min = 20.0
	glints.initial_velocity_max = 70.0
	glints.scale_amount_min = size * 0.1 / TEX_SPARKLE.get_width()
	glints.scale_amount_max = size * 0.22 / TEX_SPARKLE.get_width()
	glints.scale_amount_curve = _shrink
	glints.color_ramp = _fade()
	glints.emitting = true


func stars(pos: Vector2, size: float) -> void:
	var burst := _emitter(TEX_STAR, 12, 0.8, pos)
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = size * 0.2
	burst.spread = 180.0
	burst.gravity = Vector2(0, 250)
	burst.initial_velocity_min = size * 1.4
	burst.initial_velocity_max = size * 2.4
	burst.damping_min = size * 1.5
	burst.damping_max = size * 2.5
	burst.angular_velocity_min = -300.0
	burst.angular_velocity_max = 300.0
	burst.scale_amount_min = size * 0.16 / TEX_STAR.get_width()
	burst.scale_amount_max = size * 0.28 / TEX_STAR.get_width()
	burst.scale_amount_curve = _shrink
	burst.color_ramp = _fade()
	burst.emitting = true


# Bölüm sonu: ekranın üstünden yağan konfeti
func confetti(amount: int) -> void:
	var screen := get_viewport_rect().size
	var rain := _emitter(_confetti_texture, amount, 3.2, Vector2(screen.x / 2.0, -40.0))
	rain.explosiveness = 0.75
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(screen.x / 2.0, 20.0)
	rain.direction = Vector2(0, 1)
	rain.spread = 25.0
	rain.gravity = Vector2(0, 260)
	rain.initial_velocity_min = 120.0
	rain.initial_velocity_max = 300.0
	rain.angular_velocity_min = -360.0
	rain.angular_velocity_max = 360.0
	rain.angle_max = 360.0
	rain.scale_amount_min = 0.8
	rain.scale_amount_max = 1.3
	rain.color_initial_ramp = _rainbow
	rain.emitting = true


# Son bölüm: bol konfeti, alt köşelerden konfeti topları, sırayla yıldız patlamaları ve uçuşan kalpler
func finale(size: float) -> void:
	confetti(180)
	var screen := get_viewport_rect().size
	for left in [true, false]:
		var cannon := _emitter(_confetti_texture, 70, 3.0, Vector2(0.0 if left else screen.x, screen.y + 20.0))
		cannon.direction = Vector2(0.45 if left else -0.45, -1.0)
		cannon.spread = 18.0
		cannon.gravity = Vector2(0, 700)
		cannon.initial_velocity_min = screen.y * 0.9
		cannon.initial_velocity_max = screen.y * 1.35
		cannon.damping_min = 40.0
		cannon.damping_max = 90.0
		cannon.angular_velocity_min = -540.0
		cannon.angular_velocity_max = 540.0
		cannon.angle_max = 360.0
		cannon.scale_amount_min = 0.8
		cannon.scale_amount_max = 1.4
		cannon.color_initial_ramp = _rainbow
		cannon.emitting = true
	var tween := create_tween()
	for k in 6:
		var point := Vector2(randf_range(0.15, 0.85) * screen.x, randf_range(0.25, 0.65) * screen.y)
		tween.tween_callback(stars.bind(point, size))
		tween.tween_callback(sparkle.bind(point, size))
		tween.tween_interval(0.4)
