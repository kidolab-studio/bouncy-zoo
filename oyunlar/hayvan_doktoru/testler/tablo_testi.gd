extends SceneTree
# Hayvan Doktoru tablo testi (headless). Proje kökünden:
#   godot --headless --path . -s res://oyunlar/hayvan_doktoru/testler/tablo_testi.gd
# Denetler:
#   - ayarlar.gd problems() boş; her günün üç rahatsızlığına birbirinden farklı uygun hayvan bulunur; sonsuz klinikte
#     günler üç farklı, tanımlı rahatsızlık;
#   - her rahatsızlık × gelebileceği her hayvan (en çok diken ve benekle): nokta sayısı doğru, noktalar tuvalin içinde
#     ve hayvanın görselinin üstünde (gövde yerleri gövdede, kafa yerleri kafada); benekler yüzün dışında ve
#     birbirinden ayrı; her aletin uç noktası görselin içinde;
#   - 7 ekran oranında (çentikli ve çentiksiz): masa, hasta, düşünce balonu, bank ve banktaki hastalar tasarım
#     alanında; alet rafı güvenli alanda, geri düğmesinin altında, masaya ve hastaya binmiyor, 4 yuvada da dokunma
#     alanı yeterince büyük; albüm sayfası tasarım alanında, albüm düğmesi gün yıldızlarına binmiyor.

const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const Patient := preload("res://oyunlar/hayvan_doktoru/hasta.gd")
const Album := preload("res://oyunlar/hayvan_doktoru/album.gd")
const DESIGN := Vector2(1280, 720)
const RATIOS := [16.0 / 9.0, 18.0 / 9.0, 19.5 / 9.0, 20.0 / 9.0, 21.0 / 9.0, 4.0 / 3.0, 16.0 / 10.0]
const NOTCH := 96.0               # ekran testindeki çentik taklidinin en geniş yanı (EkranYardimcisi yatayda iki yana aynı verir)
const BACK_BOTTOM := 120.0        # geri düğmesinin alt kenarı (sahnede 20 + 100)
const MIN_TOUCH := 120.0          # dokunma alanı en az bu kadar (çap)

var _fails := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	for problem in Settings.problems():
		_check(false, "ayarlar: " + problem)
	_check_days()
	var spots := _check_spots()
	_check_tools()
	_check_layout()
	if _fails == 0:
		print("hayvan_doktoru tablo_testi: TAMAM (%d gün, %d hasta türü, %d nokta, %d ekran oranı)" % [
			Settings.DAYS.size(), _pairs(), spots, RATIOS.size()])
	else:
		printerr("hayvan_doktoru tablo_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


func _pairs() -> int:
	var count := 0
	for name in Settings.AILMENT_ORDER:
		count += Settings.animals_for(name).size()
	return count


# Her günün üç rahatsızlığına farklı hayvan (oyun sırayla, kullanılmayanlardan rastgele seçer: en kötü durumda da
# yeterli seçenek kalmalı); sonsuz klinik günleri
func _check_days() -> void:
	for d in Settings.DAYS.size():
		var names: Array = Settings.DAYS[d]["ailments"]
		for k in names.size():
			_check(Settings.animals_for(names[k]).size() > k, "%d. gün: %s için yeterli hayvan yok" % [d + 1, names[k]])
	for k in 50:
		var info := Settings.day_info(k, true)
		var names: Array = info["ailments"]
		_check(names.size() == Settings.DAY_PATIENTS, "sonsuz gün: %d hasta" % names.size())
		var seen := {}
		for name: String in names:
			_check(Settings.AILMENTS.has(name) and not seen.has(name), "sonsuz gün: geçersiz ya da tekrarlanan rahatsızlık %s" % name)
			seen[name] = true


# Bütün hayvan × rahatsızlık çiftlerinde noktalar (birkaç kez: yerleşim rastgele)
func _check_spots() -> int:
	var total := 0
	var thorns := Settings.ENDLESS_THORNS
	var rash := Settings.ENDLESS_RASH
	for day in Settings.DAYS:
		thorns = maxi(thorns, int(day["thorns"]))
		rash = maxi(rash, int(day["rash"]))
	for name in Settings.AILMENT_ORDER:
		for animal in Settings.animals_for(name):
			for attempt in 3:
				total += _check_patient(animal, name, thorns, rash)
	return total


func _check_patient(animal: String, name: String, thorns: int, rash: int) -> int:
	var data := Settings.animal(animal)
	var body := data.body_texture.get_image()
	var head := data.head_texture.get_image()
	var p := Patient.new()
	root.add_child(p)
	p.setup(data, 400.0)
	p.add_spot("dinle", [Settings.EXAM_TOOL] as Array[String], Settings.EXAM_REGION, Settings.SPOT_RADIUS)
	var expected := 1
	for info: Dictionary in Settings.AILMENTS[name]["spots"]:
		var steps: Array[String] = []
		steps.assign(info["steps"])
		var count := rash if info["look"] == "benek" else int(info.get("count", 1))
		expected += count
		for k in count:
			p.add_spot(info["look"], steps, info["region"], Settings.SPOT_RADIUS, {"thorns": thorns})
	var label := "%s / %s" % [name, animal]
	_check(p.spots.size() == expected, "%s: %d nokta bekleniyordu, %d" % [label, expected, p.spots.size()])
	for spot in p.spots:
		var on_head: bool = spot.get_meta("on_head")
		var pos: Vector2 = spot.position
		_check(Rect2(0, 0, Patient.CANVAS, Patient.CANVAS).has_point(pos), "%s: %s noktası tuvalin dışında (%s)" % [label, spot.look, pos])
		_check(_opaque(head if on_head else body, pos), "%s: %s noktası hayvanın üstünde değil (%s, %s)" % [
			label, spot.look, "kafa" if on_head else "gövde", pos])
		if spot.look == "benek":
			_check(not on_head or not p._on_face(pos), "%s: benek yüzün üstünde (%s)" % [label, pos])
			for other in p.spots:
				if other != spot and other.look == "benek" and bool(other.get_meta("on_head")) == on_head:
					_check(other.position.distance_to(pos) >= Settings.SPOT_RADIUS * 1.2, "%s: benekler üst üste (%s)" % [label, pos])
		if spot.look == "diken":
			_check(spot._thorns.size() == thorns, "%s: %d diken bekleniyordu" % [label, thorns])
	p.free()
	return expected


func _opaque(image: Image, p: Vector2) -> bool:
	var q := p * image.get_width() / Patient.CANVAS
	var x := clampi(int(q.x), 0, image.get_width() - 1)
	var y := clampi(int(q.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y).a > 0.5


# Aletin uç noktası görselin opak bir yerinde (alet noktaya değen kısmıyla etki eder)
func _check_tools() -> void:
	for id: String in Settings.TOOLS:
		var image := Settings.tool_texture(id).get_image()
		var tip: Vector2 = Settings.TOOLS[id]["tip"]
		var near := false
		for offset in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
			var q: Vector2 = tip * Vector2(image.get_size()) + offset
			var x := clampi(int(q.x), 0, image.get_width() - 1)
			var y := clampi(int(q.y), 0, image.get_height() - 1)
			near = near or image.get_pixel(x, y).a > 0.5
		_check(near, "%s: uç noktası görselin boş yerinde (%s)" % [id, tip])


func _check_layout() -> void:
	for ratio in RATIOS:
		var screen := Vector2(DESIGN.x, DESIGN.x / ratio) if ratio < DESIGN.x / DESIGN.y else Vector2(DESIGN.y * ratio, DESIGN.y)
		var area := Rect2((screen - DESIGN) / 2.0, DESIGN)
		for notch in [0.0, NOTCH]:
			var name := "%.0fx%.0f%s" % [screen.x, screen.y, " çentikli" if notch > 0.0 else ""]
			_check_plan(name, screen, area, maxf(40.0, notch))


func _check_plan(name: String, screen: Vector2, area: Rect2, pad: float) -> void:
	var plan := Settings.layout(screen, area, pad, BACK_BOTTOM)
	var patient: float = plan["patient"]
	var top: Vector2 = plan["table_top"]
	var width: float = plan["table_width"]
	var safe := Rect2(pad, 0.0, screen.x - pad * 2.0, screen.y)
	var table := Rect2(top.x - width / 2.0, top.y - 4.0, width, width * 0.42)
	_check(area.grow(1.0).encloses(table), "%s: masa tasarım alanının dışında (%s)" % [name, table])
	# Hasta: tuvalde x 30..226, y 52..246 kadar yer kaplar (kuyruklar dahil); başın üstünde düşünce balonu
	var s := patient / Patient.CANVAS
	var body := Rect2(top.x - 98.0 * s, top.y - 194.0 * s, 196.0 * s, 194.0 * s)
	_check(area.grow(1.0).encloses(body), "%s: hasta tasarım alanının dışında (%s)" % [name, body])
	var bubble_top := top.y - 176.0 * s - patient * 0.36 * (0.62 + 0.42) - 5.0
	_check(bubble_top >= area.position.y, "%s: düşünce balonu ekranın üstünden taşıyor (%.0f)" % [name, bubble_top])
	# Alet rafı: güvenli alanda, geri düğmesinin altında, masaya / hastaya binmiyor, 4 yuvada da dokunma alanı büyük
	var r := minf(plan["tray_radius"], float(plan["tray_height"]) / (4 * 2.35))
	var center: Vector2 = plan["tray_center"]
	var tray := Rect2(center - Vector2(r, r * 2.35 * 1.5 + r), Vector2(r * 2.0, (r * 2.35 * 1.5 + r) * 2.0))
	_check(safe.encloses(tray.grow(5.0)), "%s: alet rafı güvenli alanın dışında (%s)" % [name, tray])
	_check(tray.position.y >= BACK_BOTTOM, "%s: alet rafı geri düğmesinin altına girmiyor (%.0f)" % [name, tray.position.y])
	_check(tray.end.y <= screen.y, "%s: alet rafı ekranın altından taşıyor" % name)
	_check(tray.position.x - r * 0.3 > maxf(table.end.x, body.end.x), "%s: alet rafı masaya / hastaya biniyor" % name)
	_check(r * 2.6 >= MIN_TOUCH, "%s: raf yuvası küçük (%.0f px)" % [name, r * 2.6])
	# Bank ve banktaki hastalar
	var waiting: float = plan["waiting"]
	var ws := waiting / Patient.CANVAS
	var bench_top: Vector2 = plan["bench_top"]
	var bench_w: float = plan["bench_width"]
	_check(area.grow(1.0).encloses(Rect2(bench_top.x - bench_w / 2.0 - 12.0, bench_top.y - bench_w * 0.13, bench_w + 24.0, bench_w * 0.3)),
		"%s: bank tasarım alanının dışında" % name)
	for seat: Vector2 in plan["seats"]:
		var p := Rect2(seat.x - 98.0 * ws, seat.y - 194.0 * ws, 196.0 * ws, 194.0 * ws)
		_check(area.grow(1.0).encloses(p) and p.position.y > BACK_BOTTOM, "%s: banktaki hasta alanın dışında (%s)" % [name, p])
		_check(waiting * 0.6 >= MIN_TOUCH, "%s: banktaki hasta küçük" % name)
	# Albüm: sayfa tasarım alanında; düğme güvenli alanda ve gün yıldızlarına binmiyor
	var album := Album.new()
	var album_r := 100.0 * 0.56
	var at := Vector2(screen.x - pad - album_r - 6.0, 70.0)
	album.layout(screen, area, at, album_r)
	_check(area.encloses(album._panel.grow(14.0)), "%s: albüm tasarım alanının dışında (%s)" % [name, album._panel])
	_check(at.x - album_r - 5.0 >= pad and at.x + album_r + 5.0 <= screen.x - pad, "%s: albüm düğmesi güvenli alanın dışında" % name)
	var stars_left := 136.0 + 40.0
	var stars_width := minf(screen.x - stars_left - 60.0, 560.0)
	var stars_end := maxf(screen.x / 2.0, stars_left + stars_width / 2.0) + stars_width / 2.0
	_check(stars_end + 10.0 < at.x - album_r, "%s: gün yıldızları albüm düğmesine biniyor" % name)
	album.free()
