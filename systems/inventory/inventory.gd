extends Node
## Items, equipment, money, Resonance and Attunements.
## Saved by item ID and quantity (never scene instances).
## Definitions: res://data/items/items.json, res://data/progression/attunements.json.
## Owner: inventory. Tests: tests/test_runner.gd.

signal changed

const ITEMS_PATH := "res://data/items/items"  # + items_*.json
const ATTUNEMENTS_PATH := "res://data/progression/attunements"
const CATEGORIES: PackedStringArray = ["weapon", "trinket", "consumable", "material", "key", "seed", "produce", "fish"]
## Filter groups: the "farm" filter shows seeds and produce together.
const FILTER_GROUPS := {"farm": ["seed", "produce", "fish"]}
const DEFAULT_WEAPON := &"fists"
## Additive stats default to 0, multipliers to 1.
const MULT_STATS: PackedStringArray = ["dodge_cooldown_mult", "dodge_distance_mult", "flash_cooldown_mult", "flash_radius_mult", "speed_mult", "pay_mult"]

var item_defs: Dictionary = {}
## The last dish eaten (R7b): {"mods": {...}, "until": absolute minute, "desc": key}.
var meal: Dictionary = {}
var attunement_defs: Dictionary = {}

var items: Dictionary = {}  # item_id -> count
var equipped: Dictionary = {"weapon": DEFAULT_WEAPON, "trinket": &""}
var money: int = 0
var resonance: int = 0
var attunements: Dictionary = {}  # attunement_id -> true
## The player's own arrangement of the bag (drag and drop in the Things tab).
## Items not in it yet go to the end in the order they arrived.
var order: Array[StringName] = []


func _enter_tree() -> void:
	item_defs = _load(ITEMS_PATH)
	attunement_defs = _load(ATTUNEMENTS_PATH)


func _ready() -> void:
	(func() -> void: WorldClock.time_changed.connect(_on_time)).call_deferred()


func _load(path: String) -> Dictionary:
	return DataFiles.defs(path)


func reset() -> void:
	items.clear()
	order.clear()
	equipped = {"weapon": DEFAULT_WEAPON, "trinket": &""}
	money = 0
	meal = {}
	resonance = 0
	attunements.clear()
	changed.emit()


# --- Items -------------------------------------------------------------------

func def(id: StringName) -> Dictionary:
	return item_defs.get(id, {})


func count(id: StringName) -> int:
	return int(items.get(id, 0))


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func add(id: StringName, amount: int = 1, notify: bool = true) -> void:
	if not item_defs.has(id):
		push_error("Inventory: unknown item '%s'" % id)
		return
	var cap := int(def(id).get("stack", 1 if def(id).get("category") != "consumable" else 9))
	items[id] = mini(count(id) + amount, maxi(cap, 1))
	if not order.has(id):
		order.append(id)
	if notify:
		EventHub.toast_requested.emit(tr("TOAST_ITEM_GAINED") % [tr(def(id).get("name", "")), amount])
	Sfx.play(&"pickup")
	var ev := StringName(def(id).get("evidence", ""))
	if ev != &"":
		Journal.add_evidence(ev)
	changed.emit()


func remove(id: StringName, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] <= 0:
		items.erase(id)
		order.erase(id)
		for slot: String in equipped:
			if equipped[slot] == id:
				equipped[slot] = DEFAULT_WEAPON if slot == "weapon" else &""
	changed.emit()
	return true


## Item IDs the player holds in a category, in the bag's order.
func list(category: String = "") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in items:
		var cat: String = def(id).get("category", "")
		if category.is_empty() or cat == category or (FILTER_GROUPS.get(category, []) as Array).has(cat):
			out.append(id)
	if category in ["", "weapon"] and not out.has(DEFAULT_WEAPON):
		out.push_front(DEFAULT_WEAPON)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return _rank(a) < _rank(b))
	return out


func _rank(id: StringName) -> int:
	if id == DEFAULT_WEAPON:
		return -1
	var i := order.find(id)
	return i if i >= 0 else 100000 + items.keys().find(id)


## Puts an item just before another in the bag (or at the end).
func move(id: StringName, before: StringName = &"") -> void:
	if id == before or id == DEFAULT_WEAPON:
		return
	for k: StringName in items:
		if not order.has(k):
			order.append(k)
	order.erase(id)
	var i := order.find(before)
	if i < 0:
		order.append(id)
	else:
		order.insert(i, id)
	changed.emit()


## The item's picture: a single file, or a cell of an icon sheet written as
## "sheet.png#col,row" (16x16 cells). Null when there is none.
func icon_of(id: StringName) -> Texture2D:
	var path := String(def(id).get("icon", ""))
	if path.is_empty():
		return null
	if not path.contains("#"):
		return AssetLibrary.load_texture(path)
	var sheet := AssetLibrary.load_texture(path.get_slice("#", 0))
	if sheet == null:
		return null
	var cell := path.get_slice("#", 1).split(",")
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(int(cell[0]) * 16, int(cell[1]) * 16, 16, 16)
	return a


func can_equip(id: StringName) -> bool:
	var cat: String = def(id).get("category", "")
	return cat in ["weapon", "trinket"] and (id == DEFAULT_WEAPON or has(id))


func equip(id: StringName) -> void:
	if not can_equip(id):
		return
	var slot: String = def(id)["category"]
	equipped[slot] = id
	Sfx.play(&"equip")
	changed.emit()


func unequip(slot: String) -> void:
	equipped[slot] = DEFAULT_WEAPON if slot == "weapon" else &""
	changed.emit()


func weapon() -> Dictionary:
	var id: StringName = equipped.get("weapon", DEFAULT_WEAPON)
	return def(id).get("weapon", def(DEFAULT_WEAPON)["weapon"])


## Uses a consumable. Returns true if consumed.
func use(id: StringName) -> bool:
	var d := def(id)
	if d.get("category") != "consumable" or not has(id):
		return false
	var effect: Dictionary = d.get("use", {})
	if not effect.has("heal"):
		return false  # e.g. repair kits are spent by the repair minigame
	if effect.has("heal"):
		EventHub.player_heal_requested_amount.emit(int(effect["heal"]) + int(stat("heal_bonus")))
	if effect.has("meal"):
		var m: Dictionary = effect["meal"]
		meal = {"mods": m.get("mods", {}), "until": WorldClock.absolute_minute() + int(m.get("minutes", 120)), "desc": String(m.get("desc", ""))}
		EventHub.toast_requested.emit(tr("MEAL_TOAST") % [tr(meal["desc"]), WorldClock.clock_text(int(meal["until"]) % (24 * 60))])
		EventHub.player_stats_changed.emit()
	remove(id)
	Sfx.play(&"use")
	return true


# --- Money & Resonance ---------------------------------------------------------

func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	if amount > 0:
		EventHub.toast_requested.emit(tr("TOAST_MONEY_GAINED") % amount)
	changed.emit()


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	changed.emit()
	return true


func add_resonance(amount: int) -> void:
	resonance = maxi(0, resonance + amount)
	changed.emit()


# --- Attunements -------------------------------------------------------------

func has_attunement(id: StringName) -> bool:
	return attunements.has(id)


func can_attune(id: StringName) -> bool:
	var d: Dictionary = attunement_defs.get(id, {})
	if d.is_empty() or has_attunement(id):
		return false
	var req := StringName(d.get("requires", ""))
	if req != &"" and not has_attunement(req):
		return false
	return resonance >= int(d.get("cost", 0))


func attune(id: StringName) -> bool:
	if not can_attune(id):
		return false
	resonance -= int(attunement_defs[id]["cost"])
	attunements[id] = true
	Sfx.play(&"attune")
	changed.emit()
	EventHub.player_stats_changed.emit()
	return true


# --- Stats ---------------------------------------------------------------------

## Combined modifier from equipped trinket + attunements.
func stat(stat_name: String) -> float:
	var mult := stat_name in MULT_STATS
	var v := 1.0 if mult else 0.0
	var sources: Array = []
	var trinket: StringName = equipped.get("trinket", &"")
	if trinket != &"":
		sources.append(def(trinket).get("mods", {}))
	for a: StringName in attunements:
		sources.append(attunement_defs.get(a, {}).get("mods", {}))
	sources.append_array(Livelihood.home_mods())
	if meal_active():
		sources.append(meal.get("mods", {}))
	for mods: Dictionary in sources:
		if mods.has(stat_name):
			v = v * float(mods[stat_name]) if mult else v + float(mods[stat_name])
	var p: Variant = Progression.mod(stat_name)
	if p != null:
		v = v * float(p) if mult else v + float(p)
	return v


## A meal's bonus lasts until its time runs out.
func meal_active() -> bool:
	return not meal.is_empty() and WorldClock.absolute_minute() < int(meal.get("until", 0))


func _on_time(_m: int) -> void:
	if not meal.is_empty() and not meal_active():
		meal = {}
		EventHub.player_stats_changed.emit()
		changed.emit()


# --- Save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var it := {}
	for id: StringName in items:
		it[String(id)] = items[id]
	var att: Array[String] = []
	for id: StringName in attunements:
		att.append(String(id))
	return {
		"items": it,
		"equipped": {"weapon": String(equipped.get("weapon", DEFAULT_WEAPON)), "trinket": String(equipped.get("trinket", ""))},
		"money": money, "resonance": resonance, "attunements": att, "meal": meal.duplicate(true),
		"order": order.map(func(x: StringName) -> String: return String(x)),
	}


func from_dict(data: Dictionary) -> void:
	items.clear()
	var it: Dictionary = data.get("items", {})
	for id: String in it:
		if item_defs.has(StringName(id)):
			items[StringName(id)] = int(it[id])
		else:
			push_warning("Inventory: dropping unknown item '%s' from save" % id)
	var eq: Dictionary = data.get("equipped", {})
	equipped = {"weapon": StringName(eq.get("weapon", DEFAULT_WEAPON)), "trinket": StringName(eq.get("trinket", ""))}
	if not can_equip(equipped["weapon"]):
		equipped["weapon"] = DEFAULT_WEAPON
	if equipped["trinket"] != &"" and not can_equip(equipped["trinket"]):
		equipped["trinket"] = &""
	order.clear()
	for id: Variant in data.get("order", []):
		if items.has(StringName(id)) and not order.has(StringName(id)):
			order.append(StringName(id))
	for id: StringName in items:
		if not order.has(id):
			order.append(id)
	money = int(data.get("money", 0))
	resonance = int(data.get("resonance", 0))
	var ml: Variant = data.get("meal", {})
	meal = ml if ml is Dictionary else {}
	attunements.clear()
	for id: Variant in data.get("attunements", []):
		if attunement_defs.has(StringName(id)):
			attunements[StringName(id)] = true
	changed.emit()
