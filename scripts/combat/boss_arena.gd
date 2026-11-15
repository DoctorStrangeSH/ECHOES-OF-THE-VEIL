class_name BossArena
extends Area2D
## Wakes the boss when the player steps in and raises the gate (a flag shown
## by ConditionalVisibility props). Re-entering the location resets the fight.

@export var boss_path: NodePath
@export var engaged_flag: StringName = &"boss.census_taker.engaged"
@export var area_size: Vector2 = Vector2(200, 160)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = area_size
	s.shape = r
	add_child(s)
	GameState.clear_flag(engaged_flag)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player") or GameState.has_flag(engaged_flag):
		return
	# Any boss with engage() and a Health named `health` (CensusTaker, Conductor...).
	var boss := get_node_or_null(boss_path)
	if boss == null or not is_instance_valid(boss) or not boss.has_method(&"engage"):
		return
	GameState.set_flag(engaged_flag, true)
	boss.call(&"engage")
	(boss.get(&"health") as Health).died.connect(func() -> void: GameState.clear_flag(engaged_flag))
