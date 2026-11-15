class_name FloodWater
extends Node2D
## Water that rises over an arena (the Archivist of Floods). Position is the
## arena's top-left corner. `level` is the share of the arena under water,
## measured from the bottom. Islands (local rects: stacks of files, pallets)
## stay dry. In the water the player wades at half speed; deep water hurts.

const DEEP := 0.5
const TICK := 1.4

var size := Vector2(360, 170)
var islands: Array[Rect2] = []
var level := 0.0
var target := 0.0
var rise_speed := 0.6  # share of the arena per second
var _tick := 0.0
var _player_in := false


func set_target(t: float, speed: float = 0.6) -> void:
	target = clampf(t, 0.0, 1.0)
	rise_speed = speed


func water_top() -> float:
	return size.y * (1.0 - level)


func is_wet(local: Vector2) -> bool:
	if local.x < 0.0 or local.x > size.x or local.y > size.y or local.y < water_top():
		return false
	for r in islands:
		if r.has_point(local):
			return false
	return true


func _process(delta: float) -> void:
	level = move_toward(level, target, rise_speed * delta)
	queue_redraw()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var wet := level > 0.02 and is_wet(player.global_position - global_position)
	if wet != _player_in:
		_player_in = wet
		player.wading = 0.5 if wet else 1.0
		if wet:
			Sfx.play(&"step_in", 0.1, -6.0)
	if wet and level >= DEEP:
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			player.hurtbox.receive(1, player.global_position + Vector2(0, -6), 0.0)
	else:
		_tick = TICK * 0.5


func _exit_tree() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null
	if player != null:
		player.wading = 1.0


func _draw() -> void:
	if level <= 0.0:
		return
	var top := water_top()
	var deep := level >= DEEP
	draw_rect(Rect2(0, top, size.x, size.y - top), Color(0.25, 0.45, 0.75, 0.42 if deep else 0.3))
	var t := Time.get_ticks_msec() / 400.0
	for i in int(size.x / 12.0):
		var x := i * 12.0
		var y := top + sin(t + i * 0.7) * 1.5
		draw_line(Vector2(x, y), Vector2(x + 7.0, y), Color(0.85, 0.95, 1.0, 0.7), 1.0)
	for r in islands:
		if r.end.y > top:
			draw_rect(r, Color(0.9, 0.85, 0.7, 0.18))
			draw_rect(r, Color(1.0, 0.95, 0.8, 0.6), false, 1.0)
