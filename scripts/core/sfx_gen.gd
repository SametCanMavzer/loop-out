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


## Ritmik müzik loop'u (placeholder, §8.3): chiptune groove — kick/snare/hihat + minör
## pentatonik bass ostinato + hafif arp. Melodik motif kasten kısa/ritmik tutuldu ki
## pitch_scale ile hızlanınca (gerilim) çirkinleşmesin.
## 16 adım/bar (16'lık grid). Sesler "voice" olarak yazılır → üretim hızlı.
static func music_loop(bars: int = 4, bpm: float = 132.0) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var step_s := beat * 0.25                      # 16'lık
	var steps_per_bar := 16
	var total_steps := steps_per_bar * bars
	var n := int(RATE * step_s * total_steps)
	var out := PackedFloat32Array(); out.resize(n)

	# Desenler (1 bar, 16 adım). Sürükleyici ama basit bir groove.
	var kick  := [1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0]
	var snare := [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]
	var hat   := [1,0,1,1, 1,0,1,0, 1,0,1,1, 1,0,1,1]
	var open  := [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0]   # açık hihat vurgusu
	# A minör pentatonik bass (A2 C3 D3 E3 G3) — bar başına farklı kök.
	var roots := [110.00, 98.00, 130.81, 82.41]         # A2, G2, C3, E2
	var bass_hits := [1,0,0,1, 0,0,1,0, 1,0,0,1, 0,1,0,0]
	# Arp: kökün 5'lisi/oktavı, seyrek — melodi değil renk.
	var arp_hits := [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,1]

	var rng := RandomNumberGenerator.new(); rng.seed = 9

	for s_i in total_steps:
		var bar := int(s_i / steps_per_bar)
		var st := s_i % steps_per_bar
		var at := int(s_i * step_s * RATE)
		var root: float = roots[bar % roots.size()]
		if kick[st] == 1:
			_voice_kick(out, at)
		if snare[st] == 1:
			_voice_snare(out, at, rng)
		if hat[st] == 1:
			_voice_hat(out, at, rng, open[st] == 1)
		if bass_hits[st] == 1:
			_voice_bass(out, at, root, step_s * 1.6)
		if arp_hits[st] == 1:
			_voice_arp(out, at, root * 3.0, step_s * 0.9)

	var s := _make(out)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s


static func _add(buf: PackedFloat32Array, at: int, i: int, v: float) -> void:
	var idx := at + i
	if idx >= 0 and idx < buf.size():
		buf[idx] = clampf(buf[idx] + v, -1.0, 1.0)


## Kick: 140→45 Hz sweep + tık; punch için hızlı exp zarf.
static func _voice_kick(buf: PackedFloat32Array, at: int) -> void:
	var n := int(RATE * 0.16)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := lerpf(140.0, 45.0, pow(k, 0.35))
		phase += TAU * f / RATE
		var click := (1.0 - k) if k < 0.02 else 0.0
		_add(buf, at, i, (sin(phase) * pow(1.0 - k, 2.2) + click * 0.3) * 0.85)


## Snare: gürültü + gövde tonu.
static func _voice_snare(buf: PackedFloat32Array, at: int, rng: RandomNumberGenerator) -> void:
	var n := int(RATE * 0.13)
	var phase := 0.0
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var k := float(i) / float(n)
		var noise := rng.randf_range(-1.0, 1.0)
		hp = noise - prev                            # basit yüksek geçiren → çıtırtı
		prev = noise
		phase += TAU * 185.0 / RATE
		_add(buf, at, i, (hp * 0.55 + sin(phase) * 0.35) * pow(1.0 - k, 3.0) * 0.5)


## Hihat: çok kısa parlak gürültü (açık varyantı daha uzun).
static func _voice_hat(buf: PackedFloat32Array, at: int, rng: RandomNumberGenerator, is_open: bool) -> void:
	var n := int(RATE * (0.09 if is_open else 0.03))
	var prev := 0.0
	for i in n:
		var k := float(i) / float(n)
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		_add(buf, at, i, hp * pow(1.0 - k, 2.5) * (0.16 if is_open else 0.12))


## Bass: kare dalga (chiptune) + hafif alçak geçiren yumuşatma.
static func _voice_bass(buf: PackedFloat32Array, at: int, freq: float, dur: float) -> void:
	var n := int(RATE * dur)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / float(n)
		phase += TAU * freq / RATE
		var sq := 1.0 if sin(phase) >= 0.0 else -1.0
		lp = lerpf(lp, sq, 0.35)
		var env := minf(k / 0.02, 1.0) * pow(1.0 - k, 1.2)
		_add(buf, at, i, lp * env * 0.30)


## Arp: kısa üçgen dalga rengi (melodi değil vurgu).
static func _voice_arp(buf: PackedFloat32Array, at: int, freq: float, dur: float) -> void:
	var n := int(RATE * dur)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		phase += TAU * freq / RATE
		var tri := asin(sin(phase)) * (2.0 / PI)     # üçgen
		_add(buf, at, i, tri * pow(1.0 - k, 3.0) * 0.14)


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
