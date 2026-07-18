extends Node
## user://save.json okuma/yazma + migration (TDD §5.2).
## Yazım: temp'e yaz → rename (yarım yazım koruması). Şimdilik STUB — F9'da doldurulur.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var data: Dictionary = _defaults()


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

# TODO(F9): load(), save() (temp+rename), _migrate(from_version).
