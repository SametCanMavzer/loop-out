extends RefCounted
## F7d RoundDirector testi: tur bazlı aktif set, determinizm, max-2-ardışık, seçim aralığı.
## (godot --headless -s res://tests/test_director.gd)

const IDS := ["normal", "speed_step", "sudden_stop", "reverse", "high_sweep", "double_sweep", "fake_slow"]

func _pool() -> Array:
	var pool: Array = []
	for id in IDS:
		pool.append(load("res://data/behaviors/%s.tres" % id))
	return pool

func _tiers() -> Array:
	return [
		{"from": 1, "ids": ["normal"]},
		{"from": 6, "ids": ["normal", "speed_step", "sudden_stop"]},
		{"from": 13, "ids": ["normal", "speed_step", "sudden_stop", "reverse", "high_sweep"]},
		{"from": 20, "ids": ["normal", "speed_step", "sudden_stop", "reverse", "high_sweep", "double_sweep"]},
		{"from": 30, "ids": IDS.duplicate()},
	]

func _make(seed: int, interval: int = 100) -> RoundDirector:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var d := RoundDirector.new()
	d.setup(rng, _pool(), _tiers(), interval, 2)
	return d

func run(tree: SceneTree) -> int:
	var fail := 0
	if _pool().has(null):
		push_error("FAIL: davranış havuzu yüklenemedi."); print("TEST DIRECTOR FAILED"); return 1

	# --- 1) Round 1: yalnız normal seçilir ---
	var d1 := _make(1)
	for i in 10:
		var b := d1.select(1)
		if b == null or b.id != &"normal":
			push_error("FAIL: round1 yalnız normal olmalı (%s)." % (b.id if b else &"null")); fail += 1; break

	# --- 2) Round 6: yalnız {normal,speed_step,sudden_stop}; reverse/high asla ---
	var d6 := _make(2)
	var allowed6 := ["normal", "speed_step", "sudden_stop"]
	for i in 60:
		var b := d6.select(6)
		if b == null or not allowed6.has(String(b.id)):
			push_error("FAIL: round6'da yasak davranış seçildi (%s)." % (b.id if b else &"null")); fail += 1; break

	# --- 3) Determinizm: aynı seed → aynı seçim dizisi ---
	var da := _make(42); var db := _make(42)
	var seq_a: Array = []; var seq_b: Array = []
	for i in 30:
		seq_a.append(da.select(30)); seq_b.append(db.select(30))
	var ids_a := seq_a.map(func(b): return b.id)
	var ids_b := seq_b.map(func(b): return b.id)
	if ids_a != ids_b:
		push_error("FAIL: aynı seed farklı seçim dizisi."); fail += 1

	# --- 4) Max 2 ardışık: round 30'da hiçbir id 3 kez üst üste gelmez ---
	var d30 := _make(7)
	var last := &""; var run := 0; var max_run := 0
	for i in 500:
		var b := d30.select(30)
		if b.id == last:
			run += 1
		else:
			last = b.id; run = 1
		max_run = maxi(max_run, run)
	if max_run > 2:
		push_error("FAIL: aynı davranış %d kez ardışık (max 2 olmalı)." % max_run); fail += 1

	# --- 5) Seçim aralığı: tick aralık dolmadan null, dolunca davranış ---
	var di := _make(9, 100)
	if di.tick(50, 1) != null:
		push_error("FAIL: aralık dolmadan seçim olmamalı."); fail += 1
	if di.tick(100, 1) == null:
		push_error("FAIL: aralıkta seçim olmalı."); fail += 1
	if di.tick(150, 1) != null:
		push_error("FAIL: iki seçim arası null olmalı."); fail += 1

	if fail == 0:
		print("TEST DIRECTOR OK (aktif set, determinizm, max-2-ardışık, aralık)")
	else:
		print("TEST DIRECTOR FAILED: %d hata" % fail)
	return fail
