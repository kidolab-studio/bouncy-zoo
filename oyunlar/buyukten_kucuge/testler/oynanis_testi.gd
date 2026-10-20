extends SceneTree
# Büyükten Küçüğe oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/buyukten_kucuge/testler/oynanis_testi.gd -- <klasör>
# Ana menüden karta dokunup oyunu açar (ekran yatay olmalı) ve 15 bölümü parmakla sürükleyerek oynar:
#   - her bölümün türü, nesne sayısı tabloya uyuyor; nesneler oyun alanında;
#   - boşluğa bırakılan nesne sessizce evine döner; yanlış hamle (küçük halka önce, yanlış yuva, büyük bebeği
#     küçüğe koyma, boy atlayan bebek) kabul edilmez ve nesne evine döner;
#   - ikinci parmak tutulan nesneyi bozmaz, başka nesne tutamaz;
#   - boşta kalınca ipucu eli çıkar ve sıradaki doğru nesne gösterilir;
#   - bütün nesneler doğru yerleşince bölüm ilerler; 15. bölümden sonra 1. bölüme dönülür;
#   - basılı geri düğmesiyle ana menüye dönülür.
# <klasör> içine ekran görüntüleri kaydeder. Kullanıcının kayıtları (oyun ve menü) yedeklenip geri yazılır.

const GAME_SCENE := "res://oyunlar/buyukten_kucuge/buyukten_kucuge.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"
const SAVES := ["user://buyukten_kucuge.cfg", "user://ana_menu.cfg"]

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
	_bitmisti = OyunBitti.tamamlandi_mi("buyukten_kucuge")
	OyunBitti.sifirla("buyukten_kucuge")
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
		OyunBitti.tamamla("buyukten_kucuge")
	else:
		OyunBitti.sifirla("buyukten_kucuge")
	for path in SAVES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if _backups.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_backups[path])
			file.close()
	if _fails == 0:
		print("buyukten_kucuge oynanis_testi: TAMAM")
	else:
		printerr("buyukten_kucuge oynanis_testi: %d hata" % _fails)
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
	_check(index >= 0, "ana menüde Büyükten Küçüğe kartı yok")
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
	var settings: SizeSettings = game.settings
	var total := settings.level_count()
	_check(total == 15, "15 bölüm olmalı, %d" % total)
	for level in total:
		await _wait_playing()
		_check(game.level_index == level, "%d. bölüm bekleniyordu, %d" % [level + 1, game.level_index + 1])
		var activity = game.activity
		var data := settings.level(level)
		_check(game.plan.kind == data.kind and activity.items.size() == data.count,
			"%d. bölüm: tür/sayı %s %d, beklenen %s %d" % [level + 1, game.plan.kind, activity.items.size(), data.kind, data.count])
		for item in activity.items:
			_check(Rect2(Vector2.ZERO, game.plan.screen).encloses(item.rect()), "%d. bölüm: nesne ekran dışında" % (level + 1))
		await _frames(20)
		match level:
			0:
				await _shot("01_halka")
				await _empty_drop(activity)
				await _wrong_ring(activity)
				await _second_finger(activity)
				await _idle_hint(activity)
			1:
				await _shot("02_dizi_siluet")
				await _wrong_slot(activity)
			2:
				await _big_into_small(activity)
			4:
				await _shot("05_boy")
			8:
				await _shot("09_kucukten_buyuge")
			9:
				await _skip_size(activity)
		await _solve(activity, level)
		if level == 2:
			await _frames(150)
			await _shot("03_bebek_selam")
		await _wait_level_end(level)
	await _final_bastan()
	await _wait_playing()
	_check(game.level_index == 0, "son bölümden sonra 1. bölüme dönülmedi (%d)" % (game.level_index + 1))
	_check(game.stars.current == 0, "yeni turda yıldızlar sıfırlanmadı")


# Sıradaki doğru hamleyi (etkinliğin ipucu hamlesi) parmakla yaparak bölümü bitirir
func _solve(activity, level: int) -> void:
	for step in 60:
		if activity.done:
			return
		var move: Array = activity.hint_move()
		if move.is_empty():
			await _frames(10)
			continue
		await _drag(move[0].position, move[1])
		await _frames(12)
	_check(activity.done, "%d. bölüm bitmedi" % (level + 1))


func _wait_level_end(level: int) -> void:
	for k in 1500:
		await process_frame
		if game.level_index != level and game.state == game.State.PLAYING:
			return
		if level == 14 and OyunBitti.acik:
			return
		if level == 14 and k == 300:
			await _shot("15_final")
	_check(false, "%d. bölümden sonra ilerlenmedi" % (level + 1))


func _returned_home(item) -> bool:
	return not item.placed and item.position.distance_to(item.home) < 2.0


# Boşluğa (duvarın ortasına) bırakılan halka sessizce döner
func _empty_drop(activity) -> void:
	var item = activity.items[1]
	await _drag(item.position, Vector2(game.plan.screen.x * 0.35, 200.0))
	await _frames(50)
	_check(_returned_home(item), "boşluğa bırakılan halka evine dönmedi")


# Küçük halka önce direğe: kabul edilmez, evine döner
func _wrong_ring(activity) -> void:
	var small = activity.items[activity.items.size() - 1]
	await _drag(small.position, activity.rod_top(small))
	await _frames(80)
	_check(_returned_home(small), "yanlış (küçük) halka direğe takıldı ya da dönmedi")
	_check(activity.next_rank == 0, "yanlış halkadan sonra sıra değişti")


# Bir parmak halka tutarken ikinci parmak başka halkayı tutamaz
func _second_finger(activity) -> void:
	var a = activity.items[0]
	var b = activity.items[1]
	_touch(a.position, true, 0)
	await _frames(4)
	_touch(b.position, true, 1)
	await _frames(4)
	_check(game.drag_input.dragged == a, "ikinci parmak tutulan halkayı değiştirdi")
	_check(not b.dragging, "ikinci parmak ikinci halkayı tuttu")
	_touch(b.position, false, 1)
	_touch(a.position, false, 0)
	await _frames(50)
	_check(_returned_home(a) and _returned_home(b), "iki parmaktan sonra halkalar yerine dönmedi")


# Boşta kalınca ipucu eli çıkar
func _idle_hint(activity) -> void:
	var seen := false
	for k in int((game.hint_delay + 1.5) * 60.0):
		await process_frame
		if game.hand.visible:
			seen = true
			break
	_check(seen, "boşta kalınca ipucu eli çıkmadı")
	if seen:
		await _frames(40)
		await _shot("01_ipucu")


# Nesneyi yanlış yuvaya bırakınca evine döner
func _wrong_slot(activity) -> void:
	var plan: SizeLevelGenerator.Plan = game.plan
	var item = activity.items[0]
	var wrong := plan.slot_rank.find(plan.count - 1)
	await _drag(item.position, plan.slots[wrong].get_center())
	await _frames(60)
	_check(_returned_home(item), "yanlış yuvaya bırakılan nesne yerleşti ya da dönmedi")


# Büyük bebeği küçüğün içine koymak kabul edilmez
func _big_into_small(activity) -> void:
	var big = activity.items[0]
	var small = activity.items[activity.items.size() - 1]
	await _drag(big.position, small.position)
	await _frames(60)
	_check(_returned_home(big) and big.visible and small.visible, "büyük bebek küçüğün içine girdi")


# Boy atlama yok bölümü: en küçük bebek en büyüğe giremez
func _skip_size(activity) -> void:
	var big = activity.items[0]
	var small = activity.items[activity.items.size() - 1]
	await _drag(small.position, big.position)
	await _frames(60)
	_check(_returned_home(small) and small.visible, "boy atlayan bebek içeri girdi")


func _back_to_menu() -> void:
	await _wait_playing()
	var center: Vector2 = game.back_button.get_global_rect().get_center()
	_touch(center, true, 0)
	await _frames(int(game.hold_to_exit * 60.0) + 20)
	_touch(center, false, 0)
	for k in 300:
		await process_frame
		if current_scene and current_scene.scene_file_path == MENU_SCENE:
			break
	_check(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "basılı geri düğmesiyle menüye dönülmedi")


# --- Dokunma yardımcıları ---

# Nesneyi tutup hedefe götürür; bırakma noktası (parmağın biraz üstü) hedefe gelir
func _drag(start: Vector2, target: Vector2) -> void:
	var finger := target + Vector2(0, game.drag_input.lift)
	_touch(start, true, 0)
	await _frames(2)
	for k in range(1, 9):
		_drag_event(start.lerp(finger, k / 8.0), 0)
		await _frames(2)
	await _frames(4)
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
