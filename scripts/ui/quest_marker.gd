class_name QuestMarker
extends Control
## On-screen marker for the pinned case's current step ("detailed" guidance):
## a bobbing arrow over the target, or an arrow at the screen edge pointing
## towards it (or towards the next door on the way).

const EDGE := 14.0
var target: Node2D = null
var _t := 0.0
var _refresh := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.3
		target = null
		if GameState.is_playing and GameSettings.shows_guide() and Journal.pinned != &"":
			target = QuestGuide.world_target(SceneFlow.current_location, QuestGuide.target(Journal.pinned))
	queue_redraw()


func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if DialogueService.is_active:
		return
	var p := target.get_global_transform_with_canvas().origin + Vector2(0, -22)
	var r := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-EDGE)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var col := Color(1.0, 0.85, 0.35, 0.95)
	if r.has_point(p):
		var y := sin(_t * 5.0) * 2.0
		var tip := p + Vector2(0, 6 + y)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-5, -7), tip + Vector2(5, -7)]), col)
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-5, -7), tip + Vector2(5, -7), tip]), Color(0, 0, 0, 0.8), 1.0)
		return
	var c := r.get_center()
	var dir := (p - c).normalized()
	var s := minf(absf(r.size.x * 0.5 / maxf(0.001, absf(dir.x))), absf(r.size.y * 0.5 / maxf(0.001, absf(dir.y))))
	var at := c + dir * s
	var side := dir.orthogonal()
	var tip2 := at + dir * 6.0
	var pts := PackedVector2Array([tip2, at - dir * 4.0 + side * 5.0, at - dir * 4.0 - side * 5.0])
	draw_colored_polygon(pts, Color(col, 0.6 + 0.35 * absf(sin(_t * 4.0))))
	pts.append(tip2)
	draw_polyline(pts, Color(0, 0, 0, 0.8), 1.0)
