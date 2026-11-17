extends Node
## Who walks with the player. One companion at a time (data/characters/
## companions*.json); while someone is a companion their schedule is set
## aside and a follower appears beside the player in every location.
## Story data recruits and dismisses with {"companion": "id"} / {"companion": ""}.
##
## Bond (R8, D-080): time spent walking together and echoes beaten side by
## side build a bond with each companion, separate from the town-wide
## relationship value. Three tiers open three conversations on the road
## (camp dialogue choices gated by {"bond_at_least": ["id", tier]}) and, at
## the top tier, a better ability (companions.json "upgrades").

signal companion_changed(id: StringName)
signal bond_changed(id: StringName, tier: int)

const PATH := "res://data/characters/companions"
## Bond points needed for tiers 1, 2 and 3.
const TIERS := [10, 25, 45]
## Minutes walked together per bond point. Big clock jumps (sleeping,
## waiting, travel) count only up to MAX_STEP minutes.
const MINUTES_PER_POINT := 30
const MAX_STEP := 30

var defs: Dictionary = {}
var companion: StringName = &""
## companion id -> bond points
var bond: Dictionary = {}
var _minutes := 0
var _last_minute := -1


func _enter_tree() -> void:
	defs = DataFiles.defs(PATH)


func _ready() -> void:
	_connect_clock.call_deferred()


func _connect_clock() -> void:
	if not WorldClock.time_changed.is_connected(_on_time):
		WorldClock.time_changed.connect(_on_time)
	_last_minute = WorldClock.minute_of_day


func set_companion(id: StringName) -> void:
	if id != &"" and not defs.has(id):
		push_error("Party: '%s' is not a companion" % id)
		return
	if id == companion:
		return
	companion = id
	_minutes = 0
	companion_changed.emit(id)


func is_companion(id: StringName) -> bool:
	return companion != &"" and companion == id


func def_of(id: StringName) -> Dictionary:
	return defs.get(id, {})


func can_join(id: StringName) -> bool:
	return defs.has(id) and StoryRules.evaluate(defs[id].get("requires"))


func bond_points(id: StringName) -> int:
	return int(bond.get(String(id), 0))


func bond_tier(id: StringName) -> int:
	var p := bond_points(id)
	var t := 0
	for need: int in TIERS:
		if p >= need:
			t += 1
	return t


func add_bond(id: StringName, points: int) -> void:
	if not defs.has(id) or points == 0:
		return
	var before := bond_tier(id)
	bond[String(id)] = maxi(0, bond_points(id) + points)
	var after := bond_tier(id)
	if after != before:
		bond_changed.emit(id, after)
		if after > before and GameState.is_playing:
			EventHub.toast_requested.emit(tr("BOND_UP") % tr(String(defs[id].get("name", ""))))


## An echo fell while a companion was at your side.
func note_kill() -> void:
	if companion != &"":
		add_bond(companion, 1)


func _on_time(minute: int) -> void:
	var step := minute - _last_minute
	if step < 0:
		step += 24 * 60
	_last_minute = minute
	if companion == &"" or not GameState.is_playing:
		return
	_minutes += mini(step, MAX_STEP)
	while _minutes >= MINUTES_PER_POINT:
		_minutes -= MINUTES_PER_POINT
		add_bond(companion, 1)


func reset() -> void:
	set_companion(&"")
	bond = {}
	_minutes = 0


func to_dict() -> Dictionary:
	return {"companion": String(companion), "bond": bond.duplicate()}


func from_dict(d: Dictionary) -> void:
	var id := StringName(d.get("companion", ""))
	set_companion(id if defs.has(id) else &"")
	bond = {}
	var b: Variant = d.get("bond", {})
	if b is Dictionary:
		for k: String in b:
			bond[k] = int(b[k])
