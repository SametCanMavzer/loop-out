class_name RopeVisual extends Node3D
## İpin görsel katmanı (TDD §4.1: mantık açısı tick'te ilerler, render açısı _process'te
## interpolasyonla çizilir). Yalnız çizim — determinizmi ETKİLEMEZ.
## Mantık ipi (Rope) ebeveyn tarafından bind() edilir; her tick sonrası on_logic_step() çağrılır
## (node işlem sırasına güvenmemek için açı sürücü tarafından itilir).

@export var low_height: float = 0.15    # yer hizası süpürme (üstünden zıpla)
@export var high_height: float = 1.15   # yüksek süpürme (altından eğil)

var rope: Rope

@onready var _bar: MeshInstance3D = $Bar

var _prev_angle: float = 0.0
var _curr_angle: float = 0.0


func bind(logic_rope: Rope) -> void:
	rope = logic_rope
	_prev_angle = rope.angle
	_curr_angle = rope.angle


## Sürücü her mantık tick'inden sonra çağırır (önceki→şimdiki açı interpolasyon için saklanır).
func on_logic_step() -> void:
	if rope == null:
		return
	_prev_angle = _curr_angle
	_curr_angle = rope.angle
	_bar.position.y = high_height if rope.height == Rope.Height.HIGH else low_height


func _process(_delta: float) -> void:
	if rope == null:
		return
	# İki mantık tick'i arasındaki kesir kadar interpolasyon → 60 tick'te bile akıcı dönüş.
	var f := Engine.get_physics_interpolation_fraction()
	rotation.y = lerp_angle(_prev_angle, _curr_angle, f)
