extends Node2D
# Sürüklenen doktor aleti (ClinicTool; Hayvan Banyosu'ndaki alet.gd'nin uyarlaması). Raftan (alet_rafi.gd) tutulunca
# rafın yerinden büyüyerek parmağa gelir, parmakla birlikte gezer; bırakılınca küçülerek rafa uçar. Düğümün konumu
# parmağın ucu; aletin uç noktası (tip, ayarlar.gd TOOLS) parmağın LIFT kadar üstünde durur, böylece parmak noktayı
# örtmez. Etkiyi oyun tip_global() noktasında hesaplar.
# Sürtülen aletler hareket yönüne eğilir; basılı tutulan aletin ucunda dolum halkası (hold) çizilir;
# yerleştirilen alet (bant) stick_to ile hedefe uçup kaybolur (noktada bant görünür).

const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const RING := Color("ffd23f")
const RING_BACK := Color(1, 1, 1, 0.75)
const OUT := Color("3b2f6b")

var id: String = ""
var kind: int = Settings.Kind.RUB
var width: float = 170.0              # aletin ekrandaki genişliği
var lift: float = 60.0                # uç noktasının parmaktan yüksekliği
var active: bool = false
## Basılı tutulan aletin dolumu (0..1); 0'dan büyükse ucunda halka çizilir
var hold: float = 0.0

var _sprite: Sprite2D
var _target: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _tween: Tween
var _on_returned: Callable          # rafa dönüş bitince (yarıda kesilirse hemen) çağrılır


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	visible = false


## Alet ve boyu: base hasta boyu (genişlik TOOLS "width" oranıyla)
func set_tool(tool_id: String, base: float) -> void:
	id = tool_id
	var info: Dictionary = Settings.TOOLS[id]
	kind = info["kind"]
	width = base * float(info["width"])
	lift = lift_for(base)
	var texture := Settings.tool_texture(id)
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * width / texture.get_width()
	_sprite.rotation = 0.0
	# Görselin uç noktası parmağın lift kadar üstünde
	var tip: Vector2 = info["tip"]
	_sprite.offset = texture.get_size() * (Vector2(0.5, 0.5) - tip)
	_sprite.position = Vector2(0.0, -lift)
	hold = 0.0
	queue_redraw()


## Uç noktasının parmaktan yüksekliği (hasta boyuna göre; ipucu eli de kullanır)
static func lift_for(base: float) -> float:
	return clampf(base * 0.14, 44.0, 70.0)


## Aletin etki ettiği nokta (ekranda)
func tip_global() -> Vector2:
	return global_position + Vector2(0.0, -lift) * global_scale.y


# Raftan tutuldu: alet raftaki yerinden (görünen ortası slot'ta, genişliği icon_width) parmağa doğru büyür
func begin(point: Vector2, slot: Vector2, icon_width: float) -> void:
	_finish_return()
	active = true
	visible = true
	modulate.a = 1.0
	var s := icon_width / width
	scale = Vector2.ONE * s
	position = slot - visual_center() * s
	_target = point
	_velocity = Vector2.ZERO
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func move(point: Vector2) -> void:
	_target = point


# Bırakıldı: küçülerek raftaki yerine uçar, varınca gizlenir ve done çağrılır
func return_to(slot: Vector2, icon_width: float, done: Callable) -> void:
	if not active:
		return
	active = false
	hold = 0.0
	queue_redraw()
	_on_returned = done
	var s := icon_width / width
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", slot - visual_center() * s, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE * s, 0.28).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.2)
	_tween.tween_callback(_finish_return)


# Yerleştirildi: uç noktası hedefe kayar, alet küçülüp kaybolur (yerinde noktanın kendi görseli kalır); sonra done
func stick_to(point: Vector2, done: Callable) -> void:
	if not active:
		return
	active = false
	hold = 0.0
	queue_redraw()
	_on_returned = done
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", point + Vector2(0.0, lift), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.12)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(_finish_return)


func _finish_return() -> void:
	if not active:
		hide()
	if _on_returned.is_valid():
		var done := _on_returned
		_on_returned = Callable()
		done.call()


# Görselin ortası (düğüm biriminde)
func visual_center() -> Vector2:
	return _sprite.position + _sprite.offset * _sprite.scale.x


func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	var previous := position
	position = position.lerp(_target, 1.0 - exp(-28.0 * delta))
	_velocity = _velocity.lerp((position - previous) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	if kind == Settings.Kind.RUB:
		# Sürtülen alet hareket yönüne eğilir
		_sprite.rotation = clampf(_velocity.x / 3000.0, -0.35, 0.35)
	else:
		_sprite.rotation = lerpf(_sprite.rotation, sin(_time * 3.0) * 0.04, 1.0 - exp(-10.0 * delta))
	queue_redraw()


# Basılı tutulan aletin ucunda dolum halkası: beyaz zemin üstünde saat yönünde dolan sarı yay
func _draw() -> void:
	if not active or hold <= 0.0:
		return
	var center := Vector2(0.0, -lift)
	var r := width * 0.24
	draw_arc(center, r, 0.0, TAU, 48, Color(OUT, 0.35), 14.0, true)
	draw_arc(center, r, 0.0, TAU, 48, RING_BACK, 9.0, true)
	draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold, 0.0, 1.0), 48, RING, 9.0, true)
