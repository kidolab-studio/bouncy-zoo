extends SceneTree
# Noktaları Birleştir tablo testi (headless). Proje kökünden:
#   godot --headless --path . -s res://oyunlar/nokta_birlestir/testler/tablo_testi.gd
# Denetler: ayarlar.gd problems() boş; noktalar.json'daki her resmin SVG'leri var ve tabloda; 7 ekran oranında
# (çentikli ve çentiksiz) sayfa tasarım alanının ve güvenli alanın içinde, üstteki geri düğmesine binmiyor,
# noktalar birbirinden en az MIN_DOT_GAP uzakta ve dokunma alanları en az ~120 px.

const Settings := preload("res://oyunlar/nokta_birlestir/ayarlar.gd")
const DESIGN := Vector2(1280, 720)
const RATIOS := [16.0 / 9.0, 18.0 / 9.0, 19.5 / 9.0, 20.0 / 9.0, 21.0 / 9.0, 4.0 / 3.0, 16.0 / 10.0]
const NOTCH := 96.0               # ekran testindeki çentik taklidinin en geniş yanı (EkranYardimcisi yatayda iki yana aynı verir)
const BACK_BUTTON_BOTTOM := 120.0 # geri düğmesinin alt kenarı (sahnede 20 + 100)

var _fails := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	for problem in Settings.problems():
		_check(false, "ayarlar: " + problem)
	var pictures: Dictionary = Settings.data().get("pictures", {})
	for picture in pictures:
		_check(Settings.PICTURES.has(picture), "%s: noktalar.json'da var ama PICTURES'ta yok" % picture)
		var dots: Array = pictures[picture]["dots"]
		var size := Settings.picture_size()
		for p in dots:
			_check(Rect2(Vector2.ZERO, size).grow(-30.0).has_point(Vector2(p[0], p[1])), "%s: nokta resmin kenarına çok yakın (%s)" % [picture, p])
	for ratio in RATIOS:
		var screen := Vector2(DESIGN.x, DESIGN.x / ratio) if ratio < DESIGN.x / DESIGN.y else Vector2(DESIGN.y * ratio, DESIGN.y)
		var area := Rect2((screen - DESIGN) / 2.0, DESIGN)
		var rect := Settings.picture_rect(screen, area)
		var page := rect.grow(Settings.PAGE_BORDER)
		var name := "%.0fx%.0f" % [screen.x, screen.y]
		_check(area.encloses(page), "%s: sayfa tasarım alanının dışına taşıyor (%s)" % [name, page])
		_check(page.position.x >= NOTCH and page.end.x <= screen.x - NOTCH, "%s: sayfa çentikli ekranda güvenli alanın dışında" % name)
		_check(page.position.y >= BACK_BUTTON_BOTTOM, "%s: sayfa geri düğmesinin altına girmiyor" % name)
		var scale := rect.size.x / Settings.picture_size().x
		for i in Settings.level_count():
			var picture := Settings.picture_of(i)
			var gap := Settings.min_gap(picture) * scale
			_check(gap >= Settings.MIN_DOT_GAP, "%s, %s: noktalar çok yakın (%.0f px)" % [name, picture, gap])
			_check(minf(Settings.TOUCH_RADIUS, gap / 2.0) * 2.0 >= 110.0, "%s, %s: dokunma alanı küçük" % [name, picture])
	if _fails == 0:
		print("nokta_birlestir tablo_testi: TAMAM (%d bölüm, %d ekran oranı)" % [Settings.level_count(), RATIOS.size()])
	else:
		printerr("nokta_birlestir tablo_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)
