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
@onready var work: WorkScreen = $Work
@onready var repair: RepairMinigame = $Repair
@onready var epilogue: EpilogueScreen = $Epilogue
var sport: SportMinigame


func _ready() -> void:
	add_child(WaitMenu.new())
	sport = SportMinigame.new()
	add_child(sport)
	pause_menu.setup(hud)
	journal.setup(hud)
	SceneFlow.register_root(self)
	EventHub.screen_requested.connect(_on_screen_requested)
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


## Opens a work/trade screen once any running conversation has finished.
func _on_screen_requested(screen: String) -> void:
	if DialogueService.is_active:
		await DialogueService.dialogue_ended
		await get_tree().process_frame
	if screen == "match:football":
		var loc := SceneFlow.current_location
		if loc != null and loc.location_id == &"greyford_park" and loc.find_children("*", "FootballMatch", true, false).is_empty():
			var m := FootballMatch.new()
			loc.add_child(m)
			m.start(loc)
	elif screen.begins_with("sport:"):
		sport.start(screen.trim_prefix("sport:"))
	elif screen.begins_with("repair:"):
		repair.start(StringName(screen.trim_prefix("repair:")))
	elif screen == "epilogue":
		epilogue.open()
		await epilogue.finished
		# The world goes on in its new state: morning, in your room.
		WorldClock.sleep_until_hour(8)
		SceneFlow.travel(&"rented_room", &"bed")
	else:
		work.open(screen)


func show_menu(menu: Node) -> void:
	hide_menu()
	menu_layer.add_child(menu)


func hide_menu() -> void:
	for child in menu_layer.get_children():
		child.queue_free()
