extends "res://ortak/ses_havuzu.gd"
# Yapboz sesleri (ortak ses havuzu). Hepsi sesler/ses_uret.py ile sentezlendi.
# Resim bitince çalan ses ayarlar.gd PICTURES "sound" alanında (inek, tren, meyve, deniz, ...).

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
	"tren": preload("res://oyunlar/yapboz/sesler/tren.wav"),
	"meyve": preload("res://oyunlar/yapboz/sesler/meyve.wav"),
	"uzay": preload("res://oyunlar/yapboz/sesler/uzay.wav"),
	"orman": preload("res://oyunlar/yapboz/sesler/orman.wav"),
	"agac_ev": preload("res://oyunlar/yapboz/sesler/agac_ev.wav"),
	"pasta": preload("res://oyunlar/yapboz/sesler/pasta.wav"),
	"dinozor": preload("res://oyunlar/yapboz/sesler/dinozor.wav"),
	"kutup": preload("res://oyunlar/yapboz/sesler/kutup.wav"),
}
const VOLUMES := {"tut": -10.0, "otur": -7.0, "geri": -12.0, "dagil": -12.0, "bolum_sonu": -6.0, "final": -5.0,
	"inek": -5.0, "deniz": -6.0, "balon": -6.0, "kasaba": -6.0, "tren": -6.0, "meyve": -6.0, "uzay": -6.0, "orman": -7.0,
	"agac_ev": -6.0, "pasta": -6.0, "dinozor": -6.0, "kutup": -6.0}


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
