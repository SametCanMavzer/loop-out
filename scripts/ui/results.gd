class_name ResultsScreen extends Control
## Sonuç ekranı (GDD §6.1): sıralama (1./16) + ulaşılan tur + tekrar oyna.
## Jeton/ödül gösterimi F9 (ekonomi) ile bağlanır. Restart = sahne reload YOK (§7.1).

signal restart_pressed()
signal characters_pressed()
signal double_pressed()      # ödüllü reklam: jeton ×2 (GDD §6.2)

@onready var _title: Label = $Panel/Title
@onready var _detail: Label = $Panel/Detail
@onready var _coins: Label = $Panel/Coins
@onready var _button: Button = $Panel/RestartButton


@onready var _double: Button = $Panel/DoubleButton


func _ready() -> void:
	_button.pressed.connect(func() -> void: restart_pressed.emit())
	($Panel/CharactersButton as Button).pressed.connect(func() -> void: characters_pressed.emit())
	_double.pressed.connect(func() -> void:
		_double.disabled = true
		double_pressed.emit())


## Ödüllü reklam butonu yalnız servis destekliyorsa görünür (§12.3: NullAds → gizli).
func set_double_available(on: bool) -> void:
	_double.visible = on
	_double.disabled = not on


## earned: bu turda kazanılan jeton, total_coins: kasadaki toplam (GDD §6.2).
func show_result(placement: int, total: int, round_no: int,
		earned: int = 0, total_coins: int = 0, perfect_count: int = 0, daily_bonus: bool = false) -> void:
	if placement <= 1:
		_title.text = "KAZANDIN!"
	else:
		_title.text = "%d. SIRA" % placement
	_detail.text = "%d kişiden %d.  ·  tur %d  ·  %d perfect" % [total, placement, round_no, perfect_count]
	var bonus := "  (günlük ilk galibiyet ×3)" if daily_bonus else ""
	_coins.text = "+%d jeton%s     toplam: %d" % [earned, bonus, total_coins]
