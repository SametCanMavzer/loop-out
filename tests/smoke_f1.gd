extends SceneTree
## F1 duman testi: autoload'lar yüklendi mi, Config balance.json'ı ayrıştırdı mı,
## Rng stream'leri deterministik mi? (godot --headless -s res://tests/smoke_f1.gd)
## Not: -s ile çalışan SceneTree'de autoload'lara global tanımlayıcı yerine
## get_node + dinamik çağrı ile erişilir (derleme anında global map hazır değil).

func _process(_delta: float) -> bool:
	# İlk idle frame: autoload'ların _ready()'leri artık koştu.
	var fail := 0

	# 7 autoload erişilebilir mi?
	for n in ["EventBus", "Config", "SaveGame", "Audio", "Analytics", "Ads", "Rng"]:
		if root.get_node_or_null(NodePath(n)) == null:
			push_error("FAIL: autoload eksik: %s" % n); fail += 1

	var cfg := root.get_node_or_null(^"Config")
	var rng := root.get_node_or_null(^"Rng")

	# Config yüklendi + tipli erişim çalışıyor mu?
	if cfg == null or not cfg.call("is_loaded"):
		push_error("FAIL: Config yüklenmedi."); fail += 1
	elif int((cfg.get("timing") as Dictionary).get("perfect_ms", -1)) != 90:
		push_error("FAIL: Config.timing.perfect_ms beklenen 90 değil."); fail += 1

	# ms→tick dönüşümü (90ms → floor(5.4) = 5 tick, TDD §4.1)
	if cfg != null and int(cfg.call("ms_to_ticks", 90.0)) != 5:
		push_error("FAIL: ms_to_ticks(90) beklenen 5 değil."); fail += 1

	# Tipli zamanlama getter'ları (§4.3/§4.5): tur-bağımlı graze daralması + sudden death
	if cfg != null:
		if int(cfg.call("perfect_ms", 1)) != 90:
			push_error("FAIL: perfect_ms(1) beklenen 90."); fail += 1
		if int(cfg.call("graze_ms", 1)) != 160:
			push_error("FAIL: graze_ms(1) beklenen 160."); fail += 1
		if int(cfg.call("graze_ms", 25)) != 130:
			push_error("FAIL: graze_ms(25) beklenen 130 (daralan rejim)."); fail += 1
		if int(cfg.call("graze_ms", 35)) != int(cfg.call("perfect_ms", 35)):
			push_error("FAIL: graze_ms(35) sudden death'te perfect_ms'e eşit olmalı (graze yok)."); fail += 1
		# Jumper tuning ms→tick (§6): 420→25, 700→42, 300→18, 120→7, 100→6
		var jt: Variant = cfg.call("jumper_tuning")
		if jt == null or jt.jump_air != 25 or jt.high_jump_air != 42 or jt.hold_threshold != 18 \
				or jt.duck_release != 7 or jt.input_buffer != 6:
			push_error("FAIL: jumper_tuning tick değerleri yanlış."); fail += 1
		# Af eşiği (§4.5): rejim geçişleri + sudden death
		if int(cfg.call("pardon_rounds", 1)) != 5 or int(cfg.call("pardon_rounds", 25)) != 7 \
				or int(cfg.call("pardon_rounds", 35)) != -1:
			push_error("FAIL: pardon_rounds rejim değerleri yanlış (5/7/-1)."); fail += 1

	# Rng determinizmi: aynı seed → aynı ilk değer
	if rng != null:
		rng.call("seed_round", 1234)
		var a: int = rng.get("behavior").randi()
		rng.call("seed_round", 1234)
		var b: int = rng.get("behavior").randi()
		if a != b:
			push_error("FAIL: Rng aynı seed'de farklı değer üretti."); fail += 1

	if fail == 0:
		print("SMOKE F1 OK (7 autoload, Config, ms_to_ticks, Rng determinizm)")
	else:
		print("SMOKE F1 FAILED: %d hata" % fail)
	quit(fail)
	return true
