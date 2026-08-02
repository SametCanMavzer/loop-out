extends Node
## GERÇEK oyunu (main.tscn) baştan sona ölçer ve GDD §4.2 eğrisiyle karşılaştırır.
## Oyuncu yerine "iyi oynayan insan" vekili konur (Sağlam arketipi) — aksi hâlde headless'ta
## oyuncu hiç zıplamaz, tur 2'de elenir ve oyun sonuç ekranında durur, eğri ölçülemez.
##
## Çalıştırma: godot --headless scenes/dev/probe_real_game.tscn

const MAX_REAL_S := 240.0
const CHECKPOINTS := [5, 12, 19, 29]
const TARGETS := {5: 13, 12: 9, 19: 6, 29: 3}

var _main: Node
var _controller: ArenaController
var _alive_at := {}
var _elim_rounds: Array = []
var _t0 := 0.0
var _last_round := 0


func _ready() -> void:
	EventBus.jumper_eliminated.connect(_on_elim)
	EventBus.round_started.connect(_on_round_started)
	var scene := load("res://scenes/main.tscn") as PackedScene
	_main = scene.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_controller = _main.get_node("Arena3D").get_child(0).get_node("ArenaController")
	_t0 = Time.get_ticks_msec() / 1000.0
	print("=== GERÇEK OYUN ÖLÇÜMÜ (main.tscn, oyuncu = iyi oynayan vekil) ===")


## Tur kurulduktan sonra oyuncunun girdisini "iyi oyuncu" vekiliyle değiştir.
func _on_round_started(_round_no: int, _seed: int) -> void:
	if _controller == null:
		return
	var pj: Jumper = _controller.jumper(ArenaController.PLAYER_ID)
	if pj == null:
		return
	var arch := load("res://data/archetypes/saglam.tres") as BotArchetype
	var brain := BotBrain.new()
	brain.setup(Rng.bots, arch, _controller.rope, pj, _controller.round_no,
		float(Config.bots.get("lookahead_ms", 600)))
	pj.setup(brain, Config.jumper_tuning())


func _on_elim(_id: int, _cause: int) -> void:
	if _controller != null:
		_elim_rounds.append(_controller.round_no)


func _physics_process(_dt: float) -> void:
	if _controller == null:
		return
	var r: int = _controller.round_no
	if r != _last_round:
		_last_round = r
		if not _alive_at.has(r):
			_alive_at[r] = _controller.alive_ids.size()
	var elapsed := Time.get_ticks_msec() / 1000.0 - _t0
	if _controller.alive_ids.size() <= 1 or elapsed > MAX_REAL_S:
		_report()
		get_tree().quit()


func _report() -> void:
	var ticks: int = _controller.clock.current_tick
	print("--- GDD §4.2 kadro eğrisi ---")
	for cp in CHECKPOINTS:
		if _alive_at.has(cp):
			var v: int = _alive_at[cp]
			var target: int = TARGETS[cp]
			var mark := "✓" if absi(v - target) <= 2 else "✗ SAPMA"
			print("  tur %2d: canlı %2d  (hedef %d)  %s" % [cp, v, target, mark])
		else:
			print("  tur %2d: ulaşılmadı" % cp)
	print("--- oturum ---")
	print("  bitiş turu: %d   canlı: %d" % [_controller.round_no, _controller.alive_ids.size()])
	print("  süre: %d tick = %.0f sn   (GDD hedefi 60-120 sn)" % [ticks, float(ticks) / 60.0])
	print("  toplam eleme: %d" % _elim_rounds.size())
	var secs := float(ticks) / 60.0
	if secs >= 55.0 and secs <= 130.0:
		print("  SONUÇ: süre hedefte ✓")
	else:
		print("  SONUÇ: süre hedef dışı ✗")
