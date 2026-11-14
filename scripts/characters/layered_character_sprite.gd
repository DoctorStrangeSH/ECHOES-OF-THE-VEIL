@tool
class_name LayeredCharacterSprite
extends Node2D
## Draws a LimeZu Character Generator character from stacked layer sheets
## and plays idle/walk animations in four directions.
##
## Sheet layout (16x16 packs): frames are 16x32 px, rows are 32 px apart.
## Row 1 = idle, 2 = walk, 14 = punch (6 frames/dir), 19 = hurt (3 frames/dir).
## Frames are grouped per direction in the order right, up, left, down.
## The node origin is the character's feet (ground anchor for y-sorting).

enum Dir { RIGHT = 0, UP = 1, LEFT = 2, DOWN = 3 }

## Emitted when a non-looping animation reaches its last frame.
signal animation_finished(anim: StringName)

const FRAME_SIZE := Vector2i(16, 32)
const ANIMATIONS := {
	&"idle": {"row": 1, "frames": 6, "fps": 8.0, "loop": true},
	&"walk": {"row": 2, "frames": 6, "fps": 10.0, "loop": true},
	&"punch": {"row": 14, "frames": 6, "fps": 16.0, "loop": false},
	&"hurt": {"row": 19, "frames": 3, "fps": 10.0, "loop": false},
}

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_inside_tree():
			_rebuild()

var animation: StringName = &"idle"
var direction: Dir = Dir.DOWN
var _frame := 0
var _elapsed := 0.0
var _layers: Array[Sprite2D] = []
var _uses_placeholder := false


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _uses_placeholder or _layers.is_empty():
		return
	var spec: Dictionary = ANIMATIONS[animation]
	if not spec["loop"] and _frame >= int(spec["frames"]) - 1:
		return
	_elapsed += delta
	var step := 1.0 / float(spec["fps"])
	if _elapsed >= step:
		_elapsed = fmod(_elapsed, step)
		_frame += 1
		if _frame >= int(spec["frames"]):
			_frame = 0
		_apply_frame()
		if not spec["loop"] and _frame == int(spec["frames"]) - 1:
			animation_finished.emit(animation)


func play(anim: StringName, dir: Dir, restart := false) -> void:
	if not ANIMATIONS.has(anim):
		push_warning("Unknown animation %s" % anim)
		return
	if anim == animation and dir == direction and not restart:
		return
	if anim != animation or restart:
		_frame = 0
		_elapsed = 0.0
	animation = anim
	direction = dir
	_apply_frame()


## Maps any movement vector to one of the four sheet directions.
static func dir_from_vector(v: Vector2, fallback: Dir = Dir.DOWN) -> Dir:
	if v.length_squared() < 0.0001:
		return fallback
	if absf(v.x) > absf(v.y) + 0.01:
		return Dir.RIGHT if v.x > 0.0 else Dir.LEFT
	return Dir.DOWN if v.y > 0.0 else Dir.UP


func _rebuild() -> void:
	for s in _layers:
		s.queue_free()
	_layers.clear()
	var look := appearance if appearance != null else CharacterAppearance.default_player()
	for path in look.layer_paths():
		var tex := AssetLibrary.load_texture(path)
		if tex == null:
			continue
		_layers.append(_make_sprite(tex, true))
	_uses_placeholder = _layers.is_empty()
	if _uses_placeholder:
		_layers.append(_make_sprite(_placeholder_texture(look.placeholder_color), false))
	_apply_frame()


func _make_sprite(tex: Texture2D, sheet: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-FRAME_SIZE.x / 2.0, -FRAME_SIZE.y)
	s.region_enabled = sheet
	add_child(s)
	return s


func _apply_frame() -> void:
	if _uses_placeholder:
		return
	var spec: Dictionary = ANIMATIONS[animation]
	var row: int = spec["row"]
	var col := int(direction) * int(spec["frames"]) + _frame
	var rect := Rect2(col * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	for s in _layers:
		s.region_rect = rect


func _placeholder_texture(color: Color) -> Texture2D:
	var img := Image.create_empty(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	var outline := color.darkened(0.6)
	var skin := Color(0.96, 0.8, 0.66)
	for y in FRAME_SIZE.y:
		for x in FRAME_SIZE.x:
			var head := Vector2(x - 7.5, y - 13.0).length() <= 5.5
			var torso := x >= 4 and x <= 11 and y >= 18 and y <= 29
			var feet := (x >= 4 and x <= 6 or x >= 9 and x <= 11) and y >= 30
			if head:
				img.set_pixel(x, y, skin)
			elif torso:
				img.set_pixel(x, y, color)
			elif feet:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)
