extends Node
## balance.json yükleyici + tipli erişim (TDD §5.1, §4.1).
## Tüm tuning değerleri burada; koda sabit gömme YASAK (Karar #7).
## Erişim: Config.timing.perfect_ms gibi — JSON'a dağınık string erişimi yok.

const CONFIG_PATH := "res://config/balance.json"
const TICKS_PER_SECOND := 60

# Tipli erişim için nested Dictionary'ler (yükleme sonrası doldurulur).
var version: int = 0
var timing: Dictionary = {}
var rope: Dictionary = {}
var stumble_regimes: Array = []
var difficulty_rounds: Array = []
var ring: Dictionary = {}
var economy: Dictionary = {}
var bots: Dictionary = {}
var drama: Dictionary = {}
var behavior_select_interval_ms: float = 2000.0
var behavior_max_consecutive: int = 2

var _loaded: bool = false


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("[Config] balance.json bulunamadı: %s" % CONFIG_PATH)
		return
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Config] balance.json ayrıştırılamadı (geçersiz JSON).")
		return
	var d: Dictionary = parsed
	version = int(d.get("version", 0))
	timing = d.get("timing", {})
	rope = d.get("rope", {})
	stumble_regimes = d.get("stumble_regimes", [])
	difficulty_rounds = d.get("difficulty_rounds", [])
	ring = d.get("ring", {})
	economy = d.get("economy", {})
	bots = d.get("bots", {})
	drama = d.get("drama", {})
	behavior_select_interval_ms = float(d.get("behavior_select_interval_ms", 2000.0))
	behavior_max_consecutive = int(d.get("behavior_max_consecutive", 2))
	_loaded = true
	_validate()
	print("[Config] balance.json yüklendi (version=%d)." % version)


## Beklenen zorunlu alanlar var mı? (assert — release'de silinir, geliştirmede erken sinyal.)
func _validate() -> void:
	assert(version > 0, "[Config] version alanı eksik/geçersiz.")
	assert(timing.has("perfect_ms"), "[Config] timing.perfect_ms eksik.")
	assert(rope.has("start_rpm"), "[Config] rope.start_rpm eksik.")
	assert(ring.has("r_max") and ring.has("r_min"), "[Config] ring yarıçapları eksik.")


func is_loaded() -> bool:
	return _loaded


## ms → tick dönüşümü (TDD §4.1: floor, sabit yuvarlama, oyuncu lehine değil).
static func ms_to_ticks(ms: float) -> int:
	return int(floor(ms * TICKS_PER_SECOND / 1000.0))


# --- Tipli zamanlama getter'ları (§4.3). Kod string anahtarla erişmez; buradan okur. ---

## Verilen tura ait sendeleme rejimi (§4.5): from_round'u <= round_no olan en yükseği.
func _regime_for(round_no: int) -> Dictionary:
	# from_round'u <= round_no olanlar arasından EN BÜYÜK from_round (dizi sırasından bağımsız).
	var chosen: Dictionary = {}
	var best_from := -1
	for r in stumble_regimes:
		var f := int((r as Dictionary).get("from_round", 1))
		if f <= round_no and f > best_from:
			best_from = f
			chosen = r
	return chosen


## Perfect penceresi (ms). Sabit (§5.1 timing.perfect_ms); tur bağımsız.
func perfect_ms(_round_no: int = 1) -> int:
	return int(timing.get("perfect_ms", 90))


## Graze üst penceresi (ms). Rejim daraltır (§4.5). Sudden death'te (graze_ms null) graze
## bandı yoktur → perfect eşiği döner, yani perfect değilse ıskalama.
func graze_ms(round_no: int) -> int:
	var regime := _regime_for(round_no)
	var g: Variant = regime.get("graze_ms", null)
	if g == null:
		return perfect_ms(round_no)
	return int((g as Array)[1])  # [perfect_sınırı, graze_sınırı] → üst sınır


## Bu tura ait af eşiği (§4.5): temiz geçiş sayısı ⚠'yı siler. null → -1 (sudden death, af yok).
func pardon_rounds(round_no: int) -> int:
	var regime := _regime_for(round_no)
	var p: Variant = regime.get("pardon_rounds", null)
	return int(p) if p != null else -1


## Jumper zamanlama parametrelerini tick cinsinden döndürür (§6). Jumper Config'e bağlı
## kalmasın diye enjekte edilir (Karar: pure/test-edilebilir çekirdek).
func jumper_tuning() -> JumperTuning:
	return JumperTuning.new(
		ms_to_ticks(float(timing.get("jump_air_ms", 420))),
		ms_to_ticks(float(timing.get("high_jump_air_ms", 700))),
		ms_to_ticks(float(timing.get("hold_threshold_ms", 300))),
		ms_to_ticks(float(timing.get("duck_release_ms", 120))),
		ms_to_ticks(float(timing.get("input_buffer_ms", 100)))
	)
