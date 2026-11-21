extends RefCounted
# Yapboz yerleşimi (sahneden bağımsız, saf hesap): tahta ekranın ortasında (4:3), parçaların tepsi yuvaları
# tahtanın solunda ve sağında. Hepsi tasarım alanının (görünen alanın ortasındaki 1280x720) içinde kalır.
# Tahta olabildiğince büyük seçilir; tepsideki parçalar çok küçülecekse (MIN_TRAY_PIECE) tahta küçülür.
#
# make() bir Layout verir:
#   board       tahtanın dikdörtgeni (ekran koordinatı)
#   scale       resim pikselinden tahta pikseline oran (tahta genişliği / 1200)
#   cell        tahtadaki bir hücrenin boyu
#   tray_ratio  tepsideki parçanın tahtadaki boyuna oranı
#   trays       iki tepsinin dikdörtgeni (sol, sağ; arka plan paneli için)
#   slots       yuvaların ortası (count tane, karışık sırada değil: soldan sağa doldurulur)

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")


class Layout:
	var board: Rect2
	var scale: float = 1.0
	var cell: Vector2
	var tray_ratio: float = 0.5
	var trays: Array[Rect2] = []
	var slots: Array[Vector2] = []


## screen: görünen alan, area: tasarım alanı (EkranYardimcisi.tasarim_alani()), side: kenar payı
static func make(cols: int, rows: int, screen: Vector2, area: Rect2, side: float) -> Layout:
	var count := cols * rows
	var top := area.position.y + Settings.TOP
	var avail := area.end.y - Settings.BOTTOM - top
	var aspect := Settings.PICTURE_SIZE.x / Settings.PICTURE_SIZE.y
	var left_count := ceili(count / 2.0)
	var height := minf(Settings.BOARD_MAX_HEIGHT, avail)
	var best := _try(height, aspect, cols, rows, left_count, count - left_count, screen, area, top, avail, side)
	while tray_piece(best) < Settings.MIN_TRAY_PIECE and height - 10.0 >= Settings.BOARD_MIN_HEIGHT:
		height -= 10.0
		var layout := _try(height, aspect, cols, rows, left_count, count - left_count, screen, area, top, avail, side)
		if tray_piece(layout) > tray_piece(best):
			best = layout
	return best


## Tepsideki parçanın kısa kenarı (px)
static func tray_piece(layout: Layout) -> float:
	return layout.tray_ratio * minf(layout.cell.x, layout.cell.y)


static func _try(height: float, aspect: float, cols: int, rows: int, left_count: int, right_count: int,
		screen: Vector2, area: Rect2, top: float, avail: float, side: float) -> Layout:
	var layout := Layout.new()
	var width := height * aspect
	layout.board = Rect2(screen.x / 2.0 - width / 2.0, top + (avail - height) / 2.0, width, height)
	layout.scale = width / Settings.PICTURE_SIZE.x
	layout.cell = Vector2(width / cols, height / rows)
	var tray_width := maxf(40.0, layout.board.position.x - area.position.x - side - Settings.GAP)
	var tray_top := top
	layout.trays = [
		Rect2(area.position.x + side, tray_top, tray_width, avail),
		Rect2(layout.board.end.x + Settings.GAP, tray_top, tray_width, avail),
	]
	# Her tepsi için en iyi sütun sayısı: parçalar en büyük olacak şekilde
	var grid := _grid(maxi(left_count, right_count), tray_width, avail, layout.cell)
	layout.tray_ratio = grid.z
	for t in 2:
		var n := left_count if t == 0 else right_count
		var tray: Rect2 = layout.trays[t]
		var columns := mini(int(grid.x), n)
		var lines := ceili(float(n) / columns)
		var slot := Vector2(tray.size.x / columns, tray.size.y / int(grid.y))
		var used_height := slot.y * lines
		for k in n:
			var col := k % columns
			var line := k / columns
			# Son satır eksikse ortalanır
			var in_line := mini(columns, n - line * columns)
			var x := tray.position.x + tray.size.x / 2.0 + (col - (in_line - 1) / 2.0) * slot.x
			var y := tray.position.y + (tray.size.y - used_height) / 2.0 + (line + 0.5) * slot.y
			layout.slots.append(Vector2(x, y))
	return layout


# (sütun, satır, tepsi oranı): n parçayı tepsiye en büyük boyda sığdıran ızgara
static func _grid(n: int, width: float, height: float, cell: Vector2) -> Vector3:
	var best := Vector3(1, n, 0.0)
	for columns in range(1, 4):
		var lines := ceili(float(n) / columns)
		var slot := Vector2(width / columns, height / lines)
		var ratio := minf(Settings.MAX_TRAY_RATIO, Settings.TRAY_FILL * minf(slot.x / cell.x, slot.y / cell.y))
		# Tahtaya bakan çıkıntı (ve yuvadaki kayma) tahtayla arasındaki boşluğa sığmalı
		var half := cell.x * (0.5 + Settings.TRAY_JITTER.x) + minf(cell.x, cell.y) * Settings.KNOB_REACH
		ratio = minf(ratio, (slot.x / 2.0 + Settings.GAP) / half)
		if ratio > best.z:
			best = Vector3(columns, lines, ratio)
	return best
