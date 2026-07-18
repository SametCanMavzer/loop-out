class_name JumperTuning extends RefCounted
## Jumper zamanlama parametreleri — TİCK cinsinden (TDD §6, §4.3). Config'ten türetilir
## (Config.jumper_tuning()); Jumper autoload'a bağlı kalmasın diye enjekte edilir.
## Varsayılanlar mevcut balance.json ms değerlerinin tick karşılığıdır (dokümantasyon amaçlı).

var jump_air: int          # normal zıplama havada kalma (420ms → 25 tick)
var high_jump_air: int     # yüksek zıplama (700ms → 42 tick)
var hold_threshold: int    # basılı tutma → yüksek zıplama eşiği (300ms → 18 tick)
var duck_release: int      # eğilme çıkış toleransı (120ms → 7 tick)
var input_buffer: int      # zıplama tamponu (100ms → 6 tick)


func _init(p_jump_air: int = 25, p_high_jump_air: int = 42, p_hold_threshold: int = 18,
		p_duck_release: int = 7, p_input_buffer: int = 6) -> void:
	jump_air = p_jump_air
	high_jump_air = p_high_jump_air
	hold_threshold = p_hold_threshold
	duck_release = p_duck_release
	input_buffer = p_input_buffer
