extends Control
# Boyama Kitabı (ColoringGame): yatay, 2-6 yaş, hiç yazı yok; kural, puan, doğru/yanlış yok.
# Ekranlar bu düğümün çocuğu olarak açılır, aynı anda tek ekran:
#   giriş (ColoringHome) → sayfa seçimi (ColoringPagePicker) → boyama (ColoringScreen)
#   giriş → galeri (ColoringGallery) → boyama (kaldığı yerden)
# Boyamadan geri dönünce (önce otomatik kayıt) geldiği ekrana gidilir. Giriş ekranının geri düğmesi ana
# menüye döner; Escape / Android geri tuşu her yerden ana menüye döner (SahneGecis), çıkarken kayıt yapılır.
# Dokunmayı açık ekran yönetir (handle_input); geçiş sırasında dokunma yok sayılır.

## Ekran yönü: SahneGecis bu oyuna geçerken ekranı buna göre döndürür.
@export_enum("dikey", "yatay") var ekran_yonu: String = "yatay"

const Sounds := preload("res://oyunlar/boyama_kitabi/sesler.gd")
const FADE_OUT := 0.12
const FADE_IN := 0.2

## Sayfa seçiminde son açılan kategori
var last_category: String = ""

var sounds: Node
var screen: Control
var _switching: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sounds = Sounds.new()
	add_child(sounds)
	show_home()


func to_menu() -> void:
	SahneGecis.ana_menuye_don()


func show_home() -> void:
	var home := ColoringHome.new()
	_switch(home)
	home.setup(self)


func show_picker() -> void:
	# Galeri doluysa yeni resim açılmaz: galeri açılır, çöp kutuları sallanarak "birini sil" der
	if ColoringArtworks.is_full():
		show_gallery(true)
		return
	var picker := ColoringPagePicker.new()
	_switch(picker)
	picker.setup(self, last_category)


func show_gallery(full: bool = false) -> void:
	var gallery := ColoringGallery.new()
	_switch(gallery)
	gallery.setup(self)
	if full:
		gallery.hint_full()


## Boyama ekranını açar: art_id boşsa sayfadan yeni eser; from: dönülecek ekran ("picker" / "gallery")
func open_coloring(page_id: String, art_id: String, from: String) -> void:
	var coloring := ColoringScreen.new()
	_switch(coloring)
	coloring.setup(sounds, page_id, art_id)
	coloring.back_requested.connect(func() -> void:
		if from == "gallery":
			show_gallery()
		else:
			show_picker())


func _switch(next: Control) -> void:
	_switching = true
	if screen:
		var old := screen
		var tween := old.create_tween()
		tween.tween_property(old, "modulate:a", 0.0, FADE_OUT)
		tween.tween_callback(old.queue_free)
	screen = next
	next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	next.modulate.a = 0.0
	add_child(next)
	var tween := next.create_tween()
	tween.tween_interval(FADE_OUT * 0.5)
	tween.tween_property(next, "modulate:a", 1.0, FADE_IN)
	tween.tween_callback(func() -> void: _switching = false)


func _input(event: InputEvent) -> void:
	if _switching or SahneGecis.gecis_suruyor or screen == null:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		screen.handle_input(event)
