class_name CharacterScreen
extends CanvasLayer
## Character sheet (C): level, experience, characteristics to raise.

var _box: VBoxContainer
var _panel: PanelContainer
var _focus_stat := 0


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = UiTheme.get_theme()
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(330, 0)
	dim.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 244)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_box)
	visible = false
	Progression.changed.connect(func() -> void:
		if visible:
			_build())


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	_build()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"character")):
		get_viewport().set_input_as_handled()
		close()
	elif not visible and event.is_action_pressed(&"character") and GameState.is_playing \
			and not SceneFlow.is_transitioning and not get_tree().paused and not DialogueService.is_active:
		get_viewport().set_input_as_handled()
		open()


func _label(text: String, color: Color, size := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(_label(tr("PROG_TITLE") % [GameState.player_name, Progression.level], UiTheme.ACCENT, 11))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(320, 8)
	bar.show_percentage = false
	bar.max_value = Progression.xp_to_next(Progression.level)
	bar.value = Progression.xp
	_box.add_child(bar)
	_box.add_child(_label(tr("PROG_XP") % [Progression.xp, Progression.xp_to_next(Progression.level)], UiTheme.INK_DIM))
	_box.add_child(_label(tr("PROG_POINTS") % [Progression.points, Progression.talent_points], UiTheme.INK))
	var first: Button = null
	for i in Progression.STATS.size():
		var s := Progression.STATS[i]
		var row := HBoxContainer.new()
		var name_l := _label("%s  %d" % [tr("STAT_" + s.to_upper()), Progression.get_stat(s)], UiTheme.INK, 9)
		name_l.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_l)
		var desc := _label(tr("STAT_" + s.to_upper() + "_DESC"), UiTheme.INK_DIM, 7)
		desc.custom_minimum_size = Vector2(170, 0)
		row.add_child(desc)
		var plus := Button.new()
		plus.text = "+"
		plus.disabled = Progression.points <= 0 or Progression.get_stat(s) >= Progression.MAX_STAT
		plus.pressed.connect(func() -> void:
			_focus_stat = i
			Progression.raise(s))
		row.add_child(plus)
		_box.add_child(row)
		if i == _focus_stat or first == null and not plus.disabled:
			first = plus
	_box.add_child(_label(tr("TALENT_HEADER") % Progression.talent_points, UiTheme.ACCENT, 9))
	for path: String in Progression.talent_paths():
		var pdef: Dictionary = Progression.talent_paths()[path]
		var row := HBoxContainer.new()
		var have := PackedStringArray()
		for st: Dictionary in pdef.get("steps", []):
			var key := path + "/" + String(st["id"])
			have.append(("● " if Progression.has_talent(key) else "○ ") + tr("TALENT_" + String(st["id"]).to_upper()))
		var l := _label(tr(String(pdef["name"])) + ": " + "  ".join(have), UiTheme.INK, 8)
		l.custom_minimum_size = Vector2(290, 0)
		row.add_child(l)
		var next := Progression.next_step(path)
		var learn := Button.new()
		learn.text = "+"
		learn.disabled = next == "" or Progression.talent_points <= 0
		learn.tooltip_text = tr("TALENT_" + next.get_slice("/", 1).to_upper() + "_DESC") if next != "" else ""
		learn.pressed.connect(func() -> void: Progression.learn(next))
		row.add_child(learn)
		_box.add_child(row)
		if next != "":
			_box.add_child(_label("   " + tr("TALENT_NEXT") % [tr("TALENT_" + next.get_slice("/", 1).to_upper()), tr("TALENT_" + next.get_slice("/", 1).to_upper() + "_DESC")], UiTheme.INK_DIM, 7))
	_build_companions()
	var close_b := Button.new()
	close_b.text = tr("CC_BACK")
	close_b.pressed.connect(close)
	_box.add_child(close_b)
	(first if first != null and not first.disabled else close_b).call_deferred("grab_focus")


## R8: the bond with each companion met so far, three pips, and "together".
func _build_companions() -> void:
	var rows: Array[String] = []
	for id: String in Party.defs:
		var sid := StringName(id)
		if Party.bond_points(sid) <= 0 and not Party.is_companion(sid):
			continue
		var t := Party.bond_tier(sid)
		var pips := "●".repeat(t) + "○".repeat(Party.TIERS.size() - t)
		var line := tr("COMP_ROW") % [tr(String(Party.def_of(sid).get("name", ""))), pips]
		if GameState.has_flag(StringName("romance." + id)):
			line += tr("COMP_ROMANCE")
		rows.append(line)
	if rows.is_empty():
		return
	_box.add_child(_label(tr("COMP_HEADER"), UiTheme.ACCENT, 9))
	for r in rows:
		_box.add_child(_label(r, UiTheme.INK, 8))
