class_name MapScreen
extends CanvasLayer
## The city map (M) and the bus stop's route board ("map:travel").

const CANVAS := Vector2(360, 200)

var travel := false
var _panel: Control
var _buttons: VBoxContainer
var _t := 0.0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.theme = UiTheme.get_theme()
	_panel.draw.connect(_draw_map)
	add_child(_panel)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 2)
	_panel.add_child(_buttons)
	_buttons.position = Vector2(4, 40)
	_buttons.custom_minimum_size = Vector2(104, 0)
	visible = false


func is_open() -> bool:
	return visible


func open(as_travel: bool) -> void:
	travel = as_travel
	visible = true
	get_tree().paused = true
	for c in _buttons.get_children():
		c.queue_free()
	if travel:
		var dests := CityMap.destinations(GameState.current_scene_id)
		var title := Label.new()
		title.text = tr("BUS_TITLE") % CityMap.fare()
		title.add_theme_color_override("font_color", UiTheme.ACCENT)
		title.add_theme_font_size_override("font_size", 9)
		_buttons.add_child(title)
		for id in dests:
			var b := Button.new()
			b.text = tr(String(CityMap.districts()[id]["name"]))
			b.pressed.connect(_ride.bind(id))
			_buttons.add_child(b)
		if dests.is_empty():
			var none := Label.new()
			none.text = tr("BUS_NOWHERE")
			none.add_theme_font_size_override("font_size", 8)
			_buttons.add_child(none)
	var close_b := Button.new()
	close_b.text = tr("CC_BACK")
	close_b.pressed.connect(close)
	_buttons.add_child(close_b)
	(_buttons.get_child(1 if travel and _buttons.get_child_count() > 1 else 0) as Control).call_deferred("grab_focus")


func close() -> void:
	visible = false
	get_tree().paused = false


func _ride(id: String) -> void:
	close()
	CityMap.ride(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"map")):
		get_viewport().set_input_as_handled()
		close()
	elif not visible and event.is_action_pressed(&"map") and GameState.is_playing \
			and not SceneFlow.is_transitioning and not get_tree().paused and not DialogueService.is_active:
		get_viewport().set_input_as_handled()
		open(false)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_panel.queue_redraw()


func _draw_map() -> void:
	var vp := _panel.get_viewport_rect().size
	_panel.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.03, 0.05, 0.9))
	var origin := Vector2(vp.x - CANVAS.x - 6, (vp.y - CANVAS.y) * 0.5 + 8) if travel else (vp - CANVAS) * 0.5
	var area := Rect2(origin, CANVAS)
	# Sea along the top, land below: Greyford sits on a bay.
	_panel.draw_rect(area, Color(0.42, 0.55, 0.36))
	_panel.draw_rect(Rect2(origin, Vector2(CANVAS.x, 34)), Color(0.25, 0.42, 0.6))
	_panel.draw_rect(area, UiTheme.ACCENT, false, 1.0)
	var font := _panel.get_theme_default_font()
	_panel.draw_string(font, origin + Vector2(6, 14), tr("MAP_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 1.0))
	var ds := CityMap.districts()
	for r: Array in CityMap.data().get("roads", []):
		if CityMap.known(r[0]) and CityMap.known(r[1]):
			_panel.draw_line(origin + _pos(ds[r[0]]), origin + _pos(ds[r[1]]), Color(0.85, 0.82, 0.7), 3.0)
	var here := CityMap.district_of(GameState.current_scene_id)
	var quest_scene := &""
	if Journal.pinned != &"":
		quest_scene = QuestGuide.scene_of(QuestGuide.target(Journal.pinned))
	var quest_d := CityMap.district_of(quest_scene)
	for id: String in ds:
		if not CityMap.known(id):
			continue
		var p := origin + _pos(ds[id])
		var has_stop: bool = ds[id].get("stop") != null
		_panel.draw_circle(p, 7.0, Color(0.95, 0.9, 0.75) if not has_stop else Color(0.45, 0.65, 0.95))
		_panel.draw_arc(p, 7.0, 0, TAU, 20, Color(0.1, 0.1, 0.15), 1.5)
		_panel.draw_string(font, p + Vector2(-50, 18), tr(String(ds[id]["name"])), HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color.WHITE)
		if id == here:
			var pulse := 9.0 + sin(_t * 4.0) * 1.5
			_panel.draw_arc(p, pulse, 0, TAU, 24, Color(1.0, 0.85, 0.3), 2.0)
		if id == quest_d and GameSettings.shows_guide():
			_panel.draw_string(font, p + Vector2(6, -6), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3))
	_panel.draw_string(font, origin + Vector2(6, CANVAS.y - 6), tr("MAP_LEGEND"), HORIZONTAL_ALIGNMENT_LEFT, CANVAS.x - 12, 8, Color(0.95, 0.95, 0.95, 0.85))


static func _pos(d: Dictionary) -> Vector2:
	var a: Array = d.get("pos", [0, 0])
	return Vector2(float(a[0]), float(a[1]))
