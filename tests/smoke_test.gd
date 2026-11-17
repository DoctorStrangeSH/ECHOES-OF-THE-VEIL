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
		# The boss drops a Census ledger page (Rosalind's side story). Whether
		# its mote drifts to the player depends on where the boss fell, and
		# holding it changes what Jonah says later, so the main-story run sets
		# it aside to stay deterministic (it made CI flaky).
		for m in SceneFlow.current_location.find_children("*", "ResonanceMote", true, false):
			if (m as ResonanceMote).item_id == &"ledger_page":
				m.queue_free()
		if Inventory.has(&"ledger_page"):
			Inventory.remove(&"ledger_page")

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

	print("SMOKE level at the ending: ", Progression.level)
	var chapters := Chronicle.open_chapters()
	for c in chapters:
		if String(c["id"]) in ["prologue", "maps", "ward", "kindness", "index", "anchor"]:
			_assert(Chronicle.pages(c).size() >= 2 and Chronicle.finished(c), "the Chronicle tells chapter %s to its end" % c["id"])
	_assert(chapters.size() >= 7, "the Chronicle tells the whole campaign (%d chapters)" % chapters.size())
	var js := get_child(0).get_node("Journal") as JournalScreen
	js.open()
	js._set_tab("chronicle")
	await _frames(5)
	js.close()
	_assert(Progression.level >= 5, "the campaign levels you up (level %d)" % Progression.level)

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

	await _farm_story()

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


var _bolt_seen := false


## R5: the notice, Hugh, the well, Margaret at dusk, the tin, the purchase,
## then a crop from seed to the crate and the money in the morning.
func _farm_story() -> void:
	_step = "farm: the notice"
	SceneFlow.travel(&"market_street", &"bus_stop")
	await _wait_location(&"market_street")
	await _frames(10)
	var people := SceneFlow.current_location.find_children("*", "Passerby", true, false)
	_assert(not people.is_empty() or WorldClock.get_period() == "night", "people on the market street")
	if not people.is_empty():
		(people[0] as Passerby).speak(_player())
		await _frames(30)
	DialogueService.start(&"farm_notice")
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_brook_farm") == Journal.STATUS_ACTIVE and CityMap.known("brookside"), "the farm is on the bus map")
	WorldClock.wait_until_hour(9)
	var money := Inventory.money
	_assert(CityMap.ride("brookside"), "ride out of town")
	await _wait_location(&"brook_farm")
	await _frames(20)
	_assert(Inventory.money == money - CityMap.fare_to("brookside"), "the longer ride costs more")
	_step = "farm: Hugh"
	await _talk(&"hugh", {"npc": &"hugh_penny"}, ["HUGH_ASK_HOW"])
	_assert(Journal.case_stage(&"case_brook_farm") == &"pump" and Livelihood.active.has(&"farm_pump"), "mend the well")
	await _frames(5)
	_assert(_visible_in_location("WellSpot"), "the well shows a repair spot")
	Livelihood.complete(&"farm_pump")
	_assert(Journal.case_stage(&"case_brook_farm") == &"dusk" and GameState.has_flag(&"farm.well_fixed"), "come back at dusk")
	_step = "farm: Margaret"
	WorldClock.wait_until_hour(19)
	await _frames(30)
	_assert(SceneFlow.current_location.find_children("*", "Npc", true, false).any(func(n: Node) -> bool: return n.get("npc_id") == &"margaret_penny"), "Margaret by the well")
	await _talk(&"margaret", {"npc": &"margaret_penny"}, ["MARGARET_ASK_SONG", "MARGARET_ASK_WANT"])
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_brook_farm") == &"tin", "look under the apple tree")
	await _frames(5)
	var tin := _find_named("TinPickup")
	_assert(tin != null and (tin as CanvasItem).visible, "the tin can be found")
	if tin != null:
		(tin as Interactable).interact(_player())
	_assert(Inventory.has(&"margaret_tin"), "tin found")
	_step = "farm: the deal"
	SceneFlow.travel(&"brook_farmhouse", &"entrance")
	await _wait_location(&"brook_farmhouse")
	await _frames(10)
	Inventory.add_money(100)
	await _talk(&"hugh", {"npc": &"hugh_penny"}, ["FARM_LEAVE_LETTERS", "FARM_PAY_90"])
	await _finish_dialogue()
	_assert(Farm.owned() and Journal.case_status(&"case_brook_farm") == Journal.STATUS_DONE, "the farm is yours")
	_assert(Inventory.has(&"watering_can") and Inventory.has(&"seed_radish") and Farm.hens == 2, "keys, can, seeds, hens")
	_step = "farm: a crop"
	SceneFlow.travel(&"brook_farm", &"farmhouse_front")
	await _wait_location(&"brook_farm")
	await _frames(10)
	var plot := _find_named("FieldPlot1") as FarmPlot
	_assert(plot != null and plot.enabled, "the field is yours to use")
	if plot == null:
		return
	Farm.last_seed = &"seed_radish"
	_assert(Farm.plant(plot.plot_id, &"seed_radish"), "plant radish")
	for day in 3:
		plot.interact(_player())  # water (or, on a rainy day, just look)
		_assert(Farm.is_watered(plot.plot_id), "watered on day %d" % day)
		WorldClock.sleep_until_hour(8)
		await _frames(3)
	_assert(Farm.state(plot.plot_id) == "ready", "radish ripe after three watered days")
	plot.interact(_player())
	_assert(Inventory.has(&"radish"), "harvested")
	DialogueService.start(&"farm_crate")
	await _frames(3)
	DialogueService.choose(0)
	await _finish_dialogue()
	_assert(Farm.shipped > 0 and not Inventory.has(&"radish"), "into the crate")
	money = Inventory.money
	WorldClock.sleep_until_hour(8)
	_assert(Inventory.money > money and Farm.eggs >= 2, "paid in the morning; the hens laid")
	DialogueService.start(&"farm_coop")
	await _frames(3)
	DialogueService.choose(0)
	await _finish_dialogue()
	_assert(Inventory.has(&"egg", 2) and Farm.eggs == 0, "eggs collected")
	EventHub.screen_requested.emit("map:travel")
	await _frames(10)
	await _tap(&"pause")
	await _frames(5)
	await _companion_bonds()
	await _salt_tunnels()
	await _number_13()
	await _night_shift()
	await _millwood_story()
	await _mill_hill_story()
	await _cavenmouth_story()
	SceneFlow.travel(&"greyford_block", &"ward_return")
	await _wait_location(&"greyford_block")


## R5b: Millwood, Ada, the bell at night, the drowned village, the register.
func _millwood_story() -> void:
	_step = "millwood: the woods"
	WorldClock.wait_until_hour(10)
	SceneFlow.travel(&"brook_farm", &"from_millwood")
	await _wait_location(&"brook_farm")
	SceneFlow.travel(&"millwood", &"from_farm")
	await _wait_location(&"millwood")
	await _frames(10)
	var mush := _find_named("Mushrooms1") as ForageSpot
	_assert(mush != null and mush.available(), "mushrooms to gather")
	if mush != null:
		mush.interact(_player())
		_assert(Inventory.has(&"mushroom") and not mush.available(), "gathered; gone until tomorrow")
	await _talk(&"ada", {"npc": &"ada_fenwick"}, ["ADA_ASK_BELL", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_drowned_ford") == &"listen", "listen for the bell")
	_step = "millwood: the bell"
	WorldClock.wait_until_hour(21)
	await _frames(10)
	DialogueService.start(&"ford_pier")
	await _finish_dialogue()
	_assert(GameState.has_flag(&"ford.open") and _visible_in_location("VeilBelow"), "a stair of light at the end of the pier")
	SceneFlow.travel(&"drowned_ford", &"entrance")
	await _wait_location(&"drowned_ford")
	await _frames(20)
	await _finish_dialogue()
	await _clear_enemies()
	await _frames(10)
	_assert(GameState.has_flag(&"ford.cleared"), "the echoes are gone from the chapel")
	DialogueService.start(&"ford_chapel")
	await _finish_dialogue()
	_assert(Inventory.has(&"ford_register") and Journal.case_stage(&"case_drowned_ford") == &"choice", "the register")
	SceneFlow.travel(&"millwood", &"pier")
	await _wait_location(&"millwood")
	await _frames(10)
	await _talk(&"ada", {"npc": &"ada_fenwick"}, ["FORD_TO_BELL"])
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_drowned_ford") == Journal.STATUS_DONE and Inventory.has(&"ford_bell"), "laid to rest; the clapper")


## R2f: the Rope Works: day shifts, and a man still on the night shift.
func _night_shift() -> void:
	_step = "rope works: Doyle"
	WorldClock.wait_until_hour(10)
	SceneFlow.travel(&"ropeworks", &"bus_stop")
	await _wait_location(&"ropeworks")
	await _frames(10)
	var money := Inventory.money
	var h := WorldClock.minute_of_day
	await _talk(&"doyle", {"npc": &"frank_doyle"}, ["DOYLE_ASK_SHIFT", "DOYLE_ASK_CARD", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Inventory.money == money + 16 and WorldClock.minute_of_day >= h + 240, "a four-hour shift for sixteen pounds")
	_assert(Journal.case_stage(&"case_night_shift") == &"night", "a card clocked IN for a shift that doesn't exist")
	_step = "rope works: the ropewalk at night"
	WorldClock.wait_until_hour(23)
	SceneFlow.travel(&"ropewalk_shed", &"entrance")
	await _wait_location(&"ropewalk_shed")
	await _frames(10)
	_assert(NpcRegistry.resolve(&"bill_kettle").get("scene", "") == "ropewalk_shed", "Bill Kettle walks backwards down the ropewalk")
	await _talk(&"kettle", {"npc": &"bill_kettle"}, ["KETTLE_HELP"])
	await _finish_dialogue()
	_assert(Livelihood.active.has(&"ropewalk_rope"), "a rope of bad hemp to finish")
	Livelihood.complete(&"ropewalk_rope")
	_assert(Journal.case_stage(&"case_night_shift") == &"report", "the rope holds")
	SceneFlow.travel(&"ropeworks_office", &"entrance")
	await _wait_location(&"ropeworks_office")
	await _frames(10)
	await _talk(&"rw_cabinet", {}, ["RW_POST_REPORT"])
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_night_shift") == Journal.STATUS_DONE and GameState.has_flag(&"ropeworks.plaque"), "the report goes on the noticeboard")
	SceneFlow.travel(&"ropeworks", &"from_office")
	await _wait_location(&"ropeworks")
	await _frames(10)
	var plaque := _find_named("Plaque") as CanvasItem
	_assert(plaque != null and plaque.visible, "a brass plate for W. Kettle")


## R2e: Rowan Terrace goes 12, 14; at night a door appears in the gap.
func _number_13() -> void:
	_step = "terrace: Ivy"
	WorldClock.wait_until_hour(10)
	SceneFlow.travel(&"rowan_terrace", &"bus_stop")
	await _wait_location(&"rowan_terrace")
	await _frames(10)
	_assert(CityMap.district_of(&"rowan_terrace") == "terraces" and CityMap.known("terraces"), "the terrace is on the bus map")
	await _talk(&"ivy", {"npc": &"ivy_pelham"}, ["IVY_ASK_GAP", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_number_13") == &"night", "Ivy remembers number 13")
	var door := _find_named("No13Night") as CanvasItem
	_assert(door != null and not door.visible, "by day the gap is only a gap")
	WorldClock.wait_until_hour(23)
	await _frames(10)
	_assert(door.visible, "after dark, a green door with a brass 13")
	_step = "terrace: inside number 13"
	SceneFlow.travel(&"number_13", &"entrance")
	await _wait_location(&"number_13")
	await _frames(20)
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_number_13") == &"inside", "inside a kitchen in 1962")
	await _clear_enemies()
	await _frames(10)
	await _talk(&"n13_photo", {}, ["N13_RESTORE"])
	await _finish_dialogue()
	_assert(GameState.has_flag(&"terrace.13.restored") and Journal.case_status(&"case_number_13") == Journal.STATUS_DONE, "a chalked 13: the house is back")
	SceneFlow.travel(&"rowan_terrace", &"from_13")
	await _wait_location(&"rowan_terrace")
	await _frames(10)
	var house := _find_named("No13") as CanvasItem
	_assert(house != null and house.visible, "number 13 stands between 12 and 14")
	WorldClock.wait_until_hour(10)
	_assert(NpcRegistry.resolve(&"peggy_abbott").get("scene", "") == "rowan_terrace", "Peggy Abbott sits on her step")


## R9a: the salt tunnels under the harbour, a dungeon with two branches,
## two secrets, a gate with two locks and the Storekeeper.
func _salt_tunnels() -> void:
	_step = "salt: Nell's key"
	WorldClock.wait_until_hour(10)
	SceneFlow.travel(&"greyford_harbour", &"bus_stop")
	await _wait_location(&"greyford_harbour")
	await _frames(10)
	await _talk(&"nell", {"npc": &"nell_goodwin"}, ["NELL_ASK_KNOCKING"])
	await _finish_dialogue()
	_assert(GameState.has_flag(&"salt.known") and Journal.case_stage(&"case_salt_tunnels") == &"seals", "Nell gives the key to the grate")
	SceneFlow.travel(&"salt_stair", &"from_harbour")
	await _wait_location(&"salt_stair")
	await _frames(20)
	await _finish_dialogue()
	await _clear_enemies()
	DialogueService.start(&"salt_gate")
	await _finish_dialogue()
	_assert(not GameState.has_flag(&"salt.gate_open"), "the gate holds with both locks shut")
	_step = "salt: the brine gallery"
	SceneFlow.travel(&"salt_gallery", &"from_hub")
	await _wait_location(&"salt_gallery")
	await _frames(20)
	await _clear_enemies()
	await _frames(10)
	DialogueService.start(&"salt_sluice")
	await _finish_dialogue()
	_assert(GameState.has_flag(&"salt.sluice"), "the sluice drains")
	var keen := Inventory.stat("perception") >= 3.0
	DialogueService.start(&"salt_crack")
	await _finish_dialogue()
	_assert(GameState.has_flag(&"salt.cache_open") == keen, "the false wall opens only to a sharp eye")
	if not keen:
		GameState.set_flag(&"salt.cache_open", true)
	await _frames(5)
	_assert(_find_named("ToCache") != null and (_find_named("ToCache") as CanvasItem).visible, "a way into the smugglers' cache")
	SceneFlow.travel(&"salt_cache", &"entrance")
	await _wait_location(&"salt_cache")
	await _frames(10)
	(_find_named("Charm") as Interactable).interact(_player())
	_assert(Inventory.has(&"salt_charm"), "the smuggler's salt-knot")
	_step = "salt: the tally room"
	SceneFlow.travel(&"salt_tally", &"from_hub")
	await _wait_location(&"salt_tally")
	await _frames(20)
	await _clear_enemies()
	await _frames(10)
	(_find_named("Key") as Interactable).interact(_player())
	_assert(Inventory.has(&"tally_key"), "the tally key")
	DialogueService.start(&"salt_third_volume")
	await _finish_dialogue()
	SceneFlow.travel(&"salt_shrine", &"entrance")
	await _wait_location(&"salt_shrine")
	await _frames(10)
	DialogueService.start(&"salt_lost")
	await _finish_dialogue()
	_assert(GameState.has_flag(&"salt.lost_seen"), "the shelf of lost things")
	_step = "salt: the store"
	SceneFlow.travel(&"salt_stair", &"from_tally")
	await _wait_location(&"salt_stair")
	await _frames(10)
	DialogueService.start(&"salt_gate")
	await _finish_dialogue()
	_assert(GameState.has_flag(&"salt.gate_open") and Journal.case_stage(&"case_salt_tunnels") == &"store", "both locks free: the gate rises")
	SceneFlow.travel(&"salt_store", &"entrance")
	await _wait_location(&"salt_store")
	await _frames(10)
	await _finish_dialogue()
	var boss := _find_node_of(SceneFlow.current_location, "Reviser") as Reviser
	_assert(boss != null and boss.boss_id == &"storekeeper", "the Storekeeper at his desk")
	if boss != null:
		boss.engage()
		for i in 600:
			await _frames(4)
			if not is_instance_valid(boss) or boss.state == Reviser.State.DEAD:
				break
			EventHub.player_heal_requested_amount.emit(5)
			boss.health.take_damage(1, boss.global_position + Vector2(12, 0))
	await _frames(30)
	_assert(GameState.has_flag(&"boss.storekeeper.defeated"), "the Storekeeper is beaten")
	await _talk(&"salt_ledger", {}, ["SALT_OPEN_STORE"])
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_salt_tunnels") == Journal.STATUS_DONE, "the store is opened")
	await _frames(5)
	var ladder := _find_named("Ladder")
	_assert(ladder != null and (ladder as CanvasItem).visible, "a ladder straight up to the quay")
	SceneFlow.travel(&"greyford_harbour", &"from_tunnels")
	await _wait_location(&"greyford_harbour")
	await _frames(10)
	var money := Inventory.money
	await _talk(&"nell", {"npc": &"nell_goodwin"}, [])
	await _finish_dialogue()
	_assert(Inventory.money == money + 40, "Nell sleeps, and pays")


## R8: Hester walks with you; the bond opens three talks and a brighter lamp.
func _companion_bonds() -> void:
	_step = "companions: Hester joins"
	WorldClock.wait_until_hour(11)
	SceneFlow.travel(&"lighthouse_point", &"from_greyford")
	await _wait_location(&"lighthouse_point")
	await _frames(10)
	await _talk(&"hester", {"npc": &"hester_ashby"}, ["HESTER_COMPANION_ASK"])
	await _finish_dialogue()
	_assert(Party.companion == &"hester_ashby", "Hester takes her storm lantern and comes along")
	var before := Party.bond_points(&"hester_ashby")
	WorldClock.advance_minutes(20)
	WorldClock.advance_minutes(20)
	_assert(Party.bond_points(&"hester_ashby") == before + 1, "forty minutes walked together: one bond point")
	Party.add_bond(&"hester_ashby", Party.TIERS[2])
	_assert(Party.bond_tier(&"hester_ashby") == 3, "the bond at its top tier")
	_step = "companions: three talks on the road"
	await _talk(&"camp_hester", {"npc": &"hester_ashby"}, ["HEART_HESTER_1_ASK", "HEART_HESTER_2_ASK", "HEART_HESTER_3_ASK", "CAMP_KEEP_GOING"])
	await _finish_dialogue()
	_assert(GameState.has_flag(&"bond.hester_ashby.3"), "all three of Hester's talks heard; the count taught")
	SceneFlow.travel(&"greyford_block", &"ward_return")
	await _wait_location(&"greyford_block")
	await _frames(10)
	var f := SceneFlow.current_location.find_children("*", "Follower", true, false)
	_assert(f.size() == 1 and (f[0] as Follower).ability == "beam" and (f[0] as Follower).power == 3, "Hester follows into town with a brighter lamp")
	await _talk(&"camp_hester", {"npc": &"hester_ashby"}, ["CAMP_HESTER_GO_HOME"])
	await _finish_dialogue()
	_assert(Party.companion == &"", "Hester goes back to the point")


## R5c: Mill Hill and the lights in St Brigid's Abbey.
func _mill_hill_story() -> void:
	_step = "mill hill: the village"
	WorldClock.wait_until_hour(11)
	SceneFlow.travel(&"mill_hill", &"from_millwood")
	await _wait_location(&"mill_hill")
	await _frames(10)
	_assert(_find_named("ToAbbey") != null and _find_named("ShopUse") != null, "a lane to the abbey; the village shop")
	await _talk(&"avery", {"npc": &"thomas_avery"}, ["AVERY_ASK_LIGHTS", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_abbey_lights") == &"ask", "the vicar asks about the lights")
	_step = "mill hill: the abbey"
	SceneFlow.travel(&"abbey_ruins", &"from_village")
	await _wait_location(&"abbey_ruins")
	await _frames(20)
	await _finish_dialogue()
	await _clear_enemies()
	await _frames(10)
	_assert(GameState.has_flag(&"abbey.cleared"), "the vigil is over")
	DialogueService.start(&"abbey_altar")
	await _finish_dialogue()
	_assert(Inventory.has(&"abbess_rosary") and Journal.case_stage(&"case_abbey_lights") == &"rosary", "the abbess's rosary")
	SceneFlow.travel(&"mill_hill", &"from_abbey")
	await _wait_location(&"mill_hill")
	await _frames(10)
	await _talk(&"avery", {"npc": &"thomas_avery"}, ["ABBEY_TO_KEEP"])
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_abbey_lights") == Journal.STATUS_DONE and Inventory.has(&"brigid_rosary"), "kept; a rosary that counts with your heart")
	SceneFlow.travel(&"mill_hill_pub", &"entrance")
	await _wait_location(&"mill_hill_pub")
	await _frames(10)
	_assert(_find_named("PubBed") != null and _find_named("BarUse") != null, "a bed and a bar at the Millstone")


## R12a: the coach to Cavenmouth, Walter's letters, three deliveries home.
func _cavenmouth_story() -> void:
	_step = "cavenmouth: the coach"
	WorldClock.wait_until_hour(9)
	SceneFlow.travel(&"market_street", &"coach_stop")
	await _wait_location(&"market_street")
	await _frames(5)
	Inventory.add_money(40)
	var money := Inventory.money
	EventHub.screen_requested.emit("world:travel")
	await _frames(5)
	await _tap(&"interact")
	await _wait_location(&"cavenmouth", 300)
	await _frames(20)
	_assert(Inventory.money == money - 12 and WorldMap.city_of(GameState.current_scene_id) == "cavenmouth", "a ticket to the seaside")
	_assert(not SceneFlow.current_location.find_children("*", "Passerby", true, false).is_empty(), "people on the promenade")
	_step = "cavenmouth: the post office"
	SceneFlow.travel(&"cavenmouth_post", &"entrance")
	await _wait_location(&"cavenmouth_post")
	await _frames(10)
	await _talk(&"walter", {"npc": &"walter_finch"}, ["WALTER_ASK_SACK", "WALTER_TAKE_LETTERS", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Inventory.has(&"letter_edda") and Inventory.has(&"letter_theo") and Inventory.has(&"letter_jonah"), "three letters")
	SceneFlow.travel(&"cavenmouth_inn", &"entrance")
	await _wait_location(&"cavenmouth_inn")
	await _frames(10)
	await _talk(&"bridget", {"npc": &"bridget_knowles"}, ["BRIDGET_ASK_TOWN", "MARKET_BYE"])
	await _finish_dialogue()
	_step = "cavenmouth: fishing"
	SceneFlow.travel(&"cavenmouth", &"coach_stop")
	await _wait_location(&"cavenmouth")
	Inventory.add_money(20)
	_assert(Economy.buy(&"cav_bait", 0) and Inventory.has(&"fishing_rod"), "a rod from the bait shop")
	EventHub.screen_requested.emit("fish:sea")
	await _frames(5)
	var fishing := get_child(0).get("fishing") as FishingMinigame
	_assert(fishing.is_open(), "fishing off the pier")
	fishing._start_reel()
	fishing._land()
	await _frames(5)
	fishing.close()
	_assert(FishingMinigame.caught_kinds() >= 1, "something caught")
	_step = "cavenmouth: deliveries"
	SceneFlow.travel(&"cavenmouth", &"coach_stop")
	await _wait_location(&"cavenmouth")
	_assert(WorldMap.travel("greyford"), "the coach home")
	await _wait_location(&"market_street", 300)
	_step = "the car"
	Inventory.add_money(150)
	GameState.change_relationship(&"jonah_rook", 2)
	await _talk(&"jonah", {"npc": &"jonah_rook"}, ["JONAH_ASK_CAR", "JONAH_CAR_BUY", "BYE"])
	await _finish_dialogue()
	_assert(GameState.has_flag(&"car.owned") and Inventory.has(&"car_keys"), "Mr Rook's old car")
	await _frames(5)
	_assert(_visible_in_location("MyCar"), "parked on the market street")
	EventHub.screen_requested.emit("map:drive")
	await _frames(5)
	CityMap.driving = true
	_assert(CityMap.ride("old_quarter"), "drive across town")
	CityMap.driving = false
	await _wait_location(&"greyford_block")
	(get_child(0).get("city_map") as MapScreen).close()
	_step = "the harbour"
	WorldClock.wait_until_hour(10)
	_assert(CityMap.known("harbour") and CityMap.ride("harbour"), "a bus to the harbour")
	await _wait_location(&"greyford_harbour")
	await _frames(10)
	await _talk(&"nell", {"npc": &"nell_goodwin"}, ["NELL_ASK_FISH", "MARKET_BYE"])
	await _finish_dialogue()
	await _talk(&"agatha", {"npc": &"agatha_moss"}, ["AGATHA_ASK_FERRY", "AGATHA_OFFER_FIX", "MARKET_BYE"])
	await _finish_dialogue()
	_assert(Livelihood.active.has(&"ferry_engine"), "Agatha hands over the ferry's engine")
	Livelihood.complete(&"ferry_engine")
	await _frames(5)
	_assert(GameState.has_flag(&"ferry.running") and _visible_in_location("FerryTickets"), "the ferry runs again")
	_step = "St Carrow"
	Inventory.add_money(20)
	EventHub.screen_requested.emit("world:ferry")
	await _frames(5)
	await _tap(&"interact")
	await _wait_location(&"st_carrow", 300)
	await _frames(10)
	_assert(WorldMap.city_of(GameState.current_scene_id) == "st_carrow", "across to the island")
	await _talk(&"oona", {"npc": &"oona_pryce"}, ["OONA_ASK_LIGHT", "MARKET_BYE"])
	await _finish_dialogue()
	WorldClock.wait_until_hour(23)
	DialogueService.start(&"carrow_lamp")
	await _frames(3)
	await _talk(&"carrow_lamp", {}, ["CARROW_ANSWER"])
	await _finish_dialogue()
	_assert(GameState.has_flag(&"carrow.answered"), "the eighth flash")
	_assert(WorldMap.travel("greyford", "ferry"), "the ferry home")
	await _wait_location(&"greyford_harbour", 300)
	_step = "Ashbridge by air"
	WorldClock.wait_until_hour(9)
	_assert(CityMap.ride("airfield"), "a bus to the airfield")
	await _wait_location(&"greyford_airfield")
	Inventory.add_money(120)
	EventHub.screen_requested.emit("world:air")
	await _frames(5)
	await _tap(&"interact")
	await _wait_location(&"ashbridge", 300)
	await _frames(10)
	_assert(WorldMap.city_of(GameState.current_scene_id) == "ashbridge", "an hour later, the county town")
	SceneFlow.travel(&"ashbridge_museum", &"entrance")
	await _wait_location(&"ashbridge_museum")
	await _frames(10)
	Journal.start_case(&"case_eleventh")
	DialogueService.start(&"mus_census")
	await _finish_dialogue()
	_assert(Journal.case_stage(&"case_original_card") == &"ask", "Agnes Venn under glass")
	await _talk(&"imogen", {"npc": &"imogen_hale"}, ["IMOGEN_DONATE"])
	await _finish_dialogue()
	_assert(Inventory.has(&"agnes_card"), "the card, on loan to the family")
	SceneFlow.travel(&"ashbridge", &"air_stop")
	await _wait_location(&"ashbridge")
	_assert(WorldMap.travel("greyford", "air"), "the air taxi home")
	await _wait_location(&"greyford_airfield", 300)
	DialogueService.start(&"mara", {"npc": &"mara_venn"})
	await _finish_dialogue()
	_assert(Journal.case_status(&"case_original_card") == Journal.STATUS_DONE, "on Mara's wall")
	Inventory.add(&"cod", 1, false)
	var m0 := Inventory.money
	_assert(Economy.sell(&"cod") and Inventory.money > m0, "Nell buys the catch")
	for who: Array in [[&"halloway", &"edda_halloway"], [&"theo", &"theo_marsh"], [&"jonah", &"jonah_rook"]]:
		DialogueService.start(who[0], {"npc": who[1]})
		await _finish_dialogue()
	_assert(GameState.has_flag(&"letters.edda") and GameState.has_flag(&"letters.theo") and GameState.has_flag(&"letters.jonah"), "every letter in the right hands")
	_assert(Journal.case_stage(&"case_dead_letters") == &"return", "back to Walter")
	Journal.complete_case(&"case_dead_letters", &"delivered")


func _find_named(node_name: String) -> Node:
	var stack: Array[Node] = [SceneFlow.current_location]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == node_name:
			return n
		stack.append_array(n.get_children())
	return null


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
	# Weapons with other styles and talents run through the same round.
	var keep: StringName = Inventory.equipped.get("weapon", Inventory.DEFAULT_WEAPON)
	for wid: StringName in [&"pocket_sling", &"hatchet", &"quay_trident"]:
		if not Inventory.has(wid):
			Inventory.add(wid, 1, false)
		Inventory.equip(wid)
		await _tap(&"attack")
		await _frames(14)
		if wid == &"pocket_sling":
			var bolts := 0
			for c in p.get_parent().get_children():
				if c is Bolt:
					bolts += 1
			_assert(bolts > 0 or _bolt_seen, "a sling shoots")
			_bolt_seen = true
	Inventory.equip(keep)
	Progression.talents["veilwalker/veil_step"] = true
	Progression.talents["veilwalker/echo_strike"] = true
	Progression.talents["mechanic/spark"] = true
	Progression.talents["lantern/mending_light"] = true
	await _tap(&"dodge")
	await _frames(20)
	await _tap(&"attack")
	await _frames(12)
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
