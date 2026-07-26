extends SceneTree
## F7c özel davranış testi: sudden_stop (zamanlı duruş), fake_slow (yavaş→snap),
## double_sweep (ikinci süpürme). (godot --headless -s res://tests/test_behavior_special.gd)

class FakeJumper extends RefCounted:
	var id: int = 1
	var angle_pos: float = 0.0
	var is_ducking: bool = false
	var is_clear: bool = true       # ip altından geçecek yükseklikte (Model A sıkı)
	var is_airborne: bool = true
	var jump_input_tick: int = 0
	var is_alive: bool = true

var _cross_count: int = 0

func _process(_delta: float) -> bool:
	var fail := 0
	var base := Rope.rpm_to_rad_per_sec(25.0)
	var stop := load("res://data/behaviors/sudden_stop.tres") as RopeBehavior
	var fake := load("res://data/behaviors/fake_slow.tres") as RopeBehavior
	var dbl := load("res://data/behaviors/double_sweep.tres") as RopeBehavior
	if stop == null or fake == null or dbl == null:
		push_error("FAIL: özel .tres yüklenemedi."); print("TEST BEHAVIOR SPECIAL FAILED"); quit(1); return true

	# --- 1) sudden_stop: yarım tur (~72 tick) durur, sonra base'e döner ---
	var rope := Rope.new()
	rope.reset(0.0, base)
	rope.queue_behavior(stop, 0)
	if not is_zero_approx(rope.angular_vel):
		push_error("FAIL: sudden_stop hemen durdurmalı."); fail += 1
	var expected_stop := int(ceil(PI / (base * Rope.TICK_DT)))
	for i in expected_stop - 1:
		rope.tick(i, 90, 160, [])
		if not is_zero_approx(rope.angular_vel):
			push_error("FAIL: duruş sırasında hız 0 olmalı (i=%d)." % i); fail += 1; break
	rope.tick(expected_stop - 1, 90, 160, [])   # son tick → base'e döner
	if not is_equal_approx(rope.angular_vel, base):
		push_error("FAIL: sudden_stop sonrası base'e dönmeli (%f)." % rope.angular_vel); fail += 1

	# --- 2) fake_slow: base*0.5 ile başlar, ~36 tick sonra base'e snap ---
	rope.reset(0.0, base)
	rope.queue_behavior(fake, 0)
	if not is_equal_approx(rope.angular_vel, base * 0.5):
		push_error("FAIL: fake_slow yavaş başlamalı (base*0.5)."); fail += 1
	var slow_ticks := int(round(600.0 * 60.0 / 1000.0))  # 36
	for i in slow_ticks - 1:
		rope.tick(i, 90, 160, [])
	if is_equal_approx(rope.angular_vel, base):
		push_error("FAIL: fake_slow erken hızlandı."); fail += 1
	rope.tick(slow_ticks - 1, 90, 160, [])   # snap
	if not is_equal_approx(rope.angular_vel, base):
		push_error("FAIL: fake_slow sonunda base'e snap etmeli."); fail += 1

	# --- 3) double_sweep: jumper bir turda İKİ kez çözülür (ikinci süpürme ertelenir) ---
	_cross_count = 0
	rope.free()
	rope = Rope.new()
	rope.reset(0.0, base)
	rope.crossed.connect(func(_id, _res, _d): _cross_count += 1)
	rope.queue_behavior(dbl, 0)
	var jm := FakeJumper.new()
	jm.angle_pos = 0.5 * base * Rope.TICK_DT   # ilk tick'te süpürülür
	# yeterince tick sür ki hem ilk hem (gap sonrası) ikinci süpürme çözülsün
	for t in range(0, 40):
		rope.tick(t, 90, 160, [jm])
	if _cross_count != 2:
		push_error("FAIL: double_sweep jumper'ı 2 kez çözmeli (gelen %d)." % _cross_count); fail += 1

	rope.free()
	if fail == 0:
		print("TEST BEHAVIOR SPECIAL OK (sudden_stop, fake_slow, double_sweep)")
	else:
		print("TEST BEHAVIOR SPECIAL FAILED: %d hata" % fail)
	quit(fail)
	return true
