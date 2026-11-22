class_name BossPoise
extends Node
## A boss's balance (R15b). Hits fill it — hard hits (finishers, counters,
## heavy blows) by two more — and when it is full the boss is thrown off
## balance: it stops whatever it was doing for a moment (`break_open` on the
## boss) and every hit on it does one more. Left alone it settles again.
## The fill shows as a thin gold bar under the boss's health.

const OPEN_TIME := 2.2
const SETTLE_DELAY := 3.0

var boss: Node
var max_value := 6.0
var value := 0.0
var open_left := 0.0
var _last_hit := 0.0


static func attach(owner_boss: Node, hurt: Hurtbox, boss_health: int) -> BossPoise:
	var p := BossPoise.new()
	p.name = "Poise"
	p.boss = owner_boss
	p.max_value = maxf(4.0, round(boss_health * 0.28))
	owner_boss.add_child(p)
	hurt.hit.connect(p._on_hit)
	var before := hurt.modifier
	hurt.modifier = func(damage: int, from: Vector2) -> int:
		var d := int(before.call(damage, from)) if before.is_valid() else damage
		return d + 1 if p.is_open() and d > 0 else d
	return p


func is_open() -> bool:
	return open_left > 0.0


func _on_hit(damage: int, _from: Vector2, knockback: float) -> void:
	_last_hit = Time.get_ticks_msec() / 1000.0
	if is_open():
		return
	value += damage + (2 if knockback >= 200.0 else 0)
	if value >= max_value:
		value = 0.0
		open_left = OPEN_TIME
		if boss.has_method("break_open"):
			boss.call("break_open", OPEN_TIME)
		Sfx.play(&"hit_heavy", 0.0, 2.0)
		EventHub.camera_shake_requested.emit(4.0)
		var at := (boss as Node2D).global_position + Vector2(0, -34)
		CombatFx.text_pop(boss.get_parent(), at, tr("COMBAT_BROKEN"), Color(1, 0.85, 0.4), 12)
	_report()


func _process(delta: float) -> void:
	if open_left > 0.0:
		open_left -= delta
		_report()
	elif value > 0.0 and Time.get_ticks_msec() / 1000.0 - _last_hit > SETTLE_DELAY:
		value = maxf(0.0, value - delta * max_value * 0.25)
		_report()


func _report() -> void:
	if not is_instance_valid(boss) or (boss.get("health") as Health) == null or (boss.get("health") as Health).is_dead():
		EventHub.boss_poise_changed.emit(0.0, false)
		return
	EventHub.boss_poise_changed.emit(open_left / OPEN_TIME if is_open() else value / max_value, is_open())
