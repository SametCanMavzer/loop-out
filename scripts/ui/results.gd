class_name ResultsScreen extends Control
## Sonuç ekranı (GDD §6.1): sıralama (1./16) + ulaşılan tur + tekrar oyna.
## Jeton/ödül gösterimi F9 (ekonomi) ile bağlanır. Restart = sahne reload YOK (§7.1).

signal restart_pressed()

@onready var _title: Label = $Panel/Title
@onready var _detail: Label = $Panel/Detail
@onready var _button: Button = $Panel/RestartButton


func _ready() -> void:
	_button.pressed.connect(func() -> void: restart_pressed.emit())


func show_result(placement: int, total: int, round_no: int) -> void:
	if placement <= 1:
		_title.text = "KAZANDIN!"
	else:
		_title.text = "%d. SIRA" % placement
	_detail.text = "%d kişiden %d.  ·  tur %d" % [total, placement, round_no]
