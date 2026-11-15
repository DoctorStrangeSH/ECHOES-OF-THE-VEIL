extends Node
## Application root and scene-flow boundary. Owns the World container
## (locations are swapped in and out here), the persistent HUD and pause
## menu, and the menu layer. Registers itself with SceneFlow.

@onready var world: Node2D = $World
@onready var menu_layer: CanvasLayer = $MenuLayer
@onready var hud: Hud = $Hud
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var journal: JournalScreen = $Journal
@onready var inventory: InventoryScreen = $Inventory


func _ready() -> void:
	pause_menu.setup(hud)
	journal.setup(hud)
	SceneFlow.register_root(self)
	SceneFlow.show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_playing or SceneFlow.is_transitioning or get_tree().paused:
		return
	if event.is_action_pressed(&"quick_save") and not hud.dialogue_open:
		get_viewport().set_input_as_handled()
		SaveService.save_game()
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		if SaveService.has_save():
			SaveService.load_game()
		else:
			EventHub.toast_requested.emit(tr("TOAST_NO_SAVE"))


func show_menu(menu: Node) -> void:
	hide_menu()
	menu_layer.add_child(menu)


func hide_menu() -> void:
	for child in menu_layer.get_children():
		child.queue_free()
