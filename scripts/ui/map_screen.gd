class_name MapScreen
extends CanvasLayer
## The city map (M) and the bus stop's route board ("map:travel").
##
## Each known district is drawn from its real streets (pictures rendered by
## tools/regions/render_maps.py into the private art folder), on a bay with
## roads between them. Pick a district with ←/→ (or the mouse): the panel
## tells what it is, which places are there and when they're open, who you
## know is there right now, and which of your cases lead there. At a bus stop
## the same map is the route board: E rides to the chosen district.

const MAP_DIR := "derived/maps/"
const TOP := 22.0

var travel := false
var selected := ""
var _order: Array[String] = []
var _root: Control
var _info: VBoxContainer
var _title: Label
var _hint: Label
var _t := 0.0
var _tex: Dictionary = {}


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	_root.draw.connect(_draw_map)
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)
	_title = Label.new()
	_title.position = Vector2(8, 3)
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_title.add_theme_font_size_override("font_size", 11)
	_root.add_child(_title)
	var panel := PanelContainer.new()
	panel.position = Vector2(314, TOP)
	panel.custom_minimum_size = Vector2(160, 226)
	panel.size = Vector2(160, 226)
	_root.add_child(panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 2)
	panel.add_child(_info)
	_hint = Label.new()
	_hint.position = Vector2(8, 254)
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	_root.add_child(_hint)
	visible = false


func is_open() -> bool:
	return visible


func open(as_travel: bool) -> void:
	travel = as_travel
	_order.clear()
	for id: String in CityMap.districts():
		if CityMap.known(id):
			_order.append(id)
	_order.sort_custom(func(a: String, b: String) -> bool: return _at(a).x < _at(b).x)
	var here := CityMap.district_of(GameState.current_scene_id)
	selected = here if _order.has(here) else (_order[0] if not _order.is_empty() else "")
	if travel:
		var dests := CityMap.destinations(GameState.current_scene_id)
		if not dests.is_empty():
			selected = dests[0]
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	CityMap.driving = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed(&"map") and GameState.is_playing and not SceneFlow.is_transitioning \
				and not get_tree().paused and not DialogueService.is_active:
			get_viewport().set_input_as_handled()
			open(false)
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		close()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_up"):
		_step(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_down"):
		_step(1)
	elif travel and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		_try_ride()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var p := (event as InputEventMouseButton).position
		for id in _order:
			if _rect(id).grow(3).has_point(p):
				if id == selected and travel:
					_try_ride()
				selected = id
				_refresh()
				return


func _step(d: int) -> void:
	if _order.is_empty():
		return
	selected = _order[(_order.find(selected) + d + _order.size()) % _order.size()]
	Sfx.play(&"bell", 0.0, -22.0)
	_refresh()


func _try_ride() -> void:
	if CityMap.destinations(GameState.current_scene_id).has(selected):
		var id := selected
		var drive := CityMap.driving
		close()
		CityMap.driving = drive
		CityMap.ride(id)
		CityMap.driving = false


# --- Geometry ------------------------------------------------------------------

func _origin() -> Vector2:
	return Vector2(8, TOP + 8)


func _scale() -> float:
	return float(CityMap.data().get("map_scale", 0.125))


func _at(id: String) -> Vector2:
	var a: Array = CityMap.districts().get(id, {}).get("map_at", [0, 0])
	return Vector2(float(a[0]), float(a[1]))


func _texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var scene: String = (CityMap.districts()[id].get("scenes", [""]) as Array)[0]
		_tex[id] = AssetLibrary.load_texture(MAP_DIR + scene + ".png")
	return _tex[id]


func _rect(id: String) -> Rect2:
	var t := _texture(id)
	var size := t.get_size() * 0.5 if t != null else Vector2(80, 50)
	return Rect2(_origin() + _at(id), size)


# --- Panel ----------------------------------------------------------------------

func _line(text: String, color: Color, size := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_info.add_child(l)
	return l


func _refresh() -> void:
	_title.text = tr("BUS_TITLE") % CityMap.fare() if travel else tr("MAP_TITLE")
	_hint.text = tr("MAP_HINT_TRAVEL") % CityMap.fare() if travel else tr("MAP_HINT_VIEW")
	if CityMap.driving:
		_title.text = tr("CAR_TITLE_TOWN")
		_hint.text = tr("CAR_HINT_TOWN")
	for c in _info.get_children():
		c.queue_free()
	if selected == "":
		return
	var d: Dictionary = CityMap.districts()[selected]
	_line(tr(String(d["name"])), UiTheme.ACCENT, 10)
	if selected == CityMap.district_of(GameState.current_scene_id):
		_line(tr("MAP_YOU_ARE_HERE"), Color(1.0, 0.85, 0.35))
	_line(tr(String(d.get("desc", ""))), UiTheme.INK_DIM)
	_line(tr("MAP_PLACES"), UiTheme.ACCENT)
	for pl: Dictionary in d.get("places", []):
		_line("• %s — %s" % [tr(String(pl["name"])), tr(String(pl.get("hours", "")))], UiTheme.INK)
	_line(tr("MAP_PEOPLE"), UiTheme.ACCENT)
	var people := PackedStringArray()
	for npc: StringName in NpcRegistry.defs():
		var def: Dictionary = NpcRegistry.get_def(npc)
		if def.has("schedule") and _met(npc):
			var where := StringName(NpcRegistry.resolve(npc).get("scene", ""))
			if where != &"" and CityMap.district_of(where) == selected:
				people.append(tr(String(def.get("name", ""))))
	_line(", ".join(people) if not people.is_empty() else tr("MAP_NOBODY"), UiTheme.INK)
	var cases := PackedStringArray()
	for cid: StringName in Journal.case_defs:
		if Journal.case_status(cid) == Journal.STATUS_ACTIVE:
			var sc := QuestGuide.scene_of(QuestGuide.target(cid))
			if sc != &"" and CityMap.district_of(sc) == selected:
				cases.append(tr(String(Journal.case_defs[cid].get("title", ""))))
	if not cases.is_empty() and GameSettings.shows_objective():
		_line(tr("MAP_CASES"), UiTheme.ACCENT)
		_line(", ".join(cases), UiTheme.INK)
	_line(tr("MAP_BUS") if d.get("stop") != null else tr("MAP_NO_BUS"), Color(0.55, 0.75, 1.0))
	if d.get("stop") != null and CityMap.fare_to(selected) != CityMap.fare():
		_line(tr("MAP_BUS_FARE") % [CityMap.fare_to(selected), int(d.get("ride_minutes", 20))], Color(0.55, 0.75, 1.0))
	if travel and CityMap.destinations(GameState.current_scene_id).is_empty():
		_line(tr("BUS_NOWHERE"), Color(1.0, 0.7, 0.5))


static func _met(npc: StringName) -> bool:
	# NPCs you've spoken to: their dialogue usually sets met.<short id> or the
	# relationship exists; companions and story people count once met.
	return GameState.relationships.has(npc) or GameState.has_flag(StringName("met." + String(npc))) \
		or GameState.has_flag(StringName("met." + String(npc).get_slice("_", 0)))


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_root.queue_redraw()


# --- Drawing --------------------------------------------------------------------

func _draw_map() -> void:
	var vp := _root.get_viewport_rect().size
	_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.06, 0.94))
	var area := Rect2(Vector2(4, TOP), Vector2(306, 226))
	# Paper, with the bay along the top.
	_root.draw_rect(area, Color(0.84, 0.78, 0.62))
	var sea := Rect2(area.position, Vector2(area.size.x, 40))
	_root.draw_rect(sea, Color(0.36, 0.55, 0.68))
	for i in 7:
		var y := sea.position.y + 6 + i * 5 + sin(_t * 0.8 + i) * 1.0
		var x0 := area.position.x + fmod(i * 37.0 + _t * 6.0, 40.0)
		while x0 < area.end.x - 10:
			_root.draw_line(Vector2(x0, y), Vector2(x0 + 6, y), Color(0.75, 0.86, 0.92, 0.5), 1.0)
			x0 += 34.0
	_root.draw_rect(area, Color(0.35, 0.28, 0.2), false, 2.0)
	var font := _root.get_theme_default_font()
	# Roads between known districts, as dotted lanes.
	for r: Array in CityMap.data().get("roads", []):
		if CityMap.known(r[0]) and CityMap.known(r[1]):
			_dotted(_rect(r[0]).get_center(), _rect(r[1]).get_center(), Color(0.55, 0.45, 0.32))
	var here := CityMap.district_of(GameState.current_scene_id)
	var quest_d := ""
	if Journal.pinned != &"" and GameSettings.shows_guide():
		quest_d = CityMap.district_of(QuestGuide.scene_of(QuestGuide.target(Journal.pinned)))
	var dests := CityMap.destinations(GameState.current_scene_id)
	for id in _order:
		var r := _rect(id)
		_root.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
		var t := _texture(id)
		if t != null:
			_root.draw_texture_rect(t, r, false)
		else:
			_root.draw_rect(r, Color(0.55, 0.62, 0.5))
		if travel and not dests.has(id) and id != here:
			_root.draw_rect(r, Color(0.1, 0.1, 0.1, 0.45))
		var frame := Color(0.25, 0.2, 0.15)
		var width := 1.0
		if id == selected:
			frame = Color(1.0, 0.82, 0.3).lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 5.0))
			width = 2.0
		_root.draw_rect(r, frame, false, width)
		# Name banner under the picture.
		var name_text := tr(String(CityMap.districts()[id]["name"]))
		var tw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
		var banner := Rect2(Vector2(r.get_center().x - tw * 0.5, r.end.y - 3), Vector2(tw, 11))
		_root.draw_rect(banner, Color(0.98, 0.94, 0.82))
		_root.draw_rect(banner, Color(0.35, 0.28, 0.2), false, 1.0)
		_root.draw_string(font, banner.position + Vector2(4, 9), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.15, 0.1))
		# Bus stop.
		var stop_at: Variant = CityMap.districts()[id].get("stop_at")
		if stop_at != null:
			var sp := r.position + Vector2(float(stop_at[0]), float(stop_at[1])) * _scale()
			_root.draw_rect(Rect2(sp - Vector2(4, 4), Vector2(8, 8)), Color(0.25, 0.45, 0.85))
			_root.draw_string(font, sp + Vector2(-2.5, 3.5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
		if id == quest_d:
			_star(r.position + Vector2(r.size.x - 6, 4))
		if id == here:
			var pl := SceneFlow.current_location.get("player") as Node2D if SceneFlow.current_location != null else null
			var pos := r.get_center()
			if pl != null and CityMap.districts()[id]["scenes"][0] == String(GameState.current_scene_id):
				pos = r.position + pl.global_position * _scale()
			var pulse := 3.0 + sin(_t * 6.0) * 1.0
			_root.draw_circle(pos, pulse + 1.5, Color(0.1, 0.08, 0.05))
			_root.draw_circle(pos, pulse, Color(1.0, 0.85, 0.3))


func _dotted(a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(a.distance_to(b) / 6.0)
	for i in n:
		var p := a.lerp(b, float(i) / maxf(1.0, n))
		_root.draw_circle(p, 1.4, c)


func _star(p: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + i * PI / 5
		var rad := 6.0 if i % 2 == 0 else 2.6
		pts.append(p + Vector2(cos(ang), sin(ang)) * rad)
	_root.draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
	pts.append(pts[0])
	_root.draw_polyline(pts, Color(0.3, 0.2, 0.05), 1.0)
