class_name RewardCalculator extends RefCounted
## Jeton hesabı (GDD §6.2). Saf: değerler config'ten enjekte edilir, autoload'a bağlı değil.
##   sıralama: 1. → win · top3 → 25 · top8 → 10 · diğer → 5
##   perfect başına +1 · günlük ilk galibiyet ×3 · ödüllü reklam ×2 (F12'de tetiklenir)

var _win := 50
var _top3 := 25
var _top8 := 10
var _other := 5
var _perfect_bonus := 1
var _daily_mult := 3
var _ad_mult := 2


func setup(economy: Dictionary) -> void:
	_win = int(economy.get("win", 50))
	_top3 = int(economy.get("top3", 25))
	_top8 = int(economy.get("top8", 10))
	_other = int(economy.get("other", 5))
	_perfect_bonus = int(economy.get("perfect_bonus", 1))
	_daily_mult = int(economy.get("daily_first_win_mult", 3))
	_ad_mult = int(economy.get("ad_mult", 2))


## Sıralama ödülü (perfect bonusu hariç).
func placement_reward(placement: int) -> int:
	if placement <= 1:
		return _win
	elif placement <= 3:
		return _top3
	elif placement <= 8:
		return _top8
	return _other


## Tur toplamı. daily_first_win yalnız 1. sırada anlamlıdır (GDD §6.4).
func total(placement: int, perfect_count: int, daily_first_win: bool = false) -> int:
	var base := placement_reward(placement) + perfect_count * _perfect_bonus
	if daily_first_win and placement <= 1:
		base *= _daily_mult
	return base


## Ödüllü reklam çarpanı (F12: Ads.rewarded başarılıysa uygulanır).
func with_ad(amount: int) -> int:
	return amount * _ad_mult
