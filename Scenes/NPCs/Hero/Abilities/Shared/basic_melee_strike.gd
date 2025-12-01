extends AbilityBase
class_name BasicMeleeAttack

func _init() -> void:
	ability_name = "Melee Strike"
	ability_type = AbilityType.BASIC_ATTACK
	damage = 5.0
	range = 50.0
	cooldown = 0.8

func can_use(caster: Node2D) -> bool:
	return caster.has_method("is_alive") and caster.is_alive()

func execute(caster: Node2D, target: Node2D = null) -> void:
	if not target or not target.has_method("take_damage"):
		return
	
	var distance = caster.global_position.distance_to(target.global_position)
	if distance <= range:
		target.take_damage(damage)
