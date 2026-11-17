class_name GameMenu
extends CanvasLayer
## One window for everything you look at outside the world: Journal, Things,
## Character, Map and Game (save, load, settings, quit) are tabs of it. The
## keys (Tab, I, C, M, Esc) open it on their tab and switch between tabs while
## it is open; Esc closes it. Every tab can be clicked.

const TABS: Array[String] = ["journal", "inventory", "character", "map", "game"]
const KEYS := {"journal": &"journal", "inventory": &"inventory", "character": &"character", "map": &"map", "game": &"pause"}
## Window rect shared by every tab (480x270 base): room for the tab strip.
const WINDOW_LEFT := 14
const WINDOW_TOP := 26
const WINDOW_RIGHT := -14
const WINDOW_BOTTOM := -8

static var instance: GameMenu

var _root
var _strip: HBoxContainer
var _buttons := {}
var _current := ""


func setup(root) -> void:
	_root = root


func _ready() -> void:
	instance = self
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.theme = UiTheme.get_theme()
	add_child(holder)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 2)
	holder.add_child(_strip)
	_strip.position = Vector2(WINDOW_LEFT + 4, 5)
	for tab in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(open.bind(tab))
		b.mouse_entered.connect(func() -> void: Sfx.play(&"ui_click", 0.0, -14.0))
		_strip.add_child(b)
		_buttons[tab] = b
	var close_b := Button.new()
	close_b.text = "✕"
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.tooltip_text = tr("MENU_CLOSE")
	close_b.pressed.connect(close)
	_strip.add_child(close_b)
	_buttons["close"] = close_b
	_strip.visible = false


func _process(_delta: float) -> void:
	var open_tab := current_tab()
	_strip.visible = open_tab != ""
	if open_tab != _current:
		_current = open_tab
		_refresh()


func _refresh() -> void:
	for tab in TABS:
		var b: Button = _buttons[tab]
		b.text = tr("TAB_" + tab.to_upper())
		b.button_pressed = tab == _current


## The tab whose window is up, or "" when none is.
func current_tab() -> String:
	if _root == null:
		return ""
	if _screen("journal").is_open():
		return "journal"
	if _screen("inventory").is_open():
		return "inventory"
	if _screen("character").is_open():
		return "character"
	if _screen("map").is_open() and not (_screen("map") as MapScreen).travel:
		return "map"
	if _screen("game").is_open():
		return "game"
	return ""


func _screen(tab: String) -> Node:
	match tab:
		"journal":
			return _root.get_node("Journal")
		"inventory":
			return _root.get_node("Inventory")
		"character":
			return _root.find_child("CharacterScreen", false, false)
		"map":
			return _root.city_map
		_:
			return _root.get_node("PauseMenu")


func can_open() -> bool:
	return GameState.is_playing and not SceneFlow.is_transitioning and not DialogueService.is_active


func open(tab: String) -> void:
	if not can_open() and current_tab() == "":
		return
	var now := current_tab()
	if now == tab:
		_refresh()
		return
	if now != "":
		_screen(now).close()
	match tab:
		"map":
			(_screen("map") as MapScreen).open(false)
		_:
			_screen(tab).open()
	Sfx.play(&"ui_click")


func close() -> void:
	var now := current_tab()
	if now != "":
		_screen(now).close()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed() or event.is_echo():
		return
	var now := current_tab()
	# Another overlay (settings, a shop, a minigame) has the keys.
	if now == "" and (get_tree().paused or not can_open()):
		return
	if now != "" and _overlay_open():
		return
	for tab in TABS:
		if event.is_action_pressed(KEYS[tab]):
			get_viewport().set_input_as_handled()
			if now == tab or (now != "" and tab == "game"):
				close()  # the same key again, or Esc, closes the window
			else:
				open(tab)
			return


## Something opened on top of a tab (settings from the Game tab).
func _overlay_open() -> bool:
	for n in _root.get_node("PauseMenu").get_children():
		if n is SettingsScreen and n.is_open():
			return true
	return false


## Where every tab puts its window.
static func place_window(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = WINDOW_LEFT
	panel.offset_top = WINDOW_TOP
	panel.offset_right = WINDOW_RIGHT
	panel.offset_bottom = WINDOW_BOTTOM
