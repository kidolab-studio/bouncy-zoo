extends "res://ortak/ses_havuzu.gd"
# Sıradaki Ne? sesleri (ortak ses havuzu). Hepsi sesler/ses_uret.py ile sentezlendi.
# note(sıra): parçanın notası (bolum_uretici.gd notes; örüntünün A, B, C harfleri 0, 2, 4).

const NOTE_COUNT := 6
const STREAMS := {
	"pop": preload("res://oyunlar/siradaki_ne/sesler/pop.wav"),
	"nota_0": preload("res://oyunlar/siradaki_ne/sesler/nota_0.wav"),
	"nota_1": preload("res://oyunlar/siradaki_ne/sesler/nota_1.wav"),
	"nota_2": preload("res://oyunlar/siradaki_ne/sesler/nota_2.wav"),
	"nota_3": preload("res://oyunlar/siradaki_ne/sesler/nota_3.wav"),
	"nota_4": preload("res://oyunlar/siradaki_ne/sesler/nota_4.wav"),
	"nota_5": preload("res://oyunlar/siradaki_ne/sesler/nota_5.wav"),
	"geri": preload("res://oyunlar/siradaki_ne/sesler/geri.wav"),
	"kolye": preload("res://oyunlar/siradaki_ne/sesler/kolye.wav"),
	"patlama": preload("res://oyunlar/siradaki_ne/sesler/patlama.wav"),
	"cicek": preload("res://oyunlar/siradaki_ne/sesler/cicek.wav"),
	"surun": preload("res://oyunlar/siradaki_ne/sesler/surun.wav"),
	"adim": preload("res://oyunlar/siradaki_ne/sesler/adim.wav"),
	"bolum_sonu": preload("res://oyunlar/siradaki_ne/sesler/bolum_sonu.wav"),
	"final": preload("res://oyunlar/siradaki_ne/sesler/final.wav"),
}
const VOLUMES := {"pop": -10.0, "geri": -12.0, "kolye": -8.0, "patlama": -8.0, "cicek": -9.0, "surun": -12.0,
	"adim": -11.0, "bolum_sonu": -6.0, "final": -5.0}
const NOTE_VOLUME := -6.0


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
	for k in NOTE_COUNT:
		volumes["nota_%d" % k] = NOTE_VOLUME
	player_count = 10


func note(index: int) -> void:
	play("nota_%d" % clampi(index, 0, NOTE_COUNT - 1))
