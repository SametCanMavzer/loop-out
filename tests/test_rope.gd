extends SceneTree
## F3a İp testi: crossing geometrisi (sarma + yön) ve zamanlama sınıflandırması.
## Rope autoload'a bağlı değil → lokal `crossed` sinyaline bağlanır, pencereler parametre.
## (godot --headless -s res://tests/test_rope.gd)

class FakeJumper extends RefCounted:
	var id: int
	var angle_pos: float
	var is_ducking: bool = false
	# is_clear (Model A sıkı) Jumper'da hesaplanır; testte "havadaysa yeterince yüksek" varsayılır.
	var is_clear: bool = false
	var is_airborne: bool = false:
		set(v):
			is_airborne = v
			is_clear = v
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

	# --- 2) Sınıflandırma (LOW) — Model A: havada = en az GRAZE, MISS yalnız yerde. round1 (90,160) ---
	_events.clear()
	var cases := [
		# [id, jump_tick, cross_tick, airborne, beklenen]
		[1, 100, 100, true, Rope.CrossResult.PERFECT],   # delta 0ms → PERFECT
		[2, 100, 109, true, Rope.CrossResult.GRAZE],     # delta ~150ms → GRAZE
		[3, 100, 112, true, Rope.CrossResult.GRAZE],     # delta ~200ms (erken) → yine GRAZE (havada)
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

	# --- 3) Sudden death (§4.5, graze bandı yok: graze_ms<=perfect_ms) → perfect değilse MISS ---
	_events.clear()
	rope.reset(0.0, 1.0)
	var jr := FakeJumper.new(5, mid); jr.is_airborne = true; jr.jump_input_tick = 100
	rope.tick(109, 90, 90, [jr])   # havada delta ~150ms ama graze yok → MISS
	if _events.size() != 1 or _events[0][1] != Rope.CrossResult.MISS:
		push_error("FAIL: sudden death'te havada-ama-perfect-değil MISS olmalı."); fail += 1
	# ...aynı sudden death'te delta<=perfect → PERFECT
	_events.clear()
	rope.reset(0.0, 1.0)
	var jp2 := FakeJumper.new(11, mid); jp2.is_airborne = true; jp2.jump_input_tick = 100
	rope.tick(100, 90, 90, [jp2])  # delta 0 → PERFECT
	if _events.size() != 1 or _events[0][1] != Rope.CrossResult.PERFECT:
		push_error("FAIL: sudden death'te delta0 PERFECT olmalı."); fail += 1

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

	# --- 5) is_alive=false atlanır; aynı tick'te çok hedef (biri süpürülür biri süpürülmez) ---
	_events.clear()
	rope.reset(0.0, 1.0); rope.height = Rope.Height.LOW
	var dead := FakeJumper.new(8, mid); dead.is_airborne = true; dead.is_alive = false
	var swept := FakeJumper.new(9, mid); swept.is_airborne = true; swept.jump_input_tick = 100
	var outside := FakeJumper.new(10, PI); outside.is_airborne = true  # step dışında → süpürülmez
	rope.tick(100, 90, 160, [dead, swept, outside])
	if _events.size() != 1 or _events[0][0] != 9:
		push_error("FAIL: çok-hedef/ölü atlama yanlış (yalnız id 9 beklenir, gelen %s)." % str(_events)); fail += 1

	rope.free()
	if fail == 0:
		print("TEST ROPE OK (crossing geo + sarma/yön, sınıflandırma, tur-graze, HIGH/E7)")
	else:
		print("TEST ROPE FAILED: %d hata" % fail)
	quit(fail)
	return true
