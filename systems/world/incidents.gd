extends Node
## Post-ending world incidents (M8b). After the ending, every few days the
## Veil acts up somewhere in town: a short case starts, its echoes appear in
## one Veil location, and the player has a few days to clear them and report
## to the person who noticed. Missing it is a consequence (the case fails),
## never a blocker. Which incidents can happen depends on the ending.
## Data: data/world/incidents.json; cases: data/journal/incidents.json.
## State lives in flags (no save schema change): incidents.next_day.

signal incident_cleared(id: StringName)

const PATH := "res://data/world/incidents.json"
const ENEMY_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const UNLOCK_FLAG := &"game.completed"
const NEXT_DAY_FLAG := &"incidents.next_day"
const CLEAR_STAGE := &"clear"
const REPORT_STAGE := &"report"
const COOLDOWN_DAYS := 2

var _defs: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	var d: Variant = DataFiles.read_json(PATH)
	if d is Dictionary:
		for k: String in d:
			if k.begins_with("_"):
				continue
			_defs[StringName(k)] = d[k]
			_order.append(StringName(k))
	WorldClock.day_started.connect(_on_day_started)
	Journal.case_changed.connect(_on_case_changed)


func defs() -> Dictionary:
	return _defs


func def(id: StringName) -> Dictionary:
	return _defs.get(id, {})


func case_of(id: StringName) -> StringName:
	return StringName(def(id).get("case", ""))


## The incident in progress, or &"".
func active() -> StringName:
	for id in _order:
		if Journal.case_status(case_of(id)) == Journal.STATUS_ACTIVE:
			return id
	return &""


## Incidents that could start now (in data order; the first one starts).
func eligible() -> Array[StringName]:
	var out: Array[StringName] = []
	if not GameState.has_flag(UNLOCK_FLAG):
		return out
	for id in _order:
		if Journal.case_status(case_of(id)) != Journal.STATUS_NONE:
			continue
		if StoryRules.evaluate(def(id).get("requires", {})):
			out.append(id)
	return out


func _on_day_started(day: int) -> void:
	try_start(day)


## Starts the next incident if none is running and the cooldown has passed.
func try_start(day: int = -1) -> StringName:
	if day < 0:
		day = WorldClock.day
	if active() != &"" or day < int(GameState.get_flag(NEXT_DAY_FLAG, 0)):
		return &""
	var pool := eligible()
	if pool.is_empty():
		return &""
	var id := pool[0]
	Journal.start_case(case_of(id))
	return id


func _on_case_changed(case_id: StringName) -> void:
	for id in _order:
		if case_of(id) == case_id:
			var st := Journal.case_status(case_id)
			if st == Journal.STATUS_DONE or st == Journal.STATUS_FAILED:
				GameState.set_flag(NEXT_DAY_FLAG, WorldClock.day + COOLDOWN_DAYS)
			return


## Called by every Location on entering: spawns the incident's echoes here.
func populate(location: Location) -> void:
	var id := active()
	if id == &"":
		return
	var d := def(id)
	if StringName(d.get("scene", "")) != location.location_id or Journal.case_stage(case_of(id)) != CLEAR_STAGE:
		return
	var spawned: Array[EchoEnemy] = []
	for s: Dictionary in d.get("spawns", []):
		var e: EchoEnemy = ENEMY_SCENE.instantiate()
		e.variant = String(s.get("variant", "hollow"))
		e.position = Vector2(float(s["x"]), float(s["y"]))
		e.add_to_group(&"incident_echo")
		location.entities.add_child(e)
		spawned.append(e)
	var watch := IncidentWatch.new()
	watch.incident_id = id
	watch.enemies = spawned
	location.add_child(watch)
	if d.has("arrive_toast"):
		EventHub.toast_requested.emit(tr(String(d["arrive_toast"])))


## The echoes are gone: on to reporting.
func mark_cleared(id: StringName) -> void:
	var c := case_of(id)
	if Journal.case_stage(c) != CLEAR_STAGE or Journal.case_status(c) != Journal.STATUS_ACTIVE:
		return
	StoryRules.apply([{"quest_stage": [String(c), String(REPORT_STAGE)]}])
	EventHub.toast_requested.emit(tr("INC_TOAST_CLEARED"))
	incident_cleared.emit(id)


class IncidentWatch:
	extends Node
	var incident_id: StringName
	var enemies: Array[EchoEnemy] = []
	var _done := false

	func _process(_delta: float) -> void:
		if _done:
			return
		for e in enemies:
			if is_instance_valid(e) and e.state != EchoEnemy.State.DEAD:
				return
		_done = true
		Incidents.mark_cleared(incident_id)
