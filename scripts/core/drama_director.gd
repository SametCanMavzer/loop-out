class_name DramaDirector extends RefCounted
## Dinamik dram (TDD §4.7). Deterministik kural müdahaleleri — RoundDirector ile birlikte.
## Saf/decoupled: bot bilgileri {id, sigma, ref} dict listesi olarak verilir; kararı döndürür,
## caller uygular (ref.set_sigma_override). Müdahale de seed'e girdi (streak) — determinizm korunur.

var _streak_threshold: int = 2   # config.drama.streak_len


func setup(streak_threshold: int = 2) -> void:
	_streak_threshold = maxi(streak_threshold, 1)


## Erken-eleme kurtarma (§4.7): oyuncu son turlarda erken elendiyse (streak≥eşik) ve tur 1-3 ise,
## canlı Acemi botlardan birini seç (σ'sı zorla şişirilecek → ilk elenen o olur). rng deterministik.
## bots: [{id:StringName, sigma:float, ref:Object}]. Döner: seçilen dict ya da {} (müdahale yok).
func pick_rescue_target(bots: Array, round_no: int, streak: int, rng: RandomNumberGenerator) -> Dictionary:
	if streak < _streak_threshold or round_no > 3 or rng == null:
		return {}
	var acemi := bots.filter(func(b): return StringName(b.id) == &"acemi")
	if acemi.is_empty():
		return {}
	return acemi[rng.randi() % acemi.size()]


## Final 1v1 adayı (§4.7): kalanlardan Sağlam arketipe öncelik; yoksa en düşük base σ'lı bot terfi.
func pick_final_candidate(bots: Array) -> Dictionary:
	if bots.is_empty():
		return {}
	var saglam := bots.filter(func(b): return StringName(b.id) == &"saglam")
	var pool: Array = saglam if not saglam.is_empty() else bots
	var best: Dictionary = pool[0]
	for b in pool:
		if float(b.sigma) < float(best.sigma):
			best = b
	return best
