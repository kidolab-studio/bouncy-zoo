extends SceneTree
# Boyama Kitabı testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/boyama_kitabi/testler/boyama_testi.gd -- <klasör>
# Ana menüden oyuna geçer (ekran yatay olmalı) ve dokunarak oynar. Denetler:
#   - giriş → sayfa seçimi, kategori sekmeleri; sayfa açılır;
#   - kova: bölge dolar (dalga animasyonuyla); bütün bölgeler boyanınca çizgi kenarlarında beyaz boşluk yok
#     (sığdırılmış ve yakınlaştırılmış görünümde ekran görüntüsünden sayılır);
#   - fırça çizgilerin altında kalır; gökkuşağı fırçasının rengi değişir; damga yerleşir; silgi siler ve
#     boyanmış bölgeye dokununca bölgeyi beyaz yapar;
#   - geri al: 25 işlem sonra 22 geri alma doğru duruma döner; temizle (basılı) ve geri alınması;
#   - avuç içi: ikinci parmak gelince yeni çizgi iptal, iki parmak yakınlaştırır; büyüteç geri getirir;
#   - kaydet (kutlama), geri düğmesiyle otomatik kayıt, galeriden kaldığı yerden devam, aynı sayfadan
#     ikinci eser, her kartta görünen çöp → onay (✗ ve ✓) ile silme, boş galeri; Escape ile çıkarken kayıt.
# <klasör> içine ekran görüntüleri kaydeder. Kullanıcının eserleri test boyunca kenara alınıp geri konur.

const GAME := "res://oyunlar/boyama_kitabi/boyama_kitabi.tscn"
const MENU := "res://ana_menu/ana_menu.tscn"
const ART_DIR := "user://boyama_kitabi"
const BACKUP_DIR := "user://boyama_kitabi_test_yedegi"
const Settings := preload("res://oyunlar/boyama_kitabi/ayarlar.gd")

var out := ""
var game: Node
var gecis: Node
var _fails := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  tamam: ", message)
	else:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	gecis = root.get_node("SahneGecis")
	_backup()
	change_scene_to_file(MENU)
	await _wait_scene(MENU)
	gecis.sahne_degistir(GAME)
	if not await _wait_scene(GAME):
		_check(false, "oyun açılmadı")
		_finish()
		return
	game = current_scene
	_check(root.content_scale_size == Vector2i(1280, 720), "ekran yatay")
	await _frames(20)
	await _shot("01_giris")
	await _home_to_picker()
	await _coloring_tests()
	await _gallery_tests()
	await _escape_saves()
	_finish()


func _finish() -> void:
	_restore()
	if _fails == 0:
		print("boyama_kitabi testi: TAMAM")
	else:
		printerr("boyama_kitabi testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Giriş ve sayfa seçimi ---

func _home_to_picker() -> void:
	var home: Control = game.screen
	await _tap(_center(home.new_button))
	await _wait_screen(ColoringPagePicker)
	var picker: ColoringPagePicker = game.screen
	_check(picker._cards.size() == 4, "hayvanlar: 4 sayfa")
	await _tap(_center(picker._tabs[1]))
	await _frames(10)
	_check(picker.category == "araclar" and picker._cards.size() == 4, "araçlar sekmesi: 4 sayfa")
	await _shot("02_sayfa_secimi")
	await _tap(_center(picker._tabs[0]))
	await _frames(10)
	_check(picker._cards[0].get_meta("page") == "kedi", "basit sayfa (kedi) önce")


func _open_page(index: int) -> ColoringScreen:
	var picker: ColoringPagePicker = game.screen
	await _tap(_center(picker._cards[index]))
	await _wait_screen(ColoringScreen)
	await _frames(20)
	return game.screen


# --- Boyama ---

func _coloring_tests() -> void:
	var screen := await _open_page(0)
	var canvas := screen.canvas
	await _shot("03_bos_sayfa")
	_check(canvas.page_id == "kedi", "kedi sayfası açıldı")
	_check(screen.toolbar.current == "kova", "varsayılan araç kova")
	# Kova: kafaya dokun
	var head := Vector2(512, 230) * 2.0
	var region := canvas.region_at(head)
	await _tap(_page_to_screen(canvas, head))
	await _frames(6)
	await _shot("04_kova_dalgasi")
	await _frames(20)
	_check(canvas.colors[region] == Settings.COLORS[0], "kova kafayı kırmızıya boyadı")
	_check(canvas.history.size() == 1, "kova bir geri alma kaydı")
	# Çizgi üstüne dokununca yakındaki bölge seçilir
	var line_point := _find_line_x(canvas, 312 * 2, 512 * 2, -1)
	_check(canvas.region_at(Vector2(line_point, 624)) >= 0, "çizgi üstüne dokununca bölge bulundu")
	# Bütün bölgeleri boya, beyaz boşluk say
	await _fill_all(screen, 4)
	await _frames(30)
	await _shot("05_hepsi_boyali")
	var gaps := await _count_gaps(canvas)
	_check(gaps < 12, "sığdırılmış görünümde çizgi kenarında beyaz boşluk yok (%d piksel)" % gaps)
	canvas.zoom_at(_page_to_local(canvas, Vector2(560, 240) * 2.0), 4.0)
	await _frames(10)
	await _shot("06_yakin_boyali")
	gaps = await _count_gaps(canvas)
	_check(gaps < 12, "yakınlaştırılmış görünümde beyaz boşluk yok (%d piksel)" % gaps)
	await _tap(_center(screen.zoom_button))
	await _frames(30)
	_check(not canvas.is_zoomed(), "büyüteç görünümü sıfırladı")
	await _undo_tests(screen)
	await _brush_tests(screen)
	await _palm_tests(screen)
	await _clear_tests(screen)
	await _save_tests(screen)


func _fill_all(screen: ColoringScreen, color_index: int) -> void:
	await _tap(_palette_point(screen, color_index))
	var canvas := screen.canvas
	for id in canvas.colors.size():
		var point := _interior_point(canvas, id)
		if point.x < 0:
			_check(false, "bölge %d için iç nokta yok" % id)
			continue
		await _tap(_page_to_screen(canvas, point))
		await _frames(2)


func _undo_tests(screen: ColoringScreen) -> void:
	var canvas := screen.canvas
	# Her işlem bir öncekinden farklı renk: hepsi geri alma kaydı olur
	var snapshots: Array[PackedColorArray] = [canvas.colors.duplicate()]
	for i in 25:
		var id := i % canvas.colors.size()
		var color := (i * 5 + 1) % 16
		if Settings.COLORS[color] == canvas.colors[id]:
			color = (color + 1) % 16
		await _tap(_palette_point(screen, color))
		await _tap(_page_to_screen(canvas, _interior_point(canvas, id)))
		await _frames(2)
		snapshots.append(canvas.colors.duplicate())
	_check(canvas.history.size() >= 25, "25 kova işlemi 25 kayıt (%d)" % canvas.history.size())
	for i in 22:
		await _tap(_center(screen.toolbar.undo_button))
		await _frames(2)
	await _frames(20)
	_check(canvas.colors == snapshots[3], "25 işlemden sonra 22 geri alma doğru duruma döndü")


func _brush_tests(screen: ColoringScreen) -> void:
	var canvas := screen.canvas
	await _tap(_palette_point(screen, 3))
	await _tap(_center(screen.toolbar._tool_buttons["firca"]))
	await _tap(_center(screen.toolbar._options[2]))
	_check(screen.toolbar.current == "firca" and canvas.tool.width > 40.0, "kalın fırça seçildi")
	var y := 312 * 2
	var edge := _find_line_x(canvas, y, 512 * 2, -1)
	var before := canvas.history.size()
	await _drag(_page_to_screen(canvas, Vector2(edge - 180, y)), _page_to_screen(canvas, Vector2(edge + 180, y)), 12)
	await _frames(10)
	_check(canvas.history.size() == before + 1, "bir fırça darbesi = bir kayıt")
	var shot := await _shot("07_firca")
	var on_line := _pixel(shot, _page_to_screen(canvas, Vector2(edge, y)))
	var inside := _pixel(shot, _page_to_screen(canvas, Vector2(edge + 110, y)))
	_check(on_line.get_luminance() < 0.35, "fırça çizginin altında kaldı (çizgi rengi %s)" % on_line)
	_check(_close(inside, Settings.COLORS[3]), "fırçanın rengi göründü (%s)" % inside)
	await _tap(_center(screen.toolbar.undo_button))
	await _frames(10)
	shot = await _shot("")
	_check(not _close(_pixel(shot, _page_to_screen(canvas, Vector2(edge + 110, y))), Settings.COLORS[3]), "fırça darbesi geri alındı")
	# Hızlı çizgi kesintisiz: noktalar arası kalınlığın yarısından az
	await _drag(_page_to_screen(canvas, Vector2(300, 1400)), _page_to_screen(canvas, Vector2(1700, 1450)), 3)
	var node: Node2D = canvas.history._items[-1]["node"]
	var gap := 0.0
	for i in range(1, node.points.size()):
		gap = maxf(gap, node.points[i].distance_to(node.points[i - 1]))
	_check(gap <= node.width * 0.5, "hızlı çizgide ara noktalar dolduruldu (en büyük aralık %.1f)" % gap)
	# Gökkuşağı fırçası
	await _tap(_center(screen.toolbar._tool_buttons["gokkusagi"]))
	await _drag(_page_to_screen(canvas, Vector2(200, 200)), _page_to_screen(canvas, Vector2(1800, 300)), 20)
	node = canvas.history._items[-1]["node"]
	var hues := {}
	for c in node.colors:
		hues[snappedf(c.h, 0.1)] = true
	_check(hues.size() >= 4, "gökkuşağı fırçasının rengi değişti (%d ton)" % hues.size())
	# Damga
	await _tap(_center(screen.toolbar._tool_buttons["damga"]))
	await _tap(_center(screen.toolbar._options[4]))
	var stamp_at := Vector2(1750, 1250)
	await _tap(_page_to_screen(canvas, stamp_at))
	await _frames(30)
	_check(canvas.history._items[-1]["node"].get_script().resource_path.ends_with("damga_katmani.gd"), "damga yerleşti")
	shot = await _shot("08_damga")
	# Silgi: damgayı sil
	await _tap(_center(screen.toolbar._tool_buttons["silgi"]))
	await _tap(_center(screen.toolbar._options[2]))
	await _drag(_page_to_screen(canvas, stamp_at - Vector2(140, 0)), _page_to_screen(canvas, stamp_at + Vector2(140, 0)), 10)
	await _drag(_page_to_screen(canvas, stamp_at - Vector2(140, 60)), _page_to_screen(canvas, stamp_at + Vector2(140, 60)), 10)
	await _drag(_page_to_screen(canvas, stamp_at - Vector2(140, -60)), _page_to_screen(canvas, stamp_at + Vector2(140, -60)), 10)
	await _frames(10)
	shot = await _shot("09_silgi")
	var region_color := canvas.colors[canvas.region_at(stamp_at)]
	_check(_close(_pixel(shot, _page_to_screen(canvas, stamp_at)), region_color), "silgi damgayı sildi")
	# Silgiyle boyalı bölgeye dokun: bölge beyaz
	var head := Vector2(560, 200) * 2.0
	var region := canvas.region_at(head)
	_check(canvas.colors[region] != Settings.PAPER, "kafa boyalı")
	await _tap(_page_to_screen(canvas, head))
	await _frames(30)
	_check(canvas.colors[region] == Settings.PAPER, "silgiyle dokunulan bölge beyaz oldu")
	await _tap(_center(screen.toolbar.undo_button))
	await _frames(30)
	_check(canvas.colors[region] != Settings.PAPER, "silgi dokunuşu geri alındı")
	await _tap(_center(screen.toolbar._tool_buttons["firca"]))


func _palm_tests(screen: ColoringScreen) -> void:
	var canvas := screen.canvas
	var before := canvas.history.size()
	var a := _page_to_screen(canvas, Vector2(900, 700))
	var b := _page_to_screen(canvas, Vector2(1100, 800))
	_touch(0, a, true)
	await _frames(2)
	_move(0, a + Vector2(10, 5))
	await _frames(2)
	_touch(1, b, true)
	await _frames(2)
	for k in 10:
		_move(0, a - Vector2(8, 4) * k)
		_move(1, b + Vector2(8, 4) * k)
		await _frames(1)
	_touch(0, a - Vector2(72, 36), false)
	_touch(1, b + Vector2(72, 36), false)
	await _frames(10)
	_check(canvas.history.size() == before, "ikinci parmak gelince yeni çizgi iptal edildi")
	_check(canvas.is_zoomed(), "iki parmakla yakınlaştı (%.2f)" % canvas._zoom)
	_check(screen.zoom_button.visible, "büyüteç düğmesi göründü")
	await _shot("10_iki_parmak")
	# Yakınken tek parmak boyar
	await _drag(canvas.global_position + canvas.size * 0.5, canvas.global_position + canvas.size * 0.5 + Vector2(120, 40), 8)
	_check(canvas.history.size() == before + 1, "yakınken tek parmak çizdi")
	await _tap(_center(screen.zoom_button))
	await _frames(30)
	_check(not canvas.is_zoomed(), "büyüteçle varsayılan görünüm")
	# Fare tekerleği
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = canvas.global_position + canvas.size * 0.5
	root.push_input(wheel, true)
	await _frames(5)
	_check(canvas.is_zoomed(), "fare tekerleği yakınlaştırdı")
	canvas.reset_view()
	await _frames(30)


func _clear_tests(screen: ColoringScreen) -> void:
	var canvas := screen.canvas
	var colors := canvas.colors.duplicate()
	var p := _center(screen.toolbar.clear_button)
	_touch(0, p, true)
	await _frames(30)
	_touch(0, p, false)
	await _frames(10)
	_check(canvas.colors == colors, "temizle kısa basışta çalışmadı")
	_touch(0, p, true)
	await _frames(110)
	_touch(0, p, false)
	await _frames(20)
	var white := true
	for c in canvas.colors:
		white = white and c == Settings.PAPER
	_check(white, "temizle (basılı) bütün bölgeleri beyaz yaptı")
	var shot := await _shot("11_temizlendi")
	_check(_close(_pixel(shot, _page_to_screen(canvas, Vector2(1500, 1400))), Color.WHITE), "temizle fırça katmanını sildi")
	await _tap(_center(screen.toolbar.undo_button))
	await _frames(20)
	_check(canvas.colors == colors, "temizle geri alındı")


func _save_tests(screen: ColoringScreen) -> void:
	var canvas := screen.canvas
	await _tap(_center(screen.toolbar.save_button))
	await _frames(24)
	await _shot("12_kaydet_kutlama")
	await _frames(60)
	var arts := ColoringArtworks.list()
	_check(arts.size() == 1 and arts[0]["page"] == "kedi", "kaydet galeriye bir eser yazdı")
	_check(not canvas.dirty, "kayıttan sonra değişiklik yok")
	var id: String = arts[0]["id"] if arts.size() > 0 else ""
	_check(FileAccess.file_exists(ART_DIR + "/" + id + "/firca.png") and FileAccess.file_exists(ART_DIR + "/" + id + "/kucuk.png"),
		"fırça katmanı ve küçük resim yazıldı")
	# Bir değişiklik daha, sonra geri düğmesiyle çık: otomatik kayıt
	await _tap(_center(screen.toolbar._tool_buttons["kova"]))
	await _tap(_palette_point(screen, 6))
	await _tap(_page_to_screen(canvas, Vector2(512, 230) * 2.0))
	await _frames(20)
	var expected := canvas.colors.duplicate()
	await _hold(_center(screen.back), 80)
	await _wait_screen(ColoringPagePicker)
	var saved := ColoringArtworks.load_art(id)
	_check(saved.get("colors") == expected, "geri dönerken otomatik kaydedildi")


# --- Galeri ---

func _gallery_tests() -> void:
	# Aynı sayfadan ikinci eser
	var screen := await _open_page(0)
	await _tap(_palette_point(screen, 1))
	await _tap(_page_to_screen(screen.canvas, Vector2(512, 600) * 2.0))
	await _frames(20)
	await _hold(_center(screen.back), 80)
	await _wait_screen(ColoringPagePicker)
	_check(ColoringArtworks.list().size() == 2, "aynı sayfadan ikinci eser")
	var picker: Control = game.screen
	await _hold(_center(picker.back), 80)
	await _wait_screen(ColoringHome)
	await _tap(_center(game.screen.gallery_button))
	await _wait_screen(ColoringGallery)
	var gallery: ColoringGallery = game.screen
	await _frames(10)
	await _shot("13_galeri")
	_check(gallery._cards.size() == 2, "galeride 2 eser")
	var first: Dictionary = gallery._cards[1].get_meta("art")
	# Eskisini aç: kaldığı yerden
	var expected := ColoringArtworks.load_art(first["id"])
	await _tap(_center(gallery._cards[1]))
	await _wait_screen(ColoringScreen)
	await _frames(30)
	var coloring: ColoringScreen = game.screen
	_check(coloring.art_id == first["id"] and coloring.canvas.colors == expected["colors"], "galeriden eser kaldığı yerden açıldı")
	var shot := await _shot("14_devam")
	_check(not _close(_pixel(shot, _page_to_screen(coloring.canvas, Vector2(1000, 1425))), coloring.canvas.colors[coloring.canvas.region_at(Vector2(1000, 1425))]),
		"fırça katmanı geri yüklendi")
	await _hold(_center(coloring.back), 80)
	await _wait_screen(ColoringGallery)
	gallery = game.screen
	await _frames(10)
	_check(gallery._cards.size() == 2 and gallery._cards[1].get_meta("art")["id"] == first["id"], "değiştirilmeden kapanan eser yeniden yazılmadı (sırası aynı)")
	# Çöp → ✗ (çöp kutuları hep görünür ve ızgaranın kenarında kesilmez)
	var grid_rect: Rect2 = gallery._grid.get_global_rect()
	_check(gallery._trashes.size() == 2 and gallery._trashes.all(func(t: Control) -> bool:
		return t.is_visible_in_tree() and grid_rect.encloses(t.get_global_rect())), "çöp kutuları görünür, kesilmiyor")
	await _tap(_center(gallery._trashes[0]))
	await _frames(15)
	_check(gallery._confirm != null, "çöpe dokununca onay çıktı")
	await _shot("16_onay")
	await _tap(_center(gallery._no))
	await _frames(15)
	_check(gallery._confirm == null and gallery._cards.size() == 2, "✗ silmedi")
	# Çöp → ✓
	await _tap(_center(gallery._trashes[0]))
	await _frames(15)
	await _tap(_center(gallery._yes))
	await _frames(40)
	_check(gallery._cards.size() == 1 and ColoringArtworks.list().size() == 1, "✓ eseri sildi")
	await _tap(_center(gallery._trashes[0]))
	await _frames(15)
	await _tap(_center(gallery._yes))
	await _frames(40)
	_check(gallery._cards.is_empty() and gallery._empty.visible, "galeri boş: boş durum görseli")
	await _shot("17_bos_galeri")
	await _tap(_center(gallery.new_button))
	await _wait_screen(ColoringPagePicker)


func _escape_saves() -> void:
	var screen := await _open_page(1)
	await _tap(_page_to_screen(screen.canvas, Vector2(520, 384) * 2.0))
	await _frames(20)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await _wait_scene(MENU)
	var arts := ColoringArtworks.list()
	_check(arts.size() == 1 and arts[0]["page"] == "balik", "Escape ile çıkarken otomatik kaydedildi")


# --- Yardımcılar ---

func _interior_point(canvas: ColoringCanvas, id: int) -> Vector2:
	# Bölgenin çizgiden en uzak noktasına yakın bir yer (kaba tarama)
	var best := Vector2(-1, -1)
	var best_score := -1
	var step := 16
	for y in range(8, canvas.canvas_size.y - 8, step):
		for x in range(8, canvas.canvas_size.x - 8, step):
			if canvas._region_id(x, y) != id or canvas._on_line(x, y):
				continue
			var score := 0
			for r in [12, 24, 36, 48]:
				var ok := true
				for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
					var px: int = clampi(x + d.x, 0, canvas.canvas_size.x - 1)
					var py: int = clampi(y + d.y, 0, canvas.canvas_size.y - 1)
					if canvas._region_id(px, py) != id or canvas._on_line(px, py):
						ok = false
				if ok:
					score += 1
			if score > best_score:
				best_score = score
				best = Vector2(x, y)
	return best


func _find_line_x(canvas: ColoringCanvas, y: int, from_x: int, direction: int) -> int:
	var x := from_x
	while x > 0 and x < canvas.canvas_size.x - 1:
		if canvas._line_mask.get_pixel(x / 2, y / 2).a > 0.95:
			return x
		x += direction
	return x


# Sayfada çizginin örtmediği ama ekranda beyaza yakın görünen piksel (boya ile çizgi arasında boşluk)
func _count_gaps(canvas: ColoringCanvas) -> int:
	var shot := root.get_texture().get_image()
	var screen: ColoringScreen = game.screen
	var skip := screen.zoom_button.get_global_rect().grow(6.0) if screen.zoom_button.visible else Rect2()
	var rect := Rect2(canvas.global_position, canvas.size).intersection(Rect2(canvas.global_position + canvas.page_rect().position, canvas.page_rect().size))
	var count := 0
	for y in range(int(rect.position.y) + 2, int(rect.end.y) - 2):
		for x in range(int(rect.position.x) + 2, int(rect.end.x) - 2):
			var c := shot.get_pixel(x, y)
			if skip.has_point(Vector2(x, y)):
				continue
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
				var p := canvas.to_page(Vector2(x, y) + Vector2(0.5, 0.5))
				var mask := canvas._line_mask.get_pixel(clampi(int(p.x) / 2, 0, canvas._line_mask.get_width() - 1), clampi(int(p.y) / 2, 0, canvas._line_mask.get_height() - 1))
				if mask.a < 0.05:
					count += 1
	return count


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12


func _pixel(image: Image, pos: Vector2) -> Color:
	return image.get_pixel(clampi(int(pos.x), 0, image.get_width() - 1), clampi(int(pos.y), 0, image.get_height() - 1))


func _page_to_local(canvas: ColoringCanvas, page_pos: Vector2) -> Vector2:
	return canvas._offset + page_pos * canvas.view_scale()


func _page_to_screen(canvas: ColoringCanvas, page_pos: Vector2) -> Vector2:
	return canvas.global_position + _page_to_local(canvas, page_pos)


func _palette_point(screen: ColoringScreen, index: int) -> Vector2:
	return screen.palette.global_position + screen.palette._center(index)


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	root.push_input(event, true)


func _move(index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	root.push_input(event, true)


func _tap(pos: Vector2) -> void:
	_touch(0, pos, true)
	await _frames(2)
	_touch(0, pos, false)
	await _frames(3)


func _hold(pos: Vector2, frames: int) -> void:
	_touch(0, pos, true)
	await _frames(frames)
	_touch(0, pos, false)
	await _frames(3)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	_touch(0, from, true)
	await _frames(1)
	for i in range(1, steps + 1):
		_move(0, from.lerp(to, float(i) / steps))
		await _frames(1)
	_touch(0, to, false)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if name != "":
		image.save_png(out.path_join(name + ".png"))
	return image


func _wait_scene(path: String) -> bool:
	for i in 600:
		await process_frame
		if current_scene and current_scene.scene_file_path == path and not gecis.gecis_suruyor:
			return true
	return false


func _wait_screen(type: Variant) -> bool:
	for i in 300:
		await process_frame
		if game and is_instance_valid(game.screen) and is_instance_of(game.screen, type) and not game._switching:
			await _frames(5)
			return true
	_check(false, "ekran açılmadı: %s" % type)
	return false


func _backup() -> void:
	var from := ProjectSettings.globalize_path(ART_DIR)
	var to := ProjectSettings.globalize_path(BACKUP_DIR)
	if DirAccess.dir_exists_absolute(to):
		_remove_dir(ART_DIR)
	elif DirAccess.dir_exists_absolute(from):
		DirAccess.rename_absolute(from, to)


func _restore() -> void:
	_remove_dir(ART_DIR)
	var backup := ProjectSettings.globalize_path(BACKUP_DIR)
	if DirAccess.dir_exists_absolute(backup):
		DirAccess.rename_absolute(backup, ProjectSettings.globalize_path(ART_DIR))


func _remove_dir(path: String) -> void:
	var dir := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		for file in DirAccess.get_files_at(dir.path_join(sub)):
			DirAccess.remove_absolute(dir.path_join(sub).path_join(file))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
