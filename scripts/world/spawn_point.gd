@tool
class_name SpawnPoint
extends Marker2D
## Where the player appears when entering a location with this `spawn_id`.

@export var spawn_id: StringName = &""
@export var facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	add_to_group(&"spawn_point")
