@tool
class_name TalkInteractable
extends Interactable
## Starts an NPC's dialogue. Configured by Npc from its definition.

@export var dialogue_id: StringName = &""
@export var npc_id: StringName = &""


func _init() -> void:
	prompt_key = "PROMPT_TALK"
	priority = 20


func _on_interact(_actor: Node) -> void:
	if dialogue_id == &"":
		push_warning("NPC '%s' has no dialogue" % npc_id)
		return
	DialogueService.start(dialogue_id, {"npc": npc_id})
