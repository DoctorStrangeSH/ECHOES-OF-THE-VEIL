extends Node
## End-to-end smoke test: boots the real GameRoot and plays through the main
## systems with simulated input, so runtime errors (not just compile errors)
## surface in CI. Run:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = finished; check the log for "SCRIPT ERROR".

const GAME_ROOT := preload("res://scenes/bootstrap/game_root.tscn")

var _step := ""


func _ready() -> void:
	SaveService.save_dir = "user://smoke_saves"
	var root := GAME_ROOT.instantiate()
	add_child(root)
	await _frames(30)

	_step = "new game"
	var look := CharacterAppearance.default_player()
	SceneFlow.begin_new_game({"name": "Smoke", "pronouns": "they", "background": "courier", "appearance": look})
	await _wait_location(&"greyford_block")
	await _frames(20)
	_assert(DialogueService.is_active, "intro dialogue plays")
	await _finish_dialogue()

	_step = "walk"
	await _hold(&"move_right", 0.6)
	await _hold(&"move_up", 0.4)
	_assert(_player().global_position != Vector2.ZERO, "player exists")

	_step = "time + schedules"
	WorldClock.wait_until_hour(13)
	await _frames(10)
	WorldClock.wait_until_hour(19)
	await _frames(10)
	WorldClock.sleep_until_hour(8)
	await _frames(10)

	_step = "dialogue with choices"
	DialogueService.start(&"pike", {"npc": &"dana_pike"})
	await _frames(5)
	await _finish_dialogue()
	DialogueService.start(&"jonah", {"npc": &"jonah_rook"})
	await _frames(5)
	DialogueService.advance()
	await _frames(2)
	DialogueService.advance()
	await _frames(2)
	DialogueService.choose(0)  # accept the radio
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_radio") == Journal.STATUS_ACTIVE, "radio quest started")

	_step = "journal + inventory screens"
	var gr := get_child(0)
	(gr.get_node("Journal") as JournalScreen).open()
	await _frames(5)
	(gr.get_node("Journal") as JournalScreen).close()
	(gr.get_node("Inventory") as InventoryScreen).open()
	await _frames(5)
	(gr.get_node("Inventory") as InventoryScreen).close()

	_step = "rented room"
	SceneFlow.travel(&"rented_room", &"from_street")
	await _wait_location(&"rented_room")
	await _frames(10)

	_step = "echo"
	SceneFlow.travel(&"echo_lantern_row", &"entrance")
	await _wait_location(&"echo_lantern_row")
	await _frames(10)
	await _finish_dialogue()
	await _combat_round()

	_step = "phantom platform"
	Inventory.add(&"signal_rod", 1, false)
	Inventory.equip(&"signal_rod")
	Inventory.add(&"tea_flask", 2, false)
	SceneFlow.travel(&"phantom_platform", &"entrance")
	await _wait_location(&"phantom_platform")
	await _frames(10)
	await _finish_dialogue()
	await _combat_round()

	_step = "boss"
	var boss := get_tree().get_first_node_in_group(&"boss") as CensusTaker
	_assert(boss != null, "boss present")
	if boss != null:
		_player().global_position = boss.global_position + Vector2(-60, 0)
		await _frames(30)
		_assert(boss.state != CensusTaker.State.DORMANT, "boss engaged by arena")
		for i in 160:
			await _frames(12)
			if not is_instance_valid(boss) or boss.state == CensusTaker.State.DEAD:
				break
			if i % 5 == 0:
				_player().global_position = boss.global_position + Vector2(-24, 6)
			boss.health.take_damage(1, _player().global_position)
		_assert(GameState.has_flag(&"boss.census_taker.defeated"), "boss defeated")
		await _frames(60)

	_step = "archive (Mara's story)"
	GameState.set_flag(&"met.mara_venn")
	GameState.set_flag(&"door.decided")
	GameState.change_relationship(&"mara_venn", 3)
	Journal.complete_case(&"case_door", &"opened")
	DialogueService.start(&"mara", {"npc": &"mara_venn"})
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_eleventh") == Journal.STATUS_ACTIVE, "Mara's story starts at friend")
	WorldClock.wait_until_hour(23)
	SceneFlow.travel(&"municipal_archive", &"entrance")
	await _wait_location(&"municipal_archive")
	await _frames(20)
	_assert(get_tree().get_nodes_in_group(&"npc_anchor").size() > 0, "archive anchors")
	DialogueService.start(&"mara", {"npc": &"mara_venn"})
	await _finish_dialogue()
	DialogueService.start(&"census_cabinet")
	await _finish_dialogue()
	_assert(Inventory.has(&"agnes_file"), "file found")
	DialogueService.start(&"mara", {"npc": &"mara_venn"})
	await _frames(3)
	DialogueService.choose(0)
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_eleventh") == Journal.STATUS_DONE, "Mara's story resolved")
	(get_child(0).get_node("Journal") as JournalScreen).open()
	(get_child(0).get_node("Journal") as JournalScreen)._set_tab("people")
	await _frames(5)
	(get_child(0).get_node("Journal") as JournalScreen).close()
	WorldClock.wait_until_hour(9)
	_assert(Society.knows(&"nadiya_sol", &"agnes_signed") or Society.gossip.size() > 0, "gossip queued or spread")
	SceneFlow.travel(&"greyford_block", &"archive_front")
	await _wait_location(&"greyford_block")
	await _frames(20)

	_step = "lighthouse point (region built from data only)"
	SceneFlow.travel(&"lighthouse_point", &"from_greyford")
	await _wait_location(&"lighthouse_point")
	await _frames(20)
	_assert(_npc_present(&"wren_ashby"), "Wren is at the point by day")
	DialogueService.start(&"wren", {"npc": &"wren_ashby"})
	for i in 8:
		DialogueService.choose(0)
		DialogueService.advance()
		await _frames(2)
		if Journal.case_stage(&"case_lighthouse") == &"watch":
			break
	DialogueService.end()
	await _frames(3)
	_assert(Journal.case_stage(&"case_lighthouse") == &"watch", "Wren's case reaches the night watch")
	WorldClock.wait_until_hour(23)
	DialogueService.start(&"lighthouse_watch")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_lighthouse") == &"registry", "counting the flashes advances the case")
	DialogueService.start(&"archive_shelves")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_lighthouse") == &"answer", "the harbour register answers it")
	DialogueService.start(&"wren", {"npc": &"wren_ashby"})
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_lighthouse") == Journal.STATUS_DONE and GameState.has_flag(&"world.lamp_counts"), "Wren's case resolved")
	WorldClock.wait_until_hour(9)
	SceneFlow.travel(&"greyford_block", &"point_steps")
	await _wait_location(&"greyford_block")
	await _frames(10)

	_step = "work: jobs, repair, shop, workbench, stall"
	var gr2 := get_child(0)
	Inventory.money = 200
	Inventory.add(&"scrap", 10, false)
	EventHub.screen_requested.emit("shop:jonah")
	await _frames(5)
	Economy.buy(&"jonah", 0)
	(gr2.get_node("Work") as WorkScreen)._set_sell(true)
	await _frames(3)
	(gr2.get_node("Work") as WorkScreen).close()
	EventHub.screen_requested.emit("shop:halloway")
	await _frames(5)
	Economy.buy(&"halloway", 0)
	(gr2.get_node("Work") as WorkScreen).close()
	EventHub.screen_requested.emit("jobs")
	await _frames(5)
	var job: StringName = Livelihood.offered[0] if not Livelihood.offered.is_empty() else &""
	if job != &"":
		Livelihood.accept(job)
	(gr2.get_node("Work") as WorkScreen).close()
	await _frames(5)
	if job != &"":
		var mg := gr2.get_node("Repair") as RepairMinigame
		mg.start(job)
		await _frames(5)
		for i in 400:
			if not mg._active:
				break
			if absf(mg._needle - mg._zone_center) <= mg._zone_width / 2.5:
				mg._try()
			await get_tree().process_frame
		_assert(Livelihood.done_today.has(job), "repair job completed")
	EventHub.screen_requested.emit("workbench")
	await _frames(3)
	Economy.craft(&"repair_kit")
	(gr2.get_node("Work") as WorkScreen).close()
	GameState.set_flag(&"biz.unlocked")
	EventHub.screen_requested.emit("business")
	await _frames(3)
	Livelihood.stock_stall(99)
	Livelihood.set_stall_open(true)
	(gr2.get_node("Work") as WorkScreen).close()
	WorldClock.sleep_until_hour(8)
	await _frames(10)

	_step = "save/load"
	_assert(SaveService.save_game() == OK, "save ok")
	await _frames(5)
	_assert(SaveService.load_game(), "load ok")
	await _wait_location(&"greyford_block")
	await _frames(10)

	_step = "faint (fail-forward)"
	_player().health.take_damage(99, Vector2.ZERO)
	await _wait_location(&"rented_room", 400)
	await _frames(30)
	await _finish_dialogue()

	_step = "main menu"
	SceneFlow.show_main_menu()
	await _frames(40)
	print("SMOKE TEST FINISHED")
	get_tree().quit(0)


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _combat_round() -> void:
	var p := _player()
	if p == null:
		_assert(false, "player in combat location")
		return
	for i in 6:
		await _tap(&"attack")
		await _frames(12)
	await _tap(&"dodge")
	await _frames(10)
	await _tap(&"ability")
	await _frames(10)
	p.health.take_damage(1, p.global_position + Vector2(10, 0))
	await _frames(5)
	await _tap(&"quick_heal")
	await _hold(&"move_left", 0.3)
	await _frames(30)


func _tap(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)


func _npc_present(id: StringName) -> bool:
	var loc := SceneFlow.current_location as Location
	return loc != null and is_instance_valid(loc._npcs.get(id))


func _finish_dialogue() -> void:
	for i in 40:
		if not DialogueService.is_active:
			return
		DialogueService.choose(0)
		DialogueService.advance()
		await _frames(2)


func _wait_location(id: StringName, max_frames: int = 200) -> void:
	for i in max_frames:
		var loc := SceneFlow.current_location as Location
		if loc != null and loc.location_id == id and not SceneFlow.is_transitioning:
			return
		await get_tree().process_frame
	_assert(false, "reached %s" % id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _assert(cond: bool, message: String) -> void:
	if not cond:
		printerr("SMOKE FAIL [%s]: %s" % [_step, message])
