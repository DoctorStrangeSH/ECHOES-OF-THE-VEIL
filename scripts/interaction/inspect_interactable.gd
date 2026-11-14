@tool
class_name InspectInteractable
extends Interactable
## Shows dialogue lines (localization keys). Optionally records a story flag
## the first time, and shows different lines once that flag is set.

@export var speaker_key: String = ""
@export var lines: PackedStringArray = []
## Flag set after the first interaction (empty = none).
@export var sets_flag: StringName = &""
## Lines shown instead of `lines` once `sets_flag` is already set.
@export var repeat_lines: PackedStringArray = []


func _on_interact(_actor: Node) -> void:
	var seen := sets_flag != &"" and GameState.has_flag(sets_flag)
	var to_show := repeat_lines if seen and not repeat_lines.is_empty() else lines
	if to_show.is_empty():
		push_warning("InspectInteractable '%s' has no lines" % interaction_id)
		return
	EventHub.message_requested.emit(to_show, speaker_key)
	if sets_flag != &"" and not seen:
		GameState.set_flag(sets_flag, true)
