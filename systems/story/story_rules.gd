class_name StoryRules
extends RefCounted
## Data-driven conditions and effects shared by dialogue, schedules, journal
## and conditional world objects. Authored in JSON (or as Dictionaries in scenes).
##
## Conditions (all keys in one dictionary must hold; empty/null = true):
##   {"flag": "id"}  {"not_flag": "id"}  {"flag_equals": ["id", value]}
##   {"background": "courier"}  {"evidence": "id"}  {"not_evidence": "id"}
##   {"hypothesis": "id"}  {"not_hypothesis": "id"}
##   {"companion": "id" | ""}  {"can_join": "id"}
##   {"quest_outcome": ["id", "outcome"]}  {"verdict": ["e", "edited"]}  {"judged": ["e1", ...]}
##   {"verdicts_correct_at_least": [["e1", "e2", "e3"], 2]}  {"count_at_least": [[c1, c2, ...], n]}
##   {"quest_active": "id"}  {"quest_done": "id"}  {"quest_failed": "id"}  {"quest_stage": ["id", "stage"]} (open cases only)
##   {"not_quest_started": "id"}
##   {"period": "night" | ["morning", "afternoon"]}  {"weather": "rain"}
##   {"relationship_at_least": ["npc", 2]}  {"remembers": ["npc", "event"]}
##   {"has_item": "id" | ["id", n]}  {"money_at_least": n}
##   {"stat_at_least": ["perception", 3]}  {"level_at_least": 5}
##   {"faction_at_least": ["civic", 2]}  {"faction_below": ["civic", 0]}  {"knows": ["npc", "fact"]}
##   {"not_knows": ["npc", "fact"]}
##   {"all": [c, ...]}  {"any": [c, ...]}  {"not": c}
##
## Effects (applied in order):
##   {"set_flag": "id", "value": v}  {"clear_flag": "id"}  {"add_evidence": "id"}
##   {"quest_start": "id"}  {"quest_stage": ["id", "stage"]}  {"quest_complete": ["id", "outcome"]}
##   {"relationship": ["npc", delta]}  {"remember": ["npc", "event"]}
##   {"toast": "KEY"}  {"advance_minutes": n}  {"sleep_until_hour": h}  {"wait_until_hour": h}
##   {"save_game": true}  {"travel": ["scene_id", "spawn_id"]}  {"heal_player": true}
##   {"give_item": "id" | ["id", n]}  {"take_item": "id" | ["id", n]}  {"give_money": n}  {"spend_money": n}
##   {"open_screen": "shop:jonah" | "jobs" | "workbench" | "business"}
##   {"verdict": ["e", "authentic" | "edited" | "unreliable"]}  (judge a testimony)
##   {"first_match": [{"if": cond, "do": [effects]}, ...]}  (first branch that holds)
##   {"companion": "id" | ""}  (recruit a companion / send them home)
##   {"give_xp": n}  {"give_resonance": n}  {"faction": ["keepers", delta]}  {"tell": ["npc", "fact"]}  {"publish": "fact"}


static func evaluate(cond: Variant) -> bool:
	if cond == null:
		return true
	if cond is Array:
		for c: Variant in cond:
			if not evaluate(c):
				return false
		return true
	if not cond is Dictionary:
		push_warning("StoryRules: condition must be a Dictionary, got %s" % cond)
		return false
	for key: String in cond:
		if not _check(key, cond[key]):
			return false
	return true


static func _check(key: String, arg: Variant) -> bool:
	match key:
		"flag":
			return GameState.has_flag(StringName(arg))
		"not_flag":
			return not GameState.has_flag(StringName(arg))
		"flag_equals":
			return GameState.get_flag(StringName(arg[0])) == arg[1]
		"background":
			return String(GameState.background) == String(arg)
		"evidence":
			return Journal.has_evidence(StringName(arg))
		"not_evidence":
			return not Journal.has_evidence(StringName(arg))
		"hypothesis":
			return Journal.is_hypothesis_formed(StringName(arg))
		"not_hypothesis":
			return not Journal.is_hypothesis_formed(StringName(arg))
		"quest_active":
			return Journal.case_status(StringName(arg)) == Journal.STATUS_ACTIVE
		"quest_done":
			return Journal.case_status(StringName(arg)) == Journal.STATUS_DONE
		"not_quest_started":
			return Journal.case_status(StringName(arg)) == Journal.STATUS_NONE
		"companion":  # "" means nobody
			return Party.companion == StringName(arg)
		"can_join":
			return Party.can_join(StringName(arg))
		"count_at_least":  # [[cond, cond, ...], n]: at least n of the conditions hold
			var n := 0
			for c: Variant in arg[0]:
				if evaluate(c):
					n += 1
			return n >= int(arg[1])
		"quest_failed":
			return Journal.case_status(StringName(arg)) == Journal.STATUS_FAILED
		"verdict":  # ["evidence", "authentic" | "edited" | "unreliable"]
			return Journal.verdict_of(StringName(arg[0])) == String(arg[1])
		"judged":  # every listed testimony has a verdict
			for id: Variant in arg:
				if Journal.verdict_of(StringName(id)) == "":
					return false
			return true
		"verdicts_correct_at_least":  # [["e1", "e2", ...], n]
			return Journal.correct_verdicts(arg[0]) >= int(arg[1])
		"quest_outcome":  # ["case", "outcome"]: closed with that outcome
			return Journal.case_status(StringName(arg[0])) == Journal.STATUS_DONE \
				and StringName(Journal.cases.get(StringName(arg[0]), {}).get("outcome", &"")) == StringName(arg[1])
		"quest_stage":  # only while the case is open: a closed case keeps its last stage
			return Journal.case_status(StringName(arg[0])) == Journal.STATUS_ACTIVE \
				and Journal.case_stage(StringName(arg[0])) == StringName(arg[1])
		"period":
			if arg is Array:
				return WorldClock.get_period() in arg
			return WorldClock.get_period() == String(arg)
		"weather":
			return WorldClock.weather == String(arg)
		"relationship_at_least":
			return GameState.get_relationship(StringName(arg[0])) >= int(arg[1])
		"remembers":
			return GameState.npc_remembers(StringName(arg[0]), String(arg[1]))
		"has_item":
			if arg is Array:
				return Inventory.has(StringName(arg[0]), int(arg[1]))
			return Inventory.has(StringName(arg))
		"repair_level_at_least":
			return Livelihood.repair_level() >= int(arg)
		"money_at_least":
			return Inventory.money >= int(arg)
		"faction_at_least":
			return Society.get_standing(StringName(arg[0])) >= int(arg[1])
		"stat_at_least":  # ["perception", 3]
			return Progression.get_stat(String(arg[0])) >= int(arg[1])
		"level_at_least":
			return Progression.level >= int(arg)
		"faction_below":
			return Society.get_standing(StringName(arg[0])) < int(arg[1])
		"knows":
			return Society.knows(StringName(arg[0]), StringName(arg[1]))
		"not_knows":
			return not Society.knows(StringName(arg[0]), StringName(arg[1]))
		"all":
			for c: Variant in arg:
				if not evaluate(c):
					return false
			return true
		"any":
			for c: Variant in arg:
				if evaluate(c):
					return true
			return false
		"not":
			return not evaluate(arg)
		_:
			push_warning("StoryRules: unknown condition '%s'" % key)
			return false


static func apply(effects: Variant) -> void:
	if effects == null:
		return
	if effects is Dictionary:
		effects = [effects]
	for e: Variant in effects:
		if not e is Dictionary:
			push_warning("StoryRules: effect must be a Dictionary, got %s" % e)
			continue
		for key: String in e:
			if key == "value":
				continue
			_apply_one(key, e[key], e)


static func _apply_one(key: String, arg: Variant, whole: Dictionary) -> void:
	match key:
		"verdict":  # ["evidence", verdict]: the player's judgement of a testimony
			Journal.set_verdict(StringName(arg[0]), String(arg[1]))
		"first_match":  # [{"if": cond, "do": [effects]}, ...]: runs the first branch whose if holds
			for branch: Dictionary in arg:
				if evaluate(branch.get("if")):
					apply(branch.get("do", []))
					break
		"set_flag":
			GameState.set_flag(StringName(arg), whole.get("value", true))
		"clear_flag":
			GameState.clear_flag(StringName(arg))
		"add_evidence":
			Journal.add_evidence(StringName(arg))
		"quest_start":
			Journal.start_case(StringName(arg))
		"quest_stage":
			Journal.set_case_stage(StringName(arg[0]), StringName(arg[1]))
		"quest_complete":
			Journal.complete_case(StringName(arg[0]), StringName(arg[1]) if arg.size() > 1 else &"")
		"relationship":
			GameState.change_relationship(StringName(arg[0]), int(arg[1]))
		"remember":
			GameState.remember(StringName(arg[0]), String(arg[1]))
		"toast":
			EventHub.toast_requested.emit(TranslationServer.translate(String(arg)))
		"advance_minutes":
			WorldClock.advance_minutes(int(arg))
		"sleep_until_hour":
			WorldClock.sleep_until_hour(int(arg))
		"wait_until_hour":
			WorldClock.wait_until_hour(int(arg))
		"save_game":
			if SaveService.save_game() != OK:
				EventHub.toast_requested.emit(TranslationServer.translate("REST_SAVE_FAILED"))
		"travel":
			SceneFlow.travel(StringName(arg[0]), StringName(arg[1]))
		"heal_player":
			EventHub.player_heal_requested.emit()
		"give_item":  # "id" or ["id", n]
			var g: Array = arg if arg is Array else [arg]
			Inventory.add(StringName(g[0]), int(g[1]) if g.size() > 1 else 1)
		"take_item":
			var t: Array = arg if arg is Array else [arg]
			Inventory.remove(StringName(t[0]), int(t[1]) if t.size() > 1 else 1)
		"give_money":
			Inventory.add_money(int(arg))
		"spend_money":
			Inventory.spend_money(int(arg))
		"give_xp":
			Progression.add_xp(int(arg))
		"give_resonance":
			Inventory.add_resonance(int(arg))
		"faction":
			Society.change_standing(StringName(arg[0]), int(arg[1]))
		"tell":
			Society.tell(StringName(arg[0]), StringName(arg[1]))
		"publish":
			Society.publish(StringName(arg))
		"open_screen":
			EventHub.screen_requested.emit(String(arg))
		"companion":
			Party.set_companion(StringName(arg))
		_:
			push_warning("StoryRules: unknown effect '%s'" % key)
