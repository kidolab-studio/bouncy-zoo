extends SceneTree
# İpucu eli testi (başsız): ortak bileşenin davranışı (ilk açılış, dokununca kaybolma, beklemede geri gelme,
# ikinci açılış, engel, bütün hareket türleri) ve her oyunun ipucu fonksiyonu (oyunu menü sırasıyla açar,
# ADIMLAR ile oyun ekranına girer; el doğru yerde mi, dokununca kayboluyor mu, 6 sn beklenince geliyor mu).
#   godot --headless --path . --fixed-fps 60 -s res://ortak/testler/ipucu_eli_testi.gd [-- oyun ...]
# Pencereli çalıştırılırsa (--headless olmadan) ve "-- cek <klasör>" verilirse her oyunda elin göründüğü anın
# ekran görüntüsü kaydedilir. user://ipucu_eli.cfg ve oyun kayıtları yedeklenir, sonunda geri yazılır.

const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const MENU := "res://ana_menu/ana_menu.tscn"

# Oyunun ipucu gösterilen ekranına girmek için adımlar (ekran_uyumu_testi.gd ile aynı biçim):
#   Vector2 (görünen alanın oranı) dokunuş, sayı = kare bekle, "yol" = o düğümün ortasına dokun
const ADIMLAR := {
	"yol_yap": ["level_buttons.0", 60],
	"hafiza": ["level_buttons.0", 60],
	"meyve_topla": [Vector2(0.6, 0.6), 30],
	"araba_yarisi": ["_garage._play", 90, "_map._nodes.0", 60],
	"tren_rayi": ["_giris._oynat", 60],
	"kule_yapma": ["_oynat", 60],
	"boyama_kitabi": ["screen.new_button", 60, "screen._cards.0", 60],
}

var gecis: Node
var hata := 0
var _yedek := {}
var _cek := ""


func _initialize() -> void:
	_calis.call_deferred()


func _kontrol(kosul: bool, metin: String) -> void:
	print(("tamam: " if kosul else "HATA: ") + metin)
	if not kosul:
		hata += 1


func _kareler(n: int) -> void:
	for i in n:
		await process_frame


func _sn(sure: float) -> void:
	await create_timer(sure).timeout


func _calis() -> void:
	var args := OS.get_cmdline_user_args()
	var secilen: Array = []
	var i := 0
	while i < args.size():
		if args[i] == "cek" and i + 1 < args.size():
			_cek = args[i + 1]
			DirAccess.make_dir_recursive_absolute(_cek)
			i += 2
			continue
		secilen.append(args[i])
		i += 1
	if DisplayServer.get_name() == "headless":
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP    # headless pencere kare; çizim alanı 1280x720
	gecis = root.get_node("SahneGecis")
	_yedekle()
	if secilen.is_empty() or "bilesen" in secilen:
		await _bilesen_testi()
	change_scene_to_file(MENU)
	await _gecis_bekle()
	for oyun: Dictionary in OyunListesi.OYUNLAR:
		if secilen.is_empty() or oyun["klasor"] in secilen:
			await _oyun_testi(oyun)
	_geri_yaz()
	print("SONUÇ: ", "hepsi geçti" if hata == 0 else "%d hata" % hata)
	quit(1 if hata > 0 else 0)


# --- Bileşen ---

func _bilesen_testi() -> void:
	IpucuEli.sifirla()
	var sahne := Node2D.new()
	root.add_child(sahne)
	var durum := {"h": IpucuEli.dokun(Vector2(400, 300)), "engel": false}
	var el := IpucuEli.ekle(sahne, "deneme", func() -> Dictionary: return durum["h"])
	el.engel = func() -> bool: return durum["engel"]
	await _sn(0.3)
	_kontrol(not el._el.visible, "bileşen: 0.3 sn'de henüz görünmüyor")
	await _sn(0.6)
	_kontrol(el._el.visible, "bileşen: ilk açılışta ~0.5 sn sonra belirdi")
	await _sn(0.5)
	_kontrol(el._el.position.distance_to(Vector2(400, 300)) < 4.0, "bileşen: parmak ucu hedefte (%s)" % el._el.position)
	_dokun(Vector2(900, 500))
	_dokun(Vector2(900, 500), false)
	await _sn(0.3)
	_kontrol(not el._el.visible, "bileşen: dokununca kayboldu")
	await _sn(4.0)
	_kontrol(not el._el.visible, "bileşen: 4 sn beklemede görünmüyor")
	await _sn(2.6)
	_kontrol(el._el.visible, "bileşen: 6 sn beklenince geri geldi")
	durum["engel"] = true
	await _sn(0.4)
	_kontrol(not el._el.visible, "bileşen: oyunun kendi ipucu görünürken çekildi")
	durum["engel"] = false
	durum["h"] = {}
	await _sn(7.0)
	_kontrol(not el._el.visible, "bileşen: hareket yokken (ör. kutlama ekranı) görünmüyor")
	# Basılı tutan parmak varken boşta sayılmaz
	durum["h"] = IpucuEli.basili_tut(Vector2(300, 300))
	_dokun(Vector2(900, 500), true)
	await _sn(7.0)
	_kontrol(not el._el.visible, "bileşen: parmak basılıyken görünmüyor")
	_dokun(Vector2(900, 500), false)
	sahne.queue_free()
	await _kareler(2)

	# İkinci açılış: kayıt var, yalnızca beklemede
	var sahne2 := Node2D.new()
	root.add_child(sahne2)
	var el2 := IpucuEli.ekle(sahne2, "deneme", func() -> Dictionary: return IpucuEli.dokun(Vector2(500, 300)))
	await _sn(2.0)
	_kontrol(not el2._el.visible, "bileşen: ikinci açılışta hemen görünmüyor")
	await _sn(4.6)
	_kontrol(el2._el.visible, "bileşen: ikinci açılışta 6 sn beklemede görünüyor")
	sahne2.queue_free()
	await _kareler(2)

	# Bütün hareket türleri hatasız oynuyor ve bitince el gizleniyor
	var turler := [
		IpucuEli.dokun(Vector2(300, 300)),
		IpucuEli.cift_dokun(Vector2(300, 300), Vector2(700, 300)),
		IpucuEli.surukle(Vector2(300, 300), Vector2(800, 400)),
		IpucuEli.basili_tut(Vector2(640, 600)),
		IpucuEli.kaydir_yatay(Vector2(640, 650)),
		IpucuEli.sira([IpucuEli.goster(Vector2(900, 150)), IpucuEli.dokun(Vector2(300, 500), 1), IpucuEli.dokun(Vector2(700, 500), 1)]),
		IpucuEli.dokun(Vector2(1270, 715)),
	]
	for h: Dictionary in turler:
		IpucuEli.sifirla()
		var s := Node2D.new()
		root.add_child(s)
		var e := IpucuEli.ekle(s, "deneme_" + str(h["tur"]), func() -> Dictionary: return h)
		e.bekleme_suresi = 1000.0
		await _sn(1.0)
		_kontrol(e._el.visible, "bileşen: '%s' gösteriliyor" % h["tur"])
		var en_cok := 0.0
		for k in 20:
			await _sn(0.5)
			if not e._gosteriyor:
				break
			en_cok += 0.5
		_kontrol(not e._gosteriyor and not e._el.visible, "bileşen: '%s' bitti ve gizlendi (%.1f sn)" % [h["tur"], en_cok])
		s.queue_free()
		await _kareler(2)
	IpucuEli.sifirla()


# --- Oyunlar ---

func _oyun_testi(oyun: Dictionary) -> void:
	var ad: String = oyun["klasor"]
	for tur in ["ilk", "tekrar"]:
		if tur == "ilk":
			IpucuEli.sifirla()
		gecis.sahne_degistir(oyun["sahne"])
		await _gecis_bekle()
		var sahne := current_scene
		var el := _el_bul(sahne)
		if el == null:
			_kontrol(false, "%s: ipucu eli eklenmemiş" % ad)
			return
		for adim in ADIMLAR.get(ad, []):
			if adim is Vector2:
				_dokun(root.get_visible_rect().size * (adim as Vector2))
				_dokun(root.get_visible_rect().size * (adim as Vector2), false)
				await _kareler(8)
			elif adim is String:
				var hedef: Variant = _dugum_bul(sahne, adim)
				if hedef == null:
					_kontrol(false, "%s: '%s' bulunamadı" % [ad, adim])
					return
				_dokun(_orta(hedef))
				_dokun(_orta(hedef), false)
				await _kareler(8)
			else:
				await _kareler(int(adim))
		var h: Dictionary = {}
		for k in 360:          # oyun giriş animasyonu bitip hareket gösterilebilir olana kadar (en çok 6 sn)
			h = el._hareket_al()
			if not h.is_empty():
				break
			await process_frame
		if h.is_empty():
			_kontrol(false, "%s (%s): oyun ekranında hareket yok" % [ad, tur])
			return
		var hedef := _ilk_hedef(el, h)
		var alan := EkranYardimcisi.guvenli_alan()
		_kontrol(alan.has_point(hedef), "%s (%s): '%s' hedefi ekranda %s" % [ad, tur, h["tur"], hedef])
		if tur == "ilk":
			var goruldu := await _gorunene_kadar(el, 3.0)
			_kontrol(goruldu, "%s: ilk açılışta el belirdi" % ad)
			if goruldu and _cek != "":
				await _sn(1.0)
				await _goruntu(ad)
			# Beklenen hareketin başlangıcına dokun (sürüklemede yerinde bırak)
			_dokun(hedef)
			await _kareler(2)
			_kontrol(not el._gosteriyor, "%s: dokununca kayboluyor" % ad)
			_dokun(hedef, false)
			await _kareler(30)
			if el._hareket_al().is_empty():
				print("  not: %s dokunuştan sonra hareket istemiyor (durum değişti), bekleme denetimi atlandı" % ad)
			else:
				var geldi := await _gorunene_kadar(el, el.bekleme_suresi + 1.5)
				_kontrol(geldi or el._hareket_al().is_empty(), "%s: 6 sn beklenince geri geldi" % ad)
		else:
			_kontrol(not await _gorunene_kadar(el, 2.0), "%s: ikinci açılışta hemen gösterilmiyor" % ad)
			var geldi := await _gorunene_kadar(el, el.bekleme_suresi)
			_kontrol(geldi or el._hareket_al().is_empty(), "%s: ikinci açılışta beklemede gösteriliyor" % ad)


func _gorunene_kadar(el: IpucuEli, sure: float) -> bool:
	var kare := int(sure * 60.0)
	for i in kare:
		await process_frame
		if el._el.visible and el._el.modulate.a > 0.5:
			return true
		if el._engelli():
			print("  not: oyunun kendi ipucu görünüyor (bu el ona yol verdi)")
			return true
	return false


func _ilk_hedef(el: IpucuEli, h: Dictionary) -> Vector2:
	if h["tur"] == "sira":
		return el._nokta(h["adimlar"][0]["a"])
	return el._nokta(h["a"])


func _el_bul(dugum: Node) -> IpucuEli:
	for c in dugum.get_children():
		if c is IpucuEli:
			return c
	return null


func _gecis_bekle() -> void:
	await _kareler(5)
	for i in 900:
		await process_frame
		if current_scene and not gecis.gecis_suruyor:
			break
	await _kareler(10)


func _dugum_bul(sahne: Node, yol: String) -> Variant:
	var nesne: Variant = sahne
	for parca in yol.split("."):
		if nesne == null:
			return null
		if parca.is_valid_int():
			nesne = nesne[int(parca)] if int(parca) < nesne.size() else null
		else:
			nesne = nesne.get(parca)
	return nesne


func _orta(hedef: Variant) -> Vector2:
	if hedef is Control:
		return (hedef as Control).get_global_transform_with_canvas() * ((hedef as Control).size / 2.0)
	return (hedef as CanvasItem).get_global_transform_with_canvas().origin


func _dokun(konum: Vector2, basili := true) -> void:
	var olay := InputEventScreenTouch.new()
	olay.index = 0
	olay.position = konum
	olay.pressed = basili
	root.push_input(olay, true)


func _goruntu(ad: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_cek.path_join("%s.png" % ad))


# --- Kayıtlar ---

func _yedekle() -> void:
	for dosya in DirAccess.get_files_at("user://"):
		if dosya.ends_with(".cfg"):
			_yedek[dosya] = FileAccess.get_file_as_bytes("user://" + dosya)


func _geri_yaz() -> void:
	for dosya in DirAccess.get_files_at("user://"):
		if dosya.ends_with(".cfg") and not _yedek.has(dosya):
			DirAccess.remove_absolute("user://" + dosya)
	for dosya: String in _yedek:
		var f := FileAccess.open("user://" + dosya, FileAccess.WRITE)
		f.store_buffer(_yedek[dosya])
		f.close()
