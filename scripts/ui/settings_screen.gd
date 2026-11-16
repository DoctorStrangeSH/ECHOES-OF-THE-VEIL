class_name SettingsScreen
extends CanvasLayer
## Settings overlay, opened from the main menu and the pause menu.

signal closed

var _panel: PanelContainer
var _list: VBoxContainer
var _desc: Label
var _rows: Dictionary = {}


func _ready() -> void:
	layer = 30
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
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 0)
	dim.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_panel.add_child(_list)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_list.add_child(title)
	for id: String in ["guidance", "volume", "music", "fullscreen", "language"]:
		var b := Button.new()
		b.pressed.connect(_on_row.bind(id))
		b.focus_entered.connect(_show_desc.bind(id))
		_list.add_child(b)
		_rows[id] = b
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(290, 40)
	_desc.add_theme_font_size_override("font_size", 8)
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
		"fullscreen":
			GameSettings.toggle_fullscreen()
		"language":
			GameSettings.cycle_language()
	_refresh()
	_show_desc(id)


func _show_desc(id: String) -> void:
	_desc.text = tr("SETTINGS_GUIDANCE_" + GameSettings.guidance.to_upper() + "_DESC") if id == "guidance" else ""


func _refresh() -> void:
	(_list.get_node("Title") as Label).text = tr("SETTINGS_TITLE")
	(_list.get_node("Back") as Button).text = tr("CC_BACK")
	(_rows["guidance"] as Button).text = tr("SETTINGS_GUIDANCE") % tr("SETTINGS_GUIDANCE_" + GameSettings.guidance.to_upper())
	(_rows["volume"] as Button).text = tr("SETTINGS_VOLUME") % (GameSettings.volume * 10)
	(_rows["music"] as Button).text = tr("SETTINGS_MUSIC") % (GameSettings.music * 10)
	(_rows["fullscreen"] as Button).text = tr("SETTINGS_FULLSCREEN") % tr("SETTINGS_ON" if GameSettings.fullscreen else "SETTINGS_OFF")
	(_rows["language"] as Button).text = tr("SETTINGS_LANGUAGE") % ("Русский" if Localization.get_locale().begins_with("ru") else "English")
	_show_desc("guidance")
