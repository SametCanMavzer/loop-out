class_name UIRouter extends CanvasLayer
## Tek sahne UI yönlendirici (TDD §7.1). Ekranlar sahne ağacında hep var; yalnız `visible`
## toggle edilir — sahne yükleme maliyeti sıfır → <2 sn restart garantisi.
## GameState.state_changed'e bağlanır; hangi durumda hangi ekran görünür onu bilir.

## GameState.State → görünecek ekran node adı.
const SCREEN_FOR_STATE := {
	GameState.State.MENU: "MainMenu",
	GameState.State.COUNTDOWN: "HUD",
	GameState.State.PLAYING: "HUD",
	GameState.State.SPECTATE: "HUD",
	GameState.State.RESULTS: "Results",
}

## Duruma bağlı olmayan, üstte açılan ekranlar (popup/alt ekran).
const OVERLAYS := ["SettingsPopup", "Characters"]


func _ready() -> void:
	for name in OVERLAYS:
		var n := get_node_or_null(NodePath(name))
		if n != null:
			n.visible = false


## GameState'e bağla ("call down, signal up": router yukarıyı aramaz, ebeveyn bağlar).
func bind(state: GameState) -> void:
	state.state_changed.connect(_on_state_changed)
	show_for_state(state.current)


func _on_state_changed(_from: int, to: int) -> void:
	show_for_state(to)


## İlgili ekranı göster, diğer durum ekranlarını gizle (overlay'lere dokunmaz).
func show_for_state(state: int) -> void:
	var target: String = SCREEN_FOR_STATE.get(state, "")
	for s in SCREEN_FOR_STATE.values():
		var n := get_node_or_null(NodePath(s))
		if n != null:
			n.visible = (s == target)


func show_overlay(name: String, shown: bool) -> void:
	var n := get_node_or_null(NodePath(name))
	if n != null:
		n.visible = shown
