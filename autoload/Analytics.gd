extends Node
## Analitik (TDD §13.4). Event kuyruğu → aktif platform adaptörü.
## Şema (v1'in tamamı):
##   round_start{round, seed} · elimination{round, cause, behavior, delta_ms} · restart{}
##   session_end{rounds} · rewarded{shown, completed} · client_error{msg}
##
## v1 taşıma: Poki/CrazyGames sayfasındaysa portal SDK event'i; değilse yalnız bellek kuyruğu
## (+ debug'da log). Kendi endpoint'i (Supabase POST) V2 — kota/gizlilik işi, kapsam dışı.
## Kuyruk sınırlı: analitik asla belleği şişirmez, hata verirse sessiz düşer.

const MAX_QUEUE := 200
const SCHEMA := {
	&"round_start": ["round", "seed"],
	&"elimination": ["round", "cause", "behavior", "delta_ms"],
	&"restart": [],
	&"session_end": ["rounds"],
	&"rewarded": ["shown", "completed"],
	&"client_error": ["msg"],
}

var _queue: Array = []
var _enabled := true
var _web := false
var _session_rounds := 0


func _ready() -> void:
	_web = OS.has_feature("web")
	EventBus.round_started.connect(func(round_no: int, seed: int) -> void:
		_session_rounds += 1
		track(&"round_start", {"round": round_no, "seed": seed}))


## Event gönder. Şemada olmayan alanlar yok sayılmaz — yalnız debug'da uyarılır (sessiz düşme).
func track(event: StringName, params: Dictionary = {}) -> void:
	if not _enabled:
		return
	if OS.is_debug_build() and not SCHEMA.has(event):
		push_warning("[Analytics] şema dışı event: %s" % event)
	var row := {"e": String(event), "t": Time.get_unix_time_from_system()}
	for k in params:
		row[k] = params[k]
	_queue.append(row)
	if _queue.size() > MAX_QUEUE:
		_queue.pop_front()          # en eskiyi at, bellek sabit kalsın
	_forward(row)


## Portal adaptörü. SDK yoksa sessizce yalnız kuyrukta kalır (v1 kabulü).
func _forward(row: Dictionary) -> void:
	if not _web:
		if OS.is_debug_build():
			print("[Analytics] ", row.get("e", ""), " ", row)
		return
	# Poki custom event API'si varsa kullan; yoksa sessiz.
	var js := "if (typeof PokiSDK !== 'undefined' && PokiSDK.customEvent) { PokiSDK.customEvent('%s', %s); }" % [
		String(row.get("e", "")), JSON.stringify(row)]
	JavaScriptBridge.eval(js, true)


## Eleme olayı (§13.4). cause: neden elendi, behavior: o anki ip davranışı.
func track_elimination(round_no: int, cause: String, behavior: StringName, delta_ms: float) -> void:
	track(&"elimination", {
		"round": round_no, "cause": cause,
		"behavior": String(behavior), "delta_ms": int(delta_ms)})


func track_restart() -> void:
	track(&"restart", {})


func track_session_end() -> void:
	track(&"session_end", {"rounds": _session_rounds})


## §13.1: ERROR seviyesindeki log Analytics'e client_error olarak düşer.
func track_error(msg: String) -> void:
	track(&"client_error", {"msg": msg.substr(0, 300)})


func set_enabled(on: bool) -> void:
	_enabled = on


func queued() -> Array:
	return _queue


func clear() -> void:
	_queue.clear()
