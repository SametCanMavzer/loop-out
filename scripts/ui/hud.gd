class_name HUD extends Control
## Tur içi HUD (GDD §7 / TDD §7.3): üstte kalan oyuncu sayacı (eleme anında pulse),
## altta perfect combo, ⚠ durumunda ekran kenarı ince kırmızı çerçeve (4 ColorRect — shader yok),
## ilk zıplamaya kadar "DOKUN" ipucu, davranış telegrafı.
## EventBus'a bağlıdır (decoupled); arena referansı yalnız sayı okumak için.

const FEEDBACK_FADE := 1.2
const TELEGRAPH_FADE := 0.5

@onready var _alive: Label = $Top/AliveLabel
@onready var _round: Label = $Top/RoundLabel
@onready var _combo: Label = $Bottom/ComboLabel
@onready var _tap_hint: Label = $Bottom/TapHint
@onready var _feedback: Label = $Feedback
@onready var _behavior: Label = $BehaviorLabel
@onready var _warn_frame: Control = $WarnFrame
@onready var _countdown: Label = $Countdown
@onready var _orientation_button: Button = $OrientationButton   # GEÇİCİ (dev): oryantasyon testi

var _player_id := 0
var _total := 16
var _flash := 0.0
var _tel_flash := 0.0
var _combo_count := 0
var _tapped := false


func _ready() -> void:
	EventBus.ring_shrunk.connect(_on_ring_shrunk)
	EventBus.rope_crossed.connect(_on_crossed)
	EventBus.jumper_stumbled.connect(func(id: int) -> void: _set_warn_for(id, true))
	EventBus.jumper_pardoned.connect(func(id: int) -> void: _set_warn_for(id, false))
	EventBus.jumper_eliminated.connect(_on_eliminated)
	EventBus.behavior_telegraphed.connect(_on_telegraphed)
	EventBus.behavior_started.connect(_on_behavior_started)
	_feedback.modulate.a = 0.0
	_behavior.modulate.a = 0.0
	_warn_frame.visible = false
	_countdown.visible = false
	# GEÇİCİ (dev, F14'te kalkar): pencereyi yatay/dikey çevirip §7.2 preset geçişini test et.
	_orientation_button.pressed.connect(_toggle_orientation)


func _toggle_orientation() -> void:
	var s := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(s.y, s.x))


## Tur başında çağrılır (Main): sayaçları sıfırla.
func reset_for_round(total: int) -> void:
	_total = total
	_combo_count = 0
	_tapped = false
	_flash = 0.0
	_tel_flash = 0.0
	_warn_frame.visible = false
	_tap_hint.visible = false      # geri sayım bitince açılır
	_combo.text = ""
	_alive.text = "%d/%d" % [total, total]
	_round.text = "TUR 1"


func set_round(round_no: int) -> void:
	_round.text = "TUR %d" % round_no


## Geri sayım göstergesi (GDD §2.3: 1 sn). Bu süre boyunca ip DÖNMEZ, oyuncu hazırlanır.
func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = true


## Tur başladı: geri sayımı kapat, "DOKUN" ipucunu göster (ilk zıplamaya kadar).
func hide_countdown() -> void:
	_countdown.visible = false
	if not _tapped:
		_tap_hint.visible = true


func _on_ring_shrunk(alive_count: int) -> void:
	_alive.text = "%d/%d" % [alive_count, _total]
	# Eleme anında pulse (§7.3) — kozmetik tween, determinizm dışı.
	var tw := create_tween()
	_alive.scale = Vector2(1.35, 1.35)
	_alive.pivot_offset = _alive.size * 0.5
	tw.tween_property(_alive, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _on_crossed(jumper_id: int, result: int, delta_ms: float) -> void:
	if jumper_id != _player_id:
		return
	if not _tapped:
		_tapped = true
		_tap_hint.visible = false
	_flash = 1.0
	match result:
		Rope.CrossResult.PERFECT:
			_combo_count += 1
			_feedback.text = "PERFECT (%d ms)" % int(delta_ms)
			_feedback.modulate = Color(0.3, 1.0, 0.4)
		Rope.CrossResult.GRAZE:
			_combo_count = 0
			_feedback.text = "GRAZE"
			_feedback.modulate = Color(1.0, 0.9, 0.3)
		Rope.CrossResult.MISS:
			_combo_count = 0
			_feedback.text = "MISS"
			_feedback.modulate = Color(1.0, 0.35, 0.3)
	_combo.text = ("PERFECT ×%d" % _combo_count) if _combo_count > 1 else ""


## ⚠ ekran kenarı çerçevesi (§7.3) — yalnız oyuncunun durumu gösterilir.
func _set_warn_for(jumper_id: int, on: bool) -> void:
	if jumper_id == _player_id:
		_warn_frame.visible = on


func set_warning(on: bool) -> void:
	_warn_frame.visible = on


func _on_eliminated(jumper_id: int, _cause: int) -> void:
	if jumper_id == _player_id:
		_warn_frame.visible = false
		_combo.text = ""


func _on_telegraphed(id: StringName) -> void:
	_behavior.text = "⚠ " + String(id).to_upper()
	_behavior.modulate = Color(1.0, 0.8, 0.2)
	_tel_flash = 1.6


func _on_behavior_started(id: StringName) -> void:
	_behavior.text = String(id).to_upper()
	_behavior.modulate = Color(0.85, 0.9, 1.0)
	_tel_flash = 1.1


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * FEEDBACK_FADE)
		_feedback.modulate.a = _flash
	if _tel_flash > 0.0:
		_tel_flash = maxf(0.0, _tel_flash - dt * TELEGRAPH_FADE)
		_behavior.modulate.a = minf(_tel_flash, 1.0)
