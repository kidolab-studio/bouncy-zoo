extends Node2D
# Hayvanın üstündeki bir leke (Spot). Hayvanın gövde ya da kafa tuvalinin (256 birim) çocuğudur; konumu ve
# yarıçapı tuval biriminde. Sırayla dört durumdan geçer: MUD (çamur) → FOAM (köpük) → WET (su damlaları) → CLEAN.
# Her durumda amount 1'den 0'a iner (o adımın aleti üstünde sürtüldükçe); 0 olunca sonraki duruma geçer.
# Geçişler yumuşak: çamur solarken köpük büyür, köpük sönerken damlalar belirir, damlalar kurulanınca kaybolur.

enum State { MUD, FOAM, WET, CLEAN }

const TEX_MUD: Array[Texture2D] = [
	preload("res://oyunlar/hayvan_banyosu/gorseller/camur_1.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/camur_2.svg"),
	preload("res://oyunlar/hayvan_banyosu/gorseller/camur_3.svg"),
]
const TEX_FOAM: Texture2D = preload("res://oyunlar/hayvan_banyosu/gorseller/kopuk.svg")
const TEX_DROP: Texture2D = preload("res://oyunlar/hayvan_banyosu/gorseller/damla.svg")
## Islak lekedeki damlaların yeri (yarıçapa oran) ve boyu
const DROPS := [Vector3(-0.45, -0.2, 0.62), Vector3(0.4, -0.35, 0.5), Vector3(0.05, 0.4, 0.56)]

var state: State = State.MUD
var amount: float = 1.0
var radius: float = 25.0

var _mud: Sprite2D
var _foam: Sprite2D
var _drops: Array[Sprite2D] = []
var _shown: float = 1.0               # amount'un ekrandaki (yumuşatılmış) değeri
var _time: float = 0.0
var _pulse: float = 0.0               # ipucu parlaması (1 → 0)
var _wiggle: float = 0.0              # sürtülürken kıpırdama


func setup(spot_radius: float) -> void:
	radius = spot_radius
	_time = randf() * 10.0
	_mud = _sprite(TEX_MUD.pick_random(), radius * 2.5)
	_mud.rotation = randf() * TAU
	_foam = _sprite(TEX_FOAM, radius * 2.6)
	_foam.visible = false
	for d in DROPS:
		var drop := _sprite(TEX_DROP, radius * d.z)
		drop.position = Vector2(d.x, d.y) * radius
		drop.visible = false
		_drops.append(drop)


func _sprite(texture: Texture2D, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.set_meta("base", width / texture.get_width())
	sprite.scale = Vector2.ONE * float(sprite.get_meta("base"))
	add_child(sprite)
	return sprite


# Bu adımın aleti bu lekeye etki eder mi? (adım 0: sünger → çamur, 1: duş → köpük, 2: havlu → ıslak)
func needs(step: int) -> bool:
	return int(state) == step


# Parmak (ekran noktası) lekenin cömert alanının içinde mi
func hit(point: Vector2, hit_radius: float) -> bool:
	return global_position.distance_to(point) <= radius * hit_radius * global_scale.x


# Aletle sürtüldü: amount azalır. Durum değiştiyse true (bu adım için leke bitti).
func rub(part: float) -> bool:
	if state == State.CLEAN:
		return false
	amount -= part
	_wiggle = 1.0
	if amount > 0.0:
		return false
	state = (int(state) + 1) as State
	amount = 1.0
	_shown = 1.0
	return true


# İpucu: leke kısa süre parlar ve büyüyüp küçülür
func pulse() -> void:
	_pulse = 1.0


# Ekrandaki orta noktası (ipucu eli ve efektler için)
func screen_point() -> Vector2:
	return get_global_transform_with_canvas().origin


func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, amount, delta * 4.0)
	_pulse = move_toward(_pulse, 0.0, delta * 1.2)
	_wiggle = move_toward(_wiggle, 0.0, delta * 3.0)
	var t := _shown                   # 1: bu durumun başı, 0: sonu
	var bump := 1.0 + 0.18 * sin(_pulse * PI) + 0.05 * _wiggle * sin(_time * 30.0)
	modulate = Color(1.0 + 0.4 * _pulse, 1.0 + 0.4 * _pulse, 1.0 + 0.4 * _pulse)
	match state:
		State.MUD:
			_show(_mud, 0.25 + 0.75 * t, (0.7 + 0.3 * t) * bump)
			_show(_foam, 1.0 - t, (0.3 + 0.7 * (1.0 - t)) * bump)
			_show_drops(0.0, 1.0)
		State.FOAM:
			_mud.visible = false
			_show(_foam, 0.3 + 0.7 * t, (0.45 + 0.55 * t) * bump * (1.0 + 0.03 * sin(_time * 3.0)))
			_show_drops(1.0 - t, bump)
		State.WET:
			_foam.visible = false
			_show_drops(t, bump)
		State.CLEAN:
			_mud.visible = false
			_foam.visible = false
			_show_drops(0.0, 1.0)


func _show(sprite: Sprite2D, alpha: float, size: float) -> void:
	sprite.visible = alpha > 0.01
	sprite.modulate.a = clampf(alpha, 0.0, 1.0)
	sprite.scale = Vector2.ONE * float(sprite.get_meta("base")) * size


# Damlalar ıslak lekede yavaşça aşağı kayar ve tekrar başa döner
func _show_drops(alpha: float, size: float) -> void:
	for i in _drops.size():
		var drop := _drops[i]
		var d: Vector3 = DROPS[i]
		var slide := fmod(_time * 0.12 + i * 0.37, 1.0)
		drop.position = Vector2(d.x, d.y + slide * 0.35) * radius
		_show(drop, alpha * (1.0 - slide * slide), size)
