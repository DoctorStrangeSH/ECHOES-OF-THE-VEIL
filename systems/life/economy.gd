class_name Economy
extends RefCounted
## Shops, selling and crafting rules (data in res://data/economy/).
## Invariants (tested): no item can be bought for less than a shop pays for
## it, and no recipe creates more sale value than its inputs cost to buy.

const SHOPS_PATH := "res://data/economy/shops"  # + shops_*.json
const RECIPES_PATH := "res://data/economy/recipes"
const SELL_RATIO := 0.5

static var _shops: Dictionary = {}
static var _recipes: Dictionary = {}


static func shops() -> Dictionary:
	if _shops.is_empty():
		_shops = _load(SHOPS_PATH)
	return _shops


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		_recipes = _load(RECIPES_PATH)
	return _recipes


static func _load(path: String) -> Dictionary:
	return DataFiles.defs(path)


static func sell_price(item: StringName) -> int:
	if Inventory.def(item).get("category", "") == "key":
		return 0
	return int(floor(float(Inventory.def(item).get("value", 0)) * SELL_RATIO))


## Buys entry `index` of `shop`. Returns true on success.
static func buy(shop: StringName, index: int) -> bool:
	var entries: Array = shops().get(shop, {}).get("buy", [])
	if index < 0 or index >= entries.size():
		return false
	var e: Dictionary = entries[index]
	var price := int(e.get("price", 0))
	if e.has("upgrade"):
		var up := StringName(e["upgrade"])
		if Livelihood.has_home_upgrade(up) or not Inventory.spend_money(price):
			return false
		Livelihood.add_home_upgrade(up)
		Sfx.play(&"attune")
		return true
	if not Inventory.spend_money(price):
		return false
	Inventory.add(StringName(e["item"]), 1, false)
	Sfx.play(&"coin")
	return true


static func sell(item: StringName) -> bool:
	var price := sell_price(item)
	if price <= 0 or not Inventory.has(item):
		return false
	if Inventory.equipped.values().has(item) and Inventory.count(item) <= 1:
		return false
	Inventory.remove(item)
	Inventory.money += price
	Inventory.changed.emit()
	Sfx.play(&"coin")
	return true


static func can_craft(recipe: StringName) -> bool:
	var r: Dictionary = recipes().get(recipe, {})
	if r.is_empty() or Livelihood.repair_level() < int(r.get("min_level", 1)):
		return false
	if r.has("needs_flag") and not GameState.has_flag(StringName(r["needs_flag"])):
		return false
	var inputs: Dictionary = r.get("inputs", {})
	for item: String in inputs:
		if not Inventory.has(StringName(item), int(inputs[item])):
			return false
	return true


static func craft(recipe: StringName) -> bool:
	if not can_craft(recipe):
		return false
	var r: Dictionary = recipes()[recipe]
	var inputs: Dictionary = r["inputs"]
	for item: String in inputs:
		Inventory.remove(StringName(item), int(inputs[item]))
	var output: Dictionary = r["output"]
	for item: String in output:
		Inventory.add(StringName(item), int(output[item]), false)
	Sfx.play(&"equip")
	return true


## Cheapest price at which `item` can be bought anywhere (or -1).
static func cheapest_price(item: StringName) -> int:
	var best := -1
	for shop: StringName in shops():
		for e: Dictionary in shops()[shop].get("buy", []):
			if StringName(e.get("item", "")) == item:
				var p := int(e["price"])
				best = p if best < 0 else mini(best, p)
	return best


## Economy invariants, for tests.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for shop: StringName in shops():
		for e: Dictionary in shops()[shop].get("buy", []):
			if e.has("item"):
				var item := StringName(e["item"])
				if not Inventory.item_defs.has(item):
					problems.append("%s sells unknown item %s" % [shop, item])
				elif sell_price(item) >= int(e["price"]):
					problems.append("%s: %s sells back for >= its price (loop)" % [shop, item])
			elif e.has("upgrade") and not Livelihood.upgrade_defs.has(StringName(e["upgrade"])):
				problems.append("%s sells unknown upgrade %s" % [shop, e["upgrade"]])
	for r: StringName in recipes():
		var def: Dictionary = recipes()[r]
		var cost := 0
		for item: String in def.get("inputs", {}):
			var p := cheapest_price(StringName(item))
			cost += (p if p >= 0 else 0) * int(def["inputs"][item])
		var value := 0
		for item: String in def.get("output", {}):
			value += sell_price(StringName(item)) * int(def["output"][item])
		if value > cost:
			problems.append("recipe %s sells for more than its inputs cost" % r)
	return problems
