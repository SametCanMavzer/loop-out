class_name CrazyAds extends AdsService
## CrazyGames adaptörü (TDD §12.3). SDK: window.CrazyGames.SDK
## Oynanış bildirimleri: gameplayStart/gameplayStop (Poki ile aynı sözleşme, farklı API adı).

var _ready_flag := false
var _rewarded_cb: Callable = Callable()
var _js_callback: JavaScriptObject


func _init() -> void:
	if not OS.has_feature("web"):
		return
	_ready_flag = bool(JavaScriptBridge.eval(
		"typeof window.CrazyGames !== 'undefined' && !!window.CrazyGames.SDK", true))
	if _ready_flag:
		# Doküman: "SDK is unusable until initialized" → init promise'i saklanır, tüm çağrılar
		# .then() içine alınır. Aksi hâlde init bitmeden gelen gameplayStart sessizce düşerdi.
		JavaScriptBridge.eval("""
			window.__ipatla_cg_ready = window.CrazyGames.SDK.init().catch(function(){});
		""", true)
		_js_callback = JavaScriptBridge.create_callback(_on_rewarded_result)


func gameplay_start() -> void:
	if _ready_flag:
		JavaScriptBridge.eval(
			"window.__ipatla_cg_ready.then(function(){ window.CrazyGames.SDK.game.gameplayStart(); });", true)


func gameplay_stop() -> void:
	if _ready_flag:
		JavaScriptBridge.eval(
			"window.__ipatla_cg_ready.then(function(){ window.CrazyGames.SDK.game.gameplayStop(); });", true)


func rewarded(cb: Callable) -> void:
	if not _ready_flag:
		if cb.is_valid():
			cb.call(false)
		return
	_rewarded_cb = cb
	JavaScriptBridge.get_interface("window").__ipatla_reward = _js_callback
	JavaScriptBridge.eval("""
		window.__ipatla_cg_ready.then(function(){
			window.CrazyGames.SDK.ad.requestAd('rewarded', {
				adFinished: function(){ window.__ipatla_reward(true); },
				adError: function(){ window.__ipatla_reward(false); },
				adStarted: function(){}
			});
		});
	""", true)


func commercial_break(cb: Callable) -> void:
	if _ready_flag:
		JavaScriptBridge.eval("window.CrazyGames.SDK.ad.requestAd('midgame', {});", true)
	if cb.is_valid():
		cb.call(true)


func has_rewarded() -> bool:
	return _ready_flag


func service_name() -> String:
	return "crazygames"


func _on_rewarded_result(args: Array) -> void:
	var ok := args.size() > 0 and bool(args[0])
	if _rewarded_cb.is_valid():
		_rewarded_cb.call(ok)
	_rewarded_cb = Callable()
