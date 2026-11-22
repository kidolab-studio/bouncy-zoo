extends "res://ortak/ses_havuzu.gd"
# Labirent sesleri (ortak ses havuzu). Hepsi sesler/ses_uret.py ile üretildi (kedi, köpek, inek Hayvanları Besle'den kopya).
# Hayvan sesinin adı hayvanın adıyla aynı (ayarlar.gd ANIMALS).

const STREAMS := {
	"tut": preload("res://oyunlar/labirent/sesler/tut.wav"),
	"adim": preload("res://oyunlar/labirent/sesler/adim.wav"),
	"duvar": preload("res://oyunlar/labirent/sesler/duvar.wav"),
	"yildiz": preload("res://oyunlar/labirent/sesler/yildiz.wav"),
	"yemek": preload("res://oyunlar/labirent/sesler/yemek.wav"),
	"bolum_sonu": preload("res://oyunlar/labirent/sesler/bolum_sonu.wav"),
	"final": preload("res://oyunlar/labirent/sesler/final.wav"),
	"tavsan": preload("res://oyunlar/labirent/sesler/tavsan.wav"),
	"sincap": preload("res://oyunlar/labirent/sesler/sincap.wav"),
	"fare": preload("res://oyunlar/labirent/sesler/fare.wav"),
	"kedi": preload("res://oyunlar/labirent/sesler/kedi.wav"),
	"kopek": preload("res://oyunlar/labirent/sesler/kopek.wav"),
	"kus": preload("res://oyunlar/labirent/sesler/kus.wav"),
	"maymun": preload("res://oyunlar/labirent/sesler/maymun.wav"),
	"panda": preload("res://oyunlar/labirent/sesler/panda.wav"),
	"inek": preload("res://oyunlar/labirent/sesler/inek.wav"),
	"ayi": preload("res://oyunlar/labirent/sesler/ayi.wav"),
}
const VOLUMES := {"tut": -10.0, "adim": -14.0, "duvar": -12.0, "yildiz": -8.0, "yemek": -6.0, "bolum_sonu": -6.0, "final": -5.0,
	"tavsan": -6.0, "sincap": -6.0, "fare": -6.0, "kedi": -6.0, "kopek": -6.0, "kus": -6.0, "maymun": -6.0, "panda": -6.0,
	"inek": -6.0, "ayi": -6.0}


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
