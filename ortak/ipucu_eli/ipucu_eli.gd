class_name IpucuEli
extends CanvasLayer
# Animasyonlu ipucu eli (ortak): çocuğa oyunda ne yapacağını parmakla gösterir.
#   - İlk açılışta (oyun başına bir kez, user://ipucu_eli.cfg) oyun başladıktan ilk_gecikme sn sonra belirir,
#     hareketi `tekrar` kez gösterir.
#   - Sonra yalnızca bekleme_suresi sn hiçbir dokunuş olmazsa yeniden gösterir.
#   - Ekrana dokunulunca yumuşakça kaybolur. Dokunmaları engellemez: yalnızca Node2D çizer, girdiyi okur ama
#     tüketmez; oyunun üstünde ayrı bir katmanda (CanvasLayer) durur.
# Kullanım (oyunun _ready'sinde tek satır + bir fonksiyon):
#   IpucuEli.ekle(self, "ucan_kus", _ipucu)
#   func _ipucu() -> Dictionary:           # sık çağrılır; yalnızca durumu okur. {} = şimdi gösterme
#       if state != State.PLAYING:
#           return {}
#       return IpucuEli.dokun(IpucuEli.ekran_konumu(bird) + Vector2(200, 0))
# Hareketler: dokun, cift_dokun, surukle, basili_tut, kaydir_yatay, goster (basmadan işaret), sira (art arda).
# Konumlar ekran (tasarım) pikseli; Vector2 ya da Vector2 döndüren Callable (izle(): hareket eden nesne).
# Oyunun kendi ipucu varsa: el.engel = func() -> bool: return kendi_ipucu.visible  (o görünürken bu el çekilir)

const KAYIT := "user://ipucu_eli.cfg"
const DOKU: Texture2D = preload("res://ortak/ipucu_eli/el.svg")
const UC := Vector2(104.0, 8.0)        # el.svg (256x256) içinde parmak ucu
const BOY := 150.0                     # elin ekrandaki boyu (tasarım pikseli)
const EGIM := -0.32                    # el hafif sağa yatık
const GELIS := Vector2(70.0, 110.0)    # el parmak ucunun bu kadar sağ altından gelir
const KOYU := Color("2d2447")
const SARI := Color("ffd23f")

## İlk açılışta oyun başladıktan bu kadar saniye sonra belirir
var ilk_gecikme := 0.5
## Bu kadar saniye hiç dokunulmazsa el yeniden gösterir
var bekleme_suresi := 6.0
## Bir gösterimde hareket kaç kez yapılır
var tekrar := 2
## Oyunun kendi ipucu görünürken true döndüren fonksiyon (isteğe bağlı)
var engel: Callable

var _ad := ""
var _hareket: Callable
var _ilk_kez := true
var _hazir := 0.0                      # hareket kaç saniyedir gösterilebilir
var _bos := 0.0                        # kaç saniyedir dokunulmadı
var _parmaklar := {}                   # basılı parmaklar (basılı tutarken boşta sayılmaz)
var _gosteriyor := false
var _calisma := 0                      # her gösterim / gizleme yeni numara alır; eski bekleyişler durur
var _tw: Tween
var _takip: Variant = null             # el bu hedefi izler (hareket eden nesne)
var _yon := Vector2.ONE                # elin yönü: kenara yakın hedefte ayna
var _zaman := 0.0

var _el: Node2D                        # düğüm konumu = parmak ucu
var _cizim: Node2D                     # halka, iz, parlama, dolan halka
var _halkalar: Array = []              # [konum, başlama zamanı]
var _noktalar: Array = []
var _parlamalar: Array = []
var _tutma := {}                       # {konum, oran}


static func ekle(oyun: Node, ad: String, hareket: Callable) -> IpucuEli:
	var el := IpucuEli.new()
	el._ad = ad
	el._hareket = hareket
	oyun.add_child(el)
	return el


# --- Hareket tarifleri (oyunun ipucu fonksiyonu bunlardan birini döndürür) ---

# kosul (isteğe bağlı): el hedefte bekler, true dönünce basar (ör. sallanan kat kulenin üstüne gelince)
static func dokun(konum: Variant, kez := 2, kosul := Callable()) -> Dictionary:
	return {"tur": "dokun", "a": konum, "kez": kez, "kosul": kosul}


static func cift_dokun(a: Variant, b: Variant) -> Dictionary:
	return {"tur": "cift_dokun", "a": a, "b": b}


static func surukle(a: Variant, b: Variant) -> Dictionary:
	return {"tur": "surukle", "a": a, "b": b}


static func basili_tut(konum: Variant, sure := 1.4) -> Dictionary:
	return {"tur": "basili_tut", "a": konum, "sure": sure}


static func kaydir_yatay(konum: Variant, mesafe := 260.0) -> Dictionary:
	return {"tur": "kaydir_yatay", "a": konum, "mesafe": mesafe}


static func goster(konum: Variant) -> Dictionary:
	return {"tur": "goster", "a": konum}


static func sira(adimlar: Array) -> Dictionary:
	return {"tur": "sira", "adimlar": adimlar}


# Nesnenin ekrandaki yeri (Control ise ortası) + ekran pikseli kayma
static func ekran_konumu(oge: CanvasItem, kayma := Vector2.ZERO) -> Vector2:
	if oge is Control:
		return oge.get_global_transform_with_canvas() * ((oge as Control).size / 2.0) + kayma
	return oge.get_global_transform_with_canvas().origin + kayma


# Hareket eden nesne için: el her karede nesnenin o anki yerini gösterir
static func izle(oge: CanvasItem, kayma := Vector2.ZERO) -> Callable:
	var son := [ekran_konumu(oge, kayma)]
	return func() -> Vector2:
		if is_instance_valid(oge) and oge.is_inside_tree():
			son[0] = ekran_konumu(oge, kayma)
		return son[0]


# Geliştirici / test: bütün oyunların "ilk kez gösterildi" bilgisini siler
static func sifirla() -> void:
	if FileAccess.file_exists(KAYIT):
		DirAccess.remove_absolute(KAYIT)


# --- Kurulum ---

func _ready() -> void:
	layer = 20
	var kayit := ConfigFile.new()
	if kayit.load(KAYIT) == OK:
		_ilk_kez = not bool(kayit.get_value("gosterildi", _ad, false))
	_cizim = Node2D.new()
	_cizim.draw.connect(_ciz)
	add_child(_cizim)
	_el = Node2D.new()
	_el.visible = false
	add_child(_el)
	var resim := Sprite2D.new()
	resim.texture = DOKU
	resim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Resim ortalanır; parmak ucu düğümün tam konumuna gelsin diye kaydırılır
	var piksel := DOKU.get_width() / 256.0
	resim.offset = (Vector2(128.0, 128.0) - UC) * piksel
	resim.scale = Vector2.ONE * BOY / DOKU.get_height()
	_el.add_child(resim)


func _hareket_al() -> Dictionary:
	if not _hareket.is_valid():
		return {}
	var h: Variant = _hareket.call()
	return h if h is Dictionary else {}


func _engelli() -> bool:
	return engel.is_valid() and bool(engel.call())


func _process(delta: float) -> void:
	_zaman += delta
	if _takip != null:
		_el.position = _nokta(_takip)
	if not (_halkalar.is_empty() and _noktalar.is_empty() and _parlamalar.is_empty() and _tutma.is_empty()):
		_cizim.queue_redraw()

	var musait := not _hareket_al().is_empty() and not _engelli()
	if not musait:
		_hazir = 0.0
		_bos = 0.0
		if _gosteriyor:
			_gizle()
		return
	_hazir += delta
	if _gosteriyor:
		return
	if not _parmaklar.is_empty():
		_bos = 0.0
		return
	_bos += delta
	if _ilk_kez and _hazir >= ilk_gecikme:
		_ilk_kez = false
		_kaydet()
		_goster()
	elif not _ilk_kez and _bos >= bekleme_suresi:
		_goster()


func _input(event: InputEvent) -> void:
	# Sadece izlenir; olay tüketilmez (oyun aynı dokunuşu alır)
	if event is InputEventScreenTouch:
		if event.pressed:
			_parmaklar[event.index] = true
			_dokunuldu()
		else:
			_parmaklar.erase(event.index)
	elif event is InputEventScreenDrag or (event is InputEventKey and event.pressed):
		_dokunuldu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_parmaklar.clear()


func _dokunuldu() -> void:
	_bos = 0.0
	if _gosteriyor:
		_gizle()


func _kaydet() -> void:
	var kayit := ConfigFile.new()
	kayit.load(KAYIT)
	kayit.set_value("gosterildi", _ad, true)
	GuvenliKayit.save_config(kayit, KAYIT)


# --- Gösterim ---

func _goster() -> void:
	_gosteriyor = true
	_calisma += 1
	var no := _calisma
	for i in tekrar:
		var h := _hareket_al()
		if h.is_empty():
			break
		await _oynat(h, no)
		if no != _calisma:
			return
	await _cik(no)
	if no == _calisma:
		_gosteriyor = false
		_bos = 0.0


# Dokunulunca ya da durum değişince: el hemen ama yumuşakça kaybolur
func _gizle() -> void:
	_calisma += 1
	_gosteriyor = false
	_takip = null
	_tutma = {}
	if _tw:
		_tw.kill()
	if _el.visible:
		_tw = create_tween()
		_tw.tween_property(_el, "modulate:a", 0.0, 0.15)
		_tw.tween_callback(_el.hide)


func _oynat(h: Dictionary, no: int) -> void:
	match h["tur"]:
		"sira":
			var adimlar: Array = h["adimlar"]
			if adimlar.is_empty():
				return
			await _gel(adimlar[0]["a"], no)
			for adim: Dictionary in adimlar:
				if no != _calisma:
					return
				await _git(adim["a"], 0.45, no)
				await _eylem(adim, no, 1)
		_:
			await _gel(h["a"], no)
			await _eylem(h, no, int(h.get("kez", 2)))
	await _bekle(0.25, no)
	await _cik(no)


# Hedefte yapılan asıl hareket (el zaten "a" noktasında)
func _eylem(h: Dictionary, no: int, kez: int) -> void:
	match h["tur"]:
		"dokun":
			for i in kez:
				await _kosulu_bekle(h.get("kosul", Callable()), no)
				await _bas(no, true)
				await _bas_birak(no)
				await _bekle(0.3, no)
		"cift_dokun":
			await _bas(no, true)
			await _bas_birak(no)
			await _bekle(0.25, no)
			await _git(h["b"], 0.5, no)
			await _bas(no, true)
			await _bas_birak(no)
			await _bekle(0.3, no)
		"surukle":
			await _bas(no, false)
			await _git(h["b"], 1.0, no, true)
			await _bas_birak(no)
			_parlamalar.append([_nokta(h["b"]), _zaman])
			await _bekle(0.35, no)
		"basili_tut":
			await _bas(no, false)
			var sure: float = h["sure"]
			_tutma = {"konum": _el.position, "oran": 0.0}
			_tw = create_tween()
			_tw.tween_method(func(t: float) -> void: _tutma = {"konum": _el.position, "oran": t}, 0.0, 1.0, sure)
			await _tw.finished
			if no != _calisma:
				return
			_parlamalar.append([_el.position, _zaman])
			_tutma = {}
			await _bas_birak(no)
			await _bekle(0.3, no)
		"kaydir_yatay":
			var orta: Variant = h["a"]
			var yari: float = h["mesafe"] / 2.0
			await _bas(no, false)
			await _git(func() -> Vector2: return _nokta(orta) + Vector2(yari, 0.0), 0.5, no, true)
			await _git(func() -> Vector2: return _nokta(orta) - Vector2(yari, 0.0), 0.9, no, true)
			await _git(orta, 0.5, no, true)
			await _bas_birak(no)
			await _bekle(0.2, no)
		"goster":
			# Basmadan işaret eder: iki kez hafifçe öne uzanır
			for i in 2:
				_takip = null
				var p := _el.position
				_tw = create_tween()
				_tw.tween_property(_el, "position", p + Vector2(-8.0 * _yon.x, -14.0 * _yon.y), 0.2).set_trans(Tween.TRANS_SINE)
				_tw.tween_property(_el, "position", p, 0.25).set_trans(Tween.TRANS_SINE)
				await _tw.finished
				if no != _calisma:
					return
			_takip = h["a"]
			await _bekle(0.2, no)


# El, ilk hedefin sağ altından süzülerek gelir
func _gel(hedef: Variant, no: int) -> void:
	if no != _calisma:
		return
	var p := _nokta(hedef)
	_yon_sec(p)
	_takip = null
	_el.position = p + GELIS * _yon
	_el.scale = _yon
	_el.rotation = EGIM * _yon.x * _yon.y
	_el.modulate.a = 0.0
	_el.show()
	_tw = create_tween()
	_tw.tween_property(_el, "modulate:a", 1.0, 0.25)
	var bas := _el.position
	_tw.parallel().tween_method(func(t: float) -> void: _el.position = bas.lerp(_nokta(hedef), t), 0.0, 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tw.finished
	if no == _calisma:
		_takip = hedef


func _git(hedef: Variant, sure: float, no: int, iz := false) -> void:
	if no != _calisma:
		return
	_takip = null
	var bas := _el.position
	var son_iz := [bas]
	var adim := func(t: float) -> void:
		_el.position = bas.lerp(_nokta(hedef), t)
		if iz and _el.position.distance_to(son_iz[0]) >= 26.0:
			son_iz[0] = _el.position
			_noktalar.append([_el.position, _zaman])
	_tw = create_tween()
	_tw.tween_method(adim, 0.0, 1.0, sure).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tw.finished
	if no == _calisma:
		_takip = hedef


func _bas(no: int, halka: bool) -> void:
	if no != _calisma:
		return
	_tw = create_tween()
	_tw.tween_property(_el, "scale", _yon * 0.86, 0.12).set_trans(Tween.TRANS_SINE)
	await _tw.finished
	if no == _calisma and halka:
		_halkalar.append([_el.position, _zaman])


func _bas_birak(no: int) -> void:
	if no != _calisma:
		return
	_tw = create_tween()
	_tw.tween_property(_el, "scale", _yon, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _tw.finished


# Koşul true olana kadar (en çok 3 sn) bekler
func _kosulu_bekle(kosul: Callable, no: int) -> void:
	if not kosul.is_valid():
		return
	var bitis := _zaman + 3.0
	while is_inside_tree() and no == _calisma and _zaman < bitis and not bool(kosul.call()):
		await get_tree().process_frame


func _bekle(sure: float, no: int) -> void:
	if no != _calisma:
		return
	_tw = create_tween()
	_tw.tween_interval(sure)
	await _tw.finished


func _cik(no: int) -> void:
	if no != _calisma or not _el.visible:
		return
	_takip = null
	_tw = create_tween()
	_tw.tween_property(_el, "modulate:a", 0.0, 0.25)
	_tw.parallel().tween_property(_el, "position", _el.position + GELIS * _yon * 0.4, 0.25)
	await _tw.finished
	if no == _calisma:
		_el.hide()


# --- Konum ---

# Hedef noktası, güvenli alanın içinde
func _nokta(hedef: Variant) -> Vector2:
	var p: Vector2 = hedef.call() if hedef is Callable else hedef
	var alan := EkranYardimcisi.guvenli_alan().grow(-16.0)
	return p.clamp(alan.position, alan.end)


# Hedef sağ ya da alt kenara yakınsa el aynalanır (gövdesi ekranın içinde kalsın)
func _yon_sec(p: Vector2) -> void:
	var alan := EkranYardimcisi.guvenli_alan()
	_yon = Vector2(-1.0 if p.x > alan.end.x - BOY * 0.75 else 1.0, -1.0 if p.y > alan.end.y - BOY * 0.95 else 1.0)


# --- Efektler ---

func _ciz() -> void:
	_halkalar = _halkalar.filter(func(h: Array) -> bool: return _zaman - h[1] < 0.55)
	_noktalar = _noktalar.filter(func(n: Array) -> bool: return _zaman - n[1] < 0.9)
	_parlamalar = _parlamalar.filter(func(p: Array) -> bool: return _zaman - p[1] < 0.8)
	for h: Array in _halkalar:
		var k: float = (_zaman - h[1]) / 0.55
		var r := lerpf(14.0, 64.0, 1.0 - pow(1.0 - k, 2.0))
		_cizim.draw_arc(h[0], r, 0.0, TAU, 48, Color(KOYU, 0.45 * (1.0 - k)), 11.0, true)
		_cizim.draw_arc(h[0], r, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - k), 6.0, true)
	for n: Array in _noktalar:
		var a: float = 1.0 - (_zaman - n[1]) / 0.9
		_cizim.draw_circle(n[0], 8.5, Color(KOYU, 0.5 * a))
		_cizim.draw_circle(n[0], 6.0, Color(1, 1, 1, a))
	for p: Array in _parlamalar:
		var k: float = (_zaman - p[1]) / 0.8
		for i in 4:
			_cizim.draw_circle(p[0], (30.0 + 22.0 * i) * (0.6 + 0.6 * k), Color(1.0, 0.95, 0.6, 0.16 * (1.0 - k)))
	if not _tutma.is_empty():
		var c: Vector2 = _tutma["konum"]
		var oran: float = _tutma["oran"]
		_cizim.draw_arc(c, 52.0, 0.0, TAU, 64, Color(KOYU, 0.35), 14.0, true)
		_cizim.draw_arc(c, 52.0, 0.0, TAU, 64, Color(1, 1, 1, 0.6), 8.0, true)
		if oran > 0.0:
			_cizim.draw_arc(c, 52.0, -PI / 2.0, -PI / 2.0 + TAU * oran, 64, SARI, 9.0, true)
