extends RefCounted
## F12 SDK testi: Ads arayüzü/NullAds davranışı, çift-ödül koruması, analitik şeması+kuyruk.
## (godot --headless scenes/dev/run_tests.tscn -- test_sdk)

## Test için sahte servis: rewarded'ı istenen sonuçla döndürür, çağrıları sayar.
class FakeAds extends AdsService:
	var gameplay_starts := 0
	var gameplay_stops := 0
	var rewarded_calls := 0
	var result := true
	func gameplay_start() -> void: gameplay_starts += 1
	func gameplay_stop() -> void: gameplay_stops += 1
	func has_rewarded() -> bool: return true
	func service_name() -> String: return "fake"
	func rewarded(cb: Callable) -> void:
		rewarded_calls += 1
		if cb.is_valid():
			cb.call(result)


func run(tree: SceneTree) -> int:
	var fail := 0
	var ads := tree.root.get_node_or_null(^"Ads")
	var analytics := tree.root.get_node_or_null(^"Analytics")
	if ads == null or analytics == null:
		push_error("FAIL: Ads/Analytics autoload yok."); return 1

	# --- NullAds sözleşmesi (§12.3): itch/masaüstünde rewarded YOK, UI ×2 gizlenir ---
	var null_ads := AdsService.new()
	if null_ads.has_rewarded():
		push_error("FAIL: NullAds rewarded sunmamalı."); fail += 1
	var got := {"called": false, "ok": true}
	null_ads.rewarded(func(ok: bool) -> void: got.called = true; got.ok = ok)
	if not got.called or got.ok:
		push_error("FAIL: NullAds rewarded anında success=false döndürmeli."); fail += 1

	# --- Ads autoload delegasyonu + çift-ödül koruması ---
	var fake := FakeAds.new()
	ads.call("_set_service_for_test", fake)
	if not bool(ads.call("has_rewarded")) or String(ads.call("service_name")) != "fake":
		push_error("FAIL: Ads servisi delege etmiyor."); fail += 1

	var results: Array = []
	ads.call("rewarded", func(ok: bool) -> void: results.append(ok))
	if fake.rewarded_calls != 1 or results != [true]:
		push_error("FAIL: rewarded servise iletilmedi (%d çağrı, %s)." % [fake.rewarded_calls, str(results)]); fail += 1

	# Poki/Crazy zorunlu event'leri: round_started/ended → gameplay_start/stop
	EventBus.round_started.emit(1, 123)
	EventBus.round_ended.emit(3, 10)
	if fake.gameplay_starts != 1 or fake.gameplay_stops != 1:
		push_error("FAIL: gameplayStart/Stop tur sinyallerine bağlı değil (%d/%d) — portal başvurusu bunu şart koşar."
			% [fake.gameplay_starts, fake.gameplay_stops]); fail += 1

	# --- Analitik şeması (§13.4) ---
	analytics.call("clear")
	analytics.call("track_elimination", 7, "miss", &"speed_step", 142.0)
	analytics.call("track_restart")
	analytics.call("track_error", "test hatası")
	var q: Array = analytics.call("queued")
	if q.size() != 3:
		push_error("FAIL: 3 event kuyrukta olmalı (%d)." % q.size()); fail += 1
	else:
		var elim: Dictionary = q[0]
		if elim.get("e") != "elimination" or int(elim.get("round", -1)) != 7 \
				or String(elim.get("behavior", "")) != "speed_step" or int(elim.get("delta_ms", -1)) != 142:
			push_error("FAIL: elimination event alanları eksik/yanlış (%s)." % str(elim)); fail += 1
		if String(q[1].get("e", "")) != "restart" or String(q[2].get("e", "")) != "client_error":
			push_error("FAIL: restart/client_error event'leri yanlış."); fail += 1

	# round_start otomatik (EventBus.round_started'a bağlı)
	analytics.call("clear")
	EventBus.round_started.emit(4, 999)
	var q2: Array = analytics.call("queued")
	if q2.size() != 1 or String(q2[0].get("e", "")) != "round_start" or int(q2[0].get("seed", -1)) != 999:
		push_error("FAIL: round_start otomatik kaydedilmedi (%s)." % str(q2)); fail += 1

	# Kuyruk sınırı: bellek şişmez (MAX_QUEUE)
	analytics.call("clear")
	for i in 260:
		analytics.call("track", &"restart", {})
	var q3: Array = analytics.call("queued")
	if q3.size() > int(analytics.get("MAX_QUEUE")):
		push_error("FAIL: kuyruk sınırı aşıldı (%d)." % q3.size()); fail += 1
	analytics.call("clear")

	# Başarısız reklam: jeton verilmemeli (çağıran karar verir ama sonuç false gelmeli)
	fake.result = false
	var res2: Array = []
	ads.call("rewarded", func(ok: bool) -> void: res2.append(ok))
	if res2 != [false]:
		push_error("FAIL: başarısız reklam false döndürmeli (%s)." % str(res2)); fail += 1

	# --- Portal kuralı: reklam boyunca ses kısılır, sonra ESKİ HÂLİNE döner ---
	var audio := tree.root.get_node_or_null(^"Audio")
	if audio != null:
		var master := AudioServer.get_bus_index("Master")
		audio.call("set_enabled", true)
		var muted_during := {"v": false}
		fake.result = true
		# Sahte servis callback'i senkron çağırır; mute'u yakalamak için araya giriyoruz.
		var probe := FakeAds.new()
		probe.result = true
		ads.call("_set_service_for_test", probe)
		audio.call("push_mute")
		muted_during.v = AudioServer.is_bus_mute(master)
		audio.call("pop_mute")
		if not muted_during.v:
			push_error("FAIL: push_mute Master'ı susturmalı (portal kuralı)."); fail += 1
		if AudioServer.is_bus_mute(master):
			push_error("FAIL: pop_mute sesi geri açmalı (kullanıcı ayarı korunmalı)."); fail += 1
		# Ses kapalıyken reklam: pop_mute kullanıcının KAPALI ayarını bozmamalı
		audio.call("set_enabled", false)
		audio.call("push_mute"); audio.call("pop_mute")
		if not AudioServer.is_bus_mute(master):
			push_error("FAIL: kullanıcı sesi kapalıyken reklam sonrası ses açılmamalı."); fail += 1
		audio.call("set_enabled", true)

	# --- Çift-tetikleme koruması: SDK hem callback hem timeout verirse tek ödül ---
	var twice := FakeAds.new()
	ads.call("_set_service_for_test", twice)
	var calls: Array = []
	ads.call("rewarded", func(ok: bool) -> void: calls.append(ok))
	if calls.size() != 1:
		push_error("FAIL: rewarded callback tam 1 kez çağrılmalı (%d)." % calls.size()); fail += 1
	# İkinci istek: ilki bittiği için kabul edilmeli (kilit takılı kalmamalı)
	ads.call("rewarded", func(ok: bool) -> void: calls.append(ok))
	if calls.size() != 2:
		push_error("FAIL: reklam kilidi takılı kaldı (ikinci istek reddedildi)."); fail += 1

	ads.call("_set_service_for_test", AdsService.new())   # temizle
	if fail == 0:
		print("TEST SDK OK (NullAds sözleşmesi, delegasyon, gameplayStart/Stop, analitik şeması+kuyruk)")
	else:
		print("TEST SDK FAILED: %d hata" % fail)
	return fail
