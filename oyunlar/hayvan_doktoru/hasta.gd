extends Node2D
# Muayene masasındaki hasta (Patient; Hayvan Banyosu'ndaki hayvan.gd'nin uyarlaması): düğümün merkezi ayakların
# masaya değdiği nokta; parçalar gövde, boyundan dönen kafa ve kafanın üstünde kodla çizilen yüz.
# Tedavi noktaları (tedavi_noktasi.gd) gövdenin ya da kafanın tuvaline eklenir, onlarla birlikte hareket eder;
# yerleri region_points'ten seçilir (kafa yerleri hayvan verisindeki yüz, burun ve kulak yerlerinden).
# Tepkiler: hastayken üzgün ve yorgun gözlü, gözleri parmağı izler; pamukla silinirken gözlerini sıkar (wince),
# merhem sürülünce rahatlar (relief), stetoskopta göğsüne bakar (listen), kaşık / fırça yaklaşınca ağzını açar
# (open_mouth), şurubu yutunca yüzünü buruşturur (swallow), nezlede hapşırır (sneeze), ateşte titrer (shivering);
# iyileşince mutlu, zıplar ve keyifle sallanır.

const Face := preload("res://oyunlar/hayvan_doktoru/hasta_yuzu.gd")
const Spot := preload("res://oyunlar/hayvan_doktoru/tedavi_noktasi.gd")

const CANVAS := 256.0
const FEET := Vector2(128, 246)       # tuvalde ayakların yere değdiği nokta
const NECK := Vector2(128, 192)       # kafanın döndüğü nokta
const CENTER := Vector2(128, 150)     # dokunma alanının merkezi
## Kafadaki yerler (nokta kafa tuvaline eklenir, kafayla döner, yüzün üstünde çizilir)
const HEAD_REGIONS: Array[String] = ["alin", "agiz", "disler", "burun", "yanak", "kulak", "goz"]

var data: ClinicAnimalData
var size: float = 240.0               # 256'lık tuvalin ekrandaki boyu (kurulurken)
var cured: bool = false               # iyileşti: mutlu, keyifle sallanır
var spots: Array[Spot] = []

var _rig: Node2D
var _body: Node2D
var _head: Node2D
var _body_canvas: Node2D              # tuval birimiyle çizen katmanlar (noktalar buraya eklenir)
var _head_canvas: Node2D
var _face: Face
var _time: float = 0.0
var _watching: bool = false
var _watch_point: Vector2
var _next_blink: float = 0.0
var _wince_until: float = 0.0         # pamukla siliniyor: gözler sıkılı
var _relief_until: float = 0.0        # merhem: mutlu kapalı gözler
var _listen_until: float = 0.0        # stetoskop: göğsüne bakar, ağzı küçük "o"
var _mouth_until: float = 0.0         # kaşık / fırça yakında: ağzı kocaman açık
var _yuck_until: float = 0.0          # şurup yuttu: buruşuk yüz, dil dışarıda
var _sneeze_until: float = 0.0

## Ateşli: hafifçe titrer, yanakları kızarık
var shivering: bool = false

# Tween ile değişen canlandırma değerleri (_process bunları parçalara uygular)
var hop_y: float = 0.0
var slide_x: float = 0.0
var dance_rot: float = 0.0
var sneeze_rot: float = 0.0
var blink_amount: float = 0.0

var _move_tween: Tween


func setup(animal: ClinicAnimalData, animal_size: float) -> void:
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


# --- Tedavi noktaları ---

## Yerin aday noktaları (tuval biriminde; kafa yerlerinde kafa tuvali, diğerlerinde gövde tuvali)
func region_points(region: String) -> Array[Vector2]:
	var d := data
	match region:
		"gogus":
			return [Vector2(128, 213)]
		"bacak":
			return [Vector2(98, 224), Vector2(158, 224)]
		"pati":
			return [Vector2(102, 236), Vector2(154, 236)]
		"alin":
			return [Vector2(128, d.eye_y - 38.0)]
		"agiz", "disler":
			return [Vector2(128, d.mouth_y + 4.0)]
		"burun":
			return [d.nose]
		"yanak":
			return [Vector2(128 - d.cheek_dx, d.cheek_y), Vector2(128 + d.cheek_dx, d.cheek_y)]
		"kulak":
			return [d.ear, Vector2(CANVAS - d.ear.x, d.ear.y)]
		"goz":
			return [Vector2(128 - d.eye_dx, d.eye_y), Vector2(128 + d.eye_dx, d.eye_y)]
	return []


## Yerde bir nokta açar: aday yerler karışık sırayla denenir, önceki noktalardan uzak ilk yer seçilir (gövde yerlerinde
## görselin opak olduğu yer). "deri": gövdede ve kafada (yüzün dışında) rastgele yer.
func add_spot(look: String, steps: Array[String], region: String, radius: float, options: Dictionary = {}) -> Spot:
	var on_head := region in HEAD_REGIONS
	var point: Vector2
	if region == "deri":
		var found := _skin_point(radius)
		point = found[0]
		on_head = found[1]
	else:
		var image := data.body_texture.get_image()
		var candidates := region_points(region)
		candidates.shuffle()
		point = candidates[0]
		for c in candidates:
			if _far_from_spots(c, radius * 2.0, on_head) and (on_head or _solid(image, c, radius * 0.5)):
				point = c
				break
	var spot := Spot.new()
	spot.position = point
	(_head_canvas if on_head else _body_canvas).add_child(spot)
	var all_options := options.duplicate()
	all_options["skin"] = data.skin_color
	spot.setup(look, steps, radius, all_options)
	spot.set_meta("on_head", on_head)
	spots.append(spot)
	return spot


## Bütün noktaları siler (tedavi yarıda kalıp hasta banka dönünce noktalar baştan açılır)
func clear_spots() -> void:
	for spot in spots:
		spot.queue_free()
	spots.clear()


func _far_from_spots(p: Vector2, gap: float, on_head: bool) -> bool:
	for other in spots:
		if bool(other.get_meta("on_head")) == on_head and other.position.distance_to(p) < gap:
			return false
	return true


# Gövde ya da kafa görselinin opak olduğu, yüzün dışında, diğer noktalardan uzak rastgele bir yer: [nokta, kafada mı].
# Yer bulunamazsa kurallar gevşer (Hayvan Banyosu'ndaki leke yerleşimi gibi).
func _skin_point(radius: float) -> Array:
	var body_image := data.body_texture.get_image()
	var head_image := data.head_texture.get_image()
	var gap := radius * 2.2
	var inside := radius * 0.6
	var want_head := spots.filter(func(s: Spot) -> bool: return s.look == "benek").size() % 2 == 1
	for attempt in 3000:
		if attempt == 1000 or attempt == 2000:
			gap *= 0.75
			inside *= 0.5
		var p := Vector2(randf_range(radius, CANVAS - radius), randf_range(radius, 232.0))
		var head := _solid(head_image, p, inside)
		if not head and not _solid(body_image, p, inside):
			continue
		# Kafada yalnızca yüzün dışında ve kulakların altında (benek kulak ucunda kafadan taşmış gibi durmasın)
		if head and (_on_face(p) or p.y < data.eye_y - 45.0 or absf(p.x - 128.0) > 62.0):
			continue
		if attempt < 500 and head != want_head:
			continue
		if _far_from_spots(p, gap, head):
			return [p, head]
	return [Vector2(128, 210), false]


# Gözler, ağız ve yanakların bulunduğu elips (noktalar yüzü kapatmasın)
func _on_face(p: Vector2) -> bool:
	var center := Vector2(128.0, (data.eye_y + data.mouth_y) / 2.0)
	var size := Vector2(data.cheek_dx + 20.0, (data.mouth_y - data.eye_y) / 2.0 + data.eye_size.y + 22.0)
	return ((p - center) / size).length() < 1.0


# Nokta ve çevresi (radius uzaklıktaki 4 nokta) görselin opak yerinde mi
func _solid(image: Image, p: Vector2, radius: float) -> bool:
	for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		var q: Vector2 = (p + offset) * image.get_width() / CANVAS
		var x := clampi(int(q.x), 0, image.get_width() - 1)
		var y := clampi(int(q.y), 0, image.get_height() - 1)
		if image.get_pixel(x, y).a < 0.9:
			return false
	return true


# --- Sorgular ---

# Nokta hastanın üstünde mi (gövde ve başı kapsayan elips)
func contains(point: Vector2) -> bool:
	var center := to_global((CENTER - FEET) * size / CANVAS)
	var radius := Vector2(0.42, 0.5) * size * global_scale
	var d := point - center
	return pow(d.x / radius.x, 2.0) + pow(d.y / radius.y, 2.0) <= 1.0


func head_top_global() -> Vector2:
	return _face.to_global(Vector2(128.0, 70.0))


func center_global() -> Vector2:
	return _rig.to_global((CENTER - FEET) * size / CANVAS)


# --- Tepkiler ---

func watch(point: Vector2) -> void:
	_watching = true
	_watch_point = point


func unwatch() -> void:
	_watching = false


func wince() -> void:
	_wince_until = _time + 0.3


func relief() -> void:
	_relief_until = _time + 0.4


func listen() -> void:
	_listen_until = _time + 0.3


## Kaşık ya da diş fırçası yaklaşıyor: ağzını kocaman açar
func open_mouth() -> void:
	_mouth_until = _time + 0.25


## Şurubu yuttu: yanakları şişer, yüzünü buruşturur (dil dışarıda), sonra güler
func swallow() -> void:
	_mouth_until = 0.0
	_yuck_until = _time + 1.0
	var tween := create_tween()
	tween.tween_property(_face, "cheek_puff", 1.0, 0.12)
	tween.tween_property(_face, "cheek_puff", 0.0, 0.3)


## Hapşırır: başı geriye gider, sonra öne fırlar; gözler kapalı, ağız açık
func sneeze() -> void:
	_sneeze_until = _time + 0.75
	var tween := create_tween()
	tween.tween_property(self, "sneeze_rot", -0.14, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "sneeze_rot", 0.2, 0.08)
	tween.tween_property(self, "sneeze_rot", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


## Burnun ekrandaki yeri (hapşırık efekti için)
func nose_global() -> Vector2:
	return _face.to_global(data.nose)


## İyileşti: mutlu yüz, keyifle sallanır
func cure() -> void:
	cured = true


# Kutlama dansı: sırayla zıplayıp sağa sola sallanır
func dance(delay: float, times: int) -> void:
	_relief_until = _time + delay + times * 0.55
	_hop(delay, times, 0.14, true)


func hop() -> void:
	_hop(0.0, 1, 0.1)


func _hop(delay: float, times: int, height: float = 0.12, swing: bool = false) -> void:
	if _move_tween:
		_move_tween.kill()
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


# Soldan masaya zıplar (kapıdan gelir)
func appear(delay: float) -> void:
	slide_x = -size * 1.3
	hop_y = 0.0
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(self, "slide_x", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(t: float) -> void: hop_y = -size * 0.55 * sin(t * PI), 0.0, 1.0, 0.55)


# Sağa doğru zıplayarak gider
func leave(delay: float) -> void:
	if _move_tween:
		_move_tween.kill()
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "slide_x", size * 1.4, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_method(func(t: float) -> void: hop_y = -size * 0.4 * sin(t * PI), 0.0, 1.0, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.2)
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
	# Hastayken: üzgün kaşlar, asık ağız, yorgun (yarı kapalı) gözler
	var sad_t := 0.0 if cured else 0.7
	var smile_t := 1.0 if cured else 0.1
	var open_t := 0.0
	var happy_t := 1.0 if cured and fmod(_time, 3.2) < 1.1 else 0.0
	var blush_t := 1.0 if cured else 0.1
	var blink_t := maxf(blink_amount, 0.0 if cured else 0.3)
	var tongue_t := 0.0
	if shivering and not cured:
		blush_t = 1.0
	if _time < _listen_until:
		sad_t = 0.2
		open_t = 0.15
		blink_t = 0.0
	if _time < _wince_until:
		blink_t = 1.0
		sad_t = 0.6
		open_t = 0.1
	if _time < _mouth_until:
		sad_t = 0.0
		open_t = 0.9
		blink_t = 0.0
	if _time < _yuck_until:
		blink_t = 1.0
		sad_t = 0.5
		smile_t = 0.0
		tongue_t = 1.0
	if _time < _sneeze_until:
		var before := _sneeze_until - _time > 0.4
		blink_t = 1.0
		open_t = 0.5 if before else 0.8
	if _time < _relief_until:
		sad_t = 0.0
		happy_t = 1.0
		smile_t = 1.0
		open_t = 0.3
		blush_t = 1.0
	_face.sad = lerpf(_face.sad, sad_t, k)
	_face.smile = lerpf(_face.smile, smile_t, k)
	_face.mouth_open = lerpf(_face.mouth_open, open_t, k)
	_face.tongue = lerpf(_face.tongue, tongue_t, k)
	_face.happy_eyes = happy_t
	_face.blush = lerpf(_face.blush, blush_t, k)
	_face.blink = lerpf(_face.blink, blink_t, 1.0 - exp(-25.0 * delta))
	_face.look = _face.look.lerp(_look_target(), 1.0 - exp(-8.0 * delta))
	_face.queue_redraw()

	# Beden: nefes; ateşliyken titreme; iyileşince keyifle sallanma
	var breathe := 1.0 + 0.012 * sin(_time * 2.4)
	_body.scale = Vector2(1.0, breathe)
	var sway := sin(_time * 2.2) * 0.05 if cured else 0.0
	var shiver := sin(_time * 42.0) * 0.018 if shivering and not cured else 0.0
	_rig.rotation = sway + dance_rot + shiver
	_rig.position = Vector2(slide_x, hop_y)
	_head.rotation = lerpf(_head.rotation, sneeze_rot, 1.0 - exp(-30.0 * delta))


# Gözlerin bakacağı yön: stetoskopta göğsüne, parmak varsa ona, yoksa yavaşça etrafa
func _look_target() -> Vector2:
	if _time < _listen_until:
		return Vector2(0.0, 1.0)
	if _watching:
		var eyes := _face.to_global(Vector2(128.0, data.eye_y))
		return ((_watch_point - eyes) / (size * 0.9 * global_scale.x)).limit_length(1.0)
	return Vector2(sin(_time * 0.45) * 0.45, 0.2 + sin(_time * 0.31) * 0.2)
