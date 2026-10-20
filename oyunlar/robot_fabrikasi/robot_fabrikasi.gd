extends Node2D
# Robot Fabrikası ana sahnesi: katmanları ve parçaları kurar, dokunma/sürüklemeyi yönlendirir, doğru/yanlış kutu
# kararını verir, yardımcı robotu ve ipuçlarını yönetir, bölüm sonunda montajı başlatır ve ilerlemeyi kaydeder.
# Tasarım TASARIM.md'de, notlar CLAUDE.md'de.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"
## Hamle olmazsa yardımcı robotun ipucu vermesi için süre (sn)
@export var hint_delay: float = 7.0
## Sürüklenen parçanın parmağın ne kadar üstünde durduğu (px)
@export var drag_lift: float = 80.0

const Bolumler := preload("res://oyunlar/robot_fabrikasi/bolumler.gd")
const Yonetici := preload("res://oyunlar/robot_fabrikasi/bolum_yoneticisi.gd")
const ArkaPlan := preload("res://oyunlar/robot_fabrikasi/arka_plan.gd")
const Bant := preload("res://oyunlar/robot_fabrikasi/bant.gd")
const Parca := preload("res://oyunlar/robot_fabrikasi/parca.gd")
const Kutu := preload("res://oyunlar/robot_fabrikasi/kutu.gd")
const Yardimci := preload("res://oyunlar/robot_fabrikasi/yardimci.gd")
const Montaj := preload("res://oyunlar/robot_fabrikasi/montaj.gd")
const Galeri := preload("res://oyunlar/robot_fabrikasi/galeri.gd")
const Efektler := preload("res://oyunlar/robot_fabrikasi/efektler.gd")
const Sesler := preload("res://oyunlar/robot_fabrikasi/sesler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")
const G := "res://oyunlar/robot_fabrikasi/gorseller/"
const BELT_Y := 262.0
const BOX_Y := 560.0
const BOX_SPACING := 240.0

var manager := Yonetici.new()
var boxes: Array = []

var _world: Node2D
var _belt: Node2D
var _boxes_root: Node2D
var _helper: Node2D
var _effects: Node2D
var _montage: Node2D
var _gallery: Control
var _sounds: Node
var _ui: Control
var _back: Control
var _pause: Control
var _gallery_icon: TextureRect
var _pause_layer: Control
var _resume: Control
var _lever: Node2D
var _lever_stick: Sprite2D
var _size := Vector2(1280, 720)

var _held: Node2D = null
var _lift_tween: Tween
var _held_touch := -1
var _back_touch := -1
var _idle := 0.0
var _level_done := false
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_size = get_viewport_rect().size
	for error in Bolumler.validate():
		push_error("Robot Fabrikası: " + error)
	_build()
	manager.load_progress()
	_start_level()
	IpucuEli.ekle(self, "robot_fabrikasi", _ipucu)


# İpucu eli: banttaki (görünen) ilk parçayı onu alan kutuya sürükle; parça bantla birlikte kayar
func _ipucu() -> Dictionary:
	if _paused or _level_done or _held or _gallery.is_open() or _montage.running:
		return {}
	for part: Node2D in _belt.parts:
		if part.on_belt and part.visible and part.position.x < _size.x - 260.0:
			var right := manager.box_for(part.data)
			if right >= 0 and right < boxes.size():
				var hedef: Vector2 = get_viewport().get_canvas_transform() * boxes[right].drop_rect().get_center()
				return IpucuEli.surukle(IpucuEli.izle(part), hedef)
	return {}


# --- Kurulum ---

func _build() -> void:
	_sounds = Sesler.new()
	add_child(_sounds)
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var overlay := CanvasLayer.new()
	overlay.layer = 3
	add_child(overlay)
	var overlay_root := Node2D.new()
	overlay_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	overlay_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	overlay.add_child(overlay_root)
	_montage = Montaj.new()
	overlay_root.add_child(_montage)
	_effects = Efektler.new()
	overlay_root.add_child(_effects)
	_montage.effects = _effects
	_montage.sounds = _sounds

	var background := ArkaPlan.new()
	_world.add_child(background)
	background.setup(_effects)
	_boxes_root = Node2D.new()
	_world.add_child(_boxes_root)
	_belt = Bant.new()
	_world.add_child(_belt)
	_belt.setup(_size.x, BELT_Y)
	_belt.need_part.connect(_feed_belt)
	_belt.part_recycled.connect(_on_recycled)
	_helper = Yardimci.new()
	_helper.position = Vector2(92 + float(EkranYardimcisi.guvenli_bosluklar()["sol"]), _size.y - 20.0)
	_world.add_child(_helper)
	_helper.setup(_effects)
	_build_lever()

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ui.size = _size
	ui_layer.add_child(_ui)
	_pause_layer = Control.new()
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.size = _size
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.2, 0.45)
	dim.size = _size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(dim)
	_resume = _round_button(load(G + "oynat.svg"), 190.0)
	_resume.position = _size * 0.5 - _resume.size * 0.5
	_pause_layer.add_child(_resume)
	_pause_layer.visible = false
	_ui.add_child(_pause_layer)
	_pause = _round_button(load(G + "duraklat.svg"), 104.0)
	_pause.position = Vector2(_size.x - 140, 24)
	_ui.add_child(_pause)
	_gallery_icon = TextureRect.new()
	_gallery_icon.texture = load(G + "galeri.svg")
	_gallery_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gallery_icon.size = Vector2(108, 108)
	_gallery_icon.pivot_offset = Vector2(54, 54)
	_gallery_icon.position = Vector2(_size.x - 270, 22)
	_gallery_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_gallery_icon)
	_back = HoldButton.new()
	_back.size = Vector2(104, 104)
	_back.position = Vector2(36, 24)
	_back.hold_time = 0.6
	_back.completed.connect(_leave)
	_ui.add_child(_back)
	# Çentikli telefonlarda sağ üstteki düğmeler çentiğin altında kalmasın (aralarındaki düzen bozulmadan)
	EkranYardimcisi.guvenliye_it_grup([_gallery_icon, _pause])
	var screens := CanvasLayer.new()
	screens.layer = 10
	add_child(screens)
	_gallery = Galeri.new()
	_gallery.sounds = _sounds
	screens.add_child(_gallery)


func _round_button(icon: Texture2D, diameter: float) -> Control:
	var button := Control.new()
	button.size = Vector2(diameter, diameter)
	button.pivot_offset = button.size / 2.0
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.draw.connect(func() -> void:
		var c := button.size / 2.0
		var r := diameter / 2.0 - 5.0
		button.draw_circle(c + Vector2(0, 6), r, Color(0.2, 0.1, 0.1, 0.2))
		button.draw_circle(c, r, Color("fffaf0"))
		button.draw_arc(c, r, 0.0, TAU, 48, Color("6e4418"), 5.0, true)
		button.draw_texture_rect(icon, Rect2(c - Vector2(r, r) * 0.62 + Vector2(r * 0.06, 0), Vector2(r, r) * 1.24), false))
	return button


func _build_lever() -> void:
	_lever = Node2D.new()
	_lever.position = Vector2(_size.x - 92 - float(EkranYardimcisi.guvenli_bosluklar()["sag"]), _size.y - 20.0)
	_world.add_child(_lever)
	_lever_stick = Sprite2D.new()
	_lever_stick.texture = load(G + "kol_sap.svg")
	_lever_stick.scale = Vector2.ONE * 56.0 / _lever_stick.texture.get_width()
	_lever_stick.centered = false
	_lever_stick.offset = -Vector2(30, 180) * _lever_stick.texture.get_width() / 60.0
	_lever_stick.position = Vector2(0, -60)
	_lever_stick.rotation = -0.45
	_lever.add_child(_lever_stick)
	var base := Sprite2D.new()
	base.texture = load(G + "kol_taban.svg")
	base.scale = Vector2.ONE * 150.0 / base.texture.get_width()
	base.position = Vector2(0, -44)
	_lever.add_child(base)


# --- Bölüm akışı ---

func _start_level() -> void:
	_level_done = false
	var delay := 0.1
	for box in boxes:
		if is_instance_valid(box):
			box.leave(0.0)
			delay = 0.45
	boxes.clear()
	var data := Bolumler.level(manager.index, manager.rng)
	var count: int = data["boxes"].size()
	for i in count:
		var box: Node2D = Kutu.new()
		box.position = Vector2(_size.x * 0.5 + (i - (count - 1) * 0.5) * BOX_SPACING, BOX_Y + (_size.y - EkranYardimcisi.tasarim_boyutu().y) * 0.5)
		_boxes_root.add_child(box)
		box.setup(data["boxes"][i], Bolumler.capacity(data, i), _effects)
		box.filled.connect(func() -> void: _sounds.play("dolu"))
		box.appear(delay + i * 0.12)
		boxes.append(box)
	manager.start(manager.index, data, boxes)
	_belt.speed = manager.level["speed"]
	_belt.running = true
	_set_lever(true, false)
	_idle = 0.0
	get_tree().create_timer(0.7).timeout.connect(_helper.wave)


func _feed_belt() -> void:
	if _level_done:
		return
	var next := manager.next_part()
	if next.is_empty():
		return
	var part: Node2D = Parca.new()
	part.setup(next["data"], next["box"])
	_belt.drop_in(part)
	_sounds.play("dus")


func _on_recycled(part: Node2D) -> void:
	if _level_done or boxes[part.for_box].is_full():
		manager.discarded(part.for_box)
		part.queue_free()
		return
	part.scale = Vector2.ONE
	_belt.drop_in(part)
	_sounds.play("boru")


func _on_level_complete() -> void:
	_level_done = true
	_belt.running = false
	await get_tree().create_timer(0.8).timeout
	# Bantta kalanlar boruya gider (bölüm bitti)
	for part in _belt.parts.duplicate():
		var tween: Tween = part.create_tween()
		tween.tween_property(part, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	_belt.clear()
	var robot_id := manager.robot_id()
	var look := manager.robot_look()
	await _montage.run(robot_id, look, boxes, _gallery_icon.get_global_rect().get_center())
	_bounce(_gallery_icon)
	_effects.sparkles(_gallery_icon.get_global_rect().get_center(), Color("fff6b0"), 12, 40.0)
	manager.gallery[robot_id] = look
	manager.index += 1
	manager.save_progress()
	_start_level()


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _held_touch and _held:
		if _lift_tween:
			_lift_tween.kill()
		_held.global_position = drag.position + Vector2(0, -drag_lift)
		return
	if touch == null:
		return
	if not touch.pressed:
		if touch.index == _back_touch:
			_back.release()
			_back_touch = -1
		if touch.index == _held_touch:
			_drop(touch.position)
		return
	if SahneGecis.gecis_suruyor or _held:
		return
	_press(touch.index, touch.position)


func _press(index: int, p: Vector2) -> void:
	if _gallery.is_open():
		_gallery.touch(p)
		return
	if _back.contains(p):
		_back_touch = index
		_back.press()
		return
	if _paused:
		if _resume.get_global_rect().has_point(p):
			_bounce(_resume)
			_set_paused(false)
		return
	if _pause.get_global_rect().grow(8.0).has_point(p):
		_bounce(_pause)
		_sounds.play("tik")
		_set_paused(true)
		return
	if _gallery_icon.get_global_rect().grow(8.0).has_point(p) and not _montage.running:
		_bounce(_gallery_icon)
		_sounds.play("tik")
		_gallery.open(manager.gallery)
		return
	if _montage.running or _level_done:
		return
	if Rect2(_lever.global_position + Vector2(-90, -250), Vector2(180, 260)).has_point(p):
		_set_lever(not _belt.running, true)
		return
	# En üstteki (en son eklenen) parça tutulur
	for i in range(_belt.parts.size() - 1, -1, -1):
		var part: Node2D = _belt.parts[i]
		if part.on_belt and part.visible and part.contains(p):
			_pick(index, part, p)
			return
	if _helper.contains(p):
		_helper.giggle()
		_sounds.play("yardimci")


func _pick(index: int, part: Node2D, p: Vector2) -> void:
	_held = part
	_held_touch = index
	_belt.take(part)
	part.pick()
	part.highlight(false)
	_lift_tween = part.create_tween()
	_lift_tween.tween_property(part, "global_position", p + Vector2(0, -drag_lift), 0.1).set_trans(Tween.TRANS_SINE)
	_sounds.play("al")
	_idle = 0.0


func _drop(p: Vector2) -> void:
	var part := _held
	_held = null
	_held_touch = -1
	if part == null or not is_instance_valid(part):
		return
	part.release()
	var target: Node2D = null
	for box in boxes:
		if box.drop_rect().has_point(part.global_position) or box.drop_rect().has_point(p):
			target = box
	if target == null:
		_belt.return_to_belt(part, part.global_position)
		return
	if target.accepts(part.data):
		manager.accepted(boxes.find(target))
		target.receive(part)
		_sounds.play("dogru")
		_helper.cheer()
		if manager.is_complete() and not _level_done:
			_on_level_complete()
	else:
		target.reject(part, _belt)
		_sounds.play("boing")
		_helper.shake_head()
		var right := manager.box_for(part.data)
		if right >= 0:
			var box: Node2D = boxes[right]
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				box.flash()
				_helper.point_at(box.global_position + Vector2(0, -80)))


func _set_lever(run: bool, animate: bool) -> void:
	_belt.running = run
	var angle := -0.45 if run else 0.45
	if animate:
		_sounds.play("kol")
		var tween := _lever_stick.create_tween()
		tween.tween_property(_lever_stick, "rotation", angle, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lever_stick.rotation = angle


func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	_pause_layer.visible = value
	_pause.visible = not value
	if value:
		_resume.scale = Vector2(0.6, 0.6)
		_resume.create_tween().tween_property(_resume, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bounce(control: CanvasItem) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _leave() -> void:
	get_tree().paused = false
	manager.save_progress()
	SahneGecis.ana_menuye_don()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _gallery and not _paused and not _gallery.is_open():
		_set_paused(true)


# --- İpucu: uzun süre hamle yoksa yardımcı bir parçayı ve doğru kutusunu gösterir ---

func _process(delta: float) -> void:
	if _paused or _level_done or _held or _gallery.is_open():
		_idle = 0.0
		return
	_idle += delta
	if _idle < hint_delay:
		return
	_idle = 0.0
	var candidates: Array = _belt.parts.filter(func(p: Node2D) -> bool: return p.on_belt and p.visible and p.position.x < _size.x - 260.0)
	if candidates.is_empty():
		return
	var part: Node2D = candidates[0]
	var right := manager.box_for(part.data)
	if right < 0:
		return
	part.highlight(true)
	_effects.sparkles(part.global_position, Color("fff6b0"), 10, 50.0)
	_helper.point_at(part.global_position, 0.9)
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(part):
			part.highlight(false)
		if right < boxes.size() and is_instance_valid(boxes[right]):
			boxes[right].flash()
			_helper.point_at(boxes[right].global_position + Vector2(0, -80), 0.9))
