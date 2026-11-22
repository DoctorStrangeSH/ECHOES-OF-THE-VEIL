class_name CensusTaker
extends CharacterBody2D
## Miniboss: the echo of a Census Office clerk who "reclassified" Lantern Row.
## Phase 1 (>66%): stamps three telegraphed squares around the player, then
##   pauses to write in his ledger (the opening).
## Phase 2 (>33%): more stamps, summons Clingers ("calls the register").
## Phase 3: "Erasure" — draws a line toward the player, then charges along it.
## Every attack is telegraphed; the Lantern Flash briefly interrupts him
## (except mid-charge).

enum State { DORMANT, WRITING, STAMPING, SUMMONING, AIMING, CHARGING, STUNNED, DEAD }

const MAX_HEALTH := 24
const CLINGER_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const MOTE_SCENE := preload("res://scenes/combat/resonance_mote.tscn")
const TINT := Color(0.62, 0.68, 0.85, 0.95)

@export var boss_id: StringName = &"census_taker"
@export var premade: String = "Premade_Character_17"

var state: State = State.DORMANT
var health: Health
var _timer := 0.0
var _cycle := 0
var _charge_dir := Vector2.ZERO
var _aim_line := false
var _hitbox: Hitbox
var _flash := 0.0
var _home := Vector2.ZERO

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if GameState.has_flag(_defeated_flag()):
		queue_free()
		return
	add_to_group(&"boss")
	add_to_group(&"threat")
	collision_layer = 1 << 3  # solid like an NPC: the player cannot walk through him
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	sprite.appearance = CharacterAppearance.from_premade(premade, Color(0.4, 0.45, 0.6))
	sprite.scale = Vector2(1.6, 1.6)
	sprite.modulate = TINT
	sprite.play(&"idle", LayeredCharacterSprite.Dir.DOWN)

	health = Health.new()
	health.max_health = GameState.enemy_health(int(DataFiles.boss_stat("census_taker", "health", MAX_HEALTH)))
	health.invulnerability_time = 0.15
	add_child(health)
	health.died.connect(_on_died)
	var hurt := Hurtbox.new()
	hurt.team = &"enemy"
	hurt.health = health
	hurt.add_child(EchoEnemy._rect_shape(Vector2(20, 40), Vector2(0, -20)))
	add_child(hurt)
	hurt.hit.connect(_on_hit)
	BossPoise.attach(self, hurt, health.max_health)
	_hitbox = Hitbox.new()
	_hitbox.team = &"enemy"
	_hitbox.damage = 2
	_hitbox.knockback = 220.0
	_hitbox.add_child(EchoEnemy._rect_shape(Vector2(22, 22), Vector2(0, -12)))
	add_child(_hitbox)


func _defeated_flag() -> StringName:
	return StringName("boss.%s.defeated" % boss_id)


func engage() -> void:
	if state != State.DORMANT:
		return
	Sfx.play(&"boss_roar", 0.0)
	EventHub.camera_shake_requested.emit(5.0)
	_emit_bar()
	_enter(State.WRITING, 1.0)


func phase() -> int:
	var f := float(health.health) / health.max_health
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func stun(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD, State.CHARGING]:
		return
	_aim_line = false
	_enter(State.STUNNED, minf(seconds, 0.8))


func _enter(s: State, t: float) -> void:
	state = s
	_timer = t
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	_timer -= delta
	velocity = Vector2.ZERO
	match state:
		State.WRITING:
			# The opening: he pauses to write. Drifts slowly toward the player.
			velocity = to_player.normalized() * 14.0 if to_player.length() > 40.0 else Vector2.ZERO
			if _timer <= 0.0:
				_next_attack(player)
		State.STAMPING, State.SUMMONING, State.STUNNED:
			if _timer <= 0.0:
				_enter(State.WRITING, 1.4 if phase() == 1 else 1.0)
		State.AIMING:
			_charge_dir = to_player.normalized()
			queue_redraw()
			if _timer <= 0.0:
				_aim_line = false
				Sfx.play(&"dodge", 0.0, 4.0)
				_enter(State.CHARGING, 0.55)
		State.CHARGING:
			velocity = _charge_dir * 300.0
			_hitbox.position = _charge_dir * 8.0
			_hitbox.strike()
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				EventHub.camera_shake_requested.emit(3.0)
				_enter(State.WRITING, 1.6)
	move_and_slide()
	var face := LayeredCharacterSprite.dir_from_vector(to_player, LayeredCharacterSprite.Dir.DOWN)
	sprite.play(&"walk" if velocity.length() > 1.0 else &"idle", face)
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else TINT
	elif state == State.STUNNED:
		sprite.modulate = TINT.lerp(Color(1.4, 1.35, 0.8), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
	else:
		sprite.modulate = TINT


func _next_attack(player: Node2D) -> void:
	_cycle += 1
	var p := phase()
	if p == 3 and _cycle % 2 == 0:
		_aim_line = true
		Sfx.play(&"stamp_warn", 0.0, 2.0)
		_enter(State.AIMING, 0.8)
		return
	if p >= 2 and _cycle % 3 == 0 and _living_clingers() < 3:
		_summon()
		_enter(State.SUMMONING, 1.0)
		return
	var count := 3 if p == 1 else (4 if p == 2 else 5)
	var delay := 0.95 if p == 1 else (0.85 if p == 2 else 0.7)
	_stamp(player, count, delay)
	_enter(State.STAMPING, delay + 0.4)


func _stamp(player: Node2D, count: int, delay: float) -> void:
	Sfx.play(&"stamp_warn", 0.05)
	sprite.play(&"punch", LayeredCharacterSprite.Dir.DOWN, true)
	for i in count:
		var m := StampMarker.new()
		m.delay = delay + i * 0.08
		m.radius = 18.0
		var offset := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(22.0, 48.0)
		m.global_position = player.global_position + offset
		get_parent().add_child(m)


func _summon() -> void:
	Sfx.play(&"boss_roar", 0.2, -6.0)
	for i in 2:
		var c: EchoEnemy = CLINGER_SCENE.instantiate()
		c.variant = "clinger"
		c.item_drop_chance = 0.25
		c.global_position = global_position + Vector2(-20 + 40 * i, 18)
		get_parent().add_child(c)


func _living_clingers() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if get_parent().is_ancestor_of(e):
			n += 1
	return n


func _on_hit(damage: int, _from: Vector2, _knockback: float) -> void:
	_flash = 0.06
	CombatFx.damage_number(get_parent(), global_position + Vector2(0, -20), damage)
	_emit_bar()


func _emit_bar() -> void:
	EventHub.boss_health_changed.emit("BOSS_CENSUS_TAKER", health.health, health.max_health)


func _on_died() -> void:
	_enter(State.DEAD, 0.0)
	_aim_line = false
	GameState.set_flag(_defeated_flag(), true)
	EventHub.boss_health_changed.emit("", 0, 0)
	Sfx.play(&"enemy_death", 0.0, 4.0)
	Sfx.play(&"boss_roar", 0.3, -2.0)
	EventHub.camera_shake_requested.emit(6.0)
	CombatFx.hitstop(0.25)
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if get_parent().is_ancestor_of(e) and e.has_method("stun"):
			(e as EchoEnemy).health.take_damage(99, global_position)
	for i in 10:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-10, 6))
		get_parent().add_child.call_deferred(mote)
	var page: ResonanceMote = MOTE_SCENE.instantiate()
	page.item_id = &"ledger_page"
	page.global_position = global_position
	get_parent().add_child.call_deferred(page)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)


func _draw() -> void:
	if _aim_line and state == State.AIMING:
		var k := 1.0 - clampf(_timer / 0.8, 0.0, 1.0)
		draw_line(Vector2(0, -6), Vector2(0, -6) + _charge_dir * 170.0, Color(1, 0.3, 0.3, 0.3 + 0.6 * k), 2.0 + 4.0 * k)


## Thrown off balance (BossPoise): whatever he was doing, he stops.
func break_open(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	_aim_line = false
	_enter(State.STUNNED, seconds)


## A dodge now is perfect: the charge is upon `at`.
func is_threatening(at: Vector2) -> bool:
	var near := global_position.distance_to(at) < 46.0
	return (state == State.CHARGING and near) or (state == State.AIMING and _timer <= 0.2 and near)
