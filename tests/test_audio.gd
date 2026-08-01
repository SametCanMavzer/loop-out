extends SceneTree
## F10 ses testi: prosedürel SFX üretimi, bus kurulumu, havuz round-robin, müzik pitch, mute.
## (godot --headless -s res://tests/test_audio.gd)

func _process(_delta: float) -> bool:
	var fail := 0

	# --- SfxGen: üretilen stream'ler geçerli mi ---
	var streams := {
		"whoosh": SfxGen.whoosh(), "perfect": SfxGen.perfect(), "graze": SfxGen.graze(),
		"stumble": SfxGen.stumble(), "eliminate": SfxGen.eliminate(),
		"telegraph": SfxGen.telegraph(), "pardon": SfxGen.pardon(), "coin": SfxGen.coin(),
	}
	for k in streams:
		var s: AudioStreamWAV = streams[k]
		if s == null or s.data.size() < 1000:
			push_error("FAIL: '%s' sesi üretilemedi/çok kısa." % k); fail += 1
		elif s.format != AudioStreamWAV.FORMAT_16_BITS or s.mix_rate != SfxGen.RATE:
			push_error("FAIL: '%s' formatı yanlış." % k); fail += 1
		elif s.get_length() <= 0.0:
			push_error("FAIL: '%s' uzunluğu 0." % k); fail += 1

	# Müzik loop'u döngüye ayarlı mı (§8.3 tek loop)
	var music := SfxGen.music_loop()
	if music.loop_mode != AudioStreamWAV.LOOP_FORWARD or music.get_length() < 1.0:
		push_error("FAIL: müzik loop'u döngüsel/yeterli uzunlukta değil."); fail += 1

	# --- Audio autoload: bus'lar + havuz + kütüphane ---
	var audio := root.get_node_or_null(^"Audio")
	if audio == null:
		push_error("FAIL: Audio autoload yok."); print("TEST AUDIO FAILED"); quit(1); return true
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			push_error("FAIL: '%s' bus'ı kurulmadı (§8.1)." % bus); fail += 1
	var pool: Array = audio.get("_pool")
	if pool.size() != audio.get("POOL_SIZE"):
		push_error("FAIL: SFX havuzu 8 olmalı (%d)." % pool.size()); fail += 1

	# Round-robin: 8 çağrıdan sonra başa dönmeli
	var before: int = audio.get("_next")
	for i in 8:
		audio.call("play", &"whoosh")
	if audio.get("_next") != before:
		push_error("FAIL: havuz 8 çağrıda başa dönmeli (round-robin)."); fail += 1

	# Bilinmeyen ses adı çökmemeli
	audio.call("play", &"olmayan_ses")

	# --- Müzik hız bağlama (§8.3: pitch = rpm/start_rpm) ---
	audio.call("set_music_speed", 50.0, 25.0)
	var mp: AudioStreamPlayer = audio.get("_music")
	if mp == null or not is_equal_approx(mp.pitch_scale, 2.0):
		push_error("FAIL: 2× hızda pitch 2.0 olmalı (%s)." % (str(mp.pitch_scale) if mp else "null")); fail += 1
	audio.call("set_music_speed", 25.0, 25.0)
	if not is_equal_approx(mp.pitch_scale, 1.0):
		push_error("FAIL: başlangıç hızında pitch 1.0 olmalı."); fail += 1
	audio.call("set_music_speed", 999.0, 25.0)      # tavan kırpması
	if mp.pitch_scale > 2.5001:
		push_error("FAIL: pitch tavanı 2.5 aşılmamalı (%f)." % mp.pitch_scale); fail += 1

	# --- Mute (§8.1: tek toggle = Master mute) ---
	audio.call("set_enabled", false)
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) or bool(audio.call("is_enabled")):
		push_error("FAIL: ses kapatılınca Master mute olmalı."); fail += 1
	audio.call("set_enabled", true)
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		push_error("FAIL: ses açılınca mute kalkmalı."); fail += 1

	if fail == 0:
		print("TEST AUDIO OK (SFX üretimi, bus, havuz round-robin, müzik pitch, mute)")
	else:
		print("TEST AUDIO FAILED: %d hata" % fail)
	quit(fail)
	return true
