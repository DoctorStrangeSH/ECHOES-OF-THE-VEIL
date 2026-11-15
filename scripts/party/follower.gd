class_name Follower
extends Node
## Turns an Npc into the player's companion: it trails the player, talks with
## its camp dialogue and uses its ability in fights. Added by Location.
##   patch_up - when the player drops to 1 health, heals 2 (once per cooldown)
##   pin      - in fights, slows the nearest echo for a few seconds

const TRAIL := 22.0
const SPEED := 95.0
const TELEPORT := 170.0

var npc: Npc
var ability := ""
var cooldown := 0.0
var _ready_at := 0.0
var _sprite: LayeredCharacterSprite
var _last_dir := LayeredCharacterSprite.Dir.DOWN


func setup(target: Npc, def: Dictionary) -> void:
	npc = target
	ability = String(def.get("ability", ""))
	cooldown = float(def.get("cooldown", 30.0))
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


func _ready_now() -> bool:
	return Time.get_ticks_msec() / 1000.0 >= _ready_at


func _use() -> void:
	_ready_at = Time.get_ticks_msec() / 1000.0 + cooldown
	EventHub.ability_cooldown.emit(StringName("companion_" + ability), cooldown)


func _on_player_health(health: int, _max: int) -> void:
	if ability != "patch_up" or health != 1 or not _ready_now():
		return
	_use()
	EventHub.player_heal_requested_amount.emit(2)
	EventHub.toast_requested.emit(tr("TOAST_COMPANION_PATCH") % tr(Party.def_of(npc.npc_id).get("name", "")))
	Sfx.play(&"use")


func _try_pin() -> void:
	var loc := SceneFlow.current_location as Location
	if loc == null or not loc.combat_enabled or not _ready_now():
		return
	var best: EchoEnemy = null
	var best_d := 140.0
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		var d := (e as Node2D).global_position.distance_to(npc.global_position)
		if d < best_d and (e as EchoEnemy).health.health > 0:
			best = e
			best_d = d
	if best == null:
		return
	_use()
	best.slow(3.0)
	Sfx.play(&"flash", 0.0, -8.0)
