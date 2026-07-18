extends Node3D
## F5b+F6b editör kontrolü — dev harness (final arena F8/GameState). Çoklu jumper + daralan
## çember + yeniden dizilim + eleme impulsu + StumbleJudge/EventBus köprüsü + gerçek botlar.
## Oyuncu (id 0, mavi) SPACE ile oynar; botlar (gri) BotBrain ile Rng.bots'tan zıplar (§4.6).
## Tur ilerledikçe σ büyür → doğal eleme. E = rastgele rakip ele, R = yeniden başlat.

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
var _reassign_tween: Tween
var _arch_by_id := {}       # id -> BotArchetype (oyuncu: null)
var _pending_elim: Array = []   # bu tick elenecekler (rope.tick sonrası toplu uygulanır)

@onready var _input: InputQueue = $Input
@onready var _rope_viz: RopeVisual = $RopeSpinner
@onready var _info: Label = $UI/Info
@onready var _feedback: Label = $UI/Feedback

var _flash := 0.0


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

	$UI/Restart.pressed.connect(func() -> void: get_tree().reload_current_scene())

	# Bot arketip dağıtımı (7 bot): karışık Acemi/Panikçi/Sağlam.
	var acemi := load("res://data/archetypes/acemi.tres")
	var panik := load("res://data/archetypes/panikci.tres")
	var saglam := load("res://data/archetypes/saglam.tres")
	var dist := [saglam, panik, acemi, acemi, panik, saglam, acemi]  # id 1..7
	for i in N_START:
		_arch_by_id[i] = null if i == _player_id else dist[(i - 1) % dist.size()]
		_spawn_jumper(i)
	_alive_ids = range(N_START)
	_snap_positions()


func _spawn_jumper(id: int) -> void:
	var j := Jumper.new(); add_child(j)
	j.id = id
	if id == _player_id:
		j.setup(HumanInput.new(_input), Config.jumper_tuning())
	else:
		var brain := BotBrain.new()   # gerçek rakip: BotBrain, Rng.bots stream (§4.6/§4.8)
		brain.setup(Rng.bots, _arch_by_id[id], _rope, j, _round, float(Config.bots.get("lookahead_ms", 600)))
		j.setup(brain, Config.jumper_tuning())
	var viz := Node3D.new(); add_child(viz)
	var cap := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = 0.4; mesh.height = 1.4
	cap.mesh = mesh; cap.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.9) if id == _player_id else Color(0.55, 0.55, 0.58)
	cap.material_override = mat
	viz.add_child(cap)
	_players[id] = {"jumper": j, "viz": viz, "cap": cap, "mat": mat,
		"viz_y": 0.0, "viz_vy": 0.0, "last_jump": -999}


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
	# Demo tur ilerlemesi: her 720 tick (~12sn) σ büyür → doğal eleme (zorluk eğrisi).
	if t > 0 and t % 720 == 0:
		_round += 1
		for id in _alive_ids:
			var src = _players[id].jumper.input_source
			if src is BotBrain:
				src.set_round(_round)
	for id in _alive_ids:
		_players[id].jumper.tick(t)
	# İp her zaman döner (§4.4); tween sırasında yalnız crossing askıda → boş hedef listesi.
	var targets := []
	if not _suspended:
		for id in _alive_ids:
			targets.append(_players[id].jumper)
	_rope.tick(t, Config.perfect_ms(_round), Config.graze_ms(_round), targets)
	_rope_viz.on_logic_step()
	if not _pending_elim.is_empty():
		_flush_eliminations()


func _on_crossed(id: int, result: int, delta_ms: float) -> void:
	# Tüm jumper'lar (oyuncu + botlar) StumbleJudge'dan geçer.
	if not _players.has(id):
		return
	var j = _players[id].jumper
	var outcome := _judge.resolve(j, result, Config.pardon_rounds(_round))
	match outcome:
		StumbleJudge.Outcome.STUMBLED:
			EventBus.jumper_stumbled.emit(id); _refresh_color(id)
		StumbleJudge.Outcome.PARDONED:
			EventBus.jumper_pardoned.emit(id); _refresh_color(id)
		StumbleJudge.Outcome.ELIMINATED:
			# Ertele: rope.tick döngüsü sürerken pozisyon değiştirme (bkz. _flush_eliminations).
			if not _pending_elim.has(id):
				_pending_elim.append(id)
	# Geri bildirim yazısı (PERFECT/GRAZE/MISS) yalnız oyuncu için
	if id == _player_id:
		_flash = 1.0
		match result:
			Rope.CrossResult.PERFECT:
				_feedback.text = "PERFECT (%d ms)" % int(delta_ms); _feedback.modulate = Color(0.3, 1.0, 0.4)
			Rope.CrossResult.GRAZE:
				_feedback.text = "GRAZE (%d ms)" % int(delta_ms); _feedback.modulate = Color(1.0, 0.9, 0.3)
			Rope.CrossResult.MISS:
				_feedback.text = "MISS"; _feedback.modulate = Color(1.0, 0.35, 0.3)


func _refresh_color(id: int) -> void:
	if not _players.has(id):
		return
	var warned: bool = _players[id].jumper.has_warning
	var base := Color(0.35, 0.6, 0.9) if id == _player_id else Color(0.55, 0.55, 0.58)
	_players[id].mat.albedo_color = Color(1.0, 0.85, 0.2) if warned else base


## Tek jumper'ı kaldır + fırlat (§4.9). Yeniden dizilim YAPMAZ — çağıran toplu reassign eder.
func _eliminate(id: int) -> void:
	if not _alive_ids.has(id):
		return
	_alive_ids.erase(id)
	EventBus.jumper_eliminated.emit(id, 0)
	EventBus.ring_shrunk.emit(_alive_ids.size())
	# Tek gövde impuls (§4.9): kozmetik yön/hız ile fırlat.
	var e = _players[id]
	var viz: Node3D = e.viz
	var dir := Vector3(Rng.cosmetic.randf_range(-1, 1), 1.0, Rng.cosmetic.randf_range(-1, 1)).normalized()
	_flying.append({
		"node": viz, "vel": dir * 7.0 + Vector3.UP * 3.0,
		"angvel": Rng.cosmetic.randf_range(-8, 8), "life": 1.6,
	})
	e.jumper.queue_free()   # öksüz mantık node'unu temizle
	_players.erase(id)


## Bekleyen elemeleri toplu uygula, ardından TEK yeniden dizilim (pozisyonlar tick boyunca sabit kaldı).
func _flush_eliminations() -> void:
	var any := false
	for id in _pending_elim:
		if _alive_ids.has(id):
			_eliminate(id)
			any = true
	_pending_elim.clear()
	if any:
		_reassign()


func _reassign() -> void:
	var n := _alive_ids.size()
	if n == 0:
		return
	var pidx := _alive_ids.find(_player_id)
	_ring_radius = Ring.radius_for(n, _r_min, _r_max)
	var angles := Ring.distribute_angles(n, pidx, PLAYER_ANGLE)
	_suspended = true   # tween boyunca crossing askıda (§4.4 adalet)
	if _reassign_tween != null and _reassign_tween.is_valid():
		_reassign_tween.kill()   # hızlı E'de üst üste binen tween'leri önle
	var tw := create_tween().set_parallel(true)
	_reassign_tween = tw
	for i in n:
		var id = _alive_ids[i]
		_players[id].jumper.angle_pos = angles[i]   # mantık son konuma hemen geçer
		var src = _players[id].jumper.input_source
		if src is BotBrain:
			src.reset_intent()   # konum değişti → bot yeni geçiş için yeniden örnekler
		tw.tween_property(_players[id].viz, "position", Ring.world_pos(angles[i], _ring_radius, 0.0), SHRINK_S)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _suspended = false)


func _process(dt: float) -> void:
	if _clock == null:
		return
	# Zıplama görseli — TÜM jumper'lar (oyuncu + botlar). Her kapsül kendi hız-durumuyla.
	for id in _alive_ids:
		var e = _players[id]
		var pj = e.jumper
		if pj.is_airborne and pj.jump_input_tick != e.last_jump:
			e.last_jump = pj.jump_input_tick
			e.viz_vy = JUMP_V0
			e.viz_y = 0.0
		var g := GRAV_HIGH if pj.is_high() else GRAV_NORMAL
		e.viz_vy -= g * dt
		e.viz_y += e.viz_vy * dt
		if not pj.is_airborne:
			e.viz_y = move_toward(e.viz_y, 0.0, 8.0 * dt)
			e.viz_vy = 0.0
		e.viz_y = maxf(e.viz_y, 0.0)
		e.cap.position.y = 0.7 + e.viz_y
		e.cap.scale.y = 0.6 if pj.is_ducking else 1.0

	# Geri bildirim yazısını soldur
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 1.2)
		_feedback.modulate.a = _flash

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
	_info.text = "SPACE zıpla | S/↓ eğil | E: rakip ele | R: reset\ntur %d   canlı %d   çember r=%.1f   oyuncu: %s" % [_round, _alive_ids.size(), _ring_radius, pstate]


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
	_reassign()   # E crossing dışında (input) → hemen yeniden diz
