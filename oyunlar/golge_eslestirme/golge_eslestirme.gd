extends Control
# Gölge Eşleştirme (ShadowMatchGame): 1-3 yaş için. Üstte gölgeler, altta eşyalar; çocuk eşyayı
# sürükleyip kendi gölgesine bırakır. Metin, süre ve ceza yok. 10 bölüm; sonuncudan sonra büyük
# kutlama ve 1. bölüme dönüş. Bölümler bolumler/*.tres, eşyalar esyalar/<kategori>/*.tres.
#
# Dokunmayı ortak DragInput (ortak/surukleme_girdisi.gd) okur: aynı anda tek bir parmak bir şey
# tutabilir; diğer parmaklar ve avuç içi dokunuşları yok sayılır. Burada sadece sinyalleri dinlenir.

signal level_completed(index: int)
signal all_levels_completed

const Item := preload("res://oyunlar/golge_eslestirme/esya.gd")
const Slot := preload("res://oyunlar/golge_eslestirme/golge_yuvasi.gd")
const HintHand := preload("res://ortak/ipucu_eli.gd")
const Effects := preload("res://oyunlar/golge_eslestirme/kutlama.gd")
const ProgressDots := preload("res://oyunlar/golge_eslestirme/ilerleme_noktalari.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const DragInput := preload("res://ortak/surukleme_girdisi.gd")
const Sounds := preload("res://oyunlar/golge_eslestirme/sesler.gd")
const TEX_CLOUD: Texture2D = preload("res://oyunlar/golge_eslestirme/gorseller/bulut.svg")
const SAVE_PATH := "user://golge_eslestirme.cfg"

enum State { LOADING, PLAYING, CELEBRATING }

## Oyunun bölümleri (sırayla oynanır). Yeni bölüm: bolumler/ altına .tres ekleyip buraya sürükle.
@export var levels: Array[ShadowLevelData] = []

@export_group("Oynanış")
## Bırakma toleransı: eşya, gölgesinin merkezine eşya boyutunun bu oranı kadar yakınsa doğru sayılır.
@export_range(0.2, 1.0) var drop_tolerance: float = 0.55
## Yakalama alanı, görselin bu kadar katı (1'den büyük: görselin biraz dışından da tutulabilir).
@export_range(1.0, 1.6) var grab_padding: float = 1.25
## Bu kadar saniye hiçbir şey yapılmazsa ipucu eli gösterilir.
@export var hint_delay: float = 9.0
## Eşya boyutu: ekranın kısa kenarına oranı (en fazla) ...
@export_range(0.15, 0.4) var item_screen_ratio: float = 0.27
## ... ve en az. Ekran çok doluysa bile eşyalar bundan küçük olmaz.
@export_range(0.15, 0.4) var min_item_ratio: float = 0.2
## Basılı tutunca geri dönme süresi (saniye).
@export var hold_to_exit: float = 0.6

@export_group("Görünüm ve animasyon")
## Sürüklerken eşyanın büyüme oranı.
@export var drag_scale: float = 1.15
## Sürüklerken eşya parmağın ne kadar üstünde dursun (eşya boyutuna oran).
@export var drag_lift: float = 0.35
## Yanlış bırakılan eşyanın yerine dönme süresi.
@export var return_time: float = 0.45
## Doğru bırakılan eşyanın gölgeye oturma süresi.
@export var snap_time: float = 0.25
## Bölüm sonu kutlamasının süresi (sonra otomatik olarak sonraki bölüme geçilir).
@export var celebration_time: float = 2.2
## 10. bölüm sonundaki büyük kutlamanın süresi.
@export var finale_time: float = 4.5
## Gölge rengi: koyu lacivert, yarı saydam.
@export var shadow_color: Color = Color(0.16, 0.18, 0.4, 0.58)

const TOP_AREA := 150.0         # üstte geri düğmesi ve ilerleme noktaları
const SIDE_MARGIN := 40.0
const BOTTOM_MARGIN := 44.0
const ZONE_GAP := 64.0          # gölge bölgesi ile eşya tepsisi arası

@onready var sky: TextureRect = $Sky
@onready var floaters: Node2D = $Floaters
@onready var tray: Panel = $Tray
@onready var slots_layer: Node2D = $Slots
@onready var items_layer: Node2D = $Items
@onready var effects: Effects = $Effects
@onready var hand: HintHand = $Hand
@onready var progress: ProgressDots = $Progress
@onready var back_button: HoldButton = $BackButton
@onready var sounds: Sounds = $Sounds
@onready var drag_input: DragInput = $DragInput

var state: State = State.LOADING:
	set(value):
		state = value
		if drag_input:
			drag_input.enabled = value == State.PLAYING
var level_index: int = 0
var item_size: float = 200.0
var items: Array[Item] = []
var slots: Array[Slot] = []
var placed_count: int = 0
var idle_time: float = 0.0
var run_id: int = 0              # bölüm değişince eski beklemeler devam etmesin
var sky_gradient := Gradient.new()


func _ready() -> void:
	_check_data()
	_load_progress()
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky_gradient
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	sky_texture.width = 16
	sky_texture.height = 256
	sky.texture = sky_texture
	if not levels.is_empty():
		sky_gradient.set_color(0, levels[level_index].sky_top)
		sky_gradient.set_color(1, levels[level_index].sky_bottom)
	_create_floaters()
	back_button.hold_time = hold_to_exit
	back_button.completed.connect(SahneGecis.ana_menuye_don)
	drag_input.back_button = back_button
	drag_input.enabled = false
	drag_input.grab_padding = grab_padding
	drag_input.drag_scale = drag_scale
	drag_input.touched.connect(_on_touched)
	drag_input.item_grabbed.connect(_on_item_picked)
	drag_input.item_moved.connect(_on_item_moved)
	drag_input.item_dropped.connect(_on_item_dropped)
	drag_input.item_canceled.connect(_on_item_canceled)
	progress.setup(levels.size())
	level_completed.connect(_on_level_completed)
	all_levels_completed.connect(_on_all_levels_completed)
	_layout_static()
	get_viewport().size_changed.connect(_layout_static)
	if not levels.is_empty():
		_start_level(level_index)
	var ipucu := IpucuEli.ekle(self, "golge_eslestirme", _ipucu)
	ipucu.engel = func() -> bool: return hand.visible   # oyunun kendi ipucu eli görünürken çekilir
	OyunBitti.kisayol(self, func() -> void:
		if state == State.PLAYING:
			state = State.CELEBRATING
			level_completed.emit(level_index))
	if OyunBitti.tamamlandi_mi("golge_eslestirme"):
		_oyun_bitti(true)


# Son bölüm bitti (ya da tamamlanmış oyun yeniden açıldı): ortak final ekranı
func _oyun_bitti(kisa: bool) -> void:
	OyunBitti.goster(self, {
		"ad": "golge_eslestirme", "karakter": load("res://oyunlar/golge_eslestirme/esyalar/hayvanlar/kopek.svg"),
		"bolum_sayisi": levels.size(), "kisa": kisa, "bolum_baslat": _bolumden_basla, "bastan": _bolumden_basla.bind(0),
	})


func _bolumden_basla(index: int) -> void:
	await _clear_board()
	progress.setup(levels.size())
	_start_level(index)


# Başlangıç ipucu eli: yerleşmemiş ilk eşyayı kendi gölgesine sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or drag_input.active_touch != -1:
		return {}
	for item in items:
		if not item.placed:
			return IpucuEli.surukle(IpucuEli.ekran_konumu(item), IpucuEli.ekran_konumu(item.slot))
	return {}


# --- Veri kontrolü ---

# Bölüm verilerini açılışta denetler; sorun varsa hata yazar (oyun yine de açılır)
func _check_data() -> void:
	if levels.is_empty():
		push_error("Gölge Eşleştirme: hiç bölüm yok (kök düğümdeki Levels dizisi boş)")
	for i in levels.size():
		var level := levels[i]
		if level == null:
			push_error("Gölge Eşleştirme: %d. bölüm boş" % (i + 1))
			continue
		if _valid_items(level).size() < 2:
			push_error("Gölge Eşleştirme: %d. bölümde en az 2 eşya olmalı" % (i + 1))
		var seen := {}
		var groups := {}
		for item_data in level.items:
			if item_data == null or item_data.texture == null:
				push_error("Gölge Eşleştirme: %d. bölümde görseli olmayan bir eşya var" % (i + 1))
				continue
			if seen.has(item_data):
				push_error("Gölge Eşleştirme: %d. bölümde '%s' iki kez var" % [i + 1, item_data.item_name()])
			seen[item_data] = true
			# Aynı gruptaki siluetler birbirine çok benzer: aynı bölümde olmamalı
			var group: StringName = item_data.group if item_data.group != &"" else StringName(item_data.resource_path)
			if groups.has(group) and groups[group] != item_data:
				push_error("Gölge Eşleştirme: %d. bölümde '%s' ve '%s' siluetleri çok benziyor" % [i + 1, groups[group].item_name(), item_data.item_name()])
			groups[group] = item_data


func _valid_items(level: ShadowLevelData) -> Array[ShadowItemData]:
	var result: Array[ShadowItemData] = []
	for item_data in level.items:
		if item_data != null and item_data.texture != null and not result.has(item_data):
			result.append(item_data)
	return result


# --- Dokunma (ortak DragInput sinyalleri) ---

func _on_touched() -> void:
	idle_time = 0.0
	if hand.visible:
		hand.stop()


func _on_item_moved(item: Item, point: Vector2) -> void:
	item.slot.set_hover(_is_on_own_slot(item, point))


# Dokunma sistem tarafından iptal edildi (ör. bildirim çekmecesi): sessizce geri dönsün
func _on_item_canceled(item: Item) -> void:
	item.slot.set_hover(false)
	item.return_home(return_time, false)


func _is_on_own_slot(item: Item, point: Vector2) -> bool:
	return point.distance_to(item.slot.position) <= item_size * drop_tolerance


# --- Yakalama ve bırakma ---

func _on_item_picked(_item: Item) -> void:
	sounds.play("pop", randf_range(0.95, 1.1))


func _on_item_dropped(item: Item, at: Vector2) -> void:
	item.slot.set_hover(false)
	if _is_on_own_slot(item, at):
		item.snap_to(item.slot.position, snap_time)
		item.slot.fill()   # -> filled sinyali -> _on_slot_filled
		return
	# Yanlış yer: nazikçe geri döner. Başka bir gölgenin üstüne bırakıldıysa hafifçe sallanır.
	var on_other_slot := false
	for slot in slots:
		if slot != item.slot and not slot.is_filled and at.distance_to(slot.position) <= item_size * drop_tolerance:
			on_other_slot = true
	item.return_home(return_time, on_other_slot)
	sounds.play("boing")


func _on_slot_filled(slot: Slot) -> void:
	placed_count += 1
	# Her yerleşimde "çın" sesi biraz daha tiz: küçük bir melodi gibi
	sounds.play("ding", pow(1.122, placed_count - 1))
	effects.sparkle(slot.position, item_size)
	if placed_count >= slots.size() and state == State.PLAYING:
		state = State.CELEBRATING
		hand.stop()
		level_completed.emit(level_index)


# --- Bölüm akışı ---

func _start_level(index: int) -> void:
	run_id += 1
	var my_run := run_id
	state = State.LOADING
	level_index = index
	placed_count = 0
	idle_time = 0.0
	_save_progress()
	progress.set_current(index)
	var level := levels[index]
	_blend_sky(level)
	_build_board(_valid_items(level))
	await get_tree().create_timer(0.3 + items.size() * 0.12 + 0.5).timeout
	if my_run != run_id:
		return
	state = State.PLAYING


func _on_level_completed(index: int) -> void:
	var my_run := run_id
	await get_tree().create_timer(0.45).timeout
	if my_run != run_id:
		return
	progress.complete(index)
	if index >= levels.size() - 1:
		all_levels_completed.emit()
		return
	sounds.play("bolum_sonu")
	effects.confetti(80)
	for k in items.size():
		items[k].hop(k * 0.08)
	await get_tree().create_timer(celebration_time).timeout
	if my_run != run_id:
		return
	await _clear_board()
	if my_run != run_id:
		return
	_start_level(index + 1)


# 10. bölüm bitti: büyük kutlama, sonra ortak final ekranı (bölüm seç / baştan oyna / ana menü)
func _on_all_levels_completed() -> void:
	var my_run := run_id
	sounds.play("final")
	effects.finale(item_size)
	progress.celebrate_all()
	for k in items.size():
		items[k].hop(k * 0.1, 3)
	await get_tree().create_timer(finale_time).timeout
	if my_run != run_id:
		return
	await _clear_board()
	if my_run != run_id:
		return
	_oyun_bitti(false)


func _clear_board() -> void:
	for k in items.size():
		items[k].disappear(k * 0.06)
	for k in slots.size():
		slots[k].disappear(k * 0.06)
	items.clear()
	slots.clear()
	await get_tree().create_timer(0.6).timeout


# --- Yerleşim ---

# Yatay ekran: gölgeler solda, eşyalar sağdaki tepside yan yana; ikisi de 2 sütunlu ızgara. Her bölümde
# yerler karışır ve hiçbir eşya kendi gölgesinin tam altındaki hücrede başlamaz.
func _build_board(level_items: Array[ShadowItemData]) -> void:
	var count := level_items.size()
	var zones := _zones()
	var slot_cells := _cells(zones[0], count)
	var item_cells := _cells(zones[1], count)
	var cell_size: Vector2 = _cell_size(zones[0], count)
	var short := minf(get_viewport_rect().size.x, get_viewport_rect().size.y)
	item_size = clampf(minf(cell_size.x, cell_size.y) * 0.8, short * min_item_ratio, short * item_screen_ratio)
	hand.set_hand_size(item_size * 1.25)
	drag_input.lift = item_size * drag_lift
	drag_input.items = items

	var slot_order := range(count)
	slot_order.shuffle()
	var item_order := _derangement(slot_order)
	var jitter := ((cell_size - Vector2(item_size, item_size)) * 0.3).max(Vector2.ZERO)
	for k in count:
		var data := level_items[k]
		var slot: Slot = Slot.new()
		slots_layer.add_child(slot)
		slot.setup(data, item_size, slot_cells[slot_order[k]] + _random_offset(jitter), shadow_color)
		slot.filled.connect(_on_slot_filled)
		slot.appear(0.1 + k * 0.1)
		slots.append(slot)

		var item: Item = Item.new()
		items_layer.add_child(item)
		item.setup(data, item_size, item_cells[item_order[k]] + _random_offset(jitter))
		item.slot = slot
		item.appear(0.3 + k * 0.12)
		items.append(item)


# [gölge bölgesi (sol), eşya bölgesi (sağ)]
func _zones() -> Array[Rect2]:
	var screen := get_viewport_rect().size
	# Çentikli telefonlarda kenar payı güvenli alan kadar büyür (tepsi çerçevesi 16 px dışarı taşar)
	var side := maxf(EkranYardimcisi.kenar_payi(SIDE_LEFT, SIDE_MARGIN, 24.0), EkranYardimcisi.kenar_payi(SIDE_RIGHT, SIDE_MARGIN, 24.0))
	var area := Rect2(side, TOP_AREA, screen.x - side * 2.0, screen.y - TOP_AREA - BOTTOM_MARGIN)
	var zone_width := (area.size.x - ZONE_GAP) / 2.0
	var left := Rect2(area.position, Vector2(zone_width, area.size.y))
	var right := Rect2(area.position + Vector2(zone_width + ZONE_GAP, 0.0), Vector2(zone_width, area.size.y))
	return [left, right]


func _cell_size(zone: Rect2, count: int) -> Vector2:
	var cols := mini(count, 2)
	var rows := ceili(count / float(cols))
	return Vector2(zone.size.x / cols, zone.size.y / rows)


# Hücre merkezleri; son satırda tek eşya kalırsa ortalanır
func _cells(zone: Rect2, count: int) -> Array[Vector2]:
	var cols := mini(count, 2)
	var cell := _cell_size(zone, count)
	var result: Array[Vector2] = []
	for k in count:
		var row := floori(k / float(cols))
		var col := k % cols
		var in_row := cols if (row + 1) * cols <= count else count - row * cols
		var x := zone.position.x + (cols - in_row) * cell.x / 2.0 + (col + 0.5) * cell.x
		result.append(Vector2(x, zone.position.y + (row + 0.5) * cell.y))
	return result


# order'daki hiçbir değerle aynı konumda aynı değeri taşımayan karışık bir sıra
func _derangement(order: Array) -> Array:
	var result := order.duplicate()
	for attempt in 100:
		result.shuffle()
		var ok := true
		for k in order.size():
			if result[k] == order[k]:
				ok = false
				break
		if ok:
			return result
	return result


func _random_offset(limit: Vector2) -> Vector2:
	return Vector2(randf_range(-limit.x, limit.x), randf_range(-limit.y, limit.y))


# Ekran boyutuna bağlı sabit parçalar: tepsi, ilerleme noktaları
func _layout_static() -> void:
	var screen := get_viewport_rect().size
	var item_zone: Rect2 = _zones()[1]
	tray.position = item_zone.position - Vector2(16.0, 16.0)
	tray.size = item_zone.size + Vector2(32.0, 32.0)
	var dots_left := back_button.position.x + back_button.size.x + 30.0
	var dots_width := screen.x - dots_left - SIDE_MARGIN
	progress.spacing = minf(34.0, dots_width / maxf(1.0, levels.size()))
	progress.position = Vector2(dots_left + dots_width / 2.0, back_button.position.y + back_button.size.y / 2.0)


# --- Arka plan ---

func _blend_sky(level: ShadowLevelData) -> void:
	var from_top := sky_gradient.get_color(0)
	var from_bottom := sky_gradient.get_color(1)
	create_tween().tween_method(_set_sky.bind(from_top, from_bottom, level.sky_top, level.sky_bottom), 0.0, 1.0, 0.8)


func _set_sky(t: float, from_top: Color, from_bottom: Color, to_top: Color, to_bottom: Color) -> void:
	sky_gradient.set_color(0, from_top.lerp(to_top, t))
	sky_gradient.set_color(1, from_bottom.lerp(to_bottom, t))


func _create_floaters() -> void:
	var screen := get_viewport_rect().size
	# Sade kalsın: birkaç soluk, çok yavaş bulut
	for k in 3:
		var cloud := Sprite2D.new()
		cloud.texture = TEX_CLOUD
		var s := randf_range(0.8, 1.2) * 190.0 / TEX_CLOUD.get_width()
		cloud.scale = Vector2(s, s)
		cloud.modulate.a = randf_range(0.3, 0.45)
		cloud.position = Vector2(randf_range(0.0, screen.x), randf_range(80.0, screen.y * 0.75))
		cloud.set_meta("speed", -randf_range(6.0, 14.0))
		floaters.add_child(cloud)


func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	for cloud: Sprite2D in floaters.get_children():
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		var half := cloud.texture.get_width() * cloud.scale.x / 2.0
		if cloud.position.x < -half:
			cloud.position = Vector2(screen.x + half, randf_range(80.0, screen.y * 0.75))

	# İpucu: bir süre hiçbir şey yapılmazsa
	if state == State.PLAYING and drag_input.active_touch == -1:
		idle_time += delta
		if idle_time >= hint_delay:
			idle_time = 0.0
			_show_hint()


func _show_hint() -> void:
	var waiting: Array[Item] = []
	for item in items:
		if not item.placed:
			waiting.append(item)
	if waiting.is_empty():
		return
	var item: Item = waiting.pick_random()
	item.wiggle()
	hand.play(item.position, item.slot.position)


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level_index = clampi(int(config.get_value("ilerleme", "bolum", 0)), 0, maxi(levels.size() - 1, 0))


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "bolum", level_index)
	GuvenliKayit.save_config(config, SAVE_PATH)
