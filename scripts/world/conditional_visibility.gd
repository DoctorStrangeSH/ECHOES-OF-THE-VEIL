extends Node
## Shows or hides its parent depending on a StoryRules condition, and disables
## the parent's collision/interaction while hidden. Re-evaluated whenever a
## flag, the journal or the time of day changes.
## Example: barriers that appear once the door has been reported.

@export var show_if: Dictionary = {}

var _parent: CanvasItem
var _saved_layer := -1


func _ready() -> void:
	_parent = get_parent() as CanvasItem
	# Method callables (not lambdas) are disconnected automatically when freed.
	EventHub.flag_changed.connect(_on_flag_changed)
	Journal.evidence_added.connect(_on_evidence_added)
	Journal.hypothesis_changed.connect(_on_hypothesis_changed)
	WorldClock.period_changed.connect(_on_period_changed)
	Journal.case_changed.connect(_on_case_changed)
	Inventory.changed.connect(refresh)
	Society.fact_learned.connect(_on_fact_learned)
	refresh.call_deferred()


func _on_flag_changed(_id: StringName, _v: Variant) -> void:
	refresh()


func _on_evidence_added(_id: StringName) -> void:
	refresh()


func _on_hypothesis_changed(_id: StringName, _s: String) -> void:
	refresh()


func _on_period_changed(_p: String) -> void:
	refresh()


func _on_case_changed(_id: StringName) -> void:
	refresh()


func _on_fact_learned(_npc: StringName, _fact: StringName) -> void:
	refresh()


func refresh() -> void:
	if _parent == null or not is_instance_valid(_parent):
		return
	var on := StoryRules.evaluate(show_if)
	_parent.visible = on
	if _parent is Interactable:
		(_parent as Interactable).enabled = on
	if _parent is CollisionObject2D:
		var body := _parent as CollisionObject2D
		if _saved_layer < 0:
			_saved_layer = body.collision_layer
		body.collision_layer = _saved_layer if on else 0
