class_name MemoryShard
extends Hitbox
## A thrown shard of someone's memory (Wailer projectile). Flies straight,
## breaks on walls or the first target it hits.

@export var speed: float = 120.0
@export var lifetime: float = 1.8

var direction := Vector2.RIGHT


func _ready() -> void:
	add_to_group(&"memory_shard")
	add_to_group(&"threat")
	super._ready()
	team = &"enemy"
	damage = 1
	knockback = 110.0
	collision_mask = Hurtbox.LAYER_COMBAT | 1  # targets + world
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0 or strike() > 0:
		_break()


func _on_body_entered(_body: Node) -> void:
	_break()


func _break() -> void:
	set_physics_process(false)
	monitoring = false
	queue_free()


## A dodge now is perfect: the shard is about to hit `at`.
func is_threatening(at: Vector2) -> bool:
	var to := at + Vector2(0, -8) - global_position
	return to.length() < 30.0 and to.dot(direction) > 0.0
