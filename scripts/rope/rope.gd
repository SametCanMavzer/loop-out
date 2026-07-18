class_name Rope extends Node
## İp sistemi — RopeState (TDD §4.2) + fizik motorsuz açısal crossing (§4.3).
## F3a: yalnız Normal mod. Davranış havuzu/telegraf (§4.2 behavior_queue) F7'de eklenir.
##
## Tasarım: Rope saf mantık birimidir — autoload'a (EventBus/Config) bağlı DEĞİL.
## Sonucu lokal `crossed` sinyaliyle yukarı verir; ebeveyn (F5) bunu EventBus.rope_crossed'a
## köprüler (§3.2). Zamanlama pencereleri (perfect/graze ms) dışarıdan gelir; round→pencere
## eşlemesi Config'in işidir (§4.5), çağıran verir. Bu decoupling determinizmi ve testi kolaylaştırır.

signal crossed(jumper_id: int, result: int, delta_ms: float)
signal behavior_telegraphed(behavior_id: StringName)  # telegraf başladı (uyarı)
signal behavior_started(behavior_id: StringName)      # davranış etkiye girdi

enum Height { LOW, HIGH }
enum Mode { NORMAL }                      # F7'de genişler
enum CrossResult { PERFECT, GRAZE, MISS } # `crossed` result kodları → EventBus.rope_crossed (§3.2)

const TICK_DT := TickClock.TICK_DT
const TICK_MS := 1000.0 / TickClock.TICKS_PER_SECOND

# RopeState verisi (§4.2)
var angle: float = 0.0            # radyan [0,TAU)
var angular_vel: float = 0.0     # rad/s; işareti dönüş yönü
var base_angular_vel: float = 0.0  # davranış çarpanları buna uygulanır (dönüş yönü işaret)
var max_abs_speed: float = 0.0     # base hız tavanı (rad/s, 0 = kısıt yok; §5.1 max_rpm)
var height: Height = Height.LOW
var mode: Mode = Mode.NORMAL

# Telegraf/davranış durumu (§4.2)
var telegraph_ticks_left: int = 0
var current_behavior_id: StringName = &"normal"
var _pending: RopeBehavior = null

# Özel davranış alt-durumu (F7c: sudden_stop, fake_slow, double_sweep)
var _effect_ticks_left: int = 0     # zamanlı hız etkisi kalan tick (0 = yok)
var _effect_restore_vel: float = 0.0  # etki bitince dönülecek hız
var _double_active: bool = false    # double_sweep: her süpürme ikinci kez çözülür
var _double_gap: int = 20           # iki süpürme arası tick
var _deferred: Array = []           # {tick:int, target:Object} ikinci süpürme çözümleri


## rpm → rad/s (yön için işaret ayrıca verilir).
static func rpm_to_rad_per_sec(rpm: float) -> float:
	return rpm * TAU / 60.0


func reset(start_angle: float = 0.0, vel: float = 0.0) -> void:
	angle = wrapf(start_angle, 0.0, TAU)
	angular_vel = vel
	base_angular_vel = vel
	height = Height.LOW
	mode = Mode.NORMAL
	telegraph_ticks_left = 0
	current_behavior_id = &"normal"
	_pending = null
	_effect_ticks_left = 0
	_double_active = false
	_deferred.clear()


## Davranış hızlarının uygulanacağı temel hız (yön işaretli). Director tur ile ramplar.
func set_base_speed(vel: float) -> void:
	base_angular_vel = vel


## Davranışı telegraf ile kuyruğa al (§4.2): telegraph_ms önce uyar, sonra etki.
## telegraph_ticks: çağıran Config.ms_to_ticks(telegraph_ms) ile verir (Rope autoload'suz).
func queue_behavior(behavior: RopeBehavior, telegraph_ticks: int) -> void:
	_pending = behavior
	telegraph_ticks_left = maxi(telegraph_ticks, 0)
	behavior_telegraphed.emit(behavior.id)
	if telegraph_ticks_left == 0:
		_activate_pending()


func _activate_pending() -> void:
	if _pending == null:
		return
	var b := _pending
	_pending = null
	current_behavior_id = b.id
	_apply_behavior(b)
	behavior_started.emit(b.id)


## Davranış parametrelerini rope durumuna uygular (§4.2, veri odaklı).
## Kalıcı etkiler base_angular_vel'e işlenir (speed_step tempo, reverse yön); geçici/zamanlı
## etkiler (height, sudden_stop, fake_slow, double_sweep) o davranış süresince.
func _apply_behavior(b: RopeBehavior) -> void:
	var p := b.params
	# Yeni davranış: eski özel alt-durumları temizle.
	_effect_ticks_left = 0
	_double_active = false
	if bool(p.get("reverse", false)):            # yön kalıcı değişir
		base_angular_vel = -base_angular_vel
	if p.has("base_speed_mult"):                 # tempo kalıcı artar (speed_step)
		base_angular_vel *= float(p["base_speed_mult"])
	if max_abs_speed > 0.0 and absf(base_angular_vel) > max_abs_speed:
		base_angular_vel = signf(base_angular_vel) * max_abs_speed  # tavan (§5.1 max_rpm)
	height = Height.HIGH if (p.has("height") and int(p["height"]) == 1) else Height.LOW

	var special := StringName(p.get("special", &""))
	match special:
		&"sudden_stop":   # yarım tur süre durur, sonra base'e döner (§4.1)
			angular_vel = 0.0
			_effect_restore_vel = base_angular_vel
			if not is_zero_approx(base_angular_vel):
				_effect_ticks_left = int(ceil(PI / (absf(base_angular_vel) * TICK_DT)))
		&"fake_slow":     # yavaşlar gibi yapıp aniden hızlanır — telegrafsız (§4.1)
			angular_vel = base_angular_vel * float(p.get("slow_mult", 0.5))
			_effect_restore_vel = base_angular_vel
			_effect_ticks_left = _ms_to_ticks(float(p.get("fake_slow_ms", 600.0)))
		&"double_sweep":  # her süpürme ikinci kez çözülür → tek zıplamayla ikisini örtmek gerek
			_double_active = true
			_double_gap = _ms_to_ticks(float(p.get("double_gap_ms", 333.0)))
			angular_vel = base_angular_vel * float(p.get("speed_mult", 1.0))
		_:
			angular_vel = base_angular_vel * float(p.get("speed_mult", 1.0))


static func _ms_to_ticks(ms: float) -> int:
	return int(round(ms * TickClock.TICKS_PER_SECOND / 1000.0))


## İpin bir tick süpürmesi (§4.3). Süpürülen her canlı jumper için crossing çözülür.
## perfect_ms/graze_ms: bu tura ait pencereler (çağıran Config'ten hesaplar, §4.5).
## targets: angle_pos, is_ducking, is_airborne, jump_input_tick, is_alive, id alanlarına
## sahip nesneler (Jumper — §3.4, F4; testte sahte jumper).
func tick(current_tick: int, perfect_ms: int, graze_ms: int, targets: Array) -> void:
	# Telegraf geri sayımı: 0'a inince bekleyen davranış etkiye girer (§4.2).
	if telegraph_ticks_left > 0:
		telegraph_ticks_left -= 1
		if telegraph_ticks_left == 0:
			_activate_pending()
	# Zamanlı hız etkisi (sudden_stop/fake_slow): süre bitince base'e döner.
	if _effect_ticks_left > 0:
		_effect_ticks_left -= 1
		if _effect_ticks_left == 0:
			angular_vel = _effect_restore_vel
	# Ertelenmiş ikinci süpürmeler (double_sweep) — hareketten bağımsız çözülür.
	_process_deferred(current_tick, perfect_ms, graze_ms)

	var prev := angle
	var step := absf(angular_vel) * TICK_DT
	angle = wrapf(angle + angular_vel * TICK_DT, 0.0, TAU)
	var dir := signi(angular_vel)
	if step <= 0.0:
		return
	for t in targets:
		if not t.is_alive:
			continue
		if swept_past(prev, t.angle_pos, step, dir):
			_resolve_crossing(current_tick, perfect_ms, graze_ms, t)
			if _double_active:   # ikinci süpürmeyi gap tick sonrasına ertele
				_deferred.append({"tick": current_tick + _double_gap, "target": t})


## Vadesi gelen ikinci süpürmeleri (double_sweep) çözer.
func _process_deferred(current_tick: int, perfect_ms: int, graze_ms: int) -> void:
	if _deferred.is_empty():
		return
	var still: Array = []
	for d in _deferred:
		if d.tick <= current_tick:
			if d.target.is_alive:
				_resolve_crossing(current_tick, perfect_ms, graze_ms, d.target)
		else:
			still.append(d)
	_deferred = still


## prev'den `step` radyan `dir` yönünde süpürülürken target açısı yolun içinde mi?
## fposmod ile TAU sarması otomatik; (0, step] aralığı çift-çözümü önler (prev'de duran hedef sayılmaz).
static func swept_past(prev: float, target: float, step: float, dir: int) -> bool:
	var d: float
	if dir >= 0:
		d = fposmod(target - prev, TAU)
	else:
		d = fposmod(prev - target, TAU)
	return d > 0.0 and d <= step


func _resolve_crossing(current_tick: int, perfect_ms: int, graze_ms: int, t: Object) -> void:
	if height == Height.HIGH:
		# Yüksek süpürme (§4.3 / E7): yalnız eğilme temiz geçer; havada da yerde de ıskalama.
		if t.is_ducking:
			return  # nötr temiz geçiş — sinyal yok
		_emit(t.id, CrossResult.MISS, 0.0)
		return
	# Normal (yer hizası) süpürme — Model A: havadaysan en az GRAZE, MISS yalnız yerdeysen.
	# İyi zamanlama (delta<=perfect) → PERFECT. Sudden death'te (graze_ms<=perfect_ms, §4.5
	# graze bandı yok) perfect değilsen ıskalarsın.
	if not t.is_airborne:
		_emit(t.id, CrossResult.MISS, 0.0)
		return
	var delta_ms := absf(current_tick - t.jump_input_tick) * TICK_MS
	if delta_ms <= float(perfect_ms):
		_emit(t.id, CrossResult.PERFECT, delta_ms)
	elif graze_ms > perfect_ms:
		_emit(t.id, CrossResult.GRAZE, delta_ms)
	else:
		_emit(t.id, CrossResult.MISS, delta_ms)


func _emit(id: int, result: CrossResult, delta_ms: float) -> void:
	crossed.emit(id, result, delta_ms)
