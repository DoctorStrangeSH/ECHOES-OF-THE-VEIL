class_name CombatFx
extends RefCounted
## Shared "game feel" helpers: hit-stop, floating damage numbers, afterimages.

static var _hitstop_depth := 0


## Freezes the game briefly on impact. Overlapping calls extend, never stack.
static func hitstop(duration: float = 0.05) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or duration <= 0.0:
		return
	_hitstop_depth += 1
	Engine.time_scale = 0.05
	await tree.create_timer(duration, true, false, true).timeout
	_hitstop_depth -= 1
	if _hitstop_depth <= 0:
		_hitstop_depth = 0
		Engine.time_scale = 1.0


## Rising number above a hit. `parent` should be the location (world space).
static func damage_number(parent: Node, at: Vector2, amount: int, color: Color = Color(1, 0.95, 0.8)) -> void:
	if parent == null:
		return
	var l := Label.new()
	l.text = str(amount)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 100
	l.position = at + Vector2(randf_range(-4, 4), -30)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 12.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


## A fading copy of every sprite layer of `source` (dodge trails).
static func afterimage(source: Node2D, parent: Node, tint: Color = Color(0.6, 0.85, 1.0, 0.55)) -> void:
	if source == null or parent == null:
		return
	var ghost := Node2D.new()
	ghost.global_position = source.global_position
	ghost.z_index = -1
	for child in source.get_children():
		var s := child as Sprite2D
		if s == null:
			continue
		var c := Sprite2D.new()
		c.texture = s.texture
		c.centered = s.centered
		c.offset = s.offset
		c.region_enabled = s.region_enabled
		c.region_rect = s.region_rect
		ghost.add_child(c)
	ghost.modulate = tint
	parent.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)
