extends Node
## Investigation journal: cases (quests), evidence with provenance, hypotheses.
##
## Evidence kinds follow docs/narrative/world-and-quest-design.md:
##   observed  - the player saw it        reported - someone told the player
##   recorded  - a document or device     (inferred/corroborated apply to hypotheses)
## A hypothesis becomes available when its required evidence is found, is
## "inferred" once the player forms it, and "corroborated" when its supporting
## evidence comes from enough *independent sources* (two people repeating the
## same rumour share one source).
## Cases are small state graphs: "transitions" lists the allowed next stages,
## "fail_forward" moves a stalled case on after N in-game days (with a note),
## so no case can soft-lock when the player misses a window.
## Definitions: res://data/journal/*.json. Owner: journal. Tests: tests/test_runner.gd.

signal evidence_added(evidence_id: StringName)
signal case_changed(case_id: StringName)
signal hypothesis_changed(hypothesis_id: StringName, status: String)

const DATA_DIR := "res://data/journal"
const STATUS_NONE := &"none"
const STATUS_ACTIVE := &"active"
const STATUS_DONE := &"done"
const HYP_LOCKED := "locked"
const HYP_AVAILABLE := "available"
const HYP_INFERRED := "inferred"
const HYP_CORROBORATED := "corroborated"

var evidence_defs: Dictionary = {}
var case_defs: Dictionary = {}
var hypothesis_defs: Dictionary = {}

## evidence_id -> {"day": int, "time": String}
var found: Dictionary = {}
## case_id -> {"status": StringName, "stage": StringName, "outcome": StringName}
var cases: Dictionary = {}
## hypothesis_id -> "inferred" | "corroborated"
var hypotheses: Dictionary = {}
## Order in which cases were started (for the journal UI).
var case_order: Array[StringName] = []


func _enter_tree() -> void:
	load_definitions()


func _ready() -> void:
	WorldClock.day_started.connect(_on_day_started)


func load_definitions() -> void:
	evidence_defs.clear()
	case_defs.clear()
	hypothesis_defs.clear()
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if file_name.get_extension() != "json":
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file_name)))
		if not data is Dictionary:
			push_error("Journal: %s is not a JSON object" % file_name)
			continue
		for id: String in data.get("evidence", {}):
			evidence_defs[StringName(id)] = data["evidence"][id]
		for id: String in data.get("cases", {}):
			case_defs[StringName(id)] = data["cases"][id]
		for id: String in data.get("hypotheses", {}):
			hypothesis_defs[StringName(id)] = data["hypotheses"][id]


func reset() -> void:
	found.clear()
	cases.clear()
	hypotheses.clear()
	case_order.clear()


# --- Evidence ----------------------------------------------------------------

func has_evidence(id: StringName) -> bool:
	return found.has(id)


func add_evidence(id: StringName) -> void:
	if found.has(id):
		return
	if not evidence_defs.has(id):
		push_error("Journal: unknown evidence '%s'" % id)
		return
	found[id] = {"day": WorldClock.day, "time": WorldClock.time_text()}
	var def: Dictionary = evidence_defs[id]
	var case_id := StringName(def.get("case", ""))
	if case_id != &"" and case_status(case_id) == STATUS_NONE:
		start_case(case_id)
	var adv: Variant = def.get("advance")
	if adv is Array and adv.size() == 2:
		set_case_stage(StringName(adv[0]), StringName(adv[1]))
	evidence_added.emit(id)
	EventHub.toast_requested.emit(tr("JOURNAL_NEW_EVIDENCE") % tr(def.get("title", "")))
	_recheck_corroboration()


func evidence_for_case(case_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in found:
		if StringName(evidence_defs[id].get("case", "")) == case_id:
			out.append(id)
	return out


# --- Cases -------------------------------------------------------------------

func case_status(id: StringName) -> StringName:
	return cases.get(id, {}).get("status", STATUS_NONE)


func case_stage(id: StringName) -> StringName:
	return cases.get(id, {}).get("stage", &"")


func start_case(id: StringName) -> void:
	if not case_defs.has(id):
		push_error("Journal: unknown case '%s'" % id)
		return
	if case_status(id) != STATUS_NONE:
		return
	var first: StringName = StringName(case_defs[id].get("first_stage", "start"))
	cases[id] = {"status": STATUS_ACTIVE, "stage": first, "outcome": &"", "stage_day": WorldClock.day}
	case_order.append(id)
	case_changed.emit(id)
	EventHub.toast_requested.emit(tr("JOURNAL_NEW_CASE") % tr(case_defs[id].get("title", "")))


func set_case_stage(id: StringName, stage: StringName) -> void:
	if case_status(id) == STATUS_NONE:
		start_case(id)
	if case_status(id) != STATUS_ACTIVE or case_stage(id) == stage:
		return
	var allowed: Array = case_defs[id].get("transitions", {}).get(String(case_stage(id)), [])
	if not allowed.is_empty() and not allowed.has(String(stage)):
		push_warning("Journal: %s moves %s -> %s outside its declared graph" % [id, case_stage(id), stage])
	cases[id]["stage"] = stage
	cases[id]["stage_day"] = WorldClock.day
	case_changed.emit(id)
	EventHub.toast_requested.emit(tr("JOURNAL_CASE_UPDATED") % tr(case_defs[id].get("title", "")))


func complete_case(id: StringName, outcome: StringName = &"") -> void:
	if case_status(id) == STATUS_NONE:
		start_case(id)
	if case_status(id) == STATUS_DONE:
		return
	cases[id]["status"] = STATUS_DONE
	cases[id]["outcome"] = outcome
	case_changed.emit(id)
	EventHub.toast_requested.emit(tr("JOURNAL_CASE_CLOSED") % tr(case_defs[id].get("title", "")))


## Fail-forward: a stage waiting longer than `after_days` moves on by itself.
func _on_day_started(day: int) -> void:
	for id: StringName in cases.keys():
		if case_status(id) != STATUS_ACTIVE:
			continue
		for rule: Dictionary in case_defs[id].get("fail_forward", []):
			if String(rule.get("stage", "")) != String(case_stage(id)):
				continue
			if day - int(cases[id].get("stage_day", day)) < int(rule.get("after_days", 2)):
				continue
			StoryRules.apply(rule.get("effects", []))
			if rule.has("to"):
				set_case_stage(id, StringName(rule["to"]))
			if rule.has("note"):
				EventHub.toast_requested.emit(tr(String(rule["note"])))
			break


## Problems in the case graphs (unknown stages, unreachable stages). For tests.
func validate_graphs() -> PackedStringArray:
	var problems := PackedStringArray()
	for id: StringName in case_defs:
		var def: Dictionary = case_defs[id]
		var stages: Dictionary = def.get("stages", {})
		var trans: Dictionary = def.get("transitions", {})
		var first := String(def.get("first_stage", "start"))
		if not stages.has(first):
			problems.append("%s: first stage '%s' undefined" % [id, first])
		for from: String in trans:
			if not stages.has(from):
				problems.append("%s: transition from unknown stage '%s'" % [id, from])
			for to: String in trans[from]:
				if not stages.has(to):
					problems.append("%s: transition to unknown stage '%s'" % [id, to])
		for rule: Dictionary in def.get("fail_forward", []):
			if not stages.has(String(rule.get("stage", ""))) or (rule.has("to") and not stages.has(String(rule["to"]))):
				problems.append("%s: fail_forward refers to unknown stage" % id)
		# Every stage must be reachable from the first one.
		var seen := {first: true}
		var queue: Array = [first]
		while not queue.is_empty():
			var s: String = queue.pop_front()
			var nexts: Array = Array(trans.get(s, []))
			for rule: Dictionary in def.get("fail_forward", []):
				if String(rule.get("stage", "")) == s and rule.has("to"):
					nexts.append(rule["to"])
			for n: Variant in nexts:
				if not seen.has(String(n)):
					seen[String(n)] = true
					queue.append(String(n))
		for s: String in stages:
			if not seen.has(s):
				problems.append("%s: stage '%s' is unreachable" % [id, s])
	return problems


## Player-facing objective text key for the current stage (or outcome when done).
func objective_key(id: StringName) -> String:
	var def: Dictionary = case_defs.get(id, {})
	if case_status(id) == STATUS_DONE:
		var outcomes: Dictionary = def.get("outcomes", {})
		return outcomes.get(String(cases[id]["outcome"]), def.get("done", ""))
	return def.get("stages", {}).get(String(case_stage(id)), "")


# --- Hypotheses ----------------------------------------------------------------

func is_hypothesis_formed(id: StringName) -> bool:
	return hypotheses.has(id)


func hypothesis_status(id: StringName) -> String:
	if hypotheses.has(id):
		return hypotheses[id]
	return HYP_AVAILABLE if can_form(id) else HYP_LOCKED


func hypotheses_for_case(case_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in hypothesis_defs:
		if StringName(hypothesis_defs[id].get("case", "")) == case_id:
			out.append(id)
	return out


func can_form(id: StringName) -> bool:
	var def: Dictionary = hypothesis_defs.get(id, {})
	if def.is_empty() or hypotheses.has(id):
		return false
	for ev: String in def.get("requires_all", []):
		if not has_evidence(StringName(ev)):
			return false
	var any_found := 0
	for ev: String in def.get("requires_any", []):
		if has_evidence(StringName(ev)):
			any_found += 1
	return any_found >= int(def.get("min_any", 0))


func form_hypothesis(id: StringName) -> bool:
	if not can_form(id):
		return false
	hypotheses[id] = HYP_INFERRED
	_update_corroboration(id)
	StoryRules.apply(hypothesis_defs[id].get("effects", []))
	hypothesis_changed.emit(id, hypotheses[id])
	return true


## Distinct provenance sources among the found evidence that supports `id`.
func independent_sources(id: StringName) -> int:
	var def: Dictionary = hypothesis_defs.get(id, {})
	var sources := {}
	for ev: String in Array(def.get("requires_all", [])) + Array(def.get("requires_any", [])):
		var e := StringName(ev)
		if has_evidence(e):
			sources[evidence_defs[e].get("source", ev)] = true
	return sources.size()


func _update_corroboration(id: StringName) -> void:
	var need := int(hypothesis_defs[id].get("corroborate_sources", 99))
	if hypotheses[id] == HYP_INFERRED and independent_sources(id) >= need:
		hypotheses[id] = HYP_CORROBORATED
		EventHub.toast_requested.emit(tr("JOURNAL_CORROBORATED") % tr(hypothesis_defs[id].get("title", "")))


func _recheck_corroboration() -> void:
	for id: StringName in hypotheses:
		var before: String = hypotheses[id]
		_update_corroboration(id)
		if hypotheses[id] != before:
			hypothesis_changed.emit(id, hypotheses[id])


# --- Save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var c := {}
	for id: StringName in cases:
		var st: Dictionary = cases[id]
		c[String(id)] = {"status": String(st["status"]), "stage": String(st["stage"]), "outcome": String(st["outcome"]),
			"stage_day": int(st.get("stage_day", 1))}
	var f := {}
	for id: StringName in found:
		f[String(id)] = found[id]
	var h := {}
	for id: StringName in hypotheses:
		h[String(id)] = hypotheses[id]
	var order: Array[String] = []
	for id in case_order:
		order.append(String(id))
	return {"found": f, "cases": c, "hypotheses": h, "case_order": order}


func from_dict(data: Dictionary) -> void:
	reset()
	var f: Dictionary = data.get("found", {})
	for id: String in f:
		if evidence_defs.has(StringName(id)):
			found[StringName(id)] = f[id]
		else:
			push_warning("Journal: dropping unknown evidence '%s' from save" % id)
	var c: Dictionary = data.get("cases", {})
	for id: String in c:
		var st: Dictionary = c[id]
		cases[StringName(id)] = {
			"status": StringName(st.get("status", "active")),
			"stage": StringName(st.get("stage", "start")),
			"outcome": StringName(st.get("outcome", "")),
			"stage_day": int(st.get("stage_day", 1)),
		}
	var h: Dictionary = data.get("hypotheses", {})
	for id: String in h:
		hypotheses[StringName(id)] = String(h[id])
	for id: Variant in data.get("case_order", []):
		if cases.has(StringName(id)):
			case_order.append(StringName(id))
	for id: StringName in cases:
		if not case_order.has(id):
			case_order.append(id)
