extends Node
## Player settings (not part of a save): quest guidance, volume, window mode,
## language. Stored in user://settings.cfg. Autoload after Localization.
##
## Guidance (R0, D-064):
##   detailed: objective + where/when + an on-screen marker (default; new players)
##   standard: the objective line only
##   minimal:  nothing on screen; the journal and what people say are the guide

signal changed

const PATH := "user://settings.cfg"
const GUIDANCE_MODES: Array[String] = ["detailed", "standard", "minimal"]
const VOLUME_STEPS := 10
## Window sizes offered in windowed mode: whole multiples of the 480x270 base,
## so every pixel stays square and nothing is letterboxed.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1440, 810), Vector2i(1920, 1080),
	Vector2i(2400, 1350), Vector2i(2880, 1620), Vector2i(3360, 1890), Vector2i(3840, 2160)]
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
## Characters per second for dialogue; 0 = the whole line at once.
const TEXT_SPEEDS := {"slow": 30.0, "normal": 50.0, "fast": 90.0, "instant": 0.0}
const TEXT_SPEED_ORDER: Array[String] = ["slow", "normal", "fast", "instant"]

var guidance := "detailed"
var volume := 8  # 0..VOLUME_STEPS
var music := 7  # 0..VOLUME_STEPS, relative to the master volume
var fullscreen := false
var window_mode := "windowed"
var resolution := Vector2i(1440, 810)
var text_speed := "normal"
var _loaded_locale := ""


func _ready() -> void:
	if AudioServer.get_bus_index(&"Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	guidance = String(cfg.get_value("game", "guidance", guidance))
	if not guidance in GUIDANCE_MODES:
		guidance = "detailed"
	volume = clampi(int(cfg.get_value("audio", "volume", volume)), 0, VOLUME_STEPS)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	window_mode = String(cfg.get_value("video", "window_mode", "fullscreen" if fullscreen else window_mode))
	if not window_mode in WINDOW_MODES:
		window_mode = "windowed"
	var r: Variant = cfg.get_value("video", "resolution", resolution)
	if r is Vector2i:
		resolution = r
	text_speed = String(cfg.get_value("game", "text_speed", text_speed))
	if not TEXT_SPEEDS.has(text_speed):
		text_speed = "normal"
	music = clampi(int(cfg.get_value("audio", "music", music)), 0, VOLUME_STEPS)
	_loaded_locale = String(cfg.get_value("game", "locale", ""))
	if _loaded_locale != "":
		Localization.set_locale(_loaded_locale)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "guidance", guidance)
	cfg.set_value("game", "locale", Localization.get_locale())
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music", music)
	cfg.set_value("video", "fullscreen", window_mode != "windowed")
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("game", "text_speed", text_speed)
	cfg.save(PATH)


func apply() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(volume) / VOLUME_STEPS)))
	var mb := AudioServer.get_bus_index(&"Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, music == 0)
		AudioServer.set_bus_volume_db(mb, linear_to_db(maxf(0.001, float(music) / VOLUME_STEPS)))
	fullscreen = window_mode != "windowed"
	if DisplayServer.get_name() != "headless":
		_apply_window()
	changed.emit()


func _apply_window() -> void:
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var screen := DisplayServer.screen_get_size()
			var size := resolution
			if screen.x > 0 and (size.x > screen.x or size.y > screen.y):
				size = screen * 9 / 10
			DisplayServer.window_set_size(size)
			if screen.x > 0:
				DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - size) / 2)


## Resolutions that fit the current screen (all of them if it is unknown).
func resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if screen.x <= 0 or (r.x <= screen.x and r.y <= screen.y):
			out.append(r)
	return out if not out.is_empty() else [RESOLUTIONS[0]]


func cycle_resolution(step: int = 1) -> void:
	var list := resolutions()
	var i := list.find(resolution)
	resolution = list[posmod(i + step, list.size())] if i >= 0 else list[0]
	window_mode = "windowed"
	save_settings()
	apply()


func cycle_window_mode() -> void:
	window_mode = WINDOW_MODES[(WINDOW_MODES.find(window_mode) + 1) % WINDOW_MODES.size()]
	save_settings()
	apply()


func cycle_text_speed() -> void:
	text_speed = TEXT_SPEED_ORDER[(TEXT_SPEED_ORDER.find(text_speed) + 1) % TEXT_SPEED_ORDER.size()]
	save_settings()
	changed.emit()


func chars_per_second() -> float:
	return float(TEXT_SPEEDS.get(text_speed, 50.0))


func set_guidance(mode: String) -> void:
	if mode in GUIDANCE_MODES:
		guidance = mode
		save_settings()
		changed.emit()


func cycle_guidance() -> void:
	set_guidance(GUIDANCE_MODES[(GUIDANCE_MODES.find(guidance) + 1) % GUIDANCE_MODES.size()])


func cycle_volume() -> void:
	volume = (volume + 1) % (VOLUME_STEPS + 1)
	save_settings()
	apply()


func cycle_music() -> void:
	music = (music + 1) % (VOLUME_STEPS + 1)
	save_settings()
	apply()


func toggle_fullscreen() -> void:
	window_mode = "windowed" if window_mode != "windowed" else "fullscreen"
	save_settings()
	apply()


func cycle_language() -> void:
	Localization.set_locale("en" if Localization.get_locale().begins_with("ru") else "ru")
	save_settings()
	changed.emit()


func shows_objective() -> bool:
	return guidance != "minimal"


func shows_guide() -> bool:
	return guidance == "detailed"
