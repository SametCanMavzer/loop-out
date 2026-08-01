extends Node
## F11 determinizm doğrulaması (TDD §4.8): oyuncu girdisiyle oynanan bir tur, {seed, inputs}
## kaydından yeniden oynatıldığında BİREBİR aynı olmalı — "bug raporu = seed" ve v2a ghost bu
## sözleşmeye dayanır. Ayrıca farklı seed'in gerçekten farklı tur ürettiği kontrol edilir.
## Çalıştırma: godot --headless scenes/dev/sim_replay.tscn

const TICKS := 2600

var _fail := 0


func _ready() -> void:
	_check_replay_reproduces_round(4711)
	_check_replay_reproduces_round(9002)
	_check_seed_matters()
	_check_bot_only_determinism()
	if _fail == 0:
		print("SIM REPLAY OK (kayıttan birebir yeniden oynatma, seed etkisi, bot determinizmi)")
	else:
		print("SIM REPLAY FAILED: %d hata" % _fail)
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


## Turun tam parmak izi: tick tick ilerlerken oluşan olayların özeti.
func _run(d: Dictionary, seed: int, script_input: Array, replay: Array) -> Dictionary:
	var ctrl: ArenaController = d.ctrl
	var q: InputQueue = d.q
	var events: Array = []
	var cb_cross := func(id: int, result: int, ms: float) -> void:
		events.append("c%d:%d:%d" % [id, result, int(ms)])
	var cb_elim := func(id: int, _cause: int) -> void:
		events.append("e%d" % id)
	EventBus.rope_crossed.connect(cb_cross)
	EventBus.jumper_eliminated.connect(cb_elim)

	ctrl.prepare_round(seed)
	if not replay.is_empty():
		ctrl.use_replay_input(replay)          # kayıttan oynat
	elif not script_input.is_empty():
		for e in script_input:                 # senaryolu "oyuncu" girdisi
			q.enqueue(StringName(e[1]), bool(e[2]), int(e[0]))
	ctrl.begin()

	for i in TICKS:
		ctrl.step()
		if ctrl.alive_ids.size() <= 1:
			break

	EventBus.rope_crossed.disconnect(cb_cross)
	EventBus.jumper_eliminated.disconnect(cb_elim)
	return {
		"fp": "tur=%d canlı=%d açı=%.5f hız=%.5f olay=%d\n%s" % [
			ctrl.round_no, ctrl.alive_ids.size(), ctrl.rope.angle, ctrl.rope.angular_vel,
			events.size(), "|".join(events)],
		"record": ctrl.input_recording().duplicate(true),
		"placement": ctrl.placement(),
	}


## Deterministik "oyuncu" girdisi üret (gerçek oyuncu gibi düzensiz zıplamalar).
func _script_input(seed: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var out: Array = []
	var t := 20
	while t < TICKS:
		out.append([t, "jump", true])
		out.append([t + 2, "jump", false])
		if rng.randf() < 0.25:                 # ara sıra eğilme (yüksek süpürme denemesi)
			out.append([t + 6, "duck", true])
			out.append([t + 20, "duck", false])
		t += rng.randi_range(28, 95)
	return out


func _check_replay_reproduces_round(seed: int) -> void:
	var d1 := _make()
	var live := _run(d1, seed, _script_input(seed), [])
	var record: Array = live.record
	_free(d1)

	if record.is_empty():
		push_error("FAIL: girdi kaydı boş — replay kaydı çalışmıyor."); _fail += 1
		return

	var d2 := _make()
	var replayed := _run(d2, seed, [], record)
	_free(d2)

	if live.fp != replayed.fp:
		push_error("FAIL: seed %d — replay turu birebir üretmedi.\n  canlı  : %s\n  replay : %s"
			% [seed, live.fp.substr(0, 160), replayed.fp.substr(0, 160)])
		_fail += 1
	elif live.placement != replayed.placement:
		push_error("FAIL: seed %d — placement farklı (%d vs %d)." % [seed, live.placement, replayed.placement])
		_fail += 1
	else:
		print("  seed %d: %d girdi kaydı → tur birebir yeniden üretildi (placement %d)"
			% [seed, record.size(), live.placement])


## Farklı seed farklı tur üretmeli (seed gerçekten etkili mi).
func _check_seed_matters() -> void:
	var da := _make(); var a := _run(da, 1001, [], []); _free(da)
	var db := _make(); var b := _run(db, 2002, [], []); _free(db)
	if a.fp == b.fp:
		push_error("FAIL: farklı seed aynı turu üretti (seed etkisiz)."); _fail += 1


## Girdi olmadan (yalnız botlar) aynı seed → aynı tur.
func _check_bot_only_determinism() -> void:
	var d1 := _make(); var r1 := _run(d1, 5150, [], []); _free(d1)
	var d2 := _make(); var r2 := _run(d2, 5150, [], []); _free(d2)
	if r1.fp != r2.fp:
		push_error("FAIL: bot-only tur aynı seed'de tekrar etmedi."); _fail += 1
