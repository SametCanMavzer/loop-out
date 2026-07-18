extends Node
## AdsService arayüzü: PokiAds / CrazyAds / NullAds (TDD §12.3).
## Platform tespiti F12'de; şimdilik NullAds davranışı (itch/geliştirme).

# TODO(F12): AdsService alt sınıfları + JavaScriptBridge sarma + platform tespiti.
#            Poki gameplayStart/Stop event'leri round_started/round_ended'e bağlanır (zorunlu).

func gameplay_start() -> void:
	pass


func gameplay_stop() -> void:
	pass


## NullAds: rewarded anında başarısız → UI ×2 butonu gizlenir.
func rewarded(cb: Callable) -> void:
	if cb.is_valid():
		cb.call(false)


func has_rewarded() -> bool:
	return false
