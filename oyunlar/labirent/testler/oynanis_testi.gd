extends SceneTree
# Labirent oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/labirent/testler/oynanis_testi.gd -- <klasör>
# Oyunu ana menüdeki kartından açar (kart yoksa doğrudan) ve bütün bölümleri oynar. Denetler:
#   - tahta tasarım alanının içinde; hayvan başlangıçta, yemek yerinde;
#   - geçişte (tahta belirirken) hayvana dokunup sürüklemek onu yürütmez;
#   - hayvandan uzağa dokunup sürüklemek onu yürütmez; ikinci parmak sürükleyemez;
#   - hayvanı duvarın arkasına çekince duvardan geçmez (duvara değdi bilgisi gelir);
#   - tek ve çift sayılı bölümler parmağı yol boyunca yavaş, öbürleri hızlı gezdirerek (hayvan geride kalınca
#     parmak bekler) biter; hayvan hiçbir karede yol ağının dışına çıkmaz, yoldaki yıldızlar toplanır;
#   - yemeğe varınca kutlama, sonra sonraki bölüm gelir ve ilerleme kaydedilir; son bölümden sonra final
#     ekranı (OyunBitti), "baştan oyna" 1. bölümü açar; çift dokunuşlu geri düğmesiyle menüye dönülür.
# <klasör> içine her bölümün (başında, sürüklerken, bitişinde) ekran görüntüsünü kaydeder. Kullanıcının
# kayıtları yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/labirent/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/labirent/labirent.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://labirent.cfg"
const SAVES := ["user://labirent.cfg", "user://labirent.cfg.bak", "user://ana_menu.cfg", "user://ana_menu.cfg.bak",
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
	for problem in Settings.problems():
		_check(false, "ayarlar: " + problem)
	_bitmisti = OyunBitti.tamamlandi_mi("labirent")
	OyunBitti.sifirla("labirent")
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
		OyunBitti.tamamla("labirent")
	else:
		OyunBitti.sifirla("labirent")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("labirent oynanis_testi: TAMAM")
	else:
		printerr("labirent oynanis_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Açılış ---

# Ana menüde oyunun kartına dokunup açar; kart henüz yoksa (oyun menüye eklenmeden önce) doğrudan açar
func _open() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(90)
	var index := -1
	for k in menu.OYUNLAR.size():
		if menu.OYUNLAR[k]["sahne"] == GAME_SCENE:
			index = k
	if index >= 0:
		var card: Control = menu._kartlar[index]
		menu._konum = clampf(card.position.y - 40.0, 0.0, menu._en_fazla)
		await _frames(30)
		await _shot("00_menu")
		_tap(card.get_global_rect().get_center())
	else:
		print("Not: ana menüde kart yok, oyun doğrudan açılıyor")
		root.get_node("SahneGecis").sahne_degistir(GAME_SCENE)
	for k in 400:
		await process_frame
		if current_scene and current_scene.scene_file_path == GAME_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == GAME_SCENE, "oyun açılmadı")
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
			await _transition_tap()
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		_check_level_start(level)
		await _frames(20)
		await _shot("%02d_basla" % (level + 1))
		if level == 0:
			await _far_touch()
			await _second_finger()
			await _wall()
		await _walk(level, level % 3 != 2)
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "baştan oyna 1. bölümü açmadı (%d)" % (game.level_index + 1))


func _check_level_start(level: int) -> void:
	var map := Settings.map_of(level)
	var board = game.board
	var area := EkranYardimcisi.tasarim_alani()
	_check(area.grow(0.5).encloses(board.board_rect()), "%d. bölüm: tahta tasarım alanının dışında (%s)" % [level + 1, board.board_rect()])
	_check(game.walker.from_cell == Settings.find_cell(map, "S") and game.walker.t == 0.0, "%d. bölüm: hayvan başlangıçta değil" % (level + 1))
	_check(board.food.position.distance_to(board.cell_center(Settings.find_cell(map, "Y"))) < 1.0, "%d. bölüm: yemek yerinde değil" % (level + 1))
	_check(board.stars.size() == Settings.cells_with(map, "*").size(), "%d. bölüm: yıldız sayısı tutmuyor" % (level + 1))
	_check(board.cell >= 100.0, "%d. bölüm: hücre küçük (%.0f)" % [level + 1, board.cell])


# Hayvandan uzağa basıp sürüklemek onu yürütmez
func _far_touch() -> void:
	var start: Vector2 = game.walker.position()
	var far: Vector2 = game.board.cell_center(Settings.find_cell(game.board.map, "Y"))
	_touch(far, true, 0)
	await _frames(2)
	_drag_event(start + Vector2(game.walker.cell, 0), 0)
	await _frames(20)
	_check(not game.dragging and game.walker.position() == start, "hayvandan uzağa dokununca hayvan yürüdü")
	_touch(start, false, 0)
	await _frames(3)


# Birinci parmak boş bir yerde basılıyken ikinci parmak hayvanı sürükleyemez
func _second_finger() -> void:
	var start: Vector2 = game.walker.position()
	var far: Vector2 = game.board.cell_center(Settings.find_cell(game.board.map, "Y"))
	_touch(far, true, 0)
	await _frames(2)
	_touch(start, true, 1)
	_drag_event(start + Vector2(game.walker.cell, 0), 1)
	await _frames(20)
	_check(not game.dragging and game.walker.position() == start, "ikinci parmak hayvanı sürükledi")
	_touch(start, false, 1)
	_touch(far, false, 0)
	await _frames(3)


# Hayvanı duvarla ayrılmış komşu hücreye çekmek: hayvan geçmez, duvara değdi bilgisi gelir
func _wall() -> void:
	var map: PackedStringArray = game.board.map
	var start := Settings.find_cell(map, "S")
	var blocked := Vector2i(-1, -1)
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
		var n: Vector2i = start + d
		var size := Settings.grid_size(map)
		if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not Settings.is_open(map, start, n):
			blocked = n
			break
	_check(blocked != Vector2i(-1, -1), "1. bölüm: başlangıcın yanında duvar yok (test için gerekli)")
	if blocked == Vector2i(-1, -1):
		return
	var from: Vector2 = game.walker.position()
	var to: Vector2 = game.board.cell_center(blocked)
	_touch(from, true, 0)
	await _frames(2)
	_check(game.dragging, "hayvana dokununca tutulmadı")
	for s in range(1, 11):
		_drag_event(from.lerp(to, s / 10.0), 0)
		await _frames(2)
	await _frames(10)
	await _shot("01b_duvar")
	_check(game.walker.nearest_cell() == start, "hayvan duvardan geçti")
	_check(game.bumped, "duvara değdi bilgisi gelmedi")
	_touch(to, false, 0)
	await _frames(3)
	_check(not game.dragging, "parmak kalkınca hayvan bırakılmadı")


# Hayvanı tutar, parmağı yemeğe giden yol boyunca gezdirir. Yavaşta parmak saniyede ~4 hücre, hızlıda ~15 hücre
# gider; hızlıda hayvan 1,4 hücreden fazla geride kalırsa parmak bekler (çocuk hayvana bakar).
func _walk(level: int, slow: bool) -> void:
	var map: PackedStringArray = game.board.map
	var path := Settings.solution(map, Settings.find_cell(map, "S"), Settings.find_cell(map, "Y"))
	var on_path := 0
	for star in Settings.cells_with(map, "*"):
		if path.has(star):
			on_path += 1
	var stars_before: int = game.board.stars.size()
	var cell: float = game.walker.cell
	var finger: Vector2 = game.walker.position()
	_touch(finger, true, 0)
	await _frames(2)
	_check(game.dragging, "%d. bölüm: hayvan tutulmadı" % (level + 1))
	var speed := cell * (4.0 if slow else 15.0) / 60.0
	var shot := false
	for i in range(1, path.size()):
		var target: Vector2 = game.board.cell_center(path[i])
		while finger.distance_to(target) > 0.5 and game.state == game.State.PLAYING:
			if slow or game.walker.position().distance_to(finger) < cell * 1.4:
				finger = finger.move_toward(target, speed)
				_drag_event(finger, 0)
			await _frames(1)
			_check(_on_network(), "%d. bölüm: hayvan yol ağının dışında" % (level + 1))
			if not shot and i >= path.size() / 2:
				shot = true
				await _shot("%02d_surukle" % (level + 1))
	for k in 120:
		if game.state != game.State.PLAYING:
			break
		await _frames(1)
	_touch(finger, false, 0)
	await _frames(2)
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: hayvan yemeğe varmadı (%s)" % [level + 1, game.walker.from_cell])
	_check(stars_before - game.board.stars.size() >= on_path, "%d. bölüm: yoldaki yıldızlar toplanmadı" % (level + 1))


func _on_network() -> bool:
	var walker = game.walker
	return walker.t == 0.0 or Settings.is_open(walker.map, walker.from_cell, walker.to_cell)


func _wait_level_end(level: int) -> void:
	for k in 600:
		await process_frame
		if game.state == game.State.CELEBRATING:
			break
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: yemeğe varınca kutlama başlamadı" % (level + 1))
	await _frames(70)
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


# Tahta belirirken hayvana dokunup sürüklemek onu yürütmez
func _transition_tap() -> void:
	for k in 1200:
		if game.level_index == 1 and game.board != null and game.board.animal_name == Settings.animal_of(1):
			break
		await process_frame
	_check(game.state != game.State.PLAYING, "geçiş beklenirken bölüm hemen oynanabilir oldu")
	await _frames(10)
	await _shot("02a_belir")
	var start: Vector2 = game.walker.position()
	_touch(start, true, 0)
	_drag_event(start + Vector2(game.walker.cell, 0), 0)
	await _frames(3)
	_check(not game.dragging and game.walker.position() == start, "geçişte hayvan sürüklendi")
	_touch(start, false, 0)


func _back_to_menu() -> void:
	await _wait_playing()
	var start: Vector2 = game.walker.position()
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(center)
	await _frames(30)
	_check(current_scene.scene_file_path == GAME_SCENE, "geri düğmesine tek dokunuş oyundan çıkardı")
	_check(game.walker.position() == start, "geri düğmesine dokunmak hayvanı yürüttü")
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
