class_name Pontoon
extends RefCounted
## Pontoon (R7c, D-087): the pub version of twenty-one, as played at the
## Old Millstone and the Gull & Anchor.
##
## You and the banker get two cards. Twist for another, stick when you like.
## Over 21 is bust. Then the banker draws to 17. Ties go to the banker.
## A pontoon (an ace and a ten-card with your first two) and a five-card
## trick (five cards, 21 or under) beat any ordinary hand and pay double.
## Aces count 11 or 1, picture cards 10.

enum Result { NONE, WIN, LOSE, PONTOON, FIVE_CARD }

const SUITS := ["S", "H", "D", "C"]

var deck: Array = []  # [rank 1..13, suit]
var player: Array = []
var banker: Array = []
var stake := 1
var result: Result = Result.NONE
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()


static func card_value(rank: int) -> int:
	return 11 if rank == 1 else mini(rank, 10)


## Best total for a hand: aces drop from 11 to 1 while the hand would bust.
static func total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c: Array in hand:
		t += card_value(int(c[0]))
		if int(c[0]) == 1:
			aces += 1
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return t


static func is_pontoon(hand: Array) -> bool:
	return hand.size() == 2 and total(hand) == 21


static func is_five_card(hand: Array) -> bool:
	return hand.size() >= 5 and total(hand) <= 21


func deal(new_stake: int) -> void:
	stake = new_stake
	result = Result.NONE
	deck.clear()
	for s: String in SUITS:
		for r in range(1, 14):
			deck.append([r, s])
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Array = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	player = [deck.pop_back(), deck.pop_back()]
	banker = [deck.pop_back(), deck.pop_back()]
	if is_pontoon(player):
		_settle()


func can_twist() -> bool:
	return result == Result.NONE and total(player) < 21 and player.size() < 5


func twist() -> void:
	if not can_twist():
		return
	player.append(deck.pop_back())
	if total(player) > 21 or is_five_card(player) or total(player) == 21:
		_settle()


func stick() -> void:
	if result == Result.NONE:
		_settle()


func _settle() -> void:
	var p := total(player)
	if p > 21:
		result = Result.LOSE
		return
	if is_pontoon(player) and not is_pontoon(banker):
		result = Result.PONTOON
		return
	if is_five_card(player):
		result = Result.FIVE_CARD
		return
	if is_pontoon(banker):
		result = Result.LOSE
		return
	while total(banker) < 17 and banker.size() < 5:
		banker.append(deck.pop_back())
	var b := total(banker)
	result = Result.WIN if (b > 21 or p > b) else Result.LOSE


## What the hand returns to you, stake included (0 when lost).
func payout() -> int:
	match result:
		Result.WIN:
			return stake * 2
		Result.PONTOON, Result.FIVE_CARD:
			return stake * 3
	return 0
