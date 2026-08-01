extends RefCounted
## F9 ekonomi testi: jeton hesabı (GDD §6.2) + SaveGame (kayıt/okuma/migration/seri).
## (godot --headless -s res://tests/test_economy.gd)

func run(tree: SceneTree) -> int:
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
	var sg := tree.root.get_node_or_null(^"SaveGame")
	if sg == null:
		push_error("FAIL: SaveGame autoload yok."); print("TEST ECONOMY FAILED"); return 1

	sg.call("use_test_path", "user://save_test.json")   # gerçek oyuncu kaydını EZME
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

	# --- Gacha (GDD §6.3): 12 karakter, önce sahip olunmayanlar, deterministik ---
	var pool := Gacha.load_pool()
	if pool.size() != 12:
		push_error("FAIL: karakter havuzu 12 olmalı (%d)." % pool.size()); fail += 1
	var rarities := {0: 0, 1: 0, 2: 0}
	for c in pool:
		rarities[c.rarity] = int(rarities.get(c.rarity, 0)) + 1
	if rarities[0] != 8 or rarities[1] != 3 or rarities[2] != 1:
		push_error("FAIL: nadirlik dağılımı 8/3/1 olmalı (%s)." % str(rarities)); fail += 1

	var g1 := Gacha.new(); var rng1 := RandomNumberGenerator.new(); rng1.seed = 77
	g1.setup(pool, rng1)
	var g2 := Gacha.new(); var rng2 := RandomNumberGenerator.new(); rng2.seed = 77
	g2.setup(pool, rng2)
	var d1 := g1.draw(["default"])
	var d2 := g2.draw(["default"])
	if d1 == null or d1.id != d2.id:
		push_error("FAIL: gacha determinizmi bozuk."); fail += 1
	if d1 != null and String(d1.id) == "default":
		push_error("FAIL: sahip olunan karakter önce çekilmemeli."); fail += 1

	# Tüm havuza sahipsen duplikat döner (boş değil)
	var all_ids: Array = pool.map(func(c): return String(c.id))
	if g1.draw(all_ids) == null:
		push_error("FAIL: havuz tamamlanınca da bir karakter dönmeli (duplikat)."); fail += 1

	# 60 çekilişte yaygın > nadir > efsanevi (ağırlıklar makul mü)
	var counts := {0: 0, 1: 0, 2: 0}
	var g3 := Gacha.new(); var rng3 := RandomNumberGenerator.new(); rng3.seed = 5
	g3.setup(pool, rng3)
	for i in 60:
		var c := g3.draw(all_ids)     # hepsi sahip → saf ağırlık dağılımı
		counts[c.rarity] = int(counts[c.rarity]) + 1
	if counts[0] <= counts[2]:
		push_error("FAIL: yaygın karakterler efsaneviden sık çıkmalı (%s)." % str(counts)); fail += 1

	if fail == 0:
		print("TEST ECONOMY OK (ödül, jeton/karakter, record_round, günlük, atomik kayıt, gacha 8/3/1)")
	else:
		print("TEST ECONOMY FAILED: %d hata" % fail)
	return fail
