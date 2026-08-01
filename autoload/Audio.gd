extends Node
## Ses sistemi (TDD §8). Bus: Master → Music, SFX (§8.1). Ayarlardaki "ses" toggle'ı = Master mute.
## SFX: 8 AudioStreamPlayer havuzu, round-robin (§8.2). Müzik: pitch_scale = rpm/start_rpm (§8.3).
## Sesler şimdilik prosedürel placeholder (SfxGen) — F14'te CC0 kayıtlarla değişir, API aynı kalır.

const POOL_SIZE := 8
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _sfx: Dictionary = {}          # StringName -> AudioStream
var _music: AudioStreamPlayer
var _music_base_pitch := 1.0
var _enabled := true


func _ready() -> void:
	_setup_buses()
	_build_library()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = String(BUS_SFX)
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = String(BUS_MUSIC)
	_music.stream = SfxGen.music_loop()
	add_child(_music)


## Master → Music, SFX (§8.1). Bus'lar yoksa çalışma zamanında kurulur (proje ayarı gerekmez).
func _setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(String(bus_name)) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, String(bus_name))
			AudioServer.set_bus_send(idx, "Master")


func _build_library() -> void:
	_sfx = {
		&"whoosh": SfxGen.whoosh(),
		&"perfect": SfxGen.perfect(),
		&"graze": SfxGen.graze(),
		&"stumble": SfxGen.stumble(),
		&"eliminate": SfxGen.eliminate(),
		&"telegraph": SfxGen.telegraph(),
		&"pardon": SfxGen.pardon(),
		&"coin": SfxGen.coin(),
	}


## SFX çal (§8.2). pitch_var: ±oran rastgele perde sapması (kozmetik → Rng.cosmetic).
func play(sfx_name: StringName, pitch_var: float = 0.0) -> void:
	if not _enabled or not _sfx.has(sfx_name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _sfx[sfx_name]
	p.pitch_scale = 1.0 + (Rng.cosmetic.randf_range(-pitch_var, pitch_var) if pitch_var > 0.0 else 0.0)
	p.play()


func start_music() -> void:
	if _enabled and _music != null and not _music.playing:
		_music.play()


func stop_music() -> void:
	if _music != null:
		_music.stop()


## İp hızıyla tempo/perde birlikte yükselir (§8.3 E8 kararı).
func set_music_speed(current_rpm: float, start_rpm: float) -> void:
	if _music == null or start_rpm <= 0.0:
		return
	_music.pitch_scale = clampf(current_rpm / start_rpm, 0.5, 2.5) * _music_base_pitch


## Ayarlardaki tek "ses" toggle'ı = Master mute (§8.1, ayrı slider yok).
func set_enabled(on: bool) -> void:
	_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)
	if not on:
		stop_music()
	else:
		start_music()


func is_enabled() -> bool:
	return _enabled
