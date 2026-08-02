class_name ArenaView extends Node3D
## Arena görsel katmanı. ArenaController'ın (mantık) durumunu okur ve çizer — mantığa
## müdahale etmez, determinizmi etkilemez (§4.1: görsel _process'te, mantık tick'te).
##
## Oyuncular kapsül değil INSAN FİGÜRÜ (kafa/saç/gövde/kol/bacak) ve her biri farklı görünür
## (boy, en, ten, saç modeli, saç ve forma rengi — hepsi id'den, RNG'siz). Çizimi
## FigureRenderer yapar; burada yalnız her figürün konumu, yönü, pozu ve durumu hesaplanır.

const JUMP_V0 := 6.0
const GRAV_NORMAL := 28.0
const GRAV_HIGH := 14.0
const ELIM_LIFE := 1.6
const CAPACITY := 20              # 16 canlı + savrulan gövdeler için pay

const C_WARN := Color(1.0, 0.85, 0.2)

@onready var controller: ArenaController = $ArenaController
@onready var _rope_viz: RopeVisual = $RopeSpinner
@onready var _camera_rig: CameraRig = $CameraRig

var _figures := {}      # id -> {viz_y, viz_vy, last_jump, pos, yaw, crouch, tuck, swing}
var _flying: Array = []
var _r_max := 9.0
var _renderer: FigureRenderer
var _player_shirt := Color(0.35, 0.6, 0.9)
var _marker: MeshInstance3D      # oyuncunun ayağının altındaki halka


func _ready() -> void:
	_r_max = float(Config.ring.get("r_max", 9.0))
	_rope_viz.bind(controller.rope)
	_rope_viz.set_radius(_r_max)      # ip gerçek yarıçapa göre kurulur (ölçek YOK: kesiti bozardı)
	_renderer = FigureRenderer.new()
	_renderer.name = "Figures"
	add_child(_renderer)
	_renderer.setup(CAPACITY)
	_player_shirt = _load_player_shirt()
	_build_player_marker()
	EventBus.jumper_eliminated.connect(_on_eliminated)
	# ⚠ rengi için sinyal dinlemeye gerek yok — durum her karede jumper'dan okunuyor.
	# Oyuncu elenince kamera darbesi (GDD §2.2) — slow-motion'la aynı anda oynar.
	EventBus.player_eliminated.connect(func(_alive: int) -> void: _camera_rig.punch_zoom())


## Tur başında (controller.start_round sonrası) görsel temsilleri kur.
func rebuild() -> void:
	_figures.clear()
	_flying.clear()
	for id in controller.jumper_ids():
		_figures[id] = {
			"viz_y": 0.0, "viz_vy": 0.0, "last_jump": -999,
			"pos": Vector3.ZERO, "yaw": 0.0, "crouch": 0.0, "tuck": 0.0, "swing": 0.0,
		}
	_sync_positions(true)


## Çemberde `angle_pos` konumundaki figürün, ORTAYA bakması için gereken yaw açısı.
##
## Türetme (kafadan atılırsa yanlış çıkıyor — nitekim çıktı): Ring.world_pos konumu
## (cos a, −sin a) veriyor; merkeze bakan yön −P = (−cos a, +sin a). Godot'ta rotation.y = θ
## olan bir node'un yerel +Z'si dünyada (sin θ, cos θ)'ya gider. İkisini eşitleyince
## sin θ = −cos a ve cos θ = sin a çıkar, yani θ = a − π/2.
##
## İlk yazılışı `π/2 − a` idi — bunun X bileşeni ters işaretli, yani şekil AYNALANMIŞ olur:
## figürler a = ±π/2'de doğru, a = 0 ve π'de tam TERS (sırtı ipe dönük) duruyordu.
static func face_center_yaw(angle_pos: float) -> float:
	return angle_pos - PI * 0.5


## Oyuncunun forması kuşanılan karakterden gelir (GDD §6.3 — yalnız kozmetik).
## Her karede load() çağırmamak için önbelleğe alınır; karakter değişince tazelenir.
func _load_player_shirt() -> Color:
	var ch := load("res://data/characters/%s.tres" % SaveGame.equipped())
	return (ch as CharacterData).color if ch is CharacterData else Color(0.35, 0.6, 0.9)


## Karakter değişince oyuncunun görünümünü tazele (ekrandan çıkmadan görünsün).
func apply_player_skin() -> void:
	_player_shirt = _load_player_shirt()


## Oyuncunun ayağının altında parlak halka. Kadro artık renkli olduğu için "hangisi benim"
## sorusunu renk çözemiyor (Samet: "ayırt edemiyorum") — bu halka her koşulda çözer.
## Işıktan etkilenmesin diye unshaded, hep görünür.
func _build_player_marker() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.40
	ring.outer_radius = 0.52
	ring.rings = 6
	ring.ring_segments = 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 1.0, 0.95)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker = MeshInstance3D.new()
	_marker.name = "PlayerMarker"
	_marker.mesh = ring
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func _style(id: int) -> Dictionary:
	return _renderer.style_of(id, _player_shirt, id == ArenaController.PLAYER_ID)


func _on_eliminated(id: int, _cause: int) -> void:
	if not _figures.has(id):
		return
	var v = _figures[id]
	# Tek gövde impuls (§4.9) — kozmetik stream, gameplay'i etkilemez.
	var dir := Vector3(Rng.cosmetic.randf_range(-1, 1), 1.0, Rng.cosmetic.randf_range(-1, 1)).normalized()
	_flying.append({
		"pos": v.pos + Vector3(0.0, v.viz_y, 0.0),
		"vel": dir * 7.0 + Vector3.UP * 3.0,
		"spin": Vector3(Rng.cosmetic.randf_range(-6, 6), Rng.cosmetic.randf_range(-4, 4),
			Rng.cosmetic.randf_range(-8, 8)),
		"basis": Basis(Vector3.UP, v.yaw),
		"life": ELIM_LIFE, "style": _style(id),
	})
	_figures.erase(id)


func _process(dt: float) -> void:
	_rope_viz.on_logic_step()
	_sync_positions(false, dt)
	_update_flying(dt)
	_draw_figures()


## Canlı jumper'ları çemberdeki yerine (yumuşak) taşı + zıplama/eğilme pozunu işle.
func _sync_positions(snap: bool, dt: float = 0.0) -> void:
	var r := controller.ring_radius
	for id in controller.alive_ids:
		if not _figures.has(id):
			continue
		var v = _figures[id]
		var j := controller.jumper(id)
		if j == null:
			continue
		var target := Ring.world_pos(j.angle_pos, r, 0.0)
		if snap:
			v.pos = target
		else:
			v.pos = (v.pos as Vector3).lerp(target, clampf(dt * 4.0, 0.0, 1.0))
		# Figürler çemberin ortasına bakar (kapsülün yönü yoktu; insanda gerekli).
		v.yaw = face_center_yaw(j.angle_pos)
		if dt > 0.0:
			_animate(v, j, dt)


func _animate(v: Dictionary, j: Jumper, dt: float) -> void:
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
	# Poz geçişleri yumuşasın (anlık poz zıplaması çirkin duruyor).
	var k := clampf(dt * 14.0, 0.0, 1.0)
	v.crouch = lerpf(v.crouch, 1.0 if j.is_ducking else 0.0, k)
	v.tuck = lerpf(v.tuck, 1.0 if j.is_airborne else 0.0, k)
	# Yerdeyken hafif kol salınımı — 16 kişi heykel gibi durmasın. Faz kişiye göre kayık.
	v.swing = sin(float(controller.clock.current_tick) * 0.09 + v.yaw * 2.0) * 0.12 * (1.0 - v.tuck)


func _update_flying(dt: float) -> void:
	var still: Array = []
	for f in _flying:
		f.vel += Vector3.DOWN * 18.0 * dt
		f.pos += f.vel * dt
		f.basis = (f.basis as Basis).rotated(Vector3.RIGHT, f.spin.x * dt) \
			.rotated(Vector3.UP, f.spin.y * dt).rotated(Vector3.FORWARD, f.spin.z * dt)
		f.life -= dt
		if f.life > 0.0:
			still.append(f)
	_flying = still


## Tüm figürleri (canlılar + savrulanlar) MultiMesh'lere yaz.
func _draw_figures() -> void:
	if _renderer == null:
		return
	_renderer.begin_frame()
	for id in controller.alive_ids:
		if not _figures.has(id):
			continue
		var v = _figures[id]
		var j := controller.jumper(id)
		var warn: float = 1.0 if (j != null and j.has_warning) else 0.0
		var root := Transform3D(Basis(Vector3.UP, v.yaw), v.pos + Vector3(0.0, v.viz_y, 0.0))
		_renderer.draw_figure(root, _style(id),
			{"crouch": v.crouch, "tuck": v.tuck, "swing": v.swing}, C_WARN, warn * 0.8)
	for f in _flying:
		# Savrulan gövde: tek parça gibi takla atar (§4.9), bacaklar toplu.
		_renderer.draw_figure(Transform3D(f.basis, f.pos), f.style,
			{"crouch": 0.35, "tuck": 0.8, "swing": 0.0})
	_renderer.end_frame()
	_update_marker()


## Halka oyuncunun ayağında durur (zıplayınca yerde kalır — gölge gibi okunur), nabız atar.
func _update_marker() -> void:
	var pv = _figures.get(ArenaController.PLAYER_ID)
	if pv == null or not controller.alive_ids.has(ArenaController.PLAYER_ID):
		_marker.visible = false
		return
	_marker.visible = true
	_marker.position = (pv.pos as Vector3) + Vector3(0.0, 0.06, 0.0)
	var pulse := 1.0 + 0.10 * sin(float(controller.clock.current_tick) * 0.16)
	_marker.scale = Vector3(pulse, 1.0, pulse)
