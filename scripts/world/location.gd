class_name Location
extends Node2D
## Root of every playable place. Expected children:
##   Ground (TileMapLayer)        - floor; its used rect defines bounds/camera
##   Entities (Node2D, y-sorted)  - props, NPCs, interactables; the player goes here
##   SpawnPoints (Node2D)         - SpawnPoint markers
## Spawns the player at GameState's pending position or spawn ID and closes
## the map edges with invisible walls.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@export var location_id: StringName = &""
@export var name_key: String = ""
## Extra tiles of camera room beyond the ground (useful for small rooms).
@export var camera_margin_tiles: int = 0

var player: Player

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities


func _ready() -> void:
	entities.y_sort_enabled = true
	var bounds := _bounds_px()
	_add_edge_walls(bounds)
	player = PLAYER_SCENE.instantiate()
	entities.add_child(player)
	var margin := camera_margin_tiles * AssetLibrary.TILE_SIZE
	player.set_camera_limits(bounds.grow(margin))
	_place_player()
	if not name_key.is_empty():
		EventHub.toast_requested.emit(tr(name_key))


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
