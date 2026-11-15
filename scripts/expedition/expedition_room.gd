class_name ExpeditionRoom
extends Location
## One room of an expedition (see Expedition). Built at runtime from the
## run: site layout and palette, echoes from the site's pool, the run's
## modifiers, and in the last room a rematch boss. The exit opens when the
## room is clear.

const ENEMY_SCENE := preload("res://scenes/combat/echo_enemy.tscn")
const WALKABLE := "fgpy"
const GRID_EVERY := 3.2
const FLOOD_EVERY := 5.0

var exit: ExpeditionExit
var boss: Node = null
var flood: FloodWater = null
var grid: EditGrid = null
var _rng := RandomNumberGenerator.new()
var _rows: PackedStringArray = []
var _start := Vector2.ZERO
var _timer := 0.0
var _flood_t := 0.0
var _flood_high := false
var _open := false


func _ready() -> void:
	var room := Expedition.current_room()
	if room.is_empty():
		# A stale save outside any run: a plain room with the way home.
		room = {"rows": ["#####", "#fff#", "#fff#", "#fff#", "##f##"], "start": [40, 56], "exit": [40, 40]}
	var site := Expedition.site_def()
	_rows = PackedStringArray(room["rows"])
	_rng.seed = hash([Expedition.run.get("seed", 0), Expedition.run.get("room", 0)])
	location_id = &"expedition_room"
	combat_enabled = true
	outdoors = false
	name_key = String(site.get("name", "")) if int(Expedition.run.get("room", 0)) == 0 else ""
	var tint_arr: Array = site.get("tint", [0.8, 0.85, 1.0, 1.0])
	fixed_tint = Color(tint_arr[0], tint_arr[1], tint_arr[2], 1.0)
	if Expedition.has_mod(&"lightless"):
		fixed_tint = fixed_tint * Color(0.32, 0.32, 0.4, 1.0)
	ground.palette_id = String(site.get("palette", "echo_corridor"))
	ground.layout = "\n".join(_rows)
	ground.paint()
	_start = _vec(room["start"])
	var sp := SpawnPoint.new()
	sp.spawn_id = &"start"
	sp.facing = Vector2.UP
	sp.position = _start
	$SpawnPoints.add_child(sp)
	super._ready()
	_build(room)


static func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _build(room: Dictionary) -> void:
	exit = ExpeditionExit.new()
	exit.position = _vec(room["exit"])
	exit.enabled = not Expedition.active()
	exit.leads_home = not Expedition.active()
	entities.add_child(exit)
	if not Expedition.active():
		return
	if int(Expedition.run["room"]) == 0:
		var home := ExpeditionExit.new()
		home.leads_home = true
		home.prompt_key = "PROMPT_EXP_LEAVE"
		home.position = _start + Vector2(-40, 4)
		entities.add_child(home)
	if Expedition.is_arena():
		_spawn_boss(room)
	else:
		_spawn_echoes()
	var boss_id: String = Expedition.run.get("boss", "")
	var arena := Expedition.is_arena()
	if Expedition.has_mod(&"flooded") and not (arena and boss_id == "archivist"):
		flood = FloodWater.new()
		flood.size = _floor_rect().size
		flood.position = _floor_rect().position
		flood.set_target(0.3, 0.2)
		add_child(flood)
	if Expedition.has_mod(&"rewritten") and not (arena and boss_id in ["matron", "stationmaster"]):
		grid = EditGrid.new()
		var r := _floor_rect()
		grid.size = r.size
		grid.position = r.position
		grid.cols = maxi(2, int(r.size.x / 64.0))
		grid.rows = maxi(2, int(r.size.y / 64.0))
		add_child(grid)
	if Expedition.has_mod(&"lightless"):
		var light := PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 192
		g.height = 192
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		light.texture = g
		light.energy = 1.1
		light.name = "Lantern"
		player.add_child(light)


## The walkable part of the room (inside the walls), in pixels.
func _floor_rect() -> Rect2:
	var t := float(AssetLibrary.TILE_SIZE)
	var top := _rows.size()
	var bottom := 0
	var left := 999
	var right := 0
	for y in _rows.size():
		for x in _rows[y].length():
			if WALKABLE.contains(_rows[y][x]) and y < _rows.size() - 1:
				top = mini(top, y)
				bottom = maxi(bottom, y)
				left = mini(left, x)
				right = maxi(right, x)
	return Rect2(left * t, top * t, (right - left + 1) * t, (bottom - top + 1) * t)


func _free_cells() -> Array[Vector2]:
	var t := float(AssetLibrary.TILE_SIZE)
	var out: Array[Vector2] = []
	for y in range(1, _rows.size() - 1):
		for x in range(1, _rows[y].length() - 1):
			if not WALKABLE.contains(_rows[y][x]):
				continue
			var p := Vector2(x * t + t * 0.5, y * t + t * 0.5)
			if p.distance_to(_start) > 96.0 and p.distance_to(exit.position) > 32.0:
				out.append(p)
	return out


func enemy_count() -> int:
	var n := 2 + int(Expedition.run["room"])
	if Expedition.has_mod(&"crowded"):
		n += 2
	return n


func _spawn_echoes() -> void:
	var pool: Array = Expedition.site_def().get("enemies", ["hollow"])
	var cells := _free_cells()
	var n := enemy_count()
	var variants: Array[String] = []
	for i in n:
		variants.append(String(pool[_rng.randi() % pool.size()]))
	if Expedition.has_mod(&"wailing"):
		variants.append("wailer")
		variants.append("wailer")
	for v in variants:
		if cells.is_empty():
			break
		var e: EchoEnemy = ENEMY_SCENE.instantiate()
		e.variant = v
		e.position = cells.pop_at(_rng.randi() % cells.size())
		if Expedition.has_mod(&"lightless"):
			e.sight_range *= 0.6
		entities.add_child(e)


func _spawn_boss(room: Dictionary) -> void:
	var def := Expedition.boss_def()
	if def.is_empty():
		return
	var b: Node2D = load(String(def["scene"])).instantiate()
	b.set(&"boss_id", Expedition.REMATCH_ID)
	for k: String in def.get("set", {}):
		b.set(StringName(k), def["set"][k])
	b.position = _vec(room.get("boss", room["exit"]))
	b.name = "Rematch"
	entities.add_child(b)
	boss = b
	var arena := BossArena.new()
	arena.engaged_flag = StringName("boss.%s.engaged" % Expedition.REMATCH_ID)
	arena.area_size = _floor_rect().size * Vector2(0.9, 0.55)
	arena.position = b.position
	add_child(arena)
	arena.boss_path = arena.get_path_to(b)


func is_clear() -> bool:
	for e in get_tree().get_nodes_in_group(&"echo_enemy"):
		if is_ancestor_of(e):
			return false
	if Expedition.is_arena():
		return GameState.has_flag(StringName("boss.%s.defeated" % Expedition.REMATCH_ID))
	return true


func _process(delta: float) -> void:
	if not Expedition.active():
		return
	if not _open and is_clear():
		_open = true
		exit.enabled = true
		if flood != null:
			flood.set_target(0.0, 0.5)
		if grid != null:
			grid.clear_all()
		Sfx.play(&"bell", 0.0, -4.0)
		EventHub.toast_requested.emit(tr("EXP_TOAST_OPEN"))
		return
	if _open:
		return
	_timer += delta
	if grid != null and _timer >= GRID_EVERY:
		_timer = 0.0
		var cells: Array[Vector2i] = []
		for i in 2 + grid.cols * grid.rows / 6:
			cells.append(Vector2i(_rng.randi() % grid.cols, _rng.randi() % grid.rows))
		grid.mark(cells, 1.1, 1.8)
	_flood_t += delta
	if flood != null and _flood_t >= FLOOD_EVERY:
		_flood_t = 0.0
		_flood_high = not _flood_high
		flood.set_target(0.6 if _flood_high else 0.25, 0.25)
