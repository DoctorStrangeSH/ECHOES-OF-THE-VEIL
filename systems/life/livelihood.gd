extends Node
## Work and ownership: the repair profession (skill, daily jobs), weekly rent,
## home upgrades and the repair stall (light business layer).
## Data: res://data/economy/*.json. Owner: life. Tests: tests/test_runner.gd.
## Time only passes while the player plays, so nothing decays during breaks.

signal changed

const JOBS_PATH := "res://data/economy/jobs"  # + jobs_*.json
const UPGRADES_PATH := "res://data/economy/home_upgrades"
const BUSINESS_PATH := "res://data/economy/business.json"
const LEVEL_XP := [0, 6, 16, 32, 55]  # xp needed for level 1..5
const JOBS_PER_DAY := 3
const MAX_ACTIVE_JOBS := 2
const RENT := 15
const RENT_EVERY_DAYS := 7

var job_defs: Dictionary = {}
var upgrade_defs: Dictionary = {}
var business_def: Dictionary = {}

var repair_xp := 0
var offered: Array[StringName] = []
var active: Array[StringName] = []
var done_today: Array[StringName] = []
var done_once: Array[StringName] = []
var rent_debt := 0
var home: Array[StringName] = []
## Stall state.
var stall := {"open": false, "tier": "fair", "stock": 0, "reputation": 0, "upgrades": [], "report": {}}


func _enter_tree() -> void:
	job_defs = _load(JOBS_PATH)
	upgrade_defs = _load(UPGRADES_PATH)
	var b: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUSINESS_PATH))
	business_def = b if b is Dictionary else {}


func _ready() -> void:
	WorldClock.day_started.connect(_on_day_started)
	reset()


func _load(path: String) -> Dictionary:
	return DataFiles.defs(path)


func reset() -> void:
	repair_xp = 0
	offered.clear()
	active.clear()
	done_today.clear()
	done_once.clear()
	rent_debt = 0
	home.clear()
	stall = {"open": false, "tier": "fair", "stock": 0, "reputation": 0, "upgrades": [], "report": {}}
	_offer_jobs(WorldClock.day)
	changed.emit()


# --- Repair skill --------------------------------------------------------------

func repair_level() -> int:
	var lvl := 1
	for i in LEVEL_XP.size():
		if repair_xp >= int(LEVEL_XP[i]):
			lvl = i + 1
	return lvl


func add_repair_xp(amount: int) -> void:
	var before := repair_level()
	repair_xp += amount
	var after := repair_level()
	for l in range(before + 1, after + 1):
		GameState.set_flag(StringName("repair.level_%d" % l), true)
		EventHub.toast_requested.emit(tr("TOAST_REPAIR_LEVEL") % l)
		Sfx.play(&"attune")
	changed.emit()


## Width of the success zone in the repair minigame (0..1 of the bar).
func repair_zone(difficulty: int) -> float:
	return clampf(0.24 + 0.04 * (repair_level() - 1) - 0.05 * (difficulty - 1) + Inventory.stat("repair_bonus"), 0.08, 0.5)


# --- Jobs ------------------------------------------------------------------------

func job(id: StringName) -> Dictionary:
	return job_defs.get(id, {})


func can_offer(id: StringName) -> bool:
	var d := job(id)
	if d.is_empty() or (bool(d.get("once", false)) and done_once.has(id)) or not bool(d.get("board", true)):
		return false
	return StoryRules.evaluate(d.get("requires"))


## Deterministic daily selection, so reloading a day shows the same board.
func _offer_jobs(day: int) -> void:
	offered.clear()
	var pool: Array[StringName] = []
	for id: StringName in job_defs:
		if can_offer(id) and not active.has(id):
			pool.append(id)
	pool.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + 17)
	while not pool.is_empty() and offered.size() < JOBS_PER_DAY:
		offered.append(pool.pop_at(rng.randi() % pool.size()))


func accept(id: StringName) -> bool:
	if not offered.has(id) or active.size() >= MAX_ACTIVE_JOBS:
		return false
	offered.erase(id)
	active.append(id)
	Sfx.play(&"ui_click")
	changed.emit()
	return true


## A job given in person (a story effect), not picked from the board.
func take(id: StringName) -> void:
	if job(id).is_empty() or active.has(id) or (bool(job(id).get("once", false)) and done_once.has(id)):
		return
	offered.erase(id)
	active.append(id)
	changed.emit()


func abandon(id: StringName) -> void:
	if active.has(id):
		active.erase(id)
		changed.emit()


func active_job_for_spot(spot: StringName) -> StringName:
	for id in active:
		if StringName(job(id).get("spot", "")) == spot:
			return id
	return &""


## Called by the repair minigame on success.
func complete(id: StringName) -> void:
	if not active.has(id):
		return
	var d := job(id)
	Inventory.remove(&"scrap", int(d.get("scrap", 0)))
	active.erase(id)
	done_today.append(id)
	if bool(d.get("once", false)):
		done_once.append(id)
	Inventory.add_money(roundi(float(d.get("pay", 0)) * Inventory.stat("pay_mult")))
	if Progression.has_special("salvage") and int(d.get("scrap", 0)) > 0:
		Inventory.add(&"scrap", 1, false)
	if d.has("resonance"):
		Inventory.add_resonance(int(d["resonance"]))
	if d.has("client"):
		GameState.change_relationship(StringName(d["client"]), 1)
	StoryRules.apply(d.get("effects", []))
	add_repair_xp(int(d.get("xp", 1)))
	EventHub.toast_requested.emit(tr("TOAST_JOB_DONE") % tr(d.get("name", "")))
	changed.emit()


# --- Home -------------------------------------------------------------------------

func has_home_upgrade(id: StringName) -> bool:
	return home.has(id)


func add_home_upgrade(id: StringName) -> void:
	if home.has(id) or not upgrade_defs.has(id):
		return
	home.append(id)
	GameState.set_flag(StringName("home.%s" % id), true)
	EventHub.player_stats_changed.emit()
	EventHub.toast_requested.emit(tr("TOAST_HOME_UPGRADE") % tr(upgrade_defs[id].get("name", "")))
	changed.emit()


## Stat modifiers from home upgrades (combined into Inventory.stat).
func home_mods() -> Array:
	var out: Array = []
	for id in home:
		out.append(upgrade_defs.get(id, {}).get("mods", {}))
	return out


# --- Rent --------------------------------------------------------------------------

func _collect_rent(amount: int) -> void:
	var paid := mini(amount, Inventory.money)
	Inventory.money -= paid
	rent_debt += amount - paid
	Inventory.changed.emit()
	if amount - paid > 0:
		EventHub.toast_requested.emit(tr("TOAST_RENT_SHORT") % (amount - paid))
	elif amount > 0:
		EventHub.toast_requested.emit(tr("TOAST_RENT_PAID") % amount)


# --- Stall (business) ------------------------------------------------------------

func stall_unlocked() -> bool:
	return GameState.has_flag(&"biz.unlocked")


func set_stall_open(open: bool) -> void:
	stall["open"] = open
	changed.emit()


func set_stall_tier(tier: String) -> void:
	if business_def.get("price_tiers", {}).has(tier):
		stall["tier"] = tier
		changed.emit()


func stock_stall(amount: int) -> int:
	var moved := mini(amount, Inventory.count(&"repair_kit"))
	if moved > 0:
		Inventory.remove(&"repair_kit", moved)
		stall["stock"] = int(stall["stock"]) + moved
		changed.emit()
	return moved


func can_buy_stall_upgrade(id: String) -> bool:
	var u: Dictionary = business_def.get("upgrades", {}).get(id, {})
	return not u.is_empty() and not (stall["upgrades"] as Array).has(id) \
		and Inventory.money >= int(u.get("price", 0)) and StoryRules.evaluate(u.get("requires"))


func buy_stall_upgrade(id: String) -> bool:
	if not can_buy_stall_upgrade(id):
		return false
	var u: Dictionary = business_def["upgrades"][id]
	Inventory.spend_money(int(u.get("price", 0)))
	(stall["upgrades"] as Array).append(id)
	Sfx.play(&"attune")
	changed.emit()
	return true


## Expected customers for a tier (for the UI and the daily resolution).
func expected_customers(tier: String) -> int:
	var t: Dictionary = business_def.get("price_tiers", {}).get(tier, {})
	var base := float(business_def.get("base_customers", 2)) + float(stall["reputation"]) / 2.0
	for u: String in stall["upgrades"]:
		base += float(business_def.get("upgrades", {}).get(u, {}).get("customers", 0))
	return clampi(roundi(base * float(t.get("demand", 1.0))), 0, int(business_def.get("max_customers", 6)))


## Resolves one day of trading. Returns the report.
func resolve_stall_day() -> Dictionary:
	var report := {"open": bool(stall["open"]), "sold": 0, "income": 0, "upkeep": 0}
	if stall_unlocked() and bool(stall["open"]):
		var tier: String = stall["tier"]
		var t: Dictionary = business_def["price_tiers"][tier]
		var sold := mini(expected_customers(tier), int(stall["stock"]))
		var upkeep := int(business_def.get("rent_per_day", 1))
		stall["stock"] = int(stall["stock"]) - sold
		report["sold"] = sold
		report["income"] = sold * int(t["price"])
		report["upkeep"] = upkeep
		Inventory.money = maxi(0, Inventory.money + int(report["income"]) - upkeep)
		if sold > 0:
			stall["reputation"] = clampi(int(stall["reputation"]) + int(t.get("reputation", 0)), 0, 10)
		Inventory.changed.emit()
	stall["report"] = report
	return report


# --- Day tick ----------------------------------------------------------------------

func _on_day_started(day: int) -> void:
	var report := resolve_stall_day()
	if bool(report["open"]):
		EventHub.toast_requested.emit(tr("TOAST_STALL_REPORT") % [int(report["sold"]), int(report["income"])])
	if day > 1 and (day - 1) % RENT_EVERY_DAYS == 0:
		_collect_rent(RENT)
	elif rent_debt > 0 and Inventory.money > 0:
		var debt := rent_debt
		rent_debt = 0
		_collect_rent(debt)
	done_today.clear()
	_offer_jobs(day)
	changed.emit()


# --- Save ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"repair_xp": repair_xp,
		"offered": offered.map(func(x: StringName) -> String: return String(x)),
		"active": active.map(func(x: StringName) -> String: return String(x)),
		"done_today": done_today.map(func(x: StringName) -> String: return String(x)),
		"done_once": done_once.map(func(x: StringName) -> String: return String(x)),
		"rent_debt": rent_debt,
		"home": home.map(func(x: StringName) -> String: return String(x)),
		"stall": stall.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	repair_xp = int(data.get("repair_xp", 0))
	offered = _ids(data.get("offered", []), job_defs)
	active = _ids(data.get("active", []), job_defs)
	done_today = _ids(data.get("done_today", []), job_defs)
	done_once = _ids(data.get("done_once", []), job_defs)
	rent_debt = int(data.get("rent_debt", 0))
	home = _ids(data.get("home", []), upgrade_defs)
	var s: Variant = data.get("stall", {})
	stall = {"open": false, "tier": "fair", "stock": 0, "reputation": 0, "upgrades": [], "report": {}}
	if s is Dictionary:
		for k: String in stall:
			if s.has(k):
				stall[k] = s[k]
		stall["stock"] = int(stall["stock"])
		stall["reputation"] = int(stall["reputation"])
	if offered.is_empty() and active.is_empty():
		_offer_jobs(WorldClock.day)
	changed.emit()


func _ids(list: Variant, defs: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if list is Array:
		for x: Variant in list:
			if defs.has(StringName(x)):
				out.append(StringName(x))
	return out
