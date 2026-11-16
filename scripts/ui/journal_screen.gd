class_name JournalScreen
extends CanvasLayer
## Journal (Tab): cases with current objective, evidence labelled by kind and
## source, and hypotheses the player can form once the evidence supports them.
## Pauses the game while open.

const KIND_COLORS := {
	"observed": Color(0.55, 0.85, 0.95),
	"reported": Color(0.95, 0.8, 0.5),
	"recorded": Color(0.7, 0.9, 0.6),
}

var _dim: ColorRect
var _cases_list: VBoxContainer
var _detail: VBoxContainer
var _selected: StringName = &""
var _hud: Hud
var _title: Label
var _hint: Label
var _tabs: HBoxContainer
var _tab := "cases"


func setup(hud: Hud) -> void:
	_hud = hud


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_dim.visible = false


func is_open() -> bool:
	return _dim.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal") or (is_open() and event.is_action_pressed(&"pause")):
		if is_open():
			get_viewport().set_input_as_handled()
			close()
		elif _can_open() and event.is_action_pressed(&"journal"):
			get_viewport().set_input_as_handled()
			open()


func _can_open() -> bool:
	return GameState.is_playing and not SceneFlow.is_transitioning and not DialogueService.is_active \
		and not get_tree().paused


func open() -> void:
	get_tree().paused = true
	_dim.visible = true
	if _selected == &"" or not Journal.cases.has(_selected):
		_selected = Journal.case_order[0] if not Journal.case_order.is_empty() else &""
	_refresh()


func close() -> void:
	_dim.visible = false
	get_tree().paused = false


func _set_tab(tab: String) -> void:
	_tab = tab
	Sfx.play(&"ui_click")
	_refresh()


func _refresh() -> void:
	_title.text = tr("JOURNAL_TITLE")
	var act_key := Campaign.current_title_key()
	if act_key != "":
		_title.text += "  ·  " + tr(act_key)
	_hint.text = tr("JOURNAL_CLOSE_HINT")
	(_tabs.get_child(0) as Button).text = tr("JOURNAL_TAB_CASES")
	(_tabs.get_child(1) as Button).text = tr("JOURNAL_TAB_PEOPLE")
	(_tabs.get_child(2) as Button).text = tr("JOURNAL_TAB_CHRONICLE")
	(_tabs.get_child(0) as Button).button_pressed = _tab == "cases"
	(_tabs.get_child(1) as Button).button_pressed = _tab == "people"
	(_tabs.get_child(2) as Button).button_pressed = _tab == "chronicle"
	for c in _cases_list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	_cases_list.get_parent().visible = _tab == "cases" or _tab == "chronicle"
	if _tab == "people":
		_show_people()
		return
	if _tab == "chronicle":
		_show_chronicle()
		return
	if Journal.case_order.is_empty():
		_detail.add_child(_label(tr("JOURNAL_EMPTY"), UiTheme.INK_DIM))
		return
	var first_button: Button = null
	for id in Journal.case_order:
		var b := Button.new()
		var st := Journal.case_status(id)
		var mark := "[x] " if st == Journal.STATUS_DONE else ("[-] " if st == Journal.STATUS_FAILED else ("[*] " if id == Journal.pinned else "[ ] "))
		b.text = mark + tr(Journal.case_defs[id].get("title", ""))
		if st == Journal.STATUS_FAILED:
			b.add_theme_color_override("font_color", UiTheme.INK_DIM)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(_select.bind(id))
		_cases_list.add_child(b)
		if id == _selected:
			first_button = b
	if first_button != null:
		first_button.grab_focus.call_deferred()
	_show_case(_selected)


func _toggle_pin(id: StringName) -> void:
	Journal.pinned = &"" if Journal.pinned == id else id
	_refresh()


func _select(id: StringName) -> void:
	_selected = id
	_refresh()


func _show_case(id: StringName) -> void:
	var def: Dictionary = Journal.case_defs.get(id, {})
	_detail.add_child(_label(tr(def.get("title", "")), UiTheme.ACCENT, 11))
	_detail.add_child(_label(tr(def.get("summary", "")), UiTheme.INK_DIM))
	var st := Journal.case_status(id)
	var status_key := "JOURNAL_STATUS_DONE" if st == Journal.STATUS_DONE else ("JOURNAL_STATUS_FAILED" if st == Journal.STATUS_FAILED else "JOURNAL_OBJECTIVE")
	_detail.add_child(_label("%s: %s" % [tr(status_key), tr(Journal.objective_key(id))], UiTheme.INK))
	if st == Journal.STATUS_ACTIVE:
		var left := Journal.days_left(id)
		if left >= 0:
			_detail.add_child(_label(tr("JOURNAL_DAYS_LEFT") % left, Color(1.0, 0.6, 0.5)))
		for o in Journal.objectives_for(id):
			var tick := "[x] " if o["done"] else "[ ] "
			var opt := (tr("JOURNAL_OPTIONAL") + " ") if o["optional"] else ""
			_detail.add_child(_label(tick + opt + Journal.objective_text(o), UiTheme.INK_DIM if o["done"] else UiTheme.INK, 8))
		if GameSettings.shows_guide():
			var guide := QuestGuide.describe(QuestGuide.target(id))
			if guide != "":
				_detail.add_child(_label(tr("GUIDE_HEADER") + " " + guide, UiTheme.ACCENT, 8))
		var pin := Button.new()
		pin.text = tr("JOURNAL_UNPIN") if Journal.pinned == id else tr("JOURNAL_PIN")
		pin.pressed.connect(_toggle_pin.bind(id))
		_detail.add_child(pin)

	_detail.add_child(_label(tr("JOURNAL_EVIDENCE"), UiTheme.ACCENT))
	var ev := Journal.evidence_for_case(id)
	if ev.is_empty():
		_detail.add_child(_label(tr("JOURNAL_NO_EVIDENCE"), UiTheme.INK_DIM))
	for e in ev:
		var d: Dictionary = Journal.evidence_defs[e]
		var kind := String(d.get("kind", "observed"))
		var head := "[%s] %s" % [tr("EVIDENCE_KIND_" + kind.to_upper()), tr(d.get("title", ""))]
		if d.get("testimony", false):
			var v := Journal.verdict_of(e)
			head += "  — " + (tr("VERDICT_" + v.to_upper()) if v != "" else tr("VERDICT_NONE"))
		_detail.add_child(_label(head, KIND_COLORS.get(kind, UiTheme.INK)))
		var when: Dictionary = Journal.found[e]
		var src := tr("JOURNAL_SOURCE") % [tr(d.get("source_name", "")), int(when.get("day", 1)), String(when.get("time", ""))]
		_detail.add_child(_label(tr(d.get("body", "")) + "\n" + src, UiTheme.INK_DIM, 8))

	var hyps := Journal.hypotheses_for_case(id)
	if not hyps.is_empty():
		_detail.add_child(_label(tr("JOURNAL_HYPOTHESES"), UiTheme.ACCENT))
	for h in hyps:
		var hd: Dictionary = Journal.hypothesis_defs[h]
		var status := Journal.hypothesis_status(h)
		if status == Journal.HYP_LOCKED:
			_detail.add_child(_label("? " + tr("JOURNAL_HYP_LOCKED"), UiTheme.INK_DIM, 8))
			continue
		var line := "%s — %s" % [tr(hd.get("title", "")), tr("HYP_STATUS_" + status.to_upper())]
		_detail.add_child(_label(line, UiTheme.INK))
		_detail.add_child(_label(tr(hd.get("body", "")), UiTheme.INK_DIM, 8))
		if status == Journal.HYP_AVAILABLE:
			var b := Button.new()
			b.text = tr("JOURNAL_FORM_HYPOTHESIS")
			b.pressed.connect(_on_form.bind(h))
			_detail.add_child(b)
		else:
			var n := Journal.independent_sources(h)
			_detail.add_child(_label(tr("JOURNAL_SOURCES_COUNT") % n, UiTheme.INK_DIM, 8))


## Factions with standing, then every NPC the player has met: relationship,
## milestone and the semantic memories they hold about the player.
func _show_people() -> void:
	_detail.add_child(_label(tr("JOURNAL_FACTIONS"), UiTheme.ACCENT, 11))
	for f: StringName in Society.faction_defs:
		var d: Dictionary = Society.faction_defs[f]
		var v := Society.get_standing(f)
		_detail.add_child(_label("%s — %s (%+d)" % [tr(d.get("name", "")), tr("FACTION_TIER_" + Society.tier_of(v)), v], UiTheme.INK))
		_detail.add_child(_label(tr(d.get("desc", "")), UiTheme.INK_DIM, 8))
	_detail.add_child(_label(tr("JOURNAL_PEOPLE"), UiTheme.ACCENT, 11))
	var any := false
	for id: StringName in NpcRegistry.defs():
		if not GameState.has_flag(StringName("met.%s" % id)):
			continue
		any = true
		var def := NpcRegistry.get_def(id)
		var v := GameState.get_relationship(id)
		_detail.add_child(_label("%s — %s (%+d)" % [tr(def.get("name", "")), tr("REL_TIER_" + relationship_tier(v)), v], UiTheme.INK))
		var mems: Array = GameState.npc_memory.get(id, [])
		for m: Variant in mems:
			_detail.add_child(_label("  · " + tr("MEM_" + String(m).to_upper()), UiTheme.INK_DIM, 8))
	if not any:
		_detail.add_child(_label(tr("JOURNAL_NO_PEOPLE"), UiTheme.INK_DIM))


# --- Chronicle (R6a) -------------------------------------------------------------

var _chapter := ""


func _show_chronicle() -> void:
	var open := Chronicle.open_chapters()
	if open.is_empty():
		_detail.add_child(_label(tr("CHRON_EMPTY"), UiTheme.INK_DIM))
		return
	if _chapter == "" or not open.any(func(c: Dictionary) -> bool: return String(c["id"]) == _chapter):
		_chapter = String(open[open.size() - 1]["id"])
	var n := 0
	var focus: Button = null
	for c in open:
		var id := String(c["id"])
		var b := Button.new()
		if id == "prologue":
			b.text = tr("CHRON_PROLOGUE")
		elif id == "after":
			b.text = tr("CHRON_AFTER_TITLE")
		elif id in ["eleventh", "rosalind", "brook", "ford"]:
			b.text = "· " + tr(String(c["title"]))
		else:
			n += 1
			b.text = tr("CHRON_CHAPTER_N") % n
		b.add_theme_font_size_override("font_size", 8)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = String(c["id"]) == _chapter
		b.clip_text = true
		b.pressed.connect(func() -> void:
			_chapter = String(c["id"])
			_refresh())
		_cases_list.add_child(b)
		if String(c["id"]) == _chapter:
			focus = b
	if focus != null:
		focus.grab_focus.call_deferred()
	for c in open:
		if String(c["id"]) != _chapter:
			continue
		if String(c["id"]) in ["eleventh", "rosalind", "brook", "ford"]:
			_detail.add_child(_label(tr("CHRON_TALE"), UiTheme.INK_DIM, 7))
		_detail.add_child(_label(tr(String(c["title"])), UiTheme.ACCENT, 11))
		var epi := _label(tr(String(c["epigraph"])), UiTheme.INK_DIM, 8)
		epi.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_detail.add_child(epi)
		for key in Chronicle.pages(c):
			_detail.add_child(_label(tr(key), UiTheme.INK, 9))
		if not Chronicle.finished(c):
			_detail.add_child(_label("~ " + tr("CHRON_TO_BE_CONTINUED") + " ~", UiTheme.INK_DIM, 8))


static func relationship_tier(v: int) -> String:
	if v >= 6:
		return "CONFIDANT"
	if v >= 3:
		return "FRIEND"
	if v >= 1:
		return "ACQUAINTANCE"
	if v <= -3:
		return "DISTRUST"
	if v < 0:
		return "WARY"
	return "STRANGER"


func _on_form(h: StringName) -> void:
	Journal.form_hypothesis(h)
	_refresh()


func _label(text: String, color: Color, size: int = 9) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.theme = UiTheme.get_theme()
	add_child(_dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	_dim.add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	head.add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(_tabs)
	for tab in ["cases", "people", "chronicle"]:
		var tb := Button.new()
		tb.toggle_mode = true
		tb.pressed.connect(_set_tab.bind(tab))
		_tabs.add_child(tb)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	root.add_child(cols)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(130, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)
	_cases_list = VBoxContainer.new()
	_cases_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_cases_list)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 3)
	right_scroll.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 7)
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	root.add_child(_hint)
