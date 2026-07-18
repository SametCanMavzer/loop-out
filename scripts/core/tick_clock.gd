class_name TickClock extends Node
## 60Hz sabit tick çekirdeği (TDD §4.1). Tüm oyun mantığının tek zaman kaynağı.
## Çalışırken her _physics_process'te bir tick ilerler; testler advance()'i doğrudan
## çağırabilir (zamanlamadan bağımsız determinizm). GameState (F5) start/stop eder.

signal ticked(tick: int)

const TICKS_PER_SECOND := 60
const TICK_DT := 1.0 / float(TICKS_PER_SECOND)

var current_tick: int = 0
var running: bool = false


func _ready() -> void:
	# Determinizm: fiziği 60Hz'e sabitle (§4.1). project.godot da ayarlar; burada garanti.
	Engine.physics_ticks_per_second = TICKS_PER_SECOND


func start() -> void:
	running = true


func stop() -> void:
	running = false


func reset() -> void:
	current_tick = 0
	running = false


func _physics_process(_delta: float) -> void:
	if running:
		advance()


## Bir tick ilerlet. Simülasyon adımının kalbi; sinyal dinleyicileri (rope, jumper) buradan işler.
func advance() -> void:
	current_tick += 1
	ticked.emit(current_tick)
