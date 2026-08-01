extends Node
## Reklam katmanı (TDD §12.3). Platformu tespit eder, uygun AdsService'i seçer ve oyun
## koduna tek arayüz sunar. Portal farkları adaptörlerde (PokiAds/CrazyAds/NullAds).
##
## Poki/CrazyGames zorunluluğu: gameplayStart/Stop event'leri EventBus.round_started ve
## round_ended'a BURADA bağlanır — oyun kodunun bunu hatırlaması gerekmez, unutulursa
## başvuru reddedilirdi.

signal rewarded_finished(success: bool)

var _service: AdsService = AdsService.new()
var _pending := false


func _ready() -> void:
	_service = _detect_service()
	EventBus.round_started.connect(func(_r: int, _s: int) -> void: _service.gameplay_start())
	EventBus.round_ended.connect(func(_p: int, _c: int) -> void: _service.gameplay_stop())
	if OS.is_debug_build():
		print("[Ads] servis: %s (rewarded: %s)" % [_service.service_name(), str(_service.has_rewarded())])


## Platform tespiti (§12.3): export feature tag + barındırma alan adı.
## itch/localhost/masaüstü → NullAds (rewarded yok, UI ×2 butonu gizlenir).
func _detect_service() -> AdsService:
	if not OS.has_feature("web"):
		return AdsService.new()
	var host := ""
	var h: Variant = JavaScriptBridge.eval("window.location.hostname", true)
	if typeof(h) == TYPE_STRING:
		host = String(h).to_lower()
	if OS.has_feature("poki") or host.contains("poki"):
		var p := PokiAds.new()
		if p.has_rewarded():
			return p
	if OS.has_feature("crazygames") or host.contains("crazygames") or host.contains("1001juegos"):
		var c := CrazyAds.new()
		if c.has_rewarded():
			return c
	# SDK yoksa (itch, kendi sunucu, localhost) sessizce Null'a düş.
	return AdsService.new()


func gameplay_start() -> void:
	_service.gameplay_start()


func gameplay_stop() -> void:
	_service.gameplay_stop()


## Ödüllü reklam iste (GDD §6.2 "jeton ×2"). Sonuç `rewarded_finished` ile de yayılır.
## Aynı anda tek istek: ikinci çağrı sessizce reddedilir (çift ödül koruması).
const REWARD_TIMEOUT_S := 90.0     # SDK hiç yanıt vermezse kilit açılsın

func rewarded(cb: Callable = Callable()) -> void:
	if _pending:
		if cb.is_valid():
			cb.call(false)
		return
	_pending = true
	Analytics.track(&"rewarded", {"shown": true, "completed": false})
	Audio.push_mute()                # portal kuralı: reklam boyunca oyun sesi kısılır
	var done := {"v": false}
	var finish := func(ok: bool) -> void:
		if done.v:
			return                   # SDK hem callback hem timeout'u tetiklerse çift ödül olmasın
		done.v = true
		_pending = false
		Audio.pop_mute()
		Analytics.track(&"rewarded", {"shown": true, "completed": ok})
		if cb.is_valid():
			cb.call(ok)
		rewarded_finished.emit(ok)
	_service.rewarded(finish)
	# Emniyet: JS tarafı hiç geri dönmezse (SDK hatası) reklam kilidi kalıcı olmasın.
	if _pending:
		var t := get_tree().create_timer(REWARD_TIMEOUT_S, true, false, true)
		t.timeout.connect(func() -> void: finish.call(false))


func commercial_break(cb: Callable = Callable()) -> void:
	_service.commercial_break(cb)


func has_rewarded() -> bool:
	return _service.has_rewarded()


func service_name() -> String:
	return _service.service_name()


## Yalnız testler için: servisi elle değiştir.
func _set_service_for_test(s: AdsService) -> void:
	_service = s
	_pending = false
