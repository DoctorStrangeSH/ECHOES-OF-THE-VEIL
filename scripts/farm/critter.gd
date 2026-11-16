@tool
class_name Critter
extends Node2D
## A farm animal that ambles about inside its pen (R5): walks a few steps,
## stops, looks around. Pure decoration — no collision. Sheets from the
## Modern Farm pack: row 0 idle (left, up, right, down), row 1 walking,
## six frames per direction in the same order.

@export var texture_path := ""
@export var frame_size := 16
@export var pen := Rect2(-24, -16, 48, 32)  # relative to the start position
@export var speed := 10.0
@export var seed_offset := 0
## A hen of the coop: shown while the farm keeps at least this many hens
## (before you own it, Hugh keeps two). 0 = always there.
@export var hen := 0

var _tex: Texture2D
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _dir := 3  # 0 left, 1 up, 2 right, 3 down
var _rest := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home = position
	_target = position
	_rng.seed = hash([name, seed_offset])
	_rest = _rng.randf_range(0.5, 3.0)
	if not Engine.is_editor_hint():
		_tex = AssetLibrary.load_texture(texture_path)
		if hen > 0:
			Farm.changed.connect(_sync_hen)
			EventHub.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: _sync_hen())
			_sync_hen()


func _sync_hen() -> void:
	visible = Farm.hens >= hen if Farm.owned() else hen <= 2


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _rest > 0.0:
		_rest -= delta
		if _rest <= 0.0:
			_target = _home + Vector2(_rng.randf_range(pen.position.x, pen.end.x), _rng.randf_range(pen.position.y, pen.end.y))
	else:
		var d := _target - position
		if d.length() < 1.0:
			_rest = _rng.randf_range(1.5, 5.0)
		else:
			position += d.normalized() * minf(d.length(), speed * delta)
			if absf(d.x) > absf(d.y):
				_dir = 2 if d.x > 0 else 0
			else:
				_dir = 3 if d.y > 0 else 1
	queue_redraw()


func _draw() -> void:
	var s := float(frame_size)
	if _tex == null:
		draw_circle(Vector2(0, -s * 0.3), s * 0.3, Color(0.9, 0.9, 0.85))
		return
	var src: Rect2
	if _rest > 0.0:
		src = Rect2(_dir * s, 0, s, s)
	else:
		src = Rect2((_dir * 6 + int(_t * 8.0) % 6) * s, s, s, s)
	draw_texture_rect_region(_tex, Rect2(-s / 2, -s, s, s), src)
