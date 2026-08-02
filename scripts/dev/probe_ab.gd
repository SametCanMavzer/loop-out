extends Node
## A/B teşhis: AYNI seed, AYNI ArenaController — iki farklı çalıştırma yolu.
##   A) manuel step()   → sim_balance'ın yaptığı (frame temposundan bağımsız)
##   B) _physics_process → gerçek oyunun yaptığı
## Sonuçlar farklıysa sorun çalıştırma yolunda/frame temposunda; aynıysa fark sahne
## bileşenlerinden (ArenaView/HUD/Audio/Ads/Analytics) geliyordur.
##
## Çalıştırma: godot --headless scenes/dev/probe_ab.tscn

const SEED := 20250801
const TICKS := 1200          # 20 oyun-saniyesi

var _b_ctrl: ArenaController
var _b_queue: InputQueue
var _b_log: Array = []
var _a_log: Array = []


func _ready() -> void:
	_a_log = _run_manual(SEED)
	# B: aynı seed, ama _physics_process ile sürülecek
	_b_ctrl = ArenaController.new()
	add_child(_b_ctrl)
	_b_queue = InputQueue.new()
	add_child(_b_queue)
	_b_ctrl.setup(_b_queue)
	_b_queue.setup(_b_ctrl.clock)
	_b_ctrl.start_round(SEED)       # _physics_process açık kalır


func _run_manual(seed: int) -> Array:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var q := InputQueue.new()
	add_child(q)
	ctrl.setup(q)
	q.setup(ctrl.clock)
	ctrl.set_physics_process(false)
	ctrl.start_round(seed)
	var log: Array = []
	for i in TICKS:
		ctrl.step()
		if ctrl.clock.current_tick % 120 == 0:
			log.append([ctrl.clock.current_tick, ctrl.round_no, ctrl.alive_ids.size()])
		if ctrl.alive_ids.size() <= 1:
			break
	log.append([ctrl.clock.current_tick, ctrl.round_no, ctrl.alive_ids.size()])
	ctrl.queue_free()
	q.queue_free()
	return log


func _physics_process(_dt: float) -> void:
	if _b_ctrl == null:
		return
	var t: int = _b_ctrl.clock.current_tick
	if t > 0 and t % 120 == 0 and (_b_log.is_empty() or _b_log[-1][0] != t):
		_b_log.append([t, _b_ctrl.round_no, _b_ctrl.alive_ids.size()])
	if t >= TICKS or _b_ctrl.alive_ids.size() <= 1:
		_b_log.append([t, _b_ctrl.round_no, _b_ctrl.alive_ids.size()])
		_report()
		get_tree().quit()


func _report() -> void:
	print("=== A/B TEŞHİS (aynı seed %d) ===" % SEED)
	print("  tick |  A: manuel step (sim yolu)  |  B: _physics_process (oyun yolu)")
	var n: int = maxi(_a_log.size(), _b_log.size())
	var mismatch := 0
	for i in n:
		var a: String = ("tur %2d canlı %2d" % [_a_log[i][1], _a_log[i][2]]) if i < _a_log.size() else "     —"
		var b: String = ("tur %2d canlı %2d" % [_b_log[i][1], _b_log[i][2]]) if i < _b_log.size() else "     —"
		var tick: int = _a_log[i][0] if i < _a_log.size() else _b_log[i][0]
		var mark := ""
		if i < _a_log.size() and i < _b_log.size() and _a_log[i][2] != _b_log[i][2]:
			mark = "   <-- FARKLI"
			mismatch += 1
		print("  %5d |  %s  |  %s%s" % [tick, a, b, mark])
	print("--- SONUÇ ---")
	if mismatch == 0:
		print("  Çalıştırma yolu FARK YARATMIYOR → fark sahne bileşenlerinden geliyor.")
	else:
		print("  %d noktada FARKLI → aynı seed farklı sonuç: determinizm/tempo sorunu." % mismatch)
