@tool
class_name RestInteractable
extends Interactable
## A bed or safe spot. Opens the "rest" dialogue (save / wait / sleep), which
## lives in data/dialogue/rest.json so the options stay data-driven.

@export var dialogue_id: StringName = &"rest"


func _init() -> void:
	prompt_key = "PROMPT_REST"
	priority = 10


func _on_interact(_actor: Node) -> void:
	DialogueService.start(dialogue_id)
