class_name Schoolyard extends Node3D
## Arena ortamı: lise bahçesi. Asfalt saha + L şeklinde okul binası + bayrak direği +
## basket potası + banklar + çit + ağaçlar + uzakta şehir silueti.
##
## Tamamen kod, tamamen statik, RNG YOK (Rng.cosmetic'i tüketmez → determinizm sözleşmesi
## §4.8 etkilenmez). Oyun mantığıyla hiçbir bağı yoktur; yalnız dekordur.
##
## Bütçe (§11): tekrarlı her şey MultiMesh (pencere, çerçeve, bank, çit, ağaç, silüet,
## saha yayları) → yüzlerce parça birkaç çizim çağrısında. Arka plan geometrisi GÖLGE
## ÜRETMEZ; gölge haritası oyun alanına kalır. Doku yalnız bayrakta (kodda üretilir).
##
## Yerleşim kuralı: hiçbir dekor r=12'den içeri girmez ve kameranın önüne (+Z yakın bölge)
## konmaz — oyun alanı hiçbir zaman kapanmaz.

## Çayır zemini ufka kadar uzanmalı: kenarı görüş alanına girerse gökyüzüyle arasında
## çirkin bir dikiş çizgisi oluşuyor. Tek quad, maliyeti yok.
const YARD := 2000.0
const WALL_H := 11.0                # bina yüksekliği (3 kat)
const DEPTH := 10.0                 # kanat derinliği
const FRONT_Z := -14.0              # arka kanadın bahçeye bakan yüzü
const SIDE_X := -14.0               # sol kanadın bahçeye bakan yüzü
const SIDE_Z0 := -24.0              # sol kanat başlangıcı
const SIDE_Z1 := 2.0                # sol kanat bitişi (L biçimi korunur)
const FENCE_X := 20.0
## Basketbol sahası ölçüleri (uzun eksen X → potalar sağda ve solda). Saha bilerek KÜÇÜK:
## sol pota okulun sol kanadıyla çember arasına sığmalı ve iki pota da kadrajda kalmalı.
const COURT_HX := 12.0
const COURT_HZ := 7.2
const RIM_X := 10.8                 # çemberin saha merkezine olan uzaklığı
const POLE_OFFSET := 1.9            # direk çemberin ne kadar arkasında
const THREE_R := 5.2                # üçlük yayı yarıçapı
const KEY_LEN := 4.2                # boyalı alan uzunluğu
const KEY_HZ := 1.85                # boyalı alan yarı genişliği

## Gerçek asfalt koyudur (albedo ~0.15). Tamamen siyah yapılmıyor: ipin süpürme gölgesi ve
## oyuncu gölgeleri okunmaz hâle gelirdi (§4.3 okunurluk).
const C_ASPHALT := Color(0.145, 0.145, 0.15)
const C_COURT := Color(0.185, 0.185, 0.19)    # saha içi bir tık açık
const C_PAINT := Color(0.88, 0.88, 0.85)
const C_GRASS := Color(0.30, 0.42, 0.24)
const C_CURB := Color(0.62, 0.61, 0.58)
const C_WALL := Color(0.80, 0.74, 0.63)       # açık bej sıva
const C_WALL2 := Color(0.72, 0.65, 0.55)      # pilastr/şerit (gölge tonu)
const C_TRIM := Color(0.56, 0.40, 0.32)       # çatı/söve kiremit tonu
const C_GLASS := Color(0.30, 0.40, 0.50)
const C_FRAME := Color(0.92, 0.92, 0.90)
const C_DOOR := Color(0.28, 0.32, 0.38)
const C_FENCE := Color(0.34, 0.37, 0.40)
const C_TRUNK := Color(0.32, 0.24, 0.18)
const C_LEAF_A := Color(0.27, 0.45, 0.23)
const C_LEAF_B := Color(0.34, 0.50, 0.26)
const C_METAL := Color(0.70, 0.71, 0.73)
const C_WOOD := Color(0.55, 0.40, 0.26)
const C_RIM := Color(0.90, 0.42, 0.12)
const C_FIELD := Color(0.38, 0.47, 0.27)      # okulun dışındaki çayır
const C_FOREST := Color(0.24, 0.36, 0.24)     # orman şeridi
const C_HILL := Color(0.42, 0.52, 0.45)       # uzak tepeler: puslu (hava perspektifi)
const C_HOUSE := Color(0.84, 0.80, 0.71)      # köy evi sıvası
const C_ROOF := Color(0.62, 0.32, 0.24)       # kiremit

var _mats := {}
var _sign: Label3D                  # okul tabelası — dil değişince tazelenir
var _wall_note: Label3D             # duvardaki soluk not


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_court_lines()
	_build_school()
	_build_windows()
	_build_flagpole()
	_build_hoops()
	_build_benches()
	_build_fence()
	_build_trees()
	_build_backdrop()
	_build_signage()


## Dil değişince tabela ve duvar yazısı da çevrilir (ayarlardan TR↔EN anında).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_signage()


# ---------------------------------------------------------------- yardımcılar

## Paylaşılan materyal (aynı renk → aynı materyal → daha az durum değişimi).
func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	_mats[key] = m
	return m


func _add_mesh(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(m, color, pos)


func _cyl(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	return _add_mesh(m, color, pos)


## Birim küplerden MultiMesh: her parça kendi ölçek+konumuyla, TEK çizim çağrısı.
## parts = [[size:Vector3, pos:Vector3, yaw:float], ...]
func _box_batch(parts: Array, color: Color) -> MultiMeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cube
	mm.instance_count = parts.size()
	for i in parts.size():
		var p: Array = parts[i]
		var yaw: float = p[2] if p.size() > 2 else 0.0
		# DİKKAT: Basis.scaled() ölçeği DÖNÜŞTEN SONRA dünya eksenlerinde uygular (satırları
		# ölçekler) → dönmüş parçalar paralelkenara dönüşür. Ölçek YEREL eksende olmalı:
		# önce ölçek bazı, sonra dönüş. (Yay parçaları bu yüzden eğik çizgiler halinde çıkmıştı.)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(p[0] as Vector3)
		mm.set_instance_transform(i, Transform3D(basis, p[1] as Vector3))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(color)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Yayı kısa kutu parçalarına böl (tam halka için 0→360 ver).
func _arc_parts(radius: float, from_deg: float, to_deg: float, segments: int,
		width: float, y: float) -> Array:
	var parts: Array = []
	var a0 := deg_to_rad(from_deg)
	var a1 := deg_to_rad(to_deg)
	var step := (a1 - a0) / float(segments)
	var seg_len := radius * step * 1.06        # uçlar birleşsin diye hafif taşkın
	for i in segments:
		var a := a0 + step * (float(i) + 0.5)
		parts.append([
			Vector3(width, 0.03, absf(seg_len)),
			Vector3(cos(a) * radius, y, sin(a) * radius),
			-a,                                 # kutunun uzun ekseni yaya teğet olsun
		])
	return parts


# ---------------------------------------------------------------- sahne

## Gökyüzü: ufuk gradyanı (tek sky pass, post-process yok) + yumuşak ortam ışığı.
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.52, 0.85)
	sky_mat.sky_horizon_color = Color(0.78, 0.86, 0.93)
	# Ufuk rengi çayıra yakın olsun ki zemin quad'ının bittiği yer belli olmasın.
	sky_mat.ground_bottom_color = C_FIELD
	sky_mat.ground_horizon_color = Color(0.66, 0.74, 0.72)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# İnce dikey yüzeyler (figürlerin gövde/kol/bacakları) tepeden gelen tek ışığı yalayarak
	# alıyor ve kararıyordu — kadro koyu siluete dönüşüp birbirinden ayırt edilemiyordu.
	# Ortam ışığı bu yüzden yüksek: yönlü ışık şekli verir, ortam ışığı rengi okutur.
	env.ambient_light_energy = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_ground() -> void:
	# Ufka kadar çayır — okul kırsalda; asfalt yalnız bahçenin içinde.
	var plane := PlaneMesh.new()
	plane.size = Vector2(YARD, YARD)
	var mi := _add_mesh(plane, C_FIELD, Vector3.ZERO)
	mi.name = "Ground"
	_box(Vector3(46.0, 0.05, 33.0), C_ASPHALT, Vector3(-3.0, 0.02, 1.5))
	# Oyun alanını kapsayan saha zemini (biraz farklı ton — göz "burası saha" desin).
	# Spor alanı tonu: saha çizgilerinden geniş — oyun çemberinin tamamını kapsamalı.
	_box(Vector3(34.0, 0.04, 25.0), C_COURT, Vector3(0.0, 0.05, 0.0))
	# Binanın önünde çim şerit + bordür (asfaltla duvarı ayırır, derinlik verir).
	_box(Vector3(32.0, 0.08, 1.6), C_GRASS, Vector3(-2.0, 0.04, FRONT_Z + 0.8))
	var side_len := SIDE_Z1 - SIDE_Z0
	var side_cz := (SIDE_Z0 + SIDE_Z1) * 0.5
	_box(Vector3(1.6, 0.08, side_len), C_GRASS, Vector3(SIDE_X + 0.8, 0.04, side_cz))
	_box(Vector3(32.0, 0.22, 0.22), C_CURB, Vector3(-2.0, 0.12, FRONT_Z + 1.7))
	_box(Vector3(0.22, 0.22, side_len), C_CURB, Vector3(SIDE_X + 1.7, 0.12, side_cz))


## Saha çizgileri (beyaz boya). Hepsi tek MultiMesh — zeminin 1 cm üstünde (z-fighting yok).
## Gerçek bir basketbol sahası çizimi: dış dikdörtgen, orta çizgi + orta daire, iki uçta
## boyalı alan (raket) + serbest atış dairesi, üçlük yayları. Uzun eksen X (potalar sağ-sol).
## Hepsi tek MultiMesh.
func _build_court_lines() -> void:
	var y := 0.10
	var w := 0.18
	var parts: Array = []
	# Dış çizgiler + orta çizgi + orta daire.
	parts.append([Vector3(COURT_HX * 2.0, 0.03, w), Vector3(0.0, y, -COURT_HZ)])
	parts.append([Vector3(COURT_HX * 2.0, 0.03, w), Vector3(0.0, y, COURT_HZ)])
	parts.append([Vector3(w, 0.03, COURT_HZ * 2.0), Vector3(-COURT_HX, y, 0.0)])
	parts.append([Vector3(w, 0.03, COURT_HZ * 2.0), Vector3(COURT_HX, y, 0.0)])
	parts.append([Vector3(w, 0.03, COURT_HZ * 2.0), Vector3(0.0, y, 0.0)])
	parts.append_array(_arc_parts(2.1, 0.0, 360.0, 26, w, y))

	for side in [-1.0, 1.0]:
		var base_x: float = COURT_HX * side          # dip çizgisi
		var rim_x: float = RIM_X * side              # çember (üçlük yayının merkezi)
		var ft_x: float = (COURT_HX - KEY_LEN) * side    # serbest atış çizgisi
		# Boyalı alan (raket): iki yan + serbest atış çizgisi.
		parts.append([Vector3(KEY_LEN, 0.03, w), Vector3((base_x + ft_x) * 0.5, y, -KEY_HZ)])
		parts.append([Vector3(KEY_LEN, 0.03, w), Vector3((base_x + ft_x) * 0.5, y, KEY_HZ)])
		parts.append([Vector3(w, 0.03, KEY_HZ * 2.0), Vector3(ft_x, y, 0.0)])
		# Serbest atış dairesi.
		for p in _arc_parts(KEY_HZ, 0.0, 360.0, 22, w, y):
			p[1] = (p[1] as Vector3) + Vector3(ft_x, 0.0, 0.0)
			parts.append(p)
		# Üçlük: çemberden yarım daire + köşelerde dip çizgisine kısa düz parçalar.
		var from_deg := -90.0 if side > 0.0 else 90.0
		var to_deg := 90.0 if side > 0.0 else 270.0
		for p in _arc_parts(THREE_R, from_deg, to_deg, 28, w, y):
			p[1] = (p[1] as Vector3) + Vector3(rim_x, 0.0, 0.0)
			parts.append(p)
		var stub := absf(base_x - rim_x)
		for sz in [-THREE_R, THREE_R]:
			parts.append([Vector3(stub, 0.03, w), Vector3((base_x + rim_x) * 0.5, y, sz)])
	_box_batch(parts, C_PAINT)


## L şeklinde okul: uzun kanat arkada (X boyunca), kısa kanat solda (Z boyunca).
func _build_school() -> void:
	var cz := FRONT_Z - DEPTH * 0.5
	var cx := SIDE_X - DEPTH * 0.5
	var side_len := SIDE_Z1 - SIDE_Z0
	var side_cz := (SIDE_Z0 + SIDE_Z1) * 0.5
	_box(Vector3(32.0, WALL_H, DEPTH), C_WALL, Vector3(-2.0, WALL_H * 0.5, cz))
	_box(Vector3(DEPTH, WALL_H, side_len), C_WALL, Vector3(cx, WALL_H * 0.5, side_cz))
	# Çatı saçakları + parapet (silüeti keskinleştirir).
	_box(Vector3(33.0, 0.7, DEPTH + 1.0), C_TRIM, Vector3(-2.0, WALL_H + 0.35, cz))
	_box(Vector3(DEPTH + 1.0, 0.7, side_len + 1.0), C_TRIM, Vector3(cx, WALL_H + 0.35, side_cz))
	_box(Vector3(32.6, 0.5, DEPTH + 0.5), C_WALL2, Vector3(-2.0, WALL_H + 0.95, cz))
	_box(Vector3(DEPTH + 0.5, 0.5, side_len + 0.6), C_WALL2, Vector3(cx, WALL_H + 0.95, side_cz))

	# Kat araları + zemin söve şeritleri ve düşey pilastrlar: düz duvarı böler, ölçek verir.
	var detail: Array = []
	for band_y in [0.3, 3.9, 7.1]:
		detail.append([Vector3(32.2, 0.34, DEPTH + 0.16), Vector3(-2.0, band_y, cz)])
		detail.append([Vector3(DEPTH + 0.16, 0.34, side_len + 0.2), Vector3(cx, band_y, side_cz)])
	var px := -17.5
	while px <= 13.5:
		# Giriş bölümünde pilastr YOK — yoksa tabelanın harflerinin önünü keser.
		if absf(px + 2.0) > 5.0:
			detail.append([Vector3(0.55, WALL_H, 0.3), Vector3(px, WALL_H * 0.5, FRONT_Z + 0.15)])
		px += 5.8
	var pz := SIDE_Z0 + 2.5
	while pz <= SIDE_Z1 - 1.0:
		detail.append([Vector3(0.3, WALL_H, 0.55), Vector3(SIDE_X + 0.15, WALL_H * 0.5, pz)])
		pz += 5.7
	_box_batch(detail, C_WALL2)

	# Ana giriş: basamaklar + kapı + saçak + tabela.
	_box(Vector3(6.4, 0.16, 1.4), C_CURB, Vector3(-2.0, 0.08, FRONT_Z + 2.0))
	_box(Vector3(5.6, 0.16, 1.0), C_CURB, Vector3(-2.0, 0.24, FRONT_Z + 1.4))
	_box(Vector3(3.8, 3.4, 0.3), C_DOOR, Vector3(-2.0, 1.7, FRONT_Z + 0.16))
	_box(Vector3(0.14, 3.4, 0.34), C_FRAME, Vector3(-2.0, 1.7, FRONT_Z + 0.2))
	_box(Vector3(5.4, 0.35, 1.8), C_TRIM, Vector3(-2.0, 3.7, FRONT_Z + 0.9))
	# Tabela levhası — iki satırlık ada göre boyutlandı (EN metni TR'den uzun).
	_box(Vector3(9.0, 2.15, 0.24), C_TRIM, Vector3(-2.0, 5.3, FRONT_Z + 0.14))
	_box(Vector3(8.5, 1.75, 0.3), C_FRAME, Vector3(-2.0, 5.3, FRONT_Z + 0.12))


## Pencereler: cam ve çerçeve ikişer MultiMesh (2 çizim çağrısı, ~90 pencere).
func _build_windows() -> void:
	var xs: Array[float] = []           # arka kanat sütunları (giriş bölümü boş kalır: kapı+tabela)
	var x := -16.2
	while x <= 12.5:
		if absf(x + 2.0) > 4.4:
			xs.append(x)
		x += 2.9
	var zs: Array[float] = []           # sol kanat sütunları
	var z := SIDE_Z0 + 3.0
	while z <= SIDE_Z1 - 1.5:
		zs.append(z)
		z += 2.9
	var floors: Array[float] = [2.1, 5.6, 8.8]

	var glass := _quad_batch(xs, zs, floors, Vector2(1.5, 1.9), 0.05, C_GLASS)
	glass.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame := _quad_batch(xs, zs, floors, Vector2(1.74, 2.14), 0.03, C_FRAME)
	frame.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED


## İki kanadın bahçeye bakan yüzüne quad dizisi (pencere camı / çerçevesi).
func _quad_batch(xs: Array[float], zs: Array[float], floors: Array[float],
		size: Vector2, offset: float, color: Color) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = (xs.size() + zs.size()) * floors.size()
	var i := 0
	for fy in floors:
		for wx in xs:
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(wx, fy, FRONT_Z + offset)))
			i += 1
		for wz in zs:
			# +Z'ye bakan quad'ı Y ekseninde +90° döndür → +X'e (bahçeye) bakar.
			mm.set_instance_transform(i, Transform3D(
				Basis(Vector3.UP, PI * 0.5), Vector3(SIDE_X + offset, fy, wz)))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(color).duplicate()   # cull ayarı diğer renkleri etkilemesin
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Bayrak direği — Türk lisesi bahçesinin değişmezi. Bayrak dokusu kodda üretilir (dosya yok).
func _build_flagpole() -> void:
	# Saha çizgisiyle (z=-10) bordür (z=-12.3) arasındaki şeritte; banklarla çakışmaz.
	var base := Vector3(-9.3, 0.0, -11.4)
	_box(Vector3(1.6, 0.4, 1.6), C_CURB, base + Vector3(0.0, 0.2, 0.0))
	_cyl(0.09, 9.0, C_METAL, base + Vector3(0.0, 4.9, 0.0))
	_cyl(0.16, 0.2, C_METAL, base + Vector3(0.0, 9.5, 0.0))
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 1.73)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = _flag_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	# Direğin sağına asılı, hafifçe bahçeye dönük.
	mi.position = base + Vector3(1.35, 8.2, 0.0)
	mi.rotation.y = deg_to_rad(-18.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Ay-yıldızlı bayrak dokusu — 96×64, kodda çizilir (asset dosyası gerekmez).
func _flag_texture() -> ImageTexture:
	var w := 96
	var h := 64
	var red := Color(0.89, 0.06, 0.14)
	var white := Color(1.0, 1.0, 1.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(red)
	# Hilal: büyük beyaz daireden küçük kırmızı daire çıkarılır.
	var c1 := Vector2(34.0, 32.0)
	var c2 := Vector2(41.5, 32.0)
	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if p.distance_to(c1) <= 15.5 and p.distance_to(c2) > 12.4:
				img.set_pixel(x, y, white)
	# Yıldız: 5 kollu, nokta-poligon testiyle doldurulur.
	var star := _star_points(Vector2(62.0, 32.0), 9.0, 3.9)
	for y in range(20, 45):
		for x in range(50, 76):
			if _in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), star):
				img.set_pixel(x, y, white)
	return ImageTexture.create_from_image(img)


func _star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := -PI * 0.5 + PI * float(i) / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var n := poly.size()
	var j := n - 1
	for i in n:
		var a := poly[i]
		var b := poly[j]
		if (a.y > p.y) != (b.y > p.y):
			if p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
				inside = not inside
		j = i
	return inside


## İki basket potası (sahanın sağ ve sol ucunda). Çember konumu RIM_X ile çizgilerle aynı.
func _build_hoops() -> void:
	for side in [-1.0, 1.0]:
		_build_hoop(side)


## side = +1 sağ, -1 sol. Direk dip çizgisinin arkasında, konsol kol sahaya doğru uzanır.
func _build_hoop(side: float) -> void:
	var pole_x: float = (RIM_X + POLE_OFFSET) * side
	var board_x: float = (RIM_X + 0.55) * side
	_cyl(0.12, 3.7, C_METAL, Vector3(pole_x, 1.85, 0.0))
	_box(Vector3(POLE_OFFSET - 0.4, 0.14, 0.14), C_METAL,
		Vector3((pole_x + board_x) * 0.5, 3.55, 0.0))
	_box(Vector3(0.12, 1.05, 1.8), C_FRAME, Vector3(board_x, 3.2, 0.0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.36
	rim.outer_radius = 0.45
	rim.rings = 6
	rim.ring_segments = 14
	_add_mesh(rim, C_RIM, Vector3(RIM_X * side, 2.95, 0.0))


## Banklar: binanın önünde, tek MultiMesh (oturak + sırtlık + 2 ayak × 5 bank).
func _build_benches() -> void:
	var parts: Array = []
	for bx in [-12.6, -6.0, 3.5, 8.0, 12.5]:
		var b := Vector3(bx, 0.0, FRONT_Z + 2.9)
		parts.append([Vector3(2.0, 0.12, 0.55), b + Vector3(0.0, 0.45, 0.0)])
		parts.append([Vector3(2.0, 0.45, 0.1), b + Vector3(0.0, 0.75, -0.24)])
		parts.append([Vector3(0.12, 0.45, 0.5), b + Vector3(-0.85, 0.22, 0.0)])
		parts.append([Vector3(0.12, 0.45, 0.5), b + Vector3(0.85, 0.22, 0.0)])
	_box_batch(parts, C_WOOD)


## Bahçe çiti: sağ kenar boyunca direkler + üst/alt ray (hepsi tek MultiMesh).
func _build_fence() -> void:
	var parts: Array = []
	var z_start := -24.0
	var z_end := 18.0
	var step := 1.6
	var count := int((z_end - z_start) / step) + 1
	for i in count:
		parts.append([Vector3(0.12, 2.4, 0.12), Vector3(FENCE_X, 1.2, z_start + float(i) * step)])
	var span := z_end - z_start
	var mid := (z_start + z_end) * 0.5
	parts.append([Vector3(0.16, 0.12, span), Vector3(FENCE_X, 2.35, mid)])
	parts.append([Vector3(0.16, 0.12, span), Vector3(FENCE_X, 1.10, mid)])
	_box_batch(parts, C_FENCE)


## Ağaçlar: gövdeler tek MultiMesh, taçlar iki tonda iki MultiMesh (hacim hissi).
func _build_trees() -> void:
	var spots: Array = [
		[Vector3(16.8, 0.0, -19.5), 3.4], [Vector3(17.6, 0.0, -11.0), 2.7],
		[Vector3(16.4, 0.0, 7.0), 3.8], [Vector3(17.2, 0.0, 13.5), 3.0],
		[Vector3(-17.5, 0.0, 6.0), 3.3], [Vector3(-18.5, 0.0, 13.0), 2.8],
	]
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.3
	trunk.height = 1.0
	trunk.radial_segments = 8
	trunk.rings = 1
	var tmm := MultiMesh.new()
	tmm.transform_format = MultiMesh.TRANSFORM_3D
	tmm.mesh = trunk
	tmm.instance_count = spots.size()

	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 10
	crown.rings = 6
	var mms := [_crown_mm(crown, spots.size()), _crown_mm(crown, spots.size())]

	for i in spots.size():
		var p: Vector3 = spots[i][0]
		var hgt: float = spots[i][1]
		tmm.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(1.0, hgt, 1.0)), p + Vector3(0.0, hgt * 0.5, 0.0)))
		var r := hgt * 0.6
		# Alt taç geniş+koyu, üst taç dar+açık → tek küreden daha dolgun görünür.
		mms[0].set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(r, r * 0.8, r)), p + Vector3(0.0, hgt + r * 0.25, 0.0)))
		mms[1].set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(r * 0.72, r * 0.62, r * 0.72)),
			p + Vector3(0.0, hgt + r * 0.95, 0.0)))

	_attach_mm(tmm, C_TRUNK)
	_attach_mm(mms[0], C_LEAF_A)
	_attach_mm(mms[1], C_LEAF_B)


func _crown_mm(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	return mm


func _attach_mm(mm: MultiMesh, color: Color) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(color)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Okul tabelası + duvardaki soluk not. İkisi de Label3D (dokusuz, çeviriye bağlı).
func _build_signage() -> void:
	# İki satır (metin CSV'de \n ile bölünür) — EN adı TR'den uzun, tek satır levhaya sığmıyordu.
	# KALİTE: Label3D yazıyı font_size piksellik atlasa çizip pixel_size ile dünyaya ölçekler.
	# 64px'lik atlas ekranda büyütülünce bulanıklaşıyordu → atlas 4 kat büyütüldü, pixel_size
	# aynı oranda küçültüldü: dünya boyutu değişmedi, çözünürlük 4 katına çıktı.
	_sign = Label3D.new()
	_sign.font_size = 400
	_sign.pixel_size = 0.00155
	_sign.line_spacing = 20.0
	# İnce, aynı renkte kontur: harf gövdesini kalınlaştırır → küçültülünce daha okunur.
	_sign.outline_size = 14
	_sign.outline_modulate = Color(0.16, 0.20, 0.28)
	_sign.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sign.modulate = Color(0.16, 0.20, 0.28)
	_sign.outline_size = 0
	# Kesme (discard) → yazı saydam sıralamaya girmez, duvarla z-sıra sorunu çıkarmaz.
	_sign.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	# Levhanın ÖNÜNDE dursun; pilastr/söve hiçbir harfi kesmesin.
	_sign.position = Vector3(-2.0, 5.3, FRONT_Z + 0.42)
	_sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sign)

	# "Detayda görünen" duvar yazısı: girişin sağında, pencerelerin altında, hafif eğik.
	# Duvarla düşük kontrast → uzaktan sırıtmaz; ama okunacak kadar koyu ve büyük.
	_wall_note = Label3D.new()
	_wall_note.font_size = 320
	_wall_note.pixel_size = 0.00150
	_wall_note.modulate = Color(0.44, 0.38, 0.34)
	_wall_note.outline_size = 0
	_wall_note.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_wall_note.position = Vector3(8.4, 0.80, FRONT_Z + 0.42)
	_wall_note.rotation.z = deg_to_rad(-2.5)              # elle yazılmış hissi
	_wall_note.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_wall_note)

	_refresh_signage()


func _refresh_signage() -> void:
	if _sign != null:
		_sign.text = tr("DECOR_SCHOOL_NAME")
	if _wall_note != null:
		_wall_note.text = tr("DECOR_WALL_NOTE")


## Okulun ardı: orman şeridi + uzak tepeler + birkaç köy evi. Çatı çizgisinin üstünde
## görünür ve sahneye derinlik verir. Uzaklaştıkça renkler soluklaşır (hava perspektifi).
func _build_backdrop() -> void:
	_build_hills()
	_build_forest()
	_build_village()


## Uzak tepeler: yassılaştırılmış küreler, puslu yeşil. Tek MultiMesh.
func _build_hills() -> void:
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.radial_segments = 16
	dome.rings = 8
	# Yükseklikler orman şeridinin ARDINDAN görünecek kadar (aksi hâlde ağaçlar tam örter).
	var hills: Array = [
		[Vector3(58.0, 34.0, 30.0), Vector3(-62.0, 0.0, -100.0)],
		[Vector3(46.0, 42.0, 28.0), Vector3(-16.0, 0.0, -118.0)],
		[Vector3(64.0, 31.0, 32.0), Vector3(30.0, 0.0, -104.0)],
		[Vector3(50.0, 38.0, 28.0), Vector3(78.0, 0.0, -112.0)],
	]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dome
	mm.instance_count = hills.size()
	for i in hills.size():
		mm.set_instance_transform(i, Transform3D(
			Basis.from_scale(hills[i][0] as Vector3), hills[i][1] as Vector3))
	_attach_mm(mm, C_HILL)


## Orman şeridi: okulun arkasında sık kavak/çam dizisi. Koni (üst yarıçapı 0 silindir),
## tek MultiMesh. Yükseklikler sabit bir desenden gelir — RNG yok.
func _build_forest() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var pattern: Array[float] = [1.0, 0.72, 1.24, 0.88, 1.42, 0.66, 1.1, 0.95, 1.32, 0.78]
	var xs: Array[float] = []
	var zs: Array[float] = []
	var scales: Array[float] = []
	var i := 0
	var x := -78.0
	while x <= 78.0:
		var k: float = pattern[i % pattern.size()]
		xs.append(x + k * 2.0)
		zs.append(-32.0 - k * 9.0)          # iki sıra gibi görünsün diye derinlik oynar
		scales.append(k)
		x += 4.6
		i += 1

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = xs.size()
	for j in xs.size():
		var s: float = scales[j]
		var h := 11.0 + s * 6.0
		mm.set_instance_transform(j, Transform3D(
			Basis.from_scale(Vector3(1.9 + s * 0.7, h, 1.9 + s * 0.7)),
			Vector3(xs[j], h * 0.5, zs[j])))
	_attach_mm(mm, C_FOREST)


## Köy evleri: sağda, bahçe çitinin ötesinde. Gövde kutuları + PrismMesh kiremit çatılar.
func _build_village() -> void:
	var houses: Array = [
		[Vector3(7.0, 5.0, 6.0), Vector3(27.0, 0.0, -20.0), deg_to_rad(-14.0)],
		[Vector3(6.0, 4.4, 5.5), Vector3(36.0, 0.0, -30.0), deg_to_rad(8.0)],
		[Vector3(8.0, 5.4, 6.5), Vector3(24.0, 0.0, -34.0), deg_to_rad(20.0)],
	]
	var walls: Array = []
	for h in houses:
		var size: Vector3 = h[0]
		var pos: Vector3 = h[1]
		walls.append([size, pos + Vector3(0.0, size.y * 0.5, 0.0), h[2]])
	_box_batch(walls, C_HOUSE)

	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = prism
	mm.instance_count = houses.size()
	for i in houses.size():
		var size: Vector3 = houses[i][0]
		var pos: Vector3 = houses[i][1]
		mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, houses[i][2] as float)
				* Basis.from_scale(Vector3(size.x * 1.12, size.y * 0.55, size.z * 1.12)),
			pos + Vector3(0.0, size.y + size.y * 0.275, 0.0)))
	_attach_mm(mm, C_ROOF)
