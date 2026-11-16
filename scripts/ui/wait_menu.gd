class_name WaitMenu
extends CanvasLayer
## "Wait" (T by default): skip ahead to evening, night or morning anywhere it
## is calm. Many things in Greyford only happen at certain hours; standing
## still for real minutes is not a puzzle (playtest: a friend didn't know he
## had to wait for dark).

const OPTIONS := [["WAIT_EVENING", 18], ["WAIT_NIGHT", 22], ["WAIT_MORNING", 7]]
const CALM_RADIUS := 220.0

var _box: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"wait")):
		get_viewport().set_input_as_handled()
		close()
	elif not is_open() and event.is_action_pressed(&"wait") and _can_open():
		get_viewport().set_input_as_handled()
		if is_calm():
			open()
		else:
			EventHub.toast_requested.emit(tr("WAIT_NOT_NOW"))


func _can_open() -> bool:
	return GameState.is_playing and not SceneFlow.is_transitioning and not get_tree().paused \
		and not DialogueService.is_active


## No echoes nearby and no boss fight running.
static func is_calm() -> bool:
	var loc := SceneFlow.current_location
	if loc == null:
		return true
	var player := loc.get("player") as Node2D
	for e in loc.get_tree().get_nodes_in_group(&"echo_enemy"):
		if not loc.is_ancestor_of(e):
			continue
		if e is EchoEnemy and (e as EchoEnemy).state == EchoEnemy.State.DEAD:
			continue
		if player == null or (e as Node2D).global_position.distance_to(player.global_position) < CALM_RADIUS:
			return false
	for arena in loc.find_children("*", "BossArena", true, false):
		var boss := (arena as BossArena).get_node_or_null((arena as BossArena).boss_path)
		if boss == null or not GameState.has_flag((arena as BossArena).engaged_flag):
			continue
		var hp: Variant = boss.get("health")
		if hp is Health and (hp as Health).health > 0:
			return false
	return true


func open() -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = tr("WAIT_TITLE") % WorldClock.time_text()
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_box.add_child(title)
	for o: Array in OPTIONS:
		var b := Button.new()
		b.text = tr(o[0])
		b.pressed.connect(_wait.bind(int(o[1])))
		_box.add_child(b)
	var cancel := Button.new()
	cancel.text = tr("CC_BACK")
	cancel.pressed.connect(close)
	_box.add_child(cancel)
	_panel.visible = true
	get_tree().paused = true
	(_box.get_child(1) as Button).grab_focus.call_deferred()


func close() -> void:
	_panel.visible = false
	get_tree().paused = false


func _wait(hour: int) -> void:
	close()
	WorldClock.wait_until_hour(hour)
	EventHub.toast_requested.emit(tr("WAIT_DONE") % WorldClock.time_text())


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_panel.add_child(_box)
