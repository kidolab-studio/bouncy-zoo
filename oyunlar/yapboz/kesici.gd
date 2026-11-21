extends RefCounted
# Yapboz kesici (sahneden bağımsız, saf hesap): resmi cols x rows parçaya böler. Her iç kenarda rastgele
# yönde (dışa / içe) bir çıkıntı olur, dış kenarlar düzdür. Komşu iki parça aynı eğriyi ters yönde paylaşır,
# böylece birbirine tam oturur.
# Çıkıntının şekli: kenardan yumuşakça kalkan dar boyun, üstünde yuvarlak baş (baş boyundan geniş).
# Ölçüler ayarlar.gd'de (NECK, HEAD, ...), birimleri hücrenin kısa kenarı.
#
# cut() parça başına bir sözlük verir:
#   col, row   ızgaradaki yeri
#   cell       hücre dikdörtgeni (resim koordinatında, 1200x900)
#   points     parçanın çokgeni (resim koordinatında, saat yönünde; aynı nokta art arda gelmez)

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const ARC_STEPS := 18
const NECK_STEPS := 7


static func cut(cols: int, rows: int, size: Vector2, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cell := Vector2(size.x / cols, size.y / rows)
	var unit := minf(cell.x, cell.y)
	# Yatay kenarlar (r. satırın üstü, soldan sağa) ve dikey kenarlar (c. sütunun solu, yukarıdan aşağı)
	var horizontal := {}
	for r in range(1, rows):
		for c in cols:
			var a := Vector2(c * cell.x, r * cell.y)
			horizontal[Vector2i(c, r)] = edge(a, a + Vector2(cell.x, 0.0), unit, rng)
	var vertical := {}
	for c in range(1, cols):
		for r in rows:
			var a := Vector2(c * cell.x, r * cell.y)
			vertical[Vector2i(c, r)] = edge(a, a + Vector2(0.0, cell.y), unit, rng)
	var pieces: Array[Dictionary] = []
	for r in rows:
		for c in cols:
			var rect := Rect2(Vector2(c * cell.x, r * cell.y), cell)
			var points := PackedVector2Array()
			# Üst (soldan sağa), sağ (yukarıdan aşağı), alt (sağdan sola), sol (aşağıdan yukarı)
			_append(points, horizontal.get(Vector2i(c, r)), rect.position, false)
			_append(points, vertical.get(Vector2i(c + 1, r)), Vector2(rect.end.x, rect.position.y), false)
			_append(points, horizontal.get(Vector2i(c, r + 1)), rect.end, true)
			_append(points, vertical.get(Vector2i(c, r)), Vector2(rect.position.x, rect.end.y), true)
			pieces.append({"col": c, "row": r, "cell": rect, "points": points})
	return pieces


# Kenarın noktalarını ekler (son noktası hariç: o, sonraki kenarın ilk noktası). Kenar yoksa (resmin
# dış kenarı) yalnızca köşe eklenir.
static func _append(points: PackedVector2Array, line: Variant, corner: Vector2, reverse: bool) -> void:
	if line == null:
		points.append(corner)
		return
	var source: PackedVector2Array = line
	if reverse:
		source = source.duplicate()
		source.reverse()
	for k in source.size() - 1:
		points.append(source[k])


## a'dan b'ye çıkıntılı kenar (iki uç dahil). Çıkıntı rastgele yönde (kenarın sağına ya da soluna),
## kenar ortasından biraz kaymış ve biraz farklı boyda.
static func edge(a: Vector2, b: Vector2, unit: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var length := a.distance_to(b)
	var along := (b - a) / length
	var side := Vector2(-along.y, along.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	var center := length * (0.5 + rng.randf_range(-Settings.KNOB_SHIFT, Settings.KNOB_SHIFT))
	var k := unit * (1.0 + rng.randf_range(-Settings.KNOB_SIZE_JITTER, Settings.KNOB_SIZE_JITTER))
	var out := PackedVector2Array()
	for p in knob(center, k):
		out.append(a + along * p.x + side * p.y)
	out.append(b)
	return out


## Çıkıntının yerel noktaları (x: kenar boyunca, y: dışa doğru), kenarın başından (0, 0) başlar,
## çıkıntı bittiği yerde biter (kenarın sonunu edge() ekler). k: ölçü birimi (px).
static func knob(center: float, k: float) -> PackedVector2Array:
	var neck := Settings.NECK * k
	var head := Settings.HEAD * k
	var neck_h := Settings.NECK_HEIGHT * k
	var fillet := Settings.FILLET * k
	var pinch := neck * 0.85
	var head_center := Vector2(center, neck_h + sqrt(head * head - pinch * pinch))
	var left := Vector2(center - pinch, neck_h)
	var right := Vector2(center + pinch, neck_h)
	var a0 := atan2(left.y - head_center.y, left.x - head_center.x)
	var a1 := atan2(right.y - head_center.y, right.x - head_center.x) - TAU
	var out := PackedVector2Array([Vector2.ZERO])
	var tangent := (fillet + neck_h) * 1.2
	# Kenardan boyna (Hermite: kenar yönünde başlar, başın teğetiyle biter)
	_hermite(out, Vector2(center - neck - fillet, 0.0), Vector2(tangent, 0.0), left, _arc_tangent(a0) * tangent)
	# Baş: uzun yoldan (en dıştan) dolaşır
	for s in range(1, ARC_STEPS):
		var angle := lerpf(a0, a1, float(s) / ARC_STEPS)
		out.append(head_center + Vector2(cos(angle), sin(angle)) * head)
	out.append(right)
	_hermite(out, right, _arc_tangent(a1) * tangent, Vector2(center + neck + fillet, 0.0), Vector2(tangent, 0.0), false)
	return out


# Çemberde açı azalırken gidiş yönü
static func _arc_tangent(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


# p0'dan p1'e Hermite eğrisi örnekleri; start: p0'ı da ekle (ilk eğride p0 kenar noktasıdır)
static func _hermite(out: PackedVector2Array, p0: Vector2, t0: Vector2, p1: Vector2, t1: Vector2, start: bool = true) -> void:
	for s in range(0 if start else 1, NECK_STEPS + 1):
		var t := float(s) / NECK_STEPS
		var t2 := t * t
		var t3 := t2 * t
		out.append((2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * t0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * t1)


## Parçaların hatalarını verir (testler): çokgen kendini kesmiyor, üçgenlenebiliyor, alanı hücreye yakın
static func problems(pieces: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for piece in pieces:
		var points: PackedVector2Array = piece["points"]
		var name := "parça %d,%d" % [piece["col"], piece["row"]]
		if Geometry2D.triangulate_polygon(points).is_empty():
			out.append(name + ": üçgenlenemedi")
		var n := points.size()
		for i in n:
			if points[i].distance_to(points[(i + 1) % n]) < 0.01:
				out.append(name + ": aynı nokta art arda")
				break
		if _self_intersects(points):
			out.append(name + ": çokgen kendini kesiyor")
		var cell: Rect2 = piece["cell"]
		var ratio := absf(_area(points)) / cell.get_area()
		if ratio < 0.75 or ratio > 1.25:
			out.append(name + ": alanı hücreden çok farklı (%.2f)" % ratio)
	return out


static func _self_intersects(points: PackedVector2Array) -> bool:
	var n := points.size()
	for i in n:
		var a1 := points[i]
		var a2 := points[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			if Geometry2D.segment_intersects_segment(a1, a2, points[j], points[(j + 1) % n]) != null:
				return true
	return false


static func _area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total / 2.0
