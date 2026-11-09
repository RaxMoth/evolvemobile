extends AbilityBase
class_name RiverPassiveAdaptive

@export var speed_boost_multiplier: float = 1.5
@export var boost_duration: float = 3.0
## River capstone "Pathfinder": while River lives every hero's move speed is
## x this (TeamBlackboard.set_move_speed_aura; HeroBase._get_move_speed reads
## it). 1.0 = off.
@export var team_speed_aura: float = 1.0

var is_boosted: bool = false
var boost_timer: float = 0.0
var last_health: float = 0.0
## The aura is on the heroes' blackboard (written once; it leaves with River).
var _aura_posted: bool = false

func on_passive_update(caster: Node2D, delta: float) -> void:
	if not (caster is EntityBase):
		return
	if team_speed_aura != 1.0 and not _aura_posted:
		var team := TeamRegistry.team_of(caster)
		if team:
			team.set_move_speed_aura(caster as EntityBase, team_speed_aura)
			_aura_posted = true
	
	var current_health: float = (caster as EntityBase).get_health()
	
	# Detect damage taken
	if last_health > 0.0 and current_health < last_health:
		_activate_boost()
	
	last_health = current_health
	
	# Update boost timer
	if is_boosted:
		boost_timer -= delta
		if boost_timer <= 0.0:
			is_boosted = false

func _activate_boost() -> void:
	is_boosted = true
	boost_timer = boost_duration

func get_attack_speed_multiplier(_caster: Node2D) -> float:
	return speed_boost_multiplier if is_boosted else 1.0

# Used by hero stats to get movement speed bonus
func get_speed_multiplier() -> float:
	return speed_boost_multiplier if is_boosted else 1.0
