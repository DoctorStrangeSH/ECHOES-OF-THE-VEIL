class_name CookMenu
extends CanvasLayer
## The stove or campfire (R7b): every recipe, what it needs and what you
## have. Dishes you can make come first. Region screen "cook".

static var instance: CookMenu

var _box: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	instance = self
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	_panel.add_child(_box)
	_panel.visible = false


func _exit_tree() -> void:
	if instance == self:
		instance = null


func is_open() -> bool:
	return _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = tr("COOK_TITLE")
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_box.add_child(title)
	var ids: Array = Cooking.recipes().keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return int(Cooking.can_cook(a)) > int(Cooking.can_cook(b)))
	var first: Button = null
	for id: StringName in ids:
		var r: Dictionary = Cooking.recipes()[id]
		var dish := Inventory.def(StringName(r["makes"]))
		var b := Button.new()
		var needs := PackedStringArray()
		for need: Dictionary in r["needs"]:
			needs.append(Cooking.need_text(need))
		var meal: Dictionary = dish.get("use", {}).get("meal", {})
		var effect := tr("COOK_HEALS") % int(dish.get("use", {}).get("heal", 0))
		if not meal.is_empty():
			effect += " · " + tr(String(meal.get("desc", "")))
		b.text = "%s — %s\n   %s" % [tr(String(dish.get("name", ""))), effect, ", ".join(needs)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 7)
		b.disabled = not Cooking.can_cook(id)
		b.pressed.connect(_cook.bind(id))
		_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel := Button.new()
	cancel.text = tr("CC_BACK")
	cancel.pressed.connect(close)
	_box.add_child(cancel)
	_panel.visible = true
	get_tree().paused = true
	(first if first != null else cancel).grab_focus.call_deferred()


func _cook(id: StringName) -> void:
	close()
	Cooking.cook(id)


func close() -> void:
	_panel.visible = false
	get_tree().paused = false
