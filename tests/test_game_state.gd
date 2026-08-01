extends RefCounted
## F8a GameState/UIRouter testi: geçiş kuralları, sinyal, reset, ekran eşlemesi.
## (godot --headless -s res://tests/test_game_state.gd)

var _events: Array = []

func run(tree: SceneTree) -> int:
	var fail := 0
	const S := GameState.State

	var gs := GameState.new()
	gs.state_changed.connect(func(f, t): _events.append([f, t]))

	# --- 1) Başlangıç MENU; geçerli akış MENU→COUNTDOWN→PLAYING→RESULTS→COUNTDOWN ---
	if gs.current != S.MENU:
		push_error("FAIL: başlangıç MENU olmalı."); fail += 1
	for step in [S.COUNTDOWN, S.PLAYING, S.RESULTS, S.COUNTDOWN]:
		if not gs.go(step):
			push_error("FAIL: geçerli geçiş reddedildi (%d)." % step); fail += 1
	if gs.current != S.COUNTDOWN:
		push_error("FAIL: akış sonunda COUNTDOWN olmalı."); fail += 1
	if _events.size() != 4:
		push_error("FAIL: 4 state_changed beklenir (%d)." % _events.size()); fail += 1

	# --- 2) Geçersiz geçişler reddedilir, durum bozulmaz ---
	gs.reset()
	if gs.current != S.MENU:
		push_error("FAIL: reset MENU'ye dönmeli."); fail += 1
	if gs.go(S.PLAYING):        # MENU'den doğrudan PLAYING yok
		push_error("FAIL: MENU→PLAYING reddedilmeliydi."); fail += 1
	if gs.current != S.MENU:
		push_error("FAIL: reddedilen geçiş durumu bozmamalı."); fail += 1
	if gs.go(S.RESULTS):        # MENU'den RESULTS yok
		push_error("FAIL: MENU→RESULTS reddedilmeliydi."); fail += 1

	# --- 3) SPECTATE yolu (oyuncu elendi, tur sürüyor — E11) ---
	gs.reset(); gs.go(S.COUNTDOWN); gs.go(S.PLAYING)
	if not gs.go(S.SPECTATE):
		push_error("FAIL: PLAYING→SPECTATE olmalı."); fail += 1
	if not gs.is_running():
		push_error("FAIL: SPECTATE de 'running' sayılmalı."); fail += 1
	if not gs.go(S.RESULTS):
		push_error("FAIL: SPECTATE→RESULTS olmalı."); fail += 1
	if gs.is_running():
		push_error("FAIL: RESULTS running olmamalı."); fail += 1

	# --- 4) UIRouter ekran eşlemesi (main.tscn üzerinde gerçek node'larla) ---
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	var router := main.get_node("UILayer") as UIRouter
	if router == null:
		push_error("FAIL: UILayer UIRouter olmalı."); fail += 1
	else:
		var gs2 := GameState.new()
		router.bind(gs2)
		if not main.get_node("UILayer/MainMenu").visible:
			push_error("FAIL: MENU'de MainMenu görünmeli."); fail += 1
		gs2.go(S.COUNTDOWN)
		if not main.get_node("UILayer/HUD").visible or main.get_node("UILayer/MainMenu").visible:
			push_error("FAIL: COUNTDOWN'da yalnız HUD görünmeli."); fail += 1
		gs2.go(S.PLAYING); gs2.go(S.RESULTS)
		if not main.get_node("UILayer/Results").visible or main.get_node("UILayer/HUD").visible:
			push_error("FAIL: RESULTS'ta yalnız Results görünmeli."); fail += 1
		# Overlay'ler durum değişiminden etkilenmez
		router.show_overlay("SettingsPopup", true)
		gs2.go(S.COUNTDOWN)
		if not main.get_node("UILayer/SettingsPopup").visible:
			push_error("FAIL: overlay durum değişiminde kapanmamalı."); fail += 1
	main.free()

	if fail == 0:
		print("TEST GAME STATE OK (FSM geçişleri, red, SPECTATE, reset, UIRouter ekranları)")
	else:
		print("TEST GAME STATE FAILED: %d hata" % fail)
	return fail
