extends Node3D
## F4b GDD Faz 1 HİS TESTİ sürücüsü — dev harness (final mimari F5 GameState).
## TickClock + Rope + tek Jumper canlı bağlı: SPACE ile zıpla, ip geçişinde PERFECT/GRAZE/MISS.
## Autoload'ları (Config/EventBus) serbest kullanır — normal sahne çalıştırması, -s değil.

const RING_R := 6.0
const PLAYER_ANGLE := 3.0 * PI / 2.0   # 270°, ekranın altı (§4.4)

var _clock: TickClock
var _rope: Rope
var _jumper: Jumper
var _round := 1
var _flash := 0.0

@onready var _input: InputQueue = $Input
@onready var _rope_viz: RopeVisual = $RopeSpinner
@onready var _jumper_viz: Node3D = $JumperViz
@onready var _feedback: Label = $UI/Feedback
@onready var _info: Label = $UI/Info


func _ready() -> void:
	_clock = TickClock.new(); add_child(_clock)
	_rope = Rope.new(); add_child(_rope)
	_rope.reset(0.0, Rope.rpm_to_rad_per_sec(25.0))
	_rope_viz.bind(_rope)

	_input.setup(_clock)
	_jumper = Jumper.new(); add_child(_jumper)
	_jumper.id = 0
	_jumper.angle_pos = PLAYER_ANGLE
	_jumper.setup(HumanInput.new(_input), Config.jumper_tuning())
	_rope.crossed.connect(_on_crossed)

	_jumper_viz.position = Vector3(cos(PLAYER_ANGLE) * RING_R, 0.0, sin(PLAYER_ANGLE) * RING_R)
	_feedback.modulate.a = 0.0


func _physics_process(_dt: float) -> void:
	_clock.advance()
	var t := _clock.current_tick
	_jumper.tick(t)   # önce girdi/durum güncellenir
	_rope.tick(t, Config.perfect_ms(_round), Config.graze_ms(_round), [_jumper])  # sonra süpürme
	_rope_viz.on_logic_step()


func _process(dt: float) -> void:
	if _clock == null:
		return
	var t := _clock.current_tick
	# Zıplama arkı (sin) + eğilme squash — yalnız görsel.
	var y := sin(_jumper.air_progress(t) * PI) * 1.4
	_jumper_viz.position.y = y
	_jumper_viz.scale.y = 0.6 if _jumper.is_ducking else 1.0
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 1.5)
		_feedback.modulate.a = _flash
	_info.text = "SPACE: zıpla (basılı tut = yüksek)   S/↓: eğil\ntick %d   FPS %d" % [t, Engine.get_frames_per_second()]


func _on_crossed(id: int, result: int, delta_ms: float) -> void:
	EventBus.rope_crossed.emit(id, result, delta_ms)   # F5 köprüsü (§3.2 mimari)
	_flash = 1.0
	match result:
		Rope.CrossResult.PERFECT:
			_feedback.text = "PERFECT  (%d ms)" % int(delta_ms); _feedback.modulate = Color(0.3, 1.0, 0.4, 1.0)
		Rope.CrossResult.GRAZE:
			_feedback.text = "GRAZE  (%d ms)" % int(delta_ms); _feedback.modulate = Color(1.0, 0.9, 0.3, 1.0)
		Rope.CrossResult.MISS:
			_feedback.text = "MISS"; _feedback.modulate = Color(1.0, 0.35, 0.3, 1.0)
