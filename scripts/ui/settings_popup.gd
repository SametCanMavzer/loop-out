class_name SettingsPopup extends Control
## Ayarlar (GDD §9): ses, titreşim, dil (EN/TR), ekran yönü + zorunlu bilgilendirme metinleri:
##  - "rakipler yapay zekâdır" (GDD §5.3 — oyun hiçbir yerde gerçek oyuncu iddia etmez)
##  - "web'de ilerleme bu tarayıcıya bağlı" (TDD §5.2 E4 — IndexedDB kaybı kabulü)
## Tüm değerler SaveGame.settings'e yazılır ve anında uygulanır.

signal closed()
signal orientation_changed(portrait: bool)

@onready var _title: Label = $Panel/Title
@onready var _sound: Button = $Panel/Rows/SoundRow/Value
@onready var _vibration: Button = $Panel/Rows/VibrationRow/Value
@onready var _language: Button = $Panel/Rows/LanguageRow/Value
@onready var _orientation: Button = $Panel/Rows/OrientationRow/Value
@onready var _about: Label = $Panel/About
@onready var _web_note: Label = $Panel/WebNote
@onready var _close: Button = $Panel/CloseButton


func _ready() -> void:
	_sound.pressed.connect(_toggle_sound)
	_vibration.pressed.connect(_toggle_vibration)
	_language.pressed.connect(_toggle_language)
	_orientation.pressed.connect(_toggle_orientation)
	_close.pressed.connect(func() -> void: closed.emit())
	_apply_locale_from_save()
	refresh()


## Kayıttaki dili yükle (oyun açılışında da çağrılır).
func _apply_locale_from_save() -> void:
	var lang := String(SaveGame.setting("lang", "en"))
	TranslationServer.set_locale(lang)


func refresh() -> void:
	_title.text = tr("UI_SETTINGS")
	($Panel/Rows/SoundRow/Key as Label).text = tr("UI_SOUND")
	($Panel/Rows/VibrationRow/Key as Label).text = tr("UI_VIBRATION")
	($Panel/Rows/LanguageRow/Key as Label).text = tr("UI_LANGUAGE")
	($Panel/Rows/OrientationRow/Key as Label).text = tr("UI_ORIENTATION")
	_sound.text = tr("UI_ON") if bool(SaveGame.setting("sound", true)) else tr("UI_OFF")
	_vibration.text = tr("UI_ON") if bool(SaveGame.setting("vibration", true)) else tr("UI_OFF")
	_language.text = "Türkçe" if String(SaveGame.setting("lang", "en")) == "tr" else "English"
	_orientation.text = tr("UI_PORTRAIT") if _is_portrait() else tr("UI_LANDSCAPE")
	_about.text = tr("UI_ABOUT_OPPONENTS")
	_web_note.text = tr("UI_WEB_SAVE_NOTE")
	_web_note.visible = OS.has_feature("web")     # not yalnız web sürümünde anlamlı
	_close.text = tr("UI_CLOSE")


func _is_portrait() -> bool:
	return String(SaveGame.setting("orientation", "portrait")) == "portrait"


func _toggle_sound() -> void:
	var on := not bool(SaveGame.setting("sound", true))
	SaveGame.set_setting("sound", on)             # set_setting kaydı da yazar
	Audio.set_enabled(on)
	refresh()


func _toggle_vibration() -> void:
	var on := not bool(SaveGame.setting("vibration", true))
	SaveGame.set_setting("vibration", on)
	if on and OS.has_feature("mobile"):
		Input.vibrate_handheld(40)                # açıkken kısa geri bildirim
	refresh()


func _toggle_language() -> void:
	var next := "en" if String(SaveGame.setting("lang", "en")) == "tr" else "tr"
	SaveGame.set_setting("lang", next)
	TranslationServer.set_locale(next)
	refresh()


func _toggle_orientation() -> void:
	var portrait := not _is_portrait()
	SaveGame.set_setting("orientation", "portrait" if portrait else "landscape")
	apply_orientation(portrait)
	orientation_changed.emit(portrait)
	refresh()


## Ekran yönünü uygula. Mobil (asıl hedef) ekran yönünü OS'tan ister; masaüstü/web'de
## pencere oranı çevrilir. CameraRig viewport oranını izlediği için kamera kendiliğinden uyar.
static func apply_orientation(portrait: bool) -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_PORTRAIT if portrait else DisplayServer.SCREEN_LANDSCAPE)
		return
	var s := DisplayServer.window_get_size()
	if s.x > 0 and s.y > 0 and ((portrait and s.x > s.y) or (not portrait and s.y > s.x)):
		DisplayServer.window_set_size(Vector2i(s.y, s.x))
