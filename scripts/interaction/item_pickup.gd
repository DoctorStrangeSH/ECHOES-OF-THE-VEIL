@tool
class_name ItemPickup
extends Interactable
## An item lying in the world. Picked up with Interact; `pickup_flag` makes
## it one-time (it stays gone after saving/loading).

@export var item_id: StringName = &""
@export var amount: int = 1
@export var pickup_flag: StringName = &""

var _t := 0.0


func _init() -> void:
	prompt_key = "PROMPT_PICK_UP"
	interaction_priority = 15
	area_size = Vector2(16, 14)


func _ready() -> void:
	super._ready()
	if interaction_id == &"":
		interaction_id = StringName("pickup_%s" % item_id)
	if not Engine.is_editor_hint() and pickup_flag != &"" and GameState.has_flag(pickup_flag):
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var color := Color(0.9, 0.8, 0.5)
	if not Engine.is_editor_hint() and Inventory.item_defs.has(item_id):
		color = Color.html(Inventory.def(item_id).get("color", "#e0c080"))
	var bob := sin(_t * 3.0) * 1.0
	draw_circle(Vector2(0, 2), 5.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-4, -6 + bob, 8, 7), color)
	draw_rect(Rect2(-4, -6 + bob, 8, 7), color.darkened(0.5), false, 1.0)
	draw_circle(Vector2(0, -12 + bob), 1.5 + 0.5 * sin(_t * 6.0), Color(1, 1, 0.8, 0.8))


func _on_interact(_actor: Node) -> void:
	if item_id == &"":
		return
	Inventory.add(item_id, amount)
	if pickup_flag != &"":
		GameState.set_flag(pickup_flag, true)
	queue_free()
