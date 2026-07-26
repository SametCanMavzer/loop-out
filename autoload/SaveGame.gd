extends Node
## user://save.json okuma/yazma + migration (TDD §5.2).
## Yazım: önce temp dosyaya, sonra rename → yarım yazım koruması (web'de user:// = IndexedDB).
## Sürüm zinciri ilk günden kurulu: _migrate(v) her sürüm için bir adım.

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
const SAVE_VERSION := 1

var data: Dictionary = _defaults()


func _ready() -> void:
	load_game()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"characters_owned": ["default"],
		"equipped": "default",
		"best_round": 0,
		"total_wins": 0,
		"last_daily_win_date": "",
		"early_exit_streak": 0,
		"settings": {
			"sound": true, "vibration": true, "lang": "en",
			"orientation": "portrait", "reduced_fx": false
		}
	}


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _defaults()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveGame] save.json bozuk — varsayılanlara dönüldü.")
		data = _defaults()
		return
	data = _migrate(parsed)
	# Eksik alanları varsayılanlarla tamamla (ileri/geri uyum).
	var defs := _defaults()
	for k in defs:
		if not data.has(k):
			data[k] = defs[k]
	if typeof(data.get("settings")) != TYPE_DICTIONARY:
		data["settings"] = defs["settings"]
	else:
		for k in defs["settings"]:
			if not data["settings"].has(k):
				data["settings"][k] = defs["settings"][k]


## Sürüm zinciri: v1 ilk sürüm. Yeni sürümde buraya bir adım eklenir (v1→v2 …).
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	# while v < SAVE_VERSION: match v: 1: <v1→v2 dönüşümü>; v += 1
	if v > SAVE_VERSION:
		push_warning("[SaveGame] kayıt daha yeni bir sürümden (v%d) — olduğu gibi okunuyor." % v)
	d["version"] = SAVE_VERSION
	return d


## Atomik yazma: temp'e yaz → rename. Yarım yazım (kapanma/çökme) kaydı bozmaz.
func save_game() -> bool:
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveGame] temp dosya açılamadı: %s" % TEMP_PATH)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("[SaveGame] user:// erişilemedi.")
		return false
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	var err := dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("[SaveGame] rename başarısız (%d)." % err)
		return false
	return true


# --- Tipli erişim (kod string anahtarla dolaşmasın) ---

func coins() -> int:
	return int(data.get("coins", 0))


func add_coins(amount: int) -> void:
	data["coins"] = maxi(coins() + amount, 0)


func spend_coins(amount: int) -> bool:
	if coins() < amount:
		return false
	data["coins"] = coins() - amount
	return true


func owns(character_id: String) -> bool:
	return (data.get("characters_owned", []) as Array).has(character_id)


func add_character(character_id: String) -> void:
	if not owns(character_id):
		(data["characters_owned"] as Array).append(character_id)


func equipped() -> String:
	return String(data.get("equipped", "default"))


func equip(character_id: String) -> void:
	if owns(character_id):
		data["equipped"] = character_id


## Tur sonucu kaydı: rekor, galibiyet, erken-eleme serisi (§4.7 dram girdisi).
## early_exit_threshold: ilk N elemede gitmek "erken" sayılır (config.drama).
func record_round(placement: int, round_no: int, total_players: int, early_exit_threshold: int) -> void:
	data["best_round"] = maxi(int(data.get("best_round", 0)), round_no)
	if placement <= 1:
		data["total_wins"] = int(data.get("total_wins", 0)) + 1
	var was_early := placement > (total_players - early_exit_threshold)
	data["early_exit_streak"] = (int(data.get("early_exit_streak", 0)) + 1) if was_early else 0


## Günlük ilk galibiyet mi? (GDD §6.4 — tek günlük kanca). Kazanınca çağrılır.
func consume_daily_first_win() -> bool:
	var today := Time.get_date_string_from_system()
	if String(data.get("last_daily_win_date", "")) == today:
		return false
	data["last_daily_win_date"] = today
	return true


func setting(key: String, fallback: Variant = null) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	save_game()
