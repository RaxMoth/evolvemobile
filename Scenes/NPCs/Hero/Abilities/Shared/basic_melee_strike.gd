extends AbilityBase
class_name BasicMeleeAttack

func _init() -> void:
	ability_name = "Melee Strike"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 5.0
	cooldown = 0.8

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return

	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= ability_range:  # bare `range` was GDScript's builtin Callable, not the @export
		EventBus.deal_damage(caster, target, damage, self)
