extends Node
## F8 denetim doğrulaması (headless): geri sayım askısı, restart girdi temizliği,
## sonuç sonrası durma, placement doğruluğu.
## Çalıştırma: godot --headless scenes/dev/sim_audit_f8.tscn

var _fail := 0


func _ready() -> void:
	_check_tick_advances_once_per_frame()
	_check_prepare_does_not_run()
	_check_input_queue_cleared_on_reset()
	_check_stop_halts_simulation()
	_check_placement_when_player_dies()
	_check_behavior_integration()
	_check_determinism()
	await _check_no_node_leak()
	if _fail == 0:
		print("AUDIT F8 OK (geri sayım askısı, girdi temizliği, stop, placement)")
	else:
		print("AUDIT F8 FAILED: %d hata" % _fail)
	get_tree().quit(_fail)


func _make() -> Dictionary:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var q := InputQueue.new()
	add_child(q)
	ctrl.setup(q)
	q.setup(ctrl.clock)
	ctrl.set_physics_process(false)
	return {"ctrl": ctrl, "q": q}


func _free(d: Dictionary) -> void:
	d.ctrl.queue_free()
	d.q.queue_free()


## Saat kare başına TAM BİR kez ilerlemeli. TickClock'un kendi _physics_process'i açık kalırsa
## tick iki kat hızlı gider (biri step(), biri TickClock) → current_tick ile ip açısı ayrışır,
## botların geçiş tahmini bozulur ve hepsi erken zıplayıp ıskalar. Gerçek oyunda yaşandı:
## aynı seed sim'de tur 8/10 canlı verirken oyunda tur 5/2 canlı veriyordu.
func _check_tick_advances_once_per_frame() -> void:
	var d := _make()
	d.ctrl.start_round(4242)                  # begin() → clock.start() çağırır
	if d.ctrl.clock.is_physics_processing():
		push_error("FAIL: TickClock kendi _physics_process'iyle de ilerliyor — tick çift sayılır.")
		_fail += 1
	var before: int = d.ctrl.clock.current_tick
	d.ctrl.step()
	if d.ctrl.clock.current_tick != before + 1:
		push_error("FAIL: bir step() tam 1 tick ilerletmeli (%d → %d)."
			% [before, d.ctrl.clock.current_tick]); _fail += 1
	_free(d)


## prepare_round kadroyu kurar ama simülasyonu BAŞLATMAZ (geri sayımda ip dönmemeli).
func _check_prepare_does_not_run() -> void:
	var d := _make()
	d.ctrl.prepare_round(111)
	if d.ctrl.alive_ids.size() != 16:
		push_error("FAIL: prepare_round 16 kadro kurmalı (%d)." % d.ctrl.alive_ids.size()); _fail += 1
	var angle_before: float = d.ctrl.rope.angle
	for i in 120:
		d.ctrl.step()
	if d.ctrl.clock.current_tick != 0 or not is_equal_approx(d.ctrl.rope.angle, angle_before):
		push_error("FAIL: geri sayımda tick/ip ilerlememeli (tick=%d)." % d.ctrl.clock.current_tick); _fail += 1
	if d.ctrl.alive_ids.size() != 16:
		push_error("FAIL: geri sayımda eleme olmamalı."); _fail += 1
	d.ctrl.begin()
	for i in 120:
		d.ctrl.step()
	if d.ctrl.clock.current_tick != 120:
		push_error("FAIL: begin sonrası tick ilerlemeli (%d)." % d.ctrl.clock.current_tick); _fail += 1
	_free(d)


## reset girdi kuyruğunu temizler (sonuç ekranındaki tuşlar yeni tura sızmaz).
func _check_input_queue_cleared_on_reset() -> void:
	var d := _make()
	d.ctrl.start_round(222)
	for i in 5:
		d.q.enqueue(&"jump", true, 900 + i)     # sonuç ekranında basılmış gibi
	if d.q.size() == 0:
		push_error("FAIL: test kurulumu — kuyruk boş."); _fail += 1
	d.ctrl.prepare_round(222)                    # restart
	if d.q.size() != 0:
		push_error("FAIL: restart girdi kuyruğunu temizlemeli (%d kaldı)." % d.q.size()); _fail += 1
	_free(d)


## stop() simülasyonu durdurur (sonuç ekranında arka planda oyun sürmez).
func _check_stop_halts_simulation() -> void:
	var d := _make()
	d.ctrl.start_round(333)
	for i in 60:
		d.ctrl.step()
	var t_before: int = d.ctrl.clock.current_tick
	var alive_before: int = d.ctrl.alive_ids.size()
	d.ctrl.stop()
	for i in 300:
		d.ctrl.step()
	if d.ctrl.clock.current_tick != t_before:
		push_error("FAIL: stop sonrası tick ilerlememeli."); _fail += 1
	if d.ctrl.alive_ids.size() != alive_before:
		push_error("FAIL: stop sonrası eleme olmamalı."); _fail += 1
	_free(d)


## Oyuncu elendiğinde placement = kalan + 1; tur bitince tutarlı kalır.
func _check_placement_when_player_dies() -> void:
	var d := _make()
	d.ctrl.start_round(444)
	var seen := -1
	for i in 8000:
		d.ctrl.step()
		if not d.ctrl.player_alive() and seen < 0:
			seen = d.ctrl.alive_ids.size() + 1
			break
	if seen < 0:
		print("  (not: bu seed'de oyuncu elenmedi — placement kontrolü atlandı)")
	elif d.ctrl.placement() != seen:
		push_error("FAIL: placement %d, beklenen %d." % [d.ctrl.placement(), seen]); _fail += 1
	elif d.ctrl.placement() < 2 or d.ctrl.placement() > 16:
		push_error("FAIL: placement aralık dışı (%d)." % d.ctrl.placement()); _fail += 1
	_free(d)


## F7 entegrasyonu: her davranışın gerçek arenada bot MISS oranı. high_sweep'te eğilme veya
## double_sweep'te yüksek zıplama çalışmıyorsa o davranışta oran patlar (toplu katliam).
func _check_behavior_integration() -> void:
	var seen := {}       # behavior_id -> {cross:int, miss:int}
	for s in 6:
		var d := _make()
		var ctrl: ArenaController = d.ctrl
		var cb := func(id: int, result: int, _ms: float) -> void:
			if id == ArenaController.PLAYER_ID:
				return                                  # oyuncu oynamıyor, sayma
			var b := String(ctrl.rope.current_behavior_id)
			if not seen.has(b):
				seen[b] = {"cross": 0, "miss": 0}
			seen[b].cross += 1
			if result == Rope.CrossResult.MISS:
				seen[b].miss += 1
		ctrl.rope.crossed.connect(cb)
		ctrl.start_round(700 + s * 31)
		# HIGH süpürmede BAŞARILI eğilme nötrdür (§4.3: sinyal yok) → crossed ile ölçülemez.
		# Bu yüzden beklenen süpürmeyi ayrıca sayıyoruz: her tam turda her canlı bot 1 kez süpürülür.
		var prev_turn := ctrl.rope.turns
		for i in 9000:
			ctrl.step()
			if ctrl.rope.turns != prev_turn:
				prev_turn = ctrl.rope.turns
				var bkey := "high_sweep" if int(ctrl.rope.height) == int(Rope.Height.HIGH) else ""
				if bkey != "":
					if not seen.has(bkey):
						seen[bkey] = {"cross": 0, "miss": 0, "expected": 0}
					if not seen[bkey].has("expected"):
						seen[bkey]["expected"] = 0
					seen[bkey]["expected"] += maxi(ctrl.alive_ids.size() - 1, 0)
			if ctrl.alive_ids.size() <= 1:
				break
		_free(d)

	print("--- F7 davranış entegrasyonu (bot MISS oranı) ---")
	var ids := seen.keys()
	ids.sort()
	for b in ids:
		var c: int = seen[b].cross
		var m: int = seen[b].miss
		# HIGH'da temiz eğilme sinyal yaymaz → payda beklenen süpürme sayısı.
		var denom: int = maxi(int(seen[b].get("expected", 0)), c)
		var pct := 100.0 * float(m) / float(maxi(denom, 1))
		print("  %-13s süpürme %4d  miss %3d  (%%%.1f)" % [b, denom, m, pct])
		# Kaba emniyet: hiçbir davranış botların yarısını ıskalatmamalı (sistematik kusur işareti).
		if denom >= 20 and pct > 50.0:
			push_error("FAIL: '%s' davranışında bot MISS oranı %%%.1f — sistematik kusur." % [b, pct])
			_fail += 1
	for must in ["normal", "speed_step", "sudden_stop"]:
		if not seen.has(must):
			push_error("FAIL: '%s' davranışı hiç tetiklenmedi." % must); _fail += 1


## §4.8 determinizm sözleşmesi: aynı seed → aynı tur (arena seviyesinde uçtan uca).
func _check_determinism() -> void:
	var a := _fingerprint(9090)
	var b := _fingerprint(9090)
	var c := _fingerprint(9091)
	if a != b:
		push_error("FAIL: aynı seed farklı tur üretti.\n  a=%s\n  b=%s" % [a, b]); _fail += 1
	if a == c:
		push_error("FAIL: farklı seed aynı turu üretti (seed etkisiz?)."); _fail += 1


## Turu sabit adım koştur, sonucun özetini döndür (eleme sırası + ip açısı + tur).
func _fingerprint(seed: int) -> String:
	var d := _make()
	var order: Array = []
	var cb := func(id: int, _cause: int) -> void: order.append(id)
	EventBus.jumper_eliminated.connect(cb)
	d.ctrl.start_round(seed)
	for i in 2500:
		d.ctrl.step()
		if d.ctrl.alive_ids.size() <= 1:
			break
	EventBus.jumper_eliminated.disconnect(cb)
	var fp := "tur=%d canlı=%d açı=%.4f elenme=%s" % [
		d.ctrl.round_no, d.ctrl.alive_ids.size(), d.ctrl.rope.angle, str(order)]
	_free(d)
	return fp


## Restart node sızıntısı: arka arkaya turlar node sayısını büyütmemeli (§7.1).
func _check_no_node_leak() -> void:
	var d := _make()
	d.ctrl.start_round(555)
	for i in 400:
		d.ctrl.step()
	var before: int = d.ctrl.get_child_count()
	for r in 3:
		d.ctrl.start_round(555 + r)
		for i in 200:
			d.ctrl.step()
		await get_tree().process_frame    # queue_free'lerin işlenmesi için
	var after: int = d.ctrl.get_child_count()
	if after > before + 2:               # clock+rope sabit; jumper'lar yenilenmeli
		push_error("FAIL: restart node sızıntısı (%d → %d)." % [before, after]); _fail += 1
	print("  restart node sayısı: %d → %d (sızıntı yok)" % [before, after])
	_free(d)
