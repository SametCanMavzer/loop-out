class_name CameraRig extends Node3D
## Kamera + oryantasyon (TDD §7.2). İki preset (portrait/landscape) arasında tween;
## iki ayrı layout sahnesi YOK. Viewport oranı değişince otomatik uygulanır.
##
## keep_aspect = KEEP_WIDTH: fov YATAY olarak yorumlanır → dar portrait ekranda da
## çember (r_max) kadraja sığar (dikey FOV'da taşıyordu).

const PORTRAIT := {"pos": Vector3(0.0, 15.0, 18.0), "pitch": -39.0, "fov": 64.0}
const LANDSCAPE := {"pos": Vector3(0.0, 12.0, 15.0), "pitch": -37.0, "fov": 52.0}
const TWEEN_S := 0.35
## Eleme zoom'u (GDD §2.2): hızlı içeri, yavaş dışarı; toplam 0.4 sn GERÇEK zaman
## (slow-motion sırasında oynadığı için time_scale'i yok sayar).
const PUNCH_FOV := 7.0
const PUNCH_IN_S := 0.10
const PUNCH_OUT_S := 0.30

@onready var _cam: Camera3D = $Camera3D

var _is_portrait := true
var _tween: Tween
var _punch_tween: Tween
var _base_fov := 64.0     # oryantasyon preset'inin fov'u
var _punch := 0.0         # zoom sapması; efektif fov = _base_fov - _punch


func _ready() -> void:
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply(_detect_portrait(), true)


func _detect_portrait() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return vp.y >= vp.x


func _on_viewport_resized() -> void:
	var p := _detect_portrait()
	if p != _is_portrait:
		_apply(p, false)


func _apply(portrait: bool, instant: bool) -> void:
	_is_portrait = portrait
	var preset: Dictionary = PORTRAIT if portrait else LANDSCAPE
	var pos: Vector3 = preset["pos"]
	var pitch: float = deg_to_rad(float(preset["pitch"]))
	var fov: float = float(preset["fov"])
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		_cam.position = pos
		_cam.rotation.x = pitch
		_set_base_fov(fov)
		return
	_tween = create_tween().set_parallel(true)   # kozmetik geçiş; gameplay'i etkilemez
	_tween.tween_property(_cam, "position", pos, TWEEN_S).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_cam, "rotation:x", pitch, TWEEN_S).set_trans(Tween.TRANS_SINE)
	# fov doğrudan değil _base_fov üzerinden: eleme zoom'u aynı anda çalışıyorsa ezişmesinler.
	_tween.tween_method(_set_base_fov, _base_fov, fov, TWEEN_S).set_trans(Tween.TRANS_SINE)


func _set_base_fov(v: float) -> void:
	_base_fov = v
	_cam.fov = _base_fov - _punch


func _set_punch(v: float) -> void:
	_punch = v
	_cam.fov = _base_fov - _punch


## Eleme darbesi (GDD §2.2): kısa zoom. Kamera SARSILMAZ — GDD §7 kuralı, sarsıntı yerine
## HUD renk flaşı kullanılır.
func punch_zoom() -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween().set_ignore_time_scale(true)
	_punch_tween.tween_method(_set_punch, _punch, PUNCH_FOV, PUNCH_IN_S).set_trans(Tween.TRANS_QUAD)
	_punch_tween.tween_method(_set_punch, PUNCH_FOV, 0.0, PUNCH_OUT_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func is_portrait() -> bool:
	return _is_portrait
