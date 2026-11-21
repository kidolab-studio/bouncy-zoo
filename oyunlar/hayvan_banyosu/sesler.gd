extends "res://ortak/ses_havuzu.gd"
# Hayvan Banyosu sesleri (ortak ses havuzu). Sesler sesler/ses_uret.py ile üretildi; hayvan sesleri
# Hayvanları Besle'den kopya. Sünger, duş ve havlu sesi döngüdür: set_loop(ad, seviye, delta) her karede
# çağrılır; parmak durunca seviye düşer, ses yumuşakça kısılıp durur (Boyama Kitabı'ndaki gibi).

const S := "res://oyunlar/hayvan_banyosu/sesler/"
const STREAMS := {
	"kopur": preload(S + "kopur.wav"),
	"temiz": preload(S + "temiz.wav"),
	"adim": preload(S + "adim.wav"),
	"silkin": preload(S + "silkin.wav"),
	"kabarcik": preload(S + "kabarcik.wav"),
	"pop": preload(S + "pop.wav"),
	"kikir": preload(S + "kikir.wav"),
	"bolum_sonu": preload(S + "bolum_sonu.wav"),
	"final": preload(S + "final.wav"),
}
const VOLUMES := {"kopur": -9.0, "temiz": -9.0, "adim": -7.0, "silkin": -7.0, "kabarcik": -12.0, "pop": -9.0,
	"kikir": -9.0, "bolum_sonu": -6.0, "final": -5.0}
const LOOPS := {"sunger": preload(S + "sunger.wav"), "dus": preload(S + "dus.wav"), "havlu": preload(S + "havlu.wav")}
const LOOP_VOLUME := {"sunger": -15.0, "dus": -17.0, "havlu": -15.0}
const VOICE_VOLUME := -6.0

var _loop: AudioStreamPlayer
var _loop_name: String = ""
var _loop_gain: float = 0.0


func _init() -> void:
	streams = STREAMS.duplicate()
	volumes = VOLUMES.duplicate()
	player_count = 10


func _ready() -> void:
	super._ready()
	for stream: AudioStreamWAV in LOOPS.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	_loop = AudioStreamPlayer.new()
	add_child(_loop)


# Hayvan sesi ("ses")
func set_voice(animal: BathAnimalData) -> void:
	streams["ses"] = animal.voice
	volumes["ses"] = VOICE_VOLUME


## name: "sunger" / "dus" / "havlu" / "" (yok); level 0..1 (parmağın hızı)
func set_loop(name: String, level: float, delta: float) -> void:
	var target := level if name != "" else 0.0
	_loop_gain = move_toward(_loop_gain, target, delta * (8.0 if target > _loop_gain else 4.0))
	if name != "" and name != _loop_name and level > 0.0:
		_loop_name = name
		_loop.stream = LOOPS[name]
		_loop.play(randf() * 0.8)
	if _loop_gain <= 0.001:
		if _loop.playing:
			_loop.stop()
		_loop_name = ""
		return
	if not _loop.playing and _loop_name != "":
		_loop.play(randf() * 0.8)
	_loop.volume_db = LOOP_VOLUME.get(_loop_name, -16.0) + linear_to_db(maxf(_loop_gain, 0.001))
