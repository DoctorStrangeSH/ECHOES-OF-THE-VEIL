class_name OpenWorld
extends Node2D
## The open world (D-096): Greyford, the coast and the countryside as one map
## you walk across. Places (data/world/open_world.json) and the countryside
## between them (scenes/world/filler, built by tools/world/build_world.py) are
## Locations in chunk mode, loaded as the player comes near and freed when
## they are far behind. The world owns the player, the camera, the light and
## the outer edge. Whichever place the player stands in is the current
## location for everything else in the game (quests, music, NPC schedules,
## the HUD's place name); on the open road the last place stays current.
## Interiors and the Veil stay scenes of their own behind doors.

const SPEC_PATH := "res://data/world/open_world.json"
const FILLER_INDEX := "res://data/world/filler_index.json"
const FILLER_DIR := "res://scenes/world/filler/"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## Load what is this far (px) beyond the screen; free what is twice as far.
const LOAD_MARGIN := 420.0
const STREAM_EVERY := 0.25

static var _spec: Dictionary = {}

var player: Player
var active: Location = null
var _pieces := {}  # id -> {rect: Rect2 (px), path: String, node: Location or null, region: bool}
var _tint: CanvasModulate
var _stream_t := 0.0


static func spec() -> Dictionary:
	if _spec.is_empty():
		var d: Variant = DataFiles.read_json(SPEC_PATH)
		_spec = d if d is Dictionary else {"regions": {}}
	return _spec


static func has_region(id: StringName) -> bool:
	return spec()["regions"].has(String(id))


## Top-left of a place in world pixels.
static func region_origin(id: StringName) -> Vector2:
	var p: Array = spec()["regions"].get(String(id), [0, 0])
	return Vector2(float(p[0]), float(p[1])) * 16.0


func _ready() -> void:
	y_sort_enabled = true
	_tint = CanvasModulate.new()
	add_child(_tint)
	var t := 16.0
	for id: String in spec()["regions"]:
		var path := String(SceneFlow.LOCATIONS.get(StringName(id), ""))
		if path == "":
			continue
		var size := _region_size(id)
		_pieces[id] = {"rect": Rect2(region_origin(StringName(id)), size * t), "path": path, "node": null, "region": true}
	var idx: Variant = DataFiles.read_json(FILLER_INDEX)
	if idx is Dictionary:
		var cs: Array = spec()["chunk"]
		for c: Dictionary in idx["chunks"]:
			var pos := Vector2(float(c["pos"][0]), float(c["pos"][1])) * t
			_pieces[String(c["id"])] = {"rect": Rect2(pos, Vector2(float(cs[0]) + 2.0, float(cs[1]) + 2.0) * t),
				"path": FILLER_DIR + String(c["id"]) + ".tscn", "node": null, "region": false}
	var ws: Array = spec()["size"]
	var bounds := Rect2(Vector2.ZERO, Vector2(float(ws[0]), float(ws[1])) * t)
	_add_bounds(bounds)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_camera_limits(Rect2i(bounds))
	WorldClock.time_changed.connect(func(_m: int) -> void: _update_light())
	_update_light()
	EventHub.car_parked.connect(_on_car_parked)
	SceneFlow.transition_started.connect(func() -> void:
		if player != null and is_instance_valid(player) and player.driving:
			player.stop_driving())
	var spot: Variant = GameState.get_flag(&"car.spot")
	if GameState.has_flag(&"car.away") and spot is Array and (spot as Array).size() >= 3:
		_place_car(Vector2(float(spot[0]), float(spot[1])), String(spot[2]))


## Puts the player in a place (at a spawn point or a saved local position),
## loading what is around them first.
func place_player(region_id: StringName, spawn_id: StringName, local_pos: Variant, facing: Vector2) -> void:
	var origin := region_origin(region_id)
	var region_rect: Rect2 = _pieces[String(region_id)]["rect"]
	var guess: Vector2 = origin + (Vector2(local_pos) if local_pos is Vector2 else region_rect.size / 2.0)
	_stream(guess, true)
	var loc: Location = _pieces[String(region_id)]["node"]
	var at := guess
	var face := facing
	if not local_pos is Vector2 and loc != null:
		var sp := loc.find_spawn(spawn_id)
		if sp != null:
			at = sp.global_position
			face = sp.facing
	player.place(at, face)
	_set_active(loc, region_id)


func _process(delta: float) -> void:
	_stream_t -= delta
	if _stream_t > 0.0 or player == null:
		return
	_stream_t = STREAM_EVERY
	_stream(player.global_position, false)
	_track_active()


## Loads pieces near `at` and frees the far ones.
func _stream(at: Vector2, now: bool) -> void:
	var view := Vector2(480, 270)
	if player != null and player.has_node("Camera2D"):
		view = get_viewport_rect().size / (player.get_node("Camera2D") as Camera2D).zoom
	var near := Rect2(at - view / 2.0, view).grow(LOAD_MARGIN)
	var far := near.grow(LOAD_MARGIN)
	for id: String in _pieces:
		var p: Dictionary = _pieces[id]
		var r: Rect2 = p["rect"]
		if p["node"] == null and near.intersects(r):
			var loc: Location = load(String(p["path"])).instantiate()
			loc.chunk_mode = true
			loc.position = r.position
			add_child(loc)
			p["node"] = loc
		elif p["node"] != null and not far.intersects(r) and p["node"] != active and String(id) != String(_room_street):
			(p["node"] as Node).queue_free()
			p["node"] = null


func _track_active() -> void:
	if room != null:
		# Walked out through the doorway: back on the street.
		var b := Rect2(room._bounds_px())
		b.position += room.global_position
		if not b.grow(2).has_point(player.global_position):
			leave_room(_room_exit_spawn, true)
		return
	var at := player.global_position
	for id: String in _pieces:
		var p: Dictionary = _pieces[id]
		if p["region"] and p["node"] != null and (p["rect"] as Rect2).has_point(at):
			if p["node"] != active:
				_set_active(p["node"], StringName(id))
			return


func _set_active(loc: Location, id: StringName) -> void:
	if loc == active:
		return
	if active != null and is_instance_valid(active):
		active.became_inactive()
	active = loc
	if loc == null:
		return
	SceneFlow.current_location = loc
	var changed := GameState.current_scene_id != id
	GameState.current_scene_id = id
	player.combat_enabled = loc.combat_enabled
	loc.became_active(player)
	_update_light()
	if changed:
		GameState.set_flag(StringName("visited." + String(id)))
		SceneFlow.location_entered.emit(id)


func _update_light() -> void:
	var hour := WorldClock.minute_of_day / 60.0
	var tinted := active != null and active.fixed_tint.a > 0.0
	Lighting.update(get_tree(), hour, not tinted and room == null)
	if tinted:
		_tint.color = active.fixed_tint
		return
	var keys: Array = Location.TINT_KEYS
	var c: Color = keys[0][1]
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			c = (a[1] as Color).lerp(b[1], (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
			break
	if room != null:
		c = c.lerp(Color(1, 0.96, 0.9), 0.65)  # lamps are on indoors
	elif WorldClock.weather == "rain":
		c = c * Color(0.82, 0.86, 0.95)
	_tint.color = c


func _region_size(id: String) -> Vector2:
	var d: Variant = DataFiles.read_json("res://data/regions/%s.json" % id)
	if d is Dictionary and d.get("layout") is Array and not (d["layout"] as Array).is_empty():
		return Vector2(String(d["layout"][0]).length(), (d["layout"] as Array).size())
	# Generated layouts: ask the scene.
	var loc: Location = load(String(SceneFlow.LOCATIONS[StringName(id)])).instantiate()
	var used := (loc.get_node("Ground") as TileMapLayer).get_used_rect()
	loc.free()
	return Vector2(used.end)


func _add_bounds(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "WorldEdge"
	add_child(body)
	var th := 64.0
	for w: Rect2 in [Rect2(r.position.x - th, r.position.y - th, r.size.x + th * 2, th), Rect2(r.position.x - th, r.end.y, r.size.x + th * 2, th),
			Rect2(r.position.x - th, r.position.y, th, r.size.y), Rect2(r.end.x, r.position.y, th, r.size.y)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w.size
		shape.shape = rect
		shape.position = w.get_center()
		body.add_child(shape)


## Local position of the player in the current place (what saves store).
func local_player_position() -> Vector2:
	if room != null:
		return player.global_position - room.global_position
	return player.global_position - (active.global_position if active != null else Vector2.ZERO)


var _markers := {}


## Something for the quest pointer to point at: the middle of a place.
func guide_marker(id: StringName) -> Node2D:
	if not _markers.has(id):
		var m := Marker2D.new()
		add_child(m)
		_markers[id] = m
	var p: Dictionary = _pieces.get(String(id), {})
	if not p.is_empty():
		(_markers[id] as Node2D).global_position = (p["rect"] as Rect2).get_center()
	return _markers[id]


var _parked: Node2D


## Your car stays where you got out of it.
func _on_car_parked(at: Vector2, dir: String) -> void:
	GameState.set_flag(&"car.away")
	GameState.set_flag(&"car.spot", [at.x, at.y, dir])
	_place_car(at, dir)


func _place_car(at: Vector2, dir: String) -> void:
	if _parked != null and is_instance_valid(_parked):
		_parked.queue_free()
	var car: WorldProp = load("res://scenes/props/world_prop.tscn").instantiate()
	car.texture_path = Player.CAR_ART % dir
	car.placeholder_size = Vector2i(48, 32)
	car.collision_size = Vector2(40, 12) if dir in ["Left", "Right"] else Vector2(24, 20)
	car.collision_offset = Vector2(0, -6)
	car.casts_shadow = true
	car.position = at
	car.add_to_group(&"traffic_blocker")
	add_child(car)
	var use := Interactable.new()
	use.interaction_id = &"use_parked_car"
	use.prompt_key = "PROMPT_PARKED_CAR"
	use.interaction_priority = 10
	use.area_size = Vector2(48, 16)
	use.position = Vector2(0, 6)
	car.add_child(use)
	use.interacted.connect(func(_a: Node) -> void:
		car.queue_free()
		_parked = null
		player.global_position = at
		player.start_driving())
	_parked = car


# --- Rooms in place ------------------------------------------------------------
# A building's own rooms open where the building stands: the roof and walls
# fade away, the street around is dimmed, and the room is there, with the
# town still going on in the shadows outside. Rooms of the Veil (fights,
# strange light) still open as scenes of their own.

const ROOM_FADE := 0.45
const DIM := 0.62

var room: Location = null
var room_id: StringName = &""
var _room_street: StringName = &""
var _room_door_at := Vector2.ZERO
var _room_exit_spawn: StringName = &""
var _faded: Array[CanvasItem] = []
var _dim: ColorRect

static var _room_ok := {}


## Whether a scene opens in place: an interior redrawn to fit its house
## (`"in_place": true` in its region options), with no fights or fixed tint.
static func is_room(id: StringName) -> bool:
	if _room_ok.has(id):
		return _room_ok[id]
	var ok := false
	if not has_region(id):
		var path := "res://data/regions/%s.json" % id
		var d: Variant = DataFiles.read_json(path) if FileAccess.file_exists(path) else null  # generated places have no region file
		if d is Dictionary:
			var o: Dictionary = d.get("options", {})
			ok = bool(o.get("in_place", false)) and not bool(o.get("outdoors", true)) and not bool(o.get("combat_enabled", false)) and not o.has("fixed_tint")
	_room_ok[id] = ok
	return ok


## The street door (world position) that leads into a room, looking in the
## loaded street pieces; preferring `near` when several do.
func _street_door(id: StringName, near: Variant = null) -> DoorInteractable:
	var best: DoorInteractable = null
	for p: Dictionary in _pieces.values():
		if p["node"] == null or not p["region"]:
			continue
		for d in (p["node"] as Node).find_children("*", "DoorInteractable", true, false):
			var door := d as DoorInteractable
			if door.target_scene_id != id:
				continue
			if best == null or (near is Vector2 and door.global_position.distance_to(near) < best.global_position.distance_to(near)):
				best = door
	return best


## The street a room's front door is on (from the region data, before
## anything is loaded).
static var _streets := {}


func _street_of(id: StringName) -> StringName:
	if _streets.has(id):
		return _streets[id]
	_streets[id] = &""
	for rid: String in spec()["regions"]:
		var d: Variant = DataFiles.read_json("res://data/regions/%s.json" % rid)
		if d is Dictionary:
			for n: Dictionary in d.get("nodes", []):
				if n.get("kind", "") == "door" and String(n.get("scene", "")) == String(id):
					_streets[id] = StringName(rid)
					return _streets[id]
	return &""


func can_open_room(id: StringName) -> bool:
	if not is_room(id):
		return false
	return is_room(id) and _street_of(id) != &""


## Opens a room in place. `door` is the street door used (null when arriving
## by loading a save or a story jump); `local_pos` a saved position in it.
func enter_room(id: StringName, spawn_id: StringName, local_pos: Variant = null, door: DoorInteractable = null, animate := true) -> void:
	if room != null:
		_close_room(false)
	var street := _street_of(id)
	if door == null:
		place_player(street, &"", null, Vector2.DOWN)
		door = _street_door(id)
	if door == null:
		push_warning("OpenWorld: no street door into %s" % id)
		return
	room_id = id
	_room_street = street
	_room_door_at = door.global_position
	var r: Location = load(String(SceneFlow.LOCATIONS[id])).instantiate()
	r.chunk_mode = true
	r.room_mode = true
	# Line the room's way out up with the street door.
	var exit_local := Vector2.ZERO
	for d in r.find_children("*", "DoorInteractable", true, false):
		if has_region((d as DoorInteractable).target_scene_id):
			_room_exit_spawn = (d as DoorInteractable).target_spawn_id
			exit_local = (d as Node2D).position
			var parent := (d as Node).get_parent()
			while parent != r and parent is Node2D:
				exit_local += (parent as Node2D).position
				parent = parent.get_parent()
			break
	r.position = (_room_door_at - Vector2(0, 10) - exit_local).round()
	add_child(r)
	room = r
	var house := _fade_building(door, animate)
	if house.has_area():
		# The room stands where the house stands: centred on it, its floor
		# ending at the house's front.
		var b := Rect2(r._bounds_px())
		r.position = Vector2(round(house.get_center().x - b.size.x / 2.0), house.end.y - b.end.y).round()
	_dim_world(true, animate)
	if animate:
		r.modulate.a = 0.0
		r.create_tween().tween_property(r, "modulate:a", 1.0, ROOM_FADE)
	player.enter_room_layer(r)
	var at: Vector2
	var face := Vector2.UP
	if local_pos is Vector2:
		at = r.global_position + Vector2(local_pos)
	else:
		var sp := r.find_spawn(spawn_id)
		at = sp.global_position if sp != null else _room_door_at - Vector2(0, 24)
		face = sp.facing if sp != null else Vector2.UP
	player.place(at, face)
	_set_active(r, id)


## Back out to the street through the room's door.
func leave_room(spawn_id: StringName, walked_out := false) -> void:
	var street := _room_street
	_close_room(true)
	var loc: Location = _pieces[String(street)]["node"]
	var sp := loc.find_spawn(spawn_id) if loc != null else null
	GameState.current_scene_id = street
	GameState.current_spawn_id = spawn_id
	if not walked_out:
		player.place(sp.global_position if sp != null else _room_door_at + Vector2(0, 16), sp.facing if sp != null else Vector2.DOWN)
	_set_active(loc, street)


func _close_room(animate: bool) -> void:
	if room == null:
		return
	player.leave_room_layer()
	var r := room
	room = null
	room_id = &""
	if animate:
		var tw := r.create_tween()
		tw.tween_property(r, "modulate:a", 0.0, ROOM_FADE * 0.7)
		tw.tween_callback(r.queue_free)
	else:
		r.queue_free()
	for c in _faded:
		if is_instance_valid(c):
			if animate:
				c.create_tween().tween_property(c, "modulate:a", 1.0, ROOM_FADE)
			else:
				c.modulate.a = 1.0
	_faded.clear()
	_dim_world(false, animate)
	if active == r:
		active = null


## The building around the door lifts away: every tall thing of the street
## whose picture covers a point just above the door.
func _fade_building(door: Node2D, animate: bool) -> Rect2:
	# The house: the tall thing just above the door, then every piece stacked
	# on it (a shop's middle floors and roof are pictures of their own).
	var probe := door.global_position - Vector2(0, 20)
	var house := Rect2()
	var props: Array[WorldProp] = []
	var rects: Array[Rect2] = []
	for p: Dictionary in _pieces.values():
		if p["node"] == null or not p["region"]:
			continue
		for n in (p["node"] as Node).find_children("*", "WorldProp", true, false):
			var prop := n as WorldProp
			var tex := AssetLibrary.load_texture(prop.texture_path)
			var size := prop.region.size if prop.region.has_area() else (Vector2(tex.get_size()) if tex != null else Vector2(prop.placeholder_size))
			if size.y < 48.0:
				continue
			var rect := Rect2(prop.global_position - Vector2(size.x / 2.0, size.y), size)
			props.append(prop)
			rects.append(rect)
			if rect.grow(2).has_point(probe) and rect.get_area() > house.get_area():
				house = rect
	if not house.has_area():
		return house
	var grown := true
	var taken := {}
	while grown:
		grown = false
		for i in props.size():
			if taken.has(i):
				continue
			var r := rects[i]
			var overlap := minf(r.end.x, house.end.x) - maxf(r.position.x, house.position.x)
			if r.size.x >= house.size.x * 0.6 and overlap >= minf(r.size.x, house.size.x) * 0.8 and r.grow(2).intersects(house):
				taken[i] = true
				house = house.merge(r)
				grown = true
	for i: int in taken:
		var prop := props[i]
		_faded.append(prop)
		if animate:
			prop.create_tween().tween_property(prop, "modulate:a", 0.0, ROOM_FADE)
		else:
			prop.modulate.a = 0.0
	# The ground floor is what the room stands on.
	var base := Rect2()
	for i: int in taken:
		if rects[i].end.y >= house.end.y - 1.0 and rects[i].get_area() > base.get_area():
			base = rects[i]
	return base if base.has_area() else house


func _dim_world(on: bool, animate: bool) -> void:
	if _dim == null:
		_dim = ColorRect.new()
		_dim.color = Color(0.02, 0.02, 0.05, 0.0)
		_dim.z_index = 1
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ws: Array = spec()["size"]
		_dim.size = Vector2(float(ws[0]), float(ws[1])) * 16.0
		add_child(_dim)
	var a := DIM if on else 0.0
	if animate:
		_dim.create_tween().tween_property(_dim, "color:a", a, ROOM_FADE)
	else:
		_dim.color.a = a
