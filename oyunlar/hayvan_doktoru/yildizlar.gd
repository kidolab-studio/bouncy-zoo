extends Node2D
# (Hayvan Banyosu yildizlar.gd kopyası; o da Hayvanları Besle'den) Üstte metinsiz ilerleme: her gün için bir yıldız. Biten bölümler
# parlak altın, şu anki yarı saydam ve nabız gibi atar, sıradakiler soluk gölge. Bölüm bitince yıldız zıplayarak
# dolar; finalde hepsi.

const TEX_STAR: Texture2D = preload("res://oyunlar/hayvan_doktoru/gorseller/yildiz.svg")
const LATER := Color(0.3, 0.26, 0.5, 0.28)
const CURRENT := Color(1, 1, 1, 0.55)

var count: int = 10
var current: int = 0
var spacing: float = 46.0
var star_size: float = 40.0

var _stars: Array[Sprite2D] = []
var _time: float = 0.0


func setup(level_count: int) -> void:
	count = level_count
	for star in _stars:
		star.queue_free()
	_stars.clear()
	for i in count:
		var star := Sprite2D.new()
		star.texture = TEX_STAR
		add_child(star)
		_stars.append(star)
	_refresh()


func layout(center: Vector2, width: float) -> void:
	position = center
	spacing = minf(48.0, width / maxf(1.0, count))
	star_size = spacing * 0.85
	_refresh()


func set_current(index: int) -> void:
	current = index
	_refresh()


# Bölüm bitti: yıldızı dolar ve zıplar
func complete(index: int) -> void:
	current = index + 1
	_refresh()
	_pop(index, 0.0)


# Final: bütün yıldızlar sırayla zıplar
func celebrate_all() -> void:
	current = count
	_refresh()
	for i in count:
		_pop(i, i * 0.06)


func is_done(index: int) -> bool:
	return index < current


func _refresh() -> void:
	var left := -spacing * (count - 1) / 2.0
	for i in _stars.size():
		var star := _stars[i]
		star.position = Vector2(left + i * spacing, 0.0)
		star.scale = Vector2.ONE * star_size / TEX_STAR.get_width()
		star.modulate = Color.WHITE if i < current else (CURRENT if i == current else LATER)


func _pop(index: int, delay: float) -> void:
	if index < 0 or index >= _stars.size():
		return
	var star := _stars[index]
	var base := Vector2.ONE * star_size / TEX_STAR.get_width()
	var tween := star.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(star, "scale", base * 1.7, 0.14).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(star, "rotation", TAU / 5.0, 0.3)
	tween.tween_property(star, "scale", base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: star.rotation = 0.0)


func _process(delta: float) -> void:
	_time += delta
	if current < _stars.size():
		var star := _stars[current]
		star.scale = Vector2.ONE * star_size / TEX_STAR.get_width() * (1.12 + sin(_time * 4.0) * 0.08)
