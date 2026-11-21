extends "res://ortak/ses_havuzu.gd"
# Yapboz sesleri (ortak ses havuzu). Hepsi sesler/ses_uret.py ile sentezlendi.
# Resim bitince çalan ses ayarlar.gd PICTURES "sound" alanında (inek, deniz, balon, kasaba).

const STREAMS := {
	"tut": preload("res://oyunlar/yapboz/sesler/tut.wav"),
	"otur": preload("res://oyunlar/yapboz/sesler/otur.wav"),
	"geri": preload("res://oyunlar/yapboz/sesler/geri.wav"),
	"dagil": preload("res://oyunlar/yapboz/sesler/dagil.wav"),
	"bolum_sonu": preload("res://oyunlar/yapboz/sesler/bolum_sonu.wav"),
	"final": preload("res://oyunlar/yapboz/sesler/final.wav"),
	"inek": preload("res://oyunlar/yapboz/sesler/inek.wav"),
	"deniz": preload("res://oyunlar/yapboz/sesler/deniz.wav"),
	"balon": preload("res://oyunlar/yapboz/sesler/balon.wav"),
	"kasaba": preload("res://oyunlar/yapboz/sesler/kasaba.wav"),
}
const VOLUMES := {"tut": -10.0, "otur": -7.0, "geri": -12.0, "dagil": -12.0, "bolum_sonu": -6.0, "final": -5.0,
	"inek": -5.0, "deniz": -6.0, "balon": -6.0, "kasaba": -6.0}


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
