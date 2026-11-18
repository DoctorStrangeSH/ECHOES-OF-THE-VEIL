class_name SeedMenu
extends CanvasLayer
## Which seed to plant, when there is more than one kind in the bag. The last
## kind planted comes first, so planting a row is E, E, E...

static var instance: SeedMenu

var _box: VBoxContainer
var _panel: PanelContainer
var _plot: StringName = &""


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
	_box.add_theme_constant_override("separation", 2)
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


func open(plot_id: StringName) -> void:
	_plot = plot_id
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = tr("FARM_SEED_TITLE")
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_box.add_child(title)
	var seeds := Farm.seeds_held()
	if seeds.has(Farm.last_seed):
		seeds.erase(Farm.last_seed)
		seeds.push_front(Farm.last_seed)
	for s in seeds:
		var d := Inventory.def(s)
		var c := Farm.crop(Farm.crop_for_seed(s))
		var b := Button.new()
		b.text = tr("FARM_SEED_ROW") % [tr(String(d.get("name", ""))), Inventory.count(s), int(c.get("days", 1))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if d.has("icon"):
			b.icon = Inventory.icon_of(s)
			b.add_theme_constant_override("icon_max_width", 14)
		b.pressed.connect(_plant.bind(s))
		_box.add_child(b)
	var cancel := Button.new()
	cancel.text = tr("CC_BACK")
	cancel.pressed.connect(close)
	_box.add_child(cancel)
	_panel.visible = true
	get_tree().paused = true
	(_box.get_child(1) as Button).grab_focus.call_deferred()


func _plant(seed: StringName) -> void:
	close()
	Farm.plant(_plot, seed)


func close() -> void:
	_panel.visible = false
	get_tree().paused = false
