class_name RoundDirector extends RefCounted
## Davranış yönetmeni (TDD §4.2). Her seçim aralığında bir ip davranışı seçer:
## ağırlıklı rastgele (Rng.behavior), aktif-davranış tablosu (zorluk tier §4.2), min_round,
## aynı davranış max 2 ardışık. Seçileni caller rope'a telegraf'la kuyruğa alır.
## Autoload'a bağlı DEĞİL: rng, davranış havuzu ve tier'lar enjekte edilir.

var _rng: RandomNumberGenerator
var _pool: Array = []          # RopeBehavior listesi
var _tiers: Array = []         # [{from:int, ids:Array[String]}] — kümülatif aktif set
var _interval: int = 120       # seçim aralığı (tick)
var _max_consec: int = 2
var _next_select: int = 0
var _last_id: StringName = &""
var _consec: int = 0


func setup(rng: RandomNumberGenerator, pool: Array, tiers: Array,
		interval_ticks: int, max_consecutive: int = 2) -> void:
	_rng = rng
	_pool = pool
	_tiers = tiers
	_interval = maxi(interval_ticks, 1)
	_max_consec = maxi(max_consecutive, 1)
	_next_select = _interval


## Her tick çağrılır. Seçim zamanıysa seçilen davranışı döndürür (caller kuyruğa alır), yoksa null.
func tick(current_tick: int, round_no: int) -> RopeBehavior:
	if _rng == null or current_tick < _next_select:
		return null
	_next_select = current_tick + _interval
	return select(round_no)


## Bu tura uygun bir davranış seç (saf mantık; ağırlıklı rastgele + kurallar).
func select(round_no: int) -> RopeBehavior:
	var active := _active_ids(round_no)
	var eligible: Array = []
	for b in _pool:
		if b.min_round <= round_no and active.has(String(b.id)):
			eligible.append(b)
	if eligible.is_empty():
		return null
	# Aynı davranış max 2 ardışık: eşik dolduysa ve başka seçenek varsa son id'yi çıkar.
	var cands := eligible
	if _consec >= _max_consec and eligible.size() > 1:
		cands = eligible.filter(func(b): return b.id != _last_id)
	var pick := _weighted_pick(cands)
	if pick.id == _last_id:
		_consec += 1
	else:
		_last_id = pick.id
		_consec = 1
	return pick


## O tura ait aktif davranış id'leri (en yüksek from <= round_no olan tier, §4.2 kümülatif).
func _active_ids(round_no: int) -> Array:
	var ids: Array = []
	var best := -1
	for tier in _tiers:
		var f := int(tier.get("from", 1))
		if f <= round_no and f > best:
			best = f
			ids = tier.get("ids", [])
	return ids


func _weighted_pick(cands: Array) -> RopeBehavior:
	var total := 0.0
	for b in cands:
		total += b.weight
	var r := _rng.randf() * total
	for b in cands:
		r -= b.weight
		if r <= 0.0:
			return b
	return cands[cands.size() - 1]
