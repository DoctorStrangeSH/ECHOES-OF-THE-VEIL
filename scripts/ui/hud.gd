class_name Hud
extends CanvasLayer
## In-game overlay: interaction prompt, dialogue box and toasts.
## Presentation only: it listens to EventHub and never owns game state.

const CHARS_PER_SECOND := 45.0
const LOCK_REASON := &"dialogue"

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _more_label: Label
var _toast_label: Label
var _toast_tween: Tween

var _lines: PackedStringArray = []
var _line_index := 0
var dialogue_open := false


func _ready() -> void:
	layer = 10
	_build()
	EventHub.message_requested.connect(_on_message_requested)
	EventHub.interaction_focus_changed.connect(_on_focus_changed)
	EventHub.toast_requested.connect(show_toast)
	SaveService.saved.connect(func(_slot: int) -> void: show_toast(tr("TOAST_SAVED")))
	SceneFlow.transition_started.connect(_on_transition_started)


func _process(delta: float) -> void:
	visible = GameState.is_playing
	if dialogue_open and _text_label.visible_ratio < 1.0:
		var total := maxf(1.0, float(_text_label.get_total_character_count()))
		_text_label.visible_ratio = minf(1.0, _text_label.visible_ratio + delta * CHARS_PER_SECOND / total)
		_more_label.visible = _text_label.visible_ratio >= 1.0


func _input(event: InputEvent) -> void:
	if not dialogue_open or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	if _text_label.visible_ratio < 1.0:
		_text_label.visible_ratio = 1.0  # first press completes the line
		_more_label.visible = true
	else:
		_line_index += 1
		if _line_index >= _lines.size():
			_close_dialogue()
		else:
			_show_line()


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast_label.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _on_message_requested(lines: PackedStringArray, speaker: String) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = 0
	_speaker_label.text = tr(speaker) if not speaker.is_empty() else ""
	_speaker_label.visible = not speaker.is_empty()
	dialogue_open = true
	GameState.lock_player(LOCK_REASON)
	_prompt_panel.visible = false
	_dialogue_panel.visible = true
	_show_line()


func _show_line() -> void:
	_text_label.text = tr(_lines[_line_index])
	_text_label.visible_ratio = 0.0
	_more_label.visible = false


func _close_dialogue() -> void:
	dialogue_open = false
	_dialogue_panel.visible = false
	GameState.unlock_player(LOCK_REASON)
	EventHub.message_finished.emit()


func _on_transition_started() -> void:
	_on_focus_changed("")
	if dialogue_open:
		_close_dialogue()


func _on_focus_changed(prompt: String) -> void:
	_prompt_panel.visible = not prompt.is_empty() and not dialogue_open
	_prompt_label.text = "[%s] %s" % [UiTheme.action_hint(&"interact"), prompt]


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
	_prompt_panel.visible = false

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.anchor_left = 0.0
	_dialogue_panel.anchor_right = 1.0
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_left = 16
	_dialogue_panel.offset_right = -16
	_dialogue_panel.offset_top = -78
	_dialogue_panel.offset_bottom = -8
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_more_label = Label.new()
	_more_label.text = ">"
	_more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more_label.add_theme_color_override("font_color", UiTheme.INK_DIM)
	box.add_child(_speaker_label)
	box.add_child(_text_label)
	box.add_child(_more_label)
	_dialogue_panel.add_child(box)
	root.add_child(_dialogue_panel)
	_dialogue_panel.visible = false

	_toast_label = Label.new()
	_toast_label.position = Vector2(10, 8)
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 3)
	_toast_label.modulate.a = 0.0
	root.add_child(_toast_label)
