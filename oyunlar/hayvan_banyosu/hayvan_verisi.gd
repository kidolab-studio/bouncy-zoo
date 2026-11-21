class_name BathAnimalData
extends Resource
# Hayvan Banyosu: bir hayvan (hayvanlar/<ad>.tres). Hayvan parçalı çizilir: gövde ve kafa aynı 256'lık
# tuvalde iki SVG'dir (Hayvanları Besle'deki çizimler); gözleri, ağzı ve yanakları hayvan_yuzu.gd kodla çizer.
# Yüz yerleri Hayvanları Besle'nin gorseller/svg_uret.py içindeki FACES ile aynıdır.
# Yeni hayvan: gorseller/svg_uret.py çizimi üretir (Besle'nin ANIMALS listesinden), sesini sesler/ses_uret.py
# kopyalar; bu kaynaktan bir .tres yaz ve ayarlar.gd ANIMALS listesine ekle.

## Kısa ad (dosya adıyla aynı)
@export var id: StringName = &""
@export var body_texture: Texture2D
@export var head_texture: Texture2D
## Hayvanın sesi (yıkanınca ve dokununca çalar)
@export var voice: AudioStream

@export_group("Yüz (256'lık tuvalde)")
## Gözlerin yüksekliği ve merkezden yana uzaklığı
@export var eye_y: float = 124.0
@export var eye_dx: float = 26.0
## Gözün yarıçapları (yatay, dikey)
@export var eye_size: Vector2 = Vector2(14, 17)
## Göz arkasında beyaz halka (panda gibi koyu göz lekeli hayvanlar için)
@export var eye_white: bool = false
@export var mouth_y: float = 156.0
@export var mouth_width: float = 12.0
@export var cheek_y: float = 150.0
@export var cheek_dx: float = 48.0
## Yanakların rengi (yüz çizimi kullanır)
@export var skin_color: Color = Color.WHITE
## Ağzın altında iki ön diş (tavşan, fare, sincap)
@export var teeth: bool = false
## Ağız yerine gaga (kuş)
@export var beak: bool = false
