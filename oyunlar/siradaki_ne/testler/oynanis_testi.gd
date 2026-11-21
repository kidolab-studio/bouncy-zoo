extends SceneTree
# Sıradaki Ne? oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/siradaki_ne/testler/oynanis_testi.gd -- <klasör>
# Ana menüden karta dokunup oyunu açar (ekran yatay olmalı) ve 15 bölümü parçaları sürükleyerek oynar. Denetler:
#   - her bölümde tema, dizi uzunluğu, boşluk ve seçenek sayısı ayarlar.gd'deki gibi; parçalar ekranın içinde;
#   - boşluğa bırakılan ve yanlış boşluğa bırakılan parça tepsiye döner, yerleşmez;
#   - birinci parmak bir parça tutarken ikinci parmak başka parça tutamaz;
#   - aynı parçadan iki boşluk varsa ikisine de oturur; dizideki parçalar tutulamaz;
#   - bölüm geçişinde parça tutulamaz;
#   - bölüm bitince tema gösterisi oynar, sonraki bölüm gelir ve ilerleme kaydedilir; 15. bölümden sonra final
#     ekranı (OyunBitti), "baştan oyna" 1. bölümü açar; çift dokunuşlu geri düğmesiyle menüye dönülür.
# <klasör> içine her bölümün ve her tema gösterisinin ekran görüntüsünü kaydeder. Kullanıcının kayıtları
# yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/siradaki_ne/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/siradaki_ne/siradaki_ne.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://siradaki_ne.cfg"
const SAVES := ["user://siradaki_ne.cfg", "user://siradaki_ne.cfg.bak", "user://ana_menu.cfg", "user://ana_menu.cfg.bak",
	"user://ipucu_eli.cfg"]

var _bitmisti := false
var out := ""
var game: Node
var _fails := 0
var _backups := {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	_bitmisti = OyunBitti.tamamlandi_mi("siradaki_ne")
	OyunBitti.sifirla("siradaki_ne")
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else ""
	for path in SAVES:
		if FileAccess.file_exists(path):
			_backups[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await _from_menu()
	if game != null:
		_check(root.content_scale_size == Vector2i(1280, 720), "ekran yatay değil: %s" % root.content_scale_size)
		await _play_all()
		await _back_to_menu()
	_finish()


func _finish() -> void:
	if _bitmisti:
		OyunBitti.tamamla("siradaki_ne")
	else:
		OyunBitti.sifirla("siradaki_ne")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("siradaki_ne oynanis_testi: TAMAM")
	else:
		printerr("siradaki_ne oynanis_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Açılış ---

func _from_menu() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(90)
	var index := -1
	for k in menu.OYUNLAR.size():
		if menu.OYUNLAR[k]["sahne"] == GAME_SCENE:
			index = k
	_check(index >= 0, "ana menüde Sıradaki Ne? kartı yok")
	if index < 0:
		return
	var card: Control = menu._kartlar[index]
	menu._konum = clampf(card.position.y - 40.0, 0.0, menu._en_fazla)
	await _frames(30)
	_tap(card.get_global_rect().get_center())
	for k in 400:
		await process_frame
		if current_scene and current_scene.scene_file_path == GAME_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == GAME_SCENE, "karta dokununca oyun açılmadı")
	if current_scene and current_scene.scene_file_path == GAME_SCENE:
		game = current_scene
		_check(game.has_method("_start_level"), "oyun script'i yüklenemedi")
		if not game.has_method("_start_level"):
			game = null


# --- Oynanış ---

func _play_all() -> void:
	var total := Settings.level_count()
	_check(total == 15, "15 bölüm olmalı, %d" % total)
	for level in total:
		if level == 1:
			await _transition_grab()
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		_check_level_start(level)
		await _frames(40)
		await _shot("%02d_%s" % [level + 1, game.plan.theme])
		if level == 0:
			await _drop_nowhere()
			await _drop_wrong()
			await _second_finger()
			await _fixed_piece()
		await _solve(level)
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "baştan oyna 1. bölümü açmadı (%d)" % (game.level_index + 1))


func _check_level_start(level: int) -> void:
	var plan = game.plan
	var data: Dictionary = Settings.LEVELS[level]
	_check(plan.theme == data["theme"], "%d. bölüm: tema %s bekleniyordu, %s" % [level + 1, data["theme"], plan.theme])
	_check(plan.sequence.size() == Settings.length_of(data), "%d. bölüm: dizi uzunluğu yanlış" % (level + 1))
	_check(plan.gaps.size() == int(data["gaps"]), "%d. bölüm: boşluk sayısı yanlış" % (level + 1))
	_check(game.board.tray.size() == int(data["choices"]), "%d. bölüm: tepsideki parça sayısı yanlış" % (level + 1))
	var screen: Vector2 = game.get_viewport_rect().size
	for piece in game.board.tray + game.board.row_pieces():
		_check(Rect2(Vector2.ZERO, screen).grow(-20.0).has_point(piece.global_position), "%d. bölüm: parça ekranın dışında (%s)" % [level + 1, piece.global_position])


func _gap_point(g: int) -> Vector2:
	# Parça parmağın biraz üstünde durur: parmak yuvanın o kadar altına bırakılır
	return game.board.row.get_global_transform_with_canvas() * game.plan.slots[g] + Vector2(0.0, game.drag_input.lift)


func _piece_for(symbol: String):
	for piece in game.board.tray:
		if piece.symbol == symbol and piece.can_grab():
			return piece
	return null


func _wrong_piece(g: int):
	for piece in game.board.tray:
		if piece.symbol != game.plan.sequence[g] and piece.can_grab():
			return piece
	return null


# Parçayı boş bir yere bırakınca tepsiye döner
func _drop_nowhere() -> void:
	var piece = game.board.tray[0]
	var home: Vector2 = piece.home
	await _drag(piece.global_position, Vector2(game.plan.screen.x / 2.0, game.plan.area.position.y + 470.0), 0)
	await _frames(45)
	_check(not piece.placed and piece.position.distance_to(home) < 2.0, "boşluğa bırakılan parça tepsiye dönmedi")


# Yanlış parçayı boşluğa bırakınca yerleşmez, tepsiye döner
func _drop_wrong() -> void:
	var g: int = game.plan.gaps[0]
	var piece = _wrong_piece(g)
	_check(piece != null, "tepside yanlış parça yok")
	if piece == null:
		return
	await _drag(piece.global_position, _gap_point(g), 0)
	await _frames(10)
	await _shot("01b_yanlis")
	await _frames(40)
	_check(not piece.placed and game.board.pieces[g] == null, "yanlış parça boşluğa yerleşti")
	_check(piece.position.distance_to(piece.home) < 2.0, "yanlış parça tepsiye dönmedi")
	_check(game.board.wrong_count == 1, "yanlış sayılmadı")


# Birinci parmak parça tutarken ikinci parmak başka parçayı tutamaz
func _second_finger() -> void:
	var first = game.board.tray[0]
	var second = game.board.tray[1]
	_touch(first.global_position, true, 0)
	await _frames(3)
	_check(first.dragging, "birinci parmak parçayı tutamadı")
	_touch(second.global_position, true, 1)
	await _frames(3)
	_check(not second.dragging, "ikinci parmak da parça tuttu")
	_touch(second.global_position, false, 1)
	_touch(first.global_position, false, 0)
	await _frames(40)
	_check(not first.dragging and first.position.distance_to(first.home) < 2.0, "bırakılan parça tepsiye dönmedi")


# Dizideki (baştan yerleşmiş) parça tutulamaz
func _fixed_piece() -> void:
	var fixed = game.board.row_pieces()[0]
	var before: Vector2 = fixed.position
	await _drag(fixed.global_position, fixed.global_position + Vector2(0, 200), 0)
	await _frames(10)
	_check(fixed.position.distance_to(before) < 2.0 and not fixed.dragging, "dizideki parça tutuldu")


# Bütün boşlukları doğru parçalarla doldurur (aynı parçadan iki boşluk varsa ikisi de dolar)
func _solve(level: int) -> void:
	for g in game.plan.gaps:
		var piece = _piece_for(game.plan.sequence[g])
		_check(piece != null, "%d. bölüm: boşluk %d için parça yok" % [level + 1, g])
		if piece == null:
			continue
		await _drag(piece.global_position, _gap_point(g), 0)
		await _frames(25)
		_check(piece.placed and game.board.pieces[g] == piece, "%d. bölüm: doğru parça boşluğa oturmadı" % (level + 1))


func _wait_level_end(level: int) -> void:
	for k in 600:
		await process_frame
		if game.state == game.State.CELEBRATING:
			break
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: boşluklar dolunca kutlama başlamadı" % (level + 1))
	if level < 5:
		# Tema gösterisinin ortası (dizinin çalınmasından sonra)
		await _frames(210)
		await _shot("%02d_%s_bitis" % [level + 1, game.plan.theme])
	if level < Settings.level_count() - 1:
		for k in 1200:
			await process_frame
			if game.level_index == level + 1:
				break
		_check(game.level_index == level + 1, "%d. bölümden sonra sonraki bölüm gelmedi" % (level + 1))
		var config := ConfigFile.new()
		_check(config.load(SAVE) == OK and int(config.get_value("ilerleme", "bolum", -1)) == level + 1,
			"%d. bölümden sonra ilerleme kaydedilmedi" % (level + 1))


# Bölüm gelirken (geçişte) parça tutulamaz
func _transition_grab() -> void:
	for k in 1200:
		if game.level_index == 1 and game.board != null and not game.board.tray.is_empty():
			break
		await process_frame
	_check(game.state != game.State.PLAYING, "geçiş beklenirken bölüm hemen oynanabilir oldu")
	var piece = game.board.tray[0]
	_touch(piece.global_position, true, 0)
	await _frames(3)
	_check(not piece.dragging, "geçişte parça tutuldu")
	_touch(piece.global_position, false, 0)


func _back_to_menu() -> void:
	await _wait_playing()
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(center)
	await _frames(30)
	_check(current_scene.scene_file_path == GAME_SCENE, "geri düğmesine tek dokunuş oyundan çıkardı")
	_tap(center)
	for k in 300:
		await process_frame
		if current_scene and current_scene.scene_file_path == MENU_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "çift dokunuşlu geri düğmesiyle menüye dönülmedi")


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
	await _shot("16_final")
	for satir: Array in ekran._dugmeler:
		if satir[1] == "bastan":
			for basili in [true, false]:
				var olay := InputEventScreenTouch.new()
				olay.position = (satir[0] as Control).get_global_rect().get_center()
				olay.pressed = basili
				root.push_input(olay, true)


# --- Yardımcılar ---

# Noktadan noktaya sürükleyip bırakır
func _drag(from: Vector2, to: Vector2, index: int) -> void:
	_touch(from, true, index)
	await _frames(2)
	for k in range(1, 9):
		_drag_event(from.lerp(to, k / 8.0), index)
		await _frames(2)
	await _frames(6)
	_touch(to, false, index)
	await _frames(2)


func _wait_playing() -> void:
	for k in 1200:
		await process_frame
		if game.state == game.State.PLAYING and game.board != null:
			return
	_check(false, "bölüm oynanabilir hale gelmedi")


func _touch(pos: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	root.push_input(event, true)


func _tap(pos: Vector2) -> void:
	_touch(pos, true, 0)
	_touch(pos, false, 0)


func _drag_event(pos: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	root.push_input(event, true)


func _frames(count: int) -> void:
	for k in count:
		await process_frame


func _shot(name: String) -> void:
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
