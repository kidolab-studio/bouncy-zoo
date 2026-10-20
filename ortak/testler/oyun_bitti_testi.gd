extends SceneTree
# Final ekranı testi. Önce ortak bileşen (kutlama, kayıt, düğmeler, ızgara, dokunuşların alta geçmemesi), sonra
# her bölümlü oyun: F9 geliştirici kısayoluyla bölümler bitirilir → final ekranı gelir mi, "tamamlandı" yazılır mı,
# "Baştan oyna" 1. bölümü açar mı, "Bölüm seç" çalışır mı, oyun yeniden açılınca kısa final gelir mi, menüde kupa
# rozeti var mı, Lisanslar ekranındaki "ilerlemeyi sıfırla" kupayı ve kaydı siler mi.
#   godot --headless --path . --fixed-fps 60 -s res://ortak/testler/oyun_bitti_testi.gd [-- oyun ...]
#   Pencereli ve "-- cek <klasör>" ile final ekranının ve bölüm ızgarasının görüntüsü kaydedilir.
# user:// kökündeki dosyalar yedeklenir, sonunda geri yazılır; testin oluşturdukları silinir.

const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const MENU := "res://ana_menu/ana_menu.tscn"

# Bölümlü oyunlar: oyunun ilk ekranından bölüm oynamaya geçmek için dokunulacak düğüm yolları (ekran_uyumu_testi
# biçiminde) ve "Baştan oyna"dan sonra o anki bölümü veren ifade (oyun düğümünden okunur).
const OYUNLAR := {
	"yol_yap": {"giris": ["level_buttons.0"], "bolum": "level_index"},
	"hafiza": {"giris": ["level_buttons.0"], "bolum": "level_index"},
	"meyve_topla": {"giris": [Vector2(0.6, 0.6)], "bolum": "levels.level_index"},
	"araba_yarisi": {"giris": ["_garage._play", "_map._nodes.0"], "bolum": "_track_index"},
	"robot_fabrikasi": {"giris": [], "bolum": "manager.index"},
	"tren_rayi": {"giris": ["_giris._oynat"], "bolum": "yonetici.bolum"},
	"balik_tutma": {"giris": [], "bolum": "kayit.bolum"},
	"kule_yapma": {"giris": ["_oynat"], "bolum": "kayit.bolum"},
	"golge_eslestirme": {"giris": [], "bolum": "level_index"},
	"toplama": {"giris": [], "bolum": "level_index"},
	"cikarma": {"giris": [], "bolum": "level_index"},
	"hayvan_besle": {"giris": [], "bolum": "level_index"},
	"buyukten_kucuge": {"giris": [], "bolum": "level_index"},
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
	if DisplayServer.get_name() == "headless":
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
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
	gecis = root.get_node("SahneGecis")
	_yedekle()
	_temizle()
	change_scene_to_file(MENU)
	await _gecis_bekle()
	if secilen.is_empty() or "bilesen" in secilen:
		await _bilesen_testi()
	for ad: String in OYUNLAR:
		if secilen.is_empty() or ad in secilen:
			await _oyun_testi(ad)
	if secilen.is_empty() or "sifirla" in secilen:
		await _sifirlama_testi()
	_geri_yaz()
	print("SONUÇ: ", "hepsi geçti" if hata == 0 else "%d hata" % hata)
	quit(1 if hata > 0 else 0)


# --- Bileşen ---

func _bilesen_testi() -> void:
	var sahne := Node2D.new()
	root.add_child(sahne)
	var sonuc := {"bolum": -1, "bastan": 0, "sonsuz": 0, "alta": 0}
	# Alttaki oyun: final açıkken dokunuş almamalı
	var alt := _Dinleyici.new()
	alt.say = func() -> void: sonuc["alta"] += 1
	sahne.add_child(alt)
	var ekran := OyunBitti.goster(sahne, {
		"ad": "_deneme", "bolum_sayisi": 12, "yildizlar": [3, 2, 1],
		"bolum_baslat": func(b: int) -> void: sonuc["bolum"] = b,
		"bastan": func() -> void: sonuc["bastan"] += 1,
		"sonsuz": func() -> void: sonuc["sonsuz"] += 1,
	})
	await _kareler(2)
	_kontrol(OyunBitti.acik, "bileşen: final ekranı açık")
	_kontrol(OyunBitti.tamamlandi_mi("_deneme"), "bileşen: tamamlandı kaydedildi")
	_kontrol(not ekran._dugmeler[0][0].visible, "bileşen: kutlama sırasında düğmeler gizli")
	await _sn(3.2)
	_kontrol(ekran._dugmeler.size() == 4 and ekran._dugmeler[0][0].visible, "bileşen: 4 düğme göründü (sonsuz dahil)")
	await _goruntu("_bilesen_final")
	_dokun(_orta(ekran._dugmeler[0][0]))
	await _kareler(20)
	_kontrol(ekran._izgara != null and ekran._hucreler.size() == 12, "bileşen: bölüm seç → 12 bölümlük ızgara")
	await _goruntu("_bilesen_izgara")
	_dokun(_orta(ekran._hucreler[2][0]))
	await _sn(0.6)
	_kontrol(sonuc["bolum"] == 2 and not is_instance_valid(ekran), "bileşen: 3. bölüm seçildi, ekran kapandı")
	_kontrol(sonuc["alta"] == 0, "bileşen: dokunuşlar alttaki oyuna geçmedi")
	# Kısa açılış: kayıt yazmaz, düğmeler çabuk gelir; sonsuz yoksa 3 düğme
	OyunBitti.sifirla("_deneme")
	var kisa := OyunBitti.goster(sahne, {"ad": "_deneme", "bolum_sayisi": 3, "kisa": true,
		"bolum_baslat": func(_b: int) -> void: pass, "bastan": func() -> void: sonuc["bastan"] += 1})
	await _sn(1.3)
	_kontrol(not OyunBitti.tamamlandi_mi("_deneme"), "bileşen: kısa açılış kayıt yazmıyor")
	_kontrol(kisa._dugmeler.size() == 3 and kisa._dugmeler[0][0].visible, "bileşen: kısa açılışta 3 düğme (sonsuz yok) 1,3 sn'de hazır")
	_dokun(_orta(kisa._dugmeler[1][0]))
	await _sn(0.6)
	_kontrol(sonuc["bastan"] == 1 and not OyunBitti.acik, "bileşen: baştan oyna çağrıldı, ekran kapandı")
	sahne.queue_free()
	await _kareler(2)


class _Dinleyici extends Node:
	var say: Callable

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			say.call()


# --- Oyunlar ---

func _oyun_testi(ad: String) -> void:
	var oyun := _kayit(ad)
	var bilgi: Dictionary = OYUNLAR[ad]
	_temizle()
	gecis.sahne_degistir(oyun["sahne"])
	await _gecis_bekle()
	var sahne := current_scene
	await _giris_yap(sahne, bilgi["giris"])
	# F9 ile bölümleri bitir: final ekranı gelene kadar (en çok 40 bölüm, her biri en çok 25 sn)
	var gorundu := false
	var basildi := 0
	for k in 40 * 25 * 4:
		if OyunBitti.acik:
			gorundu = true
			break
		if k % 40 == 0:
			_tus(KEY_F9)
			basildi += 1
		await _sn(0.25)
	_kontrol(gorundu, "%s: F9 ile bölümler bitince final ekranı geldi (%d F9)" % [ad, basildi])
	if not gorundu:
		return
	_kontrol(OyunBitti.tamamlandi_mi(ad), "%s: tamamlandı kaydedildi" % ad)
	var ekran := _ekran_bul()
	await _sn(3.0)
	await _goruntu(ad + "_final")
	# Baştan oyna
	_dokun(_orta(_dugme(ekran, "bastan")))
	await _sn(2.5)
	_kontrol(not OyunBitti.acik, "%s: baştan oyna → final kapandı" % ad)
	var bolum: Variant = _oku(current_scene, bilgi["bolum"])
	_kontrol(bolum == 0 or (ad == "araba_yarisi" and bolum == 0), "%s: baştan oyna → 1. bölüm (bölüm=%s)" % [ad, bolum])
	_kontrol(OyunBitti.tamamlandi_mi(ad), "%s: baştan oyna tamamlandı bilgisini silmedi" % ad)
	# Yeniden açılış: kısa final gelir; bölüm seç çalışır
	gecis.sahne_degistir(oyun["sahne"])
	await _gecis_bekle()
	await _sn(1.6)
	_kontrol(OyunBitti.acik, "%s: yeniden açılınca final seçenekleri geldi" % ad)
	ekran = _ekran_bul()
	if ekran == null:
		return
	_dokun(_orta(_dugme(ekran, "secim")))
	await _sn(1.0)
	if is_instance_valid(ekran) and ekran._izgara:
		await _goruntu(ad + "_izgara")
		_dokun(_orta(ekran._hucreler[1][0]))
		await _sn(2.5)
		_kontrol(not OyunBitti.acik and _oku(current_scene, bilgi["bolum"]) == 1, "%s: ızgaradan 2. bölüm açıldı" % ad)
	else:
		_kontrol(not OyunBitti.acik, "%s: bölüm seç → oyunun kendi bölüm seçme ekranı" % ad)
	# Menüde kupa rozeti
	gecis.ana_menuye_don()
	await _gecis_bekle()
	await _sn(1.0)
	var kart: Control = current_scene._kartlar[_sira(ad)]
	_kontrol(kart.find_child("KupaRozeti", true, false) != null, "%s: menü kartında kupa rozeti" % ad)


func _sifirlama_testi() -> void:
	OyunBitti.tamamla("hafiza")
	var f := FileAccess.open("user://hafiza.cfg", FileAccess.WRITE)
	f.store_string("[ilerleme]\n")
	f.close()
	gecis.sahne_degistir(MENU)
	await _gecis_bekle()
	var menu := current_scene
	menu._lisanslari_ac()
	await _sn(0.5)
	var lisans: Control = menu._lisanslar
	var satir := -1
	for k in lisans._sifirlama.size():
		if lisans._sifirlama[k][1]["klasor"] == "hafiza":
			satir = k
	_kontrol(satir >= 0, "sıfırlama: Lisanslar ekranında Hafıza satırı var")
	if satir < 0:
		return
	var etiket: Control = lisans._sifirlama[satir][0]
	_dokun(_orta(etiket))
	_dokun(_orta(etiket), false)
	await _kareler(5)
	_kontrol(OyunBitti.tamamlandi_mi("hafiza"), "sıfırlama: ilk dokunuş silmiyor (onay bekliyor)")
	await _goruntu("_sifirlama_onay")
	_dokun(_orta(etiket))
	_dokun(_orta(etiket), false)
	await _kareler(5)
	_kontrol(not OyunBitti.tamamlandi_mi("hafiza") and not FileAccess.file_exists("user://hafiza.cfg"), "sıfırlama: onaydan sonra kupa ve kayıt silindi")
	lisans.kapat()
	await _sn(1.0)
	await _gecis_bekle()
	await _sn(1.0)
	var kart: Control = current_scene._kartlar[_sira("hafiza")]
	_kontrol(kart.find_child("KupaRozeti", true, false) == null, "sıfırlama: menü yenilendi, kupa rozeti yok")


# --- Yardımcılar ---

func _kayit(ad: String) -> Dictionary:
	return OyunListesi.OYUNLAR[_sira(ad)]


func _sira(ad: String) -> int:
	for k in OyunListesi.OYUNLAR.size():
		if OyunListesi.OYUNLAR[k]["klasor"] == ad:
			return k
	return -1


func _ekran_bul() -> OyunBitti:
	for c in root.get_children():
		if c is OyunBitti:
			return c
	return null


func _dugme(ekran: OyunBitti, eylem: String) -> Control:
	for satir: Array in ekran._dugmeler:
		if satir[1] == eylem:
			return satir[0]
	return null


func _oku(dugum: Object, yol: String) -> Variant:
	var nesne: Variant = dugum
	for parca in yol.split("."):
		nesne = nesne.get(parca)
	return nesne


func _giris_yap(sahne: Node, adimlar: Array) -> void:
	await _sn(0.8)
	for adim in adimlar:
		if adim is Vector2:
			_dokun(root.get_visible_rect().size * (adim as Vector2))
			_dokun(root.get_visible_rect().size * (adim as Vector2), false)
		else:
			var nesne: Variant = sahne
			for parca in (adim as String).split("."):
				nesne = nesne[int(parca)] if parca.is_valid_int() else nesne.get(parca)
			_dokun(_orta(nesne))
			_dokun(_orta(nesne), false)
		await _sn(1.6)


func _gecis_bekle() -> void:
	await _kareler(5)
	for i in 900:
		await process_frame
		if current_scene and not gecis.gecis_suruyor:
			break
	await _kareler(10)


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


func _tus(kod: Key) -> void:
	for basili in [true, false]:
		var olay := InputEventKey.new()
		olay.keycode = kod
		olay.pressed = basili
		root.push_input(olay, true)


func _goruntu(ad: String) -> void:
	if _cek == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_cek.path_join(ad + ".png"))


# --- Kayıtlar ---

# Her oyun testi temiz kayıtla başlar (tamamlandı bilgisi ve oyunun kendi kaydı yok)
func _temizle() -> void:
	for dosya in DirAccess.get_files_at("user://"):
		if dosya.ends_with(".cfg") or dosya.ends_with(".bak") or dosya.ends_with(".tmp"):
			DirAccess.remove_absolute("user://" + dosya)


func _yedekle() -> void:
	for dosya in DirAccess.get_files_at("user://"):
		_yedek[dosya] = FileAccess.get_file_as_bytes("user://" + dosya)


func _geri_yaz() -> void:
	for dosya in DirAccess.get_files_at("user://"):
		if not _yedek.has(dosya):
			DirAccess.remove_absolute("user://" + dosya)
	for dosya: String in _yedek:
		var f := FileAccess.open("user://" + dosya, FileAccess.WRITE)
		f.store_buffer(_yedek[dosya])
		f.close()
