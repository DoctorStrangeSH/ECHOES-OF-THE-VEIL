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

## Light this thing gives off after dark (alpha 0 = none), from a point
## `light_offset` above its base, reaching `light_radius` pixels.
@export var light_color: Color = Color(0, 0, 0, 0)
@export var light_offset: Vector2 = Vector2.ZERO
@export var light_radius: float = 48.0
## Casts a sun shadow outdoors (tall solid things). Set by the build tool.
@export var casts_shadow: bool = false

## How see-through a tall thing gets while you stand behind it.
const BEHIND_ALPHA := 0.42

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _shadow: Sprite2D
var _light: PointLight2D
var _fade := 1.0
var _tall := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_refresh()
	if Engine.is_editor_hint():
		return
	var size := _sprite.texture.get_size() if not _sprite.region_enabled else _sprite.region_rect.size
	_tall = size.y >= 28.0 and get_parent() != null and get_parent().name != "FloorDecor"
	set_process(_tall)
	if casts_shadow:
		_shadow = Sprite2D.new()
		_shadow.texture = _sprite.texture
		_shadow.region_enabled = _sprite.region_enabled
		_shadow.region_rect = _sprite.region_rect
		_shadow.flip_h = flip_h
		_shadow.centered = false
		_shadow.offset = _sprite.offset
		_shadow.show_behind_parent = true
		_shadow.add_to_group(&"sun_shadows")
		add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)
		Lighting.place_shadow(_shadow)
	if light_color.a > 0.0:
		_light = Lighting.make_light(light_color, light_radius)
		_light.position = light_offset
		add_child(_light, false, Node.INTERNAL_MODE_BACK)
		Lighting.place_light(_light)


## Fades while the player stands behind it, so nobody is ever lost behind a
## building, a tree or a wardrobe.
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var p := player.global_position
	var r := Rect2(global_position + _sprite.offset, (_sprite.region_rect.size if _sprite.region_enabled else _sprite.texture.get_size()))
	var behind := p.y < global_position.y - 1.0 and r.grow_individual(-2, 0, -2, 0).has_point(p - Vector2(0, 8))
	var target := BEHIND_ALPHA if behind else 1.0
	if not is_equal_approx(_fade, target):
		_fade = move_toward(_fade, target, delta * 3.5)
		_sprite.modulate.a = _fade


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
