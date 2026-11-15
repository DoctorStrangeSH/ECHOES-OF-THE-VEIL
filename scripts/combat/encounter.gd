class_name Encounter
extends Node
## Watches the echo enemies of its location and sets `clear_flag` once none
## are left (immediately, if they were all defeated on an earlier visit).

@export var clear_flag: StringName = &""

var _done := false


func _ready() -> void:
	_check.call_deferred()


func _process(_delta: float) -> void:
	if not _done:
		_check()


func _check() -> void:
	if _done or clear_flag == &"":
		return
	var parent := get_parent()
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if parent.is_ancestor_of(e):
			return
	_done = true
	if not GameState.has_flag(clear_flag):
		GameState.set_flag(clear_flag, true)
