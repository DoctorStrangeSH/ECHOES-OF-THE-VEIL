class_name Conductor
extends CharacterBody2D
## Boss of the Ward depot: the echo of a tram conductor still collecting
## tickets for a line that no longer runs. The arena is three tram lanes.
## Phase 1 (>66%): punches tickets (stamps) and calls "next stop" on one lane.
## Phase 2 (>33%): two lanes at once (one is always safe); "passengers" (Hollows) board.
## Phase 3: lanes in quick succession from both ends.
## After every tram he stops to check his ticket machine: the opening.
## The Lantern Flash interrupts him, except while a tram is running.

enum State { DORMANT, CHECKING, CALLING, PUNCHING, BOARDING, STUNNED, DEAD }

const MAX_HEALTH := 30
const HOLLOW_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const MOTE_SCENE := preload("res://scenes/combat/resonance_mote.tscn")
const TINT := Color(0.85, 0.8, 0.62, 0.95)

@export var boss_id: StringName = &"conductor"
@export var premade: String = "Premade_Character_08"
## Lane centres (y, relative to the boss's start) and the arena's left/right edges.
@export var lane_offsets: PackedFloat32Array = PackedFloat32Array([-48.0, 0.0, 48.0])
@export var arena_left := -180.0
@export var arena_width := 360.0

var state: State = State.DORMANT
var health: Health
var _timer := 0.0
var _cycle := 0
var _hitbox: Hitbox
var _flash := 0.0
var _home := Vector2.ZERO
var _last_lanes: Array[int] = []

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if GameState.has_flag(_defeated_flag()):
		queue_free()
		return
	add_to_group(&"boss")
	add_to_group(&"threat")
	collision_layer = 1 << 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	sprite.appearance = CharacterAppearance.from_premade(premade, Color(0.55, 0.5, 0.35))
	sprite.scale = Vector2(1.6, 1.6)
	sprite.modulate = TINT
	sprite.play(&"idle", LayeredCharacterSprite.Dir.DOWN)
	health = Health.new()
	health.max_health = GameState.enemy_health(int(DataFiles.boss_stat("conductor", "health", MAX_HEALTH)))
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
	_hitbox.damage = 1
	_hitbox.knockback = 180.0
	_hitbox.add_child(EchoEnemy._rect_shape(Vector2(22, 22), Vector2(0, -12)))
	add_child(_hitbox)


func _defeated_flag() -> StringName:
	return StringName("boss.%s.defeated" % boss_id)


func engage() -> void:
	if state != State.DORMANT:
		return
	Sfx.play(&"bell", 0.0, 2.0)
	EventHub.camera_shake_requested.emit(4.0)
	_emit_bar()
	_enter(State.CHECKING, 1.2)


func phase() -> int:
	var f := float(health.health) / health.max_health
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func stun(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD, State.CALLING]:
		return
	_enter(State.STUNNED, minf(seconds, 0.9))


func _enter(s: State, t: float) -> void:
	state = s
	_timer = t


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
		State.CHECKING:
			# The opening: he checks his machine and walks the platform slowly.
			velocity = to_player.normalized() * 18.0 if to_player.length() > 36.0 else Vector2.ZERO
			if to_player.length() < 22.0:
				_hitbox.strike()
			if _timer <= 0.0:
				_next(player)
		State.CALLING, State.PUNCHING, State.BOARDING, State.STUNNED:
			if _timer <= 0.0:
				_enter(State.CHECKING, 1.5 if phase() == 1 else (1.2 if phase() == 2 else 0.9))
	move_and_slide()
	sprite.play(&"walk" if velocity.length() > 1.0 else &"idle", LayeredCharacterSprite.dir_from_vector(to_player, LayeredCharacterSprite.Dir.DOWN))
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else TINT
	elif state == State.STUNNED:
		sprite.modulate = TINT.lerp(Color(1.4, 1.35, 0.8), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
	else:
		sprite.modulate = TINT


func _next(player: Node2D) -> void:
	_cycle += 1
	var p := phase()
	if p >= 2 and _cycle % 4 == 0 and _living_passengers() < 2:
		_board()
		_enter(State.BOARDING, 1.0)
		return
	if _cycle % 2 == 1:
		var lanes := _pick_lanes(player, 1 if p == 1 else 2)
		var delay := 1.25 if p == 1 else (1.05 if p == 2 else 0.85)
		for i in lanes.size():
			_call_lane(lanes[i], delay + (0.35 * i if p == 3 else 0.0), p == 3 and i % 2 == 1)
		Sfx.play(&"bell", 0.0, -2.0)
		_enter(State.CALLING, delay + 0.9 + (0.35 if p == 3 else 0.0))
	else:
		_punch(player, 2 if p == 1 else 3)
		_enter(State.PUNCHING, 1.2)


## Lanes for this call; the lane nearest the player is always one of them, and
## at least one lane is always left free.
func _pick_lanes(player: Node2D, count: int) -> Array[int]:
	var nearest := 0
	var best := INF
	for i in lane_offsets.size():
		var d := absf(player.global_position.y - (_home.y + lane_offsets[i]))
		if d < best:
			best = d
			nearest = i
	var out: Array[int] = [nearest]
	var others: Array[int] = []
	for i in lane_offsets.size():
		if i != nearest:
			others.append(i)
	others.shuffle()
	while out.size() < mini(count, lane_offsets.size() - 1) and not others.is_empty():
		out.append(others.pop_back())
	_last_lanes = out
	return out


func _call_lane(lane: int, delay: float, from_right: bool) -> void:
	var s := LaneSweep.new()
	s.length = arena_width
	s.delay = delay
	s.from_right = from_right
	s.global_position = _home + Vector2(arena_left, lane_offsets[lane])
	get_parent().add_child(s)


func _punch(player: Node2D, count: int) -> void:
	Sfx.play(&"stamp_warn", 0.05)
	sprite.play(&"punch", LayeredCharacterSprite.Dir.DOWN, true)
	for i in count:
		var m := StampMarker.new()
		m.delay = 0.9 + i * 0.1
		m.radius = 16.0
		var offset := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(24.0, 44.0)
		m.global_position = player.global_position + offset
		get_parent().add_child(m)


func _board() -> void:
	Sfx.play(&"boss_roar", 0.2, -8.0)
	for i in 2:
		var h: EchoEnemy = HOLLOW_SCENE.instantiate()
		h.variant = "hollow"
		h.item_drop_chance = 0.2
		h.global_position = _home + Vector2(arena_left + 20.0 + (arena_width - 40.0) * i, lane_offsets[i * (lane_offsets.size() - 1)])
		get_parent().add_child(h)


func _living_passengers() -> int:
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
	EventHub.boss_health_changed.emit("BOSS_CONDUCTOR", health.health, health.max_health)


func _on_died() -> void:
	_enter(State.DEAD, 0.0)
	GameState.set_flag(_defeated_flag(), true)
	EventHub.boss_health_changed.emit("", 0, 0)
	Sfx.play(&"enemy_death", 0.0, 4.0)
	Sfx.play(&"bell", 0.3, 2.0)
	EventHub.camera_shake_requested.emit(6.0)
	CombatFx.hitstop(0.25)
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if get_parent().is_ancestor_of(e):
			(e as EchoEnemy).health.take_damage(99, global_position)
	for i in 12:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-10, 6))
		get_parent().add_child.call_deferred(mote)
	if boss_id == &"conductor":
		var ticket: ResonanceMote = MOTE_SCENE.instantiate()
		ticket.item_id = &"last_ticket"
		ticket.global_position = global_position
		get_parent().add_child.call_deferred(ticket)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)


## Thrown off balance (BossPoise): whatever he was doing, he stops.
func break_open(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	_enter(State.STUNNED, seconds)


## A dodge now is perfect: he is close enough to strike.
func is_threatening(at: Vector2) -> bool:
	return state == State.CHECKING and global_position.distance_to(at) < 26.0
