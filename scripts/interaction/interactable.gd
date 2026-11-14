@tool
class_name Interactable
extends Area2D
## Base contract for anything the player can use: stable ID, prompt text,
## priority, and `interact(actor)`. Subclasses override `_on_interact`.
##
## Priority convention (docs/design/gameplay-systems.md):
## story interaction (20) > usable object (10) > ambient inspect (0).
## If no CollisionShape2D child exists, one is created from `area_size`.

signal interacted(actor: Node)

const LAYER_INTERACTABLE := 1 << 2

@export var interaction_id: StringName = &""
@export var prompt_key: String = "PROMPT_INSPECT"
@export var priority: int = 0
@export var enabled: bool = true
@export var area_size: Vector2 = Vector2(16, 16):
	set(value):
		area_size = value
		_sync_shape()


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	_sync_shape()


func can_interact(_actor: Node) -> bool:
	return enabled


func get_prompt() -> String:
	return tr(prompt_key)


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	if interaction_id == &"":
		push_warning("Interactable '%s' has no interaction_id" % get_path())
	EventHub.interaction_performed.emit(interaction_id)
	interacted.emit(actor)
	_on_interact(actor)


## Override in subclasses.
func _on_interact(_actor: Node) -> void:
	pass


func _sync_shape() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			shape_node = child
			break
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "AutoShape"
		add_child(shape_node, false, Node.INTERNAL_MODE_FRONT)
	if shape_node.name == "AutoShape":
		var rect := RectangleShape2D.new()
		rect.size = area_size
		shape_node.shape = rect
