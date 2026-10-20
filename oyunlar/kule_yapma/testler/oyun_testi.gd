extends SceneTree
# Kule Yapma oynanış testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://oyunlar/kule_yapma/testler/oyun_testi.gd
# Denetler: bölüm verisi; karar kuralları (mükemmel, mıknatıs, kaymış, devril); kaymış kat bırakıldığı yerde kalır ve
# kuleyi eğer; mükemmel eğimi düzeltir; devrilen kat 1 kalp götürür; eğim sınırı aşılınca üst kat düşer, 1 kalp;
# art arda 3 mükemmel 1 kalp geri verir; kalpler bitince yıkılış, ulaşılan kat ve "tekrar dene" (aynı bölüm);
# duraklatma; 12 bölüm dokunarak bitirilir, apartmanlar ve ilerleme kaydedilir; sonsuz modda rekor; galeri.
# user://kule_yapma.cfg başta yedeklenir, sonda geri yazılır. Hata varsa çıkış kodu 1.

const Bolumler := preload("res://oyunlar/kule_yapma/bolumler.gd")
const Kayit := preload("res://oyunlar/kule_yapma/kayit.gd")

var failures := 0
var game: Node
var _yedek: PackedByteArray
var _yedek_var := false


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	var bitmisti := OyunBitti.tamamlandi_mi("kule_yapma")
	OyunBitti.sifirla("kule_yapma")
	root.content_scale_size = Vector2i(720, 1280)
	_yedek_var = FileAccess.file_exists(Kayit.PATH)
	if _yedek_var:
		_yedek = FileAccess.get_file_as_bytes(Kayit.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Kayit.PATH))
	_veri_denetle()
	game = load("res://oyunlar/kule_yapma/kule_yapma.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	_expect(game.durum == game.Durum.GIRIS, "giriş ekranıyla açılır")
	tap(game._oynat.get_global_rect().get_center())
	await frames(10)
	_expect(game.durum == game.Durum.OYUN and game._kalp == 3, "oyun 3 kalple başlar")
	_karar_denetle()
	await _kaymis_ve_mukemmel_denetle()
	await _devril_denetle()
	await _egim_denetle()
	await _kalp_kazan_denetle()
	await _yikilis_denetle()
	await _duraklat_denetle()
	# Hazırlık denetimleri bölüm ilerlemesini değiştirmiş olabilir: 1. bölümden başla
	game.kayit.bolum = 0
	game.kayit.kaydet()
	await yeniden()
	for i in Bolumler.LEVELS.size():
		if not await _bolum_oyna(i):
			break
	await _sonsuz_denetle()
	await _galeri_denetle()
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
		OyunBitti.tamamla("kule_yapma")
	else:
		OyunBitti.sifirla("kule_yapma")
	quit(1 if failures > 0 else 0)


func _veri_denetle() -> void:
	_expect(Bolumler.validate().is_empty(), "bölüm verisi geçerli: %s" % [Bolumler.validate()])
	_expect(Bolumler.LEVELS.size() >= 12, "en az 12 bölüm")
	_expect(is_equal_approx(Bolumler.LEVELS[0]["miknatis"], 0.15) and is_equal_approx(Bolumler.LEVELS.back()["miknatis"], 0.05), "mıknatıs %15 → %5")
	for i in range(1, Bolumler.LEVELS.size()):
		var a: Dictionary = Bolumler.LEVELS[i - 1]
		var b: Dictionary = Bolumler.LEVELS[i]
		_expect(b["hedef"] >= a["hedef"] and b["hiz"] >= a["hiz"] and b["miknatis"] <= a["miknatis"] and b["egim_siniri"] <= a["egim_siniri"],
			"bölüm %d zorluğu yavaş artar" % (i + 1))


# Karar kuralları (kule tam dikken, zemin katın üstünde)
func _karar_denetle() -> void:
	var kule: Node2D = game.kule
	var tepe: Vector2 = kule.tepe()
	var eski_rot: float = kule.rotation
	kule.sallanma = false
	kule.rotation = 0.0
	tepe = kule.tepe()
	_expect(kule.karar(tepe + Vector2(6, 0), 0.15, 240.0)["tur"] == "mukemmel", "12 px içinde mükemmel")
	var o: Dictionary = kule.karar(tepe + Vector2(30, 0), 0.15, 240.0)
	_expect(o["tur"] == "oturur" and is_zero_approx(o["x"]), "mıknatıs payında ortaya kayar")
	var k: Dictionary = kule.karar(tepe + Vector2(80, 0), 0.15, 240.0)
	_expect(k["tur"] == "kayik" and absf(k["x"] - 80.0) < 0.5, "mıknatıs dışında bırakıldığı yerde kalır")
	var d: Dictionary = kule.karar(tepe + Vector2(-140, 0), 0.15, 240.0)
	_expect(d["tur"] == "devril" and d["yon"] < 0 and d["temas"], "ağırlık merkezi kenarın dışında devrilir")
	_expect(not kule.karar(tepe + Vector2(400, 0), 0.15, 240.0)["temas"], "çok uzak kat kenara değmeden düşer")
	_expect(kule.karar(tepe + Vector2(80, 0), 0.05, 240.0)["tur"] == "kayik", "dar mıknatısta 80 px kaymış kalır")
	kule.rotation = eski_rot
	kule.sallanma = true


# Katın tepeye göre kaymasını (kat genişliği cinsinden, işaretli) bekleyip dokunur
func birak_kayma(oran_min: float, oran_max: float) -> bool:
	await bekle(func() -> bool: return game.vinc.hazir, 400)
	var bulundu := false
	for i in 1500:
		if game.vinc.asili != null:
			var k: float = (game.vinc.asili.global_position.x - game.kule.tepe().x) / game.vinc.asili.genislik()
			if k >= oran_min and k <= oran_max:
				bulundu = true
				break
		await process_frame
	tap(Vector2(360, 900))
	return bulundu


func mukemmel_birak() -> void:
	await bekle(func() -> bool: return game.vinc.hazir, 400)
	await bekle(func() -> bool: return game.vinc.asili != null and absf(game.vinc.asili.global_position.x - game.kule.tepe().x) < 3.0, 1500)
	tap(Vector2(360, 900))


func kat_bekle() -> void:
	await bekle(func() -> bool: return (game.vinc.hazir and game.durum == game.Durum.OYUN) or game.durum != game.Durum.OYUN, 900)


func level_ayarla(alan: String, deger) -> void:
	game.level = game.level.duplicate()
	game.level[alan] = deger


func yeniden() -> void:
	game._bolumu_hazirla()
	game._oyunu_baslat()
	await frames(5)


func _kaymis_ve_mukemmel_denetle() -> void:
	await birak_kayma(0.22, 0.28)
	await kat_bekle()
	_expect(game.kule.sayi() == 1, "kaymış kat oturdu")
	var x: float = game.kule.katlar[0].position.x
	_expect(x > 40.0, "kaymış kat bırakıldığı yerde kaldı (%.0f px)" % x)
	var egim: float = game.kule.egim()
	_expect(egim > 0.15, "kaymış kat kuleyi eğdi (%.2f)" % egim)
	await mukemmel_birak()
	await kat_bekle()
	_expect(game.kule.sayi() == 2 and game.kule.egim() < egim - 0.05, "mükemmel eğimi düzeltti (%.2f → %.2f)" % [egim, game.kule.egim()])
	_expect(game._kalp == 3, "kalp gitmedi")


func _devril_denetle() -> void:
	# Büyük sallanmayla ağırlık merkezi kenarın dışında bırak
	await yeniden()
	game.vinc.aci = 1.2
	var sayi: int = game.kule.sayi()
	var ok := await birak_kayma(0.6, 0.9)
	_expect(ok, "devrilme için yeterince uçta bırakıldı")
	await kat_bekle()
	await frames(10)
	_expect(game.kule.sayi() == sayi, "devrilen kat kuleye eklenmedi")
	_expect(game._kalp == 2, "devrilme 1 kalp götürdü (%d)" % game._kalp)
	_expect(game.vinc.asili != null, "devrilmeden sonra yeni kat geldi")
	game.vinc.aci = game.level["aci"]


func _egim_denetle() -> void:
	await yeniden()
	level_ayarla("egim_siniri", 0.1)
	await birak_kayma(0.25, 0.3)
	await kat_bekle()
	await frames(10)
	_expect(game.kule.sayi() == 0, "eğim sınırı aşılınca üst kat devrildi")
	_expect(game._kalp == 2, "eğim devrilmesi 1 kalp götürdü")


func _kalp_kazan_denetle() -> void:
	# Kalp 2'deyken art arda 3 mükemmel (hedef geçici büyük: bölüm bitmesin)
	level_ayarla("hedef", 20)
	for i in 3:
		await mukemmel_birak()
		await kat_bekle()
	_expect(game._kalp == 3, "art arda 3 mükemmel 1 kalp geri verdi (%d)" % game._kalp)
	for i in 3:
		await mukemmel_birak()
		await kat_bekle()
	_expect(game._kalp == 3, "kalp en fazla 3")


func _yikilis_denetle() -> void:
	await yeniden()
	level_ayarla("egim_siniri", 0.05)
	var bolum: int = game.kayit.bolum
	for i in 3:
		await birak_kayma(0.25, 0.3)
		await kat_bekle()
	await bekle(func() -> bool: return game.durum == game.Durum.YIKILIS, 300)
	_expect(game.durum == game.Durum.YIKILIS or game.durum == game.Durum.SONUC, "kalpler bitince kule yıkılıyor")
	await bekle(func() -> bool: return game._suzulenler.get_child_count() > 0, 400)
	_expect(game._suzulenler.get_child_count() > 0, "hayvanlar şemsiye/balonla süzülüyor")
	await bekle(func() -> bool: return game.durum == game.Durum.SONUC, 900)
	_expect(game.durum == game.Durum.SONUC and game._sonuc.visible, "sonuç ekranı ve tekrar dene düğmesi")
	_expect(game._sonuc_sayi.text == str(game._en_yuksek), "ulaşılan kat gösteriliyor")
	_expect(game.kayit.bolum == bolum, "kaybedince sonraki bölüme geçilmez")
	tap(game._tekrar.get_global_rect().get_center())
	await bekle(func() -> bool: return game.durum == game.Durum.OYUN and game.vinc.hazir, 600)
	_expect(game.durum == game.Durum.OYUN and game._kalp == 3 and game.kule.sayi() == 0, "tekrar dene aynı bölümü 3 kalple baştan başlatır")
	_expect(game.kayit.bolum == bolum, "tekrar denemede bölüm aynı")


func _duraklat_denetle() -> void:
	tap(game._duraklat.get_global_rect().get_center())
	await frames(5)
	_expect(game.get_tree().paused and game._perde.visible, "duraklatma")
	var sayi: int = game.kule.sayi()
	tap(Vector2(360, 900))
	await frames(40)
	_expect(game.kule.sayi() == sayi, "duraklatılmışken kat bırakılmaz")
	tap(game._devam.get_global_rect().get_center())
	await frames(5)
	_expect(not game.get_tree().paused, "devam")


func _bolum_oyna(i: int) -> bool:
	var bas: int = game.kayit.bolum
	_expect(bas == i, "sıradaki bölüm %d (kayıttaki %d)" % [i + 1, bas])
	var hedef := int(Bolumler.level(i)["hedef"])
	var deneme := 0
	while game.durum == game.Durum.OYUN and deneme < 60:
		deneme += 1
		await mukemmel_birak()
		await kat_bekle()
	_expect(game.kule.sayi() == hedef, "bölüm %d: %d kat (hedef %d)" % [i + 1, game.kule.sayi(), hedef])
	_expect(game.kule.cati_var(), "bölüm %d: son kat çatı" % (i + 1))
	if i == Bolumler.LEVELS.size() - 1:
		# Son bölüm: bölüm sonu paneli yerine ortak final ekranı; oradan sonsuz moda geçilir
		await bekle(func() -> bool: return OyunBitti.acik, 600)
		_expect(OyunBitti.acik and OyunBitti.tamamlandi_mi("kule_yapma"), "son bölümden sonra final ekranı, oyun tamamlandı")
		await _final_dugmesi("sonsuz")
		await bekle(func() -> bool: return game.durum == game.Durum.OYUN and game.vinc.hazir, 600)
		_expect(not OyunBitti.acik and game.kayit.bolum == Bolumler.LEVELS.size(), "final → sonsuz mod başladı")
		print("bölüm %d tamam" % (i + 1))
		return true
	await bekle(func() -> bool: return game.durum == game.Durum.SONU, 600)
	if game.durum != game.Durum.SONU:
		_expect(false, "bölüm %d sonu paneli açılmadı (durum %d, kalp %d)" % [i + 1, game.durum, game._kalp])
		return false
	var ayar := ConfigFile.new()
	ayar.load(Kayit.PATH)
	_expect(int(ayar.get_value("ilerleme", "bolum", -1)) == i + 1, "bölüm %d sonrası kayıt" % (i + 1))
	var liste: Array = ayar.get_value("apartmanlar", "liste", [])
	_expect(liste.size() >= i + 1 and liste.back().has("x"), "bölüm %d apartmanı (kaymalarla) kaydedildi" % (i + 1))
	if i == 0:
		tap(game._sonu_apartman.get_global_rect().get_center())
		await frames(30)
		_expect(game._apartman.acik_mi(), "apartman görünümü açıldı")
		var blok: Node2D = game._apartman._bloklar[1]
		tap(blok.to_global(blok._pencereler[0]))
		await frames(5)
		_expect(blok._mesgul[0], "pencereye dokununca hayvan iş yapıyor")
		tap(game._apartman._kapat.get_global_rect().get_center())
		await frames(30)
		_expect(game.durum == game.Durum.SONU, "apartmandan bölüm sonuna dönüldü")
	tap(game._sonu_devam.get_global_rect().get_center())
	await bekle(func() -> bool: return game.durum == game.Durum.OYUN and game.vinc.hazir, 600)
	print("bölüm %d tamam" % (i + 1))
	return true


func _sonsuz_denetle() -> void:
	_expect(Bolumler.sonsuz_mu(game.kayit.bolum), "12 bölümden sonra sonsuz mod")
	_expect(int(game.level["hedef"]) == 0, "sonsuz modda hedef yok")
	for i in 6:
		await mukemmel_birak()
		await kat_bekle()
	_expect(game.durum == game.Durum.OYUN, "sonsuz mod bitmez")
	_expect(game.kayit.rekor == game.kule.sayi() and game.kayit.rekor >= 6, "rekor kaydedildi (%d)" % game.kayit.rekor)


func _galeri_denetle() -> void:
	var sayi: int = game.kayit.apartmanlar.size()
	game._geri_basildi()
	await frames(20)
	_expect(game.durum == game.Durum.GIRIS, "geri giriş ekranına döner")
	_expect(game.kayit.apartmanlar.size() == sayi + 1, "sonsuz moddan çıkınca kule apartmanlara eklendi")
	tap(game._galeri_dugme.get_global_rect().get_center())
	await frames(20)
	_expect(game._galeri.acik_mi() and game._galeri._kartlar.size() == game.kayit.apartmanlar.size(), "galeri bütün apartmanları gösterir")
	tap(game._galeri._kartlar[0]["rect"].get_center() + Vector2(0, 150))
	await frames(30)
	_expect(game._apartman.acik_mi(), "galeriden apartman açıldı")
	tap(game._apartman._kapat.get_global_rect().get_center())
	await frames(30)
	_expect(game._galeri.acik_mi(), "apartmandan galeriye dönüldü")


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
