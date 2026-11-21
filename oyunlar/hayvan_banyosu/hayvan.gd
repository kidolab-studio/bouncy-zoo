extends Node2D
# Küvetteki hayvan (BathAnimal). Hayvanları Besle'deki hayvan.gd'nin sadeleştirilmiş kopyası: düğümün merkezi
# ayakların değdiği nokta; parçalar gövde, boyundan dönen kafa ve kafanın üstünde kodla çizilen yüz.
# Lekeler (leke.gd) gövdenin ya da kafanın tuvaline eklenir, onlarla birlikte hareket eder; yerleri
# gövde/kafa görsellerinin opak piksellerinden rastgele seçilir (yüzün ve suyun altının dışında).
# Tepkiler: kirliyken hafif üzgün, sürtülünce gözleri ^ ^ kapanır ve kıkırdar, duşta gözlerini sıkar,
# gözleri parmağı izler; yıkanınca silkinir, zıplar ve keyifle sallanır.

const Face := preload("res://oyunlar/hayvan_banyosu/hayvan_yuzu.gd")
const Spot := preload("res://oyunlar/hayvan_banyosu/leke.gd")
const Settings := preload("res://oyunlar/hayvan_banyosu/ayarlar.gd")

const CANVAS := 256.0
const FEET := Vector2(128, 246)       # tuvalde ayakların yere değdiği nokta
const NECK := Vector2(128, 192)       # kafanın döndüğü nokta
const CENTER := Vector2(128, 150)     # dokunma alanının merkezi

var data: BathAnimalData
var size: float = 240.0               # 256'lık tuvalin ekrandaki boyu (kurulurken)
var clean: bool = false               # yıkandı: mutlu, keyifle sallanır
var spots: Array[Spot] = []

var _rig: Node2D
var _body: Node2D
var _head: Node2D
var _body_canvas: Node2D              # tuval birimiyle çizen katmanlar (lekeler buraya eklenir)
var _head_canvas: Node2D
var _face: Face
var _time: float = 0.0
var _watching: bool = false
var _watch_point: Vector2
var _next_blink: float = 0.0
var _tickle_until: float = 0.0        # sürtülüyor: mutlu gözler
var _squint_until: float = 0.0        # duş suyu yüzünde: gözler sıkılı

# Tween ile değişen canlandırma değerleri (_process bunları parçalara uygular)
var hop_y: float = 0.0
var dance_rot: float = 0.0
var shake_rot: float = 0.0
var blink_amount: float = 0.0

var _move_tween: Tween


func setup(animal: BathAnimalData, animal_size: float) -> void:
	data = animal
	size = animal_size
	_time = randf() * 10.0
	_next_blink = _time + randf_range(1.0, 3.0)
	var s := size / CANVAS
	_rig = Node2D.new()
	add_child(_rig)
	_body = Node2D.new()
	_rig.add_child(_body)
	_body_canvas = _canvas_layer(animal.body_texture, -FEET * s, s)
	_body.add_child(_body_canvas)
	_head = Node2D.new()
	_head.position = (NECK - FEET) * s
	_rig.add_child(_head)
	_head_canvas = _canvas_layer(animal.head_texture, -NECK * s, s)
	_head.add_child(_head_canvas)
	_face = Face.new()
	_face.setup(animal)
	_head_canvas.add_child(_face)


# Tuval birimiyle çizen katman: sol üstü offset'te, 1 birim = s piksel; içinde görsel (2x içe aktarılmış)
func _canvas_layer(texture: Texture2D, offset: Vector2, s: float) -> Node2D:
	var layer := Node2D.new()
	layer.position = offset
	layer.scale = Vector2.ONE * s
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * CANVAS / texture.get_width()
	layer.add_child(sprite)
	return layer


# --- Lekeler ---

# count kadar leke koyar: gövde/kafa görselinin opak olduğu, yüzün ve suyun altının dışındaki yerlere,
# birbirinden uzak. Önce kafa ve gövdeye dönüşümlü dağıtmaya çalışır.
func add_spots(count: int) -> void:
	var body_image := data.body_texture.get_image()
	var head_image := data.head_texture.get_image()
	var r := Settings.SPOT_RADIUS
	var points: Array[Vector2] = []
	var on_head: Array[bool] = []
	var gap := r * Settings.SPOT_GAP
	for attempt in 2000:
		if points.size() >= count:
			break
		if attempt == 1200:
			gap *= 0.75                 # yer bulunamadıysa biraz yakın olabilir
		var p := Vector2(randf_range(r, CANVAS - r), randf_range(r, Settings.WATER_LINE))
		var head := _solid(head_image, p, r * 0.6)
		if not head and not _solid(body_image, p, r * 0.6):
			continue
		if head and _on_face(p):
			continue
		var want_head := points.size() % 2 == 0
		if attempt < 600 and head != want_head:
			continue
		var far := true
		for q in points:
			if q.distance_to(p) < gap:
				far = false
				break
		if far:
			points.append(p)
			on_head.append(head)
	for i in points.size():
		var spot := Spot.new()
		spot.position = points[i]
		# Kafadaki leke yüzün üstünde çizilir; gövdedeki kafanın altında kalır
		(_head_canvas if on_head[i] else _body_canvas).add_child(spot)
		spot.setup(r)
		spots.append(spot)


# Nokta ve çevresi (radius uzaklıktaki 4 nokta) görselin opak yerinde mi
func _solid(image: Image, p: Vector2, radius: float) -> bool:
	for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		var q: Vector2 = (p + offset) * image.get_width() / CANVAS
		var x := clampi(int(q.x), 0, image.get_width() - 1)
		var y := clampi(int(q.y), 0, image.get_height() - 1)
		if image.get_pixel(x, y).a < 0.9:
			return false
	return true


# Gözler, ağız ve yanakların bulunduğu elips (lekeler yüzü kapatmasın)
func _on_face(p: Vector2) -> bool:
	var center := Vector2(128.0, (data.eye_y + data.mouth_y) / 2.0)
	var radius := Vector2(data.cheek_dx + 20.0, (data.mouth_y - data.eye_y) / 2.0 + data.eye_size.y + 22.0)
	var d := (p - center) / radius
	return d.length() < 1.0


# --- Sorgular ---

# Nokta hayvanın üstünde mi (gövde ve başı kapsayan elips)
func contains(point: Vector2) -> bool:
	var center := to_global((CENTER - FEET) * size / CANVAS)
	var radius := Vector2(0.42, 0.5) * size * global_scale
	var d := point - center
	return pow(d.x / radius.x, 2.0) + pow(d.y / radius.y, 2.0) <= 1.0


func head_top_global() -> Vector2:
	return _face.to_global(Vector2(128.0, 70.0))


func center_global() -> Vector2:
	return to_global((CENTER - FEET) * size / CANVAS)


# --- Tepkiler ---

func watch(point: Vector2) -> void:
	_watching = true
	_watch_point = point


func unwatch() -> void:
	_watching = false


# Sürtülüyor: kısa süre mutlu kapalı gözler ve gülümseme
func tickle() -> void:
	_tickle_until = _time + 0.35


# Duş suyu yüzüne geliyor: gözlerini sıkar ama güler
func squint() -> void:
	_squint_until = _time + 0.25


# Yıkandı: hızlıca iki yana silkinir (damlaları oyun saçar), sonra mutlu
func shake_dry() -> void:
	clean = true
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	for k in 8:
		_move_tween.tween_property(self, "shake_rot", 0.22 if k % 2 == 0 else -0.22, 0.07).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, "shake_rot", 0.0, 0.12).set_trans(Tween.TRANS_SINE)


# Bölüm sonu dansı: sırayla zıplayıp sağa sola sallanır
func dance(delay: float, times: int) -> void:
	_tickle_until = _time + delay + times * 0.55
	_hop(delay, times, 0.14, true)


func hop() -> void:
	_hop(0.0, 1, 0.1)


func _hop(delay: float, times: int, height: float = 0.12, swing: bool = false) -> void:
	if _move_tween:
		_move_tween.kill()
	shake_rot = 0.0
	_move_tween = create_tween()
	_move_tween.tween_interval(delay)
	for k in times:
		var side := 1.0 if k % 2 == 0 else -1.0
		_move_tween.tween_property(self, "hop_y", -size * height, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if swing:
			_move_tween.parallel().tween_property(self, "dance_rot", 0.14 * side, 0.2)
		_move_tween.tween_property(self, "hop_y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if swing:
			_move_tween.parallel().tween_property(self, "dance_rot", 0.0, 0.25)
		_move_tween.tween_interval(0.1)


# Yukarıdan küvete atlar (oyun suya değdiği an sıçrama yapar)
func appear(delay: float) -> void:
	hop_y = -size * 1.4
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(self, "hop_y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Yukarı zıplayıp gider
func leave(delay: float) -> void:
	if _move_tween:
		_move_tween.kill()
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "hop_y", -size * 1.6, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tween.tween_callback(queue_free)


# --- Her kare: yüz ve beden ---

func _process(delta: float) -> void:
	_time += delta
	if _time >= _next_blink:
		_next_blink = _time + randf_range(2.0, 5.0)
		var blink := create_tween()
		blink.tween_property(self, "blink_amount", 1.0, 0.07)
		blink.tween_property(self, "blink_amount", 0.0, 0.09)
	var k := 1.0 - exp(-10.0 * delta)
	var sad_t := 0.0 if clean else 0.45
	var smile_t := 1.0 if clean else 0.2
	var open_t := 0.0
	var happy_t := 1.0 if clean and fmod(_time, 3.2) < 1.1 else 0.0
	var blush_t := 1.0 if clean else 0.2
	var blink_t := blink_amount
	if _time < _tickle_until:
		sad_t = 0.0
		happy_t = 1.0
		smile_t = 1.0
		open_t = 0.4
		blush_t = 1.0
	if _time < _squint_until:
		sad_t = 0.0
		blink_t = 1.0
		smile_t = 0.8
		open_t = 0.2
	_face.sad = lerpf(_face.sad, sad_t, k)
	_face.smile = lerpf(_face.smile, smile_t, k)
	_face.mouth_open = lerpf(_face.mouth_open, open_t, k)
	_face.happy_eyes = happy_t
	_face.blush = lerpf(_face.blush, blush_t, k)
	_face.blink = blink_t
	_face.look = _face.look.lerp(_look_target(), 1.0 - exp(-8.0 * delta))
	_face.queue_redraw()

	# Beden: nefes; temizken keyifle sallanma; silkinirken hızlı dönme
	var breathe := 1.0 + 0.012 * sin(_time * 2.4)
	_body.scale = Vector2(1.0, breathe)
	var sway := sin(_time * 2.2) * 0.05 if clean else 0.0
	_rig.rotation = sway + dance_rot + shake_rot
	_rig.position.y = hop_y
	_head.rotation = lerpf(_head.rotation, -shake_rot * 0.8, 1.0 - exp(-30.0 * delta))


# Gözlerin bakacağı yön: parmak varsa ona, yoksa yavaşça etrafa
func _look_target() -> Vector2:
	if _watching:
		var eyes := _face.to_global(Vector2(128.0, data.eye_y))
		return ((_watch_point - eyes) / (size * 0.9 * global_scale.x)).limit_length(1.0)
	return Vector2(sin(_time * 0.45) * 0.45, 0.2 + sin(_time * 0.31) * 0.2)
