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
var city_map: MapScreen
var world_map: WorldMapScreen
var fishing: FishingMinigame


func _ready() -> void:
	add_child(WaitMenu.new())
	sport = SportMinigame.new()
	add_child(sport)
	city_map = MapScreen.new()
	add_child(city_map)
	world_map = WorldMapScreen.new()
	add_child(world_map)
	fishing = FishingMinigame.new()
	add_child(fishing)
	add_child(CharacterScreen.new())
	add_child(SeedMenu.new())
	pause_menu.setup(hud)
	journal.setup(hud)
	SceneFlow.register_root(self)
	EventHub.screen_requested.connect(_on_screen_requested)
	Journal.case_changed.connect(func(_c: StringName) -> void: _queue_chronicle())
	EventHub.flag_changed.connect(func(f: StringName, _v: Variant) -> void:
		if f != Chronicle.SEEN_FLAG:
			_queue_chronicle())
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
	if screen == "train:gym":
		_train()
	elif screen == "map:travel":
		city_map.open(true)
	elif screen == "world:travel":
		world_map.open()
	elif screen == "world:drive":
		world_map.open(true)
	elif screen == "map:drive":
		if WorldMap.city_of(GameState.current_scene_id) != WorldMap.HOME:
			world_map.open(true)  # out of town the car only knows the coast road
		else:
			CityMap.driving = true
			city_map.open(true)
	elif screen.begins_with("fish:"):
		fishing.start(screen.trim_prefix("fish:"))
	elif screen == "match:football":
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


var _chronicle_queued := false


## A new page of the Chronicle gets a quiet toast, once things settle.
func _queue_chronicle() -> void:
	if _chronicle_queued:
		return
	_chronicle_queued = true
	await get_tree().create_timer(0.5, true).timeout
	while DialogueService.is_active:
		await DialogueService.dialogue_ended
	_chronicle_queued = false
	if Chronicle.check_new():
		EventHub.toast_requested.emit(tr("CHRON_TOAST_NEW"))


func show_menu(menu: Node) -> void:
	hide_menu()
	menu_layer.add_child(menu)


func hide_menu() -> void:
	for child in menu_layer.get_children():
		child.queue_free()


## A session at Sol's gym: an hour, some sweat, experience once a day.
func _train() -> void:
	var flag := &"gym.trained_day"
	if int(GameState.get_flag(flag, -1)) == WorldClock.day:
		EventHub.toast_requested.emit(tr("GYM_ALREADY"))
		return
	GameState.set_flag(flag, WorldClock.day)
	WorldClock.advance_minutes(60)
	Progression.add_xp(25)
	EventHub.toast_requested.emit(tr("GYM_TRAINED"))
