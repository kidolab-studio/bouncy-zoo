extends Control
# Ana menüde tek oyun kartı: pastel zemin, ortada oyunun büyük görseli (yavaşça nefes alır), altta kısa ad,
# köşelerde küçük rozetler ("Yeni" ve bölümlü oyunlarda ilerleme; bütün bölümler bitince kupa). Bütün görünüm "ic" düğümünde;
# kartın kendisi sadece yer tutar (kaydırma onu taşır), basma ve açılış animasyonları "ic" üzerinde oynar.

const OyunListesi := preload("res://ana_menu/oyun_listesi.gd")
const YUMUSAK_DAIRE: Texture2D = preload("res://ana_menu/gorseller/yumusak_daire.svg")
const YILDIZ: Texture2D = preload("res://ana_menu/gorseller/yildiz.svg")
const YAZI_RENGI := Color("3b2f6b")
const YENI_RENGI := Color("ff6b81")

var oyun: Dictionary = {}
var ic: Control

var _renk := Color.WHITE
var _gorsel: Sprite2D
var _gorsel_olcek := 1.0
var _faz := 0.0
var _zaman := 0.0
var _yeni: Control


func kur(p_oyun: Dictionary, boyut: Vector2, faz: float) -> void:
	oyun = p_oyun
	_faz = faz
	_renk = OyunListesi.renk(oyun)
	size = boyut
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic = Control.new()
	ic.size = boyut
	ic.pivot_offset = boyut / 2.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(_zemini_ciz)
	add_child(ic)

	var yazi_payi := _yazi_yuksekligi()
	var alan := Rect2(12, 12, boyut.x - 24, boyut.y - yazi_payi - 16)
	var merkez := alan.get_center()
	# Görselin arkasında yumuşak beyaz ışık
	var isik := Sprite2D.new()
	isik.texture = YUMUSAK_DAIRE
	isik.scale = Vector2.ONE * minf(alan.size.x, alan.size.y) * 1.02 / YUMUSAK_DAIRE.get_width()
	isik.position = merkez
	isik.modulate = Color(1, 1, 1, 0.75)
	ic.add_child(isik)

	_gorsel = Sprite2D.new()
	_gorsel.texture = load(OyunListesi.kart_yolu(oyun))
	var doku := _gorsel.texture.get_size()
	_gorsel_olcek = minf(alan.size.x / doku.x, alan.size.y / doku.y)
	_gorsel.scale = Vector2.ONE * _gorsel_olcek
	_gorsel.position = merkez
	ic.add_child(_gorsel)

	var ad := Label.new()
	ad.theme_type_variation = &"KartYazisi"
	ad.text = oyun["ad"]
	ad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad.add_theme_color_override("font_color", YAZI_RENGI)
	ad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ad.position = Vector2(0, boyut.y - yazi_payi - 4.0)
	ad.size = Vector2(boyut.x, yazi_payi)
	ic.add_child(ad)
	_yaziyi_sigdir(ad, roundi(boyut.x * 0.112), boyut.x - 30.0)
	# Yazı küçülünce etiketin büyümüş boyutu kalmasın (yoksa ortadan kayar)
	ad.position = Vector2(0, boyut.y - yazi_payi - 4.0)
	ad.size = Vector2(boyut.x, yazi_payi)

	var bolum := OyunListesi.ilerleme(oyun)
	if OyunBitti.tamamlandi_mi(oyun["klasor"]):
		_kose_rozeti(_kupa_rozeti(), true)       # bütün bölümler bitti: küçük kupa
	elif bolum > 0:
		_kose_rozeti(_ilerleme_rozeti(bolum), true)
	if OyunListesi.yeni_mi(oyun):
		_yeni = _yeni_rozeti()
		_kose_rozeti(_yeni, false)


func _yazi_yuksekligi() -> float:
	return roundf(size.x * 0.2)


# Uzun adlar (ör. "Gölge Eşleştirme") karta sığsın diye yazı biraz küçülür
func _yaziyi_sigdir(ad: Label, boy: int, genislik: float) -> void:
	ad.add_theme_font_size_override("font_size", boy)
	while boy > 14 and ad.get_minimum_size().x > genislik:
		boy -= 1
		ad.add_theme_font_size_override("font_size", boy)


func _zemini_ciz() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var kose := roundi(size.x * 0.13)
	var zemin := StyleBoxFlat.new()
	zemin.bg_color = _renk
	zemin.set_corner_radius_all(kose)
	zemin.set_border_width_all(5)
	zemin.border_color = Color(1, 1, 1, 0.95)
	zemin.shadow_color = Color(_renk.darkened(0.55), 0.26)
	zemin.shadow_size = 16
	zemin.shadow_offset = Vector2(0, 9)
	zemin.anti_aliasing_size = 1.2
	ic.draw_style_box(zemin, r)
	# Adın altındaki açık bant (kartın alt kısmı)
	var bant := StyleBoxFlat.new()
	bant.bg_color = Color(1, 1, 1, 0.55)
	bant.corner_radius_bottom_left = kose - 5
	bant.corner_radius_bottom_right = kose - 5
	var yazi := _yazi_yuksekligi() + 8.0
	ic.draw_style_box(bant, Rect2(5, size.y - yazi - 5.0, size.x - 10.0, yazi))


# Sağ üstte küçük ilerleme rozeti: yıldız + sayı
func _ilerleme_rozeti(bolum: int) -> Control:
	var rozet := _hap(Color(1, 1, 1, 0.94))
	var satir := HBoxContainer.new()
	satir.add_theme_constant_override("separation", 4)
	satir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rozet.add_child(satir)
	var yildiz := TextureRect.new()
	yildiz.texture = YILDIZ
	yildiz.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	yildiz.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	yildiz.custom_minimum_size = Vector2(22, 22)
	yildiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	satir.add_child(yildiz)
	satir.add_child(_rozet_yazisi(str(bolum), YAZI_RENGI))
	return rozet


# Sağ üstte küçük kupa: oyunun bütün bölümleri bitirildi (OyunBitti)
func _kupa_rozeti() -> Control:
	var rozet := _hap(Color(1, 1, 1, 0.94))
	rozet.name = "KupaRozeti"
	var kupa := TextureRect.new()
	kupa.texture = OyunBitti.KUPA
	kupa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kupa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kupa.custom_minimum_size = Vector2(30, 30)
	kupa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rozet.add_child(kupa)
	return rozet


# Sol üstte "Yeni": oyun ilk kez açılana kadar
func _yeni_rozeti() -> Control:
	var rozet := _hap(YENI_RENGI)
	rozet.add_child(_rozet_yazisi("Yeni", Color.WHITE))
	return rozet


# Rozet ağaca eklenince içeriğine göre boyutlanır; köşeye çapalanır (sağdakiler sola doğru büyür)
func _kose_rozeti(rozet: Control, sag: bool) -> void:
	ic.add_child(rozet)
	rozet.anchor_left = 1.0 if sag else 0.0
	rozet.anchor_right = rozet.anchor_left
	rozet.grow_horizontal = Control.GROW_DIRECTION_BEGIN if sag else Control.GROW_DIRECTION_END
	var kenar := -14.0 if sag else 14.0
	rozet.offset_left = kenar
	rozet.offset_right = kenar
	rozet.offset_top = 14.0
	rozet.offset_bottom = 14.0


func _hap(renk: Color) -> PanelContainer:
	var hap := PanelContainer.new()
	hap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = renk
	stil.set_corner_radius_all(16)
	stil.content_margin_left = 10
	stil.content_margin_right = 12
	stil.content_margin_top = 1
	stil.content_margin_bottom = 2
	stil.shadow_color = Color(_renk.darkened(0.6), 0.16)
	stil.shadow_size = 4
	stil.shadow_offset = Vector2(0, 2)
	hap.add_theme_stylebox_override("panel", stil)
	return hap


func _rozet_yazisi(metin: String, renk: Color) -> Label:
	var yazi := Label.new()
	yazi.theme_type_variation = &"Rozet"
	yazi.text = metin
	yazi.add_theme_font_size_override("font_size", 22)
	yazi.add_theme_color_override("font_color", renk)
	yazi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yazi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return yazi


# --- Animasyonlar ---

# Açılışta aşağıdan hafifçe zıplayarak gelir
func giris(gecikme: float) -> void:
	ic.modulate.a = 0.0
	ic.scale = Vector2(0.86, 0.86)
	ic.position.y = 34.0
	var tween := ic.create_tween().set_parallel()
	tween.tween_property(ic, "modulate:a", 1.0, 0.22).set_delay(gecikme)
	tween.tween_property(ic, "position:y", 0.0, 0.5).set_delay(gecikme).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ic, "scale", Vector2.ONE, 0.5).set_delay(gecikme).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hemen_goster() -> void:
	ic.modulate.a = 1.0
	ic.scale = Vector2.ONE
	ic.position.y = 0.0


# Parmak basınca hafifçe küçülür
func bas() -> void:
	var tween := ic.create_tween()
	tween.tween_property(ic, "scale", Vector2(0.94, 0.94), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Kaydırmaya dönüştü ya da parmak kartın dışında kalktı: eski boyuna döner
func iptal() -> void:
	var tween := ic.create_tween()
	tween.tween_property(ic, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Parmak kalkınca büyüyüp geri oturur, sonra bitince çağrılır (oyun açılır)
func birak(bitince: Callable) -> void:
	var tween := ic.create_tween()
	tween.tween_property(ic, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ic, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(bitince)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_zaman += delta
	# Görsel yavaşça nefes alır
	_gorsel.scale = Vector2.ONE * _gorsel_olcek * (1.0 + sin(_zaman * 1.6 + _faz) * 0.022)
	_gorsel.rotation = sin(_zaman * 1.1 + _faz * 1.3) * 0.018
	if _yeni:
		_yeni.pivot_offset = _yeni.size / 2.0
		_yeni.scale = Vector2.ONE * (1.0 + maxf(0.0, sin(_zaman * 2.2 + _faz)) * 0.06)
