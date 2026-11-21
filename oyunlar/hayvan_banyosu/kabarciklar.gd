extends Node2D
# Küvetteki sudan ara sıra yükselen sabun kabarcıkları (süs). Sallanarak yükselir, yukarıda söner. Alet
# kabarcığın üstünden geçerse patlar (oyun pop_near çağırır; patlayanların yerini döndürür).

const TEX: Texture2D = preload("res://oyunlar/hayvan_banyosu/gorseller/kabarcik.svg")
const MAX_COUNT := 10

var source := Rect2(400, 440, 480, 20)  # kabarcıkların çıktığı alan (suyun yüzü)
var bubble_size: float = 46.0
var enabled: bool = true

var _bubbles: Array[Dictionary] = []    # {pos, speed, size, phase, age}
var _next: float = 0.5


func _process(delta: float) -> void:
	_next -= delta
	if enabled and _next <= 0.0 and _bubbles.size() < MAX_COUNT:
		_next = randf_range(0.6, 1.5)
		_bubbles.append({
			"pos": source.position + Vector2(randf() * source.size.x, randf() * source.size.y),
			"speed": randf_range(50.0, 90.0), "size": bubble_size * randf_range(0.6, 1.2),
			"phase": randf() * TAU, "age": 0.0,
		})
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b["age"] += delta
		b["pos"] += Vector2(sin(b["age"] * 2.2 + b["phase"]) * 30.0, -b["speed"]) * delta
		if b["pos"].y < -b["size"]:
			_bubbles.remove_at(i)
	queue_redraw()


# point çevresindeki kabarcıkları patlatır; patlayanların yerlerini döndürür
func pop_near(point: Vector2, radius: float) -> Array[Vector2]:
	var popped: Array[Vector2] = []
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		if b["age"] > 0.3 and b["pos"].distance_to(point) <= radius + b["size"] * 0.5:
			popped.append(b["pos"])
			_bubbles.remove_at(i)
	return popped


func clear() -> void:
	_bubbles.clear()


func _draw() -> void:
	for b in _bubbles:
		var grow := clampf(b["age"] / 0.4, 0.0, 1.0)
		var fade := clampf(b["pos"].y / 120.0, 0.0, 1.0)
		var s: float = b["size"] * grow
		draw_texture_rect(TEX, Rect2(b["pos"] - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(1, 1, 1, 0.9 * fade))
