class_name FlashPulse
extends Node2D
## Expanding ring of lantern light. Purely visual; the caller applies stuns.

var radius := 48.0
var _t := 0.0
const DURATION := 0.35


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var r := lerpf(6.0, radius, 1.0 - pow(1.0 - k, 3.0))
	var a := 1.0 - k
	draw_circle(Vector2(0, -10), r, Color(1.0, 0.95, 0.7, 0.18 * a))
	draw_arc(Vector2(0, -10), r, 0, TAU, 48, Color(1.0, 0.92, 0.6, 0.9 * a), 2.0)
