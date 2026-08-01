extends RefCounted
## F13 yerelleştirme testi: çeviriler yükleniyor mu, TR/EN anahtarları eksiksiz mi,
## format dizeleri (%d/%s) iki dilde de aynı sayıda argüman bekliyor mu.
## (godot --headless scenes/dev/run_tests.tscn -- test_i18n)

const KEYS := [
	"UI_READY", "UI_TAP", "UI_ROUND", "UI_PERFECT", "UI_GRAZE", "UI_MISS", "UI_COMBO",
	"UI_WIN", "UI_PLACE", "UI_RESULT_DETAIL", "UI_COINS_EARNED", "UI_DAILY_BONUS",
	"UI_RESTART", "UI_CHARACTERS", "UI_WATCH_AD", "UI_DRAW", "UI_COINS",
	"UI_RARITY_COMMON", "UI_RARITY_RARE", "UI_RARITY_LEGENDARY", "UI_SELECTED", "UI_LOCKED",
	"UI_CHAR_UNLOCKED", "UI_CHAR_DUPLICATE", "UI_NOT_ENOUGH_COINS", "UI_POOL_EMPTY",
	"UI_SETTINGS", "UI_SOUND", "UI_VIBRATION", "UI_LANGUAGE", "UI_ORIENTATION",
	"UI_PORTRAIT", "UI_LANDSCAPE", "UI_ON", "UI_OFF", "UI_CLOSE",
	"UI_ABOUT_OPPONENTS", "UI_WEB_SAVE_NOTE",
	"BEH_NORMAL", "BEH_SPEED_STEP", "BEH_SUDDEN_STOP", "BEH_REVERSE",
	"BEH_HIGH_SWEEP", "BEH_DOUBLE_SWEEP", "BEH_FAKE_SLOW",
]


func run(_tree: SceneTree) -> int:
	var fail := 0
	var prev_locale := TranslationServer.get_locale()

	# --- Her iki dilde de tüm anahtarlar çevrilmiş olmalı (çeviri yoksa tr() anahtarı döndürür) ---
	for loc in ["en", "tr"]:
		TranslationServer.set_locale(loc)
		for k in KEYS:
			var t := tr(k)
			if t == k:
				push_error("FAIL: '%s' anahtarı %s dilinde çevrilmemiş." % [k, loc]); fail += 1
			elif t.strip_edges() == "":
				push_error("FAIL: '%s' anahtarı %s dilinde boş." % [k, loc]); fail += 1

	# --- Format dizeleri: iki dil aynı sayıda %d/%s beklemeli (yoksa çalışma anında çöker) ---
	for k in KEYS:
		TranslationServer.set_locale("en")
		var en := tr(k)
		TranslationServer.set_locale("tr")
		var trk := tr(k)
		if _fmt_count(en) != _fmt_count(trk):
			push_error("FAIL: '%s' format argüman sayısı farklı (en=%d, tr=%d) — çalışma anında çöker."
				% [k, _fmt_count(en), _fmt_count(trk)]); fail += 1

	# --- Türkçe gerçekten farklı olmalı (CSV yanlış sütun eşlenmiş olabilir) ---
	TranslationServer.set_locale("en")
	var en_win := tr("UI_WIN")
	TranslationServer.set_locale("tr")
	if tr("UI_WIN") == en_win:
		push_error("FAIL: TR ve EN aynı çıktı veriyor — dil sütunları eşleşmemiş."); fail += 1

	# --- Zorunlu bilgilendirme metinleri (GDD §5.3 / TDD §5.2 E4) ---
	TranslationServer.set_locale("tr")
	if not tr("UI_ABOUT_OPPONENTS").to_lower().contains("yapay"):
		push_error("FAIL: 'rakipler yapay zekâdır' metni eksik (GDD §5.3 şartı)."); fail += 1
	if not tr("UI_WEB_SAVE_NOTE").to_lower().contains("tarayıcı"):
		push_error("FAIL: web kayıt uyarısı eksik (TDD §5.2 E4)."); fail += 1

	# --- Ayarların gerçekten bir karşılığı var mı (boş vaat ayar olmasın) ---
	# Denetimde bulundu: "titreşim" ve "ekran yönü" ayarları kaydediliyordu ama hiçbir şey yapmıyordu.
	var ad_src: String = FileAccess.get_file_as_string("res://scripts/core/audio_director.gd")
	if not ad_src.contains("vibrate_handheld"):
		push_error("FAIL: titreşim ayarı var ama oyunda hiç titreşim tetiklenmiyor."); fail += 1
	if not ad_src.contains("SaveGame.setting(\"vibration\""):
		push_error("FAIL: titreşim ayarı okunmuyor (ayar kapalıyken de titrer)."); fail += 1
	var sp_src: String = FileAccess.get_file_as_string("res://scripts/ui/settings_popup.gd")
	if not sp_src.contains("screen_set_orientation"):
		push_error("FAIL: ekran yönü ayarı mobilde etkisiz (yalnız pencere boyutu değiştiriliyor)."); fail += 1
	var main_src: String = FileAccess.get_file_as_string("res://scripts/core/main.gd")
	if not main_src.contains("apply_orientation"):
		push_error("FAIL: kayıtlı ekran yönü açılışta uygulanmıyor."); fail += 1
	if not main_src.contains("TranslationServer.set_locale"):
		push_error("FAIL: kayıtlı dil açılışta uygulanmıyor."); fail += 1

	TranslationServer.set_locale(prev_locale)
	if fail == 0:
		print("TEST I18N OK (%d anahtar × 2 dil, format tutarlılığı, zorunlu metinler)" % KEYS.size())
	else:
		print("TEST I18N FAILED: %d hata" % fail)
	return fail


func _fmt_count(s: String) -> int:
	var n := 0
	var i := 0
	while i < s.length() - 1:
		if s[i] == "%":
			if s[i + 1] == "%":
				i += 1               # %% kaçış, argüman değil
			else:
				n += 1
		i += 1
	return n
