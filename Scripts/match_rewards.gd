class_name MatchRewards
extends RefCounted

## MatchRewards — pure-logic reward computation for a finished match.
##
## No side effects: takes inputs, returns a Result. The caller (GameManager)
## applies the result to PersistedData via add_currency / add_hero_xp.
##
## Formula (README "Earning Rates v2"):
##   Currency:  win 150 / loss 75
##     + 15 per mob killed
##     +  5 per full minute survived
##     + 20 per surviving hero          (hero side only)
##     + 25 per monster stage reached   (monster side only)
##   Gold:      win 100 / loss 50, + 2 per mob killed
##   Opponent Threat T (0-4, README "Opponent Threat"): currency and Gold
##     x (1 + 0.1 T), rounded; XP is not scaled.
##   Permanent XP: see compute() (unchanged by v2).
##
## "Currency" means Steel for hero side, Leaves for monster side. Economy
## only: nothing here feeds back into the match simulation.

enum Side { HEROES, MONSTER }
enum Outcome { WIN, LOSS, TIMEOUT }

const CURRENCY_WIN := 150
const CURRENCY_LOSS := 75
const CURRENCY_PER_KILL := 15
const CURRENCY_PER_MINUTE := 5
const CURRENCY_PER_SURVIVOR := 20
const CURRENCY_PER_STAGE := 25
const GOLD_WIN := 100
const GOLD_LOSS := 50
const GOLD_PER_KILL := 2
## Reward bonus per Opponent Threat level, in tenths: x (10 + T) / 10.
const THREAT_BONUS_TENTHS := 1


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
	## The match's Opponent Threat (0-4): currency and Gold carry its bonus.
	var threat: int = 0

	# Earned currency (each side only fills its own).
	var steel: int = 0
	var leaves: int = 0
	var gold: int = 0

	# Permanent XP earned this match. Awarded to each participating character
	# on the played side (per-hero XP for heroes, monster XP for the monster).
	var xp: int = 0

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
	monster_stage: int,
	threat: int = 0
) -> Result:
	var r := Result.new()
	r.side = side
	r.outcome = outcome
	r.duration_sec = duration_sec
	r.mob_kills = maxi(0, mob_kills)
	r.heroes_alive = maxi(0, heroes_alive)
	r.monster_stage = clampi(monster_stage, 1, 3)
	r.threat = maxi(0, threat)

	# A timeout counts as a LOSS for whichever side's failure caused it.
	# Currently: timeout → monster wins (heroes failed to find them in time).
	var won := outcome == Outcome.WIN

	var minutes := maxi(0, int(duration_sec / 60.0))

	var currency := CURRENCY_WIN if won else CURRENCY_LOSS
	currency += r.mob_kills * CURRENCY_PER_KILL + minutes * CURRENCY_PER_MINUTE
	if side == Side.HEROES:
		r.steel = with_threat_bonus(currency + r.heroes_alive * CURRENCY_PER_SURVIVOR, r.threat)
	else:
		r.leaves = with_threat_bonus(currency + r.monster_stage * CURRENCY_PER_STAGE, r.threat)
	r.gold = with_threat_bonus((GOLD_WIN if won else GOLD_LOSS) + r.mob_kills * GOLD_PER_KILL, r.threat)

	# Permanent XP — a flat per-match chunk scaled by performance. Each
	# participating character on the played side receives this amount.
	var xp_base := 25 if won else 10
	r.xp = xp_base + r.mob_kills * 2 + minutes * 3
	if side == Side.HEROES:
		r.xp += r.heroes_alive * 5
	else:
		r.xp += r.monster_stage * 10

	return r


## `amount` x (1 + 0.1 T), rounded half up. The product is a whole number of
## tenths, so a half is exact: 195 at threat 1 is 2145 / 10 = 214.5 -> 215.
static func with_threat_bonus(amount: int, threat: int) -> int:
	return roundi(amount * (10 + maxi(0, threat) * THREAT_BONUS_TENTHS) / 10.0)


## GameManager tracks outcomes from the heroes' perspective (WIN = monster
## died, LOSS = heroes died, TIMEOUT = clock ran out). Convert to the played
## side's perspective: for the monster a timeout is a win (it survived).
static func outcome_for_side(side: int, heroes_view: int) -> int:
	if side != Side.MONSTER:
		return heroes_view
	match heroes_view:
		Outcome.WIN: return Outcome.LOSS
		Outcome.LOSS, Outcome.TIMEOUT: return Outcome.WIN
	return heroes_view


# ============================================
# Display helpers
# ============================================

static func outcome_label(outcome: int) -> String:
	match outcome:
		Outcome.WIN: return "VICTORY"
		Outcome.LOSS: return "DEFEAT"
		Outcome.TIMEOUT: return "TIME UP"
	return ""


static func format_duration(sec: float) -> String:
	var total: int = int(sec)
	# Intentional integer division — total and 60 are both int and we want int.
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	return "%d:%02d" % [minutes, seconds]
