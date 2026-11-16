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

var guidance := "detailed"
var volume := 8  # 0..VOLUME_STEPS
var fullscreen := false
var _loaded_locale := ""


func _ready() -> void:
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
	_loaded_locale = String(cfg.get_value("game", "locale", ""))
	if _loaded_locale != "":
		Localization.set_locale(_loaded_locale)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "guidance", guidance)
	cfg.set_value("game", "locale", Localization.get_locale())
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


func apply() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(volume) / VOLUME_STEPS)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


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


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
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
