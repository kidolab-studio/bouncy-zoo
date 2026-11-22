extends "res://ortak/ses_havuzu.gd"
# Noktaları Birleştir sesleri (ortak ses havuzu). Hepsi sesler/ses_uret.py ile sentezlendi.
# Resim bitince çalan ses ayarlar.gd PICTURES "sound" alanında (ev, yelkenli, tac, yildiz, roket, semsiye).

const STREAMS := {
	"nokta": preload("res://oyunlar/nokta_birlestir/sesler/nokta.wav"),
	"yanlis": preload("res://oyunlar/nokta_birlestir/sesler/yanlis.wav"),
	"kapan": preload("res://oyunlar/nokta_birlestir/sesler/kapan.wav"),
	"bolum_sonu": preload("res://oyunlar/nokta_birlestir/sesler/bolum_sonu.wav"),
	"final": preload("res://oyunlar/nokta_birlestir/sesler/final.wav"),
	"ev": preload("res://oyunlar/nokta_birlestir/sesler/ev.wav"),
	"yelkenli": preload("res://oyunlar/nokta_birlestir/sesler/yelkenli.wav"),
	"tac": preload("res://oyunlar/nokta_birlestir/sesler/tac.wav"),
	"yildiz": preload("res://oyunlar/nokta_birlestir/sesler/yildiz.wav"),
	"roket": preload("res://oyunlar/nokta_birlestir/sesler/roket.wav"),
	"semsiye": preload("res://oyunlar/nokta_birlestir/sesler/semsiye.wav"),
}
const VOLUMES := {"nokta": -9.0, "yanlis": -12.0, "kapan": -8.0, "bolum_sonu": -6.0, "final": -5.0,
	"ev": -6.0, "yelkenli": -6.0, "tac": -6.0, "yildiz": -6.0, "roket": -6.0, "semsiye": -6.0}


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
