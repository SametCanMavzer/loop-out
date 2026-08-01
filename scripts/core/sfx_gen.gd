class_name SfxGen extends RefCounted
## Prosedürel PLACEHOLDER sesler (kodla üretilen AudioStreamWAV) — dosya bağımlılığı yok.
## F14'te gerçek CC0 kayıtlarıyla (Kenney/freesound, §15.3) değiştirilecek; Audio API'si aynı kalır.
## Amaç: ses sistemini (havuz, metronom, pitch bağlama) dosya beklemeden çalıştırıp test etmek.

const RATE := 22050


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


static func _env(i: int, n: int, attack: float = 0.02) -> float:
	var t := float(i) / float(n)
	var a := minf(t / maxf(attack, 0.001), 1.0)
	return a * pow(1.0 - t, 2.0)


## "Vuş" — ipin süpürme sesi (metronom, GDD §8). Filtrelenmiş gürültü + düşen zarf.
static func whoosh(dur: float = 0.16) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var out := PackedFloat32Array(); out.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var lp := 0.0
	for i in n:
		var noise := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.25)                    # alçak geçiren → "hava" hissi
		out[i] = lp * _env(i, n, 0.08) * 0.55
	return _make(out)


## Perfect — parlak kısa "ding" (iki uyumlu ton).
static func perfect() -> AudioStreamWAV:
	return _tone_pair(880.0, 1320.0, 0.18, 0.4)


## Graze — daha boğuk, orta ton.
static func graze() -> AudioStreamWAV:
	return _tone_pair(520.0, 660.0, 0.14, 0.32)


## Sendeleme/ıskalama — düşük buzz.
static func stumble() -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(220.0, 120.0, float(i) / float(n))
		var saw := fmod(t * f, 1.0) * 2.0 - 1.0        # testere → sert/uyarıcı
		out[i] = saw * _env(i, n, 0.01) * 0.45
	return _make(out)


## Eleme — düşen glissando + "pof".
static func eliminate() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array(); out.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := lerpf(700.0, 90.0, k * k)
		phase += TAU * f / RATE
		var body := sin(phase) * 0.5
		var pof := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - absf(k - 0.75) * 8.0) * 0.5
		out[i] = (body + pof) * _env(i, n, 0.01) * 0.6
	return _make(out)


## Telegraf jingle — çift bip (davranış uyarısı, GDD §8).
static func telegraph() -> AudioStreamWAV:
	var n := int(RATE * 0.2)
	var out := PackedFloat32Array(); out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := 700.0 if k < 0.45 else 1050.0
		var gate := 0.0 if (k > 0.4 and k < 0.5) else 1.0
		phase += TAU * f / RATE
		out[i] = sin(phase) * gate * _env(i, n, 0.01) * 0.4
	return _make(out)


## Af (⚠ silindi) — yükselen iki ton.
static func pardon() -> AudioStreamWAV:
	return _tone_pair(520.0, 780.0, 0.26, 0.35)


## Jeton/ödül — kısa parlak arpej.
static func coin() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var out := PackedFloat32Array(); out.resize(n)
	var freqs := [880.0, 1174.0, 1568.0]
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var idx := mini(int(k * 3.0), 2)
		phase += TAU * float(freqs[idx]) / RATE
		out[i] = sin(phase) * _env(i, n, 0.01) * 0.35
	return _make(out)


## Ritmik müzik loop'u (placeholder): basit kick+hihat deseni. pitch_scale ile hızlanır (§8.3).
static func music_loop(bars: int = 2, bpm: float = 120.0) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var n := int(RATE * beat * 4.0 * bars)
	var out := PackedFloat32Array(); out.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var step := int(RATE * beat * 0.5)              # 8'lik
	for i in n:
		var pos := i % step
		var step_idx := int(i / step) % 8
		var k := float(pos) / float(step)
		var v := 0.0
		if step_idx % 4 == 0:                        # kick
			v += sin(TAU * lerpf(120.0, 45.0, k) * float(pos) / RATE) * pow(1.0 - k, 3.0) * 0.7
		if step_idx % 2 == 1:                        # hihat
			v += rng.randf_range(-1.0, 1.0) * pow(1.0 - k, 12.0) * 0.18
		out[i] = v
	var s := _make(out)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s


static func _tone_pair(f1: float, f2: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var out := PackedFloat32Array(); out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var k := float(i) / float(n)
		p1 += TAU * f1 / RATE
		p2 += TAU * f2 / RATE
		var second := 0.0 if k < 0.35 else 1.0       # ikinci ton biraz gecikir
		out[i] = (sin(p1) * 0.6 + sin(p2) * 0.5 * second) * _env(i, n, 0.005) * vol
	return _make(out)
