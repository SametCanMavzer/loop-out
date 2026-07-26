extends Node
## Teşhis: hiç zıplamayan oyuncu ne zaman eleniyor? (Samet: "zıplamasam da elenmiyorum")
## Beklenen: tur 1'de MISS→⚠, tur 2'de MISS→eleme, placement ~15-16.

func _ready() -> void:
	for s in 4:
		_run(1200 + s * 13)
	get_tree().quit()


func _run(seed: int) -> void:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var q := InputQueue.new()
	add_child(q)
	ctrl.setup(q)
	q.setup(ctrl.clock)
	ctrl.set_physics_process(false)

	var p_cross := {"perfect": 0, "graze": 0, "miss": 0}
	var cb := func(id: int, result: int, _ms: float) -> void:
		if id != ArenaController.PLAYER_ID:
			return
		match result:
			Rope.CrossResult.PERFECT: p_cross.perfect += 1
			Rope.CrossResult.GRAZE: p_cross.graze += 1
			Rope.CrossResult.MISS: p_cross.miss += 1
	ctrl.rope.crossed.connect(cb)

	ctrl.start_round(seed)
	var died_round := -1
	var died_alive := -1
	for i in 12000:
		ctrl.step()
		if died_round < 0 and not ctrl.player_alive():
			died_round = ctrl.round_no
			died_alive = ctrl.alive_ids.size()
		if ctrl.alive_ids.size() <= 1:
			break
	var pj := ctrl.jumper(ArenaController.PLAYER_ID)
	print("seed %d: oyuncu P/G/M=%d/%d/%d | elendiği tur=%s (kalan %s) | placement=%d | tur sonu=%d"
		% [seed, p_cross.perfect, p_cross.graze, p_cross.miss,
			str(died_round), str(died_alive), ctrl.placement(), ctrl.round_no])
	if pj != null:
		print("   (oyuncu hâlâ ağaçta: alive=%s warning=%s airborne=%s)"
			% [str(pj.is_alive), str(pj.has_warning), str(pj.is_airborne)])
	ctrl.queue_free()
	q.queue_free()
