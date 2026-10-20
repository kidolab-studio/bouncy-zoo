extends SceneTree
# Araba Yarışı yarış testi (headless). Proje kökünden:
#   godot --headless --fixed-fps 60 --path . -s res://oyunlar/araba_yarisi/testler/yaris_testi.gd [-- <pist no>]
# 1) Pist verilerini doğrular (pistler.gd validate) ve her pistin tahmini süresini yazar.
# 2) Her pisti üç çocuk tipiyle koşturur: "tam" hep basar, "ara" 3 sn basıp 1.5 sn bırakır,
#    "az" 1.5 sn basıp 3 sn bırakır. Beklenen: tam ve ara birinci olur, tam bütün yıldızları toplar.
# Hata varsa çıkış kodu 1. user://araba_yarisi.cfg yedeklenir ve sonunda geri yazılır.

const Pistler := preload("res://oyunlar/araba_yarisi/pistler.gd")
const PistScript := preload("res://oyunlar/araba_yarisi/pist.gd")
const SAVE := "user://araba_yarisi.cfg"

var game: Node
var failures := 0
var _backup := PackedByteArray()
var _had_save := false


func _initialize() -> void:
	# Önceki çalışmadan kalan "tamamlandı" (final ekranı) testi bozmasın: sonunda eski hali geri yazılır
	var bitmisti := OyunBitti.tamamlandi_mi("araba_yarisi")
	OyunBitti.sifirla("araba_yarisi")
	_save_backup(SAVE)
	root.content_scale_size = Vector2i(1280, 720)
	var errors := Pistler.validate(PistScript)
	for error in errors:
		_fail(error)
	for i in Pistler.TRACKS.size():
		var info := PistScript.summary(i)
		print("pist %d: tam gazla ~%.0f sn, %d yıldız" % [i + 1, info["seconds"], info["stars"]])
	game = load("res://oyunlar/araba_yarisi/araba_yarisi.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var tracks: Array = range(Pistler.TRACKS.size()) if args.is_empty() else [int(args[0]) - 1]
	for index in tracks:
		for kind in ["tam", "ara", "az"]:
			await _race(index, kind)
	game.queue_free()
	await process_frame
	_save_restore(SAVE)
	print("SONUÇ: ", "hepsi geçti" if failures == 0 else "%d hata" % failures)
	if bitmisti:
		OyunBitti.tamamla("araba_yarisi")
	else:
		OyunBitti.sifirla("araba_yarisi")
	quit(1 if failures > 0 else 0)


# Kullanıcının kaydı test boyunca yedekte durur, sonunda geri yazılır (kayıt yoksa testin yazdığı silinir)
func _save_backup(path: String) -> void:
	if FileAccess.file_exists(path):
		_backup = FileAccess.get_file_as_bytes(path)
		_had_save = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _save_restore(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _had_save:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()


func _race(index: int, kind: String) -> void:
	game._busy = false
	game._start_race(index)
	var player: Node2D = game._cars[0]
	var time := 0.0
	var racing := 0.0
	var visible := 0.0
	while time < 300.0:
		var cycle := fmod(time, 4.5)
		var hold := kind == "tam" or (kind == "ara" and cycle < 3.0) or (kind == "az" and cycle < 1.5)
		if hold:
			game._touches[0] = true
		else:
			game._touches.erase(0)
		await process_frame
		time += 1.0 / 60.0
		if game._race_state == game.RaceState.RACING:
			racing += 1.0 / 60.0
			for k in [1, 2]:
				var gap: float = game._cars[k].s - player.s
				if gap > -420.0 and gap < 900.0:
					visible += 0.5 / 60.0
		if game._race_state == game.RaceState.FINISHED:
			break
	var rank: int = game._finish_order.find(player) + 1
	var stars: int = game._stars_taken
	var total: int = game._track.stars.size()
	print("pist %d %-3s: %5.1f sn, sıra %d, yıldız %d/%d, rakip ekranda %%%.0f" % [
			index + 1, kind, racing, rank, stars, total, 100.0 * visible / maxf(racing, 0.01)])
	if rank == 0:
		_fail("pist %d %s: yarış bitmedi" % [index + 1, kind])
	if kind != "az" and rank != 1:
		_fail("pist %d %s: çocuk birinci olmalıydı" % [index + 1, kind])
	if kind == "tam" and stars < total:
		_fail("pist %d: tam gazla bütün yıldızlar alınmalıydı" % [index + 1])
	game._touches.clear()
	game._screen = game.Screen.MAP


func _fail(message: String) -> void:
	failures += 1
	printerr("HATA: ", message)
