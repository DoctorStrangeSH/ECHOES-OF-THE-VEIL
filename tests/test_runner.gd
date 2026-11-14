extends Node
## Minimal headless test runner (no plugins needed).
## Run:  godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures. Each test is a method named test_*.

var _failures: PackedStringArray = []
var _current := ""
var _checks := 0


func _ready() -> void:
	var tests: Array[String] = []
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			tests.append(n)
	tests.sort()
	for t in tests:
		_current = t
		var before := _failures.size()
		await call(t)
		print(("  ok    " if _failures.size() == before else "  FAIL  ") + t)
	print("\n%d tests, %d checks, %d failures" % [tests.size(), _checks, _failures.size()])
	for f in _failures:
		printerr("  - " + f)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("%s: %s" % [_current, message])


func _fresh_save_dir() -> String:
	var dir := "user://test_saves_%d_%d" % [Time.get_ticks_usec(), randi()]
	SaveService.save_dir = dir
	return dir


func _cleanup(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


# --- Save system -------------------------------------------------------------

func test_save_round_trip() -> void:
	var dir := _fresh_save_dir()
	GameState.reset_for_new_game()
	GameState.set_flag(&"prologue.saw_impossible_door", true)
	GameState.set_flag(&"counter", 3)
	GameState.current_scene_id = &"rented_room"
	var env := SaveService.make_envelope(GameState.to_dict())
	check(SaveService.write_envelope(1, env) == OK, "write ok")
	var r := SaveService.read_slot(1)
	check(r["ok"], "read ok: %s" % r.get("error"))
	check(not r["from_backup"], "primary used")
	var payload: Dictionary = r["envelope"]["payload"]
	check(payload["scene_id"] == "rented_room", "scene id kept")
	check(payload["flags"]["prologue.saw_impossible_door"] == true, "bool flag kept")
	check(int(payload["flags"]["counter"]) == 3, "number flag kept")
	_cleanup(dir)


func test_corrupt_primary_falls_back_to_backup_and_is_preserved() -> void:
	var dir := _fresh_save_dir()
	var env := SaveService.make_envelope(GameState.to_dict())
	SaveService.write_envelope(1, env)
	SaveService.write_envelope(1, env)  # second write rotates the first into .bak
	check(FileAccess.file_exists(SaveService.slot_path(1, ".bak")), "backup exists")
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["from_backup"], "loaded from backup")
	# Writing again must not replace the good backup with the corrupt file.
	SaveService.write_envelope(1, env)
	var b := SaveService.read_slot(1)
	check(b["ok"] and not b["from_backup"], "new primary readable")
	var corrupt_kept := false
	for name in DirAccess.get_files_at(dir):
		if name.contains(".corrupt-"):
			corrupt_kept = true
	check(corrupt_kept, "corrupt file kept for inspection")
	_cleanup(dir)


func test_rejects_invalid_and_future_saves() -> void:
	check(SaveService.validate("nope") != "", "non-object rejected")
	check(SaveService.validate({"schema_version": 1}) != "", "missing keys rejected")
	var env := SaveService.make_envelope(GameState.to_dict())
	check(SaveService.validate(env) == "", "valid envelope accepted")
	env["schema_version"] = SaveService.SCHEMA_VERSION + 1
	check(SaveService.validate(env) != "", "newer schema rejected")
	var dir := _fresh_save_dir()
	check(not SaveService.read_slot(2)["ok"], "missing slot not ok")
	_cleanup(dir)


func test_game_state_round_trip() -> void:
	GameState.reset_for_new_game()
	GameState.set_flag(&"met.mara_venn", true)
	GameState.player_appearance.hairstyle = "Hairstyle_01_02"
	var probe := Node2D.new()
	probe.global_position = Vector2(123, 45)
	var data := GameState.to_dict(probe)
	probe.free()
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(data))  # same path as disk
	GameState.reset_for_new_game()
	GameState.from_dict(json_copy)
	check(GameState.has_flag(&"met.mara_venn"), "flag restored")
	check(GameState.pending_position == Vector2(123, 45), "position restored")
	check(GameState.player_appearance.hairstyle == "Hairstyle_01_02", "appearance restored")
	GameState.reset_for_new_game()


# --- Content -----------------------------------------------------------------

func test_localization_complete() -> void:
	var missing := Localization.find_missing_keys()
	check(missing.is_empty(), "missing translations: %s" % ", ".join(missing))
	var old := Localization.get_locale()
	Localization.set_locale("ru")
	check(tr("MENU_QUIT") == "Выход", "ru translation active")
	Localization.set_locale("en")
	check(tr("MENU_QUIT") == "Quit", "en translation active")
	Localization.set_locale(old)


func test_input_actions_registered() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"pause", &"quick_save", &"quick_load"]:
		check(InputMap.has_action(a) and not InputMap.action_get_events(a).is_empty(), "action %s" % a)


func test_tile_painter() -> void:
	check(TilePainter.pick_index(0, 0, 4, Vector2i(2, 2)) == 0, "grid 0,0")
	check(TilePainter.pick_index(1, 0, 4, Vector2i(2, 2)) == 1, "grid 1,0")
	check(TilePainter.pick_index(2, 1, 4, Vector2i(2, 2)) == 2, "grid wraps")
	check(TilePainter.pick_variant(5, 7, 3) == TilePainter.pick_variant(5, 7, 3), "variant stable")
	for palette_id in ["greyford_exterior", "rented_room"]:
		var palette := TilePainter.load_palette(palette_id)
		check(not palette.is_empty(), "palette %s exists" % palette_id)
		var built := TilePainter.build_tileset(palette)
		check((built["brushes"] as Dictionary).size() == palette.size(), "every brush built for %s" % palette_id)


func test_character_direction_mapping() -> void:
	check(LayeredCharacterSprite.dir_from_vector(Vector2.RIGHT) == LayeredCharacterSprite.Dir.RIGHT, "right")
	check(LayeredCharacterSprite.dir_from_vector(Vector2.UP) == LayeredCharacterSprite.Dir.UP, "up")
	check(LayeredCharacterSprite.dir_from_vector(Vector2(-1, 0.2)) == LayeredCharacterSprite.Dir.LEFT, "mostly left")
	check(LayeredCharacterSprite.dir_from_vector(Vector2(0.7, 0.7)) == LayeredCharacterSprite.Dir.DOWN, "diagonal prefers vertical")
	check(LayeredCharacterSprite.dir_from_vector(Vector2.ZERO, LayeredCharacterSprite.Dir.UP) == LayeredCharacterSprite.Dir.UP, "zero keeps fallback")


func test_scene_registry_and_door_targets() -> void:
	var spawns := {}  # scene_id -> Array of spawn ids
	var doors: Array = []  # [from, target_scene, target_spawn]
	for scene_id: StringName in SceneFlow.LOCATIONS:
		var path: String = SceneFlow.LOCATIONS[scene_id]
		check(ResourceLoader.exists(path), "scene exists: %s" % path)
		var root: Node = (load(path) as PackedScene).instantiate()
		check(root is Location and (root as Location).location_id == scene_id, "%s location_id matches registry" % scene_id)
		spawns[scene_id] = []
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is SpawnPoint:
				spawns[scene_id].append((n as SpawnPoint).spawn_id)
			elif n is DoorInteractable:
				var d := n as DoorInteractable
				doors.append([scene_id, d.target_scene_id, d.target_spawn_id])
			if n is Interactable:
				check((n as Interactable).interaction_id != &"", "%s: %s has an interaction_id" % [scene_id, n.name])
		root.free()
	check(spawns[GameState.NEW_GAME_SCENE].has(GameState.NEW_GAME_SPAWN), "new-game spawn exists")
	for d in doors:
		check(spawns.has(d[1]), "door in %s targets known scene %s" % [d[0], d[1]])
		if spawns.has(d[1]):
			check(spawns[d[1]].has(d[2]), "door in %s targets existing spawn %s/%s" % [d[0], d[1], d[2]])
