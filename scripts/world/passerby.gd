class_name Passerby
extends Node2D
## A townsperson going about their day (R1c): walks a route, stops now and
## then, and will say a line or two if spoken to. No collision: they step
## around you the way people in a hurry do. Spawned by Crowd.

signal left

const SPEED_RANGE := Vector2(20.0, 30.0)
const FADE := 0.4

var route: PackedVector2Array = []
var crowd: Crowd
var _i := 1
var _speed := 24.0
var _pause := 0.0
var _next_pause := 6.0
var _talked := 0
var _rng := RandomNumberGenerator.new()
var _sprite: LayeredCharacterSprite
var _bubble: Label
var _leaving := false


func setup(points: PackedVector2Array, start_index: int, start_pos: Vector2, appearance: CharacterAppearance, seed_value: int) -> void:
	route = points
	_i = start_index
	position = start_pos
	_rng.seed = seed_value
	_speed = _rng.randf_range(SPEED_RANGE.x, SPEED_RANGE.y)
	_next_pause = _rng.randf_range(4.0, 12.0)
	_sprite = LayeredCharacterSprite.new()
	_sprite.appearance = appearance
	add_child(_sprite)
	var talk := PasserbyTalk.new()
	talk.passerby = self
	add_child(talk)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)


func _process(delta: float) -> void:
	if _leaving or route.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0 and _bubble != null:
			_bubble.queue_free()
			_bubble = null
		return
	var target := route[_i]
	var d := target - position
	var step := _speed * delta
	if d.length() <= step:
		position = target
		_i += 1
		if _i >= route.size():
			_leave()
			return
	else:
		position += d.normalized() * step
		_sprite.play(&"walk", LayeredCharacterSprite.dir_from_vector(d))
	_next_pause -= delta
	if _next_pause <= 0.0:
		_next_pause = _rng.randf_range(6.0, 14.0)
		_pause = _rng.randf_range(1.0, 3.5)
		_sprite.play(&"idle", [LayeredCharacterSprite.Dir.DOWN, LayeredCharacterSprite.Dir.UP, LayeredCharacterSprite.Dir.LEFT, LayeredCharacterSprite.Dir.RIGHT][_rng.randi() % 4])


## Spoken to: stop, turn, say something.
func speak(actor: Node2D) -> void:
	_pause = 4.0
	if actor != null:
		_sprite.play(&"idle", LayeredCharacterSprite.dir_from_vector(actor.global_position - global_position))
	var line := crowd.line_for(_rng) if _talked == 0 and crowd != null else "CHATTER_BUSY"
	_talked += 1
	if _bubble != null:
		_bubble.queue_free()
	_bubble = Label.new()
	_bubble.text = tr(line)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.custom_minimum_size = Vector2(150, 0)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_theme_font_size_override("font_size", 8)
	_bubble.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	_bubble.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	_bubble.add_theme_constant_override("outline_size", 4)
	_bubble.z_index = 20
	add_child(_bubble)
	await get_tree().process_frame
	if is_instance_valid(_bubble):
		_bubble.position = Vector2(-75, -36 - _bubble.size.y)


func _leave() -> void:
	_leaving = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(func() -> void:
		left.emit()
		queue_free())
