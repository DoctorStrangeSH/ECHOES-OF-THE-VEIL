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
		elif p["node"] != null and not far.intersects(r) and p["node"] != active:
			(p["node"] as Node).queue_free()
			p["node"] = null


func _track_active() -> void:
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
	Lighting.update(get_tree(), hour, not tinted)
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
	if WorldClock.weather == "rain":
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
