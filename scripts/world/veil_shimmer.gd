extends Node
## Makes its parent CanvasItem subtly "wrong": a slow cold tint pulse with a
## rare flicker. Used for Veil-touched objects such as the impossible door.

@export var tint: Color = Color(0.75, 0.9, 1.15)
@export var period: float = 2.6
@export var flicker_chance_per_second: float = 0.12

var _t := 0.0
var _target: CanvasItem


func _ready() -> void:
	_target = get_parent() as CanvasItem


func _process(delta: float) -> void:
	if _target == null:
		return
	_t += delta
	var k := (sin(_t * TAU / period) + 1.0) * 0.5
	var color := Color.WHITE.lerp(tint, k)
	if randf() < flicker_chance_per_second * delta:
		color.a = 0.55
	_target.modulate = color
