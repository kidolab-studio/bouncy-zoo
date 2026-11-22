extends RefCounted
# Labirentin yol ağı ve hayvanın üstündeki hareketi (MazeWalker). Çizim ya da dokunma yok; yalnızca hesap.
#
# Hayvan serbestçe değil, açık hücrelerin merkezlerini birleştiren doğrular (kenarlar) üstünde kayar: duvardan
# geçemez, köşelere takılmaz. Yeri: from hücresinden to hücresine giden kenarda t (0..1); t = 0 ise from'da durur.
#
# Her karede parmağa doğru ilerler (step): hayvanın LOOK_AHEAD hücre çevresinde, yol üstünden gidilebilen bütün
# noktalar içinde parmağa en yakın olanı seçer ve oraya yol üstünden yürür. Böylece parmağı köşenin ötesine
# götürünce döner (komşu koridora girer), ama duvarın arkasındaki koridora uzun bir dolambaçla gitmez: orası
# bakış uzaklığının dışındadır, hayvan duvarın önünde durur (bumped).

const Settings := preload("res://oyunlar/labirent/ayarlar.gd")
const SNAP := 0.0001

var map: PackedStringArray
var origin := Vector2.ZERO        # labirentin sol üst köşesi (ekran)
var cell := 100.0                 # hücre boyu (ekran pikseli)

var from_cell := Vector2i.ZERO
var to_cell := Vector2i.ZERO
var t := 0.0


func setup(level_map: PackedStringArray, rect: Rect2, start: Vector2i) -> void:
	map = level_map
	origin = rect.position
	cell = rect.size.x / Settings.grid_size(map).x
	from_cell = start
	to_cell = start
	t = 0.0


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func position() -> Vector2:
	return center(from_cell).lerp(center(to_cell), t)


## Hayvana en yakın hücre
func nearest_cell() -> Vector2i:
	return to_cell if t > 0.5 else from_cell


## Hayvanı parmağa (target) doğru en fazla budget piksel yürütür.
## Döner: {"moved": yürünen piksel, "entered": [varılan hücreler, sırayla], "bumped": duvarın önünde mi kaldı}
func step(target: Vector2, budget: float) -> Dictionary:
	var moved := 0.0
	var entered: Array[Vector2i] = []
	for i in 12:
		if budget - moved < 0.25:
			break
		var goal := _best_point(target)
		if goal.is_empty():
			break
		var before := position()
		var arrived := _move_toward(goal, (budget - moved) / cell)
		moved += before.distance_to(position())
		if arrived != Vector2i(-1, -1):
			entered.append(arrived)
		elif before.distance_to(position()) < 0.01:
			break
	var bumped := moved < 0.5 and position().distance_to(target) > Settings.BUMP_DISTANCE * cell
	return {"moved": moved, "entered": entered, "bumped": bumped}


# Bakış uzaklığı içinde parmağa en yakın nokta: {"u", "v", "s", "path"}. Nokta u'dan v'ye giden kenarda s (0..1);
# path: hayvanın bulunduğu kenarın ucundan u'ya giden hücreler. Hayvan zaten en yakın noktadaysa {}.
func _best_point(target: Vector2) -> Dictionary:
	var reach := Settings.LOOK_AHEAD * cell
	# Kısa yol (Dijkstra; kenarlar eşit uzun, hücre sayısı az): başlangıç kenarın iki ucu
	var dist := {from_cell: t * cell}
	var prev := {from_cell: from_cell}
	if t > 0.0:
		dist[to_cell] = (1.0 - t) * cell
		prev[to_cell] = to_cell
	var open: Array = dist.keys()
	while not open.is_empty():
		var best_k := 0
		for k in open.size():
			if dist[open[k]] < dist[open[best_k]]:
				best_k = k
		var u: Vector2i = open.pop_at(best_k)
		for n in Settings.neighbors(map, u):
			var d: float = dist[u] + cell
			if d <= reach + cell and (not dist.has(n) or d < dist[n]):
				dist[n] = d
				prev[n] = u
				if not open.has(n):
					open.append(n)
	var here := position()
	var best := {}
	var best_gap := here.distance_to(target) - 0.5
	for u in dist:
		var left: float = reach - dist[u]
		if left < 0.0:
			continue
		for v in Settings.neighbors(map, u) + [u]:
			var s := 0.0
			if v != u:
				# u'dan v'ye, bakış uzaklığının yettiği kadarı
				var limit := minf(1.0, left / cell)
				var a := center(u)
				var ab := center(v) - a
				s = clampf((target - a).dot(ab) / ab.length_squared(), 0.0, limit)
			var point := center(u).lerp(center(v), s)
			var gap := point.distance_to(target)
			if gap < best_gap - 0.01:
				best_gap = gap
				best = {"u": u, "v": v, "s": s, "path": _trace(prev, u)}
	return best


func _trace(prev: Dictionary, u: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [u]
	while prev[out[0]] != out[0]:
		out.push_front(prev[out[0]])
	return out


# Hedef noktaya doğru en fazla steps hücre boyu yürür; bir hücreye varırsa onu döner (yoksa -1, -1)
func _move_toward(goal: Dictionary, steps: float) -> Vector2i:
	var u: Vector2i = goal["u"]
	var v: Vector2i = goal["v"]
	var s: float = goal["s"]
	var path: Array[Vector2i] = goal["path"]
	var target_t: float
	var was_moving := t > 0.0
	if not was_moving:
		# Hücrede duruyor: hedef bu hücreden çıkan kenardaysa o kenara gir, değilse yolun ilk adımına
		if u == from_cell:
			if v == u or s <= 0.0:
				return Vector2i(-1, -1)
			to_cell = v
			target_t = s
		else:
			to_cell = path[1]
			target_t = 1.0
	elif _on_current_edge(u, v):
		target_t = s if u == from_cell else 1.0 - s
		if v == u:
			target_t = 0.0 if u == from_cell else 1.0
	else:
		# Kenarın ortasında, hedef başka yerde: yolun başladığı uca dön
		target_t = 0.0 if path[0] == from_cell else 1.0
	t = move_toward(t, target_t, steps)
	# Kayan nokta toplamı 1'e tam ulaşmayabilir (0,99999...): uca çok yakınsa hücreye varmış say
	if t >= 1.0 - SNAP:
		from_cell = to_cell
		t = 0.0
		return from_cell
	if was_moving and t <= SNAP:
		t = 0.0
		to_cell = from_cell
		return from_cell
	return Vector2i(-1, -1)


func _on_current_edge(u: Vector2i, v: Vector2i) -> bool:
	if v == u:
		return u == from_cell or u == to_cell
	return (u == from_cell and v == to_cell) or (u == to_cell and v == from_cell)
