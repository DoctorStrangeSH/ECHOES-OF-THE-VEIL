class_name PauseMenu
extends CanvasLayer
## Pauses the game: continue, save, load, language, main menu, quit.

var _dim: ColorRect
var _panel: PanelContainer
var _buttons: VBoxContainer
var _load_button: Button
var _settings: SettingsScreen
var _hud: Hud


func setup(hud: Hud) -> void:
	_hud = hud


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_dim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _dim.visible:
		get_viewport().set_input_as_handled()
		close()
	elif _can_open():
		get_viewport().set_input_as_handled()
		open()


func _can_open() -> bool:
	return GameState.is_playing and not SceneFlow.is_transitioning \
		and not (_hud != null and _hud.dialogue_open)


func open() -> void:
	get_tree().paused = true
	_load_button.disabled = not SaveService.has_save()
	_refresh_texts()
	_dim.visible = true
	(_buttons.get_child(0) as Button).grab_focus()


func close() -> void:
	_dim.visible = false
	get_tree().paused = false


func _on_inventory() -> void:
	close()
	(get_parent().get_node("Inventory") as InventoryScreen).open()


func _on_journal() -> void:
	close()
	(get_parent().get_node("Journal") as JournalScreen).open()


func _on_save() -> void:
	close()
	SaveService.save_game()


func _on_load() -> void:
	close()
	SaveService.load_game()


func _on_language() -> void:
	if _settings == null:
		_settings = SettingsScreen.new()
		add_child(_settings)
		_settings.closed.connect(func() -> void:
			_refresh_texts()
			(_buttons.get_child(5) as Button).grab_focus())
	_settings.open()


func _on_main_menu() -> void:
	close()
	SceneFlow.show_main_menu()


func _refresh_texts() -> void:
	var keys := ["MENU_CONTINUE", "MENU_INVENTORY", "MENU_JOURNAL", "MENU_SAVE", "MENU_LOAD", "MENU_SETTINGS", "MENU_MAIN_MENU", "MENU_QUIT"]
	for i in keys.size():
		(_buttons.get_child(i) as Button).text = tr(keys[i])


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.theme = UiTheme.get_theme()
	add_child(_dim)
	_panel = PanelContainer.new()
	_dim.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	_panel.add_child(_buttons)
	var actions: Array[Callable] = [close, _on_inventory, _on_journal, _on_save, _on_load, _on_language, _on_main_menu, func() -> void: get_tree().quit()]
	for action in actions:
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 0)
		b.pressed.connect(action)
		_buttons.add_child(b)
	_load_button = _buttons.get_child(4) as Button
