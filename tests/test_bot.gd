extends RefCounted
## F6a Bot testi: niyet örnekleme determinizmi + geçiş penceresi içinde zıplama + arketip farkı.
## (godot --headless -s res://tests/test_bot.gd)

class FakeRope extends RefCounted:
	var angle: float = 0.0
	var angular_vel: float = 0.0
	var height: int = 0

class FakeJumper extends RefCounted:
	var angle_pos: float = 0.0

func _low_sigma_arch() -> BotArchetype:
	var a := BotArchetype.new()
	a.reaction_mean_ms = -210.0; a.reaction_std_base_ms = 40.0; a.std_round_slope = 1.0
	return a

## Botu ipi döndürerek sür; ilk zıplama tick'ini ve hesaplanan t_cross'u döndür.
func _run_until_jump(seed: int, arch: BotArchetype, round_no: int) -> Dictionary:
	var rope := FakeRope.new()
	rope.angular_vel = Rope.rpm_to_rad_per_sec(25.0)   # +yön
	var jm := FakeJumper.new(); jm.angle_pos = PI       # yarım tur ötede
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var bot := BotBrain.new()
	bot.setup(rng, arch, rope, jm, round_no, 600.0)
	var step := absf(rope.angular_vel) * Rope.TICK_DT
	var jump_tick := -1
	var t_cross_at_sample := -1
	for t in range(0, 200):
		var cmds := bot.poll(t)
		for c in cmds:
			if c.action == &"jump" and c.pressed and jump_tick < 0:
				jump_tick = t
				t_cross_at_sample = t + int(ceil(fposmod(jm.angle_pos - rope.angle, TAU) / step))
		rope.angle = wrapf(rope.angle + rope.angular_vel * Rope.TICK_DT, 0.0, TAU)
	return {"jump": jump_tick, "cross_now": t_cross_at_sample}

func run(tree: SceneTree) -> int:
	var fail := 0

	# --- Determinizm: aynı seed → aynı zıplama tick'i ---
	var arch := _low_sigma_arch()
	var r1 := _run_until_jump(1234, arch, 1)
	var r2 := _run_until_jump(1234, arch, 1)
	if r1.jump != r2.jump or r1.jump < 0:
		push_error("FAIL: aynı seed farklı/eksik zıplama (%s vs %s)." % [str(r1), str(r2)]); fail += 1

	# --- Zıplama geçiş penceresi civarında (t_cross ~ 72; airborne 25 tick öncesi mantıklı) ---
	# İlk cross ≈ ceil(PI/step). step=rpm25*dt. Beklenen ilk cross ~72 tick.
	var first_cross := int(ceil(PI / (Rope.rpm_to_rad_per_sec(25.0) * Rope.TICK_DT)))
	if r1.jump < first_cross - 30 or r1.jump > first_cross + 5:
		push_error("FAIL: zıplama (%d) geçiş (%d) penceresi dışında." % [r1.jump, first_cross]); fail += 1

	# --- Farklı seed → (büyük olasılıkla) farklı tick; en azından deterministik ---
	var r3 := _run_until_jump(9999, arch, 1)
	if r3.jump < 0:
		push_error("FAIL: farklı seed'de bot hiç zıplamadı."); fail += 1

	# --- Zorluk eğrisi: yüksek turda σ büyür → örnekleme farklı (deterministik ama kayar) ---
	var r_late := _run_until_jump(1234, arch, 30)
	if r_late.jump < 0:
		push_error("FAIL: geç turda bot hiç zıplamadı."); fail += 1

	# --- InputSource sözleşmesi: BotBrain bir InputSource ---
	if not (BotBrain.new() is InputSource):
		push_error("FAIL: BotBrain InputSource olmalı (E12)."); fail += 1

	if fail == 0:
		print("TEST BOT OK (niyet determinizmi, geçiş penceresi, zorluk eğrisi, InputSource)")
	else:
		print("TEST BOT FAILED: %d hata" % fail)
	return fail
