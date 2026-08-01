class_name HumanInput extends InputSource
## İnsan girdisi (TDD §3.4, §6): tick damgalı InputQueue'yu poll ile boşaltır.
## Kuyruk _input'ta doldurulur (InputQueue); Jumper bu poll'dan komutları alır.

var _queue: InputQueue
## §4.8 replay kaydı: simülasyona giren komutlar aynen biriktirilir → {seed, inputs} ile
## tur birebir yeniden oynatılabilir ("bug raporu = seed", v2a ghost bedava).
var _record: Array = []
var _recording := true


func _init(queue: InputQueue) -> void:
	_queue = queue


func poll(tick: int) -> Array[InputCommand]:
	if _queue == null:
		return []
	var cmds := _queue.poll(tick)
	if _recording:
		for c in cmds:
			_record.append(c.to_replay())
	return cmds


## Kaydedilen girdi listesi (replay/ghost için).
func recording() -> Array:
	return _record


func clear_recording() -> void:
	_record.clear()


func set_recording(on: bool) -> void:
	_recording = on
