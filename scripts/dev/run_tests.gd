extends Node
## Tüm birim testlerini TEK Godot sürecinde koşar (GUT yerine, bağımlılık yok).
## Her test `RefCounted` + `run(tree: SceneTree) -> int` (hata sayısı) sözleşmesini uygular.
##
## Çalıştırma:
##   godot --headless scenes/dev/run_tests.tscn              → hepsi
##   godot --headless scenes/dev/run_tests.tscn -- test_rope → yalnız biri
##
## Not: eskiden her test ayrı süreçte koşuyordu (16 × ~12 sn açılış). Tek süreçte saniyeler sürer.

const TESTS := [
	"smoke_f1", "audit_f1", "test_tick_core", "test_rope", "test_jumper", "test_stumble",
	"test_ring", "test_bot", "test_bot_quirk", "test_behavior", "test_behavior_special",
	"test_director", "test_drama", "test_game_state", "test_economy", "test_audio",
]


func _ready() -> void:
	# Ağaç kurulumu bitsin: bazı testler root'a node ekliyor (_ready içinde add_child yasak).
	await get_tree().process_frame
	var only := ""
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("-"):
			only = a
	var names: Array = TESTS if only == "" else [only]
	var total_fail := 0
	var ran := 0
	var failed: Array = []

	var t0 := Time.get_ticks_msec()
	for name in names:
		var path := "res://tests/%s.gd" % name
		if not ResourceLoader.exists(path):
			print("  ATLANDI  %s (dosya yok)" % name)
			continue
		var script: GDScript = load(path)
		var inst = script.new()
		if not inst.has_method("run"):
			print("  ATLANDI  %s (run() yok)" % name)
			continue
		var fails: int = inst.run(get_tree())
		ran += 1
		if fails != 0:
			total_fail += fails
			failed.append(name)
	var dt := (Time.get_ticks_msec() - t0) / 1000.0

	print("")
	if total_fail == 0:
		print("TÜMÜ GEÇTİ — %d test, %.1f sn" % [ran, dt])
	else:
		print("BAŞARISIZ — %d hata (%s), %d test, %.1f sn" % [total_fail, ", ".join(failed), ran, dt])
	get_tree().quit(1 if total_fail > 0 else 0)
