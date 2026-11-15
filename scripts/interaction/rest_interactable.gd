@tool
class_name RestInteractable
extends Interactable
## A bed or safe spot: rests and saves the game to the default slot.


func _init() -> void:
	prompt_key = "PROMPT_REST"
	priority = 10


func _on_interact(_actor: Node) -> void:
	var err := SaveService.save_game()
	if err == OK:
		EventHub.message_requested.emit(PackedStringArray(["REST_SAVED"]), "")
	else:
		EventHub.message_requested.emit(PackedStringArray(["REST_SAVE_FAILED"]), "")
