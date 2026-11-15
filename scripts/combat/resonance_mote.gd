class_name ResonanceMote
extends Area2D
## Memory mote dropped by echoes. Drifts to the player when close; collected
## on touch. With `item_id` set it is an item pickup instead (e.g. a sandwich).

@export var item_id: StringName = &""
@export var amount: int = 1

var _t := 0.0
var _player: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # player body
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player != null and _t > 0.35:
		var d := _player.global_position + Vector2(0, -6) - global_position
		if d.length() < 56.0:
			global_position += d.normalized() * minf(d.length(), 140.0 * delta)
	if _t > 25.0:
		queue_free()


func _draw() -> void:
	var bob := sin(_t * 5.0) * 1.5
	if item_id != &"":
		draw_rect(Rect2(-3, -8 + bob, 6, 5), Color(0.95, 0.8, 0.5))
		draw_rect(Rect2(-3, -8 + bob, 6, 5), Color(0.3, 0.2, 0.1), false, 1.0)
	else:
		draw_circle(Vector2(0, -6 + bob), 3.0, Color(0.6, 0.95, 1.0, 0.35))
		draw_circle(Vector2(0, -6 + bob), 1.5, Color(0.85, 1.0, 1.0, 0.95))


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	if item_id != &"":
		Inventory.add(item_id, amount)
	else:
		Inventory.add_resonance(amount)
		Sfx.play(&"coin", 0.15, -4.0)
	queue_free()
