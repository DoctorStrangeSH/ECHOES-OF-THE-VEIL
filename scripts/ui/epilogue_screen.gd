class_name EpilogueScreen
extends CanvasLayer
## After the ending choice: a run of cards from data/story/epilogues.json -
## the ending itself, then one card per group (a character, a faction) whose
## condition holds first. Interact for the next card. Afterwards the game
## goes on in the new world state (morning, in your room).

signal finished

const PATH := "res://data/story/epilogues.json"

var _cards: Array[Dictionary] = []
var _index := 0
var _panel: ColorRect
var _title: Label
var _body: Label
var _hint: Label


func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color(0.02, 0.02, 0.04, 0.96)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 60
	box.offset_right = -60
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_title.add_theme_font_size_override("font_size", 12)
	box.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", UiTheme.INK)
	_body.add_theme_font_size_override("font_size", 9)
	box.add_child(_body)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	_hint.add_theme_font_size_override("font_size", 8)
	box.add_child(_hint)
	visible = false


## Cards for the current world state: the ending, then the first matching card of every group.
static func build_cards() -> Array[Dictionary]:
	var data: Variant = DataFiles.read_json(PATH)
	var out: Array[Dictionary] = []
	if not data is Dictionary:
		return out
	for e: Dictionary in data.get("endings", []):
		if GameState.has_flag(StringName("ending.%s" % e["id"])):
			out.append({"title": e["title"], "text": e["text"]})
	var used := {}
	for c: Dictionary in data.get("cards", []):
		var group := String(c.get("group", c.get("title", "")))
		if used.has(group) or not StoryRules.evaluate(c.get("if")):
			continue
		used[group] = true
		out.append({"title": c.get("title", ""), "text": c["text"]})
	out.append({"title": "EPI_END_TITLE", "text": "EPI_END"})
	return out


func open() -> void:
	_cards = build_cards()
	_index = 0
	visible = true
	GameState.lock_player(&"epilogue")
	_show()


func is_open() -> bool:
	return visible


func next() -> void:
	_index += 1
	if _index >= _cards.size():
		visible = false
		GameState.unlock_player(&"epilogue")
		finished.emit()
		return
	_show()


func _show() -> void:
	var c := _cards[_index]
	_title.text = tr(String(c["title"]))
	_body.text = tr(String(c["text"]))
	_hint.text = tr("EPI_HINT") % [_index + 1, _cards.size()]


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack")):
		get_viewport().set_input_as_handled()
		next()
