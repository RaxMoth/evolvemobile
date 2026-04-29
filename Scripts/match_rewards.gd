class_name MatchRewards
extends RefCounted

## MatchRewards — pure-logic reward computation for a finished match.
##
## No side effects: takes inputs, returns a Result. The caller (GameManager)
## applies the result to PersistedData via add_currency / add_hero_xp.
##
## Formula (from README "Earning Rates"):
##   Win:  100 currency + 50 Gold
##   Loss:  50 currency + 25 Gold
##   + 10 per mob killed
##   +  5 per minute survived
##   + 25 per monster stage reached  (monster side only)
##   + 15 per surviving hero          (hero side only)
##
## "Currency" means Steel for hero side, Leaves for monster side.

enum Side { HEROES, MONSTER }
enum Outcome { WIN, LOSS, TIMEOUT }


class Result:
	## Plain data bag. The MatchResult screen reads these for its display
	## and GameManager applies them to PersistedData.
	var side: int = Side.HEROES
	var outcome: int = Outcome.WIN

	# Stats (echoed back so the screen can show them).
	var duration_sec: float = 0.0
	var mob_kills: int = 0
	var heroes_alive: int = 0
	var monster_stage: int = 1

	# Earned currency (each side only fills its own).
	var steel: int = 0
	var leaves: int = 0
	var gold: int = 0

	## True if any currency was earned (formula always grants something on
	## win/loss, but if a future code path passes weird inputs we want a
	## clean signal).
	func has_rewards() -> bool:
		return steel > 0 or leaves > 0 or gold > 0


static func compute(
	side: int,
	outcome: int,
	duration_sec: float,
	mob_kills: int,
	heroes_alive: int,
	monster_stage: int
) -> Result:
	var r := Result.new()
	r.side = side
	r.outcome = outcome
	r.duration_sec = duration_sec
	r.mob_kills = maxi(0, mob_kills)
	r.heroes_alive = maxi(0, heroes_alive)
	r.monster_stage = clampi(monster_stage, 1, 3)

	# A timeout counts as a LOSS for whichever side's failure caused it.
	# Currently: timeout → monster wins (heroes failed to find them in time).
	var won := outcome == Outcome.WIN

	var base_currency := 100 if won else 50
	var base_gold := 50 if won else 25
	var kills_bonus := r.mob_kills * 10
	var time_bonus := int(duration_sec / 60.0) * 5

	if side == Side.HEROES:
		var survivors_bonus := r.heroes_alive * 15
		r.steel = base_currency + kills_bonus + time_bonus + survivors_bonus
		r.gold = base_gold
	else:
		var stage_bonus := r.monster_stage * 25
		r.leaves = base_currency + kills_bonus + time_bonus + stage_bonus
		r.gold = base_gold

	return r


# ============================================
# Display helpers
# ============================================

static func outcome_label(outcome: int) -> String:
	match outcome:
		Outcome.WIN: return "VICTORY"
		Outcome.LOSS: return "DEFEAT"
		Outcome.TIMEOUT: return "TIME UP"
	return ""


static func side_label(side: int) -> String:
	return "Heroes" if side == Side.HEROES else "Monster"


static func format_duration(sec: float) -> String:
	var total: int = int(sec)
	# Intentional integer division — total and 60 are both int and we want int.
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	return "%d:%02d" % [minutes, seconds]
