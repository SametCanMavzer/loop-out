extends RefCounted
## F5b Ring testi: daralan yarıçap + yeniden dizilim açıları (saf geometri).
## (godot --headless -s res://tests/test_ring.gd)

func run(tree: SceneTree) -> int:
	var fail := 0
	var eps := 0.0001

	# --- radius_for: 16→r_max, 2→r_min, 9→orta ---
	if absf(Ring.radius_for(16, 2.2, 9.0) - 9.0) > eps:
		push_error("FAIL: 16 kişi r_max olmalı."); fail += 1
	if absf(Ring.radius_for(2, 2.2, 9.0) - 2.2) > eps:
		push_error("FAIL: 2 kişi r_min olmalı."); fail += 1
	if absf(Ring.radius_for(9, 2.2, 9.0) - 5.6) > eps:
		push_error("FAIL: 9 kişi orta (5.6) olmalı, gelen %f." % Ring.radius_for(9, 2.2, 9.0)); fail += 1
	# Kırpma: 20 kişi (aralık dışı) r_max'ta kalmalı
	if absf(Ring.radius_for(20, 2.2, 9.0) - 9.0) > eps:
		push_error("FAIL: 20 kişi r_max'a kırpılmalı."); fail += 1

	# --- distribute_angles: oyuncu tam player_angle'da, eşit aralık ---
	var pa := 3.0 * PI / 2.0
	var angs := Ring.distribute_angles(4, 0, pa)
	if angs.size() != 4:
		push_error("FAIL: 4 açı dönmeli."); fail += 1
	elif absf(angs[0] - pa) > eps:
		push_error("FAIL: oyuncu (index0) player_angle'da olmalı."); fail += 1
	else:
		# aralıklar TAU/4 olmalı
		for i in range(1, 4):
			var d := fposmod(angs[i] - angs[i - 1], TAU)
			if absf(d - TAU / 4.0) > eps:
				push_error("FAIL: eşit aralık (TAU/4) bozuk (i=%d)." % i); fail += 1

	# Farklı player_index ile de oyuncu doğru açıda
	var angs2 := Ring.distribute_angles(5, 2, pa)
	if angs2.size() != 5 or absf(angs2[2] - pa) > eps:
		push_error("FAIL: player_index=2 için angs2[2] player_angle olmalı."); fail += 1

	# Tek kişi
	var one := Ring.distribute_angles(1, 0, pa)
	if one.size() != 1 or absf(one[0] - pa) > eps:
		push_error("FAIL: tek jumper player_angle'da olmalı."); fail += 1

	if fail == 0:
		print("TEST RING OK (daralan yarıçap + yeniden dizilim açıları)")
	else:
		print("TEST RING FAILED: %d hata" % fail)
	return fail
