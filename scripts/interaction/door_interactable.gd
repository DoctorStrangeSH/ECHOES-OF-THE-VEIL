@tool
class_name DoorInteractable
extends Interactable
## Moves the player to another location's spawn point via SceneFlow.
## Can be locked behind a flag.

@export var target_scene_id: StringName = &""
@export var target_spawn_id: StringName = &""
## If set, the door only opens when this flag is true.
@export var required_flag: StringName = &""
@export var locked_lines: PackedStringArray = ["DOOR_LOCKED"]


func _init() -> void:
	prompt_key = "PROMPT_ENTER"
	priority = 10


func _on_interact(_actor: Node) -> void:
	if required_flag != &"" and not GameState.has_flag(required_flag):
		EventHub.message_requested.emit(locked_lines, "")
		return
	SceneFlow.travel(target_scene_id, target_spawn_id)
