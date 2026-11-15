class_name ActCard
extends CanvasLayer
## Full-width title card when a new act starts ("ACT I — The City Has Two
## Maps"). Waits until conversations and scene transitions are over, never
## pauses the game, and can be skipped with interact or pause.

const FADE := 0.8
const HOLD := 3.2

var _queue: Array[StringName] = []
var _busy := false
var _band: ColorRect
var _title: Label
var _subtitle: Label
var _skip := false


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_band = ColorRect.new()
	_band.color = Color(0.03, 0.03, 0.06, 0.88)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.36
	_band.anchor_bottom = 0.64
	add_child(_band)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_title.add_theme_font_size_override("font_size", 10)
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", UiTheme.INK)
	_subtitle.add_theme_font_size_override("font_size", 16)
	box.add_child(_subtitle)
	_band.modulate.a = 0.0
	visible = false
	Campaign.act_started.connect(show_act)


func show_act(act_id: StringName) -> void:
	_queue.append(act_id)
	if not _busy:
		_run()


func is_showing() -> bool:
	return _busy


func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var id: StringName = _queue.pop_front()
		while DialogueService.is_active or SceneFlow.is_transitioning:
			await get_tree().process_frame
		var a := Campaign.act(id)
		_title.text = tr(String(a.get("title", ""))).to_upper()
		_subtitle.text = tr(String(a.get("subtitle", "")))
		visible = true
		Sfx.play(&"bell")
		_skip = false
		var t := 0.0
		var total := FADE * 2.0 + HOLD
		while t < total:
			await get_tree().process_frame
			t += get_process_delta_time()
			if _skip and t < total - FADE:
				t = total - FADE * 0.3
			var a_in := clampf(t / FADE, 0.0, 1.0)
			var a_out := clampf((total - t) / FADE, 0.0, 1.0)
			_band.modulate.a = minf(a_in, a_out)
		_band.modulate.a = 0.0
		visible = false
	_busy = false


func _input(event: InputEvent) -> void:
	if _busy and visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		_skip = true
