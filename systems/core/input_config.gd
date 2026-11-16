extends Node
## Registers default input actions in code so they stay readable, reviewable
## and remappable later (a settings screen can overwrite them at runtime).
## Owner: core. Manual test: every action works on keyboard and gamepad.

const DEADZONE := 0.25


func _key(code: Key) -> InputEvent:
	# Physical keycodes keep WASD in place on Russian/AZERTY layouts.
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _button(index: JoyButton) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e


func _mouse(index: MouseButton) -> InputEvent:
	var e := InputEventMouseButton.new()
	e.button_index = index
	return e


func _axis(axis: JoyAxis, value: float) -> InputEvent:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _defaults() -> Dictionary:
	return {
		&"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)],
		&"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)],
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)],
		&"interact": [_key(KEY_E), _key(KEY_ENTER), _button(JOY_BUTTON_A)],
		&"sprint": [_key(KEY_SHIFT), _button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"attack": [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_X)],
		&"dodge": [_key(KEY_K), _key(KEY_SPACE), _mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_B)],
		&"ability": [_key(KEY_Q), _key(KEY_L), _button(JOY_BUTTON_Y)],
		&"quick_heal": [_key(KEY_R), _button(JOY_BUTTON_LEFT_SHOULDER)],
		&"journal": [_key(KEY_TAB), _button(JOY_BUTTON_BACK)],
		&"wait": [_key(KEY_T), _button(JOY_BUTTON_RIGHT_STICK)],
		&"map": [_key(KEY_M), _button(JOY_BUTTON_LEFT_STICK)],
		&"inventory": [_key(KEY_I)],
		&"pause": [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)],
		&"quick_save": [_key(KEY_F5)],
		&"quick_load": [_key(KEY_F9)],
	}


func _enter_tree() -> void:
	var defaults := _defaults()
	for action: StringName in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		if InputMap.action_get_events(action).is_empty():
			for event: InputEvent in defaults[action]:
				InputMap.action_add_event(action, event)
