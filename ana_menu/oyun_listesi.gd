extends RefCounted
# Ana menüdeki bütün oyunlar tek listede. Yeni oyun eklemek = OYUNLAR'a bir kayıt
# (+ kart görseli: ana_menu/svg_uret.py'ye kart fonksiyonu ya da ana_menu/kartlar/ içine bir SVG).
#
# Kayıt alanları:
#   "ad"        kartta yazan kısa ad
#   "klasor"    oyunun klasörü (oyunlar/<klasor>/); "yeni" rozeti ve ilerleme kaydı bu adla tutulur
#   "sahne"     giriş sahnesi (tam yol)
#   "kart"      kart görseli (ana_menu/kartlar/ içinde, 320x300 tuval)
#   "renk"      kartın pastel rengi: PALET'teki bir ad
#   "kategori"  KATEGORILER'deki bir kimlik ("hepsi" hariç)
#   "yon"       "yatay" (eskiden "dikey" de olabilirdi; bilgi amaçlı; ekranı oyunun kendi ekran_yonu değeri çevirir, menü testi ikisini karşılaştırır)
#   "ilerleme"  (isteğe bağlı) bölümlü oyunlarda kartın köşesindeki küçük rozet:
#               {"anahtar": "bolum/anahtar", "ekle": 1, "en_fazla": 10} → user://<klasor>.cfg içinden okunur.
#               Anahtar "*" ise bölümdeki en büyük değer alınır (ör. Hafıza'da temaların en ilerisi).
#   "yeni"      (isteğe bağlı) true ise, oyun menüden ilk kez açılana kadar kartta "Yeni" rozeti görünür

const MENU_KAYDI := "user://ana_menu.cfg"
const KART_KLASORU := "res://ana_menu/kartlar/"

# Tek uyumlu pastel palet: kart zeminleri buradan seçilir
const PALET := {
	"pembe": Color("ffd9e6"),
	"seftali": Color("ffe1c7"),
	"limon": Color("fff0bd"),
	"nane": Color("d2f2de"),
	"turkuaz": Color("ccedf0"),
	"gok": Color("d5e7ff"),
	"lavanta": Color("e3dbff"),
	"leylak": Color("f4dbf3"),
}

# Sekmeler: renk ve simge ile anlaşılır, altlarında küçük ad (okuyabilen büyükler için)
const KATEGORILER := [
	{"id": "hepsi", "ad": "Hepsi", "renk": Color("8a6cf0"), "simge": "res://ana_menu/gorseller/sekme_hepsi.svg"},
	{"id": "hareket", "ad": "Hareket", "renk": Color("ff7a45"), "simge": "res://ana_menu/gorseller/sekme_hareket.svg"},
	{"id": "bulmaca", "ad": "Bulmaca", "renk": Color("3e8eeb"), "simge": "res://ana_menu/gorseller/sekme_bulmaca.svg"},
	{"id": "yaratici", "ad": "Yaratıcı", "renk": Color("ec4f94"), "simge": "res://ana_menu/gorseller/sekme_yaratici.svg"},
	{"id": "ogren", "ad": "Öğren", "renk": Color("2fae62"), "simge": "res://ana_menu/gorseller/sekme_ogren.svg"},
]

const OYUNLAR := [
	{"ad": "Hayvanları Besle", "klasor": "hayvan_besle", "sahne": "res://oyunlar/hayvan_besle/hayvan_besle.tscn", "kart": "hayvan_besle.svg",
		"renk": "nane", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Boyama Kitabı", "klasor": "boyama_kitabi", "sahne": "res://oyunlar/boyama_kitabi/boyama_kitabi.tscn", "kart": "boyama_kitabi.svg",
		"renk": "leylak", "kategori": "yaratici", "yon": "yatay"},
	{"ad": "Dondurmacı", "klasor": "dondurmaci", "sahne": "res://oyunlar/dondurmaci/dondurmaci.tscn", "kart": "dondurmaci.svg",
		"renk": "pembe", "kategori": "bulmaca", "yon": "yatay"},
	{"ad": "Balık Tutma", "klasor": "balik_tutma", "sahne": "res://oyunlar/balik_tutma/balik_tutma.tscn", "kart": "balik_tutma.svg",
		"renk": "turkuaz", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Sihirli Bahçe", "klasor": "sihirli_bahce", "sahne": "res://oyunlar/sihirli_bahce/sihirli_bahce.tscn", "kart": "sihirli_bahce.svg",
		"renk": "leylak", "kategori": "yaratici", "yon": "yatay"},
	{"ad": "Müzik Kutusu", "klasor": "muzik_kutusu", "sahne": "res://oyunlar/muzik_kutusu/muzik_kutusu.tscn", "kart": "muzik_kutusu.svg",
		"renk": "seftali", "kategori": "yaratici", "yon": "yatay"},
	{"ad": "Hayvan Banyosu", "klasor": "hayvan_banyosu", "sahne": "res://oyunlar/hayvan_banyosu/hayvan_banyosu.tscn", "kart": "hayvan_banyosu.svg",
		"renk": "turkuaz", "kategori": "yaratici", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}, "yeni": true},
	{"ad": "Sıradaki Ne?", "klasor": "siradaki_ne", "sahne": "res://oyunlar/siradaki_ne/siradaki_ne.tscn", "kart": "siradaki_ne.svg",
		"renk": "pembe", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}, "yeni": true},
	{"ad": "Yapboz", "klasor": "yapboz", "sahne": "res://oyunlar/yapboz/yapboz.tscn", "kart": "yapboz.svg",
		"renk": "seftali", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}, "yeni": true},
	{"ad": "Noktaları Birleştir", "klasor": "nokta_birlestir", "sahne": "res://oyunlar/nokta_birlestir/nokta_birlestir.tscn", "kart": "nokta_birlestir.svg",
		"renk": "gok", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}, "yeni": true},
	{"ad": "Meyve Topla", "klasor": "meyve_topla", "sahne": "res://oyunlar/meyve_topla/meyve_topla.tscn", "kart": "meyve_topla.svg",
		"renk": "seftali", "kategori": "hareket", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Hafıza", "klasor": "hafiza", "sahne": "res://oyunlar/hafiza/hafiza.tscn", "kart": "hafiza.svg",
		"renk": "lavanta", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/*", "ekle": 1, "en_fazla": 4}},
	{"ad": "Gölge Eşleştirme", "klasor": "golge_eslestirme", "sahne": "res://oyunlar/golge_eslestirme/golge_eslestirme.tscn", "kart": "golge_eslestirme.svg",
		"renk": "turkuaz", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Yol Yap", "klasor": "yol_yap", "sahne": "res://oyunlar/yol_yap/yol_yap.tscn", "kart": "yol_yap.svg",
		"renk": "nane", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/tamamlanan", "ekle": 1, "en_fazla": 10}},
	{"ad": "Tren Rayı", "klasor": "tren_rayi", "sahne": "res://oyunlar/tren_rayi/tren_rayi.tscn", "kart": "tren_rayi.svg",
		"renk": "gok", "kategori": "bulmaca", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Büyükten Küçüğe", "klasor": "buyukten_kucuge", "sahne": "res://oyunlar/buyukten_kucuge/buyukten_kucuge.tscn", "kart": "buyukten_kucuge.svg",
		"renk": "lavanta", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Robot Fabrikası", "klasor": "robot_fabrikasi", "sahne": "res://oyunlar/robot_fabrikasi/robot_fabrikasi.tscn", "kart": "robot_fabrikasi.svg",
		"renk": "limon", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Köstebek", "klasor": "kostebek", "sahne": "res://oyunlar/kostebek/kostebek.tscn", "kart": "kostebek.svg",
		"renk": "nane", "kategori": "hareket", "yon": "yatay"},
	{"ad": "Uçan Kuş", "klasor": "ucan_kus", "sahne": "res://oyunlar/ucan_kus/ucan_kus.tscn", "kart": "ucan_kus.svg",
		"renk": "gok", "kategori": "hareket", "yon": "yatay"},
	{"ad": "Kule Yapma", "klasor": "kule_yapma", "sahne": "res://oyunlar/kule_yapma/kule_yapma.tscn", "kart": "kule_yapma.svg",
		"renk": "seftali", "kategori": "hareket", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Toplama", "klasor": "toplama", "sahne": "res://oyunlar/toplama/toplama.tscn", "kart": "toplama.svg",
		"renk": "limon", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
	{"ad": "Araba Yarışı", "klasor": "araba_yarisi", "sahne": "res://oyunlar/araba_yarisi/araba_yarisi.tscn", "kart": "araba_yarisi.svg",
		"renk": "gok", "kategori": "hareket", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/acik", "ekle": 0}},
	{"ad": "Zıpla Zıpla", "klasor": "zipla_zipla", "sahne": "res://oyunlar/zipla_zipla/zipla_zipla.tscn", "kart": "zipla_zipla.svg",
		"renk": "gok", "kategori": "hareket", "yon": "yatay"},
	{"ad": "Çıkarma", "klasor": "cikarma", "sahne": "res://oyunlar/cikarma/cikarma.tscn", "kart": "cikarma.svg",
		"renk": "turkuaz", "kategori": "ogren", "yon": "yatay",
		"ilerleme": {"anahtar": "ilerleme/bolum", "ekle": 1}},
]


static func kart_yolu(oyun: Dictionary) -> String:
	return KART_KLASORU + str(oyun["kart"])


static func renk(oyun: Dictionary) -> Color:
	return PALET.get(oyun["renk"], PALET["lavanta"])


static func kategori(id: String) -> Dictionary:
	for k in KATEGORILER:
		if k["id"] == id:
			return k
	return KATEGORILER[0]


static func kategoride_mi(oyun: Dictionary, kategori_id: String) -> bool:
	return kategori_id == "hepsi" or oyun["kategori"] == kategori_id


# Kartın köşesindeki ilerleme sayısı; kayıt ya da ilerleme tanımı yoksa 0 (rozet gösterilmez)
static func ilerleme(oyun: Dictionary) -> int:
	if not oyun.has("ilerleme"):
		return 0
	var tanim: Dictionary = oyun["ilerleme"]
	var ayar := ConfigFile.new()
	if ayar.load("user://%s.cfg" % oyun["klasor"]) != OK:
		return 0
	var parcalar: PackedStringArray = str(tanim["anahtar"]).split("/")
	var bolum := parcalar[0]
	var deger := 0
	if parcalar[1] == "*":
		if not ayar.has_section(bolum):
			return 0
		for anahtar in ayar.get_section_keys(bolum):
			deger = maxi(deger, int(ayar.get_value(bolum, anahtar, 0)))
	elif ayar.has_section_key(bolum, parcalar[1]):
		deger = int(ayar.get_value(bolum, parcalar[1], 0))
	else:
		return 0
	deger += int(tanim.get("ekle", 0))
	if tanim.has("en_fazla"):
		deger = mini(deger, int(tanim["en_fazla"]))
	return deger


# --- "Yeni" rozeti: menüden açılan oyunlar user://ana_menu.cfg içinde işaretlenir ---

static func yeni_mi(oyun: Dictionary) -> bool:
	if not oyun.get("yeni", false):
		return false
	var ayar := ConfigFile.new()
	ayar.load(MENU_KAYDI)
	return not ayar.get_value("acilan", oyun["klasor"], false)


static func acildi_isaretle(oyun: Dictionary) -> void:
	var ayar := ConfigFile.new()
	ayar.load(MENU_KAYDI)
	ayar.set_value("acilan", oyun["klasor"], true)
	GuvenliKayit.save_config(ayar, MENU_KAYDI)


# Listedeki hataları bulur (menü açılırken ve menü testinde çalışır)
static func dogrula() -> PackedStringArray:
	var hatalar := PackedStringArray()
	var kategori_idleri := KATEGORILER.map(func(k: Dictionary) -> String: return k["id"])
	var klasorler := {}
	for oyun in OYUNLAR:
		for alan in ["ad", "klasor", "sahne", "kart", "renk", "kategori", "yon"]:
			if not oyun.has(alan):
				hatalar.append("%s: '%s' alanı yok" % [oyun.get("ad", "?"), alan])
		if klasorler.has(oyun.get("klasor")):
			hatalar.append("%s: klasör iki kez var" % oyun["ad"])
		klasorler[oyun.get("klasor")] = true
		if not ResourceLoader.exists(oyun.get("sahne", "")):
			hatalar.append("%s: sahne yok (%s)" % [oyun["ad"], oyun.get("sahne")])
		if not ResourceLoader.exists(kart_yolu(oyun)):
			hatalar.append("%s: kart görseli yok (%s)" % [oyun["ad"], kart_yolu(oyun)])
		if not PALET.has(oyun.get("renk")):
			hatalar.append("%s: renk paletde yok (%s)" % [oyun["ad"], oyun.get("renk")])
		if oyun.get("kategori") == "hepsi" or not oyun.get("kategori") in kategori_idleri:
			hatalar.append("%s: geçersiz kategori (%s)" % [oyun["ad"], oyun.get("kategori")])
		if not oyun.get("yon") in ["dikey", "yatay"]:
			hatalar.append("%s: yön dikey ya da yatay olmalı" % oyun["ad"])
	return hatalar
