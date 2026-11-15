@tool
class_name WorldProp
extends StaticBody2D
## A placed sprite (building, tree, lamp...) with an optional collision box at
## its base. The node origin is the prop's ground contact point (bottom-centre
## of the sprite), which is what y-sorting uses.
## Works without the art packs: shows a coloured placeholder of the same size.

## Path relative to res://assets/limezu (or a full res:// path).
@export var texture_path: String = "":
	set(value):
		texture_path = value
		_refresh()
## Size used when the texture is missing.
@export var placeholder_size: Vector2i = Vector2i(16, 32):
	set(value):
		placeholder_size = value
		_refresh()
@export var placeholder_color: Color = Color(0.55, 0.5, 0.6):
	set(value):
		placeholder_color = value
		_refresh()
## Collision rectangle, centred on `collision_offset` (relative to the origin).
## Zero size = walk-through decoration.
@export var collision_size: Vector2 = Vector2(16, 8):
	set(value):
		collision_size = value
		_refresh()
@export var collision_offset: Vector2 = Vector2(0, -4):
	set(value):
		collision_offset = value
		_refresh()
## Optional sub-rectangle of the texture (for objects cut from a tile sheet).
@export var region: Rect2 = Rect2():
	set(value):
		region = value
		_refresh()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_refresh()

var _sprite: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var tex := AssetLibrary.load_texture(texture_path)
	var use_region := tex != null and region.has_area()
	if tex == null:
		tex = AssetLibrary.placeholder(placeholder_size, placeholder_color)
	_sprite.texture = tex
	_sprite.flip_h = flip_h
	_sprite.region_enabled = use_region
	if use_region:
		_sprite.region_rect = region
	var size := region.size if use_region else tex.get_size()
	_sprite.offset = Vector2(-floorf(size.x / 2.0), -size.y)
	if collision_size.x > 0.0 and collision_size.y > 0.0:
		var rect := RectangleShape2D.new()
		rect.size = collision_size
		_shape.shape = rect
		_shape.position = collision_offset
		_shape.disabled = false
	else:
		_shape.shape = null
		_shape.disabled = true
