extends Node
# Noktaları Birleştir dokunma girdisi (DotInput). Oyun sahnesine düğüm olarak eklenir; dokunmaları kendisi
# (_input) okur ve sinyallerle bildirir. Ortak DragInput'un (ortak/surukleme_girdisi.gd) deseni, ama
# sürüklenen bir nesne yok: parmağın kendisi çizer.
#   - Aynı anda yalnızca bir parmak (active_touch) çizer; diğer parmaklar yok sayılır.
#   - Çift dokunuşlu geri düğmesi (ortak/basili_geri_dugmesi.gd) varsa önce ona bakılır.
#   - Sahne geçişi sürerken ve enabled = false iken dokunuşlar yok sayılır (geri düğmesi yine çalışır).
#   - Dokunma sistem tarafından iptal edilirse ya da uygulama arka plana giderse released gelir.

const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")

## Parmak değdi
signal pressed(pos: Vector2)
## Çizen parmak kaydı (from: önceki konum; ikisinin arasındaki noktalar da kaçmasın)
signal moved(from: Vector2, to: Vector2)
## Çizen parmak kalktı (ya da dokunma iptal oldu)
signal released
## Her basış ve kaydırmada (ipucu sayacı için)
signal touched

var enabled: bool = true
var back_button: HoldButton = null

var active_touch: int = -1
var _last := Vector2.ZERO
var _holding_back: bool = false


func _input(event: InputEvent) -> void:
	if SahneGecis.gecis_suruyor:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_on_press(touch.index, touch.position)
		elif touch.index == active_touch:
			_on_release()
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.index == active_touch and not _holding_back:
		touched.emit()
		var from := _last
		_last = drag.position
		if enabled:
			moved.emit(from, drag.position)


func _on_press(index: int, pos: Vector2) -> void:
	touched.emit()
	if active_touch != -1:
		return
	if back_button and back_button.contains(pos):
		active_touch = index
		_holding_back = true
		back_button.press()
		return
	if not enabled:
		return
	active_touch = index
	_last = pos
	pressed.emit(pos)


func _on_release() -> void:
	active_touch = -1
	touched.emit()
	if _holding_back:
		_holding_back = false
		back_button.release()
		return
	released.emit()


## Çizen parmağı bırakır (ör. bölüm biterken); basılı geri düğmesine dokunmaz
func cancel() -> void:
	if active_touch != -1 and not _holding_back:
		_on_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active_touch != -1:
		_on_release()
