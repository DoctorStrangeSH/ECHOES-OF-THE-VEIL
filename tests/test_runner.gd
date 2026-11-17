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
			elif n is EchoEnemy or n is CensusTaker or n is Conductor or n is Archivist or n is Reviser or n is Director:
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

func test_echo_traits() -> void:
	var scene := load("res://scenes/combat/echo_enemy.tscn") as PackedScene
	var room := Node2D.new()
	add_child(room)
	# Guard: a light hit from the front glances off, from behind it lands.
	var w := scene.instantiate() as EchoEnemy
	w.variant = "warden"
	room.add_child(w)
	check(w.guard and w.max_health >= 5, "the Warden guards and is tough")
	w._dir = LayeredCharacterSprite.Dir.DOWN
	check(w._modify_damage(1, w.global_position + Vector2(0, 30)) == 0, "a light hit from the front is turned aside")
	check(w._modify_damage(1, w.global_position + Vector2(0, -30)) == 1, "from behind it lands")
	check(w._modify_damage(2, w.global_position + Vector2(0, 30)) == 2, "a heavy hit goes through the guard")
	# Resist stun.
	var m := scene.instantiate() as EchoEnemy
	m.variant = "mourner"
	m.position = Vector2(40, 0)
	room.add_child(m)
	m.stun(2.0)
	check(m.state != EchoEnemy.State.STUNNED, "the Sitter ignores the Lantern Flash")
	# Mend heals a hurt neighbour.
	w.health.take_damage(2, Vector2.ZERO)
	var before := w.health.health
	m.state = EchoEnemy.State.CHASE
	m._trait_timer = 0.0
	m._tick_traits(0.1)
	check(w.health.health == before + 1, "the Sitter mends the echoes around it")
	# Split: a Doubled comes apart into two clingers that drop nothing.
	var d := scene.instantiate() as EchoEnemy
	d.variant = "doubled"
	d.position = Vector2(-40, 0)
	room.add_child(d)
	var count := func() -> int:
		var n := 0
		for c in room.get_children():
			if c is EchoEnemy and (c as EchoEnemy).variant == "clinger":
				n += 1
		return n
	d.health.take_damage(99, Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	check(count.call() == 2, "the Doubled comes apart in two")
	for c in room.get_children():
		if c is EchoEnemy and (c as EchoEnemy).variant == "clinger":
			check((c as EchoEnemy).resonance_drop == 0, "pieces drop no resonance")
	# Summon: the Caller calls a clinger, up to its limit.
	var k := scene.instantiate() as EchoEnemy
	k.variant = "caller"
	room.add_child(k)
	k.state = EchoEnemy.State.CHASE
	for i in 4:
		k._trait_timer = 0.0
		k._tick_traits(0.1)
		await get_tree().process_frame
	check(k._summoned.size() == 2, "the Caller calls no more than two")
	check(EchoEnemy.variants().get(&"flicker", {}).get("blink", false), "the Flicker blinks")
	room.queue_free()
	await get_tree().process_frame


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


# --- M7f: act V, the Director, endings --------------------------------------------------

func test_director_is_shaped_by_allies_and_evidence() -> void:
	GameState.reset_for_new_game()
	var full := Director.health_for_conditions()
	GameState.set_flag(&"site.hospital.true")
	GameState.set_flag(&"site.station.true")
	check(Director.health_for_conditions() < full, "true nights weaken him")
	for a in Director.ALLIES:
		GameState.set_flag(StringName("anchor.ally.%s" % a))
	check(Director.health_for_conditions() >= int(round(Director.BASE_HEALTH * 0.4)), "but never below 40%")
	var d := (load("res://scenes/combat/director.tscn") as PackedScene).instantiate() as Director
	add_child(d)
	await get_tree().process_frame
	check(d.mechanics == ["stamps"] and d.telegraph_mult > 1.0, "allies take his tricks away, not the fight")
	d.engage()
	check(d.state == Director.State.STALK, "he still has to be beaten")
	d.grid.queue_free()
	d.queue_free()
	GameState.reset_for_new_game()


func test_endings_and_the_accord_threshold() -> void:
	GameState.reset_for_new_game()
	var choices: Array = DialogueService.dialogues[&"anchor_heart"]["nodes"]["choose"]["choices"]
	var accord: Dictionary = choices.filter(func(c: Dictionary) -> bool: return c["text"] == "ENDING_ACCORD_CHOICE")[0]
	check(not StoryRules.evaluate(accord["if"]), "the accord has to be earned")
	Society.standing[&"unwritten"] = 4
	for f in [&"site.hospital.true", &"site.home.true", &"anchor.ally.jonah_rook", &"anchor.ally.mara_venn", &"anchor.ally.sera_vale",
			&"rosalind.reunited", &"world.theo_remembers", &"world.lamp_counts"]:
		GameState.set_flag(f)
	check(StoryRules.evaluate(accord["if"]), "trust, truth, allies and true nights open it")
	check(StoryRules.evaluate({"count_at_least": [[{"flag": "rosalind.reunited"}, {"flag": "nope"}], 1]}), "count_at_least")
	GameState.reset_for_new_game()


func test_epilogue_cards() -> void:
	GameState.reset_for_new_game()
	GameState.set_flag(&"ending.custodians")
	GameState.set_flag(&"rosalind.reunited")
	GameState.set_flag(&"world.lamp_counts")
	var cards := EpilogueScreen.build_cards()
	check(cards[0]["title"] == "ENDING_CUSTODIANS_TITLE", "the ending comes first")
	check(cards[-1]["text"] == "EPI_END", "and the end card last")
	var texts := cards.map(func(c: Dictionary) -> String: return String(c["text"]))
	check(texts.has("EPI_JONAH_ROSALIND") and not texts.has("EPI_JONAH"), "one card per person, the first that fits")
	check(texts.has("EPI_WREN_CUSTODIANS") and texts.has("EPI_HESTER_COUNTS"), "cards follow what happened")
	check(texts.has("EPI_WARD_DISTORTED"), "no true nights: a distorted record")
	GameState.reset_for_new_game()


func test_act_five_follows_act_four() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	for c in [&"case_door", &"case_two_maps", &"case_misplaced", &"case_kindness", &"case_index"]:
		Journal.start_case(c)
		Journal.complete_case(c, &"x")
	for i in 5:
		Campaign.check()
	check(Campaign.current_act() == &"act5" and Journal.case_status(&"case_anchor") == Journal.STATUS_ACTIVE, "act V begins")
	check(Journal.pinned == &"case_anchor", "and pins itself")
	GameState.is_playing = false
	GameState.reset_for_new_game()


# --- M7g: campaign pass ---------------------------------------------------------------

func test_boss_tuning_is_data() -> void:
	for id in ["census_taker", "conductor", "archivist", "matron", "lodger", "stationmaster", "director"]:
		check(int(DataFiles.boss_stat(id, "health", 0)) > 0, "%s health in bosses.json" % id)
	GameState.reset_for_new_game()
	var c := (load("res://scenes/combat/conductor.tscn") as PackedScene).instantiate() as Conductor
	add_child(c)
	check(c.health.max_health == int(DataFiles.boss_stat("conductor", "health", 0)), "bosses read their health from data")
	c.queue_free()


func test_final_fight_always_leaves_a_safe_place() -> void:
	GameState.reset_for_new_game()
	var d := (load("res://scenes/combat/director.tscn") as PackedScene).instantiate() as Director
	add_child(d)
	await get_tree().process_frame
	var dummy := Node2D.new()
	add_child(dummy)
	for hp in [d.health.max_health, 1]:
		d.health.health = hp
		d.mechanics = ["grid"]
		d.grid.clear_all()
		d._begin_cast(dummy)
		var marked := 0
		var free_rows := 0
		for y in d.grid.rows:
			var row_marked := 0
			for x in d.grid.cols:
				if d.grid._cells.has(Vector2i(x, y)):
					row_marked += 1
			marked += row_marked
			free_rows += int(row_marked == 0)
		check(marked > 0 and free_rows >= 1, "a rewrite always leaves a free row (phase %d)" % d.phase())
		var before := get_children().filter(func(n: Node) -> bool: return n is LaneSweep).size()
		d.mechanics = ["lanes"]
		d._begin_cast(dummy)
		var lanes := d.get_parent().get_children().filter(func(n: Node) -> bool: return n is LaneSweep).size() - before
		check(lanes >= 1 and lanes <= 2, "at most two of three lanes are called")
	for n in get_children():
		if n is LaneSweep:
			n.queue_free()
	d.grid.queue_free()
	d.queue_free()
	dummy.queue_free()
	var a := (load("res://scenes/combat/archivist.tscn") as PackedScene).instantiate() as Archivist
	check(not a.islands.is_empty(), "the flood has islands")
	for r: Rect2 in a.islands:
		check(Rect2(Vector2.ZERO, a.arena_size).encloses(r), "islands are inside the arena")
	a.free()


func test_companion_upgrades_from_personal_quests() -> void:
	GameState.reset_for_new_game()
	for id in [&"jonah_rook", &"mara_venn"]:
		var npc := (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate() as Npc
		npc.npc_id = id
		var f := Follower.new()
		f.setup(npc, Party.def_of(id))
		var before := f.power
		var quest := StringName(Party.def_of(id)["upgrade"]["if"]["quest_done"])
		Journal.start_case(quest)
		Journal.complete_case(quest, &"x")
		var g := Follower.new()
		g.setup(npc, Party.def_of(id))
		check(g.power > before and g.cooldown <= f.cooldown, "%s improves after their personal quest" % id)
		npc.free()
		Journal.reset()
	GameState.reset_for_new_game()


func test_agnes_and_rook_and_rook() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_agnes")
	Journal.add_evidence(&"e_agnes_card")
	check(Journal.case_stage(&"case_agnes") == &"tell", "the card moves it on")
	var tell: Array = DialogueService.dialogues[&"mara"]["nodes"]["agt"]["choices"]
	check(not StoryRules.evaluate(tell[0]["if"]), "the register answer needs Ivo")
	Journal.add_evidence(&"e_agnes_ivo")
	check(StoryRules.evaluate(tell[0]["if"]), "after Ivo it opens")
	for i in 3:
		WorldClock.sleep_until_hour(7)
	check(Journal.case_status(&"case_agnes") == Journal.STATUS_FAILED, "three days of silence fail it")
	GameState.reset_for_new_game()
	GameState.set_flag(&"storeroom.bricked")
	Journal.start_case(&"case_rook_and_rook")
	Inventory.money = 40
	var stamp: Dictionary = DialogueService.dialogues[&"pike"]["nodes"]["stamp1"]
	StoryRules.apply(stamp["choices"][1]["effects"])
	check(Inventory.money == 10 and Inventory.count(&"rook_stamp") == 1, "lost property, for a fee")
	check(Journal.case_stage(&"case_rook_and_rook") == &"evening", "the stamp moves it on")
	GameState.set_flag(&"rosalind.reunited")
	Journal.start_case(&"case_misplaced")
	Journal.complete_case(&"case_misplaced", &"reunited")
	var ros: Dictionary = DialogueService.dialogues[&"rosalind"]
	WorldClock.wait_until_hour(21)
	check(DialogueService.entry_node(ros) == "up_wait", "not without Jonah")
	Party.set_companion(&"jonah_rook")
	check(DialogueService.entry_node(ros) == "up1", "with Jonah and the stamp after dark she can cross")
	Party.set_companion(&"")
	for i in 6:
		WorldClock.sleep_until_hour(7)
	check(Journal.case_status(&"case_rook_and_rook") == Journal.STATUS_FAILED and NpcRegistry.resolve(&"rosalind_rook").is_empty(), "too late: she fades")
	GameState.reset_for_new_game()


# --- M8a: debug act starts, expeditions -----------------------------------------

func test_debug_act_starts_reach_every_act() -> void:
	for target: String in ["act1", "act2", "act3", "act4", "act5"]:
		GameState.reset_for_new_game()
		DebugStart.apply_history(target)
		Campaign.check()
		check(Campaign.current_act() == StringName(target), "debug start lands in %s (got %s)" % [target, Campaign.current_act()])
	GameState.reset_for_new_game()
	DebugStart.apply_history("endgame")
	Campaign.check()
	check(Expedition.unlocked() and Journal.case_status(&"case_anchor") == Journal.STATUS_DONE, "endgame start unlocks expeditions")
	GameState.reset_for_new_game()


func test_expedition_board_and_rewards() -> void:
	GameState.reset_for_new_game()
	check(not Expedition.unlocked() and not Expedition.start(Expedition.offers()[0]), "locked before the ending")
	var a := Expedition.offers(5)
	check(a == Expedition.offers(5), "same day, same board")
	check(a.size() == Expedition.OFFERS, "three offers")
	for i in a.size():
		check((a[i]["mods"] as Array).size() == i + 1, "tier %d has %d modifiers" % [i, i + 1])
		check(Expedition.sites().has(a[i]["site"]) and Expedition.rematches().has(a[i]["boss"]), "offer refers to real content")
	check(Expedition.reward_for(a[2]) > Expedition.reward_for(a[0]), "harder runs pay more")
	Expedition.runs_done = 1
	check(Expedition.offers(5) != a, "a finished run refreshes the board")
	# Pages: every page can be earned by some clear.
	Expedition.cleared = {}
	for site: String in Expedition.sites():
		Expedition.cleared["site:" + site] = true
	for m: String in Expedition.modifiers():
		Expedition.cleared["mod:" + m] = true
	check(Expedition._award_pages().size() == Expedition.page_defs().size(), "all pages are reachable")
	GameState.reset_for_new_game()


func test_expedition_modifiers_and_save() -> void:
	GameState.reset_for_new_game()
	check(GameState.incoming_damage(1) == 1, "normal damage")
	Expedition.run = {"site": "hospital", "mods": ["fragile"], "boss": "conductor", "room": 0, "rooms": 3, "seed": 1, "shards": 5}
	check(GameState.incoming_damage(1) == 2 and GameState.incoming_damage(0) == 0, "fragile: one more per hit")
	check(not Expedition.is_arena() and not Expedition.current_room().is_empty(), "first room")
	Expedition.run["room"] = 2
	check(Expedition.is_arena() and Expedition.current_room().has("boss"), "last room is the arena")
	Expedition.pages = ["p1_hospital"]
	var d := GameState.to_dict()
	GameState.reset_for_new_game()
	check(not Expedition.active(), "reset clears the run")
	GameState.from_dict(d)
	check(Expedition.active() and Expedition.run["room"] == 2 and Expedition.pages == ["p1_hospital"], "run and pages survive a save")
	check(Expedition.fail() and not Expedition.active() and Expedition.last_result["ok"] == false, "fainting ends the run")
	var env := {"schema_version": 7, "payload": {"flags": {}}}
	check(SaveService.migrate(env)["payload"].has("expedition"), "v7 save gains expedition state")
	GameState.reset_for_new_game()


func test_shard_trinkets_need_shards_and_the_index() -> void:
	GameState.reset_for_new_game()
	check(Economy.sell_price(&"veil_shard") == 0, "shards can't be sold")
	check(not Economy.can_craft(&"bound_index"), "bound index needs the full Index")
	Inventory.add(&"veil_shard", 20, false)
	check(not Economy.can_craft(&"bound_index"), "even with shards")
	GameState.set_flag(&"expedition.index_complete")
	check(Economy.craft(&"bound_index") and Inventory.has(&"bound_index"), "crafted once the Index is whole")
	GameState.reset_for_new_game()


# --- M8b: world incidents ---------------------------------------------------------

func _ending(outcome: String) -> void:
	GameState.reset_for_new_game()
	DebugStart.apply_history("act5")
	Journal.complete_case(&"case_anchor", StringName(outcome))
	GameState.set_flag(&"game.completed")


func test_incidents_depend_on_the_ending() -> void:
	GameState.reset_for_new_game()
	check(Incidents.eligible().is_empty() and Incidents.try_start() == &"", "nothing before the ending")
	for outcome: String in ["open_record", "custodians", "accord"]:
		_ending(outcome)
		var pool := Incidents.eligible()
		check(pool.has(&"names") == (outcome == "open_record"), "names only after the open record")
		check(pool.has(&"seal") == (outcome == "custodians"), "seal only under the custodians")
		check(pool.has(&"patrol") == (outcome == "accord"), "patrol only under the accord")
		check(pool.has(&"lanterns") and pool.has(&"storeroom"), "town incidents always possible")
	GameState.reset_for_new_game()


func test_incident_lifecycle_and_consequence() -> void:
	_ending("accord")
	var first := Incidents.try_start()
	check(first == &"lanterns" and Incidents.active() == &"lanterns", "first incident starts")
	check(Incidents.try_start() == &"", "one at a time")
	Incidents.mark_cleared(&"lanterns")
	check(Journal.case_stage(&"case_inc_lanterns") == &"report", "cleared: report")
	var mara: Dictionary = DialogueService.dialogues[&"mara"]
	check(DialogueService.entry_node(mara) == "inc_lanterns", "Mara wants to hear")
	var shards := Inventory.count(&"veil_shard")
	StoryRules.apply(mara["nodes"]["inc_lanterns"]["effects"])
	check(Journal.case_status(&"case_inc_lanterns") == Journal.STATUS_DONE and Inventory.count(&"veil_shard") == shards + 3, "reported and paid")
	check(Incidents.try_start() == &"", "cooldown after an incident")
	var rel := int(GameState.relationships.get(&"jonah_rook", 0))
	WorldClock.sleep_until_hour(8)
	WorldClock.sleep_until_hour(8)
	check(Incidents.active() == &"storeroom", "the next one starts after the cooldown")
	for i in 4:
		WorldClock.sleep_until_hour(8)
	check(Journal.case_status(&"case_inc_storeroom") == Journal.STATUS_FAILED, "ignored: it fails")
	check(GameState.has_flag(&"incident.storeroom.missed") and int(GameState.relationships.get(&"jonah_rook", 0)) < rel, "and it costs something")
	GameState.reset_for_new_game()


func test_incident_npcs_can_be_found_after_the_ending() -> void:
	_ending("custodians")
	WorldClock.wait_until_hour(12)
	for id: StringName in Incidents.defs():
		var npc := StringName(Incidents.def(id)["npc"])
		check(not NpcRegistry.resolve(npc).is_empty(), "%s is somewhere at noon after the ending" % npc)
	GameState.reset_for_new_game()


# --- Playtest fixes ----------------------------------------------------------------

## Every button of the full-screen menus must be on screen at 480x270 in every
## language (the character creator once pushed "Arrive" off the bottom).
func test_menus_fit_the_screen() -> void:
	var old := TranslationServer.get_locale()
	for locale: String in ["en", "ru"]:
		TranslationServer.set_locale(locale)
		for path: String in ["res://scripts/ui/character_creator.gd", "res://scripts/ui/main_menu.gd"]:
			var ui: Control = load(path).new()
			ui.size = Vector2(480, 270)
			add_child(ui)
			for i in 6:
				await get_tree().process_frame
			var screen := Rect2(Vector2.ZERO, Vector2(480, 270)).grow(0.5)
			var stack: Array[Node] = [ui]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				stack.append_array(n.get_children())
				if (n is Button or n is LineEdit) and (n as Control).is_visible_in_tree():
					var r := (n as Control).get_global_rect()
					check(screen.encloses(r), "%s [%s]: '%s' at %s is off screen" % [path.get_file(), locale, n.get("text"), r])
			ui.queue_free()
			await get_tree().process_frame
	TranslationServer.set_locale(old)


# --- R0: clarity (guidance, wait, settings) ----------------------------------------

func test_quest_guide_says_where_and_when() -> void:
	GameState.reset_for_new_game()
	Journal.start_case(&"case_storeroom")
	WorldClock.wait_until_hour(14)
	var g := QuestGuide.target(&"case_storeroom")
	check(g.get("scene", "") == "greyford_block" and not QuestGuide.when_ok(g), "storeroom: Greyford, not in daytime")
	var text := QuestGuide.describe(g)
	check(text.contains("T"), "daytime guide tells how to wait: " + text)
	WorldClock.wait_until_hour(22)
	check(QuestGuide.when_ok(g), "at night it's time")
	check(QuestGuide.next_door(&"rented_room", &"greyford_block") == "ExitDoor", "route out of the room")
	check(QuestGuide.next_door(&"greyford_block", &"rented_room") == "HomeDoor", "route home")
	check(QuestGuide.next_door(&"rented_room", &"the_anchor") == "", "no route through doors that aren't there yet")
	check(QuestGuide.next_door(&"greyford_block", &"greyford_block") == "", "no route when already there")
	Journal.start_case(&"case_radio")
	check(QuestGuide.target(&"case_radio").get("npc", "") == "edda_halloway", "radio: find Mrs Halloway")
	GameState.reset_for_new_game()


func test_every_open_step_has_a_guide() -> void:
	for id: StringName in Journal.case_defs:
		if String(id).begins_with("case_inc_"):
			continue
		for st: String in Journal.case_defs[id].get("stages", {}):
			check(QuestGuide.guides().get(String(id), {}).has(st), "%s/%s has a guide" % [id, st])


func test_settings_guidance_modes() -> void:
	var old := GameSettings.guidance
	GameSettings.set_guidance("minimal")
	check(not GameSettings.shows_objective() and not GameSettings.shows_guide(), "minimal hides everything")
	GameSettings.set_guidance("standard")
	check(GameSettings.shows_objective() and not GameSettings.shows_guide(), "standard: objective only")
	GameSettings.cycle_guidance()
	check(GameSettings.guidance == "minimal", "cycles")
	GameSettings.set_guidance("detailed")
	check(GameSettings.shows_guide(), "detailed shows the guide")
	GameSettings.set_guidance(old)
	check(InputMap.has_action(&"wait"), "a wait key exists")


func test_waiting_skips_to_the_hour() -> void:
	GameState.reset_for_new_game()
	WorldClock.wait_until_hour(10)
	var day := WorldClock.day
	WorldClock.wait_until_hour(18)
	check(WorldClock.get_hour() == 18 and WorldClock.day == day, "waited until evening")
	WorldClock.wait_until_hour(7)
	check(WorldClock.get_hour() == 7 and WorldClock.day == day + 1, "waited until next morning")
	GameState.reset_for_new_game()


# --- R10: music --------------------------------------------------------------------

func test_music_has_every_piece_and_picks_by_situation() -> void:
	for id: String in Music.TRACKS:
		var s := Music.stream_for(id)
		check(s != null and s.get_length() > 20.0, "music %s exists and is a real piece" % id)
	GameState.reset_for_new_game()
	GameState.is_playing = false
	check(Music.pick() == "title", "menu plays the title")
	Music.override = "epilogue"
	check(Music.pick() == "epilogue", "epilogue overrides")
	Music.override = ""
	check(AudioServer.get_bus_index(&"Music") >= 0, "music has its own bus")
	DialogueService.start(&"camp_hester", {"npc": &"hester_ashby"})
	check(DialogueService.current_music() == "hester", "Hester's talks play her theme")
	DialogueService.end()
	check(DialogueService.current_music() == "", "and stop when the talk ends")
	var mill: PackedScene = load("res://scenes/locations/mill_hill.tscn")
	var loc := mill.instantiate()
	check(String(loc.get("music")) == "village", "Mill Hill has its own piece")
	loc.free()


func test_rook_shop_opens_in_the_afternoon() -> void:
	GameState.reset_for_new_game()
	WorldClock.wait_until_hour(14)
	check(NpcRegistry.resolve(&"jonah_rook").get("scene", "") == "greyford_block", "before the note, Jonah is outside")
	Journal.add_evidence(&"e_rook_note")
	check(NpcRegistry.resolve(&"jonah_rook").get("scene", "") == "rook_shop", "afternoon: Jonah behind the counter")
	check(QuestGuide.next_door(&"greyford_block", &"rook_shop") == "ShopDoor", "the shop door is open")
	WorldClock.wait_until_hour(22)
	check(QuestGuide.next_door(&"greyford_block", &"rook_shop") == "", "closed at night")
	GameState.reset_for_new_game()


# --- R2: park sports -------------------------------------------------------------

func test_park_sports_score_and_pay_once_a_day() -> void:
	GameState.reset_for_new_game()
	var s := SportMinigame.new()
	add_child(s)
	s.start("basketball")
	for i in SportMinigame.ATTEMPTS:
		s._needle = s._band_c
		s._shoot()
		s.attempt += 1
	check(s.score == SportMinigame.ATTEMPTS, "every shot in the green scores")
	var money := Inventory.money
	s._finish()
	check(Inventory.money == money + SportMinigame.REWARD and int(GameState.get_flag(&"sport.basketball.best", 0)) == 5, "a good round pays and sets the best")
	s.start("basketball")
	s.score = 5
	s._finish()
	check(Inventory.money == money + SportMinigame.REWARD, "only once a day")
	s.start("football")
	s._aim_locked = 0
	s._needle = 1.0
	s._band_c = 0.5
	s._shoot()
	check(s.score == 0, "a blasted penalty goes over the bar")
	s._finish()
	check(not get_tree().paused, "the game unpauses after")
	s.queue_free()
	check(QuestGuide.next_door(&"greyford_block", &"greyford_park") == "ParkGate", "the park is reachable from the Old Quarter")
	GameState.reset_for_new_game()


func test_market_street_shops_and_people() -> void:
	GameState.reset_for_new_game()
	WorldClock.wait_until_hour(15)
	check(QuestGuide.next_door(&"greyford_block", &"bakery") == "MarketPath", "Market Street is east of the Old Quarter")
	check(QuestGuide.next_door(&"market_street", &"cafe") == "CafeDoor", "the café is open in the afternoon")
	check(NpcRegistry.resolve(&"martha_pell").get("scene", "") == "bakery", "Martha bakes")
	check(NpcRegistry.resolve(&"lou_ferrante").get("scene", "") == "cafe", "Lou minds the café")
	check(Economy.shops().has("bakery") and Economy.shops().has("cafe"), "both sell food")
	WorldClock.wait_until_hour(23)
	check(QuestGuide.next_door(&"market_street", &"cafe") == "", "closed at night")
	GameState.reset_for_new_game()


# --- R2d: city map and buses -------------------------------------------------------

func test_city_map_knows_where_you_have_been_and_buses_cost() -> void:
	GameState.reset_for_new_game()
	check(CityMap.district_of(&"bakery") == "market" and CityMap.district_of(&"rented_room") == "old_quarter", "interiors belong to their street")
	GameState.set_flag(&"visited.greyford_block")
	check(CityMap.known("old_quarter") and not CityMap.known("market"), "only places you've been are on the map")
	check(CityMap.destinations(&"greyford_block") == ["harbour", "airfield", "terraces"], "before you know anywhere, only the always-open stops (harbour, airfield, the terrace)")
	GameState.set_flag(&"visited.market_street")
	GameState.set_flag(&"visited.north_quay")
	check(CityMap.destinations(&"greyford_block") == ["market", "harbour", "airfield", "terraces"], "the bus goes to known stops; North Quay waits for Act III")
	for id: String in CityMap.districts():
		var stop: Variant = CityMap.districts()[id].get("stop")
		if stop != null:
			check(SceneFlow.has_location(StringName(stop[0])), "%s's stop is a real place" % id)
	check(InputMap.has_action(&"map"), "M opens the map")
	GameState.reset_for_new_game()


# --- R3a: progression -------------------------------------------------------------------

func test_progression_levels_points_and_stats() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	check(Progression.level == 1 and Progression.points == 0, "start at level 1")
	Progression.add_xp(Progression.xp_to_next(1) + Progression.xp_to_next(2))
	check(Progression.level == 3 and Progression.points == 2 and Progression.talent_points == 1, "two levels: two points, a talent point at 3")
	var hp := int(Inventory.stat("max_health"))
	check(Progression.raise("endurance") and Progression.raise("endurance"), "spend points")
	check(not Progression.raise("strength"), "no points left")
	check(int(Inventory.stat("max_health")) == hp + 1, "endurance 3: one more heart")
	Progression.stats["agility"] = 6
	check(Inventory.stat("dodge_cooldown_mult") < 0.85 and Inventory.stat("speed_mult") > 1.09, "agility feeds dodge and speed")
	Progression.stats["strength"] = 7
	check(int(Inventory.stat("damage_bonus")) == 2, "strength 7: +2 damage")
	check(StoryRules.evaluate({"stat_at_least": ["strength", 7]}) and not StoryRules.evaluate({"stat_at_least": ["perception", 2]}), "dialogue can check characteristics")
	var before := Progression.xp
	StoryRules.apply([{"give_xp": 5}])
	check(Progression.xp == before + 5, "story can give experience")
	var d := GameState.to_dict()
	GameState.reset_for_new_game()
	check(Progression.level == 1, "reset")
	GameState.from_dict(d)
	check(Progression.level == 3 and Progression.get_stat("strength") == 7, "progression survives a save")
	var env := {"schema_version": 8, "payload": {"journal": {"cases": {"a": {"status": "done"}, "b": {"status": "done"}}}}}
	check(int(SaveService.migrate(env)["payload"]["progression"]["level"]) == 3, "old saves get levels for their closed cases")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_talents_and_weapons() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	check(Progression.talent_paths().size() == 4, "four talent paths")
	check(not Progression.learn("tracker/keen_eye"), "no talent without a point")
	Progression.talent_points = 2
	check(not Progression.learn("tracker/finisher"), "steps go in order")
	var per := Progression.get_stat("perception")
	check(Progression.learn("tracker/keen_eye"), "learn the first step")
	check(Progression.get_stat("perception") == per + 2, "keen eye adds perception")
	var r := float(Inventory.stat("flash_radius_mult"))
	check(Progression.learn("lantern/bright_hands") and float(Inventory.stat("flash_radius_mult")) > r * 1.2, "talent mods feed the stat pipeline")
	check(Progression.talent_points == 0 and Progression.next_step("lantern") == "lantern/mending_light", "points spent, next step known")
	Progression.talents["veilwalker/veil_step"] = true
	check(Progression.has_special("veil_step"), "special talents are visible to the code")
	var d := GameState.to_dict()
	GameState.reset_for_new_game()
	GameState.from_dict(d)
	check(Progression.has_talent("tracker/keen_eye") and Progression.has_talent("lantern/bright_hands"), "talents survive a save")
	var styles := {}
	for id: String in ["rusted_sabre", "census_knife", "keeper_sword", "lantern_blade", "hatchet", "dockers_axe", "quay_trident", "coral_trident", "signal_wand", "tide_staff", "pocket_sling", "veil_sling"]:
		var def := Inventory.def(StringName(id))
		check(def.get("category", "") == "weapon" and String(def.get("icon", "")).begins_with("rpg_arsenal/"), "weapon %s is defined with an icon" % id)
		styles[String(def.get("weapon", {}).get("style", ""))] = true
	check(styles.size() == 5, "five fighting styles")
	Inventory.add(&"pocket_sling", 1, false)
	Inventory.equip(&"pocket_sling")
	check(Inventory.equipped["weapon"] == &"pocket_sling", "a sling can be equipped")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_farm_grows_and_pays() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	check(not CityMap.known("brookside"), "the farm is not on the map at first")
	GameState.set_flag(&"farm.route_known")
	check(CityMap.known("brookside") and CityMap.fare_to("brookside") > CityMap.fare(), "heard of: the bus goes there, for more")
	Inventory.add(&"seed_radish", 2, false)
	check(not Farm.plant(&"t1", &"seed_radish"), "not yours yet")
	GameState.set_flag(&"farm.owned")
	check(Farm.plant(&"t1", &"seed_radish") and Farm.state(&"t1") == "growing", "planted")
	check(not Farm.water(&"t1") or WorldClock.weather == "rain", "no can, no watering")
	Inventory.add(&"watering_can", 1, false)
	for i in 3:
		if not Farm.is_watered(&"t1"):
			check(Farm.water(&"t1"), "water day %d" % i)
		WorldClock.sleep_until_hour(8)
	check(Farm.state(&"t1") == "ready" and Farm.frame(&"t1", 7) == 6, "ripe after three watered days")
	check(Farm.harvest(&"t1") and Inventory.has(&"radish") and Farm.state(&"t1") == "empty", "harvest, the plant is gone")
	Farm.plant(&"t2", &"seed_radish")
	WorldClock.sleep_until_hour(8)
	var g := int(Farm.plots[&"t2"]["growth"])
	check(g == (1 if WorldClock.weather_for_day(WorldClock.day - 1) == "rain" else 0), "unwatered dry day: no growth, no withering")
	Farm.act("welcome")
	var worth := Farm.ship_all()
	check(worth > 0 and not Inventory.has(&"radish"), "the crate takes the harvest")
	var money := Inventory.money
	WorldClock.sleep_until_hour(8)
	check(Inventory.money == money + worth and Farm.eggs == 2, "paid next morning; two hens, two eggs")
	check(Farm.collect_eggs() == 2 and Inventory.has(&"egg", 2), "eggs")
	Livelihood.take(&"farm_pump")
	check(Livelihood.active.has(&"farm_pump") and not Livelihood.can_offer(&"farm_pump"), "Hugh's job is given in person, never on the board")
	var d := GameState.to_dict()
	GameState.reset_for_new_game()
	check(Farm.plots.is_empty() and Farm.hens == 0, "reset")
	GameState.from_dict(d)
	check(Farm.plots.has(&"t2") and Farm.hens == 2, "the farm survives a save")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_chronicle_follows_choices() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	var open := Chronicle.open_chapters()
	check(open.size() == 1 and String(open[0]["id"]) == "prologue", "a new game opens the prologue")
	check(Chronicle.pages(open[0]).size() == 1 and not Chronicle.finished(open[0]), "one page, still being written")
	check(Chronicle.check_new() and not Chronicle.check_new(), "a new page is noticed once")
	Journal.start_case(&"case_door")
	Journal.complete_case(&"case_door", &"opened")
	var pages := Chronicle.pages(Chronicle.open_chapters()[0])
	check(pages.size() == 2 and pages[1] == "CHRON_PROLOGUE_OPENED" and Chronicle.finished(Chronicle.open_chapters()[0]), "the prologue tells the choice that was made")
	check(not pages.has("CHRON_PROLOGUE_REPORTED"), "and not the other one")
	GameState.set_flag(&"act.act1")
	check(Chronicle.open_chapters().size() == 2, "a new act opens a chapter")
	for c: Dictionary in Chronicle.chapters():
		check(tr(String(c["title"])) != String(c["title"]), "chapter %s has a title" % c["id"])
		for p: Dictionary in c["pages"]:
			check(tr(String(p["text"])) != String(p["text"]), "page %s is written" % p["text"])
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_crowds_and_chatter() -> void:
	GameState.reset_for_new_game()
	check(Crowd.defs().has(&"market_street") and Crowd.defs().has(&"greyford_block"), "streets have people")
	var c := Crowd.new()
	c.location_id = &"market_street"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 40:
		var line := c.line_for(rng)
		check(tr(line) != line, "a line is written: %s" % line)
		seen[line] = true
	check(seen.size() > 5, "people say different things")
	check(not seen.has("CHATTER_AFTER_OPEN"), "nobody talks about an ending that has not happened")
	check(not seen.has("CHATTER_QUAY"), "quay talk stays on the quay")
	var a := Crowd.random_appearance(rng)
	check(a.premade == "" and a.layer_paths().size() >= 4 or not AssetLibrary.has_limezu(), "a random townsperson is put together from layers")
	c.free()


func test_npc_activities() -> void:
	var s := LayeredCharacterSprite.new()
	s.appearance = NpcRegistry.appearance_of(NpcRegistry.get_def(&"hugh_penny"))
	add_child(s)
	s.play(&"read", LayeredCharacterSprite.Dir.DOWN)
	check(s.animation == &"read", "a layered character can read")
	s.play(&"walk", LayeredCharacterSprite.Dir.LEFT)
	check(s.animation == &"walk", "and stop reading")
	s.queue_free()
	var acts := {}
	for id: StringName in NpcRegistry.defs():
		for e: Dictionary in NpcRegistry.get_def(id).get("schedule", []):
			acts[String(e.get("activity", ""))] = true
	check(acts.has("read") and acts.has("work") and acts.has("look") and acts.has("phone"), "people do different things through the day")


func test_world_map_routes() -> void:
	GameState.reset_for_new_game()
	check(WorldMap.city_of(&"market_street") == "greyford" and WorldMap.city_of(&"cavenmouth_inn") == "cavenmouth", "towns own their scenes")
	var r := WorldMap.routes_from("greyford")
	check(r.size() >= 1 and String(r[0]["dest"]) == "cavenmouth" and int(r[0]["fare"]) > CityMap.fare(), "a coach down the coast costs more than the bus")
	check(WorldMap.routes_from("cavenmouth").any(func(x: Dictionary) -> bool: return String(x["dest"]) == "greyford"), "and comes back")


func test_fishing() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	WorldClock.wait_until_hour(10)
	var sea := FishingMinigame.candidates("sea")
	check(sea.has("mackerel") and not sea.has("conger") and not sea.has("perch"), "the sea by day: mackerel, no eels, no lake fish")
	WorldClock.wait_until_hour(23)
	check(FishingMinigame.candidates("sea").has("conger"), "eels come out at night")
	check(not FishingMinigame.candidates("lake").has("bell_carp"), "the bell carp only after the bell is heard of")
	Journal.start_case(&"case_drowned_ford")
	check(FishingMinigame.candidates("lake").has("bell_carp"), "and then at night on the lake")
	for id: String in FishingMinigame.fish_defs():
		check(Inventory.def(StringName(id)).get("category", "") == "fish", "fish %s is an item" % id)
	var m := FishingMinigame.new()
	add_child(m)
	m.start("lake")
	check(not m.is_open(), "no rod, no fishing")
	Inventory.add(&"fishing_rod", 1, false)
	m.start("lake")
	check(m.is_open(), "with a rod, fishing")
	m._start_reel()
	var fid := m._fish_id
	m._land()
	check(Inventory.has(StringName(fid)) and FishingMinigame.caught_kinds() == 1, "a catch is landed and counted")
	m.close()
	m.queue_free()
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_own_car() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	GameState.current_scene_id = &"market_street"
	check(WorldMap.route_to("cavenmouth", "car").is_empty(), "no car, no car route")
	GameState.set_flag(&"car.owned")
	var car := WorldMap.route_to("cavenmouth", "car")
	var coach := WorldMap.route_to("cavenmouth", "coach")
	check(not car.is_empty() and int(car["minutes"]) < int(coach["minutes"]) and int(car["fare"]) < int(coach["fare"]), "the car is quicker and cheaper than the coach")
	CityMap.driving = true
	check(CityMap.fare_to("market") == 0, "driving round town is free")
	CityMap.driving = false
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_salt_tunnels() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	var base := Inventory.stat("dodge_cooldown_mult")
	Inventory.add(&"salt_charm", 1, false)
	Inventory.equip(&"salt_charm")
	check(is_equal_approx(Inventory.stat("dodge_cooldown_mult"), base * 0.8), "the salt-knot: a quicker dodge")
	Journal.start_case(&"case_salt_tunnels")
	check(Journal.case_stage(&"case_salt_tunnels") == &"seals", "two locks to find")
	var both := {"all": [{"flag": "salt.sluice"}, {"has_item": "tally_key"}]}
	check(not StoryRules.evaluate(both), "the gate holds")
	GameState.set_flag(&"salt.sluice", true)
	Inventory.add(&"tally_key", 1, false)
	check(StoryRules.evaluate(both), "sluice and key: the gate can open")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_companion_bond() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	check(Party.defs.has("hester_ashby") and Party.def_of(&"hester_ashby").get("ability") == "beam", "Hester is a companion with a lamp")
	check(not Party.can_join(&"hester_ashby"), "not before her case is solved")
	check(Party.bond_tier(&"jonah_rook") == 0, "no bond at the start")
	Party.set_companion(&"jonah_rook")
	Party.note_kill()
	check(Party.bond_points(&"jonah_rook") == 1, "an echo beaten together: a bond point")
	Party.add_bond(&"jonah_rook", Party.TIERS[0] - 1)
	check(Party.bond_tier(&"jonah_rook") == 1 and StoryRules.evaluate({"bond_at_least": ["jonah_rook", 1]}), "tier one")
	check(not StoryRules.evaluate({"bond_at_least": ["jonah_rook", 2]}), "not yet tier two")
	StoryRules.apply([{"bond": ["jonah_rook", 100]}])
	check(Party.bond_tier(&"jonah_rook") == 3, "the bond effect")
	var saved := Party.to_dict()
	Party.reset()
	check(Party.bond_tier(&"jonah_rook") == 0, "reset clears the bond")
	Party.from_dict(saved)
	check(Party.bond_tier(&"jonah_rook") == 3 and Party.companion == &"jonah_rook", "the bond survives a save")
	Party.set_companion(&"")
	Party.note_kill()
	check(Party.bond_points(&"mara_venn") == 0, "no companion, no bond")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_mill_hill_rosary() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	var base := Inventory.stat("max_health")
	Inventory.add(&"brigid_rosary", 1, false)
	Inventory.equip(&"brigid_rosary")
	check(is_equal_approx(Inventory.stat("max_health"), base + 1.0), "St Brigid's rosary: one more heart")
	check(Inventory.def(&"abbess_rosary").get("category", "") == "key", "the abbess's rosary is a key item until decided")
	check(Journal.case_stage(&"case_abbey_lights") == &"", "the abbey case is not started")
	Journal.start_case(&"case_abbey_lights")
	check(Journal.case_stage(&"case_abbey_lights") == &"ask", "the vicar's request starts at the ruins")
	GameState.reset_for_new_game()
	GameState.is_playing = false


func test_xp_comes_from_play() -> void:
	GameState.reset_for_new_game()
	GameState.is_playing = true
	var x := Progression.xp
	Journal.add_evidence(&"e_rook_note")
	check(Progression.xp == x + Progression.XP_EVIDENCE, "evidence gives a little")
	x = Progression.xp
	var lvl := Progression.level
	GameState.set_flag(&"boss.conductor.defeated")
	check(Progression.level > lvl or Progression.xp >= x + Progression.XP_BOSS, "a boss gives a lot")
	GameState.reset_for_new_game()
	GameState.is_playing = false
