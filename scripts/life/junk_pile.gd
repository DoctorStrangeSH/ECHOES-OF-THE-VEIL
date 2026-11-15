@tool
class_name JunkPile
extends Interactable
## Salvage spot: gives a little scrap once per in-game day.

@export var amount: int = 2


func _init() -> void:
	prompt_key = "PROMPT_SALVAGE"
	interaction_priority = 5
	area_size = Vector2(24, 16)


func _flag() -> StringName:
	return StringName("junk.%s.day" % interaction_id)


func can_interact(actor: Node) -> bool:
	return super.can_interact(actor) and int(GameState.get_flag(_flag(), 0)) != WorldClock.day


func _on_interact(_actor: Node) -> void:
	GameState.set_flag(_flag(), WorldClock.day)
	Inventory.add(&"scrap", amount)
