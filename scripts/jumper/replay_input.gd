class_name ReplayInput extends InputSource
## Kayıttan oynatılan girdi (TDD §3.4 ghost_input'un temeli, §4.8 replay formatı).
## Aynı InputSource arayüzünden geçer → Jumper kodu insan/bot/replay ayrımı bilmez (E12).
##
## Format: [[tick, action, pressed], ...] — InputCommand.to_replay() çıktısıyla birebir.

var _commands: Array = []
var _idx := 0


func setup(commands: Array) -> void:
	_commands = commands
	_idx = 0


func reset() -> void:
	_idx = 0


## Verilen tick'e (dahil) kadar kaydedilmiş komutları sırayla döndürür.
func poll(tick: int) -> Array[InputCommand]:
	var out: Array[InputCommand] = []
	while _idx < _commands.size() and int(_commands[_idx][0]) <= tick:
		var c: Array = _commands[_idx]
		out.append(InputCommand.new(int(c[0]), StringName(c[1]), bool(c[2])))
		_idx += 1
	return out


func size() -> int:
	return _commands.size()
