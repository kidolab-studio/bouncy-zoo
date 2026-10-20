extends SceneTree
# Robot Fabrikası oynanış testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://oyunlar/robot_fabrikasi/testler/fabrika_testi.gd
# Denetler: bölüm verisi geçerli, bütün parça ve robot görselleri var; parça dokunarak sürüklenip doğru kutuya
# girer, yanlış kutudan banda geri döner; bandın sonundaki parça borudan geri gelir; kol bandı durdurur;
# 15 bölümün hepsi bitirilip robot montajı tamamlanır, galeri ve kayıt güncellenir, kayıt geri yüklenir.
# Hata varsa çıkış kodu 1. user://robot_fabrikasi.cfg yedeklenir ve sonunda geri yazılır.

const Bolumler := preload("res://oyunlar/robot_fabrikasi/bolumler.gd")
const Yonetici := preload("res://oyunlar/robot_fabrikasi/bolum_yoneticisi.gd")
const Parca := preload("res://oyunlar/robot_fabrikasi/parca.gd")
const Robot := preload("res://oyunlar/robot_fabrikasi/robot.gd")

var failures := 0
var game: Node
var _backup := PackedByteArray()
var _had_save := false


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	var bitmisti := OyunBitti.tamamlandi_mi("robot_fabrikasi")
	OyunBitti.sifirla("robot_fabrikasi")
	_save_backup(Yonetici.PATH)
	root.content_scale_size = Vector2i(1280, 720)
	_check_data()
	game = load("res://oyunlar/robot_fabrikasi/robot_fabrikasi.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	await _check_wrong_and_right()
	await _check_recycle()
	await _check_lever()
	await _check_all_levels()
	_expect(OyunBitti.acik, "15. bölümden sonra final ekranı açılmalı")
	for c in root.get_children():
		if c is OyunBitti:
			c.queue_free()
	await _frames(2)
	await _check_gallery()
	await _check_save()
	game.queue_free()
	await process_frame
	_save_restore(Yonetici.PATH)
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures)
	if bitmisti:
		OyunBitti.tamamla("robot_fabrikasi")
	else:
		OyunBitti.sifirla("robot_fabrikasi")
	quit(1 if failures > 0 else 0)


# Kullanıcının kaydı test boyunca yedekte durur, sonunda geri yazılır (kayıt yoksa testin yazdığı silinir)
func _save_backup(path: String) -> void:
	if FileAccess.file_exists(path):
		_backup = FileAccess.get_file_as_bytes(path)
		_had_save = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _save_restore(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _had_save:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()


func _check_data() -> void:
	_expect(Bolumler.validate().is_empty(), "bölüm verisi geçerli: %s" % [Bolumler.validate()])
	_expect(Bolumler.LEVELS.size() >= 15, "en az 15 bölüm")
	_expect(Robot.ORDER.size() == 15, "15 robot")
	for color in Bolumler.COLORS:
		for kind in Bolumler.ALL_KINDS:
			if kind in Bolumler.SHAPED_KINDS:
				for shape in Bolumler.SHAPES:
					_expect(Parca.texture_for({"kind": kind, "color": color, "shape": shape}) != null, "%s %s %s görseli" % [kind, shape, color])
			else:
				_expect(Parca.texture_for({"kind": kind, "color": color}) != null, "%s %s görseli" % [kind, color])
	var ids := {}
	for data in Bolumler.LEVELS:
		_expect(Robot.ROBOTS.has(data["robot"]), "robot şablonu var: %s" % data["robot"])
		ids[data["robot"]] = true
	_expect(ids.size() == Bolumler.LEVELS.size(), "her bölümde farklı robot")


# --- Dokunma yardımcıları ---

func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = pos
	root.push_input(ev, true)


func _move(part: Node2D, to: Vector2) -> void:
	var from: Vector2 = part.global_position
	_touch(from, true)
	await _frames(3)
	for i in range(1, 9):
		_drag(from.lerp(to, i / 8.0))
		await process_frame
	_touch(to, false)
	await _frames(2)


func _belt_part() -> Node2D:
	for f in 900:
		for part in game._belt.parts:
			if part.on_belt and part.visible and part.position.x > 200.0 and part.position.x < 1000.0:
				return part
		await process_frame
	return null


func _box_point(box: Node2D) -> Vector2:
	return box.global_position + Vector2(0, 40)


# --- Testler ---

func _check_wrong_and_right() -> void:
	var part := await _belt_part()
	_expect(part != null, "bantta parça belirmeli")
	if part == null:
		return
	var right: int = game.manager.box_for(part.data)
	var wrong: int = (right + 1) % game.boxes.size()
	await _move(part, _box_point(game.boxes[wrong]) + Vector2(0, 80))
	_expect(game.boxes[wrong].stored.is_empty(), "yanlış kutu parçayı almamalı")
	await _frames(50)
	_expect(part in game._belt.parts and part.on_belt, "yanlış parça banda dönmeli")
	await _move(part, _box_point(game.boxes[right]) + Vector2(0, 80))
	_expect(game.boxes[right].stored.size() == 1, "doğru kutu parçayı almalı")
	_expect(not part in game._belt.parts, "kutudaki parça bantta olmamalı")


func _check_recycle() -> void:
	var part := await _belt_part()
	if part == null:
		_expect(false, "geri dönüş için parça yok")
		return
	part.position.x = game._belt.right_x + 40.0
	await _frames(3)
	_expect(not part in game._belt.parts, "bandın sonundaki parça boruya girmeli")
	await _frames(240)
	_expect(part in game._belt.parts, "borudaki parça baştan geri gelmeli")


func _check_lever() -> void:
	var lever_pos: Vector2 = game._lever.global_position + Vector2(0, -120)
	_touch(lever_pos, true)
	_touch(lever_pos, false)
	await _frames(5)
	_expect(not game._belt.running, "kol bandı durdurmalı")
	var part := await _belt_part()
	var x: float = part.position.x if part else 0.0
	await _frames(30)
	_expect(part == null or is_equal_approx(part.position.x, x), "duran bantta parça ilerlememeli")
	_touch(lever_pos, true)
	_touch(lever_pos, false)
	await _frames(5)
	_expect(game._belt.running, "kol bandı yeniden çalıştırmalı")


# Her bölümü dokunmayla bitirir; montaj bitince bir sonraki bölüm başlamalı
func _check_all_levels() -> void:
	for level in Bolumler.LEVELS.size():
		var start_index: int = game.manager.index
		var guard := 0
		var moves := 0
		var needed := 0
		for b in game.boxes:
			needed += b.capacity - b.stored.size()
		while game.manager.index == start_index and guard < 200:
			guard += 1
			if game._level_done:
				await _frames(10)
				continue
			var part := await _belt_part()
			if part == null:
				break
			var right: int = game.manager.box_for(part.data)
			if right < 0:
				_expect(false, "bölüm %d: parçanın kutusu yok %s" % [start_index + 1, part.data])
				break
			var before: int = game.boxes[right].stored.size()
			await _move(part, _box_point(game.boxes[right]) + Vector2(0, 80))
			moves += 1
			_expect(game.boxes[right].stored.size() == before + 1, "bölüm %d: doğru kutuya bırakılan parça girmeli" % (start_index + 1))
		_expect(moves == needed, "bölüm %d: %d hamle, gereken %d" % [start_index + 1, moves, needed])
		_expect(game.manager.index == start_index + 1, "bölüm %d bitmeli" % (start_index + 1))
		_expect(game.manager.gallery.has(Bolumler.LEVELS[start_index]["robot"]), "bölüm %d robotu galeride" % (start_index + 1))
		print("bölüm %d tamam (%d hamle)" % [start_index + 1, moves])
		await _frames(90)


func _check_gallery() -> void:
	var icon_center: Vector2 = game._gallery_icon.get_global_rect().get_center()
	_touch(icon_center, true)
	_touch(icon_center, false)
	await _frames(40)
	_expect(game._gallery.is_open(), "galeri açılmalı")
	_expect(game._gallery._robots.size() == 15, "galeride 15 robot")
	var robot: Node2D = game._gallery._robots[0]
	var p := robot.global_position + Vector2(0, -40)
	_touch(p, true)
	_touch(p, false)
	await _frames(20)
	_expect(game._gallery.is_open(), "robota dokununca galeri açık kalmalı")
	_touch(Vector2(20, 700), true)
	_touch(Vector2(20, 700), false)
	await _frames(30)
	_expect(not game._gallery.is_open(), "rafların dışına dokununca galeri kapanmalı")


func _check_save() -> void:
	var saved := Yonetici.new()
	saved.load_progress()
	_expect(saved.index == Bolumler.LEVELS.size(), "kayıtta bölüm %d (beklenen %d)" % [saved.index, Bolumler.LEVELS.size()])
	_expect(saved.gallery.size() == 15, "kayıtta 15 robot (%d)" % saved.gallery.size())
	# Sonsuz modda da bölüm kurulabilmeli
	var data := Bolumler.level(saved.index + 3, saved.rng)
	_expect(not data["boxes"].is_empty(), "sonsuz bölüm kutuları")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("HATA: " + message)
