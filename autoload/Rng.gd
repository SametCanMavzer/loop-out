extends Node
## Seed yönetimi + 3 bağımsız RNG stream (TDD §4.8).
## Gameplay'de BAŞKA rastgelelik kaynağı yok (global randf() yasak, Karar #3).

var behavior := RandomNumberGenerator.new()
var bots := RandomNumberGenerator.new()
var cosmetic := RandomNumberGenerator.new()

var master_seed: int = 0


## Tur başlangıcı: master_seed → üç stream'e türetilmiş seed'ler.
## behavior/bots senkron gerektirir; cosmetic gameplay'i etkilemez.
func seed_round(new_master_seed: int) -> void:
	master_seed = new_master_seed
	behavior.seed = _derive(new_master_seed, "behavior")
	bots.seed = _derive(new_master_seed, "bots")
	cosmetic.seed = _derive(new_master_seed, "cosmetic")


func _derive(base: int, stream: String) -> int:
	return hash("%d:%s" % [base, stream])
