extends SceneTree
# Ekran uyumu testi (pencereli): ana menüyü ve bütün oyunları farklı telefon / tablet oranlarında açar,
# her birinin ekran görüntüsünü kaydeder. Proje kökünden:
#   godot --path . --fixed-fps 60 -s res://ortak/testler/ekran_uyumu_testi.gd -- <klasör> [seçenekler] [oyun ...]
# Seçenekler:
#   centik            çentikli telefonu taklit eder (EkranYardimcisi.deneme_bosluklari); güvensiz bölge görüntüde
#                     kırmızı gösterilir ve bütün geri düğmeleri güvenli alanda mı denetlenir
#   GENxYUK           yalnızca bu çözünürlük(ler) (ör. 2520x1080 2048x1536); verilmezse COZUNURLUKLER'in hepsi
#   oyun klasörü      yalnızca bu oyunlar (ör. ucan_kus hafiza ana_menu); verilmezse hepsi
# Örnek: ... -- C:/gecici/ekranlar centik 2520x1080 2048x1536
#
# Çıktı: <klasör>/<GENxYUK>/<oyun>_1_ilk.png (ilk ekran), <oyun>_2.png, <oyun>_3.png ... (ADIMLAR'daki her "cek").
# Cihaz çözünürlükleri monitöre sığacak şekilde küçültülerek açılır: canvas_items + expand ölçeklemede görünen
# alan yalnızca ekran oranına bağlıdır, yani 2520x1080 ile 1680x720 aynı görüntüyü verir.
# Görüntülere bakarak kontrol edilir: taşma, kesilme, boşluk, kenara yapışan düğme var mı. Hata varsa çıkış kodu 1.
# user:// kayıtları (.cfg dosyaları ve Boyama Kitabı eserleri) yedeklenir ve sonunda eski haline getirilir.

const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const MENU := "res://ana_menu/ana_menu.tscn"
const GERI_DUGMESI := "res://ortak/basili_geri_dugmesi.gd"
const DENEME_BOSLUKLARI := Vector4(96, 0, 64, 30)      # sol, üst, sağ, alt (tasarım pikseli)

# Denenen cihaz çözünürlükleri (yatay). Dikey sahne eklenirse bunların dikey halleri de denenir.
const COZUNURLUKLER := [
	Vector2i(1280, 720),     # 16:9
	Vector2i(2160, 1080),    # 18:9
	Vector2i(2340, 1080),    # 19.5:9
	Vector2i(2400, 1080),    # 20:9
	Vector2i(2520, 1080),    # 21:9
	Vector2i(2048, 1536),    # 4:3 tablet
	Vector2i(1920, 1200),    # 16:10 tablet
]

# Oyunun iç ekranlarına girmek için adımlar (ilk ekran her zaman çekilir):
#   Vector2(x, y)   görünen alanın oranı olarak dokunuş
#   sayı            o kadar kare bekle
#   "yol"           sahnenin kökünden nokta ile ayrılmış özellik yolu (dizi için sıra numarası); bulunan düğümün
#                   ortasına dokunur. Ör. "level_buttons.0", "screen.new_button"
#   "cek"           ekran görüntüsü al
const ADIMLAR := {
	"ucan_kus": [Vector2(0.6, 0.6), 50, "cek"],
	"dondurmaci": [],
	"yol_yap": ["level_buttons.0", 60, "cek"],
	"hafiza": ["level_buttons.0", 200, "cek"],
	"meyve_topla": [Vector2(0.6, 0.6), 220, "cek"],
	"araba_yarisi": ["_garage._play", 90, "cek", "_map._nodes.0", 200, "cek"],
	"sihirli_bahce": [],
	"robot_fabrikasi": [],
	"tren_rayi": ["_giris._oynat", 80, "cek"],
	"balik_tutma": [],
	"kule_yapma": ["_oynat", 120, "cek"],
	"golge_eslestirme": [],
	"kostebek": [240, "cek"],
	"toplama": [],
	"cikarma": [],
	"zipla_zipla": [],
	"muzik_kutusu": [],
	"hayvan_besle": [],
	"boyama_kitabi": ["screen.new_button", 60, "cek", "screen._cards.0", 120, "cek"],
	"buyukten_kucuge": [],
	"hayvan_banyosu": [],
	"siradaki_ne": [],
	"yapboz": [],
	"nokta_birlestir": [],
}

var gecis: Node
var out := ""
var centik := false
var failures := 0
var _yedek := {}
var _eserler: PackedStringArray = []
var _isaret: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Kullanım: ... -- <klasör> [centik] [GENxYUK ...] [oyun_klasörü ...]")
		quit(1)
		return
	out = args[0]
	var secilen: Array = []
	var cozunurlukler: Array = []
	for a: String in args.slice(1):
		if a == "centik":
			centik = true
		elif a.is_valid_int() == false and "x" in a and a.split("x")[0].is_valid_int():
			cozunurlukler.append(Vector2i(int(a.split("x")[0]), int(a.split("x")[1])))
		else:
			secilen.append(a)
	if cozunurlukler.is_empty():
		cozunurlukler = COZUNURLUKLER
	gecis = root.get_node("SahneGecis")
	_kayitlari_yedekle()
	change_scene_to_file(MENU)
	await _gecis_bekle()
	if centik:
		EkranYardimcisi.deneme_bosluklari = DENEME_BOSLUKLARI
		_isaret_ekle()

	var sahneler: Array = []
	if secilen.is_empty() or "ana_menu" in secilen:
		sahneler.append({"klasor": "ana_menu", "sahne": MENU})
	for oyun: Dictionary in OyunListesi.OYUNLAR:
		if secilen.is_empty() or oyun["klasor"] in secilen:
			sahneler.append(oyun)

	for cozunurluk: Vector2i in cozunurlukler:
		var klasor := out.path_join("%dx%d" % [cozunurluk.x, cozunurluk.y])
		DirAccess.make_dir_recursive_absolute(klasor)
		await _pencere_ayarla(cozunurluk)
		print("%dx%d → görünen alan %s (pencere %s)" % [cozunurluk.x, cozunurluk.y, root.get_visible_rect().size, root.size])
		for sahne: Dictionary in sahneler:
			gecis.sahne_degistir(sahne["sahne"])
			await _gecis_bekle()
			await _frames(100)
			var ad: String = sahne["klasor"]
			await _shot(klasor.path_join("%s_1_ilk.png" % ad), ad)
			var sira := 2
			for adim in ADIMLAR.get(ad, []):
				if adim is Vector2:
					_tap(root.get_visible_rect().size * (adim as Vector2))
					await _frames(8)
				elif adim is String and adim == "cek":
					await _shot(klasor.path_join("%s_%d.png" % [ad, sira]), ad)
					sira += 1
				elif adim is String:
					var hedef: Variant = _dugum_bul(adim)
					if hedef == null:
						_hata("%s: '%s' bulunamadı" % [ad, adim])
					else:
						_tap(_orta(hedef))
						await _frames(8)
				else:
					await _frames(int(adim))
	_kayitlari_geri_yaz()
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures, "  (", out, ")")
	quit(1 if failures > 0 else 0)


# Cihaz çözünürlüğünü monitöre sığacak kadar küçültüp pencereye uygular (oran aynı kalır)
func _pencere_ayarla(cozunurluk: Vector2i) -> void:
	var kullanilabilir := Vector2(DisplayServer.screen_get_usable_rect().size) - Vector2(60, 110)
	var olcek := minf(1.0, minf(kullanilabilir.x / cozunurluk.x, kullanilabilir.y / cozunurluk.y))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(Vector2(cozunurluk) * olcek)
	root.move_to_center()
	await _frames(12)
	if _isaret:
		_isaret.size = root.get_visible_rect().size
		_isaret.queue_redraw()


# Güvensiz bölgeyi (taklit edilen çentik, köşeler, hareket çubuğu) yarı saydam kırmızı gösterir
func _isaret_ekle() -> void:
	var katman := CanvasLayer.new()
	katman.layer = 127
	root.add_child(katman)
	_isaret = Control.new()
	_isaret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_isaret.draw.connect(func() -> void:
		var b := DENEME_BOSLUKLARI
		var s := _isaret.size
		var renk := Color(1, 0, 0, 0.28)
		_isaret.draw_rect(Rect2(0, 0, b.x, s.y), renk)
		_isaret.draw_rect(Rect2(s.x - b.z, 0, b.z, s.y), renk)
		_isaret.draw_rect(Rect2(b.x, 0, s.x - b.x - b.z, b.y), renk)
		_isaret.draw_rect(Rect2(b.x, s.y - b.w, s.x - b.x - b.z, b.w), renk))
	katman.add_child(_isaret)


# Çentik denemesinde: bütün geri düğmeleri güvenli alanın içinde olmalı
func _guvenli_alan_denetle(ad: String) -> void:
	if not centik or current_scene == null:
		return
	var alan: Rect2 = EkranYardimcisi.guvenli_alan().grow(1.0)
	for dugum in current_scene.find_children("*", "Control", true, false):
		var c := dugum as Control
		var betik: Script = c.get_script()
		if betik == null or betik.resource_path != GERI_DUGMESI or not c.is_visible_in_tree():
			continue
		if not alan.encloses(c.get_global_rect()):
			_hata("%s: geri düğmesi güvenli alanın dışında (%s, güvenli alan %s)" % [ad, c.get_global_rect(), alan])


func _dugum_bul(yol: String) -> Variant:
	var deger: Variant = current_scene
	for parca in yol.split("."):
		if deger == null:
			return null
		if parca.is_valid_int():
			if not (deger is Array) or int(parca) >= (deger as Array).size():
				return null
			deger = (deger as Array)[int(parca)]
		else:
			deger = (deger as Object).get(parca)
	return deger


func _orta(dugum: Variant) -> Vector2:
	if dugum is Control:
		return (dugum as Control).get_global_rect().get_center()
	if dugum is Node2D:
		return (dugum as Node2D).get_global_transform_with_canvas().origin
	return root.get_visible_rect().size * 0.5


func _gecis_bekle() -> void:
	for i in 900:
		await process_frame
		if current_scene and not gecis.gecis_suruyor:
			return


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.position = pos
		ev.pressed = pressed
		root.push_input(ev, true)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(yol: String, ad: String) -> void:
	_guvenli_alan_denetle(ad)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(yol)


func _hata(mesaj: String) -> void:
	failures += 1
	push_error("HATA: " + mesaj)


func _kayitlari_yedekle() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if dosya.ends_with(".cfg"):
			_yedek[dosya] = FileAccess.get_file_as_bytes(klasor.path_join(dosya))
	_eserler = DirAccess.get_directories_at(klasor.path_join("boyama_kitabi"))


func _kayitlari_geri_yaz() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if dosya.ends_with(".cfg") and not _yedek.has(dosya):
			DirAccess.remove_absolute(klasor.path_join(dosya))
	for dosya in _yedek:
		var f := FileAccess.open(klasor.path_join(dosya), FileAccess.WRITE)
		f.store_buffer(_yedek[dosya])
		f.close()
	# Testin Boyama Kitabı'nda oluşturduğu eserleri sil (önceden var olanlara dokunma)
	var eser_klasoru := klasor.path_join("boyama_kitabi")
	for eser in DirAccess.get_directories_at(eser_klasoru):
		if not (eser in _eserler):
			var yol := eser_klasoru.path_join(eser)
			for dosya in DirAccess.get_files_at(yol):
				DirAccess.remove_absolute(yol.path_join(dosya))
			DirAccess.remove_absolute(yol)
