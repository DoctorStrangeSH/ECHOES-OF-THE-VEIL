class_name SportMinigame
extends CanvasLayer
## Park sports (R2): five attempts, press Interact at the right moment.
##
## Basketball: a power needle sweeps a bar; land it in the green band. Each
## basket narrows the band a little (a streak gets harder).
## Football (penalties): first the aim sweeps across the goal (left, centre,
## right); lock it. Then the power needle: too strong and it flies over the
## bar. The keeper guesses a side; a shot into the side he dives to is saved.
##
## Best scores live in flags (sport.<game>.best); a good round (4+) pays a
## little, once a day.

signal finished(game: String, score: int)

const ATTEMPTS := 5
const REWARD := 6
const GAMES := ["basketball", "football"]

var game := "basketball"
var score := 0
var attempt := 0
var phase := "power"  # football: "aim" then "power"; then "result"
var _needle := 0.0
var _dir := 1.0
var _speed := 1.1
var _band_c := 0.62
var _band_w := 0.22
var _aim := 0.5
var _aim_locked := -1
var _keeper := 1
var _result_t := 0.0
var _last := ""
var _rng := RandomNumberGenerator.new()
var _root: Control
var _active := false


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


func start(which: String) -> void:
	if not which in GAMES:
		return
	game = which
	score = 0
	attempt = 0
	_band_w = 0.24
	_rng.seed = hash([WorldClock.day, WorldClock.minute_of_day, which])
	_next_attempt()
	_active = true
	visible = true
	get_tree().paused = true


func is_open() -> bool:
	return _active


func _next_attempt() -> void:
	_needle = 0.0
	_dir = 1.0
	_speed = 1.0 + 0.12 * attempt
	_band_c = _rng.randf_range(0.5, 0.78)
	phase = "aim" if game == "football" else "power"
	_aim = 0.0
	_aim_locked = -1


func _process(delta: float) -> void:
	if not _active:
		return
	if phase == "result":
		_result_t -= delta
		if _result_t <= 0.0:
			attempt += 1
			if attempt >= ATTEMPTS:
				_finish()
				return
			_next_attempt()
	elif phase == "aim":
		_aim += _dir * delta * 0.9
		if _aim > 1.0 or _aim < 0.0:
			_dir = -_dir
			_aim = clampf(_aim, 0.0, 1.0)
	else:
		_needle += _dir * delta * _speed
		if _needle > 1.0 or _needle < 0.0:
			_dir = -_dir
			_needle = clampf(_needle, 0.0, 1.0)
	_root.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	if not (event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack") or event.is_action_pressed(&"dodge")):
		return
	get_viewport().set_input_as_handled()
	match phase:
		"aim":
			_aim_locked = clampi(int(_aim * 3.0), 0, 2)
			phase = "power"
			_needle = 0.0
			_dir = 1.0
		"power":
			_shoot()


func _shoot() -> void:
	var in_band := absf(_needle - _band_c) <= _band_w * 0.5
	var good := false
	if game == "basketball":
		good = in_band
		_last = tr("SPORT_BASKET") if good else (tr("SPORT_SHORT") if _needle < _band_c else tr("SPORT_LONG"))
		if good:
			_band_w = maxf(0.1, _band_w - 0.025)
	else:
		# The keeper reads hesitant shots: weak ones go to where he is.
		_keeper = _rng.randi_range(0, 2)
		if _needle > _band_c + _band_w * 0.5:
			_last = tr("SPORT_OVER")
		elif _keeper == _aim_locked and not (in_band and _rng.randf() < 0.25):
			_last = tr("SPORT_SAVED")
		else:
			good = true
			_last = tr("SPORT_GOAL")
	if good:
		score += 1
		Sfx.play(&"coin", 0.0, -4.0)
	else:
		Sfx.play(&"hit", 0.0, -10.0)
	phase = "result"
	_result_t = 1.0


func _finish() -> void:
	_active = false
	visible = false
	get_tree().paused = false
	var best_flag := StringName("sport.%s.best" % game)
	var best := int(GameState.get_flag(best_flag, 0))
	if score > best:
		GameState.set_flag(best_flag, score)
	var paid_flag := StringName("sport.%s.paid_day" % game)
	var line := tr("SPORT_DONE") % [score, ATTEMPTS]
	if score >= 4 and int(GameState.get_flag(paid_flag, -1)) != WorldClock.day:
		GameState.set_flag(paid_flag, WorldClock.day)
		Inventory.money += REWARD
		line += " " + tr("SPORT_PAID") % REWARD
	if score > best and best > 0:
		line += " " + tr("SPORT_RECORD")
	Progression.add_xp(score * 2)
	EventHub.toast_requested.emit(line)
	finished.emit(game, score)


func _draw_game() -> void:
	var vp := _root.get_viewport_rect().size
	var panel := Rect2(vp.x * 0.5 - 150, vp.y * 0.5 - 70, 300, 140)
	_root.draw_rect(panel, Color(0.06, 0.06, 0.09, 0.92))
	_root.draw_rect(panel, UiTheme.ACCENT, false, 1.0)
	var font := _root.get_theme_default_font()
	var title := tr("SPORT_TITLE_" + game.to_upper()) + "   " + tr("SPORT_SCORE") % [score, attempt + (0 if phase == "result" else 1), ATTEMPTS]
	_root.draw_string(font, panel.position + Vector2(10, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.ACCENT)
	var hint := tr("SPORT_HINT_AIM") if phase == "aim" else tr("SPORT_HINT_POWER")
	if phase == "result":
		hint = _last
	_root.draw_string(font, panel.position + Vector2(10, 132), hint, HORIZONTAL_ALIGNMENT_LEFT, 280, 8, UiTheme.INK)
	if game == "football":
		var goal := Rect2(panel.position + Vector2(60, 28), Vector2(180, 44))
		_root.draw_rect(goal, Color(0.15, 0.4, 0.2))
		_root.draw_rect(goal, Color.WHITE, false, 2.0)
		for i: int in [1, 2]:
			var x := goal.position.x + goal.size.x * i / 3.0
			_root.draw_line(Vector2(x, goal.position.y), Vector2(x, goal.end.y), Color(1, 1, 1, 0.25), 1.0)
		var kx := goal.position.x + goal.size.x * ((_keeper if phase == "result" else 1) + 0.5) / 3.0
		_root.draw_rect(Rect2(kx - 6, goal.end.y - 22, 12, 22), Color(0.9, 0.7, 0.2))
		var ax := goal.position.x + goal.size.x * (_aim if _aim_locked < 0 else (_aim_locked + 0.5) / 3.0)
		_root.draw_circle(Vector2(ax, goal.position.y + 14), 4.0, Color.WHITE)
	else:
		var hoop := panel.position + Vector2(150, 40)
		_root.draw_rect(Rect2(hoop - Vector2(18, 16), Vector2(36, 22)), Color(0.9, 0.9, 0.95), false, 2.0)
		_root.draw_line(hoop + Vector2(-10, 8), hoop + Vector2(10, 8), Color(0.95, 0.35, 0.2), 2.0)
		var ball_y := lerpf(118.0, 48.0, _needle) if phase != "result" else 48.0
		_root.draw_circle(panel.position + Vector2(150, ball_y), 5.0, Color(0.95, 0.5, 0.15))
	if phase != "aim":
		var bar := Rect2(panel.position + Vector2(20, 96), Vector2(260, 12))
		_root.draw_rect(bar, Color(0.2, 0.2, 0.25))
		var bw := bar.size.x * _band_w
		_root.draw_rect(Rect2(bar.position.x + bar.size.x * _band_c - bw * 0.5, bar.position.y, bw, bar.size.y), Color(0.3, 0.75, 0.35))
		var nx := bar.position.x + bar.size.x * _needle
		_root.draw_line(Vector2(nx, bar.position.y - 3), Vector2(nx, bar.end.y + 3), Color.WHITE, 2.0)
