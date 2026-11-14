@tool
class_name NpcRegistry
extends RefCounted
## Loads NPC definitions from res://data/characters/npcs.json and resolves
## where each NPC should be right now (schedule blocks + story conditions).
##
## Definition: { "name": "NPC_MARA", "premade": "Premade_Character_10" | "custom_sheet": "...",
##   "color": "#hex" (placeholder), "dialogue": "mara", "tint": "#hex" (optional),
##   "schedule": [ {"period": "morning" | [...], "if": <condition>, "scene": "greyford_block",
##                  "anchor": "plaza_east", "facing": "left"} ] }
## The first schedule entry whose period and condition match wins; none = absent.

const PATH := "res://data/characters/npcs.json"
const FACINGS := {"right": 0, "up": 1, "left": 2, "down": 3}

static var _defs: Dictionary = {}


static func defs() -> Dictionary:
	if _defs.is_empty():
		reload()
	return _defs


static func reload() -> void:
	_defs = {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		push_error("NpcRegistry: %s is not a JSON object" % PATH)
		return
	for id: String in data:
		if not id.begins_with("_"):
			_defs[StringName(id)] = data[id]


static func get_def(id: StringName) -> Dictionary:
	return defs().get(id, {})


## Current schedule entry, or {} if the NPC is absent.
static func resolve(id: StringName) -> Dictionary:
	for entry: Dictionary in get_def(id).get("schedule", []):
		var p: Variant = entry.get("period")
		if p != null:
			var now := WorldClock.get_period()
			if (p is Array and not now in p) or (p is String and p != now):
				continue
		if not StoryRules.evaluate(entry.get("if")):
			continue
		return entry
	return {}


static func facing_of(entry: Dictionary) -> int:
	return int(FACINGS.get(String(entry.get("facing", "down")), 3))


static func appearance_of(def: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.premade = String(def.get("premade", ""))
	a.custom_sheet = String(def.get("custom_sheet", ""))
	for layer in ["body", "eyes", "outfit", "hairstyle", "accessory"]:
		if def.has(layer):
			a.set(layer, String(def[layer]))
	if def.has("color"):
		a.placeholder_color = Color.html(def["color"])
	return a
