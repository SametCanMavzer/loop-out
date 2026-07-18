extends SceneTree
## F4a Jumper testi: zıplama durum makinesi (normal/high/hold, duck toleransı, input buffer).
## (godot --headless -s res://tests/test_jumper.gd)

func _make(queue: InputQueue) -> Jumper:
	var j := Jumper.new()
	# Test tuning: jump_air=25, high=42, hold=18, duck_release=7, buffer=6 (config tick karşılıkları)
	j.setup(HumanInput.new(queue), JumperTuning.new(25, 42, 18, 7, 6))
	return j

## Jumper'ı 0..last_tick aralığında sürer; belirtilen tick'lerdeki durumu yakalar.
func _run(j: Jumper, last_tick: int) -> void:
	for ct in range(0, last_tick + 1):
		j.tick(ct)

func _process(_delta: float) -> bool:
	var fail := 0

	# --- 1) Normal zıplama: tick0 bas → 24'te havada, 25'te iner ---
	var q1 := InputQueue.new()
	q1.enqueue(&"jump", true, 0)
	q1.enqueue(&"jump", false, 1)   # hemen bırak → normal zıplama (hold eşiğine ulaşmaz)
	var j1 := _make(q1)
	for ct in range(0, 25):
		j1.tick(ct)
		if ct == 24 and not j1.is_airborne:
			push_error("FAIL: normal zıplama tick24'te havada olmalı."); fail += 1
	j1.tick(25)
	if j1.is_airborne:
		push_error("FAIL: normal zıplama tick25'te inmeli."); fail += 1
	if j1.jump_input_tick != 0:
		push_error("FAIL: jump_input_tick 0 olmalı."); fail += 1

	# --- 2) Yüksek zıplama: bas+basılı tut (release yok) → 18'de yükselir, 30'da hâlâ havada, 42'de iner ---
	var q2 := InputQueue.new()
	q2.enqueue(&"jump", true, 0)   # release yok → held kalır
	var j2 := _make(q2)
	for ct in range(0, 30):
		j2.tick(ct)
	if not j2.is_airborne:
		push_error("FAIL: yüksek zıplama tick30'da havada olmalı (normal 25'i aştı)."); fail += 1
	for ct in range(30, 42):
		j2.tick(ct)
	if not j2.is_airborne:
		push_error("FAIL: yüksek zıplama tick41'de havada olmalı."); fail += 1
	j2.tick(42)
	if j2.is_airborne:
		push_error("FAIL: yüksek zıplama tick42'de inmeli."); fail += 1

	# --- 3) Duck: bas tick0 → ducking; bırak tick5 → 11'e kadar ducking, 12'de kalkar ---
	var q3 := InputQueue.new()
	q3.enqueue(&"duck", true, 0)
	q3.enqueue(&"duck", false, 5)
	var j3 := _make(q3)
	for ct in range(0, 12):
		j3.tick(ct)
		if ct == 11 and not j3.is_ducking:
			push_error("FAIL: duck bırakma toleransı tick11'de hâlâ ducking olmalı."); fail += 1
	j3.tick(12)
	if j3.is_ducking:
		push_error("FAIL: duck tick12'de (5+7) kalkmalı."); fail += 1

	# --- 4) Input buffer: tick0 zıpla (air25); tick22 havadayken tekrar bas → inişte yeniden zıpla ---
	var q4 := InputQueue.new()
	q4.enqueue(&"jump", true, 0)
	q4.enqueue(&"jump", false, 1)   # bırak (held kapansın, high'a kaçmasın)
	q4.enqueue(&"jump", true, 22)   # havadayken tampon (25-22=3 <= 6)
	q4.enqueue(&"jump", false, 23)
	var j4 := _make(q4)
	for ct in range(0, 26):
		j4.tick(ct)
	if not j4.is_airborne:
		push_error("FAIL: tamponlanmış zıplama inişte yeniden başlamalı (tick25'te havada)."); fail += 1
	if j4.jump_input_tick != 25:
		push_error("FAIL: tamponlanmış yeniden zıplama jump_input_tick=25 olmalı (gelen %d)." % j4.jump_input_tick); fail += 1

	# --- 5) Ölü jumper girdi işlemez ---
	var q5 := InputQueue.new(); q5.enqueue(&"jump", true, 0)
	var j5 := _make(q5); j5.is_alive = false
	j5.tick(0)
	if j5.is_airborne:
		push_error("FAIL: ölü jumper zıplamamalı."); fail += 1

	for j in [j1, j2, j3, j4, j5]:
		j.free()

	if fail == 0:
		print("TEST JUMPER OK (normal/high/hold geç-karar, duck toleransı, input buffer, ölü atlama)")
	else:
		print("TEST JUMPER FAILED: %d hata" % fail)
	quit(fail)
	return true
