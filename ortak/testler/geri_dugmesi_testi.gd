extends SceneTree
# Ortak geri düğmesi testi (headless). Proje kökünden:
#   godot --headless --path . --fixed-fps 60 -s res://ortak/testler/geri_dugmesi_testi.gd
# Denetler: tek dokunuş çıkmaz, düğmeyi büyütür; çok hızlı ikinci dokunuş sayılmaz; bekleme süresi bitince ya da
# başka bir yere dokununca düğme küçülür; zamanında ikinci dokunuş çıkar; basılı tutmak da çıkar; double_tap = false iken iki dokunuş
# çıkmaz, sadece basılı tutmak çıkar; reset() düğmeyi ilk haline döndürür.

const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")

var _fails := 0
var _done_count := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap(button: Control, frames: int = 4) -> void:
	button.press()
	await _frames(frames)
	button.release()


func _touch_at(pos: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = pos
	touch.pressed = pressed
	root.push_input(touch, true)


func _new_button() -> Control:
	var button: Control = HoldButton.new()
	button.size = Vector2(116, 116)
	button.position = Vector2(200, 200)
	root.add_child(button)
	button.completed.connect(func() -> void: _done_count += 1)
	return button


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	var button := _new_button()
	await _frames(2)

	# Tek dokunuş: çıkmaz, büyür
	_done_count = 0
	await _tap(button)
	await _frames(30)
	_check(_done_count == 0, "tek dokunuş çıkmamalı")
	_check(button.scale.x > 1.25, "ilk dokunuştan sonra düğme büyümeli (%.2f)" % button.scale.x)
	_check(button.pivot_offset == button.size / 2.0, "düğme ortasından büyümeli")

	# Bekleme süresi bitince küçülür, sonraki dokunuş yine ilk dokunuş sayılır
	await _frames(int(HoldButton.ARMED_TIME * 60.0) + 30)
	_check(button.scale.is_equal_approx(Vector2.ONE), "süre bitince düğme küçülmeli (%.2f)" % button.scale.x)
	await _tap(button)
	await _frames(20)
	_check(_done_count == 0, "süre bittikten sonraki dokunuş çıkmamalı")

	# Başka bir yere dokununca küçülür; sonraki dokunuş yine ilk dokunuş sayılır
	await _frames(25)
	_touch_at(Vector2(900, 500), true)
	_touch_at(Vector2(900, 500), false)
	await _frames(20)
	_check(not button._armed and button.scale.is_equal_approx(Vector2.ONE), "başka yere dokununca düğme küçülmeli")
	await _tap(button)
	await _frames(20)
	_check(_done_count == 0, "başka yere dokunduktan sonraki dokunuş çıkmamalı")
	# Düğmeye dokunan olay (oyun press() çağırır) düğmeyi küçültmez
	var center := button.get_global_rect().get_center()
	_touch_at(center, true)
	button.press()
	await _frames(2)
	_check(_done_count == 1, "düğmenin üstündeki ikinci dokunuş çıkmalı")
	button.release()
	button.reset()
	_done_count = 0
	await _tap(button)
	await _frames(20)

	# Zamanında ikinci dokunuş çıkar
	await _tap(button)
	await _frames(2)
	_check(_done_count == 1, "ikinci dokunuş çıkmalı")
	button.reset()
	_check(button.scale == Vector2.ONE and not button._armed, "reset() düğmeyi ilk haline döndürmeli")

	# Ekrana vurmak: çok hızlı art arda dokunuşlar çıkmaz
	_done_count = 0
	for i in 3:
		await _tap(button, 2)
		await _frames(2)
	_check(_done_count == 0, "çok hızlı art arda dokunuşlar çıkmamalı")
	button.reset()

	# Basılı tutmak da çıkar
	button.press()
	await _frames(int(button.hold_time * 60.0) + 5)
	_check(_done_count == 1, "basılı tutmak çıkmalı")
	button.release()
	button.reset()

	# Sadece basılı tutma kipi (ebeveyn kapısı, temizle)
	_done_count = 0
	button.double_tap = false
	await _tap(button)
	await _frames(25)
	await _tap(button)
	await _frames(25)
	_check(_done_count == 0, "double_tap = false iken iki dokunuş çıkmamalı")
	_check(button.scale.is_equal_approx(Vector2.ONE), "double_tap = false iken düğme büyümemeli")
	button.press()
	await _frames(int(button.hold_time * 60.0) + 5)
	_check(_done_count == 1, "double_tap = false iken basılı tutmak çıkmalı")

	# handle_touch: dışarıya dokunuş kullanılmaz, içeriye dokunuş kullanılır
	var other := _new_button()
	await _frames(2)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(20, 20)
	_check(not other.handle_touch(touch), "düğme dışındaki dokunuş kullanılmamalı")
	touch.position = other.get_global_rect().get_center()
	_check(other.handle_touch(touch), "düğmedeki dokunuş kullanılmalı")

	button.free()
	other.free()
	print("geri düğmesi testi: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(1 if _fails > 0 else 0)
