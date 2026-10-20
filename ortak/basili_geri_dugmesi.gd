extends Control
# Geri düğmesi. İki kullanım şekli var:
# - Çift dokunuş (varsayılan, oyunların geri düğmesi): ilk dokunuşta düğme büyür ve parlar; ikinci kez
#   dokunulursa "completed" gelir. Başka bir yere dokunulunca (ya da bir süre dokunulmazsa) düğme eski haline
#   döner. Çok hızlı art arda dokunuşlar (ekrana vurmak) sayılmaz, böylece küçük çocuklar kazara oyundan
#   çıkmaz. Basılı tutmak da çalışır (halkasız).
# - Basılı tutma (double_tap = false; ör. ebeveyn kapısı, resmi silme): parmak basılı kaldıkça halka dolar,
#   dolunca "completed" gelir; erken bırakılırsa halka geri söner.
# Dokunmayı ana sahne yönetir (press/release ya da handle_touch çağırır).

signal completed

const ICON: Texture2D = preload("res://ortak/gorseller/geri.svg")
const BG := Color(1, 1, 1, 0.95)
const BORDER := Color(0.23, 0.18, 0.42)
const RING := Color("ff7a9a")
const RING_BG := Color(0.23, 0.18, 0.42, 0.15)
const ARMED_SCALE := 1.35       # ilk dokunuştan sonraki büyüklük
const ARMED_TIME := 5.0         # hiç dokunulmazsa düğme bu kadar sonra küçülür (sn; görünmez)
const MIN_GAP := 0.3            # ilk dokunuştan bu kadar önce gelen ikinci dokunuş sayılmaz (sn)

var hold_time: float = 0.6
## true: iki dokunuşla (ya da basılı tutarak) çalışır; false: sadece basılı tutarak
var double_tap: bool = true
## Düğmenin dolgu rengi ve ikonu (geri dışındaki işler için; oyunların geri düğmesi hep aynı renktedir)
var bg_color: Color = BG
var icon: Texture2D = ICON
var _progress: float = 0.0
var _holding: bool = false
var _done: bool = false
var _finger: int = -1
var _armed: bool = false
var _armed_age: float = 0.0     # ilk dokunuştan beri geçen süre
var _armed_left: float = 0.0    # parmak kalkınca azalan bekleme süresi
var _outside_touch: bool = false   # düğme büyükken başka bir yere dokunuldu
var _scale_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0
	# Çentikli telefonlarda düğme çentiğin altında kalmasın: oyun yerini verdikten sonra güvenli alana alınır
	EkranYardimcisi.degisince(_guvenliye_al)
	_guvenliye_al.call_deferred()


## Düğmeyi güvenli alanın içine iter. Oyun düğmeyi sonradan başka bir yere taşırsa yeniden çağırabilir.
func _guvenliye_al() -> void:
	EkranYardimcisi.guvenliye_it(self)


## Sahnedeki hazır bir Panel'in yerine geçer (aynı konum ve boyut, aynı üst düğüm); Panel gizlenir.
static func replace(panel: Control, time: float = 0.6) -> Control:
	var button := new()
	button.position = panel.position
	button.size = panel.size
	button.hold_time = time
	panel.get_parent().add_child(button)
	panel.hide()
	return button


func contains(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().grow(10.0).has_point(point)


## Dokunma olayını kendi parmağıyla takip eder; olayı kullandıysa true döner.
func handle_touch(touch: InputEventScreenTouch) -> bool:
	if touch.pressed:
		if _finger == -1 and contains(touch.position):
			_finger = touch.index
			press()
			return true
		return false
	if touch.index == _finger:
		_finger = -1
		release()
		return true
	return false


## Aynı sahnede tekrar kullanılacaksa (tamamlanınca ekran değişmiyorsa) düğmeyi sıfırlar.
func reset() -> void:
	_done = false
	_holding = false
	_armed = false
	_outside_touch = false
	_finger = -1
	_progress = 0.0
	if _scale_tween:
		_scale_tween.kill()
	scale = Vector2.ONE
	queue_redraw()


## Düğme büyükken başka bir yere dokunulursa küçülür. Dokunmayı oyun yönettiği için burada sadece not edilir;
## oyun aynı karede press() çağırırsa (dokunuşu düğmenin saydıysa) not silinir.
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if _armed and touch and touch.pressed and not contains(touch.position):
		_outside_touch = true


func press() -> void:
	if _done:
		return
	_holding = true
	_outside_touch = false
	pivot_offset = size / 2.0      # boyut _ready'den sonra verilmiş olabilir; ortasından büyüsün
	if double_tap:
		if _armed and _armed_age >= MIN_GAP:
			_finish()
			return
		if not _armed:
			_arm()
	_tween_scale(_rest_scale() * 0.92, 0.08)


func release() -> void:
	_holding = false
	if _done:
		return
	_armed_left = ARMED_TIME
	_tween_scale(_rest_scale(), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _arm() -> void:
	_armed = true
	_armed_age = 0.0
	_armed_left = ARMED_TIME
	# Autoload adı yazılmaz: bu script -s ile çalışan testlerde de derlenir
	var sound := get_node_or_null("/root/SesYoneticisi")
	if sound:
		sound.efekt("dugme_tik")


func _disarm() -> void:
	_armed = false
	_outside_touch = false
	_tween_scale(1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _finish() -> void:
	_done = true
	_armed = false
	_progress = 1.0
	queue_redraw()
	completed.emit()


func _rest_scale() -> float:
	return ARMED_SCALE if _armed else 1.0


func _tween_scale(value: float, time: float) -> Tween:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(value, value), time)
	return _scale_tween


func _process(delta: float) -> void:
	if _done:
		return
	var before := _progress
	if _holding:
		_progress = minf(1.0, _progress + delta / hold_time)
		if _progress >= 1.0:
			_finish()
			return
	else:
		_progress = maxf(0.0, _progress - delta * 3.0)
	if _armed:
		_armed_age += delta
		if not _holding:
			_armed_left -= delta
		if _outside_touch or _armed_left <= 0.0:
			_disarm()
		queue_redraw()
	elif _progress != before:
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	if _armed:
		# Hafifçe atan parıltı: "bir daha dokun" der
		var pulse := 0.5 + 0.5 * sin(_armed_age * 7.0)
		draw_circle(center, radius + 8.0 + pulse * 8.0, Color(RING, 0.2 + pulse * 0.2))
	draw_circle(center + Vector2(0, 6), radius - 6.0, Color(0.2, 0.1, 0.3, 0.16))
	draw_circle(center, radius - 8.0, bg_color)
	draw_arc(center, radius - 8.0, 0.0, TAU, 48, BORDER, 5.0, true)
	var icon_size := radius * 1.0
	draw_texture_rect(icon, Rect2(center - Vector2(icon_size, icon_size) / 2.0, Vector2(icon_size, icon_size)), false)
	# Basılı tutma halkası sadece basılı tutma kipinde görünür (çift dokunuşta her dokunuşta yanıp sönmesin)
	if _progress > 0.0 and not double_tap:
		draw_arc(center, radius - 1.0, 0.0, TAU, 48, RING_BG, 10.0, true)
		draw_arc(center, radius - 1.0, -PI / 2.0, -PI / 2.0 + TAU * _progress, 48, RING, 10.0, true)
