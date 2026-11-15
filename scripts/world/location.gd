class_name Location
extends Node2D
## Root of every playable place. Expected children:
##   Ground (TileMapLayer)        - floor; its used rect defines bounds/camera
##   FloorDecor (Node2D)          - rugs and other things always under actors
##   Entities (Node2D, y-sorted)  - props, NPCs, interactables; the player goes here
##   SpawnPoints (Node2D)         - SpawnPoint markers
##   NpcAnchors (Node2D, optional)- NpcAnchor markers used by NPC schedules
## Spawns the player, closes the map edges, places scheduled NPCs, tints the
## scene for the time of day and optionally starts an entry dialogue.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npcs/npc.tscn")

## Outdoor light by hour (interpolated). Interiors use a softer version.
const TINT_KEYS := [
	[0, Color(0.42, 0.45, 0.68)], [5, Color(0.48, 0.5, 0.72)], [7, Color(0.95, 0.88, 0.85)],
	[10, Color(1, 1, 1)], [16, Color(1, 0.98, 0.95)], [19, Color(0.98, 0.8, 0.72)],
	[21, Color(0.6, 0.58, 0.8)], [24, Color(0.42, 0.45, 0.68)],
]

@export var location_id: StringName = &""
@export var name_key: String = ""
@export var outdoors: bool = true
## Enables attacking and enemy encounters (Veil locations).
@export var combat_enabled: bool = false
## If set, ignores the clock and uses this tint (e.g. the uncanny Veil).
@export var fixed_tint: Color = Color(0, 0, 0, 0)
## Extra tiles of camera room beyond the ground (useful for small rooms).
@export var camera_margin_tiles: int = 0
## Dialogue started on entering when `enter_condition` holds (e.g. an intro).
@export var enter_dialogue_id: StringName = &""
@export var enter_condition: Dictionary = {}

var player: Player
var _npcs: Dictionary = {}  # npc_id -> Npc
var _follower: Npc = null
var _anchors: Dictionary = {}  # anchor_id -> NpcAnchor
var _tint: CanvasModulate
var _npc_refresh_pending := false

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities


func _ready() -> void:
	entities.y_sort_enabled = true
	var bounds := _bounds_px()
	_add_edge_walls(bounds)
	_tint = CanvasModulate.new()
	add_child(_tint)
	_update_tint()
	for node in get_tree().get_nodes_in_group(&"npc_anchor"):
		if is_ancestor_of(node):
			_anchors[(node as NpcAnchor).anchor_id] = node
	player = PLAYER_SCENE.instantiate()
	player.combat_enabled = combat_enabled
	entities.add_child(player)
	var margin := camera_margin_tiles * AssetLibrary.TILE_SIZE
	player.set_camera_limits(bounds.grow(margin))
	_place_player()
	_refresh_npcs(false)
	_refresh_follower()
	_place_satchel()
	Incidents.populate(self)
	Party.companion_changed.connect(_on_companion_changed)
	WorldClock.time_changed.connect(_on_time_changed)
	WorldClock.period_changed.connect(_on_story_changed)
	EventHub.flag_changed.connect(_on_flag_changed)
	Journal.case_changed.connect(_on_story_changed)
	DialogueService.dialogue_ended.connect(_on_dialogue_ended)
	if not name_key.is_empty():
		EventHub.toast_requested.emit(tr(name_key))
	if enter_dialogue_id != &"" and StoryRules.evaluate(enter_condition):
		_start_enter_dialogue.call_deferred()


func _start_enter_dialogue() -> void:
	if SceneFlow.is_transitioning:
		await SceneFlow.transition_finished
	DialogueService.start(enter_dialogue_id)


func find_spawn(spawn_id: StringName) -> SpawnPoint:
	var first: SpawnPoint = null
	for node in get_tree().get_nodes_in_group(&"spawn_point"):
		var sp := node as SpawnPoint
		if sp == null or not is_ancestor_of(sp):
			continue
		if first == null:
			first = sp
		if sp.spawn_id == spawn_id:
			return sp
	if first != null:
		push_warning("Location %s: spawn '%s' not found, using '%s'" % [location_id, spawn_id, first.spawn_id])
	return first


# --- NPC schedules -------------------------------------------------------------

func _place_satchel() -> void:
	var s := GameState.satchel
	if s.is_empty() or StringName(s.get("scene", "")) != location_id:
		return
	var bag := Satchel.new()
	bag.position = Vector2(float(s["x"]), float(s["y"]))
	entities.add_child(bag)


func _refresh_follower() -> void:
	var id := Party.companion
	if _follower != null and is_instance_valid(_follower) and _follower.npc_id != id:
		_follower.fade_out_and_free()
		_follower = null
	if id == &"" or (_follower != null and is_instance_valid(_follower)):
		return
	if Party.def_of(id).get("stays_in", []).has(String(location_id)):
		return
	_follower = NPC_SCENE.instantiate()
	entities.add_child(_follower)
	_follower.npc_id = id
	(Follower.new()).setup(_follower, Party.def_of(id))
	_follower.fade_in()


func _refresh_npcs(animate: bool = true) -> void:
	for id: StringName in NpcRegistry.defs():
		var entry := NpcRegistry.resolve(id)
		var anchor_id := StringName(entry.get("anchor", ""))
		var here := not entry.is_empty() and StringName(entry.get("scene", "")) == location_id
		if here and not _anchors.has(anchor_id):
			push_warning("Location %s: NPC %s wants missing anchor '%s'" % [location_id, id, anchor_id])
			here = false
		var found: Variant = _npcs.get(id)
		var existing: Npc = found as Npc if is_instance_valid(found) else null
		if existing != null and (not here or existing.anchor_id != anchor_id):
			_npcs.erase(id)
			if animate:
				existing.fade_out_and_free()
			else:
				existing.queue_free()
			existing = null
		if here and existing == null:
			var npc: Npc = NPC_SCENE.instantiate()
			npc.anchor_id = anchor_id
			npc.position = (_anchors[anchor_id] as Node2D).global_position - entities.global_position
			entities.add_child(npc)
			npc.npc_id = id
			npc.facing = NpcRegistry.facing_of(entry) as LayeredCharacterSprite.Dir
			_npcs[id] = npc
			if animate:
				npc.fade_in()


## Story changes during a conversation are applied when it ends, so NPCs do
## not vanish mid-sentence.
func _on_companion_changed(_id: StringName) -> void:
	_refresh_npcs(true)
	_refresh_follower()


func _on_story_changed(_arg: Variant = null) -> void:
	if DialogueService.is_active:
		_npc_refresh_pending = true
	else:
		_refresh_npcs(true)


func _on_dialogue_ended(_id: StringName) -> void:
	if _npc_refresh_pending:
		_npc_refresh_pending = false
		_refresh_npcs(true)


func _on_flag_changed(_id: StringName, _value: Variant) -> void:
	_on_story_changed()


func _on_time_changed(_minute: int) -> void:
	_update_tint()


# --- Presentation --------------------------------------------------------------

func _update_tint() -> void:
	if fixed_tint.a > 0.0:
		_tint.color = fixed_tint
		return
	var hour := WorldClock.minute_of_day / 60.0
	var c: Color = TINT_KEYS[0][1]
	for i in range(TINT_KEYS.size() - 1):
		var a: Array = TINT_KEYS[i]
		var b: Array = TINT_KEYS[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			c = (a[1] as Color).lerp(b[1], (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
			break
	if not outdoors:
		c = c.lerp(Color(1, 0.96, 0.9), 0.65)  # lamps are on indoors
	elif WorldClock.weather == "rain":
		c = c * Color(0.82, 0.86, 0.95)
	_tint.color = c


func _place_player() -> void:
	if GameState.pending_position is Vector2:
		player.place(GameState.pending_position, GameState.pending_facing)
		GameState.pending_position = null
		return
	var sp := find_spawn(GameState.current_spawn_id)
	if sp != null:
		player.place(sp.global_position, sp.facing)
	else:
		push_error("Location %s has no spawn points" % location_id)
		player.place(Vector2(_bounds_px().get_center()), Vector2.DOWN)


func _bounds_px() -> Rect2i:
	var used := ground.get_used_rect()
	var t := AssetLibrary.TILE_SIZE
	return Rect2i(used.position * t, used.size * t)


func _add_edge_walls(bounds: Rect2i) -> void:
	var body := StaticBody2D.new()
	body.name = "EdgeWalls"
	body.collision_layer = 1
	add_child(body)
	var thickness := 32.0
	var r := Rect2(bounds)
	var walls := [
		Rect2(r.position.x - thickness, r.position.y - thickness, r.size.x + thickness * 2, thickness),
		Rect2(r.position.x - thickness, r.end.y, r.size.x + thickness * 2, thickness),
		Rect2(r.position.x - thickness, r.position.y, thickness, r.size.y),
		Rect2(r.end.x, r.position.y, thickness, r.size.y),
	]
	for w: Rect2 in walls:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w.size
		shape.shape = rect
		shape.position = w.get_center()
		body.add_child(shape)
