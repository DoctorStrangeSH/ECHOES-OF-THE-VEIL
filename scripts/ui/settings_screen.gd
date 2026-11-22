class_name SettingsScreen
extends CanvasLayer
## Settings overlay, opened from the main menu and the pause menu.

signal closed

var _panel: PanelContainer
var _list: VBoxContainer
var _desc: Label
var _rows: Dictionary = {}


func _ready() -> void:
	layer = 32  # above the tabbed game window it is opened from
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func open() -> void:
	visible = true
	_refresh()
	(_rows["guidance"] as Button).grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = UiTheme.get_theme()
	add_child(dim)
	# The same window as the game's tabs, so nothing is left half-hidden
	# behind it, wherever settings are opened from.
	_panel = PanelContainer.new()
	dim.add_child(_panel)
	GameMenu.place_window(_panel)
	var center := CenterContainer.new()
	_panel.add_child(center)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(380, 0)
	_list.add_theme_constant_override("separation", 6)
	center.add_child(_list)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_list.add_child(title)
	# Two columns, so everything fits in the window with room to read.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_list.add_child(grid)
	for id: String in ["guidance", "text_speed", "volume", "music", "window_mode", "resolution", "language"]:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_row.bind(id))
		b.focus_entered.connect(_show_desc.bind(id))
		b.mouse_entered.connect(_show_desc.bind(id))
		grid.add_child(b)
		_rows[id] = b
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(380, 30)
	_desc.add_theme_font_size_override("font_size", 9)
	_desc.add_theme_color_override("font_color", UiTheme.INK_DIM)
	_list.add_child(_desc)
	var back := Button.new()
	back.name = "Back"
	back.pressed.connect(close)
	_list.add_child(back)


func _on_row(id: String) -> void:
	match id:
		"guidance":
			GameSettings.cycle_guidance()
		"volume":
			GameSettings.cycle_volume()
		"music":
			GameSettings.cycle_music()
		"window_mode":
			GameSettings.cycle_window_mode()
		"resolution":
			GameSettings.cycle_resolution()
		"text_speed":
			GameSettings.cycle_text_speed()
		"language":
			GameSettings.cycle_language()
	_refresh()
	_show_desc(id)


func _show_desc(id: String) -> void:
	match id:
		"guidance":
			_desc.text = tr("SETTINGS_GUIDANCE_" + GameSettings.guidance.to_upper() + "_DESC")
		"resolution":
			_desc.text = tr("SETTINGS_RESOLUTION_DESC")
		"window_mode":
			_desc.text = tr("SETTINGS_WINDOW_DESC")
		_:
			_desc.text = ""


func _refresh() -> void:
	(_list.get_node("Title") as Label).text = tr("SETTINGS_TITLE")
	(_list.get_node("Back") as Button).text = tr("CC_BACK")
	(_rows["guidance"] as Button).text = tr("SETTINGS_GUIDANCE") % tr("SETTINGS_GUIDANCE_" + GameSettings.guidance.to_upper())
	(_rows["volume"] as Button).text = tr("SETTINGS_VOLUME") % (GameSettings.volume * 10)
	(_rows["music"] as Button).text = tr("SETTINGS_MUSIC") % (GameSettings.music * 10)
	(_rows["window_mode"] as Button).text = tr("SETTINGS_WINDOW_MODE") % tr("SETTINGS_WINDOW_" + GameSettings.window_mode.to_upper())
	var res := GameSettings.resolution
	(_rows["resolution"] as Button).text = tr("SETTINGS_RESOLUTION") % ("%d × %d" % [res.x, res.y])
	(_rows["resolution"] as Button).disabled = GameSettings.window_mode != "windowed"
	(_rows["text_speed"] as Button).text = tr("SETTINGS_TEXT_SPEED") % tr("SETTINGS_TEXT_" + GameSettings.text_speed.to_upper())
	(_rows["language"] as Button).text = tr("SETTINGS_LANGUAGE") % ("Русский" if Localization.get_locale().begins_with("ru") else "English")
	_show_desc("guidance")
