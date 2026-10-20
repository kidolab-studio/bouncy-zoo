extends Control
# Bouncy Zoo ana menüsü (yatay): üstte tek satırda başlık ve kategori sekmeleri, altında 5 sütunlu,
# dikey kaydırılan büyük oyun kartları. Oyun listesi oyun_listesi.gd'de; kart oyun_karti.gd, sekme sekme.gd.
#
# Dokunma: parmak KAYMA_ESIGI'nden fazla kayarsa dokunma iptal olur ve liste kayar (momentumlu, uçlarda esner).
# Karta basınca kart küçülür, parmak kalkınca büyüyüp oyun açılır. Oyundan dönünce aynı sekme ve kaydırma
# konumu geri gelir (static değişkenler uygulama açık kaldıkça sahne değişse de korunur).

const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const OyunKarti := preload("res://ana_menu/oyun_karti.gd")
const Sekme := preload("res://ana_menu/sekme.gd")
const SesDugmesi := preload("res://ana_menu/ses_dugmesi.gd")
const Lisanslar := preload("res://ana_menu/lisanslar.gd")
const BasiliDugme := preload("res://ortak/basili_geri_dugmesi.gd")
const BILGI_SIMGESI: Texture2D = preload("res://ana_menu/gorseller/bilgi.svg")
const EBEVEYN_BEKLEME := 3.0    # bilgi düğmesi bu kadar saniye basılı tutulunca Lisanslar açılır (ebeveyn kapısı)
const YUMUSAK_DAIRE: Texture2D = preload("res://ana_menu/gorseller/yumusak_daire.svg")

# Oyun testleri menüden oyun açarken bunları kullanır: OYUNLAR[i]["sahne"] ve _kartlar[i] (aynı sıra)
const OYUNLAR := OyunListesi.OYUNLAR

const KENAR := 48.0             # ekranın yan boşluğu
const ARALIK := 22.0            # kartlar arası boşluk
const SUTUN := 5                # kart sütun sayısı
const EN_GENIS_KART := 260.0    # tablette kartlar bundan büyümez, ızgara ortalanır
const DUGME_BOYU := 84.0        # bilgi ve ses düğmeleri
const UST_BOSLUK := 10.0        # üst satırın (başlık, sekmeler, düğmeler) ekran üstünden uzaklığı
const KART_ORANI := 1.06        # kart yüksekliği / genişliği
const KAYMA_ESIGI := 18.0       # parmak bundan fazla kayarsa dokunma sayılmaz
const SURTUNME := 2.6           # momentum yavaşlaması (büyük = çabuk durur)
const ESNEME := 0.4             # uçlardan dışarı sürüklerken liste parmağı bu oranda izler
const EN_FAZLA_ESNEME := 150.0
const LEKE_RENKLERI := [Color("ffb3cf"), Color("c9b6ff"), Color("a8efd0"), Color("ffd2a8"), Color("aedbff")]

static var _son_sekme := "hepsi"
static var _son_kaydirma := 0.0

var _kartlar: Array[Control] = []     # OYUNLAR sırasıyla (gizli sekmedekiler dahil)
var _sekmeler: Array[Control] = []
var _gorunen: Array[Control] = []     # seçili sekmede görünen kartlar, sırayla
var _sekme := "hepsi"
var _ekran := Vector2(1280, 720)
var _baslik: HBoxContainer
var _ses_dugmesi: Control
var _bilgi_dugmesi: Control           # ebeveyn kapısı: basılı tutunca Lisanslar ekranı
var _bilgi_ipucu: Label
var _ipucu_tween: Tween
var _lisanslar: Control = null
var _alan: Control                     # kartların kaydığı, kırpılan bölge
var _icerik: Control
var _ust_golge: TextureRect
var _lekeler: Array[Sprite2D] = []
var _zaman := 0.0
var _yeniden_kurulacak := false

# Kaydırma
var _konum := 0.0
var _hiz := 0.0
var _en_fazla := 0.0
var _surukleniyor := false

# Dokunma
var _parmak := -1
var _bas_yeri := Vector2.ZERO
var _son_y := 0.0
var _son_zaman := 0
var _kayiyor := false
var _basili_kart: Control = null
var _basili_sekme: Control = null
var _ses_basili := false
var _secildi := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ekran = get_viewport_rect().size
	get_viewport().size_changed.connect(_boyut_degisti)
	EkranYardimcisi.degisince(_boyut_degisti)
	for hata in OyunListesi.dogrula():
		push_error("Ana menü listesi: " + hata)
	SesYoneticisi.muzik("menu", self)
	_arka_plan_olustur()
	_baslik_olustur()
	_ses_dugmesi_olustur()
	_bilgi_dugmesi_olustur()
	_sekmeleri_olustur()
	_alani_olustur()
	for i in OYUNLAR.size():
		var kart: Control = OyunKarti.new()
		_icerik.add_child(kart)
		kart.kur(OYUNLAR[i], _kart_boyu(), i * 1.3)
		_kartlar.append(kart)
	_sekme = _son_sekme if _kategori_var(_son_sekme) else "hepsi"
	for sekme in _sekmeler:
		sekme.sec(sekme.kategori["id"] == _sekme, false)
	_yerlestir()
	_konum = clampf(_son_kaydirma, 0.0, _en_fazla)
	_icerik.position.y = -_konum
	_acilis_animasyonu()


func _kategori_var(id: String) -> bool:
	return OyunListesi.KATEGORILER.any(func(k: Dictionary) -> bool: return k["id"] == id)


# --- Kurulum ---

func _arka_plan_olustur() -> void:
	var gecis := Gradient.new()
	gecis.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gecis.colors = PackedColorArray([Color("fff0f6"), Color("f1f0ff"), Color("e9f8f1")])
	var doku := GradientTexture2D.new()
	doku.gradient = gecis
	doku.fill_from = Vector2(0.2, 0.0)
	doku.fill_to = Vector2(0.5, 1.0)
	doku.width = 64
	doku.height = 256
	var zemin := TextureRect.new()
	zemin.texture = doku
	zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zemin.stretch_mode = TextureRect.STRETCH_SCALE
	zemin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zemin)
	zemin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Çok yavaş süzülen, soluk renkli lekeler
	for i in LEKE_RENKLERI.size():
		var leke := Sprite2D.new()
		leke.texture = YUMUSAK_DAIRE
		leke.scale = Vector2.ONE * randf_range(340.0, 520.0) / YUMUSAK_DAIRE.get_width()
		leke.modulate = Color(LEKE_RENKLERI[i], 0.3)
		leke.set_meta("ev", Vector2(randf_range(0.0, _ekran.x), _ekran.y * (i + 0.5) / LEKE_RENKLERI.size()))
		leke.set_meta("faz", randf() * TAU)
		add_child(leke)
		_lekeler.append(leke)


func _baslik_olustur() -> void:
	_baslik = HBoxContainer.new()
	_baslik.alignment = BoxContainer.ALIGNMENT_BEGIN
	_baslik.add_theme_constant_override("separation", 14)
	_baslik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_baslik.position = Vector2(_yan_kenar() + DUGME_BOYU + 24.0, UST_BOSLUK)
	_baslik.size = Vector2(380, _sekme_boyu().y)
	add_child(_baslik)
	for parca in [["Bouncy", Color("ff7a9a")], ["Zoo", Color("7b6cf6")]]:
		var etiket := Label.new()
		etiket.theme_type_variation = &"Baslik"
		etiket.text = parca[0]
		etiket.add_theme_font_size_override("font_size", 46)
		etiket.add_theme_constant_override("shadow_offset_y", 4)
		etiket.add_theme_color_override("font_color", parca[1])
		etiket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_baslik.add_child(etiket)


# Sağ üstte, başlıkla aynı hizada küçük ses düğmesi
func _ses_dugmesi_olustur() -> void:
	var boyut := DUGME_BOYU
	_ses_dugmesi = SesDugmesi.new()
	add_child(_ses_dugmesi)
	_ses_dugmesi.kur(boyut)
	_ses_dugmesi.position = Vector2(_ekran.x - _yan_kenar() - boyut, _baslik.position.y + (_baslik.size.y - boyut) / 2.0)


# Sol üstte küçük, soluk bilgi düğmesi: çocuk kazara açmasın diye 3 sn basılı tutmak gerekir
func _bilgi_dugmesi_olustur() -> void:
	var boyut := DUGME_BOYU
	_bilgi_dugmesi = BasiliDugme.new()
	_bilgi_dugmesi.double_tap = false
	_bilgi_dugmesi.hold_time = EBEVEYN_BEKLEME
	_bilgi_dugmesi.icon = BILGI_SIMGESI
	_bilgi_dugmesi.size = Vector2(boyut, boyut)
	_bilgi_dugmesi.position = Vector2(_yan_kenar(), _ses_dugmesi.position.y)
	_bilgi_dugmesi.modulate.a = 0.7
	_bilgi_dugmesi.completed.connect(_lisanslari_ac)
	add_child(_bilgi_dugmesi)
	_bilgi_ipucu = Label.new()
	_bilgi_ipucu.theme_type_variation = &"Rozet"
	_bilgi_ipucu.text = "Ebeveynler için: 3 saniye basılı tutun"
	_bilgi_ipucu.add_theme_font_size_override("font_size", 24)
	_bilgi_ipucu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bilgi_ipucu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bilgi_ipucu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bilgi_ipucu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# İki düğmenin arasında, başlığın yerinde görünür
	_bilgi_ipucu.position = _baslik.position
	_bilgi_ipucu.size = _baslik.size
	_bilgi_ipucu.modulate.a = 0.0
	add_child(_bilgi_ipucu)


# Kısa dokunuşta ne yapılacağını söyleyen küçük yazı, kısa süre başlığın yerinde görünür
func _bilgi_ipucu_goster() -> void:
	if _ipucu_tween and _ipucu_tween.is_valid():
		_ipucu_tween.kill()
	_ipucu_tween = create_tween()
	_ipucu_tween.tween_property(_baslik, "modulate:a", 0.0, 0.15)
	_ipucu_tween.parallel().tween_property(_bilgi_ipucu, "modulate:a", 1.0, 0.15)
	_ipucu_tween.tween_interval(2.2)
	_ipucu_tween.tween_property(_bilgi_ipucu, "modulate:a", 0.0, 0.3)
	_ipucu_tween.parallel().tween_property(_baslik, "modulate:a", 1.0, 0.3)


func _lisanslari_ac() -> void:
	SesYoneticisi.efekt("dugme_tik")
	_hiz = 0.0
	_lisanslar = Lisanslar.new()
	add_child(_lisanslar)
	_lisanslar.kapandi.connect(_lisanslar_kapandi)


func _lisanslar_kapandi() -> void:
	var silindi: bool = _lisanslar.ilerleme_silindi
	_lisanslar = null
	_bilgi_dugmesi.reset()
	if silindi:
		SahneGecis.sahneyi_yeniden_baslat()      # kart rozetleri (ilerleme, kupa) yenilensin


func _sekme_boyu() -> Vector2:
	return Vector2(104.0, 112.0)


func _sekmeleri_olustur() -> void:
	var boyut := _sekme_boyu()
	var sayi := OyunListesi.KATEGORILER.size()
	var aralik := 12.0
	# Sekmeler ses düğmesinin soluna dayanır
	var sol := _ekran.x - _yan_kenar() - DUGME_BOYU - 24.0 - boyut.x * sayi - aralik * (sayi - 1)
	for i in sayi:
		var sekme: Control = Sekme.new()
		add_child(sekme)
		sekme.kur(OyunListesi.KATEGORILER[i], boyut)
		sekme.position = Vector2(sol + i * (boyut.x + aralik), _sekme_ust())
		_sekmeler.append(sekme)
	# Dar kalan ekranda (ör. çentikli 16:9 telefon) başlık sekmelerin altına girmesin: sığacak kadar küçülür
	var bosluk := sol - 16.0 - _baslik.position.x
	var genislik := _baslik.get_combined_minimum_size().x
	if bosluk > 0.0 and genislik > bosluk:
		_baslik.pivot_offset = Vector2(0, _baslik.size.y / 2.0)
		_baslik.scale = Vector2.ONE * (bosluk / genislik)


func _sekme_ust() -> float:
	return UST_BOSLUK


func _alan_ust() -> float:
	return _sekme_ust() + _sekme_boyu().y + 14.0


func _alani_olustur() -> void:
	_alan = Control.new()
	_alan.clip_contents = true
	_alan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alan.position = Vector2(0, _alan_ust())
	_alan.size = Vector2(_ekran.x, _ekran.y - _alan_ust())
	add_child(_alan)
	_icerik = Control.new()
	_icerik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icerik.size = _alan.size
	_alan.add_child(_icerik)
	# Liste kayınca sekmelerin altında hafif bir gölge belirir
	var gecis := Gradient.new()
	gecis.colors = PackedColorArray([Color(0.35, 0.25, 0.55, 0.22), Color(0.35, 0.25, 0.55, 0.0)])
	var doku := GradientTexture2D.new()
	doku.gradient = gecis
	doku.fill_from = Vector2(0, 0)
	doku.fill_to = Vector2(0, 1)
	doku.width = 4
	doku.height = 32
	_ust_golge = TextureRect.new()
	_ust_golge.texture = doku
	_ust_golge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ust_golge.stretch_mode = TextureRect.STRETCH_SCALE
	_ust_golge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ust_golge.size = Vector2(_ekran.x, 26)
	_ust_golge.modulate.a = 0.0
	_alan.add_child(_ust_golge)


func _kart_boyu() -> Vector2:
	var genislik := minf((_ekran.x - 2.0 * _kenar() - ARALIK * (SUTUN - 1)) / SUTUN, EN_GENIS_KART)
	return Vector2(roundf(genislik), roundf(genislik * KART_ORANI))


# Ekranın yan boşluğu: çentikli telefonda güvenli alan kadar büyür (iki yanda aynı: ızgara ortada kalır)
func _kenar() -> float:
	return maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, KENAR), EkranYardimcisi.kenar_payi(SIDE_RIGHT, KENAR))


# Kart ızgarasının ekran kenarına uzaklığı; geniş ekranda ızgara ortalanır, üst satır da bu kenarlara hizalanır
func _yan_kenar() -> float:
	var boyut := _kart_boyu()
	return roundf((_ekran.x - boyut.x * SUTUN - ARALIK * (SUTUN - 1)) / 2.0)


# Seçili sekmenin kartlarını SUTUN sütuna dizer, kaydırma sınırını hesaplar
func _yerlestir() -> void:
	var boyut := _kart_boyu()
	var sol := _yan_kenar()
	var ust_bosluk := 14.0
	_gorunen.clear()
	for kart in _kartlar:
		kart.visible = OyunListesi.kategoride_mi(kart.oyun, _sekme)
		if kart.visible:
			var j := _gorunen.size()
			kart.position = Vector2(sol + (j % SUTUN) * (boyut.x + ARALIK), ust_bosluk + floori(float(j) / SUTUN) * (boyut.y + ARALIK))
			_gorunen.append(kart)
	var satir := ceili(float(_gorunen.size()) / SUTUN)
	var yukseklik := ust_bosluk + satir * (boyut.y + ARALIK) - ARALIK + 60.0
	_en_fazla = maxf(0.0, yukseklik - _alan.size.y)


# Başlık ve sekmeler süzülür, ekranda görünen kartlar sırayla hafifçe zıplayarak gelir
func _acilis_animasyonu() -> void:
	_baslik.modulate.a = 0.0
	var tween := _baslik.create_tween().set_parallel()
	tween.tween_property(_baslik, "modulate:a", 1.0, 0.4).set_delay(0.05)
	tween.tween_property(_baslik, "position:y", _baslik.position.y, 0.5).from(_baslik.position.y - 20.0) \
		.set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _sekmeler.size():
		_sekmeler[i].giris(0.1 + i * 0.05)
	_ses_dugmesi.modulate.a = 0.0
	_ses_dugmesi.create_tween().tween_property(_ses_dugmesi, "modulate:a", 1.0, 0.4).set_delay(0.3)
	_bilgi_dugmesi.modulate.a = 0.0
	_bilgi_dugmesi.create_tween().tween_property(_bilgi_dugmesi, "modulate:a", 0.7, 0.4).set_delay(0.3)
	_kartlari_getir(0.25)


func _kartlari_getir(ilk_gecikme: float) -> void:
	var sira := 0
	for kart in _gorunen:
		if _ekranda_mi(kart):
			kart.giris(ilk_gecikme + sira * 0.06)
			sira += 1
		else:
			kart.hemen_goster()


func _ekranda_mi(kart: Control) -> bool:
	var y: float = kart.position.y - _konum
	return y + kart.size.y > 0.0 and y < _alan.size.y


# --- Sekme seçimi ---

func _sekme_sec(id: String) -> void:
	SesYoneticisi.efekt("dugme_tik")
	if id == _sekme:
		# Aynı sekmeye dokununca liste yumuşakça başa döner
		_hiz = 0.0
		create_tween().tween_property(self, "_konum", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	_sekme = id
	_son_sekme = id
	for sekme in _sekmeler:
		sekme.sec(sekme.kategori["id"] == id)
	_konum = 0.0
	_hiz = 0.0
	_son_kaydirma = 0.0
	_yerlestir()
	_kartlari_getir(0.02)


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	if _secildi or SahneGecis.gecis_suruyor or _lisanslar != null:
		return
	var tekerlek := event as InputEventMouseButton
	if tekerlek and tekerlek.pressed and tekerlek.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_hiz += -1200.0 if tekerlek.button_index == MOUSE_BUTTON_WHEEL_UP else 1200.0
		return
	var dokunma := event as InputEventScreenTouch
	if dokunma:
		if _parmak == -1 and _bilgi_dugmesi.handle_touch(dokunma):
			if not dokunma.pressed and _lisanslar == null:
				_bilgi_ipucu_goster()
			return
		if dokunma.pressed and _parmak == -1:
			_dokunma_basladi(dokunma)
		elif not dokunma.pressed and dokunma.index == _parmak:
			_dokunma_bitti(dokunma)
		return
	var surukleme := event as InputEventScreenDrag
	if surukleme and surukleme.index == _parmak:
		_suruklendi(surukleme)


func _dokunma_basladi(dokunma: InputEventScreenTouch) -> void:
	_parmak = dokunma.index
	_bas_yeri = dokunma.position
	_son_y = dokunma.position.y
	_son_zaman = Time.get_ticks_usec()
	_kayiyor = false
	var akiyordu := absf(_hiz) > 150.0
	_hiz = 0.0
	if _ses_dugmesi.icinde_mi(dokunma.position):
		_ses_basili = true
		_ses_dugmesi.bas()
		return
	if dokunma.position.y < _alan_ust():
		for sekme in _sekmeler:
			if sekme.get_global_rect().has_point(dokunma.position):
				_basili_sekme = sekme
				sekme.bas()
		return
	_surukleniyor = true
	# Akan listeyi durdurmak için yapılan dokunuş oyun açmaz
	if akiyordu:
		return
	for kart in _gorunen:
		if kart.get_global_rect().has_point(dokunma.position):
			_basili_kart = kart
			kart.bas()
			return


func _suruklendi(surukleme: InputEventScreenDrag) -> void:
	if not _kayiyor:
		if surukleme.position.distance_to(_bas_yeri) <= KAYMA_ESIGI:
			return
		_kayiyor = true
		_son_y = surukleme.position.y
		if _basili_kart:
			_basili_kart.iptal()
			_basili_kart = null
		if _basili_sekme:
			_basili_sekme.iptal()
			_basili_sekme = null
		if _ses_basili:
			_ses_basili = false
			_ses_dugmesi.iptal()
	if not _surukleniyor:
		return
	var fark := _son_y - surukleme.position.y
	if _konum < 0.0 or _konum > _en_fazla:
		fark *= ESNEME
	_konum = clampf(_konum + fark, -EN_FAZLA_ESNEME, _en_fazla + EN_FAZLA_ESNEME)
	var simdi := Time.get_ticks_usec()
	var sure := maxf((simdi - _son_zaman) / 1000000.0, 0.004)
	_hiz = lerpf(_hiz, fark / sure, 0.6)
	_son_y = surukleme.position.y
	_son_zaman = simdi


func _dokunma_bitti(dokunma: InputEventScreenTouch) -> void:
	_parmak = -1
	_surukleniyor = false
	# Parmak durup bekledikten sonra kalktıysa liste akmaz
	if Time.get_ticks_usec() - _son_zaman > 90000:
		_hiz = 0.0
	_hiz = clampf(_hiz, -5000.0, 5000.0)
	if _ses_basili:
		_ses_basili = false
		if _ses_dugmesi.icinde_mi(dokunma.position):
			_ses_dugmesi.degistir()
		else:
			_ses_dugmesi.iptal()
	if _basili_sekme:
		var sekme := _basili_sekme
		_basili_sekme = null
		sekme.iptal()
		if sekme.get_global_rect().has_point(dokunma.position):
			_sekme_sec(sekme.kategori["id"])
	if _basili_kart:
		var kart := _basili_kart
		_basili_kart = null
		if kart.get_global_rect().has_point(dokunma.position):
			_oyunu_ac(kart)
		else:
			kart.iptal()


func _oyunu_ac(kart: Control) -> void:
	_secildi = true
	_hiz = 0.0
	_son_sekme = _sekme
	_son_kaydirma = clampf(_konum, 0.0, _en_fazla)
	SesYoneticisi.efekt("dugme_tik")
	if OyunListesi.yeni_mi(kart.oyun):
		OyunListesi.acildi_isaretle(kart.oyun)
	kart.birak(SahneGecis.sahne_degistir.bind(kart.oyun["sahne"]))


# Düzen açılıştaki ekran boyutuna göre kurulur. Pencere sonradan büyür ya da küçülürse
# (ör. ilk açılışta oyun penceresi yerine oturunca) menü aynı sekme ve kaydırmayla yeniden kurulur.
func _boyut_degisti() -> void:
	if _yeniden_kurulacak:
		return
	_yeniden_kurulacak = true
	# Pencere yerine otursun diye kısa bekle (art arda gelen boyut değişiklikleri tek sefer sayılır)
	await get_tree().create_timer(0.2).timeout
	_yeniden_kurulacak = false
	if get_tree().current_scene != self or _secildi or _lisanslar:
		return
	if get_viewport_rect().size.is_equal_approx(_ekran):
		return
	_son_sekme = _sekme
	_son_kaydirma = _konum
	get_tree().reload_current_scene()


# --- Her kare ---

func _process(delta: float) -> void:
	_zaman += delta
	_kaydirmayi_guncelle(delta)
	_icerik.position.y = -_konum
	_ust_golge.modulate.a = clampf(_konum / 40.0, 0.0, 1.0)
	for leke in _lekeler:
		var ev: Vector2 = leke.get_meta("ev")
		var faz: float = leke.get_meta("faz")
		leke.position = ev + Vector2(sin(_zaman * 0.07 + faz) * 60.0, cos(_zaman * 0.05 + faz) * 45.0)


# Momentum: sürtünmeyle yavaşlar. Uçlardan taşınca yay gibi geri döner (taşan hız çabuk söner).
func _kaydirmayi_guncelle(delta: float) -> void:
	if _surukleniyor:
		return
	var hedef := clampf(_konum, 0.0, _en_fazla)
	if _konum != hedef:
		_hiz *= exp(-delta * 18.0)
		_konum += _hiz * delta
		hedef = clampf(_konum, 0.0, _en_fazla)
		_konum = hedef + (_konum - hedef) * exp(-delta * 11.0)
		if absf(_konum - hedef) < 0.5 and absf(_hiz) < 20.0:
			_konum = hedef
			_hiz = 0.0
	elif _hiz != 0.0:
		_konum = clampf(_konum + _hiz * delta, -EN_FAZLA_ESNEME, _en_fazla + EN_FAZLA_ESNEME)
		_hiz *= exp(-delta * SURTUNME)
		if absf(_hiz) < 8.0:
			_hiz = 0.0
