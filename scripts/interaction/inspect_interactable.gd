@tool
class_name InspectInteractable
extends Interactable
## Shows a conversation: either a full dialogue (`dialogue_id`, with branches,
## evidence and choices) or plain lines (localization keys). Optionally sets a
## flag the first time and shows `repeat_lines` afterwards.

## If set, runs this dialogue from res://data/dialogue and ignores `lines`.
@export var dialogue_id: StringName = &""
@export var speaker_key: String = ""
@export var lines: PackedStringArray = []
## Flag set after the first interaction (empty = none).
@export var sets_flag: StringName = &""
## Lines shown instead of `lines` once `sets_flag` is already set.
@export var repeat_lines: PackedStringArray = []


func _on_interact(_actor: Node) -> void:
	if dialogue_id != &"":
		DialogueService.start(dialogue_id, {"interaction_id": interaction_id})
		return
	var seen := sets_flag != &"" and GameState.has_flag(sets_flag)
	var to_show := repeat_lines if seen and not repeat_lines.is_empty() else lines
	if to_show.is_empty():
		push_warning("InspectInteractable '%s' has no lines" % interaction_id)
		return
	DialogueService.show_lines(to_show, speaker_key)
	if sets_flag != &"" and not seen:
		GameState.set_flag(sets_flag, true)
