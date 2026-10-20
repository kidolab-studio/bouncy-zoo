extends SceneTree
# Müzik Kutusu oynanış testi (pencereli). Proje kökünden:
#   godot --path . --fixed-fps 60 --resolution 1280x720 -s res://oyunlar/muzik_kutusu/testler/oyun_testi.gd -- <klasör> [GENxYÜK]
# Ana menüden karta dokunup oyunu açar ve şunları denetler: ekran yatay; üç enstrümanın her parçası dokununca
# doğru sesi çalıyor; ksilofonda soldan sağa / sağdan sola hızlı kaydırma 8 notayı sırayla çalıyor; klavye 1-8;
# davulda iki parmak aynı anda iki parça çalıyor, aynı parçaya art arda 20 vuruşta hiçbiri sessiz kalmıyor;
# hayvanlar ses süresince ağzı açık; şarkı modunda üç şarkı parlayan tuşlar izlenerek baştan sona çalınıyor,
# yanlış tuş ilerletmiyor, sonunda kutlama; enstrüman değişirken dokunuş hemen yeni enstrümana gidiyor;
# dansçılar müzikle dans edip sessizlikte duruyor; 15 sn dokunulmayınca davet; basılı geri düğmesiyle menüye dönüş.
# Boyut verilirse oyunu doğrudan o boyutta açıp sadece ekran görüntüsü alır. Görüntüler <klasör> içine.

const GAME_SCENE := "res://oyunlar/muzik_kutusu/muzik_kutusu.tscn"
const MENU_SCENE := "res://ana_menu/ana_menu.tscn"

var out := ""
var prefix := ""
var game: Node
var _fails := 0
var _played: Array[String] = []      # çalınan seslerin adları (note_played sırasıyla)
var _finished: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		printerr("HATA: " + message)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 1:
		await _screens_at(args[1])
		_finish()
		return
	await _from_menu()
	if game == null:
		_finish()
		return
	_check(root.content_scale_size == Vector2i(1280, 720), "ekran yatay değil: %s" % root.content_scale_size)
	for instrument in game.instruments:
		instrument.note_played.connect(func(pad: Node2D, _at: Vector2) -> void: _played.append(pad.sound))
	game.instruments[0].song_finished.connect(func(_song: MusicSong) -> void: _finished += 1)
	await _xylophone()
	await _songs()
	await _drums()
	await _animals()
	await _dancers_and_invite()
	await _back_to_menu()
	_finish()


func _finish() -> void:
	if is_instance_valid(game) and game.is_inside_tree() and current_scene != game:
		game.queue_free()
	await process_frame
	if _fails == 0:
		print("oyun_testi: TAMAM")
	else:
		printerr("oyun_testi: %d hata" % _fails)
	quit(1 if _fails > 0 else 0)


# --- Açılış ---

func _from_menu() -> void:
	var menu: Node = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(90)
	await _shot("00_menu")
	var index := -1
	for k in menu.OYUNLAR.size():
		if menu.OYUNLAR[k]["sahne"] == GAME_SCENE:
			index = k
	_check(index >= 0, "ana menüde Müzik Kutusu kartı yok")
	if index < 0:
		menu.queue_free()
		root.get_node("SahneGecis").sahne_degistir(GAME_SCENE)
	else:
		_tap(menu._kartlar[index].get_global_rect().get_center())
	for k in 400:
		await process_frame
		if current_scene and current_scene.scene_file_path == GAME_SCENE and not root.get_node("SahneGecis").gecis_suruyor:
			break
	_check(current_scene != null and current_scene.scene_file_path == GAME_SCENE, "karta dokununca oyun açılmadı")
	game = current_scene
	await _frames(20)


func _screens_at(size_text: String) -> void:
	var parts := size_text.split("x")
	prefix = size_text + "_"
	var size := Vector2i(int(parts[0]), int(parts[1]))
	root.content_scale_size = Vector2i(1280, 720)
	root.size = size
	root.get_node("SahneGecis").visible = false
	game = load(GAME_SCENE).instantiate()
	root.add_child(game)
	await _frames(30)
	for k in game.instruments.size():
		game.select(k, false)
		await _frames(10)
		var instrument: Node2D = game.instruments[k]
		for pad in instrument.pads:
			_check(root.get_visible_rect().has_point(pad.touch_center()), "%s: parça ekran dışında" % size_text)
		_tap(instrument.pads[1].touch_center())
		await _frames(12)
		await _shot("%d_enstruman" % k)


# --- Ksilofon ---

func _xylophone() -> void:
	var xylo: Node2D = game.instruments[0]
	_check(game.current == 0 and xylo.visible, "ilk enstrüman ksilofon değil")
	await _frames(30)
	await _shot("01_ksilofon")
	# Her tuş: doğru nota, havuzda çalıyor, uzundan kısaya
	for i in 8:
		_played.clear()
		_tap(xylo.pads[i].touch_center())
		await _frames(2)
		_check(_played == ["n%d" % i], "ksilofon tuşu %d: %s" % [i, _played])
		_check(_is_sounding(xylo, "n%d" % i), "ksilofon tuşu %d sesi havuzda çalmıyor" % i)
		if i > 0:
			_check(xylo.pads[i].hit_size.y < xylo.pads[i - 1].hit_size.y, "tuşlar soldan sağa kısalmıyor")
	# Glissando: 6 hareketle hızlıca soldan sağa, sonra sağdan sola
	await _frames(20)
	var left: Vector2 = xylo.pads[0].touch_center()
	var right: Vector2 = xylo.pads[7].touch_center()
	_played.clear()
	await _drag(left, right, 6)
	_check(_played == ["n0", "n1", "n2", "n3", "n4", "n5", "n6", "n7"], "soldan sağa kaydırma: %s" % [_played])
	await _frames(10)
	await _shot("02_kaydirma")
	_played.clear()
	await _drag(right, left, 4)
	_check(_played == ["n7", "n6", "n5", "n4", "n3", "n2", "n1", "n0"], "sağdan sola kaydırma: %s" % [_played])
	# Klavye 1-8
	_played.clear()
	for i in 8:
		_key(KEY_1 + i)
	_check(_played.size() == 8 and _played[0] == "n0" and _played[7] == "n7", "klavye 1-8: %s" % [_played])
	await _frames(30)


# --- Şarkı modu ---

func _songs() -> void:
	var xylo: Node2D = game.instruments[0]
	var book: Vector2 = xylo.to_global(xylo.BOOK_CENTER)
	for s in xylo.SONGS.size():
		_tap(book)
		await _frames(3)
		var song: MusicSong = xylo.current_song()
		_check(song == xylo.SONGS[s], "defter %d. basışta %d. şarkıyı başlatmadı" % [s + 1, s + 1])
		if song == null:
			return
		var first: int = song.bar(0)
		_check(xylo.pads[first].is_target(), "şarkının ilk tuşu parlamıyor")
		# Yanlış tuş: ses çıkar ama şarkı ilerlemez
		var wrong: int = (first + 3) % 8
		_played.clear()
		_tap(xylo.pads[wrong].touch_center())
		await _frames(2)
		_check(_played == ["n%d" % wrong] and xylo.song_player.step == 0, "yanlış tuş şarkıyı ilerletti ya da sessiz kaldı")
		if s == 0:
			await _frames(20)
			await _shot("03_sarki_modu")
		for i in song.size():
			var bar: int = xylo.song_player.target()
			_check(bar == song.bar(i), "%s: %d. notada hedef tuş yanlış" % [song.resource_path.get_file(), i])
			for k in 8:
				if xylo.pads[k].is_target() != (k == bar):
					_check(false, "%d. notada yanlış tuş parlıyor" % i)
					break
			_tap(xylo.pads[bar].touch_center())
			await _frames(3)
		_check(_finished == s + 1, "%s bitince kutlama gelmedi" % song.resource_path.get_file())
		_check(not xylo.song_player.is_playing(), "şarkı bitince şarkı modu kapanmadı")
		await _frames(30)
		if s == 0:
			await _shot("04_kutlama")
			# Kutlamadan sonra şarkı kendiliğinden çalınır
			_played.clear()
			await _frames(150)
			_check(_played.size() >= 3 and _played[0] == "n%d" % song.bar(0), "şarkı kendiliğinden geri çalınmadı: %s" % [_played])
			_tap(xylo.pads[0].touch_center())
			await _frames(2)
			_check(not xylo.song_player.is_replaying(), "dokununca geri çalma durmadı")
	# Şarkı açıkken son şarkıdan sonra defter kapatır
	_tap(book)
	await _frames(2)
	_tap(book)
	await _frames(2)
	_tap(book)
	await _frames(2)
	_check(xylo.current_song() == xylo.SONGS[2], "defter şarkıları sırayla açmıyor")
	_tap(book)
	await _frames(2)
	_check(xylo.current_song() == null, "sonuncudan sonra defter şarkı modunu kapatmadı")
	for pad in xylo.pads:
		_check(not pad.is_target(), "şarkı modu kapanınca tuş parlamaya devam ediyor")
	await _frames(20)


# --- Davul seti ---

func _drums() -> void:
	# Enstrüman değişimi: dokunuş kayma bitmeden yeni enstrümana gider
	_tap(game.hud._buttons[1].get_global_rect().get_center())
	await _frames(1)
	_check(game.current == 1, "davul düğmesi davul setini seçmedi")
	var drums: Node2D = game.instruments[1]
	_played.clear()
	_tap(drums.pads[0].touch_center())
	await _frames(1)
	_check(_played == ["bas"], "geçiş sırasında dokunuş yeni enstrümana gitmedi: %s" % [_played])
	await _frames(30)
	_check(not game.instruments[0].visible and drums.visible, "geçiş sonunda eski enstrüman görünüyor")
	await _shot("05_davul")
	# Her parça
	for pad in drums.pads:
		_played.clear()
		_tap(pad.touch_center())
		await _frames(2)
		_check(_played == [pad.sound], "davul parçası %s: %s" % [pad.sound, _played])
		_check(_is_sounding(drums, pad.sound), "%s sesi havuzda çalmıyor" % pad.sound)
		await _frames(10)
	# Çoklu dokunma: iki parmak aynı karede iki parçaya
	_played.clear()
	_touch(drums.pads[1].touch_center(), true, 0)
	_touch(drums.pads[5].touch_center(), true, 1)
	await _frames(2)
	_check(_played.size() == 2 and _played.has("trampet") and _played.has("marakas"), "iki parmak iki parça çalmadı: %s" % [_played])
	await _shot("06_iki_parmak")
	_touch(drums.pads[1].touch_center(), false, 0)
	_touch(drums.pads[5].touch_center(), false, 1)
	# Aynı parçaya art arda 20 vuruş: hepsi çalar, sesler üst üste biner (havuz dolunca en eski susar)
	_played.clear()
	for k in 20:
		_tap(drums.pads[1].touch_center())
		await _frames(1)
	_check(_played.size() == 20, "20 hızlı vuruşta %d ses çaldı" % _played.size())
	var sounding := 0
	for player in drums.sounds.get_children():
		if player.playing:
			sounding += 1
	_check(sounding >= 12, "hızlı vuruşlar üst üste çalmıyor (%d ses)" % sounding)
	await _frames(40)


# --- Hayvan orkestrası ---

func _animals() -> void:
	_tap(game.hud._buttons[2].get_global_rect().get_center())
	await _frames(30)
	var band: Node2D = game.instruments[2]
	_check(game.current == 2 and band.visible, "hayvan orkestrası seçilmedi")
	for pad in band.pads:
		_played.clear()
		_tap(pad.touch_center())
		await _frames(3)
		_check(_played == [pad.sound], "hayvan %s: %s" % [pad.sound, _played])
		_check(pad.is_singing() and pad._sprite.texture == pad.open_texture, "%s ağzını açmadı" % pad.sound)
		if pad.sound == "inek":
			await _frames(6)
			await _shot("07_hayvanlar")
	var cat: Node2D = band.pads[0]
	await _frames(int(band.sound_length("kedi") * 60.0) + 90)
	_check(not cat.is_singing() and cat._sprite.texture != cat.open_texture, "ses bitince kedinin ağzı kapanmadı")
	# Aynı anda iki hayvan
	_played.clear()
	_touch(band.pads[2].touch_center(), true, 0)
	_touch(band.pads[7].touch_center(), true, 1)
	await _frames(2)
	_check(_played.size() == 2, "iki hayvan aynı anda çalmadı")
	_touch(band.pads[2].touch_center(), false, 0)
	_touch(band.pads[7].touch_center(), false, 1)
	await _frames(20)


# --- Dans ve davet ---

func _dancers_and_invite() -> void:
	var band: Node2D = game.instruments[2]
	_tap(band.pads[3].touch_center())
	await _frames(10)
	for dancer in game.dancers:
		_check(dancer.is_dancing(), "müzik çalınca dansçı dans etmiyor")
	await _shot("08_dans")
	# Sessizlikte dans yavaşça durur
	await _frames(60 * 5)
	for dancer in game.dancers:
		_check(not dancer.is_dancing(), "sessizlikte dansçı durmadı")
	# 15 sn dokunulmayınca davet (sayaç son dokunuştan beri işliyor)
	var before: int = game.invite_count
	await _frames(60 * 11)
	_check(game.invite_count == before + 1, "15 sn sonra davet gelmedi")
	await _frames(20)
	await _shot("09_davet")


# --- Geri düğmesi ---

func _back_to_menu() -> void:
	var back: Vector2 = game.hud.back_button.get_global_rect().get_center()
	_touch(back, true, 0)
	await _frames(20)
	_touch(back, false, 0)
	await _frames(30)
	_check(current_scene == game, "tek dokunuş geri düğmesinde oyundan çıkardı")
	_touch(back, true, 0)
	await _frames(5)
	_touch(back, false, 0)
	for k in 200:
		await process_frame
		if current_scene and current_scene.scene_file_path == MENU_SCENE:
			break
	_check(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "geri düğmesine ikinci dokunuş ana menüye dönmedi")
	_check(AudioServer.get_bus_index(&"MuzikKutusu") == -1, "oyundan çıkınca ses yolu kaldırılmadı")


# --- Yardımcılar ---

func _is_sounding(instrument: Node2D, sound: String) -> bool:
	var stream: AudioStream = instrument.sounds.streams[sound]
	for player in instrument.sounds.get_children():
		if player.playing and player.stream == stream and player.bus == &"MuzikKutusu":
			return true
	return false


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	root.push_input(event, true)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	_touch(pos, false)


func _drag(from: Vector2, to: Vector2, moves: int) -> void:
	_touch(from, true)
	await _frames(1)
	for k in range(1, moves + 1):
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = from.lerp(to, float(k) / moves)
		event.relative = (to - from) / moves
		root.push_input(event, true)
		await _frames(1)
	_touch(to, false)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _frames(count: int) -> void:
	for k in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s%s.png" % [out, prefix, name])
