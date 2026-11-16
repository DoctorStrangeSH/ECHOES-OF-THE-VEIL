class_name Bolt
extends Node2D
## A projectile from a staff or sling: flies straight, hits the first echo
## (or every echo on its way if it pierces), fades at the end of its range.

var dir := Vector2.RIGHT
var speed := 230.0
var range_left := 140.0
var damage := 1
var pierce := false
var color := Color(0.75, 0.9, 1.0)
var _hitbox: Hitbox
var _hit: Array = []


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.team = &"player"
	_hitbox.damage = damage
	_hitbox.knockback = 90.0
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	s.shape = c
	_hitbox.add_child(s)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += dir * step
	range_left -= step
	for area in _hitbox.get_overlapping_areas():
		var hb := area as Hurtbox
		if hb == null or hb.team == &"player" or _hit.has(hb):
			continue
		if hb.receive(damage, global_position, 90.0):
			_hit.append(hb)
			Sfx.play(&"hit", 0.05, -6.0)
			if not pierce:
				queue_free()
				return
	if range_left <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, -8), 3.0, color)
	draw_circle(Vector2(0, -8) - dir * 4.0, 2.0, Color(color, 0.5))
	draw_circle(Vector2(0, -8) - dir * 8.0, 1.2, Color(color, 0.25))
