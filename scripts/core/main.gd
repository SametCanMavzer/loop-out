class_name MainRoot extends Node3D
## Kök koordinatör (TDD §7.1). GameState akışını, UIRouter'ı ve Arena'yı bağlar.
## Sahne HİÇ değişmez; restart = ArenaController.reset() + yeni tur (sahne reload YOK).

const COUNTDOWN_S := 1.0    # GDD §2.3: "OYNA → 1 sn geri sayım → tur başlar"

var state := GameState.new()

@onready var _arena_root: Node3D = $Arena3D
@onready var _router: UIRouter = $UILayer

var _arena: ArenaView
var _input_queue := InputQueue.new()


func _ready() -> void:
	_input_queue.name = "InputQueue"
	add_child(_input_queue)

	var arena_scene := load("res://scenes/arena/arena.tscn") as PackedScene
	_arena = arena_scene.instantiate()
	_arena_root.add_child(_arena)
	_arena.controller.setup(_input_queue)
	_input_queue.setup(_arena.controller.clock)

	_router.bind(state)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.player_eliminated.connect(_on_player_eliminated)

	# v1 akışı: menü yok sayılır (GDD "Lobi yok → OYNA"); doğrudan geri sayım + tur.
	start_new_round()


## Yeni tur: geri sayım → oyun. Restart bu fonksiyondan geçer (<2 sn, sahne yüklenmez).
func start_new_round() -> void:
	if state.current == GameState.State.MENU or state.current == GameState.State.RESULTS:
		state.go(GameState.State.COUNTDOWN)
	elif state.current != GameState.State.COUNTDOWN:
		state.reset()
		state.go(GameState.State.COUNTDOWN)
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF  # tur öncesi, gameplay dışı
	_arena.controller.start_round(seed)
	_arena.rebuild()
	await get_tree().create_timer(COUNTDOWN_S).timeout   # kozmetik bekleme (gameplay tick'i değil)
	if state.current == GameState.State.COUNTDOWN:
		state.go(GameState.State.PLAYING)


func _on_player_eliminated(_alive: int) -> void:
	# GDD §5.4: ≤3 kalan varsa finali izlet, değilse doğrudan sonuç.
	if _arena.controller.should_spectate():
		state.go(GameState.State.SPECTATE)
	else:
		state.go(GameState.State.RESULTS)


func _on_round_ended(_placement: int, _coins: int) -> void:
	state.go(GameState.State.RESULTS)


func restart() -> void:
	start_new_round()


func arena() -> ArenaView:
	return _arena
