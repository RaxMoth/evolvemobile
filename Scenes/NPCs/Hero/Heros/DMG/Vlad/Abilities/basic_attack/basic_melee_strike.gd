extends AbilityBase
class_name VladBasicAttack

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= effective_range(caster):
		# Apply damage with modifier from passive
		var damage_mult = 1.0
		if caster.has_node("AbilitySystem"):
			var ability_system = caster.get_node("AbilitySystem")
			damage_mult = ability_system.get_damage_multiplier()

		var final_damage = damage * damage_mult
		EventBus.deal_damage(caster, target, final_damage, self)
