extends Node2D
# Hastanın üstündeki bir tedavi noktası (TreatSpot; Hayvan Banyosu'ndaki leke.gd'nin genelleşmesi). Hastanın gövde
# ya da kafa tuvalinin (256 birim) çocuğudur; konumu ve yarıçapı tuval biriminde. steps'teki aletleri sırayla bekler
# (stage); her aşamada amount 1'den 0'a iner (o aşamanın aleti etki ettikçe), 0 olunca sonraki aşamaya geçer.
# Görünüşü rahatsızlığa göre (look); katmanlar aletlerin ilerlemesine (progress) bağlıdır, aşama sırasına değil:
#   dinle / agiz: görünmez hedef; sırası gelince (active) nabız gibi atan sarı halka (stetoskop, şurup kaşığı)
#   siyrik:   yara + kir (pamuk) → merhem katmanı (merhem) → yara bandı (bant)
#   diken:    kızarıklık ve diken(ler) (cımbızla birer birer çekilir, yerinde minik nokta kalır) → merhem → bant
#   ates:     alında kızarıklık ve ter damlaları (buz sürüldükçe geçer; termometre yalnızca ölçer)
#   nezle:    kırmızı burun ve burun damlası (mendil)
#   dis:      ağız çevresinde yemek kırıntıları (diş fırçası; fırçalarken köpük)
#   sislik:   şiş yanak (buz sürüldükçe iner)
#   benek:    kabarık kırmızı benek (krem: söner, üstünde krem) → pudra
#   kulak:    kulakta kızarıklık ve kir (kulak çubuğu) → damla (kızarıklık geçer)
#   burkulma: şiş, kızarık bilek ve ağrı çizgileri (buz) → sarılmış bilek (sargı)
#   goz:      kızarık göz, toz (damla) ve gözyaşı (mendil)

const TEX: Dictionary = {
	"yara": preload("res://oyunlar/hayvan_doktoru/gorseller/yara.svg"),
	"kir": preload("res://oyunlar/hayvan_doktoru/gorseller/kir.svg"),
	"merhem": preload("res://oyunlar/hayvan_doktoru/gorseller/merhem_kat.svg"),
	"bant": preload("res://oyunlar/hayvan_doktoru/gorseller/bant.svg"),
	"diken": preload("res://oyunlar/hayvan_doktoru/gorseller/diken.svg"),
	"kizarik": preload("res://oyunlar/hayvan_doktoru/gorseller/kizarik.svg"),
	"damla": preload("res://oyunlar/hayvan_doktoru/gorseller/su_damlasi.svg"),
	"benek": preload("res://oyunlar/hayvan_doktoru/gorseller/benek.svg"),
	"pudra": preload("res://oyunlar/hayvan_doktoru/gorseller/pudra_kat.svg"),
	"kopuk": preload("res://oyunlar/hayvan_doktoru/gorseller/kopuk.svg"),
	"sargi": preload("res://oyunlar/hayvan_doktoru/gorseller/sargi_kat.svg"),
}
const RING := Color("ffd23f")
const OUT := Color("3b2f6b")
const PAIN := Color("ff4d6a")
const HOLE := Color("e24a66")
const CRUMBS := Color(1.0, 0.85, 0.45)    # kir görselini yemek kırıntısı yapar
const WAX := Color(1.0, 0.8, 0.5)
const DUST := Color(0.75, 0.72, 0.85)

var look: String = ""
var steps: Array[String] = []
var stage: int = 0
var amount: float = 1.0
var radius: float = 24.0
## Sırası gelen hedef: görünmez noktalarda (dinle, agiz) sarı halka çizilir
var active: bool = false
## Ten rengi (şiş yanak çizimi için)
var skin: Color = Color.WHITE

var _layers: Dictionary = {}          # ad -> Sprite2D
var _thorns: Array[Sprite2D] = []
var _pulled: int = 0                  # çekilen diken sayısı
var _pull: float = 0.0                # şu an çekilen dikenin çıkışı (0..1)
var _shown: float = 1.0               # amount'un ekrandaki (yumuşatılmış) değeri
var _time: float = 0.0
var _pulse: float = 0.0               # ipucu parlaması (1 → 0)
var _wiggle: float = 0.0              # alet etki ederken kıpırdama
var _stick: float = 0.0               # bant / sargı yapışınca kısa zıplama (1 → 0)


## options: "thorns" (diken sayısı), "skin" (ten rengi), "side" (-1 sol, 1 sağ: göz, yanak, kulak)
func setup(spot_look: String, spot_steps: Array[String], spot_radius: float, options: Dictionary = {}) -> void:
	look = spot_look
	steps = spot_steps
	radius = spot_radius
	skin = options.get("skin", Color.WHITE)
	_time = randf() * 10.0
	var r := radius
	var angle := randf_range(-0.35, 0.35)
	match look:
		"siyrik":
			_add("yara", r * 2.6, angle)
			_add("kir", r * 2.6, angle)
			_add("merhem", r * 2.7, angle)
			_add("bant", r * 3.3, angle - 0.25)
		"diken":
			_add("kizarik", r * 2.4)
			_add("merhem", r * 2.3, angle)
			var count: int = options.get("thorns", 1)
			for k in count:
				var thorn := _add("diken%d" % k, r * 0.9, 0.0, TEX["diken"])
				var a := (k - (count - 1) / 2.0) * 0.6
				thorn.rotation = a
				thorn.position = Vector2((k - (count - 1) / 2.0) * r * 0.6, r * 0.1)
				thorn.offset = Vector2(0.0, -thorn.texture.get_height() * 0.4)
				thorn.set_meta("home", thorn.position)
				_thorns.append(thorn)
			_add("bant", r * 3.3, angle - 0.25)
		"ates":
			_add("kizarik", r * 3.4)
			for k in 2:
				_add("ter%d" % k, r * 0.5, 0.0, TEX["damla"])
		"nezle":
			_add("kizarik", r * 1.8)
			_add("akinti", r * 0.45, 0.0, TEX["damla"])
		"dis":
			_add("kir", r * 2.2, angle, TEX["kir"]).self_modulate = CRUMBS
			_add("kopuk", r * 2.6)
		"sislik":
			_add("kizarik", r * 2.2)
		"benek":
			_add("benek", r * 1.15)
			_add("merhem", r * 1.8, angle)
			_add("pudra", r * 2.2)
		"kulak":
			_add("kizarik", r * 2.8)
			_add("kir", r * 1.6, angle, TEX["kir"]).self_modulate = WAX
		"burkulma":
			_add("kizarik", r * 3.0)
			_add("sargi", r * 2.9, randf_range(-0.15, 0.15))
		"goz":
			_add("kizarik", r * 2.4)
			_add("kir", r * 1.4, angle, TEX["kir"]).self_modulate = DUST
			for k in 2:
				_add("yas%d" % k, r * 0.45, 0.0, TEX["damla"])
	queue_redraw()


func _add(layer: String, width: float, angle: float = 0.0, texture: Texture2D = null) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture if texture else TEX[layer]
	sprite.rotation = angle
	sprite.set_meta("base", width / sprite.texture.get_width())
	sprite.scale = Vector2.ONE * float(sprite.get_meta("base"))
	sprite.visible = false
	add_child(sprite)
	_layers[layer] = sprite
	return sprite


# --- Sorgular ---

## Bu alet şimdi bu noktaya etki eder mi?
func needs(tool_id: String) -> bool:
	return stage < steps.size() and steps[stage] == tool_id


func done() -> bool:
	return stage >= steps.size()


## Aletin bu noktadaki ilerlemesi: 0 sırası gelmedi, 1 bitti (bu aşamadaysa yumuşatılmış ara değer)
func progress(tool_id: String) -> float:
	var index := steps.find(tool_id)
	if index < 0 or index > stage:
		return 0.0
	if index < stage:
		return 1.0
	return 1.0 - _shown


## Ekran noktası noktanın cömert alanının içinde mi
func hit(point: Vector2, hit_radius: float) -> bool:
	return global_position.distance_to(point) <= radius * hit_radius * global_scale.x


## Ekrandaki orta noktası (ipucu eli ve efektler için)
func screen_point() -> Vector2:
	return get_global_transform_with_canvas().origin


# --- Değişiklikler ---

## Alet etki etti: amount azalır. Aşama bittiyse true.
func work(part: float) -> bool:
	if done():
		return false
	amount -= part
	_wiggle = 1.0
	if amount > 0.0:
		return false
	if steps[stage] in ["bant", "sargi"]:
		_stick = 1.0
	stage += 1
	amount = 1.0
	_shown = 1.0
	return true


## Cımbız: şu anki diken t kadar (0..1) dışarı çekildi
func set_pull(t: float) -> void:
	_pull = clampf(t, 0.0, 1.0)
	_wiggle = 1.0


## Şu anki diken çıktı; dikenlerin hepsi çıktıysa (aşama bitti) true
func pull_out() -> bool:
	_pull = 0.0
	_pulled += 1
	var count := maxi(_thorns.size(), 1)
	amount = 1.0 - float(_pulled) / count
	_shown = amount
	if _pulled < count:
		_wiggle = 1.0
		return false
	return work(1.0)


## Çekilen dikenin ekrandaki yeri (efekt için)
func thorn_point() -> Vector2:
	if _pulled < _thorns.size():
		return _thorns[_pulled].global_position
	return global_position


## Bütün aşamaları bitirir (geliştirici kısayolu)
func finish_all() -> void:
	stage = steps.size()
	_pulled = _thorns.size()
	amount = 1.0
	_shown = 1.0


## İpucu: nokta kısa süre parlar ve büyüyüp küçülür
func pulse() -> void:
	_pulse = 1.0


# --- Her kare ---

func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, amount, delta * 4.0)
	_pulse = move_toward(_pulse, 0.0, delta * 1.2)
	_wiggle = move_toward(_wiggle, 0.0, delta * 3.0)
	_stick = move_toward(_stick, 0.0, delta * 2.5)
	var glow := 1.0 + 0.4 * _pulse
	modulate = Color(glow, glow, glow)
	var bump := 1.0 + 0.18 * sin(_pulse * PI) + 0.05 * _wiggle * sin(_time * 30.0)
	var throb := 1.0 + 0.06 * sin(_time * 4.0)
	var stuck := 1.0 + 0.35 * sin(_stick * PI)
	match look:
		"siyrik":
			_show("yara", 1.0, bump)
			_show("kir", 1.0 - progress("pamuk"), bump * (1.0 - 0.3 * progress("pamuk")))
			_show("merhem", progress("merhem"), bump * (0.6 + 0.4 * progress("merhem")))
			_show("bant", 1.0 if progress("bant") >= 1.0 else 0.0, stuck)
		"diken":
			_show("kizarik", 0.8 - 0.5 * progress("merhem"), throb * bump)
			_show("merhem", progress("merhem"), bump * (0.6 + 0.4 * progress("merhem")))
			for k in _thorns.size():
				var thorn := _thorns[k]
				thorn.visible = k >= _pulled
				var out := Vector2.UP.rotated(thorn.rotation) * radius * 2.2 * (_pull if k == _pulled else 0.0)
				thorn.position = thorn.get_meta("home") + out
				thorn.scale = Vector2.ONE * float(thorn.get_meta("base")) * bump
			_show("bant", 1.0 if progress("bant") >= 1.0 else 0.0, stuck)
		"ates":
			var fever := 1.0 - progress("buz")
			_show("kizarik", fever * 0.9, throb * bump)
			for k in 2:
				var drop: Sprite2D = _layers["ter%d" % k]
				var slide := fmod(_time * 0.3 + k * 0.5, 1.0)
				drop.position = Vector2((k * 2 - 1) * radius * 1.1, -radius * 0.3 + slide * radius * 0.9)
				_show("ter%d" % k, fever * (1.0 - slide * slide), bump)
		"nezle":
			var cold := 1.0 - progress("mendil")
			_show("kizarik", 0.3 + 0.6 * cold, throb * bump)
			var drip: Sprite2D = _layers["akinti"]
			drip.position = Vector2(radius * 0.25, radius * (0.8 + 0.25 * sin(_time * 2.0)))
			drip.rotation = PI
			_show("akinti", cold, bump)
		"dis":
			var p := progress("dis_fircasi")
			_show("kir", 1.0 - p, bump)
			_show("kopuk", clampf(p * (1.0 - p) * 4.0, 0.0, 1.0) if not done() else 0.0, bump * (0.7 + 0.3 * p))
		"sislik":
			_show("kizarik", (1.0 - progress("buz")) * 0.7, throb * bump)
		"benek":
			var cream := progress("krem")
			_show("benek", 1.0 - 0.6 * cream, bump * (1.0 - 0.35 * cream))
			_show("merhem", cream * (1.0 - progress("pudra")), bump * 0.8)
			_show("pudra", progress("pudra") * 0.9, bump)
		"kulak":
			_show("kizarik", (1.0 - progress("damla")) * 0.85, throb * bump)
			_show("kir", 1.0 - progress("kulak_cubugu"), bump)
		"burkulma":
			_show("kizarik", 1.0 - 0.7 * progress("buz"), throb * bump)
			_show("sargi", 1.0 if progress("sargi") >= 1.0 else 0.0, stuck)
		"goz":
			var tears := (0.5 + 0.5 * progress("damla")) * (1.0 - progress("mendil"))
			_show("kizarik", 0.8 * (1.0 - progress("mendil")) + 0.1, throb * bump)
			_show("kir", 1.0 - progress("damla"), bump)
			for k in 2:
				var tear: Sprite2D = _layers["yas%d" % k]
				var slide := fmod(_time * 0.4 + k * 0.5, 1.0)
				tear.position = Vector2((k - 0.5) * radius * 0.7, radius * (0.7 + slide * 0.8))
				_show("yas%d" % k, tears * (1.0 - slide * slide), bump)
	queue_redraw()


func _show(layer: String, alpha: float, size: float) -> void:
	var sprite: Sprite2D = _layers[layer]
	sprite.visible = alpha > 0.01
	sprite.modulate.a = clampf(alpha, 0.0, 1.0)
	sprite.scale = Vector2.ONE * float(sprite.get_meta("base")) * size


# Görsel dosyası olmayan parçalar (çocuk görsellerin altında çizilir): hedef halkası, diken delikleri, şiş yanak,
# ağrı çizgileri
func _draw() -> void:
	var r := radius
	if look in ["dinle", "agiz"] and active and not done():
		var ring := r * (1.15 + 0.08 * sin(_time * 5.0) + 0.25 * sin(_pulse * PI))
		draw_circle(Vector2.ZERO, ring, Color(RING, 0.18 + 0.15 * _pulse))
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(RING, 0.9), 4.0, true)
	match look:
		"diken":
			for k in mini(_pulled, _thorns.size()):
				draw_circle(_thorns[k].get_meta("home"), r * 0.1, Color(HOLE, 1.0 - progress("merhem")))
		"sislik":
			# Şiş yanak: ten renginde dışa taşan tümsek, buzla iner
			var swell := 1.0 - 0.85 * progress("buz")
			if swell > 0.2:
				var size := Vector2(r * 1.1, r * 0.95) * swell * (1.0 + 0.04 * sin(_time * 4.0))
				_ellipse(Vector2.ZERO, size + Vector2(4.0, 4.0), OUT)
				_ellipse(Vector2.ZERO, size, skin)
				_ellipse(Vector2(-size.x * 0.3, -size.y * 0.35), size * Vector2(0.3, 0.18), Color(1, 1, 1, 0.5))
		"burkulma":
			# Ağrı çizgileri: buzla söner
			var a := 1.0 - progress("buz")
			if a > 0.02 and progress("sargi") < 1.0:
				for k in 3:
					var dir := Vector2.UP.rotated(-0.9 + k * 0.9)
					var from := dir * r * (1.25 + 0.08 * sin(_time * 6.0))
					draw_line(from, from + dir * r * 0.5, Color(PAIN, a), 4.5, true)


func _ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		points.append(center + Vector2(cos(t) * size.x, sin(t) * size.y))
	draw_colored_polygon(points, color)
