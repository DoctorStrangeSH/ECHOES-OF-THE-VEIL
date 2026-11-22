class_name CombatHud
extends Control
## Boss bar (top centre) and ability cooldown pips (bottom left). Only shown
## in Veil locations; listens to EventHub.

var _boss_name := ""
var _boss_hp := 0
var _boss_max := 0
var _cooldowns := {"dodge": 0.0, "flash": 0.0}
var _shown_hp := 0.0
var _poise := 0.0
var _poise_open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventHub.boss_health_changed.connect(_on_boss)
	# A boss bar belongs to its arena: leaving the place takes it down.
	SceneFlow.location_entered.connect(func(_id: StringName) -> void: _on_boss("", 0, 0))
	EventHub.ability_cooldown.connect(_on_cooldown)
	EventHub.boss_poise_changed.connect(func(fill: float, open: bool) -> void:
		_poise = fill
		_poise_open = open
		queue_redraw())
	EventHub.player_health_changed.connect(func(_h: int, m: int) -> void: visible = m > 0 or _boss_max > 0)


func _on_boss(name_key: String, hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		_poise = 0.0
		_poise_open = false
	_boss_name = tr(name_key) if not name_key.is_empty() else ""
	_boss_hp = hp
	_boss_max = max_hp
	if max_hp > 0 and _shown_hp <= 0.0:
		_shown_hp = hp
	queue_redraw()


func _on_cooldown(ability: String, fraction: float) -> void:
	if not is_equal_approx(_cooldowns.get(ability, 0.0), fraction):
		_cooldowns[ability] = fraction
		queue_redraw()


func _process(delta: float) -> void:
	if _poise_open:
		queue_redraw()
	if _boss_max > 0 and absf(_shown_hp - _boss_hp) > 0.01:
		_shown_hp = move_toward(_shown_hp, _boss_hp, delta * 8.0)
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var vp := get_viewport_rect().size
	if _boss_max > 0:
		var w := 200.0
		var x := (vp.x - w) / 2.0
		var y := 14.0
		draw_string(font, Vector2(x, y - 3), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color(1, 0.9, 0.85))
		draw_rect(Rect2(x - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x, y, w * _shown_hp / _boss_max, 4), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(x, y, w * float(_boss_hp) / _boss_max, 4), Color(0.85, 0.2, 0.25))
		for f in [0.66, 0.33]:
			draw_line(Vector2(x + w * f, y), Vector2(x + w * f, y + 4), Color(0, 0, 0, 0.8), 1.0)
		# Balance: fills with hits; full means off balance (it blinks then).
		draw_rect(Rect2(x - 1, y + 6, w + 2, 4), Color(0, 0, 0, 0.7))
		var gold := Color(1, 0.82, 0.35)
		if _poise_open and int(Time.get_ticks_msec() / 120) % 2 == 0:
			gold = Color(1, 1, 0.8)
		draw_rect(Rect2(x, y + 7, w * clampf(_poise, 0.0, 1.0), 2), gold)
	# Ability pips: dodge (blue) and flash (gold), bottom-left.
	var labels := {"dodge": UiTheme.action_hint(&"dodge"), "flash": UiTheme.action_hint(&"ability")}
	var colors := {"dodge": Color(0.55, 0.8, 1.0), "flash": Color(1.0, 0.85, 0.45)}
	var i := 0
	for ab: String in ["dodge", "flash"]:
		var c := Vector2(14 + i * 22, vp.y - 14)
		var frac: float = _cooldowns.get(ab, 0.0)
		draw_circle(c, 8.0, Color(0, 0, 0, 0.6))
		draw_arc(c, 7.0, -PI / 2, -PI / 2 + TAU * (1.0 - frac), 24, colors[ab] if frac <= 0.0 else colors[ab].darkened(0.4), 2.0)
		draw_string(font, c + Vector2(-6, 3), String(labels[ab]).left(2), HORIZONTAL_ALIGNMENT_CENTER, 12, 7, Color.WHITE if frac <= 0.0 else Color(0.6, 0.6, 0.6))
		i += 1
