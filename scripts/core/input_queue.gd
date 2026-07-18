class_name InputQueue extends Node
## Tick damgalı girdi kuyruğu (TDD §4.1, §6). Girdiler _input'ta yakalanır, yakalandıkları
## tick ile damgalanıp kuyruklanır; simülasyon yalnız bu kuyruğu okur → aynı seed + aynı
## tick listesi = aynı tur. HumanInput (§3.4, F4) poll() ile kuyruğu boşaltır.

const ACTIONS: Array[StringName] = [&"jump", &"duck"]

var _queue: Array[InputCommand] = []
var _tick_clock: TickClock


## Ebeveyn (GameState) bağlar — "call down": çocuk yukarıyı get_node ile aramaz.
func setup(tick_clock: TickClock) -> void:
	_tick_clock = tick_clock


func _input(event: InputEvent) -> void:
	if _tick_clock == null:
		return  # setup() çağrılmadan damgalama yapma (tick=0 ile sessiz wiring hatasını önler).
	for action in ACTIONS:
		if event.is_action_pressed(action, false):
			enqueue(action, true)
		elif event.is_action_released(action):
			enqueue(action, false)


## Komutu kuyruğa ekler. tick verilmezse mevcut tick'le damgalar (test için tick geçilebilir).
func enqueue(action: StringName, pressed: bool, tick: int = -1) -> void:
	var t := tick
	if t < 0:
		t = _tick_clock.current_tick if _tick_clock != null else 0
	_queue.append(InputCommand.new(t, action, pressed))


## Verilen tick'e (dahil) kadar damgalı komutları yakalanma sırasıyla çıkarır; sonrasını bırakır.
## Simülasyon her tick bir kez çağırır.
func poll(tick: int) -> Array[InputCommand]:
	var out: Array[InputCommand] = []
	var remaining: Array[InputCommand] = []
	for cmd in _queue:
		if cmd.tick <= tick:
			out.append(cmd)
		else:
			remaining.append(cmd)
	_queue = remaining
	return out


func clear() -> void:
	_queue.clear()


func size() -> int:
	return _queue.size()
