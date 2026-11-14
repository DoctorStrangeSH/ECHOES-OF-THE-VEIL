class_name Health
extends Node
## Hit points with a short invulnerability window after each hit.

signal changed(health: int, max_health: int)
signal damaged(amount: int, from_position: Vector2)
signal died

@export var max_health: int = 3
@export var invulnerability_time: float = 0.6

var health: int
var _invulnerable_until := 0.0


func _ready() -> void:
	health = max_health


func is_dead() -> bool:
	return health <= 0


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invulnerable_until


## Returns true if the damage was applied.
func take_damage(amount: int, from_position: Vector2) -> bool:
	if is_dead() or is_invulnerable() or amount <= 0:
		return false
	health = maxi(0, health - amount)
	_invulnerable_until = Time.get_ticks_msec() / 1000.0 + invulnerability_time
	changed.emit(health, max_health)
	damaged.emit(amount, from_position)
	if health == 0:
		died.emit()
	return true


func heal_full() -> void:
	health = max_health
	changed.emit(health, max_health)
