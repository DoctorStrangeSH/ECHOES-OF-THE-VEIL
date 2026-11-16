class_name PasserbyTalk
extends Interactable
## "Talk" on a passer-by: a line in a speech bubble, no dialogue window.

var passerby: Passerby


func _init() -> void:
	prompt_key = "PROMPT_PASSERBY"
	interaction_priority = 5
	area_size = Vector2(14, 22)
	position = Vector2(0, -10)
	interaction_id = &"talk_passerby"


func _on_interact(actor: Node) -> void:
	if passerby != null:
		passerby.speak(actor as Node2D)
