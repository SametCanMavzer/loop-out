extends Node3D
## F4b GDD Faz 1 HİS TESTİ sürücüsü — dev harness (final mimari F5 GameState).
## TickClock + Rope + tek Jumper canlı bağlı: SPACE ile zıpla, ip geçişinde PERFECT/GRAZE/MISS.
## Autoload'ları (Config/EventBus) serbest kullanır — normal sahne çalıştırması, -s değil.

const RING_R := 6.0
## Rope görseli Y-rotasyonu +X'i (cos a, 0, -sin a) yönüne çevirir. Jumper dünya konumu da
## AYNI konvansiyonu kullanmalı yoksa görsel ip ile mantıksal geçiş farklı yerde olur.
## a=π/2 → jumper öne (-Z, kameraya dönük) gelir ve ip tam oraya süpürür.
const PLAYER_ANGLE := PI / 2.0

var _clock: TickClock
var _rope: Rope
var _jumper: Jumper
var _round := 1
var _flash := 0.0

# Zıplama görseli — hız tabanlı (pop yok). basılı tutunca (high) yerçekimi azalır → yumuşak süzülme.
const JUMP_V0 := 6.0
const GRAV_NORMAL := 28.0
const GRAV_HIGH := 14.0
var _viz_y := 0.0
var _viz_vy := 0.0
var _last_jump_tick := -999

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

	_jumper_viz.position = Vector3(cos(PLAYER_ANGLE) * RING_R, 0.0, -sin(PLAYER_ANGLE) * RING_R)
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
	# Zıplama görseli: yeni zıplamada ilk hızı ver; her karede hız-entegre et (pop yok).
	if _jumper.is_airborne and _jumper.jump_input_tick != _last_jump_tick:
		_last_jump_tick = _jumper.jump_input_tick
		_viz_vy = JUMP_V0
		_viz_y = 0.0
	var g := GRAV_HIGH if _jumper.is_high() else GRAV_NORMAL   # basılı tut → daha yumuşak/uzun süzülme
	_viz_vy -= g * dt
	_viz_y += _viz_vy * dt
	if not _jumper.is_airborne:
		_viz_y = move_toward(_viz_y, 0.0, 8.0 * dt)   # inişte yere otur
		_viz_vy = 0.0
	_viz_y = maxf(_viz_y, 0.0)
	_jumper_viz.position.y = _viz_y
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
