class_name RepairMinigame
extends CanvasLayer
## Repair minigame: a needle sweeps across a gauge; press Interact (or Strike)
## while it is inside the green zone. Hits needed = difficulty + 1; three
## misses and the repair fails (no materials are used). Zone width grows with
## the repair level; a repair kit (if carried) widens it once and is used up.

signal finished(success: bool)

var job_id: StringName = &""
var _zone_center := 0.5
var _zone_width := 0.25
var _needle := 0.0
var _dir := 1.0
var _speed := 0.9
var _hits := 0
var _needed := 2
var _misses := 0
var _flash := 0.0
var _flash_color := Color.WHITE
var _active := false
var _used_kit := false
var _root: Control


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_gauge)
	add_child(_root)
	visible = false


func start(id: StringName) -> void:
	var d := Livelihood.job(id)
	if d.is_empty():
		return
	if not Inventory.has(&"scrap", int(d.get("scrap", 0))):
		EventHub.toast_requested.emit(tr("TOAST_NEED_SCRAP") % int(d.get("scrap", 0)))
		return
	job_id = id
	var difficulty := int(d.get("difficulty", 1))
	_needed = difficulty + 1
	_speed = 0.7 + 0.35 * difficulty
	_zone_width = Livelihood.repair_zone(difficulty)
	_used_kit = false
	if Inventory.has(&"repair_kit"):
		Inventory.remove(&"repair_kit")
		_zone_width += float(Inventory.def(&"repair_kit").get("use", {}).get("repair_bonus", 0.08))
		_used_kit = true
	_hits = 0
	_misses = 0
	_needle = 0.0
	_new_zone()
	_active = true
	visible = true
	get_tree().paused = true
	Sfx.play(&"ui_open")


func _process(delta: float) -> void:
	if not _active:
		return
	_needle += _dir * _speed * delta
	if _needle >= 1.0 or _needle <= 0.0:
		_needle = clampf(_needle, 0.0, 1.0)
		_dir = -_dir
	_flash = maxf(0.0, _flash - delta)
	_root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_end(false)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()
		_try()


func _try() -> void:
	if absf(_needle - _zone_center) <= _zone_width / 2.0:
		_hits += 1
		_flash = 0.15
		_flash_color = Color(0.5, 1.0, 0.6)
		Sfx.play(&"hit", 0.05)
		if _hits >= _needed:
			_end(true)
		else:
			_new_zone()
			_speed *= 1.12
	else:
		_misses += 1
		_flash = 0.15
		_flash_color = Color(1.0, 0.4, 0.4)
		Sfx.play(&"hurt", 0.05, -6.0)
		if _misses >= 3:
			_end(false)


func _new_zone() -> void:
	_zone_center = randf_range(_zone_width / 2.0 + 0.05, 1.0 - _zone_width / 2.0 - 0.05)


func _end(success: bool) -> void:
	_active = false
	visible = false
	get_tree().paused = false
	if success:
		Sfx.play(&"attune")
		Livelihood.complete(job_id)
	else:
		EventHub.toast_requested.emit(tr("TOAST_REPAIR_FAILED"))
	finished.emit(success)


func _draw_gauge() -> void:
	var vp := _root.get_viewport_rect().size
	var w := 220.0
	var x := (vp.x - w) / 2.0
	var y := vp.y / 2.0
	var font := _root.get_theme_default_font()
	_root.draw_rect(Rect2(x - 12, y - 34, w + 24, 64), Color(0.06, 0.06, 0.1, 0.92))
	_root.draw_rect(Rect2(x - 12, y - 34, w + 24, 64), UiTheme.PANEL_EDGE, false, 1.0)
	var title := tr(Livelihood.job(job_id).get("name", ""))
	_root.draw_string(font, Vector2(x, y - 20), title, HORIZONTAL_ALIGNMENT_CENTER, w, 9, UiTheme.HUD_ACCENT)
	_root.draw_rect(Rect2(x, y - 6, w, 12), Color(0.15, 0.15, 0.2))
	var zx := x + (_zone_center - _zone_width / 2.0) * w
	_root.draw_rect(Rect2(zx, y - 6, _zone_width * w, 12), Color(0.3, 0.8, 0.45, 0.85))
	var nx := x + _needle * w
	_root.draw_rect(Rect2(nx - 1, y - 10, 3, 20), Color.WHITE)
	if _flash > 0.0:
		_root.draw_rect(Rect2(x, y - 6, w, 12), Color(_flash_color, _flash * 3.0), false, 2.0)
	var status := tr("REPAIR_STATUS") % [_hits, _needed, 3 - _misses]
	if _used_kit:
		status += "  " + tr("REPAIR_KIT_USED")
	_root.draw_string(font, Vector2(x, y + 22), status, HORIZONTAL_ALIGNMENT_CENTER, w, 8, UiTheme.HUD_DIM)
