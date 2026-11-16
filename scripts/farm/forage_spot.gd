@tool
class_name ForageSpot
extends Interactable
## Something that grows wild (R5b): mushrooms, a berry bush. Gather it once a
## day; it is back the next morning. The day it was picked is kept in the
## flag "forage.<forage_id>".

@export var forage_id: StringName = &""
@export var item_id: StringName = &""
@export var amount := 1
@export var texture_path := ""
## Drawn after picking (a bare bush); empty = nothing.
@export var picked_texture_path := ""

var _tex: Texture2D
var _picked_tex: Texture2D


func _init() -> void:
	prompt_key = "PROMPT_GATHER"
	interaction_priority = 8
	area_size = Vector2(16, 14)


func _ready() -> void:
	super._ready()
	if interaction_id == &"":
		interaction_id = StringName("forage_%s" % forage_id)
	if Engine.is_editor_hint():
		return
	_tex = AssetLibrary.load_texture(texture_path)
	_picked_tex = AssetLibrary.load_texture(picked_texture_path) if picked_texture_path != "" else null
	WorldClock.day_started.connect(func(_d: int) -> void: _sync())
	_sync()


func _flag() -> StringName:
	return StringName("forage.%s" % forage_id)


func available() -> bool:
	return int(GameState.get_flag(_flag(), -1)) != WorldClock.day


func _sync() -> void:
	enabled = available()
	set_deferred("monitorable", enabled)
	queue_redraw()


func _on_interact(_actor: Node) -> void:
	if not available():
		return
	GameState.set_flag(_flag(), WorldClock.day)
	Inventory.add(item_id, amount)
	_sync()


func _draw() -> void:
	var t := _tex if Engine.is_editor_hint() or available() else _picked_tex
	if t == null:
		if Engine.is_editor_hint():
			draw_rect(Rect2(-6, -10, 12, 10), Color(0.6, 0.4, 0.3, 0.6))
		return
	draw_texture(t, Vector2(-t.get_width() / 2.0, 6 - t.get_height()))
