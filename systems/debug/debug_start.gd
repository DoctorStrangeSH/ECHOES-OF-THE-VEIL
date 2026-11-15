class_name DebugStart
extends RefCounted
## Editor/debug builds only: begin a new game at the start of any act, with a
## plausible history (data/debug/act_starts.json). Lets testers reach late
## bosses and endings without replaying everything. Never shown in exports.

const PATH := "res://data/debug/act_starts.json"
const TARGETS: Array[String] = ["act1", "act2", "act3", "act4", "act5", "endgame"]


static func available() -> bool:
	return OS.is_debug_build()


static func apply_history(target: String) -> void:
	var data: Variant = DataFiles.read_json(PATH)
	if not data is Dictionary:
		return
	# Acts only start while playing; start each one right after its step so
	# the next step finds the case the act opened.
	var was_playing := GameState.is_playing
	GameState.is_playing = true
	Campaign.check()
	for step: Dictionary in data.get("steps", []):
		StoryRules.apply(step.get("effects", []))
		Campaign.check()
		if String(step.get("to", "")) == target:
			break
	GameState.is_playing = was_playing


static func start(target: String, difficulty: String = "normal") -> void:
	SceneFlow.begin_new_game({"name": "Tester", "pronouns": "they", "background": "returning_local", "difficulty": difficulty})
	apply_history(target)
