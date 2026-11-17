class_name FocusMark
extends Node2D
## The pointer the player sees over the thing they would use with E.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 5.0) * 1.5
	var pts := PackedVector2Array([Vector2(-3.5, -4 + bob), Vector2(3.5, -4 + bob), Vector2(0, 0.5 + bob)])
	draw_colored_polygon(pts, Color(0.1, 0.1, 0.12, 0.8))
	var inner := PackedVector2Array([Vector2(-2.5, -3.4 + bob), Vector2(2.5, -3.4 + bob), Vector2(0, -0.4 + bob)])
	draw_colored_polygon(inner, Color(1.0, 0.92, 0.55))
