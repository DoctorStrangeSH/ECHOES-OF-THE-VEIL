class_name InventoryScreen
extends CanvasLayer
## Inventory (I): items by category with details, equip/use, and the
## Attunements tab where Resonance is spent. Pauses the game while open.

const FILTERS: PackedStringArray = ["", "weapon", "trinket", "consumable", "key"]

var _dim: ColorRect
var _title: Label
var _summary: Label
var _tabs: HBoxContainer
var _filters: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _hint: Label
var _tab := "items"
var _filter := ""
var _selected: StringName = &""


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_dim.visible = false
	Inventory.changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return _dim.visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"inventory") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		close()
	elif not is_open() and event.is_action_pressed(&"inventory") and _can_open():
		get_viewport().set_input_as_handled()
		open()


func _can_open() -> bool:
	return GameState.is_playing and not SceneFlow.is_transitioning and not DialogueService.is_active \
		and not get_tree().paused


func open() -> void:
	get_tree().paused = true
	_dim.visible = true
	Sfx.play(&"ui_open")
	_refresh()


func close() -> void:
	_dim.visible = false
	get_tree().paused = false


func _on_inventory_changed() -> void:
	if is_open():
		_refresh()


func _set_tab(tab: String) -> void:
	_tab = tab
	_selected = &""
	Sfx.play(&"ui_click")
	_refresh()


func _set_filter(f: String) -> void:
	_filter = f
	_selected = &""
	_refresh()


func _select(id: StringName) -> void:
	_selected = id
	Sfx.play(&"ui_click")
	_refresh()


func _refresh() -> void:
	_title.text = tr("INV_TITLE")
	_hint.text = tr("INV_HINT")
	var weapon_name := tr(Inventory.def(Inventory.equipped["weapon"]).get("name", ""))
	var trinket: StringName = Inventory.equipped.get("trinket", &"")
	var trinket_name := tr(Inventory.def(trinket).get("name", "")) if trinket != &"" else tr("CC_NONE")
	_summary.text = tr("INV_SUMMARY") % [weapon_name, trinket_name, Inventory.money, Inventory.resonance]
	for i in _tabs.get_child_count():
		var b := _tabs.get_child(i) as Button
		b.button_pressed = (i == 0 and _tab == "items") or (i == 1 and _tab == "attunements")
	_tabs.get_child(0).set("text", tr("INV_TAB_ITEMS"))
	_tabs.get_child(1).set("text", tr("INV_TAB_ATTUNEMENTS"))
	_filters.visible = _tab == "items"
	for i in FILTERS.size():
		var fb := _filters.get_child(i) as Button
		fb.text = tr("INV_FILTER_" + (FILTERS[i].to_upper() if not FILTERS[i].is_empty() else "ALL"))
		fb.button_pressed = FILTERS[i] == _filter
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	if _tab == "items":
		_fill_items()
	else:
		_fill_attunements()


func _fill_items() -> void:
	var ids := Inventory.list(_filter)
	if ids.is_empty():
		_list.add_child(_label(tr("INV_EMPTY"), UiTheme.INK_DIM))
		return
	if _selected == &"" or not ids.has(_selected):
		_selected = ids[0]
	for id in ids:
		var d := Inventory.def(id)
		var b := Button.new()
		var equipped_mark := " [E]" if Inventory.equipped.values().has(id) else ""
		var n := Inventory.count(id)
		b.text = tr(d.get("name", "")) + (" ×%d" % n if n > 1 else "") + equipped_mark
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(_select.bind(id))
		_list.add_child(b)
		if id == _selected:
			b.grab_focus.call_deferred()
	_show_item(_selected)


func _show_item(id: StringName) -> void:
	var d := Inventory.def(id)
	_detail.add_child(_label(tr(d.get("name", "")), UiTheme.ACCENT, 11))
	_detail.add_child(_label(tr("INV_CATEGORY_" + String(d.get("category", "")).to_upper()), UiTheme.INK_DIM, 8))
	_detail.add_child(_label(tr(d.get("desc", "")), UiTheme.INK))
	if d.has("weapon"):
		var w: Dictionary = d["weapon"]
		var combo := PackedStringArray()
		for v: Variant in w.get("combo", []):
			combo.append(str(int(v)))
		_detail.add_child(_label(tr("INV_WEAPON_STATS") % ["-".join(combo), int(w.get("reach", 12)), float(w.get("cooldown", 0.35))], UiTheme.INK_DIM, 8))
	var cat: String = d.get("category", "")
	if cat in ["weapon", "trinket"]:
		var b := Button.new()
		var is_on: bool = Inventory.equipped.get(cat) == id
		b.text = tr("INV_UNEQUIP") if is_on and id != Inventory.DEFAULT_WEAPON else tr("INV_EQUIP")
		b.disabled = is_on and id == Inventory.DEFAULT_WEAPON
		b.pressed.connect(_on_equip.bind(id, is_on))
		_detail.add_child(b)
	elif cat == "consumable":
		var b := Button.new()
		b.text = tr("INV_USE")
		b.pressed.connect(func() -> void: Inventory.use(id))
		_detail.add_child(b)


func _on_equip(id: StringName, is_on: bool) -> void:
	if is_on:
		Inventory.unequip(Inventory.def(id).get("category", "trinket"))
	else:
		Inventory.equip(id)


func _fill_attunements() -> void:
	_list.add_child(_label(tr("INV_RESONANCE_NOTE") % Inventory.resonance, UiTheme.INK_DIM, 8))
	for id: StringName in Inventory.attunement_defs:
		var d: Dictionary = Inventory.attunement_defs[id]
		var b := Button.new()
		var owned := Inventory.has_attunement(id)
		b.text = ("[x] " if owned else "[ ] ") + tr(d.get("name", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(_select.bind(id))
		_list.add_child(b)
	if _selected == &"" or not Inventory.attunement_defs.has(_selected):
		_selected = Inventory.attunement_defs.keys()[0] if not Inventory.attunement_defs.is_empty() else &""
	if _selected == &"":
		return
	var d: Dictionary = Inventory.attunement_defs[_selected]
	_detail.add_child(_label(tr(d.get("name", "")), UiTheme.ACCENT, 11))
	_detail.add_child(_label(tr(d.get("desc", "")), UiTheme.INK))
	_detail.add_child(_label(tr("INV_COST") % int(d.get("cost", 0)), UiTheme.INK_DIM, 8))
	var req := StringName(d.get("requires", ""))
	if req != &"" and not Inventory.has_attunement(req):
		_detail.add_child(_label(tr("INV_REQUIRES") % tr(Inventory.attunement_defs[req].get("name", "")), UiTheme.INK_DIM, 8))
	if Inventory.has_attunement(_selected):
		_detail.add_child(_label(tr("INV_ATTUNED"), Color(0.6, 0.95, 0.7)))
	else:
		var b := Button.new()
		b.text = tr("INV_ATTUNE")
		b.disabled = not Inventory.can_attune(_selected)
		b.pressed.connect(func() -> void: Inventory.attune(_selected))
		_detail.add_child(b)


func _label(text: String, color: Color, size: int = 9) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.theme = UiTheme.get_theme()
	add_child(_dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	_dim.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	head.add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(_tabs)
	for tab in ["items", "attunements"]:
		var b := Button.new()
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(tab))
		_tabs.add_child(b)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 8)
	_summary.add_theme_color_override("font_color", UiTheme.INK_DIM)
	root.add_child(_summary)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 2)
	root.add_child(_filters)
	for f in FILTERS:
		var b := Button.new()
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(_set_filter.bind(f))
		_filters.add_child(b)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	root.add_child(cols)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_list)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 3)
	right.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 7)
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	root.add_child(_hint)
