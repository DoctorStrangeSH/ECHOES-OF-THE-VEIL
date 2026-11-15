extends Node
## Who walks with the player. One companion at a time (data/characters/
## companions*.json); while someone is a companion their schedule is set
## aside and a follower appears beside the player in every location.
## Story data recruits and dismisses with {"companion": "id"} / {"companion": ""}.

signal companion_changed(id: StringName)

const PATH := "res://data/characters/companions"

var defs: Dictionary = {}
var companion: StringName = &""


func _enter_tree() -> void:
	defs = DataFiles.defs(PATH)


func set_companion(id: StringName) -> void:
	if id != &"" and not defs.has(id):
		push_error("Party: '%s' is not a companion" % id)
		return
	if id == companion:
		return
	companion = id
	companion_changed.emit(id)


func is_companion(id: StringName) -> bool:
	return companion != &"" and companion == id


func def_of(id: StringName) -> Dictionary:
	return defs.get(id, {})


func can_join(id: StringName) -> bool:
	return defs.has(id) and StoryRules.evaluate(defs[id].get("requires"))


func reset() -> void:
	set_companion(&"")


func to_dict() -> Dictionary:
	return {"companion": String(companion)}


func from_dict(d: Dictionary) -> void:
	var id := StringName(d.get("companion", ""))
	set_companion(id if defs.has(id) else &"")
