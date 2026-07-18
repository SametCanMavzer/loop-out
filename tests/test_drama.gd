extends SceneTree
## F7f Dinamik dram testi. (godot --headless -s res://tests/test_drama.gd)

func _bots() -> Array:
	return [
		{"id": &"acemi",  "sigma": 90.0, "ref": 1},
		{"id": &"acemi",  "sigma": 90.0, "ref": 2},
		{"id": &"panikci","sigma": 70.0, "ref": 3},
		{"id": &"saglam", "sigma": 45.0, "ref": 4},
		{"id": &"saglam", "sigma": 50.0, "ref": 5},
	]

func _process(_delta: float) -> bool:
	var fail := 0
	var drama := DramaDirector.new(); drama.setup(2)
	var rng := RandomNumberGenerator.new(); rng.seed = 3

	# --- Kurtarma: streak≥2 + tur≤3 + Acemi var → bir Acemi seçilir ---
	var r := drama.pick_rescue_target(_bots(), 2, 2, rng)
	if r.is_empty() or StringName(r.id) != &"acemi":
		push_error("FAIL: kurtarma bir Acemi seçmeli."); fail += 1

	# streak yetersiz → müdahale yok
	if not drama.pick_rescue_target(_bots(), 2, 1, rng).is_empty():
		push_error("FAIL: streak<eşik iken kurtarma olmamalı."); fail += 1
	# tur > 3 → müdahale yok
	if not drama.pick_rescue_target(_bots(), 4, 3, rng).is_empty():
		push_error("FAIL: tur>3 iken kurtarma olmamalı."); fail += 1
	# Acemi yoksa → müdahale yok
	var no_acemi := _bots().filter(func(b): return StringName(b.id) != &"acemi")
	if not drama.pick_rescue_target(no_acemi, 2, 3, rng).is_empty():
		push_error("FAIL: Acemi yokken kurtarma olmamalı."); fail += 1

	# Determinizm: aynı seed → aynı kurtarma hedefi
	var rngA := RandomNumberGenerator.new(); rngA.seed = 7
	var rngB := RandomNumberGenerator.new(); rngB.seed = 7
	if drama.pick_rescue_target(_bots(), 2, 2, rngA).ref != drama.pick_rescue_target(_bots(), 2, 2, rngB).ref:
		push_error("FAIL: kurtarma determinizmi bozuk."); fail += 1

	# --- Final aday: Sağlam öncelik + en düşük σ (id 4, σ45) ---
	var f := drama.pick_final_candidate(_bots())
	if f.is_empty() or f.ref != 4:
		push_error("FAIL: final aday en düşük σ'lı Sağlam (id 4) olmalı, gelen %s." % str(f.get("ref"))); fail += 1
	# Sağlam yoksa → genel en düşük σ (panikci σ70)
	var no_saglam := _bots().filter(func(b): return StringName(b.id) != &"saglam")
	var f2 := drama.pick_final_candidate(no_saglam)
	if f2.is_empty() or f2.ref != 3:
		push_error("FAIL: Sağlam yokken en düşük σ (id 3) terfi etmeli."); fail += 1

	# --- BotBrain σ override etkisi: override niyet zamanlamasını değiştirir ---
	var base := Rope.rpm_to_rad_per_sec(25.0)
	var arch := load("res://data/archetypes/acemi.tres") as BotArchetype
	var jt_plain := _run_bot(arch, base, 11, 1.0)
	var jt_infl := _run_bot(arch, base, 11, 4.0)   # σ×4 → farklı örneklem
	if jt_plain < 0 or jt_infl < 0 or jt_plain == jt_infl:
		push_error("FAIL: σ override niyet zamanlamasını değiştirmeli (%d vs %d)." % [jt_plain, jt_infl]); fail += 1

	if fail == 0:
		print("TEST DRAMA OK (kurtarma koşulları/determinizm, final aday, σ override)")
	else:
		print("TEST DRAMA FAILED: %d hata" % fail)
	quit(fail)
	return true

class FakeRope extends RefCounted:
	var angle: float = 0.0
	var angular_vel: float = 0.0
	var height: int = 0
class FakeJumper extends RefCounted:
	var angle_pos: float = PI

func _run_bot(arch: BotArchetype, base: float, seed: int, sigma_mult: float) -> int:
	var rope := FakeRope.new(); rope.angular_vel = base
	var jm := FakeJumper.new()
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var bot := BotBrain.new(); bot.setup(rng, arch, rope, jm, 1, 600.0)
	bot.set_sigma_override(sigma_mult)
	var jt := -1
	for t in range(0, 200):
		for c in bot.poll(t):
			if c.action == &"jump" and c.pressed and jt < 0:
				jt = t
		rope.angle = wrapf(rope.angle + rope.angular_vel * Rope.TICK_DT, 0.0, TAU)
	return jt
