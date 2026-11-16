class_name CityMap
extends RefCounted
## The city's districts (data/world/city_map.json): where you are, what you
## know, and bus rides between stops (R2d).

const PATH := "res://data/world/city_map.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = DataFiles.read_json(PATH)
		_data = d if d is Dictionary else {"districts": {}, "roads": []}
	return _data


static func districts() -> Dictionary:
	return data().get("districts", {})


static func district_of(scene: StringName) -> String:
	for id: String in districts():
		if (districts()[id].get("scenes", []) as Array).has(String(scene)):
			return id
	return ""


## Known: its condition holds and you have set foot in one of its places.
static func known(id: String) -> bool:
	var d: Dictionary = districts().get(id, {})
	if d.is_empty() or not StoryRules.evaluate(d.get("known_if", {})):
		return false
	if d.has("open_if") and StoryRules.evaluate(d["open_if"]):
		return true  # heard of it: the bus goes there before you have been
	for s: String in d.get("scenes", []):
		if GameState.has_flag(StringName("visited." + s)):
			return true
	return false


## Districts you can ride to from where you stand.
static func destinations(from_scene: StringName) -> Array[String]:
	var here := district_of(from_scene)
	var out: Array[String] = []
	for id: String in districts():
		if id != here and districts()[id].get("stop") != null and known(id):
			out.append(id)
	return out


static func fare() -> int:
	return int(data().get("fare", 2))


## A district further out can cost more and take longer.
static func fare_to(id: String) -> int:
	return int(districts().get(id, {}).get("fare", fare()))


## Ride the bus. Returns false if it can't be done (unknown stop, no money).
static func ride(to: String) -> bool:
	var d: Dictionary = districts().get(to, {})
	var stop: Variant = d.get("stop")
	if stop == null or not known(to):
		return false
	if Inventory.money < fare_to(to):
		EventHub.toast_requested.emit(TranslationServer.translate("BUS_NO_MONEY"))
		return false
	Inventory.money -= fare_to(to)
	WorldClock.advance_minutes(int(d.get("ride_minutes", data().get("ride_minutes", 20))))
	EventHub.toast_requested.emit(String(TranslationServer.translate("BUS_RIDE")) % TranslationServer.translate(String(d["name"])))
	SceneFlow.travel(StringName(stop[0]), StringName(stop[1]))
	return true
