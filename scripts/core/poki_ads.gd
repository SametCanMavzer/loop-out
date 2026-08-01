class_name PokiAds extends AdsService
## Poki adaptörü (TDD §12.3). Portal SDK'sını JavaScriptBridge ile sarar.
## gameplayStart/gameplayStop ZORUNLU (yoksa başvuru reddedilir).
## SDK, index.html'e head_include ile eklenir (F15 export adımı).

var _ready_flag := false
var _rewarded_cb: Callable = Callable()
var _js_callback: JavaScriptObject      # GC'ye yem olmasın diye referans tutulur


func _init() -> void:
	if not OS.has_feature("web"):
		return
	# SDK yüklendi mi? (sayfa PokiSDK'yı tanımlamamışsa sessizce Null gibi davranırız)
	_ready_flag = bool(JavaScriptBridge.eval("typeof PokiSDK !== 'undefined'", true))
	if _ready_flag:
		# init ASENKRON: bitmeden gelen çağrılar kaybolmasın diye promise saklanır ve
		# her çağrı .then() içine alınır (SDK hazır olana kadar otomatik kuyruklanır).
		JavaScriptBridge.eval("""
			window.__ipatla_poki_ready = PokiSDK.init().catch(function(){});
		""", true)
		_js_callback = JavaScriptBridge.create_callback(_on_rewarded_result)


func gameplay_start() -> void:
	if _ready_flag:
		JavaScriptBridge.eval(
			"window.__ipatla_poki_ready.then(function(){ PokiSDK.gameplayStart(); });", true)


func gameplay_stop() -> void:
	if _ready_flag:
		JavaScriptBridge.eval(
			"window.__ipatla_poki_ready.then(function(){ PokiSDK.gameplayStop(); });", true)


func rewarded(cb: Callable) -> void:
	if not _ready_flag:
		if cb.is_valid():
			cb.call(false)
		return
	_rewarded_cb = cb
	# Sonucu godot tarafına köprüle: window.__ipatla_reward(success)
	JavaScriptBridge.get_interface("window").__ipatla_reward = _js_callback
	JavaScriptBridge.eval("""
		window.__ipatla_poki_ready.then(function(){
			return PokiSDK.rewardedBreak();
		}).then(function(ok){ window.__ipatla_reward(!!ok); })
			.catch(function(){ window.__ipatla_reward(false); });
	""", true)


func commercial_break(cb: Callable) -> void:
	# v1'de çağrılmaz; yine de doğru davranış (SDK'ya bildir, sonra devam et).
	if _ready_flag:
		JavaScriptBridge.eval("PokiSDK.commercialBreak().then(function(){});", true)
	if cb.is_valid():
		cb.call(true)


func has_rewarded() -> bool:
	return _ready_flag


func service_name() -> String:
	return "poki"


func _on_rewarded_result(args: Array) -> void:
	var ok := args.size() > 0 and bool(args[0])
	if _rewarded_cb.is_valid():
		_rewarded_cb.call(ok)
	_rewarded_cb = Callable()
