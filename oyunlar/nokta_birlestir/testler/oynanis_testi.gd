extends SceneTree
# Noktaları Birleştir oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/nokta_birlestir/testler/oynanis_testi.gd -- <klasör>
# Oyunu ana menüdeki kartından açar (kart yoksa doğrudan) ve bütün bölümleri oynar. Denetler:
#   - her bölümde nokta sayısı noktalar.json kadar; noktalar ekranın ve tasarım alanının içinde, birbirinden uzak;
#   - geçişte (noktalar belirirken) dokunulan nokta bağlanmaz;
#   - sırası gelmeyen noktaya dokununca bağlanmaz; ikinci parmak çizemez;
#   - 1. bölüm noktalara tek tek dokunarak, 2. bölüm tek bir yavaş kaydırmayla, sonrakiler boş bir yerden
#     başlayıp noktadan noktaya hızlı (büyük adımlı) kaydırmayla biter;
#   - son nokta bağlanınca kutlama, sonra sonraki bölüm gelir ve ilerleme kaydedilir; son bölümden sonra final
#     ekranı (OyunBitti), "baştan oyna" 1. bölümü açar; çift dokunuşlu geri düğmesiyle menüye dönülür.
# <klasör> içine her bölümün (başında, çizerken, bitişinde) ekran görüntüsünü kaydeder. Kullanıcının
# kayıtları yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/nokta_birlestir/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/nokta_birlestir/nokta_birlestir.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://nokta_birlestir.cfg"
const SAVES := ["user://nokta_birlestir.cfg", "user://nokta_birlestir.cfg.bak", "user://ana_menu.cfg", "user://ana_menu.cfg.bak",
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
	_bitmisti = OyunBitti.tamamlandi_mi("nokta_birlestir")
	OyunBitti.sifirla("nokta_birlestir")
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
		OyunBitti.tamamla("nokta_birlestir")
	else:
		OyunBitti.sifirla("nokta_birlestir")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("nokta_birlestir oynanis_testi: TAMAM")
	else:
		printerr("nokta_birlestir oynanis_testi: %d hata" % _fails)
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
			await _wrong_dot()
			await _tap_all(level)
		elif level == 1:
			await _slow_swipe(level)
		else:
			await _fast_swipe(level)
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "baştan oyna 1. bölümü açmadı (%d)" % (game.level_index + 1))


func _check_level_start(level: int) -> void:
	var picture := Settings.picture_of(level)
	var page = game.page
	_check(page.count() == Settings.dots_of(picture).size(), "%d. bölüm: nokta sayısı tutmuyor" % (level + 1))
	_check(page.done == 0, "%d. bölüm: bölüm başında bağlı nokta var" % (level + 1))
	var area := EkranYardimcisi.tasarim_alani()
	for i in page.count():
		var p: Vector2 = page.dots[i]
		_check(area.grow(-Settings.DOT_RADIUS).has_point(p), "%d. bölüm: %d. nokta tasarım alanının dışında (%s)" % [level + 1, i + 1, p])
		for j in range(i + 1, page.count()):
			_check(p.distance_to(page.dots[j]) >= Settings.MIN_DOT_GAP, "%d. bölüm: %d ve %d. noktalar çok yakın" % [level + 1, i + 1, j + 1])
	_check(page.touch_radius * 2.0 >= 110.0, "%d. bölüm: dokunma alanı küçük (%.0f)" % [level + 1, page.touch_radius * 2.0])


# Sırası gelmeyen noktaya dokunmak bir şey bağlamaz; ikinci parmak da çizemez
func _wrong_dot() -> void:
	var page = game.page
	_tap(page.dots[2])
	await _frames(4)
	await _shot("01b_yanlis")
	_check(page.done == 0, "sırası gelmeyen nokta bağlandı")
	_tap(page.dots[0])
	await _frames(4)
	_check(page.done == 1, "1. noktaya dokununca bağlanmadı")
	# Birinci parmak basılıyken ikinci parmak sıradaki noktaya dokunur ve kaydırır: bağlanmamalı
	_touch(page.dots[0] + Vector2(-80, 40), true, 0)
	await _frames(2)
	_touch(page.dots[1], true, 1)
	_drag_event(page.dots[1] + Vector2(5, 5), 1)
	await _frames(3)
	_check(page.done == 1, "ikinci parmak nokta bağladı")
	_touch(page.dots[1], false, 1)
	_touch(page.dots[0] + Vector2(-80, 40), false, 0)
	await _frames(3)
	# Bağlanmış noktaya yeniden dokunmak bir şey bozmaz
	_tap(page.dots[0])
	await _frames(3)
	_check(page.done == 1, "bağlı noktaya dokununca sayı değişti")


# Kalan noktalara tek tek dokunur
func _tap_all(level: int) -> void:
	var page = game.page
	while page.next_index() >= 0:
		var before: int = page.done
		if before == 3:
			await _shot("%02d_cizerken" % (level + 1))
		_tap(page.dots[page.next_index()])
		await _frames(12)
		_check(page.done == before + 1, "%d. bölüm: dokunulan nokta bağlanmadı (%d)" % [level + 1, before + 1])


# 1. noktadan başlayıp parmağı kaldırmadan bütün noktaların üstünden yavaşça geçer
func _slow_swipe(level: int) -> void:
	var page = game.page
	var dots: PackedVector2Array = page.dots
	_touch(dots[0], true, 0)
	await _frames(2)
	_check(page.done == 1, "%d. bölüm: kaydırmanın başında 1. nokta bağlanmadı" % (level + 1))
	for i in range(1, dots.size()):
		for s in range(1, 9):
			_drag_event(dots[i - 1].lerp(dots[i], s / 8.0), 0)
			await _frames(1)
			if i == 3 and s == 4:
				await _frames(4)
				await _shot("%02d_cizerken" % (level + 1))
		_check(page.done == i + 1 or game.state != game.State.PLAYING, "%d. bölüm: kaydırırken %d. nokta bağlanmadı" % [level + 1, i + 1])
	_touch(dots[dots.size() - 1], false, 0)
	await _frames(2)
	_check(page.done == dots.size(), "%d. bölüm: kaydırma bitince bütün noktalar bağlanmadı (%d/%d)" % [level + 1, page.done, dots.size()])


# 1. noktaya dokunur, sonra boş bir yerden basıp noktadan noktaya tek büyük adımlarla kaydırır
func _fast_swipe(level: int) -> void:
	var page = game.page
	var dots: PackedVector2Array = page.dots
	_tap(dots[0])
	await _frames(3)
	var start: Vector2 = page.rect.get_center() + Vector2(0, page.rect.size.y * 0.1)
	_touch(start, true, 0)
	await _frames(2)
	_drag_event(start + Vector2(30, 0), 0)
	await _frames(4)
	await _shot("%02d_cizerken" % (level + 1))
	var last := start + Vector2(30, 0)
	for i in range(1, dots.size()):
		# Noktanın biraz ötesine atla: parmak noktanın üstünden geçer ama orada durmaz
		var target: Vector2 = dots[i] + (dots[i] - last).normalized() * 30.0
		_drag_event(target, 0)
		last = target
		await _frames(2)
	_touch(last, false, 0)
	await _frames(2)
	_check(page.done == dots.size(), "%d. bölüm: hızlı kaydırmada noktalar kaçtı (%d/%d)" % [level + 1, page.done, dots.size()])


func _wait_level_end(level: int) -> void:
	for k in 600:
		await process_frame
		if game.state == game.State.CELEBRATING:
			break
	_check(game.state == game.State.CELEBRATING, "%d. bölüm: noktalar bitince kutlama başlamadı" % (level + 1))
	await _frames(110)
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


# Noktalar belirirken 1. noktaya dokunmak onu bağlamaz
func _transition_tap() -> void:
	for k in 1200:
		if game.level_index == 1 and game.page != null and game.page.picture == Settings.picture_of(1):
			break
		await process_frame
	_check(game.state != game.State.PLAYING, "geçiş beklenirken bölüm hemen oynanabilir oldu")
	await _frames(10)
	await _shot("02a_belir")
	_tap(game.page.dots[0])
	await _frames(3)
	_check(game.page.done == 0, "geçişte nokta bağlandı")


func _back_to_menu() -> void:
	await _wait_playing()
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(center)
	await _frames(30)
	_check(current_scene.scene_file_path == GAME_SCENE, "geri düğmesine tek dokunuş oyundan çıkardı")
	_check(game.page.done == 0, "geri düğmesine dokunmak nokta bağladı")
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
		if game.state == game.State.PLAYING and game.page != null:
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
