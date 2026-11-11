class_name MatchConfig
extends Resource

## MatchConfig — the player's pre-round strategy for the hero team.
## Chosen on the PreRoundScreen (heroes side), persisted in PersistedData
## settings so the last choice is the default next time, and read by the AI
## consumers through the derived getters below (never by poking the raw
## sliders).
## It also names the hunt's quarry (quarry_id), which the menu hands to
## GameManager.begin_hunt(); that one is chosen per hunt and never persisted
## here (the Change picker's lock lives in PersistedData).

enum Formation { TIGHT, SPREAD, LINE }

const KEY_AGGRESSION: StringName = &"match_aggression"
const KEY_FARMING: StringName = &"match_farming"
const KEY_EXPLORATION: StringName = &"match_exploration"
const KEY_FORMATION: StringName = &"match_formation"

@export_range(0.0, 1.0) var aggression: float = 0.5   ## commit to fights early vs. play safe
@export_range(0.0, 1.0) var farming: float = 0.5      ## prefer mob camps vs. hunting the monster
@export_range(0.0, 1.0) var exploration: float = 0.5  ## roam fast and wide vs. methodically
@export var formation: Formation = Formation.SPREAD
## The monster the heroes hunt (a roster id from GameManager.next_quarry()),
## shown on the pre-round screen; &"" = GameManager picks at the start.
@export var quarry_id: StringName = &""


static func from_settings() -> MatchConfig:
	var c := MatchConfig.new()
	c.aggression = clampf(float(PersistedData.get_setting(KEY_AGGRESSION, 0.5)), 0.0, 1.0)
	c.farming = clampf(float(PersistedData.get_setting(KEY_FARMING, 0.5)), 0.0, 1.0)
	c.exploration = clampf(float(PersistedData.get_setting(KEY_EXPLORATION, 0.5)), 0.0, 1.0)
	c.formation = clampi(int(PersistedData.get_setting(KEY_FORMATION, Formation.SPREAD)), 0, Formation.size() - 1) as Formation
	return c


## What the hero AI should use for THIS match: the player's choice when they
## command the heroes, neutral defaults when the heroes are the AI opponent.
static func for_current_match() -> MatchConfig:
	if GameManager.chosen_side == MatchRewards.Side.HEROES:
		return from_settings()
	return MatchConfig.new()


## Puts the strategy into the settings without writing the save file (the
## pre-round calls it on every dial change; from_settings() reads it back).
func store() -> void:
	PersistedData.set_setting(KEY_AGGRESSION, aggression)
	PersistedData.set_setting(KEY_FARMING, farming)
	PersistedData.set_setting(KEY_EXPLORATION, exploration)
	PersistedData.set_setting(KEY_FORMATION, int(formation))


func save_to_settings() -> void:
	store()
	PersistedData.save_data()


# ---------- derived values consumed by the AI ----------

## Enemies that must be clustered before a hero auto-fires its ultimate.
func auto_ult_min_enemies() -> int:
	return roundi(lerpf(4.0, 1.0, aggression))


## Ally HP fraction that triggers a panic ultimate.
func auto_ult_panic_hp_pct() -> float:
	return lerpf(0.15, 0.4, aggression)


## Target-score bonus for mobs (vs. the fixed 100 for heroes/monster).
func priority_mob() -> float:
	return lerpf(20.0, 120.0, farming)


## Seconds between exploration re-targets.
func exploration_update_interval() -> float:
	return lerpf(5.0, 1.5, exploration)


## How far ahead the group samples for unexplored tiles.
func search_radius() -> float:
	return lerpf(300.0, 600.0, exploration)


func formation_spread_px() -> float:
	match formation:
		Formation.TIGHT: return 60.0
		Formation.LINE: return 160.0
		_: return 100.0
