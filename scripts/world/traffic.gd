class_name Traffic
extends Node2D
## Cars and the odd bus driving along a street (region option "traffic":
## {"lanes": [{"y": 318, "dir": -1}, ...]}). Each lane runs the whole width of
## the map; vehicles enter off-screen, keep their distance, wait for anyone
## standing in the road and leave at the other end. Purely decorative: they
## never hit anyone.

const CARS := 26
const SPEED := Vector2(46.0, 66.0)
const GAP := 18.0
const WAIT_FOR_PLAYER := 30.0

var lanes: Array = []
var width := 640.0
var _vehicles: Array = []  # {node, lane, speed, length}
var _timers: Array[float] = []
var _rng := RandomNumberGenerator.new()


func setup(spec: Dictionary, map_width: float) -> void:
	lanes = spec.get("lanes", [])
	width = map_width
	_rng.seed = hash(String(get_path()))
	for i in lanes.size():
		_timers.append(_rng.randf_range(0.5, 4.0))
		# Start with one car already on the street so it never looks dead.
		_spawn(i, _rng.randf_range(width * 0.2, width * 0.8))


func _process(delta: float) -> void:
	for i in lanes.size():
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			_timers[i] = _rng.randf_range(3.0, 9.0)
			var d := int(lanes[i].get("dir", -1))
			_spawn(i, width + 60.0 if d < 0 else -60.0)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	for v: Dictionary in _vehicles.duplicate():
		var node: Node2D = v["node"]
		var lane: Dictionary = lanes[v["lane"]]
		var d := float(lane.get("dir", -1))
		var front: float = node.position.x + d * float(v["length"]) / 2.0
		var blocked := false
		if player != null:
			var py := player.global_position.y - global_position.y
			var ahead: float = (player.global_position.x - global_position.x - front) * d
			if py > float(lane["y"]) - 26.0 and py < float(lane["y"]) + 8.0 and ahead > -4.0 and ahead < WAIT_FOR_PLAYER:
				blocked = true
		for o: Dictionary in _vehicles:
			if o == v or o["lane"] != v["lane"]:
				continue
			var gap: float = ((o["node"] as Node2D).position.x - node.position.x) * d - (o["length"] + v["length"]) / 2.0
			if gap > -4.0 and gap < GAP:
				blocked = true
		v["speed"] = move_toward(v["speed"], 0.0 if blocked else v["cruise"], delta * (140.0 if blocked else 40.0))
		node.position.x += d * v["speed"] * delta
		if node.position.x < -120.0 or node.position.x > width + 120.0:
			node.queue_free()
			_vehicles.erase(v)


func _spawn(lane_idx: int, x: float) -> void:
	var lane: Dictionary = lanes[lane_idx]
	var d := int(lane.get("dir", -1))
	for o: Dictionary in _vehicles:
		if o["lane"] == lane_idx and absf((o["node"] as Node2D).position.x - x) < 110.0:
			return  # no room at the kerb yet
	var side := "Left" if d < 0 else "Right"
	var bus := _rng.randf() < 0.12
	var id := "Bus_%s_%d" % [side, _rng.randi_range(1, 6)] if bus else "Car_%s_%d" % [side, _rng.randi_range(1, CARS)]
	var tex := AssetLibrary.load_texture("modern_exteriors/Modern_Exteriors_16x16/ME_Theme_Sorter_16x16/10_Vehicles_Singles_16x16/ME_Singles_Vehicles_16x16_%s.png" % id)
	var sprite := Sprite2D.new()
	if tex == null:
		sprite.texture = AssetLibrary.placeholder(Vector2i(48, 24), Color(0.4, 0.5, 0.7))
	else:
		sprite.texture = tex
	var size := sprite.texture.get_size()
	sprite.centered = false
	sprite.offset = Vector2(-size.x / 2.0, -size.y)
	sprite.position = Vector2(x, float(lane["y"]))
	add_child(sprite)
	var cruise := _rng.randf_range(SPEED.x, SPEED.y) * (0.8 if bus else 1.0)
	_vehicles.append({"node": sprite, "lane": lane_idx, "speed": cruise, "cruise": cruise, "length": size.x - 4.0})
