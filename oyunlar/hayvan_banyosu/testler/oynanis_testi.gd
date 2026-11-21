extends SceneTree
# Hayvan Banyosu oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/hayvan_banyosu/testler/oynanis_testi.gd -- <klasör>
# Ana menüden karta dokunup oyunu açar (ekran yatay olmalı) ve 10 bölümü sürterek oynar. Denetler:
#   - her bölümde ayarlar.gd'deki kadar leke var, hepsi suyun üstünde ve ekranın içinde;
#   - boşluğa sürtmek lekeleri değiştirmez; ikinci parmak alet olmaz, leke temizlemez;
#   - bölüm geçişinde (hayvan gelirken) sürtmek bir şey yapmaz;
#   - her adımda yalnızca o adımın aleti etki eder: çamur → köpük → ıslak → temiz; adım bitince alet değişir;
#   - duş parmak dururken de akar (köpük söner);
#   - bölüm bitince sonraki hayvan gelir ve ilerleme kaydedilir; 10. bölümden sonra final ekranı (OyunBitti),
#     "baştan oyna" 1. bölümü açar; çift dokunuşlu geri düğmesiyle menüye dönülür.
# <klasör> içine ekran görüntüleri kaydeder. Kullanıcının kayıtları yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/hayvan_banyosu/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/hayvan_banyosu/hayvan_banyosu.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://hayvan_banyosu.cfg"
const SAVES := ["user://hayvan_banyosu.cfg", "user://hayvan_banyosu.cfg.bak", "user://ana_menu.cfg", "user://ana_menu.cfg.bak",
	"user://ipucu_eli.cfg"]

var _bitmisti := false             # oyun bu testten önce tamamlanmış mıydı (OyunBitti)
var out := ""
var game: Node
var _fails := 0
var _backups := {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	_bitmisti = OyunBitti.tamamlandi_mi("hayvan_banyosu")
	OyunBitti.sifirla("hayvan_banyosu")
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
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
		OyunBitti.tamamla("hayvan_banyosu")
	else:
		OyunBitti.sifirla("hayvan_banyosu")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("hayvan_banyosu oynanis_testi: TAMAM")
	else:
		printerr("hayvan_banyosu oynanis_testi: %d hata" % _fails)
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
	_check(index >= 0, "ana menüde Hayvan Banyosu kartı yok")
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


# --- Oynanış ---

func _play_all() -> void:
	var total := Settings.level_count()
	_check(total == 10, "10 bölüm olmalı, %d" % total)
	for level in total:
		if level == 1:
			await _transition_rub()
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		_check_level_start(level)
		if level == 0:
			await _shot("01_bolum1")
			await _empty_rub()
			await _second_finger()
		await _wash(level)
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "baştan oyna 1. bölümü açmadı (%d)" % (game.level_index + 1))


func _check_level_start(level: int) -> void:
	var spots: Array = game.animal.spots
	_check(spots.size() == Settings.SPOTS[level], "%d. bölüm: %d leke bekleniyordu, %d" % [level + 1, Settings.SPOTS[level], spots.size()])
	var screen: Vector2 = game.get_viewport_rect().size
	for spot in spots:
		var p: Vector2 = spot.global_position
		_check(spot.state == 0 and is_equal_approx(spot.amount, 1.0), "%d. bölüm: leke başta çamur değil" % (level + 1))
		_check(p.y < game.water.y, "%d. bölüm: leke suyun altında (%s)" % [level + 1, p])
		_check(Rect2(Vector2.ZERO, screen).grow(-20.0).has_point(p), "%d. bölüm: leke ekranın dışında (%s)" % [level + 1, p])


# Hayvandan uzakta sürtmek hiçbir lekeyi değiştirmez
func _empty_rub() -> void:
	var far := Vector2(160.0, 420.0)
	_check(not game.animal.contains(far), "boş sürtme noktası hayvanın üstünde")
	await _rub_at(far, 0, 40)
	for spot in game.animal.spots:
		_check(spot.state == 0 and is_equal_approx(spot.amount, 1.0), "boşluğa sürtünce leke değişti")


# Birinci parmak boşta dururken ikinci parmak lekenin üstünde sürtse de bir şey olmaz
func _second_finger() -> void:
	var spot = game.animal.spots[0]
	_touch(Vector2(160.0, 420.0), true, 0)
	await _frames(2)
	await _rub_at(spot.global_position, 1, 30)
	_touch(Vector2(160.0, 420.0), false, 0)
	await _frames(4)
	_check(spot.state == 0 and is_equal_approx(spot.amount, 1.0), "ikinci parmak lekeyi temizledi")
	_check(not game.tool.active, "parmaklar kalkınca alet kaybolmadı")


# Önceki bölüm biterken (sonraki hayvan gelirken) sürtmek bir şey yapmaz
func _transition_rub() -> void:
	for k in 900:
		if game.level_index == 1 and game.animal != null:
			break
		await process_frame
	_check(game.state != game.State.PLAYING, "geçiş beklenirken bölüm hemen oynanabilir oldu")
	var spots: Array = game.animal.spots
	await _rub_at(spots[0].global_position, 0, 10)
	for spot in spots:
		_check(spot.state == 0 and is_equal_approx(spot.amount, 1.0), "geçişte sürtünce leke değişti")


# Üç adımı sırayla bitirir: her adımda bu adımın lekelerini sürter, sonra alet değişir
func _wash(level: int) -> void:
	for step in 3:
		_check(game.step == step, "%d. bölüm: %d. adım bekleniyordu, %d" % [level + 1, step + 1, game.step + 1])
		_check(game.tool.kind == step, "%d. bölüm: alet adımla aynı değil" % (level + 1))
		if level == 0 and step == 1:
			await _shower_still()
		for k in 20:
			var spot = _next_spot(step)
			if spot == null:
				break
			await _rub_at(spot.global_position, 0, 40, spot, step)
		for spot in game.animal.spots:
			_check(spot.state > step, "%d. bölüm %d. adım: leke bitmedi (durum %d)" % [level + 1, step + 1, spot.state])
		if level == 0:
			await _shot("02_adim%d" % (step + 1))
		if step < 2:
			await _frames(40)              # alet değişirken kısa bekleme


# Duşu bir lekenin üstünde hareket ettirmeden tutmak da köpüğü söndürür
func _shower_still() -> void:
	var spot = _next_spot(1)
	_touch(spot.global_position, true, 0)
	for k in 150:
		await process_frame
		if spot.state != 1:
			break
	_touch(spot.global_position, false, 0)
	await _frames(4)
	_check(spot.state == 2, "duş dururken akmadı (leke durumu %d)" % spot.state)


func _next_spot(step: int):
	if game.animal == null:
		return null
	for spot in game.animal.spots:
		if spot.needs(step):
			return spot
	return null


func _wait_level_end(level: int) -> void:
	for k in 900:
		await process_frame
		if game.state == game.State.CELEBRATING:
			break
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: üç adım bitince kutlama başlamadı" % (level + 1))
	if level == 0:
		await _frames(50)
		await _shot("03_silkinme")
	if level < Settings.level_count() - 1:
		for k in 900:
			await process_frame
			if game.level_index == level + 1:
				break
		_check(game.level_index == level + 1, "%d. bölümden sonra sonraki bölüm gelmedi" % (level + 1))
		var config := ConfigFile.new()
		_check(config.load(SAVE) == OK and int(config.get_value("ilerleme", "bolum", -1)) == level + 1,
			"%d. bölümden sonra ilerleme kaydedilmedi" % (level + 1))


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


# --- Yardımcılar ---

# Noktanın çevresinde sağa sola sürter. spot verilirse o leke bu adımı bitirince durur.
func _rub_at(point: Vector2, index: int, moves: int, spot = null, step: int = -1) -> void:
	_touch(point, true, index)
	await _frames(2)
	for k in moves:
		_drag_event(point + Vector2(36.0 if k % 2 == 0 else -36.0, 0.0), index)
		await _frames(2)
		if spot != null and (not is_instance_valid(spot) or not spot.needs(step)):
			break
	_touch(point, false, index)
	await _frames(2)


func _wait_playing() -> void:
	for k in 900:
		await process_frame
		if game.state == game.State.PLAYING and not game._step_busy:
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


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
	await _shot("04_final")
	for satir: Array in ekran._dugmeler:
		if satir[1] == "bastan":
			for basili in [true, false]:
				var olay := InputEventScreenTouch.new()
				olay.position = (satir[0] as Control).get_global_rect().get_center()
				olay.pressed = basili
				root.push_input(olay, true)
