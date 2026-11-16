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
var player_name: String = "Alex"
## "they" | "she" | "he" (used for text variants that need it).
var pronouns: String = "they"
## Origin chosen in the character creator (see data/characters/backgrounds.json).
var background: StringName = &"returning_local"
## npc_id -> int (negative = distrust).
var relationships: Dictionary = {}
## npc_id -> Array of semantic memory events, e.g. "kept_promise".
var npc_memory: Dictionary = {}
var is_playing: bool = false

## Reasons the player cannot move/interact right now (dialogue, menu, cutscene...).
var _player_locks: Dictionary = {}


func _process(delta: float) -> void:
	if is_playing and not get_tree().paused:
		play_time_seconds += delta


## Story / normal / hard (chosen at a new game, D-055).
const DIFFICULTIES: Array[String] = ["story", "normal", "hard"]
const ENEMY_HEALTH := {"story": 0.7, "normal": 1.0, "hard": 1.3}
var difficulty := "normal"
## Money and Resonance dropped where the player last fainted:
## {"scene": id, "x": float, "y": float, "money": int, "resonance": int} or {}.
var satchel: Dictionary = {}


func enemy_health(base: int) -> int:
	return maxi(1, int(round(base * float(ENEMY_HEALTH.get(difficulty, 1.0)))))


func incoming_damage(damage: int) -> int:
	if damage <= 0:
		return damage
	return damage + (1 if difficulty == "hard" else 0) + (1 if Expedition.has_mod(&"fragile") else 0)


func player_health_bonus() -> int:
	return 3 if difficulty == "story" else 0


## Fainting drops half your money (all of it on hard) and all carried Resonance
## where you fell; an older satchel is lost for good. Nothing on story.
func drop_satchel(scene_id: StringName, at: Vector2) -> void:
	if difficulty == "story":
		satchel = {}
		return
	var money := Inventory.money if difficulty == "hard" else Inventory.money / 2
	var res := Inventory.resonance
	Inventory.money -= money
	Inventory.resonance = 0
	satchel = {"scene": String(scene_id), "x": at.x, "y": at.y, "money": money, "resonance": res} if money + res > 0 else {}


func recover_satchel() -> void:
	if satchel.is_empty():
		return
	Inventory.money += int(satchel["money"])
	Inventory.add_resonance(int(satchel["resonance"]))
	EventHub.toast_requested.emit(tr("TOAST_SATCHEL") % [int(satchel["money"]), int(satchel["resonance"])])
	satchel = {}


func reset_for_new_game() -> void:
	flags.clear()
	difficulty = "normal"
	satchel = {}
	current_scene_id = NEW_GAME_SCENE
	current_spawn_id = NEW_GAME_SPAWN
	pending_position = null
	pending_facing = Vector2.DOWN
	play_time_seconds = 0.0
	player_appearance = CharacterAppearance.default_player()
	player_name = "Alex"
	pronouns = "they"
	background = &"returning_local"
	relationships.clear()
	npc_memory.clear()
	_player_locks.clear()
	Journal.reset()
	WorldClock.reset()
	Inventory.reset()
	Society.reset()
	Livelihood.reset()
	Party.reset()
	Progression.reset()
	Expedition.reset()
	Farm.reset()


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


func clear_flag(flag_id: StringName) -> void:
	if flags.erase(flag_id):
		EventHub.flag_changed.emit(flag_id, null)


func get_relationship(npc_id: StringName) -> int:
	return int(relationships.get(npc_id, 0))


func change_relationship(npc_id: StringName, delta: int) -> void:
	var old := get_relationship(npc_id)
	var value := clampi(old + delta, -10, 10)
	relationships[npc_id] = value
	EventHub.relationship_changed.emit(npc_id, value)
	Society.check_milestones(npc_id, old, value)


## Records a semantic memory ("helped_with_radio"), not a raw input log.
func remember(npc_id: StringName, event: String) -> void:
	var list: Array = npc_memory.get(npc_id, [])
	if not list.has(event):
		list.append(event)
	npc_memory[npc_id] = list


func npc_remembers(npc_id: StringName, event: String) -> bool:
	return (npc_memory.get(npc_id, []) as Array).has(event)


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
		"profile": {"name": player_name, "pronouns": pronouns, "background": String(background), "difficulty": difficulty},
		"satchel": satchel.duplicate(),
		"relationships": _string_keys(relationships),
		"memory": _string_keys(npc_memory),
		"journal": Journal.to_dict(),
		"clock": WorldClock.to_dict(),
		"inventory": Inventory.to_dict(),
		"society": Society.to_dict(),
		"life": Livelihood.to_dict(),
		"party": Party.to_dict(),
		"progression": Progression.to_dict(),
		"expedition": Expedition.to_dict(),
		"farm": Farm.to_dict(),
	}


static func _string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[String(k)] = d[k]
	return out


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
	var profile: Dictionary = data.get("profile", {})
	player_name = String(profile.get("name", "Alex"))
	pronouns = String(profile.get("pronouns", "they"))
	background = StringName(profile.get("background", "returning_local"))
	difficulty = String(profile.get("difficulty", "normal"))
	satchel = (data.get("satchel", {}) as Dictionary).duplicate()
	relationships.clear()
	var rel: Dictionary = data.get("relationships", {})
	for k: String in rel:
		relationships[StringName(k)] = int(rel[k])
	npc_memory.clear()
	var mem: Dictionary = data.get("memory", {})
	for k: String in mem:
		npc_memory[StringName(k)] = Array(mem[k])
	Journal.from_dict(data.get("journal", {}))
	WorldClock.from_dict(data.get("clock", {}))
	Inventory.from_dict(data.get("inventory", {}))
	Society.from_dict(data.get("society", {}))
	Livelihood.from_dict(data.get("life", {}))
	Party.from_dict(data.get("party", {}))
	Progression.from_dict(data.get("progression", {}))
	Expedition.from_dict(data.get("expedition", {}))
	Farm.from_dict(data.get("farm", {}))
