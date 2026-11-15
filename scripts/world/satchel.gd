class_name Satchel
extends Interactable
## What the player dropped when they last fainted (GameState.satchel). Placed
## by Location where they fell; picking it up gives everything back.

var _sprite_t := 0.0


func _init() -> void:
	prompt_key = "PROMPT_SATCHEL"
	interaction_priority = 40
	area_size = Vector2(24, 20)
	interaction_id = &"satchel"


func _on_interact(_actor: Node) -> void:
	GameState.recover_satchel()
	Sfx.play(&"pickup")
	queue_free()


func _process(delta: float) -> void:
	_sprite_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_sprite_t * 3.0) * 1.5
	draw_rect(Rect2(-6, -10 + bob, 12, 9), Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(-6, -10 + bob, 12, 9), Color(0.95, 0.85, 0.5), false, 1.0)
	draw_circle(Vector2(0, -12 + bob), 2.0, Color(0.7, 0.9, 1.0, 0.8))
