extends SceneTree
# Gölge Eşleştirme oynanış testi (ortak sürükle-bırak bileşeniyle). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 720x1280 -s res://oyunlar/golge_eslestirme/testler/oynanis_testi.gd
# 10 bölümü sürükleyerek oynar. Denetler: boşluğa ve yanlış gölgeye bırakılan eşya yerine döner;
# ikinci parmak tutulan eşyayı bozmaz ve başka eşya tutamaz; doğru gölgeye bırakılan eşya yerleşir;
# bölümler sırayla ilerler, 10. bölümden sonra 1. bölüme dönülür. Kullanıcının kaydı yedeklenip geri yazılır.

const GAME_SCENE := "res://oyunlar/golge_eslestirme/golge_eslestirme.tscn"
const SAVE_PATH := "user://golge_eslestirme.cfg"

var _bitmisti := false             # oyun bu testten önce tamamlanmış mıydı (OyunBitti)
var game: Node
var _fails := 0
var _backup: PackedByteArray
var _had_save := false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	_bitmisti = OyunBitti.tamamlandi_mi("golge_eslestirme")
	OyunBitti.sifirla("golge_eslestirme")
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_bytes(SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	root.get_node("SahneGecis").visible = false
	game = load(GAME_SCENE).instantiate()
	root.add_child(game)
	await _play_all()
	_finish()


func _finish() -> void:
	if _bitmisti:
		OyunBitti.tamamla("golge_eslestirme")
	else:
		OyunBitti.sifirla("golge_eslestirme")
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_backup)
	if _fails == 0:
		print("golge oynanis_testi: TAMAM")
	else:
		printerr("golge oynanis_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


func _play_all() -> void:
	var count: int = game.levels.size()
	_check(count == 10, "10 bölüm olmalı, %d" % count)
	for level in count:
		await _wait_playing()
		_check(game.level_index == level, "bölüm %d bekleniyordu, %d" % [level, game.level_index])
		if level == 0:
			await _empty_and_wrong_drop()
			await _second_finger()
		for item in game.items.duplicate():
			await _drop_on(item, item.slot.position)
			await _frames(20)
			_check(item.placed, "bölüm %d: eşya gölgesine yerleşmedi" % level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "son bölümden sonra 1. bölüme dönülmedi (%d)" % game.level_index)
	_check(game.placed_count == 0, "yeni turda yerleşmiş eşya var")


func _empty_and_wrong_drop() -> void:
	var item = game.items[0]
	var other = game.items[1]
	# Boşluğa (ekranın sol altı) bırak: yerine döner, yerleşmez
	await _drop_on(item, Vector2(60, game.get_viewport_rect().size.y - 40))
	await _frames(50)
	_check(not item.placed and item.position.distance_to(item.home) < 2.0, "boşluğa bırakılan eşya yerine dönmedi")
	# Başka eşyanın gölgesine bırak: yerine döner
	await _drop_on(item, other.slot.position)
	await _frames(60)
	_check(not item.placed and item.position.distance_to(item.home) < 2.0, "yanlış gölgeye bırakılan eşya yerine dönmedi")
	_check(not other.slot.is_filled, "yanlış eşya gölgeyi doldurdu")


# 1. parmak eşyayı tutarken 2. parmak başka eşyaya basıp sürükler: hiçbir şey olmamalı
func _second_finger() -> void:
	var item = game.items[0]
	var other = game.items[1]
	var other_home: Vector2 = other.home
	_touch(item.position, true, 0)
	await _frames(2)
	_touch(other.position, true, 1)
	_drag_event(other.position + Vector2(0, -200), 1)
	await _frames(10)
	_check(other.position.distance_to(other_home) < 2.0 and not other.dragging, "ikinci parmak başka eşyayı sürükledi")
	_touch(other.position + Vector2(0, -200), false, 1)
	await _frames(2)
	_check(item.dragging, "ikinci parmak kalkınca ilk eşya bırakıldı")
	var lift: float = game.drag_input.lift
	for k in range(1, 7):
		_drag_event(item.position.lerp(item.slot.position + Vector2(0, lift), k / 6.0), 0)
		await _frames(2)
	_touch(item.slot.position + Vector2(0, lift), false, 0)
	await _frames(20)
	_check(item.placed, "iki parmak sonrası eşya gölgesine yerleşmedi")


func _drop_on(item, target: Vector2) -> void:
	var lift: float = game.drag_input.lift
	var start: Vector2 = item.position
	var finger := target + Vector2(0, lift)
	_touch(start, true, 0)
	await _frames(2)
	for k in range(1, 9):
		_drag_event(start.lerp(finger, k / 8.0), 0)
		await _frames(2)
	await _frames(8)
	_touch(finger, false, 0)
	await _frames(2)


func _wait_playing() -> void:
	for k in 900:
		await process_frame
		if game.state == game.State.PLAYING:
			return
	_check(false, "bölüm oynanabilir hale gelmedi")


func _touch(pos: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	root.push_input(event, true)


func _drag_event(pos: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	root.push_input(event, true)


func _frames(count: int) -> void:
	for k in count:
		await process_frame


# Son bölümden sonra ortak final ekranı (OyunBitti) gelir; düğmeler belirince "Baştan oyna"ya dokunulur
func _final_bastan() -> void:
	for k in 3000:
		if OyunBitti.acik:
			break
		await process_frame
	_check(OyunBitti.acik, "son bölümden sonra final ekranı gelmedi")
	var ekran: OyunBitti = null
	for c in root.get_children():
		if c is OyunBitti:
			ekran = c
	if ekran == null:
		return
	for k in 600:
		if ekran._hazir:
			break
		await process_frame
	for satir: Array in ekran._dugmeler:
		if satir[1] == "bastan":
			for basili in [true, false]:
				var olay := InputEventScreenTouch.new()
				olay.position = (satir[0] as Control).get_global_rect().get_center()
				olay.pressed = basili
				root.push_input(olay, true)
