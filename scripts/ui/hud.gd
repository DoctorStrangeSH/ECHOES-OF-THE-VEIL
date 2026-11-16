class_name Hud
extends CanvasLayer
## In-game overlay: interaction prompt, dialogue box with choices, clock,
## health, toasts. Presentation only: renders DialogueService/EventHub state.

const CHARS_PER_SECOND := 45.0
const TOAST_QUEUE_MAX := 4

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _more_label: Label
var _choices_box: VBoxContainer
var _clock_label: Label
var _hearts: HeartBar
var _combat: CombatHud
var _wallet: Label
var _objective: Label
var _guide: Label
var _keys_hint: Label
var _controls: PanelContainer
var _controls_t := 0.0
var _objective_t := 0.0
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _choices: PackedStringArray = []

var dialogue_open: bool:
	get:
		return DialogueService.is_active


func _ready() -> void:
	layer = 10
	_build()
	DialogueService.line_shown.connect(_on_line_shown)
	DialogueService.dialogue_ended.connect(_on_dialogue_ended)
	EventHub.interaction_focus_changed.connect(_on_focus_changed)
	EventHub.toast_requested.connect(show_toast)
	EventHub.player_health_changed.connect(_on_health_changed)
	SaveService.saved.connect(func(_slot: int) -> void: show_toast(tr("TOAST_SAVED")))
	SceneFlow.transition_started.connect(func() -> void: _on_focus_changed(""))


## The pinned case's current objective, plus its deadline if it has one.
func _objective_line() -> String:
	var id := Journal.pinned
	if id == &"" or Journal.case_status(id) != Journal.STATUS_ACTIVE:
		return ""
	var line := Journal.current_objective_text(id)
	var left := Journal.days_left(id)
	if left >= 0:
		line += "  " + tr("JOURNAL_DAYS_LEFT") % left
	return line


## Where/when for the pinned case ("detailed" guidance only).
func _guide_line() -> String:
	if Journal.pinned == &"" or not GameSettings.shows_guide():
		return ""
	return QuestGuide.describe(QuestGuide.target(Journal.pinned))


## First minutes of a new game: a small card with the controls. Disappears
## after 30 seconds on screen, and never comes back.
func _update_controls_card(delta: float) -> void:
	if GameState.has_flag(&"ui.controls_seen"):
		_controls.visible = false
		return
	_controls.visible = not _dialogue_panel.visible
	if _controls.visible:
		_controls_t += delta
	if _controls_t > 30.0:
		GameState.set_flag(&"ui.controls_seen")


func _process(delta: float) -> void:
	visible = GameState.is_playing
	if not visible:
		return
	var clock := tr("HUD_CLOCK") % [WorldClock.day, WorldClock.time_text(), tr("PERIOD_" + WorldClock.get_period().to_upper())]
	if WorldClock.weather == "rain":
		clock += "  " + tr("WEATHER_RAIN")
	_clock_label.text = clock
	var wallet := "£%d" % Inventory.money
	if Inventory.resonance > 0 or _hearts.visible:
		wallet += "  ·  " + tr("HUD_RESONANCE") % Inventory.resonance
	_wallet.text = wallet
	_objective_t -= delta
	if _objective_t <= 0.0:
		_objective_t = 0.4
		_objective.text = _objective_line()
		_guide.text = _guide_line()
		_keys_hint.text = tr("HUD_KEYS_HINT")
		(_controls.get_node("Text") as Label).text = tr("HUD_CONTROLS")
	_objective.visible = GameSettings.shows_objective() and not _dialogue_panel.visible and _objective.text != ""
	_guide.visible = _objective.visible and GameSettings.shows_guide() and _guide.text != ""
	_keys_hint.visible = not _dialogue_panel.visible
	_update_controls_card(delta)
	if _dialogue_panel.visible and _text_label.visible_ratio < 1.0:
		var total := maxf(1.0, float(_text_label.get_total_character_count()))
		_text_label.visible_ratio = minf(1.0, _text_label.visible_ratio + delta * CHARS_PER_SECOND / total)
		if _text_label.visible_ratio >= 1.0:
			_reveal_choices()


func _input(event: InputEvent) -> void:
	if not DialogueService.is_active or not _dialogue_panel.visible:
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		if _text_label.visible_ratio < 1.0:
			_text_label.visible_ratio = 1.0  # first press completes the line
			_reveal_choices()
		elif _choices.is_empty():
			DialogueService.advance()
		else:
			var focused := get_viewport().gui_get_focus_owner()
			var idx := _choices_box.get_children().find(focused)
			DialogueService.choose(maxi(idx, 0))
	elif event is InputEventKey and event.pressed and not event.echo and _choices_box.visible:
		var n := int((event as InputEventKey).physical_keycode) - int(KEY_1)
		if n >= 0 and n < _choices.size():
			get_viewport().set_input_as_handled()
			DialogueService.choose(n)


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	if _toast_queue.size() < TOAST_QUEUE_MAX:
		_toast_queue.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_toast_label.text = _toast_queue.pop_front()
	_toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_next_toast)


func _on_line_shown(speaker: String, text: String, choices: PackedStringArray) -> void:
	_prompt_panel.visible = false
	_dialogue_panel.visible = true
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	_text_label.text = text
	_text_label.visible = not text.is_empty()
	_text_label.visible_ratio = 0.0 if not text.is_empty() else 1.0
	_choices = choices
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()
	_choices_box.visible = false
	_more_label.visible = false
	for i in choices.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, choices[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(DialogueService.choose.bind(i))
		_choices_box.add_child(b)
	if text.is_empty():
		_reveal_choices()


func _reveal_choices() -> void:
	if _choices.is_empty():
		_more_label.visible = true
		return
	if not _choices_box.visible:
		_choices_box.visible = true
		var first := _choices_box.get_child(0) as Button
		if first != null:
			first.grab_focus.call_deferred()


func _on_dialogue_ended(_id: StringName) -> void:
	_dialogue_panel.visible = false
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()
	_choices = PackedStringArray()


func _on_focus_changed(prompt: String) -> void:
	_prompt_panel.visible = not prompt.is_empty() and not DialogueService.is_active
	_prompt_label.text = "[%s] %s" % [UiTheme.action_hint(&"interact"), prompt]


func _on_health_changed(health: int, max_health: int) -> void:
	_hearts.set_health(health, max_health)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	_prompt_panel = PanelContainer.new()
	_prompt_label = Label.new()
	_prompt_panel.add_child(_prompt_label)
	root.add_child(_prompt_panel)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.visible = false

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.anchor_left = 0.0
	_dialogue_panel.anchor_right = 1.0
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_left = 16
	_dialogue_panel.offset_right = -16
	_dialogue_panel.offset_top = -72
	_dialogue_panel.offset_bottom = -8
	_dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 24)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 2)
	_more_label = Label.new()
	_more_label.text = ">"
	_more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more_label.add_theme_color_override("font_color", UiTheme.INK_DIM)
	box.add_child(_speaker_label)
	box.add_child(_text_label)
	box.add_child(_choices_box)
	box.add_child(_more_label)
	_dialogue_panel.add_child(box)
	root.add_child(_dialogue_panel)
	_dialogue_panel.visible = false

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 8)
	_clock_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock_label.add_theme_constant_override("outline_size", 3)
	root.add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_hearts = HeartBar.new()
	_hearts.position = Vector2(8, 8)
	root.add_child(_hearts)

	_combat = CombatHud.new()
	root.add_child(_combat)
	_combat.visible = false

	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 8)
	_wallet.add_theme_color_override("font_outline_color", Color.BLACK)
	_wallet.add_theme_constant_override("outline_size", 3)
	root.add_child(_wallet)
	_wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_wallet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wallet.offset_top = 16
	_wallet.offset_bottom = 28

	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 8)
	_objective.add_theme_color_override("font_color", UiTheme.ACCENT)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.add_theme_constant_override("outline_size", 3)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var quest_box := VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 0)
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest_box)
	quest_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_box.offset_left = -196
	quest_box.offset_right = -6
	quest_box.offset_top = 30
	quest_box.offset_bottom = 110
	_objective.add_theme_constant_override("line_spacing", -2)
	quest_box.add_child(_objective)

	_guide = Label.new()
	_guide.add_theme_font_size_override("font_size", 8)
	_guide.add_theme_color_override("font_color", UiTheme.INK)
	_guide.add_theme_color_override("font_outline_color", Color.BLACK)
	_guide.add_theme_constant_override("outline_size", 3)
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_guide.add_theme_constant_override("line_spacing", -2)
	quest_box.add_child(_guide)

	_keys_hint = Label.new()
	_keys_hint.add_theme_font_size_override("font_size", 8)
	_keys_hint.add_theme_color_override("font_color", Color(UiTheme.INK_DIM, 0.85))
	_keys_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_keys_hint.add_theme_constant_override("outline_size", 2)
	_keys_hint.text = tr("HUD_KEYS_HINT")
	root.add_child(_keys_hint)
	_keys_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
	_keys_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_keys_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_controls = PanelContainer.new()
	var cl := Label.new()
	cl.name = "Text"
	cl.add_theme_font_size_override("font_size", 8)
	_controls.add_child(cl)
	root.add_child(_controls)
	_controls.position = Vector2(6, 6)
	_controls.visible = false

	var marker := QuestMarker.new()
	root.add_child(marker)

	_toast_label = Label.new()
	_toast_label.position = Vector2(10, 22)
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 3)
	_toast_label.modulate.a = 0.0
	root.add_child(_toast_label)
