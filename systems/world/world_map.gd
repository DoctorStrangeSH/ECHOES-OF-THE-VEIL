class_name WorldMap
extends RefCounted
## Travel between towns (R12a). Data: data/world/world_map.json: cities (where
## they are on the coast map, which scenes belong to them, where you arrive)
## and routes between them (mode, fare, hours). Greyford is the town every
## scene belongs to unless a city lists it. Coach today; car and plane are
## modes of the same route table later.

const PATH := "res://data/world/world_map.json"
const HOME := "greyford"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = DataFiles.read_json(PATH)
		_data = d if d is Dictionary else {"cities": {}, "routes": []}
	return _data


static func cities() -> Dictionary:
	return data().get("cities", {})


static func city_of(scene: StringName) -> String:
	for id: String in cities():
		if (cities()[id].get("scenes", []) as Array).has(String(scene)):
			return id
	return HOME


static func known(id: String) -> bool:
	return cities().has(id) and StoryRules.evaluate(cities()[id].get("known_if", {}))


## Routes leaving `city` to towns you know of.
static func routes_from(city: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in data().get("routes", []):
		var other := ""
		if String(r["from"]) == city:
			other = String(r["to"])
		elif String(r["to"]) == city:
			other = String(r["from"])
		if other != "" and known(other) and StoryRules.evaluate(r.get("if", {})):
			var rr := r.duplicate()
			rr["dest"] = other
			out.append(rr)
	return out


## Go. Returns false when it can't be done (no route, no money).
static func travel(to: String) -> bool:
	var here := city_of(GameState.current_scene_id)
	for r in routes_from(here):
		if String(r["dest"]) != to:
			continue
		var fare := int(r.get("fare", 0))
		if Inventory.money < fare:
			EventHub.toast_requested.emit(TranslationServer.translate("TRAVEL_NO_MONEY"))
			return false
		Inventory.money -= fare
		WorldClock.advance_minutes(int(r.get("minutes", 60)))
		var arrive: Array = cities()[to]["arrive"]
		GameState.set_flag(StringName("travel.visited.%s" % to))
		EventHub.toast_requested.emit(String(TranslationServer.translate("TRAVEL_ARRIVED")) % TranslationServer.translate(String(cities()[to]["name"])))
		SceneFlow.travel(StringName(arrive[0]), StringName(arrive[1]))
		return true
	return false
