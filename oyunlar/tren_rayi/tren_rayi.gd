extends Node2D
# Tren Rayı ana sahnesi: giriş ekranı ↔ oyun. Katmanları kurar, dokunmayı yönlendirir, trenin yolculuğunu
# (yolcu durakları, eksik yolda "?" ve geri dönüş) ve bölüm sonu kutlamasını yönetir.
# Tasarım TASARIM.md'de, notlar CLAUDE.md'de.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Hamle olmazsa yanlış yöndeki parçanın sallanması için süre (sn)
@export var hint_delay: float = 9.0
## Trenin hızı (hücre / sn)
@export var tren_hizi: float = 2.3

const Bolumler := preload("res://oyunlar/tren_rayi/bolumler.gd")
const Baglanti := preload("res://oyunlar/tren_rayi/baglanti.gd")
const Yonetici := preload("res://oyunlar/tren_rayi/bolum_yoneticisi.gd")
const Izgara := preload("res://oyunlar/tren_rayi/izgara.gd")
const ArkaPlan := preload("res://oyunlar/tren_rayi/arka_plan.gd")
const Tren := preload("res://oyunlar/tren_rayi/tren.gd")
const Efektler := preload("res://oyunlar/tren_rayi/efektler.gd")
const Kutlama := preload("res://oyunlar/tren_rayi/kutlama.gd")
const GirisEkrani := preload("res://oyunlar/tren_rayi/giris_ekrani.gd")
const Sesler := preload("res://oyunlar/tren_rayi/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const G := "res://oyunlar/tren_rayi/gorseller/"
# Tren sesleri ortak seslerden (SesYoneticisi): "çuf çuf" döngüsü trenin o anki hızını izler
const CUF := "tren_cufcuf"
const CUF_PERDE_YAVAS := 0.7     # tren yeni kalkarken / dururken döngünün hızı
const CUF_PERDE_HIZLI := 1.3     # tren en hızlıyken
const CUF_DB_YAVAS := -16.0
const CUF_DB_HIZLI := -4.0
const DUDUK_DB := -5.0
const FREN_DB := -9.0

enum Durum { GIRIS, OYUN, YOLCULUK, KUTLAMA }

var yonetici := Yonetici.new()
var durum := Durum.GIRIS
var izgara: Node2D
var tren: Node2D

var _ekran := Vector2(1280, 720)
var _sesler: Node
var _dunya: Node2D
var _arka: Node2D
var _efektler: Node2D
var _giris: Node2D
var _ui: Control
var _geri: Control
var _geri_parmak := -1
var _yeniden: Control
var _hareket: TextureRect
var _kutlama: Control
var _soru: Sprite2D
var _baslangic_s := 0.0
var _bosta := 0.0
var _oturum := 0                 # ekran değişince süren yolculuk/kutlama beklemeleri iptal olsun diye
var _zaman := 0.0
var _rng := RandomNumberGenerator.new()
var _cuf_caliyor := false
var _onceki_mesafe := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ekran = get_viewport_rect().size
	_rng.randomize()
	for hata in Bolumler.validate():
		push_error("Tren Rayı: " + hata)
	yonetici.yukle()
	_sesler = Sesler.new()
	add_child(_sesler)
	_dunya = Node2D.new()
	add_child(_dunya)
	_giris = GirisEkrani.new()
	_giris.sesler = _sesler
	add_child(_giris)
	var ui_katmani := CanvasLayer.new()
	ui_katmani.layer = 5
	add_child(ui_katmani)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ui.size = _ekran
	ui_katmani.add_child(_ui)
	_kutlama = Kutlama.new()
	_kutlama.size = _ekran
	_kutlama.sesler = _sesler
	_ui.add_child(_kutlama)
	_yeniden = _yuvarlak_dugme(load(G + "yeniden.svg"), 104.0)
	_yeniden.position = Vector2(_ekran.x - 140.0, 24.0)
	_ui.add_child(_yeniden)
	EkranYardimcisi.guvenliye_it(_yeniden)
	_hareket = TextureRect.new()
	_hareket.texture = load(G + "hareket.svg")
	_hareket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hareket.size = Vector2(150, 150)
	_hareket.pivot_offset = _hareket.size * 0.5
	_hareket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hareket)
	_giris_ekranina()
	IpucuEli.ekle(self, "tren_rayi", _ipucu)
	OyunBitti.kisayol(self, func() -> void:
		if durum == Durum.OYUN:
			_kutla(false))
	if OyunBitti.tamamlandi_mi("tren_rayi"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "tren_rayi", "karakter": load(G + "lokomotif.svg"), "bolum_sayisi": Bolumler.LEVELS.size(),
		"kisa": kisa, "bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	yonetici.bolum = index
	yonetici.kaydet()
	if durum == Durum.GIRIS:
		_oyuna_basla()
	else:
		_bolumu_kur()
		create_tween().tween_property(_dunya, "modulate:a", 1.0, 0.35)


# İpucu eli: yol tamamsa yeşil "hareket" düğmesine, değilse çözüm yolundaki yanlış yöndeki ilk raya dokun
# (izgara.ipucu() ile aynı seçim, ama parçayı sallamadan)
func _ipucu() -> Dictionary:
	if durum != Durum.OYUN or izgara == null:
		return {}
	if izgara.tamam:
		return IpucuEli.dokun(IpucuEli.ekran_konumu(_hareket))
	for h in izgara._cozum_sirasi:
		var parca: Node2D = izgara.parcalar[h]
		var cozum: Dictionary = izgara.bolum["cozum"][h]
		if not parca.sabit and Baglanti.acikliklar(parca.tip, parca.yon) != Baglanti.acikliklar(cozum["tip"], cozum["yon"]):
			return IpucuEli.dokun(IpucuEli.ekran_konumu(parca), 1)
	return {}


func _yuvarlak_dugme(simge: Texture2D, cap: float) -> Control:
	var dugme := Control.new()
	dugme.size = Vector2(cap, cap)
	dugme.pivot_offset = dugme.size / 2.0
	dugme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dugme.draw.connect(func() -> void:
		var c := dugme.size / 2.0
		var r := cap / 2.0 - 5.0
		dugme.draw_circle(c + Vector2(0, 6), r, Color(0.2, 0.1, 0.3, 0.2))
		dugme.draw_circle(c, r, Color(1, 1, 1, 0.95))
		dugme.draw_arc(c, r, 0.0, TAU, 48, Color(0.23, 0.18, 0.42), 5.0, true)
		dugme.draw_texture_rect(simge, Rect2(c - Vector2(r, r) * 0.66, Vector2(r, r) * 1.32), false))
	return dugme


# Her ekranda yeni geri düğmesi (bir kez dolunca kilitlenir)
func _geri_dugmesi_kur() -> void:
	if _geri:
		_geri.queue_free()
	_geri = HoldButton.new()
	_geri.size = Vector2(104, 104)
	_geri.position = Vector2(36, 24)
	_geri.hold_time = 0.6
	_geri.completed.connect(_geri_basildi)
	_ui.add_child(_geri)
	_geri_parmak = -1


# --- Ekranlar ---

func _giris_ekranina() -> void:
	_oturum += 1
	durum = Durum.GIRIS
	_dunya.visible = false
	for c in _dunya.get_children():
		c.queue_free()
	izgara = null
	tren = null
	_giris.visible = true
	_giris.kur(_ekran, yonetici.vagonlar(Yonetici.GIRISTE_VAGON))
	_yeniden.visible = false
	_hareket.visible = false
	_geri_dugmesi_kur()


func _oyuna_basla() -> void:
	_sesler.play("dokun")
	_giris.visible = false
	for c in _giris.get_children():
		c.queue_free()
	_dunya.visible = true
	_bolumu_kur()
	_yeniden.visible = true
	_hareket.visible = true
	_geri_dugmesi_kur()
	_dunya.modulate.a = 0.0
	create_tween().tween_property(_dunya, "modulate:a", 1.0, 0.35)


func _bolumu_kur() -> void:
	_oturum += 1
	for c in _dunya.get_children():
		c.queue_free()
	var veri := yonetici.veri()
	var kurulu := Bolumler.kur(veri, _rng)
	_arka = ArkaPlan.new()
	_dunya.add_child(_arka)
	izgara = Izgara.new()
	_dunya.add_child(izgara)
	tren = Tren.new()
	_dunya.add_child(tren)
	_efektler = Efektler.new()
	_dunya.add_child(_efektler)
	izgara.efektler = _efektler
	izgara.kur(kurulu, veri["tema"], _ekran)
	tren.efektler = _efektler
	tren.sesler = _sesler
	tren.kur(yonetici.vagonlar(Yonetici.OYUNDA_VAGON), izgara.hucre)
	var bilgi: Dictionary = izgara.tren_yolu()
	tren.yol = bilgi["yol"]
	_baslangic_s = bilgi["giris_s"] - tren.on_ucu() - izgara.hucre * 0.12
	tren.mesafe = _baslangic_s
	tren.yerlestir()
	_soru = Sprite2D.new()
	_soru.texture = load(G + "soru.svg")
	_soru.scale = Vector2.ZERO
	_dunya.add_child(_soru)
	_hareket_yerlestir()
	_arka.kur(veri["tema"], _ekran, _yasak_alanlar())
	durum = Durum.OYUN
	_bosta = 0.0


func _hareket_yerlestir() -> void:
	var ray_y: float = izgara.giris_noktasi().y
	var yukari := ray_y > _ekran.y * 0.5
	var y: float = ray_y + (-1.0 if yukari else 1.0) * (izgara.hucre * 0.55 + 82.0)
	y = clampf(y, 225.0, _ekran.y - 95.0)
	_hareket.position = Vector2(minf(150.0, izgara.koken.x - 110.0) - 75.0, y - 75.0)
	EkranYardimcisi.guvenliye_it(_hareket)


func _yasak_alanlar() -> Array:
	var h: float = izgara.hucre
	var bosluk: Dictionary = EkranYardimcisi.guvenli_bosluklar()      # köşe düğmeleri çentikten içeri kayar
	var sol: float = 170.0 + float(bosluk["sol"])
	var sag: float = 170.0 + float(bosluk["sag"])
	var yasak: Array = [
		izgara.alan().grow(30.0),
		Rect2(0, izgara.giris_noktasi().y - h * 0.55, izgara.koken.x + 10.0, h * 1.1),
		_hareket.get_rect().grow(16.0),
		Rect2(0, 0, sol, 150), Rect2(_ekran.x - sag, 0, sag, 150),
	]
	var ist: Vector2 = izgara.istasyon_noktasi()
	var yon: Vector2 = Vector2(Baglanti.ADIM[izgara.bolum["cikis_yonu"]])
	var uc: Vector2 = ist + yon * h * Izgara.ISTASYON_BOY
	var kutu := Rect2(ist, Vector2.ZERO).expand(uc)
	yasak.append(kutu.grow(h * 1.05))
	return yasak


func _geri_basildi() -> void:
	if durum == Durum.GIRIS:
		SahneGecis.ana_menuye_don()
	else:
		_giris_ekranina()


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	var dokunma := event as InputEventScreenTouch
	if dokunma == null:
		return
	if not dokunma.pressed:
		if dokunma.index == _geri_parmak and _geri:
			_geri.release()
			_geri_parmak = -1
		return
	if SahneGecis.gecis_suruyor:
		return
	var p := dokunma.position
	if _geri and _geri.contains(p):
		_geri_parmak = dokunma.index
		_geri.press()
		return
	match durum:
		Durum.GIRIS:
			if _giris.dokun(p) == "oyna":
				_oyuna_basla()
		Durum.OYUN:
			_oyunda_dokun(p)


func _oyunda_dokun(p: Vector2) -> void:
	_bosta = 0.0
	if _yeniden.get_global_rect().grow(8.0).has_point(p):
		_sicrat(_yeniden)
		_sesler.play("dokun")
		_bolumu_kur()
		return
	if _hareket.get_global_rect().grow(10.0).has_point(p) or tren.iceriyor_mu(p):
		_sicrat(_hareket)
		_yolculuk()
		return
	var sonuc: int = izgara.dokun(p)
	if sonuc == 1:
		_sesler.play("tik", _rng.randf_range(0.95, 1.08))
		var onceki: bool = izgara.tamam
		if izgara.parlama_guncelle() and not onceki:
			_sesler.play("tamam")
	elif sonuc == 0:
		_sesler.play("civata")


func _sicrat(kontrol: Control) -> void:
	var tween := kontrol.create_tween()
	tween.tween_property(kontrol, "scale", Vector2(0.9, 0.9), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(kontrol, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Yolculuk ---

func _yolculuk() -> void:
	durum = Durum.YOLCULUK
	var oturum := _oturum
	var bilgi: Dictionary = izgara.tren_yolu()
	tren.yol = bilgi["yol"]
	var h: float = izgara.hucre
	var hiz := tren_hizi * h
	SesYoneticisi.efekt("tren_duduk", DUDUK_DB)
	await get_tree().create_timer(0.35).timeout
	if oturum != _oturum:
		return
	if bilgi["tamam"]:
		# Yolcuların yanında durup onları alır
		var alinan := 0
		for durak in bilgi["duraklar"]:
			await tren.git(durak["s"], hiz)
			if oturum != _oturum:
				return
			SesYoneticisi.efekt("tren_fren", FREN_DB)
			var yolcu: Node2D = izgara.yolcu_al(durak["hucre"])
			if yolcu:
				await get_tree().create_timer(0.2).timeout
				_sesler.play("yolcu")
				await tren.yolcu_bindir(yolcu)
				alinan += 1
				_efektler.parilti(yolcu.global_position, Color("fff6b0"), 8, h * 0.3)
			await get_tree().create_timer(0.25).timeout
			if oturum != _oturum:
				return
		var durak_s: float = bilgi["yol"].uzunluk() - tren.on_ucu()
		await tren.git(durak_s, hiz)
		if oturum != _oturum:
			return
		# İstasyona varış: yumuşak duruş ve neşeli düdük
		SesYoneticisi.efekt("tren_fren", FREN_DB)
		SesYoneticisi.efekt("tren_duduk", DUDUK_DB)
		await _kutla(alinan > 0 and alinan == bilgi["yolcu_sayisi"])
	else:
		# Eksik noktada nazikçe durur, "?" çıkar, yavaşça başlangıca döner
		var hedef: float = maxf(bilgi["son"] - tren.on_ucu() - h * 0.04, tren.mesafe + h * 0.1)
		await tren.git(hedef, hiz * 0.85)
		if oturum != _oturum:
			return
		SesYoneticisi.efekt("tren_fren", FREN_DB)
		await _soru_goster()
		if oturum != _oturum:
			return
		await tren.git(_baslangic_s, hiz * 0.55)
		if oturum != _oturum:
			return
		tren.yol = izgara.tren_yolu()["yol"]
		durum = Durum.OYUN
		_bosta = 0.0


func _soru_goster() -> void:
	var h: float = izgara.hucre
	_soru.position = tren.loko_konumu() + Vector2(0, -h * 0.95)
	var boy := h * 0.9 / _soru.texture.get_width()
	_sesler.play("soru")
	var tween := _soru.create_tween()
	tween.tween_property(_soru, "scale", Vector2.ONE * boy, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_soru, "rotation", 0.12, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_soru, "rotation", -0.12, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_soru, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.5)
	tween.tween_property(_soru, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished


func _kutla(ek_yildiz: bool) -> void:
	durum = Durum.KUTLAMA
	var oturum := _oturum
	_kutlama.efektler = _efektler
	_kutlama.oyna(izgara, tren, _ekran, ek_yildiz)
	await get_tree().create_timer(2.8).timeout
	if oturum != _oturum:
		return
	# Yeni vagon trenin sonuna eklenir
	var vagon: Node2D = tren.vagon_ekle(Tren.vagon_adi(yonetici.vagon))
	_sesler.play("vagon")
	_efektler.parilti(vagon.global_position, Color("fff6b0"), 16, izgara.hucre * 0.5)
	yonetici.bitti()
	await get_tree().create_timer(1.6).timeout
	if oturum != _oturum:
		return
	if yonetici.bolum % Bolumler.LEVELS.size() == 0:
		_oyun_bitti(false)          # 20. bölüm bitti: final ekranı (yoksa sessizce 1. bölüme dönülüyordu)
		return
	var tween := create_tween()
	tween.tween_property(_dunya, "modulate:a", 0.0, 0.35)
	await tween.finished
	if oturum != _oturum:
		return
	_bolumu_kur()
	create_tween().tween_property(_dunya, "modulate:a", 1.0, 0.35)


# --- Her kare ---

func _process(delta: float) -> void:
	_zaman += delta
	if durum == Durum.OYUN and izgara:
		# Yol tamamsa hareket düğmesi nabız gibi atar
		var nabiz := 1.0 + (sin(_zaman * 6.0) * 0.06 if izgara.tamam else sin(_zaman * 2.0) * 0.02)
		_hareket.scale = Vector2.ONE * nabiz
		_bosta += delta
		if _bosta > hint_delay:
			_bosta = 0.0
			izgara.ipucu()
	_cuf_guncelle(delta)


# "Çuf çuf" döngüsü: tren hareket ederken çalar; perdesi (ve temposu) ile seviyesi trenin o anki hızına bağlıdır
func _cuf_guncelle(delta: float) -> void:
	var oran := 0.0
	if is_instance_valid(tren) and izgara and tren.hareket_ediyor and delta > 0.0:
		# 1.0 = ortalama yolculuk hızı; yumuşak kalkış ve duruş yüzünden tepe hız bunun ~1.6 katı
		oran = absf(tren.mesafe - _onceki_mesafe) / delta / (tren_hizi * izgara.hucre)
	if is_instance_valid(tren):
		_onceki_mesafe = tren.mesafe
	if oran < 0.04:
		if _cuf_caliyor:
			_cuf_caliyor = false
			SesYoneticisi.dongu_durdur(CUF, 0.25)
		return
	var t := clampf(oran / 1.6, 0.0, 1.0)
	if not _cuf_caliyor:
		_cuf_caliyor = true
		SesYoneticisi.dongu_baslat(CUF, CUF_DB_YAVAS, CUF_PERDE_YAVAS)
	SesYoneticisi.dongu_perde(CUF, lerpf(CUF_PERDE_YAVAS, CUF_PERDE_HIZLI, t))
	SesYoneticisi.dongu_seviye(CUF, lerpf(CUF_DB_YAVAS, CUF_DB_HIZLI, sqrt(t)))


func _exit_tree() -> void:
	SesYoneticisi.dongu_durdur(CUF, 0.1)
