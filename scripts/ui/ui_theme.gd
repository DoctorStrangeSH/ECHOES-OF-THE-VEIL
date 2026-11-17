class_name UiTheme
extends RefCounted
## The game's look, built from LimeZu's Modern UI pack (Modern_UI_Style_1):
## paper panels in wooden frames, beige buttons that press in, dark ink.
## Sizes are in the 480x270 base resolution; the canvas_items stretch mode
## renders text crisply at any window size. Without the art pack the same
## colours are drawn as flat boxes.

## Ink on paper (panels, windows, dialogue).
const INK := Color(0.23, 0.15, 0.1)
const INK_DIM := Color(0.43, 0.33, 0.25)
const ACCENT := Color(0.09, 0.36, 0.44)
const GOLD := Color(0.58, 0.38, 0.05)
const WARN := Color(0.66, 0.2, 0.14)
const GOOD := Color(0.2, 0.44, 0.18)
const BLUE := Color(0.16, 0.3, 0.6)
const PAPER := Color(0.82, 0.75, 0.61)
const PAPER_DARK := Color(0.76, 0.68, 0.55)
## Text drawn straight over the world (clock, objective, toasts): light, with
## a dark outline.
const HUD_INK := Color(0.96, 0.94, 0.88)
const HUD_DIM := Color(0.78, 0.78, 0.8)
const HUD_ACCENT := Color(0.6, 0.88, 0.96)
## Kept for old callers.
const PANEL := Color(0.82, 0.75, 0.61, 0.97)
const PANEL_EDGE := Color(0.5, 0.3, 0.16)

const SHEET := "modern_ui/16x16/Modern_UI_Style_1.png"
## Pieces of the sheet: [x, y, w, h, left, top, right, bottom]. The margins
## stop just short of each piece's flat middle, so only plain paper is
## stretched (otherwise the frame's inner shadow smears into a band).
const WINDOW := [8, 8, 32, 31, 8, 8, 7, 7]
const INSET := [58, 169, 28, 29, 6, 7, 6, 6]
const BUTTON := [60, 251, 24, 25, 4, 4, 4, 4]
const BUTTON_PRESSED := [13, 300, 22, 24, 4, 4, 4, 4]
const BUTTON_DISABLED := [12, 251, 24, 25, 4, 4, 4, 4]
const SLOT := [61, 301, 22, 23, 4, 4, 4, 4]

static var _theme: Theme
static var _sheet: Texture2D


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_sheet = AssetLibrary.load_texture(SHEET)
	var t := Theme.new()
	t.default_font_size = 9
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", window_style())
	t.set_stylebox("panel", "Panel", window_style())

	var normal := _piece(BUTTON, PAPER, PANEL_EDGE)
	var hover := _piece(BUTTON, Color(0.9, 0.84, 0.7), ACCENT)
	if hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = Color(1.1, 1.07, 1.0)
	var focus := _piece(BUTTON, Color(0.9, 0.84, 0.7), ACCENT)
	var pressed := _piece(BUTTON_PRESSED, PAPER_DARK, PANEL_EDGE)
	var disabled := _piece(BUTTON_DISABLED, Color(0.7, 0.66, 0.6), Color(0.55, 0.5, 0.45))
	for s: StyleBox in [normal, hover, focus, pressed, disabled]:
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 3
		s.content_margin_bottom = 4
	# The pressed piece is drawn one pixel lower: the button sinks.
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", _focus_ring())
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(0.1, 0.06, 0.04))
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.06, 0.04))
	t.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.06, 0.04))
	t.set_color("font_disabled_color", "Button", Color(0.48, 0.42, 0.36))
	# Text fields look like the buttons beside them, a shade darker.
	var field := _piece(SLOT, PAPER_DARK, PANEL_EDGE)
	field.content_margin_left = 6
	field.content_margin_right = 6
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", _focus_ring())
	t.set_stylebox("read_only", "LineEdit", disabled)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.42, 0.34))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	# Scroll bars: a thin dark rail with a paper grabber.
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.35, 0.24, 0.16, 0.35)
	rail.set_corner_radius_all(2)
	rail.content_margin_left = 3
	rail.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.5, 0.33, 0.2)
	grab.set_corner_radius_all(2)
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, rail)
		t.set_stylebox("grabber", kind, grab)
		t.set_stylebox("grabber_highlight", kind, grab)
		t.set_stylebox("grabber_pressed", kind, grab)
	_theme = t
	return t


## The big window: paper in a wooden frame.
static func window_style() -> StyleBox:
	var s := _piece(WINDOW, PANEL, PANEL_EDGE)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## A smaller box inside a window (portraits, detail areas).
static func inset_style() -> StyleBox:
	var s := _piece(INSET, PAPER_DARK, PANEL_EDGE)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func panel_style() -> StyleBox:
	return window_style()


static func _piece(r: Array, flat_bg: Color, flat_edge: Color) -> StyleBox:
	if _sheet == null:
		_sheet = AssetLibrary.load_texture(SHEET)
	if _sheet != null:
		var s := StyleBoxTexture.new()
		s.texture = _sheet
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.texture_margin_left = r[4]
		s.texture_margin_top = r[5]
		s.texture_margin_right = r[6]
		s.texture_margin_bottom = r[7]
		return s
	var f := StyleBoxFlat.new()
	f.bg_color = flat_bg
	f.border_color = flat_edge
	f.set_border_width_all(1)
	f.set_corner_radius_all(2)
	return f


static func _focus_ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color(ACCENT, 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.expand_margin_left = 1
	s.expand_margin_right = 1
	s.expand_margin_top = 1
	s.expand_margin_bottom = 1
	return s


## Outline settings for text drawn over the world.
static func hud_label(l: Label, color: Color = HUD_INK, size: int = 8) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04))
	l.add_theme_constant_override("outline_size", 3)


## Short label for the first binding of an action, e.g. "E".
static func action_hint(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var t := (e as InputEventKey).as_text_physical_keycode()
			return "Esc" if t == "Escape" else t
	return "?"


## A living backdrop for menus: the harbour, drifting slowly, a little dim.
static func backdrop(parent: Control) -> Control:
	var tex := AssetLibrary.load_texture("derived/menu/greyford_harbour.png")
	if tex == null:
		var bg := ColorRect.new()
		bg.color = Color(0.1, 0.08, 0.07)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
		return bg
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.modulate = Color(0.62, 0.6, 0.66)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	var drift := pic.create_tween().set_loops()
	pic.position = Vector2(0, -60)
	drift.tween_property(pic, "position", Vector2(-190, -150), 40.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(pic, "position", Vector2(0, -60), 40.0).set_trans(Tween.TRANS_SINE)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.06, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	return holder


## The pack's own pointer and hand as mouse cursors, scaled with the window
## (system cursors are not scaled by the stretch mode).
static func apply_cursors(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sheet := AssetLibrary.load_texture(SHEET)
	if sheet == null:
		return
	var img := sheet.get_image()
	if img == null:
		return
	var k := maxi(1, int(round(window.size.y / 270.0)))
	for spec: Array in [[Input.CURSOR_ARROW, Rect2i(162, 322, 12, 12), Vector2(1, 1)], [Input.CURSOR_POINTING_HAND, Rect2i(177, 322, 15, 14), Vector2(5, 1)]]:
		var part := img.get_region(spec[1])
		part.resize(part.get_width() * k, part.get_height() * k, Image.INTERPOLATE_NEAREST)
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(part), spec[0], spec[2] * k)
