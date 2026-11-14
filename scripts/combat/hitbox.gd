class_name Hitbox
extends Area2D
## Deals damage to overlapping Hurtboxes of other teams when `strike()` is
## called (on the attack's impact frame). Each hurtbox is hit at most once
## per strike.

@export var team: StringName = &"player"
@export var damage: int = 1
@export var knockback: float = 140.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hurtbox.LAYER_COMBAT
	monitoring = true
	monitorable = false


## Returns the number of hurtboxes hit.
func strike() -> int:
	var count := 0
	for area in get_overlapping_areas():
		var hb := area as Hurtbox
		if hb == null or hb.team == team:
			continue
		if hb.receive(damage, global_position, knockback):
			count += 1
	return count
