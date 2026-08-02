class_name RopeVisual extends Node3D
## İpin görsel katmanı (TDD §4.1: mantık açısı tick'te ilerler, render açısı _process'te
## interpolasyonla çizilir). Yalnız çizim — determinizmi ETKİLEMEZ, RNG kullanmaz, mantığa
## hiçbir şey yazmaz.
##
## Şekil SABİT DEĞİL: ip, uçları birbirine yaylarla bağlı bir zincir gibi simüle edilir.
## Göbek (i=0) sürücüdür; her halka bir öncekini gecikmeyle takip eder, kendi ataleti vardır.
## Sonuç: ip hızlanınca/yavaşlayınca/yön değiştirince kıvrım göbekten uca doğru bir DALGA
## halinde yürür ve sönerek salınır — dönen bükük çubuk değil, yaşayan halat. Yükseklik
## değişimi (LOW↔HIGH) de aynı zincirden geçer, ip boyunca yayılır.
##
## Görünüm: kalın halat, kodda üretilen burgu dokusu (4 kol, iki ton, kollar arası oluk).

## SEGMENTS az tutuluyor: her parça ~0.6 birim olsun ki burgu dokusunun adımı halat çapıyla
## orantılı kalsın. 30 parçada adım 0.15 birime düşüyordu ve doku bu ölçekte bant değil
## NOKTA olarak görünüyordu — ip kesik kesik bir iplik gibi çıkıyordu (videoda görüldü).
const SEGMENTS := 14
## Çap 0.30 birim (Samet'in seçtiği). Aralık deneyle bulundu: 0.23 iplik gibi ince,
## 0.56 fazla kalın. Koyu asfalt üstünde okunurluk da gerekiyor.
const THICK := 0.15
const INNER_R := 0.42            # göbeğin dışından başlar

## ŞEKİL HER KARE YENİDEN ÇÖZÜLÜR — hazır bir eğri döndürülmez. İki kuvvetin oranı belirler:
##   1) MERKEZKAÇ (ω²·r): ipi yarıçap boyunca gerer, DÜZLEŞTİRİR. Hız arttıkça baskın.
##   2) YERÇEKİMİ (g): ipi DÜNYA −Y yönünde sarkıtır; sarkma ~ g/(ω²·L).
## Sonuç: hızlı ve sabit → ip neredeyse düz; yavaş/duruyor → belirgin sarkma ve geri kalma.
## Sarkma ipin yerel eksenine yapışık DEĞİL, hep aşağı.
const SAG_K := 1.25              # sarkma = SAG_K / ω²
const SAG_W_FLOOR := 1.3         # çok yavaşta sarkma sonsuza gitmesin
const SAG_MAX_LOW := 0.06        # alçak süpürme zaten yerde — sarkacak yer az
const SAG_MAX_HIGH := 0.42       # yüksek süpürmede belirgin sarkma

## Zincir dinamiği (kozmetik). LAG_PER_SEG: her halkanın bir öncekinden, dönüş hızına
## orantılı geri kalması.
##
## ⚠ SÖNÜM KRİTİK ÖNEMDE: her halka bir öncekini takip ettiği için zincir bir filtre
## zinciridir. Sönüm azsa (ζ<1) her halkanın rezonans kazancı 1'den büyük olur ve en
## ufak sarsıntı 30 halka boyunca KATLANARAK büyür — ip paramparça görünür (yaşandı).
## Bu yüzden DAMP ≈ 2·√STIFF (kritik sönümün biraz üstü) ve ayrıca halkalar arası bağıl
## hız sönümü var. Üstüne, aşağıdaki SERT SINIRLAR komşu halkaların birbirinden
## kopmasını matematiksel olarak imkânsız kılar: en kötü ihtimalle ip fazla kıvrılmış
## görünür, asla dağılmaz.
## Geri kalma (kamçı). Halka başına geri kalma yarıçap payıyla (t) orantılı → kıvrım karesel,
## yani gerçek kavis (sabit olsaydı doğrusal çıkar, o da eğri değil sadece kaymış düz çubuktur).
##
## ⚠ ESKİ MODELDEKİ FİZİK HATASI: geri kalma ω ile ARTIYORDU — hız arttıkça ip daha çok
## bükülüyordu. Yanlış: merkezkaç gerilmesi hızla büyüdüğü için hızlı ip DAHA DÜZ olur.
## LAG_K/|ω| bunu tersine çevirir. LAG_RAMP_W ise "ip duruyorsa sürükleme de yoktur"
## durumunu verir: ω→0'da gecikme söner, yani ters dönüşte ip önce düzelir, sonra öbür
## yöne bükülür.
## Not: uç gecikmesi ≈ LAG_K/|ω| × (SEGMENTS+1)/2 — yani SEGMENTS değişirse bu da ölçeklenmeli.
const LAG_K := 0.165
const LAG_RAMP_W := 2.0
const W_FLOOR := 0.6             # sıfıra bölme koruması
const STIFF := 140.0

## ⚠ İpi çeviren el SABİT BİR NOKTA DEĞİL: küçük bir daire çizer, ve süpürme düzlemi tam
## yatay değildir (el bel hizasında, ipin ucu yerde sürünüyor). Bu ikisi, dönüşün her turunda
## ipe bir kez itiş/çekiş verir — yerçekiminin süpürme yönündeki bileşeni tur boyunca
## cos/sin gibi değişir. Sonuç: kıvrım DÜNYA AÇISINA göre nefes alır.
## Bu terim olmadan sabit hızda şekil de sabit kalıyor ve ip "dönen bükük çubuk" gibi
## görünüyor (Samet'in şikâyeti buydu). Zincirin ataleti tepkiyi geciktirdiği için kıvrım
## simetrik değil, doğal bir savrulma hissi veriyor.
##
## ÖLÇÜM NOTU: bu itiş önce zincirin İÇİNDEN sürülüyordu, ama 30 halkalık zincir alçak
## geçiren filtre gibi davranıp tur frekansındaki bileşeni %90 söndürüyor — tur içindeki
## değişim 0.04 rad'da (≈2°) kalıyordu, yani gözle görülmüyordu. Bu yüzden doğrudan şekle
## uygulanıyor. ÇARPAN olarak: kamçı eğrisinin miktarını büyütüp küçültür, şekli bozmaz.
## (Toplama olarak uygulanınca iki ucu sıfır olan bir göbek ekliyordu ve ip S'e dönüyordu.)
##
## GERÇEK OYUNDA ÖLÇÜLDÜ (probe_rope): 0.45/0.15 ile uç gecikmesi tur boyunca yalnız
## 12°–28° arası gidiyordu — ekranda fark edilmiyordu ("yine yamuk olarak sabit duruyor").
## Genlik büyütüldü ve ikinci harmonik öne çıkarıldı: şekil tur başına İKİ kez değişiyor,
## ip neredeyse düzden belirgin kancaya kadar gidiyor.
const SWAY_REL := 0.55           # tur başına bir kez (eğik süpürme düzlemi / yerçekimi)
const SWAY_REL2 := 0.42          # elin dairesi elips → tur başına iki kez
const SWAY_FOLLOW := 7.0         # salınımın gecikmesi (ip ataletli, anında uymaz)
const SWAY_SAG_MIX := 0.4        # sarkma da aynı fazla nefes alsın (yalnız kozmetik)
const DAMP := 28.5               # 2·√140 ≈ 23.7 → biraz üstü (hafif aşırı sönümlü)
const REL_DAMP := 12.0           # komşu halkalar arası bağıl hız sönümü
const Y_STIFF := 400.0           # yükseklik dalgası hızlı yayılsın (oyuncuyu yanıltmasın)
const Y_DAMP := 48.0             # 2·√400 = 40 → üstü
const MAX_LAG := 3.0             # ham zincir sınırı (yalnız patlama emniyeti)
const MAX_DELTA_LAG := 0.30      # komşu halkalar arası en fazla açı farkı (patlama emniyeti)
const MAX_DELTA_Y := 0.10        # komşu halkalar arası en fazla yükseklik farkı
## Ucun en fazla ne kadar geride kalabileceği (rad). Aşınca tüm eğri orantılı küçültülür —
## yüksek hızda ip kendi üstüne dolanmasın.
const MAX_BEND := 1.0

## Halat burgusu: 2 kalın kol, iki ton (4 ince kol bu ölçekte noktalara dönüşüyordu).
## STRANDS ve TWIST'in İKİSİ DE ÇİFT olmalı: bantlar mod-2 ile renklendiği için tek sayıda
## olsalardı desen çevrede/parça ekinde ton atlar, burgu zıplıyormuş gibi görünürdü.
## Renkler koyu asfalt üstünde okunacak kadar parlak.
const C_STRAND_A := Color(0.94, 0.85, 0.64)     # doğal kenevir
const C_STRAND_B := Color(0.86, 0.36, 0.24)     # kiremit kırmızısı
const C_HUB := Color(0.30, 0.32, 0.36)
const STRANDS := 2.0
const TWIST := 2.0
const SHADE_FLOOR := 0.78        # kollar arası oluk yalnız hafif koyulaşsın (0.58 çok sertti)
const SHADE_RANGE := 0.22

@export var low_height: float = 0.20    # yer hizası süpürme (üstünden zıpla) — halat kalın,
                                        # ekseni biraz yukarıda ki alt yüzü yerde otursun
@export var high_height: float = 1.15   # yüksek süpürme (altından eğil)

var rope: Rope

var _radius := 9.0
var _prev_angle: float = 0.0
var _curr_angle: float = 0.0
var _height_y := 0.15

var _lag := PackedFloat32Array()        # halka başına açısal gecikme (yerel radyan)
var _lag_vel := PackedFloat32Array()
var _y := PackedFloat32Array()          # halka başına yükseklik
var _y_vel := PackedFloat32Array()
var _sway := 1.0                        # tur fazına bağlı kamçı ÇARPANI (şekli bozmaz, büyütür)

var _mm: MultiMesh
var _shadow_mm: MultiMesh
var _tip: MeshInstance3D


func _ready() -> void:
	_radius = float(Config.ring.get("r_max", 9.0))
	_height_y = low_height
	_init_chain()
	_build()


## Arena gerçek çember yarıçapını bildirir (dev sahneleri varsayılanı kullanır).
func set_radius(r: float) -> void:
	_radius = r


func bind(logic_rope: Rope) -> void:
	rope = logic_rope
	_prev_angle = rope.angle
	_curr_angle = rope.angle
	_init_chain()


## Sürücü her mantık tick'inden sonra çağırır (önceki→şimdiki açı interpolasyon için saklanır).
func on_logic_step() -> void:
	if rope == null:
		return
	_prev_angle = _curr_angle
	_curr_angle = rope.angle
	_height_y = high_height if rope.height == Rope.Height.HIGH else low_height


func _init_chain() -> void:
	_lag.resize(SEGMENTS + 1)
	_lag_vel.resize(SEGMENTS + 1)
	_y.resize(SEGMENTS + 1)
	_y_vel.resize(SEGMENTS + 1)
	_sway = 1.0
	for i in SEGMENTS + 1:
		_lag[i] = 0.0
		_lag_vel[i] = 0.0
		_y[i] = _height_y
		_y_vel[i] = 0.0


# ---------------------------------------------------------------- geometri

func _build() -> void:
	# Merkez göbeği: ipin bir yere bağlı olduğu okunsun (yoksa havada dönen çubuk gibi duruyor).
	var hub := CylinderMesh.new()
	hub.top_radius = 0.34
	hub.bottom_radius = 0.42
	hub.height = 0.3
	hub.radial_segments = 12
	hub.rings = 1
	_add(hub, _flat(C_HUB), Vector3(0.0, 0.15, 0.0))

	# Halat gövdesi: birim silindir + burgu dokusu; her parça kendi ölçek+yönüyle yerleşir.
	var seg := CylinderMesh.new()
	seg.top_radius = 1.0
	seg.bottom_radius = 1.0
	seg.height = 1.0
	seg.radial_segments = 10
	seg.rings = 1
	seg.cap_top = false          # uçları göbek ve düğüm kapatıyor; kapaklar UV'yi bozardı
	seg.cap_bottom = false
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = seg
	_mm.instance_count = SEGMENTS
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_texture = _rope_texture()
	rope_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rope_mat.roughness = 1.0
	# ⚠ Parçalar uçları AÇIK boru (kapaklar UV'yi bozuyor, o yüzden kapalılar). İp tam
	# kameraya doğru gelince borunun içine bakılıyor ve arka yüzler ayıklandığı için ip
	# GÖRÜNMEZ oluyordu (Samet: "görüş açımla dik gelince yok oluyor"). Arka yüzleri de
	# çizince boru her açıdan dolu görünür.
	rope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = rope_mat
	add_child(mmi)

	# Uçtaki düğüm topu.
	var knot := SphereMesh.new()
	knot.radius = THICK * 1.55
	knot.height = THICK * 3.1
	knot.radial_segments = 10
	knot.rings = 6
	_tip = _add(knot, _flat(C_STRAND_A), Vector3.ZERO)

	# Süpürme gölgesi: aynı eğriyi yerde takip eden yassı parçalar (§4.3 okunurluk).
	var quad := BoxMesh.new()
	quad.size = Vector3.ONE
	_shadow_mm = MultiMesh.new()
	_shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shadow_mm.mesh = quad
	_shadow_mm.instance_count = SEGMENTS
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.0, 0.0, 0.0, 0.45)   # zemin koyu asfalt — gölge güçlü olmalı
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var smmi := MultiMeshInstance3D.new()
	smmi.multimesh = _shadow_mm
	smmi.material_override = smat
	smmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smmi)


## Burgulu halat dokusu — silindirin UV'sinde köşegen bantlar. u çevre, v uzunluk yönü;
## g = u*STRANDS + v*TWIST sabit olan yerler bir kolun sırtıdır. İki tonlu bantlar +
## bant içinde parlaklık eğrisi (kollar arası oluk) → burgu hissi.
func _rope_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	for yy in n:
		var v := float(yy) / float(n)
		for xx in n:
			var u := float(xx) / float(n)
			var g: float = u * STRANDS + v * TWIST
			var s: float = g - floor(g)                   # kol içindeki konum 0..1
			var base := C_STRAND_A if int(floor(g)) % 2 == 0 else C_STRAND_B
			# Kol ortası aydınlık, kenarları (oluk) koyu.
			var shade := SHADE_FLOOR + SHADE_RANGE * sin(PI * s)
			img.set_pixel(xx, yy, Color(base.r * shade, base.g * shade, base.b * shade))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


# ---------------------------------------------------------------- her kare

func _process(delta: float) -> void:
	if rope == null:
		return
	# İki mantık tick'i arasındaki kesir kadar interpolasyon → 60 tick'te bile akıcı dönüş.
	var f := Engine.get_physics_interpolation_fraction()
	var true_angle := lerp_angle(_prev_angle, _curr_angle, f)
	rotation.y = true_angle          # zincir faz itişini buradan okur
	# Kare atlamalarında zincir patlamasın: adımı sınırla ve 3 alt adıma böl.
	var dt := clampf(delta, 0.0, 1.0 / 20.0) / 3.0
	for _i in 3:
		_step_chain(dt)
	_apply_rotation(true_angle)
	_lay_out()


## Zincir dinamiği: her halka bir öncekini gecikmeyle takip eder, kendi ataleti vardır.
## Göbek (i=0) sabit sürücüdür. Hız değişince kıvrım uca doğru dalga hâlinde yürür.
func _step_chain(dt: float) -> void:
	if dt <= 0.0:
		return
	var w: float = rope.angular_vel
	var high := rope.height == Rope.Height.HIGH
	_lag[0] = 0.0
	_lag_vel[0] = 0.0
	_y[0] = _height_y
	_y_vel[0] = 0.0
	# Dönüşün her turunda bir kez değişen salınım (eğik süpürme düzlemi + çeviren elin dairesi).
	var theta: float = rotation.y
	var sway_target: float = 1.0 + SWAY_REL * sin(theta) + SWAY_REL2 * sin(theta * 2.0 + 1.1)
	_sway += (sway_target - _sway) * clampf(SWAY_FOLLOW * dt, 0.0, 1.0)
	# Geri kalma: sürükleme yönü hıza ters; miktarı 1/|ω| (merkezkaç gerilmesi düzleştirir).
	var lag_drive: float = -signf(w) * LAG_K / maxf(absf(w), W_FLOOR) \
		* clampf(absf(w) / LAG_RAMP_W, 0.0, 1.0)
	# Sarkma: yerçekimi ÷ merkezkaç gerilmesi ~ g/(ω²·L). Hızlı → düz, yavaş → sarkık.
	var max_sag: float = SAG_MAX_HIGH if high else SAG_MAX_LOW
	var sag: float = clampf(SAG_K / maxf(w * w, SAG_W_FLOOR), 0.0, max_sag) \
		* (1.0 - SWAY_SAG_MIX + SWAY_SAG_MIX * _sway)
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		# Açısal: hedef = bir önceki halka + geri kalma. Geri kalma yarıçapla (t) orantılı →
		# kıvrım karesel, yani gerçek kavis; ayrıca tur fazına göre nefes alır.
		var target: float = _lag[i - 1] + lag_drive * t
		var acc: float = (target - _lag[i]) * STIFF \
			- _lag_vel[i] * DAMP + (_lag_vel[i - 1] - _lag_vel[i]) * REL_DAMP
		_lag_vel[i] += acc * dt
		var next_lag: float = _lag[i] + _lag_vel[i] * dt
		# SERT SINIR: komşudan bu kadar ayrılamaz → zincir hiçbir koşulda dağılamaz.
		next_lag = clampf(next_lag, _lag[i - 1] - MAX_DELTA_LAG, _lag[i - 1] + MAX_DELTA_LAG)
		next_lag = clampf(next_lag, -MAX_LAG, MAX_LAG)
		if next_lag != _lag[i] + _lag_vel[i] * dt:
			_lag_vel[i] = 0.0            # sınıra çarptı: hızı yut, yoksa sınırda birikir
		_lag[i] = next_lag
		# Dikey: sarkma her zaman AŞAĞI (dünya −Y), miktarı hıza bağlı; zincirden yayılır.
		var y_target: float = _height_y - sag * sin(PI * t)
		var y_acc: float = (y_target - _y[i]) * Y_STIFF \
			- _y_vel[i] * Y_DAMP + (_y_vel[i - 1] - _y_vel[i]) * REL_DAMP
		_y_vel[i] += y_acc * dt
		var next_y: float = _y[i] + _y_vel[i] * dt
		next_y = clampf(next_y, _y[i - 1] - MAX_DELTA_Y, _y[i - 1] + MAX_DELTA_Y)
		if next_y != _y[i] + _y_vel[i] * dt:
			_y_vel[i] = 0.0
		_y[i] = next_y


## Çizilen kıvrım: gerçek KAMÇI eğrisi — uç, gidiş yönünün TERSİNE en çok geride kalan
## yerdir; kıvrım göbekten uca doğru tek yönde artar (S yapmaz).
##
## Şekil için ucu ipin mantıksal açısına sabitlemek YANLIŞ oldu (denendi): kavis ortaya
## itiliyor ve ip S'e dönüyor. Doğrusu şekli bozmadan bırakıp TÜM ipi, ucun geride kaldığı
## kadar İLERİ döndürmek — bunu _apply_rotation yapar. Böylece hem eğri fiziksel olarak
## doğru, hem de ucun dünya açısı ipin gerçek açısı.
##
## Ucun gerçek açıda kalması OYUN ADALETİ meselesidir, estetik değil: crossing matematiği
## ipi tek bir açı olarak görür. Uç görselde geride kalsaydı oyuncu ipi bulunduğu yerden
## 30-50° farklı görürdü — bu, zamanlama penceresinin (±90-160 ms) tamamı kadar sapma —
## ve "ip bana gelmemişti ama elendim" derdi.
func bend_at(i: int) -> float:
	return _lag[i] * _bend_scale()


## Faz çarpanı + üst sınır. Sınır TÜM eğriye orantılı uygulanır, böylece şekil bozulmaz.
func _bend_scale() -> float:
	var s: float = _sway
	var tip: float = absf(_lag[SEGMENTS] * s)
	if tip > MAX_BEND:
		s *= MAX_BEND / tip
	return s


## İpi çiz: uç, ipin gerçek (mantıksal) açısında dursun diye tüm gövde kamçı kadar ileri döner.
func _apply_rotation(true_angle: float) -> void:
	rotation.y = true_angle - bend_at(SEGMENTS)


## i numaralı ipin noktasının DÜNYA konumu — yani ekranda gerçekten çizilen yer.
## Ölçüm bunun üzerinden yapılmalı: iç değişkenler doğru görünürken çizim ters/sabit olabilir
## (nitekim öyle oldu — yerel eğri +Z'de kurulmuştu, dönüş −Z'ye taşıyordu).
func point_world(i: int) -> Vector3:
	var t := float(i) / float(SEGMENTS)
	var r: float = lerpf(INNER_R, _radius, t)
	var a := bend_at(i)
	return to_global(Vector3(cos(a) * r, _y[i], -sin(a) * r))


## Zincirin o anki hâlini geometriye yaz. Yerel uzayda +X yönünde uzanır; kök node zaten
## dönmüş durumda, gecikme burada YEREL açı kayması olarak uygulanır.
func _lay_out() -> void:
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var r: float = lerpf(INNER_R, _radius, t)
		var a := bend_at(i)
		# ⚠ z BİLEREK NEGATİF: Godot'ta rotation.y pozitifken yerel +X, −Z'ye döner. Eğriyi
		# +Z yönünde kurunca kıvrım ters elle çıkıyor ve uç, geride kalacağına ÖNDE gidiyordu
		# (Samet: "yamukluğu terse çevir"). Bu işaret, kamçının doğru yöne bakmasını sağlar.
		pts.append(Vector3(cos(a) * r, _y[i], -sin(a) * r))

	for i in SEGMENTS:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		_mm.set_instance_transform(i, _segment_xform(p0, p1, THICK))
		# Gölge: aynı parça yerde, yassı ve biraz geniş (ip yükseldikçe genişler).
		var flat0 := Vector3(p0.x, 0.03, p0.z)
		var flat1 := Vector3(p1.x, 0.03, p1.z)
		var spread: float = 1.0 + ((p0.y + p1.y) * 0.5 - low_height) * 0.5
		_shadow_mm.set_instance_transform(i, _shadow_box_xform(flat0, flat1, 0.28 * spread))
	_tip.position = pts[SEGMENTS]


## p0→p1 arasına uzanan silindir (silindirin ekseni Y'dir, o yüzden Y'yi yöne oturtuyoruz).
func _segment_xform(p0: Vector3, p1: Vector3, thick: float) -> Transform3D:
	var d := p1 - p0
	var seg_len := d.length()
	if seg_len < 0.0001:
		# Sıfır ölçek MultiMesh'te saklanmıyor (geri okununca 1 çıkıyor) → çok küçük ölçek
		# ve kadraj dışı konum birlikte kullanılır.
		return Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0.0, -10000.0, 0.0))
	var up := d / seg_len
	var side := Vector3.UP.cross(up)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var fwd := up.cross(side).normalized()
	var basis := Basis(side, up, fwd) * Basis.from_scale(Vector3(thick, seg_len * 1.06, thick))
	return Transform3D(basis, (p0 + p1) * 0.5)


## Yerdeki gölge parçası: yassı kutu, uzun ekseni Z, ipin izdüşümüne hizalı.
func _shadow_box_xform(p0: Vector3, p1: Vector3, width: float) -> Transform3D:
	var d := p1 - p0
	var seg_len := Vector2(d.x, d.z).length()
	if seg_len < 0.0001:
		# Sıfır ölçek MultiMesh'te saklanmıyor (geri okununca 1 çıkıyor) → çok küçük ölçek
		# ve kadraj dışı konum birlikte kullanılır.
		return Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0.0, -10000.0, 0.0))
	var yaw := atan2(d.x, d.z)
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width, 0.02, seg_len * 1.1))
	return Transform3D(basis, (p0 + p1) * 0.5)
