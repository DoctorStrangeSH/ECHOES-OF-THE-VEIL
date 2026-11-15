extends Node
## The campaign spine: acts from data/story/campaign.json start in order when
## their condition holds. Starting an act sets flag act.<id>, runs its effects
## and announces it (the act card). Everything is derived from flags, so it
## works with any save and needs no state of its own.

signal act_started(act_id: StringName)

const PATH := "res://data/story/campaign.json"

var acts: Array[Dictionary] = []
var _queued := false


func _ready() -> void:
	reload()
	EventHub.flag_changed.connect(_on_change.unbind(2))
	Journal.case_changed.connect(_on_change.unbind(1))
	Journal.hypothesis_changed.connect(_on_change.unbind(2))
	Journal.evidence_added.connect(_on_change.unbind(1))
	WorldClock.period_changed.connect(_on_change.unbind(1))
	SceneFlow.location_entered.connect(_on_change.unbind(1))


func reload() -> void:
	acts.clear()
	var data: Variant = DataFiles.read_json(PATH)
	if data is Dictionary:
		for a: Dictionary in data.get("acts", []):
			acts.append(a)


func act(id: StringName) -> Dictionary:
	for a in acts:
		if StringName(a["id"]) == id:
			return a
	return {}


func has_started(id: StringName) -> bool:
	return GameState.has_flag(StringName("act.%s" % id))


## The last act that has started ("" before a game begins).
func current_act() -> StringName:
	var cur := &""
	for a in acts:
		if has_started(StringName(a["id"])):
			cur = StringName(a["id"])
	return cur


func current_title_key() -> String:
	var a := act(current_act())
	return String(a.get("title", ""))


## Starts every act whose turn has come, in order; one per call of the loop.
func check() -> void:
	_queued = false
	if not GameState.is_playing:
		return
	for a in acts:
		var id := StringName(a["id"])
		if has_started(id):
			continue
		if a.get("planned", false) or not StoryRules.evaluate(a.get("begins_if", {})):
			return  # acts start strictly in order
		GameState.set_flag(StringName("act.%s" % id))
		StoryRules.apply(a.get("effects", []))
		if not a.get("silent", false):
			act_started.emit(id)


func _on_change() -> void:
	if not _queued:
		_queued = true
		check.call_deferred()
