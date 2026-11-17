class_name Cooking
extends RefCounted
## Cooking (R7b, D-086): recipes turn what you grow, catch and forage into
## dishes (data/cooking/recipes.json). A dish heals and may leave a "meal":
## a few hours of a small bonus (Inventory.meal). One meal at a time; a new
## one replaces the old. Cooking takes COOK_MINUTES at a stove or campfire
## (region screen "cook").

const PATH := "res://data/cooking/recipes.json"
const COOK_MINUTES := 20

static var _recipes: Dictionary = {}


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		var d: Variant = DataFiles.read_json(PATH)
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_"):
					_recipes[StringName(k)] = d[k]
	return _recipes


## How many of a need the bag holds (an "any" need counts every listed item).
static func have(need: Dictionary) -> int:
	if need.has("item"):
		return Inventory.count(StringName(need["item"]))
	var n := 0
	for id: String in need.get("any", []):
		n += Inventory.count(StringName(id))
	return n


static func can_cook(id: StringName) -> bool:
	var r: Dictionary = recipes().get(id, {})
	if r.is_empty():
		return false
	for need: Dictionary in r.get("needs", []):
		if have(need) < int(need.get("n", 1)):
			return false
	return true


static func cook(id: StringName) -> bool:
	if not can_cook(id):
		return false
	var r: Dictionary = recipes()[id]
	for need: Dictionary in r["needs"]:
		var left := int(need.get("n", 1))
		var pool: Array = [need["item"]] if need.has("item") else need.get("any", [])
		for item: String in pool:
			while left > 0 and Inventory.count(StringName(item)) > 0:
				Inventory.remove(StringName(item))
				left -= 1
	Inventory.add(StringName(r["makes"]), 1, false)
	WorldClock.advance_minutes(COOK_MINUTES)
	Sfx.play(&"use", 0.1, -4.0)
	EventHub.toast_requested.emit(TranslationServer.translate("COOK_DONE") % TranslationServer.translate(String(Inventory.def(StringName(r["makes"])).get("name", ""))))
	GameState.set_flag(&"cooked.any", true)
	return true


## A need as text: "2× carrot or turnip (1/2)".
static func need_text(need: Dictionary) -> String:
	var names := PackedStringArray()
	var pool: Array = [need["item"]] if need.has("item") else need.get("any", [])
	for item: String in pool:
		names.append(TranslationServer.translate(String(Inventory.def(StringName(item)).get("name", item))))
	var label: String = String(TranslationServer.translate(String(need["label"]))) if need.has("label") else String(TranslationServer.translate("GUIDE_OR")).join(names)
	return "%d× %s (%d)" % [int(need.get("n", 1)), label, have(need)]
