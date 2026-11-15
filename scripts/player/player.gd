class_name Player
extends CharacterBody2D
## Player controller: 8-direction movement with normalized diagonals,
## 4-direction sprite facing, interaction with the best target in reach, and
## (only in Veil locations) a short melee strike with knockback and i-frames.
## Owner: player. Manual tests: docs/technical/m1-test-plan.md, m2-test-plan.md.

const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_NPC := 1 << 3
const MAX_HEALTH := 5
const COURIER_SPRINT_BONUS := 1.12

@export var walk_speed: float = 72.0
@export var sprint_speed: float = 118.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
## Distance in front of the feet where the interaction sensor sits.
@export var reach: float = 10.0
@export var attack_cooldown: float = 0.38
## Delay from pressing attack to the impact frame.
@export var attack_impact_delay: float = 0.1

var facing: Vector2 = Vector2.DOWN
var combat_enabled := false
var _focused: Interactable = null
var _dir: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN
var _action_anim_time := 0.0  # while > 0, punch/hurt animation owns the sprite
var _attack_ready_at := 0.0
var _knockback := Vector2.ZERO
var _fainting := false

var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox

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
	if GameState.background == &"courier":
		sprint_speed *= COURIER_SPRINT_BONUS
	_build_combat()
	_face(facing)
	sprite.play(&"idle", _dir)
	EventHub.player_heal_requested.connect(_on_heal_requested)


func _build_combat() -> void:
	health = Health.new()
	health.max_health = MAX_HEALTH
	health.invulnerability_time = 0.9
	add_child(health)
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.team = &"player"
	hurtbox.health = health
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(10, 18)
	hs.shape = hr
	hs.position = Vector2(0, -9)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.hit.connect(_on_hit)

	hitbox = Hitbox.new()
	hitbox.team = &"player"
	hitbox.damage = 1
	var ks := CollisionShape2D.new()
	var kr := RectangleShape2D.new()
	kr.size = Vector2(16, 16)
	ks.shape = kr
	hitbox.add_child(ks)
	add_child(hitbox)
	EventHub.player_health_changed.emit(MAX_HEALTH if combat_enabled else 0, MAX_HEALTH if combat_enabled else 0)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not _is_blocked():
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# get_vector already clamps diagonals to length 1 (no faster diagonal movement).
	var speed := sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	if _action_anim_time > 0.0:
		_action_anim_time -= delta
		speed *= 0.35  # committed to the swing
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, acceleration * delta)
		if _action_anim_time <= 0.0:
			_face(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if _action_anim_time <= 0.0:
		sprite.play(&"walk" if input != Vector2.ZERO else &"idle", _dir)
	_update_blink()
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _is_blocked():
		return
	if event.is_action_pressed(&"interact"):
		if _focused != null and is_instance_valid(_focused):
			get_viewport().set_input_as_handled()
			_focused.interact(self)
	elif event.is_action_pressed(&"attack") and combat_enabled:
		get_viewport().set_input_as_handled()
		_attack()


func _attack() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _attack_ready_at:
		return
	_attack_ready_at = now + attack_cooldown
	_action_anim_time = attack_cooldown * 0.8
	sprite.play(&"punch", _dir, true)
	await get_tree().create_timer(attack_impact_delay, false).timeout
	if is_inside_tree() and not _fainting:
		hitbox.strike()


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
	if hitbox != null:
		hitbox.position = Vector2(facing.x, facing.y) * 12.0 + Vector2(0, -10)


func _is_blocked() -> bool:
	return _fainting or GameState.is_player_locked() or SceneFlow.is_transitioning or get_tree().paused


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


# --- Combat reactions ----------------------------------------------------------

func _on_hit(_damage: int, from_position: Vector2, knockback: float) -> void:
	var away := (global_position - from_position).normalized()
	if away == Vector2.ZERO:
		away = -facing
	_knockback = away * knockback
	_action_anim_time = 0.3
	sprite.play(&"hurt", _dir, true)


func _on_health_changed(h: int, m: int) -> void:
	if combat_enabled:
		EventHub.player_health_changed.emit(h, m)


func _update_blink() -> void:
	if health != null and health.is_invulnerable() and not health.is_dead():
		sprite.visible = int(Time.get_ticks_msec() / 80) % 2 == 0
	else:
		sprite.visible = true


func _on_heal_requested() -> void:
	health.heal_full()


## Fail-forward: fainting in the Veil returns the player to their room.
func _on_died() -> void:
	_fainting = true
	GameState.set_flag(&"veil.fainted_once", true)
	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.8)
	await t.finished
	GameState.set_flag(&"veil.just_fainted", true)
	SceneFlow.travel(&"rented_room", &"bed")
