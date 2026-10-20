extends SceneTree
# Oynanış testi: ana menüden Toplama kartına dokunur, 20 bölümü baştan sona oynar ve son bölümden
# sonra 1. bölüme dönüldüğünü doğrular. Her bölümde önce yanlış bir düğmeye, sonra doğrusuna dokunur;
# yanlış kaybolurken ve doğru animasyonu sürerken gelen dokunuşların yok sayıldığını da denetler.
# Çalıştırma (proje klasöründe; pencereli, ekran görüntüsü için isteğe bağlı klasör):
#   Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://oyunlar/toplama/testler/oynanis_testi.gd -- --ekran=C:/klasor
# Varsa kullanıcının user://toplama.cfg kaydını yedekler ve sonunda geri koyar.

const GAME_SCENE := "res://oyunlar/toplama/toplama.tscn"
const SAVE_PATH := "user://toplama.cfg"
const SPEED := 3.0                      # testi hızlandırmak için oyun zamanı çarpanı
const SHOT_LEVELS := [0, 8, 16, 19]     # bu bölümlerin ekran görüntüsü alınır (0'dan)

var _bitmisti := false             # oyun bu testten önce tamamlanmış mıydı (OyunBitti)
var errors: PackedStringArray = []
var shot_dir: String = ""
var backup: PackedByteArray = []
var had_save: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	_bitmisti = OyunBitti.tamamlandi_mi("toplama")
	OyunBitti.sifirla("toplama")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ekran="):
			shot_dir = arg.trim_prefix("--ekran=")
	if FileAccess.file_exists(SAVE_PATH):
		had_save = true
		backup = FileAccess.get_file_as_bytes(SAVE_PATH)
		DirAccess.remove_absolute(SAVE_PATH)

	await process_frame
	change_scene_to_file("res://ana_menu/ana_menu.tscn")
	await _wait(func() -> bool: return current_scene != null and not _transition().gecis_suruyor, 300)
	var menu := current_scene
	var index := -1
	for i in menu.OYUNLAR.size():
		if menu.OYUNLAR[i]["sahne"] == GAME_SCENE:
			index = i
	_check(index >= 0, "ana menüde Toplama kartı yok")
	if index < 0:
		_finish()
		return
	await create_timer(1.5).timeout   # kartların açılış animasyonu
	var card: Control = menu._kartlar[index]
	_tap(card.get_global_rect().get_center())
	var opened := await _wait(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == GAME_SCENE and not _transition().gecis_suruyor, 600)
	_check(opened, "karta dokununca oyun açılmadı")
	if not opened:
		_finish()
		return
	_check(_transition().ekran_yonu == "yatay", "oyun yatay açılmadı")
	_check(root.content_scale_size == Vector2i(1280, 720), "çizim boyutu 1280x720 değil")

	var game := current_scene
	var count: int = game.settings.level_count()
	_check(game.level_index == 0, "kayıt yokken 1. bölümden başlamadı")
	await _test_extras(game)
	Engine.time_scale = SPEED
	for level in count:
		if not await _play_level(game, level):
			break
	# Final sonrası baştan
	await _final_bastan()
	var restarted := await _wait(func() -> bool: return game.state == game.State.WAITING and game.level_index == 0, 1200)
	_check(restarted, "son bölümden sonra 1. bölüme dönülmedi")
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_check(int(config.get_value("ilerleme", "bolum", -1)) == 0, "kayıt baştan başlamadı")
	_finish()


func _play_level(game: Node, level: int) -> bool:
	var ready := await _wait(func() -> bool: return game.state == game.State.WAITING, 900)
	_check(ready, "bölüm %d: cevap beklenmiyor" % (level + 1))
	if not ready:
		return false
	_check(game.level_index == level, "bölüm %d bekleniyordu, %d" % [level + 1, game.level_index + 1])
	var problem = game.problem
	var stage: AdditionStage = game.settings.stage_for_level(level)
	_check(game.buttons.size() == stage.choice_count, "bölüm %d: düğme sayısı %d" % [level + 1, game.buttons.size()])
	_check(game.box_a.objects.size() == problem.a and game.box_b.objects.size() == problem.b, "bölüm %d: kutulardaki nesne sayısı yanlış" % (level + 1))
	if level in SHOT_LEVELS:
		await _shot("bolum_%02d" % (level + 1))

	# Yanlış düğme: kaybolur, bölüm değişmez; kaybolurken doğruya dokunmak yok sayılır
	var wrong: Node2D = null
	var right: Node2D = null
	for button in game.buttons:
		if button.value == problem.answer:
			right = button
		elif wrong == null:
			wrong = button
	_tap(wrong.global_position)
	_check(game.state == game.State.WRONG, "bölüm %d: yanlış cevap durumu yok" % (level + 1))
	_tap(right.global_position)
	_check(game.state == game.State.WRONG, "bölüm %d: yanlış kaybolurken dokunuş kabul edildi" % (level + 1))
	await _wait(func() -> bool: return game.state == game.State.WAITING, 300)
	_check(game.buttons.size() == stage.choice_count - 1 and not is_instance_valid(wrong), "bölüm %d: yanlış düğme kaybolmadı" % (level + 1))
	_check(game.level_index == level, "bölüm %d: yanlış cevapta bölüm değişti" % (level + 1))

	# Doğru düğme + aynı karede ikinci dokunuş: yalnızca bir cevap sayılır
	var other: Node2D = null
	for button in game.buttons:
		if button != right:
			other = button
	_tap(right.global_position)
	if other:
		_tap(other.global_position)
	_check(game.state == game.State.CORRECT, "bölüm %d: doğru cevap kabul edilmedi" % (level + 1))
	if level == SHOT_LEVELS[-1]:
		await _wait(func() -> bool: return game.box_result.objects.size() >= problem.answer / 2, 600)
		await _shot("sayma_ortasi")
	var done := await _wait(func() -> bool:
		return game.state == game.State.LEVEL_DONE or game.state == game.State.FINALE, 1200)
	_check(done, "bölüm %d: kutlamaya geçilmedi" % (level + 1))
	_check(game.box_result.objects.size() == problem.answer, "bölüm %d: sonuç kutusunda %d nesne var, %d olmalı" % [level + 1, game.box_result.objects.size(), problem.answer])
	_check(game.box_a.objects.is_empty() and game.box_b.objects.is_empty(), "bölüm %d: nesneler kutulardan uçmadı" % (level + 1))
	if level == SHOT_LEVELS[0]:
		await _shot("kutlama")
	if game.state == game.State.FINALE:
		_check(level == game.settings.level_count() - 1, "final son bölümden önce geldi")
		await create_timer(1.0 * SPEED).timeout
		await _shot("final")
	return true


# Kutudaki nesneye dokunma
func _test_extras(game: Node) -> void:
	await _wait(func() -> bool: return game.state == game.State.WAITING, 600)
	var sprite: Sprite2D = game.box_a.objects[0]
	await create_timer(0.3).timeout
	_tap(sprite.global_position)
	await create_timer(0.07).timeout
	_check(sprite.position.y < sprite.get_meta("home").y - 1.0, "nesneye dokununca zıplamadı")
	_check(game.state == game.State.WAITING and game.level_index == 0, "nesneye dokunmak akışı değiştirdi")


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		root.push_input(touch, true)


func _wait(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _shot(file_name: String) -> void:
	if shot_dir == "":
		return
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(shot_dir.path_join(file_name + ".png"))


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		printerr("HATA: " + message)


func _finish() -> void:
	if _bitmisti:
		OyunBitti.tamamla("toplama")
	else:
		OyunBitti.sifirla("toplama")
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(SAVE_PATH)
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	if errors.is_empty():
		print("OYNANIŞ TESTİ: tamam")
		quit(0)
	else:
		printerr("OYNANIŞ TESTİ: %d hata" % errors.size())
		quit(1)


# Autoload adı (SahneGecis) -s ile çalışan script'te derlenirken bilinmez; düğümden alınır
func _transition() -> Node:
	return root.get_node("SahneGecis")


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
