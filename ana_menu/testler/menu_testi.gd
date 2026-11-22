extends SceneTree
# Ana menü testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://ana_menu/testler/menu_testi.gd
# Denetler: oyun listesi geçerli, listedeki yön oyunun ekran_yonu ile aynı; kaydırma dokunma sayılmaz;
# momentum ve uçlarda esneme; sekmeler kartları süzer; her oyun menüden açılır, doğru yönde açılır ve
# Escape ile menüye dönülür; dönünce sekme ve kaydırma konumu korunur; "Yeni" rozeti oyun açılınca kaybolur.
# Başta user:// içindeki .cfg kayıtlarının kopyası alınır, sonunda hepsi aynen geri yazılır (yeni oluşanlar silinir).
# Hata varsa çıkış kodu 1.

const MENU := "res://ana_menu/ana_menu.tscn"
const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
## Hazırlanan, henüz menüye eklenmemiş oyunların klasörleri (menüye eklenince buradan sil)
const HAZIRLANAN := []

var failures := 0
var gecis: Node
var _yedek := {}


func _initialize() -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP    # headless pencere kare; çizim alanı yine 1280x720 olsun
	gecis = root.get_node("SahneGecis")
	_kayitlari_yedekle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OyunListesi.MENU_KAYDI))
	_listeyi_denetle()
	change_scene_to_file(MENU)
	_expect(await _sahne_bekle(MENU), "ana menü açıldı")
	await _frames(60)
	await _kaydirma_denetle()
	await _oyunlari_ac()
	await _sekme_denetle()
	_kayitlari_geri_yaz()
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures)
	quit(1 if failures > 0 else 0)


func _listeyi_denetle() -> void:
	var hatalar := OyunListesi.dogrula()
	_expect(hatalar.is_empty(), "liste geçerli: %s" % [hatalar])
	var klasorler := Array(DirAccess.get_directories_at("res://oyunlar")).filter(func(k: String) -> bool: return k not in HAZIRLANAN)
	_expect(klasorler.size() == OyunListesi.OYUNLAR.size(), "oyunlar/ klasöründeki her oyun listede (%d klasör, %d kayıt)" % [klasorler.size(), OyunListesi.OYUNLAR.size()])
	for oyun in OyunListesi.OYUNLAR:
		_expect(oyun["klasor"] in klasorler, "%s klasörü var" % oyun["ad"])
		var sahne: Node = load(oyun["sahne"]).instantiate()
		var yon = sahne.get("ekran_yonu")
		sahne.free()
		_expect((yon if yon != null else "yatay") == oyun["yon"], "%s yönü listede doğru (%s)" % [oyun["ad"], oyun["yon"]])


func _kaydirma_denetle() -> void:
	var menu: Control = current_scene
	var kart: Control = menu._gorunen[0]
	var bas := kart.get_global_rect().get_center()
	# Kayan parmak oyun açmaz
	_touch(bas, true)
	await _frames(2)
	await _drag(bas, bas + Vector2(0, -260), 10)
	_touch(bas + Vector2(0, -260), false)
	await _frames(40)
	_expect(current_scene == menu and not gecis.gecis_suruyor, "kaydırma oyun açmadı")
	_expect(menu._konum > 150.0, "liste parmakla kaydı (%.0f)" % menu._konum)
	# Hızlı fiske: parmak kalktıktan sonra da akar
	var once: float = menu._konum
	await _drag_hizli(Vector2(640, 650), Vector2(0, -300))
	var birakinca: float = menu._konum
	var en_uzak: float = birakinca
	for i in 30:
		await process_frame
		en_uzak = maxf(en_uzak, menu._konum)
	_expect(en_uzak > birakinca + 40.0 or birakinca >= menu._en_fazla, "momentumla akmaya devam etti (%.0f → %.0f)" % [birakinca, en_uzak])
	_expect(menu._konum > once, "fiske listeyi aşağı kaydırdı")
	await _frames(120)
	# Üst uçtan aşağı çekince esner, bırakınca geri döner
	menu._konum = 0.0
	_touch(Vector2(640, 250), true)
	await _drag(Vector2(640, 250), Vector2(640, 550), 12)
	_expect(menu._konum < -40.0, "üst uçta esnedi (%.0f)" % menu._konum)
	_touch(Vector2(640, 550), false)
	await _frames(60)
	_expect(absf(menu._konum) < 1.0, "bırakınca başa geri döndü (%.1f)" % menu._konum)


func _oyunlari_ac() -> void:
	for i in OyunListesi.OYUNLAR.size():
		var oyun: Dictionary = OyunListesi.OYUNLAR[i]
		var menu: Control = current_scene
		var kart: Control = menu._kartlar[i]
		var yeniydi: bool = kart._yeni != null
		# Kart ekranda görünsün diye listeyi ona kaydır (parmakla sürüklemenin kısa yolu)
		menu._konum = clampf(kart.position.y - 60.0, 0.0, menu._en_fazla)
		await _frames(5)
		var konum: float = menu._konum
		_tap(kart.get_global_rect().get_center())
		if not await _sahne_bekle(oyun["sahne"]):
			_expect(false, "%s açılmadı" % oyun["ad"])
			continue
		_expect(gecis.ekran_yonu == oyun["yon"], "%s %s açıldı" % [oyun["ad"], oyun["yon"]])
		await _frames(40)
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		root.push_input(esc)
		if not await _sahne_bekle(MENU):
			_expect(false, "%s: Escape ile menüye dönülmedi" % oyun["ad"])
			gecis.ana_menuye_don()
			await _sahne_bekle(MENU)
		await _frames(20)
		menu = current_scene
		_expect(gecis.ekran_yonu == "yatay", "%s sonrası menü yatay" % oyun["ad"])
		_expect(is_equal_approx(menu._konum, konum), "%s sonrası kaydırma korundu (%.0f / %.0f)" % [oyun["ad"], menu._konum, konum])
		if yeniydi:
			_expect(menu._kartlar[i]._yeni == null, "%s açılınca Yeni rozeti kayboldu" % oyun["ad"])
		print("tamam: ", oyun["ad"])


func _sekme_denetle() -> void:
	var menu: Control = current_scene
	for s in menu._sekmeler.size():
		var sekme: Control = menu._sekmeler[s]
		var id: String = sekme.kategori["id"]
		_tap(sekme.get_global_rect().get_center())
		await _frames(20)
		_expect(menu._sekme == id, "%s sekmesi seçildi" % id)
		var beklenen := OyunListesi.OYUNLAR.filter(func(o: Dictionary) -> bool: return OyunListesi.kategoride_mi(o, id)).size()
		_expect(menu._gorunen.size() == beklenen and beklenen > 0, "%s: %d kart" % [id, menu._gorunen.size()])
	# Öğren sekmesinden oyun açıp dönünce sekme korunur
	var ogren: Control = menu._sekmeler[4]
	_tap(ogren.get_global_rect().get_center())
	await _frames(20)
	var kart: Control = menu._gorunen[0]
	_tap(kart.get_global_rect().get_center())
	await _sahne_bekle(kart.oyun["sahne"])
	await _frames(20)
	gecis.ana_menuye_don()
	await _sahne_bekle(MENU)
	await _frames(10)
	_expect(current_scene._sekme == "ogren", "oyundan dönünce Öğren sekmesi korundu")
	_expect(current_scene._sekmeler[4].secili, "Öğren sekmesi seçili görünüyor")


# --- Yardımcılar ---

func _kayitlari_yedekle() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if dosya.ends_with(".cfg"):
			_yedek[dosya] = FileAccess.get_file_as_bytes(klasor.path_join(dosya))


func _kayitlari_geri_yaz() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if dosya.ends_with(".cfg") and not _yedek.has(dosya):
			DirAccess.remove_absolute(klasor.path_join(dosya))
	for dosya in _yedek:
		var f := FileAccess.open(klasor.path_join(dosya), FileAccess.WRITE)
		f.store_buffer(_yedek[dosya])
		f.close()


func _sahne_bekle(yol: String) -> bool:
	for i in 600:
		await process_frame
		if current_scene and current_scene.scene_file_path == yol and not gecis.gecis_suruyor:
			return true
	return false


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	_touch(pos, false)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	for i in range(1, steps + 1):
		var ev := InputEventScreenDrag.new()
		ev.position = from.lerp(to, float(i) / steps)
		root.push_input(ev, true)
		await process_frame


# Kısa ve hızlı sürükleme: bırakıldığında hız yüksek olsun
func _drag_hizli(from: Vector2, move: Vector2) -> void:
	_touch(from, true)
	await process_frame
	await _drag(from, from + move, 4)
	_touch(from + move, false)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("HATA: " + message)
