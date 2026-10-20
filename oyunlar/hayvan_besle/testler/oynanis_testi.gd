extends SceneTree
# Hayvanları Besle oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/hayvan_besle/testler/oynanis_testi.gd -- <klasör>
# Ana menüden karta dokunup oyunu açar (ekran yatay olmalı) ve 12 bölümü sürükleyerek oynar. Denetler:
#   - masadaki yiyecek sayısı isteklerle tutuyor, balon kuralı (1-6 görünür, 7-12 gizli), çeldirici sadece 10-12'de;
#   - boşluğa bırakılan yiyecek sessizce döner, yanlış (ya da doymuş) hayvan reddeder ve yiyecek döner;
#   - sürüklerken doğru hayvan heyecanlanır, diğerleri heyecanlanmaz;
#   - ikinci parmak tutulan yiyeceği bozmaz, başka yiyecek tutamaz;
#   - doğru yiyecekler art arda verilince (hayvan yerken bile) noktalar dolar, hayvan doyar;
#   - gizli balon: hayvana dokununca ve boşta kalınca belirir, sonra kaybolur;
#   - hepsi doyunca bölüm ilerler, çeldirici kaybolur, bölüm geçişinde dokunma yok sayılır;
#   - 12. bölümden sonra 1. bölüme dönülür; basılı geri düğmesiyle menüye dönülür.
# <klasör> içine ekran görüntüleri kaydeder. Kullanıcının kayıtları (oyun ve menü) yedeklenip geri yazılır.

const GAME_SCENE := "res://oyunlar/hayvan_besle/hayvan_besle.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVES := ["user://hayvan_besle.cfg", "user://ana_menu.cfg"]

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
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	_bitmisti = OyunBitti.tamamlandi_mi("hayvan_besle")
	OyunBitti.sifirla("hayvan_besle")
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
		OyunBitti.tamamla("hayvan_besle")
	else:
		OyunBitti.sifirla("hayvan_besle")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("hayvan_besle oynanis_testi: TAMAM")
	else:
		printerr("hayvan_besle oynanis_testi: %d hata" % _fails)
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
	_check(index >= 0, "ana menüde Hayvanları Besle kartı yok")
	if index < 0:
		return
	# Liste kart görünecek kadar kaydırılır (yeni oyunlar eklendikçe kart ortalarda kalabilir), sonra karta dokunulur
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
	var total: int = game.settings.level_count()
	_check(total == 12, "12 bölüm olmalı, %d" % total)
	for level in total:
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		var plan = game.plan
		await _frames(30)
		_check_level_start(level, plan)
		if level == 0:
			await _shot("01_bolum1")
			await _empty_drop()
			await _wrong_drop()
			await _excitement()
			await _second_finger()
		if level == 6:
			await _hidden_bubble()
		if level == 9:
			await _shot("03_bolum10")
		await _feed_all(level)
		if level == 0:
			await _shot("02_doydu")
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "son bölümden sonra 1. bölüme dönülmedi (%d)" % (game.level_index + 1))
	_check(game.stars.current == 0, "yeni turda yıldızlar sıfırlanmadı")


func _check_level_start(level: int, plan) -> void:
	var tag := "%d. bölüm" % (level + 1)
	var expected_animals: int = [2, 3, 3, 4][level / 3]
	_check(game.animals.size() == expected_animals, "%s: %d hayvan, olması gereken %d" % [tag, game.animals.size(), expected_animals])
	var wanted := 0
	for c in plan.counts:
		wanted += c
	var on_table := 0
	for food in game.foods:
		if is_instance_valid(food) and not food.eaten:
			on_table += 1
	_check(on_table == wanted + plan.distractors.size(), "%s: masada %d yiyecek, olması gereken %d" % [tag, on_table, wanted + plan.distractors.size()])
	_check(plan.distractors.size() == (1 if level >= 9 else 0), "%s: çeldirici sayısı %d" % [tag, plan.distractors.size()])
	var always := level < 6
	_check(plan.bubble_always == always, "%s: balon ayarı yanlış" % tag)
	for animal in game.animals:
		_check(animal.bubble.shown == always, "%s: %s balonu %s olmalı" % [tag, animal.data.id, "görünür" if always else "gizli"])
		if always:
			_check(animal.bubble.count == animal.want_count, "%s: balon nokta sayısı yanlış" % tag)


func _empty_drop() -> void:
	var food = _free_food_for(game.animals[0])
	var home: Vector2 = food.home
	var screen: Vector2 = game.get_viewport_rect().size
	await _drag_food(food, Vector2(screen.x / 2.0, 150.0))
	await _frames(45)
	_check(not food.eaten and food.position.distance_to(home) < 3.0, "boşluğa bırakılan yiyecek yerine dönmedi")
	for animal in game.animals:
		_check(animal.eaten == 0 and animal.refuse_amount == 0.0, "boşluğa bırakınca %s tepki verdi" % animal.data.id)


func _wrong_drop() -> void:
	var owner = game.animals[0]
	var other = game.animals[1]
	var food = _free_food_for(owner)
	await _drag_food(food, _drop_target(other), false)
	await _frames(3)
	_check(other.refuse_amount > 0.0, "yanlış hayvan reddetmedi")
	await _shot("01b_ret")
	await _frames(45)
	_check(not food.eaten and food.position.distance_to(food.home) < 3.0, "yanlış hayvana bırakılan yiyecek yerine dönmedi")
	_check(other.eaten == 0, "yanlış hayvan yiyeceği yedi")


# Sürüklerken doğru hayvan heyecanlanır (gözleri büyür, ağzı açılır), diğeri heyecanlanmaz
func _excitement() -> void:
	var owner = game.animals[0]
	var other = game.animals[1]
	var food = _free_food_for(owner)
	var lift: float = game.drag_input.lift
	var target: Vector2 = _drop_target(owner) + Vector2(0, lift + owner.size * 0.35)
	_touch(food.position, true, 0)
	await _frames(2)
	for k in range(1, 11):
		_drag_event(food.position.lerp(target, k / 10.0), 0)
		await _frames(2)
	await _frames(20)
	_check(owner.is_excited() and owner.face().mouth_open > 0.3, "doğru hayvan heyecanlanmadı")
	_check(not other.is_excited(), "yanlış hayvan heyecanlandı")
	_check(other.face().look.x < 0.0, "diğer hayvan yiyeceğe bakmıyor (%s)" % other.face().look)
	await _shot("01c_heyecan")
	# Boşluğa götürüp bırak
	var screen: Vector2 = game.get_viewport_rect().size
	for k in 6:
		_drag_event(Vector2(screen.x / 2.0, 150.0 + lift), 0)
		await _frames(2)
	_touch(Vector2(screen.x / 2.0, 150.0 + lift), false, 0)
	await _frames(40)
	_check(not owner.is_excited(), "bırakınca heyecan geçmedi")


func _second_finger() -> void:
	var owner = game.animals[0]
	var food = _free_food_for(owner)
	var other_food = _free_food_for(game.animals[1])
	var other_home: Vector2 = other_food.home
	_touch(food.position, true, 0)
	await _frames(2)
	_touch(other_food.position, true, 1)
	_drag_event(other_food.position + Vector2(0, -250), 1)
	await _frames(10)
	_check(not other_food.dragging and other_food.position.distance_to(other_home) < 3.0, "ikinci parmak başka yiyecek sürükledi")
	_touch(other_food.position + Vector2(0, -250), false, 1)
	await _frames(2)
	_check(food.dragging, "ikinci parmak kalkınca tutulan yiyecek bırakıldı")
	_touch(food.position, false, 0)
	await _frames(40)


# 7. bölüm: balon gizli; hayvana dokununca ve boşta kalınca kısa süre belirir
func _hidden_bubble() -> void:
	var animal = game.animals[0]
	_check(not animal.bubble.shown, "gizli balon görünüyor")
	_tap(_drop_target(animal))
	await _frames(10)
	_check(animal.bubble.shown, "hayvana dokununca balon belirmedi")
	await _shot("04_dokununca_balon")
	await _frames(int((game.bubble_hint_time + 0.8) * 60))
	_check(not animal.bubble.shown, "balon kısa süre sonra kaybolmadı")
	# Dokunuştan hint_delay saniye sonra (hiçbir şey yapılmadan) bütün aç hayvanların balonları belirir
	var all_shown := false
	for k in int(game.hint_delay * 60) + 60:
		await process_frame
		if game.animals.all(func(a) -> bool: return a.bubble.shown):
			all_shown = true
			break
	_check(all_shown, "boşta kalınca balonlar belirmedi")
	_check(game.idle_time < 1.0, "ipucu bekleme süresi sıfırlanmadı")
	await _frames(int((game.bubble_hint_time + 0.8) * 60))


# Her hayvana istediği kadar yiyecek, art arda (hayvan yerken bile) verilir
func _feed_all(level: int) -> void:
	for animal in game.animals:
		var count: int = animal.want_count
		for i in count:
			var food = _free_food_for(animal)
			_check(food != null, "%d. bölüm: %s için yiyecek kalmadı" % [level + 1, animal.data.id])
			if food == null:
				break
			await _drag_food(food, _drop_target(animal))
			await _frames(4)
			_check(food.eaten, "%d. bölüm: %s doğru yiyeceği almadı" % [level + 1, animal.data.id])
			if level == 0 and animal == game.animals[0]:
				await _frames(20)
				await _shot("01d_yiyor")
	# Hepsi yiyip doyana kadar
	for k in 600:
		await process_frame
		if game.animals.all(func(a) -> bool: return a.is_full()):
			break
	for animal in game.animals:
		_check(animal.is_full() and animal.eaten == animal.want_count, "%d. bölüm: %s doymadı (%d/%d)" % [level + 1, animal.data.id, animal.eaten, animal.want_count])
		_check(animal.bubble.filled == animal.want_count, "%d. bölüm: %s balonunda noktalar dolmadı" % [level + 1, animal.data.id])
	# Doymuş hayvan kibarca reddeder (bölüm bitmeden hemen önce, çeldirici varsa onunla)
	if level == 9:
		var extra = _distractor()
		_check(extra != null, "10. bölümde çeldirici masada yok")


func _wait_level_end(level: int) -> void:
	# Kutlama sırasında çeldirici kaybolur, sonra geçişte dokunma yok sayılır
	for k in 240:
		await process_frame
		if game.state == game.State.TRANSITION:
			break
	if level == 9:
		_check(_distractor() == null, "10. bölüm: kutlamada çeldirici kaybolmadı")
	if level == 11:
		await _shot("05_final")
		for k in int(game.finale_time * 60) - 30:
			await process_frame
			if game.state == game.State.TRANSITION:
				break
	_check(game.state == game.State.TRANSITION, "%d. bölüm: hepsi doyunca bölüm geçişi başlamadı" % (level + 1))
	# Geçişte dokunma yok sayılır
	var screen: Vector2 = game.get_viewport_rect().size
	_touch(Vector2(screen.x / 2.0, screen.y - 80.0), true, 0)
	await _frames(2)
	_check(game.drag_input.dragged == null, "bölüm geçişinde yiyecek tutulabildi")
	_touch(Vector2(screen.x / 2.0, screen.y - 80.0), false, 0)


func _back_to_menu() -> void:
	await _wait_playing()
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_touch(center, true, 0)
	await _frames(int(game.hold_to_exit * 60) + 20)
	_touch(center, false, 0)
	for k in 300:
		await process_frame
		if current_scene and current_scene.scene_file_path == MENU_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "basılı geri düğmesiyle menüye dönülmedi")


# --- Yardımcılar ---

func _free_food_for(animal):
	for food in game.foods:
		if is_instance_valid(food) and food.can_grab() and animal.accepts(food.data):
			return food
	return null


func _distractor():
	for food in game.foods:
		if is_instance_valid(food) and game.plan.distractors.has(food.data):
			return food
	return null


# Hayvanın bırakma alanının ortası (gövde ile başın arası)
func _drop_target(animal) -> Vector2:
	return animal.global_position + Vector2(0, -(246.0 - 150.0) / 256.0 * animal.size)


# Yiyeceği tutup hedefe götürür; bırakma noktası (parmağın biraz üstü) hedefe gelir
func _drag_food(food, target: Vector2, release: bool = true) -> void:
	var lift: float = game.drag_input.lift
	var start: Vector2 = food.position
	var finger := target + Vector2(0, lift)
	_touch(start, true, 0)
	await _frames(2)
	for k in range(1, 9):
		_drag_event(start.lerp(finger, k / 8.0), 0)
		await _frames(2)
	await _frames(6)
	_touch(finger, false, 0)
	if release:
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
	for satir: Array in ekran._dugmeler:
		if satir[1] == "bastan":
			for basili in [true, false]:
				var olay := InputEventScreenTouch.new()
				olay.position = (satir[0] as Control).get_global_rect().get_center()
				olay.pressed = basili
				root.push_input(olay, true)
