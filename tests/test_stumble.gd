extends RefCounted
## F5a Sendeleme/eleme testi: uyarı → af → eleme akışı + sudden death.
## (godot --headless -s res://tests/test_stumble.gd)

class FakeJumper extends RefCounted:
	var is_alive: bool = true
	var has_warning: bool = false
	var pardon_counter: int = 0

func run(tree: SceneTree) -> int:
	var fail := 0
	var judge := StumbleJudge.new()
	const MISS := Rope.CrossResult.MISS
	const GRAZE := Rope.CrossResult.GRAZE
	const PERFECT := Rope.CrossResult.PERFECT

	# --- 1) İlk sendeleme → STUMBLED + ⚠ (eleme değil) ---
	var j := FakeJumper.new()
	var o := judge.resolve(j, MISS, 5)
	if o != StumbleJudge.Outcome.STUMBLED or not j.has_warning or not j.is_alive:
		push_error("FAIL: ilk MISS STUMBLED + uyarı olmalı, eleme değil."); fail += 1

	# --- 2) Uyarılıyken 5 temiz geçiş → 5.'te PARDONED, ⚠ silinir ---
	for i in 4:
		if judge.resolve(j, GRAZE, 5) != StumbleJudge.Outcome.CLEAN:
			push_error("FAIL: af eşiğinden önce CLEAN olmalı (i=%d)." % i); fail += 1
	var op := judge.resolve(j, PERFECT, 5)   # 5. temiz geçiş
	if op != StumbleJudge.Outcome.PARDONED or j.has_warning or j.pardon_counter != 0:
		push_error("FAIL: 5. temiz geçişte PARDONED + ⚠ silinmeli."); fail += 1

	# --- 3) Af sonrası tekrar sendeleme → yine sadece STUMBLED (temiz sayfa) ---
	if judge.resolve(j, MISS, 5) != StumbleJudge.Outcome.STUMBLED or not j.has_warning:
		push_error("FAIL: af sonrası MISS yeniden STUMBLED olmalı."); fail += 1

	# --- 4) Uyarılıyken sendeleme → ELIMINATED ---
	var oe := judge.resolve(j, MISS, 5)
	if oe != StumbleJudge.Outcome.ELIMINATED or j.is_alive:
		push_error("FAIL: uyarılıyken MISS ELIMINATED olmalı."); fail += 1
	# ölüye tekrar uygulanınca CLEAN (no-op)
	if judge.resolve(j, MISS, 5) != StumbleJudge.Outcome.CLEAN:
		push_error("FAIL: ölü jumper no-op olmalı."); fail += 1

	# --- 5) Sudden death (pardon_rounds=-1): ilk MISS direkt ELIMINATED ---
	var j2 := FakeJumper.new()
	if judge.resolve(j2, MISS, -1) != StumbleJudge.Outcome.ELIMINATED or j2.is_alive:
		push_error("FAIL: sudden death ilk MISS ELIMINATED olmalı."); fail += 1

	# --- 6) Temiz geçiş, uyarı yokken → CLEAN, sayaç oynamaz ---
	var j3 := FakeJumper.new()
	if judge.resolve(j3, PERFECT, 5) != StumbleJudge.Outcome.CLEAN or j3.pardon_counter != 0:
		push_error("FAIL: uyarısız temiz geçiş CLEAN + sayaç 0 olmalı."); fail += 1

	if fail == 0:
		print("TEST STUMBLE OK (uyarı→af→eleme, sudden death, temiz geçiş)")
	else:
		print("TEST STUMBLE FAILED: %d hata" % fail)
	return fail
