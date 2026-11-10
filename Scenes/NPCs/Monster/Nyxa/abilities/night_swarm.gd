class_name NightSwarm
extends AbilityBase

## Nyxa's ultimate: a bat swarm circles her for `duration` seconds and bites
## every target within `area_of_effect` once per `tick_interval` (the first
## bite lands on the cast). The aura follows her while she keeps moving and
## screeching, and lifesteal_pct heals her from every bite (deal()).
##
## Not a node and not a timer: MonsterBase._process steps it through
## tick_active on the monster's own copy, and the only allocation is the
## overlap query's result. Its cast centre is the caster, so the combo's
## slam_min_targets counts the heroes around her. VfxManager reads
## is_active() / time_left() for its swarm ring and MonsterBase's F3 line
## reads debug_tag(); neither writes anything here.

## Seconds between two bites (the first lands on the cast).
@export var tick_interval: float = 0.5

var _time_left: float = 0.0
var _tick_left: float = 0.0
var _bite_damage: float = 0.0


func _init() -> void:
	ability_name = "Night Swarm"
	ability_type = AbilityType.ULTIMATE
	damage = 5.0
	duration = 3.5
	area_of_effect = 110.0
	cooldown = 16.0
	description = "A bat swarm circles Nyxa and bites everything close"


func get_reach() -> float:
	return area_of_effect


## The swarm is centred on Nyxa, not on her target.
func get_cast_center(caster: Node2D, _target: Node2D) -> Vector2:
	return caster.global_position


func is_active() -> bool:
	return _time_left > 0.0


## Seconds the running swarm still bites (0 when none runs).
func time_left() -> float:
	return maxf(_time_left, 0.0)


func execute(_caster: Node2D, _target: Node2D = null, override_damage: float = -1.0) -> void:
	_bite_damage = override_damage if override_damage >= 0.0 else damage
	_time_left = duration
	_tick_left = 0.0


func tick_active(caster: Node2D, delta: float) -> void:
	if _time_left <= 0.0:
		return
	if not is_instance_valid(caster) or not (caster as EntityBase).is_alive():
		_time_left = 0.0
		return
	_time_left -= delta
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += tick_interval
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			area_of_effect, GameUtils.MASK_MONSTER_TARGETS, true, caster):
		if GameUtils.can_entity_target(caster, entity):
			deal(caster, entity, _bite_damage)


## F3 (MonsterBase.debug_meta_line): whether the swarm bites and for how long.
func debug_tag() -> String:
	return "swarm! %.1f s left" % _time_left if is_active() else "swarm off"
