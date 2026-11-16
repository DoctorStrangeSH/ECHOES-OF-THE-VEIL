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
	_assert(_npc_present(&"hester_ashby"), "Hester is at the point by day")
	DialogueService.start(&"hester", {"npc": &"hester_ashby"})
	for i in 8:
		DialogueService.choose(0)
		DialogueService.advance()
		await _frames(2)
		if Journal.case_stage(&"case_lighthouse") == &"watch":
			break
	DialogueService.end()
	await _frames(3)
	_assert(Journal.case_stage(&"case_lighthouse") == &"watch", "Hester's case reaches the night watch")
	WorldClock.wait_until_hour(23)
	DialogueService.start(&"lighthouse_watch")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_lighthouse") == &"registry", "counting the flashes advances the case")
	DialogueService.start(&"archive_shelves")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_lighthouse") == &"answer", "the harbour register answers it")
	DialogueService.start(&"hester", {"npc": &"hester_ashby"})
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_lighthouse") == Journal.STATUS_DONE and GameState.has_flag(&"world.lamp_counts"), "Hester's case resolved")
	WorldClock.wait_until_hour(9)
	SceneFlow.travel(&"greyford_block", &"point_steps")
	await _wait_location(&"greyford_block")
	await _frames(10)

	_step = "act I: the city has two maps"
	_assert(Campaign.has_started(&"act1"), "act I started after the door case")
	_assert(Journal.case_status(&"case_two_maps") == Journal.STATUS_ACTIVE, "act I main case open")
	_assert(Journal.pinned == &"case_two_maps" and (get_child(0).get_node("Hud") as Hud)._objective_line() != "", "the HUD shows the act's objective")
	await _wait_card()
	await _talk(&"jonah", {"npc": &"jonah_rook"}, ["JONAH_ASK_STRANGE"])
	_assert(Journal.case_stage(&"case_storeroom") == &"wall", "Jonah's storeroom case")
	WorldClock.wait_until_hour(21)
	SceneFlow.travel(&"rook_storeroom", &"entrance")
	await _wait_location(&"rook_storeroom")
	await _frames(10)
	await _finish_dialogue()
	await _clear_enemies()
	_assert(GameState.has_flag(&"storeroom.cleared"), "storeroom echo cleared")
	DialogueService.start(&"storeroom_crate")
	await _finish_dialogue()
	DialogueService.start(&"storeroom_ledger")
	await _finish_dialogue()
	await _talk(&"jonah", {"npc": &"jonah_rook"}, ["JONAH_STOREROOM_TELL"])
	_assert(Journal.case_status(&"case_storeroom") == Journal.STATUS_DONE, "storeroom resolved")
	await _talk(&"theo", {"npc": &"theo_marsh"}, [])
	_assert(Journal.case_stage(&"case_larger_house") == &"measure", "Theo's case")
	SceneFlow.travel(&"theo_flat", &"from_street")
	await _wait_location(&"theo_flat")
	await _frames(10)
	DialogueService.start(&"theo_corridor")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_larger_house") == &"room", "the corridor is too long")
	SceneFlow.travel(&"theo_new_room", &"entrance")
	await _wait_location(&"theo_new_room")
	await _frames(10)
	await _finish_dialogue()
	await _clear_enemies()
	DialogueService.start(&"new_room_bed")
	await _finish_dialogue()
	_assert(Journal.form_hypothesis(&"incidents_share_mark"), "incidents share the mark")
	DialogueService.start(&"new_room_desk")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_two_maps") == &"hand", "the pencil map found")
	if not Journal.can_form(&"halloway_drew_map"):
		Journal.add_evidence(&"e_rent_book")
	_assert(Journal.form_hypothesis(&"halloway_drew_map"), "handwriting identified")
	await _talk(&"theo", {"npc": &"theo_marsh"}, ["THEO_TELL", "THEO_SAY_LOST"])
	_assert(Journal.case_status(&"case_larger_house") == Journal.STATUS_DONE, "Theo's case resolved")
	SceneFlow.travel(&"greyford_block", &"theo_front")
	await _wait_location(&"greyford_block")
	await _talk(&"halloway", {"npc": &"edda_halloway"}, ["HALLOWAY_SHOW_MAP", "HALLOWAY_MAP_WHO"])
	_assert(Journal.case_status(&"case_two_maps") == Journal.STATUS_DONE, "act I resolved")
	await _frames(10)
	_assert(Campaign.current_act() == &"act2" and Journal.case_status(&"case_misplaced") == Journal.STATUS_ACTIVE, "act II begins")
	_assert((get_child(0).get_node("ActCard") as ActCard).is_showing(), "act card shown")
	await _wait_card()
	await _talk(&"ivo", {"npc": &"ivo_calder"}, ["IVO_ASK_WARD"])

	_step = "act II: the people we misplaced"
	await _talk(&"nadiya", {"npc": &"nadiya_sol"}, ["NADIYA_ASK_WARD"])
	_assert(GameState.has_flag(&"ward.nadiya_invite"), "Nadiya knows a way in")
	WorldClock.wait_until_hour(21)
	await _frames(5)
	_assert(_visible_in_location(&"WardGate"), "the Ward gate shows at night")
	SceneFlow.travel(&"echo_ward", &"gate")
	await _wait_location(&"echo_ward")
	await _frames(10)
	await _finish_dialogue()
	_assert(GameState.has_flag(&"ward.open") and Journal.case_stage(&"case_misplaced") == &"residents", "into the Ward")
	await _talk(&"alderman", {"npc": &"alderman_penhallow"}, [])
	await _talk(&"bea", {"npc": &"bea_halloway"}, ["BEA_TELL_EDDA"])
	await _talk(&"abel", {"npc": &"abel_crane"}, ["ABEL_LEAVE"])
	await _talk(&"ellie", {"npc": &"ellie_marsh"}, ["ELLIE_THEO"])
	await _talk(&"vale", {"npc": &"sera_vale"}, ["VALE_HELP"])
	await _talk(&"alderman", {"npc": &"alderman_penhallow"}, ["ALD_HEARD"])
	_assert(Journal.case_stage(&"case_misplaced") == &"depot", "the depot is next")
	await _talk(&"jonah", {"npc": &"jonah_rook"}, ["COMPANION_ASK"])
	await _frames(10)
	_assert(Party.is_companion(&"jonah_rook"), "Jonah comes along")
	_assert(is_instance_valid((SceneFlow.current_location as Location)._follower), "Jonah follows in the Ward")
	SceneFlow.travel(&"ward_depot", &"entrance")
	await _wait_location(&"ward_depot")
	await _frames(10)
	await _finish_dialogue()
	_assert(is_instance_valid((SceneFlow.current_location as Location)._follower), "and into the depot")
	await _clear_enemies()
	_assert(GameState.has_flag(&"depot.cleared"), "depot hall cleared")
	SceneFlow.travel(&"depot_platform", &"from_hall")
	await _wait_location(&"depot_platform")
	await _frames(10)
	await _finish_dialogue()
	var conductor := _find_node_of(SceneFlow.current_location, "Conductor") as Conductor
	_assert(conductor != null, "the Conductor waits")
	if conductor != null:
		conductor.engage()
		for i in 120:
			await _frames(4)
			if not is_instance_valid(conductor) or conductor.state == Conductor.State.DEAD:
				break
			conductor.health.take_damage(1, conductor.global_position + Vector2(12, 0))
	await _frames(40)
	_assert(GameState.has_flag(&"boss.conductor.defeated"), "the Conductor is beaten")
	await _talk(&"rosalind", {"npc": &"rosalind_rook"}, ["ROS_SAY_HERE"])
	_assert(Journal.case_status(&"case_misplaced") == Journal.STATUS_DONE and GameState.has_flag(&"rosalind.reunited"), "Jonah and Rosalind reunited")
	_assert(Journal.form_hypothesis(&"two_rooks"), "the Census cut the family in two")
	await _talk(&"camp_jonah", {"npc": &"jonah_rook"}, ["CAMP_GO_HOME"])
	_assert(Party.companion == &"", "Jonah goes home")
	SceneFlow.travel(&"greyford_block", &"ward_return")
	await _wait_location(&"greyford_block")
	WorldClock.wait_until_hour(9)

	_step = "act III: a kindness built on a lie"
	await _frames(10)
	_assert(Campaign.current_act() == &"act3" and Journal.case_stage(&"case_kindness") == &"pact", "act III begins")
	await _wait_card()
	SceneFlow.travel(&"keepers_rooms", &"stairs")
	await _wait_location(&"keepers_rooms")
	await _frames(10)
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_kindness") == &"quay", "the pact explained")
	SceneFlow.travel(&"north_quay", &"from_greyford")
	await _wait_location(&"north_quay")
	await _frames(10)
	await _talk(&"nadiya", {"npc": &"nadiya_sol"}, ["NADIYA_ASK_PLAN"])
	_assert(Journal.case_stage(&"case_kindness") == &"underpass", "the Open Hand's plan")
	SceneFlow.travel(&"flooded_underpass", &"entrance")
	await _wait_location(&"flooded_underpass")
	await _frames(10)
	await _finish_dialogue()
	await _clear_enemies()
	_assert(GameState.has_flag(&"underpass.cleared"), "underpass cleared")
	SceneFlow.travel(&"underpass_archive", &"from_hall")
	await _wait_location(&"underpass_archive")
	await _frames(10)
	await _finish_dialogue()
	var archivist := _find_node_of(SceneFlow.current_location, "Archivist") as Archivist
	_assert(archivist != null, "the Archivist waits")
	if archivist != null:
		archivist.engage()
		for i in 900:
			await _frames(4)
			if not is_instance_valid(archivist) or archivist.state == Archivist.State.DEAD:
				break
			EventHub.player_heal_requested_amount.emit(5)  # this test is about the flow, not dodging
			if not archivist.is_submerged():
				archivist.health.take_damage(1, archivist.global_position + Vector2(12, 0))
	await _frames(40)
	_assert(GameState.has_flag(&"boss.archivist.defeated"), "the Archivist is beaten")
	DialogueService.start(&"resonator_found")
	await _finish_dialogue()
	_assert(Inventory.count(&"resonator") == 1 and Journal.case_stage(&"case_kindness") == &"truth", "the resonator")
	_assert(Journal.form_hypothesis(&"flood_was_a_cover"), "the flood was a cover")
	var confessor := &"ivo"
	if GameState.has_flag(&"act3.confessor_mara"):
		confessor = &"mara"
	elif GameState.has_flag(&"act3.confessor_halloway"):
		confessor = &"halloway"
	await _talk(confessor, {}, [])
	_assert(Journal.case_stage(&"case_kindness") == &"decide", "the ally who knew (%s)" % confessor)
	await _talk(&"seal_engine", {}, ["SEAL_BREAK"])
	_assert(Journal.case_status(&"case_kindness") == Journal.STATUS_DONE and Inventory.count(&"resonator") == 0, "the resonator broken")
	await _frames(10)
	_assert(Campaign.current_act() == &"act4" and Journal.case_stage(&"case_index") == &"nodes", "act IV begins")
	await _wait_card()

	_step = "act IV: the index"
	SceneFlow.travel(&"echo_ward", &"gate")
	await _wait_location(&"echo_ward")
	await _frames(10)
	await _talk(&"vale", {"npc": &"sera_vale"}, ["VALE_ASK_NODES"])
	_assert(Journal.case_stage(&"case_index") == &"sites", "Vale opens the sites")
	_assert(_visible_in_location(&"HospitalDoor"), "memory doors in the Ward")
	var sites := {"memory_hospital": ["t_nurse_log", "t_admissions", "t_doctor"], "memory_home": ["t_child_diary", "t_eviction", "t_neighbour"], "memory_station": ["t_station_log", "t_letter", "t_porter"]}
	for site: String in sites:
		SceneFlow.travel(StringName(site), &"entrance")
		await _wait_location(StringName(site))
		await _frames(10)
		await _finish_dialogue()
		var reviser := _find_node_of(SceneFlow.current_location, "Reviser") as Reviser
		_assert(reviser != null, "%s: the revision waits" % site)
		if reviser != null:
			reviser.engage()
			for i in 600:
				await _frames(4)
				if not is_instance_valid(reviser) or reviser.state == Reviser.State.DEAD:
					break
				EventHub.player_heal_requested_amount.emit(5)
				reviser.health.take_damage(1, reviser.global_position + Vector2(12, 0))
		await _frames(30)
		var right := site != "memory_home"  # judge one site wrongly on purpose
		for t: String in sites[site]:
			var truth := String(Journal.evidence_defs[StringName("e_" + t)]["truth"])
			var say := truth if right else ("edited" if truth != "edited" else "authentic")
			await _talk(StringName(t), {}, ["VERDICT_SAY_" + say.to_upper()])
		await _talk(StringName("recon_" + site), {}, [])
		_assert(GameState.has_flag(StringName("site.%s.done" % site.trim_prefix("memory_"))), "%s put back together" % site)
		SceneFlow.travel(&"echo_ward", StringName("from_" + site))
		await _wait_location(&"echo_ward")
		await _frames(5)
	_assert(GameState.has_flag(&"site.hospital.true") and GameState.has_flag(&"site.home.distorted"), "verdicts decide each night")
	_assert(Journal.case_stage(&"case_index") == &"index", "all three nights")
	await _talk(&"alderman", {"npc": &"alderman_penhallow"}, ["ALD_INDEX"])
	_assert(Journal.form_hypothesis(&"the_lattice"), "the Index is a prison made of remembrance")
	await _talk(&"vale", {"npc": &"sera_vale"}, ["VALE_FINAL", "VALE_SHOW_TRUTH"])
	_assert(Journal.case_status(&"case_index") == Journal.STATUS_DONE and GameState.has_flag(&"vale.turned"), "Vale turned")

	_step = "fainting leaves a satchel"
	SceneFlow.travel(&"ward_depot", &"entrance")
	await _wait_location(&"ward_depot")
	await _frames(10)
	Inventory.money = 30
	var p := get_tree().get_first_node_in_group(&"player") as Player
	p.health.take_damage(99, p.global_position + Vector2(10, 0))
	await _wait_location(&"rented_room")
	await _frames(10)
	_assert(GameState.satchel.get("scene", "") == "ward_depot" and Inventory.money == 15, "half the money stayed in the depot")
	SceneFlow.travel(&"ward_depot", &"entrance")
	await _wait_location(&"ward_depot")
	await _frames(10)
	var bag := _find_node_of(SceneFlow.current_location, "Satchel") as Satchel
	_assert(bag != null, "the satchel lies where you fell")
	if bag != null:
		bag._on_interact(get_tree().get_first_node_in_group(&"player"))
	_assert(Inventory.money == 30 and GameState.satchel.is_empty(), "and can be picked up")

	_step = "act V: what we choose to remember"
	_assert(Campaign.current_act() == &"act5" and Journal.case_stage(&"case_anchor") == &"gather", "act V begins")
	await _wait_card()
	await _talk(&"jonah", {"npc": &"jonah_rook"}, ["ANCHOR_ASK"])
	await _talk(&"vale", {"npc": &"sera_vale"}, ["ANCHOR_ASK"])
	_assert(GameState.has_flag(&"anchor.ally.jonah_rook") and GameState.has_flag(&"anchor.ally.sera_vale"), "allies stand with you")
	SceneFlow.travel(&"keepers_rooms", &"stairs")
	await _wait_location(&"keepers_rooms")
	await _frames(5)
	_assert(_visible_in_location(&"AnchorDescent"), "the way down")
	SceneFlow.travel(&"the_anchor", &"entrance")
	await _wait_location(&"the_anchor")
	await _frames(10)
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_anchor") == &"confront", "Wren's plan")
	var director := _find_node_of(SceneFlow.current_location, "Director") as Director
	_assert(director != null, "the Director waits")
	if director != null:
		director.engage()
		for i in 900:
			await _frames(4)
			if not is_instance_valid(director) or director.state == Director.State.DEAD:
				break
			EventHub.player_heal_requested_amount.emit(5)
			director.health.take_damage(1, director.global_position + Vector2(12, 0))
	await _frames(40)
	_assert(GameState.has_flag(&"boss.director.defeated"), "Wren is stopped")
	await _talk(&"anchor_heart", {}, ["ENDING_OPEN_CHOICE"])
	await _frames(10)
	var epi := get_child(0).get_node("Epilogue") as EpilogueScreen
	_assert(epi.is_open() and Journal.case_status(&"case_anchor") == Journal.STATUS_DONE, "the epilogue")
	for i in 40:
		if not epi.is_open():
			break
		epi.next()
		await _frames(2)
	await _wait_location(&"rented_room")
	_assert(GameState.has_flag(&"game.completed") and GameState.has_flag(&"ending.open_record"), "the world goes on after the ending")

	_step = "world incident after the ending"
	_assert(Incidents.active() == &"lanterns", "the morning after, Lantern Row acts up (got %s)" % Incidents.active())
	SceneFlow.travel(&"echo_lantern_row", &"entrance")
	await _wait_location(&"echo_lantern_row")
	await _frames(10)
	_assert(get_tree().get_nodes_in_group(&"incident_echo").size() == 3, "the incident's echoes are here")
	_player().health.heal(99)
	await _clear_enemies()
	await _frames(10)
	_assert(Journal.case_stage(&"case_inc_lanterns") == &"report", "cleared, now report")
	await _talk(&"mara", {}, [])
	_assert(Journal.case_status(&"case_inc_lanterns") == Journal.STATUS_DONE, "Mara hears about it")
	SceneFlow.travel(&"greyford_block", &"ward_return")
	await _wait_location(&"greyford_block")
	WorldClock.wait_until_hour(9)

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

	_step = "park: a three-a-side match on the pitch"
	WorldClock.wait_until_hour(15)
	SceneFlow.travel(&"greyford_park", &"from_town")
	await _wait_location(&"greyford_park")
	await _frames(10)
	EventHub.screen_requested.emit("match:football")
	await _frames(10)
	var matches := SceneFlow.current_location.find_children("*", "FootballMatch", true, false)
	_assert(matches.size() == 1, "a match starts on the pitch")
	if matches.size() == 1:
		var fm := matches[0] as FootballMatch
		_assert(fm.bots.size() == 7, "seven other players on the pitch")
		var cash := Inventory.money
		for g in FootballMatch.WIN:
			await get_tree().create_timer(FootballMatch.KICKOFF_PAUSE + 0.3).timeout
			if not is_instance_valid(fm):
				break
			fm.ball_pos = Vector2(FootballMatch.CENTER.x, FootballMatch.top_goal_y() - 6)
			fm.ball_vel = Vector2(0, -120)
			await _frames(6)
		await _frames(10)
		_assert(not is_instance_valid(fm) or not fm.running, "the match ends at three goals")
		_assert(Inventory.money > cash or int(GameState.get_flag(&"match.football.wins", 0)) >= 1, "a win counts")
	SceneFlow.travel(&"greyford_block", &"from_park")
	await _wait_location(&"greyford_block")

	_step = "city: the number 11 bus"
	GameState.set_flag(&"visited.market_street")
	Inventory.money += 5
	var fare_before := Inventory.money
	EventHub.screen_requested.emit("map:travel")
	await _frames(5)
	var ms := get_child(0).city_map as MapScreen
	_assert(ms.is_open() and ms.travel, "the route board opens at the stop")
	ms.selected = "market"
	ms._try_ride()
	await _wait_location(&"market_street")
	_assert(Inventory.money == fare_before - CityMap.fare(), "a bus ride costs the fare")
	SceneFlow.travel(&"greyford_block", &"bus_stop")
	await _wait_location(&"greyford_block")

	_step = "endgame: an expedition with combined mechanics"
	SceneFlow.travel(&"echo_ward", &"rift_return")
	await _wait_location(&"echo_ward")
	await _frames(5)
	_assert(_visible_in_location("RiftUse"), "the rift opens after the ending")
	EventHub.screen_requested.emit("expeditions")
	await _frames(5)
	(get_child(0).get_node("Work") as WorkScreen).close()
	_assert(Expedition.offers().size() == 3, "three runs on the board")
	var shards_before := Inventory.count(Expedition.SHARD)
	Expedition.start({"site": "station", "mods": ["flooded", "rewritten", "lightless", "crowded", "fragile"], "boss": "matron"})
	for room in 3:
		await _frames(3)
		await _wait_location(&"expedition_room")
		await _frames(10)
		var er := SceneFlow.current_location as ExpeditionRoom
		_assert(er != null and int(Expedition.run.get("room", -1)) == room, "expedition room %d" % room)
		if er == null:
			break
		_player().health.heal(99)
		if Expedition.is_arena():
			var rb := er.boss as Reviser
			_assert(rb != null and er.flood != null, "a revised Matron in rising water")
			if rb != null:
				rb.engage()
				for i in 600:
					await _frames(4)
					if not is_instance_valid(rb) or rb.state == Reviser.State.DEAD:
						break
					_player().health.heal(99)
					rb.health.take_damage(1, rb.global_position + Vector2(12, 0))
		await _clear_enemies()
		await _frames(10)
		_assert(er.exit.enabled, "room %d opens once clear" % room)
		er.exit.interact(_player())
	await _wait_location(&"echo_ward", 300)
	_assert(Inventory.count(Expedition.SHARD) > shards_before and not Expedition.active(), "the run pays shards")
	_assert(Expedition.pages.has("p3_station") and Expedition.pages.has("p8_fragile"), "Index pages earned")
	Inventory.add(Expedition.SHARD, 10, false)
	Inventory.add(&"tram_token", 1, false)
	_assert(Economy.craft(&"shard_ribbon"), "a shard trinket crafted")

	_step = "endgame: fainting ends a run"
	Inventory.money = 40
	var shards_now := Inventory.count(Expedition.SHARD)
	Expedition.start(Expedition.offers()[0])
	await _frames(3)
	await _wait_location(&"expedition_room")
	await _frames(10)
	_player().health.take_damage(99, Vector2.ZERO)
	await _wait_location(&"echo_ward", 400)
	await _frames(10)
	_assert(not Expedition.active() and Inventory.count(Expedition.SHARD) == shards_now, "no shards from a lost run")
	var rift_bag := _find_node_of(SceneFlow.current_location, "Satchel")
	_assert(rift_bag != null or GameState.difficulty == "story", "the satchel waits at the rift")
	if rift_bag != null:
		(rift_bag as Satchel).interact(_player())
	_assert(Inventory.money >= 40, "satchel recovered")
	SceneFlow.travel(&"greyford_block", &"ward_return")
	await _wait_location(&"greyford_block")

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


## Talks through a conversation, picking the listed choices (by text key) in order.
## Story beats that open with their own scene end the conversation first, so it
## talks again (up to six times) until the wanted choices have been made.
func _talk(id: StringName, ctx: Dictionary, picks: Array) -> void:
	var tries := 0
	DialogueService.start(id, ctx)
	for i in 240:
		await _frames(2)
		if not DialogueService.is_active:
			tries += 1
			if picks.is_empty() or tries >= 6:
				if not picks.is_empty():
					print("TALK %s: gave up waiting for %s" % [id, picks[0]])
				return
			DialogueService.start(id, ctx)
			continue
		var vis: Array = DialogueService._visible_choices
		if vis.is_empty():
			DialogueService.advance()
			continue
		var picked := -1
		if not picks.is_empty():
			for j in vis.size():
				if String(vis[j].get("text", "")) == String(picks[0]):
					picked = j
		if picked >= 0:
			picks.pop_front()
			DialogueService.choose(picked)
		else:
			if not picks.is_empty():
				print("TALK %s: wanted %s, saw %s" % [id, picks[0], vis.map(func(c: Dictionary) -> String: return String(c.get("text", "")))])
			DialogueService.end()
			return


func _clear_enemies() -> void:
	for round in 40:
		var left := 0
		var stack: Array[Node] = [SceneFlow.current_location]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is EchoEnemy and (n as EchoEnemy).health.health > 0:
				left += 1
				(n as EchoEnemy).health.take_damage(1, (n as EchoEnemy).global_position + Vector2(10, 0))
		if left == 0:
			break
		await _frames(30)
	await _frames(20)


func _find_node_of(root: Node, cls: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
			return n
		stack.append_array(n.get_children())
	return null


func _visible_in_location(node_name: String) -> bool:
	var stack: Array[Node] = [SceneFlow.current_location]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == node_name:
			return (n as CanvasItem).visible if n is CanvasItem else true
		stack.append_array(n.get_children())
	return false


func _wait_card() -> void:
	var card := get_child(0).get_node("ActCard") as ActCard
	for i in 600:
		if not card.is_showing():
			return
		await get_tree().process_frame


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
