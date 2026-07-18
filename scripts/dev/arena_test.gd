extends Node3D
## F5b editör kontrolü — dev harness (final arena F8/GameState). Çoklu jumper + daralan çember +
## yeniden dizilim + eleme impulsu + StumbleJudge/EventBus köprüsü.
## Oyuncu (id 0, mavi) SPACE ile oynar → gerçek sendeleme/eleme. Dummy'ler (gri) yer tutucu
## (gerçek botlar F6). E = rastgele bir dummy'yi ele (çember tepkisini göster). R = yeniden başlat.

const N_START := 8
const PLAYER_ANGLE := PI / 2.0
const SHRINK_S := 0.6          # yeniden dizilim tween süresi (§4.4)

# Zıplama görseli (play_test ile aynı hız modeli)
const JUMP_V0 := 6.0
const GRAV_NORMAL := 28.0
const GRAV_HIGH := 14.0

var _clock: TickClock
var _rope: Rope
var _judge := StumbleJudge.new()
var _players := {}          # id -> {jumper, viz(Node3D), cap(MeshInstance3D), mat}
var _alive_ids: Array = []  # açısal sıralı canlı id'ler (oyuncu içeride)
var _player_id := 0
var _round := 1
var _suspended := false
var _r_min := 2.2
var _r_max := 9.0
var _ring_radius := 9.0
var _flying := []           # elenen gövdeler: {node, vel:Vector3, angvel:float, life:float}

# oyuncu zıplama görseli
var _viz_vy := 0.0
var _viz_y := 0.0
var _last_jump_tick := -999

@onready var _input: InputQueue = $Input
@onready var _rope_viz: RopeVisual = $RopeSpinner
@onready var _info: Label = $UI/Info


func _ready() -> void:
	Rng.seed_round(12345)
	_r_min = float(Config.ring.get("r_min", 2.2))
	_r_max = float(Config.ring.get("r_max", 9.0))

	_clock = TickClock.new(); add_child(_clock)
	_rope = Rope.new(); add_child(_rope)
	_rope.reset(0.0, Rope.rpm_to_rad_per_sec(25.0))
	_rope_viz.bind(_rope)
	_rope_viz.scale = Vector3(_r_max / 6.0, 1.0, 1.0)   # rope çubuğu (6 birim) r_max'a ulaşsın
	_rope.crossed.connect(_on_crossed)
	_input.setup(_clock)

	for i in N_START:
		_spawn_jumper(i)
	_alive_ids = range(N_START)
	_snap_positions()


func _spawn_jumper(id: int) -> void:
	var j := Jumper.new(); add_child(j)
	j.id = id
	if id == _player_id:
		j.setup(HumanInput.new(_input), Config.jumper_tuning())
	else:
		j.setup(null, Config.jumper_tuning())   # dummy: girdi yok (yer tutucu)
	var viz := Node3D.new(); add_child(viz)
	var cap := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = 0.4; mesh.height = 1.4
	cap.mesh = mesh; cap.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.9) if id == _player_id else Color(0.55, 0.55, 0.58)
	cap.material_override = mat
	viz.add_child(cap)
	_players[id] = {"jumper": j, "viz": viz, "cap": cap, "mat": mat}


## Tween'siz anlık yerleşim (başlangıç).
func _snap_positions() -> void:
	var n := _alive_ids.size()
	var pidx := _alive_ids.find(_player_id)
	_ring_radius = Ring.radius_for(n, _r_min, _r_max)
	var angles := Ring.distribute_angles(n, pidx, PLAYER_ANGLE)
	for i in n:
		var id = _alive_ids[i]
		_players[id].jumper.angle_pos = angles[i]
		_players[id].viz.position = Ring.world_pos(angles[i], _ring_radius, 0.0)


func _physics_process(_dt: float) -> void:
	_clock.advance()
	var t := _clock.current_tick
	for id in _alive_ids:
		_players[id].jumper.tick(t)
	if not _suspended:
		var targets := []
		for id in _alive_ids:
			targets.append(_players[id].jumper)
		_rope.tick(t, Config.perfect_ms(_round), Config.graze_ms(_round), targets)
	_rope_viz.on_logic_step()


func _on_crossed(id: int, result: int, _delta_ms: float) -> void:
	# F5b: yalnız oyuncu gerçek sendeleme/eleme (dummy'ler yer tutucu — F6 botları gelene dek).
	if id != _player_id:
		return
	var j = _players[id].jumper
	var outcome := _judge.resolve(j, result, Config.pardon_rounds(_round))
	match outcome:
		StumbleJudge.Outcome.STUMBLED:
			EventBus.jumper_stumbled.emit(id)
			_players[id].mat.albedo_color = Color(1.0, 0.85, 0.2)   # ⚠ sarı
		StumbleJudge.Outcome.PARDONED:
			EventBus.jumper_pardoned.emit(id)
			_players[id].mat.albedo_color = Color(0.35, 0.6, 0.9)   # temiz → mavi
		StumbleJudge.Outcome.ELIMINATED:
			EventBus.jumper_eliminated.emit(id, 0)
			_eliminate(id)


func _eliminate(id: int) -> void:
	if not _alive_ids.has(id):
		return
	_alive_ids.erase(id)
	EventBus.ring_shrunk.emit(_alive_ids.size())
	# Tek gövde impuls (§4.9): kozmetik yön/hız ile fırlat.
	var e = _players[id]
	var viz: Node3D = e.viz
	var dir := Vector3(Rng.cosmetic.randf_range(-1, 1), 1.0, Rng.cosmetic.randf_range(-1, 1)).normalized()
	_flying.append({
		"node": viz, "vel": dir * 7.0 + Vector3.UP * 3.0,
		"angvel": Rng.cosmetic.randf_range(-8, 8), "life": 1.6,
	})
	_players.erase(id)
	_reassign()


func _reassign() -> void:
	var n := _alive_ids.size()
	if n == 0:
		return
	var pidx := _alive_ids.find(_player_id)
	_ring_radius = Ring.radius_for(n, _r_min, _r_max)
	var angles := Ring.distribute_angles(n, pidx, PLAYER_ANGLE)
	_suspended = true   # tween boyunca crossing askıda (§4.4 adalet)
	var tw := create_tween().set_parallel(true)
	for i in n:
		var id = _alive_ids[i]
		_players[id].jumper.angle_pos = angles[i]   # mantık son konuma hemen geçer
		tw.tween_property(_players[id].viz, "position", Ring.world_pos(angles[i], _ring_radius, 0.0), SHRINK_S)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _suspended = false)


func _process(dt: float) -> void:
	if _clock == null:
		return
	var t := _clock.current_tick
	# Oyuncu zıplama görseli (yalnız oyuncu kapsülünün lokal y'si)
	if _players.has(_player_id):
		var pj = _players[_player_id].jumper
		if pj.is_airborne and pj.jump_input_tick != _last_jump_tick:
			_last_jump_tick = pj.jump_input_tick
			_viz_vy = JUMP_V0; _viz_y = 0.0
		var g := GRAV_HIGH if pj.is_high() else GRAV_NORMAL
		_viz_vy -= g * dt; _viz_y += _viz_vy * dt
		if not pj.is_airborne:
			_viz_y = move_toward(_viz_y, 0.0, 8.0 * dt); _viz_vy = 0.0
		_viz_y = maxf(_viz_y, 0.0)
		_players[_player_id].cap.position.y = 0.7 + _viz_y
		_players[_player_id].cap.scale.y = 0.6 if pj.is_ducking else 1.0

	# Elenen gövdeleri uçur + soldur
	var still := []
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

	var pstate := "-"
	if _players.has(_player_id):
		pstate = "havada" if _players[_player_id].jumper.is_airborne else ("⚠" if _players[_player_id].jumper.has_warning else "yerde")
	_info.text = "SPACE zıpla | S/↓ eğil | E: dummy ele | R: reset\ncanlı %d   çember r=%.1f   oyuncu: %s   tick %d" % [_alive_ids.size(), _ring_radius, pstate, t]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_eliminate_random_dummy()
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()


func _eliminate_random_dummy() -> void:
	var dummies := _alive_ids.filter(func(x): return x != _player_id)
	if dummies.is_empty():
		return
	_eliminate(dummies[Rng.cosmetic.randi() % dummies.size()])
