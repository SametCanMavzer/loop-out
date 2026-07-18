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
var _player: Object = null      # Kopyacı için: duck-typed jump_input_tick, is_airborne
var _copy_delay_ticks: int = 12  # Kopyacı: oyuncu + bu gecikme
var _forced_sigma_mult: float = 1.0  # dinamik dram müdahalesi (§4.7): σ zorla şişir/kıs
var _duck_release_at: int = -1       # yüksek süpürme: eğilmeyi bu tick'te bırak
const _DUCK_HOLD_TICKS := 16         # eğilmeyi geçiş penceresini örtecek kadar tut

var _intent_tick: int = -1
var _handled_cross: int = -1


func setup(rng: RandomNumberGenerator, arch: BotArchetype, rope: Object, jumper: Object,
		round_no: int = 1, lookahead_ms: float = 600.0,
		player: Object = null, copy_delay_ms: float = 200.0) -> void:
	_rng = rng
	_arch = arch
	_rope = rope
	_jumper = jumper
	_round = round_no
	_lookahead_ticks = _ms_to_ticks(lookahead_ms)
	_player = player
	_copy_delay_ticks = _ms_to_ticks(copy_delay_ms)


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
		_intent_tick = _sample_intent(t_cross, tick)
		_handled_cross = t_cross
	# Bekleyen eğilme bırakma (yüksek süpürme sonrası ayağa kalk).
	if _duck_release_at >= 0 and tick >= _duck_release_at:
		out.append(InputCommand.new(tick, &"duck", false))
		_duck_release_at = -1
	# Niyet tick'i geldi → ip YÜKSEK ise eğil (tut+geç bırak), değilse kısa zıpla.
	if _intent_tick >= 0 and tick >= _intent_tick:
		if int(_rope.height) == int(Rope.Height.HIGH):
			out.append(InputCommand.new(tick, &"duck", true))
			_duck_release_at = tick + _DUCK_HOLD_TICKS   # geçişi örtecek kadar tut
		else:
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


## Dinamik dram müdahalesi (§4.7): σ çarpanını değiştirir (kurtarma: şişir; final koruma: kıs).
func set_sigma_override(mult: float) -> void:
	_forced_sigma_mult = maxf(mult, 0.01)


func archetype_id() -> StringName:
	return _arch.id if _arch != null else &""


func base_sigma() -> float:
	return _arch.reaction_std_base_ms if _arch != null else 0.0


## σ(round) — zorluk eğrisi + Acemi gidiş penceresi şişmesi + dram override.
func _sigma_ms() -> float:
	var s := _arch.reaction_std_base_ms + _arch.std_round_slope * _round
	if _arch.exit_from > 0 and _round >= _arch.exit_from and _round <= _arch.exit_to:
		s *= _arch.exit_sigma_mult
	return s * _forced_sigma_mult


func _default_sample(t_cross: int, sigma_scale: float = 1.0) -> int:
	var offset_ms := _rng.randfn(_arch.reaction_mean_ms, maxf(_sigma_ms() * sigma_scale, 1.0))
	return t_cross + _ms_to_ticks(offset_ms)


## Niyet tick'i (§4.6). Quirk'e göre dallanır: NONE/Acemi/Panikçi/Sağlam düz örnekler;
## Şovcu (SHOWOFF) %30 takla → σ×2; Kopyacı (COPYCAT) oyuncunun zıplamasını +gecikme ile kopyalar.
func _sample_intent(t_cross: int, current_tick: int) -> int:
	match _arch.quirk:
		1:  # SHOWOFF
			var scale := 2.0 if _rng.randf() < 0.30 else 1.0
			return _default_sample(t_cross, scale)
		2:  # COPYCAT
			if _player != null and _player.jump_input_tick >= 0 \
					and (current_tick - _player.jump_input_tick) <= _lookahead_ticks:
				return _player.jump_input_tick + _copy_delay_ticks
			return _default_sample(t_cross)  # oyuncu zıplamadı → kendi (kötü) örneklemi
		_:
			return _default_sample(t_cross)


static func _ms_to_ticks(ms: float) -> int:
	return int(round(ms * TPS / 1000.0))
