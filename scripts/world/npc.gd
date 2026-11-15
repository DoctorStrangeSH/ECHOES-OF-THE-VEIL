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

@onready var _sprite: LayeredCharacterSprite = $Sprite
@onready var _talk: TalkInteractable = $Talk


func _ready() -> void:
	collision_layer = LAYER_NPC
	collision_mask = 0
	_configure()
	if not Engine.is_editor_hint():
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


func _on_talked(actor: Node) -> void:
	if actor is Node2D:
		var to_actor: Vector2 = (actor as Node2D).global_position - global_position
		_sprite.play(&"idle", LayeredCharacterSprite.dir_from_vector(to_actor, facing))


func _on_dialogue_ended(_id: StringName) -> void:
	_sprite.play(&"idle", facing)
