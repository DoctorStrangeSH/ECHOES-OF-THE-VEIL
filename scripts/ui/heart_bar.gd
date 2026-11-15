class_name HeartBar
extends Control
## Draws pixel hearts for the player's health. Hidden when max_health is 0
## (outside Veil locations).

const HEART := [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]
const PIXEL := 1.0
const GAP := 2.0

var health := 0
var max_health := 0


func set_health(h: int, m: int) -> void:
	health = h
	max_health = m
	visible = m > 0
	custom_minimum_size = Vector2(m * (7 + GAP), 6)
	queue_redraw()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for i in max_health:
		var full := i < health
		var color := Color(0.9, 0.25, 0.3) if full else Color(0.25, 0.22, 0.28)
		var ox := i * (7 + GAP)
		draw_rect(Rect2(ox - 1, -1, 9, 8), Color(0, 0, 0, 0.6))
		for y in HEART.size():
			var row: String = HEART[y]
			for x in row.length():
				if row[x] == "X":
					draw_rect(Rect2(ox + x * PIXEL, y * PIXEL, PIXEL, PIXEL), color)
