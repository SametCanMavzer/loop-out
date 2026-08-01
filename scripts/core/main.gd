class_name MainRoot extends Node3D
## Kök koordinatör (TDD §7.1). GameState akışını, UIRouter'ı ve Arena'yı bağlar.
## Sahne HİÇ değişmez; restart = ArenaController.reset() + yeni tur (sahne reload YOK).

const COUNTDOWN_S := 1.0    # GDD §2.3: "OYNA → 1 sn geri sayım → tur başlar"
## Elenme sahnesi (GDD §5.2): savrulma + slow-motion görünsün diye sonuç ekranı kısa gecikir.
## Gerçek zamanlı ölçülür (slow-mo sırasında time_scale 0.3'tür).
const ELIM_SCENE_S := 0.75

var state := GameState.new()

@onready var _arena_root: Node3D = $Arena3D
@onready var _router: UIRouter = $UILayer
@onready var _hud: HUD = $UILayer/HUD
@onready var _results: ResultsScreen = $UILayer/Results
@onready var _characters: CharactersScreen = $UILayer/Characters

var _arena: ArenaView
var _input_queue := InputQueue.new()
var _rewards := RewardCalculator.new()
var _audio_director := AudioDirector.new()
var _round_scored := false      # aynı turun ödülü iki kez yazılmasın


func _ready() -> void:
	_input_queue.name = "InputQueue"
	add_child(_input_queue)

	var arena_scene := load("res://scenes/arena/arena.tscn") as PackedScene
	_arena = arena_scene.instantiate()
	_arena_root.add_child(_arena)
	_arena.controller.setup(_input_queue)
	_input_queue.setup(_arena.controller.clock)

	_rewards.setup(Config.economy)
	_audio_director.name = "AudioDirector"
	add_child(_audio_director)
	_audio_director.setup(_arena.controller)
	_router.bind(state)
	_results.restart_pressed.connect(restart)
	# Karakterler ekranı: sonuç ekranından açılır (overlay — durum makinesini etkilemez).
	_results.characters_pressed.connect(func() -> void:
		_characters.refresh()
		_router.show_overlay("Characters", true))
	_characters.closed.connect(func() -> void: _router.show_overlay("Characters", false))
	_characters.equipped_changed.connect(func(_id: String) -> void: _arena.apply_player_skin())
	_arena.controller.round_advanced.connect(func(r: int) -> void: _hud.set_round(r))
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
	# Turu KUR ama başlatma: geri sayım boyunca ip dönmez, crossing olmaz (oyuncu hazırlanır).
	_round_scored = false
	_arena.controller.prepare_round(seed)
	_arena.rebuild()
	_hud.reset_for_round(_arena.controller.alive_ids.size())
	_hud.show_countdown("HAZIR?")
	await get_tree().create_timer(COUNTDOWN_S).timeout   # UI beklemesi (gameplay tick'i değil)
	if state.current == GameState.State.COUNTDOWN:
		_hud.hide_countdown()
		state.go(GameState.State.PLAYING)
		_arena.controller.begin()
		Audio.start_music()


func _on_player_eliminated(_alive: int) -> void:
	# GDD §5.4: ≤3 kalan varsa finali izlet, değilse sonuç ekranı.
	if _arena.controller.should_spectate():
		state.go(GameState.State.SPECTATE)
		return
	# Elenme sahnesini (ragdoll savrulma + slow-motion) göster, sonra sonuç ekranı.
	await get_tree().create_timer(ELIM_SCENE_S, true, false, true).timeout
	if state.current == GameState.State.PLAYING:      # bu sırada tur bitmediyse
		_show_results(_arena.controller.placement())


func _on_round_ended(placement: int, _coins: int) -> void:
	_show_results(placement)


## Tur sonu: simülasyonu durdur, jetonu hesapla+kaydet (GDD §6.2), sonucu göster.
func _show_results(placement: int) -> void:
	_arena.controller.stop()    # sonuç ekranında simülasyon arkada sürmesin
	var total := int(Config.bots.get("archetype_counts", {}).values().reduce(func(a, b): return a + b, 0)) + 1
	var place := maxi(placement, 1)
	var round_no := _arena.controller.round_no
	var perfects := _arena.controller.perfect_total
	var earned := 0
	var daily := false
	if not _round_scored:
		_round_scored = true
		daily = SaveGame.consume_daily_first_win() if place <= 1 else false
		earned = _rewards.total(place, perfects, daily)
		SaveGame.add_coins(earned)
		SaveGame.record_round(place, round_no, total, int(Config.drama.get("early_exit_threshold", 4)))
		SaveGame.save_game()
	_results.show_result(place, total, round_no, earned, SaveGame.coins(), perfects, daily)
	state.go(GameState.State.RESULTS)


func restart() -> void:
	start_new_round()


func arena() -> ArenaView:
	return _arena
