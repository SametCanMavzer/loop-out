class_name StumbleJudge extends RefCounted
## Sendeleme + af + eleme durum mantığı (TDD §4.5, §4.9). Saf: autoload'a bağlı değil.
## Bir crossing sonucunu jumper'a uygular, jumper alanlarını (has_warning, pardon_counter,
## is_alive) günceller ve bir Outcome döndürür. Sinyalleri (EventBus §3.2) ve görsel impulsu
## (§4.9) çağıran (F5b/GameState) Outcome'a göre tetikler.
##
## Model A ile uyum: PERFECT/GRAZE = temiz geçiş (havada, kurtuldun); MISS = sendeleme (yerde).

enum Outcome { CLEAN, PARDONED, STUMBLED, ELIMINATED }


## result: Rope.CrossResult. pardon_rounds: bu turun af eşiği (<0 → sudden death, af yok).
func resolve(j: Object, result: int, pardon_rounds: int) -> Outcome:
	if not j.is_alive:
		return Outcome.CLEAN
	if result == Rope.CrossResult.MISS:
		# Sendeleme. Zaten uyarılıysa ya da sudden death'te → eleme; değilse uyarı + af şansı.
		if j.has_warning or pardon_rounds < 0:
			j.is_alive = false
			return Outcome.ELIMINATED
		j.has_warning = true
		j.pardon_counter = 0
		return Outcome.STUMBLED
	# PERFECT / GRAZE = temiz geçiş. Uyarılıysa af sayacını ilerlet; eşikte affet.
	if j.has_warning and pardon_rounds >= 0:
		j.pardon_counter += 1
		if j.pardon_counter >= pardon_rounds:
			j.has_warning = false
			j.pardon_counter = 0
			return Outcome.PARDONED
	return Outcome.CLEAN
