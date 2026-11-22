extends SceneTree
# Yapboz oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/yapboz/testler/oynanis_testi.gd -- <klasör>
# Ana menüden karta dokunup oyunu açar ve bütün bölümleri parçaları sürükleyerek oynar. Denetler:
#   - her bölümde parça sayısı ayarlar.gd'deki ızgara kadar; parçalar ekranın içinde, tepsidekiler tahtanın
#     dışında;
#   - boş bir yere ve başka parçanın yerine bırakılan parça tepsiye döner, oturmaz;
#   - birinci parmak bir parça tutarken ikinci parmak başka parça tutamaz; oturan parça tutulamaz;
#   - bölüm geçişinde parça tutulamaz;
#   - bütün parçalar oturunca kutlama, sonra sonraki bölüm gelir ve ilerleme kaydedilir; son bölümden sonra
#     final ekranı (OyunBitti), "baştan oyna" 1. bölümü açar; çift dokunuşlu geri düğmesiyle menüye dönülür.
# <klasör> içine her bölümün (başında, ortasında, bitişinde) ekran görüntüsünü kaydeder. Kullanıcının
# kayıtları yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/yapboz/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/yapboz/yapboz.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://yapboz.cfg"
const SAVES := ["user://yapboz.cfg", "user://yapboz.cfg.bak", "user://ana_menu.cfg", "user://ana_menu.cfg.bak",
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
	_bitmisti = OyunBitti.tamamlandi_mi("yapboz")
	OyunBitti.sifirla("yapboz")
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else ""
	for path in SAVES:
		if FileAccess.file_exists(path):
			_backups[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await _open()
	if game != null:
		_check(root.content_scale_size == Vector2i(1280, 720), "ekran yatay değil: %s" % root.content_scale_size)
		await _play_all()
		await _back_to_menu()
	_finish()


func _finish() -> void:
	if _bitmisti:
		OyunBitti.tamamla("yapboz")
	else:
		OyunBitti.sifirla("yapboz")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("yapboz oynanis_testi: TAMAM")
	else:
		printerr("yapboz oynanis_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Açılış ---

# Ana menüde Yapboz kartına dokunup oyunu açar
func _open() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(90)
	var index := -1
	for k in menu.OYUNLAR.size():
		if menu.OYUNLAR[k]["sahne"] == GAME_SCENE:
			index = k
	_check(index >= 0, "ana menüde Yapboz kartı yok")
	if index < 0:
		return
	var card: Control = menu._kartlar[index]
	menu._konum = clampf(card.position.y - 40.0, 0.0, menu._en_fazla)
	await _frames(30)
	await _shot("00_menu")
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
	for level in total:
		if level == 1:
			await _transition_grab()
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		_check_level_start(level)
		await _frames(20)
		await _shot("%02d_basla" % (level + 1))
		if level == 0:
			await _drop_nowhere()
			await _drop_wrong()
			await _second_finger()
		await _solve(level)
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "baştan oyna 1. bölümü açmadı (%d)" % (game.level_index + 1))


func _check_level_start(level: int) -> void:
	var data: Dictionary = Settings.LEVELS[level]
	var count := int(data["cols"]) * int(data["rows"])
	_check(game.pieces.size() == count, "%d. bölüm: %d parça bekleniyordu, %d" % [level + 1, count, game.pieces.size()])
	var screen: Vector2 = game.get_viewport_rect().size
	var board: Rect2 = game.layout.board
	for piece in game.pieces:
		_check(Rect2(Vector2.ZERO, screen).grow(-20.0).has_point(piece.global_position), "%d. bölüm: parça ekranın dışında (%s)" % [level + 1, piece.global_position])
		_check(not board.has_point(piece.global_position), "%d. bölüm: tepsideki parça tahtanın üstünde (%s)" % [level + 1, piece.global_position])


# Parmağın bırakılacağı nokta: parça parmağın biraz üstünde durduğu için hedefin o kadar altı
func _drop_point(target: Vector2) -> Vector2:
	return target + Vector2(0.0, game.drag_input.lift)


# Boş bir yere (tahtanın köşesine, parçanın yerinden uzağa) bırakılan parça tepsiye döner
func _drop_nowhere() -> void:
	var piece = game.pieces[0]
	var board: Rect2 = game.layout.board
	var corner := board.position + board.size * 0.1 if piece.target.distance_to(board.position) > board.size.x * 0.4 else board.end - board.size * 0.1
	await _drag(piece.global_position, _drop_point(corner), 0)
	await _frames(45)
	_check(not piece.placed and piece.position.distance_to(piece.home) < 2.0, "boşluğa bırakılan parça tepsiye dönmedi")


# Başka parçanın yerine bırakılan parça oturmaz, tepsiye döner
func _drop_wrong() -> void:
	var piece = game.pieces[0]
	var other = game.pieces[game.pieces.size() - 1]
	await _drag(piece.global_position, _drop_point(other.target), 0)
	await _frames(8)
	await _shot("01b_yanlis")
	await _frames(40)
	_check(not piece.placed, "parça başka parçanın yerine oturdu")
	_check(piece.position.distance_to(piece.home) < 2.0, "yanlış yere bırakılan parça tepsiye dönmedi")


# Birinci parmak parça tutarken ikinci parmak başka parçayı tutamaz
func _second_finger() -> void:
	var first = game.pieces[0]
	var second = game.pieces[1]
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


# Bütün parçaları yerine sürükler; ilk bölümde oturan parçanın tutulamadığını da dener
func _solve(level: int) -> void:
	var half: int = game.pieces.size() / 2
	for k in game.pieces.size():
		var piece = game.pieces[k]
		if piece.placed:
			continue
		var from: Vector2 = piece.global_position
		if k == half:
			# Sürüklerken ekran görüntüsü (parça tutulu, tahtanın ortasında)
			_touch(from, true, 0)
			await _frames(2)
			for s in range(1, 7):
				_drag_event(from.lerp(_drop_point(piece.target), s / 10.0), 0)
				await _frames(2)
			await _frames(10)
			await _shot("%02d_surukle" % (level + 1))
			_touch(from.lerp(_drop_point(piece.target), 0.6), false, 0)
			await _frames(40)
			from = piece.global_position
		await _drag(from, _drop_point(piece.target), 0)
		await _frames(20)
		_check(piece.placed and piece.position.distance_to(piece.target) < 2.0, "%d. bölüm: parça %d yerine oturmadı" % [level + 1, k])
		if level == 0 and k == 0:
			await _drag(piece.global_position, piece.global_position + Vector2(0, 200), 0)
			await _frames(10)
			_check(piece.position.distance_to(piece.target) < 2.0 and not piece.dragging, "oturan parça tutuldu")


func _wait_level_end(level: int) -> void:
	for k in 600:
		await process_frame
		if game.state == game.State.CELEBRATING:
			break
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: parçalar bitince kutlama başlamadı" % (level + 1))
	await _frames(80)
	await _shot("%02d_bitti" % (level + 1))
	if level < Settings.level_count() - 1:
		for k in 1200:
			await process_frame
			if game.level_index == level + 1:
				break
		_check(game.level_index == level + 1, "%d. bölümden sonra sonraki bölüm gelmedi" % (level + 1))
		var config := ConfigFile.new()
		_check(config.load(SAVE) == OK and int(config.get_value("ilerleme", "bolum", -1)) == level + 1,
			"%d. bölümden sonra ilerleme kaydedilmedi" % (level + 1))


# Bölüm gelirken (resim gösterilirken, parçalar dağılırken) parça tutulamaz
func _transition_grab() -> void:
	for k in 1200:
		if game.level_index == 1 and game.board != null and not game.pieces.is_empty():
			break
		await process_frame
	_check(game.state != game.State.PLAYING, "geçiş beklenirken bölüm hemen oynanabilir oldu")
	await _shot("02a_resim")
	var piece = game.pieces[0]
	_touch(piece.target, true, 0)
	await _frames(3)
	_check(not piece.dragging, "geçişte parça tutuldu")
	_touch(piece.target, false, 0)


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
	await _shot("99_final")
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
