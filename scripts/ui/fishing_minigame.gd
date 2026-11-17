class_name FishingMinigame
extends CanvasLayer
## Fishing (R7a), opened by a "fish:<water>" spot with a rod in the bag.
## Cast (E), wait for the float to dip, strike (E) before the fish lets go,
## then reel: hold E to lift the green band, let go and it sinks; keep the
## fish inside it until the line is full. What bites depends on the water,
## the hour, the weather and sometimes the story (data/fishing/fish.json).
## Every cast takes ten minutes of the day.

const FISH_PATH := "res://data/fishing/fish.json"
const BAND := 0.24
const STRIKE_WINDOW := 0.9

static var _fish: Dictionary = {}

var water := "sea"
var phase := "cast"  # cast, wait, bite, reel, result
var _t := 0.0
var _fish_id := ""
var _fish_pos := 0.5
var _fish_vel := 0.0
var _band_pos := 0.2
var _band_vel := 0.0
var _progress := 0.3
var _last := ""
var _hold := false
var _rng := RandomNumberGenerator.new()
var _root: Control
var _active := false


static func fish_defs() -> Dictionary:
	if _fish.is_empty():
		var d: Variant = DataFiles.read_json(FISH_PATH)
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_"):
					_fish[k] = d[k]
	return _fish


## What could bite here, now (ids with weights).
static func candidates(water_id: String) -> Dictionary:
	var out := {}
	for id: String in fish_defs():
		var f: Dictionary = fish_defs()[id]
		if not (f.get("where", []) as Array).has(water_id):
			continue
		var when: Array = f.get("when", [])
		if not when.is_empty() and not when.has(WorldClock.get_period()):
			continue
		if f.has("weather") and WorldClock.weather != String(f["weather"]):
			continue
		if not StoryRules.evaluate(f.get("if", {})):
			continue
		out[id] = float(f.get("weight", 1.0))
	return out


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	_root.draw.connect(_draw_game)
	add_child(_root)
	visible = false


func is_open() -> bool:
	return _active


func start(water_id: String) -> void:
	if not Inventory.has(&"fishing_rod"):
		EventHub.toast_requested.emit(tr("FISH_NO_ROD"))
		return
	water = water_id
	_rng.seed = hash([WorldClock.day, WorldClock.minute_of_day, water_id])
	phase = "cast"
	_last = ""
	_active = true
	visible = true
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action(&"interact"):
		get_viewport().set_input_as_handled()
		_hold = event.is_pressed()
		if event.is_pressed() and not event.is_echo():
			_press()


func _press() -> void:
	match phase:
		"cast", "result":
			_cast()
		"wait":
			_last = tr("FISH_TOO_EARLY")
			phase = "result"
			_t = 1.2
		"bite":
			_start_reel()


func _cast() -> void:
	WorldClock.advance_minutes(10)
	Sfx.play(&"swing", 0.1, -6.0)
	phase = "wait"
	_t = _rng.randf_range(1.5, 4.5)
	_last = ""


func _start_reel() -> void:
	var pool := candidates(water)
	if pool.is_empty():
		_last = tr("FISH_NOTHING")
		phase = "result"
		_t = 1.5
		return
	var total := 0.0
	for k: String in pool:
		total += pool[k]
	var roll := _rng.randf() * total
	for k: String in pool:
		roll -= pool[k]
		if roll <= 0.0:
			_fish_id = k
			break
	if _fish_id == "":
		_fish_id = pool.keys()[0]
	phase = "reel"
	_progress = 0.3
	_fish_pos = 0.5
	_fish_vel = 0.0
	_band_pos = 0.35
	_band_vel = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	match phase:
		"wait":
			_t -= delta
			if _t <= 0.0:
				phase = "bite"
				_t = STRIKE_WINDOW
				Sfx.play(&"bell", 0.0, -10.0)
		"bite":
			_t -= delta
			if _t <= 0.0:
				_last = tr("FISH_LET_GO")
				phase = "result"
				_t = 1.2
		"reel":
			_reel(delta)
		"result":
			_t -= delta
	_root.queue_redraw()


func _reel(delta: float) -> void:
	var f: Dictionary = fish_defs()[_fish_id]
	var diff := float(f.get("difficulty", 2))
	# The fish darts about; harder fish dart more often and further.
	if _rng.randf() < delta * (0.6 + diff * 0.45):
		_fish_vel = _rng.randf_range(-1.0, 1.0) * (0.25 + diff * 0.12)
	_fish_pos = clampf(_fish_pos + _fish_vel * delta, 0.0, 1.0)
	if _fish_pos <= 0.0 or _fish_pos >= 1.0:
		_fish_vel = -_fish_vel
	_band_vel += (1.6 if _hold else -1.3) * delta
	_band_vel = clampf(_band_vel, -0.9, 0.9)
	_band_pos = clampf(_band_pos + _band_vel * delta, 0.0, 1.0 - BAND)
	if _band_pos <= 0.0 or _band_pos >= 1.0 - BAND:
		_band_vel *= -0.3
	var inside := _fish_pos >= _band_pos and _fish_pos <= _band_pos + BAND
	_progress += (0.32 if inside else -0.22 - diff * 0.02) * delta
	if _progress >= 1.0:
		_land()
	elif _progress <= 0.0:
		_last = tr("FISH_GOT_AWAY") % tr(String(f["name"]))
		phase = "result"
		_t = 1.5


func _land() -> void:
	var f: Dictionary = fish_defs()[_fish_id]
	var first := not GameState.has_flag(StringName("fish.caught.%s" % _fish_id))
	GameState.set_flag(StringName("fish.caught.%s" % _fish_id))
	Inventory.add(StringName(_fish_id), 1, false)
	Progression.add_xp(2 + int(f.get("difficulty", 1)) * 2)
	Sfx.play(&"coin", 0.0, -4.0)
	_last = tr("FISH_CAUGHT") % tr(String(f["name"]))
	if first:
		_last += " " + tr("FISH_NEW_KIND") % [caught_kinds(), fish_defs().size()]
	phase = "result"
	_t = 2.0


static func caught_kinds() -> int:
	var n := 0
	for id: String in fish_defs():
		if GameState.has_flag(StringName("fish.caught.%s" % id)):
			n += 1
	return n


func close() -> void:
	_active = false
	visible = false
	_hold = false
	get_tree().paused = false


func _draw_game() -> void:
	var vp := _root.get_viewport_rect().size
	var panel := Rect2(vp.x * 0.5 - 150, vp.y - 128, 300, 116)
	_root.draw_rect(panel, Color(0.06, 0.06, 0.09, 0.92))
	_root.draw_rect(panel, UiTheme.HUD_ACCENT, false, 1.0)
	var font := _root.get_theme_default_font()
	_root.draw_string(font, panel.position + Vector2(10, 15), tr("FISH_TITLE_" + water.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.HUD_ACCENT)
	_root.draw_string(font, panel.position + Vector2(190, 15), tr("FISH_KINDS") % [caught_kinds(), fish_defs().size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.HUD_DIM)
	var water_r := Rect2(panel.position + Vector2(10, 24), Vector2(280, 54))
	_root.draw_rect(water_r, Color(0.16, 0.32, 0.45) if water != "lake" else Color(0.14, 0.3, 0.32))
	for i in 5:
		var y := water_r.position.y + 8 + i * 10
		var x := water_r.position.x + fmod(i * 47.0 + Time.get_ticks_msec() * 0.01, 260.0)
		_root.draw_line(Vector2(x, y), Vector2(x + 10, y), Color(0.6, 0.8, 0.9, 0.35), 1.0)
	if phase == "reel":
		var bar := Rect2(water_r.position + Vector2(20, 18), Vector2(240, 14))
		_root.draw_rect(bar, Color(0.05, 0.1, 0.15))
		_root.draw_rect(Rect2(bar.position + Vector2(bar.size.x * _band_pos, 0), Vector2(bar.size.x * BAND, bar.size.y)), Color(0.35, 0.8, 0.4, 0.75))
		var fx := bar.position.x + bar.size.x * _fish_pos
		var col := Color.html(String(fish_defs()[_fish_id].get("color", "#c0d0e0")))
		_root.draw_colored_polygon(PackedVector2Array([Vector2(fx - 6, bar.get_center().y), Vector2(fx + 2, bar.position.y + 2), Vector2(fx + 2, bar.end.y - 2)]), col)
		_root.draw_circle(Vector2(fx + 3, bar.get_center().y), 4.0, col)
		var prog := Rect2(bar.position + Vector2(0, 20), Vector2(bar.size.x * _progress, 4))
		_root.draw_rect(Rect2(bar.position + Vector2(0, 20), Vector2(bar.size.x, 4)), Color(0.2, 0.2, 0.25))
		_root.draw_rect(prog, Color(1.0, 0.85, 0.3))
	else:
		var bob := water_r.get_center() + Vector2(0, -4)
		if phase == "bite":
			bob.y += 5.0
			_root.draw_arc(bob, 9.0, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
		elif phase == "wait":
			bob.y += sin(Time.get_ticks_msec() * 0.004) * 1.5
		if phase != "cast":
			_root.draw_line(water_r.position + Vector2(280, -10), bob, Color(0.9, 0.9, 0.9, 0.5), 1.0)
			_root.draw_circle(bob, 3.0, Color(0.95, 0.3, 0.25))
			_root.draw_circle(bob + Vector2(0, -2), 1.5, Color.WHITE)
	var hint := ""
	match phase:
		"cast":
			hint = tr("FISH_HINT_CAST")
		"wait":
			hint = tr("FISH_HINT_WAIT")
		"bite":
			hint = tr("FISH_HINT_BITE")
		"reel":
			hint = tr("FISH_HINT_REEL")
		"result":
			hint = _last + "  " + tr("FISH_HINT_AGAIN")
	_root.draw_string(font, panel.position + Vector2(10, 92), hint, HORIZONTAL_ALIGNMENT_LEFT, 280, 8, UiTheme.HUD_INK)
	_root.draw_string(font, panel.position + Vector2(10, 108), tr("FISH_HINT_LEAVE"), HORIZONTAL_ALIGNMENT_LEFT, 280, 7, UiTheme.HUD_DIM)
