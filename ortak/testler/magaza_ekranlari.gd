extends SceneTree
# Google Play telefon ekran görüntüleri (pencereli, 1920x1080). Proje kökünden:
#   godot --path . --fixed-fps 60 -s res://ortak/testler/magaza_ekranlari.gd [-- <klasör> [GENxYUK] [oyun ...]]
# Klasör verilmezse .playstore/screenshots/telefon; oyun adları verilirse yalnızca onlar yeniden çekilir.
# GENxYUK verilirse pencere o boyutta açılır (tablet: -- res://.playstore/screenshots/tablet 1920x1200). Sekiz oyunu menüden açar, her birini dolu ve hareketli bir
# anına getirip 01_hayvan_besle.png ... 08_toplama.png kaydeder (alfa kanalsız PNG). Monitör en az 1920x1080
# olmalı (pencere kenarlıksız açılır). user:// kayıtları (.bak dahil) yedeklenir, sonunda eski haline getirilir.
# Görüntülerde dile bağlı yazı yok; aynı set Türkçe ve İngilizce mağaza sayfasında kullanılabilir.

const MENU := "res://ana_menu/ana_menu.tscn"
const Baglanti := preload("res://oyunlar/tren_rayi/baglanti.gd")

# Sıra mağazadaki sıradır
const OYUNLAR := ["hayvan_besle", "boyama_kitabi", "dondurmaci", "balik_tutma", "sihirli_bahce", "tren_rayi",
	"robot_fabrikasi", "toplama"]

var gecis: Node
var game: Node
var out := ""
var boyut := Vector2i(1920, 1080)
var _yedek := {}
var _eserler: PackedStringArray = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = ProjectSettings.globalize_path(args[0] if args.size() > 0 else "res://.playstore/screenshots/telefon")
	var secilen := args.slice(1)
	for arg in secilen.duplicate():
		var parca := arg.split("x")
		if parca.size() == 2 and parca[0].is_valid_int() and parca[1].is_valid_int():
			boyut = Vector2i(parca[0].to_int(), parca[1].to_int())
			secilen.erase(arg)
	DirAccess.make_dir_recursive_absolute(out)
	gecis = root.get_node("SahneGecis")
	_kayitlari_yedekle()
	change_scene_to_file(MENU)
	await _gecis_bekle()
	root.borderless = true
	root.mode = Window.MODE_WINDOWED
	root.size = boyut
	root.position = Vector2i.ZERO
	await frames(20)
	if root.get_texture().get_image().get_size() != boyut:
		push_error("Pencere %s olamadı (monitör küçük mü?)" % boyut)
	for i in OYUNLAR.size():
		var ad: String = OYUNLAR[i]
		if not secilen.is_empty() and not ad in secilen:
			continue
		await call("_" + ad)
		await shot("%02d_%s" % [i + 1, ad])
	gecis.sahne_degistir(MENU)
	await frames(5)
	await _gecis_bekle()
	await frames(30)
	_kayitlari_geri_yaz()
	print("SONUÇ: bitti (", out, ")")
	quit()


func _ac(ad: String, kayit := {}) -> void:
	if not kayit.is_empty():
		var ayar := ConfigFile.new()
		for bolum: String in kayit:
			for anahtar: String in kayit[bolum]:
				ayar.set_value(bolum, anahtar, kayit[bolum][anahtar])
		ayar.save("user://%s.cfg" % ad)
	gecis.sahne_degistir("res://oyunlar/%s/%s.tscn" % [ad, ad])
	await _gecis_bekle()
	game = current_scene


# --- Oyunlar ---

# Bir hayvan doymuş ve mutlu, ikincisine yiyeceği götürülüyor
func _hayvan_besle() -> void:
	await _ac("hayvan_besle", {"ilerleme": {"bolum": 4}})
	await frames(120)
	await _yiyecek_tasi(game.animals[0], 1.0)
	await frames(150)
	await _yiyecek_tasi(game.animals[1], 0.7)
	await frames(30)


func _yiyecek_tasi(animal: Node, oran: float) -> void:
	for food in game.foods:
		if not is_instance_valid(food) or food.eaten or not animal.accepts(food.data):
			continue
		var from: Vector2 = food.global_position
		var to: Vector2 = animal.global_position + Vector2(0, -animal.size * 0.45)
		var to_now := from.lerp(to, oran)
		touch(0, from, true)
		for k in 24:
			drag(0, from.lerp(to_now, k / 23.0))
			await process_frame
		if oran >= 1.0:
			touch(0, to, false)
		return


# Yarısı boyanmış sayfa, bir bölge boyanırken (kova dalgası)
func _boyama_kitabi() -> void:
	await _ac("boyama_kitabi")
	await frames(30)
	game.open_coloring("kaplumbaga", "", "picker")
	await frames(60)
	var canvas: Node = game.screen.canvas
	var renkler := [Color("8ee04f"), Color("ffd93b"), Color("5cc8ff"), Color("ff9a2e"), Color("2e9e4f"),
		Color("ff5fae"), Color("9a5cf0"), Color("ff4b4b")]
	for r in range(1, canvas.colors.size() - 2):
		canvas.set_region_color(r, renkler[r % renkler.size()], Vector2.ZERO, false)
	await frames(10)
	var son: int = canvas.colors.size() - 2
	var kutu: Rect2 = canvas._region_boxes[son]
	canvas.set_region_color(son, Color("ffd93b"), kutu.get_center(), true)
	await frames(8)
	canvas.dirty = false  # çıkarken (ya da pencere odağını kaybedince) galeriye kaydedilmesin


# Üç toplu sipariş, iki topu konmuş dondurma
func _dondurmaci() -> void:
	await _ac("dondurmaci")
	await bekle(func() -> bool: return game.state == game.State.CHOOSE_CONTAINER, 400)
	game.stars = 7
	game.star_label.text = "7"
	game.order_container = "kulah"
	game.order_flavors.assign(["cilek", "cikolata", "vanilya"].filter(func(id: String) -> bool: return game._flavor_index(id) >= 0))
	if game.order_flavors.size() < 3:
		game.order_flavors.assign([game.FLAVORS[0]["id"], game.FLAVORS[1]["id"], game.FLAVORS[2]["id"]])
	game._show_order()
	await frames(40)
	game._on_container_tapped("kulah")
	await frames(30)
	for k in 2:
		game._on_flavor_tapped(game._flavor_index(game.order_flavors[k]))
		await frames(30)
	await frames(20)


# Mercan bölümü: görev baloncuğu, kayıkta penguen, mercanların arasında balıklar
func _balik_tutma() -> void:
	await _ac("balik_tutma", {"ilerleme": {"bolum": 8}})
	await frames(300)


# Dolu bahçe: çiçekler, kabak, mantar; kelebek ve uğur böceği
func _sihirli_bahce() -> void:
	await _ac("sihirli_bahce", {"ipucu": {"ekme": true}})
	await frames(60)
	var setups := [
		{"bitki": "lale", "asama": 4, "ihtiyac": ""},
		{"bitki": "aycicegi", "asama": 4, "ihtiyac": ""},
		{"bitki": "kabak", "asama": 4, "ihtiyac": "", "birikinti": true},
		{"bitki": "mantar", "asama": 4, "ihtiyac": ""},
		{"bitki": "yildiz_agaci", "asama": 3, "ihtiyac": "sun"},
	]
	for i in 5:
		game.plots[i].from_dict(setups[i], false)
	game._critters.spawn("kelebek")
	game._critters.spawn("ugur")
	await frames(150)


# Yol tamamlanmış, vagonlu tren yolcuları alarak ilerliyor
func _tren_rayi() -> void:
	await _ac("tren_rayi", {"ilerleme": {"bolum": 5, "vagon": 5}})
	await frames(60)
	tap(game._giris._oynat.position)
	await frames(60)
	var izgara: Node2D = game.izgara
	for h in izgara.parcalar:
		var parca: Node2D = izgara.parcalar[h]
		if parca.sabit or not izgara.bolum["cozum"].has(h):
			continue
		var hedef := Baglanti.acikliklar(izgara.bolum["cozum"][h]["tip"], izgara.bolum["cozum"][h]["yon"])
		for k in 4:
			if Baglanti.acikliklar(parca.tip, parca.yon) == hedef:
				break
			tap(izgara.merkez(h))
			await frames(2)
	await frames(40)
	tap(game._hareket.get_global_rect().get_center())
	await frames(150)


# Kutular yarı dolu, bir parça bantdan doğru kutuya taşınıyor (kutlama yazısı dile göre değiştiği için
# robotun birleştiği an değil)
func _robot_fabrikasi() -> void:
	await _ac("robot_fabrikasi", {"ilerleme": {"bolum": 2}})
	await frames(240)
	var konan := 0
	while konan < 5:
		var part := _banttaki_parca()
		if part == null:
			await frames(10)
			continue
		var to: Vector2 = game.boxes[game.manager.box_for(part.data)].global_position + Vector2(0, 120)
		touch(0, part.global_position, true)
		await frames(3)
		drag(0, to)
		await frames(2)
		touch(0, to, false)
		await frames(30)
		konan += 1
	await frames(90)
	var part := _banttaki_parca()
	while part == null:
		await frames(10)
		part = _banttaki_parca()
	var from: Vector2 = part.global_position
	var to: Vector2 = game.boxes[game.manager.box_for(part.data)].global_position + Vector2(0, -40)
	touch(0, from, true)
	for k in 24:
		drag(0, from.lerp(to, k / 23.0 * 0.75))
		await process_frame
	await frames(10)


func _banttaki_parca() -> Node2D:
	var best: Node2D = null
	for part in game._belt.parts:
		if part.on_belt and part.visible and part.position.x > 200.0 and part.position.x < 1000.0:
			if best == null or part.position.x > best.position.x:
				best = part
	return best


# Toplama: doğru cevap seçildi, nesneler sayılarak sonuç kutusuna uçuyor
func _toplama() -> void:
	await _ac("toplama", {"ilerleme": {"bolum": 8}})
	await bekle(func() -> bool: return game.state == game.State.WAITING, 600)
	await frames(30)
	for button in game.buttons:
		if button.value == game.problem.answer:
			game._choose(button)
			break
	await frames(150)


# --- Yardımcılar ---

func _gecis_bekle() -> void:
	for i in 900:
		await process_frame
		if current_scene and not gecis.gecis_suruyor:
			return


func bekle(kosul: Callable, en_fazla: int) -> void:
	for i in en_fazla:
		if kosul.call():
			return
		await process_frame


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(ad: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)  # Play: alfa kanalsız PNG
	img.save_png(out.path_join(ad + ".png"))
	print("çekildi: ", ad)


func tap(pos: Vector2) -> void:
	touch(0, pos, true)
	touch(0, pos, false)


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)


func drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	root.push_input(ev, true)


func _kayitlari_yedekle() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if ".cfg" in dosya:  # .cfg, .cfg.bak, .cfg.tmp (GuvenliKayit)
			_yedek[dosya] = FileAccess.get_file_as_bytes(klasor.path_join(dosya))
	if DirAccess.dir_exists_absolute(klasor.path_join("boyama_kitabi")):
		_eserler = DirAccess.get_directories_at(klasor.path_join("boyama_kitabi"))


func _kayitlari_geri_yaz() -> void:
	var klasor := OS.get_user_data_dir()
	for dosya in DirAccess.get_files_at(klasor):
		if ".cfg" in dosya and not _yedek.has(dosya):
			DirAccess.remove_absolute(klasor.path_join(dosya))
	for dosya in _yedek:
		var f := FileAccess.open(klasor.path_join(dosya), FileAccess.WRITE)
		f.store_buffer(_yedek[dosya])
		f.close()
	var eser_klasoru := klasor.path_join("boyama_kitabi")
	if not DirAccess.dir_exists_absolute(eser_klasoru):
		return
	for eser in DirAccess.get_directories_at(eser_klasoru):
		if not (eser in _eserler):
			var yol := eser_klasoru.path_join(eser)
			for dosya in DirAccess.get_files_at(yol):
				DirAccess.remove_absolute(yol.path_join(dosya))
			DirAccess.remove_absolute(yol)
