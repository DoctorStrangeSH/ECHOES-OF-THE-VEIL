@tool
class_name Npc
extends StaticBody2D
## A named NPC. Look, name and dialogue come from data/characters/npcs.json
## (via `npc_id`); where they stand comes from their schedule, applied by the
## Location. Turns to face whoever talks to them.

const LAYER_NPC := 1 << 3
const FADE_TIME := 0.35

@export var npc_id: StringName = &"":
	set(value):
		npc_id = value
		_configure()
@export var facing: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN:
	set(value):
		facing = value
		if _sprite != null:
			_sprite.play(&"idle", facing)

var anchor_id: StringName = &""
## What they do while nobody talks to them (R1d): "" (stand), "look" (glance
## around), "read", "phone", "work" (busy, a few steps to and fro). From the
## schedule entry ("activity"); talking interrupts it.
var activity := ""
var _home := Vector2.ZERO
var _t := 0.0
var _next := 2.0
var _busy := false
var _rng := RandomNumberGenerator.new()

@onready var _sprite: LayeredCharacterSprite = $Sprite
@onready var _talk: TalkInteractable = $Talk


func _ready() -> void:
	collision_layer = LAYER_NPC
	collision_mask = 0
	_configure()
	if not Engine.is_editor_hint():
		add_child(ContactShadow.new(), false, Node.INTERNAL_MODE_FRONT)
		_talk.interacted.connect(_on_talked)
		DialogueService.dialogue_ended.connect(_on_dialogue_ended)


func _configure() -> void:
	if _sprite == null or npc_id == &"":
		return
	var def := NpcRegistry.get_def(npc_id)
	if def.is_empty():
		push_warning("Npc: unknown npc_id '%s'" % npc_id)
		return
	_sprite.appearance = NpcRegistry.appearance_of(def)
	if def.has("tint"):
		_sprite.modulate = Color.html(def["tint"])
	_sprite.play(&"idle", facing)
	_talk.npc_id = npc_id
	_talk.interaction_id = StringName("talk_%s" % npc_id)
	_talk.dialogue_id = StringName(def.get("dialogue", ""))


func fade_in() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)


func fade_out_and_free() -> void:
	_talk.enabled = false
	collision_layer = 0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	t.finished.connect(queue_free)


func set_activity(a: String) -> void:
	activity = a
	_home = position
	_rng.seed = hash(npc_id)
	_next = _rng.randf_range(1.0, 4.0)
	_resume()


func _resume() -> void:
	if _sprite == null:
		return
	match activity:
		"read":
			_sprite.play(&"read", LayeredCharacterSprite.Dir.DOWN)
		"phone":
			var premade := _sprite.appearance != null and not _sprite.appearance.premade.is_empty()
			_sprite.play(&"phone" if premade else &"idle", LayeredCharacterSprite.Dir.DOWN if premade else facing)
		_:
			_sprite.play(&"idle", facing)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _busy or activity in ["", "read", "phone"]:
		return
	_t += delta
	if activity == "work" and position.distance_to(_target) > 0.5:
		var d := _target - position
		position += d.normalized() * minf(d.length(), 14.0 * delta)
		_sprite.play(&"walk", LayeredCharacterSprite.dir_from_vector(d))
		return
	if _t < _next:
		return
	_t = 0.0
	_next = _rng.randf_range(2.5, 6.0)
	if activity == "look":
		var dirs := [facing, facing, LayeredCharacterSprite.Dir.LEFT, LayeredCharacterSprite.Dir.RIGHT, LayeredCharacterSprite.Dir.DOWN]
		_sprite.play(&"idle", dirs[_rng.randi() % dirs.size()])
	elif activity == "work":
		_target = _home + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-3.0, 3.0))
		if _target.distance_to(_home) < 4.0:
			_target = _home
		_sprite.play(&"idle", facing)


var _target := Vector2.ZERO


func _on_talked(actor: Node) -> void:
	_busy = true
	if actor is Node2D:
		var to_actor: Vector2 = (actor as Node2D).global_position - global_position
		_sprite.play(&"idle", LayeredCharacterSprite.dir_from_vector(to_actor, facing))


func _on_dialogue_ended(_id: StringName) -> void:
	_busy = false
	_resume()
