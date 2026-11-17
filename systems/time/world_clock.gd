extends Node
## In-game day clock and daily weather. Time advances only while the player
## is free to act (not in menus, dialogue or transitions), so story moments
## cannot be missed by reading slowly. Story events use explicit conditions,
## never "only at 14:03".
## Owner: time. Tests: tests/test_runner.gd (periods, sleeping, weather, save).

signal time_changed(minute_of_day: int)
signal period_changed(period: String)
signal day_started(day: int)
signal weather_changed(weather: String)

const START_DAY := 1
const START_MINUTE := 10 * 60
const MINUTES_PER_DAY := 24 * 60
## Game minutes per real second (1.0 -> a day lasts 24 real minutes).
const GAME_MINUTES_PER_SECOND := 1.0
const PERIODS := ["night", "morning", "afternoon", "evening"]

var day: int = START_DAY
var minute_of_day: int = START_MINUTE
var weather: String = "clear"

var _accum := 0.0
var _last_period := ""


func _ready() -> void:
	reset()


func reset() -> void:
	day = START_DAY
	minute_of_day = START_MINUTE
	weather = weather_for_day(day)
	_accum = 0.0
	_last_period = get_period()


func _process(delta: float) -> void:
	if not GameState.is_playing or get_tree().paused or GameState.is_player_locked() or SceneFlow.is_transitioning:
		return
	_accum += delta * GAME_MINUTES_PER_SECOND
	if _accum >= 1.0:
		var whole := int(_accum)
		_accum -= whole
		advance_minutes(whole)


static func period_for(minute: int) -> String:
	var h := minute / 60
	if h >= 6 and h < 12:
		return "morning"
	if h >= 12 and h < 18:
		return "afternoon"
	if h >= 18 and h < 22:
		return "evening"
	return "night"


## Deterministic daily weather: about one day in three is rainy; day 1 is clear.
static func weather_for_day(d: int) -> String:
	if d <= START_DAY:
		return "clear"
	return "rain" if posmod(d * 7919 + 13, 3) == 0 else "clear"


func get_period() -> String:
	return period_for(minute_of_day)


func get_hour() -> int:
	return minute_of_day / 60


func time_text() -> String:
	return clock_text(minute_of_day)


## "HH:MM" for a minute of the day.
static func clock_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


## Minutes since the start of day 0: for things that last across midnight.
func absolute_minute() -> int:
	return day * MINUTES_PER_DAY + minute_of_day


func advance_minutes(amount: int) -> void:
	if amount <= 0:
		return
	var total := minute_of_day + amount
	while total >= MINUTES_PER_DAY:
		total -= MINUTES_PER_DAY
		day += 1
		_set_weather(weather_for_day(day))
		day_started.emit(day)
	minute_of_day = total
	time_changed.emit(minute_of_day)
	_check_period()


## Skips to the given hour of the next day (sleeping).
func sleep_until_hour(hour: int) -> void:
	var target := hour * 60
	var amount := (MINUTES_PER_DAY - minute_of_day) + target
	advance_minutes(amount)


## Skips forward to the given hour today, or tomorrow if it has passed.
func wait_until_hour(hour: int) -> void:
	var target := hour * 60
	var amount := target - minute_of_day
	if amount <= 0:
		amount += MINUTES_PER_DAY
	advance_minutes(amount)


func to_dict() -> Dictionary:
	return {"day": day, "minute": minute_of_day, "weather": weather}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", START_DAY))
	minute_of_day = clampi(int(data.get("minute", START_MINUTE)), 0, MINUTES_PER_DAY - 1)
	weather = String(data.get("weather", weather_for_day(day)))
	_accum = 0.0
	_last_period = get_period()
	weather_changed.emit(weather)
	period_changed.emit(_last_period)


func _set_weather(w: String) -> void:
	if w != weather:
		weather = w
		weather_changed.emit(weather)


func _check_period() -> void:
	var p := get_period()
	if p != _last_period:
		_last_period = p
		period_changed.emit(p)
