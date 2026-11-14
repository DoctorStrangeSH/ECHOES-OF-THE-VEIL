extends Node
## Runs branching conversations authored in res://data/dialogue/*.json.
##
## File format: { "<dialogue_id>": {
##     "entries": [ {"if": <condition>, "node": "<node_id>"}, ... ],  # optional, first match wins
##     "start": "<node_id>",                                            # fallback entry
##     "nodes": { "<node_id>": {
##         "speaker": "NPC_MARA" | "player" | "",  "text": "LOC_KEY",
##         "effects": [ ... ],            # applied when the node is shown
##         "next": "<node_id>" | null,    # used when there are no visible choices
##         "choices": [ {"text": "LOC_KEY", "next": "<node_id>" | null,
##                       "if": <condition>, "effects": [ ... ]} ]
##     } } } }
## Conditions/effects: see StoryRules. Text supports {name} (player name).
## Simple line lists (signs, notes) go through show_lines().
## Owner: dialogue. Tests: tests/test_runner.gd (all dialogues validated).

signal line_shown(speaker: String, text: String, choices: PackedStringArray)
signal dialogue_ended(dialogue_id: StringName)

const DATA_DIR := "res://data/dialogue"
const LOCK_REASON := &"dialogue"

var dialogues: Dictionary = {}
var is_active := false
var current_id: StringName = &""
var context: Dictionary = {}

var _def: Dictionary = {}
var _node: Dictionary = {}
var _visible_choices: Array = []


func _enter_tree() -> void:
	load_definitions()


func _ready() -> void:
	EventHub.message_requested.connect(show_lines)
	SceneFlow.transition_started.connect(_on_transition_started)


func _on_transition_started() -> void:
	if is_active:
		end()


func load_definitions() -> void:
	dialogues.clear()
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if file_name.get_extension() != "json":
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file_name)))
		if not data is Dictionary:
			push_error("Dialogue: %s is not a JSON object" % file_name)
			continue
		for id: String in data:
			if dialogues.has(StringName(id)):
				push_error("Dialogue: duplicate id '%s' in %s" % [id, file_name])
			dialogues[StringName(id)] = data[id]


func has_dialogue(id: StringName) -> bool:
	return dialogues.has(id)


func start(id: StringName, ctx: Dictionary = {}) -> void:
	if not dialogues.has(id):
		push_error("Dialogue: unknown dialogue '%s'" % id)
		return
	_begin(id, dialogues[id], ctx)


## Plays a plain list of lines (localization keys) as a linear conversation.
func show_lines(lines: PackedStringArray, speaker: String = "") -> void:
	if lines.is_empty():
		return
	var nodes := {}
	for i in lines.size():
		nodes[str(i)] = {"speaker": speaker, "text": lines[i], "next": str(i + 1) if i + 1 < lines.size() else null}
	_begin(&"_lines", {"start": "0", "nodes": nodes}, {})


func _begin(id: StringName, def: Dictionary, ctx: Dictionary) -> void:
	if is_active:
		end()
	current_id = id
	_def = def
	context = ctx
	is_active = true
	GameState.lock_player(LOCK_REASON)
	_goto(entry_node(def))


## First entry whose condition holds, else "start".
func entry_node(def: Dictionary) -> String:
	for entry: Dictionary in def.get("entries", []):
		if StoryRules.evaluate(entry.get("if")):
			return String(entry["node"])
	return String(def.get("start", ""))


func advance() -> void:
	if not is_active or not _visible_choices.is_empty():
		return
	_goto(_node.get("next"))


func choose(index: int) -> void:
	if not is_active or index < 0 or index >= _visible_choices.size():
		return
	var choice: Dictionary = _visible_choices[index]
	StoryRules.apply(choice.get("effects", []))
	if is_active:  # an effect (e.g. travel) may have ended the dialogue
		_goto(choice.get("next"))


func end() -> void:
	if not is_active:
		return
	is_active = false
	var id := current_id
	current_id = &""
	_node = {}
	_visible_choices = []
	GameState.unlock_player(LOCK_REASON)
	dialogue_ended.emit(id)
	EventHub.message_finished.emit()


func _goto(node_id: Variant) -> void:
	if node_id == null or String(node_id).is_empty():
		end()
		return
	var nodes: Dictionary = _def.get("nodes", {})
	if not nodes.has(String(node_id)):
		push_error("Dialogue '%s': missing node '%s'" % [current_id, node_id])
		end()
		return
	_node = nodes[String(node_id)]
	StoryRules.apply(_node.get("effects", []))
	if not is_active:
		return
	_visible_choices = []
	var labels := PackedStringArray()
	for c: Dictionary in _node.get("choices", []):
		if StoryRules.evaluate(c.get("if")):
			_visible_choices.append(c)
			labels.append(format_text(String(c.get("text", ""))))
	var text_key := String(_node.get("text", ""))
	if text_key.is_empty() and labels.is_empty():
		_goto(_node.get("next"))  # silent node: effects only
		return
	line_shown.emit(speaker_name(String(_node.get("speaker", ""))), format_text(text_key), labels)


func speaker_name(key: String) -> String:
	if key.is_empty():
		return ""
	if key == "player":
		return GameState.player_name
	return tr(key)


func format_text(key: String) -> String:
	if key.is_empty():
		return ""
	return tr(key).format({"name": GameState.player_name})


## Static validation for tests: returns a list of problems.
func validate_all() -> PackedStringArray:
	var problems := PackedStringArray()
	for id: StringName in dialogues:
		var def: Dictionary = dialogues[id]
		var nodes: Dictionary = def.get("nodes", {})
		var targets: Array = [def.get("start")]
		for entry: Dictionary in def.get("entries", []):
			targets.append(entry.get("node"))
		for nid: String in nodes:
			var n: Dictionary = nodes[nid]
			targets.append(n.get("next"))
			for key in [n.get("text", ""), n.get("speaker", "")]:
				if not String(key).is_empty() and key != "player" and tr(key) == key:
					problems.append("%s/%s: missing text key %s" % [id, nid, key])
			for c: Dictionary in n.get("choices", []):
				targets.append(c.get("next"))
				if tr(c.get("text", "")) == c.get("text", ""):
					problems.append("%s/%s: missing choice key %s" % [id, nid, c.get("text")])
		for t: Variant in targets:
			if t != null and not nodes.has(String(t)):
				problems.append("%s: missing node '%s'" % [id, t])
	return problems
