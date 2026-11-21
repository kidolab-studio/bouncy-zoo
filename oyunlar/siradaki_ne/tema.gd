extends Node2D
# Tema tabanı (PatternTheme): bir bölümün dizisi, boşlukları ve seçenek tepsisi. Beş tema bunu extends eder
# (tema_kolye.gd, tema_bayrak.gd, tema_bahce.gd, tema_tirtil.gd, tema_gecit.gd) ve yalnızca görünüşü
# (_draw_track: dizinin arkasındaki ip / saksı / dal / yol; decorate: baş, direk gibi ek parçalar) ve
# bitiş gösterisini (finish) değiştirir. Bırakma kararı, örüntünün çalınması ve ipucu burada.
#
# Ana sahne şu sırayla çağırır: setup(plan, ...) -> build() -> play_row() -> ... oyun ...
#   -> completed sinyali -> await celebrate() -> await finish() -> await leave() -> queue_free
# Dizi (row) ayrı bir düğümdür: ip ve parçalar onun içinde birlikte hareket eder (kolye boyna takılırken
# küçülür, tırtıl sürünerek gider). Tepsideki parça doğru boşluğa oturunca diziye geçer.

## Bütün boşluklar doldu; ana sahne kutlamayı başlatır
signal completed

const Settings := preload("res://oyunlar/siradaki_ne/ayarlar.gd")
const Generator := preload("res://oyunlar/siradaki_ne/bolum_uretici.gd")
const Piece := preload("res://oyunlar/siradaki_ne/parca.gd")
const Sounds := preload("res://oyunlar/siradaki_ne/sesler.gd")
const Effects := preload("res://oyunlar/siradaki_ne/efektler.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const TEX_SLOT: Texture2D = preload("res://oyunlar/siradaki_ne/gorseller/yuva.svg")
const OUTLINE := Color("3b2f6b")

## Yanlış / boş bırakmada parçanın tepsiye dönme süresi
const RETURN_TIME := 0.45
## Dizinin çalınmasında iki parça arası (saniye)
const PLAY_STEP := 0.32

var plan: Generator.Plan
var sounds: Sounds
var effects: Effects
var drag_input: DragInput

var row: Node2D
var pieces: Array = []          # yuva -> dizideki parça (boşsa null)
var rings: Array = []           # yuva -> boşluk halkası (Sprite2D; boşluk değilse null)
var tray: Array = []            # tepsideki parçalar
var wrong_count: int = 0
var done: bool = false
var playing_row: bool = false

var _time: float = 0.0


func setup(level_plan: Generator.Plan, game_sounds: Sounds, game_effects: Effects, input: DragInput) -> void:
	plan = level_plan
	sounds = game_sounds
	effects = game_effects
	drag_input = input
	drag_input.item_grabbed.connect(_on_grabbed)
	drag_input.item_dropped.connect(_on_dropped)
	drag_input.item_canceled.connect(_on_canceled)


func _exit_tree() -> void:
	if drag_input:
		drag_input.item_grabbed.disconnect(_on_grabbed)
		drag_input.item_dropped.disconnect(_on_dropped)
		drag_input.item_canceled.disconnect(_on_canceled)
		if drag_input.items == tray:       # sonraki bölümün listesine dokunma
			drag_input.items = []


func build() -> void:
	row = Node2D.new()
	add_child(row)
	row.draw.connect(_draw_track)
	decorate()
	for i in plan.sequence.size():
		pieces.append(null)
		rings.append(null)
		if plan.is_gap(i):
			var ring := Sprite2D.new()
			ring.texture = TEX_SLOT
			ring.position = plan.slots[i]
			ring.set_meta("size", plan.cell * 0.92 / TEX_SLOT.get_width())
			row.add_child(ring)
			rings[i] = ring
			_pop_in(ring, 0.1 + i * 0.05)
			ring.create_tween().tween_callback(ring.set_meta.bind("live", true)).set_delay(0.5 + i * 0.05)
		else:
			var piece := _make_piece(plan.sequence[i], plan.slots[i])
			piece.placed = true
			row.add_child(piece)
			pieces[i] = piece
			_pop_in(piece, 0.1 + i * 0.05)
	for k in plan.choices.size():
		var piece := _make_piece(plan.choices[k], plan.trays[k])
		add_child(piece)
		tray.append(piece)
		piece.appear(0.5 + k * 0.08)
	drag_input.items = tray


func _make_piece(symbol: String, at: Vector2) -> Piece:
	var piece := Piece.new()
	piece.setup_piece(symbol, int(plan.notes.get(symbol, 0)), plan.piece, plan.grab, at)
	return piece


func _pop_in(node: Node2D, delay: float) -> void:
	var target: Vector2 = Vector2.ONE * float(node.get_meta("size")) if node.has_meta("size") else node.scale
	node.scale = Vector2.ZERO
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "scale", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	# Boş halkalar hafifçe nabız gibi atar
	for i in rings.size():
		var ring: Sprite2D = rings[i]
		if ring and ring.has_meta("live"):
			ring.scale = Vector2.ONE * float(ring.get_meta("size")) * (1.0 + 0.04 * sin(_time * 3.5 + i))
	if row:
		row.queue_redraw()


# --- Temanın dolduracağı işlevler ---

## Dizinin arkası (row'a çizilir; row.draw_* kullan). Parçalar hareket edince her karede yeniden çizilir.
func _draw_track() -> void:
	pass


## Ek parçalar (tırtılın başı vb.)
func decorate() -> void:
	pass


## Bitiş gösterisi (await edilir)
func finish() -> void:
	await get_tree().create_timer(0.6).timeout


# --- Yardımcılar ---

## Yuvanın şu anki noktası (parça varsa onun yeri; kolye takılırken / tırtıl sürünürken değişir)
func point(i: int) -> Vector2:
	if pieces[i] and (pieces[i] as Node2D).get_parent() == row:
		return (pieces[i] as Node2D).position
	return plan.slots[i]


func points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in plan.sequence.size():
		out.append(point(i))
	return out


## Noktalardan geçen yumuşak eğri (Catmull-Rom)
func smooth(pts: PackedVector2Array, steps: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


## Koyu hatlı kalın çizgi (ip, dal, yol)
func cord(pts: PackedVector2Array, width: float, color: Color, outline: float = 5.0) -> void:
	row.draw_polyline(pts, OUTLINE, width + outline * 2.0, true)
	row.draw_polyline(pts, color, width, true)
	for p in [pts[0], pts[pts.size() - 1]]:
		row.draw_circle(p, width / 2.0 + outline, OUTLINE)
		row.draw_circle(p, width / 2.0, color)


func row_pieces() -> Array:
	return pieces.filter(func(p) -> bool: return p != null)


# --- Örüntüyü çalma ---

## Dizi soldan sağa çalınır: her parça zıplayıp kendi notasını çalar, boşluk sessizce parlar
func play_row(step: float = PLAY_STEP) -> void:
	if playing_row:
		return
	playing_row = true
	for i in plan.sequence.size():
		if not is_inside_tree():
			return
		var piece: Piece = pieces[i]
		if piece:
			piece.bounce()
			sounds.note(piece.note)
		elif rings[i]:
			_flash(rings[i])
		await get_tree().create_timer(step).timeout
	playing_row = false


func _flash(ring: Sprite2D) -> void:
	ring.set_meta("live", true)
	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate", Color(1.35, 1.3, 1.0), 0.12)
	tween.tween_property(ring, "modulate", Color.WHITE, 0.35)


# --- Dokunma ---

func _on_grabbed(_item: Piece) -> void:
	sounds.play("pop", randf_range(0.95, 1.1))


func _on_canceled(item: Piece) -> void:
	item.return_home(RETURN_TIME, false)


func _on_dropped(item: Piece, at: Vector2) -> void:
	var g := gap_at(at, item.symbol)
	if g < 0:
		item.return_home(RETURN_TIME, false)
	elif pieces[g] == null and plan.sequence[g] == item.symbol:
		_place(item, g)
	else:
		_refuse(item, g)


## Bırakılan noktanın (toleranslı) içinde olduğu boşluk: önce bu parçanın uyduğu boş yuva, sonra en yakın boş yuva
func gap_at(at: Vector2, symbol: String) -> int:
	var best := -1
	var best_distance := INF
	for g in plan.gaps:
		if pieces[g] != null or not drag_input.drop_area(plan.slot_rect(g)).has_point(at):
			continue
		var distance := at.distance_to(plan.slots[g])
		if plan.sequence[g] == symbol:
			distance -= 10000.0
		if distance < best_distance:
			best_distance = distance
			best = g
	return best


func _place(item: Piece, g: int) -> void:
	pieces[g] = item
	tray.erase(item)
	item.reparent(row)
	item.z_index = 2
	item.seat(plan.slots[g], 0.22, _on_landed.bind(item, g))


func _on_landed(item: Piece, g: int) -> void:
	sounds.note(item.note)
	effects.sparkle(item.global_position, plan.piece * 0.7)
	var ring: Sprite2D = rings[g]
	if ring:
		rings[g] = null
		var fade := ring.create_tween()
		fade.tween_property(ring, "modulate:a", 0.0, 0.2)
		fade.tween_callback(ring.queue_free)
	if not done and plan.gaps.all(func(i: int) -> bool: return pieces[i] != null):
		done = true
		completed.emit()


# Yanlış boşluk: yumuşak ses, parça sallanıp tepsiye döner, halka kıpırdar; birkaç yanlıştan sonra örüntü yeniden çalar
func _refuse(item: Piece, g: int) -> void:
	sounds.play("geri")
	item.bounce_back(RETURN_TIME)
	var ring: Sprite2D = rings[g]
	if ring:
		var tween := ring.create_tween()
		for angle in [0.18, -0.15, 0.1, 0.0]:
			tween.tween_property(ring, "rotation", angle, 0.07)
	wrong_count += 1
	if wrong_count % Settings.REPLAY_AFTER == 0:
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree() and not done:
			play_row()


## İpucu: ilk boş yuva ve ona uyan tepsideki parça ([parça, yuvanın noktası] ya da [])
func hint_move() -> Array:
	for g in plan.gaps:
		if pieces[g] != null:
			continue
		for piece in tray:
			if piece.symbol == plan.sequence[g] and piece.can_grab() and not piece.dragging:
				return [piece, plan.slots[g]]
	return []


# --- Bölüm sonu ---

## Bütün boşluklar doldu: artakalan seçenekler kaybolur, dizi baştan sona çalar
func celebrate() -> void:
	for piece in tray:
		piece.disappear(randf() * 0.15)
	tray.clear()
	await get_tree().create_timer(0.3).timeout
	await play_row(0.22)
	await get_tree().create_timer(0.2).timeout


## Her şey küçülerek / solarak kaybolur (await edilir)
func leave() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
