class_name QuestGuide
extends RefCounted
## Where and when the current step of a case happens (R0, D-064). Used by the
## HUD and journal when the "detailed" guidance setting is on. Data:
## data/story/guides.json (hand-written per stage/objective), incidents from
## data/world/incidents.json, doors from data/world/doors.json (generated).

const GUIDES_PATH := "res://data/story/guides.json"
const DOORS_PATH := "res://data/world/doors.json"

static var _guides: Dictionary = {}
static var _doors: Dictionary = {}


static func _load() -> void:
	if _guides.is_empty():
		var g: Variant = DataFiles.read_json(GUIDES_PATH)
		_guides = g if g is Dictionary else {"_": {}}
		var d: Variant = DataFiles.read_json(DOORS_PATH)
		_doors = d if d is Dictionary else {}


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func guides() -> Dictionary:
	_load()
	return _guides


## The first unfinished required objective of the case's current stage.
static func current_objective_id(case_id: StringName) -> String:
	for o in Journal.objectives_for(case_id):
		if not o["done"] and not o["optional"]:
			return String(o["id"])
	return ""


## Guide entry for the case's current step ({} if none).
static func target(case_id: StringName) -> Dictionary:
	_load()
	if Journal.case_status(case_id) != Journal.STATUS_ACTIVE:
		return {}
	var stage := String(Journal.case_stage(case_id))
	for inc: StringName in Incidents.defs():
		var d := Incidents.def(inc)
		if StringName(d.get("case", "")) == case_id:
			if stage == String(Incidents.CLEAR_STAGE):
				return {"scene": d["scene"]}
			return {"npc": d.get("npc", "")}
	var by_case: Dictionary = _guides.get(String(case_id), {})
	var oid := current_objective_id(case_id)
	if oid != "" and by_case.has(stage + "/" + oid):
		return by_case[stage + "/" + oid]
	return by_case.get(stage, {})


static func when_ok(g: Dictionary) -> bool:
	if not g.has("period"):
		return true
	if bool(g.get("or_rain", false)) and WorldClock.weather == "rain":
		return true
	var p: Variant = g["period"]
	var now := WorldClock.get_period()
	return now in p if p is Array else String(p) == now


## The scene the step happens in right now ("" if unknown or nobody's there).
static func scene_of(g: Dictionary) -> StringName:
	if g.has("npc"):
		var id := StringName(g["npc"])
		if Party.is_companion(id):
			return GameState.current_scene_id
		return StringName(NpcRegistry.resolve(id).get("scene", ""))
	return StringName(g.get("scene", ""))


static func scene_name(scene: StringName) -> String:
	var key := "LOC_" + String(scene).to_upper()
	var t := _t(key)
	return String(scene).capitalize() if t == key else t


static func period_text(g: Dictionary) -> String:
	var p: Variant = g.get("period", [])
	var parts := PackedStringArray()
	for x: String in (p if p is Array else [p]):
		parts.append(_t("PERIOD_" + x.to_upper()).to_lower())
	var t := _t("GUIDE_OR").join(parts)
	if bool(g.get("or_rain", false)):
		t += _t("GUIDE_OR") + _t("GUIDE_RAIN")
	return t


## One or two short lines for the HUD/journal.
static func describe(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	var parts := PackedStringArray()
	if g.has("npc"):
		var npc_name: String = _t(String(NpcRegistry.get_def(StringName(g["npc"])).get("name", "")))
		var where := scene_of(g)
		if where == &"":
			parts.append(_t("GUIDE_WHO_AWAY") % npc_name)
		else:
			parts.append(_t("GUIDE_WHO_AT") % [npc_name, scene_name(where)])
	elif g.has("scene"):
		parts.append(_t("GUIDE_WHERE") % scene_name(StringName(g["scene"])))
	if g.has("period"):
		if when_ok(g):
			parts.append(_t("GUIDE_WHEN_NOW") % period_text(g))
		else:
			parts.append(_t("GUIDE_WHEN_WAIT") % period_text(g))
	var line := " · ".join(parts)
	if g.has("note"):
		line = (line + "\n" if line != "" else "") + _t(String(g["note"]))
	return line


## The open-world place a scene belongs to: itself, or the nearest one its
## doors lead out to (an interior's street).
static func outdoor_of(scene: StringName) -> StringName:
	_load()
	if OpenWorld.has_region(scene):
		return scene
	var seen := {String(scene): true}
	var queue: Array[String] = [String(scene)]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for door: Dictionary in _doors.get(cur, []):
			var nxt := String(door["to"])
			if seen.has(nxt):
				continue
			if OpenWorld.has_region(StringName(nxt)):
				return StringName(nxt)
			seen[nxt] = true
			queue.append(nxt)
	return &""


## The next door node to take from `from` towards `to` ("" if none or there).
static func next_door(from: StringName, to: StringName) -> String:
	_load()
	if from == to or to == &"":
		return ""
	var prev: Dictionary = {String(from): ""}
	var first: Dictionary = {String(from): ""}
	var queue: Array[String] = [String(from)]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for door: Dictionary in _doors.get(cur, []):
			var nxt := String(door["to"])
			if prev.has(nxt):
				continue
			if door.has("show_if") and not StoryRules.evaluate(door["show_if"]):
				continue
			prev[nxt] = cur
			first[nxt] = String(door["node"]) if cur == String(from) else first[cur]
			if nxt == String(to):
				return first[nxt]
			queue.append(nxt)
	return ""


## The node to point at in the current location (the target itself, or the
## next door towards it); null if there's nothing sensible to point at.
static func world_target(location: Node, g: Dictionary) -> Node2D:
	if location == null or g.is_empty():
		return null
	var here := GameState.current_scene_id
	var scene := scene_of(g)
	if scene == &"":
		return null
	if scene != here:
		# In the open world: point at the street the target is on, until you
		# are there; from there the door leads in.
		if SceneFlow.open_world != null and OpenWorld.has_region(here):
			var street := outdoor_of(scene)
			if street != &"" and street != here:
				return SceneFlow.open_world.guide_marker(street)
		var door := next_door(here, scene)
		return _visible_node(location, [door]) if door != "" else null
	if g.has("npc"):
		var id := StringName(g["npc"])
		for n in location.find_children("*", "Npc", true, false):
			if (n as Npc).npc_id == id:
				return n as Node2D
		return null
	var names: Array = g["node"] if g.get("node") is Array else ([g["node"]] if g.has("node") else [])
	return _visible_node(location, names)


static func _visible_node(location: Node, names: Array) -> Node2D:
	for nm: Variant in names:
		var n := location.find_child(String(nm), true, false)
		if n is Node2D and (n as Node2D).is_visible_in_tree():
			if n is Interactable and not (n as Interactable).enabled:
				continue
			return n
	return null
