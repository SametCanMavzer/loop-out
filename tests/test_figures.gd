extends RefCounted
## İnsan figürü çizimi doğru mu? (F14 cila)
##
## Neden test var: saç bir süre HİÇ görünmedi, herkes kel duruyordu. Sebep "saç yok" değildi
## — saç çiziliyordu ama küresi kafadan yalnız %4 büyüktü, yani kafanın İÇİNDE kalıyordu.
## Ayrıca kadro tek tip görünüyordu: id karıştırıcısı kötüydü, 16 kişiye yalnız 2 ten tonu
## ve 2 saç modeli düşüyordu. İkisi de gözle "ekledim" denip geçilebilecek türden; burada
## ÖLÇÜLÜYOR.
##
## ⚠ MultiMesh'in içi okunmuyor: headless'ta RenderingServer sahte olduğu için
## get_instance_transform ne yazılırsa yazılsın birim matris döndürür. Bu yüzden geometri
## `compute_parts()` ile saf fonksiyon olarak alınır — çizimden bağımsız, gerçekten test
## edilebilir.
## (godot --headless scenes/dev/run_tests.tscn -- test_figures)

const COUNT := 16
const HAIR_PARTS := ["hair_cap", "hair_puff"]


func run(tree: SceneTree) -> int:
	var fail := 0
	var host := Node3D.new()
	tree.root.add_child(host)
	var fr := FigureRenderer.new()
	host.add_child(fr)
	fr.setup(20)

	var styles: Array = []
	var figures: Array = []
	for id in COUNT:
		var st := fr.style_of(id, Color(0.35, 0.6, 0.9), id == 0)
		styles.append(st)
		figures.append(fr.compute_parts(Transform3D(), st, {}))

	# --- 1) Her figürde gövde parçalarının hepsi var mı ---
	for parts in figures:
		var names := {}
		for p in parts:
			names[p[0]] = int(names.get(p[0], 0)) + 1
		for must in ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r", "eye_l", "eye_r"]:
			if names.get(must, 0) != 1:
				push_error("FAIL: '%s' parçası eksik/fazla (%d)." % [must, names.get(must, 0)])
				fail += 1
				break

	# --- 2) HERKESİN saçı olmalı (kel kalan olmasın) ---
	var bald := 0
	for parts in figures:
		var has := false
		for p in parts:
			if HAIR_PARTS.has(p[0]):
				has = true
		if not has:
			bald += 1
	if bald > 0:
		push_error("FAIL: %d figür kel — saç parçası hiç eklenmemiş." % bald); fail += 1

	# --- 3) Saç kafanın DIŞINA taşmalı (asıl kusur buydu: içinde kalıyordu) ---
	var worst := 999.0
	for i in figures.size():
		worst = minf(worst, _hair_clearance(fr, figures[i]))
	if worst < 0.02:
		push_error("FAIL: saç kafanın içinde kalıyor (taşma %.4f birim) — kel görünür." % worst)
		fail += 1

	# --- 4) Kadro gerçekten çeşitli mi (16 klon olmasın) ---
	var uniq := {"height": {}, "hair_type": {}, "skin": {}, "shirt": {}, "hair": {}}
	for st in styles:
		uniq["height"][snappedf(st["height"], 0.01)] = true
		uniq["hair_type"][st["hair_type"]] = true
		uniq["skin"][st["skin"]] = true
		uniq["shirt"][st["shirt"]] = true
		uniq["hair"][st["hair"]] = true
	var need := {"height": 8, "hair_type": 4, "skin": 4, "shirt": 7, "hair": 4}
	for key in need.keys():
		if uniq[key].size() < int(need[key]):
			push_error("FAIL: '%s' için yalnız %d farklı değer (en az %d) — kadro tek tip."
				% [key, uniq[key].size(), need[key]]); fail += 1

	# --- 5) Boy farkı gerçekten geometriye yansıyor mu ---
	var tops: Array = []
	for parts in figures:
		tops.append(_find(parts, "head").origin.y)
	tops.sort()
	var spread: float = tops[COUNT - 1] - tops[0]
	if spread < 0.15:
		push_error("FAIL: en uzun ile en kısa arasında %.3f birim var — fark görünmez." % spread)
		fail += 1

	# --- 6) Eğilince figür GERÇEKTEN alçalmalı (poz boş vaat olmasın) ---
	var stand := _find(fr.compute_parts(Transform3D(), styles[0], {}), "head").origin.y
	var duck := _find(fr.compute_parts(Transform3D(), styles[0], {"crouch": 1.0}), "head").origin.y
	if stand - duck < 0.25:
		push_error("FAIL: eğilince kafa yalnız %.3f alçalıyor — eğilme okunmaz." % (stand - duck))
		fail += 1

	# --- 7) Figürler çemberin ORTASINA bakmalı ---
	# Denetimde bulundu: yaw formülü X'te aynalanmıştı (π/2−a yerine a−π/2), bu yüzden
	# çemberin bazı noktalarındaki figürler sırtını ipe dönüyordu. Gözle zor fark ediliyor,
	# burada her açı için ölçülüyor.
	for k in 16:
		var a := TAU * float(k) / 16.0
		var pos := Ring.world_pos(a, 9.0, 0.0)
		var fwd := Basis(Vector3.UP, ArenaView.face_center_yaw(a)) * Vector3(0.0, 0.0, 1.0)
		var to_center := (-pos).normalized()
		if fwd.dot(to_center) < 0.999:
			push_error("FAIL: açı %.2f rad'da figür ortaya bakmıyor (nokta çarpım %.3f)."
				% [a, fwd.dot(to_center)]); fail += 1
			break

	fr.queue_free()
	host.queue_free()
	if fail == 0:
		print("TEST FIGURES OK (%d figür, saç taşması %.3f, boy farkı %.2f, eğilme %.2f, %d forma)"
			% [COUNT, worst, spread, stand - duck, uniq["shirt"].size()])
	else:
		print("TEST FIGURES FAILED: %d hata" % fail)
	return fail


func _find(parts: Array, name: String) -> Transform3D:
	for p in parts:
		if p[0] == name:
			return p[1]
	return Transform3D()


## Saçın kafanın üstünden taşma miktarı (birim). Sıfır/negatifse saç kafanın içindedir.
func _hair_clearance(fr: FigureRenderer, parts: Array) -> float:
	var head := _find(parts, "head")
	var head_top: float = head.origin.y + FigureRenderer.HEAD_R * head.basis.get_scale().y
	var hair_top := -999.0
	for p in parts:
		if not HAIR_PARTS.has(p[0]):
			continue
		var mesh := fr._mm[p[0]].mesh as SphereMesh
		var t: Transform3D = p[1]
		hair_top = maxf(hair_top, t.origin.y + mesh.radius * t.basis.get_scale().y)
	return hair_top - head_top if hair_top > -900.0 else -1.0
