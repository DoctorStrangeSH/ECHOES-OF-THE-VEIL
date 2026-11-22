class_name Player
extends CharacterBody2D
## Player controller.
## Town: 8-direction movement, sprint, interaction.
## Veil locations (combat_enabled): weapon combo (3 hits, finisher), dodge with
## short i-frames, "Lantern Flash" stun ability, quick heal, hit-stop and shake.
## R15a: hold the attack for a heavy blow all around; a dodge in the last
## instant before an echo's blow is perfect (the Echo: time slows and the
## next blow is a counter for double); a run of hits without being hurt is a
## streak, and a streak makes echoes drop more Resonance.
## Stats come from the equipped weapon/trinket and Attunements (Inventory.stat).
## Owner: player. Manual tests: docs/technical/m3-test-plan.md.

const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_NPC := 1 << 3
const BASE_MAX_HEALTH := 5
const COURIER_SPRINT_BONUS := 1.12

const COMBO_WINDOW := 0.5
const DODGE_SPEED := 250.0
const DODGE_TIME := 0.16
const DODGE_IFRAMES := 0.22
const DODGE_COOLDOWN := 0.75
const FLASH_RADIUS := 50.0
const FLASH_STUN := 1.6
const FLASH_COOLDOWN := 6.0
const CHARGE_START := 0.3
const CHARGE_FULL := 0.8
const HEAVY_RADIUS := 26.0
const COUNTER_TIME := 1.5

## Behind the wheel of your own car in the open world (see Driving).
const DRIVE_SPEED := 210.0
const CAR_ART := "modern_exteriors/Modern_Exteriors_16x16/ME_Theme_Sorter_16x16/10_Vehicles_Singles_16x16/ME_Singles_Vehicles_16x16_Car_%s_3.png"

@export var walk_speed: float = 72.0
@export var sprint_speed: float = 118.0
## Set by hazards such as flood water (1.0 = normal).
var wading := 1.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
## Distance in front of the feet where the interaction sensor sits.
@export var reach: float = 11.0

var facing: Vector2 = Vector2.DOWN
var combat_enabled := false
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox

var _focused: Interactable = null
var _focus_mark: FocusMark = null
var driving := false
## While in a room shown in place, only that room's things can be used.
var focus_root: Node = null
var _car: Sprite2D
var _car_dir := "Left"
var _dir: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN
var _action_anim_time := 0.0  # while > 0, punch/hurt animation owns the sprite
var _attack_ready_at := 0.0
var _combo_index := 0
var _attacks := 0
var _echo_strike_until := 0.0
var _swing: WeaponSwing
var _combo_expires_at := 0.0
var _knockback := Vector2.ZERO
var _fainting := false
var _hold_start := -1.0
var _charge := 0.0
var _counter_until := 0.0
## Hits landed in a row without being hurt.
var streak := 0
var _dodge_time := 0.0
var _dodge_dir := Vector2.ZERO
var _dodge_ready_at := 0.0
var _flash_ready_at := 0.0
var _afterimage_timer := 0.0
var _shake := 0.0

@onready var sprite: LayeredCharacterSprite = $Sprite
@onready var sensor: Area2D = $InteractionSensor
@onready var camera: Camera2D = $Camera2D
## Where a cutscene glance has moved the camera (look_at_point).
var _look_offset := Vector2.ZERO


func _ready() -> void:
	add_child(ContactShadow.new(), false, Node.INTERNAL_MODE_FRONT)
	_swing = WeaponSwing.new()
	_swing.visible = false
	add_child(_swing)
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
	EventHub.player_heal_requested_amount.connect(_on_heal_amount)
	EventHub.player_stats_changed.connect(_apply_stats)
	EventHub.camera_shake_requested.connect(shake)
	Inventory.changed.connect(_apply_stats)


func _build_combat() -> void:
	health = Health.new()
	health.max_health = max_health()
	health.invulnerability_time = 0.9
	add_child(health)
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.team = &"player"
	hurtbox.health = health
	hurtbox.add_child(EchoEnemy._rect_shape(Vector2(10, 18), Vector2(0, -9)))
	add_child(hurtbox)
	hurtbox.hit.connect(_on_hit)

	hitbox = Hitbox.new()
	hitbox.team = &"player"
	hitbox.add_child(EchoEnemy._rect_shape(Vector2(16, 16), Vector2.ZERO))
	add_child(hitbox)
	_emit_health()


func max_health() -> int:
	return BASE_MAX_HEALTH + int(Inventory.stat("max_health")) + GameState.player_health_bonus()


func _apply_stats() -> void:
	var m := max_health()
	if m != health.max_health:
		var gained := maxi(0, m - health.max_health)
		health.max_health = m
		health.health = clampi(health.health + gained, 1, m)
		_emit_health()


func _emit_health() -> void:
	if combat_enabled:
		EventHub.player_health_changed.emit(health.health, health.max_health)
	else:
		EventHub.player_health_changed.emit(0, 0)


# --- Frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not _is_blocked():
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# get_vector already clamps diagonals to length 1 (no faster diagonal movement).
	var speed := (sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed) * Inventory.stat("speed_mult")
	if driving:
		speed = DRIVE_SPEED
	if _action_anim_time > 0.0:
		_action_anim_time -= delta
		speed *= 0.35  # committed to the swing
	speed *= wading

	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity = _dodge_dir * DODGE_SPEED * Inventory.stat("dodge_distance_mult")
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.035
			CombatFx.afterimage(sprite, get_parent())
	elif input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, acceleration * delta * (0.6 if driving else 1.0))
		if driving:
			_steer_car(input)
		elif _action_anim_time <= 0.0:
			_face(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if _action_anim_time <= 0.0:
		sprite.play(&"walk" if velocity.length() > 8.0 else &"idle", _dir)
	_update_blink()
	_update_focus()
	_update_shake(delta)
	if combat_enabled:
		_report_cooldowns()
		_update_charge()


func _unhandled_input(event: InputEvent) -> void:
	if _is_blocked():
		return
	if driving:
		if event.is_action_pressed(&"interact"):
			get_viewport().set_input_as_handled()
			stop_driving()
		return
	if event is InputEventMouseButton and event.pressed:
		_on_mouse_click(event as InputEventMouseButton)
	if event.is_action_pressed(&"interact"):
		if _focused != null and is_instance_valid(_focused):
			get_viewport().set_input_as_handled()
			_focused.interact(self)
	elif not combat_enabled:
		return
	elif event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()
		_hold_start = _now()
		_attack()
	elif event.is_action_pressed(&"dodge"):
		get_viewport().set_input_as_handled()
		_dodge()
	elif event.is_action_pressed(&"ability"):
		get_viewport().set_input_as_handled()
		_flash()
	elif event.is_action_pressed(&"quick_heal"):
		get_viewport().set_input_as_handled()
		_quick_heal()


# --- Driving ---------------------------------------------------------------------

## Gets into your own car: you see the car instead of yourself, it is much
## faster than walking, and the interact key gets you out where you are,
## leaving the car parked there for next time.
func start_driving() -> void:
	if driving:
		return
	driving = true
	_car = Sprite2D.new()
	_car.centered = false
	add_child(_car)
	_steer_car(Vector2(facing.x if absf(facing.x) > 0.1 else -1.0, 0.0))
	sprite.visible = false
	_focused = null
	EventHub.interaction_focus_changed.emit("")
	EventHub.toast_requested.emit(tr("TOAST_DRIVING"))


func stop_driving() -> void:
	if not driving:
		return
	driving = false
	velocity = Vector2.ZERO
	sprite.visible = true
	if _car != null:
		_car.queue_free()
		_car = null
	EventHub.car_parked.emit(global_position + Vector2(0, 2), _car_dir)


func _steer_car(input: Vector2) -> void:
	var d := _car_dir
	if absf(input.x) >= absf(input.y):
		d = "Left" if input.x < 0.0 else "Right"
	else:
		d = "Up" if input.y < 0.0 else "Down"
	if d == _car_dir and _car.texture != null:
		return
	_car_dir = d
	var tex := AssetLibrary.load_texture(CAR_ART % d)
	if tex == null:
		tex = AssetLibrary.placeholder(Vector2i(48, 32) if d in ["Left", "Right"] else Vector2i(32, 48), Color(0.3, 0.6, 0.5))
	_car.texture = tex
	var sz := tex.get_size()
	_car.offset = Vector2(-sz.x / 2.0, -sz.y + 4.0)


# --- Mouse -----------------------------------------------------------------------

## The mouse aims: in the Veil a left click strikes towards the pointer.
## Walking is WASD and using things is the interact key; the right button is
## kept free for later.
func _on_mouse_click(e: InputEventMouseButton) -> bool:
	if e.button_index == MOUSE_BUTTON_LEFT and combat_enabled:
		_face((get_canvas_transform().affine_inverse() * e.position - global_position).normalized())
	return false


# --- Actions -------------------------------------------------------------------

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _attack() -> void:
	var now := _now()
	if now < _attack_ready_at or _dodge_time > 0.0:
		return
	var w := Inventory.weapon()
	var combo: Array = w.get("combo", [1, 1, 2])
	if now > _combo_expires_at:
		_combo_index = 0
	var damage := int(combo[_combo_index % combo.size()])
	var is_finisher := _combo_index % combo.size() == combo.size() - 1
	_attacks += 1
	if Progression.has_special("spark") and _attacks % 5 == 0:
		damage += 2
		Sfx.play(&"flash", 0.1, -8.0)
	if Progression.has_special("echo_strike") and now < _echo_strike_until:
		damage += 3
		_echo_strike_until = 0.0
	if is_finisher:
		damage += int(Inventory.stat("finisher_bonus"))
	damage += int(Inventory.stat("damage_bonus"))
	var countering := _take_counter()
	if countering:
		damage *= 2
	var cooldown := float(w.get("cooldown", 0.36)) * (1.35 if is_finisher else 1.0)
	_attack_ready_at = now + cooldown
	_combo_expires_at = now + cooldown + COMBO_WINDOW
	_combo_index = (_combo_index + 1) % combo.size()
	_action_anim_time = cooldown * 0.8
	var weapon_reach := float(w.get("reach", 12))
	hitbox.position = facing * (weapon_reach * 0.9) + Vector2(0, -10)
	hitbox.scale = Vector2.ONE * clampf(weapon_reach / 12.0, 0.8, 1.5)
	hitbox.damage = damage
	hitbox.knockback = float(w.get("knockback", 140)) * (1.5 if is_finisher or countering else 1.0)
	sprite.play(&"punch", _dir, true)
	Sfx.play(&"swing", 0.1)
	var style := String(w.get("style", "fists"))
	_swing.show_attack(String(Inventory.def(Inventory.equipped.get("weapon", Inventory.DEFAULT_WEAPON)).get("icon", "")), style, facing, cooldown, is_finisher)
	var bolt_on := String(w.get("bolt_on", ""))
	if bolt_on == "every" or (bolt_on == "finisher" and is_finisher):
		var b := Bolt.new()
		b.dir = facing
		b.damage = int(w.get("bolt", 1)) + int(Inventory.stat("damage_bonus"))
		b.range_left = float(w.get("bolt_range", 140))
		b.pierce = bool(w.get("pierce", false))
		b.color = Color(1.0, 0.8, 0.5) if style == "sling" else Color(0.7, 0.9, 1.0)
		b.global_position = global_position + facing * 8.0
		get_parent().add_child(b)
	await get_tree().create_timer(0.09, false).timeout
	if not is_inside_tree() or _fainting:
		return
	var hits := hitbox.strike()
	if hits > 0:
		Sfx.play(&"hit_heavy" if is_finisher or countering else &"hit")
		CombatFx.hitstop(0.07 if is_finisher or countering else 0.04)
		shake(3.0 if is_finisher or countering else 1.5)
		_add_streak(hits)


func _dodge() -> void:
	var now := _now()
	if now < _dodge_ready_at or _dodge_time > 0.0:
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_dodge_dir = input.normalized() if input != Vector2.ZERO else facing
	_dodge_time = DODGE_TIME
	_dodge_ready_at = now + DODGE_COOLDOWN * Inventory.stat("dodge_cooldown_mult")
	_action_anim_time = 0.0
	_knockback = Vector2.ZERO
	health.grant_invulnerability(DODGE_IFRAMES)
	Sfx.play(&"dodge")
	_check_perfect_dodge()
	if Progression.has_special("echo_strike"):
		_echo_strike_until = now + DODGE_TIME + 1.5
	if Progression.has_special("veil_step"):
		_veil_step_hit()


## Veil step (talent): passing through echoes in a dodge clips them once.
func _veil_step_hit() -> void:
	await get_tree().create_timer(DODGE_TIME * 0.6, false).timeout
	if not is_inside_tree():
		return
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		var n := e as Node2D
		if n != null and n.global_position.distance_to(global_position) < 18.0:
			var hb := n.find_child("Hurtbox", true, false) as Hurtbox
			if hb != null:
				hb.receive(1, global_position, 60.0)


func _flash() -> void:
	var now := _now()
	if now < _flash_ready_at:
		return
	_flash_ready_at = now + FLASH_COOLDOWN * Inventory.stat("flash_cooldown_mult")
	var radius := FLASH_RADIUS * Inventory.stat("flash_radius_mult")
	var stun := FLASH_STUN + Inventory.stat("flash_stun_bonus")
	var pulse := FlashPulse.new()
	pulse.radius = radius
	pulse.global_position = global_position
	get_parent().add_child(pulse)
	Sfx.play(&"flash", 0.02)
	shake(1.0)
	var caught := 0
	for group in [&"echo_enemy", &"boss"]:
		for e in get_tree().get_nodes_in_group(group):
			var n := e as Node2D
			if n != null and n.global_position.distance_to(global_position) <= radius + 8.0 and n.has_method("stun"):
				n.call("stun", stun)
				caught += 1
	if caught > 0 and Progression.has_special("flash_heal"):
		EventHub.player_heal_requested_amount.emit(1)


func _quick_heal() -> void:
	if health.health >= health.max_health:
		return
	for id: StringName in [&"sandwich", &"tea_flask"]:
		if Inventory.has(id) and Inventory.use(id):
			return
	EventHub.toast_requested.emit(tr("TOAST_NO_HEALING"))


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


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _update_shake(delta: float) -> void:
	if _shake <= 0.05:
		camera.offset = _look_offset
		_shake = 0.0
		return
	camera.offset = _look_offset + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	_shake = move_toward(_shake, 0.0, 18.0 * delta)


func _report_cooldowns() -> void:
	var now := _now()
	var dodge_total := DODGE_COOLDOWN * Inventory.stat("dodge_cooldown_mult")
	var flash_total := FLASH_COOLDOWN * Inventory.stat("flash_cooldown_mult")
	EventHub.ability_cooldown.emit("dodge", clampf((_dodge_ready_at - now) / dodge_total, 0.0, 1.0))
	EventHub.ability_cooldown.emit("flash", clampf((_flash_ready_at - now) / flash_total, 0.0, 1.0))


func _face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	_dir = LayeredCharacterSprite.dir_from_vector(dir, _dir)
	sensor.position = Vector2(facing.x, facing.y) * reach + Vector2(0, -4)


func _is_blocked() -> bool:
	return _fainting or GameState.is_player_locked() or SceneFlow.is_transitioning or get_tree().paused


func _update_focus() -> void:
	var best: Interactable = null
	if not _is_blocked() and not driving:
		var best_score := -INF
		for area in sensor.get_overlapping_areas():
			if focus_root != null and is_instance_valid(focus_root) and not focus_root.is_ancestor_of(area):
				continue
			var it := area as Interactable
			if it == null or not it.can_interact(self):
				continue
			var dist := it.global_position.distance_to(sensor.global_position)
			var score := it.interaction_priority * 1000.0 - dist
			if score > best_score:
				best_score = score
				best = it
	if best != _focused:
		_focused = best
		EventHub.interaction_focus_changed.emit(best.get_prompt() if best != null else "")
	_place_focus_mark()


## A small bobbing pointer over whatever E would use, so it is always clear
## which of two nearby things you are about to read, open or talk to.
func _place_focus_mark() -> void:
	if _focus_mark == null:
		_focus_mark = FocusMark.new()
		_focus_mark.top_level = true
		_focus_mark.z_index = 50
		add_child(_focus_mark)
	_focus_mark.visible = _focused != null and is_instance_valid(_focused) and not DialogueService.is_active
	if _focus_mark.visible:
		var top := _focused.global_position.y - _focused.area_size.y / 2.0
		_focus_mark.global_position = Vector2(_focused.global_position.x, minf(top, _focused.global_position.y - 10.0) - 6.0)


# --- Heavy blow, perfect dodge, streak (R15a) ------------------------------------

func _update_charge() -> void:
	if _hold_start < 0.0:
		return
	if Input.is_action_pressed(&"attack") and not _is_blocked() and _dodge_time <= 0.0:
		var t := _now() - _hold_start
		if t > CHARGE_START:
			var was := _charge
			_set_charge(clampf((t - CHARGE_START) / (CHARGE_FULL - CHARGE_START), 0.0, 1.0))
			if was < 1.0 and _charge >= 1.0:
				Sfx.play(&"flash", 0.1, -12.0)
				CombatFx.flash_ring(get_parent(), global_position + Vector2(0, -8), 12.0, Color(1, 0.85, 0.5, 0.8))
		return
	var full := _charge >= 1.0
	_hold_start = -1.0
	_set_charge(0.0)
	if full and not _is_blocked():
		_heavy()


func _set_charge(c: float) -> void:
	_charge = c
	var a := sprite.modulate.a
	if c <= 0.0:
		sprite.modulate = Color(1, 1, 1, a)
	else:
		var pulse := 0.5 + 0.5 * sin(_now() * (14.0 if c >= 1.0 else 6.0))
		var tint := Color(1, 1, 1).lerp(Color(1.45, 1.3, 1.05), c * (0.55 + 0.45 * pulse))
		sprite.modulate = Color(tint.r, tint.g, tint.b, a)


## A heavy blow all around: more damage, hard knockback, knocks echoes off
## balance.
func _heavy() -> void:
	var now := _now()
	var w := Inventory.weapon()
	var combo: Array = w.get("combo", [1, 1, 2])
	var damage := int(combo.max()) + 1 + int(Inventory.stat("damage_bonus")) + int(Inventory.stat("finisher_bonus"))
	var countering := _take_counter()
	if countering:
		damage *= 2
	_attack_ready_at = now + 0.45
	_combo_index = 0
	_action_anim_time = 0.4
	sprite.play(&"punch", _dir, true)
	Sfx.play(&"swing", 0.1, 2.0)
	CombatFx.flash_ring(get_parent(), global_position + Vector2(0, -8), HEAVY_RADIUS + 8.0, Color(1, 0.8, 0.45, 0.85))
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HEAVY_RADIUS
	q.shape = circle
	q.transform = Transform2D(0.0, global_position + Vector2(0, -8))
	q.collision_mask = Hurtbox.LAYER_COMBAT
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hits := 0
	for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var hb := r["collider"] as Hurtbox
		if hb != null and hb.team != &"player" and hb.receive(damage, global_position, 280.0):
			hits += 1
	if hits > 0:
		Sfx.play(&"hit_heavy")
		CombatFx.hitstop(0.09)
		shake(4.0)
		_add_streak(hits)


func _take_counter() -> bool:
	if _now() >= _counter_until:
		return false
	_counter_until = 0.0
	CombatFx.text_pop(get_parent(), global_position + Vector2(0, -6), tr("COMBAT_COUNTER"), Color(0.6, 0.9, 1.0))
	return true


## A dodge in the last instant before a blow lands: the Echo.
func _check_perfect_dodge() -> void:
	var threat := false
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if e.has_method("is_threatening") and e.is_threatening(global_position):
			threat = true
			break
	if not threat:
		for s in get_tree().get_nodes_in_group(&"memory_shard"):
			if (s as Node2D).global_position.distance_to(global_position + Vector2(0, -8)) < 26.0:
				threat = true
				break
	if not threat:
		return
	_counter_until = _now() + COUNTER_TIME
	health.grant_invulnerability(0.5)
	Sfx.play(&"flash", 0.1, -6.0)
	CombatFx.flash_ring(get_parent(), global_position + Vector2(0, -8), 30.0, Color(0.6, 0.85, 1.0, 0.8))
	CombatFx.text_pop(get_parent(), global_position, tr("COMBAT_PERFECT"), Color(0.6, 0.9, 1.0), 11)
	CombatFx.slowmo(0.45, 0.3)
	EventHub.perfect_dodge.emit()


func _add_streak(hits: int) -> void:
	var before := streak / 5
	streak += hits
	if streak / 5 > before:
		CombatFx.text_pop(get_parent(), global_position + Vector2(0, -10), tr("COMBAT_STREAK") % streak, Color(1, 0.9, 0.5), 10)


# --- Combat reactions ----------------------------------------------------------

func _on_hit(damage: int, from_position: Vector2, knockback: float) -> void:
	if streak >= 5:
		CombatFx.text_pop(get_parent(), global_position, tr("COMBAT_STREAK_LOST"), Color(0.8, 0.8, 0.85))
	streak = 0
	_hold_start = -1.0
	_set_charge(0.0)
	var away := (global_position - from_position).normalized()
	if away == Vector2.ZERO:
		away = -facing
	_knockback = away * knockback
	_action_anim_time = 0.3
	_dodge_time = 0.0
	sprite.play(&"hurt", _dir, true)
	Sfx.play(&"hurt")
	shake(4.0)
	CombatFx.hitstop(0.08)
	CombatFx.damage_number(get_parent(), global_position, damage, Color(1, 0.45, 0.45))


func _on_health_changed(_h: int, _m: int) -> void:
	_emit_health()


func _update_blink() -> void:
	if health != null and health.is_invulnerable() and not health.is_dead() and _dodge_time <= 0.0:
		sprite.visible = int(Time.get_ticks_msec() / 80) % 2 == 0
	else:
		sprite.visible = true


func _on_heal_requested() -> void:
	health.heal_full()


func _on_heal_amount(amount: int) -> void:
	health.heal(amount)
	CombatFx.damage_number(get_parent(), global_position, amount, Color(0.5, 1, 0.6))


## Fainting returns the player to their room; money and Resonance stay
## behind in a satchel where they fell (GameState.drop_satchel).
func _on_died() -> void:
	_fainting = true
	var in_run := Expedition.fail()
	if in_run:
		GameState.drop_satchel(Expedition.RETURN_SCENE, Expedition.SATCHEL_AT)
	else:
		GameState.drop_satchel(GameState.current_scene_id, global_position)
	GameState.set_flag(&"veil.fainted_once", true)
	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.8)
	await t.finished
	if in_run:
		EventHub.toast_requested.emit(tr("EXP_TOAST_FAILED"))
		SceneFlow.travel(Expedition.RETURN_SCENE, Expedition.RETURN_SPAWN)
		return
	GameState.set_flag(&"veil.just_fainted", true)
	SceneFlow.travel(&"rented_room", &"bed")


## A cutscene glance (story effect camera_look): the camera glides to a world
## point and stays until camera_back (Vector2.INF) brings it home.
func look_at_point(point: Vector2) -> void:
	var target := Vector2.ZERO
	if point != Vector2.INF:
		# Frame the point in the upper half (the dialogue panel covers the
		# bottom), and never past the edges of the map.
		var half := get_viewport_rect().size * 0.5
		var c := point + Vector2(0, half.y * 0.35)
		c.x = clampf(c.x, camera.limit_left + half.x, camera.limit_right - half.x)
		c.y = clampf(c.y, camera.limit_top + half.y, camera.limit_bottom - half.y)
		target = c - global_position
	var tw := create_tween()
	tw.tween_property(self, "_look_offset", target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Walls and furniture of an in-place room instead of the street.
func enter_room_layer(room: Node) -> void:
	focus_root = room
	collision_mask = Location.LAYER_ROOM
	z_index = 2


func leave_room_layer() -> void:
	focus_root = null
	collision_mask = LAYER_WORLD | LAYER_NPC
	z_index = 0
