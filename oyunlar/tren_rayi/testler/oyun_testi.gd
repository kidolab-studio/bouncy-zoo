extends SceneTree
# Tren Rayı oynanış testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://oyunlar/tren_rayi/testler/oyun_testi.gd
# Denetler: bölüm verisi geçerli, her bölüm karıştırılınca başta çözülmemiş; giriş ekranından oyuna geçiş;
# sabit parça dönmez; eksik yolda tren durup başlangıca döner (ilerleme olmaz); ipucu yanlış parçayı bulur;
# 20 bölümün hepsi dokunarak çözülür, tren istasyona varır, yolcuların hepsi alınır, vagon eklenir ve kayıt
# güncellenir; geri düğmesi oyundan giriş ekranına döner. user://tren_rayi.cfg başta yedeklenir, sonda geri yazılır.
# Hata varsa çıkış kodu 1.

const Bolumler := preload("res://oyunlar/tren_rayi/bolumler.gd")
const Baglanti := preload("res://oyunlar/tren_rayi/baglanti.gd")
const Yonetici := preload("res://oyunlar/tren_rayi/bolum_yoneticisi.gd")

var failures := 0
var game: Node
var _yedek: PackedByteArray
var _yedek_var := false


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	var bitmisti := OyunBitti.tamamlandi_mi("tren_rayi")
	OyunBitti.sifirla("tren_rayi")
	root.content_scale_size = Vector2i(1280, 720)
	_yedek_var = FileAccess.file_exists(Yonetici.PATH)
	if _yedek_var:
		_yedek = FileAccess.get_file_as_bytes(Yonetici.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Yonetici.PATH))
	_veri_denetle()
	game = load("res://oyunlar/tren_rayi/tren_rayi.tscn").instantiate()
	root.add_child(game)
	await frames(60)
	_expect(game.durum == game.Durum.GIRIS, "giriş ekranıyla açılır")
	tap(game._giris._oynat.position)
	await frames(30)
	_expect(game.durum == game.Durum.OYUN, "oynat düğmesi oyunu başlatır")
	await _eksik_yol_denetle()
	await _sabit_denetle()
	for i in Bolumler.LEVELS.size():
		if not await _bolum_oyna(i):
			break
	await _geri_denetle()
	game.queue_free()
	await process_frame
	if _yedek_var:
		var f := FileAccess.open(Yonetici.PATH, FileAccess.WRITE)
		f.store_buffer(_yedek)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Yonetici.PATH))
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures)
	if bitmisti:
		OyunBitti.tamamla("tren_rayi")
	else:
		OyunBitti.sifirla("tren_rayi")
	quit(1 if failures > 0 else 0)


func _veri_denetle() -> void:
	var hatalar := Bolumler.validate()
	_expect(hatalar.is_empty(), "bölüm verisi geçerli: %s" % [hatalar])
	_expect(Bolumler.LEVELS.size() >= 20, "en az 20 bölüm")
	var temalar := {}
	for data in Bolumler.LEVELS:
		temalar[data["tema"]] = temalar.get(data["tema"], 0) + 1
	_expect(temalar.size() == 5 and temalar.values().all(func(n: int) -> bool: return n == 4), "5 tema, her birinde 4 bölüm")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in Bolumler.LEVELS.size():
		for k in 20:
			var kurulu := Bolumler.kur(Bolumler.LEVELS[i], rng)
			var yolcular: Array = kurulu["yolcular"].map(func(y: Dictionary) -> Vector2i: return y["hucre"])
			var rota := Baglanti.rota(Bolumler.durum_sozlugu(kurulu["parcalar"]), kurulu["giris"], kurulu["cikis"], kurulu["cikis_yonu"], yolcular)
			if rota["tamam"]:
				_expect(false, "bölüm %d başta çözülmüş kuruldu" % (i + 1))
				break


func _eksik_yol_denetle() -> void:
	var tren: Node2D = game.tren
	var bas: float = tren.mesafe
	tap(game._hareket.get_global_rect().get_center())
	await frames(5)
	_expect(game.durum == game.Durum.YOLCULUK, "hareket düğmesi treni yola çıkarır")
	await bekle(func() -> bool: return game.durum == game.Durum.OYUN, 1500)
	_expect(game.durum == game.Durum.OYUN, "eksik yolda tren başlangıca döner ve oyun sürer")
	_expect(absf(tren.mesafe - bas) < 1.0, "tren başlangıç yerine döndü")
	_expect(game.yonetici.bolum == 0, "eksik yolda ilerleme olmaz")
	_expect(game.izgara.ipucu(), "ipucu yanlış yöndeki bir parçayı bulur")


func _sabit_denetle() -> void:
	# 6. bölümde sabit parça var: geçici olarak kur, dokun, dönmediğini gör
	game.yonetici.bolum = 5
	game._bolumu_kur()
	await frames(5)
	var izgara: Node2D = game.izgara
	var sabit: Vector2i = Bolumler.LEVELS[5]["sabit"][0]
	var yon: int = izgara.parcalar[sabit].yon
	tap(izgara.merkez(sabit))
	await frames(5)
	_expect(izgara.parcalar[sabit].yon == yon, "sabit parça dönmez")
	var serbest: Vector2i = izgara.parcalar.keys().filter(func(h: Vector2i) -> bool: return not izgara.parcalar[h].sabit)[0]
	yon = izgara.parcalar[serbest].yon
	tap(izgara.merkez(serbest))
	await frames(5)
	_expect(izgara.parcalar[serbest].yon == (yon + 1) % 4, "sabit olmayan parça 90° döner")
	game.yonetici.bolum = 0
	game._bolumu_kur()
	await frames(5)


func _bolum_oyna(i: int) -> bool:
	_expect(game.yonetici.bolum == i, "sıradaki bölüm %d" % (i + 1))
	await coz()
	var izgara: Node2D = game.izgara
	_expect(izgara.tamam, "bölüm %d: çözülünce yol tamam" % (i + 1))
	# Başlangıçtan istasyona kadarki parçalar parlıyor
	for adim in Baglanti.rota(izgara.durum(), izgara.bolum["giris"], izgara.bolum["cikis"], izgara.bolum["cikis_yonu"], [])["adimlar"]:
		if not izgara.parcalar[adim["hucre"]].bagli:
			_expect(false, "bölüm %d: bağlı parça parlamıyor" % (i + 1))
			break
	var yolcu_sayisi: int = izgara.yolcular.size()
	tap(game._hareket.get_global_rect().get_center())
	await bekle(func() -> bool: return game.durum == game.Durum.KUTLAMA, 3000)
	if game.durum != game.Durum.KUTLAMA:
		_expect(false, "bölüm %d: tren istasyona varmadı" % (i + 1))
		return false
	_expect(game.tren.yolcu_sayisi() == yolcu_sayisi, "bölüm %d: yolcuların hepsi alındı (%d/%d)" % [i + 1, game.tren.yolcu_sayisi(), yolcu_sayisi])
	if i == Bolumler.LEVELS.size() - 1:
		# Son bölüm: ortak final ekranı; "baştan oyna" 1. bölümü açar, vagonlar kalır
		await bekle(func() -> bool: return OyunBitti.acik, 1200)
		_expect(OyunBitti.acik and OyunBitti.tamamlandi_mi("tren_rayi"), "son bölümden sonra final ekranı, oyun tamamlandı")
		await _final_dugmesi("bastan")
		await bekle(func() -> bool: return game.durum == game.Durum.OYUN, 1200)
		_expect(game.yonetici.bolum == 0 and game.yonetici.vagon == i + 1, "final → baştan oyna: 1. bölüm, vagonlar duruyor")
		print("bölüm %d tamam" % (i + 1))
		await frames(30)
		return true
	await bekle(func() -> bool: return game.durum == game.Durum.OYUN, 1200)
	_expect(game.yonetici.bolum == i + 1 and game.yonetici.vagon == i + 1, "bölüm %d sonrası ilerleme ve vagon" % (i + 1))
	var ayar := ConfigFile.new()
	ayar.load(Yonetici.PATH)
	_expect(int(ayar.get_value("ilerleme", "bolum", -1)) == i + 1, "bölüm %d sonrası kayıt" % (i + 1))
	print("bölüm %d tamam" % (i + 1))
	await frames(30)
	return true


func _geri_denetle() -> void:
	var geri: Control = game._geri
	var yer := geri.get_global_rect().get_center()
	var ev := InputEventScreenTouch.new()
	ev.position = yer
	ev.pressed = true
	root.push_input(ev, true)
	await frames(80)
	ev = InputEventScreenTouch.new()
	ev.position = yer
	root.push_input(ev, true)
	await frames(10)
	_expect(game.durum == game.Durum.GIRIS, "basılı tutulan geri düğmesi giriş ekranına döner")
	_expect(game._giris.tren != null and game._giris.tren.uzunluk() > 0.0, "giriş ekranında tren var")


# Parçalara dokunarak çözüm yönüne çevirir
func coz() -> void:
	var izgara: Node2D = game.izgara
	for h in izgara.parcalar:
		var parca: Node2D = izgara.parcalar[h]
		if parca.sabit or not izgara.bolum["cozum"].has(h):
			continue
		var hedef := Baglanti.acikliklar(izgara.bolum["cozum"][h]["tip"], izgara.bolum["cozum"][h]["yon"])
		for k in 4:
			if Baglanti.acikliklar(parca.tip, parca.yon) == hedef:
				break
			tap(izgara.merkez(h))
			await frames(2)


func bekle(kosul: Callable, en_fazla: int) -> void:
	for i in en_fazla:
		if kosul.call():
			return
		await process_frame


func tap(pos: Vector2) -> void:
	for basili in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.position = pos
		ev.pressed = basili
		root.push_input(ev, true)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("HATA: " + message)


# Ortak final ekranında (OyunBitti) düğmeler belirince verilen düğmeye dokunur ("bastan", "sonsuz", ...)
func _final_dugmesi(eylem: String) -> void:
	var ekran: OyunBitti = null
	for c in root.get_children():
		if c is OyunBitti:
			ekran = c
	if ekran == null:
		return
	await bekle(func() -> bool: return ekran._hazir, 600)
	for satir: Array in ekran._dugmeler:
		if satir[1] == eylem:
			tap((satir[0] as Control).get_global_rect().get_center())
