class_name MusicSong
extends Resource
# Şarkı modu için bir şarkı: melodinin notaları ve süreleri. Sadece melodi, söz yok.
# Yeni şarkı: sarkilar/ içine yeni bir .tres (bu script) koy ve ksilofon.gd SONGS listesine bir satır ekle.

## Ksilofonun 8 tuşu, soldan sağa (pesten tize)
const NOTE_NAMES: PackedStringArray = ["do", "re", "mi", "fa", "sol", "la", "si", "do2"]

## Ksilofonun defter düğmesinde görünen küçük resim
@export var icon: Texture2D
# notes / beats varsayılanı [] olmamalı: [] ile dışa aktarılan oyunda (Godot 4.7.2) .tres'teki değerler boş geliyor
## Notalar sırayla: "do", "re", "mi", "fa", "sol", "la", "si", "do2" (ince do)
@export var notes: PackedStringArray = PackedStringArray()
## Her notanın süresi (vuruş; 1 = dörtlük, 0.5 = sekizlik, 2 = ikilik). notes ile aynı uzunlukta.
@export var beats: PackedFloat32Array = PackedFloat32Array()
## Dakikadaki vuruş: şarkı bitince kutlama olarak bu hızla kendiliğinden çalınır
@export var tempo: float = 110.0


func size() -> int:
	return notes.size()


## i. notanın ksilofon tuşu (0-7)
func bar(i: int) -> int:
	return NOTE_NAMES.find(notes[i])


func seconds(i: int) -> float:
	return beats[i] * 60.0 / tempo


func problems() -> PackedStringArray:
	var list: PackedStringArray = []
	if notes.is_empty():
		list.append("%s: nota yok" % resource_path)
	if notes.size() != beats.size():
		list.append("%s: notes (%d) ve beats (%d) aynı uzunlukta değil" % [resource_path, notes.size(), beats.size()])
	for name in notes:
		if not NOTE_NAMES.has(name):
			list.append("%s: bilinmeyen nota '%s'" % [resource_path, name])
	for beat in beats:
		if beat <= 0.0:
			list.append("%s: süre sıfırdan büyük olmalı" % resource_path)
			break
	if tempo <= 0.0:
		list.append("%s: tempo sıfırdan büyük olmalı" % resource_path)
	return list
