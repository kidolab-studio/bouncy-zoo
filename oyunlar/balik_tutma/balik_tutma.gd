extends Node2D
# Balık Tutma ana sahnesi (dikey): katmanları kurar, dokunmayı yönlendirir, ağa giren nesneye ne olacağına karar
# verir (görevdeyse kova/geri dönüşüm, yeni türse tanıtım + akvaryum, değilse suya geri), denizanası, su
# berraklığı, duraklatma, akvaryum ve bölüm sonu kutlaması. Tasarım TASARIM.md'de, notlar CLAUDE.md'de.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Su yüzeyinin yüksekliği (px, üstten)
@export var yuzey_y: float = 355.0

const Bolumler := preload("res://oyunlar/balik_tutma/bolumler.gd")
const Turler := preload("res://oyunlar/balik_tutma/balik_turleri.gd")
const Kayit := preload("res://oyunlar/balik_tutma/kayit.gd")
const Su := preload("res://oyunlar/balik_tutma/su.gd")
const SuYuzeyi := preload("res://oyunlar/balik_tutma/su_yuzeyi.gd")
const Uretici := preload("res://oyunlar/balik_tutma/balik_uretici.gd")
const Olta := preload("res://oyunlar/balik_tutma/olta.gd")
const Kayik := preload("res://oyunlar/balik_tutma/kayik.gd")
const Balik := preload("res://oyunlar/balik_tutma/balik.gd")
const Gorev := preload("res://oyunlar/balik_tutma/gorev_yoneticisi.gd")
const Akvaryum := preload("res://oyunlar/balik_tutma/akvaryum.gd")
const Kutlama := preload("res://oyunlar/balik_tutma/kutlama.gd")
const Efektler := preload("res://oyunlar/balik_tutma/efektler.gd")
const Sesler := preload("res://oyunlar/balik_tutma/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const G := "res://oyunlar/balik_tutma/gorseller/"

enum Durum { OYUN, KUTLAMA }

var kayit := Kayit.new()
var durum := Durum.OYUN
var level: Dictionary = {}
var su: Node2D
var su_yuzeyi: Node2D
var uretici: Node2D
var olta: Node2D
var kayik: Node2D
var gorev: Control
var efektler: Node2D

var _ekran := Vector2(720, 1280)
var _sesler: Node
var _dunya: Node2D
var _ui: Control
var _geri: Control
var _geri_parmak := -1
var _duraklat: Control
var _perde: Control
var _devam: Control
var _akvaryum_simge: TextureRect
var _akvaryum: Control
var _kutlama: Control
var _parmak := -1
var _duraklatildi := false
var _toplam_cop := 0
var _kovadakiler: Array = []
var _gidik_bekleme := 0.0
var _oturum := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ekran = get_viewport_rect().size
	for hata in Bolumler.validate():
		push_error("Balık Tutma: " + hata)
	kayit.yukle()
	_sesler = Sesler.new()
	add_child(_sesler)
	_dunya = Node2D.new()
	_dunya.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dunya)
	_arayuzu_kur()
	_bolumu_kur()
	IpucuEli.ekle(self, "balik_tutma", _ipucu)


# İpucu eli: kayığın altında suya bas, ekrandaki (kayığa en yakın) balığa doğru sürükle; balık yüzdükçe el izler
func _ipucu() -> Dictionary:
	if durum != Durum.OYUN or _duraklatildi or _akvaryum.acik_mi() or _parmak != -1 or olta == null or olta.icerik != null:
		return {}
	var kayik_x: float = IpucuEli.ekran_konumu(kayik).x
	var en_yakin: Node2D = null
	for balik: Node2D in uretici.baliklar:
		if not is_instance_valid(balik) or not balik.visible:
			continue
		var x: float = IpucuEli.ekran_konumu(balik).x
		if x > 120.0 and x < _ekran.x - 120.0:
			if en_yakin == null or absf(x - kayik_x) < absf(IpucuEli.ekran_konumu(en_yakin).x - kayik_x):
				en_yakin = balik
	if en_yakin == null:
		return {}
	return IpucuEli.surukle(Vector2(kayik_x, yuzey_y + 70.0), IpucuEli.izle(en_yakin))


func _arayuzu_kur() -> void:
	var katman := CanvasLayer.new()
	katman.layer = 5
	add_child(katman)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ui.size = _ekran
	katman.add_child(_ui)
	gorev = Gorev.new()
	gorev.size = _ekran
	_ui.add_child(gorev)
	_kutlama = Kutlama.new()
	_kutlama.size = _ekran
	_kutlama.sesler = _sesler
	_ui.add_child(_kutlama)
	_akvaryum_simge = TextureRect.new()
	_akvaryum_simge.texture = load(G + "akvaryum.svg")
	_akvaryum_simge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_akvaryum_simge.size = Vector2(108, 99)
	_akvaryum_simge.pivot_offset = _akvaryum_simge.size * 0.5
	_akvaryum_simge.position = Vector2(_ekran.x - 262.0, 26.0)
	_akvaryum_simge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_akvaryum_simge)
	_duraklat = _yuvarlak_dugme(load(G + "duraklat.svg"), 104.0)
	_duraklat.position = Vector2(_ekran.x - 140.0, 24.0)
	_ui.add_child(_duraklat)
	_perde = Control.new()
	_perde.size = _ekran
	_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var karart := ColorRect.new()
	karart.color = Color(0.05, 0.1, 0.25, 0.45)
	karart.size = _ekran
	karart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perde.add_child(karart)
	_devam = _yuvarlak_dugme(load(G + "oynat.svg"), 190.0)
	_devam.position = _ekran * 0.5 - _devam.size * 0.5
	_perde.add_child(_devam)
	_perde.visible = false
	_ui.add_child(_perde)
	var ust := CanvasLayer.new()
	ust.layer = 10
	add_child(ust)
	_akvaryum = Akvaryum.new()
	_akvaryum.sesler = _sesler
	_akvaryum.kapandi.connect(_akvaryum_kapandi)
	ust.add_child(_akvaryum)
	_geri = HoldButton.new()
	_geri.size = Vector2(104, 104)
	_geri.position = Vector2(36, 24)
	_geri.hold_time = 0.6
	_geri.completed.connect(_cikis)
	_ui.add_child(_geri)
	# Çentikli telefonlarda sağ üstteki simgeler çentiğin altında kalmasın (aralarındaki düzen bozulmadan)
	EkranYardimcisi.guvenliye_it_grup([_akvaryum_simge, _duraklat])


func _yuvarlak_dugme(simge: Texture2D, cap: float) -> Control:
	var dugme := Control.new()
	dugme.size = Vector2(cap, cap)
	dugme.pivot_offset = dugme.size / 2.0
	dugme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dugme.draw.connect(func() -> void:
		var c := dugme.size / 2.0
		var r := cap / 2.0 - 5.0
		dugme.draw_circle(c + Vector2(0, 6), r, Color(0.1, 0.1, 0.3, 0.2))
		dugme.draw_circle(c, r, Color(1, 1, 1, 0.95))
		dugme.draw_arc(c, r, 0.0, TAU, 48, Color(0.23, 0.18, 0.42), 5.0, true)
		dugme.draw_texture_rect(simge, Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), false))
	return dugme


# --- Bölüm ---

func _bolumu_kur() -> void:
	_oturum += 1
	for c in _dunya.get_children():
		c.queue_free()
	level = Bolumler.level(kayit.bolum)
	var tema: String = level["tema"]
	su = Su.new()
	_dunya.add_child(su)
	su.kur(tema, _ekran, yuzey_y)
	efektler = Efektler.new()
	uretici = Uretici.new()
	uretici.name = "Uretici"
	_dunya.add_child(uretici)
	olta = Olta.new()
	_dunya.add_child(olta)
	kayik = Kayik.new()
	_dunya.add_child(kayik)
	su_yuzeyi = SuYuzeyi.new()
	_dunya.add_child(su_yuzeyi)
	_dunya.add_child(efektler)
	su_yuzeyi.kur(_ekran, yuzey_y, Su.TEMALAR[tema]["su"][0], tema)
	kayik.kur(_ekran, yuzey_y)
	var fener: Sprite2D = efektler.isik(Color(1.0, 0.9, 0.5, 0.8), 200.0) if tema == "derin" else null
	olta.kur(yuzey_y, su.dip_y, tema == "derin", fener)
	olta.yerlestir(kayik.olta_ucu())
	olta.teslim.connect(_teslim)
	olta.suya_girdi.connect(func(x: float) -> void:
		efektler.sicrama(Vector2(x, yuzey_y), 6)
		_sesler.play("dalis"))
	gorev.kur(level["gorev"], _ekran.x)
	uretici.kur(level, _ekran, yuzey_y, su.dip_y, gorev)
	efektler.dip_kabarciklari(_ekran.x, su.dip_y, su.dip_y - yuzey_y)
	_toplam_cop = int(level.get("cop", 0))
	if _toplam_cop > 0:
		su.berraklik = 0.0
		su.berraklik_ayarla(0.0)
		su_yuzeyi.bulaniklik = 1.0
	_kovadakiler.clear()
	_parmak = -1
	durum = Durum.OYUN


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	var dokunma := event as InputEventScreenTouch
	var surukleme := event as InputEventScreenDrag
	if dokunma and not dokunma.pressed:
		if dokunma.index == _geri_parmak:
			_geri.release()
			_geri_parmak = -1
		if dokunma.index == _parmak:
			_parmak = -1
			if olta:
				olta.birak()
		return
	if surukleme:
		if surukleme.index == _parmak and not _duraklatildi:
			_suya_dokun(surukleme.position)
		return
	if dokunma == null or SahneGecis.gecis_suruyor:
		return
	var p := dokunma.position
	if _akvaryum.acik_mi():
		_akvaryum.dokun(p)
		return
	if _geri.contains(p):
		_geri_parmak = dokunma.index
		_geri.press()
		return
	if _duraklatildi:
		if _devam.get_global_rect().has_point(p):
			_sicrat(_devam)
			_duraklat_ayarla(false)
		return
	if _duraklat.get_global_rect().grow(8.0).has_point(p):
		_sicrat(_duraklat)
		_sesler.play("dokun")
		_duraklat_ayarla(true)
		return
	if _akvaryum_simge.get_global_rect().grow(8.0).has_point(p):
		_sicrat(_akvaryum_simge)
		_sesler.play("dokun")
		get_tree().paused = true
		_akvaryum.ac(kayit.akvaryum, _ekran)
		return
	if p.y > yuzey_y - 30.0 and durum == Durum.OYUN and _parmak == -1:
		_parmak = dokunma.index
		_suya_dokun(p)


func _suya_dokun(p: Vector2) -> void:
	if durum != Durum.OYUN:
		return
	olta.parmak(p)
	kayik.parmagi_izle(p.x)


func _sicrat(kontrol: Control) -> void:
	var tween := kontrol.create_tween()
	tween.tween_property(kontrol, "scale", Vector2(0.9, 0.9), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(kontrol, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _duraklat_ayarla(deger: bool) -> void:
	_duraklatildi = deger
	get_tree().paused = deger
	_perde.visible = deger
	_duraklat.visible = not deger
	_parmak = -1
	if olta:
		olta.birak()


func _akvaryum_kapandi() -> void:
	if not _duraklatildi:
		get_tree().paused = false


func _cikis() -> void:
	get_tree().paused = false
	kayit.kaydet()
	SahneGecis.ana_menuye_don()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _perde and not _duraklatildi and not _akvaryum.acik_mi():
		_duraklat_ayarla(true)


# --- Her kare: ağın çarpışmaları ---

func _process(delta: float) -> void:
	if _duraklatildi or olta == null or not is_instance_valid(olta):
		return
	olta.uc = kayik.olta_ucu()
	_gidik_bekleme -= delta
	if durum != Durum.OYUN or not olta.suda_mi() or olta.kilitli:
		return
	var torba: Vector2 = olta.torba()
	var r: float = olta.torba_yaricapi()
	if _gidik_bekleme <= 0.0 and uretici.denizanasi_degiyor(torba, r):
		_gidik_bekleme = 1.2
		_gidikla()
		return
	if olta.icerik == null:
		var nesne: Node2D = uretici.carpisan(torba, r)
		if nesne:
			_yakala(nesne)


func _yakala(nesne: Node2D) -> void:
	uretici.cikar(nesne)
	if nesne is Balik:
		nesne.aga_gir()
	else:
		nesne.serbest = false
	olta.yakala(nesne)
	_parmak = -1
	_sesler.play("yakala")
	efektler.kabarciklar(olta.torba(), 8, 26.0)
	kayik.hal("mutlu", 0.8)


# Denizanası: ağ titrer, içindeki balık yüzüp gider
func _gidikla() -> void:
	_sesler.play("gidik")
	olta.gidikla()
	kayik.hal("saskin", 1.0)
	efektler.kabarciklar(olta.torba(), 6, 30.0)
	if olta.icerik and olta.icerik is Balik:
		var balik: Node2D = olta.icerigi_al()
		balik.kac(uretici)
		uretici.geri_al(balik)


# --- Ağ yukarı çıktı: içindekine karar ver ---

func _teslim(nesne: Node2D) -> void:
	var oturum := _oturum
	olta.icerigi_al()
	if nesne is Balik:
		await _balik_teslim(nesne)
	else:
		await _cop_teslim(nesne)
	if oturum != _oturum:
		return
	olta.kilitli = false
	if gorev.tamam() and durum == Durum.OYUN:
		_bolum_bitti()


func _cop_teslim(cop: Node2D) -> void:
	var yer := cop.global_position
	cop.reparent(_dunya)
	cop.global_position = yer
	await _ucur(cop, kayik.kutu_konumu(), 0.2)
	cop.queue_free()
	kayik.kutu_zipla()
	_sesler.play("cop")
	var simge: Vector2 = gorev.isle({"cop": true})
	if simge != Vector2.INF:
		efektler.parilti(simge, Color("b6f5a0"), 10, 26.0)
	# Su adım adım berraklaşır, bitkiler renklenir, daha çok balık gelir
	var kalan: int = uretici.kalan_cop()
	var temiz := 1.0 - float(kalan) / maxf(1.0, _toplam_cop)
	su.berraklik_ayarla(temiz)
	su_yuzeyi.bulaniklik_ayarla(1.0 - temiz)
	uretici.ek_balik = roundi(temiz * 4.0)
	_sesler.play("temiz")
	efektler.kabarciklar(Vector2(_ekran.x * 0.5, su.dip_y - 60.0), 14, 200.0)


func _balik_teslim(balik: Node2D) -> void:
	var oturum := _oturum
	var tur: String = balik.tur
	var bilgi: Dictionary = balik.bilgi()
	var yeni: bool = kayit.yeni_mi(tur)
	var gerekli: bool = gorev.gerekli_mi(bilgi)
	if gerekli or yeni:
		kayit.ekle(tur)
		kayit.kaydet()
	if yeni:
		# Yeni tür: büyüyerek öne gelir, parlar; görevdeyse kovaya, değilse akvaryuma
		balik.visible = false
		var hedef: Vector2 = kayik.kova_konumu() if gerekli else _akvaryum_simge.get_global_rect().get_center()
		await _kutlama.yeni_tur(tur, balik.global_position, hedef, _ekran)
		if oturum != _oturum or not is_instance_valid(balik):
			return
		if not gerekli:
			_sicrat(_akvaryum_simge)
			balik.queue_free()
			return
		balik.visible = true
	if gerekli:
		kayik.hal("mutlu", 1.0)
		await get_tree().create_timer(0.25, false).timeout
		if oturum != _oturum or not is_instance_valid(balik):
			return
		var yer := balik.global_position
		balik.reparent(_dunya)
		balik.global_position = yer
		await _ucur(balik, kayik.kova_konumu(), 0.35)
		balik.queue_free()
		kayik.kova_zipla()
		_sesler.play("kova")
		efektler.sicrama(kayik.kova_konumu(), 5)
		_kovadakiler.append(tur)
		var simge: Vector2 = gorev.isle(bilgi)
		if simge != Vector2.INF:
			_sesler.play("gorev")
			efektler.parilti(simge, Color("fff6b0"), 12, 30.0)
	else:
		# Görevle ilgisiz, bilinen tür: yüzgecini sallar ve suya geri atlar
		_sesler.play("geri")
		var hedef := Vector2(clampf(balik.global_position.x + 160.0 * (1.0 if randf() < 0.5 else -1.0), 80.0, _ekran.x - 80.0), yuzey_y + 60.0)
		uretici.geri_al(balik)
		balik.suya_don(uretici, hedef)
		await get_tree().create_timer(0.6, false).timeout
		efektler.sicrama(Vector2(hedef.x, yuzey_y), 8)


# Nesne yay çizerek hedefe zıplar ve küçülür
func _ucur(nesne: Node2D, hedef: Vector2, kuculme: float) -> void:
	var bas := nesne.global_position
	var tepe := (bas + hedef) * 0.5 + Vector2(0, -150)
	var olcek := nesne.scale
	var tween := nesne.create_tween()
	tween.tween_method(func(t: float) -> void:
		nesne.global_position = bas.lerp(tepe, t).lerp(tepe.lerp(hedef, t), t)
		nesne.scale = olcek * lerpf(1.0, kuculme, t)
		nesne.rotation = sin(t * PI) * 0.6, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


# --- Bölüm sonu ---

func _bolum_bitti() -> void:
	durum = Durum.KUTLAMA
	var oturum := _oturum
	_parmak = -1
	olta.birak()
	kayik.dans()
	_sesler.play("kutlama")
	for i in 5:
		efektler.kabarciklar(Vector2(_ekran.x * (0.1 + i * 0.2), yuzey_y + 120.0), 12, 40.0)
	efektler.konfeti(Vector2(_ekran.x * 0.5, _ekran.y + 20.0), _ekran.x * 0.9)
	_kutlama.soz(_ekran)
	await get_tree().create_timer(1.6, false).timeout
	if oturum != _oturum:
		return
	# Kovadaki balıklar akvaryuma
	_kutlama.akvaryuma_tasi(_kovadakiler, kayik.kova_konumu(), _akvaryum_simge.get_global_rect().get_center())
	await get_tree().create_timer(0.4 + _kovadakiler.size() * 0.18 + 0.8, false).timeout
	if oturum != _oturum:
		return
	_sicrat(_akvaryum_simge)
	kayit.bolum += 1
	kayit.kaydet()
	await get_tree().create_timer(0.8, false).timeout
	if oturum != _oturum:
		return
	var tween := create_tween()
	tween.tween_property(_dunya, "modulate:a", 0.0, 0.35)
	await tween.finished
	if oturum != _oturum:
		return
	_bolumu_kur()
	create_tween().tween_property(_dunya, "modulate:a", 1.0, 0.35)
