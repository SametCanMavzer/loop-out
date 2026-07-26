class_name ArenaView extends Node3D
## Arena görsel katmanı. ArenaController'ın (mantık) durumunu okur ve çizer — mantığa
## müdahale etmez, determinizmi etkilemez (§4.1: görsel _process'te, mantık tick'te).
## Jumper temsilleri koddan kurulur (CLAUDE.md: .tscn minimal).

const JUMP_V0 := 6.0
const GRAV_NORMAL := 28.0
const GRAV_HIGH := 14.0
const ELIM_LIFE := 1.6

@onready var controller: ArenaController = $ArenaController
@onready var _rope_viz: RopeVisual = $RopeSpinner

var _views := {}        # id -> {node, cap, mat, viz_y, viz_vy, last_jump}
var _flying: Array = []
var _r_max := 9.0


func _ready() -> void:
	_r_max = float(Config.ring.get("r_max", 9.0))
	_rope_viz.bind(controller.rope)
	_rope_viz.scale = Vector3(_r_max / 6.0, 1.0, 1.0)   # çubuk (6 birim) r_max'a ulaşsın
	EventBus.jumper_eliminated.connect(_on_eliminated)
	EventBus.jumper_stumbled.connect(_refresh_color)
	EventBus.jumper_pardoned.connect(_refresh_color)


## Tur başında (controller.start_round sonrası) görsel temsilleri kur.
func rebuild() -> void:
	for v in _views.values():
		if is_instance_valid(v.node):
			v.node.queue_free()
	_views.clear()
	for f in _flying:                     # önceki turun uçan gövdeleri kalmasın
		if is_instance_valid(f.node):
			f.node.queue_free()
	_flying.clear()
	for id in controller.jumper_ids():
		_create_view(id)
	_sync_positions(true)


func _create_view(id: int) -> void:
	var node := Node3D.new()
	add_child(node)
	var cap := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = 0.4; mesh.height = 1.4
	cap.mesh = mesh
	cap.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _base_color(id)
	cap.material_override = mat
	node.add_child(cap)
	_views[id] = {"node": node, "cap": cap, "mat": mat, "viz_y": 0.0, "viz_vy": 0.0, "last_jump": -999}


func _base_color(id: int) -> Color:
	return Color(0.35, 0.6, 0.9) if id == ArenaController.PLAYER_ID else Color(0.55, 0.55, 0.58)


func _refresh_color(id: int) -> void:
	if not _views.has(id):
		return
	var j := controller.jumper(id)
	if j == null:
		return
	_views[id].mat.albedo_color = Color(1.0, 0.85, 0.2) if j.has_warning else _base_color(id)


func _on_eliminated(id: int, _cause: int) -> void:
	if not _views.has(id):
		return
	var v = _views[id]
	# Tek gövde impuls (§4.9) — kozmetik stream, gameplay'i etkilemez.
	var dir := Vector3(Rng.cosmetic.randf_range(-1, 1), 1.0, Rng.cosmetic.randf_range(-1, 1)).normalized()
	_flying.append({
		"node": v.node, "vel": dir * 7.0 + Vector3.UP * 3.0,
		"angvel": Rng.cosmetic.randf_range(-8, 8), "life": ELIM_LIFE,
	})
	_views.erase(id)


func _process(dt: float) -> void:
	_rope_viz.on_logic_step()
	_sync_positions(false, dt)
	_update_flying(dt)


## Canlı jumper'ları çemberdeki yerine (yumuşak) taşı + zıplama/eğilme görselini işle.
func _sync_positions(snap: bool, dt: float = 0.0) -> void:
	var r := controller.ring_radius
	for id in controller.alive_ids:
		if not _views.has(id):
			continue
		var v = _views[id]
		var j := controller.jumper(id)
		if j == null:
			continue
		var target := Ring.world_pos(j.angle_pos, r, 0.0)
		if snap:
			v.node.position = target
		else:
			v.node.position = v.node.position.lerp(target, clampf(dt * 4.0, 0.0, 1.0))
		if dt > 0.0:
			_animate_jump(v, j, dt)


func _animate_jump(v: Dictionary, j: Jumper, dt: float) -> void:
	if j.is_airborne and j.jump_input_tick != v.last_jump:
		v.last_jump = j.jump_input_tick
		v.viz_vy = JUMP_V0
		v.viz_y = 0.0
	var g := GRAV_HIGH if j.is_high() else GRAV_NORMAL
	v.viz_vy -= g * dt
	v.viz_y += v.viz_vy * dt
	if not j.is_airborne:
		v.viz_y = move_toward(v.viz_y, 0.0, 8.0 * dt)
		v.viz_vy = 0.0
	v.viz_y = maxf(v.viz_y, 0.0)
	v.cap.position.y = 0.7 + v.viz_y
	v.cap.scale.y = 0.6 if j.is_ducking else 1.0


func _update_flying(dt: float) -> void:
	var still: Array = []
	for f in _flying:
		f.vel += Vector3.DOWN * 18.0 * dt
		f.node.position += f.vel * dt
		f.node.rotate_z(f.angvel * dt)
		f.life -= dt
		if f.life > 0.0:
			still.append(f)
		else:
			f.node.queue_free()
	_flying = still
