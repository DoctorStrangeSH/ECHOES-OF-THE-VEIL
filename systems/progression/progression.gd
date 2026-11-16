extends Node
## Character progression (R3a): experience, levels and six characteristics.
##
## XP comes from what you do: echoes and bosses, closed cases and finished
## objectives, evidence, sport and training. Each level gives one point to
## spend on a characteristic (C opens the character sheet); every third level
## also gives a talent point (talents: R3b).
##
## Characteristics feed the same stat pipeline as trinkets (Inventory.stat),
## so every system that already reads a stat gets them for free:
##   strength   +1 damage per 3 points over 1
##   agility    dodges recharge 4% faster per point, run 2% faster
##   endurance  +1 heart per 2 points over 1
##   will       Flash recharges 5% faster and stuns 0.08 s longer per point
##   intellect  repairs get a wider window, jobs pay 5% more per point
##   perception notices more: dialogue and hidden things check it
## Autoload "Progression" (after Inventory and Journal).

signal changed
signal leveled_up(level: int)

const MAX_LEVEL := 50
const MAX_STAT := 10
const STATS: Array[String] = ["strength", "agility", "endurance", "will", "intellect", "perception"]
const XP_ENEMY := 4
const XP_BOSS := 60
const XP_CASE_MAIN := 50
const XP_CASE_SIDE := 25
const XP_OBJECTIVE := 8
const XP_EVIDENCE := 3

var level := 1
var xp := 0
var points := 0
var talent_points := 0
var stats: Dictionary = {}
## Unlocked talents: "path/step_id" -> true.
var talents: Dictionary = {}
static var _talent_defs: Dictionary = {}


func _ready() -> void:
	reset()
	EventHub.flag_changed.connect(_on_flag)
	Journal.case_changed.connect(_on_case)
	Journal.evidence_added.connect(func(_id: StringName) -> void: add_xp(XP_EVIDENCE))


func reset() -> void:
	level = 1
	xp = 0
	points = 0
	talent_points = 0
	stats = {}
	talents = {}
	for s in STATS:
		stats[s] = 1
	changed.emit()


static func xp_to_next(lvl: int) -> int:
	return 60 + 30 * lvl


func get_stat(s: String) -> int:
	var v := int(stats.get(s, 1))
	for key: String in talents:
		v += int(talent_def(key).get("stats", {}).get(s, 0))
	return v


# --- Talents ---------------------------------------------------------------------

static func talent_paths() -> Dictionary:
	if _talent_defs.is_empty():
		var d: Variant = DataFiles.read_json("res://data/progression/talents.json")
		for k: String in (d as Dictionary):
			if not k.begins_with("_"):
				_talent_defs[k] = d[k]
	return _talent_defs


static func talent_def(key: String) -> Dictionary:
	var path := key.get_slice("/", 0)
	var id := key.get_slice("/", 1)
	for st: Dictionary in talent_paths().get(path, {}).get("steps", []):
		if String(st["id"]) == id:
			return st
	return {}


func has_talent(key: String) -> bool:
	return talents.has(key)


## A special effect from any unlocked talent ("flash_heal", "spark", ...).
func has_special(name: String) -> bool:
	for key: String in talents:
		if String(talent_def(key).get("special", "")) == name:
			return true
	return false


## The next step of a path that can be learned (or "" if none).
func next_step(path: String) -> String:
	for st: Dictionary in talent_paths().get(path, {}).get("steps", []):
		var key := path + "/" + String(st["id"])
		if not talents.has(key):
			return key
	return ""


func learn(key: String) -> bool:
	if talent_points <= 0 or key != next_step(key.get_slice("/", 0)) or talent_def(key).is_empty():
		return false
	talents[key] = true
	talent_points -= 1
	changed.emit()
	EventHub.player_stats_changed.emit()
	return true


func add_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL or not GameState.is_playing:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		points += 1
		if level % 3 == 0:
			talent_points += 1
		leveled_up.emit(level)
		EventHub.toast_requested.emit(tr("PROG_LEVEL_UP") % level)
		Sfx.play(&"attune", 0.0, -2.0)
	changed.emit()
	EventHub.player_stats_changed.emit()


func raise(s: String) -> bool:
	if points <= 0 or not s in STATS or get_stat(s) >= MAX_STAT:
		return false
	stats[s] = get_stat(s) + 1
	points -= 1
	changed.emit()
	EventHub.player_stats_changed.emit()
	return true


## The characteristics' and talents' share of a stat (Inventory.stat adds or
## multiplies it).
func mod(stat_name: String) -> Variant:
	var base: Variant = _stat_mod(stat_name)
	for key: String in talents:
		var m: Dictionary = talent_def(key).get("mods", {})
		if m.has(stat_name):
			if stat_name in Inventory.MULT_STATS:
				base = (1.0 if base == null else float(base)) * float(m[stat_name])
			else:
				base = (0.0 if base == null else float(base)) + float(m[stat_name])
	return base


func _stat_mod(stat_name: String) -> Variant:
	var over := func(s: String) -> int: return get_stat(s) - 1
	match stat_name:
		"damage_bonus":
			return floori(over.call("strength") / 3.0)
		"dodge_cooldown_mult":
			return pow(0.96, over.call("agility"))
		"speed_mult":
			return 1.0 + 0.02 * over.call("agility")
		"max_health":
			return floori(over.call("endurance") / 2.0)
		"flash_cooldown_mult":
			return pow(0.95, over.call("will"))
		"flash_stun_bonus":
			return 0.08 * over.call("will")
		"repair_bonus":
			return 0.012 * over.call("intellect")
		"pay_mult":
			return 1.0 + 0.05 * over.call("intellect")
	return null


func _on_flag(flag: StringName, value: Variant) -> void:
	if not (value is bool and value):
		return
	var f := String(flag)
	if f.begins_with("boss.") and f.ends_with(".defeated") and not f.begins_with("boss.exp_rematch"):
		add_xp(XP_BOSS)
	elif f.begins_with("obj."):
		add_xp(XP_OBJECTIVE)


func _on_case(id: StringName) -> void:
	if Journal.case_status(id) == Journal.STATUS_DONE:
		add_xp(XP_CASE_MAIN if bool(Journal.case_defs.get(id, {}).get("main", false)) else XP_CASE_SIDE)


# --- Save ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "points": points, "talent_points": talent_points, "stats": stats.duplicate(), "talents": talents.keys()}


func from_dict(d: Dictionary) -> void:
	reset()
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	points = int(d.get("points", 0))
	talent_points = int(d.get("talent_points", 0))
	for s: String in d.get("stats", {}):
		if s in STATS:
			stats[s] = clampi(int(d["stats"][s]), 1, MAX_STAT)
	for k: String in d.get("talents", []):
		if not talent_def(k).is_empty():
			talents[k] = true
	changed.emit()
