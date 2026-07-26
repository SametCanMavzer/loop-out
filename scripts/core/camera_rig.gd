class_name CameraRig extends Node3D
## Kamera + oryantasyon (TDD §7.2). İki preset (portrait/landscape) arasında tween;
## iki ayrı layout sahnesi YOK. Viewport oranı değişince otomatik uygulanır.
##
## keep_aspect = KEEP_WIDTH: fov YATAY olarak yorumlanır → dar portrait ekranda da
## çember (r_max) kadraja sığar (dikey FOV'da taşıyordu).

const PORTRAIT := {"pos": Vector3(0.0, 15.0, 18.0), "pitch": -39.0, "fov": 64.0}
const LANDSCAPE := {"pos": Vector3(0.0, 12.0, 15.0), "pitch": -37.0, "fov": 52.0}
const TWEEN_S := 0.35

@onready var _cam: Camera3D = $Camera3D

var _is_portrait := true
var _tween: Tween


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
		_cam.fov = fov
		return
	_tween = create_tween().set_parallel(true)   # kozmetik geçiş; gameplay'i etkilemez
	_tween.tween_property(_cam, "position", pos, TWEEN_S).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_cam, "rotation:x", pitch, TWEEN_S).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_cam, "fov", fov, TWEEN_S).set_trans(Tween.TRANS_SINE)


func is_portrait() -> bool:
	return _is_portrait
