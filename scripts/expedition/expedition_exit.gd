class_name ExpeditionExit
extends Interactable
## The way on from an expedition room: a tear in the Veil that opens once the
## room is clear. In the first room a second, always-open tear leads home.

@export var leads_home := false
var _t := 0.0


func _init() -> void:
	prompt_key = "PROMPT_EXP_NEXT"
	interaction_priority = 30
	area_size = Vector2(28, 24)
	interaction_id = &"expedition_exit"


func can_interact(_actor: Node) -> bool:
	return enabled and not SceneFlow.is_transitioning


func _on_interact(_actor: Node) -> void:
	Sfx.play(&"door")
	if leads_home:
		Expedition.abandon()
	else:
		Expedition.advance()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var a := 0.9 if enabled else 0.25
	var col := Color(0.95, 0.75, 0.6, a) if leads_home else Color(0.7, 0.85, 1.0, a)
	var wob := sin(_t * 4.0) * 1.5
	draw_rect(Rect2(-9, -22 + wob * 0.3, 18, 22), Color(col, a * 0.25))
	draw_rect(Rect2(-9, -22 + wob * 0.3, 18, 22), col, false, 1.0)
	if enabled:
		for i in 3:
			var y := -20.0 + fmod(_t * 12.0 + i * 7.0, 20.0)
			draw_line(Vector2(-6, y), Vector2(6, y), Color(col, 0.5), 1.0)
