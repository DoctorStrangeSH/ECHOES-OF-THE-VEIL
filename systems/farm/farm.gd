extends Node
## Brookside farm (R5): crops in plots, hens in the coop, a crate for the
## harvest. Bought through the side case case_brook_farm (flag farm.owned).
## A planted crop grows one step for every day it was watered (or it rained);
## nothing withers. Produce put in the crate is paid for the next morning.
## Data: data/farm/crops.json; items: data/items/items_farm.json.

signal changed

const CROPS_PATH := "res://data/farm/crops.json"
const OWNED_FLAG := &"farm.owned"
const MAX_HENS := 4
const HEN_PRICE := 12
const MAX_EGGS := 12

var crops: Dictionary = {}  # crop id -> def
## plot id -> {"crop": id, "growth": watered days so far, "watered": day or -1}
var plots: Dictionary = {}
var hens := 0
var eggs := 0
var shipped := 0  # paid tomorrow morning
var last_seed: StringName = &""


func _ready() -> void:
	var d: Variant = DataFiles.read_json(CROPS_PATH)
	if d is Dictionary:
		for k: String in d:
			if not k.begins_with("_"):
				crops[StringName(k)] = d[k]
	WorldClock.day_started.connect(_on_day_started)


func reset() -> void:
	plots = {}
	hens = 0
	eggs = 0
	shipped = 0
	last_seed = &""
	changed.emit()


func owned() -> bool:
	return GameState.has_flag(OWNED_FLAG)


func crop(id: StringName) -> Dictionary:
	return crops.get(id, {})


func crop_for_seed(seed: StringName) -> StringName:
	for id: StringName in crops:
		if StringName(crops[id]["seed"]) == seed:
			return id
	return &""


## Seed items in the bag, in data order.
func seeds_held() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in crops:
		var s := StringName(crops[id]["seed"])
		if Inventory.has(s):
			out.append(s)
	return out


func state(plot_id: StringName) -> String:
	var p: Dictionary = plots.get(plot_id, {})
	if p.is_empty():
		return "empty"
	return "ready" if int(p["growth"]) >= int(crop(p["crop"]).get("days", 1)) else "growing"


func is_watered(plot_id: StringName) -> bool:
	var p: Dictionary = plots.get(plot_id, {})
	return not p.is_empty() and (int(p["watered"]) == WorldClock.day or WorldClock.weather == "rain")


## Growth frame for the plot's sprite sheet with `frames` frames.
func frame(plot_id: StringName, frames: int) -> int:
	var p: Dictionary = plots.get(plot_id, {})
	if p.is_empty() or frames <= 0:
		return -1
	var days := int(crop(p["crop"]).get("days", 1))
	if int(p["growth"]) >= days:
		return frames - 1
	return clampi(int(float(p["growth"]) / float(days) * float(frames - 1)), 0, frames - 2)


func plant(plot_id: StringName, seed: StringName) -> bool:
	var c := crop_for_seed(seed)
	if not owned() or c == &"" or state(plot_id) != "empty" or not Inventory.has(seed):
		return false
	Inventory.remove(seed)
	plots[plot_id] = {"crop": String(c), "growth": 0, "watered": -1}
	last_seed = seed
	Sfx.play(&"pickup", 0.1, -6.0)
	changed.emit()
	return true


func water(plot_id: StringName) -> bool:
	if state(plot_id) != "growing" or is_watered(plot_id) or not Inventory.has(&"watering_can"):
		return false
	plots[plot_id]["watered"] = WorldClock.day
	Sfx.play(&"use", 0.1, -4.0)
	changed.emit()
	return true


func harvest(plot_id: StringName) -> bool:
	if state(plot_id) != "ready":
		return false
	var p: Dictionary = plots[plot_id]
	var c := crop(p["crop"])
	Inventory.add(StringName(c["produce"]), int(c.get("yield", 1)))
	var regrow := int(c.get("regrow", 0))
	if regrow > 0:
		p["growth"] = int(c["days"]) - regrow
		p["watered"] = -1
	else:
		plots.erase(plot_id)
	Progression.add_xp(2)
	changed.emit()
	return true


## Everything that grew here goes in the crate; returns its worth.
func ship_all() -> int:
	var total := 0
	for id in Inventory.list("produce"):
		total += int(Inventory.def(id).get("value", 0)) * Inventory.count(id)
		Inventory.remove(id, Inventory.count(id))
	shipped += total
	changed.emit()
	return total


func collect_eggs() -> int:
	var n := eggs
	if n > 0:
		Inventory.add(&"egg", n)
		eggs = 0
		changed.emit()
	return n


func buy_hen() -> bool:
	if hens >= MAX_HENS or Inventory.money < HEN_PRICE:
		return false
	Inventory.spend_money(HEN_PRICE)
	hens += 1
	changed.emit()
	return true


## The asking price, settled in conversation with Hugh (flag farm.price).
func price() -> int:
	return int(GameState.get_flag(&"farm.price", 120))


## Story effects ({"farm": action}); each reports what happened in a toast.
func act(action: String) -> void:
	match action:
		"collect_eggs":
			var n := collect_eggs()
			if n > 0:
				EventHub.toast_requested.emit(tr("FARM_TOAST_EGGS") % n)
		"buy_hen":
			if buy_hen():
				EventHub.toast_requested.emit(tr("FARM_TOAST_HEN") % [hens, MAX_HENS])
			else:
				EventHub.toast_requested.emit(tr("FARM_TOAST_NO_HEN"))
		"ship":
			var total := ship_all()
			EventHub.toast_requested.emit(tr("FARM_TOAST_SHIPPED") % total if total > 0 else tr("FARM_TOAST_CRATE_EMPTY"))
		"pay":
			Inventory.spend_money(price())
		"welcome":  # Hugh leaves his two hens
			hens = maxi(hens, 2)
			changed.emit()
		_:
			push_error("Farm: unknown action '%s'" % action)


func _on_day_started(day: int) -> void:
	var rained := WorldClock.weather_for_day(day - 1) == "rain"
	for id: StringName in plots:
		var p: Dictionary = plots[id]
		if rained or int(p["watered"]) == day - 1:
			p["growth"] = mini(int(p["growth"]) + 1, int(crop(p["crop"]).get("days", 1)))
		p["watered"] = -1
	if owned():
		eggs = mini(eggs + hens, MAX_EGGS)
	if shipped > 0:
		Inventory.add_money(shipped)
		EventHub.toast_requested.emit(tr("FARM_TOAST_PAID") % shipped)
		shipped = 0
	changed.emit()


func to_dict() -> Dictionary:
	var p := {}
	for id: StringName in plots:
		p[String(id)] = plots[id].duplicate()
	return {"plots": p, "hens": hens, "eggs": eggs, "shipped": shipped}


func from_dict(d: Dictionary) -> void:
	reset()
	for k: String in d.get("plots", {}):
		var p: Dictionary = d["plots"][k]
		if crops.has(StringName(String(p.get("crop", "")))):
			plots[StringName(k)] = {"crop": String(p["crop"]), "growth": int(p.get("growth", 0)), "watered": int(p.get("watered", -1))}
	hens = clampi(int(d.get("hens", 0)), 0, MAX_HENS)
	eggs = clampi(int(d.get("eggs", 0)), 0, MAX_EGGS)
	shipped = maxi(int(d.get("shipped", 0)), 0)
	changed.emit()
