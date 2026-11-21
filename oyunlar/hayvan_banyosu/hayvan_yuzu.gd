extends Node2D
# Hayvanın yüzü (AnimalFace; Hayvanları Besle'deki hayvan_yuzu.gd'nin kopyası): gözler, kaşlar, yanaklar,
# ağız/gaga ve dil kodla çizilir; böylece gözler parmağı izleyebilir, ağız açılıp kapanabilir. Kafa SVG'siyle aynı 256'lık tuvalde
# çizer (kafa düğümü bu tuvali ölçekler). Yer bilgileri BathAnimalData'dan gelir. Stil Müzik Kutusu
# hayvanlarıyla aynı: koyu mor hat, koyu gözler ve beyaz parıltılar, pembe yanaklar.
# Değerleri hayvan.gd her karede yumuşakça değiştirir; burada sadece çizilir.

const OUT := Color("3b2f6b")
const EYE := Color("1e1636")
const EYE_LIGHT := Color("3f3368")
const MOUTH := Color("8a2a4a")
const TONGUE := Color("ff8fb0")
const BLUSH := Color(1.0, 0.5, 0.64)
const BEAK := Color("ff9a3d")
const BEAK_DARK := Color("e0782a")

var data: BathAnimalData

## Bakış yönü (-1..1): gözler bu yöne kayar
var look: Vector2 = Vector2.ZERO
## Göz büyüklüğü (1: normal, heyecanda büyür)
var eye_scale: float = 1.0
## 0: açık, 1: kapalı (göz kırpma)
var blink: float = 0.0
## 0..1: mutlu kapalı gözler (^ ^)
var happy_eyes: float = 0.0
## 0..1: üzgün kaşlar ve asık ağız (aç)
var sad: float = 0.0
## 0..1: ağız açıklığı
var mouth_open: float = 0.0
## 0..1: gülümseme
var smile: float = 0.3
## 0..1: dil dışarıda (ağız yalama)
var tongue: float = 0.0
## 0..1: yanakların şişmesi (çiğneme)
var cheek_puff: float = 0.0
## 0..1: ek kızarıklık (mutlu)
var blush: float = 0.0


func setup(animal_data: BathAnimalData) -> void:
	data = animal_data
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	_draw_cheeks()
	if data.beak:
		_draw_beak()
	else:
		_draw_mouth()
	for side in [-1.0, 1.0]:
		_draw_eye(Vector2(128.0 + side * data.eye_dx, data.eye_y), side)


# --- Gözler ---

func _draw_eye(center: Vector2, side: float) -> void:
	var r := data.eye_size * eye_scale
	if data.eye_white and happy_eyes <= 0.5 and blink < 0.8:
		_ellipse(center + look * r * 0.25, r * 1.45, Color.WHITE)
	if happy_eyes > 0.5:
		# Mutlu, kapalı göz: yukarı kıvrık yay
		var points := PackedVector2Array()
		for k in 9:
			var a := PI + PI * k / 8.0
			points.append(center + Vector2(cos(a) * r.x * 0.95, sin(a) * r.y * 0.55 + r.y * 0.15))
		draw_polyline(points, Color.WHITE if data.eye_white else OUT, 5.5, true)
	else:
		var open := clampf(1.0 - blink, 0.0, 1.0)
		if open < 0.2:
			draw_line(center + Vector2(-r.x, 2), center + Vector2(r.x, 2), Color.WHITE if data.eye_white else OUT, 5.0, true)
		else:
			var c := center + look * Vector2(r.x * 0.35, r.y * 0.28)
			var er := Vector2(r.x, r.y * open)
			_ellipse(c, er, EYE)
			_ellipse(c + Vector2(-0.1, -0.12) * er, er * 0.72, EYE_LIGHT)
			_ellipse(c + Vector2(-0.35 * er.x, -0.45 * er.y), Vector2(0.42 * er.x, 0.4 * er.y), Color.WHITE)
			draw_circle(c + Vector2(0.35 * er.x, 0.4 * er.y), 0.2 * er.x, Color(1, 1, 1, 0.85))
	# Üzgün kaşlar: iç uçları yukarıda
	if sad > 0.05:
		var inner := center + Vector2(-side * r.x * 0.9, -r.y * 1.5 - 6.0 * sad)
		var outer := center + Vector2(side * r.x * 0.9, -r.y * 1.25)
		draw_line(inner, outer, Color(OUT, clampf(sad * 1.5, 0.0, 1.0)), 5.0, true)


# --- Yanaklar ---

func _draw_cheeks() -> void:
	for side in [-1.0, 1.0]:
		var c := Vector2(128.0 + side * data.cheek_dx, data.cheek_y)
		if cheek_puff > 0.03:
			# Çiğnerken yanaklar dışa doğru şişer
			var puff := Vector2(128.0 + side * (data.cheek_dx + 10.0 * cheek_puff), data.cheek_y + 4.0)
			var pr := Vector2(20.0, 17.0) * (0.6 + 0.5 * cheek_puff)
			_ellipse(puff, pr + Vector2(3.5, 3.5), OUT)
			_ellipse(puff, pr, data.skin_color)
		var alpha := 0.45 + 0.35 * blush
		_ellipse(c, Vector2(19, 11), Color(BLUSH, alpha * 0.45))
		_ellipse(c, Vector2(13, 7.5), Color(BLUSH, alpha * 0.7))


# --- Ağız ---

func _draw_mouth() -> void:
	var x := 128.0
	var y := data.mouth_y
	var w := data.mouth_width
	if mouth_open > 0.06:
		var half := w * (1.0 + 0.5 * mouth_open)
		var depth := 8.0 + 26.0 * mouth_open
		var points := PackedVector2Array()
		# Üst kenar: hafif yukarı kıvrık; alt kenar: yarım elips
		for k in 9:
			var t := k / 8.0
			points.append(Vector2(x - half + 2.0 * half * t, y - 3.0 * sin(PI * t)))
		for k in range(1, 12):
			var a := PI * k / 12.0
			points.append(Vector2(x + cos(a) * half, y + sin(a) * depth))
		draw_colored_polygon(points, MOUTH)
		# Dil: ağzın alt kısmında
		var tongue_points := PackedVector2Array()
		for k in 13:
			var a := PI * k / 12.0
			tongue_points.append(Vector2(x + cos(a) * half * 0.62, y + depth * 0.62 + sin(a) * depth * 0.3))
		draw_colored_polygon(tongue_points, TONGUE)
		points.append(points[0])
		draw_polyline(points, OUT, 5.0, true)
		if data.teeth:
			_teeth(x, y + 1.0)
		return
	var line := PackedVector2Array()
	if sad > 0.5 and smile < 0.4:
		# Asık ağız: aşağı bakan yay
		for k in 9:
			var t := k / 8.0
			line.append(Vector2(x - w + 2.0 * w * t, y + 5.0 - 7.0 * sin(PI * t)))
	else:
		# "w" gülümseme; gülümseme arttıkça derinleşir
		var d := 4.0 + 7.0 * smile
		for k in 17:
			var t := k / 16.0
			line.append(Vector2(x - w + 2.0 * w * t, y + d * absf(sin(TAU * t))))
	if data.teeth:
		_teeth(x, y + 2.0)
	draw_polyline(line, OUT, 5.0, true)
	if tongue > 0.05:
		var tc := Vector2(x + 3.0, y + 6.0 + 4.0 * tongue)
		_ellipse(tc, Vector2(7.5, 7.0 * tongue) + Vector2(2.5, 2.5), OUT)
		_ellipse(tc, Vector2(7.5, 7.0 * tongue), TONGUE)


func _teeth(x: float, y: float) -> void:
	for dx in [-6.0, 0.5]:
		var rect := Rect2(x + dx, y, 5.5, 8.0)
		draw_rect(rect, Color.WHITE)
		draw_rect(rect, OUT, false, 2.5, true)


# Kuşun gagası: üst parça sabit, alt parça ağız açıldıkça aşağı iner
func _draw_beak() -> void:
	var x := 128.0
	var y := data.mouth_y
	var w := data.mouth_width
	var open := 18.0 * mouth_open
	if open > 1.0:
		var inside := PackedVector2Array([Vector2(x - w * 0.8, y + 2), Vector2(x + w * 0.8, y + 2), Vector2(x, y + 14 + open)])
		draw_colored_polygon(inside, MOUTH)
	var lower := PackedVector2Array([Vector2(x - w * 0.85, y + 3 + open * 0.6), Vector2(x + w * 0.85, y + 3 + open * 0.6), Vector2(x, y + 18 + open)])
	_polygon(lower, BEAK_DARK)
	var upper := PackedVector2Array([Vector2(x - w, y + 2), Vector2(x, y - 9), Vector2(x + w, y + 2), Vector2(x, y + 10)])
	_polygon(upper, BEAK)


# --- Yardımcılar ---

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)


func _polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUT, 4.5, true)
