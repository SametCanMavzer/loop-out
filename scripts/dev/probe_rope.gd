extends Node
## GERÇEK oyundaki (main.tscn) ipin EKRANDA ÇİZİLEN hâlini ölçer.
##
## Neden dünya koordinatı: daha önce iç değişkenlere (bend_at) bakıp "kıvrım değişiyor"
## sonucuna varmıştım, oysa çizim ters elle kuruluyordu — yani ölçtüğüm şey ekrandaki şey
## değildi. Burada ipin gerçek dünya noktaları okunur.
##
## İki şeyi denetler:
##   1) KAMÇI YÖNÜ: ipin ucu, gidiş yönünün GERİSİNDE kalmalı (gövde önde olmalı).
##   2) ŞEKİL DEĞİŞİMİ: kavis derinliği dönüş boyunca gözle görülür şekilde değişmeli.
##
## Çalıştırma: godot --headless scenes/dev/probe_rope.tscn

const SAMPLES := 240

var _viz: RopeVisual
var _rope: Rope
var _rows: Array = []
var _n := 0
var _prev_tip_angle := 0.0
var _behind := 0
var _ahead := 0


func _ready() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	add_child(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var arena := get_child(0).get_node("Arena3D").get_child(0)
	_viz = arena.get_node("RopeSpinner")
	_rope = arena.get_node("ArenaController").rope
	print("=== GERÇEK OYUNDA İP (dünya koordinatları) ===")


func _process(_dt: float) -> void:
	if _viz == null or _rope == null:
		return
	var tip := _viz.point_world(RopeVisual.SEGMENTS)
	var mid := _viz.point_world(RopeVisual.SEGMENTS / 2)
	var tip_a := atan2(tip.z, tip.x)
	var mid_a := atan2(mid.z, mid.x)
	var sweep := wrapf(tip_a - _prev_tip_angle, -PI, PI)     # ucun dünyadaki dönüş yönü
	_prev_tip_angle = tip_a
	# Gövde, ucun ilerisinde mi? (kamçı: uç geride kalır)
	var rel := wrapf(mid_a - tip_a, -PI, PI)
	if absf(sweep) > 0.0005 and _n > 10:
		if signf(rel) == signf(sweep):
			_ahead += 1                                      # gövde önde → uç geride ✓
		else:
			_behind += 1

	_n += 1
	if _n % 6 != 0:
		return
	# Kavis derinliği: orta noktanın, göbek→uç kirişine dik uzaklığı (birim).
	var hub := _viz.point_world(0)
	var chord := Vector2(tip.x - hub.x, tip.z - hub.z)
	var to_mid := Vector2(mid.x - hub.x, mid.z - hub.z)
	var bow := 0.0
	if chord.length() > 0.001:
		bow = (chord.x * to_mid.y - chord.y * to_mid.x) / chord.length()
	_rows.append([rad_to_deg(wrapf(_rope.angle, 0.0, TAU)), _rope.angular_vel, bow,
		String(_rope.current_behavior_id)])
	if _rows.size() >= SAMPLES:
		_report()
		get_tree().quit()


func _report() -> void:
	print("  ip açısı |    ω    | kavis derinliği | davranış")
	var min_b := 9999.0
	var max_b := -9999.0
	for i in _rows.size():
		var r: Array = _rows[i]
		min_b = minf(min_b, r[2])
		max_b = maxf(max_b, r[2])
		if i % 8 == 0:
			print("  %7.1f° | %6.2f  | %10.2f      | %s" % [r[0], r[1], r[2], r[3]])
	print("--- kavis derinliği: %.2f … %.2f birim (fark %.2f) ---" % [min_b, max_b, max_b - min_b])
	# Eşik GÖRÜLEBİLİRLİK eşiği: ip 9 birim uzun, 0.4 birim kalın. Kavisin tur boyunca en az
	# ~1 birim (ipin 2-3 katı kalınlığı kadar) değişmesi lazım ki ekranda fark edilsin.
	if max_b - min_b < 1.0:
		print("  SONUÇ: şekil neredeyse SABİT — dönen bükük çubuk gibi görünür ✗")
	else:
		print("  SONUÇ: şekil dönüş boyunca gözle görülür değişiyor ✓")
	var total := _ahead + _behind
	var pct := 100.0 * float(_ahead) / float(maxi(total, 1))
	print("--- kamçı yönü: karelerin %%%.0f'inde gövde ucun İLERİSİNDE (uç geride) ---" % pct)
	if pct < 90.0:
		print("  SONUÇ: ip TERS bükülüyor — uç, gidiş yönünün önünde ✗")
	else:
		print("  SONUÇ: kamçı yönü doğru (uç geride kalıyor) ✓")
