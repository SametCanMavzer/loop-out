extends SceneTree
## F2 tick çekirdeği birim testi: TickClock determinizmi, Rng stream'leri, InputQueue
## tick damgalama + FIFO poll. (godot --headless -s res://tests/test_tick_core.gd)

func _process(_delta: float) -> bool:
	var fail := 0

	# --- TickClock: advance say + reset ---
	var clock := TickClock.new()
	var last_signal := {"tick": -1}
	clock.ticked.connect(func(t: int) -> void: last_signal.tick = t)
	for i in 5:
		clock.advance()
	if clock.current_tick != 5:
		push_error("FAIL: current_tick=%d, beklenen 5." % clock.current_tick); fail += 1
	if last_signal.tick != 5:
		push_error("FAIL: ticked sinyali son değeri=%d, beklenen 5." % last_signal.tick); fail += 1
	clock.reset()
	if clock.current_tick != 0 or clock.running:
		push_error("FAIL: reset sonrası tick/running sıfırlanmadı."); fail += 1

	# --- Determinizm: iki saat aynı adımda aynı tick ---
	var c1 := TickClock.new(); var c2 := TickClock.new()
	for i in 123:
		c1.advance(); c2.advance()
	if c1.current_tick != c2.current_tick:
		push_error("FAIL: iki TickClock farklı tick üretti."); fail += 1

	# --- Rng: aynı seed → aynı dizi; farklı stream → farklı dizi ---
	var rng := root.get_node_or_null(^"Rng")
	if rng == null:
		push_error("FAIL: Rng autoload yok."); fail += 1
	else:
		rng.call("seed_round", 42)
		var b1: int = rng.get("behavior").randi()
		var bots1: int = rng.get("bots").randi()
		rng.call("seed_round", 42)
		var b2: int = rng.get("behavior").randi()
		if b1 != b2:
			push_error("FAIL: Rng.behavior aynı seed'de farklı değer."); fail += 1
		if b1 == bots1:
			push_error("FAIL: behavior ve bots stream'leri aynı değeri verdi (bağımsız olmalı)."); fail += 1

	# --- InputQueue: tick damgalama + FIFO poll ---
	var q := InputQueue.new()
	q.enqueue(&"jump", true, 3)
	q.enqueue(&"duck", true, 5)
	q.enqueue(&"jump", false, 4)
	var got := q.poll(4)  # tick<=4 olanlar, yakalanma sırasıyla: jump@3(basıldı), jump@4(bırakıldı)
	if got.size() != 2:
		push_error("FAIL: poll(4) %d komut döndü, beklenen 2." % got.size()); fail += 1
	elif got[0].tick != 3 or not got[0].pressed or got[1].tick != 4 or got[1].pressed:
		push_error("FAIL: poll(4) sıra/damga yanlış."); fail += 1
	if q.size() != 1:
		push_error("FAIL: poll sonrası kuyrukta %d kaldı, beklenen 1." % q.size()); fail += 1
	var got2 := q.poll(100)
	if got2.size() != 1 or got2[0].action != &"duck" or got2[0].tick != 5:
		push_error("FAIL: kalan duck@5 komutu doğru çıkmadı."); fail += 1

	# Sızıntı olmasın: ağaç dışı Node'ları serbest bırak.
	clock.free(); c1.free(); c2.free(); q.free()

	if fail == 0:
		print("TEST TICK CORE OK (TickClock determinizm, Rng stream, InputQueue damga+poll)")
	else:
		print("TEST TICK CORE FAILED: %d hata" % fail)
	quit(fail)
	return true
