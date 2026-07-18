class_name BotBrain extends InputSource
## Bot beyni (TDD §4.6). InputSource arayüzünden geçer (E12): insan/bot/ghost aynı Jumper kodu.
## Karar: ip botun konumuna lookahead kala bir "niyet tick'i" örnekler
## (t_input = t_cross + N(reaction_mean, σ(round)), Rng.bots'tan) ve o tick'te zıplar.
## Autoload'a bağlı DEĞİL: rng stream, arketip, rope ve jumper enjekte edilir.

const TICK_DT := TickClock.TICK_DT
const TPS := TickClock.TICKS_PER_SECOND

var _rng: RandomNumberGenerator
var _arch: BotArchetype
var _rope: Object      # duck-typed: angle, angular_vel
var _jumper: Object    # duck-typed: angle_pos
var _round: int = 1
var _lookahead_ticks: int = 36

var _intent_tick: int = -1
var _handled_cross: int = -1


func setup(rng: RandomNumberGenerator, arch: BotArchetype, rope: Object, jumper: Object,
		round_no: int = 1, lookahead_ms: float = 600.0) -> void:
	_rng = rng
	_arch = arch
	_rope = rope
	_jumper = jumper
	_round = round_no
	_lookahead_ticks = _ms_to_ticks(lookahead_ms)


## Tur ilerledikçe σ büyür (zorluk eğrisi). GameState/arena tur değişiminde çağırır.
func set_round(round_no: int) -> void:
	_round = round_no


## Yeniden dizilim sonrası çağrılır: bot konumu değişti, bayat niyeti iptal et → yeniden örnekler.
func reset_intent() -> void:
	_intent_tick = -1
	_handled_cross = -1


func poll(tick: int) -> Array[InputCommand]:
	var out: Array[InputCommand] = []
	if _rng == null or _arch == null:
		return out
	var ttc := _ticks_to_cross()
	if ttc < 0:
		return out
	var t_cross := tick + ttc
	# Geçiş lookahead içine girdi + bu geçiş için henüz niyet örneklemedik → örnekle.
	if _intent_tick < 0 and ttc <= _lookahead_ticks and absi(t_cross - _handled_cross) > _lookahead_ticks:
		_intent_tick = _sample_intent(t_cross)
		_handled_cross = t_cross
	# Niyet tick'i geldi → kısa zıpla (press+release aynı tick = normal zıplama, hold yok).
	if _intent_tick >= 0 and tick >= _intent_tick:
		out.append(InputCommand.new(tick, &"jump", true))
		out.append(InputCommand.new(tick, &"jump", false))
		_intent_tick = -1
	return out


## İpin botun açısına ulaşmasına kaç tick kaldı (yön/sarma güvenli). -1 = ip durgun.
func _ticks_to_cross() -> int:
	var step := absf(_rope.angular_vel) * TICK_DT
	if step <= 0.0:
		return -1
	var d: float
	if signi(_rope.angular_vel) >= 0:
		d = fposmod(_jumper.angle_pos - _rope.angle, TAU)
	else:
		d = fposmod(_rope.angle - _jumper.angle_pos, TAU)
	return int(ceil(d / step))


func _sample_intent(t_cross: int) -> int:
	var sigma := _arch.reaction_std_base_ms + _arch.std_round_slope * _round
	# Acemi gidiş penceresi: σ yapay şişer (gidiş garanti ama hâlâ zar atılır).
	if _arch.exit_from > 0 and _round >= _arch.exit_from and _round <= _arch.exit_to:
		sigma *= _arch.exit_sigma_mult
	var offset_ms := _rng.randfn(_arch.reaction_mean_ms, maxf(sigma, 1.0))
	return t_cross + _ms_to_ticks(offset_ms)


static func _ms_to_ticks(ms: float) -> int:
	return int(round(ms * TPS / 1000.0))
