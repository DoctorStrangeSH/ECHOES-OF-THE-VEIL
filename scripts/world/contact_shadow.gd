class_name ContactShadow
extends Node2D
## A soft dark oval under a person's feet, so they stand on the ground
## instead of floating over it.

@export var radius := Vector2(6.0, 2.5)


func _ready() -> void:
	show_behind_parent = true
	z_index = 0


func _draw() -> void:
	for i in 3:
		var k := 1.0 - i * 0.28
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(radius.x * k, radius.y * k))
		draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.12))
