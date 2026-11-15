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


func test_fail_forward_moves_stalled_case() -> void:
	GameState.reset_for_new_game()
	WorldClock.reset()
	Journal.start_case(&"case_radio")
	GameState.set_flag(&"has_radio")
	WorldClock.sleep_until_hour(7)
	check(Journal.case_stage(&"case_radio") == &"deliver", "one day is not enough")
	WorldClock.sleep_until_hour(7)
	check(Journal.case_stage(&"case_radio") == &"return", "fail-forward after two days")
	check(not GameState.has_flag(&"has_radio"), "fail-forward effects applied")
	GameState.reset_for_new_game()


func test_lantern_row_clues_not_missable_after_fail_forward() -> void:
	# Even if the radio delivery is missed, Mrs Halloway and the map still supply clues.
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
			elif n is EchoEnemy or n is CensusTaker:
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
