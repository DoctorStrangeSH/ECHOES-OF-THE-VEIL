class_name UiTheme
extends RefCounted
## Shared look for prototype UI. Sizes are in the 480x270 base resolution;
## the canvas_items stretch mode renders text crisply at any window size.
## Replace with a Theme resource built from the Modern UI pack in M2.

const INK := Color(0.93, 0.92, 0.88)
const INK_DIM := Color(0.7, 0.7, 0.74)
const ACCENT := Color(0.55, 0.85, 0.95)
const PANEL := Color(0.08, 0.08, 0.12, 0.92)
const PANEL_EDGE := Color(0.42, 0.56, 0.7)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 9
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", panel_style())

	var normal := _button_style(Color(0.14, 0.15, 0.2), Color(0.3, 0.33, 0.42))
	var hover := _button_style(Color(0.2, 0.24, 0.32), ACCENT)
	var pressed := _button_style(Color(0.1, 0.12, 0.16), ACCENT)
	var disabled := _button_style(Color(0.1, 0.1, 0.13), Color(0.2, 0.2, 0.25))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	# Text fields look like the buttons beside them.
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", hover)
	t.set_stylebox("read_only", "LineEdit", disabled)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.52, 0.58))
	t.set_color("caret_color", "LineEdit", ACCENT)
	_theme = t
	return t


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = PANEL_EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


static func _button_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## Short label for the first binding of an action, e.g. "E".
static func action_hint(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return (e as InputEventKey).as_text_physical_keycode()
	return "?"
