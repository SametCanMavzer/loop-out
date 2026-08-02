extends RefCounted
## İp görselinin zincir dinamiği KARARLI mı? (F14 cila)
##
## Neden test var: zincirin her halkası bir öncekini takip ediyor. Sönüm kritik değerin
## altındayken her halkanın rezonans kazancı 1'den büyük oluyor ve en ufak sarsıntı 30 halka
## boyunca katlanarak büyüyor — ip ekranda paramparça bir yıldız gibi görünüyordu (gerçekten
## yaşandı). Gözle "düzeldi" demek yetmez; burada ÖLÇÜLÜYOR.
##
## Test, ipin en zorlanacağı senaryoyu koşturur: hızlanma, ani duruş, ters dönüş, LOW↔HIGH
## geçişleri — ve her karede zincirin düzgün kaldığını doğrular.
## (godot --headless scenes/dev/run_tests.tscn -- test_rope_visual)

const FRAMES := 900
const DT := 1.0 / 60.0


func run(tree: SceneTree) -> int:
	var fail := 0
	var host := Node3D.new()
	tree.root.add_child(host)
	var rope := Rope.new()
	var viz := RopeVisual.new()
	host.add_child(viz)          # _ready() burada koşar (meshleri kurar)
	viz.set_radius(9.0)
	viz.bind(rope)

	var max_delta := 0.0
	var max_bend := 0.0
	var bad_number := false

	# --- A) SABİT hızda dön: kıvrım tur boyunca DEĞİŞMELİ ---
	# Samet'in şikâyeti: "yamuk duruyor ama hep sabit, döndürünce değişmiyor". Sabit hızda
	# şekil de sabit kalırsa ip dönen bükük çubuk gibi görünür. Süpürme düzleminin eğikliği
	# (PHASE_DRIVE) tur başına bir kez kıvrımı nefes aldırır — burada ölçülüyor.
	rope.angular_vel = 2.6
	rope.height = Rope.Height.LOW
	viz.on_logic_step()
	for f in 240:                       # önce yerleşsin
		viz.rotation.y += 2.6 * DT
		viz._step_chain(DT)
	var tip_min := 999.0
	var tip_max := -999.0
	var s_shape := false
	for f in 360:                       # ~2.5 tur gözlem
		viz.rotation.y += 2.6 * DT
		viz._step_chain(DT)
		var tip: float = absf(viz.bend_at(RopeVisual.SEGMENTS))
		tip_min = minf(tip_min, tip)
		tip_max = maxf(tip_max, tip)
		# Kamçı eğrisi TEK YÖNLÜ olmalı: kıvrım göbekten uca doğru hep aynı yönde artmalı.
		# Yön değiştirirse ip S'e döner — Samet'in reddettiği şekil buydu.
		var sign_ref := signf(viz.bend_at(RopeVisual.SEGMENTS))
		var prev := 0.0
		for i in range(1, RopeVisual.SEGMENTS + 1):
			var b: float = viz.bend_at(i)
			if signf(b - prev) == -sign_ref and absf(b - prev) > 0.002:
				s_shape = true
			prev = b
	var breathe := tip_max - tip_min
	if tip_max < 0.20:
		push_error("FAIL: ipin ucu geride kalmıyor (%.3f) — çubuk gibi duruyor." % tip_max)
		fail += 1
	if s_shape:
		push_error("FAIL: kıvrım yön değiştiriyor — ip S şeklinde, kamçı gibi değil."); fail += 1
	# Eşik GÖRÜLEBİLİRLİK eşiği: 0.041 rad (≈2°) ölçüldüğünde ekranda hiç fark edilmiyordu.
	if breathe < 0.18:
		push_error("FAIL: kıvrım tur boyunca değişmiyor (%.4f) — dönen bükük çubuk." % breathe)
		fail += 1

	# --- A2) FİZİK: merkezkaç ↔ yerçekimi oranı ---
	# Hızlı dönen ip GERİLİR: hem sarkması hem geri kalması azalır, neredeyse düz olur.
	# (Eski modelde tam tersiydi: hız arttıkça daha çok bükülüyordu — fiziksel olarak yanlış.)
	viz.rotation.y = 0.0
	rope.height = Rope.Height.HIGH
	var slow_sag := _settle_sag(viz, rope, 1.6)
	var fast_sag := _settle_sag(viz, rope, 7.0)
	if not (slow_sag > fast_sag * 2.0):
		push_error("FAIL: sarkma hıza göre azalmıyor (yavaş %.3f, hızlı %.3f) — g/(ω²L) değil."
			% [slow_sag, fast_sag]); fail += 1
	rope.height = Rope.Height.LOW
	var slow_lag := _settle_lag(viz, rope, 2.0)
	var fast_lag := _settle_lag(viz, rope, 7.0)
	if not (slow_lag > fast_lag * 1.5):
		push_error("FAIL: hızlı ip düzleşmiyor (yavaş %.3f, hızlı %.3f) — merkezkaç gerilmesi yok."
			% [slow_lag, fast_lag]); fail += 1

	# --- B) Zorlu senaryoda kararlılık ---
	for f in FRAMES:
		viz.rotation.y += rope.angular_vel * DT
		# Zorlu senaryo: hızlan → ani dur → ters dön → yüksek süpürme → normale dön.
		var phase := f / 150
		match phase:
			0: rope.angular_vel = 2.6
			1: rope.angular_vel = 6.5                     # speed_step
			2: rope.angular_vel = 0.0                     # sudden_stop
			3: rope.angular_vel = -5.0                    # reverse
			4: rope.angular_vel = -5.0
			_: rope.angular_vel = 3.0
		rope.height = Rope.Height.HIGH if phase == 4 else Rope.Height.LOW
		viz.on_logic_step()
		viz._step_chain(DT)

		var prev_bend := 0.0
		for i in RopeVisual.SEGMENTS + 1:
			var b: float = viz.bend_at(i)
			if not is_finite(b) or not is_finite(viz._y[i]):
				bad_number = true
				break
			if i > 0:
				max_delta = maxf(max_delta, absf(b - prev_bend))
			prev_bend = b
			max_bend = maxf(max_bend, absf(b))
		if bad_number:
			break

	if bad_number:
		push_error("FAIL: zincirde NaN/sonsuz değer — simülasyon patladı."); fail += 1
	# Komşu halkalar birbirinden kopmamalı (kopunca ip 'yıldız' gibi dağılıyordu).
	if max_delta > RopeVisual.MAX_DELTA_LAG + 0.001:
		push_error("FAIL: komşu halka açı farkı sınırı aştı (%.4f > %.4f)."
			% [max_delta, RopeVisual.MAX_DELTA_LAG]); fail += 1
	# Kavis makul kalmalı: ip kendi üstüne dolanmamalı.
	if max_bend > RopeVisual.MAX_BEND + 0.001:
		push_error("FAIL: kavis çok büyük (%.3f > %.3f)." % [max_bend, RopeVisual.MAX_BEND])
		fail += 1
	# UÇ, ipin gerçek açısında ÇİZİLMELİ — yoksa oyuncu ipi olduğu yerden farklı görür
	# (haksız eleme). Şekil kamçı, ama gövde ucun geride kaldığı kadar ileri döndürülür.
	var probe := 1.234
	viz._apply_rotation(probe)
	var tip_world: float = wrapf(viz.rotation.y + viz.bend_at(RopeVisual.SEGMENTS) - probe, -PI, PI)
	if absf(tip_world) > 0.0001:
		push_error("FAIL: ipin ucu gerçek açısında çizilmiyor (%.5f rad sapma)." % tip_world)
		fail += 1

	viz.queue_free()
	host.queue_free()
	if fail == 0:
		print("TEST ROPE VISUAL OK (kamçı %.2f-%.2f rad tek yönlü; sarkma yavaş %.3f → hızlı %.3f; komşu farkı %.4f; uç açısı doğru)"
			% [tip_min, tip_max, slow_sag, fast_sag, max_delta])
	else:
		print("TEST ROPE VISUAL FAILED: %d hata" % fail)
	return fail


## Verilen hızda zincir yerleşene kadar koştur, ortadaki sarkma derinliğini döndür.
func _settle_sag(viz: RopeVisual, rope: Rope, w: float) -> float:
	rope.angular_vel = w
	viz.on_logic_step()
	for f in 200:
		viz._step_chain(DT)
	return viz._y[0] - viz._y[RopeVisual.SEGMENTS / 2]


## Verilen hızda zincir yerleşene kadar koştur, ucun geri kalma açısını döndür.
func _settle_lag(viz: RopeVisual, rope: Rope, w: float) -> float:
	rope.angular_vel = w
	viz.on_logic_step()
	for f in 200:
		viz._step_chain(DT)
	return absf(viz.bend_at(RopeVisual.SEGMENTS))
