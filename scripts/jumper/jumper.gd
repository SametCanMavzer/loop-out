class_name Jumper extends Node3D
## Zıplayıcı (TDD §3.4). InputSource'tan komut alır, tick-deterministik zıplama/eğilme
## durum makinesini işletir. Rope'un crossing hedefi budur (is_airborne/jump_input_tick/
## is_ducking/is_alive/angle_pos/id alanlarını okur). Autoload'a bağlı DEĞİL: zamanlama
## JumperTuning ile enjekte edilir (F5 Config'ten kurar).

const CLEAR_LO := 0.12        # kalkışın ilk %12'si henüz yeterince yüksek değil
const CLEAR_HI := 0.88        # son %12'de inişe geçilmiştir

var id: int = 0
var angle_pos: float = 0.0    # çemberdeki açısal konum (§4.4)

# Rope crossing'in okuduğu durum (§4.3)
var is_alive: bool = true
var is_airborne: bool = false
## İpin altından geçebilecek YÜKSEKLİKTE misin? (Model A sıkı sürüm — Samet kararı)
## Havada olmak yetmez: zıplamanın ilk %CLEAR_LO'luk kalkışı ve son %CLEAR_HI sonrası inişi
## güvenli değildir. Çok erken zıplayıp inişe geçmişsen ip seni yakalar.
var is_clear: bool = false
var is_ducking: bool = false
var jump_input_tick: int = -1   # son zıplama başlangıcı (crossing delta'sı bunu kullanır)

# Sendeleme (§4.5) — F5'te kullanılır, burada yalnız taşınır
var has_warning: bool = false
var pardon_counter: int = 0

var input_source: InputSource
var _t: JumperTuning = JumperTuning.new()

# Dahili durum
var _jump_held: bool = false          # fiziksel buton durumu (tampon için)
var _current_jump_held: bool = false  # BU zıplama başından beri kesintisiz basılı mı (hold→high için)
var _jump_high: bool = false
var _pending_jump_tick: int = -1   # havadayken basılan zıplama (input buffer)
var _duck_held: bool = false
var _duck_release_tick: int = -1


func setup(source: InputSource, tuning: JumperTuning) -> void:
	input_source = source
	_t = tuning


## Bir simülasyon tick'i: komutları uygula, ardından durumu güncelle. F5 her tick çağırır.
func tick(current_tick: int) -> void:
	if not is_alive:
		return
	if input_source != null:
		for cmd in input_source.poll(current_tick):
			_apply(cmd, current_tick)
	_update_state(current_tick)


func _apply(cmd: InputCommand, ct: int) -> void:
	match cmd.action:
		&"jump":
			if cmd.pressed:
				_jump_held = true
				if not is_airborne:
					_start_jump(ct, true)
				else:
					_pending_jump_tick = ct   # tampon: inişte yeniden zıpla (mevcut zıplamayı etkilemez)
			else:
				_jump_held = false
				_current_jump_held = false
		&"duck":
			if cmd.pressed:
				_duck_held = true
				is_ducking = true
				_duck_release_tick = -1
			else:
				_duck_held = false
				_duck_release_tick = ct


## Yüksek zıplama aktif mi (yalnız görsel/geri bildirim; mantık zaten air ile işler).
func is_high() -> bool:
	return is_airborne and _jump_high


func _start_jump(ct: int, held: bool) -> void:
	is_airborne = true
	jump_input_tick = ct
	_jump_high = false
	_current_jump_held = held


func _update_state(ct: int) -> void:
	# Hold → yüksek zıplama (§6: geç karar, oyuncu lehine). Havada + basılı + eşik aşıldıysa yükselt.
	if is_airborne and _current_jump_held and not _jump_high:
		if ct - jump_input_tick >= _t.hold_threshold:
			_jump_high = true

	# Havadaki yükseklik penceresi (Model A sıkı): yalnız yayın ortasında ip altından geçilir.
	if is_airborne:
		var air_ticks := _t.high_jump_air if _jump_high else _t.jump_air
		var frac := float(ct - jump_input_tick) / float(maxi(air_ticks, 1))
		is_clear = frac >= CLEAR_LO and frac <= CLEAR_HI
	else:
		is_clear = false

	# İniş
	if is_airborne:
		var air := _t.high_jump_air if _jump_high else _t.jump_air
		if ct - jump_input_tick >= air:
			is_airborne = false
			# Tamponlanmış zıplama penceresi içindeyse hemen yeniden zıpla (§4.3 input buffer)
			if _pending_jump_tick >= 0 and ct - _pending_jump_tick <= _t.input_buffer:
				_pending_jump_tick = -1
				_start_jump(ct, _jump_held)   # inişte hâlâ basılıysa yeni zıplama high olabilir
			else:
				_pending_jump_tick = -1

	# Eğilme çıkış toleransı (§6: basılı süre + duck_release)
	if is_ducking and not _duck_held and _duck_release_tick >= 0:
		if ct - _duck_release_tick >= _t.duck_release:
			is_ducking = false
			_duck_release_tick = -1
