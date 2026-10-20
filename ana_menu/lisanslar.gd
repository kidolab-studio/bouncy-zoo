extends Control
# Lisanslar ekranı: ana menüde, ebeveyn kapısının (3 sn basılı tutulan bilgi düğmesi) arkasında açılır.
# Godot'un lisansı ve içindeki üçüncü taraf bileşenler motordan okunur (Engine.get_license_text(),
# get_copyright_info(), get_license_info()); yazı tipi lisansı ve ses kaynakları lisans_metinleri.gd'de.
# Parmakla ya da fare tekerleğiyle kaydırılır; sol üstteki geri düğmesi, Escape ve Android geri tuşu kapatır.
# En üstte "İlerlemeyi sıfırla": kaydı olan her oyun için bir satır; ilk dokunuş onay ister, ikinci dokunuş oyunun
# kaydını (user://<klasör>.cfg) ve kupasını (OyunBitti) siler. Çocuğun erişebildiği başka hiçbir yerde ilerleme silinmez.

signal kapandi

const Metinler := preload("res://ana_menu/lisans_metinleri.gd")
const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const GERI: Texture2D = preload("res://ortak/gorseller/geri.svg")
const KENAR := 36.0
const BASLIK_YUKSEKLIGI := 170.0
const KAYMA_ESIGI := 14.0
const SURTUNME := 3.0
const YAZI := Color("3b2f6b")
const SOLUK := Color("6f6790")

var _ekran := Vector2(720, 1280)
var _alan: Control
var _icerik: VBoxContainer
var _geri: Control
var _tam_metin_dugmesi: Control
var _konum := 0.0
var _hiz := 0.0
var _parmak := -1
var _bas_yeri := Vector2.ZERO
var _son_y := 0.0
var _son_zaman := 0
var _kayiyor := false
var _kapaniyor := false
var _sifirlama: Array = []             # [etiket, oyun kaydı]
var _onaydaki := -1                    # silmek için ikinci dokunuşu bekleyen satır
var ilerleme_silindi := false          # kapanınca menü yenilensin (kart rozetleri)


func _ready() -> void:
	_ekran = get_viewport_rect().size
	size = _ekran
	mouse_filter = Control.MOUSE_FILTER_STOP
	var zemin := ColorRect.new()
	zemin.color = Color("fbf8ff")
	zemin.size = _ekran
	zemin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zemin)
	_alan = Control.new()
	_alan.clip_contents = true
	_alan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alan.position = Vector2(0, BASLIK_YUKSEKLIGI)
	_alan.size = Vector2(_ekran.x, _ekran.y - BASLIK_YUKSEKLIGI)
	add_child(_alan)
	_icerik = VBoxContainer.new()
	_icerik.add_theme_constant_override("separation", 14)
	_icerik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Çentikli telefonlarda yazılar çentiğin altında kalmasın
	var sol := EkranYardimcisi.kenar_payi(SIDE_LEFT, KENAR)
	var sag := EkranYardimcisi.kenar_payi(SIDE_RIGHT, KENAR)
	_icerik.position = Vector2(sol, 0)
	_icerik.size = Vector2(_ekran.x - sol - sag, 0)
	_alan.add_child(_icerik)
	_basligi_olustur()
	_icerigi_doldur()
	SahneGecis.geri_yakalayici = kapat
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _basligi_olustur() -> void:
	var baslik := Label.new()
	baslik.theme_type_variation = &"Baslik"
	baslik.text = "Lisanslar"
	baslik.add_theme_font_size_override("font_size", 52)
	baslik.add_theme_constant_override("shadow_offset_y", 3)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	baslik.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	baslik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baslik.position = Vector2(0, 62)
	baslik.size = Vector2(_ekran.x, 84)
	add_child(baslik)
	_geri = Control.new()
	_geri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geri.size = Vector2(88, 88)
	_geri.position = Vector2(EkranYardimcisi.kenar_payi(SIDE_LEFT, KENAR), 60)
	_geri.pivot_offset = _geri.size / 2.0
	_geri.draw.connect(_geri_ciz)
	add_child(_geri)
	var cizgi := ColorRect.new()
	cizgi.color = Color("e4ddff")
	cizgi.position = Vector2(0, BASLIK_YUKSEKLIGI - 3.0)
	cizgi.size = Vector2(_ekran.x, 3)
	cizgi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cizgi)


func _geri_ciz() -> void:
	var orta := _geri.size / 2.0
	_geri.draw_circle(orta, 40.0, Color.WHITE)
	_geri.draw_arc(orta, 40.0, 0.0, TAU, 48, YAZI, 5.0, true)
	_geri.draw_texture_rect(GERI, Rect2(orta - Vector2(22, 22), Vector2(44, 44)), false)


# --- İçerik ---

func _icerigi_doldur() -> void:
	_bosluk(6)
	_ilerleme_bolumu()
	_metin(tr(Metinler.GIRIS), 26, YAZI)

	_bolum(tr("Oyun motoru: Godot Engine"))
	_metin(tr("Bu uygulama Godot Engine %s ile yapıldı (godotengine.org). Godot, MIT lisansıyla dağıtılır:") % Engine.get_version_info()["string"], 24, YAZI)
	_metin(_akit(Engine.get_license_text()), 20, SOLUK)

	_bolum(tr("Yazı tipi: Nunito"))
	_metin(Metinler.NUNITO_TELIF + "\n" + tr("SIL Open Font License 1.1 ile lisanslıdır:"), 24, YAZI)
	_metin(_akit(Metinler.OFL), 20, SOLUK)

	_bolum(tr("Sesler ve müzikler"))
	_metin(tr(Metinler.SES_ACIKLAMA), 24, YAZI)
	var satirlar := PackedStringArray()
	for kaynak: Array in Metinler.SES_KAYNAKLARI:
		satirlar.append("• %s\n   %s, %s" % kaynak)
	_metin("\n".join(satirlar), 22, SOLUK)

	_bolum("Gizlilik / Privacy")
	_metin(Metinler.GIZLILIK, 22, YAZI)

	_bolum(tr("Godot içindeki bileşenler"))
	_metin(tr("Godot Engine aşağıdaki açık kaynaklı bileşenleri içerir (bileşen, telif sahipleri, lisans):"), 24, YAZI)
	_metin(_bilesen_listesi(), 20, SOLUK)

	_bosluk(10)
	_tam_metin_dugmesi = _dugme(tr("Tam lisans metinlerini göster"))
	_bosluk(80)


# Ebeveyn için: kaydı olan her oyunun ilerlemesini sıfırlama (onaylı)
func _ilerleme_bolumu() -> void:
	var oyunlar: Array = []
	for oyun: Dictionary in OyunListesi.OYUNLAR:
		var klasor: String = oyun["klasor"]
		if FileAccess.file_exists("user://%s.cfg" % klasor) or OyunBitti.tamamlandi_mi(klasor):
			oyunlar.append(oyun)
	if oyunlar.is_empty():
		return
	_bolum(tr("İlerlemeyi sıfırla"))
	_metin(tr("Bir oyunun bütün ilerlemesini (bölümler ve kupa) siler. Önce oyuna, sonra onaylamak için bir kez daha dokunun."), 24, YAZI)
	for oyun: Dictionary in oyunlar:
		_sifirlama.append([_dugme(tr(oyun["ad"])), oyun])
	_bosluk(20)


func _sifirlama_dokunuldu(sira: int) -> void:
	var etiket: Label = _sifirlama[sira][0]
	var oyun: Dictionary = _sifirlama[sira][1]
	if _onaydaki != sira:
		_onay_kaldir()
		_onaydaki = sira
		SesYoneticisi.efekt("dugme_tik")
		etiket.text = tr("%s: silmek için tekrar dokunun") % tr(oyun["ad"])
		etiket.add_theme_color_override("font_color", Color("d93a5a"))
		return
	_onaydaki = -1
	var klasor: String = oyun["klasor"]
	for ek in [".cfg", ".cfg.bak", ".cfg.tmp"]:
		if FileAccess.file_exists("user://" + klasor + ek):
			DirAccess.remove_absolute("user://" + klasor + ek)
	OyunBitti.sifirla(klasor)
	ilerleme_silindi = true
	SesYoneticisi.efekt("geri")
	etiket.text = tr("%s: ilerleme silindi") % tr(oyun["ad"])
	etiket.add_theme_color_override("font_color", SOLUK)


func _onay_kaldir() -> void:
	if _onaydaki >= 0:
		var etiket: Label = _sifirlama[_onaydaki][0]
		etiket.text = tr(_sifirlama[_onaydaki][1]["ad"])
		etiket.remove_theme_color_override("font_color")
	_onaydaki = -1


# Motorun bildirdiği bileşenler: her biri için ad, telif sahipleri (en çok üçü) ve lisans adı
func _bilesen_listesi() -> String:
	var satirlar := PackedStringArray()
	for bilesen: Dictionary in Engine.get_copyright_info():
		var sahipler := {}
		var lisanslar := {}
		for parca: Dictionary in bilesen["parts"]:
			for telif: String in parca["copyright"]:
				sahipler[telif] = true
			lisanslar[parca["license"]] = true
		var liste: Array = sahipler.keys()
		var ek := ""
		if liste.size() > 3:
			ek = tr(" ve diğerleri")
			liste.resize(3)
		satirlar.append("• %s\n   © %s%s\n   %s" % [bilesen["name"], "; ".join(liste), ek, tr("Lisans: %s") % ", ".join(lisanslar.keys())])
	return "\n".join(satirlar)


# Uzun olduğu için ancak istenince eklenir: bileşenlerin lisans metinlerinin tamamı
func _tam_metinleri_ekle() -> void:
	var sira := _tam_metin_dugmesi.get_index()
	_tam_metin_dugmesi.queue_free()
	_tam_metin_dugmesi = null
	var lisanslar := Engine.get_license_info()
	var adlar: Array = lisanslar.keys()
	adlar.sort()
	for ad: String in adlar:
		_icerik.move_child(_bolum(ad), sira)
		_icerik.move_child(_metin(_akit(lisanslar[ad]), 18, SOLUK), sira + 1)
		sira += 2


# Lisans metinleri ~75 karaktere göre elle bölünmüş gelir; dar ekranda yarım satırlar kalmasın diye
# paragraf içindeki satır sonları boşluğa çevrilir (kısa satırlar, başlıklar ve boş satırlar korunur)
func _akit(yazi: String) -> String:
	var sonuc := ""
	var onceki := ""
	for satir in yazi.split("\n"):
		var duz := satir.strip_edges()
		if sonuc != "":
			sonuc += " " if (onceki.length() >= 45 and duz != "" and not duz.begins_with("Copyright")) else "\n"
		sonuc += duz
		onceki = duz
	return sonuc


func _bolum(yazi: String) -> Label:
	var etiket := Label.new()
	etiket.theme_type_variation = &"KartYazisi"
	etiket.text = yazi
	etiket.add_theme_font_size_override("font_size", 34)
	etiket.add_theme_color_override("font_color", Color("7b6cf6"))
	etiket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiket.custom_minimum_size.y = 70
	etiket.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_icerik.add_child(etiket)
	return etiket


func _metin(yazi: String, boyut: int, renk: Color) -> Label:
	var etiket := Label.new()
	etiket.text = yazi.strip_edges()
	etiket.add_theme_font_size_override("font_size", boyut)
	etiket.add_theme_color_override("font_color", renk)
	etiket.add_theme_constant_override("line_spacing", 2)
	etiket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icerik.add_child(etiket)
	return etiket


func _dugme(yazi: String) -> Control:
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color("ece8ff")
	stil.set_corner_radius_all(28)
	stil.set_border_width_all(3)
	stil.border_color = Color("c9c0f5")
	stil.set_content_margin_all(26)
	var etiket := Label.new()
	etiket.theme_type_variation = &"KartYazisi"
	etiket.text = yazi
	etiket.add_theme_font_size_override("font_size", 28)
	etiket.add_theme_stylebox_override("normal", stil)
	etiket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiket.custom_minimum_size.y = 120
	etiket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icerik.add_child(etiket)
	return etiket


func _bosluk(yukseklik: float) -> void:
	var bosluk := Control.new()
	bosluk.custom_minimum_size.y = yukseklik
	bosluk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icerik.add_child(bosluk)


# --- Kapatma ---

func kapat() -> void:
	if _kapaniyor:
		return
	_kapaniyor = true
	SahneGecis.geri_yakalayici = Callable()
	SesYoneticisi.efekt("geri")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(kapandi.emit)
	tween.tween_callback(queue_free)


# --- Dokunma ve kaydırma ---

func _en_fazla() -> float:
	return maxf(0.0, _icerik.size.y - _alan.size.y)


func _input(event: InputEvent) -> void:
	if _kapaniyor:
		return
	var tekerlek := event as InputEventMouseButton
	if tekerlek and tekerlek.pressed and tekerlek.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_hiz += -1400.0 if tekerlek.button_index == MOUSE_BUTTON_WHEEL_UP else 1400.0
		return
	var dokunma := event as InputEventScreenTouch
	if dokunma:
		if dokunma.pressed and _parmak == -1:
			_parmak = dokunma.index
			_bas_yeri = dokunma.position
			_son_y = dokunma.position.y
			_son_zaman = Time.get_ticks_usec()
			_kayiyor = false
			_hiz = 0.0
		elif not dokunma.pressed and dokunma.index == _parmak:
			_parmak = -1
			if not _kayiyor:
				_dokunuldu(dokunma.position)
			elif Time.get_ticks_usec() - _son_zaman > 90000:
				_hiz = 0.0
		return
	var surukleme := event as InputEventScreenDrag
	if surukleme and surukleme.index == _parmak:
		if not _kayiyor:
			if surukleme.position.distance_to(_bas_yeri) <= KAYMA_ESIGI:
				return
			_kayiyor = true
			_son_y = surukleme.position.y
		var fark := _son_y - surukleme.position.y
		_konum = clampf(_konum + fark, 0.0, _en_fazla())
		var simdi := Time.get_ticks_usec()
		_hiz = lerpf(_hiz, fark / maxf((simdi - _son_zaman) / 1000000.0, 0.004), 0.6)
		_son_y = surukleme.position.y
		_son_zaman = simdi


func _dokunuldu(nokta: Vector2) -> void:
	if nokta.y > BASLIK_YUKSEKLIGI:
		for i in _sifirlama.size():
			if (_sifirlama[i][0] as Control).get_global_rect().has_point(nokta):
				_sifirlama_dokunuldu(i)
				return
	_onay_kaldir()
	if _geri.get_global_rect().grow(18.0).has_point(nokta):
		kapat()
	elif _tam_metin_dugmesi and nokta.y > BASLIK_YUKSEKLIGI and _tam_metin_dugmesi.get_global_rect().has_point(nokta):
		SesYoneticisi.efekt("dugme_tik")
		_tam_metinleri_ekle()


func _process(delta: float) -> void:
	if _parmak == -1 and _hiz != 0.0:
		_konum = clampf(_konum + _hiz * delta, 0.0, _en_fazla())
		_hiz *= exp(-delta * SURTUNME)
		if absf(_hiz) < 8.0 or _konum <= 0.0 or _konum >= _en_fazla():
			_hiz = 0.0
	_konum = minf(_konum, _en_fazla())
	_icerik.position.y = -_konum
