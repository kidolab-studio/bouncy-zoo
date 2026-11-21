extends RefCounted
# Sıradaki Ne? bölüm üreticisi (sahneden bağımsız, saf hesap): bölüm tablosundan (ayarlar.gd LEVELS) diziyi,
# boşlukları, seçenekleri ve ekrandaki yerleri kurar. problems(plan) kuralları denetler (testte de çalışır).
#
# Dizi: örüntü birimi (ör. "AAB") tekrar eder; her harfe temanın parça havuzundan bir parça düşer.
# İlk birim hep görünür (boşluk olmaz); son boşluk hep dizinin sonundadır ("orta" dışında).
# Seçenekler: her boşluğun doğru parçası + yanlışlar. Tek boşlukta en az bir yanlış örüntünün içinden gelir
# (ör. AB'de sona B gerekiyorsa A da seçeneklerde), kalanlar örüntü dışından.

const Settings := preload("res://oyunlar/siradaki_ne/ayarlar.gd")

## Sesler: örüntünün harfleri pentatonikte aralıklı notalar çalar (A pes, C tiz), örüntü dışındakiler araya düşer
const LETTER_NOTES := [0, 2, 4]
const EXTRA_NOTES := [5, 3, 1]
## Parçanın tutulma boyu yuvanın bu kadarı (temadan bağımsız; büyük çizilen hayvanlar da aynı alanla tutulur)
const GRAB_RATIO := 0.86


class Plan:
	var index: int = 0
	var level: Dictionary
	var theme: String
	var pattern: String
	var letters: String = ""                  # her yuvanın harfi
	var sequence: Array[String] = []          # her yuvanın parçası (dosya adı)
	var gaps: Array[int] = []                 # boş yuvalar (soldan sağa)
	var choices: Array[String] = []           # alttaki seçenekler (karışık sırada)
	var notes: Dictionary = {}                # parça -> nota sırası
	var area: Rect2                           # tasarım alanı (görünen alanın ortasındaki 1280x720)
	var screen: Vector2
	var cell: float = 140.0                   # yuva genişliği
	var piece: float = 120.0                  # parçanın görünen boyu (SVG tuvalinin genişliği)
	var grab: float = 120.0                   # parçanın tutulma boyu (yakalama alanı bunun GRAB_PADDING katı)
	var slots: Array[Vector2] = []            # yuvaların ortası
	var trays: Array[Vector2] = []            # seçeneklerin başlangıç yeri
	var floor_y: float = 520.0                # arka plandaki zemin çizgisi (ekran pikseli)

	func is_gap(slot: int) -> bool:
		return slot in gaps

	func slot_rect(slot: int) -> Rect2:
		return Rect2(slots[slot] - Vector2.ONE * cell / 2.0, Vector2.ONE * cell)


var rng := RandomNumberGenerator.new()
## Kenar payı (güvenli alan boşluğu daha büyükse oyun bunu büyütür)
var side: float = Settings.SIDE


func generate(index: int, screen: Vector2, area: Rect2) -> Plan:
	var plan := Plan.new()
	plan.index = index
	plan.level = Settings.LEVELS[index]
	plan.theme = plan.level["theme"]
	plan.pattern = plan.level["pattern"]
	plan.screen = screen
	plan.area = area
	_build_sequence(plan)
	_pick_gaps(plan)
	_pick_choices(plan)
	_layout(plan)
	return plan


func _build_sequence(plan: Plan) -> void:
	var pool := Settings.pool(plan.theme, plan.level["kind"], rng)
	_shuffle(pool)
	var alphabet := _alphabet(plan.pattern)
	var by_letter := {}
	for k in alphabet.size():
		by_letter[alphabet[k]] = pool[k]
		plan.notes[pool[k]] = LETTER_NOTES[k]
	# Örüntü dışı parçalar (yanlış seçenekler için) kendi notalarıyla
	for k in range(alphabet.size(), pool.size()):
		plan.notes[pool[k]] = EXTRA_NOTES[(k - alphabet.size()) % EXTRA_NOTES.size()]
	var length := Settings.length_of(plan.level)
	for i in length:
		var letter := plan.pattern[i % plan.pattern.length()]
		plan.letters += letter
		plan.sequence.append(by_letter[letter])


func _pick_gaps(plan: Plan) -> void:
	var length := plan.sequence.size()
	var unit := plan.pattern.length()
	var count := int(plan.level["gaps"])
	match plan.level["gap"]:
		"son":
			for i in range(length - count, length):
				plan.gaps.append(i)
		"orta":
			# İlk birimden sonra, sondan önce; tek boşluk
			var candidates: Array[int] = []
			for i in range(unit, length - 1):
				candidates.append(i)
			_shuffle(candidates)
			for k in count:
				plan.gaps.append(candidates[k])
		_:
			# Karışık: son yuva hep boş, kalanlar ilk birimden sonra; mümkünse yan yana gelmez
			var best: Array[int] = []
			for attempt in 60:
				var picked: Array[int] = [length - 1]
				var candidates: Array[int] = []
				for i in range(unit, length - 1):
					candidates.append(i)
				_shuffle(candidates)
				for i in candidates:
					if picked.size() < count:
						picked.append(i)
				if best.is_empty() or _adjacent(picked) < _adjacent(best):
					best = picked
				if _adjacent(best) == 0:
					break
			plan.gaps = best
	plan.gaps.sort()


func _pick_choices(plan: Plan) -> void:
	var needed: Array[String] = []
	for g in plan.gaps:
		needed.append(plan.sequence[g])
	var extra_count := int(plan.level["choices"]) - needed.size()
	# Örüntünün içinden ama gerekmeyen parçalar ve örüntü dışı parçalar
	var inside: Array[String] = []
	for k in _alphabet(plan.pattern).size():
		var piece: String = plan.sequence[plan.letters.find(_alphabet(plan.pattern)[k])]
		if not piece in needed:
			inside.append(piece)
	var outside: Array[String] = []
	for piece in plan.notes.keys():
		if not piece in plan.sequence:
			outside.append(piece)
	_shuffle(inside)
	_shuffle(outside)
	var order: Array[String] = []
	order.append_array(inside if plan.gaps.size() == 1 else outside)
	order.append_array(outside if plan.gaps.size() == 1 else inside)
	plan.choices = needed.duplicate()
	for k in mini(extra_count, order.size()):
		plan.choices.append(order[k])
	_shuffle(plan.choices)


func _layout(plan: Plan) -> void:
	var theme: Dictionary = Settings.THEMES[plan.theme]
	var a := plan.area
	var sy := a.size.y / 720.0
	var count := plan.sequence.size()
	var usable := a.size.x - 2.0 * side
	# Tırtılın başı ilk yuvanın solunda durur: ona bir yuva kadar yer
	var cells := count + (1 if plan.theme == "tirtil" else 0)
	plan.cell = minf(Settings.MAX_CELL, usable / cells)
	plan.piece = plan.cell * float(theme["piece"])
	plan.grab = plan.cell * GRAB_RATIO
	var left := a.get_center().x - plan.cell * count / 2.0 + plan.cell / 2.0
	if plan.theme == "tirtil":
		left += plan.cell / 2.0
	var row_y := a.position.y + Settings.ROW_Y * sy
	for i in count:
		var t := (float(i) / maxf(1.0, count - 1)) * 2.0 - 1.0
		var y := row_y + float(theme["sag"]) * (1.0 - t * t) + float(theme["wave"]) * sin(i * 1.4)
		plan.slots.append(Vector2(left + i * plan.cell, y))
	var n := plan.choices.size()
	var spacing := minf(Settings.TRAY_SPACING, usable / maxf(1.0, n))
	var tray_y := a.position.y + Settings.TRAY_Y * sy
	for k in n:
		plan.trays.append(Vector2(a.get_center().x + (k - (n - 1) / 2.0) * spacing, tray_y))
	plan.floor_y = a.position.y + Settings.FLOOR_Y * sy


## Kurallara uymayan her şey (boş liste: sorun yok)
func problems(plan: Plan) -> PackedStringArray:
	var out := PackedStringArray()
	var unit := plan.pattern.length()
	if plan.gaps.size() != int(plan.level["gaps"]):
		out.append("boşluk sayısı yanlış")
	for g in plan.gaps:
		if g < unit:
			out.append("ilk birimde boşluk var")
	if plan.level["gap"] != "orta" and not (plan.sequence.size() - 1) in plan.gaps:
		out.append("son yuva boş değil")
	if plan.level["gap"] == "orta" and (plan.sequence.size() - 1) in plan.gaps:
		out.append("ortadaki boşluk sonda")
	# Her harf, boşluklar dışında en az bir kez görünmeli
	for letter in _alphabet(plan.pattern):
		var seen := false
		for i in plan.sequence.size():
			if plan.letters[i] == letter and not i in plan.gaps:
				seen = true
		if not seen:
			out.append("%s harfi hiç görünmüyor" % letter)
	if plan.choices.size() != int(plan.level["choices"]):
		out.append("seçenek sayısı yanlış (%d)" % plan.choices.size())
	var left := plan.choices.duplicate()
	for g in plan.gaps:
		var k := left.find(plan.sequence[g])
		if k < 0:
			out.append("boşluk %d için seçenek yok" % g)
		else:
			left.remove_at(k)
	if left.is_empty():
		out.append("yanlış seçenek yok")
	if plan.gaps.size() == 1:
		var inside_wrong := false
		for piece in left:
			if piece in plan.sequence:
				inside_wrong = true
		if not inside_wrong:
			out.append("örüntü içinden yanlış seçenek yok")
	var touch := plan.grab * Settings.GRAB_PADDING
	if touch < Settings.MIN_TOUCH:
		out.append("dokunma alanı küçük (%.0f)" % touch)
	var visible := Rect2(Vector2.ZERO, plan.screen)
	for p in plan.slots + plan.trays:
		if not visible.grow(-plan.grab * 0.5).has_point(p):
			out.append("ekran dışında parça (%.0f, %.0f)" % [p.x, p.y])
		if not plan.area.has_point(p):
			out.append("tasarım alanı dışında parça")
	for k in range(1, plan.trays.size()):
		if plan.trays[k].x - plan.trays[k - 1].x < touch:
			out.append("seçenekler üst üste biniyor")
	if plan.trays[0].y - plan.slots.reduce(func(m: float, p: Vector2) -> float: return maxf(m, p.y), 0.0) < plan.cell * 1.6:
		out.append("dizi ve seçenekler çok yakın")
	return out


func _alphabet(pattern: String) -> Array[String]:
	var out: Array[String] = []
	for ch in pattern:
		if not ch in out:
			out.append(ch)
	return out


func _adjacent(picked: Array[int]) -> int:
	var count := 0
	for a in picked:
		if (a + 1) in picked:
			count += 1
	return count


func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
