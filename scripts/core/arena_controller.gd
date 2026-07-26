class_name ArenaController extends Node3D
## Arena sürücüsü (TDD §7.1 üretim karşılığı; dev harness arena_test'in yerini alır).
## Tüm alt sistemleri bağlar: TickClock + Rope + Jumper'lar + RoundDirector + DramaDirector +
## StumbleJudge + Ring. Autoload köprüsü BURADA (Config→değer, sonuç→EventBus) — alt sistemler
## decoupled kalır. Restart = reset() (sahne reload YOK, §7.1 <2 sn garantisi).
##
## Tur numarası = ipin tamamladığı tam tur sayısı (GDD §3.2 "5 tur temiz geçilirse", §4.2 tablosu).

signal round_advanced(round_no: int)
signal player_state_changed()          # HUD tazeleme (⚠, combo, canlı sayısı)

const PLAYER_ID := 0
const PLAYER_ANGLE := PI / 2.0         # oyuncu ekranın önünde sabit (§4.4 270° hizası)
const SHRINK_S := 0.6                  # yeniden dizilim tween süresi (§4.4)
const SPECTATE_ALIVE_MAX := 3          # oyuncu elenince ≤3 kalan varsa finali izlet (GDD §5.4)

var clock := TickClock.new()
var rope := Rope.new()
var ring_radius: float = 9.0
var round_no: int = 1
var alive_ids: Array = []              # açısal sıralı canlı id'ler
var perfect_combo: int = 0

var _judge := StumbleJudge.new()
var _director := RoundDirector.new()
var _drama := DramaDirector.new()
var _jumpers := {}                     # id -> Jumper
var _archetypes := {}                  # id -> BotArchetype (oyuncu: null)
var _input_queue: InputQueue
var _r_min := 2.2
var _r_max := 9.0
var _suspend_ticks := 0                # yeniden dizilim sırasında crossing askıda (§4.4), TICK tabanlı
var _pending_elim: Array = []
var _running := false
var _placement: int = 0                # oyuncunun sıralaması (elendiğinde yazılır)


## Ebeveyn (F8 Main) bağlar. input_queue insan girdisi için; behaviors/archetypes yüklenir.
func setup(input_queue: InputQueue) -> void:
	_input_queue = input_queue
	add_child(clock)
	add_child(rope)
	_r_min = float(Config.ring.get("r_min", 2.2))
	_r_max = float(Config.ring.get("r_max", 9.0))
	rope.max_abs_speed = Rope.rpm_to_rad_per_sec(float(Config.rope.get("max_rpm", 60)))
	rope.crossed.connect(_on_crossed)
	rope.behavior_telegraphed.connect(_on_telegraphed)
	rope.behavior_started.connect(_on_behavior_started)
	_drama.setup(int(Config.drama.get("streak_len", 2)))
	_setup_director()


func _setup_director() -> void:
	var pool: Array = []
	for bid in ["normal", "speed_step", "sudden_stop", "reverse", "high_sweep", "double_sweep", "fake_slow"]:
		var b := load("res://data/behaviors/%s.tres" % bid)
		if b != null:
			pool.append(b)
	var tiers: Array = []
	for tier in Config.difficulty_rounds:
		tiers.append({"from": int(tier.get("from", 1)), "ids": tier.get("behaviors", [])})
	_director.setup(Rng.behavior, pool, tiers,
		Config.ms_to_ticks(Config.behavior_select_interval_ms), Config.behavior_max_consecutive)


## Yeni tur başlat (restart dahil): tam state reset, sahne yüklenmez (§7.1).
func start_round(master_seed: int) -> void:
	reset()
	Rng.seed_round(master_seed)
	_setup_director()          # director seed'e bağlı → yeniden kur
	rope.reset(0.0, Rope.rpm_to_rad_per_sec(float(Config.rope.get("start_rpm", 25))))
	rope.max_abs_speed = Rope.rpm_to_rad_per_sec(float(Config.rope.get("max_rpm", 60)))
	_spawn_roster()
	_apply_rescue_drama()
	_snap_positions()
	_running = true
	clock.start()
	EventBus.round_started.emit(round_no, master_seed)


## Tüm durumu temizle (restart hazırlığı).
func reset() -> void:
	_running = false
	clock.stop()
	clock.reset()
	round_no = 1
	perfect_combo = 0
	_placement = 0
	_suspend_ticks = 0
	_pending_elim.clear()
	for id in _jumpers.keys():
		var j: Jumper = _jumpers[id]
		if is_instance_valid(j):
			j.queue_free()
	_jumpers.clear()
	_archetypes.clear()
	alive_ids.clear()


## 16 kişilik kadro: 1 oyuncu + Config.bots.archetype_counts kadar bot (GDD §5.1).
func _spawn_roster() -> void:
	var counts: Dictionary = Config.bots.get("archetype_counts", {})
	var bot_archs: Array = []
	for arch_id in ["acemi", "panikci", "saglam", "sovcu", "kopyaci"]:
		var arch := load("res://data/archetypes/%s.tres" % arch_id)
		for i in int(counts.get(arch_id, 0)):
			bot_archs.append(arch)
	# Karışık dağıtım (§5.1) — Rng.bots ile deterministik.
	for i in range(bot_archs.size() - 1, 0, -1):
		var j := Rng.bots.randi() % (i + 1)
		var tmp = bot_archs[i]; bot_archs[i] = bot_archs[j]; bot_archs[j] = tmp

	_create_jumper(PLAYER_ID, null)
	for i in bot_archs.size():
		_create_jumper(i + 1, bot_archs[i])
	alive_ids = _jumpers.keys()
	alive_ids.sort()


func _create_jumper(id: int, arch: BotArchetype) -> void:
	var j := Jumper.new()
	j.name = "Jumper%d" % id
	j.id = id
	add_child(j)
	_archetypes[id] = arch
	if arch == null:
		j.setup(HumanInput.new(_input_queue), Config.jumper_tuning())
	else:
		var brain := BotBrain.new()
		var player: Object = _jumpers.get(PLAYER_ID)      # Kopyacı için oyuncu referansı
		brain.setup(Rng.bots, arch, rope, j, round_no,
			float(Config.bots.get("lookahead_ms", 600)), player, 200.0)
		j.setup(brain, Config.jumper_tuning())
	_jumpers[id] = j


## Erken-eleme kurtarma (§4.7): oyuncu son turlarda erken elendiyse bir Acemi'nin σ'sı şişer.
func _apply_rescue_drama() -> void:
	var streak := int(SaveGame.data.get("early_exit_streak", 0))
	var infos := _bot_infos()
	var target := _drama.pick_rescue_target(infos, round_no, streak, Rng.bots)
	if not target.is_empty():
		target.ref.set_sigma_override(3.0)


func _bot_infos() -> Array:
	var out: Array = []
	for id in alive_ids:
		if id == PLAYER_ID:
			continue
		var br = _jumpers[id].input_source
		if br is BotBrain:
			out.append({"id": br.archetype_id(), "sigma": br.base_sigma(), "ref": br})
	return out


func _snap_positions() -> void:
	var n := alive_ids.size()
	var pidx := alive_ids.find(PLAYER_ID)
	ring_radius = Ring.radius_for(n, _r_min, _r_max)
	var angles := Ring.distribute_angles(n, maxi(pidx, 0), PLAYER_ANGLE)
	for i in n:
		_jumpers[alive_ids[i]].angle_pos = angles[i]


func _physics_process(_dt: float) -> void:
	step()


## Bir simülasyon adımı. Normalde _physics_process çağırır; headless balans simülasyonu (F11)
## bunu doğrudan çağırarak hızlı koşar — determinizm aynı (tick sayısı özdeş).
func step() -> void:
	if not _running:
		return
	clock.advance()
	var t := clock.current_tick
	if _suspend_ticks > 0:
		_suspend_ticks -= 1
	var suspended := _suspend_ticks > 0

	# Tur ilerlemesi: ip tam tur attıkça (GDD §4.2 zorluk eğrisi + §3.2 af sayacı bununla senkron).
	if rope.turns + 1 != round_no:
		round_no = rope.turns + 1
		for id in alive_ids:
			var src = _jumpers[id].input_source
			if src is BotBrain:
				src.set_round(round_no)
		round_advanced.emit(round_no)

	# Davranış seçimi → telegraf'la kuyruğa (§4.2)
	if not suspended:
		var beh := _director.tick(t, round_no)
		if beh != null:
			rope.queue_behavior(beh, Config.ms_to_ticks(beh.telegraph_ms))

	for id in alive_ids:
		_jumpers[id].tick(t)

	var targets: Array = []
	if not suspended:                        # ip her zaman döner, yalnız crossing askıda (§4.4)
		for id in alive_ids:
			targets.append(_jumpers[id])
	rope.tick(t, Config.perfect_ms(round_no), Config.graze_ms(round_no), targets)

	if not _pending_elim.is_empty():
		_flush_eliminations()


func _on_crossed(id: int, result: int, delta_ms: float) -> void:
	if not _jumpers.has(id):
		return
	EventBus.rope_crossed.emit(id, result, delta_ms)
	var j: Jumper = _jumpers[id]
	if id == PLAYER_ID:
		perfect_combo = perfect_combo + 1 if result == Rope.CrossResult.PERFECT else 0
	var outcome := _judge.resolve(j, result, Config.pardon_rounds(round_no))
	match outcome:
		StumbleJudge.Outcome.STUMBLED:
			EventBus.jumper_stumbled.emit(id)
		StumbleJudge.Outcome.PARDONED:
			EventBus.jumper_pardoned.emit(id)
		StumbleJudge.Outcome.ELIMINATED:
			if not _pending_elim.has(id):
				_pending_elim.append(id)   # rope.tick sürerken pozisyon değiştirme
	if id == PLAYER_ID:
		player_state_changed.emit()


func _on_telegraphed(id: StringName) -> void:
	EventBus.behavior_telegraphed.emit(id)
	for pid in alive_ids:                    # Panikçi tepkisi (§4.6); sıra sabit → deterministik
		var br = _jumpers[pid].input_source
		if br is BotBrain:
			br.on_telegraph()


func _on_behavior_started(id: StringName) -> void:
	EventBus.behavior_started.emit(id)
	for pid in alive_ids:                    # hız/yön değişti → bayat niyetleri sıfırla (adalet)
		var br = _jumpers[pid].input_source
		if br is BotBrain:
			br.reset_intent()


func _flush_eliminations() -> void:
	var any := false
	for id in _pending_elim:
		if alive_ids.has(id):
			_eliminate(id)
			any = true
	_pending_elim.clear()
	if any:
		_reassign()
		_protect_finalist()
		_check_end()


func _eliminate(id: int) -> void:
	alive_ids.erase(id)
	var cause := 0
	EventBus.jumper_eliminated.emit(id, cause)
	EventBus.ring_shrunk.emit(alive_ids.size())
	if id == PLAYER_ID:
		_placement = alive_ids.size() + 1     # kaçıncı bitirdi (1 = kazanan)
		EventBus.player_eliminated.emit(alive_ids.size())
		player_state_changed.emit()


## Final 1v1 adayı korunur (§4.7): son botlar arasından Sağlam/en tutarlı olan σ'sını sıkar.
func _protect_finalist() -> void:
	var infos := _bot_infos()
	if infos.size() > 0 and infos.size() <= 2:
		var cand := _drama.pick_final_candidate(infos)
		if not cand.is_empty():
			cand.ref.set_sigma_override(0.5)


## Tur bitti mi? Tek kişi kaldıysa sonuç. Oyuncu elendiyse izleme/sonuç kararı (GDD §5.4).
func _check_end() -> void:
	if alive_ids.size() <= 1:
		if alive_ids.has(PLAYER_ID):
			_placement = 1
		_running = false
		clock.stop()
		EventBus.round_ended.emit(_placement, 0)   # jeton hesabı F9


func placement() -> int:
	return _placement


func player_alive() -> bool:
	return alive_ids.has(PLAYER_ID)


## Oyuncu elendiğinde izleme modu mu, direkt sonuç mu (GDD §5.4: ≤3 kalan → finali izle).
func should_spectate() -> bool:
	return alive_ids.size() > 0 and alive_ids.size() <= SPECTATE_ALIVE_MAX


func _reassign() -> void:
	var n := alive_ids.size()
	if n == 0:
		return
	var pidx := alive_ids.find(PLAYER_ID)
	ring_radius = Ring.radius_for(n, _r_min, _r_max)
	var angles := Ring.distribute_angles(n, maxi(pidx, 0), PLAYER_ANGLE)
	# Askı TICK tabanlı (§4.8: gameplay'de gerçek-zaman timer/tween YASAK — determinizm).
	# Görsel geçiş ArenaView'da; burada yalnız crossing adaleti için askı süresi.
	_suspend_ticks = Config.ms_to_ticks(SHRINK_S * 1000.0)
	for i in n:
		var id = alive_ids[i]
		_jumpers[id].angle_pos = angles[i]
		var src = _jumpers[id].input_source
		if src is BotBrain:
			src.reset_intent()


func jumper(id: int) -> Jumper:
	return _jumpers.get(id)


func jumper_ids() -> Array:
	return _jumpers.keys()
