class_name AdsService extends RefCounted
## Reklam servisi arayüzü (TDD §12.3, E3 çözümü). Oyun kodu YALNIZ bu arayüzü bilir;
## portal farkları adaptörlerde kalır (NullAds / PokiAds / CrazyAds).
##
## Poki'nin gameplayStart/gameplayStop event'leri ZORUNLUDUR — başvuru bunlarsız reddedilir.
## Bu yüzden çağrılar EventBus.round_started/round_ended'a bağlanır (Ads autoload'ında).

## Oynanış başladı (portal reklam/ses politikası bunu bekler).
func gameplay_start() -> void:
	pass


## Oynanış durdu (tur bitti, menü/sonuç ekranı).
func gameplay_stop() -> void:
	pass


## Ödüllü reklam. cb(success: bool) — v1'de yalnız "jeton ×2" için (GDD §6.2).
func rewarded(cb: Callable) -> void:
	if cb.is_valid():
		cb.call(false)


## Zorunlu ara reklam. v1'de ÇAĞRILMAZ (kapsam kararı: zorunlu reklam yok).
func commercial_break(cb: Callable) -> void:
	if cb.is_valid():
		cb.call(false)


## Ödüllü reklam sunulabiliyor mu? false → UI "×2" butonunu gizler.
func has_rewarded() -> bool:
	return false


func service_name() -> String:
	return "null"
