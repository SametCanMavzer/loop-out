extends Node3D
## F3b editör kontrolü için dev sürücü — final mimarinin parçası DEĞİL (F5 GameState sürer).
## TickClock + Rope (mantık) + RopeSpinner (görsel) bağlar; ipi döndürür, LOW/HIGH yükseklik
## ve süpürme gölgesi editörde görülebilsin diye periyodik yükseklik değiştirir.

const HEIGHT_FLIP_TICKS := 150  # ~2.5 sn'de bir LOW<->HIGH

var _tick_clock: TickClock
var _rope: Rope

@onready var _visual: RopeVisual = $RopeSpinner
@onready var _label: Label = $UI/Info


func _ready() -> void:
	_tick_clock = TickClock.new()
	add_child(_tick_clock)
	_rope = Rope.new()
	add_child(_rope)
	_rope.reset(0.0, Rope.rpm_to_rad_per_sec(25.0))  # start_rpm yönü +
	_visual.bind(_rope)


func _physics_process(_delta: float) -> void:
	_tick_clock.advance()
	var t := _tick_clock.current_tick
	# Yükseklik demosu: her HEIGHT_FLIP_TICKS'te LOW<->HIGH.
	_rope.height = Rope.Height.HIGH if (t / HEIGHT_FLIP_TICKS) % 2 == 1 else Rope.Height.LOW
	_rope.tick(t, 90, 160, [])  # jumper yok; yalnız dönüş+gölge demosu
	_visual.on_logic_step()


func _process(_delta: float) -> void:
	if _rope != null:
		_label.text = "tick %d\naçı %.2f rad\nyükseklik %s\nFPS %d" % [
			_tick_clock.current_tick, _rope.angle,
			("HIGH" if _rope.height == Rope.Height.HIGH else "LOW"),
			Engine.get_frames_per_second()]
