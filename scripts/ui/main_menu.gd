class_name MainMenu
extends Control
## Title screen: new game, continue, language, quit, credits.

var _buttons: VBoxContainer
var _title: Label
var _subtitle: Label
var _footer: Label
var _debug_target := 0
var _debug_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	(_buttons.get_child(1 if SaveService.has_any_save() else 0) as Button).grab_focus()


func _on_new_game() -> void:
	SceneFlow.start_new_game()


func _on_continue() -> void:
	SaveService.load_game()


func _on_debug_start() -> void:
	DebugStart.start(DebugStart.TARGETS[_debug_target])


func _on_debug_cycle() -> void:
	_debug_target = (_debug_target + 1) % DebugStart.TARGETS.size()
	_refresh()


func _on_language() -> void:
	Localization.set_locale("en" if Localization.get_locale().begins_with("ru") else "ru")
	_refresh()


func _refresh() -> void:
	_subtitle.text = tr("MENU_TAGLINE")
	var keys := ["MENU_NEW_GAME", "MENU_CONTINUE_GAME", "MENU_LANGUAGE", "MENU_QUIT"]
	for i in keys.size():
		(_buttons.get_child(i) as Button).text = tr(keys[i])
	(_buttons.get_child(1) as Button).disabled = not SaveService.has_any_save()
	var footer := tr("CREDITS_LIMEZU")
	if not AssetLibrary.has_limezu():
		footer += "\n" + tr("MENU_NO_ASSETS")
	_footer.text = footer
	if _debug_button != null:
		_debug_button.text = tr("MENU_DEBUG_START") % DebugStart.TARGETS[_debug_target]


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 6)
	add_child(center)

	_title = Label.new()
	_title.text = "ECHOES OF THE VEIL"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	center.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", UiTheme.INK_DIM)
	center.add_child(_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	var actions: Array[Callable] = [_on_new_game, _on_continue, _on_language, func() -> void: get_tree().quit()]
	for action in actions:
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(action)
		_buttons.add_child(b)
	center.add_child(_buttons)
	if DebugStart.available():
		_debug_button = Button.new()
		_debug_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_debug_button.pressed.connect(_on_debug_start)
		var cycle := Button.new()
		cycle.text = ">"
		cycle.pressed.connect(_on_debug_cycle)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(_debug_button)
		row.add_child(cycle)
		center.add_child(row)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 7)
	_footer.add_theme_color_override("font_color", UiTheme.INK_DIM)
	add_child(_footer)
	_footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 6)
	_footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
