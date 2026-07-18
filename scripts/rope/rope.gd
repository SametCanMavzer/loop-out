class_name Rope extends Node
## İp sistemi — RopeState (TDD §4.2) + fizik motorsuz açısal crossing (§4.3).
## F3a: yalnız Normal mod. Davranış havuzu/telegraf (§4.2 behavior_queue) F7'de eklenir.
##
## Tasarım: Rope saf mantık birimidir — autoload'a (EventBus/Config) bağlı DEĞİL.
## Sonucu lokal `crossed` sinyaliyle yukarı verir; ebeveyn (F5) bunu EventBus.rope_crossed'a
## köprüler (§3.2). Zamanlama pencereleri (perfect/graze ms) dışarıdan gelir; round→pencere
## eşlemesi Config'in işidir (§4.5), çağıran verir. Bu decoupling determinizmi ve testi kolaylaştırır.

signal crossed(jumper_id: int, result: int, delta_ms: float)

enum Height { LOW, HIGH }
enum Mode { NORMAL }                      # F7'de genişler
enum CrossResult { PERFECT, GRAZE, MISS } # `crossed` result kodları → EventBus.rope_crossed (§3.2)

const TICK_DT := TickClock.TICK_DT
const TICK_MS := 1000.0 / TickClock.TICKS_PER_SECOND

# RopeState verisi (§4.2)
var angle: float = 0.0            # radyan [0,TAU)
var angular_vel: float = 0.0     # rad/s; işareti dönüş yönü
var height: Height = Height.LOW
var mode: Mode = Mode.NORMAL


## rpm → rad/s (yön için işaret ayrıca verilir).
static func rpm_to_rad_per_sec(rpm: float) -> float:
	return rpm * TAU / 60.0


func reset(start_angle: float = 0.0, vel: float = 0.0) -> void:
	angle = wrapf(start_angle, 0.0, TAU)
	angular_vel = vel
	height = Height.LOW
	mode = Mode.NORMAL


## İpin bir tick süpürmesi (§4.3). Süpürülen her canlı jumper için crossing çözülür.
## perfect_ms/graze_ms: bu tura ait pencereler (çağıran Config'ten hesaplar, §4.5).
## targets: angle_pos, is_ducking, is_airborne, jump_input_tick, is_alive, id alanlarına
## sahip nesneler (Jumper — §3.4, F4; testte sahte jumper).
func tick(current_tick: int, perfect_ms: int, graze_ms: int, targets: Array) -> void:
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
