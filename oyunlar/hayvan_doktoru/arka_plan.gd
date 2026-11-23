extends Node2D
# Klinik odası: çizgili nane yeşili duvar (altında açık lambri), solda bulutlu pencere, sağda kalp posteri,
# kareli zemin; tedavide ortada muayene masası (yumuşak minder, altında çekmeceli dolap), bekleme odasında
# (waiting) uzun bekleme bankı (iyileşenlerin boş yerinde kalp). Her şey ekranın tamamını kaplar; layout() ve
# set_bench() ekran boyutuna, masanın ve bankın yerine göre yerleştirir. Görsel dosya yok, hepsi kodla çizilir.
# (Kızıl haç işareti korumalı bir amblem olduğu için kullanılmaz; klinik kalple anlatılır.)

const OUT := Color("3b2f6b")
const WALL := Color("dcf3ec")
const WALL_STRIPE := Color("e8f8f2")
const PANEL := Color("bfe6db")
const PANEL_DARK := Color("a6d8cb")
const FLOOR := Color("dde4f6")
const FLOOR_LIGHT := Color("eef2fb")
const SKY := Color("9fd8ff")
const SKY_LIGHT := Color("d4efff")
const CUSHION := Color("7fd0c5")
const CUSHION_LIGHT := Color("b4e9e1")
const PAPER := Color("ffffff")
const CABINET := Color("fdfbff")
const CABINET_DARK := Color("d9d3ee")
const HEART := Color("ff7b9c")
const POSTER := Color("fff6d9")
const BENCH := Color("c9bdf5")
const BENCH_SEAT := Color("8f7ae6")
const BENCH_LEG := Color("6d5bc4")

var screen := Vector2(1280, 720)
var table_center := Vector2(560, 540)  # minderin üst ortası (hastanın ayakları burada)
var table_width: float = 420.0
var floor_y: float = 580.0
## Bekleme odası: masa yerine bank çizilir
var waiting: bool = false
var bench_top := Vector2(640, 540)    # oturağın üst ortası (hastaların ayakları burada)
var bench_width: float = 900.0
var seat_xs: Array[float] = []
## İyileşenlerin boş yerleri (kalp çizilir)
var seats_done: Array[bool] = []
var _window: Rect2
var _poster: Rect2


## table_top: minderin üst ortası, width: masanın genişliği, area: tasarım alanı (pencere ve poster bunun içinde)
func layout(screen_size: Vector2, table_top: Vector2, width: float, area: Rect2) -> void:
	screen = screen_size
	table_center = table_top
	table_width = width
	floor_y = table_top.y + width * 0.1
	var w := clampf(area.size.y * 0.3, 150.0, 230.0)
	_window = Rect2(table_top.x - width * 0.5 - w * 0.95, area.position.y + area.size.y * 0.16, w, w * 0.85)
	_window.position.x = maxf(_window.position.x, area.position.x + 40.0)
	var p := w * 0.6
	_poster = Rect2(table_top.x + width * 0.42, area.position.y + area.size.y * 0.2, p, p * 1.2)
	queue_redraw()


## top: oturağın üst ortası, width: bankın genişliği, xs: oturakların ortaları
func set_bench(top: Vector2, width: float, xs: Array[float]) -> void:
	bench_top = top
	bench_width = width
	seat_xs = xs
	queue_redraw()


func set_waiting(on: bool, done: Array[bool] = []) -> void:
	waiting = on
	seats_done = done
	queue_redraw()


func _draw() -> void:
	_draw_wall()
	_draw_window()
	_draw_poster()
	_draw_floor()
	if waiting:
		_draw_bench()
	else:
		_draw_table()


func _draw_wall() -> void:
	draw_rect(Rect2(0, 0, screen.x, floor_y), WALL)
	# Dikey yumuşak çizgiler ekranın ortasından hizalanır (her ekran oranında simetrik)
	var stripe := 64.0
	var x := fmod(screen.x / 2.0, stripe * 2.0) - stripe * 2.0
	while x < screen.x:
		draw_rect(Rect2(x, 0, stripe, floor_y), WALL_STRIPE)
		x += stripe * 2.0
	# Lambri: duvarın alt kısmı, üstünde beyaz pervaz
	var rail := floor_y - table_width * 0.36
	draw_rect(Rect2(0, rail, screen.x, floor_y - rail), PANEL)
	var px := fmod(screen.x / 2.0, 120.0) - 120.0
	while px < screen.x:
		draw_line(Vector2(px, rail + 16.0), Vector2(px, floor_y), PANEL_DARK, 4.0)
		px += 120.0
	draw_rect(Rect2(0, rail - 7.0, screen.x, 14.0), Color.WHITE)
	draw_line(Vector2(0, rail + 7.0), Vector2(screen.x, rail + 7.0), Color(OUT, 0.15), 3.0)


func _draw_window() -> void:
	var r := _window
	_rounded(r.grow(12.0), Color.WHITE, 14, OUT, 6)
	draw_rect(r, SKY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), SKY_LIGHT.lerp(SKY, 0.4))
	# Bulutlar ve güneş
	draw_circle(r.position + Vector2(r.size.x * 0.78, r.size.y * 0.24), r.size.x * 0.1, Color("ffe066"))
	for c: Vector3 in [Vector3(0.3, 0.55, 1.0), Vector3(0.68, 0.72, 0.8)]:
		var center := r.position + Vector2(c.x, c.y) * r.size
		var s := r.size.x * 0.08 * c.z
		for o: Vector3 in [Vector3(-1.2, 0.2, 0.8), Vector3(0.0, -0.3, 1.1), Vector3(1.2, 0.2, 0.8)]:
			draw_circle(center + Vector2(o.x, o.y) * s, s * o.z, Color.WHITE)
	# Çerçevenin ortasındaki haç biçimli kayıtlar
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color.WHITE, 10.0)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color.WHITE, 10.0)
	draw_rect(r, OUT, false, 5.0)
	# Pencere eşiği
	_rounded(Rect2(r.position.x - 22.0, r.end.y + 8.0, r.size.x + 44.0, 18.0), Color.WHITE, 8, OUT, 5)


func _draw_poster() -> void:
	var r := _poster
	_rounded(r, POSTER, 12, OUT, 5)
	# Ortada büyük kalp, altında üç küçük nokta (yazısız)
	var c := r.get_center() + Vector2(0.0, -r.size.y * 0.08)
	var s := r.size.x * 0.3
	_heart(c, s)
	for k in 3:
		draw_circle(Vector2(r.position.x + r.size.x * (0.3 + 0.2 * k), r.end.y - r.size.y * 0.14), r.size.x * 0.05, Color(OUT, 0.35))
	# Asma ipi ve çivi
	var nail := Vector2(r.get_center().x, r.position.y - r.size.y * 0.16)
	draw_line(nail, r.position + Vector2(r.size.x * 0.2, 0), OUT, 3.0, true)
	draw_line(nail, r.position + Vector2(r.size.x * 0.8, 0), OUT, 3.0, true)
	draw_circle(nail, 6.0, OUT)


func _draw_floor() -> void:
	draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), FLOOR)
	var tile := 70.0
	var x0 := fmod(screen.x / 2.0, tile * 2.0) - tile * 2.0
	var row := 0
	var y := floor_y + 12.0
	while y < screen.y:
		var x := x0 + (tile if row % 2 == 1 else 0.0)
		while x < screen.x:
			draw_rect(Rect2(x, y, tile, tile * 0.5), FLOOR_LIGHT)
			x += tile * 2.0
		y += tile * 0.5
		row += 1
	# Süpürgelik
	draw_rect(Rect2(0, floor_y - 2.0, screen.x, 14.0), Color.WHITE)
	draw_line(Vector2(0, floor_y + 12.0), Vector2(screen.x, floor_y + 12.0), Color(OUT, 0.2), 3.0)


func _draw_table() -> void:
	var w := table_width
	var top := table_center.y
	var cx := table_center.x
	var cushion_h := w * 0.09
	var bottom := minf(top + w * 0.42, screen.y - 6.0)
	# Gölge
	_ellipse(Vector2(cx, bottom), Vector2(w * 0.5, w * 0.045), Color(OUT, 0.15))
	# Dolap: iki çekmece, yuvarlak tutamaklar, altta ayaklar
	var cabinet := Rect2(cx - w * 0.42, top + cushion_h - 6.0, w * 0.84, bottom - top - cushion_h - 6.0)
	for side in [-1.0, 1.0]:
		_rounded(Rect2(cx + side * w * 0.34 - w * 0.04, bottom - w * 0.05, w * 0.08, w * 0.05), CABINET_DARK, 6, OUT, 5)
	_rounded(cabinet, CABINET, 12, OUT, 6)
	var drawer_h := (cabinet.size.y - 30.0) / 2.0
	for k in 2:
		var d := Rect2(cabinet.position.x + 16.0, cabinet.position.y + 12.0 + k * (drawer_h + 6.0), cabinet.size.x - 32.0, drawer_h)
		if d.size.y > 12.0:
			_rounded(d, Color.WHITE, 8, CABINET_DARK, 4)
			_rounded(Rect2(d.get_center() - Vector2(w * 0.07, 6.0), Vector2(w * 0.14, 12.0)), CABINET_DARK, 6, OUT, 3)
	# Minder ve üstünde kağıt örtü
	var cushion := Rect2(cx - w / 2.0, top - 4.0, w, cushion_h)
	_rounded(cushion, CUSHION, int(cushion_h / 2.0), OUT, 6)
	draw_rect(Rect2(cushion.position.x + 14.0, cushion.position.y + 5.0, w - 28.0, cushion_h * 0.28), CUSHION_LIGHT)
	_rounded(Rect2(cx - w * 0.28, top - 7.0, w * 0.56, cushion_h * 0.55), PAPER, 6, Color(OUT, 0.35), 3)


# Bekleme bankı: arkalık, minderli oturak, ayaklar; iyileşen hastanın boş yerinde kalp
func _draw_bench() -> void:
	var w := bench_width
	var top := bench_top.y
	var cx := bench_top.x
	var bottom := minf(top + w * 0.17, screen.y - 6.0)
	_ellipse(Vector2(cx, bottom), Vector2(w * 0.52, w * 0.025), Color(OUT, 0.15))
	for k in 4:
		var x := cx - w * 0.44 + k * w * 0.88 / 3.0
		_rounded(Rect2(x - 9.0, top + 20.0, 18.0, bottom - top - 20.0), BENCH_LEG, 6, OUT, 5)
	var back_h := w * 0.13
	_rounded(Rect2(cx - w / 2.0, top - back_h, w, back_h + 10.0), BENCH, 18, OUT, 6)
	for x in seat_xs:
		_rounded(Rect2(x - w * 0.12, top - back_h + 14.0, w * 0.24, back_h - 26.0), Color(1, 1, 1, 0.35), 12, Color(0, 0, 0, 0), 0)
	_rounded(Rect2(cx - w / 2.0 - 12.0, top - 6.0, w + 24.0, 34.0), BENCH_SEAT, 16, OUT, 6)
	draw_rect(Rect2(cx - w / 2.0 + 6.0, top, w - 12.0, 8.0), Color(1, 1, 1, 0.3))
	for i in mini(seat_xs.size(), seats_done.size()):
		if seats_done[i]:
			_heart(Vector2(seat_xs[i], top - w * 0.05), w * 0.035)


func _heart(c: Vector2, s: float) -> void:
	var heart := PackedVector2Array()
	for k in 40:
		var t := TAU * k / 40.0
		heart.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * s / 16.0)
	draw_colored_polygon(heart, HEART)
	heart.append(heart[0])
	draw_polyline(heart, OUT, 4.0, true)
	draw_circle(c + Vector2(-s * 0.4, -s * 0.35), s * 0.15, Color(1, 1, 1, 0.8))


func _rounded(rect: Rect2, color: Color, radius: int, border: Color, border_width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
