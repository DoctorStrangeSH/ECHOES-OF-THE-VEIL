class_name StampMarker
extends Node2D
## Telegraphed area attack: a ring fills up over `delay` seconds, then the
## stamp lands and hurts the player if they are still inside `radius`.

var radius := 20.0
var delay := 0.9
var damage := 1
var _t := 0.0
var _landed := false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _landed and _t >= delay:
		_landed = true
		_land()
	if _t >= delay + 0.25:
		queue_free()


func _land() -> void:
	Sfx.play(&"stamp", 0.08)
	EventHub.camera_shake_requested.emit(3.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= radius + 4.0:
		player.hurtbox.receive(damage, global_position, 170.0)


func _draw() -> void:
	if not _landed:
		var k := clampf(_t / delay, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.2, 0.25, 0.12 + 0.18 * k))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0.35, 0.35, 0.9), 1.0)
		draw_circle(Vector2.ZERO, radius * k, Color(1, 0.3, 0.3, 0.25))
	else:
		var a := 1.0 - clampf((_t - delay) / 0.25, 0.0, 1.0)
		draw_rect(Rect2(-radius * 0.7, -radius * 0.45, radius * 1.4, radius * 0.9), Color(0.85, 0.1, 0.15, 0.8 * a))
		draw_rect(Rect2(-radius * 0.7, -radius * 0.45, radius * 1.4, radius * 0.9), Color(0.2, 0, 0, a), false, 1.0)
