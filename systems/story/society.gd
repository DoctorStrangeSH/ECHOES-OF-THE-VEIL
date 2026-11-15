extends Node
## Social state of Greyford beyond single relationships:
##  * faction standing (Civic Renewal, Keepers, Open Hand, Unwritten), -10..10;
##  * NPC knowledge: which NPC knows which fact, and gossip that spreads a
##    published fact to its audience one time-of-day period later;
##  * relationship milestones (friend / confidant / distrust) as flags.
## Definitions: res://data/world/factions.json, res://data/world/facts.json,
## milestones in res://data/characters/npcs.json. Owner: story.
## Tests: tests/test_runner.gd (gossip timing, milestones, factions, save).

signal faction_changed(faction_id: StringName, value: int)
signal milestone_reached(npc_id: StringName, milestone: StringName)
signal fact_learned(npc_id: StringName, fact_id: StringName)

const FACTIONS_PATH := "res://data/world/factions.json"
const FACTS_PATH := "res://data/world/facts.json"
const DEFAULT_MILESTONES := [
	{"at": 3, "id": "friend"}, {"at": 6, "id": "confidant"}, {"at": -3, "id": "distrust"},
]
const FACTION_TIERS := [[-6, "HOSTILE"], [-2, "WARY"], [2, "NEUTRAL"], [6, "TRUSTED"], [99, "ALLY"]]

var faction_defs: Dictionary = {}
var fact_defs: Dictionary = {}

var standing: Dictionary = {}  # faction_id -> int
var knowledge: Dictionary = {}  # npc_id -> Array[String] of fact ids
var gossip: Array = []  # [{"fact": String, "due": int}]


func _enter_tree() -> void:
	faction_defs = _load(FACTIONS_PATH)
	fact_defs = _load(FACTS_PATH)


func _ready() -> void:
	WorldClock.period_changed.connect(_on_period_changed)


func _load(path: String) -> Dictionary:
	var out := {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		for id: String in data:
			if not id.begins_with("_"):
				out[StringName(id)] = data[id]
	else:
		push_error("Society: %s is not a JSON object" % path)
	return out


func reset() -> void:
	standing.clear()
	knowledge.clear()
	gossip.clear()


# --- Factions --------------------------------------------------------------------

func get_standing(faction: StringName) -> int:
	return int(standing.get(faction, 0))


func change_standing(faction: StringName, delta: int) -> void:
	if not faction_defs.has(faction):
		push_error("Society: unknown faction '%s'" % faction)
		return
	var v := clampi(get_standing(faction) + delta, -10, 10)
	standing[faction] = v
	faction_changed.emit(faction, v)
	var key := "TOAST_FACTION_UP" if delta > 0 else "TOAST_FACTION_DOWN"
	EventHub.toast_requested.emit(tr(key) % tr(faction_defs[faction].get("name", "")))


static func tier_of(value: int) -> String:
	for t: Array in FACTION_TIERS:
		if value <= int(t[0]):
			return t[1]
	return "ALLY"


# --- Knowledge & gossip -------------------------------------------------------------

func knows(npc: StringName, fact: StringName) -> bool:
	return (knowledge.get(npc, []) as Array).has(String(fact))


func tell(npc: StringName, fact: StringName) -> void:
	var list: Array = knowledge.get(npc, [])
	if not list.has(String(fact)):
		list.append(String(fact))
		knowledge[npc] = list
		fact_learned.emit(npc, fact)


## Spreads a fact to its audience after its delay (in time-of-day periods).
func publish(fact: StringName) -> void:
	if not fact_defs.has(fact):
		push_error("Society: unknown fact '%s'" % fact)
		return
	var delay := int(fact_defs[fact].get("delay_periods", 1))
	if delay <= 0:
		_spread(fact)
	else:
		gossip.append({"fact": String(fact), "due": period_index() + delay})


func audience_of(fact: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: String in fact_defs.get(fact, {}).get("audience", []):
		for npc_id: StringName in NpcRegistry.defs():
			var def := NpcRegistry.get_def(npc_id)
			var match_all := a == "all"
			var match_faction := a.begins_with("faction:") and (def.get("factions", []) as Array).has(a.trim_prefix("faction:"))
			if (match_all or match_faction or a == String(npc_id)) and not out.has(npc_id):
				out.append(npc_id)
	return out


func period_index() -> int:
	return WorldClock.day * 4 + WorldClock.PERIODS.find(WorldClock.get_period())


func _spread(fact: StringName) -> void:
	for npc in audience_of(fact):
		tell(npc, fact)


func _on_period_changed(_p: String) -> void:
	process_gossip()


func process_gossip() -> void:
	var now := period_index()
	var remaining: Array = []
	for g: Dictionary in gossip:
		if int(g["due"]) <= now:
			_spread(StringName(g["fact"]))
		else:
			remaining.append(g)
	gossip = remaining


# --- Relationship milestones --------------------------------------------------------

## Called by GameState after a relationship changes.
func check_milestones(npc: StringName, old_value: int, new_value: int) -> void:
	var list: Array = NpcRegistry.get_def(npc).get("milestones", DEFAULT_MILESTONES)
	for m: Dictionary in list:
		var at := int(m["at"])
		var crossed := (at > 0 and old_value < at and new_value >= at) or (at < 0 and old_value > at and new_value <= at)
		if not crossed:
			continue
		var flag := StringName("rel.%s.%s" % [npc, m["id"]])
		if GameState.has_flag(flag):
			continue
		GameState.set_flag(flag, true)
		milestone_reached.emit(npc, StringName(m["id"]))
		var npc_name := tr(NpcRegistry.get_def(npc).get("name", ""))
		EventHub.toast_requested.emit(tr("TOAST_MILESTONE_" + String(m["id"]).to_upper()) % npc_name)


# --- Save ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var s := {}
	for k: StringName in standing:
		s[String(k)] = standing[k]
	var kn := {}
	for k: StringName in knowledge:
		kn[String(k)] = knowledge[k]
	return {"standing": s, "knowledge": kn, "gossip": gossip.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	var s: Dictionary = data.get("standing", {})
	for k: String in s:
		if faction_defs.has(StringName(k)):
			standing[StringName(k)] = int(s[k])
	var kn: Dictionary = data.get("knowledge", {})
	for k: String in kn:
		knowledge[StringName(k)] = Array(kn[k])
	for g: Variant in data.get("gossip", []):
		if g is Dictionary and fact_defs.has(StringName(g.get("fact", ""))):
			gossip.append({"fact": String(g["fact"]), "due": int(g.get("due", 0))})
