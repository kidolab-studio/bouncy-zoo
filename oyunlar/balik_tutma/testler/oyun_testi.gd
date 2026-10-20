extends SceneTree
# Balık Tutma oynanış testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://oyunlar/balik_tutma/testler/oyun_testi.gd
# Denetler: tür ve bölüm verisi (en az 20 tür, 16 bölüm, 4 tema x 4); parmakla ağ balığa gider ve yakalar;
# görev balığı kovaya gider ve simgeyi doldurur; ilk kez yakalanan ilgisiz tür akvaryuma, bilinen ilgisiz tür suya
# döner; denizanası ağdaki balığı kaçırır; çöp toplandıkça su berraklaşır; duraklatma ve akvaryum ekranı;
# 16 bölümün hepsi dokunarak bitirilir ve kayıt güncellenir.
# user://balik_tutma.cfg başta yedeklenir, sonda geri yazılır. Hata varsa çıkış kodu 1.

const Bolumler := preload("res://oyunlar/balik_tutma/bolumler.gd")
const Turler := preload("res://oyunlar/balik_tutma/balik_turleri.gd")
const Kayit := preload("res://oyunlar/balik_tutma/kayit.gd")
const Balik := preload("res://oyunlar/balik_tutma/balik.gd")

var failures := 0
var game: Node
var _yedek: PackedByteArray
var _yedek_var := false


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	var bitmisti := OyunBitti.tamamlandi_mi("balik_tutma")
	OyunBitti.sifirla("balik_tutma")
	root.content_scale_size = Vector2i(720, 1280)
	_yedek_var = FileAccess.file_exists(Kayit.PATH)
	if _yedek_var:
		_yedek = FileAccess.get_file_as_bytes(Kayit.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Kayit.PATH))
	_veri_denetle()
	game = load("res://oyunlar/balik_tutma/balik_tutma.tscn").instantiate()
	root.add_child(game)
	await frames(60)
	await _ilk_bolum_denetle()
	await _sakin_bekle()
	await _denizanasi_denetle()
	await _sakin_bekle()
	await _cop_denetle()
	await _sakin_bekle()
	await _duraklat_akvaryum_denetle()
	await _sakin_bekle()
	game.kayit.bolum = 0
	game._bolumu_kur()
	await frames(10)
	for i in Bolumler.LEVELS.size():
		if not await _bolum_oyna(i):
			break
	game.queue_free()
	await process_frame
	if _yedek_var:
		var f := FileAccess.open(Kayit.PATH, FileAccess.WRITE)
		f.store_buffer(_yedek)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Kayit.PATH))
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures)
	if bitmisti:
		OyunBitti.tamamla("balik_tutma")
	else:
		OyunBitti.sifirla("balik_tutma")
	quit(1 if failures > 0 else 0)


func _veri_denetle() -> void:
	var hatalar := Bolumler.validate()
	_expect(hatalar.is_empty(), "bölüm verisi geçerli: %s" % [hatalar])
	_expect(Turler.TURLER.size() >= 20, "en az 20 tür")
	_expect(Turler.SIRA.size() == Turler.TURLER.size(), "akvaryum sırasında bütün türler var")
	for tur in Turler.TURLER:
		_expect(tur in Turler.SIRA, "%s akvaryum sırasında" % tur)
		_expect(Turler.doku(tur) != null, "%s görseli" % tur)
	var temalar := {}
	for data in Bolumler.LEVELS:
		temalar[data["tema"]] = temalar.get(data["tema"], 0) + 1
	_expect(Bolumler.LEVELS.size() >= 16 and temalar.size() == 4 and temalar.values().all(func(n: int) -> bool: return n == 4),
		"16 bölüm, 4 tema, her birinde 4")


# Parmağı hedefin üstünde tutar (ağ izler), ağa girince bırakır. Döner: yakalandı mı
func kovala(hedef: Node2D, en_fazla: int = 400) -> bool:
	var olta: Node2D = game.olta
	touch(hedef.global_position, true)
	for i in en_fazla:
		await process_frame
		if not is_instance_valid(hedef):
			break
		if olta.icerik == hedef:
			touch(hedef.global_position, false)
			return true
		if hedef.get_parent() != game.uretici:
			break
		drag(hedef.global_position)
	touch(Vector2(360, 900), false)
	return false


# Belirli bir denetimde ağ yolda başka balık yakalamasın diye diğer balıklar sudan alınır
func yalniz_birak(hedef: Node2D) -> void:
	game.uretici._bekleme = 1000.0
	for b in game.uretici.baliklar.duplicate():
		if b != hedef:
			game.uretici.baliklar.erase(b)
			b.queue_free()


func uretime_devam() -> void:
	game.uretici._bekleme = 0.0


func teslim_bekle() -> void:
	for i in 600:
		await process_frame
		if game.olta.icerik == null and not game.olta.kilitli:
			return


func _uyan_balik(kosul: Callable) -> Node2D:
	for i in 1500:
		for b in game.uretici.baliklar:
			if b.durum == Balik.Durum.YUZUYOR and b.position.x > 80.0 and b.position.x < 640.0 and kosul.call(b):
				return b
		await process_frame
	return null


func _ilk_bolum_denetle() -> void:
	# Bölüm 1: 3 mavi. İlgisiz yeni tür akvaryuma, ikinci kez yakalanan ilgisiz tür suya döner.
	var kirmizi := await _uyan_balik(func(b: Node2D) -> bool: return b.tur != "mavi_minik")
	_expect(kirmizi != null, "ilgisiz balık bulundu")
	if kirmizi:
		var tur: String = kirmizi.tur
		yalniz_birak(kirmizi)
		_expect(await kovala(kirmizi), "ağ ilgisiz balığı yakaladı")
		await teslim_bekle()
		_expect(game.kayit.akvaryum.has(tur), "ilk kez yakalanan ilgisiz tür akvaryuma girdi")
		uretime_devam()
		var ikinci := await _uyan_balik(func(b: Node2D) -> bool: return b.tur == tur)
		if ikinci:
			yalniz_birak(ikinci)
			_expect(await kovala(ikinci), "ağ bilinen türü yakaladı")
			await teslim_bekle()
			await frames(30)
			_expect(ikinci in game.uretici.baliklar and ikinci.get_parent() == game.uretici, "bilinen ilgisiz tür suya döndü")
			_expect(game.gorev.gereksinimler[0]["dolu"] == 0, "ilgisiz balık göreve sayılmadı")
	uretime_devam()
	var mavi := await _uyan_balik(func(b: Node2D) -> bool: return b.tur == "mavi_minik")
	if mavi:
		yalniz_birak(mavi)
	_expect(mavi != null and await kovala(mavi), "görev balığı yakalandı")
	await teslim_bekle()
	_expect(game.gorev.gereksinimler[0]["dolu"] == 1, "görev balığı simgeyi doldurdu")
	_expect(game._kovadakiler.size() == 1, "görev balığı kovada")
	uretime_devam()


func _denizanasi_denetle() -> void:
	game.kayit.bolum = 4
	game._bolumu_kur()
	await frames(20)
	# Derinde yüzen bir balık: ağ yakaladıktan sonra bir süre suda kalsın
	var balik := await _uyan_balik(func(b: Node2D) -> bool: return b.position.y > game.yuzey_y + 280.0)
	if balik:
		yalniz_birak(balik)
		for d in game.uretici.denizanalari:
			d.global_position = Vector2(-500, -500)
	if balik == null or not await kovala(balik):
		_expect(false, "denizanası testi için balık yakalanamadı")
		return
	# Denizanasını ağın yoluna koy
	var d: Node2D = game.uretici.denizanalari[0]
	game._gidik_bekleme = 0.0
	d.global_position = game.olta.torba()
	await frames(3)
	_expect(game.olta.icerik == null, "denizanası ağdaki balığı kaçırdı")
	_expect(balik in game.uretici.baliklar, "kaçan balık suya döndü")
	d.global_position = Vector2(-500, -500)
	uretime_devam()
	await frames(60)


func _cop_denetle() -> void:
	game.kayit.bolum = 3
	game._bolumu_kur()
	await frames(20)
	_expect(game.su_yuzeyi.bulaniklik > 0.9, "çöp bölümünde su başta bulanık")
	var ilk_cop: int = game.uretici.kalan_cop()
	# Ağa en yakın çöp (yolda başka çöp toplanırsa o da sayılır)
	var copler: Array = game.uretici.copler.duplicate()
	var torba: Vector2 = game.olta.torba()
	copler.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(torba) < b.global_position.distance_to(torba))
	yalniz_birak(null)
	await kovala(copler[0])
	await teslim_bekle()
	await frames(80)
	_expect(game.uretici.kalan_cop() == ilk_cop - 1, "çöp sudan çıktı")
	_expect(game.su_yuzeyi.bulaniklik < 0.9 and game.su.berraklik > 0.1, "su biraz berraklaştı")
	_expect(game.gorev.gereksinimler[0]["dolu"] == 1, "çöp görevi saydı")
	uretime_devam()


func _duraklat_akvaryum_denetle() -> void:
	tap(game._duraklat.get_global_rect().get_center())
	await frames(5)
	_expect(game.get_tree().paused and game._perde.visible, "duraklatma")
	tap(game._devam.get_global_rect().get_center())
	await frames(5)
	_expect(not game.get_tree().paused, "devam")
	tap(game._akvaryum_simge.get_global_rect().get_center())
	await frames(30)
	_expect(game._akvaryum.acik_mi() and game.get_tree().paused, "akvaryum açıldı, oyun durdu")
	_expect(game._akvaryum._yuzenler.size() == game.kayit.akvaryum.size(), "akvaryumda yakalanan türler yüzüyor")
	_expect(game._akvaryum._hucreler.size() == Turler.SIRA.size(), "ızgarada bütün türler")
	tap(game._akvaryum._kapat.get_global_rect().get_center())
	await frames(30)
	_expect(not game._akvaryum.acik_mi() and not game.get_tree().paused, "akvaryum kapandı, oyun sürüyor")


# Bir bölümü oynar: görevdeki nesneleri kovalar. Bölüm bitince sayaç tam bir artmalı ve kaydedilmeli.
func _bolum_oyna(i: int) -> bool:
	await _sakin_bekle()
	var bas: int = game.kayit.bolum
	_expect(bas == i, "sıradaki bölüm %d (kayıttaki %d)" % [i + 1, bas])
	var deneme := 0
	while game.kayit.bolum == bas and deneme < 60:
		deneme += 1
		if game.durum != game.Durum.OYUN:
			await frames(10)
			continue
		var hedef: Node2D = null
		for k in game.gorev.gereksinimler:
			if k["dolu"] >= int(k["g"]["adet"]):
				continue
			if k["g"].get("cop", false):
				if not game.uretici.copler.is_empty():
					hedef = game.uretici.copler[0]
			else:
				var g: Dictionary = k["g"]
				hedef = await _uyan_balik(func(b: Node2D) -> bool: return Turler.eslesir(g, b.bilgi()))
			if hedef:
				break
		if hedef == null:
			await frames(30)
			continue
		if await kovala(hedef):
			await teslim_bekle()
	await _bekle(func() -> bool: return game.kayit.bolum != bas, 900)
	if game.kayit.bolum != bas + 1:
		_expect(false, "bölüm %d sonrası sayaç %d (beklenen %d)" % [i + 1, game.kayit.bolum, bas + 1])
		return false
	var ayar := ConfigFile.new()
	ayar.load(Kayit.PATH)
	_expect(int(ayar.get_value("ilerleme", "bolum", -1)) == bas + 1, "bölüm %d sonrası kayıt" % (i + 1))
	print("bölüm %d tamam" % (i + 1))
	return true


# Kutlama ve teslimler bitene, yeni bölüm kurulana kadar bekler
func _sakin_bekle() -> void:
	await _bekle(func() -> bool: return game.durum == game.Durum.OYUN and not game.olta.kilitli and game.olta.icerik == null, 1200)
	await frames(5)


func _bekle(kosul: Callable, en_fazla: int) -> void:
	for i in en_fazla:
		if kosul.call():
			return
		await process_frame


func touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)


func drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = pos
	root.push_input(ev, true)


func tap(pos: Vector2) -> void:
	touch(pos, true)
	touch(pos, false)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("HATA: " + message)
