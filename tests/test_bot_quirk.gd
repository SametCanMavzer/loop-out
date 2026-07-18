extends SceneTree
## F7e Şovcu/Kopyacı testi. (godot --headless -s res://tests/test_bot_quirk.gd)

class FakeRope extends RefCounted:
	var angle: float = 0.0
	var angular_vel: float = 0.0
	var height: int = 0

class FakeJumper extends RefCounted:
	var angle_pos: float = 0.0

class FakePlayer extends RefCounted:
	var jump_input_tick: int = -1
	var is_airborne: bool = false

func _first_jump(bot: BotBrain, rope: FakeRope, step: float) -> int:
	var jt := -1
	for t in range(0, 200):
		for c in bot.poll(t):
			if c.action == &"jump" and c.pressed and jt < 0:
				jt = t
		rope.angle = wrapf(rope.angle + rope.angular_vel * Rope.TICK_DT, 0.0, TAU)
	return jt

func _process(_delta: float) -> bool:
	var fail := 0
	var base := Rope.rpm_to_rad_per_sec(25.0)
	var step := base * Rope.TICK_DT
	var sovcu := load("res://data/archetypes/sovcu.tres") as BotArchetype
	var kopya := load("res://data/archetypes/kopyaci.tres") as BotArchetype
	var none := load("res://data/archetypes/saglam.tres") as BotArchetype
	if sovcu == null or kopya == null:
		push_error("FAIL: quirk .tres yüklenemedi."); print("TEST BOT QUIRK FAILED"); quit(1); return true
	if sovcu.quirk != 1 or kopya.quirk != 2:
		push_error("FAIL: quirk değerleri yanlış (sovcu=1, kopyaci=2)."); fail += 1

	# --- 1) Şovcu takla zarı (rng.randf) tüketir → aynı seed'de NONE'dan farklı niyet ---
	var r1 := FakeRope.new(); r1.angular_vel = base
	var j1 := FakeJumper.new(); j1.angle_pos = PI
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 5
	var b_sovcu := BotBrain.new(); b_sovcu.setup(rng1, sovcu, r1, j1, 1, 600.0)
	var jt_sovcu := _first_jump(b_sovcu, r1, step)

	var r2 := FakeRope.new(); r2.angular_vel = base
	var j2 := FakeJumper.new(); j2.angle_pos = PI
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 5
	var b_none := BotBrain.new(); b_none.setup(rng2, none, r2, j2, 1, 600.0)
	var jt_none := _first_jump(b_none, r2, step)

	if jt_sovcu < 0:
		push_error("FAIL: Şovcu hiç zıplamadı."); fail += 1
	if jt_sovcu == jt_none:
		push_error("FAIL: Şovcu quirk zar tüketmiyor (NONE ile aynı niyet)."); fail += 1

	# --- 2) Kopyacı: oyuncu yakın zamanda zıpladıysa intent = oyuncu_tick + copy_delay ---
	var r3 := FakeRope.new(); r3.angular_vel = base
	var j3 := FakeJumper.new(); j3.angle_pos = PI
	var player := FakePlayer.new(); player.jump_input_tick = 30
	var rng3 := RandomNumberGenerator.new(); rng3.seed = 5
	var b_kopya := BotBrain.new()
	b_kopya.setup(rng3, kopya, r3, j3, 1, 600.0, player, 200.0)  # copy_delay 200ms = 12 tick
	var jt_kopya := _first_jump(b_kopya, r3, step)
	# ilk cross ≈ 72; bot ~tick 36'da örnekler, oyuncu 30'da zıpladı (yakın) → intent 30+12=42
	if jt_kopya != 42:
		push_error("FAIL: Kopyacı oyuncuyu kopyalamalı (42 beklenir, gelen %d)." % jt_kopya); fail += 1

	# --- 3) Kopyacı: oyuncu zıplamadıysa (jump_input_tick=-1) kendi örneklemine düşer ---
	var r4 := FakeRope.new(); r4.angular_vel = base
	var j4 := FakeJumper.new(); j4.angle_pos = PI
	var noplayer := FakePlayer.new()  # jump_input_tick = -1
	var rng4 := RandomNumberGenerator.new(); rng4.seed = 5
	var b_kopya2 := BotBrain.new()
	b_kopya2.setup(rng4, kopya, r4, j4, 1, 600.0, noplayer, 200.0)
	var jt_fb := _first_jump(b_kopya2, r4, step)
	if jt_fb < 0 or jt_fb == 42:
		push_error("FAIL: Kopyacı oyuncu yokken kendi örneklemine düşmeli (gelen %d)." % jt_fb); fail += 1

	# --- 4) Panikçi telegraf tepkisi (§4.6): on_telegraph (prob=1.0) → σ×3 → farklı niyet ---
	var panik_arch := BotArchetype.new()
	panik_arch.reaction_mean_ms = -210.0; panik_arch.reaction_std_base_ms = 70.0
	panik_arch.std_round_slope = 4.0; panik_arch.telegraph_fail_prob = 1.0
	var r5 := FakeRope.new(); r5.angular_vel = base
	var j5 := FakeJumper.new(); j5.angle_pos = PI
	var rng5 := RandomNumberGenerator.new(); rng5.seed = 5
	var b_panic := BotBrain.new(); b_panic.setup(rng5, panik_arch, r5, j5, 1, 600.0)
	b_panic.on_telegraph()   # panik kesin (prob 1.0)
	var jt_panic := _first_jump(b_panic, r5, step)
	var r6 := FakeRope.new(); r6.angular_vel = base
	var j6 := FakeJumper.new(); j6.angle_pos = PI
	var rng6 := RandomNumberGenerator.new(); rng6.seed = 5
	var b_calm := BotBrain.new(); b_calm.setup(rng6, panik_arch, r6, j6, 1, 600.0)
	var jt_calm := _first_jump(b_calm, r6, step)
	if jt_panic < 0 or jt_panic == jt_calm:
		push_error("FAIL: panik niyeti değiştirmeli (%d vs %d)." % [jt_panic, jt_calm]); fail += 1

	if fail == 0:
		print("TEST BOT QUIRK OK (Şovcu σ×2 zar, Kopyacı kopyala + fallback, Panikçi telegraf σ×3)")
	else:
		print("TEST BOT QUIRK FAILED: %d hata" % fail)
	quit(fail)
	return true
