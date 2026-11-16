extends Node
## Endgame (M8a): expeditions into the Veil, unlocked once the story is over.
## The board at the Echo Ward rift offers three runs a day (more mods = more
## shards). A run is a few rooms of a memory site and a rematch boss in the
## last one; every modifier changes how rooms play (water, rewritten floors,
## darkness...). Fainting ends the run: the shards of that run are lost and
## the satchel lies at the rift. Clears fill the Index (8 pages).

signal changed

const SITES_PATH := "res://data/expeditions/sites.json"
const MODS_PATH := "res://data/expeditions/modifiers.json"
const REMATCH_PATH := "res://data/expeditions/rematches.json"
const PAGES_PATH := "res://data/expeditions/pages.json"
const ROOM_SCENE := &"expedition_room"
const RETURN_SCENE := &"echo_ward"
const RETURN_SPAWN := &"rift_return"
const SATCHEL_AT := Vector2(236, 344)
const REMATCH_ID := &"exp_rematch"
const OFFERS := 3
const SHARD := &"veil_shard"
const UNLOCK_FLAG := &"game.completed"

## Current run: {site, mods, boss, room, rooms, seed}. Empty when not in one.
var run: Dictionary = {}
## Things cleared at least once: "site:hospital", "mod:flooded", "boss:matron".
var cleared: Dictionary = {}
var pages: Array[String] = []
var runs_done := 0
## Result of the last finished run, for the board ({} if none yet).
var last_result: Dictionary = {}

var _cache: Dictionary = {}


func reset() -> void:
	run = {}
	cleared = {}
	pages = []
	runs_done = 0
	last_result = {}
	changed.emit()


func _defs(path: String) -> Dictionary:
	if not _cache.has(path):
		var d: Variant = DataFiles.read_json(path)
		var out := {}
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_"):
					out[k] = d[k]
		_cache[path] = out
	return _cache[path]


func sites() -> Dictionary:
	return _defs(SITES_PATH)


func modifiers() -> Dictionary:
	return _defs(MODS_PATH)


func rematches() -> Dictionary:
	return _defs(REMATCH_PATH)


func page_defs() -> Dictionary:
	return _defs(PAGES_PATH)


func unlocked() -> bool:
	return GameState.has_flag(UNLOCK_FLAG)


func active() -> bool:
	return not run.is_empty()


func has_mod(id: StringName) -> bool:
	return active() and (run.get("mods", []) as Array).has(String(id))


## Today's board: deterministic for a day and the number of runs done, so it
## changes after every run but can't be rerolled by reloading.
func offers(day: int = -1) -> Array[Dictionary]:
	if day < 0:
		day = WorldClock.day
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, runs_done, "expeditions"])
	var site_ids: Array = sites().keys()
	site_ids.sort()
	var mod_ids: Array = modifiers().keys()
	mod_ids.sort()
	var boss_ids: Array = rematches().keys()
	boss_ids.sort()
	var out: Array[Dictionary] = []
	var used_sites: Array = []
	for tier in OFFERS:
		var site: String = site_ids[rng.randi() % site_ids.size()]
		var guard := 0
		while used_sites.has(site) and used_sites.size() < site_ids.size() and guard < 20:
			site = site_ids[rng.randi() % site_ids.size()]
			guard += 1
		used_sites.append(site)
		var pool := mod_ids.duplicate()
		var mods: Array[String] = []
		for i in tier + 1:
			var m: String = pool[rng.randi() % pool.size()]
			pool.erase(m)
			mods.append(m)
		mods.sort()
		out.append({"site": site, "mods": mods, "boss": boss_ids[rng.randi() % boss_ids.size()], "tier": tier})
	return out


## Shards a run pays if finished: base + per room + modifier bonuses.
func reward_for(offer: Dictionary) -> int:
	var site: Dictionary = sites().get(offer.get("site", ""), {})
	var n := 2 + (site.get("rooms", []) as Array).size()
	for m: String in offer.get("mods", []):
		n += int(modifiers().get(m, {}).get("shards", 1))
	return n


func start(offer: Dictionary) -> bool:
	if not unlocked() or active() or not sites().has(offer.get("site", "")):
		return false
	var site: Dictionary = sites()[offer["site"]]
	run = {
		"site": String(offer["site"]),
		"mods": (offer.get("mods", []) as Array).duplicate(),
		"boss": String(offer.get("boss", rematches().keys()[0])),
		"room": 0,
		"rooms": (site.get("rooms", []) as Array).size() + 1,
		"seed": hash([WorldClock.day, runs_done, offer["site"]]),
		"shards": reward_for(offer),
	}
	GameState.clear_flag(StringName("boss.%s.defeated" % REMATCH_ID))
	GameState.clear_flag(StringName("boss.%s.engaged" % REMATCH_ID))
	changed.emit()
	SceneFlow.travel(ROOM_SCENE, &"start")
	return true


func site_def() -> Dictionary:
	return sites().get(run.get("site", ""), {})


func is_arena() -> bool:
	return active() and int(run["room"]) >= int(run["rooms"]) - 1


func current_room() -> Dictionary:
	if not active():
		return {}
	var site := site_def()
	if is_arena():
		return site.get("arena", {})
	return (site.get("rooms", []) as Array)[int(run["room"])]


func boss_def() -> Dictionary:
	return rematches().get(run.get("boss", ""), {})


## Leaving a cleared room: on to the next, or home with the rewards.
func advance() -> void:
	if not active():
		return
	if is_arena():
		_complete()
		return
	run["room"] = int(run["room"]) + 1
	changed.emit()
	SceneFlow.travel(ROOM_SCENE, &"start")


func _complete() -> void:
	var shards := int(run.get("shards", 1))
	var resonance := 4 * int(run["rooms"])
	Inventory.add(SHARD, shards, false)
	Inventory.resonance += resonance
	cleared["site:" + String(run["site"])] = true
	cleared["boss:" + String(run["boss"])] = true
	for m: String in run["mods"]:
		cleared["mod:" + m] = true
	var new_pages := _award_pages()
	var weapon := _award_weapon()
	last_result = {"ok": true, "site": run["site"], "shards": shards, "resonance": resonance, "pages": new_pages, "weapon": String(weapon)}
	runs_done += 1
	run = {}
	GameState.set_flag(&"expedition.cleared_once", true)
	if pages.size() >= page_defs().size() and not page_defs().is_empty():
		GameState.set_flag(&"expedition.index_complete", true)
	changed.emit()
	EventHub.toast_requested.emit(tr("EXP_TOAST_DONE") % shards)
	for p in new_pages:
		EventHub.toast_requested.emit(tr("EXP_TOAST_PAGE") % tr(String(page_defs()[p].get("title", ""))))
	SceneFlow.travel(RETURN_SCENE, RETURN_SPAWN)


## Each finished run brings back a relic weapon you don't have yet.
const RELIC_WEAPONS: Array[StringName] = [&"rusted_sabre", &"quay_trident", &"census_knife", &"dockers_axe", &"tide_staff", &"keeper_sword", &"veil_sling"]


func _award_weapon() -> StringName:
	for id in RELIC_WEAPONS:
		if not Inventory.has(id):
			Inventory.add(id, 1, false)
			EventHub.toast_requested.emit(tr("EXP_TOAST_WEAPON") % tr(String(Inventory.def(id).get("name", ""))))
			return id
	return &""


func _award_pages() -> Array[String]:
	var out: Array[String] = []
	var ids: Array = page_defs().keys()
	ids.sort()
	for id: String in ids:
		if pages.has(id):
			continue
		var need: String = page_defs()[id].get("needs", "")
		if need == "" or cleared.has(need):
			pages.append(id)
			out.append(id)
	return out


## The player fainted inside a run: it ends, nothing is paid, the satchel
## waits at the rift. Returns false if not in a run.
func fail() -> bool:
	if not active():
		return false
	last_result = {"ok": false, "site": run["site"]}
	runs_done += 1
	run = {}
	changed.emit()
	return true


## Walks away from a run between rooms (the exit of room one leads home too).
func abandon() -> void:
	if fail():
		SceneFlow.travel(RETURN_SCENE, RETURN_SPAWN)


# --- Save ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"run": run.duplicate(true), "cleared": cleared.keys(), "pages": pages.duplicate(), "runs_done": runs_done}


func from_dict(d: Dictionary) -> void:
	run = (d.get("run", {}) as Dictionary).duplicate(true)
	cleared = {}
	for k: String in d.get("cleared", []):
		cleared[k] = true
	pages = []
	for p: String in d.get("pages", []):
		pages.append(p)
	runs_done = int(d.get("runs_done", 0))
	last_result = {}
	if active() and not sites().has(run.get("site", "")):
		run = {}
	changed.emit()
