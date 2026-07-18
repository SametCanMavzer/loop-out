class_name InputCommand extends RefCounted
## Tek girdi olayı (TDD §6): tick damgalı aksiyon + basıldı/bırakıldı bilgisi.
## Simülasyon yalnız bu komutları okur (determinizm). Hold tespiti (§6) press+release
## tick farkından hesaplanır — bu yüzden `pressed` taşınır.

var tick: int
var action: StringName
var pressed: bool


func _init(p_tick: int, p_action: StringName, p_pressed: bool) -> void:
	tick = p_tick
	action = p_action
	pressed = p_pressed


## §4.8 replay formatına yakın seri hale: [tick, action, pressed].
func to_replay() -> Array:
	return [tick, action, pressed]
