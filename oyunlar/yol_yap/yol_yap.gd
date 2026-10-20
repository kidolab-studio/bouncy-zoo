extends Control
# Yol Yap: tepsideki parçaları sürükleyip yolu tamamla, bilye hediye kutusuna yuvarlansın.
# Bölümler bolumler.gd içinde, bilyenin yol hesabı yol_mantigi.gd içinde.

const Logic := preload("res://oyunlar/yol_yap/yol_mantigi.gd")
const Levels := preload("res://oyunlar/yol_yap/bolumler.gd")
const HoldButton := preload("res://ortak/basili_geri_dugmesi.gd")

enum State { SELECT, PLAYING, ROLLING, CELEBRATING, FINISHED }

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

## Bilyenin yuvarlanma hızı (hücre/saniye).
@export var roll_speed: float = 2.5
## Bölüm sonu kutlamasının süresi (saniye); sonra sonraki bölüme geçilir.
@export var celebration_time: float = 2.0
## Parça doğru yere bu kadar yakın bırakılırsa oturur (hücre boyuna oranla).
@export_range(0.3, 1.0) var snap_distance: float = 0.7

const PIECE_TEXTURES := {
	"blok": preload("res://oyunlar/yol_yap/gorseller/blok.svg"),
	"rampa_sag": preload("res://oyunlar/yol_yap/gorseller/rampa.svg"),
	"rampa_sol": preload("res://oyunlar/yol_yap/gorseller/rampa.svg"),  # yatayda çevrilerek çizilir
	"kopru": preload("res://oyunlar/yol_yap/gorseller/kopru.svg"),
	"yay": preload("res://oyunlar/yol_yap/gorseller/yay.svg"),
}
const TEX_GRASS: Texture2D = preload("res://oyunlar/yol_yap/gorseller/zemin_cim.svg")
const TEX_DIRT: Texture2D = preload("res://oyunlar/yol_yap/gorseller/zemin_toprak.svg")
const TEX_WALL: Texture2D = preload("res://oyunlar/yol_yap/gorseller/duvar.svg")
const TEX_WATER: Texture2D = preload("res://oyunlar/yol_yap/gorseller/su.svg")
const TEX_STAR: Texture2D = preload("res://oyunlar/yol_yap/gorseller/yildiz.svg")
const TEX_LOCK: Texture2D = preload("res://oyunlar/yol_yap/gorseller/kilit.svg")

const SAVE_PATH := "user://yol_yap.cfg"
const WORDS := ["Harika!", "Süper!", "Tebrikler!"]
const RAINBOW := [Color("ff5a5a"), Color("ff9f40"), Color("ffc93d"), Color("5cc95c"), Color("4fa8ff"), Color("a66bff")]
const TEXTURE_CELL := 100.0      # SVG'lerde bir hücre 100 piksel
const BOARD_TOP := 130.0         # ızgaranın başlayabileceği en üst nokta (düğmelerin altı)
const TRAY_WIDTH := 250.0        # parça tepsisi ekranın sağında dikey bir şerit
const TRAY_TOP := 190.0
const SCREEN_MARGIN := 30.0
const NO_CELL := Vector2i(-1, -1)

@onready var game: Control = $Game
@onready var board: Node2D = $Game/Board
@onready var terrain: Node2D = $Game/Board/Terrain
@onready var hints: Node2D = $Game/Board/Hints
@onready var goal_box: Sprite2D = $Game/Board/Goal/Box
@onready var goal_lid: Sprite2D = $Game/Board/Goal/Lid
@onready var tray: Panel = $Game/Tray
@onready var piece_layer: Node2D = $Game/PieceLayer
@onready var ball: Sprite2D = $Game/Ball
@onready var effects: Node2D = $Game/Effects
@onready var back_panel: Panel = $Game/BackButton
@onready var select_back_panel: Panel = $LevelSelect/BackButton
var back_button: Control
var select_back_button: Control
@onready var restart_button: Panel = $Game/RestartButton
@onready var level_label: Label = $Game/LevelBadge/Label
@onready var cheer: HBoxContainer = $Game/Cheer
@onready var replay_button: Panel = $Game/ReplayButton
@onready var level_select: Control = $LevelSelect
@onready var level_grid: GridContainer = $LevelSelect/Grid

var state: State = State.SELECT
var completed: int = 0             # sırayla bitirilen bölüm sayısı (kaydedilir)
var level_index: int = 0
var level: Dictionary = {}
var cell_size: float = 100.0
var ball_radius: float = 30.0
var board_origin := Vector2.ZERO
var lid_rest := Vector2.ZERO
var pieces: Array[Node2D] = []
var dragging: Node2D = null
var drag_offset := Vector2.ZERO
var drag_touch_index: int = -1
var run_id: int = 0                # bölüm değişince eski animasyonların devam etmemesi için
var level_tweens: Array[Tween] = []
var level_buttons: Array[Panel] = []
var pulse_tween: Tween


func _ready() -> void:
	SesYoneticisi.muzik("yol_yap", self)
	back_button = HoldButton.replace(back_panel)
	back_button.completed.connect(_on_back_completed)
	select_back_button = HoldButton.replace(select_back_panel)
	select_back_button.completed.connect(_on_select_back_completed)
	# Çentikli telefonlarda köşe düğmeleri çentiğin altında kalmasın (geri + yeniden başlat birlikte kayar)
	EkranYardimcisi.guvenliye_it_grup([back_button, restart_button])
	EkranYardimcisi.guvenliye_it(level_label.get_parent())
	_check_levels()
	_load_progress()
	_create_level_buttons()
	hints.draw.connect(_draw_hints)
	# İpucu çizgileri yavaşça parlayıp sönsün
	var hint_pulse := hints.create_tween().set_loops()
	hint_pulse.tween_property(hints, "modulate:a", 0.45, 0.8)
	hint_pulse.tween_property(hints, "modulate:a", 1.0, 0.8)
	_show_level_select()
	IpucuEli.ekle(self, "yol_yap", _ipucu)


# İpucu eli: tepsideki bir parçayı onun boş hedef hücresine sürükle
func _ipucu() -> Dictionary:
	if state != State.PLAYING or dragging != null:
		return {}
	for piece in pieces:
		if piece.get_meta("cell") != NO_CELL:
			continue
		for p: Dictionary in level["pieces"]:
			if p["type"] == piece.get_meta("type") and not _cell_taken(p["cell"], piece):
				var orta: Vector2 = piece.get_meta("size") / 2.0
				return IpucuEli.surukle(piece.get_global_transform_with_canvas() * orta,
					piece_layer.get_global_transform_with_canvas() * (_cell_position(p["cell"]) + orta))
	return {}


func _exit_tree() -> void:
	SesYoneticisi.dongu_durdur("bilye_yuvarlanma", 0.1)


# Her bölümün çözülebilir olduğunu kontrol et
func _check_levels() -> void:
	for i in Levels.LIST.size():
		var error := Logic.validate(Levels.LIST[i])
		if error != "":
			push_error("Yol Yap bölüm %d: %s" % [i + 1, error])


# --- Dokunma ---

func _input(event: InputEvent) -> void:
	# Sadece dokunma ile oynanır (bilgisayarda fare dokunmaya çevrilir)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		# Geri düğmeleri basılı tutulur: bölüm seçmede ana menüye, oyunda bölüm seçmeye döner
		var back: Control = select_back_button if state == State.SELECT else back_button
		if back.handle_touch(touch):
			return
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		elif touch.index == drag_touch_index and dragging != null:
			_drop()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == drag_touch_index and dragging != null:
			dragging.position = drag.position + drag_offset


func _on_touch_down(index: int, pos: Vector2) -> void:
	if dragging != null:
		return  # aynı anda tek parça sürüklenir
	match state:
		State.SELECT:
			for i in level_buttons.size():
				if _is_touched(level_buttons[i], pos):
					if i <= completed:
						SesYoneticisi.efekt("dugme_tik")
						_start_level(i)
					else:
						SesYoneticisi.efekt("yumusak_hayir")
						_shake(level_buttons[i])
					return
			return
		State.FINISHED:
			if _is_touched(replay_button, pos):
				SesYoneticisi.efekt("basari")
				_start_level(0)
				return

	if _is_touched(restart_button, pos):
		SesYoneticisi.efekt("dugme_tik")
		_start_level(level_index)
	elif state == State.PLAYING:
		var piece := _piece_at(pos)
		if piece != null:
			_pick_up(piece, index, pos)


func _on_select_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	SahneGecis.ana_menuye_don()


func _on_back_completed() -> void:
	SesYoneticisi.efekt("geri")
	back_button.reset()
	_show_level_select()


func _is_touched(control: Control, pos: Vector2) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(pos)


# --- Ekranlar ---

func _show_level_select() -> void:
	_stop_level_animations()
	state = State.SELECT
	game.visible = false
	level_select.visible = true
	_update_level_buttons()


func _start_level(index: int) -> void:
	_stop_level_animations()
	if pulse_tween:
		pulse_tween.kill()
	level_index = index
	level = Levels.LIST[index]
	state = State.PLAYING
	level_select.visible = false
	game.visible = true
	cheer.visible = false
	replay_button.visible = false
	for child in effects.get_children():
		child.queue_free()
	for child in cheer.get_children():
		child.queue_free()

	_layout_board()
	_build_terrain()
	_build_goal()
	_build_pieces()
	_reset_ball()
	hints.queue_redraw()
	level_label.text = str(index + 1)


func _stop_level_animations() -> void:
	SesYoneticisi.dongu_durdur("bilye_yuvarlanma", 0.1)
	run_id += 1
	for tween in level_tweens:
		if tween.is_valid():
			tween.kill()
	level_tweens.clear()
	dragging = null
	drag_touch_index = -1


func _level_tween() -> Tween:
	var tween := create_tween()
	level_tweens.append(tween)
	return tween


# --- Bölümü kurma ---

func _layout_board() -> void:
	var screen := get_viewport_rect().size
	var map_dims := Logic.map_size(level)
	var left := EkranYardimcisi.kenar_payi(SIDE_LEFT, SCREEN_MARGIN)
	var right := EkranYardimcisi.kenar_payi(SIDE_RIGHT, SCREEN_MARGIN)
	# Geniş telefonlarda ızgara ve tepsi kenarlara dağılmasın: tasarım genişliğinde, ekranın ortasında dururlar
	var width := minf(screen.x - left - right, EkranYardimcisi.tasarim_boyutu().x - 2.0 * SCREEN_MARGIN)
	var area_left := left + (screen.x - left - right - width) / 2.0
	var tray_left := area_left + width - TRAY_WIDTH
	var board_bottom := screen.y - EkranYardimcisi.kenar_payi(SIDE_BOTTOM, 40.0)
	var available := Vector2(tray_left - 20.0 - area_left, board_bottom - BOARD_TOP)
	# Haritanın üstündeki boş satırlar yer kaplamasın: ızgara sadece dolu satırlar + 2 satır boşlukla ölçeklenir
	var visible_rows := mini(map_dims.y, map_dims.y - _empty_top_rows() + 2)
	cell_size = floorf(minf(minf(available.x / map_dims.x, available.y / visible_rows), 110.0))
	var board_size := Vector2(map_dims) * cell_size
	# Izgara tepsinin solunda, kalan alanda ortada ve altta dursun
	board_origin = Vector2(area_left + (available.x - board_size.x) / 2.0, board_bottom - board_size.y)
	board.position = board_origin
	tray.position = Vector2(tray_left, TRAY_TOP)
	tray.size = Vector2(TRAY_WIDTH, board_bottom - TRAY_TOP)


# Üstten kaç satır tamamen boş (parçaların yerleri de dolu sayılır)
func _empty_top_rows() -> int:
	var map: Array = level["map"]
	var top := map.size()
	for r in map.size():
		if (map[r] as String).strip_edges().replace(".", "") != "":
			top = r
			break
	for piece in level["pieces"]:
		top = mini(top, (piece["cell"] as Vector2i).y)
	return top


func _build_terrain() -> void:
	for child in terrain.get_children():
		child.queue_free()
	var map: Array = level["map"]
	for r in map.size():
		var row: String = map[r]
		for c in row.length():
			var ch := row[c]
			var texture: Texture2D = null
			if ch == Logic.GROUND:
				texture = TEX_GRASS if _is_open(c, r - 1) else TEX_DIRT
			elif ch == Logic.WALL:
				texture = TEX_WALL
			elif ch == Logic.WATER:
				texture = TEX_WATER
			if texture != null:
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.scale = _piece_scale()
				sprite.position = (Vector2(c, r) + Vector2(0.5, 0.5)) * cell_size
				terrain.add_child(sprite)


# Hücre gökyüzü mü (üstündeki zemine çim çizmek için)
func _is_open(c: int, r: int) -> bool:
	if r < 0:
		return true
	var ch := (level["map"][r] as String)[c]
	return ch == Logic.EMPTY or ch == Logic.START or ch == Logic.GOAL


func _build_goal() -> void:
	var goal := Logic.find_char(level, Logic.GOAL)
	var sc := cell_size / TEXTURE_CELL * 0.8
	goal_box.scale = Vector2(sc, sc)
	goal_lid.scale = Vector2(sc, sc)
	var box_height := goal_box.texture.get_height() * sc
	var bottom := (goal.y + 1) * cell_size - 2.0
	var x := (goal.x + 0.5) * cell_size
	goal_box.position = Vector2(x, bottom - box_height / 2.0)
	# Kapağın alt kenarı kutunun üst kenarına otursun
	lid_rest = Vector2(x, bottom - box_height - 24.0 * sc)
	goal_lid.position = lid_rest
	goal_lid.rotation = 0.0


func _build_pieces() -> void:
	for piece in pieces:
		piece.queue_free()
	pieces.clear()

	var types: Array = []
	for p: Dictionary in level["pieces"]:
		types.append(p["type"])
	types.shuffle()

	# Tepside alt alta ve ortalı dizilsin
	var gap := 18.0
	var total := (cell_size + gap) * types.size() - gap
	var y := tray.position.y + (tray.size.y - total) / 2.0
	for type: String in types:
		var piece := _make_piece(type)
		var x := tray.position.x + (tray.size.x - _piece_width(type) * cell_size) / 2.0
		piece.position = Vector2(x, y)
		piece.set_meta("home", piece.position)
		y += cell_size + gap


func _make_piece(type: String) -> Node2D:
	var piece := Node2D.new()
	var piece_size := Vector2(_piece_width(type) * cell_size, cell_size)
	var sprite := Sprite2D.new()
	sprite.texture = PIECE_TEXTURES[type]
	sprite.flip_h = type == Logic.RAMP_LEFT
	sprite.scale = _piece_scale()
	sprite.position = piece_size / 2.0
	piece.add_child(sprite)
	piece.set_meta("type", type)
	piece.set_meta("size", piece_size)
	piece.set_meta("cell", NO_CELL)
	piece_layer.add_child(piece)
	pieces.append(piece)
	return piece


func _piece_width(type: String) -> int:
	return 2 if type == Logic.BRIDGE else 1


func _piece_scale() -> Vector2:
	return Vector2.ONE * cell_size / TEXTURE_CELL


func _reset_ball() -> void:
	ball_radius = cell_size * 0.3
	var s := ball_radius * 2.0 / TEXTURE_CELL
	ball.scale = Vector2(s, s)
	ball.rotation = 0.0
	ball.modulate.a = 1.0
	var start := Logic.find_char(level, Logic.START)
	ball.position = _ball_center({"p": Vector2(start.x + 0.5, start.y + 1.0), "n": Logic.UP})


# İlk bölümlerde parçaların gideceği yerleri kesikli çizgiyle göster
func _draw_hints() -> void:
	if level.is_empty() or not level.get("hints", false):
		return
	var s := cell_size
	var line_color := Color(1, 1, 1, 0.95)
	var fill_color := Color(1, 1, 1, 0.25)
	for p: Dictionary in level["pieces"]:
		if _cell_taken(p["cell"], null):
			continue  # parça yerleşti, ipucuna gerek yok
		var o := Vector2(p["cell"]) * s
		var type: String = p["type"]
		var shape := PackedVector2Array([o, o + Vector2(s, 0), o + Vector2(s, s), o + Vector2(0, s)])
		if type == Logic.RAMP_RIGHT:
			shape = PackedVector2Array([o + Vector2(0, s), o + Vector2(s, s), o + Vector2(s, 0)])
		elif type == Logic.RAMP_LEFT:
			shape = PackedVector2Array([o, o + Vector2(s, s), o + Vector2(0, s)])
		elif type == Logic.BRIDGE:
			shape = PackedVector2Array([o, o + Vector2(2 * s, 0), o + Vector2(2 * s, 0.4 * s), o + Vector2(0, 0.4 * s)])
		hints.draw_colored_polygon(shape, fill_color)
		for i in shape.size():
			hints.draw_dashed_line(shape[i], shape[(i + 1) % shape.size()], line_color, 5.0, 14.0)
		if type == Logic.SPRING:
			# Yay ipucunun içine zikzak
			var zigzag := PackedVector2Array()
			for k in 6:
				zigzag.append(o + Vector2(0.3 * s if k % 2 == 0 else 0.7 * s, (0.8 - k * 0.12) * s))
			hints.draw_polyline(zigzag, line_color, 4.0)


# --- Sürükle bırak ---

func _piece_at(pos: Vector2) -> Node2D:
	# En üstteki parçadan başla
	for i in range(piece_layer.get_child_count() - 1, -1, -1):
		var piece := piece_layer.get_child(i) as Node2D
		if piece.is_queued_for_deletion():
			continue
		var rect := Rect2(piece.position, piece.get_meta("size")).grow(14.0)
		if rect.has_point(pos):
			return piece
	return null


func _pick_up(piece: Node2D, index: int, pos: Vector2) -> void:
	dragging = piece
	drag_touch_index = index
	drag_offset = piece.position - pos
	piece.set_meta("cell", NO_CELL)  # yerleştirilmişse geri alındı
	piece_layer.move_child(piece, -1)
	SesYoneticisi.efekt("pop", -6.0)
	hints.queue_redraw()
	_level_tween().tween_property(_sprite_of(piece), "scale", _piece_scale() * 1.1, 0.1)


func _drop() -> void:
	var piece := dragging
	dragging = null
	drag_touch_index = -1
	var sprite := _sprite_of(piece)
	var target := _find_target(piece)
	var tween := _level_tween()
	if target != NO_CELL:
		# Hücreye otur ve hafifçe esne
		SesYoneticisi.efekt("tahta_tok")
		piece.set_meta("cell", target)
		tween.tween_property(piece, "position", _cell_position(target), 0.1)
		tween.parallel().tween_property(sprite, "scale", _piece_scale(), 0.1)
		tween.tween_property(sprite, "scale", _piece_scale() * Vector2(1.1, 0.9), 0.07)
		tween.tween_property(sprite, "scale", _piece_scale(), 0.1)
		hints.queue_redraw()
		_check_complete()
	else:
		# Yanlış yer: ceza yok, yumuşakça tepsiye döner
		SesYoneticisi.efekt("hisirti")
		tween.tween_property(piece, "position", piece.get_meta("home"), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", _piece_scale(), 0.2)


# Aynı türden, boş ve yeterince yakın bir hedef hücre bul
func _find_target(piece: Node2D) -> Vector2i:
	var best := NO_CELL
	var best_distance := cell_size * snap_distance
	for p: Dictionary in level["pieces"]:
		if p["type"] != piece.get_meta("type") or _cell_taken(p["cell"], piece):
			continue
		var distance := piece.position.distance_to(_cell_position(p["cell"]))
		if distance < best_distance:
			best = p["cell"]
			best_distance = distance
	return best


func _cell_taken(cell: Vector2i, except: Node2D) -> bool:
	for piece in pieces:
		if piece != except and piece.get_meta("cell") == cell:
			return true
	return false


func _cell_position(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell) * cell_size


func _sprite_of(piece: Node2D) -> Sprite2D:
	return piece.get_child(0) as Sprite2D


func _current_placements() -> Array:
	var list := []
	for piece in pieces:
		list.append({"type": piece.get_meta("type"), "cell": piece.get_meta("cell")})
	return list


func _check_complete() -> void:
	for piece in pieces:
		if piece.get_meta("cell") == NO_CELL:
			return
	state = State.ROLLING
	_roll_ball()


# --- Bilyenin yolculuğu ---

func _roll_ball() -> void:
	var my_run := run_id
	await get_tree().create_timer(0.4).timeout
	if my_run != run_id:
		return

	var result := Logic.simulate(level, _current_placements())
	var points: Array = result["points"]
	var reached: bool = result["ok"]
	# Hedefe ulaşıyorsa son adımda kutuya zıplayarak girecek
	var end_index := points.size() - 1 if reached else points.size()
	var last := ball.position
	var rot := ball.rotation
	var tween := _level_tween()
	tween.tween_interval(0.01)
	for i in range(1, end_index):
		var point: Dictionary = points[i]
		var center := _ball_center(point)
		var distance := last.distance_to(center)
		var time := maxf(distance / (roll_speed * cell_size), 0.05)
		tween.tween_callback(_rolling_sound.bind(point["kind"] != "fall" and point["kind"] != "jump"))
		match point["kind"]:
			"fall":
				tween.tween_property(ball, "position", center, time * 0.7) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			"jump":
				tween.tween_callback(_squash_spring.bind(_support_cell(points[i - 1])))
				tween.tween_method(_move_on_arc.bind(last, center, cell_size * 1.3), 0.0, 1.0, 0.6)
				rot += TAU * signf(center.x - last.x)
				tween.parallel().tween_property(ball, "rotation", rot, 0.6)
			_:
				# Yuvarlanma: gidilen yol kadar döner
				rot += signf(center.x - last.x) * distance / ball_radius
				tween.tween_property(ball, "position", center, time)
				tween.parallel().tween_property(ball, "rotation", rot, time)
		last = center
	await tween.finished
	_rolling_sound(false)
	if my_run != run_id:
		return

	if reached:
		_enter_gift(my_run, points[points.size() - 1], points[points.size() - 2])
	else:
		_ball_failed(my_run)


func _rolling_sound(on: bool) -> void:
	if on:
		SesYoneticisi.dongu_baslat("bilye_yuvarlanma")
	else:
		SesYoneticisi.dongu_durdur("bilye_yuvarlanma", 0.12)


func _ball_center(point: Dictionary) -> Vector2:
	return board_origin + (point["p"] as Vector2) * cell_size + (point["n"] as Vector2) * ball_radius


func _support_cell(point: Dictionary) -> Vector2i:
	var p: Vector2 = point["p"]
	return Vector2i(floori(p.x), roundi(p.y))


func _move_on_arc(t: float, from: Vector2, to: Vector2, height: float) -> void:
	ball.position = from.lerp(to, t) + Vector2(0, -4.0 * height * t * (1.0 - t))


func _squash_spring(cell: Vector2i) -> void:
	for piece in pieces:
		if piece.get_meta("type") == Logic.SPRING and piece.get_meta("cell") == cell:
			var sprite := _sprite_of(piece)
			SesYoneticisi.efekt("boing_kisa")
			var tween := _level_tween()
			tween.tween_property(sprite, "scale", _piece_scale() * Vector2(1.15, 0.6), 0.08)
			tween.tween_property(sprite, "scale", _piece_scale(), 0.4) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _enter_gift(my_run: int, goal_point: Dictionary, before_goal: Dictionary) -> void:
	# Kapak açılır
	SesYoneticisi.efekt("hediye_acilis")
	var lid_tween := _level_tween()
	lid_tween.tween_property(goal_lid, "position", lid_rest + Vector2(cell_size * 0.4, -cell_size * 0.9), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lid_tween.parallel().tween_property(goal_lid, "rotation", 0.6, 0.35)

	# Bilye kutuya zıplar (son adım yaydan ise yay da esner)
	var box_center := goal_box.global_position
	var box_top := box_center.y - goal_box.texture.get_height() * goal_box.scale.y / 2.0
	var mouth := Vector2(box_center.x, box_top - ball_radius * 0.5)
	var hop := _level_tween()
	hop.tween_interval(0.15)
	if goal_point["kind"] == "jump":
		hop.tween_callback(_squash_spring.bind(_support_cell(before_goal)))
	var height := cell_size * (1.4 if goal_point["kind"] == "jump" else 0.8)
	hop.tween_method(_move_on_arc.bind(ball.position, mouth, height), 0.0, 1.0, 0.5)
	hop.parallel().tween_property(ball, "rotation", ball.rotation + TAU, 0.5)
	hop.tween_property(ball, "position", box_center, 0.2)
	hop.parallel().tween_property(ball, "scale", Vector2.ZERO, 0.2)
	await hop.finished
	if my_run != run_id:
		return

	# Kutudan yıldızlar fışkırır
	_burst_stars(Vector2(box_center.x, box_top))
	var wiggle := _level_tween()
	var box_scale := goal_box.scale
	wiggle.tween_property(goal_box, "scale", box_scale * Vector2(1.15, 0.85), 0.1)
	wiggle.tween_property(goal_box, "scale", box_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_celebrate(my_run)


# Olmaması gerekir (parçalar sadece doğru yere oturur), ama bölüm verisi hatalıysa
# bilye başa döner ve parçalar tepsiye geri gelir.
func _ball_failed(my_run: int) -> void:
	var tween := _level_tween()
	tween.tween_property(ball, "modulate:a", 0.0, 0.3)
	await tween.finished
	if my_run != run_id:
		return
	_reset_ball()
	for piece in pieces:
		piece.set_meta("cell", NO_CELL)
		_level_tween().tween_property(piece, "position", piece.get_meta("home"), 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	state = State.PLAYING


# --- Kutlama ---

func _celebrate(my_run: int) -> void:
	state = State.CELEBRATING
	completed = maxi(completed, level_index + 1)
	_save_progress()

	if level_index == Levels.LIST.size() - 1:
		# Son bölüm: daha büyük kutlama ve "Tekrar oyna" düğmesi
		_show_cheer(tr("Tebrikler!"), true)
		SesYoneticisi.ezgi("kutlama")
		for wave in 3:
			_spawn_confetti(90)
			await get_tree().create_timer(0.7).timeout
			if my_run != run_id:
				return
		state = State.FINISHED
		replay_button.visible = true
		replay_button.pivot_offset = replay_button.size / 2.0
		replay_button.scale = Vector2.ZERO
		_level_tween().tween_property(replay_button, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_show_cheer(tr(WORDS.pick_random()), false)
		SesYoneticisi.ezgi("tamamlandi")
		_spawn_confetti(70)
		await get_tree().create_timer(celebration_time).timeout
		if my_run != run_id:
			return
		_start_level(level_index + 1)


# Gökkuşağı renkli, harf harf zıplayarak beliren yazı
func _show_cheer(word: String, big: bool) -> void:
	for child in cheer.get_children():
		child.queue_free()
	cheer.visible = true
	for i in word.length():
		var letter := Label.new()
		letter.text = word[i]
		letter.add_theme_font_size_override("font_size", 110 if big else 100)
		letter.add_theme_color_override("font_color", RAINBOW[i % RAINBOW.size()])
		letter.add_theme_color_override("font_outline_color", Color("3b2a5a"))
		letter.add_theme_constant_override("outline_size", 24)
		cheer.add_child(letter)
		letter.pivot_offset = letter.get_minimum_size() / 2.0
		letter.scale = Vector2.ZERO
		var tween := letter.create_tween()
		tween.tween_interval(i * 0.07)
		tween.tween_property(letter, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(letter, "scale", Vector2.ONE, 0.12)
		if big:
			# Büyük kutlamada harfler sallanmaya devam eder
			var wiggle := letter.create_tween().set_loops()
			wiggle.tween_property(letter, "rotation", 0.12, 0.3).set_delay(0.6 + i * 0.07)
			wiggle.tween_property(letter, "rotation", -0.12, 0.3)


func _spawn_confetti(count: int) -> void:
	SesYoneticisi.efekt("konfeti", -4.0)
	var screen := get_viewport_rect().size
	for i in count:
		var bit := Polygon2D.new()
		var w := randf_range(5.0, 9.0)
		var h := randf_range(8.0, 13.0)
		bit.polygon = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
		bit.color = RAINBOW.pick_random()
		_fall_from_sky(bit, screen)
	# Konfetinin arasında yıldızlar da yağsın
	for i in int(count / 8.0):
		var star := Sprite2D.new()
		star.texture = TEX_STAR
		star.scale = Vector2.ONE * randf_range(0.3, 0.5)
		_fall_from_sky(star, screen)


func _fall_from_sky(node: Node2D, screen: Vector2) -> void:
	node.position = Vector2(randf_range(0.0, screen.x), randf_range(-300.0, -20.0))
	node.rotation = randf() * TAU
	effects.add_child(node)
	var time := randf_range(1.6, 2.6)
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position", node.position + Vector2(randf_range(-120.0, 120.0), screen.y + 350.0), time) \
		.set_delay(randf() * 0.4)
	tween.tween_property(node, "rotation", node.rotation + randf_range(-8.0, 8.0), time)
	tween.chain().tween_callback(node.queue_free)


func _burst_stars(center: Vector2) -> void:
	for i in 10:
		var star := Sprite2D.new()
		star.texture = TEX_STAR
		star.position = center
		star.scale = Vector2.ONE * 0.1
		effects.add_child(star)
		var angle := deg_to_rad(randf_range(-165.0, -15.0))
		var target := center + Vector2.from_angle(angle) * randf_range(1.5, 3.0) * cell_size
		var tween := star.create_tween().set_parallel()
		tween.tween_property(star, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE * randf_range(0.4, 0.65), 0.3)
		tween.tween_property(star, "rotation", randf_range(-4.0, 4.0), 0.8)
		tween.tween_property(star, "modulate:a", 0.0, 0.4).set_delay(0.6)
		tween.chain().tween_callback(star.queue_free)


# --- Bölüm seçme ekranı ---

func _create_level_buttons() -> void:
	for i in Levels.LIST.size():
		var button := Panel.new()
		button.custom_minimum_size = Vector2(170, 170)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var number := Label.new()
		number.name = "Number"
		number.text = str(i + 1)
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 84)
		number.add_theme_color_override("font_outline_color", Color("3b2a5a"))
		number.add_theme_constant_override("outline_size", 20)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)

		var lock := TextureRect.new()
		lock.name = "Lock"
		lock.texture = TEX_LOCK
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 36)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(lock)

		# Bitirilen bölümün köşesinde yıldız
		var star := TextureRect.new()
		star.name = "Star"
		star.texture = TEX_STAR
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.anchor_left = 1.0
		star.anchor_right = 1.0
		star.offset_left = -62.0
		star.offset_right = 8.0
		star.offset_top = -14.0
		star.offset_bottom = 56.0
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(star)

		level_grid.add_child(button)
		level_buttons.append(button)


func _update_level_buttons() -> void:
	if pulse_tween:
		pulse_tween.kill()
	for i in level_buttons.size():
		var button := level_buttons[i]
		var open := i <= completed
		button.add_theme_stylebox_override("panel", _button_style(RAINBOW[i % RAINBOW.size()] if open else Color("cfcbe0")))
		button.get_node("Number").visible = open
		button.get_node("Lock").visible = not open
		button.get_node("Star").visible = i < completed
		button.scale = Vector2.ONE
		button.rotation = 0.0
	# Sıradaki bölümün düğmesi hafifçe nabız gibi atsın
	var current := level_buttons[mini(completed, level_buttons.size() - 1)]
	current.pivot_offset = current.custom_minimum_size / 2.0
	pulse_tween = current.create_tween().set_loops()
	pulse_tween.tween_property(current, "scale", Vector2(1.08, 1.08), 0.5)
	pulse_tween.tween_property(current, "scale", Vector2.ONE, 0.5)


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(6)
	style.border_color = color.darkened(0.35)
	style.set_corner_radius_all(40)
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 6)
	return style


func _shake(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	for angle in [0.12, -0.12, 0.08, -0.05, 0.0]:
		tween.tween_property(control, "rotation", angle, 0.06)


# --- Kayıt ---

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		completed = int(config.get_value("ilerleme", "tamamlanan", 0))
	completed = clampi(completed, 0, Levels.LIST.size())


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("ilerleme", "tamamlanan", completed)
	GuvenliKayit.save_config(config, SAVE_PATH)
