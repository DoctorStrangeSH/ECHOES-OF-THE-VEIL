class_name Hurtbox
extends Area2D
## Receives hits from Hitboxes of another team and forwards them to a Health.

const LAYER_COMBAT := 1 << 4

@export var team: StringName = &"enemy"
@export var health_path: NodePath

signal hit(damage: int, from_position: Vector2, knockback: float)

var health: Health


func _ready() -> void:
	collision_layer = LAYER_COMBAT
	collision_mask = 0
	monitoring = false
	monitorable = true
	if not health_path.is_empty():
		health = get_node(health_path) as Health


func receive(damage: int, from_position: Vector2, knockback: float) -> bool:
	if team == &"player":
		damage = GameState.incoming_damage(damage)
	if health != null and not health.take_damage(damage, from_position):
		return false
	hit.emit(damage, from_position, knockback)
	return true
