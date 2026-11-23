extends "res://ortak/ses_havuzu.gd"
# Hayvan Doktoru sesleri (ortak ses havuzu). Sesler sesler/ses_uret.py ile üretildi; hayvan sesleri Hayvanları
# Besle'den kopya. Sürtülen aletlerin sesi döngüdür (Hayvan Banyosu'ndaki gibi): set_loop(ad, seviye, delta) her
# karede çağrılır; parmak durunca seviye düşer, ses yumuşakça kısılıp durur.

const S := "res://oyunlar/hayvan_doktoru/sesler/"
const STREAMS := {
	"kalp": preload(S + "kalp.wav"),
	"bant": preload(S + "bant.wav"),
	"cek": preload(S + "cek.wav"),
	"yut": preload(S + "yut.wav"),
	"hapsu": preload(S + "hapsu.wav"),
	"damla": preload(S + "damla.wav"),
	"buz": preload(S + "buz.wav"),
	"sargi": preload(S + "sargi.wav"),
	"temiz": preload(S + "temiz.wav"),
	"adim": preload(S + "adim.wav"),
	"iyilesti": preload(S + "iyilesti.wav"),
	"gun_sonu": preload(S + "gun_sonu.wav"),
	"final": preload(S + "final.wav"),
	"sayfa": preload(S + "sayfa.wav"),
	"cikartma": preload(S + "cikartma.wav"),
	"pop": preload(S + "pop.wav"),
	"kikir": preload(S + "kikir.wav"),
}
const VOLUMES := {"kalp": -5.0, "bant": -8.0, "cek": -8.0, "yut": -7.0, "hapsu": -6.0, "damla": -10.0, "buz": -9.0,
	"sargi": -8.0, "temiz": -9.0, "adim": -7.0, "iyilesti": -6.0, "gun_sonu": -6.0, "final": -5.0, "sayfa": -9.0, "cikartma": -7.0, "pop": -9.0, "kikir": -9.0}
const LOOPS := {"sil": preload(S + "sil.wav"), "merhem": preload(S + "merhem.wav"), "fircala": preload(S + "fircala.wav")}
const LOOP_VOLUME := {"sil": -15.0, "merhem": -15.0, "fircala": -16.0}
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


# Hastanın sesi ("ses")
func set_voice(animal: ClinicAnimalData) -> void:
	streams["ses"] = animal.voice
	volumes["ses"] = VOICE_VOLUME


## name: LOOPS'taki bir ad ya da "" (yok); level 0..1 (parmağın hızı)
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
