extends Node2D
# Müzik Kutusu (MusicBoxGame): kuralsız, skorsuz serbest müzik alanı (yatay, 1-4 yaş, yazı yok).
# Üstte perdeli sahnede dans eden karakterler, ortada seçili enstrüman, sağ kenarda enstrüman düğmeleri.
# Enstrümanlar (enstruman.gd'den türer) INSTRUMENTS listesinde: yeni enstrüman = yeni script + bir satır.
#
# Dokunma: her parmak (index) ayrı izlenir. Basışta sırayla geri düğmesi, enstrüman düğmeleri, sonra seçili
# enstrüman sorulur; parmağın sürüklenmesi ve bırakılması basıldığı yere gider. Ses dokunuşun basıldığı
# anda çalar. Klavye 1-9 seçili enstrümanın parçalarını çalar (masaüstünde deneme).
# Ses güvenliği: oyun açıkken kendi ses yolu (BUS) eklenir; üstünde limiter var, böylece aynı anda çok ses
# çalınca toplam ses patlamaz. Oyundan çıkınca yol kaldırılır (öbür oyunlar etkilenmez).

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Bu kadar saniye hiçbir şeye dokunulmazsa bir parça hafifçe parlayıp zıplayarak davet eder.
@export var invite_after: float = 15.0
## Basılı tutunca ana menüye dönme süresi (saniye).
@export var hold_to_exit: float = 0.6

const G := "res://oyunlar/muzik_kutusu/gorseller/"
const BUS := &"MuzikKutusu"
const Instrument := preload("res://oyunlar/muzik_kutusu/enstruman.gd")
const Xylophone := preload("res://oyunlar/muzik_kutusu/ksilofon.gd")
const Dancer := preload("res://oyunlar/muzik_kutusu/dansci.gd")
const Hud := preload("res://oyunlar/muzik_kutusu/arayuz.gd")
const Background := preload("res://oyunlar/muzik_kutusu/arka_plan.gd")
const Effects := preload("res://oyunlar/muzik_kutusu/efektler.gd")

## Enstrümanlar sırayla (sağdaki düğmeler de bu sırada)
const INSTRUMENTS := [
	{"script": preload("res://oyunlar/muzik_kutusu/ksilofon.gd"), "icon": preload(G + "ikon_ksilofon.svg"), "color": Color("ff9a3d")},
	{"script": preload("res://oyunlar/muzik_kutusu/davul_seti.gd"), "icon": preload(G + "ikon_davul.svg"), "color": Color("ff5b6e")},
	{"script": preload("res://oyunlar/muzik_kutusu/hayvan_orkestrasi.gd"), "icon": preload(G + "ikon_hayvan.svg"), "color": Color("7bd85a")},
]
const DANCERS := [["tavsan", Dancer.Move.SWAY], ["kurbaga", Dancer.Move.BOUNCE], ["panda", Dancer.Move.STEP], ["penguen", Dancer.Move.SPIN]]
const FLOOR_Y := 212.0                # dansçıların ayak çizgisi
const DANCER_HEIGHT := 128.0
const SIDE := 56.0
const SLIDE_TIME := 0.3

@onready var background: Background = $Background
@onready var dancers_layer: Node2D = $Dancers
@onready var instruments_layer: Node2D = $Instruments
@onready var effects: Effects = $Effects
@onready var hud: Hud = $UI/Hud

var instruments: Array[Instrument] = []
var dancers: Array[Dancer] = []
var current: int = -1
var back_touch: int = -1              # geri düğmesini tutan parmak (-1: yok)
var idle_time: float = 0.0
var invite_count: int = 0            # kaç kez davet edildi (test için)
var _owners: Dictionary = {}          # parmak index -> "instrument" (enstrümana gider) ya da "ui"
var _area: Rect2
var _slides: Array[Tween] = []


func _enter_tree() -> void:
	# Enstrümanların ses havuzları _ready'de bu yola bağlanır; yol ondan önce hazır olmalı
	if AudioServer.get_bus_index(BUS) == -1:
		var bus := AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, BUS)
		AudioServer.set_bus_send(bus, &"Master")
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.5
		limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(bus, limiter)


func _exit_tree() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus != -1:
		AudioServer.remove_bus(bus)


func _ready() -> void:
	var icons: Array[Texture2D] = []
	var colors: Array[Color] = []
	for entry in INSTRUMENTS:
		var instrument: Instrument = entry["script"].new()
		instrument.bus_name = BUS
		instrument.visible = false
		instruments_layer.add_child(instrument)
		instrument.note_played.connect(_on_note_played.bind(instrument))
		instruments.append(instrument)
		icons.append(entry["icon"])
		colors.append(entry["color"])
		var xylophone := instrument as Xylophone
		if xylophone:
			xylophone.song_finished.connect(_on_song_finished)
			xylophone.song_started.connect(_on_song_started)
	hud.build_selector(icons, colors)
	hud.back_button.hold_time = hold_to_exit
	hud.back_button.completed.connect(SahneGecis.ana_menuye_don)
	for entry in DANCERS:
		var dancer := Dancer.new()
		dancer.setup(entry[0], DANCER_HEIGHT, entry[1])
		dancers_layer.add_child(dancer)
		dancers.append(dancer)
	_layout()
	get_viewport().size_changed.connect(_layout)
	select(0, false)
	IpucuEli.ekle(self, "muzik_kutusu", _ipucu)


# Başlangıç ipucu eli: seçili enstrümanın ortadaki parçasına dokun (ses çıkar)
func _ipucu() -> Dictionary:
	var calgi := instrument()
	if calgi == null or calgi.pads.is_empty():
		return {}
	var parca: Node2D = calgi.pads[int(calgi.pads.size() / 2.0)]
	return IpucuEli.dokun(parca.get_global_transform_with_canvas() * parca.hit_offset)


# --- Yerleşim (ekran boyutuna göre; telefon ve tablet oranları) ---

func _layout() -> void:
	var size := get_viewport_rect().size
	var xs: Array[float] = []
	for k in dancers.size():
		xs.append(lerpf(270.0, size.x - 270.0, float(k) / maxf(1.0, dancers.size() - 1.0)))
		dancers[k].position = Vector2(xs[k], FLOOR_Y)
	background.layout(size, FLOOR_Y, xs)
	var top := background.floor_bottom(FLOOR_Y) + 10.0
	hud.layout(size, top, size.y - 12.0)
	var right := hud.column_left(size) - 24.0
	var left := EkranYardimcisi.kenar_payi(SIDE_LEFT, SIDE - 16.0)
	_area = Rect2(left, top, right - left, size.y - top - 14.0)
	for each in instruments:
		each.fit(_area)
	_kill_slides()


# --- Enstrüman seçimi: eski enstrüman kayıp solar, yenisi karşı taraftan kayarak gelir ---

func select(index: int, animate: bool = true) -> void:
	if index == current:
		hud.bounce(index)
		return
	var previous := current
	current = index
	# Eski enstrümana giden parmaklar artık hiçbir yere gitmesin; yeni dokunuşlar hemen yeni enstrümana
	for finger in _owners.keys():
		_owners[finger] = "ui"
	hud.select(index, animate)
	var incoming := instruments[index]
	incoming.show()
	incoming.position = incoming.home
	incoming.modulate.a = 1.0
	if previous == -1 or not animate:
		for k in instruments.size():
			instruments[k].visible = k == index
		return
	var outgoing := instruments[previous]
	outgoing.release_all()
	_kill_slides()
	var direction := 1.0 if index > previous else -1.0
	var distance := _area.size.y * 0.55
	var out_tween := outgoing.create_tween().set_parallel()
	out_tween.tween_property(outgoing, "position", outgoing.home - Vector2(0, direction * distance), SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out_tween.tween_property(outgoing, "modulate:a", 0.0, SLIDE_TIME)
	out_tween.chain().tween_callback(outgoing.hide)
	incoming.position = incoming.home + Vector2(0, direction * distance)
	incoming.modulate.a = 0.0
	var in_tween := incoming.create_tween().set_parallel()
	in_tween.tween_property(incoming, "position", incoming.home, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(incoming, "modulate:a", 1.0, SLIDE_TIME * 0.7)
	_slides = [out_tween, in_tween]
	for k in instruments.size():
		if k != index and k != previous:
			instruments[k].hide()


func _kill_slides() -> void:
	for tween in _slides:
		if tween.is_valid():
			tween.kill()
	_slides.clear()
	for k in instruments.size():
		instruments[k].position = instruments[k].home
		instruments[k].visible = k == current
		instruments[k].modulate.a = 1.0


func instrument() -> Instrument:
	return instruments[current]


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	if SahneGecis.gecis_suruyor:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		idle_time = 0.0
		instrument().press_key(key.keycode - KEY_1)
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag and _owners.get(drag.index) == "instrument":
		instrument().touch_move(drag.index, drag.position)


func _on_press(index: int, at: Vector2) -> void:
	idle_time = 0.0
	if back_touch == -1 and hud.back_button.contains(at):
		back_touch = index
		hud.back_button.press()
		_owners[index] = "ui"
		return
	var selector := hud.selector_at(at)
	if selector != -1:
		_owners[index] = "ui"
		select(selector)
		return
	_owners[index] = "instrument"
	instrument().touch_down(index, at)


func _on_release(index: int) -> void:
	if index == back_touch:
		_release_back()
	if _owners.get(index) == "instrument":
		instrument().touch_up(index)
	_owners.erase(index)


func _release_back() -> void:
	back_touch = -1
	hud.back_button.release()


# Uygulama arka plana giderse basılı parmaklar bırakılır
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if back_touch != -1:
			_release_back()
		if current != -1:
			instrument().release_all()
		_owners.clear()


# --- Müzik olunca: efektler ve dans ---

func _on_note_played(pad: Node2D, at: Vector2, source: Instrument) -> void:
	effects.notes(at, pad.color, 2 if source.ring_effect else 1)
	if source.ring_effect:
		effects.ring(at, 110.0 * source.scale.x, pad.color)
	for dancer in dancers:
		dancer.kick(0.8)


func _on_song_started(_song: MusicSong) -> void:
	for dancer in dancers:
		dancer.kick(0.5)


func _on_song_finished(_song: MusicSong) -> void:
	effects.confetti(get_viewport_rect().size)
	for k in dancers.size():
		get_tree().create_timer(k * 0.12).timeout.connect(dancers[k].celebrate)


func _process(delta: float) -> void:
	idle_time += delta
	if idle_time >= invite_after:
		idle_time = 0.0
		invite_count += 1
		instrument().invite()
