extends SceneTree
## F9 ekonomi testi: jeton hesabı (GDD §6.2) + SaveGame (kayıt/okuma/migration/seri).
## (godot --headless -s res://tests/test_economy.gd)

func _process(_delta: float) -> bool:
	var fail := 0

	# --- Ödül matematiği (GDD §6.2: 50/25/10/5, +1 perfect, ×3 günlük ilk galibiyet) ---
	var r := RewardCalculator.new()
	r.setup({"win": 50, "top3": 25, "top8": 10, "other": 5,
		"perfect_bonus": 1, "daily_first_win_mult": 3, "ad_mult": 2})
	var cases := [[1, 50], [2, 25], [3, 25], [4, 10], [8, 10], [9, 5], [16, 5]]
	for c in cases:
		if r.placement_reward(c[0]) != c[1]:
			push_error("FAIL: %d. sıra ödülü %d, beklenen %d." % [c[0], r.placement_reward(c[0]), c[1]]); fail += 1
	if r.total(1, 4) != 54:
		push_error("FAIL: 1.sıra + 4 perfect = 54 olmalı (%d)." % r.total(1, 4)); fail += 1
	if r.total(1, 4, true) != 162:
		push_error("FAIL: günlük ilk galibiyet ×3 → 162 olmalı (%d)." % r.total(1, 4, true)); fail += 1
	if r.total(5, 2, true) != 12:
		push_error("FAIL: günlük çarpan yalnız 1.sırada geçerli (%d)." % r.total(5, 2, true)); fail += 1
	if r.with_ad(20) != 40:
		push_error("FAIL: reklam çarpanı ×2 olmalı."); fail += 1

	# --- SaveGame: jeton, karakter, kayıt/okuma döngüsü ---
	var sg := root.get_node_or_null(^"SaveGame")
	if sg == null:
		push_error("FAIL: SaveGame autoload yok."); print("TEST ECONOMY FAILED"); quit(1); return true

	sg.data = sg.call("_defaults")
	sg.call("add_coins", 120)
	if int(sg.call("coins")) != 120:
		push_error("FAIL: add_coins çalışmadı."); fail += 1
	if not bool(sg.call("spend_coins", 100)) or int(sg.call("coins")) != 20:
		push_error("FAIL: spend_coins 100 harcamalı, 20 kalmalı."); fail += 1
	if bool(sg.call("spend_coins", 999)):
		push_error("FAIL: yetersiz jetonla harcama reddedilmeli."); fail += 1
	sg.call("add_character", "robot")
	if not bool(sg.call("owns", "robot")):
		push_error("FAIL: karakter eklenmedi."); fail += 1
	sg.call("equip", "robot")
	if String(sg.call("equipped")) != "robot":
		push_error("FAIL: equip çalışmadı."); fail += 1
	sg.call("equip", "sahip_olmadigim")
	if String(sg.call("equipped")) != "robot":
		push_error("FAIL: sahip olunmayan karakter kuşanılmamalı."); fail += 1

	# --- record_round: rekor + galibiyet + erken-eleme serisi (§4.7) ---
	sg.data = sg.call("_defaults")
	sg.call("record_round", 16, 3, 16, 4)      # ilk 4 elemede gitti → erken
	if int(sg.data["early_exit_streak"]) != 1:
		push_error("FAIL: erken eleme serisi 1 olmalı."); fail += 1
	sg.call("record_round", 15, 5, 16, 4)      # yine erken → 2
	if int(sg.data["early_exit_streak"]) != 2 or int(sg.data["best_round"]) != 5:
		push_error("FAIL: seri 2 / best_round 5 olmalı."); fail += 1
	sg.call("record_round", 2, 20, 16, 4)      # iyi tur → seri sıfırlanır
	if int(sg.data["early_exit_streak"]) != 0 or int(sg.data["best_round"]) != 20:
		push_error("FAIL: iyi turda seri sıfırlanmalı, rekor 20 olmalı."); fail += 1
	sg.call("record_round", 1, 25, 16, 4)      # galibiyet
	if int(sg.data["total_wins"]) != 1:
		push_error("FAIL: galibiyet sayacı artmalı."); fail += 1

	# --- Günlük ilk galibiyet: aynı gün ikinci kez false ---
	sg.data["last_daily_win_date"] = ""
	if not bool(sg.call("consume_daily_first_win")):
		push_error("FAIL: günün ilk galibiyeti true dönmeli."); fail += 1
	if bool(sg.call("consume_daily_first_win")):
		push_error("FAIL: aynı gün ikinci galibiyet false dönmeli."); fail += 1

	# --- Atomik kayıt + geri okuma ---
	sg.data["coins"] = 777
	if not bool(sg.call("save_game")):
		push_error("FAIL: save_game başarısız."); fail += 1
	sg.data = sg.call("_defaults")
	sg.call("load_game")
	if int(sg.call("coins")) != 777:
		push_error("FAIL: kayıt geri okunamadı (%d)." % int(sg.call("coins"))); fail += 1
	# Eksik alan tamamlama (ileri/geri uyum)
	sg.data.erase("total_wins")
	sg.call("save_game")
	sg.call("load_game")
	if not sg.data.has("total_wins"):
		push_error("FAIL: eksik alan varsayılanla tamamlanmalı."); fail += 1

	if fail == 0:
		print("TEST ECONOMY OK (ödül matematiği, jeton/karakter, record_round, günlük, atomik kayıt)")
	else:
		print("TEST ECONOMY FAILED: %d hata" % fail)
	quit(fail)
	return true
