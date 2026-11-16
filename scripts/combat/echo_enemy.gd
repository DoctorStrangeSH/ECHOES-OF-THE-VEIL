class_name EchoEnemy
extends CharacterBody2D
## The Hollow family — fragments of erased residents, looping one gesture.
## One script; variants are data in data/enemies/enemies*.json (set `variant`):
##   hollow  - steady melee lunger (3 HP)
##   clinger - small, fast, fragile, short wind-up (1 HP)
##   wailer  - keeps its distance and throws memory shards (2 HP)
## Readable state machine: drift -> chase -> wind-up (clear glow telegraph) ->
## lunge/shoot -> recover. Hit flash, knockback, stun from the Lantern Flash.
## Stays defeated once beaten (flag "defeated.<enemy_id>"). Drops Resonance.

enum State { DRIFT, CHASE, WINDUP, LUNGE, RECOVER, HURT, STUNNED, DEAD }

const SHEET := "modern_exteriors/Modern_Exteriors_16x16/Character_Generator_Addons_16x16/Body_10_Ghost_White_16x16.png"
const WINDUP_TINT := Color(1.6, 1.6, 1.9, 1.0)
const SHARD_SCENE := preload("res://scenes/combat/memory_shard.tscn")
const MOTE_SCENE := preload("res://scenes/combat/resonance_mote.tscn")

const VARIANTS_PATH := "res://data/enemies/enemies"

static var _variants: Dictionary = {}

@export var enemy_id: StringName = &""
## Id from data/enemies/enemies*.json.
@export var variant: String = "hollow"
@export var sight_range: float = 120.0
@export var lunge_time: float = 0.2
@export var recover_time: float = 0.6
## Chance to drop a consumable on defeat.
@export var item_drop_chance: float = 0.12

var state: State = State.DRIFT
var health: Health
var max_health := 3
var move_speed := 34.0
var chase_speed := 52.0
var lunge_speed := 190.0
var windup_time := 0.55
var attack_range := 26.0
var ranged := false
var resonance_drop := 2
var base_tint := Color.WHITE
var _slow_until := 0.0
var contact_damage := 1
var sheet := SHEET

var _timer := 0.0
var _lunge_dir := Vector2.ZERO
var _drift_dir := Vector2.ZERO
var _knockback := Vector2.ZERO
var _dir: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN
var _hit_this_lunge := false
var _hitbox: Hitbox
var _home := Vector2.ZERO
var _flash := 0.0
var _bar: Node2D

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if enemy_id != &"" and GameState.has_flag(StringName("defeated.%s" % enemy_id)):
		queue_free()
		return
	_apply_variant()
	add_to_group(&"echo_enemy")
	collision_layer = 0
	collision_mask = 1  # world only: echoes pass through the player's body
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	var look := CharacterAppearance.new()
	look.custom_sheet = sheet
	look.placeholder_color = Color(0.7, 0.9, 1.0)
	sprite.appearance = look
	sprite.modulate = base_tint

	health = Health.new()
	health.max_health = max_health
	health.invulnerability_time = 0.2
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
	_hitbox.damage = contact_damage
	_hitbox.knockback = 160.0
	_hitbox.add_child(_rect_shape(Vector2(14, 14), Vector2(0, -8)))
	add_child(_hitbox)

	_bar = EnemyHealthBar.new()
	_bar.position = Vector2(0, -36 * sprite.scale.y)
	add_child(_bar)
	_pick_drift()


static func variants() -> Dictionary:
	if _variants.is_empty():
		_variants = DataFiles.defs(VARIANTS_PATH)
	return _variants


func _apply_variant() -> void:
	var all := variants()
	if not all.has(StringName(variant)):
		push_error("EchoEnemy %s: unknown variant '%s'" % [enemy_id, variant])
	var v: Dictionary = all.get(StringName(variant), all.get(&"hollow", {}))
	max_health = GameState.enemy_health(int(v["max_health"]))
	move_speed = float(v["move_speed"])
	chase_speed = float(v["chase_speed"])
	lunge_speed = float(v["lunge_speed"])
	windup_time = float(v["windup_time"])
	attack_range = float(v["attack_range"])
	ranged = bool(v.get("ranged", false))
	resonance_drop = int(v["resonance"])
	var t: Array = v.get("tint", [1, 1, 1, 1])
	base_tint = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))
	contact_damage = int(v.get("damage", 1))
	sheet = String(v.get("sheet", SHEET))
	item_drop_chance = float(v.get("drop_chance", item_drop_chance))
	sprite.scale = Vector2.ONE * float(v["scale"])


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
			if player == null or dist > sight_range * 1.5 or blocked:
				state = State.DRIFT
			elif ranged:
				# Keep a comfortable distance, then shoot.
				if dist < attack_range * 0.55:
					desired = -to_player.normalized() * chase_speed
				elif dist > attack_range:
					desired = to_player.normalized() * chase_speed
				elif _timer <= 0.0:
					_start_windup(to_player)
				else:
					desired = to_player.orthogonal().normalized() * move_speed * (1.0 if int(_home.x) % 2 == 0 else -1.0)
			elif dist < attack_range:
				_start_windup(to_player)
			else:
				desired = to_player.normalized() * chase_speed
		State.WINDUP:
			var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
			sprite.modulate = base_tint.lerp(WINDUP_TINT, k)
			if _timer <= 0.0:
				sprite.modulate = base_tint
				if ranged:
					_shoot(player)
					state = State.RECOVER
					_timer = recover_time + 1.2
				else:
					state = State.LUNGE
					_timer = lunge_time
					_hit_this_lunge = false
					sprite.play(&"punch", _dir, true)
		State.LUNGE:
			desired = _lunge_dir * lunge_speed
			if not _hit_this_lunge and _hitbox.strike() > 0:
				_hit_this_lunge = true
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_time
		State.RECOVER, State.HURT, State.STUNNED:
			if _timer <= 0.0:
				state = State.CHASE
				sprite.modulate = base_tint
	velocity = desired * (0.5 if is_slowed() else 1.0)
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	if state in [State.DRIFT, State.CHASE]:
		if desired != Vector2.ZERO:
			_dir = LayeredCharacterSprite.dir_from_vector(desired, _dir)
		sprite.play(&"walk" if desired != Vector2.ZERO else &"idle", _dir)
	if state == State.STUNNED:
		sprite.modulate = base_tint.lerp(Color(1.4, 1.35, 0.8), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3, 1) if _flash > 0.0 else base_tint
	elif is_slowed() and state in [State.DRIFT, State.CHASE]:
		sprite.modulate = base_tint.lerp(Color(0.5, 0.7, 1.4), 0.5)


## Lantern Flash: interrupts any attack.
## Slowed by an ally (Mara's "pin"): moves at half speed and shows blue.
func slow(seconds: float) -> void:
	_slow_until = Time.get_ticks_msec() / 1000.0 + seconds


func is_slowed() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _slow_until


func stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	state = State.STUNNED
	_timer = seconds
	_hitbox.position = Vector2.ZERO


func _start_windup(to_player: Vector2) -> void:
	state = State.WINDUP
	_timer = windup_time
	_lunge_dir = to_player.normalized()
	_dir = LayeredCharacterSprite.dir_from_vector(to_player, _dir)
	_hitbox.position = _lunge_dir * 10.0
	sprite.play(&"idle", _dir)
	if ranged:
		Sfx.play(&"stamp_warn", 0.1, -6.0)


func _shoot(player: Node2D) -> void:
	if player == null:
		return
	var shard: MemoryShard = SHARD_SCENE.instantiate()
	shard.direction = (player.global_position + Vector2(0, -8) - (global_position + Vector2(0, -12))).normalized()
	shard.global_position = global_position + Vector2(0, -12)
	get_parent().add_child(shard)
	Sfx.play(&"shard")


func _pick_drift() -> void:
	_timer = randf_range(1.0, 2.2)
	var back_home := (_home - global_position)
	if back_home.length() > 48.0:
		_drift_dir = back_home.normalized()
	else:
		_drift_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO


func _on_hit(damage: int, from_position: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	_knockback = (global_position - from_position).normalized() * knockback
	if state != State.STUNNED:
		state = State.HURT
		_timer = 0.3
	_flash = 0.06
	sprite.play(&"hurt", _dir, true)
	(_bar as EnemyHealthBar).show_health(health.health, health.max_health)
	CombatFx.damage_number(get_parent(), global_position, damage)


func _on_died() -> void:
	state = State.DEAD
	collision_mask = 0
	if enemy_id != &"":
		GameState.set_flag(StringName("defeated.%s" % enemy_id), true)
	remove_from_group(&"echo_enemy")
	Progression.add_xp(Progression.XP_ENEMY)
	Sfx.play(&"enemy_death")
	_drop_rewards()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_property(self, "position:y", position.y - 8.0, 0.6)
	t.chain().tween_callback(queue_free)


func _drop_rewards() -> void:
	for i in resonance_drop:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-6, 2))
		get_parent().add_child.call_deferred(mote)
	if randf() < item_drop_chance:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.item_id = &"sandwich"
		mote.global_position = global_position
		get_parent().add_child.call_deferred(mote)


static func _rect_shape(size: Vector2, offset: Vector2) -> CollisionShape2D:
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	s.shape = r
	s.position = offset
	return s
