extends Control
# Dondurmacı: müşterinin baloncukta gösterdiği dondurmayı hazırla.
# Önce külah/kase seç, sonra tatları alttan üste doğru sırayla ekle.

enum State { ENTERING, CHOOSE_CONTAINER, ADD_SCOOPS, CELEBRATING }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

# --- Sipariş kuralları (Inspector'dan da değiştirilebilir) ---
@export_group("Sipariş kuralları")
## İlk müşterilerin istediği top sayısı.
@export_range(1, 5) var start_scoops: int = 1
## Bir siparişteki en fazla top sayısı.
@export_range(1, 5) var max_scoops: int = 3
## Kaç müşteriden sonra bir top daha istensin.
@export var customers_per_level: int = 3
## Siparişlerde çıkabilecek tatlar (FLAVORS listesindeki id'ler). Boş bırakılırsa hepsi çıkar.
@export var allowed_flavors: Array[String] = []
## Aynı siparişte aynı tat iki kez istenebilir mi?
@export var allow_same_flavor_twice: bool = false
## Kase isteme olasılığı (0 = hep külah, 1 = hep kase).
@export_range(0.0, 1.0) var bowl_chance: float = 0.4

# Tatlar: yeni tat için gorseller/ klasörüne top SVG'si çiz ve buraya bir satır ekle.
# Tat kutuları bu listeden otomatik oluşur (2 sütun).
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")

const FLAVORS := [
	{"id": "cilek", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_cilek.svg"), "box_color": Color("ffd6e6")},
	{"id": "cikolata", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_cikolata.svg"), "box_color": Color("ecd3c2")},
	{"id": "vanilya", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_vanilya.svg"), "box_color": Color("fff8e6")},
	{"id": "limon", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_limon.svg"), "box_color": Color("fff5b8")},
	{"id": "yaban_mersini", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_yaban_mersini.svg"), "box_color": Color("d4ddff")},
	{"id": "fistik", "texture": preload("res://oyunlar/dondurmaci/gorseller/top_fistik.svg"), "box_color": Color("ddf3c8")},
]

# Hayvanlar: yeni hayvan için normal ve mutlu SVG'lerini çiz ve buraya bir satır ekle.
const ANIMALS := [
	{"id": "panda", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_panda.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_panda_mutlu.svg")},
	{"id": "tavsan", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_tavsan.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_tavsan_mutlu.svg")},
	{"id": "kedi", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_kedi.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_kedi_mutlu.svg")},
	{"id": "penguen", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_penguen.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_penguen_mutlu.svg")},
	{"id": "fil", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_fil.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_fil_mutlu.svg")},
	{"id": "zurafa", "normal": preload("res://oyunlar/dondurmaci/gorseller/hayvan_zurafa.svg"), "happy": preload("res://oyunlar/dondurmaci/gorseller/hayvan_zurafa_mutlu.svg")},
]

# Külah ve kase. first_scoop_y: ilk topun merkezinin tabana göre yüksekliği.
# in_front: kap topların önünde mi çizilsin (kasede alttaki top içeride görünsün diye)
const CONTAINERS := {
	"kulah": {"texture": preload("res://oyunlar/dondurmaci/gorseller/kulah.svg"), "first_scoop_y": -185.0, "in_front": false},
	"kase": {"texture": preload("res://oyunlar/dondurmaci/gorseller/kase.svg"), "first_scoop_y": -115.0, "in_front": true},
}

const STAR_TEXTURE: Texture2D = preload("res://oyunlar/dondurmaci/gorseller/yildiz.svg")
const HEART_TEXTURE: Texture2D = preload("res://oyunlar/dondurmaci/gorseller/kalp.svg")

const SCOOP_STEP := 72.0           # üst üste topların arası
const ORDER_SCALE := 0.62          # baloncuktaki dondurmanın boyutu
const CUSTOMER_POS := Vector2(-380, 330)
const HAND_POS := Vector2(110, 80) # müşterinin dondurmayı tuttuğu yer
const FLAVOR_BOX_SIZE := Vector2(160, 125)

@onready var customer: Sprite2D = $TopArea/Customer
@onready var bubble: Node2D = $TopArea/Bubble
@onready var order_spot: Node2D = $TopArea/Bubble/OrderSpot
@onready var prep: Node2D = $PrepArea/Prep
@onready var flavor_grid: GridContainer = $FlavorGrid
@onready var effects: Node2D = $Effects
@onready var star_icon: TextureRect = $StarBox/StarIcon
@onready var star_label: Label = $StarBox/StarLabel
@onready var container_buttons := {"kulah": $ConeButton, "kase": $BowlButton}
@onready var back_panel: Panel = $BackButton
var back_button: Control

var state: State = State.ENTERING
var stars: int = 0
var served: int = 0
var animal_index: int = -1
var order_container: String = ""
var order_flavors: Array[String] = []
var made_count: int = 0
var ice_cream: Node2D                 # hazırlanan dondurma
var made_container: String = ""
var flavor_boxes: Array[Panel] = []
var feedback_tweens: Dictionary = {}  # düğüm -> sallanma/parlama tween'i


func _ready() -> void:
	SesYoneticisi.muzik("dondurmaci", self)
	back_button = HoldButton.replace(back_panel)
	# Çentikli telefonlarda geri düğmesi ve yıldız sayacı birlikte güvenli alana kayar (üst üste binmesinler)
	EkranYardimcisi.guvenliye_it_grup([back_button, $StarBox])
	back_button.completed.connect(_on_back_completed)
	_create_flavor_boxes()
	for button: Panel in container_buttons.values():
		button.add_theme_stylebox_override("panel", _make_box_style(Color("fffaf2")))
	star_label.text = "0"
	bubble.scale = Vector2.ZERO
	customer.visible = false
	_next_customer()
	IpucuEli.ekle(self, "dondurmaci", _ipucu)


# İpucu eli: siparişi göster, sonra istenen kaba, sonra sıradaki tadın kutusuna dokun
func _ipucu() -> Dictionary:
	if state != State.CHOOSE_CONTAINER and state != State.ADD_SCOOPS:
		return {}
	var adimlar: Array = [IpucuEli.goster(IpucuEli.ekran_konumu(order_spot, Vector2(0.0, -80.0)))]
	if state == State.CHOOSE_CONTAINER:
		adimlar.append(IpucuEli.dokun(IpucuEli.ekran_konumu(container_buttons[order_container]), 1))
	if made_count < order_flavors.size():
		var kutu := flavor_boxes[_flavor_index(order_flavors[made_count])]
		adimlar.append(IpucuEli.dokun(IpucuEli.ekran_konumu(kutu), 1))
	return IpucuEli.sira(adimlar)


func _input(event: InputEvent) -> void:
	# Sadece dokunma ile oynanır (bilgisayarda fare tıklaması dokunmaya çevrilir)
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	# Geri: bu oyunun tek ekranı var; basılı tutunca ana menüye döner
	if back_button.handle_touch(touch) or not touch.pressed:
		return
	if state != State.CHOOSE_CONTAINER and state != State.ADD_SCOOPS:
		return

	for id: String in container_buttons:
		if _is_touched(container_buttons[id], touch.position):
			_on_container_tapped(id)
			return
	for i in flavor_boxes.size():
		if _is_touched(flavor_boxes[i], touch.position):
			_on_flavor_tapped(i)
			return


func _on_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	SahneGecis.ana_menuye_don()


func _is_touched(control: Control, pos: Vector2) -> bool:
	return control.get_global_rect().has_point(pos)


# --- Dokunmalar ---

func _on_container_tapped(id: String) -> void:
	if state == State.ADD_SCOOPS:
		return  # kap zaten seçildi
	if id != order_container:
		SesYoneticisi.efekt("yumusak_hayir")
		_shake(container_buttons[id])
		_glow(container_buttons[order_container])
		return

	_bounce(container_buttons[id])
	# Külah tahta gibi "tok", kase cam gibi "tink"
	SesYoneticisi.efekt("tahta_tok" if id == "kulah" else "tink")
	made_container = id
	ice_cream = _build_ice_cream(id, [])
	prep.add_child(ice_cream)
	ice_cream.scale = Vector2.ZERO
	create_tween().tween_property(ice_cream, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	state = State.ADD_SCOOPS
	_update_step_visuals()


func _on_flavor_tapped(index: int) -> void:
	var box := flavor_boxes[index]
	if state == State.CHOOSE_CONTAINER:
		# Önce kap seçilmeli: doğru kabı göster
		SesYoneticisi.efekt("yumusak_hayir")
		_shake(box)
		_glow(container_buttons[order_container])
		return

	var wanted := order_flavors[made_count]
	if FLAVORS[index]["id"] != wanted:
		SesYoneticisi.efekt("yumusak_hayir")
		_shake(box)
		_glow(flavor_boxes[_flavor_index(wanted)])
		return

	_bounce(box)
	# Her yeni top biraz daha ince "plop"
	SesYoneticisi.efekt("plop", 0.0, 1.0 + made_count * 0.07)
	_add_scoop(ice_cream, made_container, made_count, FLAVORS[index]["texture"], true)
	made_count += 1
	if made_count == order_flavors.size():
		_serve()


# --- Müşteri akışı ---

func _next_customer() -> void:
	state = State.ENTERING
	# Önceki müşterinin elindeki dondurmayı temizle
	for child in customer.get_children():
		child.queue_free()

	var next := randi() % ANIMALS.size()
	while ANIMALS.size() > 1 and next == animal_index:
		next = randi() % ANIMALS.size()
	animal_index = next
	_make_order()

	# Giriş animasyonu: soldan sallanarak gelir
	var screen_width := get_viewport_rect().size.x
	customer.texture = ANIMALS[animal_index]["normal"]
	customer.position = CUSTOMER_POS - Vector2(screen_width, 0)
	customer.rotation = 0.0
	customer.visible = true
	SesYoneticisi.efekt("kapi_zili", -3.0)
	var walk := create_tween()
	walk.tween_property(customer, "position", CUSTOMER_POS, 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wobble := create_tween()
	for i in 3:
		wobble.tween_property(customer, "rotation", 0.08, 0.12)
		wobble.tween_property(customer, "rotation", -0.08, 0.12)
	wobble.tween_property(customer, "rotation", 0.0, 0.1)
	await walk.finished

	_show_order()
	made_container = ""
	made_count = 0
	state = State.CHOOSE_CONTAINER
	_update_step_visuals()


func _make_order() -> void:
	var level := floori(float(served) / maxi(customers_per_level, 1))
	var count := clampi(start_scoops + level, 1, max_scoops)
	var pool := _allowed_flavor_ids()
	order_flavors.clear()
	for i in count:
		var choices: Array[String] = pool.duplicate()
		if not allow_same_flavor_twice:
			var unused := choices.filter(func(id: String) -> bool: return not order_flavors.has(id))
			if not unused.is_empty():
				choices.assign(unused)
		order_flavors.append(choices.pick_random())
	order_container = "kase" if randf() < bowl_chance else "kulah"


func _allowed_flavor_ids() -> Array[String]:
	var ids: Array[String] = []
	for flavor: Dictionary in FLAVORS:
		if allowed_flavors.is_empty() or allowed_flavors.has(flavor["id"]):
			ids.append(flavor["id"])
	if ids.is_empty():  # yanlış id yazıldıysa hepsini kullan
		for flavor: Dictionary in FLAVORS:
			ids.append(flavor["id"])
	return ids


func _show_order() -> void:
	for child in order_spot.get_children():
		child.queue_free()
	var order_ice_cream := _build_ice_cream(order_container, order_flavors)
	order_ice_cream.scale = Vector2(ORDER_SCALE, ORDER_SCALE)
	order_spot.add_child(order_ice_cream)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _serve() -> void:
	state = State.CELEBRATING
	_update_step_visuals()
	await get_tree().create_timer(0.55).timeout  # son top yerine otursun
	SesYoneticisi.ezgi("tamamlandi")

	# Dondurma müşterinin eline uçar
	ice_cream.reparent(effects)
	var fly := create_tween().set_parallel()
	fly.tween_property(ice_cream, "global_position", customer.to_global(HAND_POS), 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(ice_cream, "scale", Vector2(0.55, 0.55), 0.5)
	await fly.finished
	ice_cream.reparent(customer)
	ice_cream = null

	# Müşteri sevinir: mutlu yüz, zıplama, kalpler ve bir yıldız
	create_tween().tween_property(bubble, "scale", Vector2.ZERO, 0.2)
	customer.texture = ANIMALS[animal_index]["happy"]
	SesYoneticisi.efekt("hayvan_sevinc")
	var jump := create_tween()
	for i in 2:
		jump.tween_property(customer, "position:y", CUSTOMER_POS.y - 50.0, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump.tween_property(customer, "position:y", CUSTOMER_POS.y, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_spawn_hearts()
	_fly_star()
	await get_tree().create_timer(1.8).timeout

	# Müşteri sağa doğru gider, yenisi gelir
	served += 1
	var leave := create_tween()
	leave.tween_property(customer, "position:x", CUSTOMER_POS.x + get_viewport_rect().size.x, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await leave.finished
	_next_customer()


# --- Dondurma yapımı ---

# Tabanı (0, 0) noktasında olan bir dondurma oluşturur
func _build_ice_cream(container_id: String, flavor_ids: Array) -> Node2D:
	var root := Node2D.new()
	var cup := Sprite2D.new()
	cup.name = "Container"
	cup.texture = CONTAINERS[container_id]["texture"]
	cup.position.y = -cup.texture.get_height() / 2.0
	root.add_child(cup)
	for i in flavor_ids.size():
		_add_scoop(root, container_id, i, FLAVORS[_flavor_index(flavor_ids[i])]["texture"], false)
	return root


func _add_scoop(root: Node2D, container_id: String, index: int, texture: Texture2D, animated: bool) -> void:
	var info: Dictionary = CONTAINERS[container_id]
	var target_y: float = info["first_scoop_y"] - index * SCOOP_STEP
	var scoop := Sprite2D.new()
	scoop.texture = texture
	root.add_child(scoop)
	if info["in_front"]:
		root.move_child(root.get_node("Container"), -1)

	if not animated:
		scoop.position.y = target_y
		return
	# Yukarıdan düşüp zıplayarak yerine otursun
	scoop.position.y = target_y - 260.0
	var drop := scoop.create_tween()
	drop.tween_property(scoop, "position:y", target_y, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(scoop, "scale", Vector2(1.12, 0.9), 0.07)
	drop.tween_property(scoop, "scale", Vector2.ONE, 0.1)


func _flavor_index(id: String) -> int:
	for i in FLAVORS.size():
		if FLAVORS[i]["id"] == id:
			return i
	return 0


# --- Görsel geri bildirim ---

func _create_flavor_boxes() -> void:
	for flavor: Dictionary in FLAVORS:
		var box := Panel.new()
		box.custom_minimum_size = FLAVOR_BOX_SIZE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _make_box_style(flavor["box_color"]))
		var icon := TextureRect.new()
		icon.texture = flavor["texture"]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		box.add_child(icon)
		flavor_grid.add_child(box)
		flavor_boxes.append(box)


func _make_box_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(6)
	style.border_color = color.darkened(0.3)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 6)
	return style


# Sıradaki adımın düğmeleri parlak, diğerleri soluk görünür
func _update_step_visuals() -> void:
	var choosing := state == State.CHOOSE_CONTAINER
	var adding := state == State.ADD_SCOOPS
	for button: Panel in container_buttons.values():
		button.modulate.a = 1.0 if choosing else 0.45
	for box in flavor_boxes:
		box.modulate.a = 1.0 if adding else 0.45


func _feedback_tween(node: Control) -> Tween:
	if feedback_tweens.has(node):
		(feedback_tweens[node] as Tween).kill()
	node.rotation = 0.0
	node.scale = Vector2.ONE
	node.self_modulate = Color.WHITE
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	feedback_tweens[node] = tween
	return tween


# Yanlış seçim: hafifçe sallan
func _shake(node: Control) -> void:
	var tween := _feedback_tween(node)
	for angle in [0.12, -0.12, 0.08, -0.05, 0.0]:
		tween.tween_property(node, "rotation", angle, 0.06)


# Doğru seçeneği göster: iki kez büyüyüp parlar
func _glow(node: Control) -> void:
	var tween := _feedback_tween(node)
	tween.tween_interval(0.15)
	for i in 2:
		tween.tween_property(node, "scale", Vector2(1.12, 1.12), 0.18)
		tween.parallel().tween_property(node, "self_modulate", Color(1.4, 1.4, 1.4), 0.18)
		tween.tween_property(node, "scale", Vector2.ONE, 0.18)
		tween.parallel().tween_property(node, "self_modulate", Color.WHITE, 0.18)


# Doğru dokunuş: kısa bir basılma hissi
func _bounce(node: Control) -> void:
	var tween := _feedback_tween(node)
	tween.tween_property(node, "scale", Vector2(0.9, 0.9), 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.1)


func _spawn_hearts() -> void:
	for i in 5:
		var heart := Sprite2D.new()
		heart.texture = HEART_TEXTURE
		effects.add_child(heart)
		heart.global_position = customer.global_position + Vector2(randf_range(-120, 120), randf_range(-150, -60))
		heart.scale = Vector2.ZERO
		var tween := heart.create_tween()
		tween.tween_interval(i * 0.12)
		tween.tween_property(heart, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "position:y", heart.position.y - 140.0, 0.9)
		tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.9)
		tween.tween_callback(heart.queue_free)


# Müşteriden üstteki yıldız sayacına bir yıldız uçar
func _fly_star() -> void:
	var star := Sprite2D.new()
	star.texture = STAR_TEXTURE
	effects.add_child(star)
	star.global_position = customer.global_position + Vector2(0, -130)
	star.scale = Vector2(0.3, 0.3)
	var target := star_icon.global_position + star_icon.size / 2.0
	var tween := star.create_tween()
	tween.tween_property(star, "scale", Vector2(1.4, 1.4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "global_position", target, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(star, "scale", Vector2.ONE, 0.6)
	tween.tween_callback(_add_star)
	tween.tween_callback(star.queue_free)


func _add_star() -> void:
	SesYoneticisi.ezgi("yildiz_kazanma")
	stars += 1
	star_label.text = str(stars)
	star_icon.pivot_offset = star_icon.size / 2.0
	var tween := create_tween()
	tween.tween_property(star_icon, "scale", Vector2(1.35, 1.35), 0.1)
	tween.tween_property(star_icon, "scale", Vector2.ONE, 0.15)
