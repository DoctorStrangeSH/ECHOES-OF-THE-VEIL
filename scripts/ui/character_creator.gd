class_name CharacterCreator
extends Control
## New-game character creator: name, pronouns, look (LimeZu Character
## Generator layers, split into style + colour), and background.
## Works without the art packs (placeholder colour instead of layers).

const BACKGROUNDS_PATH := "res://data/characters/backgrounds.json"
const PRONOUNS := ["they", "she", "he"]
const PLACEHOLDER_COLORS := [
	Color(0.35, 0.55, 0.85), Color(0.8, 0.45, 0.4), Color(0.45, 0.7, 0.45), Color(0.75, 0.6, 0.3),
	Color(0.6, 0.45, 0.75), Color(0.3, 0.65, 0.7), Color(0.85, 0.85, 0.85), Color(0.3, 0.3, 0.35),
]

## One customisable layer: styles and, per style, colour variants (file ids).
class LayerRow:
	var key: String
	var label_key: String
	var optional: bool
	var styles: Array[String] = []
	var variants: Dictionary = {}  # style -> Array[String] of full ids
	var style_idx := 0
	var var_idx := 0
	var style_label: Label
	var var_label: Label

	func current_id() -> String:
		if styles.is_empty():
			return ""
		var style := styles[style_idx]
		if style.is_empty():
			return ""
		var list: Array = variants[style]
		return list[clampi(var_idx, 0, list.size() - 1)]

var appearance := CharacterAppearance.new()
var _rows: Array[LayerRow] = []
var _backgrounds: Dictionary = {}
var _background_ids: Array[String] = []
var _background := "returning_local"
var _pronoun_idx := 0
var _difficulty_idx := 1  # normal
var _difficulty_button: Button
var _difficulty_desc: Label
var _color_idx := 0
var _has_assets := false

var _preview: LayeredCharacterSprite
var _name_edit: LineEdit
var _pronoun_button: Button
var _bg_desc: Label
var _bg_button: Button
var _preview_dir := 3
var _preview_timer := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_backgrounds()
	_has_assets = AssetLibrary.has_limezu()
	if _has_assets:
		_rows = [
			_make_row("body", "CC_SKIN", false, "Bodies"),
			_make_row("eyes", "CC_EYES", false, "Eyes"),
			_make_row("outfit", "CC_OUTFIT", false, "Outfits"),
			_make_row("hairstyle", "CC_HAIR", true, "Hairstyles"),
			_make_row("accessory", "CC_ACCESSORY", true, "Accessories"),
		]
		_select_defaults()
	_build()
	_apply()


func _process(delta: float) -> void:
	_preview_timer += delta
	if _preview_timer > 1.6:
		_preview_timer = 0.0
		_preview_dir = (_preview_dir + 1) % 4
		_preview.play(&"walk", _preview_dir as LayeredCharacterSprite.Dir)


# --- Data ----------------------------------------------------------------------

func _load_backgrounds() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BACKGROUNDS_PATH))
	if data is Dictionary:
		_backgrounds = data
		for id: String in data:
			_background_ids.append(id)


func _make_row(key: String, label_key: String, optional: bool, folder: String) -> LayerRow:
	var row := LayerRow.new()
	row.key = key
	row.label_key = label_key
	row.optional = optional
	if optional:
		row.styles.append("")
	for id in AssetLibrary.list_png_ids(AssetLibrary.CHARACTER_GENERATOR + "/" + folder + "/16x16"):
		var style := style_of(id)
		if not row.variants.has(style):
			row.variants[style] = []
			row.styles.append(style)
		(row.variants[style] as Array).append(id)
	return row


## "Hairstyle_07_03" -> "Hairstyle_07"; "Body_03" -> "Body_03";
## "Accessory_01_Ladybug_02" -> "Accessory_01_Ladybug".
static func style_of(id: String) -> String:
	var parts := id.split("_")
	if parts.size() >= 3 and parts[-1].is_valid_int():
		return "_".join(parts.slice(0, parts.size() - 1))
	return id


func _select_defaults() -> void:
	var defaults := CharacterAppearance.default_player()
	for row in _rows:
		var want: String = defaults.get(row.key)
		var style := style_of(want)
		var si := row.styles.find(style)
		if si >= 0:
			row.style_idx = si
			row.var_idx = 0 if style.is_empty() else maxi(0, (row.variants[style] as Array).find(want))


func _apply() -> void:
	appearance = CharacterAppearance.new()
	for row in _rows:
		appearance.set(row.key, row.current_id())
	appearance.placeholder_color = PLACEHOLDER_COLORS[_color_idx]
	_preview.appearance = appearance
	_preview.play(&"walk", _preview_dir as LayeredCharacterSprite.Dir, true)
	for row in _rows:
		var style := row.styles[row.style_idx] if not row.styles.is_empty() else ""
		row.style_label.text = tr("CC_NONE") if style.is_empty() else "%d/%d" % [row.style_idx + (0 if row.optional else 1), row.styles.size() - (1 if row.optional else 0)]
		var n: int = 0 if style.is_empty() else (row.variants[style] as Array).size()
		row.var_label.text = "-" if n <= 1 else "%d/%d" % [row.var_idx + 1, n]


func _step(row: LayerRow, what: String, delta: int) -> void:
	if row.styles.is_empty():
		return
	if what == "style":
		row.style_idx = posmod(row.style_idx + delta, row.styles.size())
		row.var_idx = 0
	else:
		var style := row.styles[row.style_idx]
		if style.is_empty():
			return
		row.var_idx = posmod(row.var_idx + delta, (row.variants[style] as Array).size())
	_apply()


func _randomize() -> void:
	for row in _rows:
		if row.styles.is_empty():
			continue
		row.style_idx = randi() % row.styles.size()
		if row.key == "accessory" and randf() < 0.6:
			row.style_idx = 0  # mostly no accessory
		var style := row.styles[row.style_idx]
		row.var_idx = 0 if style.is_empty() else randi() % (row.variants[style] as Array).size()
	_color_idx = randi() % PLACEHOLDER_COLORS.size()
	_apply()


func _cycle_pronouns() -> void:
	_pronoun_idx = (_pronoun_idx + 1) % PRONOUNS.size()
	_pronoun_button.text = tr("CC_PRONOUN_" + String(PRONOUNS[_pronoun_idx]).to_upper())


func _cycle_difficulty() -> void:
	_difficulty_idx = (_difficulty_idx + 1) % GameState.DIFFICULTIES.size()
	_show_difficulty()


func _show_difficulty() -> void:
	var d := GameState.DIFFICULTIES[_difficulty_idx].to_upper()
	_difficulty_button.text = tr("CC_DIFFICULTY_" + d)
	_difficulty_desc.text = tr("CC_DIFFICULTY_" + d + "_DESC")


func _cycle_color() -> void:
	_color_idx = (_color_idx + 1) % PLACEHOLDER_COLORS.size()
	_apply()


func _set_background(id: String) -> void:
	_background = id
	var def: Dictionary = _backgrounds.get(id, {})
	_bg_button.text = tr(def.get("name", id))
	_bg_desc.text = tr(def.get("desc", ""))


func _cycle_background() -> void:
	if _background_ids.is_empty():
		return
	var i := _background_ids.find(_background)
	_set_background(_background_ids[(i + 1) % _background_ids.size()])


func _on_begin() -> void:
	var player_name := _name_edit.text.strip_edges()
	if player_name.is_empty():
		player_name = tr("CC_DEFAULT_NAME")
	SceneFlow.begin_new_game({
		"name": player_name.left(18),
		"pronouns": PRONOUNS[_pronoun_idx],
		"difficulty": GameState.DIFFICULTIES[_difficulty_idx],
		"background": _background,
		"appearance": appearance,
	})


# --- UI --------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Everything must fit the 480x270 viewport (tested); the scroll container
	# is only a safety net for long translations.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	var title := Label.new()
	title.text = tr("CC_TITLE")
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.add_theme_font_size_override("font_size", 12)
	root.add_child(title)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top)

	# Preview + identity
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160, 0)
	left.add_theme_constant_override("separation", 3)
	top.add_child(left)
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(160, 84)
	left.add_child(stage)
	var holder := Control.new()
	stage.add_child(holder)
	_preview = LayeredCharacterSprite.new()
	_preview.scale = Vector2(2.5, 2.5)
	_preview.position = Vector2(72, 80)
	holder.add_child(_preview)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = tr("CC_NAME_PLACEHOLDER")
	_name_edit.max_length = 18
	left.add_child(_labeled(tr("CC_NAME"), _name_edit))
	_pronoun_button = Button.new()
	_pronoun_button.pressed.connect(_cycle_pronouns)
	_pronoun_button.text = tr("CC_PRONOUN_" + String(PRONOUNS[_pronoun_idx]).to_upper())
	left.add_child(_labeled(tr("CC_PRONOUNS"), _pronoun_button))
	_difficulty_button = Button.new()
	_difficulty_button.pressed.connect(_cycle_difficulty)
	left.add_child(_labeled(tr("CC_DIFFICULTY"), _difficulty_button))
	_bg_button = Button.new()
	_bg_button.pressed.connect(_cycle_background)
	_bg_button.clip_text = true
	left.add_child(_labeled(tr("CC_BACKGROUND"), _bg_button))

	# Look + what the choices mean
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	top.add_child(right)
	if _has_assets:
		for row in _rows:
			right.add_child(_layer_row_ui(row))
	else:
		var note := Label.new()
		note.text = tr("MENU_NO_ASSETS")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 8)
		right.add_child(note)
		var color_btn := Button.new()
		color_btn.text = tr("CC_COLOR")
		color_btn.pressed.connect(_cycle_color)
		right.add_child(color_btn)
	var rnd := Button.new()
	rnd.text = tr("CC_RANDOM")
	rnd.pressed.connect(_randomize)
	right.add_child(rnd)
	_difficulty_desc = _note()
	right.add_child(_difficulty_desc)
	_bg_desc = _note()
	right.add_child(_bg_desc)
	_show_difficulty()

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(actions)
	var back := Button.new()
	back.text = tr("CC_BACK")
	back.pressed.connect(SceneFlow.show_main_menu)
	actions.add_child(back)
	var begin := Button.new()
	begin.text = tr("CC_BEGIN")
	begin.pressed.connect(_on_begin)
	actions.add_child(begin)
	_set_background(_background)
	_name_edit.grab_focus.call_deferred()


func _note() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", UiTheme.INK_DIM)
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _labeled(text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(52, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func _layer_row_ui(row: LayerRow) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = tr(row.label_key)
	l.custom_minimum_size = Vector2(62, 0)
	h.add_child(l)
	row.style_label = Label.new()
	row.var_label = Label.new()
	for part in [["style", row.style_label], ["color", row.var_label]]:
		var prev := Button.new()
		prev.text = "<"
		prev.pressed.connect(_step.bind(row, part[0], -1))
		h.add_child(prev)
		var lab: Label = part[1]
		lab.custom_minimum_size = Vector2(38, 0)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(lab)
		var next := Button.new()
		next.text = ">"
		next.pressed.connect(_step.bind(row, part[0], 1))
		h.add_child(next)
		if part[0] == "style":
			var c := Label.new()
			c.text = tr("CC_COLOR_SHORT")
			c.add_theme_color_override("font_color", UiTheme.INK_DIM)
			h.add_child(c)
	return h
