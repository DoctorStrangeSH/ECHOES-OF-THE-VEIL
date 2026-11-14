class_name Player
extends CharacterBody2D
## Player controller: 8-direction movement with normalized diagonals,
## 4-direction sprite facing, and interaction with the best target in reach.
## Owner: player. Manual test: docs/technical/m1-test-plan.md.

const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_NPC := 1 << 3

@export var walk_speed: float = 72.0
@export var sprint_speed: float = 118.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
## Distance in front of the feet where the interaction sensor sits.
@export var reach: float = 10.0

var facing: Vector2 = Vector2.DOWN
var _focused: Interactable = null
var _dir: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN

@onready var sprite: LayeredCharacterSprite = $Sprite
@onready var sensor: Area2D = $InteractionSensor
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_NPC
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sensor.collision_layer = 0
	sensor.collision_mask = Interactable.LAYER_INTERACTABLE
	sprite.appearance = GameState.player_appearance
	_face(facing)
	sprite.play(&"idle", _dir)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not _is_blocked():
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# get_vector already clamps diagonals to length 1 (no faster diagonal movement).
	var speed := sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, acceleration * delta)
		_face(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	sprite.play(&"walk" if input != Vector2.ZERO else &"idle", _dir)
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not _is_blocked():
		if _focused != null and is_instance_valid(_focused):
			get_viewport().set_input_as_handled()
			_focused.interact(self)


## Places the player (used by Location when spawning / loading).
func place(at: Vector2, face_dir: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_face(face_dir)
	sprite.play(&"idle", _dir)
	camera.reset_smoothing()


func set_camera_limits(rect: Rect2i) -> void:
	# Rooms smaller than the screen are centred instead of pinned to a corner.
	var view := Vector2i(get_viewport_rect().size)
	if rect.size.x < view.x:
		rect = rect.grow_individual((view.x - rect.size.x) / 2, 0, (view.x - rect.size.x + 1) / 2, 0)
	if rect.size.y < view.y:
		rect = rect.grow_individual(0, (view.y - rect.size.y) / 2, 0, (view.y - rect.size.y + 1) / 2)
	camera.limit_left = rect.position.x
	camera.limit_top = rect.position.y
	camera.limit_right = rect.end.x
	camera.limit_bottom = rect.end.y


func _face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	_dir = LayeredCharacterSprite.dir_from_vector(dir, _dir)
	sensor.position = Vector2(facing.x, facing.y) * reach + Vector2(0, -4)


func _is_blocked() -> bool:
	return GameState.is_player_locked() or SceneFlow.is_transitioning or get_tree().paused


func _update_focus() -> void:
	var best: Interactable = null
	if not _is_blocked():
		var best_score := -INF
		for area in sensor.get_overlapping_areas():
			var it := area as Interactable
			if it == null or not it.can_interact(self):
				continue
			var dist := it.global_position.distance_to(sensor.global_position)
			var score := it.priority * 1000.0 - dist
			if score > best_score:
				best_score = score
				best = it
	if best != _focused:
		_focused = best
		EventHub.interaction_focus_changed.emit(best.get_prompt() if best != null else "")
