class_name ColoringArtworks
extends RefCounted
# Eserlerin kaydı (user://boyama_kitabi/<eser>/). Her eser düzenlenebilir halde saklanır:
#   eser.cfg   [eser] sayfa (sayfa kimliği), renkler (bölge renkleri, PackedColorArray),
#              olusturma / degisme (unix zamanı)
#   firca.png  fırça ve damga katmanı (tuval boyutunda, önceden çarpılmış alfa; katman boşsa yok)
#   kucuk.png  galeri küçük resmi
# Aynı sayfadan istenildiği kadar eser olabilir; toplamda en fazla Settings.MAX_ARTWORKS eser.
# Galeri en son değişeni en başta gösterir.

const Settings := preload("res://oyunlar/boyama_kitabi/ayarlar.gd")
const PageList := preload("res://oyunlar/boyama_kitabi/sayfalar/sayfa_listesi.gd")
const DIR := "user://boyama_kitabi/"


static func list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIR):
		return result
	for id in DirAccess.get_directories_at(DIR):
		var config := ConfigFile.new()
		if config.load(DIR + id + "/eser.cfg") != OK:
			continue
		result.append({"id": id, "page": str(config.get_value("eser", "sayfa", "")),
			"modified": float(config.get_value("eser", "degisme", 0.0))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["modified"] > b["modified"])
	return result


## Galeride görünen eserler: sayfası hâlâ var olanlar (list() sırasıyla)
static func gallery_list() -> Array[Dictionary]:
	var known := {}
	for page in PageList.PAGES:
		known[page["id"]] = true
	return list().filter(func(art: Dictionary) -> bool: return known.has(art["page"]))


## Galeri dolu mu: yeni eser açılmaz
static func is_full() -> bool:
	return gallery_list().size() >= Settings.MAX_ARTWORKS


## {"page", "colors", "brush" (Image ya da null)}; yoksa boş sözlük
static func load_art(id: String) -> Dictionary:
	var config := ConfigFile.new()
	if id == "" or config.load(DIR + id + "/eser.cfg") != OK:
		return {}
	var brush: Image = null
	var brush_path := DIR + id + "/firca.png"
	if FileAccess.file_exists(brush_path):
		brush = Image.load_from_file(brush_path)
	return {"page": str(config.get_value("eser", "sayfa", "")),
		"colors": config.get_value("eser", "renkler", PackedColorArray()), "brush": brush}


static func thumbnail(id: String) -> Texture2D:
	var path := DIR + id + "/kucuk.png"
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image else null


## Eseri yazar (id boşsa yeni eser açar) ve kimliğini döndürür. brush null ise fırça katmanı yok sayılır.
static func save_art(id: String, page: String, colors: PackedColorArray, brush: Image, thumb: Image) -> String:
	if id == "":
		id = "eser_%d_%03d" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 1000]
	var folder := DIR + id + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var config := ConfigFile.new()
	var now := Time.get_unix_time_from_system()
	var created := now
	if config.load(folder + "eser.cfg") == OK:
		created = float(config.get_value("eser", "olusturma", now))
	config.set_value("eser", "sayfa", page)
	config.set_value("eser", "renkler", colors)
	config.set_value("eser", "olusturma", created)
	config.set_value("eser", "degisme", now)
	if brush != null:
		brush.save_png(folder + "firca.png")
	elif FileAccess.file_exists(folder + "firca.png"):
		DirAccess.remove_absolute(folder + "firca.png")
	if thumb != null:
		thumb.save_png(folder + "kucuk.png")
	GuvenliKayit.save_config(config, folder + "eser.cfg")
	return id


static func delete_art(id: String) -> void:
	var folder := DIR + id + "/"
	if id == "" or not DirAccess.dir_exists_absolute(folder):
		return
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + file)
	DirAccess.remove_absolute(folder)
