extends Node
## Runtime state of the current playthrough. Holds only IDs and primitive
## values, never live Nodes, so it serializes cleanly (see SaveService).
## Owner: core. Test: tests/run_tests.gd (round-trip through to_dict/from_dict).

const NEW_GAME_SCENE := &"greyford_block"
const NEW_GAME_SPAWN := &"arrival"

var flags: Dictionary = {}
var current_scene_id: StringName = NEW_GAME_SCENE
var current_spawn_id: StringName = NEW_GAME_SPAWN
## Exact position to restore after loading a save; null when a spawn point is used.
var pending_position: Variant = null
var pending_facing: Vector2 = Vector2.DOWN
var play_time_seconds: float = 0.0
var player_appearance: CharacterAppearance = CharacterAppearance.default_player()
var is_playing: bool = false

## Reasons the player cannot move/interact right now (dialogue, menu, cutscene...).
var _player_locks: Dictionary = {}


func _process(delta: float) -> void:
	if is_playing and not get_tree().paused:
		play_time_seconds += delta


func reset_for_new_game() -> void:
	flags.clear()
	current_scene_id = NEW_GAME_SCENE
	current_spawn_id = NEW_GAME_SPAWN
	pending_position = null
	pending_facing = Vector2.DOWN
	play_time_seconds = 0.0
	player_appearance = CharacterAppearance.default_player()
	_player_locks.clear()


func lock_player(reason: StringName) -> void:
	_player_locks[reason] = true


func unlock_player(reason: StringName) -> void:
	_player_locks.erase(reason)


func is_player_locked() -> bool:
	return not _player_locks.is_empty()


func set_flag(flag_id: StringName, value: Variant = true) -> void:
	if flags.get(flag_id) == value:
		return
	flags[flag_id] = value
	EventHub.flag_changed.emit(flag_id, value)


func get_flag(flag_id: StringName, default: Variant = null) -> Variant:
	return flags.get(flag_id, default)


func has_flag(flag_id: StringName) -> bool:
	return bool(flags.get(flag_id, false))


## Serializable snapshot. `player_node` (optional) supplies the live position.
func to_dict(player_node: Node2D = null) -> Dictionary:
	var pos: Variant = null
	var facing := pending_facing
	if player_node != null:
		pos = [player_node.global_position.x, player_node.global_position.y]
		if "facing" in player_node:
			facing = player_node.facing
	var flag_data := {}
	for k: StringName in flags:
		flag_data[String(k)] = flags[k]
	return {
		"flags": flag_data,
		"scene_id": String(current_scene_id),
		"spawn_id": String(current_spawn_id),
		"position": pos,
		"facing": [facing.x, facing.y],
		"play_time_seconds": play_time_seconds,
		"appearance": player_appearance.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	flags.clear()
	var flag_data: Dictionary = data.get("flags", {})
	for k: String in flag_data:
		flags[StringName(k)] = flag_data[k]
	current_scene_id = StringName(data.get("scene_id", NEW_GAME_SCENE))
	current_spawn_id = StringName(data.get("spawn_id", NEW_GAME_SPAWN))
	var pos: Variant = data.get("position")
	pending_position = Vector2(pos[0], pos[1]) if pos is Array and pos.size() == 2 else null
	var f: Variant = data.get("facing", [0, 1])
	pending_facing = Vector2(f[0], f[1]) if f is Array and f.size() == 2 else Vector2.DOWN
	play_time_seconds = float(data.get("play_time_seconds", 0.0))
	player_appearance = CharacterAppearance.from_dict(data.get("appearance", {}))
