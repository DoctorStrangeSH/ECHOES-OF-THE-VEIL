class_name EnemyHealthBar
extends Node2D
## Tiny bar above an enemy, shown for a moment after it takes damage.

var _fraction := 1.0
var _visible_for := 0.0


func show_health(health: int, max_health: int) -> void:
	_fraction = clampf(float(health) / maxf(1.0, float(max_health)), 0.0, 1.0)
	_visible_for = 1.6
	queue_redraw()


func _process(delta: float) -> void:
	if _visible_for > 0.0:
		_visible_for -= delta
		if _visible_for <= 0.0:
			queue_redraw()


func _draw() -> void:
	if _visible_for <= 0.0:
		return
	draw_rect(Rect2(-7, 0, 14, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-6, 1, 12 * _fraction, 1), Color(0.95, 0.4, 0.45))
