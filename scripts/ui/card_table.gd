class_name CardTable
extends CanvasLayer
## A pub card table (R7c): pontoon against the house (see Pontoon).
## Stake: Left/Right picks £1, £2 or £5; E deals. In a hand: E twists,
## Space sticks. Esc leaves between hands. A keen eye (Perception 4) reads
## the banker's face and sees whether the hidden card is high or low.
## Region screen "cards:<house>", e.g. "cards:millstone".

const STAKES := [1, 2, 5]
const READ_PERCEPTION := 4

var house := ""
var game: Pontoon
var phase := "stake"  # stake, play, result
var stake_i := 0
var session := 0  # winnings this sitting
var _root: Control
var _active := false
var _line := ""


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	_root.draw.connect(_draw_table)
	add_child(_root)
	visible = false


func start(which: String) -> void:
	house = which
	game = Pontoon.new(hash([WorldClock.day, WorldClock.minute_of_day, which, Inventory.money]))
	phase = "stake"
	session = 0
	stake_i = 0
	_line = tr("CARDS_WELCOME_" + which.to_upper())
	_active = true
	visible = true
	get_tree().paused = true
	_root.queue_redraw()


func is_open() -> bool:
	return _active


func stake() -> int:
	return STAKES[stake_i]


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"pause"):
		if phase != "play":
			close()
		return
	match phase:
		"stake":
			if event.is_action_pressed(&"move_left"):
				stake_i = maxi(0, stake_i - 1)
			elif event.is_action_pressed(&"move_right"):
				stake_i = mini(STAKES.size() - 1, stake_i + 1)
			elif event.is_action_pressed(&"interact"):
				deal()
		"play":
			if event.is_action_pressed(&"interact"):
				twist()
			elif event.is_action_pressed(&"dodge"):
				stick()
		"result":
			if event.is_action_pressed(&"interact"):
				phase = "stake"
				_line = ""
	_root.queue_redraw()


func deal() -> bool:
	if Inventory.money < stake():
		_line = tr("CARDS_NO_MONEY")
		return false
	Inventory.money -= stake()
	Inventory.changed.emit()
	game.deal(stake())
	phase = "play"
	_line = ""
	Sfx.play(&"ui_click")
	if game.result != Pontoon.Result.NONE:
		_settle()
	return true


func twist() -> void:
	game.twist()
	Sfx.play(&"ui_click", 0.1)
	if game.result != Pontoon.Result.NONE:
		_settle()


func stick() -> void:
	game.stick()
	_settle()


func _settle() -> void:
	phase = "result"
	var pay := game.payout()
	if pay > 0:
		Inventory.money += pay
		Inventory.changed.emit()
		Sfx.play(&"coin")
	session += pay - game.stake
	var key: String = "CARDS_" + String(Pontoon.Result.keys()[game.result])
	if game.result == Pontoon.Result.LOSE and Pontoon.total(game.player) > 21:
		key = "CARDS_BUST"
	elif game.result == Pontoon.Result.WIN and Pontoon.total(game.banker) > 21:
		key = "CARDS_BANKER_BUST"
	_line = tr(key) % [Pontoon.total(game.player), Pontoon.total(game.banker)]
	GameState.set_flag(&"cards.played", true)
	if game.result in [Pontoon.Result.PONTOON, Pontoon.Result.FIVE_CARD]:
		GameState.set_flag(&"cards.special", true)
	Progression.add_xp(2)


func close() -> void:
	_active = false
	visible = false
	get_tree().paused = false
	if session != 0:
		EventHub.toast_requested.emit(tr("CARDS_SESSION_UP" if session > 0 else "CARDS_SESSION_DOWN") % absi(session))


# --- Drawing ---------------------------------------------------------------

func _draw_table() -> void:
	var vp := _root.get_viewport_rect().size
	var panel := Rect2(vp.x * 0.5 - 160, vp.y * 0.5 - 92, 320, 184)
	_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.03, 0.05, 0.7))
	_root.draw_rect(panel, Color(0.12, 0.3, 0.2))
	_root.draw_rect(panel.grow(-3), Color(0.55, 0.42, 0.22), false, 2.0)
	var font := _root.get_theme_default_font()
	_root.draw_string(font, panel.position + Vector2(10, 16), tr("CARDS_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.HUD_ACCENT)
	_root.draw_string(font, panel.position + Vector2(220, 16), "£%d" % Inventory.money, HORIZONTAL_ALIGNMENT_RIGHT, 90, 9, UiTheme.HUD_INK)
	if phase != "stake" or not game.player.is_empty():
		var hide := phase == "play"
		_root.draw_string(font, panel.position + Vector2(10, 32), tr("CARDS_BANKER") + ("" if hide else "  %d" % Pontoon.total(game.banker)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.HUD_INK)
		_hand(panel.position + Vector2(14, 38), game.banker, hide)
		_root.draw_string(font, panel.position + Vector2(10, 102), tr("CARDS_YOU") + "  %d" % Pontoon.total(game.player), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.HUD_INK)
		_hand(panel.position + Vector2(14, 108), game.player, false)
	var hint := ""
	match phase:
		"stake":
			hint = tr("CARDS_HINT_STAKE") % stake()
		"play":
			hint = tr("CARDS_HINT_PLAY")
			if StoryRules.evaluate({"stat_at_least": ["perception", READ_PERCEPTION]}):
				var hidden := Pontoon.card_value(int(game.banker[1][0]))
				_root.draw_string(font, panel.position + Vector2(170, 32), tr("CARDS_READ_HIGH" if hidden >= 10 else "CARDS_READ_LOW"), HORIZONTAL_ALIGNMENT_LEFT, 140, 7, Color(0.75, 0.85, 1.0))
		"result":
			hint = tr("CARDS_HINT_NEXT")
	if _line != "":
		_root.draw_string(font, panel.position + Vector2(10, 166), _line, HORIZONTAL_ALIGNMENT_LEFT, 300, 8, Color(1.0, 0.9, 0.6))
	_root.draw_string(font, panel.position + Vector2(10, 178), hint, HORIZONTAL_ALIGNMENT_LEFT, 300, 7, UiTheme.HUD_INK)


func _hand(at: Vector2, hand: Array, hide_second: bool) -> void:
	for i in hand.size():
		var r := Rect2(at + Vector2(i * 34, 0), Vector2(28, 40))
		_root.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
		if hide_second and i == 1:
			_root.draw_rect(r, Color(0.55, 0.15, 0.18))
			_root.draw_rect(r.grow(-3), Color(0.8, 0.7, 0.5), false, 1.0)
			continue
		_root.draw_rect(r, Color(0.97, 0.95, 0.9))
		_root.draw_rect(r, Color(0.3, 0.3, 0.3), false, 1.0)
		_card_face(r, int(hand[i][0]), String(hand[i][1]))


func _card_face(r: Rect2, rank: int, suit: String) -> void:
	var red := suit in ["H", "D"]
	var col := Color(0.75, 0.12, 0.12) if red else Color(0.1, 0.1, 0.12)
	var label: String = {1: "A", 11: "J", 12: "Q", 13: "K"}.get(rank, str(rank))
	var font := _root.get_theme_default_font()
	_root.draw_string(font, r.position + Vector2(3, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	_suit(r.get_center() + Vector2(0, 4), suit, col, 6.0)


func _suit(c: Vector2, suit: String, col: Color, s: float) -> void:
	match suit:
		"D":
			_root.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)]), col)
		"H":
			_root.draw_circle(c + Vector2(-s * 0.4, -s * 0.25), s * 0.45, col)
			_root.draw_circle(c + Vector2(s * 0.4, -s * 0.25), s * 0.45, col)
			_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, -s * 0.05), c + Vector2(s * 0.85, -s * 0.05), c + Vector2(0, s)]), col)
		"S":
			_root.draw_circle(c + Vector2(-s * 0.4, s * 0.15), s * 0.45, col)
			_root.draw_circle(c + Vector2(s * 0.4, s * 0.15), s * 0.45, col)
			_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, s * 0.05), c + Vector2(s * 0.85, s * 0.05), c + Vector2(0, -s)]), col)
			_root.draw_rect(Rect2(c + Vector2(-1, s * 0.3), Vector2(2, s * 0.7)), col)
		_:
			_root.draw_circle(c + Vector2(0, -s * 0.45), s * 0.38, col)
			_root.draw_circle(c + Vector2(-s * 0.45, s * 0.1), s * 0.38, col)
			_root.draw_circle(c + Vector2(s * 0.45, s * 0.1), s * 0.38, col)
			_root.draw_rect(Rect2(c + Vector2(-1, s * 0.2), Vector2(2, s * 0.8)), col)
