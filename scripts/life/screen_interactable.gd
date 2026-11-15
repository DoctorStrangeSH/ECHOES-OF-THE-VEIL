@tool
class_name ScreenInteractable
extends Interactable
## Opens a work/trade screen (jobs board, workbench, stall) when used.

@export var screen: String = "jobs"


func _init() -> void:
	prompt_key = "PROMPT_USE"
	interaction_priority = 12


func _on_interact(_actor: Node) -> void:
	EventHub.screen_requested.emit(screen)
