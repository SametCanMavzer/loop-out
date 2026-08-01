extends RefCounted
## F1 tam denetim: InputMap, sahne yükleme, proje ayarları. Tek seferlik kontrol aracı.

func run(tree: SceneTree) -> int:
	var fail := 0

	# --- Proje ayarları (TDD §1, §4.1) ---
	var tps := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0))
	if tps != 60:
		push_error("FAIL: physics_ticks_per_second=%d, beklenen 60." % tps); fail += 1
	var rmethod := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if rmethod != "gl_compatibility":
		push_error("FAIL: renderer=%s, beklenen gl_compatibility." % rmethod); fail += 1
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene != "res://scenes/main.tscn":
		push_error("FAIL: main_scene=%s." % main_scene); fail += 1

	# --- InputMap (TDD §6: jump + duck var; high_jump ayrı aksiyon DEĞİL, hold'dan türetilir) ---
	if not InputMap.has_action("jump"):
		push_error("FAIL: 'jump' aksiyonu yok."); fail += 1
	if not InputMap.has_action("duck"):
		push_error("FAIL: 'duck' aksiyonu yok."); fail += 1
	if InputMap.has_action("high_jump"):
		push_error("FAIL: 'high_jump' ayrı aksiyon olmamalı (§6 hold-türevi)."); fail += 1

	# --- Sahneler hatasız yükleniyor + instantiate ediliyor mu? ---
	for path in ["res://scenes/main.tscn", "res://scenes/fps_test.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			push_error("FAIL: sahne yüklenemedi: %s" % path); fail += 1
			continue
		var inst := ps.instantiate()
		if inst == null:
			push_error("FAIL: instantiate başarısız: %s" % path); fail += 1
		else:
			inst.free()

	if fail == 0:
		print("AUDIT F1 OK (proje ayarları, InputMap, sahne yükleme)")
	else:
		print("AUDIT F1 FAILED: %d hata" % fail)
	return fail
