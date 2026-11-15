class_name EditGrid
extends Node2D
## The arena a Reviser rewrites: a grid of cells over the floor. Cells are
## marked (pale outline, `delay` seconds), then "edited" for `live` seconds:
## standing in an edited cell hurts (1, then every TICK). Position is the
## arena's top-left corner.

const TICK := 0.8

var size := Vector2(320, 160)
var cols := 4
var rows := 3
## cell -> {"t": seconds left, "phase": "marked" | "live"}
var _cells: Dictionary = {}
var _tick := 0.0
var live_time := 2.2


func cell_size() -> Vector2:
	return Vector2(size.x / cols, size.y / rows)


func cell_at(local: Vector2) -> Vector2i:
	if local.x < 0.0 or local.y < 0.0 or local.x >= size.x or local.y >= size.y:
		return Vector2i(-1, -1)
	var cs := cell_size()
	return Vector2i(int(local.x / cs.x), int(local.y / cs.y))


func mark(cells: Array[Vector2i], delay: float, live: float = 2.2) -> void:
	live_time = live
	for c in cells:
		_cells[c] = {"t": delay, "phase": "marked"}


func is_live(c: Vector2i) -> bool:
	return _cells.has(c) and _cells[c]["phase"] == "live"


func busy() -> bool:
	return not _cells.is_empty()


func clear_all() -> void:
	_cells.clear()


func _process(delta: float) -> void:
	for c: Vector2i in _cells.keys():
		var st: Dictionary = _cells[c]
		st["t"] -= delta
		if st["t"] <= 0.0:
			if st["phase"] == "marked":
				st["phase"] = "live"
				st["t"] = live_time
			else:
				_cells.erase(c)
	queue_redraw()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if is_live(cell_at(player.global_position - global_position)):
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			player.hurtbox.receive(1, player.global_position + Vector2(0, -6), 60.0)
	else:
		_tick = 0.0


func _draw() -> void:
	var cs := cell_size()
	var t := Time.get_ticks_msec() / 1000.0
	for c: Vector2i in _cells:
		var r := Rect2(Vector2(c) * cs, cs).grow(-1.0)
		if _cells[c]["phase"] == "marked":
			var a := 0.25 + 0.25 * sin(t * 14.0)
			draw_rect(r, Color(0.9, 0.95, 1.0, 0.08))
			draw_rect(r, Color(0.9, 0.95, 1.0, a + 0.3), false, 1.0)
		else:
			draw_rect(r, Color(0.95, 0.35, 0.5, 0.32))
			for i in 3:  # struck-through lines: this part of the night has been edited
				var y := r.position.y + r.size.y * (i + 1) / 4.0
				draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color(1, 0.8, 0.85, 0.7), 1.0)
