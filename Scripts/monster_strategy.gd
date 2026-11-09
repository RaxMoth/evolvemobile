class_name MonsterStrategy
extends Resource

## Behaviour profile for a MonsterBase (README "Monster AI — planned"):
## Stage 1 hides and farms mob camps, Stage 2 ambushes isolated heroes,
## Stage 3 hunts, and a hurt early-stage monster retreats. It only biases the
## existing hooks (target scoring, idle destination, ability choice); the state
## chart stays the single state machine. Assigned per monster scene so a future
## monster-side pre-round screen can swap profiles like MatchConfig does.

## false = legacy behaviour (always hunt the nearest hero, cleave on cooldown);
## useful for A/B runs with tools/sim.sh.
@export var enabled: bool = true

@export_group("Stages")
@export var ambush_from_stage: int = 2
@export var hunt_from_stage: int = 3

@export_group("Awareness")
## Heroes inside this radius count as "near" (flee, retreat, no farming).
@export var hero_awareness_radius: float = 400.0
## A hero this close is fought regardless of strategy (README "Desperation").
@export var cornered_radius: float = 70.0
## HUNT looks for heroes this far away.
@export var hunt_sense_radius: float = 12000.0
@export var strategy_eval_interval: float = 0.5

@export_group("Retreat")
@export_range(0.0, 1.0) var retreat_hp_pct: float = 0.3
@export var retreat_max_stage: int = 2
@export var retreat_min_heroes: int = 2

@export_group("Recovery")
## Below this HP fraction (any strategy but HUNT) the monster stops picking
## fights with mobs and rests away from camps until resume_hp_pct. Without it
## a stage-1 monster farmed itself to death one camp short of evolving.
@export_range(0.0, 1.0) var rest_hp_pct: float = 0.45
@export_range(0.0, 1.0) var resume_hp_pct: float = 0.8
## Regeneration while resting, as a fraction of max HP per second, once no
## damage was taken for regen_delay seconds.
@export var rest_regen_pct_per_sec: float = 0.006
@export var regen_delay: float = 4.0
## A resting monster keeps at least this far from camp centres (camps
## activate around the monster, so resting next to one starts a fight).
@export var rest_camp_clearance: float = 450.0

@export_group("Ambush")
## AMBUSH only engages a hero with at most this many heroes (itself included)
## within isolation_radius of it.
@export var ambush_max_heroes: int = 2
@export var isolation_radius: float = 300.0

@export_group("Farming")
## Camps with a hero this close are skipped.
@export var camp_hero_avoid_radius: float = 500.0
## Per stage (index 0 = stage 1): only farm camps whose mobs have at most this
## much max HP, and leave tougher mobs alone (walk on; they leash home).
## Stage-1 Grount (Front Cleave 12 dmg / 4.5 s) lost ~350 HP to a 3-Hog camp
## without killing one.
@export var farm_max_mob_health: Array[float] = [60.0, 150.0, 1000.0]

@export_group("Combos")
## Minimum gap between two casts (no Slam+Dash+Cleave on consecutive frames).
@export var cast_lock_time: float = 0.25
## Ram Dash is a gap closer from this distance up to its reach.
@export var dash_min_range: float = 120.0
## Only dash in when Front Cleave will be ready within this many seconds.
@export var dash_cleave_window: float = 0.4
@export var slam_min_targets: int = 2
@export var dash_on_mobs: bool = false
## A hero this close while farming/retreating triggers an escape dash.
@export var escape_dash_radius: float = 110.0
## false: ability 2 is not a movement skill (Gorrak's thrown Tusk Axe) and is
## never cast away from the heroes as an escape.
@export var escape_with_ability_2: bool = true


func max_mob_health_for_stage(stage: int) -> float:
	if farm_max_mob_health.is_empty():
		return INF
	return farm_max_mob_health[clampi(stage - 1, 0, farm_max_mob_health.size() - 1)]
