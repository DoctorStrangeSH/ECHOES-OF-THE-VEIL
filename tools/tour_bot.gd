extends Node
## Tour bot: plays through every location the way a very thorough tester would.
##
## For each story state it is asked for (start of the game, then act starts from
## data/debug/act_starts.json), it travels to every location, photographs the
## whole map and the player's view, walks up to every inspectable, person, bed
## and pickup and uses it (answering conversations with each choice in turn),
## checks that every door leads somewhere real, and measures how dressed the
## floor is. Everything it sees and every error the engine logs goes into
## <out>/report.json; tools/tour_report.py turns that into a readable report.
##
## Needs the art pack and a display (xvfb-run). Run:
##   godot --path . --rendering-driver opengl3 res://tools/tour_bot.tscn -- \
##     --out=/tmp/tour --states=start,act2,act4 [--only=greyford_block,cafe]

const LOCATIONS_DIR := "res://scenes/locations/"
const MAX_DIALOGUE_STEPS := 80
const NEAR_PX := 24.0

var out_dir := "/tmp/tour"
var states: PackedStringArray = ["start"]
var only: PackedStringArray = []
var report := {"states": {}, "errors": []}
var _errors: Array = []
var _screens: Array = []
var _region := ""


class ErrorCatcher extends Logger:
	var sink: Callable

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		var kind := "warning" if error_type == ERROR_TYPE_WARNING else "error"
		sink.call(kind, "%s (%s:%d %s) %s" % [rationale if rationale != "" else code, file.get_file(), line, function, code if rationale != "" else ""])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--states="):
			states = a.trim_prefix("--states=").split(",")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var catcher := ErrorCatcher.new()
	catcher.sink = func(kind: String, text: String) -> void:
		_errors.append({"kind": kind, "region": _region, "text": text})
	OS.add_logger(catcher)
	await _frames(2)
	TranslationServer.set_locale("ru")
	var root: Node = load("res://scenes/bootstrap/game_root.tscn").instantiate()
	get_tree().root.add_child(root)
	await _frames(20)
	# Screens (shops, jobs, minigames) pause the game; the bot notes them instead.
	for c in EventHub.screen_requested.get_connections():
		EventHub.screen_requested.disconnect(c["callable"])
	EventHub.screen_requested.connect(func(s: String) -> void: _screens.append(s))
	for state in states:
		await _run_state(state)
	report["errors"] = _errors
	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, " "))
	f.close()
	print("TOUR DONE: %d states, %d errors" % [states.size(), _errors.filter(func(e: Dictionary) -> bool: return e["kind"] == "error").size()])
	get_tree().quit()


func _run_state(state: String) -> void:
	_region = "(new game %s)" % state
	SceneFlow.begin_new_game({"name": "Тест", "pronouns": "they", "background": "returning_local", "difficulty": "normal"})
	await _frames(90)
	await _finish_dialogue()
	GameState.set_flag(&"ui.controls_seen")
	if state != "start":
		DebugStart.apply_history(state)
	var regions := {}
	for file in DirAccess.get_files_at(LOCATIONS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var id := file.get_basename()
		if not only.is_empty() and not id in only:
			continue
		regions[id] = await _tour_region(state, StringName(id))
	report["states"][state] = regions


func _tour_region(state: String, id: StringName) -> Dictionary:
	_region = String(id)
	var info := {"errors_before": _errors.size()}
	if WorldClock.get_period() != "morning":
		WorldClock.wait_until_hour(11)
	SceneFlow.travel(id, _first_spawn(id))
	await _frames(70)
	await _finish_dialogue()
	var loc := SceneFlow.current_location
	if loc == null or String(GameState.current_scene_id) != String(id):
		info["visited"] = false
		return info
	info["visited"] = true
	var tag := "%s_%s" % [state, id]
	info["metrics"] = _measure(loc)
	await _snap_whole(loc, tag + "_map")
	await _snap(tag + "_view")
	info["used"] = await _use_everything(loc, id)
	info["screens"] = _screens.duplicate()
	_screens.clear()
	info["errors"] = _errors.slice(info["errors_before"]).map(func(e: Dictionary) -> String: return e["kind"] + ": " + e["text"])
	info.erase("errors_before")
	print("tour %s/%s: %s" % [state, id, JSON.stringify(info["metrics"])])
	return info


## How much of the walkable floor has something near it, and how varied it is.
func _measure(loc: Node) -> Dictionary:
	var ground: TileMapLayer = loc.get_node_or_null("Ground")
	var rects: Array[Rect2] = []
	var textures := {}
	for n in _all(loc):
		if n is Sprite2D and n.is_visible_in_tree() and n.texture != null and not _is_actor(n):
			var r: Rect2 = n.get_rect()
			rects.append(Rect2(n.to_global(r.position), r.size * n.global_scale.abs()))
			textures[n.texture.resource_path] = true
	var floor_cells := 0
	var bare := 0
	var tiles := {}
	var decor: TileMapLayer = null
	if ground != null:
		for c in ground.get_children(true):
			if c.name == "DecorLayer":
				decor = c
		for cell in ground.get_used_cells():
			var data := ground.get_cell_tile_data(cell)
			tiles["%d:%s" % [ground.get_cell_source_id(cell), ground.get_cell_atlas_coords(cell)]] = true
			if data != null and data.get_collision_polygons_count(0) > 0:
				continue
			floor_cells += 1
			if decor != null and decor.get_cell_source_id(cell) != -1:
				continue
			var p := ground.to_global(ground.map_to_local(cell))
			var near := false
			for r in rects:
				if r.grow(NEAR_PX).has_point(p):
					near = true
					break
			if not near:
				bare += 1
	return {"floor_cells": floor_cells, "bare_cells": bare,
		"bare_ratio": snappedf(float(bare) / maxf(1.0, floor_cells), 0.01),
		"sprites": rects.size(), "unique_textures": textures.size(), "ground_tiles": tiles.size()}


func _use_everything(loc: Node, id: StringName) -> Array:
	var used: Array = []
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	for n in _all(loc):
		if not is_instance_valid(n) or not n is Interactable or not n.is_visible_in_tree():
			continue
		var it := n as Interactable
		var entry := {"id": String(it.interaction_id), "kind": it.get_script().get_global_name() if it.get_script() else "?"}
		if it is DoorInteractable:
			var target := StringName(it.get("target_scene_id"))
			entry["to"] = String(target)
			entry["ok"] = target == &"" or SceneFlow.has_location(target)
			used.append(entry)
			continue
		if not it.can_interact(player):
			entry["skipped"] = "cannot interact"
			used.append(entry)
			continue
		player.global_position = it.global_position + Vector2(0, 14)
		await _frames(3)
		if not is_instance_valid(it):
			continue
		var errors_before := _errors.size()
		it.interact(player)
		await _frames(4)
		entry["dialogue"] = String(DialogueService.current_id) if DialogueService.is_active else ""
		entry["steps"] = await _finish_dialogue()
		get_tree().paused = false
		if String(GameState.current_scene_id) != String(id) or SceneFlow.current_location != loc:
			entry["moved_to"] = String(GameState.current_scene_id)
			used.append(entry)
			SceneFlow.travel(id, _first_spawn(id))
			await _frames(70)
			await _finish_dialogue()
			return used + await _use_rest(SceneFlow.current_location, id, used)
		entry["new_errors"] = _errors.size() - errors_before
		used.append(entry)
	return used


## After a door or a story effect moved the player away, carry on with the
## things not used yet.
func _use_rest(loc: Node, id: StringName, done: Array) -> Array:
	var seen := {}
	for e: Dictionary in done:
		seen[e["id"]] = true
	var rest: Array = []
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	for n in _all(loc):
		if not is_instance_valid(n) or not n is Interactable or n is DoorInteractable or not n.is_visible_in_tree():
			continue
		var it := n as Interactable
		if seen.has(String(it.interaction_id)) or not it.can_interact(player):
			continue
		player.global_position = it.global_position + Vector2(0, 14)
		await _frames(3)
		if not is_instance_valid(it):
			continue
		it.interact(player)
		await _frames(4)
		rest.append({"id": String(it.interaction_id), "steps": await _finish_dialogue()})
		get_tree().paused = false
		if SceneFlow.current_location != loc:
			SceneFlow.travel(id, _first_spawn(id))
			await _frames(70)
			return rest
	return rest


## Answers a conversation to its end, cycling through the choices so that
## different branches get exercised. Returns how many lines it went through.
func _finish_dialogue() -> int:
	var steps := 0
	var turn := 0
	var seen := {}
	while DialogueService.is_active and steps < MAX_DIALOGUE_STEPS:
		await _frames(2)
		var choices: Array = DialogueService._visible_choices
		if choices.size() > 0:
			# Try each branch once; when a menu comes round again, take its
			# last choice, which is how conversations are usually left.
			var key := String(DialogueService._node.get("text", ""))
			seen[key] = int(seen.get(key, 0)) + 1
			var pick := turn % choices.size() if seen[key] <= choices.size() else choices.size() - 1
			DialogueService.choose(pick)
			turn += 1
		else:
			DialogueService.advance()
		steps += 1
	if DialogueService.is_active:
		_errors.append({"kind": "error", "region": _region, "text": "dialogue %s did not end in %d steps" % [DialogueService.current_id, MAX_DIALOGUE_STEPS]})
		DialogueService.end()
	await _frames(2)
	get_tree().paused = false
	return steps


## The whole map in one picture: UI hidden, camera zoomed out to fit.
func _snap_whole(loc: Node, tag: String) -> void:
	var ground: TileMapLayer = loc.get_node_or_null("Ground")
	var cam := get_viewport().get_camera_2d()
	if ground == null or cam == null:
		return
	var rect := Rect2(ground.get_used_rect())
	rect = Rect2(ground.to_global(rect.position * 16.0), rect.size * 16.0)
	var view := get_viewport().get_visible_rect().size
	var zoom := minf(view.x / rect.size.x, view.y / rect.size.y)
	var saved := [cam.zoom, cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom, cam.position_smoothing_enabled, cam.global_position]
	var layers := _ui_layers(true)
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = rect.get_center()
	cam.offset = Vector2.ZERO
	await _frames(3)
	await _snap(tag)
	cam.zoom = saved[0]
	cam.limit_left = saved[1]
	cam.limit_top = saved[2]
	cam.limit_right = saved[3]
	cam.limit_bottom = saved[4]
	cam.position_smoothing_enabled = saved[5]
	for l in layers:
		l.visible = true
		l.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)


func _ui_layers(hide: bool) -> Array:
	var out: Array = []
	for n in _all(get_tree().root):
		if n is CanvasLayer and n.visible:
			out.append(n)
			if hide:
				n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED
	return out


func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))


func _is_actor(n: Node) -> bool:
	var p := n
	while p != null:
		if p.is_in_group(&"player") or p is Npc or p is CharacterBody2D:
			return true
		p = p.get_parent()
	return false


func _all(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		stack.append_array(n.get_children(true))
	return out


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _first_spawn(id: StringName) -> StringName:
	var path := "res://data/regions/%s.json" % id
	if not FileAccess.file_exists(path):
		return &""
	var spec: Variant = DataFiles.read_json(path)
	if spec is Dictionary:
		for n: Dictionary in spec.get("nodes", []):
			if n.get("kind", "") == "spawn":
				return StringName(n.get("id", ""))
	return &""
