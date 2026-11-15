@tool
class_name Npc
extends StaticBody2D
## A standing NPC with a LimeZu premade or generated look and simple talk
## lines. Schedules, memory and dialogue graphs arrive in M2/M4; this keeps
## the stable-ID contract those systems will build on.

const LAYER_NPC := 1 << 3

@export var npc_id: StringName = &""
@export var name_key: String = ""
@export var premade: String = "Premade_Character_05":
	set(value):
		premade = value
		_apply_look()
@export var placeholder_color: Color = Color(0.8, 0.45, 0.4):
	set(value):
		placeholder_color = value
		_apply_look()
@export var facing: LayeredCharacterSprite.Dir = LayeredCharacterSprite.Dir.DOWN:
	set(value):
		facing = value
		_apply_look()
@export var lines: PackedStringArray = []
@export var repeat_lines: PackedStringArray = []
@export var sets_flag: StringName = &""

@onready var _sprite: LayeredCharacterSprite = $Sprite
@onready var _talk: InspectInteractable = $Talk


func _ready() -> void:
	collision_layer = LAYER_NPC
	collision_mask = 0
	_apply_look()
	if Engine.is_editor_hint():
		return
	_talk.interaction_id = StringName("talk_%s" % npc_id)
	_talk.prompt_key = "PROMPT_TALK"
	_talk.priority = 20
	_talk.speaker_key = name_key
	_talk.lines = lines
	_talk.repeat_lines = repeat_lines
	_talk.sets_flag = sets_flag
	_talk.interacted.connect(_on_talked)


func _apply_look() -> void:
	if _sprite == null:
		return
	_sprite.appearance = CharacterAppearance.from_premade(premade, placeholder_color)
	_sprite.play(&"idle", facing)


func _on_talked(actor: Node) -> void:
	# Turn to face whoever is talking.
	if actor is Node2D:
		var to_actor: Vector2 = (actor as Node2D).global_position - global_position
		_sprite.play(&"idle", LayeredCharacterSprite.dir_from_vector(to_actor, facing))
