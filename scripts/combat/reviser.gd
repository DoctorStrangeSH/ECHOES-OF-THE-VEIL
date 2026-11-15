class_name Reviser
extends CharacterBody2D
## Bosses of the Index's memory-sites: "revisions" of people from the night of
## 1962, each rewriting its arena. One script, tuned per site:
##   pattern "rows" | "columns" | "checker" - which cells it edits
##   summon_variant - the echoes it calls in phase 2+
## Cycle: it walks at you, lunges, then rewrites the floor (it channels while
## marking cells - the Lantern Flash breaks the channel); edited cells hurt.
## At least one row/column/colour of cells is always left untouched.

enum State { DORMANT, STALK, LUNGE, REWRITE, SUMMON, STUNNED, DEAD }

const ECHO_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const MOTE_SCENE := preload("res://scenes/combat/resonance_mote.tscn")

@export var boss_id: StringName = &"reviser"
@export var name_key: String = "BOSS_REVISER"
@export var premade: String = "Premade_Character_13"
@export var pattern: String = "rows"
@export var summon_variant: String = "clinger"
@export var max_health := 28
@export var tint := Color(0.9, 0.85, 1.0, 0.92)
@export var arena_offset := Vector2(-144, -64)
@export var arena_size := Vector2(288, 128)
@export var cols := 4
@export var rows := 3

var state: State = State.DORMANT
var health: Health
var grid: EditGrid
var _timer := 0.0
var _cycle := 0
var _hitbox: Hitbox
var _flash := 0.0
var _home := Vector2.ZERO
var _lunge_dir := Vector2.ZERO
var _checker_flip := 0

@onready var sprite: LayeredCharacterSprite = $Sprite


func _ready() -> void:
	if GameState.has_flag(_defeated_flag()):
		queue_free()
		return
	add_to_group(&"boss")
	collision_layer = 1 << 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	sprite.appearance = CharacterAppearance.from_premade(premade, Color(0.5, 0.45, 0.6))
	sprite.scale = Vector2(1.5, 1.5)
	sprite.modulate = tint
	sprite.play(&"idle", LayeredCharacterSprite.Dir.DOWN)
	health = Health.new()
	health.max_health = GameState.enemy_health(max_health)
	health.invulnerability_time = 0.15
	add_child(health)
	health.died.connect(_on_died)
	var hurt := Hurtbox.new()
	hurt.team = &"enemy"
	hurt.health = health
	hurt.add_child(EchoEnemy._rect_shape(Vector2(18, 36), Vector2(0, -18)))
	add_child(hurt)
	hurt.hit.connect(_on_hit)
	_hitbox = Hitbox.new()
	_hitbox.team = &"enemy"
	_hitbox.damage = 1
	_hitbox.knockback = 200.0
	_hitbox.add_child(EchoEnemy._rect_shape(Vector2(22, 22), Vector2(0, -12)))
	add_child(_hitbox)
	grid = EditGrid.new()
	grid.size = arena_size
	grid.cols = cols
	grid.rows = rows
	grid.z_index = -1
	get_parent().add_child.call_deferred(grid)
	grid.set_deferred("global_position", _home + arena_offset)


func _defeated_flag() -> StringName:
	return StringName("boss.%s.defeated" % boss_id)


func engage() -> void:
	if state != State.DORMANT:
		return
	Sfx.play(&"boss_roar", 0.1)
	EventHub.camera_shake_requested.emit(3.0)
	_emit_bar()
	_enter(State.STALK, 1.4)


func phase() -> int:
	var f := float(health.health) / health.max_health
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func stun(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	if state == State.REWRITE:
		grid.clear_all()  # the flash breaks the channel before the cells go live
	_enter(State.STUNNED, minf(seconds, 1.0))


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
		State.STALK:
			velocity = to_player.normalized() * (34.0 + 8.0 * phase())
			if _timer <= 0.0:
				_lunge_dir = to_player.normalized()
				_enter(State.LUNGE, 0.4)
				Sfx.play(&"swing", 0.05)
		State.LUNGE:
			velocity = _lunge_dir * 190.0
			_hitbox.strike()
			if _timer <= 0.0:
				_next()
		State.REWRITE:
			if _timer <= 0.0:
				_enter(State.STALK, 1.6 if phase() == 1 else 1.1)
		State.SUMMON, State.STUNNED:
			if _timer <= 0.0:
				_enter(State.STALK, 1.2)
	move_and_slide()
	var dir := LayeredCharacterSprite.dir_from_vector(to_player, LayeredCharacterSprite.Dir.DOWN)
	sprite.play(&"walk" if velocity.length() > 1.0 else &"idle", dir)
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else tint
	elif state == State.REWRITE:
		sprite.modulate = tint.lerp(Color(1.3, 1.3, 1.5), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 70.0))
	else:
		sprite.modulate = tint


func _next() -> void:
	_cycle += 1
	if phase() >= 2 and _cycle % 3 == 0 and _living_echoes() < 2:
		_summon()
		_enter(State.SUMMON, 0.9)
		return
	var delay := 1.2 if phase() == 1 else (1.0 if phase() == 2 else 0.85)
	grid.mark(pick_cells(), delay, 2.0 + 0.3 * phase())
	Sfx.play(&"stamp_warn", 0.05)
	_enter(State.REWRITE, delay)


## The cells to edit this time. Always leaves at least one row, column or
## colour of the checkerboard untouched, so there is always somewhere safe.
func pick_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := phase()
	match pattern:
		"columns":
			var idx := range(cols)
			idx.shuffle()
			for i in mini(p, cols - 1):
				for y in rows:
					out.append(Vector2i(idx[i], y))
		"checker":
			_checker_flip += 1
			for x in cols:
				for y in rows:
					if (x + y + _checker_flip) % 2 == 0:
						out.append(Vector2i(x, y))
		_:
			var idy := range(rows)
			idy.shuffle()
			for i in mini(p, rows - 1):
				for x in cols:
					out.append(Vector2i(x, idy[i]))
	return out


func _summon() -> void:
	Sfx.play(&"boss_roar", 0.2, -8.0)
	for i in 2:
		var e: EchoEnemy = ECHO_SCENE.instantiate()
		e.variant = summon_variant
		e.item_drop_chance = 0.2
		e.global_position = _home + arena_offset + Vector2(20.0 + (arena_size.x - 40.0) * i, arena_size.y * 0.5)
		get_parent().add_child(e)


func _living_echoes() -> int:
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
	EventHub.boss_health_changed.emit(name_key, health.health, health.max_health)


func _on_died() -> void:
	_enter(State.DEAD, 0.0)
	grid.clear_all()
	GameState.set_flag(_defeated_flag(), true)
	EventHub.boss_health_changed.emit("", 0, 0)
	Sfx.play(&"enemy_death", 0.0, 4.0)
	EventHub.camera_shake_requested.emit(5.0)
	CombatFx.hitstop(0.2)
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if get_parent().is_ancestor_of(e):
			(e as EchoEnemy).health.take_damage(99, global_position)
	for i in 10:
		var mote: ResonanceMote = MOTE_SCENE.instantiate()
		mote.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-10, 6))
		get_parent().add_child.call_deferred(mote)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)
