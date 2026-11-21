extends SceneTree
# Sıradaki Ne? bölüm üreticisi testi (headless):
#   godot --path . --headless --fixed-fps 60 -s res://oyunlar/siradaki_ne/testler/uretici_testi.gd
# Bölüm tablosunu denetler, sonra 7 ekran oranında her bölümü 300 kez üretir ve problems() boş mu bakar
# (seçenekler boşlukları karşılıyor mu, yanlış seçenek var mı, ilk birim görünüyor mu, ekrana sığıyor mu,
# dokunma alanı yeterli mi). Sonunda her bölümün örnek dizisini ve yuva boyunu yazar.

const Settings := preload("res://oyunlar/siradaki_ne/ayarlar.gd")
const Generator := preload("res://oyunlar/siradaki_ne/bolum_uretici.gd")
const SCREENS := [Vector2(1280, 720), Vector2(1440, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1680, 720),
	Vector2(1280, 960), Vector2(1280, 800)]
const ROUNDS := 300


func _initialize() -> void:
	var errors := PackedStringArray()
	for problem in Settings.problems():
		errors.append("tablo: " + problem)
	# Her parça dosyası var mı
	var rng := RandomNumberGenerator.new()
	for level in Settings.LEVELS:
		for k in 8:
			for piece in Settings.pool(level["theme"], level["kind"], rng):
				if not ResourceLoader.exists("res://oyunlar/siradaki_ne/gorseller/parcalar/%s.svg" % piece):
					errors.append("parça görseli yok: " + piece)
	var generator := Generator.new()
	for screen in SCREENS:
		var area := Rect2((screen - Vector2(1280, 720)) / 2.0, Vector2(1280, 720))
		for index in Settings.level_count():
			for r in ROUNDS:
				generator.rng.seed = hash([screen, index, r])
				var plan := generator.generate(index, screen, area)
				for problem in generator.problems(plan):
					var line := "%s bölüm %d: %s (%s, boşluk %s, seçenek %s)" % [screen, index + 1, problem, plan.letters, plan.gaps, plan.choices]
					if not line in errors:
						errors.append(line)
	# Örnek tablo
	generator.rng.seed = 7
	for index in Settings.level_count():
		var plan := generator.generate(index, Vector2(1280, 720), Rect2(0, 0, 1280, 720))
		var shown := ""
		for i in plan.letters.length():
			shown += "_" if plan.is_gap(i) else plan.letters[i]
		print("%2d %-7s %-5s %-6s %-9s yuva %.0f  %s  seçenek %d" % [index + 1, plan.theme, plan.pattern, plan.level["kind"], shown, plan.cell, plan.gaps, plan.choices.size()])
	if errors.is_empty():
		print("Üretici testi: hepsi tamam")
	else:
		for e in errors.slice(0, 40):
			printerr(e)
		printerr("Üretici testi: %d sorun" % errors.size())
	quit(0 if errors.is_empty() else 1)
