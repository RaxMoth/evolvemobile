extends AbilityBase
class_name VladUltimateBloodBomb

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	# Every enemy in range, once each (never the caster).
	for entity in GameUtils.entities_in_circle(caster.get_world_2d(), caster.global_position,
			area_of_effect, GameUtils.MASK_HERO_TARGETS, false, caster):
		if entity.is_in_group("Enemy"):
			EventBus.deal_damage(caster, entity, damage, self)
