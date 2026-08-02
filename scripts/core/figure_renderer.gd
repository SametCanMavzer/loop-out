class_name FigureRenderer extends Node3D
## Oyuncuların insan figürü (kafa + gövde + iki kol + iki bacak + saç), low-poly.
##
## HER FİGÜR AYRI GÖRÜNÜR: boy, gövde eni, ten tonu, saç modeli, saç rengi ve forma rengi
## kişiye özel. Hepsi id'den türetilir — RNG YOK, yani kadro her turda aynı görünür ve
## kozmetik stream tüketilmez (§4.8).
##
## BÜTÇE (§11): çeşitlilik için ayrı node GEREKMEZ — MultiMesh'te her kopyanın kendi
## dönüşümü (dolayısıyla ölçeği) ve rengi olur. Parça tipi başına tek MultiMesh: 16 kişilik
## kadro toplam 9 çizim çağrısında çizilir. Node başına yapsaydık 150+ çağrı olurdu ve orta
## seviye Android tarayıcıda 60 FPS hedefi (§11) riske girerdi.

const HIP := 0.60                # kalça yüksekliği (ayakta)
const CROUCH_DROP := 0.34        # eğilince kalça bu oranda alçalır
const TORSO_LEN := 0.62
const TORSO_R := 0.17
const HEAD_R := 0.17
const ARM_LEN := 0.44
const ARM_R := 0.068
const LEG_LEN := 0.52
const LEG_R := 0.088
const SHOULDER_Y := 0.55         # kalçadan yukarı
const SHOULDER_X := 0.215
const HIP_X := 0.105

## Ten tonları. Aralık DAR (geniş aralıkta kafalar aşırı ayrışıp tuhaf duruyordu) ve hepsinde
## hafif PEMBE/KIRMIZI ton var — düz sarı-kahve karışımı ten gibi değil plastik gibi duruyor.
const SKINS: Array[Color] = [
	Color(0.94, 0.77, 0.68), Color(0.87, 0.68, 0.57), Color(0.75, 0.56, 0.45),
	Color(0.60, 0.43, 0.34), Color(0.45, 0.31, 0.25),
]
## Saç renkleri — tenle karışmasın diye hepsi belirgin koyu/ayrık.
const HAIRS: Array[Color] = [
	Color(0.09, 0.08, 0.08), Color(0.20, 0.13, 0.10), Color(0.34, 0.21, 0.13),
	Color(0.56, 0.38, 0.16), Color(0.82, 0.70, 0.40), Color(0.48, 0.18, 0.12),
]
## Bot formaları: okul bahçesi kalabalığı gibi AYRIK ve canlı renkler.
## (Önce GDD §3'e uyup nötr gri tonlar kullanıldı — 16 kişi birbirinin aynısı göründü.
## Oyuncunun ayırt edilmesi artık renkle değil, ayağının altındaki halka ile sağlanıyor.)
const BOT_SHIRTS: Array[Color] = [
	Color(0.86, 0.30, 0.28), Color(0.30, 0.52, 0.86), Color(0.35, 0.70, 0.40),
	Color(0.90, 0.66, 0.22), Color(0.62, 0.36, 0.76), Color(0.22, 0.70, 0.72),
	Color(0.88, 0.48, 0.66), Color(0.55, 0.60, 0.30), Color(0.92, 0.92, 0.88),
	Color(0.40, 0.42, 0.50),
]

## Saç modelleri: 0 kısa, 1 kısa+at kuyruğu, 2 kabarık, 3 çok kısa (jile).
const HAIR_SHORT := 0
const HAIR_TAIL := 1
const HAIR_PUFF := 2
const HAIR_BUZZ := 3

var _mm := {}                    # parça adı -> MultiMesh
var _count := {}                 # parça adı -> bu karede kaç kopya yazıldı
var _capacity := 0
var _styles := {}                # id -> stil sözlüğü (bir kez hesaplanır)


func setup(capacity: int) -> void:
	_capacity = capacity
	var head := SphereMesh.new()
	head.radius = HEAD_R
	head.height = HEAD_R * 2.0
	head.radial_segments = 10
	head.rings = 6
	_make("head", head)

	var torso := CapsuleMesh.new()
	torso.radius = TORSO_R
	torso.height = TORSO_LEN
	torso.radial_segments = 10
	torso.rings = 2
	_make("torso", torso)

	var arm := CapsuleMesh.new()
	arm.radius = ARM_R
	arm.height = ARM_LEN
	arm.radial_segments = 6
	arm.rings = 1
	_make("arm_l", arm)
	_make("arm_r", arm)

	var leg := CapsuleMesh.new()
	leg.radius = LEG_R
	leg.height = LEG_LEN
	leg.radial_segments = 6
	leg.rings = 1
	_make("leg_l", leg)
	_make("leg_r", leg)

	# Saç: kafayı saran küre (kısa/jile bunun yassı hâli), kabarık küre, at kuyruğu kapsülü.
	# ⚠ Saç küresi kafadan BELİRGİN büyük olmalı. Önce %4 büyük yapılmıştı (0.177 / 0.170) —
	# tamamen kafanın içinde kalıyordu ve herkes KEL görünüyordu. %18 büyük + yukarı kaydırma
	# ile saç kafanın üstünde ayrı bir hacim olarak okunuyor.
	var cap := SphereMesh.new()
	cap.radius = HEAD_R * 1.18
	cap.height = HEAD_R * 2.36
	cap.radial_segments = 10
	cap.rings = 6
	_make("hair_cap", cap)

	var puff := SphereMesh.new()
	puff.radius = HEAD_R * 1.52
	puff.height = HEAD_R * 3.04
	puff.radial_segments = 10
	puff.rings = 6
	_make("hair_puff", puff)

	var tail := CapsuleMesh.new()
	tail.radius = HEAD_R * 0.46
	tail.height = HEAD_R * 2.1
	tail.radial_segments = 6
	tail.rings = 1
	_make("hair_tail", tail)

	# Gözler: yüzün önünde iki koyu nokta. Bu kamera uzaklığında birkaç piksel ama figürün
	# hangi yöne baktığını okutuyor ve "kafa = boş top" hissini kırıyor.
	var eye := SphereMesh.new()
	eye.radius = HEAD_R * 0.19
	eye.height = HEAD_R * 0.38
	eye.radial_segments = 6
	eye.rings = 4
	_make("eye_l", eye)
	_make("eye_r", eye)


func _make(part: String, mesh: Mesh) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = _capacity
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true      # renk kopya başına gelir
	mat.roughness = 1.0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = part
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	_mm[part] = mm
	_count[part] = 0


## id'den türetilen sabit karışım — aynı id her zaman aynı kişiyi verir (RNG yok).
##
## ⚠ İYİ KARIŞTIRMASI ŞART: ilk sürüm `((id+1)*2654435761 + salt*40503) % 997` idi. O çarpan
## 997'ye göre 30'a denk düşüyor, 30 da 5 ve 3'e bölündüğü için sonucun `% 5` / `% 4` alt
## bitleri neredeyse sabit kalıyordu — 16 kişinin yalnız 2 ten tonu ve 2 saç modeli çıkıyordu.
## Aşağıdaki xor-kaydır-çarp karışımı alt bitleri de dağıtır.
static func _pick(id: int, salt: int) -> int:
	var h: int = (id + 1) * 73856093 ^ (salt + 1) * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h) % 1000003


## Bir jumper'ın görünüş stili: boy, en, ten, saç, forma. Bir kez hesaplanır, saklanır.
func style_of(id: int, player_shirt: Color, is_player: bool) -> Dictionary:
	if _styles.has(id):
		var s: Dictionary = _styles[id]
		s["shirt"] = player_shirt if is_player else s["shirt"]
		return s
	var st := {
		"height": 0.86 + float(_pick(id, 1) % 33) * 0.01,     # 0.86 – 1.18 (belirgin boy farkı)
		"width": 0.88 + float(_pick(id, 2) % 25) * 0.01,      # 0.88 – 1.12
		"skin": SKINS[_pick(id, 3) % SKINS.size()],
		"hair_type": _pick(id, 4) % 4,
		"hair": HAIRS[_pick(id, 5) % HAIRS.size()],
		"shirt": player_shirt if is_player else BOT_SHIRTS[_pick(id, 6) % BOT_SHIRTS.size()],
	}
	_styles[id] = st
	return st


func clear_styles() -> void:
	_styles.clear()


# ---------------------------------------------------------------- çizim

func begin_frame() -> void:
	for part in _count.keys():
		_count[part] = 0


## Bir figür çiz.
##   root  : gövdenin dünya dönüşümü (konum + yön; savrulan gövdede takla da buradadır)
##   style : style_of() çıktısı (boy/en/ten/saç/forma)
##   pose  : {"crouch": eğilme 0..1, "tuck": havada bacak toplama 0..1, "swing": kol salınımı}
##   tint  : ⚠ durumunda karıştırılacak renk ve oranı [Color, float]
func draw_figure(root: Transform3D, style: Dictionary, pose: Dictionary,
		tint: Color = Color.BLACK, tint_amount: float = 0.0) -> void:
	for p in compute_parts(root, style, pose, tint, tint_amount):
		_put(p[0], p[1], p[2])


## Figürün parçalarını hesapla: [[parça adı, dönüşüm, renk], ...].
##
## Çizimden AYRI tutuluyor çünkü MultiMesh'in içi headless'ta geri OKUNAMIYOR (sahte
## RenderingServer her zaman birim matris döndürür). Geometriyi test edebilmenin tek yolu
## onu saf fonksiyon olarak hesaplamak.
func compute_parts(root: Transform3D, style: Dictionary, pose: Dictionary,
		tint: Color = Color.BLACK, tint_amount: float = 0.0) -> Array:
	var out: Array = []
	var crouch: float = pose.get("crouch", 0.0)
	var tuck: float = pose.get("tuck", 0.0)
	var swing: float = pose.get("swing", 0.0)

	var shirt: Color = (style["shirt"] as Color).lerp(tint, tint_amount)
	var skin: Color = (style["skin"] as Color).lerp(tint, tint_amount * 0.45)
	var hair: Color = (style["hair"] as Color).lerp(tint, tint_amount * 0.5)
	var shorts := Color(shirt.r * 0.45, shirt.g * 0.45, shirt.b * 0.52).lerp(tint, tint_amount * 0.7)

	# Boy/en farkı: ölçek figürün KENDİ ekseninde uygulanır (kök dönüşümün içine katılır).
	var w: float = style["width"]
	var h: float = style["height"]
	var body := Transform3D(root.basis * Basis.from_scale(Vector3(w, h, w)), root.origin)

	var hip: float = HIP - CROUCH_DROP * crouch
	var lean: float = 0.55 * crouch                      # eğilince gövde öne yatar

	# Gövde: kalçadan yukarı, öne yatık.
	var torso_dir := Vector3(0.0, cos(lean), sin(lean))
	var torso_joint := Vector3(0.0, hip, 0.0)
	out.append(["torso", body * _limb(torso_joint, torso_dir, TORSO_LEN * 0.5 + TORSO_R * 0.4), shirt])

	# Kafa, saç, gözler.
	var neck: Vector3 = torso_joint + torso_dir * (TORSO_LEN * 0.86)
	var head_c: Vector3 = neck + Vector3(0.0, HEAD_R * 0.75, 0.0)
	out.append(["head", body * Transform3D(Basis(), head_c), skin])
	_append_hair(out, body, head_c, int(style["hair_type"]), hair)
	var eye_c := Color(0.11, 0.10, 0.12).lerp(tint, tint_amount * 0.3)
	for s in [-1.0, 1.0]:
		out.append([
			"eye_l" if s < 0.0 else "eye_r",
			body * Transform3D(Basis(), head_c
				+ Vector3(HEAD_R * 0.40 * s, HEAD_R * 0.10, HEAD_R * 0.88)),
			eye_c])

	# Kollar: omuzdan aşağı; zıplarken öne/yukarı kalkar, eğilince öne düşer.
	var arm_pitch: float = -0.35 * tuck + 0.45 * crouch + swing
	for s in [-1.0, 1.0]:
		var shoulder := torso_joint + torso_dir * SHOULDER_Y + Vector3(SHOULDER_X * s, 0.0, 0.0)
		var dir := Vector3(0.16 * s, -cos(arm_pitch), sin(arm_pitch)).normalized()
		out.append(["arm_l" if s < 0.0 else "arm_r", body * _limb(shoulder, dir, ARM_LEN * 0.5), skin])

	# Bacaklar: kalçadan aşağı; zıplarken dizler öne toplanır, eğilince bükülür.
	var leg_pitch: float = 1.05 * tuck + 0.5 * crouch
	for s in [-1.0, 1.0]:
		var hip_j := Vector3(HIP_X * s, hip, 0.0)
		var dir := Vector3(0.05 * s, -cos(leg_pitch), sin(leg_pitch)).normalized()
		out.append(["leg_l" if s < 0.0 else "leg_r", body * _limb(hip_j, dir, LEG_LEN * 0.5), shorts])
	return out


## Saç modeli: kafanın üstüne oturan küre; jile daha yassı, kabarık daha büyük,
## at kuyruğu ayrıca arkaya sarkan bir kapsül ekler.
## Saç hafif GERİYE (yerel −Z, figür +Z'ye bakar) kaydırılır ki alında ten görünsün,
## kafa baştan aşağı saçla kaplı bir top gibi durmasın.
func _append_hair(out: Array, body: Transform3D, head_c: Vector3, hair_type: int,
		color: Color) -> void:
	match hair_type:
		HAIR_PUFF:
			out.append(["hair_puff", body * Transform3D(
				Basis.from_scale(Vector3(1.0, 0.94, 1.0)),
				head_c + Vector3(0.0, HEAD_R * 0.30, -HEAD_R * 0.10)), color])
		HAIR_BUZZ:
			out.append(["hair_cap", body * Transform3D(
				Basis.from_scale(Vector3(0.97, 0.74, 0.97)),
				head_c + Vector3(0.0, HEAD_R * 0.40, -HEAD_R * 0.12)), color])
		_:
			out.append(["hair_cap", body * Transform3D(
				Basis.from_scale(Vector3(1.0, 0.94, 1.0)),
				head_c + Vector3(0.0, HEAD_R * 0.34, -HEAD_R * 0.16)), color])
			if hair_type == HAIR_TAIL:
				var joint := head_c + Vector3(0.0, HEAD_R * 0.25, -HEAD_R * 0.95)
				out.append(["hair_tail", body * _limb(joint,
					Vector3(0.0, -0.70, -0.71).normalized(), HEAD_R * 1.05), color])


## Kalan kopyaları gizle — eski karenin figürleri ekranda kalmasın.
##
## ⚠ SIFIR ÖLÇEKLE GİZLENMEZ: Godot MultiMesh'e sıfır bazlı bir dönüşüm verildiğinde onu
## saklamıyor, geri okuyunca ölçek (1,1,1) çıkıyor — yani kullanılmayan kopyalar sahnenin
## ORTASINDA tam boyutta duruyordu. Bu yüzden hem çok küçük bir ölçek hem de kadraj dışına
## taşıma birlikte kullanılıyor.
const HIDDEN_XFORM := Vector3(0.0, -10000.0, 0.0)


func end_frame() -> void:
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), HIDDEN_XFORM)
	for part in _mm.keys():
		var mm: MultiMesh = _mm[part]
		for i in range(int(_count[part]), _capacity):
			mm.set_instance_transform(i, hidden)


## Eklem noktasından `dir` yönünde uzanan uzuv (kapsülün ekseni Y'dir).
func _limb(joint: Vector3, dir: Vector3, half_len: float) -> Transform3D:
	var up := dir.normalized()
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var fwd := up.cross(side).normalized()
	side = fwd.cross(up).normalized()
	return Transform3D(Basis(side, up, fwd), joint + up * half_len)


func _put(part: String, xform: Transform3D, color: Color) -> void:
	var i: int = _count[part]
	if i >= _capacity:
		return
	var mm: MultiMesh = _mm[part]
	mm.set_instance_transform(i, xform)
	mm.set_instance_color(i, color)
	_count[part] = i + 1
