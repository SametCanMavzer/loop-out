class_name ArenaController extends Node3D
## Arena sürücüsü (TDD §7.1 üretim karşılığı; dev harness arena_test'in yerini alır).
## Tüm alt sistemleri bağlar: TickClock + Rope + Jumper'lar + RoundDirector + DramaDirector +
## StumbleJudge + Ring. Autoload köprüsü BURADA (Config→değer, sonuç→EventBus) — alt sistemler
## decoupled kalır. Restart = reset() (sahne reload YOK, §7.1 <2 sn garantisi).
##
## Tur numarası = ipin tamamladığı tam tur sayısı (GDD §3.2 "5 tur temiz geçilirse", §4.2 tablosu).

signal round_advanced(round_no: int)
## İp oyuncu bölgesinden (ekranın önü) geçti → "vuş" metronomu (§8.2). Crossing SONUCU beklenmez:
## ritim bilgisi önden gelir, ses sonuçtan bağımsızdır.
signal rope_swept_front()

const PLAYER_ID := 0
const PLAYER_ANGLE := PI / 2.0         # oyuncu ekranın önünde sabit (§4.4 270° hizası)
const SHRINK_S := 0.6                  # yeniden dizilim tween süresi (§4.4)
const SPECTATE_ALIVE_MAX := 3          # oyuncu elenince ≤3 kalan varsa finali izlet (GDD §5.4)

var clock := TickClock.new()
var rope := Rope.new()
var ring_radius: float = 9.0
var round_no: int = 1
var alive_ids: Array = []              # açısal sıralı canlı id'ler
var perfect_combo: int = 0      # mevcut seri (HUD)
var perfect_total: int = 0      # tur boyunca toplam perfect (jeton ödülü, GDD §6.2)

var _judge := StumbleJudge.new()
var _director := RoundDirector.new()
var _drama := DramaDirector.new()
var _jumpers := {}                     # id -> Jumper
var _archetypes := {}                  # id -> BotArchetype (oyuncu: null)
var _input_queue: InputQueue
var _r_min := 2.2
var _r_max := 9.0
# Yeniden dizilim (§4.4): crossing ASKIYA ALINMAZ — mantıksal açı da görselle birlikte kayar.
# (Askı modeli bir turu "bedava" geçiriyordu: ip askı penceresinde geçen jumper'ı hiç çözmüyordu.)
var _reassign_from := {}               # id -> başlangıç açısı
var _reassign_to := {}                 # id -> hedef açı
var _reassign_left := 0
var _reassign_total := 0
var _radius_from := 9.0
var _radius_to := 9.0
var _pending_elim: Array = []
var _running := false
var _placement: int = 0                # oyuncunun sıralaması (elendiğinde yazılır)
var _seed: int = 0
var _last_player_delta_ms: float = 0.0   # analitik: oyuncunun son geçiş sapması (§13.4)


## Ebeveyn (F8 Main) bağlar. input_queue insan girdisi için; behaviors/archetypes yüklenir.
func setup(input_queue: InputQueue) -> void:
	_input_queue = input_queue
	add_child(clock)
	# ÖNEMLİ: saati YALNIZ step() ilerletir. TickClock'un kendi _physics_process'i açık kalırsa
	# tick her karede İKİ kez artar (biri burada, biri TickClock'ta) → current_tick ip açısından
	# iki kat hızlı gider, botların "ip N tick sonra gelecek" hesabı bozulur ve hepsi erken
	# zıplayıp ıskalar. (F8'den beri gerçek oyundaki tempo/zorluk bozukluğunun asıl sebebi buydu.)
	clock.set_physics_process(false)
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


## Turu KUR ama başlatma (geri sayım ekranı için): kadro dizilir, ip durur, tick ilerlemez.
func prepare_round(master_seed: int) -> void:
	reset()
	Rng.seed_round(master_seed)
	_setup_director()          # director seed'e bağlı → yeniden kur
	rope.reset(0.0, Rope.rpm_to_rad_per_sec(float(Config.rope.get("start_rpm", 25))))
	rope.max_abs_speed = Rope.rpm_to_rad_per_sec(float(Config.rope.get("max_rpm", 60)))
	_spawn_roster()
	_apply_rescue_drama()
	_snap_positions()
	_seed = master_seed


## Kurulan turu başlat (geri sayım bitince). Simülasyon buradan itibaren işler.
func begin() -> void:
	if _running or _jumpers.is_empty():
		return
	_running = true
	clock.start()
	EventBus.round_started.emit(round_no, _seed)


## Kur + hemen başlat (test/sim kolaylığı).
func start_round(master_seed: int) -> void:
	prepare_round(master_seed)
	begin()


## Turu durdur (sonuç ekranına geçince simülasyon arkada sürmesin).
func stop() -> void:
	_running = false
	clock.stop()


## Tüm durumu temizle (restart hazırlığı).
func reset() -> void:
	_running = false
	clock.stop()
	clock.reset()
	round_no = 1
	perfect_combo = 0
	perfect_total = 0
	_placement = 0
	_reassign_left = 0
	_reassign_from.clear()
	_reassign_to.clear()
	_pending_elim.clear()
	if _input_queue != null:
		_input_queue.clear()   # sonuç ekranında basılan tuşlar yeni tura sızmasın
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
	_advance_reassign()

	# Tur ilerlemesi: ip tam tur attıkça (GDD §4.2 zorluk eğrisi + §3.2 af sayacı bununla senkron).
	if rope.turns + 1 != round_no:
		round_no = rope.turns + 1
		for id in alive_ids:
			var src = _jumpers[id].input_source
			if src is BotBrain:
				src.set_round(round_no)
		round_advanced.emit(round_no)

	# Davranış seçimi → telegraf'la kuyruğa (§4.2)
	var beh := _director.tick(t, round_no)
	if beh != null:
		rope.queue_behavior(beh, Config.ms_to_ticks(beh.telegraph_ms))

	for id in alive_ids:
		_jumpers[id].tick(t)

	var targets: Array = []
	for id in alive_ids:
		targets.append(_jumpers[id])
	var prev_angle := rope.angle
	rope.tick(t, Config.perfect_ms(round_no), Config.graze_ms(round_no), targets)
	# Vuş metronomu (§8.2): ip oyuncu bölgesini süpürdü mü? (oyuncu elense de ritim sürer)
	var sweep := absf(rope.angular_vel) * TickClock.TICK_DT
	if sweep > 0.0 and Rope.swept_past(prev_angle, PLAYER_ANGLE, sweep, signi(rope.angular_vel)):
		rope_swept_front.emit()

	if not _pending_elim.is_empty():
		_flush_eliminations()


func _on_crossed(id: int, result: int, delta_ms: float) -> void:
	if not _jumpers.has(id):
		return
	EventBus.rope_crossed.emit(id, result, delta_ms)
	var j: Jumper = _jumpers[id]
	if id == PLAYER_ID:
		_last_player_delta_ms = delta_ms
		if result == Rope.CrossResult.PERFECT:
			perfect_combo += 1
			perfect_total += 1
		else:
			perfect_combo = 0
	var outcome := _judge.resolve(j, result, Config.pardon_rounds(round_no))
	match outcome:
		StumbleJudge.Outcome.STUMBLED:
			EventBus.jumper_stumbled.emit(id)
		StumbleJudge.Outcome.PARDONED:
			EventBus.jumper_pardoned.emit(id)
		StumbleJudge.Outcome.ELIMINATED:
			if not _pending_elim.has(id):
				_pending_elim.append(id)   # rope.tick sürerken pozisyon değiştirme


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
	if id == PLAYER_ID:      # §13.4: yalnız oyuncunun elemesi analitiğe girer
		Analytics.track_elimination(round_no, "miss", rope.current_behavior_id, _last_player_delta_ms)
	EventBus.jumper_eliminated.emit(id, cause)
	EventBus.ring_shrunk.emit(alive_ids.size())
	if id == PLAYER_ID:
		_placement = alive_ids.size() + 1     # kaçıncı bitirdi (1 = kazanan)
		EventBus.player_eliminated.emit(alive_ids.size())


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
		elif _placement <= 0:
			_placement = 1 + alive_ids.size()      # oyuncu son tick'te elendi (kenar durum)
		stop()
		EventBus.round_ended.emit(_placement, 0)   # jeton hesabı F9


func placement() -> int:
	return _placement


func player_alive() -> bool:
	return alive_ids.has(PLAYER_ID)


## Oyuncu elendiğinde izleme modu mu, direkt sonuç mu (GDD §5.4: ≤3 kalan → finali izle).
func should_spectate() -> bool:
	return alive_ids.size() > 0 and alive_ids.size() <= SPECTATE_ALIVE_MAX


## Eleme sonrası yeniden dizilim (§4.4). Açılar ANINDA değil, SHRINK_S boyunca tick tick kayar
## (görsel ArenaView aynı angle_pos'u okuduğu için otomatik senkron). Crossing kesintisiz sürer:
## ip o an kimin üstündeyse onu çözer → "bedava tur" oluşmaz, adalet de korunur.
func _reassign() -> void:
	var n := alive_ids.size()
	if n == 0:
		return
	var pidx := alive_ids.find(PLAYER_ID)
	var angles := Ring.distribute_angles(n, maxi(pidx, 0), PLAYER_ANGLE)
	_reassign_from.clear()
	_reassign_to.clear()
	for i in n:
		var id = alive_ids[i]
		_reassign_from[id] = _jumpers[id].angle_pos
		_reassign_to[id] = angles[i]
	_radius_from = ring_radius
	_radius_to = Ring.radius_for(n, _r_min, _r_max)
	_reassign_total = maxi(Config.ms_to_ticks(SHRINK_S * 1000.0), 1)
	_reassign_left = _reassign_total


## Yeniden dizilim ilerlemesi (her tick). Bitince botlar niyetlerini tazeler.
func _advance_reassign() -> void:
	if _reassign_left <= 0:
		return
	_reassign_left -= 1
	var f := 1.0 - float(_reassign_left) / float(_reassign_total)
	for id in alive_ids:
		if _reassign_to.has(id):
			_jumpers[id].angle_pos = lerp_angle(_reassign_from[id], _reassign_to[id], f)
	ring_radius = lerpf(_radius_from, _radius_to, f)
	if _reassign_left == 0:
		for id in alive_ids:
			var src = _jumpers[id].input_source
			if src is BotBrain:
				src.reset_intent()   # konum oturdu → yeni geçiş için yeniden örnekle


# --- Replay (§4.8): {master_seed, inputs} ile tur birebir yeniden oynatılır ---

## Oyuncunun bu turdaki girdi kaydı ([[tick, action, pressed], ...]).
func input_recording() -> Array:
	var src = _jumpers.get(PLAYER_ID)
	if src == null or not (src.input_source is HumanInput):
		return []
	return (src.input_source as HumanInput).recording()


## Bu turun seed'i (replay dosyasının diğer yarısı).
func seed_used() -> int:
	return _seed


## Turu KAYITTAN oynat: aynı seed + aynı girdi listesi → aynı tur (determinizm sözleşmesi).
## prepare_round'dan SONRA, begin()'den ÖNCE çağrılır.
func use_replay_input(commands: Array) -> void:
	var pj: Jumper = _jumpers.get(PLAYER_ID)
	if pj == null:
		return
	var replay := ReplayInput.new()
	replay.setup(commands)
	pj.setup(replay, Config.jumper_tuning())


func jumper(id: int) -> Jumper:
	return _jumpers.get(id)


func jumper_ids() -> Array:
	return _jumpers.keys()
