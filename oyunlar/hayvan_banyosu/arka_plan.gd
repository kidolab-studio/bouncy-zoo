extends Node2D
# Banyo: kareli fayans duvar (ortasında renkli bir şerit), ahşap zemin, küvetin altında yuvarlak paspas ve
# küvetin arka parçası (kenarın arkası ve suyun arka yarısı; hayvan bunun önünde durur). Her şey ekranın
# tamamını kaplar; layout() ekran boyutu ve küvet yerine göre yerleştirir.
# Küvetin ön parçası (kuvet_on.svg) hayvanın önünde ayrı bir düğümdür (hayvan_banyosu.gd).

const TEX_TUB_BACK: Texture2D = preload("res://oyunlar/hayvan_banyosu/gorseller/kuvet_arka.svg")
const TUB_WIDTH := 640.0              # kuvet_on.svg / kuvet_arka.svg tuval genişliği
const TUB_WATER := Vector2(320, 64)   # iki dosyada suyun merkezi (svg_uret.py TUB_WATER)
const TUB_HEIGHT := 280.0

const OUT := Color("3b2f6b")
const TILE := Color("bfeaf0")
const TILE_LIGHT := Color("d9f4f6")
const GROUT := Color("e9fafb")
const BAND := Color("ffb3cf")
const BAND_DARK := Color("f58db5")
const FLOOR := Color("f2c48d")
const FLOOR_DARK := Color("dba66c")
const MAT := Color("a8d8ff")
const MAT_DARK := Color("7fc0f5")

var screen := Vector2(1280, 720)
var floor_y: float = 560.0
var tile: float = 84.0
var _mat_rect: Rect2

var _tub_back: Sprite2D


func _ready() -> void:
	_tub_back = Sprite2D.new()
	_tub_back.texture = TEX_TUB_BACK
	_tub_back.centered = false
	add_child(_tub_back)


# center_x: küvetin ortası, water_y: suyun merkezi, tub_width: küvetin ekrandaki genişliği
func layout(screen_size: Vector2, center_x: float, water_y: float, tub_width: float) -> void:
	screen = screen_size
	var k := tub_width / TUB_WIDTH
	_tub_back.scale = Vector2.ONE * tub_width / TEX_TUB_BACK.get_width()     # SVG 2x içe aktarılmış
	_tub_back.position = Vector2(center_x, water_y) - TUB_WATER * k
	floor_y = water_y + 120.0 * k
	tile = clampf(tub_width / 9.0, 60.0, 100.0)
	var tub_bottom := water_y + (TUB_HEIGHT - TUB_WATER.y) * k
	_mat_rect = Rect2(center_x - tub_width * 0.62, tub_bottom - 46.0 * k, tub_width * 1.24, 70.0 * k)
	queue_redraw()


# Küvetin ön parçasını (ayrı düğüm) arka parçayla aynı yere koyar
static func place_front(front: Sprite2D, center_x: float, water_y: float, tub_width: float) -> void:
	var k := tub_width / TUB_WIDTH
	front.centered = false
	front.scale = Vector2.ONE * tub_width / front.texture.get_width()
	front.position = Vector2(center_x, water_y) - TUB_WATER * k


func _draw() -> void:
	# Duvar: fayanslar ekranın ortasından hizalanır (her ekran oranında simetrik)
	draw_rect(Rect2(0, 0, screen.x, floor_y), TILE)
	var x0 := fmod(screen.x / 2.0, tile) - tile
	var row := 0
	var y := floor_y
	while y > -tile:
		var x := x0
		var col := 0
		while x < screen.x + tile:
			if (row + col) % 2 == 0:
				draw_rect(Rect2(x + 3, y - tile + 3, tile - 6, tile - 6), TILE_LIGHT)
			x += tile
			col += 1
		y -= tile
		row += 1
	var gx := x0
	while gx < screen.x + tile:
		draw_line(Vector2(gx, 0), Vector2(gx, floor_y), GROUT, 5.0)
		gx += tile
	var gy := floor_y
	while gy > 0:
		draw_line(Vector2(0, gy), Vector2(screen.x, gy), GROUT, 5.0)
		gy -= tile
	# Renkli şerit: duvarın ortasında bir sıra pembe fayans
	var band_top := floor_y - tile * 3.0
	draw_rect(Rect2(0, band_top, screen.x, tile * 0.5), BAND)
	draw_rect(Rect2(0, band_top + tile * 0.5 - 6.0, screen.x, 6.0), BAND_DARK)
	var dot := x0 + tile / 2.0
	while dot < screen.x + tile:
		draw_circle(Vector2(dot, band_top + tile * 0.25), tile * 0.08, Color.WHITE)
		dot += tile
	# Süpürgelik ve zemin tahtaları
	draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), FLOOR)
	draw_rect(Rect2(0, floor_y - 8.0, screen.x, 16.0), Color.WHITE)
	draw_line(Vector2(0, floor_y + 8.0), Vector2(screen.x, floor_y + 8.0), Color(OUT, 0.25), 3.0)
	var plank := floor_y + 8.0 + 44.0
	while plank < screen.y:
		draw_line(Vector2(0, plank), Vector2(screen.x, plank), FLOOR_DARK, 3.0)
		plank += 44.0
	# Paspas: küvetin altında yuvarlak kenarlı
	var box := StyleBoxFlat.new()
	box.bg_color = MAT
	box.border_color = MAT_DARK
	box.set_border_width_all(8)
	box.set_corner_radius_all(int(_mat_rect.size.y / 2.0))
	box.anti_aliasing = true
	draw_style_box(box, _mat_rect)
