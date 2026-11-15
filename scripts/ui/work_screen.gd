class_name WorkScreen
extends CanvasLayer
## One overlay for work and trade, in four modes:
##   "shop:<id>"  buy (and sell, if the shop buys) — data/economy/shops.json
##   "jobs"       today's repair jobs board — data/economy/jobs.json
##   "workbench"  crafting at home — data/economy/recipes.json
##   "business"   the repair stall: open/close, prices, stock, upgrades
## Pauses the game while open.

var mode := ""
var _sell := false
var _dim: ColorRect
var _title: Label
var _summary: Label
var _list: VBoxContainer
var _hint: Label


func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_dim.visible = false
	Inventory.changed.connect(_refresh_if_open)
	Livelihood.changed.connect(_refresh_if_open)


func is_open() -> bool:
	return _dim.visible


func open(screen: String) -> void:
	mode = screen
	_sell = false
	get_tree().paused = true
	_dim.visible = true
	Sfx.play(&"ui_open")
	_refresh()


func close() -> void:
	_dim.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"inventory")):
		get_viewport().set_input_as_handled()
		close()


func _refresh_if_open() -> void:
	if is_open():
		_refresh.call_deferred()


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_hint.text = tr("WORK_HINT")
	_summary.text = tr("WORK_SUMMARY") % [Inventory.money, Inventory.count(&"scrap"), Inventory.count(&"repair_kit"), Livelihood.repair_level()]
	if mode.begins_with("shop:"):
		_fill_shop(StringName(mode.trim_prefix("shop:")))
	elif mode == "jobs":
		_fill_jobs()
	elif mode == "workbench":
		_fill_workbench()
	elif mode == "business":
		_fill_business()
	elif mode == "expeditions":
		_fill_expeditions()
	_focus_first.call_deferred()


func _focus_first() -> void:
	var first := _first_button(_list)
	if first != null and first.is_inside_tree() and not first.is_queued_for_deletion():
		first.grab_focus()


# --- Shop ------------------------------------------------------------------------

func _fill_shop(shop: StringName) -> void:
	var def: Dictionary = Economy.shops().get(shop, {})
	_title.text = tr(def.get("name", ""))
	if bool(def.get("sells_to", false)):
		var toggle := HBoxContainer.new()
		toggle.add_child(_button(tr("SHOP_BUY"), _set_sell.bind(false), not _sell))
		toggle.add_child(_button(tr("SHOP_SELL"), _set_sell.bind(true), _sell))
		_list.add_child(toggle)
	if _sell:
		var any := false
		for id in Inventory.list():
			var price := Economy.sell_price(id)
			if price <= 0:
				continue
			any = true
			var label := "%s ×%d — £%d" % [tr(Inventory.def(id).get("name", "")), Inventory.count(id), price]
			_list.add_child(_button(label, func() -> void: Economy.sell(id)))
		if not any:
			_list.add_child(_label(tr("SHOP_NOTHING_TO_SELL"), UiTheme.INK_DIM))
		return
	var entries: Array = def.get("buy", [])
	for i in entries.size():
		var e: Dictionary = entries[i]
		var price := int(e.get("price", 0))
		var name_key := ""
		var desc := ""
		var owned := false
		if e.has("upgrade"):
			var u: Dictionary = Livelihood.upgrade_defs.get(StringName(e["upgrade"]), {})
			name_key = u.get("name", "")
			desc = tr(u.get("desc", ""))
			owned = Livelihood.has_home_upgrade(StringName(e["upgrade"]))
		else:
			var d := Inventory.def(StringName(e["item"]))
			name_key = d.get("name", "")
			desc = tr(d.get("desc", ""))
		var text := "%s — £%d" % [tr(name_key), price] if not owned else "%s — %s" % [tr(name_key), tr("SHOP_OWNED")]
		var b := _button(text, func() -> void: Economy.buy(shop, i))
		b.disabled = owned or Inventory.money < price
		_list.add_child(b)
		_list.add_child(_label(desc, UiTheme.INK_DIM, 8))


func _set_sell(value: bool) -> void:
	_sell = value
	_refresh()


# --- Jobs ------------------------------------------------------------------------

func _fill_jobs() -> void:
	_title.text = tr("JOBS_TITLE")
	_list.add_child(_label(tr("JOBS_ACTIVE") % [Livelihood.active.size(), Livelihood.MAX_ACTIVE_JOBS], UiTheme.ACCENT))
	for id in Livelihood.active:
		_list.add_child(_job_line(id, true))
	_list.add_child(_label(tr("JOBS_TODAY"), UiTheme.ACCENT))
	if Livelihood.offered.is_empty():
		_list.add_child(_label(tr("JOBS_NONE"), UiTheme.INK_DIM))
	for id in Livelihood.offered:
		_list.add_child(_job_line(id, false))


func _job_line(id: StringName, is_active: bool) -> Control:
	var d := Livelihood.job(id)
	var box := VBoxContainer.new()
	var client := tr(NpcRegistry.get_def(StringName(d.get("client", ""))).get("name", ""))
	var stars := "*".repeat(int(d.get("difficulty", 1)))
	var head := "%s  [%s]  — %s, £%d, %s %d" % [tr(d.get("name", "")), stars, client, int(d.get("pay", 0)), tr("JOBS_SCRAP"), int(d.get("scrap", 0))]
	if is_active:
		box.add_child(_label(head, UiTheme.INK))
		box.add_child(_label(tr(d.get("desc", "")), UiTheme.INK_DIM, 8))
		box.add_child(_button(tr("JOBS_ABANDON"), func() -> void: Livelihood.abandon(id)))
	else:
		var b := _button(head, func() -> void: Livelihood.accept(id))
		b.disabled = Livelihood.active.size() >= Livelihood.MAX_ACTIVE_JOBS
		box.add_child(b)
		box.add_child(_label(tr(d.get("desc", "")), UiTheme.INK_DIM, 8))
	return box


# --- Workbench -------------------------------------------------------------------

func _fill_workbench() -> void:
	_title.text = tr("WORKBENCH_TITLE")
	for r: StringName in Economy.recipes():
		var def: Dictionary = Economy.recipes()[r]
		var parts := PackedStringArray()
		for item: String in def.get("inputs", {}):
			parts.append("%s ×%d" % [tr(Inventory.def(StringName(item)).get("name", "")), int(def["inputs"][item])])
		var b := _button("%s  ←  %s" % [tr(def.get("name", "")), ", ".join(parts)], func() -> void: Economy.craft(r))
		b.disabled = not Economy.can_craft(r)
		_list.add_child(b)


# --- Expeditions (M8a) -------------------------------------------------------------

func _fill_expeditions() -> void:
	_title.text = tr("EXP_TITLE")
	_summary.text = tr("EXP_SUMMARY") % [Inventory.count(Expedition.SHARD), Expedition.pages.size(), Expedition.page_defs().size()]
	var res := Expedition.last_result
	if not res.is_empty():
		var site_name := tr(String(Expedition.sites().get(res.get("site", ""), {}).get("name", "")))
		if bool(res.get("ok", false)):
			_list.add_child(_label(tr("EXP_LAST_OK") % [site_name, int(res["shards"]), int(res["resonance"])], UiTheme.ACCENT))
		else:
			_list.add_child(_label(tr("EXP_LAST_FAILED") % site_name, UiTheme.INK_DIM))
	_list.add_child(_label(tr("EXP_TODAY"), UiTheme.ACCENT))
	for offer in Expedition.offers():
		var site: Dictionary = Expedition.sites()[offer["site"]]
		var mods := PackedStringArray()
		for m: String in offer["mods"]:
			mods.append(tr(String(Expedition.modifiers()[m]["name"])))
		var boss_name := tr(String(Expedition.rematches()[offer["boss"]]["name"]))
		var text := tr("EXP_OFFER") % [tr(String(site["name"])), ", ".join(mods), Expedition.reward_for(offer)]
		_list.add_child(_button(text, _start_expedition.bind(offer)))
		var descs := PackedStringArray()
		for m: String in offer["mods"]:
			descs.append(tr(String(Expedition.modifiers()[m]["desc"])))
		_list.add_child(_label(tr("EXP_BOSS") % boss_name + " " + " ".join(descs), UiTheme.INK_DIM, 8))
	_list.add_child(_label(tr("EXP_INDEX"), UiTheme.ACCENT))
	var ids: Array = Expedition.page_defs().keys()
	ids.sort()
	for id: String in ids:
		var def: Dictionary = Expedition.page_defs()[id]
		if Expedition.pages.has(id):
			_list.add_child(_label("• " + tr(String(def["title"])) + " — " + tr(String(def["text"])), UiTheme.INK, 8))
		else:
			_list.add_child(_label("• " + tr("EXP_PAGE_MISSING"), UiTheme.INK_DIM, 8))


func _start_expedition(offer: Dictionary) -> void:
	close()
	Expedition.start(offer)


# --- Business --------------------------------------------------------------------

func _fill_business() -> void:
	_title.text = tr("BIZ_TITLE")
	var s := Livelihood.stall
	var biz := Livelihood.business_def
	var report: Dictionary = s.get("report", {})
	if not report.is_empty() and bool(report.get("open", false)):
		_list.add_child(_label(tr("BIZ_REPORT") % [int(report.get("sold", 0)), int(report.get("income", 0)), int(report.get("upkeep", 0))], UiTheme.INK))
	_list.add_child(_label(tr("BIZ_STATUS") % [int(s["stock"]), int(s["reputation"])], UiTheme.INK_DIM))
	var open_text := tr("BIZ_CLOSE") if bool(s["open"]) else tr("BIZ_OPEN")
	_list.add_child(_button(open_text, func() -> void: Livelihood.set_stall_open(not bool(Livelihood.stall["open"]))))
	_list.add_child(_label(tr("BIZ_PRICES"), UiTheme.ACCENT))
	var tiers := HBoxContainer.new()
	for tier: String in biz.get("price_tiers", {}):
		var t: Dictionary = biz["price_tiers"][tier]
		var text := "%s £%d (~%d)" % [tr("BIZ_TIER_" + tier.to_upper()), int(t["price"]), Livelihood.expected_customers(tier)]
		tiers.add_child(_button(text, func() -> void: Livelihood.set_stall_tier(tier), s["tier"] == tier))
	_list.add_child(tiers)
	var stock := _button(tr("BIZ_STOCK") % Inventory.count(&"repair_kit"), func() -> void: Livelihood.stock_stall(99))
	stock.disabled = Inventory.count(&"repair_kit") == 0
	_list.add_child(stock)
	_list.add_child(_label(tr("BIZ_UPGRADES"), UiTheme.ACCENT))
	for id: String in biz.get("upgrades", {}):
		var u: Dictionary = biz["upgrades"][id]
		var owned := (s["upgrades"] as Array).has(id)
		var text := "%s — %s" % [tr(u.get("name", "")), tr("SHOP_OWNED") if owned else "£%d" % int(u.get("price", 0))]
		var b := _button(text, func() -> void: Livelihood.buy_stall_upgrade(id))
		b.disabled = owned or not Livelihood.can_buy_stall_upgrade(id)
		_list.add_child(b)
		_list.add_child(_label(tr(u.get("desc", "")), UiTheme.INK_DIM, 8))


# --- Widgets -----------------------------------------------------------------------

func _button(text: String, action: Callable, pressed: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if pressed:
		b.toggle_mode = true
		b.button_pressed = true
	b.pressed.connect(action)
	return b


func _label(text: String, color: Color, size: int = 9) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button and not (c as Button).disabled:
			return c
		var inner := _first_button(c)
		if inner != null:
			return inner
	return null


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.theme = UiTheme.get_theme()
	add_child(_dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 14
	panel.offset_right = -40
	panel.offset_bottom = -14
	_dim.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	root.add_child(_title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 8)
	_summary.add_theme_color_override("font_color", UiTheme.INK_DIM)
	root.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.pressed.connect(close)
	root.add_child(close_button)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 7)
	_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	root.add_child(_hint)
