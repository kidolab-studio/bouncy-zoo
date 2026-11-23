extends SceneTree
# Hayvan Doktoru oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/hayvan_doktoru/testler/oynanis_testi.gd -- <klasör>
# Oyun henüz menüde olmadığı için menü açıldıktan sonra SahneGecis ile açılır. Denetler:
#   - ayarlar.gd problems() boş; ekran yatay;
#   - bekleme odası: her gün DAYS'teki üç rahatsızlık, uygun ve birbirinden farklı hayvanlar, banktaki yerlerinde;
#     boşluğa dokunmak bir şey açmaz; dokunulan hasta masaya geçer, diğerleri gizlenir;
#   - sırası gelmeyen alet tutulamaz (kıpırdar); boşluğa bırakılan alet rafa döner, noktayı değiştirmez;
#     ikinci parmak alet tutmaz; aletsiz parmak noktayı değiştirmez;
#   - tedavideyken çift dokunuşlu geri: hasta banka döner, noktaları baştan açılır; bekleme odasında geri: ana menü;
#   - stetoskop göğüste basılı tutulunca biter, düşünce balonu çıkar;
#   - her rahatsızlıktan en az bir hasta: RUB sürtülünce, HOLD / FEED noktada durunca, PLACE bırakılınca, PULL her
#     diken çekilince biter; yarım çekilen diken yerine döner; noktalar ekranın içinde, sayıları günle uyumlu;
#   - hasta iyileşir, gider; üç hasta bitince gün biter, sonraki gün kaydedilir; oynanmayan hastalar F9
#     (geliştirici kısayolu) ile geçilir; son gün baştan sona oynanır;
#   - son gün bitince final ekranı (OyunBitti) açılır ve oyun tamamlandı sayılır; "sonsuz" rastgele hastalarla
#     sonsuz kliniği başlatır.
# <klasör> içine ekran görüntüleri kaydeder. Kullanıcının kayıtları yedeklenip geri yazılır.

const Settings := preload("res://oyunlar/hayvan_doktoru/ayarlar.gd")
const GAME_SCENE := "res://oyunlar/hayvan_doktoru/hayvan_doktoru.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVE := "user://hayvan_doktoru.cfg"
const SAVES := ["user://hayvan_doktoru.cfg", "user://hayvan_doktoru.cfg.bak", "user://ipucu_eli.cfg"]

var out := ""
var game: Node
var _fails := 0
var _backups := {}
var _bitmisti := false
var _played := {}                      # oynanan rahatsızlıklar
var _taken := {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	_bitmisti = OyunBitti.tamamlandi_mi("hayvan_doktoru")
	OyunBitti.sifirla("hayvan_doktoru")
	for path in SAVES:
		if FileAccess.file_exists(path):
			_backups[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(Settings.problems().is_empty(), "ayarlar: %s" % ", ".join(Settings.problems()))
	await _open()
	if game != null:
		_check(root.content_scale_size == Vector2i(1280, 720), "ekran yatay değil: %s" % root.content_scale_size)
		await _first_day()
		for d in range(1, Settings.DAYS.size()):
			await _play_day(d)
		await _finale_and_endless()
		await _back_to_menu()
	_finish()


func _finish() -> void:
	if _bitmisti:
		OyunBitti.tamamla("hayvan_doktoru")
	else:
		OyunBitti.sifirla("hayvan_doktoru")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	print("hayvan_doktoru oynanis_testi: " + ("TAMAM" if _fails == 0 else "%d hata" % _fails))
	quit(1 if _fails > 0 else 0)


func _open() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(90)
	root.get_node("SahneGecis").sahne_degistir(GAME_SCENE)
	for k in 400:
		await process_frame
		if current_scene and current_scene.scene_file_path == GAME_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == GAME_SCENE, "oyun açılmadı")
	if current_scene and current_scene.has_method("_start_day"):
		game = current_scene
	else:
		_check(false, "oyun script'i yüklenemedi")


# --- Günler ---

# 1. gün: bekleme odası, yanlış dokunuşlar, tedaviden geri dönüş; üç hasta da oynanır (ortadaki, soldaki, sağdaki)
func _first_day() -> void:
	await _wait_state(game.State.WAITING)
	_check(game.day == 0 and not game.endless, "1. gün bekleniyordu (%d)" % (game.day + 1))
	_check_day(0)
	await _shot("00_bekleme")
	# İpucu eli: ilk açılışta bekleme odasında bir hastaya dokunmayı gösterir
	await _wait_hint("bekleme odası", "00_ipucu_bekleme")
	_tap(Vector2(game.seats[0].x - game.waiting_size * 1.2, game.seats[0].y - game.waiting_size * 0.4))
	await _frames(20)
	_check(game.state == game.State.WAITING and game.current == -1, "boşluğa dokununca hasta seçildi")
	await _select(1)
	await _shot("01_masa")
	# Tedavide hiç dokunulmazsa ipucu eli sırası gelen aleti noktaya sürüklemeyi gösterir
	await _wait_hint("tedavi", "01_ipucu_tedavi")
	await _wrong_tool()
	await _empty_drop()
	await _second_finger()
	await _exam()
	await _back_to_bench()
	for k in [1, 0, 2]:
		await _select(k)
		await _exam()
		await _treat()
		await _wait_after_patient()
	await _wait_state(game.State.WAITING)
	_check(game.day == 1, "1. gün bitince 2. gün gelmedi (%d)" % (game.day + 1))
	var config := ConfigFile.new()
	config.load(SAVE)
	_check(int(config.get_value("ilerleme", "gun", -1)) == 1, "2. gün kaydedilmedi")
	await _album()


# Albüm: 1. günün üç çıkartması kazanılmış ve kaydedilmiş; düğmeyle açılır, kaydırma ve okla sayfa çevrilir, kazanılmış
# çıkartmaya dokunulur; çift dokunuşlu geri albümü kapatır (oyunda kalınır)
func _album() -> void:
	var config := ConfigFile.new()
	config.load(SAVE)
	var saved: int = config.get_section_keys("album").size() if config.has_section("album") else 0
	_check(game.album.stickers.size() == Settings.DAY_PATIENTS and saved == Settings.DAY_PATIENTS,
		"1. günden sonra 3 çıkartma bekleniyordu (%d, kayıtta %d)" % [game.album.stickers.size(), saved])
	_check(game.album.has_new and game.album.show_button, "albüm düğmesi yeni çıkartmayı göstermiyor")
	await _shot("04_album_dugmesi")
	_tap(game.album.button_center)
	await _frames(30)
	_check(game.album.shown and not game.album.has_new, "albüm düğmesine dokununca albüm açılmadı")
	_check(game.album.page == 0 and game.album.slot_count() == Settings.animals_for(Settings.AILMENT_ORDER[0]).size(),
		"albümün ilk sayfası yanlış")
	var filled := 0
	for k in game.album.slot_count():
		filled += 1 if game.album._slots[k].filled else 0
	_check(filled == 1, "sıyrık sayfasında 1 dolu çıkartma bekleniyordu (%d)" % filled)
	await _shot("05_album")
	for k in game.album.slot_count():
		if game.album._slots[k].filled:
			_tap(game.album.slot_point(k))
	var center: Vector2 = game.album._panel.get_center()
	_touch(center + Vector2(200, 0), true, 0)
	_touch(center - Vector2(200, 0), false, 0)
	await _frames(20)
	_check(game.album.page == 1, "sola kaydırınca sayfa çevrilmedi (%d)" % game.album.page)
	_tap(game.album._arrow_rect(1).get_center())
	await _frames(20)
	_check(game.album.page == 2, "sağ okla sayfa çevrilmedi (%d)" % game.album.page)
	await _shot("06_album_ates")
	_check(game.state == game.State.WAITING and game.current == -1, "albümde dokununca hasta seçildi")
	var back: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(back)
	await _frames(30)
	_tap(back)
	await _frames(20)
	_check(not game.album.shown and current_scene.scene_file_path == GAME_SCENE, "geri albümü kapatmadı")


# Ara günler: henüz oynanmamış rahatsızlıklar oynanır, gerisi F9 ile geçilir; son gün baştan sona oynanır
func _play_day(d: int) -> void:
	await _wait_state(game.State.WAITING)
	_check(game.day == d, "%d. gün bekleniyordu (%d)" % [d + 1, game.day + 1])
	_check_day(d)
	var last := d == Settings.DAYS.size() - 1
	for k in Settings.DAY_PATIENTS:
		var name: String = game.waiting[k]["ailment"]
		if last or not _played.has(name):
			await _select(k)
			await _exam()
			await _treat()
			await _wait_after_patient()
	if not last and game.day == d and game.state == game.State.WAITING:
		_key(KEY_F9)
		await _frames(10)
		_check(game.state == game.State.CELEBRATING, "F9 günü bitirmedi")


func _finale_and_endless() -> void:
	for k in 900:
		await process_frame
		if OyunBitti.acik:
			break
	_check(OyunBitti.acik, "son günden sonra final ekranı açılmadı")
	_check(OyunBitti.tamamlandi_mi("hayvan_doktoru"), "oyun tamamlandı sayılmadı")
	_check(_played.size() == Settings.AILMENT_ORDER.size(), "oynanmayan rahatsızlık var: %s" % [_played.keys()])
	await _frames(240)
	await _shot("30_final")
	var screen: OyunBitti = null
	for child in root.get_children():
		if child is OyunBitti:
			screen = child
	_check(screen != null, "final ekranı düğümü bulunamadı")
	if screen == null:
		return
	screen._eylem("sonsuz")
	for k in 600:
		await process_frame
		if game.endless and game.state == game.State.WAITING:
			break
	_check(game.endless and game.state == game.State.WAITING, "sonsuz klinik başlamadı")
	_check(game.waiting.size() == Settings.DAY_PATIENTS, "sonsuz klinikte %d hasta" % game.waiting.size())
	await _shot("31_sonsuz")
	await _select(0)
	await _exam()
	await _treat()
	await _wait_after_patient()
	await _wait_state(game.State.WAITING)
	_key(KEY_F9)
	await _frames(10)
	await _wait_state(game.State.WAITING)
	_check(game.endless and game.waiting.all(func(w) -> bool: return not w["done"]), "sonsuz klinikte yeni gün gelmedi")


# Günün hastaları DAYS'teki rahatsızlıklar, hayvanlar uygun ve birbirinden farklı, banktaki yerlerinde
func _check_day(d: int) -> void:
	var names: Array = Settings.DAYS[d]["ailments"]
	var animals := {}
	for k in game.waiting.size():
		var w: Dictionary = game.waiting[k]
		_check(w["ailment"] == names[k], "%d. gün %d. hasta: %s bekleniyordu, %s" % [d + 1, k + 1, names[k], w["ailment"]])
		_check(w["animal"] in Settings.animals_for(w["ailment"]), "%d. gün: %s %s için uygun değil" % [d + 1, w["animal"], w["ailment"]])
		animals[w["animal"]] = true
		_check(w["patient"].position.distance_to(game.seats[k]) < 2.0, "%d. gün: hasta banktaki yerinde değil" % (d + 1))
	_check(animals.size() == game.waiting.size(), "%d. gün: aynı hayvan iki kez geldi" % (d + 1))


# --- Bekleme odası ---

func _select(k: int) -> void:
	await _wait_state(game.State.WAITING)
	var p = game.waiting[k]["patient"]
	_tap(p.center_global())
	await _wait_state(game.State.PLAYING)
	_check(game.current == k and game.patient == p, "%d. hastaya dokununca masaya geçmedi" % (k + 1))
	_check(not game.album.show_button, "tedavide albüm düğmesi görünüyor")
	for j in game.waiting.size():
		var other = game.waiting[j]["patient"]
		if j != k and is_instance_valid(other):
			_check(not other.visible, "masadayken banktaki hasta görünüyor")
	await _check_spots()


# Tedavide çift dokunuşlu geri: hasta banka döner, noktaları baştan açılır, hiçbiri bitmemiş
func _back_to_bench() -> void:
	var k: int = game.current
	var p = game.patient
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(center)
	await _frames(30)
	_tap(center)
	await _wait_state(game.State.WAITING)
	_check(game.current == -1 and current_scene.scene_file_path == GAME_SCENE, "tedavide geri hastayı banka göndermedi")
	_check(p.position.distance_to(game.seats[k]) < 2.0, "geri dönen hasta banktaki yerinde değil")
	_check(p.spots.all(func(s) -> bool: return s.stage == 0), "geri dönen hastanın noktaları baştan açılmadı")
	await _shot("02_geri")


func _wait_after_patient() -> void:
	for k in 900:
		await process_frame
		if game.current == -1 and game.state != game.State.TRANSITION:
			break
	_check(game.current == -1, "hasta iyileşince bekleme odasına dönülmedi")


# --- Tedavi ---

func _wrong_tool() -> void:
	_tap(game.tray.slot_position(1))
	await _frames(10)
	_check(not game.tool.active, "sırası gelmeyen alet tutuldu")


# Stetoskobu boşluğa bırakmak: alet rafa döner, nokta değişmez
func _empty_drop() -> void:
	var spot = _spots_for(Settings.EXAM_TOOL)[0]
	await _grab(_far_point(), 0)
	_check(game.tool.active, "sırası gelen alet tutulamadı")
	await _frames(100)
	_check(is_equal_approx(spot.amount, 1.0), "stetoskop noktadan uzakta işledi")
	_touch(_far_point(), false, 0)
	await _frames(30)
	_check(not game.tool.active and game.tray.empty_slot == -1, "bırakılan alet rafa dönmedi")


# Bir parmak aleti tutarken ikinci parmak başka alet tutmaz; aletsiz parmak noktayı değiştirmez
func _second_finger() -> void:
	var spot = _spots_for(Settings.EXAM_TOOL)[0]
	_touch(spot.global_position, true, 1)
	for k in 30:
		_drag_event(spot.global_position + Vector2(30.0 if k % 2 == 0 else -30.0, 0.0), 1)
		await _frames(2)
	_touch(spot.global_position, false, 1)
	_check(not game.tool.active, "rafa dokunmadan alet tutuldu")
	_check(is_equal_approx(spot.amount, 1.0), "aletsiz parmak noktayı değiştirdi")
	await _grab(_far_point(), 0)
	_touch(game.tray.slot_position(1), true, 1)
	await _frames(5)
	_check(game.tool.id == Settings.EXAM_TOOL, "ikinci parmak başka alet tuttu")
	_touch(game.tray.slot_position(1), false, 1)
	_touch(_far_point(), false, 0)
	await _frames(30)


# Stetoskop göğüste basılı tutulur: biter, düşünce balonu çıkar
func _exam() -> void:
	await _wait_state(game.State.PLAYING)
	_check(game.step == 0 and game.steps[0] == Settings.EXAM_TOOL, "ziyaret stetoskopla başlamadı")
	var spot = _spots_for(Settings.EXAM_TOOL)[0]
	await _grab(_finger_for(spot), 0)
	for k in int(float(Settings.TOOLS[Settings.EXAM_TOOL]["time"]) * 60.0) + 40:
		await process_frame
		if game.step > 0:
			break
	_touch(_finger_for(spot), false, 0)
	_check(game.step == 1, "stetoskop basılı tutulunca adım bitmedi")
	await _frames(20)
	_check(game.bubble.shown, "stetoskoptan sonra düşünce balonu çıkmadı")
	await _shot_once("%s_a" % game.ailment, "1%d_%s_a" % [_played.size(), game.ailment])


# Rahatsızlığın adımları: her adımda sırası gelen aleti türüne göre kullanır
func _treat() -> void:
	var name: String = game.ailment
	var first := not _played.has(name)
	while game.step < game.steps.size() and game.state == game.State.PLAYING:
		await _wait_state(game.State.PLAYING)
		if game.state != game.State.PLAYING:
			break
		var id: String = game.steps[game.step]
		var spots := _spots_for(id)
		_check(not spots.is_empty(), "%s: %s için nokta yok" % [name, id])
		if spots.is_empty():
			return
		var before: int = game.step
		for spot in spots:
			await _use_tool(id, spot, first)
			await _frames(6)
			_check(not spot.needs(id), "%s: %s noktayı bitirmedi" % [name, id])
		_check(game.step == before + 1 or game.state != game.State.PLAYING, "%s: %s bitince adım ilerlemedi" % [name, id])
		if before == 1 and game.state == game.State.PLAYING:
			await _frames(20)
			await _shot_once("%s_b" % name, "1%d_%s_b" % [_played.size(), name])
	_check(game.patient.spots.all(func(s) -> bool: return s.done()), "%s: noktalar bitmedi" % name)
	_check(game.state == game.State.CELEBRATING, "%s: son adımdan sonra hasta iyileşmedi" % name)
	_played[name] = true
	await _frames(40)
	await _shot_once("iyilesti", "03_iyilesti")


func _use_tool(id: String, spot, first: bool) -> void:
	var finger := _finger_for(spot)
	match int(Settings.TOOLS[id]["kind"]):
		Settings.Kind.RUB:
			await _grab(finger, 0)
			for k in 160:
				_drag_event(finger + Vector2(34.0 if k % 2 == 0 else -34.0, 0.0), 0)
				await _frames(2)
				if not spot.needs(id):
					break
			_touch(finger, false, 0)
		Settings.Kind.PLACE:
			await _grab(finger, 0)
			_touch(finger, false, 0)
		Settings.Kind.PULL:
			await _grab(finger, 0)
			var away := Vector2(0.0, -(Settings.PULL_DISTANCE + 0.6) * spot.radius * spot.global_scale.x)
			var tries := 0
			while spot.needs(id) and tries < 8:
				tries += 1
				_drag_event(finger, 0)
				await _frames(4)
				if first and tries == 1:
					# Yarım çekip bırakmak: diken yerine döner, çıkmaz
					_drag_event(finger + away * 0.4, 0)
					await _frames(4)
					_touch(finger + away * 0.4, false, 0)
					await _frames(20)
					_check(spot.needs(id) and spot._pull == 0.0, "yarım çekilen diken yerine dönmedi")
					await _grab(finger, 0)
					continue
				for k in range(1, 7):
					_drag_event(finger + away * k / 6.0, 0)
					await _frames(2)
				await _frames(10)
			_touch(finger + away, false, 0)
		_:
			await _grab(finger, 0)
			await _frames(int(float(Settings.TOOLS[id]["time"]) * 60.0) + 30)
			_touch(finger, false, 0)


# Tedavideki hastanın noktaları: sayıları günle uyumlu, hepsi ekranın içinde (masaya geçiş bitince)
func _check_spots() -> void:
	var name: String = game.ailment
	var expected := 1
	for info: Dictionary in Settings.AILMENTS[name]["spots"]:
		expected += int(game._day_info["rash"]) if info["look"] == "benek" else int(info.get("count", 1))
	_check(game.patient.spots.size() == expected, "%s: %d nokta bekleniyordu, %d" % [name, expected, game.patient.spots.size()])
	for spot in game.patient.spots:
		if spot.look == "diken":
			_check(spot._thorns.size() == int(game._day_info["thorns"]), "diken sayısı günle uyumlu değil")
	await _frames(20)
	var screen: Vector2 = game.get_viewport_rect().size
	for spot in game.patient.spots:
		var p: Vector2 = spot.global_position
		_check(Rect2(Vector2.ZERO, screen).grow(-20.0).has_point(p), "%s: nokta ekranın dışında (%s)" % [name, p])


func _back_to_menu() -> void:
	await _wait_state(game.State.WAITING)
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_tap(center)
	await _frames(30)
	_check(current_scene.scene_file_path == GAME_SCENE, "geri düğmesine tek dokunuş oyundan çıkardı")
	_tap(center)
	for k in 300:
		await process_frame
		if current_scene and current_scene.scene_file_path == MENU_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == MENU_SCENE,
		"bekleme odasında çift dokunuşlu geri menüye dönmedi (durum %s, hasta %s, sahne %s)" % [
			game.state if is_instance_valid(game) else "-", game.current if is_instance_valid(game) else "-",
			current_scene.scene_file_path if current_scene else "yok"])


# --- Yardımcılar ---

# İpucu eli görünene kadar dokunmadan bekler (ilk açılışta hemen, sonra 6 sn boşta kalınca), görüntüsünü alır
func _wait_hint(where: String, shot: String) -> void:
	var hand: IpucuEli = null
	for child in game.get_children():
		if child is IpucuEli:
			hand = child
	_check(hand != null, "ipucu eli eklenmemiş")
	if hand == null:
		return
	for k in 600:
		await process_frame
		if hand._gosteriyor:
			break
	_check(hand._gosteriyor, "%s: ipucu eli görünmedi" % where)
	await _frames(70)
	await _shot(shot)

func _spots_for(id: String) -> Array:
	return game.patient.spots.filter(func(s) -> bool: return s.needs(id))


# Aletin ucu noktanın üstüne gelsin diye parmağın duracağı yer (uç parmağın lift kadar üstünde)
func _finger_for(spot) -> Vector2:
	var lift := clampf(game.patient_size * 0.14, 44.0, 70.0)
	return spot.global_position + Vector2(0.0, lift)


# Hastadan uzak boş nokta: rafın solunda
func _far_point() -> Vector2:
	return game.tray.slot_position(0) + Vector2(-game.tray.radius * 2.4, 0.0)


# Sırası gelen aleti raftan tutup noktaya sürükler (parmak basılı kalır)
func _grab(point: Vector2, index: int) -> void:
	var slot: Vector2 = game.tray.slot_position(game.step)
	_touch(slot, true, index)
	await _frames(2)
	for k in range(1, 9):
		_drag_event(slot.lerp(point, k / 8.0), index)
		await _frames(2)
	await _frames(10)


func _wait_state(wanted: int) -> void:
	for k in 900:
		if game.state == wanted and not game._step_busy:
			return
		await process_frame
	_check(false, "durum %d beklendi, %d" % [wanted, game.state])


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	var up := event.duplicate()
	up.pressed = false
	root.push_input(up)


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


func _shot_once(key: String, name: String) -> void:
	if not _taken.has(key):
		_taken[key] = true
		await _shot(name)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
