@tool
class_name RepairSpot
extends Interactable
## Something broken that a repair job points at. Only visible and usable
## while a job for this spot is active (accepted on the jobs board).

@export var spot_id: StringName = &""

var _t := 0.0


func _init() -> void:
	prompt_key = "PROMPT_REPAIR"
	interaction_priority = 25
	area_size = Vector2(22, 18)


func _ready() -> void:
	super._ready()
	if interaction_id == &"":
		interaction_id = StringName("repair_%s" % spot_id)
	if not Engine.is_editor_hint():
		Livelihood.changed.connect(_sync)
		_sync()


func _sync() -> void:
	var on := Livelihood.active_job_for_spot(spot_id) != &""
	visible = on
	enabled = on
	set_deferred("monitorable", on)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 4.0) * 1.5
	var c := Color(1.0, 0.85, 0.35)
	draw_circle(Vector2(0, -16 + bob), 5.0, Color(0, 0, 0, 0.5))
	draw_line(Vector2(-3, -13 + bob), Vector2(3, -19 + bob), c, 2.0)
	draw_circle(Vector2(3, -19 + bob), 2.0, c)


func _on_interact(_actor: Node) -> void:
	var job := Livelihood.active_job_for_spot(spot_id)
	if job != &"":
		EventHub.screen_requested.emit("repair:%s" % job)
