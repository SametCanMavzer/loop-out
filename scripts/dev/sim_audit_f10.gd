extends Node
## F10 ses denetimi (headless): vuş metronomu ip turlarıyla birebir mi, ses gameplay
## determinizmini etkiliyor mu, slow-motion zaman ölçeğini geri bırakıyor mu.
## Çalıştırma: godot --headless scenes/dev/sim_audit_f10.tscn

var _fail := 0


func _ready() -> void:
	_check_whoosh_matches_turns()
	_check_sound_does_not_affect_gameplay()
	await _check_slowmo_restores_time_scale()
	if _fail == 0:
		print("AUDIT F10 OK (vuş=tur sayısı, ses gameplay'i etkilemiyor, slow-mo time_scale iadesi)")
	else:
		print("AUDIT F10 FAILED: %d hata" % _fail)
	get_tree().quit(_fail)


func _make() -> Dictionary:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var q := InputQueue.new()
	add_child(q)
	ctrl.setup(q)
	ctrl.set_physics_process(false)
	return {"ctrl": ctrl, "q": q}


func _free(d: Dictionary) -> void:
	d.ctrl.queue_free()
	d.q.queue_free()


## "Vuş" ritim sesidir (§8.2): ip oyuncu bölgesinden her geçişte tam 1 kez tetiklenmeli.
## Toplam vuş sayısı = tamamlanan tur sayısı olmalı (±1 kısmi tur payı).
func _check_whoosh_matches_turns() -> void:
	var d := _make()
	var count := {"n": 0}
	d.ctrl.rope_swept_front.connect(func() -> void: count.n += 1)
	d.ctrl.start_round(3131)
	# Yalnız tur 1-5: bu tier'da sadece "normal" aktif (yön değişmez). reverse sonrası ip
	# oyuncunun üstünden geri de geçer — o durumda vuş > tur olması DOĞRUdur (gerçek süpürme).
	for i in 4000:
		d.ctrl.step()
		if d.ctrl.round_no > 5 or d.ctrl.alive_ids.size() <= 1:
			break
	var turns: int = d.ctrl.rope.turns
	if absi(count.n - turns) > 1:
		push_error("FAIL: vuş sayısı %d, ip turu %d — ritim ipe kilitli değil." % [count.n, turns])
		_fail += 1
	else:
		print("  vuş %d / ip turu %d (sabit yönde ritim ipe kilitli)" % [count.n, turns])
	_free(d)


## Ses açık/kapalı gameplay sonucunu DEĞİŞTİRMEMELİ (§4.8: ses hiçbir stream'i tüketmez).
func _check_sound_does_not_affect_gameplay() -> void:
	var fp_on := _fingerprint(true)
	var fp_off := _fingerprint(false)
	if fp_on != fp_off:
		push_error("FAIL: ses açık/kapalı farklı tur üretti.\n  açık=%s\n  kapalı=%s" % [fp_on, fp_off])
		_fail += 1
	else:
		print("  ses açık/kapalı aynı tur: %s" % fp_on)


func _fingerprint(sound_on: bool) -> String:
	Audio.set_enabled(sound_on)
	var d := _make()
	var order: Array = []
	var cb := func(id: int, _cause: int) -> void: order.append(id)
	EventBus.jumper_eliminated.connect(cb)
	d.ctrl.start_round(8080)
	for i in 3000:
		d.ctrl.step()
		if d.ctrl.alive_ids.size() <= 1:
			break
	EventBus.jumper_eliminated.disconnect(cb)
	var fp := "tur=%d canlı=%d açı=%.4f elenme=%s" % [
		d.ctrl.round_no, d.ctrl.alive_ids.size(), d.ctrl.rope.angle, str(order)]
	_free(d)
	Audio.set_enabled(true)
	return fp


## Slow-motion bittiğinde Engine.time_scale 1.0'a dönmeli (yoksa oyun kalıcı ağır çeker).
func _check_slowmo_restores_time_scale() -> void:
	var director := AudioDirector.new()
	add_child(director)
	var d := _make()
	director.setup(d.ctrl)
	EventBus.player_eliminated.emit(9)
	# Sinyal işleyicisinin ilk (await öncesi) kısmı SENKRON çalışır → time_scale hemen düşmeli.
	if is_equal_approx(Engine.time_scale, 1.0):
		push_error("FAIL: slow-motion hiç uygulanmadı (time_scale 1.0 kaldı)."); _fail += 1
	else:
		print("  slow-mo devrede: time_scale=%.2f" % Engine.time_scale)
	await get_tree().create_timer(AudioDirector.SLOWMO_REAL_S + 0.2, true, false, true).timeout
	if not is_equal_approx(Engine.time_scale, 1.0):
		push_error("FAIL: slow-motion sonrası time_scale iade edilmedi (%f)." % Engine.time_scale)
		_fail += 1
	director.queue_free()
	_free(d)
