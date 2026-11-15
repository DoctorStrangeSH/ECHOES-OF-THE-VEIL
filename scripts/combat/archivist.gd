class_name Archivist
extends CharacterBody2D
## Boss of the flooded underpass: the Archivist of Floods, an echo made of
## every record the 1962 flood was blamed for destroying. The arena floods
## in cycles; stacks of files are islands.
##   LOW      - he stands in the open throwing pages (the opening)
##   RISING   - he sinks; water rises (telegraphed by the tide line)
##   HIGH     - he is under water; ledgers fall where you stand
##   RECEDING - the water drains and he surfaces somewhere else
## Phases raise the water and shorten his time on the surface.

enum State { DORMANT, LOW, RISING, HIGH, RECEDING, STUNNED, DEAD }

const MAX_HEALTH := 34
const SHARD_SCENE := preload("res://scenes/combat/memory_shard.tscn")
const MOTE_SCENE := preload("res://scenes/combat/resonance_mote.tscn")
const TINT := Color(0.7, 0.85, 1.0, 0.92)

@export var boss_id: StringName = &"archivist"
@export var premade: String = "Premade_Character_11"
## Arena relative to the boss's start: top-left corner and size.
@export var arena_offset := Vector2(-180, -90)
@export var arena_size := Vector2(360, 180)
## Dry islands, relative to the arena's top-left corner.
@export var islands: Array[Rect2] = [Rect2(30, 110, 44, 34), Rect2(158, 40, 44, 30), Rect2(286, 110, 44, 34)]

var state: State = State.DORMANT
var health: Health
var water: FloodWater
var _timer := 0.0
var _throw := 0.0
var _hurt: Hurtbox
var _flash := 0.0
var _home := Vector2.ZERO

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if GameState.has_flag(_defeated_flag()):
		queue_free()
		return
	add_to_group(&"boss")
	collision_layer = 1 << 3
	collision_mask = 0  # walks through his own flood
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	sprite.appearance = CharacterAppearance.from_premade(premade, Color(0.4, 0.5, 0.6))
	sprite.scale = Vector2(1.6, 1.6)
	sprite.modulate = TINT
	sprite.play(&"idle", LayeredCharacterSprite.Dir.DOWN)
	health = Health.new()
	health.max_health = GameState.enemy_health(int(DataFiles.boss_stat("archivist", "health", MAX_HEALTH)))
	health.invulnerability_time = 0.15
	add_child(health)
	health.died.connect(_on_died)
	_hurt = Hurtbox.new()
	_hurt.team = &"enemy"
	_hurt.health = health
	_hurt.add_child(EchoEnemy._rect_shape(Vector2(20, 40), Vector2(0, -20)))
	add_child(_hurt)
	_hurt.hit.connect(_on_hit)
	water = FloodWater.new()
	water.size = arena_size
	water.islands = islands
	water.z_index = 1
	get_parent().add_child.call_deferred(water)
	water.set_deferred("global_position", _home + arena_offset)


func _defeated_flag() -> StringName:
	return StringName("boss.%s.defeated" % boss_id)


func engage() -> void:
	if state != State.DORMANT:
		return
	Sfx.play(&"boss_roar", 0.1)
	EventHub.camera_shake_requested.emit(4.0)
	_emit_bar()
	_enter(State.LOW, 2.0)


func phase() -> int:
	var f := float(health.health) / health.max_health
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func is_submerged() -> bool:
	return state in [State.RISING, State.HIGH]


func stun(seconds: float) -> void:
	if state != State.LOW:
		return
	_enter(State.STUNNED, minf(seconds, 1.0))


func _enter(s: State, t: float) -> void:
	state = s
	_timer = t
	_hurt.set_deferred("monitorable", not is_submerged())
	match s:
		State.RISING:
			water.set_target(0.75 if phase() == 1 else 0.92, 0.55)
			Sfx.play(&"shard", 0.1, -4.0)
		State.RECEDING:
			water.set_target(0.0, 0.8)
		State.LOW:
			_surface()


func _surface() -> void:
	var spots := [Vector2(0, 0), Vector2(-90, 20), Vector2(90, 20), Vector2(0, 40)]
	global_position = _home + spots[randi() % spots.size()]
	sprite.modulate.a = TINT.a


func _physics_process(delta: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	_timer -= delta
	match state:
		State.LOW:
			_throw -= delta
			if _throw <= 0.0:
				_throw = 1.3 if phase() == 1 else 1.0
				_throw_pages(player, 3 if phase() < 3 else 5)
			if _timer <= 0.0:
				_enter(State.RISING, 1.6)
		State.STUNNED:
			if _timer <= 0.0:
				_enter(State.RISING, 1.6)
		State.RISING:
			sprite.modulate.a = move_toward(sprite.modulate.a, 0.15, delta)
			if _timer <= 0.0:
				_enter(State.HIGH, 3.6 if phase() == 1 else 4.2)
				_throw = 0.6
		State.HIGH:
			_throw -= delta
			if _throw <= 0.0:
				_throw = 1.25 if phase() < 3 else 0.9
				_drop_ledger(player)
			if _timer <= 0.0:
				_enter(State.RECEDING, 1.3)
		State.RECEDING:
			if _timer <= 0.0:
				_enter(State.LOW, 3.6 if phase() == 1 else (3.0 if phase() == 2 else 2.4))
	sprite.play(&"idle", LayeredCharacterSprite.dir_from_vector(player.global_position - global_position, LayeredCharacterSprite.Dir.DOWN))
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else TINT
	elif state == State.STUNNED:
		sprite.modulate = TINT.lerp(Color(1.4, 1.4, 1.0), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
	elif not is_submerged():
		sprite.modulate = TINT


func _throw_pages(player: Node2D, count: int) -> void:
	sprite.play(&"punch", LayeredCharacterSprite.Dir.DOWN, true)
	Sfx.play(&"shard", 0.05)
	var base := (player.global_position - global_position).angle()
	for i in count:
		var s: MemoryShard = SHARD_SCENE.instantiate()
		s.direction = Vector2.from_angle(base + (i - (count - 1) / 2.0) * 0.28)
		s.global_position = global_position + Vector2(0, -16)
		get_parent().add_child(s)


func _drop_ledger(player: Node2D) -> void:
	var m := StampMarker.new()
	m.delay = 0.95
	m.radius = 15.0
	m.global_position = player.global_position
	get_parent().add_child(m)
	Sfx.play(&"stamp_warn", 0.05, -4.0)


func _on_hit(damage: int, _from: Vector2, _knockback: float) -> void:
	_flash = 0.06
	CombatFx.damage_number(get_parent(), global_position + Vector2(0, -20), damage)
	_emit_bar()


func _emit_bar() -> void:
	EventHub.boss_health_changed.emit("BOSS_ARCHIVIST", health.health, health.max_health)


func _on_died() -> void:
	_enter(State.DEAD, 0.0)
	water.set_target(0.0, 1.5)
	GameState.set_flag(_defeated_flag(), true)
	EventHub.boss_health_changed.emit("", 0, 0)
	Sfx.play(&"enemy_death", 0.0, 4.0)
	EventHub.camera_shake_requested.emit(6.0)
	CombatFx.hitstop(0.25)
	for i in 12:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-10, 6))
		get_parent().add_child.call_deferred(mote)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)
