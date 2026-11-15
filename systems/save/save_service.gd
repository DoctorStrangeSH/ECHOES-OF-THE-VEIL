extends Node
## Versioned, crash-safe save/load.
##
## Write path: serialize -> write slot_N.tmp -> read back and validate ->
## rotate the current save to slot_N.bak -> rename .tmp to slot_N.json.
## Load path: primary -> (if unreadable) backup. An unreadable primary is never
## overwritten silently: it is kept as slot_N.corrupt-<time>.json.
## Owner: save. Tests: tests/run_tests.gd (round trip, corrupt file, backup, migration).

signal saved(slot: int)
signal save_failed(slot: int, message: String)

const SCHEMA_VERSION := 4
const DEFAULT_SLOT := 1
const MAX_SLOTS := 3

## Overridable for tests.
var save_dir := "user://saves"

## schema version -> Callable(envelope: Dictionary) -> Dictionary (returns the next version).
var _migrations: Dictionary = {}


func _init() -> void:
	_migrations[1] = _migrate_1_to_2
	_migrations[2] = _migrate_2_to_3
	_migrations[3] = _migrate_3_to_4


## v4 (M4) adds faction standing, NPC knowledge and pending gossip.
func _migrate_3_to_4(env: Dictionary) -> Dictionary:
	var p: Dictionary = env["payload"]
	if not p.has("society"):
		p["society"] = {"standing": {}, "knowledge": {}, "gossip": []}
	return env


## v3 (M3) adds inventory, money, Resonance and Attunements.
func _migrate_2_to_3(env: Dictionary) -> Dictionary:
	var p: Dictionary = env["payload"]
	if not p.has("inventory"):
		p["inventory"] = {"items": {}, "equipped": {"weapon": "fists", "trinket": ""}, "money": 0, "resonance": 0, "attunements": []}
	return env


## v2 (M2) adds the player profile, relationships, NPC memory, journal and clock.
func _migrate_1_to_2(env: Dictionary) -> Dictionary:
	var p: Dictionary = env["payload"]
	if not p.has("profile"):
		p["profile"] = {"name": "Alex", "pronouns": "they", "background": "returning_local"}
	for key in ["relationships", "memory", "journal", "clock"]:
		if not p.has(key):
			p[key] = {}
	return env


func slot_path(slot: int, suffix := ".json") -> String:
	return save_dir.path_join("slot_%d%s" % [slot, suffix])


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot, ".bak"))


func has_any_save() -> bool:
	for slot in range(1, MAX_SLOTS + 1):
		if has_save(slot):
			return true
	return false


## Builds the envelope for the current game and writes it.
func save_game(slot: int = DEFAULT_SLOT) -> Error:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var envelope := make_envelope(GameState.to_dict(player))
	var err := write_envelope(slot, envelope)
	if err == OK:
		saved.emit(slot)
	else:
		save_failed.emit(slot, error_string(err))
	return err


func make_envelope(payload: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"timestamp": int(Time.get_unix_time_from_system()),
		"payload": payload,
	}


func write_envelope(slot: int, envelope: Dictionary) -> Error:
	var problem := validate(envelope)
	if not problem.is_empty():
		push_error("SaveService: refusing to write invalid save: %s" % problem)
		return ERR_INVALID_DATA
	var mk := DirAccess.make_dir_recursive_absolute(save_dir)
	if mk != OK:
		return mk

	var tmp := slot_path(slot, ".tmp")
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	file.close()

	var check := _read_file(tmp)
	if not check["ok"]:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT

	var primary := slot_path(slot)
	var backup := slot_path(slot, ".bak")
	if FileAccess.file_exists(primary):
		if _read_file(primary)["ok"]:
			if FileAccess.file_exists(backup):
				DirAccess.remove_absolute(backup)
			var rot := DirAccess.rename_absolute(primary, backup)
			if rot != OK:
				return rot
		else:
			var stamp := Time.get_datetime_string_from_system().replace(":", "-")
			DirAccess.rename_absolute(primary, slot_path(slot, ".corrupt-%s.json" % stamp))
	return DirAccess.rename_absolute(tmp, primary)


## Returns {ok: bool, envelope: Dictionary, from_backup: bool, error: String}.
func read_slot(slot: int = DEFAULT_SLOT) -> Dictionary:
	var primary := _read_file(slot_path(slot))
	if primary["ok"]:
		primary["from_backup"] = false
		return primary
	var backup := _read_file(slot_path(slot, ".bak"))
	if backup["ok"]:
		backup["from_backup"] = true
		push_warning("SaveService: slot %d primary unreadable (%s); loaded backup." % [slot, primary["error"]])
		return backup
	return {"ok": false, "envelope": {}, "from_backup": false,
		"error": "primary: %s; backup: %s" % [primary["error"], backup["error"]]}


## Applies a save to GameState and enters the saved scene.
func load_game(slot: int = DEFAULT_SLOT) -> bool:
	var result := read_slot(slot)
	if not result["ok"]:
		EventHub.toast_requested.emit(tr("TOAST_LOAD_FAILED"))
		push_error("SaveService: cannot load slot %d: %s" % [slot, result["error"]])
		return false
	GameState.from_dict(result["envelope"]["payload"])
	if result["from_backup"]:
		EventHub.toast_requested.emit(tr("TOAST_LOADED_BACKUP"))
	SceneFlow.enter_game_from_state()
	return true


## Lightweight info for menus without applying the save.
func slot_summary(slot: int = DEFAULT_SLOT) -> Dictionary:
	var result := read_slot(slot)
	if not result["ok"]:
		return {}
	var env: Dictionary = result["envelope"]
	return {
		"timestamp": env.get("timestamp", 0),
		"scene_id": env["payload"].get("scene_id", ""),
		"play_time_seconds": env["payload"].get("play_time_seconds", 0.0),
	}


func validate(envelope: Variant) -> String:
	if not envelope is Dictionary:
		return "envelope is not an object"
	for key in ["schema_version", "game_version", "timestamp", "payload"]:
		if not envelope.has(key):
			return "missing '%s'" % key
	if not envelope["payload"] is Dictionary:
		return "payload is not an object"
	var v: Variant = envelope["schema_version"]
	if not (v is int or v is float) or int(v) < 1:
		return "bad schema_version"
	if int(v) > SCHEMA_VERSION:
		return "save is from a newer game version (schema %d)" % int(v)
	var payload: Dictionary = envelope["payload"]
	if not payload.get("scene_id") is String or not payload.get("flags") is Dictionary:
		return "payload missing scene_id/flags"
	return ""


func migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope["schema_version"])
	while version < SCHEMA_VERSION:
		if not _migrations.has(version):
			push_error("SaveService: no migration from schema %d" % version)
			return {}
		envelope = (_migrations[version] as Callable).call(envelope)
		version += 1
		envelope["schema_version"] = version
	return envelope


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "envelope": {}, "error": "not found"}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "envelope": {}, "error": "JSON error line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	var problem := validate(json.data)
	if not problem.is_empty():
		return {"ok": false, "envelope": {}, "error": problem}
	var env := migrate(json.data)
	if env.is_empty():
		return {"ok": false, "envelope": {}, "error": "migration failed"}
	return {"ok": true, "envelope": env, "error": ""}
