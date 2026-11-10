class_name BullFrontCleave
extends AbilityBase

@export var cone_angle: float = 60.0
@export var cone_range: float = 80.0
@export var cone_angle_per_stage: Array[float] = [50.0, 60.0, 75.0]
## Gorrak capstone "Whirlwind": from this stage on the cleave hits all around
## the caster (apply_stage_stats sets cone_angle to 360). 0 = off; the tree
## node sets 3.
@export var full_circle_from_stage: int = 0

const FULL_CIRCLE: float = 360.0

func _init() -> void:
	ability_name = "Front Cleave"
	ability_type = AbilityType.ACTIVE
	damage = 15.0
	cooldown = 3.0
	description = "Attacks enemies in a frontal cone"

func get_reach() -> float:
	return cone_range

func apply_stage_stats(stage: int) -> void:
	super.apply_stage_stats(stage)
	# Keeps a tree's cone_angle modifier (Nyxa "Wide Shriek", Gorrak "Wide
	# Arc") on top of the stage's angle, like the four base stage stats.
	if cone_angle_per_stage.size() >= stage and stage > 0:
		cone_angle = _modified("cone_angle", cone_angle_per_stage[stage - 1])
	if is_full_circle_at(stage):
		cone_angle = FULL_CIRCLE


## Whirlwind holds at `stage`: the cleave is a full circle.
func is_full_circle_at(stage: int) -> bool:
	return full_circle_from_stage > 0 and stage >= full_circle_from_stage

func execute(caster: Node2D, _target: Node2D = null, override_damage: float = -1.0) -> void:
	var effective_damage: float = override_damage if override_damage >= 0.0 else damage
	var forward_dir: Vector2 = Vector2.from_angle((caster as EntityBase).sprite.rotation)
	var half_cone: float = deg_to_rad(cone_angle * 0.5)
	# Titan Form's flat reach (MonsterBase.get_range_bonus) widens the Fight
	# gate; the hit radius grows with it or a Titan whiffs at the gate's edge.
	var radius: float = cone_range + _caster_range_bonus(caster)
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			radius, GameUtils.MASK_MONSTER_TARGETS, true, caster):
		# Only what stands in the frontal cone (Whirlwind: all around).
		if cone_angle < FULL_CIRCLE:
			var to_entity: Vector2 = (entity.global_position - caster.global_position).normalized()
			if absf(forward_dir.angle_to(to_entity)) > half_cone:
				continue
		if GameUtils.can_entity_target(caster, entity):
			deal(caster, entity, effective_damage)


func _caster_range_bonus(caster: Node2D) -> float:
	if caster != null and caster.has_method(&"get_range_bonus"):
		return float(caster.call(&"get_range_bonus"))
	return 0.0


## F3 (MonsterBase.debug_meta_line): Whirlwind, "!" while the cleave is a
## full circle; "" on a fresh save.
func debug_tag() -> String:
	if full_circle_from_stage <= 0:
		return ""
	return "whirlwind!" if cone_angle >= FULL_CIRCLE else "whirlwind"
