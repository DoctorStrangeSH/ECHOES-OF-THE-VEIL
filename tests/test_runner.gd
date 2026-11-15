extends Node
## Minimal headless test runner (no plugins needed).
## Run:  godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures. Each test is a method named test_*.

var _failures: PackedStringArray = []
var _current := ""
var _checks := 0


func _ready() -> void:
	var tests: Array[String] = []
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			tests.append(n)
	tests.sort()
	for t in tests:
		_current = t
		var before := _failures.size()
		await call(t)
		print(("  ok    " if _failures.size() == before else "  FAIL  ") + t)
	print("\n%d tests, %d checks, %d failures" % [tests.size(), _checks, _failures.size()])
	for f in _failures:
		printerr("  - " + f)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func check(cond: bool, message: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("%s: %s" % [_current, message])


func _fresh_save_dir() -> String:
	var dir := "user://test_saves_%d_%d" % [Time.get_ticks_usec(), randi()]
	SaveService.save_dir = dir
	return dir


func _cleanup(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


# --- Save system -------------------------------------------------------------

func test_save_round_trip() -> void:
	var dir := _fresh_save_dir()
	GameState.reset_for_new_game()
	GameState.set_flag(&"prologue.saw_impossible_door", true)
	GameState.set_flag(&"counter", 3)
	GameState.current_scene_id = &"rented_room"
	var env := SaveService.make_envelope(GameState.to_dict())
	check(SaveService.write_envelope(1, env) == OK, "write ok")
	var r := SaveService.read_slot(1)
	check(r["ok"], "read ok: %s" % r.get("error"))
	check(not r["from_backup"], "primary used")
	var payload: Dictionary = r["envelope"]["payload"]
	check(payload["scene_id"] == "rented_room", "scene id kept")
	check(payload["flags"]["prologue.saw_impossible_door"] == true, "bool flag kept")
	check(int(payload["flags"]["counter"]) == 3, "number flag kept")
	_cleanup(dir)


func test_corrupt_primary_falls_back_to_backup_and_is_preserved() -> void:
	var dir := _fresh_save_dir()
	var env := SaveService.make_envelope(GameState.to_dict())
	SaveService.write_envelope(1, env)
	SaveService.write_envelope(1, env)  # second write rotates the first into .bak
	check(FileAccess.file_exists(SaveService.slot_path(1, ".bak")), "backup exists")
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["from_backup"], "loaded from backup")
	# Writing again must not replace the good backup with the corrupt file.
	SaveService.write_envelope(1, env)
	var b := SaveService.read_slot(1)
	check(b["ok"] and not b["from_backup"], "new primary readable")
	var corrupt_kept := false
	for name in DirAccess.get_files_at(dir):
		if name.contains(".corrupt-"):
			corrupt_kept = true
	check(corrupt_kept, "corrupt file kept for inspection")
	_cleanup(dir)


func test_rejects_invalid_and_future_saves() -> void:
	check(SaveService.validate("nope") != "", "non-object rejected")
	check(SaveService.validate({"schema_version": 1}) != "", "missing keys rejected")
	var env := SaveService.make_envelope(GameState.to_dict())
	check(SaveService.validate(env) == "", "valid envelope accepted")
	env["schema_version"] = SaveService.SCHEMA_VERSION + 1
	check(SaveService.validate(env) != "", "newer schema rejected")
	var dir := _fresh_save_dir()
	check(not SaveService.read_slot(2)["ok"], "missing slot not ok")
	_cleanup(dir)


func test_game_state_round_trip() -> void:
	GameState.reset_for_new_game()
	GameState.set_flag(&"met.mara_venn", true)
	GameState.player_appearance.hairstyle = "Hairstyle_01_02"
	var probe := Node2D.new()
	probe.global_position = Vector2(123, 45)
	var data := GameState.to_dict(probe)
	probe.free()
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(data))  # same path as disk
	GameState.reset_for_new_game()
	GameState.from_dict(json_copy)
	check(GameState.has_flag(&"met.mara_venn"), "flag restored")
	check(GameState.pending_position == Vector2(123, 45), "position restored")
	check(GameState.player_appearance.hairstyle == "Hairstyle_01_02", "appearance restored")
	GameState.reset_for_new_game()


# --- Content -----------------------------------------------------------------

func test_localization_complete() -> void:
	var missing := Localization.find_missing_keys()
	check(missing.is_empty(), "missing translations: %s" % ", ".join(missing))
	var old := Localization.get_locale()
	Localization.set_locale("ru")
	check(tr("MENU_QUIT") == "Выход", "ru translation active")
	Localization.set_locale("en")
	check(tr("MENU_QUIT") == "Quit", "en translation active")
	Localization.set_locale(old)


func test_input_actions_registered() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"attack", &"dodge", &"ability", &"quick_heal", &"journal", &"inventory", &"pause", &"quick_save", &"quick_load"]:
		check(InputMap.has_action(a) and not InputMap.action_get_events(a).is_empty(), "action %s" % a)


func test_tile_painter() -> void:
	check(TilePainter.pick_index(0, 0, 4, Vector2i(2, 2)) == 0, "grid 0,0")
	check(TilePainter.pick_index(1, 0, 4, Vector2i(2, 2)) == 1, "grid 1,0")
	check(TilePainter.pick_index(2, 1, 4, Vector2i(2, 2)) == 2, "grid wraps")
	check(TilePainter.pick_variant(5, 7, 3) == TilePainter.pick_variant(5, 7, 3), "variant stable")
	for palette_id in ["greyford_exterior", "rented_room", "echo_corridor", "tram_platform"]:
		var palette := TilePainter.load_palette(palette_id)
		check(not palette.is_empty(), "palette %s exists" % palette_id)
		var built := TilePainter.build_tileset(palette)
		check((built["brushes"] as Dictionary).size() == palette.size(), "every brush built for %s" % palette_id)


func test_character_direction_mapping() -> void:
	check(LayeredCharacterSprite.dir_from_vector(Vector2.RIGHT) == LayeredCharacterSprite.Dir.RIGHT, "right")
	check(LayeredCharacterSprite.dir_from_vector(Vector2.UP) == LayeredCharacterSprite.Dir.UP, "up")
	check(LayeredCharacterSprite.dir_from_vector(Vector2(-1, 0.2)) == LayeredCharacterSprite.Dir.LEFT, "mostly left")
	check(LayeredCharacterSprite.dir_from_vector(Vector2(0.7, 0.7)) == LayeredCharacterSprite.Dir.DOWN, "diagonal prefers vertical")
	check(LayeredCharacterSprite.dir_from_vector(Vector2.ZERO, LayeredCharacterSprite.Dir.UP) == LayeredCharacterSprite.Dir.UP, "zero keeps fallback")


func test_scene_registry_and_door_targets() -> void:
	var spawns := {}  # scene_id -> Array of spawn ids
	var doors: Array = []  # [from, target_scene, target_spawn]
	for scene_id: StringName in SceneFlow.LOCATIONS:
		var path: String = SceneFlow.LOCATIONS[scene_id]
		check(ResourceLoader.exists(path), "scene exists: %s" % path)
		var root: Node = (load(path) as PackedScene).instantiate()
		check(root is Location and (root as Location).location_id == scene_id, "%s location_id matches registry" % scene_id)
		spawns[scene_id] = []
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is SpawnPoint:
				spawns[scene_id].append((n as SpawnPoint).spawn_id)
			elif n is DoorInteractable:
				var d := n as DoorInteractable
				doors.append([scene_id, d.target_scene_id, d.target_spawn_id])
			if n is Interactable:
				check((n as Interactable).interaction_id != &"", "%s: %s has an interaction_id" % [scene_id, n.name])
		root.free()
	check(spawns[GameState.NEW_GAME_SCENE].has(GameState.NEW_GAME_SPAWN), "new-game spawn exists")
	for d in doors:
		check(spawns.has(d[1]), "door in %s targets known scene %s" % [d[0], d[1]])
		if spawns.has(d[1]):
			check(spawns[d[1]].has(d[2]), "door in %s targets existing spawn %s/%s" % [d[0], d[1], d[2]])


# --- M2: story systems ---------------------------------------------------------

func test_dialogues_valid() -> void:
	var problems := DialogueService.validate_all()
	check(problems.is_empty(), "dialogue problems: %s" % "; ".join(problems))


## Every evidence/case/hypothesis/dialogue referenced anywhere must exist.
func test_story_references() -> void:
	var refs := []  # [kind, id, where]
	for id: StringName in DialogueService.dialogues:
		_collect_refs(DialogueService.dialogues[id], "dialogue %s" % id, refs)
	for id: StringName in Journal.hypothesis_defs:
		_collect_refs(Journal.hypothesis_defs[id], "hypothesis %s" % id, refs)
		for ev: String in Array(Journal.hypothesis_defs[id].get("requires_all", [])) + Array(Journal.hypothesis_defs[id].get("requires_any", [])):
			refs.append(["evidence", ev, "hypothesis %s" % id])
	for id: StringName in NpcRegistry.defs():
		var d: Dictionary = NpcRegistry.get_def(id)
		refs.append(["dialogue", d.get("dialogue", ""), "npc %s" % id])
		_collect_refs(d.get("schedule", []), "npc %s" % id, refs)
	for r: Array in refs:
		var ok := true
		match r[0]:
			"evidence": ok = Journal.evidence_defs.has(StringName(r[1]))
			"case": ok = Journal.case_defs.has(StringName(r[1]))
			"hypothesis": ok = Journal.hypothesis_defs.has(StringName(r[1]))
			"dialogue": ok = DialogueService.has_dialogue(StringName(r[1]))
			"scene": ok = SceneFlow.has_location(StringName(r[1]))
		check(ok, "%s references unknown %s '%s'" % [r[2], r[0], r[1]])
	for id: StringName in Journal.evidence_defs:
		check(Journal.case_defs.has(StringName(Journal.evidence_defs[id].get("case", ""))), "evidence %s has a known case" % id)


func _collect_refs(v: Variant, where: String, out: Array) -> void:
	if v is Array:
		for x: Variant in v:
			_collect_refs(x, where, out)
	elif v is Dictionary:
		for k: Variant in v:
			var a: Variant = v[k]
			match String(k):
				"add_evidence", "evidence", "not_evidence":
					out.append(["evidence", a, where])
				"quest_start", "quest_active", "quest_done", "not_quest_started":
					out.append(["case", a, where])
				"quest_stage", "quest_complete":
					out.append(["case", a[0], where])
				"hypothesis", "not_hypothesis":
					out.append(["hypothesis", a, where])
				"travel":
					out.append(["scene", a[0], where])
				"scene":
					out.append(["scene", a, where])
			_collect_refs(a, where, out)


func test_story_rules() -> void:
	GameState.reset_for_new_game()
	check(StoryRules.evaluate(null), "null is true")
	check(StoryRules.evaluate({}), "empty is true")
	check(not StoryRules.evaluate({"flag": "x.test"}), "unset flag false")
	StoryRules.apply([{"set_flag": "x.test"}, {"relationship": ["mara_venn", 3]}, {"remember": ["mara_venn", "kept_promise"]}])
	check(StoryRules.evaluate({"flag": "x.test"}), "flag set by effect")
	check(StoryRules.evaluate({"relationship_at_least": ["mara_venn", 3]}), "relationship")
	check(StoryRules.evaluate({"remembers": ["mara_venn", "kept_promise"]}), "memory")
	check(StoryRules.evaluate({"any": [{"flag": "nope"}, {"flag": "x.test"}]}), "any")
	check(not StoryRules.evaluate({"all": [{"flag": "nope"}, {"flag": "x.test"}]}), "all")
	check(StoryRules.evaluate({"not": {"flag": "nope"}}), "not")
	StoryRules.apply({"clear_flag": "x.test"})
	check(not GameState.has_flag(&"x.test"), "clear_flag")
	GameState.reset_for_new_game()


func test_journal_hypothesis_and_corroboration() -> void:
	GameState.reset_for_new_game()
	var h := &"lantern_row_fragment"
	check(Journal.hypothesis_status(h) == Journal.HYP_LOCKED, "locked at start")
	Journal.add_evidence(&"e_door_observed")
	check(Journal.case_status(&"case_door") == Journal.STATUS_ACTIVE, "evidence opens its case")
	Journal.add_evidence(&"e_mara_lantern_row")
	check(not Journal.can_form(h), "needs two supporting items")
	Journal.add_evidence(&"e_city_map")
	check(Journal.can_form(h), "can form with door + 2")
	check(Journal.form_hypothesis(h), "formed")
	check(Journal.hypothesis_status(h) == Journal.HYP_INFERRED, "3 sources = inferred")
	check(Journal.case_stage(&"case_door") == &"decide", "hypothesis effect advanced the case")
	Journal.add_evidence(&"e_radio_announcement")
	check(Journal.hypothesis_status(h) == Journal.HYP_CORROBORATED, "4 independent sources = corroborated")
	var saved := Journal.to_dict()
	Journal.reset()
	Journal.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(Journal.is_hypothesis_formed(h) and Journal.has_evidence(&"e_city_map"), "journal survives save")
	GameState.reset_for_new_game()


func test_world_clock() -> void:
	WorldClock.reset()
	check(WorldClock.get_period() == "morning", "starts in the morning")
	check(WorldClock.period_for(0) == "night" and WorldClock.period_for(13 * 60) == "afternoon", "periods")
	WorldClock.wait_until_hour(18)
	check(WorldClock.get_hour() == 18 and WorldClock.day == 1, "wait until evening")
	WorldClock.sleep_until_hour(7)
	check(WorldClock.get_hour() == 7 and WorldClock.day == 2, "sleep to next morning")
	check(WorldClock.weather == WorldClock.weather_for_day(2), "weather follows the day")
	check(WorldClock.weather_for_day(1) == "clear", "day 1 is clear")
	WorldClock.reset()


func test_npc_schedules_resolve_to_real_anchors() -> void:
	var anchors := {}  # scene_id -> {anchor_id: true}
	for scene_id: StringName in SceneFlow.LOCATIONS:
		var root: Node = (load(SceneFlow.LOCATIONS[scene_id]) as PackedScene).instantiate()
		anchors[scene_id] = {}
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is NpcAnchor:
				anchors[scene_id][(n as NpcAnchor).anchor_id] = true
		root.free()
	for id: StringName in NpcRegistry.defs():
		for entry: Dictionary in NpcRegistry.get_def(id).get("schedule", []):
			var sid := StringName(entry.get("scene", ""))
			check(anchors.has(sid), "%s: known scene %s" % [id, sid])
			if anchors.has(sid):
				check(anchors[sid].has(StringName(entry.get("anchor", ""))), "%s: anchor %s exists in %s" % [id, entry.get("anchor"), sid])


func test_save_migration_from_v1() -> void:
	var dir := _fresh_save_dir()
	var v1 := {
		"schema_version": 1, "game_version": "0.1.0-m1", "timestamp": 0,
		"payload": {"flags": {"met.mara_venn": true}, "scene_id": "rented_room", "spawn_id": "from_street",
			"position": null, "facing": [0, 1], "play_time_seconds": 12.0, "appearance": {}},
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"], "v1 save readable: %s" % r.get("error"))
	if r["ok"]:
		var env: Dictionary = r["envelope"]
		check(int(env["schema_version"]) == SaveService.SCHEMA_VERSION, "migrated to current schema")
		check(env["payload"].has("profile") and env["payload"].has("journal"), "new sections added")
		GameState.from_dict(env["payload"])
		check(GameState.has_flag(&"met.mara_venn"), "old flags kept")
		check(GameState.player_name == "Alex", "default profile")
	GameState.reset_for_new_game()
	_cleanup(dir)


func test_creator_style_parsing() -> void:
	check(CharacterCreator.style_of("Hairstyle_07_03") == "Hairstyle_07", "hair style")
	check(CharacterCreator.style_of("Body_03") == "Body_03", "body has no colour variant")
	check(CharacterCreator.style_of("Accessory_01_Ladybug_02") == "Accessory_01_Ladybug", "accessory")


# --- M3: inventory, progression, combat ------------------------------------------

func test_inventory_items_and_equipment() -> void:
	GameState.reset_for_new_game()
	check(Inventory.equipped["weapon"] == Inventory.DEFAULT_WEAPON, "fists by default")
	Inventory.add(&"wrench", 1, false)
	Inventory.equip(&"wrench")
	var combo: Array = Inventory.weapon().get("combo", [])
	check(combo.size() == 3 and int(combo[2]) == 3, "wrench combo")
	Inventory.add(&"tram_token", 1, false)
	Inventory.equip(&"tram_token")
	check(int(Inventory.stat("max_health")) == 1, "trinket mod applies")
	Inventory.remove(&"tram_token")
	check(Inventory.equipped["trinket"] == &"", "removing an item unequips it")
	Inventory.add(&"tea_flask", 20, false)
	check(Inventory.count(&"tea_flask") == 9, "stack cap")
	check(Inventory.use(&"tea_flask") and Inventory.count(&"tea_flask") == 8, "consumable used")
	check(not Inventory.use(&"wrench"), "weapons are not consumable")
	GameState.reset_for_new_game()


func test_attunements_and_stats() -> void:
	GameState.reset_for_new_game()
	check(not Inventory.can_attune(&"steady_heart"), "costs resonance")
	Inventory.add_resonance(20)
	check(not Inventory.can_attune(&"steady_heart_2"), "requires the first heart")
	check(Inventory.attune(&"steady_heart") and Inventory.attune(&"steady_heart_2"), "chain bought")
	check(int(Inventory.stat("max_health")) == 2, "two hearts")
	Inventory.attune(&"quick_step")
	Inventory.add(&"brass_compass", 1, false)
	Inventory.equip(&"brass_compass")
	check(is_equal_approx(Inventory.stat("dodge_cooldown_mult"), 0.8 * 0.7), "multipliers multiply")
	check(Inventory.resonance == 20 - 4 - 8 - 4, "resonance spent")
	var saved := Inventory.to_dict()
	Inventory.reset()
	Inventory.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(Inventory.has_attunement(&"steady_heart_2") and Inventory.equipped["trinket"] == &"brass_compass", "survives save")
	GameState.reset_for_new_game()


func test_money_and_shop_rules() -> void:
	GameState.reset_for_new_game()
	Inventory.money = 5
	check(StoryRules.evaluate({"money_at_least": 4}), "can afford")
	StoryRules.apply([{"spend_money": 4}, {"give_item": ["tea_flask", 1]}])
	check(Inventory.money == 1 and Inventory.has(&"tea_flask"), "bought")
	check(not StoryRules.evaluate({"money_at_least": 4}), "cannot afford twice")
	check(not Inventory.spend_money(4), "no debt")
	GameState.reset_for_new_game()


func test_item_evidence_advances_case() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_rosalind")
	Inventory.add(&"ledger_page", 1, false)
	check(Journal.has_evidence(&"e_census_page"), "key item grants its evidence")
	check(Journal.case_stage(&"case_rosalind") == &"page", "evidence advances the case")
	GameState.reset_for_new_game()


func test_health_iframes_and_heal() -> void:
	var h := Health.new()
	h.max_health = 5
	h.invulnerability_time = 0.0
	add_child(h)
	check(h.take_damage(2, Vector2.ZERO) and h.health == 3, "damage")
	h.grant_invulnerability(10.0)
	check(not h.take_damage(1, Vector2.ZERO) and h.health == 3, "i-frames block damage")
	h.heal(5)
	check(h.health == 5, "heal clamps to max")
	h.queue_free()


func test_enemy_variants_defined() -> void:
	for v: String in ["hollow", "clinger", "wailer"]:
		check(EchoEnemy.variants().has(StringName(v)), "variant %s" % v)
	check(bool(EchoEnemy.variants()[&"wailer"].get("ranged", false)), "wailer is ranged")


func test_save_migration_from_v2() -> void:
	var dir := _fresh_save_dir()
	var v2 := SaveService.make_envelope(GameState.to_dict())
	v2["schema_version"] = 2
	v2["payload"].erase("inventory")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v2))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["envelope"]["payload"].has("inventory"), "v2 save gains an inventory")
	_cleanup(dir)


# --- M4: society, knowledge, quest graphs ------------------------------------------

func test_quest_graphs_valid() -> void:
	var problems := Journal.validate_graphs()
	check(problems.is_empty(), "graph problems: %s" % "; ".join(problems))


func test_every_memory_has_text() -> void:
	var events := {}
	for id: StringName in DialogueService.dialogues:
		_collect_memories(DialogueService.dialogues[id], events)
	for e: String in events:
		check(tr("MEM_" + e.to_upper()) != "MEM_" + e.to_upper(), "memory text for %s" % e)
	check(events.size() >= 10, "memories collected (%d)" % events.size())


func _collect_memories(v: Variant, out: Dictionary) -> void:
	if v is Array:
		for x: Variant in v:
			_collect_memories(x, out)
	elif v is Dictionary:
		for k: Variant in v:
			if String(k) == "remember":
				out[String(v[k][1])] = true
			_collect_memories(v[k], out)


func test_gossip_spreads_after_a_period() -> void:
	GameState.reset_for_new_game()
	WorldClock.reset()
	Society.publish(&"reported_door")
	check(not Society.knows(&"mara_venn", &"reported_door"), "not known immediately")
	WorldClock.wait_until_hour(12)  # next period
	check(Society.knows(&"mara_venn", &"reported_door"), "known after a period")
	Society.publish(&"opened_door")  # keepers + open hand only
	WorldClock.wait_until_hour(18)
	check(Society.knows(&"ivo_calder", &"opened_door"), "keepers hear about it")
	check(Society.knows(&"nadiya_sol", &"opened_door"), "open hand hears about it")
	check(not Society.knows(&"dana_pike", &"opened_door"), "civic does not")
	var saved := Society.to_dict()
	Society.reset()
	Society.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(Society.knows(&"ivo_calder", &"opened_door"), "knowledge survives save")
	GameState.reset_for_new_game()


func test_relationship_milestones_and_factions() -> void:
	GameState.reset_for_new_game()
	GameState.change_relationship(&"mara_venn", 2)
	check(not GameState.has_flag(&"rel.mara_venn.friend"), "not yet a friend")
	GameState.change_relationship(&"mara_venn", 1)
	check(GameState.has_flag(&"rel.mara_venn.friend"), "friend at 3")
	GameState.change_relationship(&"nadiya_sol", -3)
	check(GameState.has_flag(&"rel.nadiya_sol.distrust"), "distrust at -3")
	StoryRules.apply({"faction": ["keepers", 3]})
	check(StoryRules.evaluate({"faction_at_least": ["keepers", 3]}), "faction condition")
	check(Society.tier_of(3) == "TRUSTED" and Society.tier_of(-7) == "HOSTILE", "tiers")
	GameState.reset_for_new_game()


func test_late_radio_fails_the_case() -> void:
	GameState.reset_for_new_game()
	WorldClock.reset()
	Journal.start_case(&"case_radio")
	GameState.set_flag(&"has_radio")
	for i in 2:
		WorldClock.sleep_until_hour(7)
	check(Journal.case_status(&"case_radio") == Journal.STATUS_ACTIVE and Journal.days_left(&"case_radio") == 1, "a day left")
	WorldClock.sleep_until_hour(7)
	check(Journal.case_status(&"case_radio") == Journal.STATUS_FAILED, "too late: the case fails")
	check(not GameState.has_flag(&"has_radio") and GameState.get_relationship(&"edda_halloway") < 0, "and it costs you")
	GameState.reset_for_new_game()


func test_lantern_row_clues_not_missable_after_failed_radio() -> void:
	# Even if the radio delivery fails, Mrs Halloway and the map still supply clues.
	var hub: Array = DialogueService.dialogues[&"halloway"]["nodes"]["hub"]["choices"]
	var has_direct_question := false
	for c: Dictionary in hub:
		if str(c.get("next")) == "lr1":
			has_direct_question = true
	check(has_direct_question, "Halloway can be asked about Lantern Row directly")


func test_save_migration_from_v3() -> void:
	var dir := _fresh_save_dir()
	var v3 := SaveService.make_envelope(GameState.to_dict())
	v3["schema_version"] = 3
	v3["payload"].erase("society")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["envelope"]["payload"].has("society"), "v3 save gains society")
	_cleanup(dir)


# --- M5: work, ownership, economy ------------------------------------------------

func test_economy_has_no_exploits() -> void:
	var problems := Economy.validate()
	check(problems.is_empty(), "economy problems: %s" % "; ".join(problems))
	for id: StringName in Inventory.item_defs:
		var buy := Economy.cheapest_price(id)
		if buy > 0:
			check(Economy.sell_price(id) < buy, "%s cannot be flipped for profit" % id)


func test_jobs_board_is_deterministic_and_pays() -> void:
	GameState.reset_for_new_game()
	var first := Livelihood.offered.duplicate()
	Livelihood._offer_jobs(WorldClock.day)
	check(Livelihood.offered == first, "same day, same board")
	check(Livelihood.offered.size() > 0 and Livelihood.offered.size() <= Livelihood.JOBS_PER_DAY, "some jobs offered")
	check(not Livelihood.offered.has(&"echo_clock"), "level-gated job hidden at level 1")
	var job := Livelihood.offered[0]
	check(Livelihood.accept(job), "accept")
	var spot := StringName(Livelihood.job(job)["spot"])
	check(Livelihood.active_job_for_spot(spot) == job, "spot becomes active")
	Inventory.add(&"scrap", 5, false)
	var money := Inventory.money
	Livelihood.complete(job)
	check(Inventory.money == money + int(Livelihood.job(job)["pay"]), "paid")
	check(Inventory.count(&"scrap") == 5 - int(Livelihood.job(job)["scrap"]), "scrap used")
	check(Livelihood.repair_xp > 0, "xp gained")
	GameState.reset_for_new_game()


func test_repair_levels_widen_zone() -> void:
	GameState.reset_for_new_game()
	var z1 := Livelihood.repair_zone(2)
	Livelihood.add_repair_xp(16)
	check(Livelihood.repair_level() == 3 and GameState.has_flag(&"repair.level_3"), "level 3 at 16 xp")
	check(Livelihood.repair_zone(2) > z1, "zone grows with skill")
	Livelihood._offer_jobs(WorldClock.day + 1)
	GameState.reset_for_new_game()


func test_rent_and_debt_are_gentle() -> void:
	GameState.reset_for_new_game()
	Inventory.money = 10
	for i in 7:
		WorldClock.sleep_until_hour(7)
	check(WorldClock.day == 8, "a week passed")
	check(Inventory.money == 0 and Livelihood.rent_debt == 5, "short rent becomes debt, not eviction")
	Inventory.money = 20
	WorldClock.sleep_until_hour(7)
	check(Livelihood.rent_debt == 0 and Inventory.money == 15, "debt collected when possible")
	GameState.reset_for_new_game()


func test_stall_income_is_bounded() -> void:
	GameState.reset_for_new_game()
	GameState.set_flag(&"biz.unlocked")
	Livelihood.stall["stock"] = 100
	Livelihood.set_stall_open(true)
	for tier in ["fair", "normal", "premium"]:
		Livelihood.set_stall_tier(tier)
		var r := Livelihood.resolve_stall_day()
		check(int(r["sold"]) <= int(Livelihood.business_def["max_customers"]), "%s sales capped" % tier)
	var fair := Livelihood.expected_customers("fair")
	var premium := Livelihood.expected_customers("premium")
	check(fair >= premium, "fair prices draw more customers")
	GameState.reset_for_new_game()


func test_home_upgrades_and_crafting() -> void:
	GameState.reset_for_new_game()
	Inventory.money = 100
	check(Economy.buy(&"halloway", 1), "buy the bed")
	check(Livelihood.has_home_upgrade(&"good_bed") and int(Inventory.stat("max_health")) == 1, "bed gives +1 health")
	check(not Economy.buy(&"halloway", 1), "cannot buy twice")
	Inventory.add(&"scrap", 4, false)
	check(Economy.craft(&"repair_kit") and Inventory.count(&"repair_kit") == 1, "craft a kit")
	check(not Inventory.use(&"repair_kit"), "kits are not used by hand")
	check(Economy.sell(&"repair_kit") and Inventory.count(&"repair_kit") == 0, "sell a kit")
	GameState.reset_for_new_game()


func test_save_migration_from_v4() -> void:
	var dir := _fresh_save_dir()
	var v4 := SaveService.make_envelope(GameState.to_dict())
	v4["schema_version"] = 4
	v4["payload"].erase("life")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v4))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["envelope"]["payload"].has("life"), "v4 save gains life")
	_cleanup(dir)


# --- M6: content pipeline --------------------------------------------------------

func test_location_budgets() -> void:
	var budgets: Dictionary = DataFiles.read_json("res://data/world/budgets.json")
	for scene_id: StringName in SceneFlow.LOCATIONS:
		var b: Dictionary = (budgets["default"] as Dictionary).duplicate()
		b.merge(budgets.get(String(scene_id), {}), true)
		var t0 := Time.get_ticks_usec()
		var root: Node = (load(SceneFlow.LOCATIONS[scene_id]) as PackedScene).instantiate()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var got := {"nodes": 0, "props": 0, "interactables": 0, "npcs": 0, "enemies": 0, "tiles": 0}
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			got["nodes"] += 1
			if n is WorldProp:
				got["props"] += 1
			elif n is Interactable:
				got["interactables"] += 1
			elif n is Npc:
				got["npcs"] += 1
			elif n is EchoEnemy or n is CensusTaker or n is Conductor or n is Archivist or n is Reviser:
				got["enemies"] += 1
			elif n is TilePainter:
				got["tiles"] += (n as TilePainter).layout.replace("\n", "").replace(" ", "").replace(".", "").length()
		root.free()
		for k: String in got:
			check(int(got[k]) <= int(b[k]), "%s: %s %d within budget %d" % [scene_id, k, got[k], b[k]])
		check(ms <= float(b["instantiate_ms"]), "%s: instantiated in %.1f ms (budget %d)" % [scene_id, ms, b["instantiate_ms"]])
		print("    %s: %d nodes, %d props, %d tiles, %.1f ms" % [scene_id, got["nodes"], got["props"], got["tiles"], ms])


func test_locations_register_themselves() -> void:
	check(SceneFlow.LOCATIONS.size() >= 5, "locations found by scanning scenes/locations")
	for scene_id: StringName in SceneFlow.LOCATIONS:
		check(String(SceneFlow.LOCATIONS[scene_id]).ends_with("/%s.tscn" % scene_id), "%s: id is the file name" % scene_id)


func test_data_files_merge_and_reject_duplicates() -> void:
	var files := DataFiles.files_for("res://data/items/items")
	check(files.size() >= 1 and files[0].ends_with("/items.json"), "primary file first")
	var items := DataFiles.defs("res://data/items/items")
	check(items.has(&"scrap") and not items.has(&"_doc"), "comments skipped, ids loaded")
	check(Inventory.item_defs.size() == items.size(), "inventory uses the merged files")
	check(DataFiles.files_for("res://data/world/facts").size() >= 1, "facts found")
	for f in DataFiles.files_for("res://data/world/facts"):
		check(not f.ends_with("factions.json"), "prefix match is exact: factions.json is not a facts file")


func test_enemy_variants_are_data() -> void:
	for id: StringName in EchoEnemy.variants():
		var v: Dictionary = EchoEnemy.variants()[id]
		for k in ["max_health", "move_speed", "chase_speed", "windup_time", "attack_range", "resonance", "tint"]:
			check(v.has(k), "%s has %s" % [id, k])
	var e := (load("res://scenes/combat/echo_enemy.tscn") as PackedScene).instantiate() as EchoEnemy
	e.variant = "clinger"
	add_child(e)
	check(e.max_health == 1 and is_equal_approx(e.sprite.scale.x, 0.8), "clinger stats come from data")
	e.queue_free()


# --- M7: campaign -------------------------------------------------------------------

func test_campaign_acts_start_in_order() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	Campaign.check()
	check(Campaign.current_act() == &"prologue", "a new game is in the prologue")
	check(not Campaign.has_started(&"act1"), "act I waits for the door")
	Journal.start_case(&"case_door")
	Journal.complete_case(&"case_door", &"opened")
	Campaign.check()
	check(Campaign.current_act() == &"act1", "closing the door case starts act I")
	check(Journal.case_status(&"case_two_maps") == Journal.STATUS_ACTIVE, "act I opens its main case")
	Campaign.check()
	check(Journal.case_status(&"case_two_maps") == Journal.STATUS_ACTIVE and Campaign.current_act() == &"act1", "checking again changes nothing")
	Journal.complete_case(&"case_two_maps", &"kept")
	Campaign.check()
	check(Campaign.current_act() == &"act2" and Journal.case_status(&"case_misplaced") == Journal.STATUS_ACTIVE, "act II follows act I")
	for i in 3:
		Campaign.check()
	check(Campaign.current_act() == &"act2", "planned acts never start")
	GameState.is_playing = false
	GameState.reset_for_new_game()


func test_campaign_data_is_consistent() -> void:
	var ids := {}
	for a: Dictionary in Campaign.acts:
		check(not ids.has(a["id"]), "act %s is unique" % a["id"])
		ids[a["id"]] = true
		for k in ["title", "subtitle"]:
			check(tr(String(a[k])) != String(a[k]), "%s %s translated" % [a["id"], k])
	check(Campaign.acts.size() == 6 and Campaign.acts[0]["id"] == "prologue", "prologue plus five acts")


func test_act_one_incidents_lead_to_the_map() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_two_maps")
	Journal.start_case(&"case_storeroom")
	Journal.start_case(&"case_larger_house")
	check(not Journal.can_form(&"incidents_share_mark"), "one incident is not a pattern")
	Journal.add_evidence(&"e_storeroom_mark")
	check(Journal.case_stage(&"case_storeroom") == &"tell", "the stencil advances the storeroom")
	Journal.add_evidence(&"e_house_longer")
	Journal.add_evidence(&"e_house_mark")
	check(Journal.case_stage(&"case_larger_house") == &"tell", "the bed advances the house")
	check(Journal.form_hypothesis(&"incidents_share_mark"), "two marked incidents form the pattern")
	check(Journal.case_stage(&"case_two_maps") == &"map", "the pattern points to the map")
	Journal.add_evidence(&"e_two_maps")
	check(Journal.case_stage(&"case_two_maps") == &"hand", "the map asks whose hand")
	check(not Journal.can_form(&"halloway_drew_map") or Journal.has_evidence(&"e_landlord_note"), "the hand needs a sample")
	Journal.add_evidence(&"e_rent_book")
	check(Journal.form_hypothesis(&"halloway_drew_map") and Journal.case_stage(&"case_two_maps") == &"turn", "handwriting identified")
	GameState.reset_for_new_game()


func test_closed_cases_do_not_replay_their_last_stage() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_radio")
	Journal.set_case_stage(&"case_radio", &"return")
	check(StoryRules.evaluate({"quest_stage": ["case_radio", "return"]}), "stage matches while open")
	Journal.complete_case(&"case_radio", &"delivered")
	check(not StoryRules.evaluate({"quest_stage": ["case_radio", "return"]}), "a closed case is at no stage")
	check(DialogueService.entry_node(DialogueService.dialogues[&"jonah"]) != "reward1", "Jonah does not pay the radio reward twice")
	GameState.reset_for_new_game()


# --- M7b: companions, the Conductor, act II -----------------------------------------

func test_party_companion_lifecycle() -> void:
	GameState.reset_for_new_game()
	check(Party.companion == &"", "nobody at the start")
	check(not Party.can_join(&"jonah_rook"), "companions wait for the Ward")
	GameState.set_flag(&"ward.open")
	check(Party.can_join(&"jonah_rook") and StoryRules.evaluate({"can_join": "mara_venn"}), "the Ward opens the party")
	StoryRules.apply([{"companion": "jonah_rook"}])
	check(Party.is_companion(&"jonah_rook") and StoryRules.evaluate({"companion": "jonah_rook"}), "recruited by story effect")
	check(NpcRegistry.resolve(&"jonah_rook").is_empty(), "a companion leaves their schedule")
	var saved := GameState.to_dict()
	GameState.reset_for_new_game()
	check(Party.companion == &"", "reset clears the party")
	GameState.from_dict(saved)
	check(Party.is_companion(&"jonah_rook"), "the party survives save and load")
	Party.set_companion(&"nobody")
	check(Party.is_companion(&"jonah_rook"), "unknown companions are refused")
	StoryRules.apply([{"companion": ""}])
	check(Party.companion == &"" and not NpcRegistry.resolve(&"jonah_rook").is_empty(), "sent home, back on schedule")
	GameState.reset_for_new_game()


func test_jonah_patches_you_up() -> void:
	GameState.reset_for_new_game()
	var npc := (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate() as Npc
	add_child(npc)
	npc.npc_id = &"jonah_rook"
	var f := Follower.new()
	f.setup(npc, Party.def_of(&"jonah_rook"))
	var healed: Array[int] = []
	var on_heal := func(amount: int) -> void: healed.append(amount)
	EventHub.player_heal_requested_amount.connect(on_heal)
	EventHub.player_health_changed.emit(3, 5)
	check(healed.is_empty(), "no help while healthy")
	EventHub.player_health_changed.emit(1, 5)
	check(healed == [2], "patched up at 1 health")
	EventHub.player_health_changed.emit(1, 5)
	check(healed.size() == 1, "then on cooldown")
	EventHub.player_heal_requested_amount.disconnect(on_heal)
	check(npc.collision_layer == 0, "a follower never blocks the player")
	npc.queue_free()


func test_slow_and_conductor_lanes() -> void:
	var e := (load("res://scenes/combat/echo_enemy.tscn") as PackedScene).instantiate() as EchoEnemy
	add_child(e)
	check(not e.is_slowed(), "not slowed by default")
	e.slow(2.0)
	check(e.is_slowed(), "Mara's pin slows")
	e.queue_free()
	var c := (load("res://scenes/combat/conductor.tscn") as PackedScene).instantiate() as Conductor
	add_child(c)
	var dummy := Node2D.new()
	add_child(dummy)
	for lane in c.lane_offsets.size():
		dummy.global_position = c.global_position + Vector2(0, c.lane_offsets[lane])
		for count in [1, 2, 3]:
			var picked := c._pick_lanes(dummy, count)
			check(picked.has(lane), "the player's lane is always called")
			check(picked.size() < c.lane_offsets.size(), "one lane is always safe")
	check(c.phase() == 1, "full health is phase one")
	c.health.health = 9
	check(c.phase() == 3, "low health is phase three")
	dummy.queue_free()
	c.queue_free()


func test_save_migration_from_v5() -> void:
	var dir := _fresh_save_dir()
	var v5 := SaveService.make_envelope(GameState.to_dict())
	v5["schema_version"] = 5
	v5["payload"].erase("party")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v5))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["envelope"]["payload"].has("party"), "v5 save gains the party")
	_cleanup(dir)


func test_first_match_and_outcomes() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_two_maps")
	Journal.complete_case(&"case_two_maps", &"kept")
	check(StoryRules.evaluate({"quest_outcome": ["case_two_maps", "kept"]}), "outcome matches")
	check(not StoryRules.evaluate({"quest_outcome": ["case_two_maps", "shared"]}), "other outcome does not")
	StoryRules.apply([{"first_match": [
		{"if": {"flag": "nope"}, "do": [{"set_flag": "branch.a"}]},
		{"if": {"quest_outcome": ["case_two_maps", "kept"]}, "do": [{"set_flag": "branch.b"}]},
		{"if": {}, "do": [{"set_flag": "branch.c"}]}]}])
	check(GameState.has_flag(&"branch.b") and not GameState.has_flag(&"branch.a") and not GameState.has_flag(&"branch.c"), "only the first true branch runs")
	GameState.reset_for_new_game()


func test_act_three_picks_the_confessor() -> void:
	for setup in [["", "", "act3.confessor_ivo"], ["case_two_maps", "kept", "act3.confessor_halloway"], ["case_eleventh", "sealed", "act3.confessor_mara"]]:
		GameState.reset_for_new_game()
		GameState.is_playing = true
		for c in [&"case_door", &"case_two_maps", &"case_misplaced"]:
			Journal.start_case(c)
			Journal.complete_case(c, &"x")
		if setup[0] != "":
			Journal.cases.erase(StringName(setup[0]))
			Journal.start_case(StringName(setup[0]))
			Journal.complete_case(StringName(setup[0]), StringName(setup[1]))
		Campaign.check()
		check(Campaign.current_act() == &"act3", "act III starts after act II")
		check(GameState.has_flag(StringName(setup[2])), "confessor: %s" % setup[2])
		var count := 0
		for f in ["act3.confessor_ivo", "act3.confessor_mara", "act3.confessor_halloway"]:
			count += int(GameState.has_flag(StringName(f)))
		check(count == 1, "exactly one confessor")
	GameState.is_playing = false
	GameState.reset_for_new_game()


func test_flood_water_and_islands() -> void:
	var w := FloodWater.new()
	w.size = Vector2(100, 100)
	w.islands = [Rect2(10, 60, 20, 20)]
	w.level = 0.5
	check(w.is_wet(Vector2(50, 80)), "below the waterline is wet")
	check(not w.is_wet(Vector2(50, 30)), "above it is dry")
	check(not w.is_wet(Vector2(20, 70)), "islands stay dry")
	check(not w.is_wet(Vector2(150, 80)), "outside the arena is dry")
	w.free()
	var a := (load("res://scenes/combat/archivist.tscn") as PackedScene).instantiate() as Archivist
	add_child(a)
	await get_tree().process_frame
	a.engage()
	check(a.state == Archivist.State.LOW and not a.is_submerged(), "starts on the surface")
	a._enter(Archivist.State.RISING, 1.0)
	check(a.is_submerged() and a.water.target > 0.5, "sinks and the water rises")
	a.stun(1.0)
	check(a.state == Archivist.State.RISING, "the flash can't reach him under water")
	a.water.queue_free()
	a.queue_free()


func test_testimony_verdicts() -> void:
	GameState.reset_for_new_game()
	Journal.add_evidence(&"e_t_nurse_log")
	StoryRules.apply([{"verdict": ["e_t_nurse_log", "authentic"]}])
	check(Journal.verdict_of(&"e_t_nurse_log") == "authentic" and Journal.is_verdict_correct(&"e_t_nurse_log"), "judged, and right")
	Journal.set_verdict(&"e_t_admissions", "authentic")
	check(not Journal.is_verdict_correct(&"e_t_admissions"), "the register was edited")
	check(not StoryRules.evaluate({"judged": ["e_t_nurse_log", "e_t_admissions", "e_t_doctor"]}), "not all judged")
	Journal.set_verdict(&"e_t_doctor", "unreliable")
	check(StoryRules.evaluate({"judged": ["e_t_nurse_log", "e_t_admissions", "e_t_doctor"]}), "all judged")
	check(StoryRules.evaluate({"verdicts_correct_at_least": [["e_t_nurse_log", "e_t_admissions", "e_t_doctor"], 2]}), "two of three right")
	Journal.set_verdict(&"e_t_doctor", "authentic")
	check(not StoryRules.evaluate({"verdicts_correct_at_least": [["e_t_nurse_log", "e_t_admissions", "e_t_doctor"], 2]}), "verdicts can be changed")
	var saved := Journal.to_dict()
	Journal.reset()
	Journal.from_dict(saved)
	check(Journal.verdict_of(&"e_t_doctor") == "authentic", "verdicts are saved")
	Journal.set_verdict(&"e_ward_census", "edited")
	check(Journal.verdict_of(&"e_ward_census") == "", "only testimony can be judged")
	GameState.reset_for_new_game()


func test_every_testimony_has_a_truth() -> void:
	for id: StringName in Journal.evidence_defs:
		var d: Dictionary = Journal.evidence_defs[id]
		if d.get("testimony", false):
			check(Journal.VERDICTS.has(String(d.get("truth", ""))), "%s has a hidden truth" % id)


func test_reconstruction_true_or_distorted() -> void:
	for right in [true, false]:
		GameState.reset_for_new_game()
		Journal.start_case(&"case_index")
		Journal.set_case_stage(&"case_index", &"sites")
		for t in ["e_t_nurse_log", "e_t_admissions", "e_t_doctor"]:
			Journal.add_evidence(StringName(t))
			var truth := String(Journal.evidence_defs[StringName(t)]["truth"])
			Journal.set_verdict(StringName(t), truth if right else ("edited" if truth != "edited" else "authentic"))
		var d: Dictionary = DialogueService.dialogues[&"recon_memory_hospital"]
		check(DialogueService.entry_node(d) == "r1", "the night can be put back together")
		StoryRules.apply(d["nodes"]["r1"]["effects"])
		check(GameState.has_flag(&"site.hospital.true") == right and GameState.has_flag(&"site.hospital.distorted") == (not right), "true night only with good verdicts")
		check(Journal.case_stage(&"case_index") == &"sites", "one site is not enough")
		check(DialogueService.entry_node(d) == "after", "a reconstruction is final")
	GameState.reset_for_new_game()


func test_act_four_has_no_free_progress() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_index")
	for i in 10:
		WorldClock.sleep_until_hour(7)
	check(Journal.case_stage(&"case_index") == &"nodes", "waiting changes nothing")
	GameState.reset_for_new_game()


func test_reviser_always_leaves_safe_cells() -> void:
	for pattern in ["rows", "columns", "checker"]:
		var r := (load("res://scenes/combat/reviser.tscn") as PackedScene).instantiate() as Reviser
		r.pattern = pattern
		add_child(r)
		await get_tree().process_frame
		for hp in [r.max_health, r.max_health / 2, 3]:
			r.health.health = hp
			for i in 4:
				var cells := r.pick_cells()
				check(cells.size() > 0 and cells.size() < r.cols * r.rows, "%s phase %d leaves safe cells" % [pattern, r.phase()])
		r.stun(1.0)
		r.grid.queue_free()
		r.queue_free()



# --- M7e: quests without fail-forward ---------------------------------------------------

func test_waiting_never_advances_anything() -> void:
	for id: StringName in Journal.case_defs:
		var def: Dictionary = Journal.case_defs[id]
		check(not def.has("fail_forward"), "%s has no fail-forward" % id)
		for stage: String in def.get("stages", {}):
			GameState.reset_for_new_game()
			Journal.start_case(id)
			Journal.cases[id]["stage"] = StringName(stage)
			var deadline := Journal.deadline_for(id)
			for i in 30:
				WorldClock.sleep_until_hour(7)
			if deadline.is_empty():
				check(Journal.case_status(id) == Journal.STATUS_ACTIVE and Journal.case_stage(id) == StringName(stage), "%s/%s: thirty days change nothing" % [id, stage])
			else:
				check(Journal.case_status(id) == Journal.STATUS_FAILED and Journal.cases[id]["outcome"] == StringName(deadline["outcome"]), "%s/%s: the deadline fails it" % [id, stage])
	GameState.reset_for_new_game()


func test_failable_side_quests_share() -> void:
	var side := 0
	var failable := 0
	for id: StringName in Journal.case_defs:
		var def: Dictionary = Journal.case_defs[id]
		if def.get("main", false):
			check(not def.has("deadlines"), "%s: the main story can't be failed by time" % id)
			continue
		side += 1
		if def.has("deadlines"):
			failable += 1
	check(failable * 4 >= side, "at least a quarter of side quests can fail (%d of %d)" % [failable, side])


func test_main_story_survives_failed_incidents() -> void:
	GameState.reset_for_new_game()
	for c in [&"case_two_maps", &"case_storeroom", &"case_larger_house"]:
		Journal.start_case(c)
	Journal.fail_case(&"case_storeroom", &"bricked")
	Journal.fail_case(&"case_larger_house", &"closed")
	check(not Journal.can_form(&"incidents_share_mark"), "two failed incidents leave a gap")
	Journal.add_evidence(&"e_census_page")
	Journal.add_evidence(&"e_house_mark")
	check(Journal.can_form(&"incidents_share_mark"), "the tram stop and what you saw before the room closed still count")
	check(not StoryRules.evaluate({"quest_active": "case_storeroom"}), "a bricked storeroom stays shut")
	GameState.reset_for_new_game()


func test_objectives_progress_and_rewards() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_misplaced")
	Journal.set_case_stage(&"case_misplaced", &"residents")
	check(Journal.pinned == &"case_misplaced", "main cases pin themselves")
	var objs := Journal.objectives_for(&"case_misplaced")
	check(objs.size() == 2 and objs[0]["have"] == 0 and objs[0]["need"] == 3, "residents heard 0/3")
	GameState.set_flag(&"ward.heard_bea")
	GameState.set_flag(&"ward.heard_abel")
	check(Journal.objective_text(Journal.objectives_for(&"case_misplaced")[0]).ends_with("(2/3)"), "progress shows 2/3")
	var res := Inventory.resonance
	for f in [&"ward.heard_ellie", &"ward.bea_message", &"ward.abel_left", &"ward.ellie_hopes"]:
		GameState.set_flag(f)
	Journal._check_objectives()
	check(Inventory.resonance == res + 2 and GameState.has_flag(&"obj.case_misplaced.answered"), "the optional objective pays once")
	Journal._check_objectives()
	check(Inventory.resonance == res + 2, "and only once")
	check(Journal.current_objective_text(&"case_misplaced") == tr("CASE_MP_RESIDENTS"), "with every objective met the stage text shows")
	var saved := Journal.to_dict()
	Journal.reset()
	Journal.from_dict(saved)
	check(Journal.pinned == &"case_misplaced", "the pin is saved")
	GameState.reset_for_new_game()


func test_difficulty_and_the_satchel() -> void:
	GameState.reset_for_new_game()
	for d in GameState.DIFFICULTIES:
		GameState.difficulty = d
		check(GameState.enemy_health(10) == {"story": 7, "normal": 10, "hard": 13}[d], "%s enemy health" % d)
		check(GameState.incoming_damage(1) == (2 if d == "hard" else 1), "%s incoming damage" % d)
	GameState.difficulty = "normal"
	Inventory.money = 40
	Inventory.resonance = 6
	GameState.drop_satchel(&"echo_ward", Vector2(10, 20))
	check(Inventory.money == 20 and Inventory.resonance == 0 and int(GameState.satchel["money"]) == 20, "half the money and all Resonance stay behind")
	var saved := GameState.to_dict()
	GameState.reset_for_new_game()
	GameState.from_dict(saved)
	check(GameState.difficulty == "normal" and GameState.satchel.get("scene") == "echo_ward", "difficulty and satchel are saved")
	GameState.recover_satchel()
	check(Inventory.money == 40 and Inventory.resonance == 6 and GameState.satchel.is_empty(), "picked up again")
	GameState.difficulty = "story"
	GameState.drop_satchel(&"echo_ward", Vector2.ZERO)
	check(Inventory.money == 40 and GameState.satchel.is_empty(), "story mode loses nothing")
	GameState.reset_for_new_game()


func test_save_migration_from_v6() -> void:
	var dir := _fresh_save_dir()
	var v6 := SaveService.make_envelope(GameState.to_dict())
	v6["schema_version"] = 6
	v6["payload"]["profile"].erase("difficulty")
	v6["payload"].erase("satchel")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(v6))
	f.close()
	var r := SaveService.read_slot(1)
	check(r["ok"] and r["envelope"]["payload"]["profile"]["difficulty"] == "normal" and r["envelope"]["payload"].has("satchel"), "v6 saves play on normal")
	_cleanup(dir)
