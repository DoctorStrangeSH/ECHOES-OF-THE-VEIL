class_name Follower
extends Node
## Turns an Npc into the player's companion: it trails the player, talks with
## its camp dialogue and uses its ability in fights. Added by Location.
##   patch_up - when the player drops to 1 health, heals `power` (once per cooldown)
##   pin      - in fights, slows the `power` nearest echoes for a few seconds
##   beam     - in fights, a lamp flash slows every echo within BEAM_RADIUS
##              for `power` seconds
## Personal quests and the bond upgrade them (companions.json "upgrade" and
## "upgrades": the later entries that hold win).

const TRAIL := 22.0
const SPEED := 95.0
const TELEPORT := 170.0
const BEAM_RADIUS := 160.0

var npc: Npc
var ability := ""
var cooldown := 0.0
## patch_up: health restored; pin: how many echoes are slowed at once.
var power := 1
var _ready_at := 0.0
var _sprite: LayeredCharacterSprite
var _last_dir := LayeredCharacterSprite.Dir.DOWN


func setup(target: Npc, def: Dictionary) -> void:
	npc = target
	ability = String(def.get("ability", ""))
	cooldown = float(def.get("cooldown", 30.0))
	power = int(def.get("power", 2 if ability == "patch_up" else 1))
	# Personal quests can improve the ability: {"upgrade": {"if": cond, "power": n, "cooldown": s}}
	var ups: Array = []
	if def.has("upgrade"):
		ups.append(def["upgrade"])
	ups.append_array(def.get("upgrades", []))
	for up: Dictionary in ups:
		if StoryRules.evaluate(up.get("if")):
			power = int(up.get("power", power))
			cooldown = float(up.get("cooldown", cooldown))
	npc.collision_layer = 0  # never blocks the player
	npc.add_child(self)


func _ready() -> void:
	_sprite = npc.get_node("Sprite") as LayeredCharacterSprite
	var def := Party.def_of(npc.npc_id)
	var talk := npc.get_node("Talk") as TalkInteractable
	if def.has("camp_dialogue"):
		talk.dialogue_id = StringName(def["camp_dialogue"])
	EventHub.player_health_changed.connect(_on_player_health)
	_snap_to_player.call_deferred()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _snap_to_player() -> void:
	var p := _player()
	if p != null:
		npc.global_position = p.global_position + Vector2(-TRAIL, 4)


func _physics_process(delta: float) -> void:
	var p := _player()
	if p == null or DialogueService.is_active:
		return
	var to_p := p.global_position - npc.global_position
	var dist := to_p.length()
	if dist > TELEPORT:
		_snap_to_player()
		return
	if dist > TRAIL:
		var step := minf(SPEED * delta * (1.6 if dist > TRAIL * 3 else 1.0), dist - TRAIL)
		npc.global_position += to_p.normalized() * step
		_last_dir = LayeredCharacterSprite.dir_from_vector(to_p, _last_dir)
		_sprite.play(&"walk", _last_dir)
	else:
		_sprite.play(&"idle", _last_dir)
	if ability == "pin":
		_try_pin()
	elif ability == "beam":
		_try_beam()


func _ready_now() -> bool:
	return Time.get_ticks_msec() / 1000.0 >= _ready_at


func _use() -> void:
	_ready_at = Time.get_ticks_msec() / 1000.0 + cooldown
	EventHub.ability_cooldown.emit(StringName("companion_" + ability), cooldown)


func _on_player_health(health: int, _max: int) -> void:
	if ability != "patch_up" or health != 1 or not _ready_now():
		return
	_use()
	EventHub.player_heal_requested_amount.emit(power)
	EventHub.toast_requested.emit(tr("TOAST_COMPANION_PATCH") % tr(Party.def_of(npc.npc_id).get("name", "")))
	Sfx.play(&"use")


func _try_pin() -> void:
	var loc := SceneFlow.current_location as Location
	if loc == null or not loc.combat_enabled or not _ready_now():
		return
	var near: Array[EchoEnemy] = []
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if (e as Node2D).global_position.distance_to(npc.global_position) < 140.0 and (e as EchoEnemy).health.health > 0:
			near.append(e)
	if near.is_empty():
		return
	near.sort_custom(func(a: EchoEnemy, b: EchoEnemy) -> bool: return a.global_position.distance_to(npc.global_position) < b.global_position.distance_to(npc.global_position))
	_use()
	for i in mini(power, near.size()):
		near[i].slow(3.0)
	Sfx.play(&"flash", 0.0, -8.0)


func _try_beam() -> void:
	var loc := SceneFlow.current_location as Location
	if loc == null or not loc.combat_enabled or not _ready_now():
		return
	var hit: Array[EchoEnemy] = []
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		var en := e as EchoEnemy
		if en.global_position.distance_to(npc.global_position) < BEAM_RADIUS and en.health.health > 0:
			hit.append(en)
	if hit.is_empty():
		return
	_use()
	for en in hit:
		en.slow(float(power))
	CombatFx.flash_ring(npc.get_parent(), npc.global_position, BEAM_RADIUS)
	Sfx.play(&"flash", 0.0, -4.0)
