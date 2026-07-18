class_name HumanInput extends InputSource
## İnsan girdisi (TDD §3.4, §6): tick damgalı InputQueue'yu poll ile boşaltır.
## Kuyruk _input'ta doldurulur (InputQueue); Jumper bu poll'dan komutları alır.

var _queue: InputQueue


func _init(queue: InputQueue) -> void:
	_queue = queue


func poll(tick: int) -> Array[InputCommand]:
	if _queue == null:
		return []
	return _queue.poll(tick)
