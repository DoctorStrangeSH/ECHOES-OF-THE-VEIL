extends Node
## Safe scene changes with fades and spawn routing.
##
## Locations are instanced under GameRoot's World node, so the HUD, pause menu
## and this fade overlay persist across transitions. Callers never reference
## node paths in other scenes: they pass a scene ID and a spawn ID.
## Owner: scene_flow. Tests: tests/run_tests.gd (registry), manual: doors both ways.

signal location_entered(scene_id: StringName)
signal transition_started
signal transition_finished

## Scene registry: stable ID -> scene path. Every scene in scenes/locations is
## registered by its file name; nothing to add by hand.
var LOCATIONS: Dictionary = DataFiles.location_scenes()
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const CHARACTER_CREATOR := "res://scenes/ui/character_creator.tscn"
const FADE_TIME := 0.25

var is_transitioning := false
var current_location: Node = null

var _root = null  # GameRoot (untyped: uses its world/show_menu/hide_menu API)
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Called by GameRoot once it is ready.
func register_root(root: Node) -> void:
	_root = root


func has_location(scene_id: StringName) -> bool:
	return LOCATIONS.has(scene_id)


func show_main_menu() -> void:
	GameState.is_playing = false
	await _transition(_swap_to_menu)


## Opens the character creator; it calls begin_new_game() when confirmed.
func start_new_game() -> void:
	await _transition(_swap_to_creator)


## profile: {name, pronouns, background, appearance: CharacterAppearance}
func begin_new_game(profile: Dictionary) -> void:
	GameState.reset_for_new_game()
	GameState.player_name = String(profile.get("name", "Alex"))
	GameState.pronouns = String(profile.get("pronouns", "they"))
	GameState.background = StringName(profile.get("background", "returning_local"))
	GameState.difficulty = String(profile.get("difficulty", "normal"))
	if profile.get("appearance") is CharacterAppearance:
		GameState.player_appearance = profile["appearance"]
	GameState.set_flag(StringName("background.%s" % GameState.background), true)
	Inventory.money = 20
	enter_game_from_state()


## Enters GameState.current_scene_id (used by New Game and Load).
func enter_game_from_state() -> void:
	await _enter_location(GameState.current_scene_id)


## Moves the player to another location through a door/exit.
func travel(scene_id: StringName, spawn_id: StringName) -> void:
	if is_transitioning:
		return
	if not has_location(scene_id):
		push_error("SceneFlow: unknown location '%s'" % scene_id)
		EventHub.toast_requested.emit(tr("TOAST_PATH_BLOCKED"))
		return
	GameState.current_scene_id = scene_id
	GameState.current_spawn_id = spawn_id
	GameState.pending_position = null
	await _enter_location(scene_id)


func _enter_location(scene_id: StringName) -> void:
	if not has_location(scene_id):
		push_error("SceneFlow: unknown location '%s', falling back to new-game start" % scene_id)
		scene_id = GameState.NEW_GAME_SCENE
		GameState.current_scene_id = scene_id
		GameState.current_spawn_id = GameState.NEW_GAME_SPAWN
		GameState.pending_position = null
	await _transition(_swap_to_location.bind(scene_id))
	location_entered.emit(scene_id)


func _swap_to_creator() -> void:
	_clear_world()
	_root.show_menu(load(CHARACTER_CREATOR).instantiate())


func _swap_to_menu() -> void:
	_clear_world()
	_root.show_menu(load(MAIN_MENU).instantiate())


func _swap_to_location(scene_id: StringName) -> void:
	_clear_world()
	_root.hide_menu()
	var scene: PackedScene = load(LOCATIONS[scene_id])
	current_location = scene.instantiate()
	_root.world.add_child(current_location)
	GameState.is_playing = true


func _clear_world() -> void:
	if current_location != null and is_instance_valid(current_location):
		current_location.get_parent().remove_child(current_location)
		current_location.queue_free()
	current_location = null


func _transition(swap: Callable) -> void:
	if _root == null:
		push_error("SceneFlow: GameRoot not registered")
		return
	is_transitioning = true
	transition_started.emit()
	get_tree().paused = false
	await _tween_fade(1.0)
	swap.call()
	await get_tree().process_frame
	await _tween_fade(0.0)
	is_transitioning = false
	transition_finished.emit()


func _tween_fade(alpha: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
