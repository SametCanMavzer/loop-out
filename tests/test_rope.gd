extends SceneTree
## F3a İp testi: crossing geometrisi (sarma + yön) ve zamanlama sınıflandırması.
## Rope autoload'a bağlı değil → lokal `crossed` sinyaline bağlanır, pencereler parametre.
## (godot --headless -s res://tests/test_rope.gd)

class FakeJumper extends RefCounted:
	var id: int
	var angle_pos: float
	var is_ducking: bool = false
	var is_airborne: bool = false
	var jump_input_tick: int = 0
	var is_alive: bool = true
	func _init(p_id: int, p_angle: float) -> void:
		id = p_id
		angle_pos = p_angle

var _events: Array = []  # [id, result, delta_ms]

func _process(_delta: float) -> bool:
	var fail := 0

	# --- 1) swept_past saf geometri (sarma + yön) ---
	if not Rope.swept_past(6.2, 0.05, 0.2, 1):
		push_error("FAIL: sarma üzerinden ileri süpürme yakalanmadı."); fail += 1
	if Rope.swept_past(1.0, 2.0, 0.1, 1):
		push_error("FAIL: menzil dışı hedef yanlışlıkla süpürüldü."); fail += 1
	if not Rope.swept_past(0.05, 6.2, 0.2, -1):
		push_error("FAIL: sarma üzerinden geri süpürme yakalanmadı."); fail += 1
	if Rope.swept_past(1.0, 1.0, 0.2, 1):
		push_error("FAIL: prev'deki hedef çift süpürüldü (d==0 sayıldı)."); fail += 1

	var rope := Rope.new()
	rope.crossed.connect(func(id: int, result: int, delta_ms: float) -> void:
		_events.append([id, result, delta_ms]))

	var mid := 0.5 * absf(1.0) * Rope.TICK_DT  # prev(0) ile curr arası → bu tick süpürülür

	# --- 2) Sınıflandırma (LOW), round1 pencereleri: perfect 90, graze 160 ---
	_events.clear()
	var cases := [
		# [id, jump_tick, cross_tick, airborne, beklenen]
		[1, 100, 100, true, Rope.CrossResult.PERFECT],   # delta 0ms
		[2, 100, 109, true, Rope.CrossResult.GRAZE],     # delta ~150ms (<=160)
		[3, 100, 112, true, Rope.CrossResult.MISS],      # delta ~200ms (>160)
		[4, 100, 100, false, Rope.CrossResult.MISS],     # yerde → MISS
	]
	for c in cases:
		rope.reset(0.0, 1.0)
		var j := FakeJumper.new(c[0], mid)
		j.is_airborne = c[3]; j.jump_input_tick = c[1]
		rope.tick(c[2], 90, 160, [j])
	var res := {}
	for e in _events:
		res[e[0]] = e[1]
	for c in cases:
		if res.get(c[0]) != c[4]:
			push_error("FAIL: id %d beklenen %d, gelen %s." % [c[0], c[4], str(res.get(c[0]))]); fail += 1

	# --- 3) Tur-bağımlı graze (§4.5): round25 graze=130 → 150ms artık MISS ---
	_events.clear()
	rope.reset(0.0, 1.0)
	var jr := FakeJumper.new(5, mid); jr.is_airborne = true; jr.jump_input_tick = 100
	rope.tick(109, 90, 130, [jr])   # delta ~150ms, graze 130 → MISS
	if _events.size() != 1 or _events[0][1] != Rope.CrossResult.MISS:
		push_error("FAIL: daralan graze (130) uygulanmadı (150ms MISS olmalı)."); fail += 1

	# --- 4) HIGH süpürme (E7): ducking nötr (sinyal yok), airborne MISS ---
	_events.clear()
	rope.reset(0.0, 1.0); rope.height = Rope.Height.HIGH
	var jd := FakeJumper.new(6, mid); jd.is_ducking = true
	rope.tick(100, 90, 160, [jd])
	if _events.size() != 0:
		push_error("FAIL: HIGH+ducking nötr olmalı, sinyal yayıldı."); fail += 1
	rope.reset(0.0, 1.0); rope.height = Rope.Height.HIGH
	var ja := FakeJumper.new(7, mid); ja.is_airborne = true
	rope.tick(100, 90, 160, [ja])
	if _events.size() != 1 or _events[0][1] != Rope.CrossResult.MISS:
		push_error("FAIL: HIGH+airborne MISS olmalı (E7)."); fail += 1

	rope.free()
	if fail == 0:
		print("TEST ROPE OK (crossing geo + sarma/yön, sınıflandırma, tur-graze, HIGH/E7)")
	else:
		print("TEST ROPE FAILED: %d hata" % fail)
	quit(fail)
	return true
