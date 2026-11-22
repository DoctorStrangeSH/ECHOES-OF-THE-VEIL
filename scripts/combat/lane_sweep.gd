class_name LaneSweep
extends Node2D
## The Conductor's "next stop": a lane lights up for `delay` seconds, then a
## ghost tram runs its length. Anyone in the lane while the tram passes is hit.
## Position is the lane's left end; it runs `length` px to the right.

var length := 320.0
var half_height := 14.0
var delay := 1.2
var damage := 2
var run_time := 0.45
var from_right := false
var _t := 0.0
var _hit_done := false


func _enter_tree() -> void:
	add_to_group(&"threat")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= delay and not _hit_done:
		var player := get_tree().get_first_node_in_group(&"player") as Player
		if player != null:
			var local := player.global_position - global_position
			var head := _head_x()
			var near := absf(local.y) <= half_height + 3.0
			var passed := (local.x <= head) if not from_right else (local.x >= head)
			if near and passed and local.x >= -8.0 and local.x <= length + 8.0:
				_hit_done = true
				player.hurtbox.receive(damage, player.global_position + Vector2(-20.0 if not from_right else 20.0, 0), 240.0)
	if _t >= delay + run_time + 0.2:
		queue_free()


func _head_x() -> float:
	var k := clampf((_t - delay) / run_time, 0.0, 1.0)
	return length * k if not from_right else length * (1.0 - k)


func _draw() -> void:
	var r := Rect2(0, -half_height, length, half_height * 2.0)
	if _t < delay:
		var k := clampf(_t / delay, 0.0, 1.0)
		draw_rect(r, Color(1.0, 0.85, 0.3, 0.08 + 0.16 * k))
		draw_rect(r, Color(1.0, 0.8, 0.3, 0.5 + 0.4 * k), false, 1.0)
		var blink := int(_t * 8.0) % 2 == 0
		if blink:
			draw_circle(Vector2(0 if not from_right else length, 0), 3.0, Color(1, 0.4, 0.3))
	else:
		var head := _head_x()
		var tail := maxf(0.0, head - 70.0) if not from_right else minf(length, head + 70.0)
		var body := Rect2(minf(head, tail), -half_height + 2, absf(head - tail), half_height * 2.0 - 4)
		draw_rect(body, Color(0.75, 0.9, 1.0, 0.55))
		draw_rect(body, Color(0.9, 1.0, 1.0, 0.9), false, 1.0)


## A dodge now is perfect: the sweep is reaching `at`.
func is_threatening(at: Vector2) -> bool:
	if _hit_done or _t < delay - 0.22:
		return false
	var local := at - global_position
	if absf(local.y) > half_height + 6.0:
		return false
	var head := _head_x()
	return absf(local.x - head) < 48.0 or _t < delay
