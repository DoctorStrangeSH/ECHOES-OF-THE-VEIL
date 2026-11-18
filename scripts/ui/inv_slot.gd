class_name InvSlot
extends Button
## One square of the bag, or one of the hero's two equipment slots. Click to
## look at the item, double-click to use or wear it, and drag it: onto another
## square to rearrange the bag, onto the hero's slot to wear it, or out of a
## worn slot back into the bag to take it off.

signal picked(id: StringName)
signal activated(id: StringName)

const SIZE := Vector2(24, 24)

var item: StringName = &""
## "" for a bag square, or the equipment slot ("weapon", "trinket").
var equip_slot := ""
var _count: Label


func setup(id: StringName, slot := "") -> InvSlot:
	item = id
	equip_slot = slot
	custom_minimum_size = SIZE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 16)
	add_theme_stylebox_override("normal", UiTheme.inset_style())
	add_theme_stylebox_override("hover", UiTheme.inset_style())
	add_theme_stylebox_override("pressed", UiTheme.inset_style())
	toggle_mode = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 7)
	_count.add_theme_color_override("font_color", UiTheme.INK)
	_count.add_theme_color_override("font_outline_color", UiTheme.PAPER)
	_count.add_theme_constant_override("outline_size", 2)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 1)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	refresh()
	pressed.connect(func() -> void: picked.emit(item))
	gui_input.connect(_on_gui_input)
	return self


func refresh() -> void:
	text = ""
	icon = Inventory.icon_of(item) if item != &"" else null
	if icon == null and item != &"":
		icon = AssetLibrary.placeholder(Vector2i(12, 12), Color(String(Inventory.def(item).get("color", "#a08060"))))
	var n := Inventory.count(item) if item != &"" else 0
	_count.text = str(n) if n > 1 else ""
	tooltip_text = tr(String(Inventory.def(item).get("name", ""))) if item != &"" else tr("INV_SLOT_" + equip_slot.to_upper()) if equip_slot != "" else ""


func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).double_click and item != &"":
		activated.emit(item)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if item == &"":
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(16, 16)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"item": item, "from_slot": equip_slot}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item"):
		return false
	if equip_slot != "":
		return String(Inventory.def(data["item"]).get("category", "")) == equip_slot
	return true


func _drop_data(_at: Vector2, data: Variant) -> void:
	var id: StringName = data["item"]
	if equip_slot != "":
		Inventory.equip(id)
	elif String(data.get("from_slot", "")) != "":
		Inventory.unequip(String(data["from_slot"]))
		if item != &"":
			Inventory.move(id, item)
	else:
		Inventory.move(id, item)
	Sfx.play(&"ui_click")
