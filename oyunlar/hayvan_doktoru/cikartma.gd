extends Node2D
# Bir çıkartma (Sticker): yuvarlak rozetin içinde iyileşmiş, mutlu hayvan (hasta.gd, noktasız) ve sağ altta
# rahatsızlığın küçük simgesi. Kazanılmamış çıkartma soluk gölge olarak görünür (simge yok). Albümde ve iyileşen
# hastadan albüme uçan çıkartmada kullanılır. Düğümün merkezi rozetin ortası.

const Patient := preload("res://oyunlar/hayvan_doktoru/hasta.gd")
const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const OUT := Color("3b2f6b")
const SHADOW := Color(0.32, 0.27, 0.5, 0.28)
## Rozetin iç rengi rahatsızlığa göre (AILMENT_ORDER sırasıyla, pastel)
const COLORS: Array[Color] = [Color("ffd9e6"), Color("d2f2de"), Color("ffe1c7"), Color("d5e7ff"), Color("ccedf0"),
	Color("fff0bd"), Color("f4dbf3"), Color("e3dbff"), Color("dff3d0")]

var animal: String = ""
var ailment: String = ""
var diameter: float = 150.0
var filled: bool = false

var _patient: Patient
var _icon: Sprite2D
var _wiggle: float = 0.0
var _time: float = 0.0


func setup(animal_id: String, ailment_name: String, size: float, is_filled: bool) -> void:
	animal = animal_id
	ailment = ailment_name
	diameter = size
	filled = is_filled
	_patient = Patient.new()
	add_child(_patient)
	_patient.setup(Settings.animal(animal), diameter * 0.9)
	_patient.position = Vector2(0.0, diameter * 0.38)
	if filled:
		_patient.cure()
		_icon = Sprite2D.new()
		_icon.texture = Settings.tool_texture(Settings.AILMENTS[ailment]["icon"])
		_icon.scale = Vector2.ONE * diameter * 0.3 / _icon.texture.get_width()
		_icon.position = Vector2(diameter * 0.33, diameter * 0.33)
		add_child(_icon)
	else:
		_patient.modulate = SHADOW
		_patient.set_process(false)        # gölge kıpırdamasın
	queue_redraw()


func contains(point: Vector2) -> bool:
	return to_local(point).length() <= diameter * 0.55


## Dokununca kısa sallanır ve hayvan zıplar
func wiggle() -> void:
	_wiggle = 1.0
	if filled:
		_patient.hop()


func _process(delta: float) -> void:
	_time += delta
	_wiggle = move_toward(_wiggle, 0.0, delta * 2.0)
	rotation = sin(_wiggle * 18.0) * 0.12 * _wiggle


func _draw() -> void:
	var r := diameter / 2.0
	var color: Color = COLORS[maxi(Settings.AILMENT_ORDER.find(ailment), 0) % COLORS.size()]
	if not filled:
		draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.45))
		draw_arc(Vector2.ZERO, r - 3.0, 0.0, TAU, 48, Color(OUT, 0.25), 4.0, true)
		return
	draw_circle(Vector2(0, 5), r + 2.0, Color(OUT, 0.18))
	draw_circle(Vector2.ZERO, r + 3.0, OUT)
	draw_circle(Vector2.ZERO, r, Color.WHITE)
	draw_circle(Vector2.ZERO, r * 0.86, color)
	draw_arc(Vector2.ZERO, r * 0.7, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.7), r * 0.07, true)
