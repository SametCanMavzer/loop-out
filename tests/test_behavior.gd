extends SceneTree
## F7a İp davranış/telegraf testi: telegraf geri sayımı, davranış uygulama, sinyal sırası.
## (godot --headless -s res://tests/test_behavior.gd)

var _events: Array = []  # ["tel"/"start", id]

func _make_behavior(id: StringName, mult: float, height: int = -1) -> RopeBehavior:
	var b := RopeBehavior.new()
	b.id = id
	var p := {"speed_mult": mult}
	if height >= 0:
		p["height"] = height
	b.params = p
	return b

func _process(_delta: float) -> bool:
	var fail := 0
	var base := Rope.rpm_to_rad_per_sec(25.0)

	var rope := Rope.new()
	rope.reset(0.0, base)
	rope.behavior_telegraphed.connect(func(id): _events.append(["tel", id]))
	rope.behavior_started.connect(func(id): _events.append(["start", id]))

	# --- 1) speed_step, 5 tick telegraf: telegraf anında yayılır, hız DEĞİŞMEZ ---
	var speed := _make_behavior(&"speed_step", 1.5)
	rope.queue_behavior(speed, 5)
	if rope.telegraph_ticks_left != 5:
		push_error("FAIL: telegraph_ticks_left 5 olmalı."); fail += 1
	if _events.size() != 1 or _events[0][0] != "tel" or _events[0][1] != &"speed_step":
		push_error("FAIL: behavior_telegraphed hemen yayılmalı."); fail += 1
	if not is_equal_approx(rope.angular_vel, base):
		push_error("FAIL: telegraf sırasında hız değişmemeli."); fail += 1

	# 5 tick say → 5.'te etkiye girer
	for i in 4:
		rope.tick(i, 90, 160, [])
		if rope.current_behavior_id == &"speed_step":
			push_error("FAIL: davranış telegraf bitmeden etkiye girdi (i=%d)." % i); fail += 1
	rope.tick(4, 90, 160, [])   # 5. tick → aktifleşir
	if not is_equal_approx(rope.angular_vel, base * 1.5):
		push_error("FAIL: davranış sonrası hız base*1.5 olmalı (%f)." % rope.angular_vel); fail += 1
	if rope.current_behavior_id != &"speed_step":
		push_error("FAIL: current_behavior_id speed_step olmalı."); fail += 1
	if _events.size() != 2 or _events[1][0] != "start":
		push_error("FAIL: behavior_started etki anında yayılmalı."); fail += 1

	# --- 2) height davranışı: HIGH ---
	_events.clear()
	rope.reset(0.0, base)
	var high := _make_behavior(&"high_rope", 1.0, 1)
	rope.queue_behavior(high, 0)   # telegraf 0 → anında
	if rope.height != Rope.Height.HIGH:
		push_error("FAIL: height davranışı HIGH yapmalı."); fail += 1
	if rope.current_behavior_id != &"high_rope":
		push_error("FAIL: anında davranış current_behavior_id güncellemeli."); fail += 1

	# --- 3) yön korunur: negatif base'de speed_mult işareti bozmaz ---
	rope.reset(0.0, -base)
	rope.queue_behavior(_make_behavior(&"speed_step", 2.0), 0)
	if rope.angular_vel >= 0.0 or not is_equal_approx(rope.angular_vel, -base * 2.0):
		push_error("FAIL: negatif yön korunmalı (-base*2)."); fail += 1

	# --- 4) .tres roster yüklenir + etkiler doğru ---
	var normal := load("res://data/behaviors/normal.tres") as RopeBehavior
	var speed_step := load("res://data/behaviors/speed_step.tres") as RopeBehavior
	var reverse := load("res://data/behaviors/reverse.tres") as RopeBehavior
	var high_sweep := load("res://data/behaviors/high_sweep.tres") as RopeBehavior
	if normal == null or speed_step == null or reverse == null or high_sweep == null:
		push_error("FAIL: davranış .tres'leri yüklenemedi."); fail += 1
	elif speed_step.min_round != 6 or reverse.min_round != 13:
		push_error("FAIL: .tres min_round değerleri yanlış."); fail += 1
	else:
		# speed_step: base KALICI artar (iki kez → 1.08²)
		rope.reset(0.0, base)
		rope.queue_behavior(speed_step, 0)
		rope.queue_behavior(speed_step, 0)
		if not is_equal_approx(rope.base_angular_vel, base * 1.08 * 1.08):
			push_error("FAIL: speed_step base'i kalıcı artırmalı (1.08²)."); fail += 1
		# reverse: yön kalıcı çevrilir
		rope.reset(0.0, base)
		rope.queue_behavior(reverse, 0)
		if not is_equal_approx(rope.base_angular_vel, -base) or rope.angular_vel >= 0.0:
			push_error("FAIL: reverse base yönünü çevirmeli."); fail += 1
		# high_sweep: HIGH, base değişmez
		rope.reset(0.0, base)
		rope.queue_behavior(high_sweep, 0)
		if rope.height != Rope.Height.HIGH or not is_equal_approx(rope.base_angular_vel, base):
			push_error("FAIL: high_sweep HIGH yapmalı, base'i değiştirmemeli."); fail += 1
		# normal: base'i korur (kalıcı hızı sıfırlamaz), height LOW
		rope.reset(0.0, base)
		rope.queue_behavior(speed_step, 0)      # base artar
		rope.queue_behavior(normal, 0)          # normal base'i korumalı
		if not is_equal_approx(rope.angular_vel, base * 1.08):
			push_error("FAIL: normal kalıcı hızı korumalı (base*1.08)."); fail += 1

	rope.free()
	if fail == 0:
		print("TEST BEHAVIOR OK (telegraf, uygulama, sinyaller, yön, .tres roster: speed_step/reverse/high_sweep/normal)")
	else:
		print("TEST BEHAVIOR FAILED: %d hata" % fail)
	quit(fail)
	return true
