class_name CharactersScreen extends Control
## Karakterler ekranı (GDD §6.3 / §9): koleksiyon ızgarası + çekiliş makinesi + kuşanma.
## Kartlar koddan kurulur (CLAUDE.md: .tscn minimal). Yalnız kozmetik.

signal closed()
signal equipped_changed(id: String)

const RARITY_LABEL := ["Yaygın", "Nadir", "Efsanevi"]
const RARITY_COLOR := [Color(0.75, 0.78, 0.82), Color(0.45, 0.75, 1.0), Color(1.0, 0.82, 0.3)]

@onready var _grid: GridContainer = $Panel/Scroll/Grid
@onready var _coins: Label = $Panel/Header/Coins
@onready var _draw_button: Button = $Panel/DrawButton
@onready var _close_button: Button = $Panel/Header/Close
@onready var _toast: Label = $Panel/Toast

var _gacha := Gacha.new()
var _pool: Array = []
var _cost := 100
var _toast_time := 0.0


func _ready() -> void:
	_pool = Gacha.load_pool()
	_gacha.setup(_pool, Rng.cosmetic)
	_cost = int(Config.economy.get("gacha_cost", 100))
	_draw_button.pressed.connect(_on_draw)
	_close_button.pressed.connect(func() -> void: closed.emit())
	_toast.text = ""


## Ekran açılırken çağrılır: ızgarayı ve jeton sayacını tazele.
func refresh() -> void:
	_coins.text = "%d jeton" % SaveGame.coins()
	_draw_button.text = "ÇEKİLİŞ (%d)" % _cost
	_draw_button.disabled = SaveGame.coins() < _cost
	for c in _grid.get_children():
		c.queue_free()
	for ch in _pool:
		_grid.add_child(_make_card(ch))


func _make_card(ch: CharacterData) -> Control:
	var owned := SaveGame.owns(String(ch.id))
	var is_equipped := SaveGame.equipped() == String(ch.id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(150, 110)
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not owned
	card.text = "%s\n%s%s" % [
		(ch.display_name if owned else "???"),
		RARITY_LABEL[ch.rarity],
		("\n★ SEÇİLİ" if is_equipped else "")]
	card.modulate = ch.color if owned else Color(0.35, 0.35, 0.38)
	card.add_theme_color_override("font_color", RARITY_COLOR[ch.rarity])
	if owned and not is_equipped:
		card.pressed.connect(func() -> void:
			SaveGame.equip(String(ch.id))
			SaveGame.save_game()
			equipped_changed.emit(String(ch.id))
			refresh())
	return card


func _on_draw() -> void:
	if not SaveGame.spend_coins(_cost):
		_show_toast("Yetersiz jeton")
		return
	var owned: Array = (SaveGame.data.get("characters_owned", []) as Array).duplicate()
	var result := _gacha.draw(owned)
	if result == null:
		SaveGame.add_coins(_cost)     # havuz boş — jetonu iade et
		_show_toast("Havuz boş")
		return
	var is_new := not owned.has(String(result.id))
	if is_new:
		SaveGame.add_character(String(result.id))
	SaveGame.save_game()
	_show_toast("%s %s! (%s)" % [
		result.display_name, ("kazanıldı" if is_new else "tekrar geldi"), RARITY_LABEL[result.rarity]])
	refresh()


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	_toast_time = 2.5


func _process(dt: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= dt
		if _toast_time <= 0.0:
			_toast.modulate.a = 0.0
