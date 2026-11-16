class_name WorldMapScreen
extends CanvasLayer
## The coach timetable ("world:travel", R12a): the coast with the towns you
## know, the roads between them, and what a ticket costs. ←/→ to choose,
## E to buy a ticket and go, Esc to stay.

var selected := ""
## How you travel from here: "coach", "car" (your own) or "ferry".
var mode := "coach"
var _order: Array[String] = []
var _root: Control
var _info: VBoxContainer
var _hint: Label
var _t := 0.0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	_root.draw.connect(_draw_map)
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(8, 3)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.add_theme_font_size_override("font_size", 11)
	_root.add_child(title)
	var panel := PanelContainer.new()
	panel.position = Vector2(314, 22)
	panel.custom_minimum_size = Vector2(160, 226)
	panel.size = Vector2(160, 226)
	_root.add_child(panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	panel.add_child(_info)
	_hint = Label.new()
	_hint.position = Vector2(8, 254)
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	_root.add_child(_hint)
	visible = false


func is_open() -> bool:
	return visible


func open(travel_mode := "coach") -> void:
	mode = travel_mode
	_order.clear()
	for id: String in WorldMap.cities():
		if WorldMap.known(id):
			_order.append(id)
	var here := WorldMap.city_of(GameState.current_scene_id)
	var routes := WorldMap.routes_from(here).filter(func(r: Dictionary) -> bool: return String(r.get("mode", "coach")) == mode)
	selected = String(routes[0]["dest"]) if not routes.is_empty() else here
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_up"):
		_step(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_down"):
		_step(1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_go()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var p := (event as InputEventMouseButton).position
		for id in _order:
			if _pos(id).distance_to(p) < 12.0:
				if id == selected:
					_go()
				selected = id
				_refresh()
				return


func _step(d: int) -> void:
	if _order.is_empty():
		return
	selected = _order[(_order.find(selected) + d + _order.size()) % _order.size()]
	_refresh()


func _route_to(id: String) -> Dictionary:
	return WorldMap.route_to(id, mode)


func _go() -> void:
	if _route_to(selected).is_empty():
		return
	var to := selected
	close()
	WorldMap.travel(to, mode)


func _pos(id: String) -> Vector2:
	var p: Array = WorldMap.cities()[id].get("pos", [100, 100])
	return Vector2(8, 24) + Vector2(float(p[0]), float(p[1]))


func _line(text: String, color: Color, size := 8) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_info.add_child(l)


func _refresh() -> void:
	(_root.get_node("Title") as Label).text = tr("CAR_TITLE") if mode == "car" else (tr("FERRY_TITLE") if mode == "ferry" else tr("TRAVEL_TITLE"))
	_hint.text = tr("TRAVEL_HINT")
	for c in _info.get_children():
		c.queue_free()
	if selected == "":
		return
	var c: Dictionary = WorldMap.cities()[selected]
	_line(tr(String(c["name"])), UiTheme.ACCENT, 10)
	_line(tr(String(c.get("desc", ""))), UiTheme.INK_DIM)
	var here := WorldMap.city_of(GameState.current_scene_id)
	if selected == here:
		_line(tr("MAP_YOU_ARE_HERE"), Color(1.0, 0.85, 0.35))
		return
	var r := _route_to(selected)
	if r.is_empty():
		_line(tr("TRAVEL_NO_ROUTE"), Color(1.0, 0.7, 0.5))
		return
	_line(tr("TRAVEL_MODE_" + String(r.get("mode", "coach")).to_upper()), Color(0.55, 0.75, 1.0))
	var minutes := int(r.get("minutes", 60))
	_line(tr("TRAVEL_TICKET") % [int(r.get("fare", 0)), minutes / 60, minutes % 60], UiTheme.INK)
	if Inventory.money < int(r.get("fare", 0)):
		_line(tr("TRAVEL_NO_MONEY"), Color(1.0, 0.6, 0.5))


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_root.queue_redraw()


func _draw_map() -> void:
	var vp := _root.get_viewport_rect().size
	_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.06, 0.94))
	var area := Rect2(Vector2(4, 22), Vector2(306, 226))
	_root.draw_rect(area, Color(0.36, 0.55, 0.68))
	# The coast: land to the north-west, the sea to the south-east.
	var land := PackedVector2Array([area.position, area.position + Vector2(306, 0), area.position + Vector2(306, 40),
		area.position + Vector2(250, 70), area.position + Vector2(210, 140), area.position + Vector2(150, 175),
		area.position + Vector2(90, 200), area.position + Vector2(40, 226), area.position + Vector2(0, 226)])
	_root.draw_colored_polygon(land, Color(0.78, 0.74, 0.58))
	_root.draw_polyline(land.slice(2, 8), Color(0.92, 0.88, 0.74), 2.0)
	for i in 6:
		var y := area.position.y + 90 + i * 22 + sin(_t + i) * 1.5
		_root.draw_line(Vector2(area.position.x + 200 + i * 14, y), Vector2(area.position.x + 212 + i * 14, y), Color(0.75, 0.86, 0.92, 0.5), 1.0)
	_root.draw_rect(area, Color(0.35, 0.28, 0.2), false, 2.0)
	var font := _root.get_theme_default_font()
	for r: Dictionary in WorldMap.data().get("routes", []):
		if WorldMap.known(String(r["from"])) and WorldMap.known(String(r["to"])):
			var a := _pos(String(r["from"]))
			var b := _pos(String(r["to"]))
			var n := int(a.distance_to(b) / 6.0)
			for i in n:
				_root.draw_circle(a.lerp(b, float(i) / maxf(1.0, n)), 1.3, Color(0.45, 0.35, 0.25))
	var here := WorldMap.city_of(GameState.current_scene_id)
	for id in _order:
		var p := _pos(id)
		var sel := id == selected
		_root.draw_circle(p, 6.0 if sel else 4.5, Color(0.2, 0.15, 0.1))
		_root.draw_circle(p, 4.5 if sel else 3.2, Color(1.0, 0.85, 0.3) if sel else Color(0.95, 0.92, 0.82))
		if id == here:
			_root.draw_arc(p, 9.0 + sin(_t * 5.0), 0, TAU, 20, Color(1.0, 0.85, 0.3), 1.5)
		var name_text := tr(String(WorldMap.cities()[id]["name"]))
		var tw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
		var banner := Rect2(p + Vector2(-tw * 0.5, 9), Vector2(tw, 11))
		_root.draw_rect(banner, Color(0.98, 0.94, 0.82))
		_root.draw_rect(banner, Color(0.35, 0.28, 0.2), false, 1.0)
		_root.draw_string(font, banner.position + Vector2(4, 9), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.15, 0.1))
