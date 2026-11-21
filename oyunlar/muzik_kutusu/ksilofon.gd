extends "res://oyunlar/muzik_kutusu/enstruman.gd"
# Xylophone: 8 gökkuşağı renkli tuş (Do ... ince Do). Gerçek ksilofon gibi soldan sağa pesten tize, tuşlar
# uzundan kısaya. Dokunulan yerde bir tokmak belirir. Parmak tuşların üstünde kaydırılınca (glissando)
# geçtiği her tuş sırayla çalar; hızlı kaydırmada tuş atlanmasın diye yol küçük adımlarla taranır.
# Sağ üst köşedeki nota defteri şarkı modunu açar (sarki_calar.gd): her basışta sıradaki şarkı, sonuncudan
# sonra kapanır; şarkı yokken basınca sıradaki başlar. Şarkı bitince kutlama olur ve şarkı kendi temposuyla bir kez kendiliğinden çalınır.
# Tuş geometrisi gorseller/svg_uret.py ile aynı (cerceve.svg bu sabitlere göre çizildi).

signal song_started(song: MusicSong)
signal song_finished(song: MusicSong)

const SongPlayer := preload("res://oyunlar/muzik_kutusu/sarki_calar.gd")
const G := "res://oyunlar/muzik_kutusu/gorseller/"
const S := "res://oyunlar/muzik_kutusu/sesler/"

## Şarkı modundaki şarkılar sırayla (yeni şarkı: sarkilar/ içine .tres ve buraya bir satır)
const SONGS: Array[MusicSong] = [
	# Küçük Yıldız: Ah vous dirai-je, maman (Twinkle Twinkle Little Star), geleneksel halk ezgisi
	preload("res://oyunlar/muzik_kutusu/sarkilar/kucuk_yildiz.tres"),
	# Tembel Çocuk: Frère Jacques, geleneksel halk ezgisi. Son dizedeki pes sol ksilofonda olmadığı için do2-sol-do2
	preload("res://oyunlar/muzik_kutusu/sarkilar/tembel_cocuk.tres"),
	# Kuzucuk: Mary Had a Little Lamb, geleneksel ezgi
	preload("res://oyunlar/muzik_kutusu/sarkilar/kuzucuk.tres"),
]
const BAR_TEXTURES: Array[Texture2D] = [
	preload(G + "tus_1.svg"), preload(G + "tus_2.svg"), preload(G + "tus_3.svg"), preload(G + "tus_4.svg"),
	preload(G + "tus_5.svg"), preload(G + "tus_6.svg"), preload(G + "tus_7.svg"), preload(G + "tus_8.svg"),
]
const BAR_COLORS: Array[Color] = [
	Color("ff5b5b"), Color("ff9a3d"), Color("ffd23f"), Color("7bd85a"),
	Color("36cfc9"), Color("4aa3ff"), Color("8b6cf6"), Color("ff6fb5"),
]
const TEX_FRAME: Texture2D = preload(G + "cerceve.svg")
const TEX_MALLET: Texture2D = preload(G + "tokmak.svg")
const TEX_BOOK: Texture2D = preload(G + "defter.svg")
const TEX_MARKER: Texture2D = preload(G + "yildiz.svg")

const BAR_W := 96.0
const BAR_STEP := 122.0
const BAR_X0 := 88.0
const BAR_CY := 260.0
const BAR_TALL := 390.0
const BAR_SHORT := 250.0
const BOOK_CENTER := Vector2(928, 66)
const BOOK_SIZE := 118.0
const GLISS_STEP := 14.0              # kaydırmada yolun taranma aralığı (ekran pikseli)
const MALLET_WIDTH := 100.0

var song_player: SongPlayer
var _book: Node2D
var _book_art: Sprite2D
var _badge: Sprite2D
var _marker: Node2D                   # şarkı modunda sıradaki tuşun üstünde zıplayan yıldız
var _song_index: int = -1
var _last_point: Dictionary = {}      # parmak index -> son konum (glissando için)
var _mallets: Dictionary = {}         # parmak index -> tokmak
var _mallet_layer: Node2D
var _time: float = 0.0


static func bar_height(i: int) -> float:
	return BAR_TALL - (BAR_TALL - BAR_SHORT) * i / 7.0


func sound_streams() -> Dictionary:
	var streams := {}
	for i in 8:
		streams["n%d" % i] = load(S + "ksilofon_%d.wav" % (i + 1))
	streams["kutlama"] = preload(S + "kutlama.wav")
	return streams


func build() -> void:
	var frame := Sprite2D.new()
	frame.texture = TEX_FRAME
	frame.centered = false
	frame.scale = Vector2.ONE * design_size.x / TEX_FRAME.get_width()
	add_child(frame)
	for i in 8:
		var pad := Pad.new()
		pad.sound = "n%d" % i
		pad.color = BAR_COLORS[i]
		pad.style = Pad.Style.PRESS
		pad.position = Vector2(BAR_X0 + BAR_STEP * i, BAR_CY)
		# Dokunma alanı tuşlar arası boşluğu da kapsar: kaydırırken tuştan tuşa kesintisiz geçilir
		pad.setup(BAR_TEXTURES[i], BAR_W + 16.0, Vector2(BAR_STEP, bar_height(i) + 44.0))
		add_pad(pad)
	_marker = Node2D.new()
	_marker.visible = false
	add_child(_marker)
	var star := Sprite2D.new()
	star.texture = TEX_MARKER
	star.scale = Vector2.ONE * 60.0 / TEX_MARKER.get_width()
	_marker.add_child(star)
	_mallet_layer = Node2D.new()
	add_child(_mallet_layer)
	_build_book()
	song_player = SongPlayer.new()
	add_child(song_player)
	song_player.target_changed.connect(_on_target_changed)
	song_player.finished.connect(_on_song_finished)
	song_player.replay_note.connect(_on_replay_note)
	for song in SONGS:
		for problem in song.problems():
			push_error("Müzik Kutusu: " + problem)


func _build_book() -> void:
	_book = Node2D.new()
	_book.position = BOOK_CENTER
	add_child(_book)
	_book_art = Sprite2D.new()
	_book_art.texture = TEX_BOOK
	_book_art.scale = Vector2.ONE * BOOK_SIZE / TEX_BOOK.get_width()
	_book.add_child(_book_art)
	_badge = Sprite2D.new()
	_badge.position = Vector2(46, 40)
	_badge.visible = false
	_book.add_child(_badge)


func book_contains(global_point: Vector2) -> bool:
	return is_visible_in_tree() and to_local(global_point).distance_to(BOOK_CENTER) <= BOOK_SIZE * 0.62


func pad_index(pad: Pad) -> int:
	return pads.find(pad)


# --- Dokunma ---

func touch_down(index: int, at: Vector2) -> void:
	song_player.stop_replay()
	if book_contains(at):
		_fingers[index] = null
		next_song()
		return
	_last_point[index] = at
	_show_mallet(index, at)
	super.touch_down(index, at)


func touch_move(index: int, at: Vector2) -> void:
	if not _last_point.has(index):
		return
	var from: Vector2 = _last_point[index]
	_last_point[index] = at
	_move_mallet(index, at)
	# Yol küçük adımlarla taranır: parmağın geçtiği her tuş, geçiş sırasıyla çalar
	var steps := maxi(1, ceili(from.distance_to(at) / GLISS_STEP))
	for k in range(1, steps + 1):
		var point := from.lerp(at, float(k) / steps)
		var pad := pad_at(point)
		if pad != _fingers.get(index):
			_fingers[index] = pad
			if pad:
				play_pad(pad, point)


func touch_up(index: int) -> void:
	super.touch_up(index)
	_last_point.erase(index)
	_hide_mallet(index)


func play_pad(pad: Pad, at: Vector2, pitch: float = 1.0) -> void:
	super.play_pad(pad, at, pitch)
	song_player.on_bar(pad_index(pad))


# --- Tokmak ---

func _show_mallet(index: int, at: Vector2) -> void:
	var mallet: Node2D = _mallets.get(index)
	if mallet == null:
		mallet = Node2D.new()
		var sprite := Sprite2D.new()
		sprite.texture = TEX_MALLET
		sprite.scale = Vector2.ONE * MALLET_WIDTH / TEX_MALLET.get_width()
		# Tokmağın topu (tuvalde 60, 56) düğümün merkezinde olsun
		sprite.position = Vector2(0, 150.0 - 56.0) * MALLET_WIDTH / 120.0
		mallet.add_child(sprite)
		_mallet_layer.add_child(mallet)
		_mallets[index] = mallet
	mallet.position = to_local(at)
	mallet.modulate.a = 1.0
	mallet.show()
	# Vuruş: tokmak yukarıdan tuşa iner
	mallet.rotation = -0.95
	var tween := mallet.create_tween()
	tween.tween_property(mallet, "rotation", -0.45, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(mallet, "rotation", -0.55, 0.12).set_trans(Tween.TRANS_SINE)


func _move_mallet(index: int, at: Vector2) -> void:
	var mallet: Node2D = _mallets.get(index)
	if mallet:
		mallet.position = to_local(at)


func _hide_mallet(index: int) -> void:
	var mallet: Node2D = _mallets.get(index)
	if mallet:
		var tween := mallet.create_tween()
		tween.tween_property(mallet, "modulate:a", 0.0, 0.25)
		tween.tween_callback(mallet.hide)


# --- Şarkı modu ---

# Şarkı çalarken: sıradaki şarkı (sonuncudan sonra şarkı modu kapanır). Şarkı yokken (kapalı ya da biri
# bitmiş): en son çalınanın ardından gelen şarkı başlar.
func next_song() -> void:
	if song_player.is_playing():
		_song_index += 1
	else:
		_song_index = (_song_index + 1) % SONGS.size()
	if _song_index >= SONGS.size():
		_song_index = -1
		song_player.stop()
		_badge.visible = false
	else:
		var song := SONGS[_song_index]
		_badge.texture = song.icon
		_badge.scale = Vector2.ONE * 64.0 / song.icon.get_width()
		_badge.visible = true
		song_player.start(song)
		song_started.emit(song)
	_pop(_book)


func current_song() -> MusicSong:
	return song_player.song


func _on_target_changed(bar: int) -> void:
	for k in pads.size():
		pads[k].set_target(k == bar)
	_marker.visible = bar >= 0
	if bar >= 0:
		_marker.set_meta("x", pads[bar].position.x)
		_marker.set_meta("y", BAR_CY - bar_height(bar) / 2.0 - 34.0)
		_marker.position = Vector2(_marker.get_meta("x"), _marker.get_meta("y"))
		_pop(_marker)


func _on_song_finished(song: MusicSong) -> void:
	_badge.visible = false
	sounds.play("kutlama")
	song_finished.emit(song)
	# Kutlamadan sonra şarkı kendi temposuyla bir kez çalınır (dokununca durur)
	song_player.replay(song, 1.6)


func _on_replay_note(bar: int) -> void:
	super.play_pad(pads[bar], pads[bar].touch_center())


func invite() -> void:
	var bar := song_player.target()
	if bar >= 0:
		pads[bar].invite()
	elif randf() < 0.25:
		_pop(_book)
	else:
		super.invite()


func release_all() -> void:
	for index in _last_point.keys():
		_hide_mallet(index)
	_last_point.clear()
	song_player.stop_replay()
	super.release_all()


func _pop(node: Node2D) -> void:
	node.scale = Vector2(0.8, 0.8)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# Defter hafifçe nefes alır (dikkat çeksin); şarkı açıkken rozet sallanır
	_time += delta
	_book_art.rotation = sin(_time * 1.6) * 0.05
	if _badge.visible:
		_badge.rotation = sin(_time * 3.0) * 0.15
	if _marker.visible:
		_marker.position = Vector2(_marker.get_meta("x"), _marker.get_meta("y") - absf(sin(_time * 5.0)) * 16.0)
		_marker.rotation = sin(_time * 2.5) * 0.2
