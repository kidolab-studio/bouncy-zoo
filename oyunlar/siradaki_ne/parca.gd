extends "res://ortak/suruklenebilir.gd"
# Örüntü parçası (PatternPiece): dizide duran ya da tepsiden sürüklenen bir boncuk, bayrak, çiçek, tırtıl
# halkası ya da hayvan. Yakalanma, parmağı izleme, yerine dönme, gelme/gitme ve zıplama ortak
# DraggableItem'dan (ortak/suruklenebilir.gd), dokunma ortak DragInput'tan gelir.
# Dizideki parçalar baştan yerleşmiştir (placed); tepsidekiler doğru boşluğa oturunca yerleşir.

const PIECE_DIR := "res://oyunlar/siradaki_ne/gorseller/parcalar/%s.svg"

var symbol: String = ""
var note: int = 0
## Yerine oturdu (ya da baştan dizide): artık tutulamaz
var placed: bool = false
## Yerine kayıyor: bu sırada zıplamaz (oturma animasyonu kesilmesin, oturunca çağrılan işlev çalışsın)
var settling: bool = false
var sprite: Sprite2D

var _glow: Tween


func setup_piece(piece_symbol: String, piece_note: int, visual: float, grab: float, start: Vector2) -> void:
	symbol = piece_symbol
	note = piece_note
	sprite = Sprite2D.new()
	sprite.texture = load(PIECE_DIR % symbol)
	sprite.scale = Vector2.ONE * visual / sprite.texture.get_width()
	add_child(sprite)
	setup_drag(grab, start)


func can_grab() -> bool:
	return not placed and visible


# Yerine yumuşakça kayar ve oturur (on_landed: oturunca çağrılır)
func seat(target: Vector2, duration: float, on_landed: Callable = Callable()) -> void:
	placed = true
	settling = true
	dragging = false
	home = target
	var tween := _new_tween()
	tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "rotation", 0.0, duration)
	tween.tween_property(self, "scale", Vector2(1.1, 0.88), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		z_index = Z_IDLE
		settling = false)
	if on_landed.is_valid():
		tween.tween_callback(on_landed)


# Yanlış boşluğa bırakıldı: hafifçe sallanır ve yumuşakça tepsideki yerine döner
func bounce_back(duration: float) -> void:
	return_home(duration, true)


# İpucu: birkaç kez parlar ve kıpırdar
func glow() -> void:
	if _glow:
		_glow.kill()
	_glow = create_tween()
	for k in 3:
		_glow.tween_property(self, "modulate", Color(1.45, 1.45, 1.3), 0.22).set_trans(Tween.TRANS_SINE)
		_glow.tween_property(self, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_SINE)
	wiggle()


# Dizinin çalınmasında: zıplar (sesi tema çalar)
func bounce() -> void:
	if settling or dragging:
		return
	var tween := _new_tween()
	var base := home
	tween.tween_property(self, "position", base + Vector2(0.0, -size * 0.22), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.94, 1.08), 0.13)
	tween.tween_property(self, "position", base, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.22)


func stop_tween() -> void:
	if _tween:
		_tween.kill()
