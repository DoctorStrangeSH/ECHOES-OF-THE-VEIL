class_name Crowd
extends Node
## Townspeople on the streets (R1c). Data: data/world/crowds.json (routes and
## how many people are out in each part of the day, per location) and
## data/world/chatter.json (what they say, some lines only after certain
## events). Fewer people at night and in the rain. Never in Veil places.

const CROWDS_PATH := "res://data/world/crowds.json"
const CHATTER_PATH := "res://data/world/chatter.json"
const ACCESSORIES: PackedStringArray = ["Accessory_15_Glasses_01", "Accessory_15_Glasses_02", "Accessory_11_Beanie_01",
	"Accessory_11_Beanie_04", "Accessory_03_Backpack_02", "Accessory_03_Backpack_05", "Accessory_13_Beard_01",
	"Accessory_13_Beard_03", "Accessory_12_Mustache_02", "Accessory_04_Snapback_03"]

static var _crowds: Dictionary = {}
static var _chatter: Array = []
static var _layers: Dictionary = {}

var location_id: StringName = &""
var _def: Dictionary = {}
var _routes: Array[PackedVector2Array] = []
var _people: Array = []
var _entities: Node2D
var _rng := RandomNumberGenerator.new()
var _spawn_wait := 0.0


static func defs() -> Dictionary:
	if _crowds.is_empty():
		var d: Variant = DataFiles.read_json(CROWDS_PATH)
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_"):
					_crowds[StringName(k)] = d[k]
	return _crowds


static func chatter() -> Array:
	if _chatter.is_empty():
		var d: Variant = DataFiles.read_json(CHATTER_PATH)
		if d is Dictionary:
			_chatter = d.get("lines", [])
	return _chatter


func setup(loc_id: StringName, entities: Node2D) -> void:
	location_id = loc_id
	_entities = entities
	_def = defs().get(loc_id, {})
	for r: Array in _def.get("routes", []):
		var pts := PackedVector2Array()
		for p: Array in r:
			pts.append(Vector2(float(p[0]), float(p[1])))
		_routes.append(pts)
	_rng.seed = hash([loc_id, WorldClock.day, WorldClock.get_hour()])
	for i in wanted():
		_spawn(true)


## How many people should be out right now.
func wanted() -> int:
	var n := int((_def.get("count", {}) as Dictionary).get(WorldClock.get_period(), 0))
	if WorldClock.weather == "rain":
		n = int(ceil(n * 0.5))
	return n


func _process(delta: float) -> void:
	if _routes.is_empty():
		return
	_people = _people.filter(func(p: Variant) -> bool: return is_instance_valid(p))
	if _people.size() < wanted():
		_spawn_wait -= delta
		if _spawn_wait <= 0.0:
			_spawn_wait = _rng.randf_range(1.5, 5.0)
			_spawn(false)


func _spawn(anywhere: bool) -> void:
	if _routes.is_empty() or _entities == null:
		return
	var route := _routes[_rng.randi() % _routes.size()]
	if _rng.randf() < 0.5:
		route = route.duplicate()
		route.reverse()
	var start := route[0]
	var idx := 1
	if anywhere:
		# Somewhere along the way, so the street is not empty when you arrive.
		var seg := _rng.randi() % (route.size() - 1)
		start = route[seg].lerp(route[seg + 1], _rng.randf())
		idx = seg + 1
	var p := Passerby.new()
	p.crowd = self
	p.setup(route, idx, start, random_appearance(_rng), _rng.randi())
	_entities.add_child(p)
	_people.append(p)


## A line for someone in this place, now (story-aware).
func line_for(rng: RandomNumberGenerator) -> String:
	var pool := PackedStringArray()
	for l: Dictionary in chatter():
		var where: Array = l.get("where", [])
		if not where.is_empty() and not where.has(String(location_id)):
			continue
		if StoryRules.evaluate(l.get("if", {})):
			pool.append(String(l["text"]))
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else "CHATTER_BUSY"


static func _layer_ids(folder: String) -> PackedStringArray:
	if not _layers.has(folder):
		_layers[folder] = AssetLibrary.list_png_ids("%s/%s/16x16" % [AssetLibrary.CHARACTER_GENERATOR, folder])
	return _layers[folder]


static func random_appearance(rng: RandomNumberGenerator) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.placeholder_color = Color.from_hsv(rng.randf(), 0.35, 0.8)
	for layer: String in ["body", "eyes", "outfit", "hairstyle"]:
		var ids := _layer_ids(CharacterAppearance.LAYER_FOLDERS[layer])
		if not ids.is_empty():
			a.set(layer, ids[rng.randi() % ids.size()])
	a.accessory = ACCESSORIES[rng.randi() % ACCESSORIES.size()] if rng.randf() < 0.3 else ""
	return a
