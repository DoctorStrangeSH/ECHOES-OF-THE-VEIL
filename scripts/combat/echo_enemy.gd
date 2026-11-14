class_name EchoEnemy
extends CharacterBody2D
## "Hollow" — a fragment of an erased resident, looping one gesture.
## Readable state machine: drift -> chase -> wind-up (clear telegraph) ->
## lunge -> recover. Takes knockback and flinches when hit. Stays defeated
## once beaten (flag "defeated.<enemy_id>").

enum State { DRIFT, CHASE, WINDUP, LUNGE, RECOVER, HURT, DEAD }

const SHEET := "modern_exteriors/Modern_Exteriors_16x16/Character_Generator_Addons_16x16/Body_10_Ghost_White_16x16.png"
const BASE_TINT := Color(0.75, 0.95, 1.0, 0.82)
const WINDUP_TINT := Color(1.6, 1.6, 1.9, 1.0)

@export var enemy_id: StringName = &""
@export var max_health: int = 3
@export var move_speed: float = 34.0
@export var chase_speed: float = 52.0
@export var lunge_speed: float = 190.0
@export var sight_range: float = 110.0
@export var attack_range: float = 26.0
@export var windup_time: float = 0.55
@export var lunge_time: float = 0.2
@export var recover_time: float = 0.6

var state: State = State.DRIFT
var health: Health
var _timer := 0.0
var _lunge_dir := Vector2.ZERO
var _drift_dir := Vector2.ZERO
var _knockback := Vector2.ZERO
var _dir: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN
var _hit_this_lunge := false
var _hitbox: Hitbox
var _home := Vector2.ZERO

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if enemy_id != &"" and GameState.has_flag(StringName("defeated.%s" % enemy_id)):
		queue_free()
		return
	add_to_group(&"echo_enemy")
	collision_layer = 0
	collision_mask = 1  # world only: echoes pass through the player's body
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	var look := CharacterAppearance.new()
	look.custom_sheet = SHEET
	look.placeholder_color = Color(0.7, 0.9, 1.0)
	sprite.appearance = look
	sprite.modulate = BASE_TINT

	health = Health.new()
	health.max_health = max_health
	health.invulnerability_time = 0.25
	add_child(health)
	health.died.connect(_on_died)

	var hurt := Hurtbox.new()
	hurt.team = &"enemy"
	hurt.health = health
	hurt.add_child(_rect_shape(Vector2(12, 18), Vector2(0, -9)))
	add_child(hurt)
	hurt.hit.connect(_on_hit)

	_hitbox = Hitbox.new()
	_hitbox.team = &"enemy"
	_hitbox.damage = 1
	_hitbox.knockback = 160.0
	_hitbox.add_child(_rect_shape(Vector2(14, 14), Vector2(0, -8)))
	add_child(_hitbox)
	_pick_drift()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var to_player := (player.global_position - global_position) if player != null else Vector2.ZERO
	var dist := to_player.length()
	_timer -= delta
	var desired := Vector2.ZERO
	var blocked := GameState.is_player_locked() or SceneFlow.is_transitioning

	match state:
		State.DRIFT:
			desired = _drift_dir * move_speed
			if _timer <= 0.0:
				_pick_drift()
			if player != null and dist < sight_range and not blocked:
				state = State.CHASE
		State.CHASE:
			if player == null or dist > sight_range * 1.4 or blocked:
				state = State.DRIFT
			elif dist < attack_range:
				_start_windup(to_player)
			else:
				desired = to_player.normalized() * chase_speed
		State.WINDUP:
			# Telegraph: freeze and glow. The player has time to step aside.
			var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
			sprite.modulate = BASE_TINT.lerp(WINDUP_TINT, k)
			if _timer <= 0.0:
				state = State.LUNGE
				_timer = lunge_time
				_hit_this_lunge = false
				sprite.modulate = BASE_TINT
				sprite.play(&"punch", _dir, true)
		State.LUNGE:
			desired = _lunge_dir * lunge_speed
			if not _hit_this_lunge and _hitbox.strike() > 0:
				_hit_this_lunge = true
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_time
		State.RECOVER, State.HURT:
			if _timer <= 0.0:
				state = State.CHASE
	velocity = desired
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	if state in [State.DRIFT, State.CHASE]:
		if desired != Vector2.ZERO:
			_dir = LayeredCharacterSprite.dir_from_vector(desired, _dir)
		sprite.play(&"walk" if desired != Vector2.ZERO else &"idle", _dir)


func _start_windup(to_player: Vector2) -> void:
	state = State.WINDUP
	_timer = windup_time
	_lunge_dir = to_player.normalized()
	_dir = LayeredCharacterSprite.dir_from_vector(to_player, _dir)
	_hitbox.position = _lunge_dir * 10.0
	sprite.play(&"idle", _dir)


func _pick_drift() -> void:
	_timer = randf_range(1.0, 2.2)
	var back_home := (_home - global_position)
	if back_home.length() > 48.0:
		_drift_dir = back_home.normalized()
	else:
		_drift_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO


func _on_hit(_damage: int, from_position: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	_knockback = (global_position - from_position).normalized() * knockback
	state = State.HURT
	_timer = 0.3
	sprite.modulate = BASE_TINT
	sprite.play(&"hurt", _dir, true)


func _on_died() -> void:
	state = State.DEAD
	collision_mask = 0
	if enemy_id != &"":
		GameState.set_flag(StringName("defeated.%s" % enemy_id), true)
	remove_from_group(&"echo_enemy")
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_property(self, "position:y", position.y - 8.0, 0.6)
	t.chain().tween_callback(queue_free)


static func _rect_shape(size: Vector2, offset: Vector2) -> CollisionShape2D:
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	s.shape = r
	s.position = offset
	return s
