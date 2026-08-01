class_name AudioDirector extends Node
## Ses tetikleyicileri tek yerde (TDD §8): EventBus sinyalleri → Audio.play, müzik hız bağlama,
## eleme slow-motion'ı (§4.9). Gameplay kodu ses bilmez; determinizmi etkilemez (yalnız kozmetik).

const SLOWMO_SCALE := 0.3      # §4.9
const SLOWMO_REAL_S := 0.4     # gerçek zaman (time_scale'den bağımsız)

var _controller: ArenaController
var _player_id := 0
var _slowmo_active := false
var _start_rpm := 25.0        # her karede Config sözlüğü aramamak için önbellek (§11 bütçe)


func setup(controller: ArenaController) -> void:
	_controller = controller
	_start_rpm = float(Config.rope.get("start_rpm", 25))
	_controller.rope_swept_front.connect(_on_swept)          # "vuş" metronomu (§8.2)
	EventBus.rope_crossed.connect(_on_crossed)
	EventBus.jumper_stumbled.connect(_on_stumbled)
	EventBus.jumper_pardoned.connect(_on_pardoned)
	EventBus.jumper_eliminated.connect(_on_eliminated)
	EventBus.behavior_telegraphed.connect(_on_telegraphed)
	EventBus.player_eliminated.connect(_on_player_eliminated)
	EventBus.round_ended.connect(_on_round_ended)
	Audio.set_enabled(bool(SaveGame.setting("sound", true)))


func _process(_dt: float) -> void:
	if _controller == null:
		return
	# Müzik temposu ip hızıyla (§8.3): pitch_scale = rpm / start_rpm.
	var rpm := absf(_controller.rope.angular_vel) * 60.0 / TAU
	Audio.set_music_speed(rpm, _start_rpm)


func _on_swept() -> void:
	Audio.play(&"whoosh", 0.06)


func _on_crossed(id: int, result: int, _delta_ms: float) -> void:
	if id != _player_id:
		return                                   # botların sonucu ses yapmaz (gürültü olmasın)
	match result:
		Rope.CrossResult.PERFECT:
			Audio.play(&"perfect", 0.03)
		Rope.CrossResult.GRAZE:
			Audio.play(&"graze", 0.05)


func _on_stumbled(id: int) -> void:
	if id == _player_id:
		Audio.play(&"stumble")
		_vibrate(30)


## Dokunsal geri bildirim (GDD §9 "titreşim" ayarı). Yalnız mobilde ve ayar açıkken.
func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile") and bool(SaveGame.setting("vibration", true)):
		Input.vibrate_handheld(ms)


func _on_pardoned(id: int) -> void:
	if id == _player_id:
		Audio.play(&"pardon")


func _on_eliminated(_id: int, _cause: int) -> void:
	Audio.play(&"eliminate", 0.08)               # her eleme duyulur (kalabalık hissi)


func _on_telegraphed(_behavior_id: StringName) -> void:
	Audio.play(&"telegraph", 0.02)


## Oyuncu elendiğinde kısa slow-motion (§4.9). Tick sayısı değişmez → determinizm korunur.
func _on_player_eliminated(_alive: int) -> void:
	if _slowmo_active:
		return
	_slowmo_active = true
	_vibrate(120)                                # eleme: daha uzun darbe
	Engine.time_scale = SLOWMO_SCALE
	# ignore_time_scale = true → gerçek zamanda 0.4 sn
	await get_tree().create_timer(SLOWMO_REAL_S, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo_active = false


func _on_round_ended(_placement: int, _coins: int) -> void:
	Audio.play(&"coin")


## Sesi aç/kapa — M tuşu (ayarlar ekranı F13'te gelene kadar geçici erişim, §8.1 Master mute).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		var on := not Audio.is_enabled()
		Audio.set_enabled(on)
		SaveGame.set_setting("sound", on)


func _exit_tree() -> void:
	Engine.time_scale = 1.0                      # sahne kapanırken zaman ölçeğini bırakma
