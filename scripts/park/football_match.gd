class_name FootballMatch
extends Node2D
## A real kickabout on the Quay Gardens pitch (R2b): three outfield players and
## a keeper a side, played in the world, no separate screen.
##
## Your side (you + two) defends the bottom goal and attacks the top one.
## Run into the ball to dribble; press Attack (J / LMB) to shoot in the
## direction you're moving. Bots: the nearest of each side chases the ball,
## the others hold a shape that follows play; keepers track the ball along
## their line and clear it. First to three, or the most goals when the
## whistle goes after three minutes.

signal ended(our: int, their: int)

const FIELD := Rect2(512, 174, 176, 262)  # inside the painted lines
const GOAL_HALF := 22.0                   # half the goal mouth
const CENTER := Vector2(600, 305)
const WIN := 3
const TIME := 180.0
const KICK := 230.0
const DRIBBLE := 70.0
const SHOT_RANGE := 95.0
const KICKOFF_PAUSE := 1.5
const FRICTION := 160.0
const BALL_R := 4.0
const REWARD := 8
const BALL_TEX := "modern_exteriors/Modern_Exteriors_16x16/Modern_Exteriors_Complete_Singles_16x16/ME_Singles_School_16x16_Soccer_Ball_1.png"
const TEAM_US := ["Premade_Character_04", "Premade_Character_15"]
const TEAM_THEM := ["Premade_Character_09", "Premade_Character_19", "Premade_Character_11"]

var our := 0
var their := 0
var time_left := TIME
var ball_pos := CENTER
var ball_vel := Vector2.ZERO
var running := false
var player: Player
var bots: Array[Dictionary] = []
var _pause := 0.0
var _ball: Sprite2D
var _hud: Label
var _layer: CanvasLayer
var _rng := RandomNumberGenerator.new()
var _last_touch := ""  # "us" / "them"
var _world: Node2D
var _hidden_keeper: Node2D


static func top_goal_y() -> float:
	return FIELD.position.y


static func bottom_goal_y() -> float:
	return FIELD.end.y


func start(location: Location) -> void:
	player = location.player
	_world = location.entities
	for n in location.find_children("*", "Npc", true, false):
		if (n as Npc).npc_id == &"park_keeper":
			_hidden_keeper = n
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	_rng.seed = hash([WorldClock.day, WorldClock.minute_of_day])
	z_index = 0
	y_sort_enabled = true
	_ball = Sprite2D.new()
	var tex := AssetLibrary.load_texture(BALL_TEX)
	_ball.texture = tex if tex != null else AssetLibrary.placeholder(Vector2i(8, 8), Color.WHITE)
	_ball.offset = Vector2(0, -6)
	_world.add_child(_ball)
	# Teams: role = home position as a fraction of the field, side.
	_add_bot("us", "keeper", "Premade_Character_02", Vector2(0.5, 0.98))
	_add_bot("us", "back", TEAM_US[0], Vector2(0.3, 0.78))
	_add_bot("us", "wing", TEAM_US[1], Vector2(0.72, 0.6))
	_add_bot("them", "keeper", TEAM_THEM[2], Vector2(0.5, 0.02))
	_add_bot("them", "back", TEAM_THEM[0], Vector2(0.65, 0.25))
	_add_bot("them", "wing", TEAM_THEM[1], Vector2(0.3, 0.42))
	_add_bot("them", "forward", "Premade_Character_17", Vector2(0.5, 0.36))
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 10)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(_hud)
	_kickoff()
	running = true
	EventHub.toast_requested.emit(tr("MATCH_START"))
	Sfx.play(&"bell", 0.0, -4.0)


func _add_bot(side: String, role: String, premade: String, home: Vector2) -> void:
	var s := LayeredCharacterSprite.new()
	var a := CharacterAppearance.new()
	a.premade = premade
	a.placeholder_color = Color(0.3, 0.5, 0.9) if side == "us" else Color(0.9, 0.4, 0.3)
	s.appearance = a
	_world.add_child(s)
	var b := {"node": s, "side": side, "role": role, "home": home, "pos": _home_pos(home), "cool": 0.0, "speed": 54.0 + _rng.randf_range(-4, 6)}
	if role == "keeper":
		b["speed"] = 70.0
	bots.append(b)


func _home_pos(frac: Vector2) -> Vector2:
	return FIELD.position + FIELD.size * frac


func _kickoff() -> void:
	ball_pos = CENTER
	ball_vel = Vector2.ZERO
	for b in bots:
		b["pos"] = _home_pos(b["home"])
	if player != null:
		player.global_position = CENTER + Vector2(0, 30)
	_pause = KICKOFF_PAUSE


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _pause > 0.0:
		_pause -= delta
		_draw_all()
		return
	time_left -= delta
	_update_player_touch(delta)
	for b in bots:
		_update_bot(b, delta)
	_update_ball(delta)
	_draw_all()
	if our >= WIN or their >= WIN or time_left <= 0.0:
		finish()


func _update_player_touch(_delta: float) -> void:
	if player == null:
		return
	var feet := player.global_position
	var d := ball_pos.distance_to(feet)
	if d < 9.0 and player.velocity.length() > 10.0:
		ball_vel = player.velocity.normalized() * maxf(DRIBBLE, player.velocity.length() * 1.05)
		ball_pos = feet + player.velocity.normalized() * 9.5
		_last_touch = "us"
	if d < 15.0 and Input.is_action_just_pressed(&"attack"):
		var dir := player.velocity.normalized() if player.velocity.length() > 5.0 else player.facing
		ball_vel = dir * KICK * (1.15 if Input.is_action_pressed(&"sprint") else 1.0)
		_last_touch = "us"
		Sfx.play(&"hit", 0.0, -6.0)


func _update_bot(b: Dictionary, delta: float) -> void:
	b["cool"] = maxf(0.0, float(b["cool"]) - delta)
	var pos: Vector2 = b["pos"]
	var side: String = b["side"]
	var attack_goal := Vector2(CENTER.x, top_goal_y() - 6) if side == "us" else Vector2(CENTER.x, bottom_goal_y() + 6)
	var target: Vector2
	if b["role"] == "keeper":
		var line_y := top_goal_y() + 6 if side == "them" else bottom_goal_y() - 6
		target = Vector2(clampf(ball_pos.x, CENTER.x - GOAL_HALF, CENTER.x + GOAL_HALF), line_y)
		if ball_pos.distance_to(pos) < 34.0 and absf(ball_pos.y - line_y) < 34.0:
			target = ball_pos
			b["speed"] = 105.0  # the dive
		else:
			b["speed"] = 70.0
	elif _is_chaser(b):
		# Get behind the ball, facing the goal we attack.
		var behind := ball_pos - (attack_goal - ball_pos).normalized() * 7.0
		target = behind if pos.distance_to(ball_pos) > 10.0 else ball_pos
	else:
		var home := _home_pos(b["home"])
		target = home.lerp(ball_pos, 0.35)
	var to := target - pos
	var spd: float = b["speed"]
	var step := to.limit_length(spd * delta)
	pos += step
	pos.x = clampf(pos.x, FIELD.position.x - 6, FIELD.end.x + 6)
	pos.y = clampf(pos.y, FIELD.position.y - 10, FIELD.end.y + 10)
	b["pos"] = pos
	var s: LayeredCharacterSprite = b["node"]
	s.position = pos
	if step.length() > 0.2:
		s.play(&"walk", _dir_of(step))
	else:
		s.play(&"idle", LayeredCharacterSprite.Dir.UP if side == "us" else LayeredCharacterSprite.Dir.DOWN)
	# Touch the ball when close: keepers clear it, others dribble towards
	# goal and shoot only from shooting range.
	var reach := 14.0 if b["role"] == "keeper" else 10.0
	if pos.distance_to(ball_pos) < reach and b["cool"] <= 0.0:
		var to_goal := attack_goal.distance_to(ball_pos)
		if b["role"] == "keeper":
			var aim := Vector2(_rng.randf_range(FIELD.position.x + 20, FIELD.end.x - 20), CENTER.y)
			ball_vel = (aim - ball_pos).normalized() * KICK * 0.8
			b["cool"] = 0.8
			Sfx.play(&"hit", 0.0, -10.0)
		elif to_goal < SHOT_RANGE:
			var aim := attack_goal + Vector2(_rng.randf_range(-GOAL_HALF * 1.3, GOAL_HALF * 1.3), 0)
			ball_vel = (aim - ball_pos).normalized() * KICK * _rng.randf_range(0.6, 0.85)
			b["cool"] = 0.8
			Sfx.play(&"hit", 0.0, -10.0)
		else:
			var drift := Vector2(_rng.randf_range(-0.35, 0.35), 0)
			ball_vel = ((attack_goal - ball_pos).normalized() + drift).normalized() * DRIBBLE * 1.1
			b["cool"] = 0.25
		_last_touch = side


func _is_chaser(b: Dictionary) -> bool:
	var best: Dictionary = {}
	var best_d := INF
	for o in bots:
		if o["side"] != b["side"] or o["role"] == "keeper":
			continue
		var d: float = (o["pos"] as Vector2).distance_to(ball_pos)
		if d < best_d:
			best_d = d
			best = o
	# On our side a bot leaves the ball to you only when you're right on it.
	if b["side"] == "us" and player != null and player.global_position.distance_to(ball_pos) < minf(best_d, 24.0):
		return false
	return best == b


func _update_ball(delta: float) -> void:
	ball_pos += ball_vel * delta
	ball_vel = ball_vel.move_toward(Vector2.ZERO, FRICTION * delta)
	var in_mouth := absf(ball_pos.x - CENTER.x) < GOAL_HALF
	if ball_pos.y < top_goal_y():
		if in_mouth:
			_goal("us")
			return
		ball_pos.y = top_goal_y()
		ball_vel.y = absf(ball_vel.y) * 0.6
	if ball_pos.y > bottom_goal_y():
		if in_mouth:
			_goal("them")
			return
		ball_pos.y = bottom_goal_y()
		ball_vel.y = -absf(ball_vel.y) * 0.6
	if ball_pos.x < FIELD.position.x or ball_pos.x > FIELD.end.x:
		ball_pos.x = clampf(ball_pos.x, FIELD.position.x, FIELD.end.x)
		ball_vel.x = -ball_vel.x * 0.6


func _goal(side: String) -> void:
	if side == "us":
		our += 1
		EventHub.toast_requested.emit(tr("MATCH_GOAL_US") % [our, their])
	else:
		their += 1
		EventHub.toast_requested.emit(tr("MATCH_GOAL_THEM") % [our, their])
	Sfx.play(&"bell", 0.0, -2.0)
	_kickoff()


func _draw_all() -> void:
	_ball.position = ball_pos
	var m := int(ceil(maxf(0.0, time_left))) / 60
	var s := int(ceil(maxf(0.0, time_left))) % 60
	_hud.text = tr("MATCH_SCORE") % [our, their, m, s]


static func _dir_of(v: Vector2) -> LayeredCharacterSprite.Dir:
	if absf(v.x) > absf(v.y):
		return LayeredCharacterSprite.Dir.RIGHT if v.x > 0 else LayeredCharacterSprite.Dir.LEFT
	return LayeredCharacterSprite.Dir.DOWN if v.y > 0 else LayeredCharacterSprite.Dir.UP


func finish() -> void:
	if not running:
		return
	running = false
	var line := ""
	if our > their:
		line = tr("MATCH_WON") % [our, their]
		var paid := StringName("match.football.paid_day")
		if int(GameState.get_flag(paid, -1)) != WorldClock.day:
			GameState.set_flag(paid, WorldClock.day)
			Inventory.money += REWARD
			line += " " + tr("SPORT_PAID") % REWARD
		GameState.set_flag(&"match.football.wins", int(GameState.get_flag(&"match.football.wins", 0)) + 1)
	elif our == their:
		line = tr("MATCH_DRAW") % [our, their]
	else:
		line = tr("MATCH_LOST") % [our, their]
	EventHub.toast_requested.emit(line)
	ended.emit(our, their)
	_cleanup()
	queue_free()


func _cleanup() -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	for b in bots:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	bots.clear()
	if is_instance_valid(_hidden_keeper):
		_hidden_keeper.visible = true
		_hidden_keeper.process_mode = Node.PROCESS_MODE_INHERIT


func _exit_tree() -> void:
	if running:
		running = false
		_cleanup()
