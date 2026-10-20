class_name OyunBitti
extends CanvasLayer
# Ortak final ekranı: bölümlü bir oyunun son bölümü bitince büyük kutlama (parlayan kupa, konfeti, yıldız
# yağmuru, zıplayan "Hepsini bitirdin!", oyunun karakteri dans eder), sonra büyük simgeli düğmeler:
# bölüm seç, baştan oyna, (varsa) sonsuz mod, ana menü. Tamamlanan oyun user://oyun_bitti.cfg'ye yazılır;
# bu bilgiyi yalnızca ebeveyn bölümündeki "ilerlemeyi sıfırla" siler (Lisanslar ekranı).
# Kullanım (son bölüm bittiğinde):
#   OyunBitti.goster(self, {
#       "ad": "yol_yap",                       # oyun klasörü (kayıt anahtarı)
#       "karakter": preload(".../bilye.svg"),  # kupanın yanında dans eden görsel
#       "bolum_sayisi": 10,
#       "bolum_baslat": func(i): ...,           # ızgaradan bölüm seçilince (oyunun kendi seçme ekranı yoksa)
#       "bolum_secme_ekrani": func(): ...,      # (isteğe bağlı) oyunun kendi bölüm seçme ekranı varsa onu açar
#       "bastan": func(): ...,                  # 1. bölümden başlat
#       "sonsuz": func(): ...,                  # (isteğe bağlı) yalnızca sonsuz modu olan oyunlarda
#       "yildizlar": [3, 2, -1, ...],           # (isteğe bağlı) bölüm başına kazanılan yıldız
#       "kisa": true,                           # tamamlanmış oyun yeniden açılınca: kısaltılmış kutlama
#   })
# Ekran oyunun üstünde ayrı bir katmanda (30) durur ve açıkken bütün dokunuşları kendisi alır (oyun altta
# tepki vermez). Oyun sahnesi kapanınca kendisi de kapanır.
# Geliştirici kısayolu (yalnızca debug derlemede): OyunBitti.kisayol(self, bolumu_bitir) → F9 o anki bölümü bitirir.

const KAYIT := "user://oyun_bitti.cfg"
const KUPA: Texture2D = preload("res://ortak/oyun_bitti/kupa.svg")
const YILDIZ: Texture2D = preload("res://ortak/oyun_bitti/yildiz.svg")
const IKONLAR := {
	"secim": preload("res://ortak/oyun_bitti/ikon_bolumler.svg"),
	"bastan": preload("res://ortak/oyun_bitti/ikon_bastan.svg"),
	"sonsuz": preload("res://ortak/oyun_bitti/ikon_sonsuz.svg"),
	"menu": preload("res://ortak/oyun_bitti/ikon_ev.svg"),
}
const RENKLER := {"secim": Color("3e8eeb"), "bastan": Color("2fae62"), "sonsuz": Color("8a6cf0"), "menu": Color("ff7a45")}
const GOKKUSAGI := [Color("ff5a5a"), Color("ff9f40"), Color("ffc93d"), Color("5cc95c"), Color("4fa8ff"), Color("a66bff")]
const KOYU := Color("2d2447")
const DUGME := 150.0

static var acik := false               # bir final ekranı açık mı (ipucu eli bu sırada gösterilmez)

var _ayar: Dictionary = {}
var _kok: Control
var _zemin: ColorRect
var _isinlar: Node2D
var _kupa: Sprite2D
var _karakter: Sprite2D
var _yazi: HBoxContainer
var _dugmeler: Array = []              # [Control, eylem]
var _izgara: Control
var _hucreler: Array = []              # [Control, bölüm]
var _kapat_dugmesi: Control
var _hazir := false                    # düğmeler göründü mü
var _kapaniyor := false
var _zaman := 0.0


# --- Kayıt ---

static func tamamlandi_mi(ad: String) -> bool:
	var kayit := ConfigFile.new()
	return kayit.load(KAYIT) == OK and bool(kayit.get_value("tamamlandi", ad, false))


static func tamamla(ad: String) -> void:
	var kayit := ConfigFile.new()
	kayit.load(KAYIT)
	kayit.set_value("tamamlandi", ad, true)
	GuvenliKayit.save_config(kayit, KAYIT)


# Yalnızca ebeveyn bölümünden (ilerlemeyi sıfırla) çağrılır
static func sifirla(ad: String) -> void:
	var kayit := ConfigFile.new()
	if kayit.load(KAYIT) == OK and kayit.has_section_key("tamamlandi", ad):
		kayit.erase_section_key("tamamlandi", ad)
		GuvenliKayit.save_config(kayit, KAYIT)


# --- Açma ---

static func goster(oyun: Node, ayar: Dictionary) -> OyunBitti:
	if not ayar.get("kisa", false):
		tamamla(ayar["ad"])
	var ekran := OyunBitti.new()
	ekran._ayar = ayar
	# Kök pencerenin son çocuğu: dokunuşları oyundan önce alır
	oyun.get_tree().root.add_child(ekran)
	oyun.tree_exiting.connect(ekran.queue_free)
	return ekran


# Geliştirici kısayolu: yalnızca debug derlemede F9 o anki bölümü bitirir (yayında hiçbir şey eklenmez)
static func kisayol(oyun: Node, bolumu_bitir: Callable) -> void:
	if not OS.is_debug_build():
		return
	var dugum := _Kisayol.new()
	dugum.bitir = bolumu_bitir
	oyun.add_child(dugum)


class _Kisayol extends Node:
	var bitir: Callable

	func _input(event: InputEvent) -> void:
		var tus := event as InputEventKey
		if tus and tus.pressed and not tus.echo and tus.keycode == KEY_F9 and not OyunBitti.acik:
			print("Geliştirici kısayolu (F9): bölüm bitiriliyor")
			bitir.call()


func _ready() -> void:
	layer = 30
	acik = true
	var boyut := EkranYardimcisi.gorunen_boyut()
	_kok = Control.new()
	_kok.size = boyut
	_kok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kok)
	_zemin = ColorRect.new()
	_zemin.color = Color(KOYU, 0.0)
	_zemin.size = boyut
	_zemin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kok.add_child(_zemin)
	var alan := EkranYardimcisi.tasarim_alani()
	var kupa_yeri := alan.position + Vector2(alan.size.x * 0.5, 300.0)
	_isinlar = Node2D.new()
	_isinlar.position = kupa_yeri
	_isinlar.draw.connect(_isinlari_ciz)
	_isinlar.modulate.a = 0.0
	_kok.add_child(_isinlar)
	_kupa = _resim(KUPA, 250.0)
	_kupa.position = kupa_yeri
	_kupa.scale = Vector2.ZERO
	_kok.add_child(_kupa)
	if _ayar.get("karakter") is Texture2D:
		_karakter = _resim(_ayar["karakter"], 190.0)
		_karakter.position = kupa_yeri + Vector2(-260.0, 50.0)
		_karakter.scale = Vector2.ZERO
		_kok.add_child(_karakter)
	_yaziyi_kur(alan)
	_dugmeleri_kur(alan)
	_kutla()


func _exit_tree() -> void:
	acik = false


func _resim(doku: Texture2D, boy: float) -> Sprite2D:
	var resim := Sprite2D.new()
	resim.texture = doku
	resim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resim.set_meta("olcek", boy / maxf(doku.get_width(), doku.get_height()))
	return resim


func _yaziyi_kur(alan: Rect2) -> void:
	_yazi = HBoxContainer.new()
	_yazi.alignment = BoxContainer.ALIGNMENT_CENTER
	_yazi.add_theme_constant_override("separation", 0)
	_yazi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_yazi.position = Vector2(alan.position.x, alan.position.y + 40.0)
	_yazi.size = Vector2(alan.size.x, 110.0)
	_kok.add_child(_yazi)
	var metin := tr("Hepsini bitirdin!")
	for i in metin.length():
		var harf := Label.new()
		harf.text = metin[i]
		harf.add_theme_font_size_override("font_size", 84)
		harf.add_theme_color_override("font_color", GOKKUSAGI[i % GOKKUSAGI.size()])
		harf.add_theme_color_override("font_outline_color", Color.WHITE)
		harf.add_theme_constant_override("outline_size", 22)
		harf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		harf.modulate.a = 0.0
		_yazi.add_child(harf)


func _dugmeleri_kur(alan: Rect2) -> void:
	var eylemler := ["secim", "bastan"]
	if _ayar.get("sonsuz") is Callable:
		eylemler.append("sonsuz")
	eylemler.append("menu")
	var aralik := 56.0
	var genislik := eylemler.size() * DUGME + (eylemler.size() - 1) * aralik
	var x := alan.position.x + (alan.size.x - genislik) * 0.5
	var y := alan.end.y - DUGME - maxf(48.0, EkranYardimcisi.guvenli_bosluklar()["alt"] + 24.0)
	for eylem: String in eylemler:
		var dugme := _yuvarlak_dugme(IKONLAR[eylem], RENKLER[eylem], DUGME)
		dugme.position = Vector2(x, y)
		dugme.scale = Vector2.ZERO
		dugme.visible = false
		_kok.add_child(dugme)
		_dugmeler.append([dugme, eylem])
		x += DUGME + aralik


func _yuvarlak_dugme(ikon: Texture2D, renk: Color, cap: float) -> Control:
	var stil := StyleBoxFlat.new()
	stil.bg_color = renk
	stil.set_corner_radius_all(int(cap / 2.0))
	stil.set_border_width_all(7)
	stil.border_color = Color.WHITE
	stil.shadow_color = Color(0, 0, 0, 0.3)
	stil.shadow_size = 10
	stil.shadow_offset = Vector2(0, 6)
	var dugme := Panel.new()
	dugme.add_theme_stylebox_override("panel", stil)
	dugme.size = Vector2(cap, cap)
	dugme.pivot_offset = dugme.size / 2.0
	dugme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resim := TextureRect.new()
	resim.texture = ikon
	resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resim.size = Vector2(cap, cap) * 0.58
	resim.position = (Vector2(cap, cap) - resim.size) / 2.0
	resim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dugme.add_child(resim)
	return dugme


# --- Kutlama ---

func _kutla() -> void:
	var kisa: bool = _ayar.get("kisa", false)
	var hiz := 0.45 if kisa else 1.0
	var ses := get_tree().root.get_node_or_null("SesYoneticisi")
	if ses and not kisa:
		ses.ezgi("kutlama")
		ses.efekt("konfeti", -3.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_zemin, "color:a", 0.9, 0.35 * hiz)
	tw.tween_property(_isinlar, "modulate:a", 1.0, 0.5 * hiz).set_delay(0.2 * hiz)
	var kupa_olcek: float = _kupa.get_meta("olcek")
	tw.tween_property(_kupa, "scale", Vector2.ONE * kupa_olcek * 1.18, 0.45 * hiz).set_delay(0.2 * hiz) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_kupa, "scale", Vector2.ONE * kupa_olcek, 0.2 * hiz)
	if _karakter:
		var olcek: float = _karakter.get_meta("olcek")
		create_tween().tween_property(_karakter, "scale", Vector2.ONE * olcek, 0.4 * hiz).set_delay(0.45 * hiz) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_dans(olcek, 0.85 * hiz)
	for i in _yazi.get_child_count():
		_harf_zipla(_yazi.get_child(i) as Label, 0.5 * hiz + i * 0.05 * hiz)
	_konfeti(80 if kisa else 220, Color.WHITE, null)
	if not kisa:
		_konfeti(40, Color.WHITE, YILDIZ)
	get_tree().create_timer(0.9 if kisa else 2.6).timeout.connect(_dugmeleri_goster)


# Karakter kupanın yanında zıplayıp sağa sola sallanır
func _dans(olcek: float, gecikme: float) -> void:
	await get_tree().create_timer(gecikme).timeout
	if not is_instance_valid(_karakter):
		return
	var bas := _karakter.position
	var tw := _karakter.create_tween().set_loops()
	tw.tween_property(_karakter, "scale", Vector2(olcek * 1.15, olcek * 0.85), 0.12)
	tw.tween_property(_karakter, "position", bas + Vector2(0, -60), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_karakter, "scale", Vector2(olcek * 0.92, olcek * 1.1), 0.22)
	tw.parallel().tween_property(_karakter, "rotation", 0.18, 0.22)
	tw.tween_property(_karakter, "position", bas, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_karakter, "rotation", -0.18, 0.2)
	tw.tween_property(_karakter, "scale", Vector2(olcek * 1.12, olcek * 0.88), 0.08)
	tw.tween_property(_karakter, "scale", Vector2.ONE * olcek, 0.1)
	tw.tween_property(_karakter, "rotation", 0.0, 0.1)


func _harf_zipla(harf: Label, gecikme: float) -> void:
	harf.pivot_offset = harf.get_minimum_size() / 2.0
	var tw := harf.create_tween()
	tw.tween_interval(gecikme)
	tw.tween_property(harf, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(harf, "position:y", -40.0, 0.18).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(harf, "position:y", 40.0, 0.18).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Sonra harfler sırayla hafifçe zıplamayı sürdürür
	var dongu := harf.create_tween().set_loops()
	dongu.tween_interval(gecikme + 0.6)
	dongu.tween_property(harf, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_SINE)
	dongu.tween_property(harf, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	dongu.tween_interval(1.4)


# Ekranın üstünden yağan konfeti (dokusuz: renkli kareler) ya da yıldızlar
func _konfeti(adet: int, renk: Color, doku: Texture2D) -> void:
	var boyut := EkranYardimcisi.gorunen_boyut()
	var p := CPUParticles2D.new()
	p.position = Vector2(boyut.x * 0.5, -30.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(boyut.x * 0.5, 10.0)
	p.amount = adet
	p.lifetime = 3.2
	p.one_shot = true
	p.explosiveness = 0.35
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 260.0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	if doku:
		p.texture = doku
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.7
	else:
		p.scale_amount_min = 9.0
		p.scale_amount_max = 16.0
		var renkler := Gradient.new()
		renkler.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		renkler.colors = PackedColorArray(GOKKUSAGI)
		renkler.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		p.color_initial_ramp = renkler
	p.color = renk
	p.emitting = true
	_kok.add_child(p)
	p.finished.connect(p.queue_free)


func _isinlari_ciz() -> void:
	for i in 12:
		var a := _zaman * 0.35 + i * TAU / 12.0
		var nokta := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.12) * 900.0, Vector2.from_angle(a + 0.12) * 900.0])
		_isinlar.draw_colored_polygon(nokta, Color(1.0, 0.92, 0.55, 0.13))
	for i in 4:
		_isinlar.draw_circle(Vector2.ZERO, 170.0 - i * 32.0, Color(1.0, 0.9, 0.45, 0.10))


func _dugmeleri_goster() -> void:
	if _hazir or _kapaniyor:
		return
	_hazir = true
	for i in _dugmeler.size():
		var dugme: Control = _dugmeler[i][0]
		dugme.visible = true
		dugme.create_tween().tween_property(dugme, "scale", Vector2.ONE, 0.35).set_delay(i * 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_zaman += delta
	_isinlar.queue_redraw()
	# Kupa yavaşça nefes alır gibi parlar
	_kupa.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.0), (sin(_zaman * 3.0) + 1.0) * 0.25)


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	# Açıkken bütün dokunuşlar burada kalır (alttaki oyun tepki vermesin); tuşlar (Escape) geçer
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		var dokunma := event as InputEventScreenTouch
		if dokunma and dokunma.pressed and not _kapaniyor:
			_dokunuldu(dokunma.position)


func _dokunuldu(nokta: Vector2) -> void:
	if not _hazir:
		_dugmeleri_goster()          # kutlamayı beklemek istemeyen çocuk için
		return
	if _izgara:
		if _kapat_dugmesi.get_global_rect().grow(16.0).has_point(nokta):
			_sec_sesi()
			_izgarayi_kapat()
			return
		for hucre: Array in _hucreler:
			if (hucre[0] as Control).get_global_rect().grow(6.0).has_point(nokta):
				_sec_sesi()
				var bolum: int = hucre[1]
				_kapat(func() -> void: _ayar["bolum_baslat"].call(bolum))
				return
		return
	for satir: Array in _dugmeler:
		var dugme: Control = satir[0]
		if dugme.visible and dugme.get_global_rect().grow(14.0).has_point(nokta):
			_sec_sesi()
			_bas(dugme)
			_eylem(satir[1])
			return


func _eylem(eylem: String) -> void:
	match eylem:
		"secim":
			if _ayar.get("bolum_secme_ekrani") is Callable:
				_kapat(_ayar["bolum_secme_ekrani"])
			else:
				_izgarayi_ac()
		"bastan":
			_kapat(_ayar["bastan"])
		"sonsuz":
			_kapat(_ayar["sonsuz"])
		"menu":
			_kapaniyor = true
			get_tree().root.get_node("SahneGecis").ana_menuye_don()


func _sec_sesi() -> void:
	var ses := get_tree().root.get_node_or_null("SesYoneticisi")
	if ses:
		ses.efekt("dugme_tik")


func _bas(dugme: Control) -> void:
	var tw := dugme.create_tween()
	tw.tween_property(dugme, "scale", Vector2(0.88, 0.88), 0.07)
	tw.tween_property(dugme, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Ekran yumuşakça kapanır, sonra oyunun verdiği iş yapılır
func _kapat(sonra: Callable) -> void:
	if _kapaniyor:
		return
	_kapaniyor = true
	acik = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_kok, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		if sonra.is_valid():
			sonra.call()
		queue_free())


# --- Bölüm seçme ızgarası (oyunun kendi seçme ekranı yoksa) ---

func _izgarayi_ac() -> void:
	for satir: Array in _dugmeler:
		(satir[0] as Control).visible = false
	var sayi: int = _ayar.get("bolum_sayisi", 1)
	var yildizlar: Array = _ayar.get("yildizlar", [])
	var sutun := 5 if sayi <= 20 else 6
	var satir_sayisi := ceili(sayi / float(sutun))
	var hucre := 112.0 if satir_sayisi <= 4 else 92.0
	var aralik := 18.0
	var ic := Vector2(sutun * hucre + (sutun - 1) * aralik, satir_sayisi * hucre + (satir_sayisi - 1) * aralik)
	var alan := EkranYardimcisi.tasarim_alani()
	_izgara = Panel.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color("fbf8ff")
	stil.set_corner_radius_all(36)
	stil.set_border_width_all(6)
	stil.border_color = Color("c9c0f5")
	_izgara.add_theme_stylebox_override("panel", stil)
	_izgara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_izgara.size = ic + Vector2(64, 64)
	_izgara.position = alan.get_center() - _izgara.size / 2.0 + Vector2(0, 40)
	_kok.add_child(_izgara)
	_hucreler.clear()
	for i in sayi:
		var kutu := _hucre(i, hucre, int(yildizlar[i]) if i < yildizlar.size() else -1)
		kutu.position = Vector2(32, 32) + Vector2(i % sutun, floori(i / float(sutun))) * (hucre + aralik)
		_izgara.add_child(kutu)
		_hucreler.append([kutu, i])
	_kapat_dugmesi = _yuvarlak_dugme(IKONLAR["menu"], RENKLER["menu"], 96.0)
	(_kapat_dugmesi.get_child(0) as TextureRect).texture = preload("res://ortak/gorseller/geri.svg")
	_kapat_dugmesi.position = _izgara.position + Vector2(-48, -48)
	_kok.add_child(_kapat_dugmesi)
	_izgara.pivot_offset = _izgara.size / 2.0
	_izgara.scale = Vector2(0.8, 0.8)
	_izgara.create_tween().tween_property(_izgara, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hucre(i: int, boy: float, yildiz: int) -> Control:
	var stil := StyleBoxFlat.new()
	stil.bg_color = GOKKUSAGI[i % GOKKUSAGI.size()]
	stil.set_corner_radius_all(26)
	stil.set_border_width_all(5)
	stil.border_color = Color.WHITE
	stil.shadow_color = Color(0, 0, 0, 0.2)
	stil.shadow_size = 6
	stil.shadow_offset = Vector2(0, 4)
	var kutu := Panel.new()
	kutu.add_theme_stylebox_override("panel", stil)
	kutu.size = Vector2(boy, boy)
	kutu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sayi := Label.new()
	sayi.text = str(i + 1)
	sayi.add_theme_font_size_override("font_size", int(boy * 0.46))
	sayi.add_theme_color_override("font_color", Color.WHITE)
	sayi.add_theme_color_override("font_outline_color", KOYU)
	sayi.add_theme_constant_override("outline_size", 12)
	sayi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sayi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sayi.size = Vector2(boy, boy * (0.78 if yildiz >= 0 else 1.0))
	sayi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kutu.add_child(sayi)
	if yildiz >= 0:
		# Kazanılan yıldızlar (3 üzerinden): dolu altın, eksikler soluk
		for k in 3:
			var y := TextureRect.new()
			y.texture = YILDIZ
			y.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			y.size = Vector2(boy * 0.24, boy * 0.24)
			y.position = Vector2(boy * 0.5 + (k - 1) * boy * 0.26 - y.size.x / 2.0, boy * 0.7)
			y.modulate = Color.WHITE if k < yildiz else Color(1, 1, 1, 0.3)
			y.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kutu.add_child(y)
	return kutu


func _izgarayi_kapat() -> void:
	_izgara.queue_free()
	_izgara = null
	_kapat_dugmesi.queue_free()
	_kapat_dugmesi = null
	_hucreler.clear()
	for satir: Array in _dugmeler:
		(satir[0] as Control).visible = true
