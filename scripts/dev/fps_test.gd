extends Node3D
## F1-KAPI / E10 kapısı: hedef cihazda boş sahne + 17 kapsül FPS testi (TDD §18-1, §11).
## Amaç: "Godot 4 3D mobil tarayıcıda 60fps" varsayımını gün 1'de doğrulamak.
## Bu bir geliştirme aracıdır — final mimarinin parçası değil.

const CAPSULE_COUNT := 17
const RING_RADIUS := 6.0

@onready var _fps_label: Label = $UI/FpsLabel


func _ready() -> void:
	_spawn_capsules()


func _spawn_capsules() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.5, 0.3)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.6
	for i in CAPSULE_COUNT:
		var angle := TAU * i / float(CAPSULE_COUNT)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(cos(angle) * RING_RADIUS, 0.8, sin(angle) * RING_RADIUS)
		add_child(mi)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
