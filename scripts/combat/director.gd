class_name Director
extends CharacterBody2D
## The final encounter: Director Elias Wren at the anchor, using the Lattice
## itself. He cycles through every trick the echoes used on you:
##   stamps (the Census Taker), lanes (the Conductor), rewrites (the Revisions),
##   and summoned echoes. He casts each for a moment; the Lantern Flash during
##   a cast breaks it.
## Who stands with you changes the fight (never skips it):
##   Jonah heals you at each phase, Mara reads the rewrites aloud (no grid),
##   Ivo's Keepers weaken him (75% health), Nadiya's people hold the lines (no
##   lanes), Dr Vale reads the Lattice (slower telegraphs), the Alderman's
##   Unwritten hold back the echoes (no summons). Each true night you put back
##   together costs him another 10% of his health.

enum State { DORMANT, STALK, CAST, STUNNED, DEAD }

const BASE_HEALTH := 44
const ECHO_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const TINT := Color(0.85, 0.85, 0.95, 1.0)
const ALLIES := ["jonah_rook", "mara_venn", "ivo_calder", "nadiya_sol", "sera_vale", "alderman_penhallow"]

@export var premade: String = "Premade_Character_07"
@export var arena_offset := Vector2(-160, -80)
@export var arena_size := Vector2(320, 160)

var state: State = State.DORMANT
var health: Health
var grid: EditGrid
var mechanics: Array[String] = ["stamps", "lanes", "grid", "summon"]
var telegraph_mult := 1.0
var _timer := 0.0
var _cast := ""
var _cast_index := 0
var _phase_seen := 1
var _hitbox: Hitbox
var _flash := 0.0
var _home := Vector2.ZERO

@onready var sprite: LayeredCharacterSprite = $Sprite


static func ally_present(id: String) -> bool:
	return GameState.has_flag(StringName("anchor.ally.%s" % id))


static func true_nights() -> int:
	var n := 0
	for s in ["hospital", "home", "station"]:
		n += int(GameState.has_flag(StringName("site.%s.true" % s)))
	return n


## Health after allies and evidence; at least 40% of the base always remains.
static func health_for_conditions() -> int:
	var k := 1.0 - 0.1 * true_nights()
	if ally_present("ivo_calder"):
		k -= 0.25
	var base := int(DataFiles.boss_stat("director", "health", BASE_HEALTH))
	return GameState.enemy_health(int(round(base * maxf(0.4, k))))


func _ready() -> void:
	if GameState.has_flag(&"boss.director.defeated"):
		queue_free()
		return
	add_to_group(&"boss")
	add_to_group(&"threat")
	collision_layer = 1 << 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = global_position
	sprite.appearance = CharacterAppearance.from_premade(premade, Color(0.3, 0.3, 0.4))
	sprite.scale = Vector2(1.5, 1.5)
	sprite.modulate = TINT
	sprite.play(&"idle", LayeredCharacterSprite.Dir.DOWN)
	health = Health.new()
	health.max_health = health_for_conditions()
	health.invulnerability_time = 0.15
	add_child(health)
	health.died.connect(_on_died)
	var hurt := Hurtbox.new()
	hurt.team = &"enemy"
	hurt.health = health
	hurt.add_child(EchoEnemy._rect_shape(Vector2(18, 36), Vector2(0, -18)))
	add_child(hurt)
	hurt.hit.connect(_on_hit)
	BossPoise.attach(self, hurt, health.max_health)
	_hitbox = Hitbox.new()
	_hitbox.team = &"enemy"
	_hitbox.damage = 1
	_hitbox.knockback = 200.0
	_hitbox.add_child(EchoEnemy._rect_shape(Vector2(22, 22), Vector2(0, -12)))
	add_child(_hitbox)
	grid = EditGrid.new()
	grid.size = arena_size
	grid.cols = 4
	grid.rows = 3
	grid.z_index = -1
	get_parent().add_child.call_deferred(grid)
	grid.set_deferred("global_position", _home + arena_offset)
	apply_allies()


func apply_allies() -> void:
	mechanics = ["stamps", "lanes", "grid", "summon"]
	if ally_present("mara_venn"):
		mechanics.erase("grid")
	if ally_present("nadiya_sol"):
		mechanics.erase("lanes")
	if ally_present("alderman_penhallow"):
		mechanics.erase("summon")
	telegraph_mult = 1.5 if ally_present("sera_vale") else 1.0


func engage() -> void:
	if state != State.DORMANT:
		return
	Sfx.play(&"boss_roar", 0.1)
	EventHub.camera_shake_requested.emit(5.0)
	_emit_bar()
	_enter(State.STALK, 1.5)


func phase() -> int:
	var f := float(health.health) / health.max_health
	if f > 0.66:
		return 1
	if f > 0.33:
		return 2
	return 3


func stun(seconds: float) -> void:
	if state == State.CAST:
		grid.clear_all()
		_enter(State.STUNNED, minf(seconds, 1.2))
	elif state == State.STALK:
		_enter(State.STUNNED, minf(seconds, 0.6))


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
	if phase() != _phase_seen:
		_phase_seen = phase()
		_on_phase_change()
	match state:
		State.STALK:
			velocity = to_player.normalized() * (30.0 + 10.0 * phase()) if to_player.length() > 30.0 else Vector2.ZERO
			if to_player.length() < 24.0:
				_hitbox.strike()
			if _timer <= 0.0:
				_begin_cast(player)
		State.CAST:
			if _timer <= 0.0:
				_release(player)
				_enter(State.STALK, 1.6 if phase() == 1 else (1.2 if phase() == 2 else 0.9))
		State.STUNNED:
			if _timer <= 0.0:
				_enter(State.STALK, 1.0)
	move_and_slide()
	sprite.play(&"walk" if velocity.length() > 1.0 else &"idle", LayeredCharacterSprite.dir_from_vector(to_player, LayeredCharacterSprite.Dir.DOWN))
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else TINT
	elif state == State.CAST:
		sprite.modulate = TINT.lerp(Color(1.4, 1.2, 1.6), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
	else:
		sprite.modulate = TINT


func _on_phase_change() -> void:
	Sfx.play(&"bell", 0.0, 2.0)
	EventHub.camera_shake_requested.emit(4.0)
	if ally_present("jonah_rook"):
		EventHub.player_heal_requested_amount.emit(2)
		EventHub.toast_requested.emit(tr("TOAST_COMPANION_PATCH") % tr("NPC_JONAH"))


func _begin_cast(player: Node2D) -> void:
	if mechanics.is_empty():
		_cast = "stalk"
	else:
		_cast = mechanics[_cast_index % mechanics.size()]
		_cast_index += 1
	var t := 1.0 * telegraph_mult
	match _cast:
		"grid":
			var cells: Array[Vector2i] = []
			var skip := randi() % grid.rows
			for y in grid.rows:
				if y != skip and (phase() > 1 or y % 2 == 0):
					for x in grid.cols:
						cells.append(Vector2i(x, y))
			grid.mark(cells, t, 2.4)
		"lanes":
			var free := randi() % 3
			for i in 3:
				if i != free and (phase() > 1 or i == (free + 1) % 3):
					var s := LaneSweep.new()
					s.length = arena_size.x
					s.delay = t
					s.global_position = _home + Vector2(arena_offset.x, -50.0 + 50.0 * i)
					get_parent().add_child(s)
		"stamps":
			for i in phase() + 1:
				var m := StampMarker.new()
				m.delay = t + 0.1 * i
				m.radius = 16.0
				m.global_position = player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(24, 48))
				get_parent().add_child(m)
		"summon":
			pass
	Sfx.play(&"stamp_warn", 0.05)
	_enter(State.CAST, t)


func _release(_player: Node2D) -> void:
	if _cast == "summon" and _living_echoes() < 2:
		for i in 2:
			var e: EchoEnemy = ECHO_SCENE.instantiate()
			e.variant = ["hollow", "wailer"][i]
			e.global_position = _home + arena_offset + Vector2(30.0 + (arena_size.x - 60.0) * i, arena_size.y * 0.5)
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
	EventHub.boss_health_changed.emit("BOSS_DIRECTOR", health.health, health.max_health)


func _on_died() -> void:
	_enter(State.DEAD, 0.0)
	grid.clear_all()
	GameState.set_flag(&"boss.director.defeated", true)
	EventHub.boss_health_changed.emit("", 0, 0)
	Sfx.play(&"bell", 0.3, 2.0)
	EventHub.camera_shake_requested.emit(7.0)
	CombatFx.hitstop(0.3)
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if get_parent().is_ancestor_of(e):
			(e as EchoEnemy).health.take_damage(99, global_position)
	# Wren doesn't die: he kneels by the anchor (an NPC takes his place).
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)


## Thrown off balance (BossPoise): the cast breaks, he stops.
func break_open(seconds: float) -> void:
	if state in [State.DORMANT, State.DEAD]:
		return
	if state == State.CAST:
		grid.clear_all()
	_enter(State.STUNNED, seconds)


## A dodge now is perfect: he is close enough to strike.
func is_threatening(at: Vector2) -> bool:
	return state == State.STALK and global_position.distance_to(at) < 28.0
