@tool
class_name NpcAnchor
extends Marker2D
## A named spot where scheduled NPCs stand (see data/characters/npcs.json).

@export var anchor_id: StringName = &""


func _ready() -> void:
	add_to_group(&"npc_anchor")
